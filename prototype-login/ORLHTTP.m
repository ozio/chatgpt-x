#import "ORLHTTP.h"
#import <CFNetwork/CFNetwork.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <mach/mach_time.h>
#include <math.h>
#include <netinet/in.h>
#include <pthread.h>
#include <stdint.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <unistd.h>
#include <zlib.h>
#include <mbedtls/ctr_drbg.h>
#include <mbedtls/entropy.h>
#include <mbedtls/net_sockets.h>
#include <mbedtls/ssl.h>
#include <psa/crypto.h>

NSString * const ORLHTTPErrorDomain = @"ORLHTTP";
static const NSUInteger ORLRequestLimit = 1024 * 1024;
static const NSUInteger ORLResponseLimit = 8 * 1024 * 1024;
static const NSUInteger ORLHeaderLimit = 64 * 1024;
static const NSUInteger ORLLineLimit = 16 * 1024;

static pthread_mutex_t ORLLibraryLock = PTHREAD_MUTEX_INITIALIZER;
static pthread_once_t ORLClockOnce = PTHREAD_ONCE_INIT;
static mach_timebase_info_data_t ORLClockScale;
static BOOL ORLPSAReady = NO;

static void ORLClockInit(void) { mach_timebase_info(&ORLClockScale); }
static double ORLNow(void) {
    pthread_once(&ORLClockOnce, ORLClockInit);
    return ((double)mach_absolute_time() * ORLClockScale.numer / ORLClockScale.denom) / 1000000000.0;
}
static NSError *ORLError(ORLHTTPErrorCode code, NSString *reason) {
    return [NSError errorWithDomain:ORLHTTPErrorDomain code:code
        userInfo:@{NSLocalizedDescriptionKey: [@"http_" stringByAppendingString:reason]}];
}
static BOOL ORLFail(NSError **error, ORLHTTPErrorCode code, NSString *reason) {
    if (error) *error = ORLError(code, reason);
    return NO;
}
static BOOL ORLAlive(double deadline, BOOL (^cancelled)(void), NSError **error) {
    @try {
        if (cancelled && cancelled()) return ORLFail(error, ORLHTTPCancelled, @"cancelled");
    } @catch(NSException *exception) {
        (void)exception;return ORLFail(error,ORLHTTPInvalidRequest,@"request_failed");
    }
    if (ORLNow() >= deadline) return ORLFail(error, ORLHTTPTimeout, @"timeout");
    return YES;
}
static BOOL ORLTokenByte(unsigned char c) {
    if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) return YES;
    switch (c) {
        case '!': case '#': case '$': case '%': case '&': case '\'': case '*':
        case '+': case '-': case '.': case '^': case '_': case 0x60: case '|': case '~': return YES;
        default: return NO;
    }
}
static BOOL ORLToken(NSString *s) {
    NSData *b = [s dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:NO];
    if (!b.length) return NO;
    const unsigned char *p = b.bytes;
    for (NSUInteger i = 0; i < b.length; i++) if (!ORLTokenByte(p[i])) return NO;
    return YES;
}
static BOOL ORLHeaderValue(NSString *s) {
    NSData *b = [s dataUsingEncoding:NSISOLatin1StringEncoding allowLossyConversion:NO];
    if (!b && s.length) return NO;
    const unsigned char *p = b.bytes;
    for (NSUInteger i = 0; i < b.length; i++)
        if ((p[i] < 32 && p[i] != '\t') || p[i] == 127) return NO;
    return YES;
}
static NSString *ORLTrim(NSString *s) {
    return [s stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" \t"]];
}
static NSString *ORLHeaderName(NSString *lower) {
    NSMutableArray *parts = [NSMutableArray array];
    for (NSString *p in [lower componentsSeparatedByString:@"-"]) {
        if (!p.length) { [parts addObject:@""]; continue; }
        [parts addObject:[[[p substringToIndex:1] uppercaseString]
            stringByAppendingString:[p substringFromIndex:1]]];
    }
    return [parts componentsJoinedByString:@"-"];
}
static BOOL ORLDecimal(NSString *s, NSUInteger bound, NSUInteger *value) {
    NSData *d = [s dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:NO];
    if (!d.length) return NO;
    const unsigned char *p = d.bytes; NSUInteger n = 0;
    for (NSUInteger i = 0; i < d.length; i++) {
        if (p[i] < '0' || p[i] > '9' || n > bound / 10) return NO;
        NSUInteger digit = p[i] - '0';
        if (n * 10 > bound - digit) return NO;
        n = n * 10 + digit;
    }
    *value = n; return YES;
}
static NSString *ORLTarget(NSURL *url, NSError **error) {
    NSString *path = [(id)CFURLCopyPath((CFURLRef)url) autorelease];
    NSString *query = [(id)CFURLCopyQueryString((CFURLRef)url, NULL) autorelease];
    if (!path.length) path = @"/";
    if(path.length>ORLLineLimit || query.length>ORLLineLimit ||
        path.length+query.length+(query?1:0)>ORLLineLimit){
        ORLFail(error,ORLHTTPInvalidRequest,@"invalid_target");return nil;
    }
    if (![path hasPrefix:@"/"]) { ORLFail(error, ORLHTTPInvalidRequest, @"invalid_target"); return nil; }
    NSString *target = query ? [path stringByAppendingFormat:@"?%@", query] : path;
    NSData *ascii = [target dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:NO];
    if (!ascii || ascii.length > ORLLineLimit) {
        ORLFail(error, ORLHTTPInvalidRequest, @"invalid_target"); return nil;
    }
    const unsigned char *p = ascii.bytes;
    for (NSUInteger i = 0; i < ascii.length; i++) {
        if (p[i] <= 32 || p[i] >= 127 || p[i] == '#' || p[i] == '\\') {
            ORLFail(error, ORLHTTPInvalidRequest, @"invalid_target"); return nil;
        }
        if (p[i] == '%') {
            if (i + 2 >= ascii.length) {
                ORLFail(error, ORLHTTPInvalidRequest, @"invalid_escape"); return nil;
            }
            for (NSUInteger j = 1; j <= 2; j++) {
                unsigned char c = p[i+j];
                if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'))) {
                    ORLFail(error, ORLHTTPInvalidRequest, @"invalid_escape"); return nil;
                }
            }
            i += 2;
        }
    }
    return target;
}
static BOOL ORLValidateURL(NSURL *url, NSSet *allowedHosts, NSError **error) {
    if (![url isKindOfClass:[NSURL class]] || ![[url.scheme lowercaseString] isEqualToString:@"https"] ||
        url.user || url.password || ![allowedHosts isKindOfClass:[NSSet class]]) {
        return ORLFail(error, ORLHTTPInvalidRequest, @"destination_not_allowed");
    }
    NSString *rawHost=url.host;
    if(!rawHost.length || rawHost.length>253)
        return ORLFail(error,ORLHTTPInvalidRequest,@"invalid_host");
    NSString *host=[rawHost lowercaseString];
    NSData *ascii=[host dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:NO];
    if(!ascii || [host rangeOfCharacterFromSet:
        [[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789.-"] invertedSet]].location!=NSNotFound)
        return ORLFail(error,ORLHTTPInvalidRequest,@"invalid_host");
    if(![allowedHosts containsObject:host])
        return ORLFail(error,ORLHTTPInvalidRequest,@"destination_not_allowed");
    NSNumber *port=url.port;
#if defined(ORL_HTTP_TESTING)
    if(port && (port.longLongValue<1 || port.longLongValue>65535))
#else
    if(port && port.integerValue!=443)
#endif
        return ORLFail(error,ORLHTTPInvalidRequest,@"port_not_allowed");
    return ORLTarget(url,error)!=nil;
}
@interface ORLBodyEvents : NSObject <NSStreamDelegate> {
@public BOOL readable, ended, failed;
}
@end
@implementation ORLBodyEvents
- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)event {
    (void)stream;
    if(event & NSStreamEventHasBytesAvailable)readable=YES;
    if(event & NSStreamEventEndEncountered)ended=YES;
    if(event & NSStreamEventErrorOccurred)failed=YES;
}
@end
static NSData *ORLBody(NSURLRequest *request, double deadline, BOOL (^cancelled)(void), NSError **error) {
    NSData *body = request.HTTPBody;
    NSInputStream *stream = request.HTTPBodyStream;
    if (body && stream) {
        ORLFail(error, ORLHTTPInvalidRequest, @"ambiguous_body"); return nil;
    }
    if (body) {
        if (![body isKindOfClass:[NSData class]] || body.length > ORLRequestLimit) {
            ORLFail(error, ORLHTTPSizeLimit, @"request_too_large"); return nil;
        }
        return [[body copy] autorelease];
    }
    if (!stream) return [NSData data];
    NSMutableData *result = [NSMutableData data];
    NSString *mode=@"ORLHTTPBodyStream";
    id previousDelegate=[[stream delegate] retain];
    ORLBodyEvents *events=[ORLBodyEvents new];
    @try {
        [stream setDelegate:events];
        [stream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:mode];
        [stream open];
        for (;;) {
            if (!ORLAlive(deadline, cancelled, error)) return nil;
            NSStreamStatus status = stream.streamStatus;
            if (events->failed || status == NSStreamStatusError || status == NSStreamStatusClosed ||
                status == NSStreamStatusNotOpen) {
                ORLFail(error, ORLHTTPBodyStreamFailure, @"request_stream_failed"); return nil;
            }
            if (events->ended || status == NSStreamStatusAtEnd) break;
            if (![stream hasBytesAvailable] && !events->readable) {
                SInt32 code=CFRunLoopRunInMode((CFStringRef)mode,0.01,true);
                if(code==kCFRunLoopRunFinished)usleep(10000);
                continue;
            }
            events->readable=NO;
            unsigned char chunk[8192];
            NSInteger n = [stream read:chunk maxLength:sizeof(chunk)];
            if (n < 0) { ORLFail(error, ORLHTTPBodyStreamFailure, @"request_stream_failed"); return nil; }
            if (n == 0) break;
            if ((NSUInteger)n > ORLRequestLimit - result.length) {
                ORLFail(error, ORLHTTPSizeLimit, @"request_too_large"); return nil;
            }
            [result appendBytes:chunk length:(NSUInteger)n];
        }
    } @finally {
        [stream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:mode];
        [stream close];[stream setDelegate:previousDelegate];
        [events release];[previousDelegate release];
    }
    return result;
}
static NSDictionary *ORLPrepare(NSURLRequest *request, double deadline, BOOL (^cancelled)(void), NSError **error) {
    if (![request isKindOfClass:[NSURLRequest class]]) {
        ORLFail(error, ORLHTTPInvalidRequest, @"invalid_request"); return nil;
    }
    NSString *method = request.HTTPMethod ?: @"GET";
    if (![@[@"GET", @"HEAD", @"POST", @"PUT", @"PATCH", @"DELETE", @"OPTIONS"] containsObject:method]) {
        ORLFail(error, ORLHTTPInvalidRequest, @"method_not_supported"); return nil;
    }
    NSString *target = ORLTarget(request.URL, error);
    if (!target) return nil;
    NSData *body = ORLBody(request, deadline, cancelled, error);
    if (!body) return nil;
    NSDictionary *source = request.allHTTPHeaderFields ?: @{};
    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    NSUInteger fieldBudget=0;
    if(source.count>256){ORLFail(error,ORLHTTPSizeLimit,@"request_headers_too_large");return nil;}
    for (id key in source) {
        id value = source[key];
        if (![key isKindOfClass:[NSString class]] || ![value isKindOfClass:[NSString class]]) {
            ORLFail(error, ORLHTTPInvalidRequest, @"invalid_request_header"); return nil;
        }
        if([key length]>ORLHeaderLimit || [value length]>ORLHeaderLimit ||
            [key length]+[value length]+4>ORLHeaderLimit-fieldBudget){
            ORLFail(error,ORLHTTPSizeLimit,@"request_headers_too_large");return nil;
        }
        fieldBudget+=[key length]+[value length]+4;
        if (!ORLToken(key) || !ORLHeaderValue(value)) {
            ORLFail(error, ORLHTTPInvalidRequest, @"invalid_request_header"); return nil;
        }
        NSString *lower = [key lowercaseString];
        if (headers[lower]) {
            ORLFail(error, ORLHTTPInvalidRequest, @"duplicate_request_header"); return nil;
        }
        headers[lower] = value;
    }
    NSString *host = [request.URL.host lowercaseString];
    NSString *hostHeader = host;
#if defined(ORL_HTTP_TESTING)
    if (request.URL.port && request.URL.port.integerValue != 443)
        hostHeader = [host stringByAppendingFormat:@":%@", request.URL.port];
#endif
    if (headers[@"host"] && ![[headers[@"host"] lowercaseString] isEqualToString:hostHeader] &&
        ![[headers[@"host"] lowercaseString] isEqualToString:[host stringByAppendingString:@":443"]]) {
        ORLFail(error, ORLHTTPInvalidRequest, @"host_header_mismatch"); return nil;
    }
    for (NSString *bad in @[@"transfer-encoding", @"te", @"trailer", @"upgrade", @"expect", @"proxy-authorization"]) {
        if (headers[bad]) { ORLFail(error, ORLHTTPInvalidRequest, @"unsupported_request_header"); return nil; }
    }
    if (headers[@"content-length"]) {
        NSUInteger declared = 0;
        if (!ORLDecimal(ORLTrim(headers[@"content-length"]), ORLRequestLimit, &declared) ||
            declared != body.length) {
            ORLFail(error, ORLHTTPInvalidRequest, @"request_length_mismatch"); return nil;
        }
    }
    for (NSString *omit in @[@"host", @"connection", @"proxy-connection", @"keep-alive",
                             @"accept-encoding", @"content-length"]) [headers removeObjectForKey:omit];
    headers[@"host"] = hostHeader;
    headers[@"connection"] = @"close";
    headers[@"accept-encoding"] = @"gzip";
    if (!headers[@"user-agent"]) headers[@"user-agent"] = @"LegacyClient/0.1 (iOS 6)";
    if (body.length || [@[@"POST", @"PUT", @"PATCH"] containsObject:method])
        headers[@"content-length"] = [NSString stringWithFormat:@"%lu", (unsigned long)body.length];
    NSMutableString *head = [NSMutableString stringWithFormat:@"%@ %@ HTTP/1.1\r\n", method, target];
    for (NSString *lower in [[headers allKeys] sortedArrayUsingSelector:@selector(compare:)])
        [head appendFormat:@"%@: %@\r\n", ORLHeaderName(lower), headers[lower]];
    [head appendString:@"\r\n"];
    NSData *encoded = [head dataUsingEncoding:NSISOLatin1StringEncoding allowLossyConversion:NO];
    if (!encoded || encoded.length > ORLHeaderLimit) {
        ORLFail(error, ORLHTTPSizeLimit, @"request_headers_too_large"); return nil;
    }
    NSMutableData *wire = [NSMutableData dataWithData:encoded]; [wire appendData:body];
    NSMutableURLRequest *prepared = [[request mutableCopy] autorelease];
    [prepared setHTTPBody:body];
    return @{@"wire":wire, @"request":[[prepared copy] autorelease], @"method":method};
}

/* A bounded incremental reader shared by sockets and offline framing fixtures. */
typedef NSInteger (^ORLReadBlock)(unsigned char *, NSUInteger, NSError **);
@interface ORLHTTPReader : NSObject {
    NSMutableData *_buffer;
    NSUInteger _offset, _wireBytes;
    BOOL _eof;
    ORLReadBlock _read;
}
- (id)initWithRead:(ORLReadBlock)read;
- (NSData *)line:(NSUInteger)limit error:(NSError **)error;
- (BOOL)take:(NSUInteger)count into:(NSMutableData *)data error:(NSError **)error;
- (BOOL)untilEOF:(NSMutableData *)data error:(NSError **)error;
- (NSUInteger)remaining;
@end
@implementation ORLHTTPReader
- (id)initWithRead:(ORLReadBlock)read {
    if ((self = [super init])) { _buffer = [NSMutableData new]; _read = [read copy]; }
    return self;
}
- (BOOL)fill:(NSError **)error {
    if (_eof) return YES;
    if (_offset) {
        [_buffer replaceBytesInRange:NSMakeRange(0, _offset) withBytes:NULL length:0]; _offset = 0;
    }
    unsigned char chunk[8192]; NSInteger n = _read(chunk, sizeof(chunk), error);
    if (n < 0) return NO;
    if ((NSUInteger)n > sizeof(chunk)) return ORLFail(error, ORLHTTPInvalidResponse, @"reader_failed");
    if ((NSUInteger)n > ORLResponseLimit+2*ORLHeaderLimit-_wireBytes)
        return ORLFail(error,ORLHTTPSizeLimit,@"response_wire_too_large");
    _wireBytes+=(NSUInteger)n;
    if (!n) _eof = YES;
    else [_buffer appendBytes:chunk length:(NSUInteger)n];
    return YES;
}
- (NSUInteger)remaining { return _buffer.length - _offset; }
- (NSData *)line:(NSUInteger)limit error:(NSError **)error {
    for (;;) {
        const unsigned char *p = _buffer.bytes;
        NSUInteger n = self.remaining;
        for (NSUInteger i = 0; i < n; i++) {
            if (p[_offset+i] != '\n') continue;
            if (!i || p[_offset+i-1] != '\r') {
                ORLFail(error, ORLHTTPInvalidResponse, @"invalid_line_ending"); return nil;
            }
            if (i-1 > limit) { ORLFail(error, ORLHTTPSizeLimit, @"line_too_large"); return nil; }
            NSData *line = [_buffer subdataWithRange:NSMakeRange(_offset, i-1)];
            _offset += i+1; return line;
        }
        if (n > limit+1) { ORLFail(error, ORLHTTPSizeLimit, @"line_too_large"); return nil; }
        if (_eof) { ORLFail(error, ORLHTTPInvalidResponse, @"truncated_response"); return nil; }
        if (![self fill:error]) return nil;
    }
}
- (BOOL)take:(NSUInteger)count into:(NSMutableData *)data error:(NSError **)error {
    if (count > ORLResponseLimit - data.length)
        return ORLFail(error, ORLHTTPSizeLimit, @"response_too_large");
    while (count) {
        if (!self.remaining) {
            if (_eof) return ORLFail(error, ORLHTTPInvalidResponse, @"truncated_body");
            if (![self fill:error]) return NO;
            continue;
        }
        NSUInteger n = MIN(count, self.remaining);
        [data appendBytes:(const unsigned char *)_buffer.bytes+_offset length:n];
        _offset += n; count -= n;
    }
    return YES;
}
- (BOOL)untilEOF:(NSMutableData *)data error:(NSError **)error {
    for (;;) {
        NSUInteger n = self.remaining;
        if (n && ![self take:n into:data error:error]) return NO;
        if (_eof) return YES;
        if (![self fill:error]) return NO;
    }
}
- (void)dealloc { [_buffer release]; [_read release]; [super dealloc]; }
@end

static BOOL ORLField(NSData *line, NSString **name, NSString **value, NSError **error) {
    const unsigned char *p = line.bytes; NSUInteger n = line.length, colon = NSNotFound;
    if (!n || p[0] == ' ' || p[0] == '\t')
        return ORLFail(error, ORLHTTPInvalidResponse, @"folded_header");
    for (NSUInteger i = 0; i < n; i++) {
        if (p[i] == ':') { colon = i; break; }
        if (!ORLTokenByte(p[i])) return ORLFail(error, ORLHTTPInvalidResponse, @"invalid_header_name");
    }
    if (colon == NSNotFound || !colon)
        return ORLFail(error, ORLHTTPInvalidResponse, @"invalid_header_name");
    NSString *key = [[[NSString alloc] initWithBytes:p length:colon encoding:NSASCIIStringEncoding] autorelease];
    NSString *text = [[[NSString alloc] initWithBytes:p+colon+1 length:n-colon-1
        encoding:NSISOLatin1StringEncoding] autorelease];
    if (!text || !ORLHeaderValue(text))
        return ORLFail(error, ORLHTTPInvalidResponse, @"invalid_header_value");
    *name = [key lowercaseString]; *value = ORLTrim(text); return YES;
}
static NSDictionary *ORLHead(ORLHTTPReader *reader, NSUInteger *headerBytes, NSError **error) {
    NSData *line = [reader line:ORLLineLimit error:error];
    if (!line) return nil;
    *headerBytes += line.length+2;
    const unsigned char *p = line.bytes;
    if (line.length < 12 ||
        (memcmp(p,"HTTP/1.1 ",9) && memcmp(p,"HTTP/1.0 ",9)) ||
        p[9] < '1' || p[9] > '5' || p[10] < '0' || p[10] > '9' ||
        p[11] < '0' || p[11] > '9' || (line.length > 12 && p[12] != ' ')) {
        ORLFail(error, ORLHTTPInvalidResponse, @"invalid_status"); return nil;
    }
    for (NSUInteger i = 0; i < line.length; i++)
        if ((p[i] < 32 && p[i] != '\t') || p[i] == 127) {
            ORLFail(error, ORLHTTPInvalidResponse, @"invalid_status"); return nil;
        }
    NSInteger status = (p[9]-'0')*100+(p[10]-'0')*10+p[11]-'0';
    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    NSMutableArray *cookies = [NSMutableArray array];
    NSSet *singles = [NSSet setWithArray:@[@"content-length",@"transfer-encoding",
        @"content-encoding",@"location",@"host"]];
    NSUInteger count = 0;
    for (;;) {
        line = [reader line:ORLLineLimit error:error];
        if (!line) return nil;
        *headerBytes += line.length+2;
        if (*headerBytes > ORLHeaderLimit || ++count > 256) {
            ORLFail(error, ORLHTTPSizeLimit, @"headers_too_large"); return nil;
        }
        if (!line.length) break;
        NSString *name = nil, *value = nil;
        if (!ORLField(line, &name, &value, error)) return nil;
        if ([name isEqualToString:@"set-cookie"]) { [cookies addObject:value]; continue; }
        if (headers[name] && [singles containsObject:name]) {
            ORLFail(error, ORLHTTPInvalidResponse, @"ambiguous_header"); return nil;
        }
        headers[name] = headers[name] ? [headers[name] stringByAppendingFormat:@", %@",value] : value;
    }
    if (headers[@"content-length"] && headers[@"transfer-encoding"]) {
        ORLFail(error, ORLHTTPInvalidResponse, @"ambiguous_framing"); return nil;
    }
    return @{@"status":@(status), @"headers":headers, @"setCookies":cookies};
}
static BOOL ORLChunkSize(NSData *line, NSUInteger *size, NSError **error) {
    const unsigned char *p = line.bytes; NSUInteger i = 0, n = line.length, value = 0;
    while (i < n && p[i] != ';') {
        unsigned char c = p[i++]; NSUInteger digit;
        if (c >= '0' && c <= '9') digit = c-'0';
        else if (c >= 'a' && c <= 'f') digit = c-'a'+10;
        else if (c >= 'A' && c <= 'F') digit = c-'A'+10;
        else return ORLFail(error, ORLHTTPInvalidResponse, @"invalid_chunk_size");
        if (value > ORLResponseLimit/16 || value*16 > ORLResponseLimit-digit)
            return ORLFail(error, ORLHTTPSizeLimit, @"response_too_large");
        value = value*16+digit;
    }
    if (!i || p[0] == ';') return ORLFail(error, ORLHTTPInvalidResponse, @"invalid_chunk_size");
    while (i < n) {
        if (p[i++] != ';') return ORLFail(error, ORLHTTPInvalidResponse, @"invalid_chunk_extension");
        while (i<n && (p[i]==' ' || p[i]=='\t')) i++;
        NSUInteger start = i; while (i<n && ORLTokenByte(p[i])) i++;
        if (i==start) return ORLFail(error, ORLHTTPInvalidResponse, @"invalid_chunk_extension");
        while (i<n && (p[i]==' ' || p[i]=='\t')) i++;
        if (i<n && p[i]=='=') {
            i++; while (i<n && (p[i]==' ' || p[i]=='\t')) i++;
            if (i<n && p[i]=='"') {
                i++; BOOL closed = NO;
                while (i<n) {
                    unsigned char c=p[i++];
                    if (c=='"') { closed=YES;break; }
                    if (c=='\\') {
                        if (i==n) return ORLFail(error, ORLHTTPInvalidResponse, @"invalid_chunk_extension");
                        c=p[i++];
                    }
                    if ((c<32 && c!='\t') || c==127)
                        return ORLFail(error, ORLHTTPInvalidResponse, @"invalid_chunk_extension");
                }
                if (!closed) return ORLFail(error, ORLHTTPInvalidResponse, @"invalid_chunk_extension");
            } else {
                start=i;while(i<n && ORLTokenByte(p[i]))i++;
                if(i==start)return ORLFail(error, ORLHTTPInvalidResponse, @"invalid_chunk_extension");
            }
            while(i<n && (p[i]==' '||p[i]=='\t'))i++;
        }
        if(i<n && p[i]!=';')return ORLFail(error, ORLHTTPInvalidResponse, @"invalid_chunk_extension");
    }
    *size=value;return YES;
}
static BOOL ORLTrailers(ORLHTTPReader *reader, NSUInteger *budget, NSError **error) {
    NSSet *forbidden=[NSSet setWithArray:@[@"content-length",@"transfer-encoding",@"content-encoding",
        @"content-type",@"authorization",@"cookie",@"set-cookie",@"host",@"connection",
        @"location",@"trailer",@"proxy-authenticate",@"proxy-authorization"]];
    NSUInteger count=0;
    for (;;) {
        NSData *line=[reader line:ORLLineLimit error:error];if(!line)return NO;
        *budget+=line.length+2;
        if(*budget>ORLHeaderLimit || ++count>256)return ORLFail(error,ORLHTTPSizeLimit,@"trailers_too_large");
        if(!line.length)return YES;
        NSString *name=nil,*value=nil;if(!ORLField(line,&name,&value,error))return NO;
        if([forbidden containsObject:name])return ORLFail(error,ORLHTTPInvalidResponse,@"unsafe_trailer");
    }
}
static NSData *ORLGunzip(NSData *data, double deadline, BOOL (^cancelled)(void), NSError **error) {
    z_stream stream;memset(&stream,0,sizeof(stream));
    if(inflateInit2(&stream,15+16)!=Z_OK){ORLFail(error,ORLHTTPUnsupportedEncoding,@"gzip_failed");return nil;}
    NSMutableData *result=[NSMutableData data];stream.next_in=(Bytef *)data.bytes;stream.avail_in=(uInt)data.length;
    BOOL ok=NO;
    for (;;) {
        if (!ORLAlive(deadline,cancelled,error)) break;
        unsigned char buffer[8192];stream.next_out=buffer;stream.avail_out=sizeof(buffer);
        int code=inflate(&stream,Z_NO_FLUSH);NSUInteger n=sizeof(buffer)-stream.avail_out;
        if(n>ORLResponseLimit-result.length){ORLFail(error,ORLHTTPSizeLimit,@"decoded_response_too_large");break;}
        [result appendBytes:buffer length:n];
        if(code==Z_STREAM_END){if(stream.avail_in==0)ok=YES;else ORLFail(error,ORLHTTPInvalidResponse,@"gzip_trailing_data");break;}
        if(code!=Z_OK || (!stream.avail_in && stream.avail_out==sizeof(buffer))){
            ORLFail(error,ORLHTTPInvalidResponse,@"invalid_gzip");break;
        }
    }
    inflateEnd(&stream);return ok?result:nil;
}
static NSDictionary *ORLParse(ORLHTTPReader *reader, NSString *method, double deadline, BOOL (^cancelled)(void), NSError **error) {
    NSUInteger headerBytes=0;NSDictionary *head=nil;
    for(NSUInteger interim=0;interim<=8;interim++){
        if (!ORLAlive(deadline,cancelled,error)) return nil;
        head=ORLHead(reader,&headerBytes,error);if(!head)return nil;
        NSInteger status=[head[@"status"] integerValue];
        if(status>=200)break;
        if(status==101){ORLFail(error,ORLHTTPInvalidResponse,@"upgrade_not_supported");return nil;}
        if(interim==8){ORLFail(error,ORLHTTPInvalidResponse,@"too_many_informational");return nil;}
        NSDictionary *headers=head[@"headers"];
        if(headers[@"content-length"] || headers[@"transfer-encoding"]){
            ORLFail(error,ORLHTTPInvalidResponse,@"informational_body");return nil;
        }
    }
    NSMutableDictionary *headers=[NSMutableDictionary dictionaryWithDictionary:head[@"headers"]];
    NSInteger status=[head[@"status"] integerValue];BOOL noBody=[method isEqualToString:@"HEAD"] || status==204 || status==304;
    NSString *transfer=headers[@"transfer-encoding"],*length=headers[@"content-length"];
    NSUInteger count=0;
    if(length && !ORLDecimal(length,noBody?NSUIntegerMax:ORLResponseLimit,&count)){
        ORLFail(error,ORLHTTPInvalidResponse,@"invalid_content_length");return nil;
    }
    if(transfer && ![[transfer lowercaseString] isEqualToString:@"chunked"]){
        ORLFail(error,ORLHTTPUnsupportedEncoding,@"transfer_encoding_not_supported");return nil;
    }
    if(status==204 && (transfer || (length && count!=0))){
        ORLFail(error,ORLHTTPInvalidResponse,@"invalid_no_content_framing");return nil;
    }
    NSMutableData *body=[NSMutableData data];
    if(!noBody){
        if(transfer){
            NSUInteger metadata=0;
            for(;;){
                if (!ORLAlive(deadline,cancelled,error)) return nil;
                NSData *line=[reader line:4096 error:error];if(!line)return nil;
                metadata+=line.length+2;
                if(metadata>ORLHeaderLimit){ORLFail(error,ORLHTTPSizeLimit,@"chunk_metadata_too_large");return nil;}
                NSUInteger chunk=0;if(!ORLChunkSize(line,&chunk,error))return nil;
                if(!chunk){if(!ORLTrailers(reader,&headerBytes,error))return nil;break;}
                if(![reader take:chunk into:body error:error])return nil;
                NSMutableData *ending=[NSMutableData data];
                if(![reader take:2 into:ending error:error])return nil;
                metadata+=2;
                if(metadata>ORLHeaderLimit){ORLFail(error,ORLHTTPSizeLimit,@"chunk_metadata_too_large");return nil;}
                const unsigned char *p=ending.bytes;
                if(p[0]!='\r'||p[1]!='\n'){ORLFail(error,ORLHTTPInvalidResponse,@"invalid_chunk_ending");return nil;}
            }
        }else if(length){if(![reader take:count into:body error:error])return nil;}
        else if(![reader untilEOF:body error:error])return nil;
    }
    if(reader.remaining){ORLFail(error,ORLHTTPInvalidResponse,@"unexpected_response_data");return nil;}
    if(status==205 && body.length){ORLFail(error,ORLHTTPInvalidResponse,@"reset_content_has_body");return nil;}
    NSData *decoded=body;
    NSString *encoding=headers[@"content-encoding"];
    if(!noBody && encoding && ![[encoding lowercaseString] isEqualToString:@"identity"]){
        if(![[encoding lowercaseString] isEqualToString:@"gzip"]){
            ORLFail(error,ORLHTTPUnsupportedEncoding,@"content_encoding_not_supported");return nil;
        }
        decoded=ORLGunzip(body,deadline,cancelled,error);if(!decoded)return nil;
        [headers removeObjectForKey:@"content-encoding"];
        for(NSString *digest in @[@"content-md5",@"digest",@"content-digest",@"repr-digest"])
            [headers removeObjectForKey:digest];
    }
    NSMutableSet *hop=[NSMutableSet setWithArray:@[@"connection",@"keep-alive",@"proxy-connection",
        @"transfer-encoding",@"te",@"trailer",@"upgrade",@"proxy-authenticate",@"proxy-authorization"]];
    if(headers[@"connection"]){
        for(NSString *raw in [headers[@"connection"] componentsSeparatedByString:@","]){
            NSString *token=[ORLTrim(raw) lowercaseString];
            if(!ORLToken(token) || [@[@"content-length",@"content-encoding",@"location",@"set-cookie"] containsObject:token]){
                ORLFail(error,ORLHTTPInvalidResponse,@"invalid_connection_header");return nil;
            }
            [hop addObject:token];
        }
    }
    for(NSString *name in hop)[headers removeObjectForKey:name];
    if(!noBody)headers[@"content-length"]=[NSString stringWithFormat:@"%lu",(unsigned long)decoded.length];
    NSMutableDictionary *canonical=[NSMutableDictionary dictionary];
    for(NSString *name in headers)canonical[ORLHeaderName(name)]=headers[name];
    return @{@"status":head[@"status"],@"headers":canonical,@"setCookies":head[@"setCookies"],@"data":decoded};
}

@interface ORLResolution : NSObject {
@public BOOL finished; CFStreamError error;
}
@end
@implementation ORLResolution
@end
static const void *ORLRetainContext(const void *value) { return [(id)value retain]; }
static void ORLReleaseContext(const void *value) { [(id)value release]; }
static void ORLResolved(CFHostRef host, CFHostInfoType type, const CFStreamError *error, void *info) {
    (void)host; (void)type;
    ORLResolution *result=(ORLResolution *)info;
    if(error)result->error=*error;
    result->finished=YES;
}
static NSArray *ORLAddresses(NSString *name,double deadline,BOOL (^cancelled)(void),NSError **error) {
    CFHostRef host=CFHostCreateWithName(kCFAllocatorDefault,(CFStringRef)name);
    if(!host){ORLFail(error,ORLHTTPDNSFailure,@"dns_failed");return nil;}
    ORLResolution *result=[ORLResolution new];
    CFHostClientContext context={0,result,ORLRetainContext,ORLReleaseContext,NULL};
    BOOL scheduled=NO;NSArray *addresses=nil;
    @try {
        if(!CFHostSetClient(host,ORLResolved,&context)){
            ORLFail(error,ORLHTTPDNSFailure,@"dns_failed");
        }else{
            CFHostScheduleWithRunLoop(host,CFRunLoopGetCurrent(),kCFRunLoopDefaultMode);scheduled=YES;
            CFStreamError immediate={0,0};
            if(!CFHostStartInfoResolution(host,kCFHostAddresses,&immediate)){
                ORLFail(error,ORLHTTPDNSFailure,@"dns_failed");
            }else{
                BOOL alive=YES;
                while(!result->finished && (alive=ORLAlive(deadline,cancelled,error)))
                    CFRunLoopRunInMode(kCFRunLoopDefaultMode,0.05,true);
                if(alive && result->finished && !result->error.error){
                    Boolean resolved=false;
                    CFArrayRef raw=CFHostGetAddressing(host,&resolved);
                    if(resolved && raw && CFArrayGetCount(raw)>0 && CFArrayGetCount(raw)<=64)
                        addresses=[[(NSArray *)raw copy] autorelease];
                }
                if(!addresses && alive)ORLFail(error,ORLHTTPDNSFailure,@"dns_failed");
            }
        }
    } @finally {
        CFHostCancelInfoResolution(host,kCFHostAddresses);
        if(scheduled)CFHostUnscheduleFromRunLoop(host,CFRunLoopGetCurrent(),kCFRunLoopDefaultMode);
        CFHostSetClient(host,NULL,NULL);
        CFRelease(host);[result release];
    }
    return addresses;
}
static int ORLWait(int fd,BOOL writing,double until,BOOL (^cancelled)(void),NSError **error) {
    if(fd<0 || fd>=FD_SETSIZE){ORLFail(error,ORLHTTPIOFailure,@"socket_failed");return -1;}
    for(;;){
        if(!ORLAlive(until,cancelled,error))return -1;
        fd_set ready;FD_ZERO(&ready);FD_SET(fd,&ready);
        double remaining=until-ORLNow();
        if(remaining<=0){ORLFail(error,ORLHTTPTimeout,@"timeout");return -1;}
        double delay=MIN(0.1,remaining);
        struct timeval timeout={(time_t)delay,(suseconds_t)((delay-floor(delay))*1000000.0)};
        int result=select(fd+1,writing?NULL:&ready,writing?&ready:NULL,NULL,&timeout);
        if(result>0)return 1;
        if(result==0)continue;
        if(errno==EINTR)continue;
        ORLFail(error,ORLHTTPIOFailure,@"socket_failed");return -1;
    }
}
static int ORLConnect(NSArray *addresses,NSUInteger port,double deadline,BOOL (^cancelled)(void),NSError **error) {
    NSUInteger tries=0;
    for(id item in addresses){
        if(!ORLAlive(deadline,cancelled,error))return -1;
        if(++tries>16)break;
        if(![item isKindOfClass:[NSData class]] || [item length]<sizeof(struct sockaddr) ||
            [item length]>sizeof(struct sockaddr_storage))continue;
        struct sockaddr_storage storage;memset(&storage,0,sizeof(storage));
        memcpy(&storage,[item bytes],[item length]);
        struct sockaddr *address=(struct sockaddr *)&storage;socklen_t length=0;
        if(address->sa_family==AF_INET && [item length]>=sizeof(struct sockaddr_in)){
            ((struct sockaddr_in *)&storage)->sin_port=htons((uint16_t)port);length=sizeof(struct sockaddr_in);
        }else if(address->sa_family==AF_INET6 && [item length]>=sizeof(struct sockaddr_in6)){
            ((struct sockaddr_in6 *)&storage)->sin6_port=htons((uint16_t)port);length=sizeof(struct sockaddr_in6);
        }else continue;
        int fd=socket(address->sa_family,SOCK_STREAM,IPPROTO_TCP);if(fd<0)continue;
        BOOL connected=NO;
        @try{
        int flags=fcntl(fd,F_GETFL,0),one=1;
        if(flags>=0 && fcntl(fd,F_SETFL,flags|O_NONBLOCK)==0 &&
            fcntl(fd,F_SETFD,FD_CLOEXEC)==0 &&
            setsockopt(fd,SOL_SOCKET,SO_NOSIGPIPE,&one,sizeof(one))==0){
            int code=connect(fd,address,length);
            if(code==0)connected=YES;
            else if(errno==EINPROGRESS || errno==EWOULDBLOCK || errno==EINTR){
                NSError *waitError=nil;double addressDeadline=MIN(deadline,ORLNow()+1.5);
                if(ORLWait(fd,YES,addressDeadline,cancelled,&waitError)>0){
                    int issue=0;socklen_t size=sizeof(issue);
                    connected=getsockopt(fd,SOL_SOCKET,SO_ERROR,&issue,&size)==0 && issue==0;
                }else if(waitError.code==ORLHTTPCancelled || ORLNow()>=deadline){
                    if(error)*error=waitError;return -1;
                }
            }
        }
        if(connected)return fd;
        }@finally{if(!connected)close(fd);}
    }
    ORLFail(error,ORLHTTPConnectFailure,@"connect_failed");return -1;
}
typedef struct {
    int fd;
    double deadline;
    BOOL (^cancelled)(void);
    ORLHTTPErrorCode issue;
    BOOL eofSeen;
} ORLSocket;
static BOOL ORLSocketAlive(ORLSocket *socket) {
    @try{
        if(socket->cancelled && socket->cancelled()){socket->issue=ORLHTTPCancelled;return NO;}
    }@catch(NSException *exception){
        (void)exception;socket->issue=ORLHTTPInvalidRequest;return NO;
    }
    if(ORLNow()>=socket->deadline){socket->issue=ORLHTTPTimeout;return NO;}
    return YES;
}
static int ORLSend(void *context,const unsigned char *bytes,size_t length) {
    ORLSocket *s=context;
    if(!ORLSocketAlive(s))return MBEDTLS_ERR_NET_SEND_FAILED;
    ssize_t result=send(s->fd,bytes,length,0);
    if(result>=0)return (int)result;
    if(errno==EAGAIN || errno==EWOULDBLOCK || errno==EINTR)return MBEDTLS_ERR_SSL_WANT_WRITE;
    return MBEDTLS_ERR_NET_SEND_FAILED;
}
static int ORLReceive(void *context,unsigned char *bytes,size_t length) {
    ORLSocket *s=context;
    if(!ORLSocketAlive(s))return MBEDTLS_ERR_NET_RECV_FAILED;
    ssize_t result=recv(s->fd,bytes,length,0);
    if(!result)s->eofSeen=YES;
    if(result>=0)return (int)result;
    if(errno==EAGAIN || errno==EWOULDBLOCK || errno==EINTR)return MBEDTLS_ERR_SSL_WANT_READ;
    return MBEDTLS_ERR_NET_RECV_FAILED;
}
static BOOL ORLTLSWait(int code,ORLSocket *socket,NSError **error) {
    if(socket->issue==ORLHTTPInvalidRequest)return ORLFail(error,ORLHTTPInvalidRequest,@"request_failed");
    if(socket->issue==ORLHTTPCancelled)return ORLFail(error,ORLHTTPCancelled,@"cancelled");
    if(socket->issue==ORLHTTPTimeout)return ORLFail(error,ORLHTTPTimeout,@"timeout");
    if(code!=MBEDTLS_ERR_SSL_WANT_READ && code!=MBEDTLS_ERR_SSL_WANT_WRITE)return NO;
    return ORLWait(socket->fd,code==MBEDTLS_ERR_SSL_WANT_WRITE,
                   socket->deadline,socket->cancelled,error)>0;
}
static NSData *ORLRoots(NSString *path,NSError **error) {
    if(![path isKindOfClass:[NSString class]] || !path.length || path.length>PATH_MAX){
        ORLFail(error,ORLHTTPInvalidRequest,@"invalid_roots");return nil;
    }
    int fd=open(path.fileSystemRepresentation,O_RDONLY|O_NOFOLLOW|O_NONBLOCK);
    if(fd<0){ORLFail(error,ORLHTTPCertificateFailure,@"roots_unavailable");return nil;}
    NSMutableData *data=[NSMutableData data];BOOL valid=YES;
    @try{
        struct stat st;
        if(fstat(fd,&st) || !S_ISREG(st.st_mode) || st.st_size<=0 || st.st_size>1024*1024){
            ORLFail(error,ORLHTTPCertificateFailure,@"invalid_roots");valid=NO;
        }else{
            for(;;){
                unsigned char bytes[8192];ssize_t n=read(fd,bytes,sizeof(bytes));
                if(n<0 && errno==EINTR)continue;
                if(n<0 || (n>0 && (NSUInteger)n>1024*1024-data.length)){
                    ORLFail(error,ORLHTTPCertificateFailure,@"invalid_roots");valid=NO;break;
                }
                if(!n)break;
                [data appendBytes:bytes length:(NSUInteger)n];
            }
            if(valid && data.length!=(NSUInteger)st.st_size){
                ORLFail(error,ORLHTTPCertificateFailure,@"roots_changed");valid=NO;
            }
        }
    }@finally{close(fd);}
    return valid?data:nil;
}
static NSDictionary *ORLNetwork(NSURLRequest *request,NSDictionary *prepared,NSString *CAFile,
    double deadline,BOOL (^cancelled)(void),NSError **error) {
    NSData *roots=ORLRoots(CAFile,error);if(!roots)return nil;
    NSArray *addresses=ORLAddresses([request.URL.host lowercaseString],deadline,cancelled,error);
    if(!addresses)return nil;
    if(!ORLAlive(deadline,cancelled,error))return nil;
    ORLSocket socket;memset(&socket,0,sizeof(socket));socket.fd=-1;
    socket.deadline=deadline;socket.cancelled=cancelled;
    mbedtls_ssl_context ssl;mbedtls_ssl_config conf;mbedtls_x509_crt ca;
    mbedtls_entropy_context entropy;mbedtls_ctr_drbg_context rng;
    mbedtls_ssl_init(&ssl);mbedtls_ssl_config_init(&conf);mbedtls_x509_crt_init(&ca);
    mbedtls_entropy_init(&entropy);mbedtls_ctr_drbg_init(&rng);
    NSDictionary *result=nil;
    @try{
        do{
            if(!ORLPSAReady){
                if(psa_crypto_init()!=PSA_SUCCESS){ORLFail(error,ORLHTTPTLSFailure,@"crypto_unavailable");break;}
                ORLPSAReady=YES;
            }
            const unsigned char personal[]="LegacyClient single HTTPS";
            if(mbedtls_ctr_drbg_seed(&rng,mbedtls_entropy_func,&entropy,personal,sizeof(personal)-1)!=0){
                ORLFail(error,ORLHTTPTLSFailure,@"entropy_failed");break;
            }
            NSMutableData *terminated=[NSMutableData dataWithData:roots];
            unsigned char zero=0;[terminated appendBytes:&zero length:1];
            BOOL pem=NO;const char *marker="-----BEGIN CERTIFICATE-----";size_t markerLength=strlen(marker);
            if(roots.length>=markerLength)for(NSUInteger i=0;i<=roots.length-markerLength;i++)
                if(!memcmp((const unsigned char *)roots.bytes+i,marker,markerLength)){pem=YES;break;}
            if(mbedtls_x509_crt_parse(&ca,pem?terminated.bytes:roots.bytes,pem?terminated.length:roots.length)!=0){
                ORLFail(error,ORLHTTPCertificateFailure,@"invalid_roots");break;
            }
            if(mbedtls_ssl_config_defaults(&conf,MBEDTLS_SSL_IS_CLIENT,MBEDTLS_SSL_TRANSPORT_STREAM,
                MBEDTLS_SSL_PRESET_DEFAULT)!=0){
                ORLFail(error,ORLHTTPTLSFailure,@"tls_configuration_failed");break;
            }
            mbedtls_ssl_conf_authmode(&conf,MBEDTLS_SSL_VERIFY_REQUIRED);
            mbedtls_ssl_conf_ca_chain(&conf,&ca,NULL);
            mbedtls_ssl_conf_rng(&conf,mbedtls_ctr_drbg_random,&rng);
            mbedtls_ssl_conf_min_tls_version(&conf,MBEDTLS_SSL_VERSION_TLS1_2);
            mbedtls_ssl_conf_max_tls_version(&conf,MBEDTLS_SSL_VERSION_TLS1_3);
#if defined(MBEDTLS_SSL_SESSION_TICKETS)
            mbedtls_ssl_conf_session_tickets(&conf,MBEDTLS_SSL_SESSION_TICKETS_DISABLED);
#endif
#if defined(MBEDTLS_SSL_RENEGOTIATION)
            mbedtls_ssl_conf_renegotiation(&conf,MBEDTLS_SSL_RENEGOTIATION_DISABLED);
#endif
            const char *alpn[]={"http/1.1",NULL};
            if(mbedtls_ssl_conf_alpn_protocols(&conf,alpn)!=0 ||
                mbedtls_ssl_setup(&ssl,&conf)!=0 ||
                mbedtls_ssl_set_hostname(&ssl,request.URL.host.UTF8String)!=0){
                ORLFail(error,ORLHTTPTLSFailure,@"tls_configuration_failed");break;
            }
            NSUInteger port=request.URL.port?[request.URL.port unsignedIntegerValue]:443;
            socket.fd=ORLConnect(addresses,port,deadline,cancelled,error);
            if(socket.fd<0)break;
            mbedtls_ssl_set_bio(&ssl,&socket,ORLSend,ORLReceive,NULL);
            int code=0;
            for(;;){
                if(!ORLAlive(deadline,cancelled,error)){code=-1;break;}
                code=mbedtls_ssl_handshake(&ssl);
                if(code==0)break;
                if(!ORLTLSWait(code,&socket,error))break;
            }
            if(code!=0){
                if(error && !*error){
                    BOOL certificate=mbedtls_ssl_get_verify_result(&ssl)!=0 ||
                        code==MBEDTLS_ERR_X509_CERT_VERIFY_FAILED;
                    ORLFail(error,certificate?ORLHTTPCertificateFailure:ORLHTTPTLSFailure,
                        certificate?@"certificate_rejected":@"tls_failed");
                }
                break;
            }
            if(mbedtls_ssl_get_verify_result(&ssl)!=0 || !mbedtls_ssl_get_peer_cert(&ssl)){
                ORLFail(error,ORLHTTPCertificateFailure,@"certificate_rejected");break;
            }
            NSData *wire=prepared[@"wire"];NSUInteger written=0;
            while(written<wire.length){
                if(!ORLAlive(deadline,cancelled,error)){code=-1;break;}
                code=mbedtls_ssl_write(&ssl,(const unsigned char *)wire.bytes+written,wire.length-written);
                if(code>0){written+=(NSUInteger)code;continue;}
                if(!ORLTLSWait(code,&socket,error))break;
            }
            if(written!=wire.length){
                if(error && !*error)ORLFail(error,ORLHTTPIOFailure,@"send_failed");
                break;
            }
            mbedtls_ssl_context *sslPtr=&ssl; ORLSocket *socketPtr=&socket;
            ORLReadBlock read=^NSInteger(unsigned char *bytes,NSUInteger capacity,NSError **readError){
                NSUInteger tickets=0;
                for(;;){
                    if(!ORLAlive(deadline,cancelled,readError))return -1;
                    int n=mbedtls_ssl_read(sslPtr,bytes,capacity);
                    if(n>0)return n;
                    if(n==MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY)return 0;
                    if(n==0){
                        if(socketPtr->eofSeen){ORLFail(readError,ORLHTTPIOFailure,@"tls_truncated");return -1;}
                        return 0;
                    }
                    if(n==MBEDTLS_ERR_SSL_RECEIVED_NEW_SESSION_TICKET && ++tickets<=32)continue;
                    if(ORLTLSWait(n,socketPtr,readError))continue;
                    if(readError && !*readError)ORLFail(readError,ORLHTTPIOFailure,@"receive_failed");
                    return -1;
                }
            };
            ORLHTTPReader *reader=[[ORLHTTPReader alloc] initWithRead:read];
            NSDictionary *parsed=nil;
            @try{parsed=[ORLParse(reader,prepared[@"method"],deadline,cancelled,error) retain];}
            @finally{[reader release];}
            [parsed autorelease];
            if(!parsed || !ORLAlive(deadline,cancelled,error))break;
            NSMutableDictionary *response=[NSMutableDictionary dictionaryWithDictionary:parsed];
            response[@"url"]=request.URL;
            response[@"preparedRequest"]=prepared[@"request"];
            response[@"tlsVersion"]=[NSString stringWithUTF8String:mbedtls_ssl_get_version(&ssl)];
            response[@"cipher"]=[NSString stringWithUTF8String:mbedtls_ssl_get_ciphersuite(&ssl)];
            response[@"certificateVerified"]=@YES;
            result=response;
        }while(0);
    }@finally{
        if(socket.fd>=0)close(socket.fd);
        mbedtls_ssl_free(&ssl);mbedtls_ssl_config_free(&conf);mbedtls_x509_crt_free(&ca);
        mbedtls_ctr_drbg_free(&rng);mbedtls_entropy_free(&entropy);
    }
    return result;
}
NSDictionary *ORLHTTPPerform(NSURLRequest *request,NSString *CAFile,NSSet *allowedHosts,
    BOOL (^cancelled)(void),NSError **error) {
    NSAutoreleasePool *pool=[NSAutoreleasePool new];NSError *failure=nil;NSDictionary *result=nil;
    BOOL locked=NO;
    NSURLRequest *fixed=nil;NSString *roots=nil;NSSet *hosts=nil;BOOL (^stop)(void)=nil;
    @try{
        if(![request isKindOfClass:[NSURLRequest class]]){
            ORLFail(&failure,ORLHTTPInvalidRequest,@"invalid_request");
        }else{
            // Snapshot mutable callers before any stream wait, DNS or I/O.
            fixed=[request copy];roots=[CAFile copy];hosts=[allowedHosts copy];stop=[cancelled copy];
            double seconds=fixed.timeoutInterval;
            if(!isfinite(seconds) || seconds<=0)seconds=30;
            double deadline=ORLNow()+MIN(45.0,MAX(1.0,seconds));
            if(ORLAlive(deadline,stop,&failure) && ORLValidateURL(fixed.URL,hosts,&failure)){
                NSDictionary *prepared=ORLPrepare(fixed,deadline,stop,&failure);
                if(prepared){
                    for(;;){
                        if(!ORLAlive(deadline,stop,&failure))break;
                        int code=pthread_mutex_trylock(&ORLLibraryLock);
                        if(!code){locked=YES;break;}
                        if(code!=EBUSY){ORLFail(&failure,ORLHTTPIOFailure,@"transport_busy");break;}
                        usleep(10000);
                    }
                    if(locked)result=ORLNetwork(fixed,prepared,roots,deadline,stop,&failure);
                }
            }
        }
    }@catch(NSException *exception){
        (void)exception;failure=ORLError(ORLHTTPInvalidRequest,@"request_failed");result=nil;
    }@finally{
        if(locked)pthread_mutex_unlock(&ORLLibraryLock);
        [fixed release];[roots release];[hosts release];[stop release];
    }
    [result retain];[failure retain];[pool drain];
    if(error)*error=[failure autorelease];else[failure release];
    return [result autorelease];
}
#if defined(ORL_HTTP_TESTING)
NSDictionary *ORLHTTPParseForTesting(NSArray *fragments,NSString *method,NSError **error) {
    __block NSUInteger index=0,offset=0;
    ORLHTTPReader *reader=[[[ORLHTTPReader alloc] initWithRead:
        ^NSInteger(unsigned char *bytes,NSUInteger capacity,NSError **readError){
            (void)readError;
            while(index<fragments.count){
                NSData *part=fragments[index];
                if(offset==part.length){index++;offset=0;continue;}
                NSUInteger n=MIN(capacity,part.length-offset);
                memcpy(bytes,(const unsigned char *)part.bytes+offset,n);offset+=n;return (NSInteger)n;
            }
            return 0;
        }]autorelease];
    return ORLParse(reader,method,ORLNow()+30,nil,error);
}
NSData *ORLHTTPRequestForTesting(NSURLRequest *request,NSError **error) {
    NSDictionary *prepared=ORLPrepare(request,ORLNow()+5,nil,error);
    return prepared[@"wire"];
}
#endif
