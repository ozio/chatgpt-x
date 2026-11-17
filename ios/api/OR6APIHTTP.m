#import "OR6APIHTTP.h"
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
#include <mbedtls/version.h>
#include <psa/crypto.h>
#if !defined(MBEDTLS_THREADING_C) || !defined(MBEDTLS_THREADING_PTHREAD)
#error Native API transport requires the matching threaded Mbed TLS build
#endif

NSString *const OR6APIHTTPErrorDomain=@"OR6APIHTTP";
static const NSUInteger N6HardLimit=64*1024*1024;
static const NSUInteger N6HeaderLimit=64*1024;
static const NSUInteger N6LineLimit=16*1024;
static const NSUInteger N6ResponseLimit=64*1024*1024;
static pthread_once_t N6ClockOnce=PTHREAD_ONCE_INIT;
static mach_timebase_info_data_t N6Scale;
static void N6ClockInit(void){mach_timebase_info(&N6Scale);}
static double N6Now(void){pthread_once(&N6ClockOnce,N6ClockInit);return ((double)mach_absolute_time()*N6Scale.numer/N6Scale.denom)/1e9;}
/* Descriptions are solely from this table, never Foundation/server exceptions. */
static NSError *N6Error(OR6APIHTTPError code){
    NSArray *names=@[@"invalid_request",@"cancelled",@"connect_timeout",@"idle_timeout",@"overall_timeout",@"dns_failure",@"tls_failure",@"certificate_failure",@"invalid_response",@"size_limit",@"io_failure",@"consumer_stopped"];
    if(code<1 || code>OR6APIHTTPConsumerStopped)code=OR6APIHTTPInvalidRequest;
    return [NSError errorWithDomain:OR6APIHTTPErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey:names[code-1]}];
}
static BOOL N6Fail(NSError **error,OR6APIHTTPError code,NSString *ignored){(void)ignored;if(error)*error=N6Error(code);return NO;}
typedef NS_ENUM(NSUInteger,N6Phase){
 N6Prepared,N6RootsStart,N6RootsEnd,N6DNSStart,N6DNSEnd,N6TLSSetupStart,N6RNGReady,N6CAStart,N6CAEnd,N6ConfigReady,N6TCPStart,N6TCPReady,N6TLSStart,N6TLSReady,N6HeadersWritten,N6RequestWritten,N6FirstByte,N6ResponseHeaders,N6FirstEncoded,N6FirstDecoded,N6ResponseComplete,N6Finished,N6PhaseCount
};
static NSString*const N6PhaseNames[]={@"requestPreparedMs",@"rootsReadStartedMs",@"rootsReadFinishedMs",@"dnsStartedMs",@"dnsFinishedMs",@"tlsSetupStartedMs",@"rngReadyMs",@"caParseStartedMs",@"caParseFinishedMs",@"tlsConfigReadyMs",@"tcpStartedMs",@"tcpConnectedMs",@"tlsHandshakeStartedMs",@"tlsHandshakeFinishedMs",@"requestHeadersWrittenMs",@"requestWrittenMs",@"firstResponseByteMs",@"responseHeadersMs",@"firstEncodedBodyMs",@"firstDecodedBodyMs",@"responseCompleteMs",@"finishedMs"};
/* One state per invocation. TLS, CA, entropy and DRBG contexts are never shared. */
typedef struct {
    double overall,connect,idle,lastProgress,started,phases[N6PhaseCount];
    BOOL connecting;
    BOOL (^cancelled)(void);
    NSUInteger requestLimit,encodedLimit,decodedLimit,sent,received,encoded,decoded,connections;
    BOOL collect,identityEncoding;NSUInteger responseEncoding,responseFraming;
    BOOL traceEnabled,traceTruncated;NSUInteger traceCount,socketWaitCalls,socketReadTimeouts;
    double socketWait,trace[128][6];
} N6State;
static void N6Trace(N6State*s,NSUInteger kind,double start,double end,NSInteger bytes,double wait,NSUInteger timeouts){
 if(!s->traceEnabled)return;if(s->traceCount>=128){s->traceTruncated=YES;return;}
 double*r=s->trace[s->traceCount++];r[0]=kind;r[1]=(start-s->started)*1000;r[2]=(end-s->started)*1000;r[3]=bytes;r[4]=wait*1000;r[5]=timeouts;
}
static NSDictionary*N6StreamTiming(N6State*s){
 NSMutableArray*rows=[NSMutableArray array];for(NSUInteger i=0;i<s->traceCount;i++){double*r=s->trace[i];[rows addObject:@[@(r[0]),@(r[1]),@(r[2]),@(r[3]),@(r[4]),@(r[5])]];}
 return @{@"rows":rows,@"truncated":@(s->traceTruncated),@"socketWaitMs":@(s->socketWait*1000),@"socketWaitCalls":@(s->socketWaitCalls),@"socketReadTimeouts":@(s->socketReadTimeouts)};
}
static void N6Mark(N6State*s,N6Phase phase){if(s->started>0&&!s->phases[phase])s->phases[phase]=N6Now();}
static NSDictionary*N6Timings(N6State*s){NSMutableDictionary*d=[NSMutableDictionary dictionary];for(NSUInteger n=0;n<N6PhaseCount;n++)if(s->phases[n])d[N6PhaseNames[n]]=@((s->phases[n]-s->started)*1000);return[[d copy]autorelease];}
static BOOL N6Alive(N6State *s,NSError **error){
    @try{if(s->cancelled && s->cancelled())return N6Fail(error,OR6APIHTTPCancelled,nil);}
    @catch(NSException *e){(void)e;return N6Fail(error,OR6APIHTTPInvalidRequest,nil);}
    double now=N6Now();
    if(now>=s->overall)return N6Fail(error,OR6APIHTTPOverallTimeout,nil);
    if(s->connecting && now>=s->connect)return N6Fail(error,OR6APIHTTPConnectTimeout,nil);
    if(!s->connecting && now-s->lastProgress>=s->idle)return N6Fail(error,OR6APIHTTPIdleTimeout,nil);
    return YES;
}
static double N6Deadline(N6State *s){return MIN(s->overall,s->connecting?s->connect:s->lastProgress+s->idle);}
static BOOL N6TokenByte(unsigned char c) {
    if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) return YES;
    switch (c) {
        case '!': case '#': case '$': case '%': case '&': case '\'': case '*':
        case '+': case '-': case '.': case '^': case '_': case 0x60: case '|': case '~': return YES;
        default: return NO;
    }
}
static BOOL N6Token(NSString *s) {
    NSData *b = [s dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:NO];
    if (!b.length) return NO;
    const unsigned char *p = b.bytes;
    for (NSUInteger i = 0; i < b.length; i++) if (!N6TokenByte(p[i])) return NO;
    return YES;
}
static BOOL N6HeaderValue(NSString *s) {
    NSData *b = [s dataUsingEncoding:NSISOLatin1StringEncoding allowLossyConversion:NO];
    if (!b && s.length) return NO;
    const unsigned char *p = b.bytes;
    for (NSUInteger i = 0; i < b.length; i++)
        if ((p[i] < 32 && p[i] != '\t') || p[i] == 127) return NO;
    return YES;
}
static NSString *N6Trim(NSString *s) {
    return [s stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" \t"]];
}
static NSString *N6HeaderName(NSString *lower) {
    NSMutableArray *parts = [NSMutableArray array];
    for (NSString *p in [lower componentsSeparatedByString:@"-"]) {
        if (!p.length) { [parts addObject:@""]; continue; }
        [parts addObject:[[[p substringToIndex:1] uppercaseString]
            stringByAppendingString:[p substringFromIndex:1]]];
    }
    return [parts componentsJoinedByString:@"-"];
}
static BOOL N6Decimal(NSString *s, NSUInteger bound, NSUInteger *value) {
    NSData *d = [s dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:NO];
    if (!d.length) return NO;
    const unsigned char *p = d.bytes; NSUInteger n = 0;
    for (NSUInteger i = 0; i < d.length; i++) {
        if (p[i] < '0' || p[i] > '9' || n > bound / 10) return NO;
        NSUInteger digit = p[i] - '0';
        if (digit > bound || n > (bound - digit) / 10) return NO;
        n = n * 10 + digit;
    }
    *value = n; return YES;
}
static NSString *N6Target(NSURL *url, NSError **error) {
    NSString *path = [(id)CFURLCopyPath((CFURLRef)url) autorelease];
    NSString *query = [(id)CFURLCopyQueryString((CFURLRef)url, NULL) autorelease];
    if (!path.length) path = @"/";
    if(path.length>N6LineLimit || query.length>N6LineLimit ||
        path.length+query.length+(query?1:0)>N6LineLimit){
        N6Fail(error,OR6APIHTTPInvalidRequest,@"invalid_target");return nil;
    }
    if (![path hasPrefix:@"/"]) { N6Fail(error, OR6APIHTTPInvalidRequest, @"invalid_target"); return nil; }
    NSString *target = query ? [path stringByAppendingFormat:@"?%@", query] : path;
    NSData *ascii = [target dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:NO];
    if (!ascii || ascii.length > N6LineLimit) {
        N6Fail(error, OR6APIHTTPInvalidRequest, @"invalid_target"); return nil;
    }
    const unsigned char *p = ascii.bytes;
    for (NSUInteger i = 0; i < ascii.length; i++) {
        if (p[i] <= 32 || p[i] >= 127 || p[i] == '#' || p[i] == '\\') {
            N6Fail(error, OR6APIHTTPInvalidRequest, @"invalid_target"); return nil;
        }
        if (p[i] == '%') {
            if (i + 2 >= ascii.length) {
                N6Fail(error, OR6APIHTTPInvalidRequest, @"invalid_escape"); return nil;
            }
            for (NSUInteger j = 1; j <= 2; j++) {
                unsigned char c = p[i+j];
                if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'))) {
                    N6Fail(error, OR6APIHTTPInvalidRequest, @"invalid_escape"); return nil;
                }
            }
            i += 2;
        }
    }
    return target;
}
static BOOL N6ValidateURL(NSURL *url, NSSet *allowedHosts, NSError **error) {
    if (![url isKindOfClass:[NSURL class]] || ![[url.scheme lowercaseString] isEqualToString:@"https"] ||
        url.user || url.password || url.fragment || ![allowedHosts isKindOfClass:[NSSet class]]) {
        return N6Fail(error, OR6APIHTTPInvalidRequest, @"destination_not_allowed");
    }
    NSString *rawHost=url.host;
    if(!rawHost.length || rawHost.length>253)
        return N6Fail(error,OR6APIHTTPInvalidRequest,@"invalid_host");
    NSString *host=[rawHost lowercaseString];
    NSData *ascii=[host dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:NO];
    if(!ascii || [host rangeOfCharacterFromSet:
        [[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789.-"] invertedSet]].location!=NSNotFound)
        return N6Fail(error,OR6APIHTTPInvalidRequest,@"invalid_host");
    for(NSString *label in [host componentsSeparatedByString:@"."])
        if(!label.length || label.length>63 || [label hasPrefix:@"-"] || [label hasSuffix:@"-"])
            return N6Fail(error,OR6APIHTTPInvalidRequest,@"invalid_host");
    if(![allowedHosts containsObject:host])
        return N6Fail(error,OR6APIHTTPInvalidRequest,@"destination_not_allowed");
    NSNumber *port=url.port;
#if defined(OR6_API_HTTP_TESTING)
    if(port && (port.longLongValue<1 || port.longLongValue>65535 || (port.integerValue!=443 && ![host isEqualToString:@"localhost"] && ![host isEqualToString:@"127.0.0.1"])))
#else
    if(port && port.longLongValue!=443)
#endif
        return N6Fail(error,OR6APIHTTPInvalidRequest,@"port_not_allowed");
    return N6Target(url,error)!=nil;
}

static NSDictionary *N6Prepare(NSURLRequest *request,N6State *state,NSError **error){
    NSString *method=request.HTTPMethod?:@"GET";
    if(![@[@"GET",@"HEAD",@"POST",@"PUT",@"PATCH",@"DELETE",@"OPTIONS"] containsObject:method]){
        N6Fail(error,OR6APIHTTPInvalidRequest,nil);return nil;
    }
    NSString *target=N6Target(request.URL,error);if(!target)return nil;
    NSData *body=request.HTTPBody;NSInputStream *stream=request.HTTPBodyStream;
    if((body && stream) || (body && ![body isKindOfClass:[NSData class]]) ||
        (stream && ![stream isKindOfClass:[NSInputStream class]])){
        N6Fail(error,OR6APIHTTPInvalidRequest,nil);return nil;
    }
    if(body.length>state->requestLimit){N6Fail(error,OR6APIHTTPSizeLimit,nil);return nil;}
    NSDictionary *source=request.allHTTPHeaderFields?:@{};
    if(![source isKindOfClass:[NSDictionary class]] || source.count>256){N6Fail(error,OR6APIHTTPSizeLimit,nil);return nil;}
    NSMutableDictionary *headers=[NSMutableDictionary dictionary];NSUInteger budget=0;
    for(id key in source){
        id value=source[key];
        if(![key isKindOfClass:[NSString class]] || ![value isKindOfClass:[NSString class]] || !N6Token(key) || !N6HeaderValue(value)){
            N6Fail(error,OR6APIHTTPInvalidRequest,nil);return nil;
        }
        if([key length]>N6HeaderLimit || [value length]>N6HeaderLimit || [key length]+[value length]+4>N6HeaderLimit-budget){
            N6Fail(error,OR6APIHTTPSizeLimit,nil);return nil;
        }
        budget+=[key length]+[value length]+4;NSString *lower=[key lowercaseString];
        if(headers[lower]){N6Fail(error,OR6APIHTTPInvalidRequest,nil);return nil;}headers[lower]=value;
    }
    NSString *host=[request.URL.host lowercaseString],*authority=host;
#if defined(OR6_API_HTTP_TESTING)
    if(request.URL.port && request.URL.port.integerValue!=443)authority=[host stringByAppendingFormat:@":%@",request.URL.port];
#endif
    if(headers[@"host"] && ![[headers[@"host"] lowercaseString] isEqualToString:authority] &&
        ![[headers[@"host"] lowercaseString] isEqualToString:[host stringByAppendingString:@":443"]]){
        N6Fail(error,OR6APIHTTPInvalidRequest,nil);return nil;
    }
    for(NSString *bad in @[@"transfer-encoding",@"te",@"trailer",@"upgrade",@"expect",@"proxy-authorization"])
        if(headers[bad]){N6Fail(error,OR6APIHTTPInvalidRequest,nil);return nil;}
    NSUInteger length=body.length;
    if(stream && !headers[@"content-length"]){N6Fail(error,OR6APIHTTPInvalidRequest,nil);return nil;}
    if(headers[@"content-length"]){
        if(!N6Decimal(N6Trim(headers[@"content-length"]),state->requestLimit,&length) || (!stream && length!=body.length)){
            N6Fail(error,OR6APIHTTPInvalidRequest,nil);return nil;
        }
    }
    for(NSString *omit in @[@"host",@"connection",@"proxy-connection",@"keep-alive",@"accept-encoding",@"content-length"])[headers removeObjectForKey:omit];
    headers[@"host"]=authority;headers[@"connection"]=@"close";headers[@"accept-encoding"]=state->identityEncoding?@"identity":@"gzip";
    if(!headers[@"user-agent"])headers[@"user-agent"]=@"LegacyClient/0.1 (iOS 6)";
    if(length || stream || [@[@"POST",@"PUT",@"PATCH"] containsObject:method])headers[@"content-length"]=[NSString stringWithFormat:@"%lu",(unsigned long)length];
    NSMutableString *head=[NSMutableString stringWithFormat:@"%@ %@ HTTP/1.1\r\n",method,target];
    for(NSString *key in [[headers allKeys] sortedArrayUsingSelector:@selector(compare:)])[head appendFormat:@"%@: %@\r\n",N6HeaderName(key),headers[key]];
    [head appendString:@"\r\n"];NSData *wire=[head dataUsingEncoding:NSISOLatin1StringEncoding allowLossyConversion:NO];
    if(!wire || wire.length>N6HeaderLimit || wire.length>state->requestLimit || length>state->requestLimit-wire.length){
        N6Fail(error,OR6APIHTTPSizeLimit,nil);return nil;
    }
    /* No duplicate body/wire aggregate. A body stream requires an exact length. */
    return @{@"head":wire,@"method":method,@"length":@(length)};
}
typedef NSInteger (^N6ReadBlock)(unsigned char *,NSUInteger,NSError **);
typedef BOOL (^N6Sink)(const unsigned char *,NSUInteger,NSError **);
@interface N6Reader:NSObject{
    NSMutableData *_buffer;NSUInteger _offset,_wire,_limit;BOOL _eof;N6ReadBlock _read;
}
- (id)initWithRead:(N6ReadBlock)read limit:(NSUInteger)limit;
- (NSData *)line:(NSUInteger)limit error:(NSError **)error;
- (BOOL)take:(NSUInteger)count sink:(N6Sink)sink error:(NSError **)error;
- (BOOL)untilEOF:(N6Sink)sink error:(NSError **)error;
- (NSUInteger)remaining;
@end
@implementation N6Reader
- (id)initWithRead:(N6ReadBlock)read limit:(NSUInteger)limit{if((self=[super init])){_buffer=[NSMutableData new];_read=[read copy];_limit=limit;}return self;}
- (NSUInteger)remaining{return _buffer.length-_offset;}
- (BOOL)fill:(NSError **)error{
    if(_eof)return YES;
    if(_offset){[_buffer replaceBytesInRange:NSMakeRange(0,_offset) withBytes:NULL length:0];_offset=0;}
    unsigned char bytes[8192];NSInteger n=_read(bytes,sizeof(bytes),error);if(n<0)return NO;
    if((NSUInteger)n>sizeof(bytes))return N6Fail(error,OR6APIHTTPInvalidResponse,nil);
    if((NSUInteger)n>_limit-_wire)return N6Fail(error,OR6APIHTTPSizeLimit,nil);_wire+=(NSUInteger)n;
    if(!n)_eof=YES;else [_buffer appendBytes:bytes length:(NSUInteger)n];return YES;
}
- (NSData *)line:(NSUInteger)limit error:(NSError **)error{
    for(;;){
        const unsigned char *p=_buffer.bytes;NSUInteger n=self.remaining;
        for(NSUInteger i=0;i<n;i++)if(p[_offset+i]=='\n'){
            if(!i || p[_offset+i-1]!='\r'){N6Fail(error,OR6APIHTTPInvalidResponse,nil);return nil;}
            if(i-1>limit){N6Fail(error,OR6APIHTTPSizeLimit,nil);return nil;}
            NSData *line=[_buffer subdataWithRange:NSMakeRange(_offset,i-1)];_offset+=i+1;return line;
        }
        if(n>limit+1){N6Fail(error,OR6APIHTTPSizeLimit,nil);return nil;}
        if(_eof){N6Fail(error,OR6APIHTTPInvalidResponse,nil);return nil;}
        if(![self fill:error])return nil;
    }
}
- (BOOL)take:(NSUInteger)count sink:(N6Sink)sink error:(NSError **)error{
    while(count){
        if(!self.remaining){if(_eof)return N6Fail(error,OR6APIHTTPInvalidResponse,nil);if(![self fill:error])return NO;continue;}
        NSUInteger n=MIN(count,self.remaining);
        if(sink && !sink((const unsigned char *)_buffer.bytes+_offset,n,error))return NO;
        _offset+=n;count-=n;
    }return YES;
}
- (BOOL)untilEOF:(N6Sink)sink error:(NSError **)error{
    for(;;){NSUInteger n=self.remaining;if(n && ![self take:n sink:sink error:error])return NO;if(_eof)return YES;if(![self fill:error])return NO;}
}
- (void)dealloc{[_read release];[_buffer release];[super dealloc];}
@end

static BOOL N6Field(NSData *line, NSString **name, NSString **value, NSError **error) {
    const unsigned char *p = line.bytes; NSUInteger n = line.length, colon = NSNotFound;
    if (!n || p[0] == ' ' || p[0] == '\t')
        return N6Fail(error, OR6APIHTTPInvalidResponse, @"folded_header");
    for (NSUInteger i = 0; i < n; i++) {
        if (p[i] == ':') { colon = i; break; }
        if (!N6TokenByte(p[i])) return N6Fail(error, OR6APIHTTPInvalidResponse, @"invalid_header_name");
    }
    if (colon == NSNotFound || !colon)
        return N6Fail(error, OR6APIHTTPInvalidResponse, @"invalid_header_name");
    NSString *key = [[[NSString alloc] initWithBytes:p length:colon encoding:NSASCIIStringEncoding] autorelease];
    NSString *text = [[[NSString alloc] initWithBytes:p+colon+1 length:n-colon-1
        encoding:NSISOLatin1StringEncoding] autorelease];
    if (!text || !N6HeaderValue(text))
        return N6Fail(error, OR6APIHTTPInvalidResponse, @"invalid_header_value");
    *name = [key lowercaseString]; *value = N6Trim(text); return YES;
}
static NSDictionary *N6Head(N6Reader *reader, NSUInteger *headerBytes, NSError **error) {
    NSData *line = [reader line:N6LineLimit error:error];
    if (!line) return nil;
    *headerBytes += line.length+2;
    const unsigned char *p = line.bytes;
    if (line.length < 12 ||
        (memcmp(p,"HTTP/1.1 ",9) && memcmp(p,"HTTP/1.0 ",9)) ||
        p[9] < '1' || p[9] > '5' || p[10] < '0' || p[10] > '9' ||
        p[11] < '0' || p[11] > '9' || (line.length > 12 && p[12] != ' ')) {
        N6Fail(error, OR6APIHTTPInvalidResponse, @"invalid_status"); return nil;
    }
    for (NSUInteger i = 0; i < line.length; i++)
        if ((p[i] < 32 && p[i] != '\t') || p[i] == 127) {
            N6Fail(error, OR6APIHTTPInvalidResponse, @"invalid_status"); return nil;
        }
    NSInteger status = (p[9]-'0')*100+(p[10]-'0')*10+p[11]-'0';
    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    NSMutableArray *cookies = [NSMutableArray array];
    NSSet *singles = [NSSet setWithArray:@[@"content-length",@"transfer-encoding",
        @"content-encoding",@"location",@"host"]];
    NSUInteger count = 0;
    for (;;) {
        line = [reader line:N6LineLimit error:error];
        if (!line) return nil;
        *headerBytes += line.length+2;
        if (*headerBytes > N6HeaderLimit || (line.length && ++count > 256)) {
            N6Fail(error, OR6APIHTTPSizeLimit, @"headers_too_large"); return nil;
        }
        if (!line.length) break;
        NSString *name = nil, *value = nil;
        if (!N6Field(line, &name, &value, error)) return nil;
        if ([name isEqualToString:@"set-cookie"]) { [cookies addObject:value]; continue; }
        if (headers[name] && [singles containsObject:name]) {
            N6Fail(error, OR6APIHTTPInvalidResponse, @"ambiguous_header"); return nil;
        }
        headers[name] = headers[name] ? [headers[name] stringByAppendingFormat:@", %@",value] : value;
    }
    if (headers[@"content-length"] && headers[@"transfer-encoding"]) {
        N6Fail(error, OR6APIHTTPInvalidResponse, @"ambiguous_framing"); return nil;
    }
    return @{@"status":@(status), @"headers":headers, @"setCookies":cookies};
}
static BOOL N6ChunkSize(NSData *line, NSUInteger *size, NSError **error) {
    const unsigned char *p = line.bytes; NSUInteger i = 0, n = line.length, value = 0;
    while (i < n && p[i] != ';') {
        unsigned char c = p[i++]; NSUInteger digit;
        if (c >= '0' && c <= '9') digit = c-'0';
        else if (c >= 'a' && c <= 'f') digit = c-'a'+10;
        else if (c >= 'A' && c <= 'F') digit = c-'A'+10;
        else return N6Fail(error, OR6APIHTTPInvalidResponse, @"invalid_chunk_size");
        if (value > N6ResponseLimit/16 || value*16 > N6ResponseLimit-digit)
            return N6Fail(error, OR6APIHTTPSizeLimit, @"response_too_large");
        value = value*16+digit;
    }
    if (!i || p[0] == ';') return N6Fail(error, OR6APIHTTPInvalidResponse, @"invalid_chunk_size");
    while (i < n) {
        if (p[i++] != ';') return N6Fail(error, OR6APIHTTPInvalidResponse, @"invalid_chunk_extension");
        while (i<n && (p[i]==' ' || p[i]=='\t')) i++;
        NSUInteger start = i; while (i<n && N6TokenByte(p[i])) i++;
        if (i==start) return N6Fail(error, OR6APIHTTPInvalidResponse, @"invalid_chunk_extension");
        while (i<n && (p[i]==' ' || p[i]=='\t')) i++;
        if (i<n && p[i]=='=') {
            i++; while (i<n && (p[i]==' ' || p[i]=='\t')) i++;
            if (i<n && p[i]=='"') {
                i++; BOOL closed = NO;
                while (i<n) {
                    unsigned char c=p[i++];
                    if (c=='"') { closed=YES;break; }
                    if (c=='\\') {
                        if (i==n) return N6Fail(error, OR6APIHTTPInvalidResponse, @"invalid_chunk_extension");
                        c=p[i++];
                    }
                    if ((c<32 && c!='\t') || c==127)
                        return N6Fail(error, OR6APIHTTPInvalidResponse, @"invalid_chunk_extension");
                }
                if (!closed) return N6Fail(error, OR6APIHTTPInvalidResponse, @"invalid_chunk_extension");
            } else {
                start=i;while(i<n && N6TokenByte(p[i]))i++;
                if(i==start)return N6Fail(error, OR6APIHTTPInvalidResponse, @"invalid_chunk_extension");
            }
            while(i<n && (p[i]==' '||p[i]=='\t'))i++;
        }
        if(i<n && p[i]!=';')return N6Fail(error, OR6APIHTTPInvalidResponse, @"invalid_chunk_extension");
    }
    *size=value;return YES;
}
static BOOL N6Trailers(N6Reader *reader, NSUInteger *budget, NSError **error) {
    NSSet *forbidden=[NSSet setWithArray:@[@"content-length",@"transfer-encoding",@"content-encoding",
        @"content-type",@"authorization",@"cookie",@"set-cookie",@"host",@"connection",
        @"location",@"trailer",@"proxy-authenticate",@"proxy-authorization"]];
    NSUInteger count=0;
    for (;;) {
        NSData *line=[reader line:N6LineLimit error:error];if(!line)return NO;
        *budget+=line.length+2;
        if(*budget>N6HeaderLimit || (line.length && ++count>256))return N6Fail(error,OR6APIHTTPSizeLimit,@"trailers_too_large");
        if(!line.length)return YES;
        NSString *name=nil,*value=nil;if(!N6Field(line,&name,&value,error))return NO;
        if([forbidden containsObject:name])return N6Fail(error,OR6APIHTTPInvalidResponse,@"unsafe_trailer");
    }
}

static BOOL N6Emit(const unsigned char *bytes,NSUInteger length,N6State *state,NSMutableData *body,OR6APIHTTPBytes onBytes,NSError **error){
    if(!N6Alive(state,error))return NO;
    if(length>state->decodedLimit-state->decoded)return N6Fail(error,OR6APIHTTPSizeLimit,nil);
    state->decoded+=length;if(!length)return YES;N6Mark(state,N6FirstDecoded);
    if(body)[body appendBytes:bytes length:length];
    if(onBytes){
        double began=state->traceEnabled?N6Now():0;
        /* Release each fragment promptly, including noncollecting long streams. */
        NSAutoreleasePool *pool=[NSAutoreleasePool new];NSData *data=[[NSData alloc] initWithBytes:bytes length:length];BOOL keep=NO;
        @try{keep=onBytes(data);}@catch(NSException *e){(void)e;keep=NO;}
        @finally{[data release];[pool drain];}
        N6Trace(state,1,began,N6Now(),(NSInteger)length,0,0);
        if(!keep)return N6Fail(error,OR6APIHTTPConsumerStopped,nil);
    }
    return N6Alive(state,error);
}
static NSDictionary *N6Parse(N6Reader *reader,NSString *method,N6State *state,OR6APIHTTPHeaders onHeaders,OR6APIHTTPBytes onBytes,NSError **error){
    NSUInteger headerBytes=0;NSDictionary *head=nil;
    for(NSUInteger interim=0;interim<=8;interim++){
        if(!N6Alive(state,error))return nil;head=N6Head(reader,&headerBytes,error);if(!head)return nil;
        NSInteger code=[head[@"status"] integerValue];if(code>=200)break;
        if(code==101 || interim==8 || head[@"headers"][@"content-length"] || head[@"headers"][@"transfer-encoding"]){N6Fail(error,OR6APIHTTPInvalidResponse,nil);return nil;}
    }
    NSInteger status=[head[@"status"] integerValue];BOOL noBody=[method isEqualToString:@"HEAD"] || status==204 || status==304;
    NSMutableDictionary *headers=[NSMutableDictionary dictionaryWithDictionary:head[@"headers"]];
    NSString *transfer=headers[@"transfer-encoding"],*length=headers[@"content-length"],*encoding=headers[@"content-encoding"];
    NSUInteger count=0;
    if(length && !N6Decimal(length,NSUIntegerMax,&count)){N6Fail(error,OR6APIHTTPInvalidResponse,nil);return nil;}
    if(!noBody && count>state->encodedLimit){N6Fail(error,OR6APIHTTPSizeLimit,nil);return nil;}
    if((transfer && ![[transfer lowercaseString] isEqualToString:@"chunked"]) || (status==204 && (transfer || (length && count)))){
        N6Fail(error,OR6APIHTTPInvalidResponse,nil);return nil;
    }
    BOOL gzip=!noBody && encoding && ![[encoding lowercaseString] isEqualToString:@"identity"];
    if(gzip && ![[encoding lowercaseString] isEqualToString:@"gzip"]){N6Fail(error,OR6APIHTTPInvalidResponse,nil);return nil;}
    state->responseEncoding=gzip?2:1;state->responseFraming=noBody?1:transfer?2:length?3:4;N6Mark(state,N6ResponseHeaders);
    NSMutableSet *hop=[NSMutableSet setWithArray:@[@"connection",@"keep-alive",@"proxy-connection",@"transfer-encoding",@"te",@"trailer",@"upgrade",@"proxy-authenticate",@"proxy-authorization"]];
    if(headers[@"connection"])for(NSString *raw in [headers[@"connection"] componentsSeparatedByString:@","]){
        NSString *token=[N6Trim(raw) lowercaseString];
        if(!N6Token(token) || [@[@"content-length",@"content-encoding",@"location",@"set-cookie"] containsObject:token]){
            N6Fail(error,OR6APIHTTPInvalidResponse,nil);return nil;
        }[hop addObject:token];
    }
    for(NSString *name in hop)[headers removeObjectForKey:name];
    if(gzip){[headers removeObjectForKey:@"content-encoding"];[headers removeObjectForKey:@"content-length"];
        for(NSString *name in @[@"content-md5",@"digest",@"content-digest",@"repr-digest"])[headers removeObjectForKey:name];}
    NSMutableDictionary *canonical=[NSMutableDictionary dictionary];for(NSString *name in headers)canonical[N6HeaderName(name)]=headers[name];
    NSDictionary *frozen=[NSDictionary dictionaryWithDictionary:canonical];
    if(onHeaders){BOOL keep=NO;@try{keep=onHeaders(status,frozen);}@catch(NSException *e){(void)e;}
        if(!keep){N6Fail(error,OR6APIHTTPConsumerStopped,nil);return nil;}}
    if(!N6Alive(state,error))return nil;
    NSMutableData *body=state->collect?[NSMutableData data]:nil;
    __block z_stream z;memset(&z,0,sizeof(z));__block BOOL ended=NO;
    if(gzip && inflateInit2(&z,15+16)!=Z_OK){N6Fail(error,OR6APIHTTPInvalidResponse,nil);return nil;}
    BOOL ok=NO;
    @try{
        N6Sink sink=^BOOL(const unsigned char *bytes,NSUInteger n,NSError **issue){
            if(!N6Alive(state,issue))return NO;
            if(n>state->encodedLimit-state->encoded)return N6Fail(issue,OR6APIHTTPSizeLimit,nil);
            state->encoded+=n;if(n)N6Mark(state,N6FirstEncoded);
            if(status==205 && n)return N6Fail(issue,OR6APIHTTPInvalidResponse,nil);
            if(!gzip)return N6Emit(bytes,n,state,body,onBytes,issue);
            if(ended && n)return N6Fail(issue,OR6APIHTTPInvalidResponse,nil);
            z.next_in=(Bytef *)bytes;z.avail_in=(uInt)n;
            do{
                if(!N6Alive(state,issue))return NO;
                unsigned char decoded[8192];z.next_out=decoded;z.avail_out=sizeof(decoded);
                uInt before=z.avail_in;
                int code=inflate(&z,Z_NO_FLUSH);NSUInteger produced=sizeof(decoded)-z.avail_out;
                if(produced && !N6Emit(decoded,produced,state,body,onBytes,issue))return NO;
                if(code==Z_STREAM_END){ended=YES;if(z.avail_in)return N6Fail(issue,OR6APIHTTPInvalidResponse,nil);break;}
                if(code==Z_BUF_ERROR && !z.avail_in && !produced)break;
                if(code!=Z_OK)return N6Fail(issue,OR6APIHTTPInvalidResponse,nil);
                if(!produced && z.avail_in==before && z.avail_in)return N6Fail(issue,OR6APIHTTPInvalidResponse,nil);
            }while(z.avail_in || z.avail_out==0);
            return YES;
        };
        if(!noBody){
            if(transfer){NSUInteger metadata=0,chunks=0;
                for(;;){
                    if(!N6Alive(state,error))return nil;
                    NSData *line=[reader line:4096 error:error];if(!line)return nil;
                    metadata+=line.length+2;if(metadata>256*1024 || ++chunks>16384){N6Fail(error,OR6APIHTTPSizeLimit,nil);return nil;}
                    NSUInteger n=0;if(!N6ChunkSize(line,&n,error))return nil;
                    if(!n){if(!N6Trailers(reader,&headerBytes,error))return nil;break;}
                    if(n>state->encodedLimit-state->encoded){N6Fail(error,OR6APIHTTPSizeLimit,nil);return nil;}
                    if(![reader take:n sink:sink error:error])return nil;
                    unsigned char ending[2];unsigned char *endPtr=ending;__block NSUInteger at=0;
                    if(![reader take:2 sink:^BOOL(const unsigned char *p,NSUInteger size,NSError **unused){(void)unused;memcpy(endPtr+at,p,size);at+=size;return YES;} error:error])return nil;
                    metadata+=2;if(ending[0]!='\r' || ending[1]!='\n'){N6Fail(error,OR6APIHTTPInvalidResponse,nil);return nil;}
                    if(metadata>256*1024){N6Fail(error,OR6APIHTTPSizeLimit,nil);return nil;}
                }
            }else if(length){if(![reader take:count sink:sink error:error])return nil;}
            else if(![reader untilEOF:sink error:error])return nil;
        }
        if(reader.remaining || (gzip && !ended)){N6Fail(error,OR6APIHTTPInvalidResponse,nil);return nil;}
        ok=N6Alive(state,error);
    }@finally{if(gzip)inflateEnd(&z);}
    if(!ok)return nil;N6Mark(state,N6ResponseComplete);
    NSMutableDictionary *result=[NSMutableDictionary dictionaryWithDictionary:@{@"status":head[@"status"],@"headers":frozen,@"setCookies":head[@"setCookies"]}];
    if(body)result[@"data"]=body;return result;
}

@interface N6Resolution : NSObject {
@public BOOL finished; CFStreamError error;
}
@end
@implementation N6Resolution
@end
static const void *N6RetainContext(const void *value) { return [(id)value retain]; }
static void N6ReleaseContext(const void *value) { [(id)value release]; }
static void N6Resolved(CFHostRef host, CFHostInfoType type, const CFStreamError *error, void *info) {
    (void)host; (void)type;
    N6Resolution *result=(N6Resolution *)info;
    if(error)result->error=*error;
    result->finished=YES;
}
static NSArray *N6Addresses(NSString *name,N6State *state,NSError **error) {
    CFHostRef host=CFHostCreateWithName(kCFAllocatorDefault,(CFStringRef)name);
    if(!host){N6Fail(error,OR6APIHTTPDNSFailure,@"dns_failed");return nil;}
    N6Resolution *result=[N6Resolution new];
    CFHostClientContext context={0,result,N6RetainContext,N6ReleaseContext,NULL};
    BOOL scheduled=NO;NSArray *addresses=nil;
    @try {
        if(!CFHostSetClient(host,N6Resolved,&context)){
            N6Fail(error,OR6APIHTTPDNSFailure,@"dns_failed");
        }else{
            CFHostScheduleWithRunLoop(host,CFRunLoopGetCurrent(),kCFRunLoopDefaultMode);scheduled=YES;
            CFStreamError immediate={0,0};
            if(!CFHostStartInfoResolution(host,kCFHostAddresses,&immediate)){
                N6Fail(error,OR6APIHTTPDNSFailure,@"dns_failed");
            }else{
                BOOL alive=YES;
                while(!result->finished && (alive=N6Alive(state,error)))
                    CFRunLoopRunInMode(kCFRunLoopDefaultMode,0.05,true);
                if(alive && result->finished && !result->error.error){
                    Boolean resolved=false;
                    CFArrayRef raw=CFHostGetAddressing(host,&resolved);
                    if(resolved && raw && CFArrayGetCount(raw)>0 && CFArrayGetCount(raw)<=64)
                        addresses=[[(NSArray *)raw copy] autorelease];
                }
                if(!addresses && alive)N6Fail(error,OR6APIHTTPDNSFailure,@"dns_failed");
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
static NSData *N6Roots(NSString *path,NSError **error) {
    if(![path isKindOfClass:[NSString class]] || !path.length || path.length>PATH_MAX){
        N6Fail(error,OR6APIHTTPInvalidRequest,@"invalid_roots");return nil;
    }
    int fd=open(path.fileSystemRepresentation,O_RDONLY|O_NOFOLLOW|O_NONBLOCK);
    if(fd<0){N6Fail(error,OR6APIHTTPCertificateFailure,@"roots_unavailable");return nil;}
    NSMutableData *data=[NSMutableData data];BOOL valid=YES;
    @try{
        struct stat st;
        if(fstat(fd,&st) || !S_ISREG(st.st_mode) || st.st_size<=0 || st.st_size>1024*1024){
            N6Fail(error,OR6APIHTTPCertificateFailure,@"invalid_roots");valid=NO;
        }else{
            for(;;){
                unsigned char bytes[8192];ssize_t n=read(fd,bytes,sizeof(bytes));
                if(n<0 && errno==EINTR)continue;
                if(n<0 || (n>0 && (NSUInteger)n>1024*1024-data.length)){
                    N6Fail(error,OR6APIHTTPCertificateFailure,@"invalid_roots");valid=NO;break;
                }
                if(!n)break;
                [data appendBytes:bytes length:(NSUInteger)n];
            }
            if(valid && data.length!=(NSUInteger)st.st_size){
                N6Fail(error,OR6APIHTTPCertificateFailure,@"roots_changed");valid=NO;
            }
        }
    }@finally{close(fd);}
    return valid?data:nil;
}

static int N6Wait(int fd,BOOL writing,N6State *state,NSError **error){
    if(fd<0 || fd>=FD_SETSIZE){N6Fail(error,OR6APIHTTPIOFailure,nil);return -1;}
    for(;;){
        if(!N6Alive(state,error))return -1;
        double delay=MIN(.05,MAX(0.,N6Deadline(state)-N6Now()));
        struct timeval tv={(time_t)delay,(suseconds_t)((delay-floor(delay))*1e6)};
        fd_set ready;FD_ZERO(&ready);FD_SET(fd,&ready);
        double began=state->traceEnabled?N6Now():0;
        int n=select(fd+1,writing?NULL:&ready,writing?&ready:NULL,NULL,&tv);
        if(state->traceEnabled){state->socketWait+=N6Now()-began;state->socketWaitCalls++;if(!writing&&!n)state->socketReadTimeouts++;}
        if(n>0)return 1;if(!n || errno==EINTR)continue;
        N6Fail(error,OR6APIHTTPIOFailure,nil);return -1;
    }
}
/* Race TCP candidates only; HTTP/TLS still use exactly one winning socket.
 * Interleave address families and stagger starts by250ms so a black-holed
 * preferred family cannot consume the entire shared connect deadline.
 * Pending candidates keep their full budget; cancel/overall limits stay global. */
static int N6Connect(NSArray *addresses,NSUInteger port,N6State *state,NSError **error){
    NSMutableArray *primary=[NSMutableArray array],*secondary=[NSMutableArray array];int preferred=0;
    NSUInteger inspected=0;
    for(id item in addresses){
        if(++inspected>64)break;
        if(![item isKindOfClass:NSData.class]||[item length]<sizeof(struct sockaddr)||[item length]>sizeof(struct sockaddr_storage))continue;
        struct sockaddr_storage storage;memset(&storage,0,sizeof(storage));memcpy(&storage,[item bytes],[item length]);
        struct sockaddr *addr=(void*)&storage;socklen_t size=0;
        if(addr->sa_family==AF_INET&&[item length]>=sizeof(struct sockaddr_in)){
#if defined(OR6_API_HTTP_TESTING)
            if(port!=443&&(ntohl(((struct sockaddr_in*)&storage)->sin_addr.s_addr)>>24)!=127)continue;
#endif
            ((struct sockaddr_in*)&storage)->sin_port=htons((uint16_t)port);size=sizeof(struct sockaddr_in);
        }else if(addr->sa_family==AF_INET6&&[item length]>=sizeof(struct sockaddr_in6)){
#if defined(OR6_API_HTTP_TESTING)
            if(port!=443&&!IN6_IS_ADDR_LOOPBACK(&((struct sockaddr_in6*)&storage)->sin6_addr))continue;
#endif
            ((struct sockaddr_in6*)&storage)->sin6_port=htons((uint16_t)port);size=sizeof(struct sockaddr_in6);
        }else continue;
        if(!preferred)preferred=addr->sa_family;
        NSData *fixed=[NSData dataWithBytes:&storage length:size];
        if(![primary containsObject:fixed]&&![secondary containsObject:fixed])[(addr->sa_family==preferred?primary:secondary)addObject:fixed];
    }
    NSMutableArray *ordered=[NSMutableArray array];
    for(NSUInteger i=0;i<MAX(primary.count,secondary.count)&&ordered.count<16;i++){
        if(i<primary.count)[ordered addObject:primary[i]];
        if(i<secondary.count&&ordered.count<16)[ordered addObject:secondary[i]];
    }
    int pending[16];for(NSUInteger i=0;i<16;i++)pending[i]=-1;
    NSUInteger next=0,active=0;double nextStart=0;int winner=-1;
    @try{
        while(N6Alive(state,error)){
            if(next>=ordered.count&&!active){N6Fail(error,OR6APIHTTPIOFailure,nil);break;}
            double now=N6Now();
            if(next<ordered.count&&(!active||now>=nextStart)){
                NSData *data=ordered[next++];const struct sockaddr *addr=data.bytes;
                state->connections++;int fd=socket(addr->sa_family,SOCK_STREAM,IPPROTO_TCP);
                if(fd<0)continue;
                int flags=fcntl(fd,F_GETFL,0),one=1;
                if(fd>=FD_SETSIZE||flags<0||fcntl(fd,F_SETFL,flags|O_NONBLOCK)||fcntl(fd,F_SETFD,FD_CLOEXEC)||setsockopt(fd,SOL_SOCKET,SO_NOSIGPIPE,&one,sizeof(one))){close(fd);continue;}
                int code=connect(fd,addr,(socklen_t)data.length);
                if(!code){winner=fd;break;}
                if(errno!=EINPROGRESS&&errno!=EWOULDBLOCK&&errno!=EINTR){close(fd);nextStart=0;continue;}
                for(NSUInteger i=0;i<16;i++)if(pending[i]<0){pending[i]=fd;break;}
                active++;nextStart=N6Now()+.25;
            }
            if(!active)continue;
            fd_set ready,exception;FD_ZERO(&ready);FD_ZERO(&exception);int highest=-1;
            for(NSUInteger i=0;i<16;i++)if(pending[i]>=0){FD_SET(pending[i],&ready);FD_SET(pending[i],&exception);highest=MAX(highest,pending[i]);}
            now=N6Now();double delay=MIN(.05,MAX(0.,N6Deadline(state)-now));
            if(next<ordered.count)delay=MIN(delay,MAX(0.,nextStart-now));
            struct timeval tv={(time_t)delay,(suseconds_t)((delay-floor(delay))*1e6)};
            double began=state->traceEnabled?N6Now():0;
            int count=select(highest+1,NULL,&ready,&exception,&tv);
            if(state->traceEnabled){state->socketWait+=N6Now()-began;state->socketWaitCalls++;}
            if(count<0){if(errno==EINTR)continue;N6Fail(error,OR6APIHTTPIOFailure,nil);break;}
            if(!count)continue;
            for(NSUInteger i=0;i<16;i++)if(pending[i]>=0&&(FD_ISSET(pending[i],&ready)||FD_ISSET(pending[i],&exception))){
                int problem=0;socklen_t length=sizeof(problem);
                if(!getsockopt(pending[i],SOL_SOCKET,SO_ERROR,&problem,&length)&&!problem){winner=pending[i];pending[i]=-1;active--;break;}
                close(pending[i]);pending[i]=-1;active--;nextStart=0;
            }
            if(winner>=0)break;
        }
    }@finally{for(NSUInteger i=0;i<16;i++)if(pending[i]>=0)close(pending[i]);}
    return winner;
}
typedef struct{int fd;N6State *state;OR6APIHTTPError issue;BOOL eof;}N6Socket;
static BOOL N6SocketAlive(N6Socket *s){NSError *error=nil;if(!N6Alive(s->state,&error)){s->issue=(OR6APIHTTPError)error.code;return NO;}return YES;}
static int N6Send(void *context,const unsigned char *bytes,size_t length){
    N6Socket *s=context;if(!N6SocketAlive(s))return MBEDTLS_ERR_NET_SEND_FAILED;
    ssize_t n=send(s->fd,bytes,length,0);if(n>=0)return (int)n;
    if(errno==EAGAIN || errno==EWOULDBLOCK || errno==EINTR)return MBEDTLS_ERR_SSL_WANT_WRITE;return MBEDTLS_ERR_NET_SEND_FAILED;
}
static int N6Receive(void *context,unsigned char *bytes,size_t length){
    N6Socket *s=context;if(!N6SocketAlive(s))return MBEDTLS_ERR_NET_RECV_FAILED;
    ssize_t n=recv(s->fd,bytes,length,0);if(!n)s->eof=YES;if(n>=0)return (int)n;
    if(errno==EAGAIN || errno==EWOULDBLOCK || errno==EINTR)return MBEDTLS_ERR_SSL_WANT_READ;return MBEDTLS_ERR_NET_RECV_FAILED;
}
static BOOL N6TLSWait(int code,N6Socket *s,NSError **error){
    if(s->issue)return N6Fail(error,s->issue,nil);
    if(code!=MBEDTLS_ERR_SSL_WANT_READ && code!=MBEDTLS_ERR_SSL_WANT_WRITE)return NO;
    return N6Wait(s->fd,code==MBEDTLS_ERR_SSL_WANT_WRITE,s->state,error)>0;
}
static BOOL N6Write(mbedtls_ssl_context *ssl,N6Socket *socket,const unsigned char *p,NSUInteger n,NSError **error){
    NSUInteger at=0;
    while(at<n){
        if(!N6Alive(socket->state,error))return NO;
        /* A TLS record-sized slice, with identical args on WANT_READ/WRITE. */
        NSUInteger size=MIN((NSUInteger)16384,n-at);int code=mbedtls_ssl_write(ssl,p+at,size);
        if(code>0){socket->state->sent+=(NSUInteger)code;socket->state->lastProgress=N6Now();at+=(NSUInteger)code;continue;}
        if(N6TLSWait(code,socket,error))continue;
        if(error && !*error)N6Fail(error,OR6APIHTTPIOFailure,nil);return NO;
    }return YES;
}
@interface N6BodyEvents:NSObject<NSStreamDelegate>{@public BOOL readable,ended,failed;}
@end
@implementation N6BodyEvents
- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)event{(void)stream;if(event&NSStreamEventHasBytesAvailable)readable=YES;if(event&NSStreamEventEndEncountered)ended=YES;if(event&NSStreamEventErrorOccurred)failed=YES;}
@end
static BOOL N6Upload(NSURLRequest *request,NSUInteger length,mbedtls_ssl_context *ssl,N6Socket *socket,NSError **error){
    if(!request.HTTPBodyStream)return !request.HTTPBody.length || N6Write(ssl,socket,request.HTTPBody.bytes,request.HTTPBody.length,error);
    NSInputStream *stream=request.HTTPBodyStream;N6BodyEvents *events=[N6BodyEvents new];id previous=[[stream delegate] retain];NSString *mode=@"OR6APIHTTPUpload";
    BOOL ok=NO;NSUInteger readBytes=0;
    @try{
        [stream setDelegate:events];[stream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:mode];[stream open];
        for(;;){
            if(!N6Alive(socket->state,error))break;
            NSStreamStatus status=stream.streamStatus;
            if(events->failed || status==NSStreamStatusError || status==NSStreamStatusClosed || status==NSStreamStatusNotOpen){N6Fail(error,OR6APIHTTPIOFailure,nil);break;}
            if(events->ended || status==NSStreamStatusAtEnd){if(readBytes==length)ok=YES;else N6Fail(error,OR6APIHTTPInvalidRequest,nil);break;}
            if(![stream hasBytesAvailable] && !events->readable){
                SInt32 code=CFRunLoopRunInMode((CFStringRef)mode,.01,true);if(code==kCFRunLoopRunFinished)usleep(10000);continue;
            }
            events->readable=NO;unsigned char chunk[8192];NSUInteger capacity=MIN(sizeof(chunk),length-readBytes+1);
            NSInteger n=[stream read:chunk maxLength:capacity];
            if(n<0){N6Fail(error,OR6APIHTTPIOFailure,nil);break;}
            if(!n){if(readBytes==length)ok=YES;else N6Fail(error,OR6APIHTTPInvalidRequest,nil);break;}
            if((NSUInteger)n>capacity || (NSUInteger)n>length-readBytes){N6Fail(error,OR6APIHTTPInvalidRequest,nil);break;}
            if(!N6Write(ssl,socket,chunk,(NSUInteger)n,error))break;readBytes+=(NSUInteger)n;
        }
    }@finally{
        [stream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:mode];[stream close];[stream setDelegate:previous];[events release];[previous release];
    }
    return ok;
}
static NSDictionary *N6Network(NSURLRequest *request,NSDictionary *prepared,NSString *CAFile,N6State *state,OR6APIHTTPHeaders onHeaders,OR6APIHTTPBytes onBytes,OR6APIHTTPDuplexPump pump,NSError **error){
    /* Reject an accidentally mixed baseline archive before context ABI use. */
    if(mbedtls_version_get_number()!=0x03060700 ||
        mbedtls_version_check_feature("MBEDTLS_THREADING_C") ||
        mbedtls_version_check_feature("MBEDTLS_THREADING_PTHREAD")){
        N6Fail(error,OR6APIHTTPTLSFailure,nil);return nil;
    }
    N6Mark(state,N6RootsStart);NSData *roots=N6Roots(CAFile,error);N6Mark(state,N6RootsEnd);if(!roots || !N6Alive(state,error))return nil;
    N6Mark(state,N6DNSStart);NSArray *addresses=N6Addresses([request.URL.host lowercaseString],state,error);N6Mark(state,N6DNSEnd);if(!addresses)return nil;
    N6Mark(state,N6TLSSetupStart);
    N6Socket socket;memset(&socket,0,sizeof(socket));socket.fd=-1;socket.state=state;
    mbedtls_ssl_context ssl;mbedtls_ssl_config conf;mbedtls_x509_crt ca;mbedtls_entropy_context entropy;mbedtls_ctr_drbg_context rng;
    mbedtls_ssl_init(&ssl);mbedtls_ssl_config_init(&conf);mbedtls_x509_crt_init(&ca);mbedtls_entropy_init(&entropy);mbedtls_ctr_drbg_init(&rng);
    NSDictionary *result=nil;
    @try{do{
        /* 3.6.7 PSA init is thread-safe with the matching pthread configuration. */
        if(psa_crypto_init()!=PSA_SUCCESS){N6Fail(error,OR6APIHTTPTLSFailure,nil);break;}
        const unsigned char personal[]="LegacyClient HTTPS";
        if(mbedtls_ctr_drbg_seed(&rng,mbedtls_entropy_func,&entropy,personal,sizeof(personal)-1)){
            N6Fail(error,OR6APIHTTPTLSFailure,nil);break;
        }
        N6Mark(state,N6RNGReady);
        NSMutableData *terminated=[NSMutableData dataWithData:roots];unsigned char zero=0;[terminated appendBytes:&zero length:1];
        BOOL pem=NO;const char *marker="-----BEGIN CERTIFICATE-----";size_t markerLength=strlen(marker);
        if(roots.length>=markerLength)for(NSUInteger i=0;i<=roots.length-markerLength;i++)if(!memcmp((const unsigned char *)roots.bytes+i,marker,markerLength)){pem=YES;break;}
        N6Mark(state,N6CAStart);if(mbedtls_x509_crt_parse(&ca,pem?terminated.bytes:roots.bytes,pem?terminated.length:roots.length)){
            N6Fail(error,OR6APIHTTPCertificateFailure,nil);break;
        }
        N6Mark(state,N6CAEnd);if(mbedtls_ssl_config_defaults(&conf,MBEDTLS_SSL_IS_CLIENT,MBEDTLS_SSL_TRANSPORT_STREAM,MBEDTLS_SSL_PRESET_DEFAULT)){
            N6Fail(error,OR6APIHTTPTLSFailure,nil);break;
        }
        mbedtls_ssl_conf_authmode(&conf,MBEDTLS_SSL_VERIFY_REQUIRED);mbedtls_ssl_conf_ca_chain(&conf,&ca,NULL);mbedtls_ssl_conf_rng(&conf,mbedtls_ctr_drbg_random,&rng);
        mbedtls_ssl_conf_min_tls_version(&conf,MBEDTLS_SSL_VERSION_TLS1_2);mbedtls_ssl_conf_max_tls_version(&conf,MBEDTLS_SSL_VERSION_TLS1_3);
#if defined(MBEDTLS_SSL_SESSION_TICKETS)
        mbedtls_ssl_conf_session_tickets(&conf,MBEDTLS_SSL_SESSION_TICKETS_DISABLED);
#endif
#if defined(MBEDTLS_SSL_RENEGOTIATION)
        mbedtls_ssl_conf_renegotiation(&conf,MBEDTLS_SSL_RENEGOTIATION_DISABLED);
#endif
        const char *alpn[]={"http/1.1",NULL};
        if(mbedtls_ssl_conf_alpn_protocols(&conf,alpn) || mbedtls_ssl_setup(&ssl,&conf) || mbedtls_ssl_set_hostname(&ssl,request.URL.host.UTF8String)){
            N6Fail(error,OR6APIHTTPTLSFailure,nil);break;
        }
        N6Mark(state,N6ConfigReady);N6Mark(state,N6TCPStart);NSUInteger port=request.URL.port?[request.URL.port unsignedIntegerValue]:443;socket.fd=N6Connect(addresses,port,state,error);if(socket.fd<0)break;
        N6Mark(state,N6TCPReady);mbedtls_ssl_set_bio(&ssl,&socket,N6Send,N6Receive,NULL);int code=0;N6Mark(state,N6TLSStart);
        for(;;){if(!N6Alive(state,error)){code=-1;break;}code=mbedtls_ssl_handshake(&ssl);if(!code)break;if(!N6TLSWait(code,&socket,error))break;}
        if(code){
            if(error && !*error){
                uint32_t flags=mbedtls_ssl_get_verify_result(&ssl);
                /* UINT32_MAX means verification never ran (e.g. TLS version). */
                BOOL certificate=code==MBEDTLS_ERR_X509_CERT_VERIFY_FAILED || (flags && flags!=UINT32_MAX);
                N6Fail(error,certificate?OR6APIHTTPCertificateFailure:OR6APIHTTPTLSFailure,nil);
            }break;
        }
        if(mbedtls_ssl_get_verify_result(&ssl) || !mbedtls_ssl_get_peer_cert(&ssl)){N6Fail(error,OR6APIHTTPCertificateFailure,nil);break;}
        N6Mark(state,N6TLSReady);state->connecting=NO;state->lastProgress=N6Now();NSData *head=prepared[@"head"];
        if(!N6Write(&ssl,&socket,head.bytes,head.length,error))break;N6Mark(state,N6HeadersWritten);
        if(!N6Upload(request,[prepared[@"length"] unsignedIntegerValue],&ssl,&socket,error))break;N6Mark(state,N6RequestWritten);
        mbedtls_ssl_context *sslPtr=&ssl;N6Socket *socketPtr=&socket;
        N6ReadBlock read=^NSInteger(unsigned char *bytes,NSUInteger capacity,NSError **issue){
            NSUInteger tickets=0,timeouts=state->socketReadTimeouts;double began=state->traceEnabled?N6Now():0,wait=state->socketWait;NSInteger readResult=-1;
            @try{
            for(;;){
                if(!N6Alive(state,issue))return -1;int n=mbedtls_ssl_read(sslPtr,bytes,capacity);
                if(n>0){N6Mark(state,N6FirstByte);state->received+=(NSUInteger)n;state->lastProgress=N6Now();readResult=n;return n;}
                if(n==MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY){readResult=0;return 0;}
                if(!n){if(socketPtr->eof){N6Fail(issue,OR6APIHTTPIOFailure,nil);return -1;}readResult=0;return 0;}
                if(n==MBEDTLS_ERR_SSL_RECEIVED_NEW_SESSION_TICKET && ++tickets<=32)continue;
                if(N6TLSWait(n,socketPtr,issue))continue;if(issue && !*issue)N6Fail(issue,OR6APIHTTPIOFailure,nil);return -1;
            }}@finally{N6Trace(state,0,began,N6Now(),readResult,state->socketWait-wait,state->socketReadTimeouts-timeouts);}
        };
        if(pump){
            OR6APIHTTPDuplexRead receive=^NSInteger(unsigned char *bytes,NSUInteger capacity,NSError **issue){
                if(!bytes||!capacity||capacity>65536||!N6Alive(state,issue))return -1;
                for(NSUInteger ticket=0;ticket<32;ticket++){
                    int n=mbedtls_ssl_read(sslPtr,bytes,capacity);
                    if(n>0){if(state->received>8*1024*1024||(NSUInteger)n>8*1024*1024-state->received){N6Fail(issue,OR6APIHTTPSizeLimit,nil);return -1;}state->received+=(NSUInteger)n;state->lastProgress=N6Now();return n;}
                    if(n==MBEDTLS_ERR_SSL_WANT_READ||n==MBEDTLS_ERR_SSL_WANT_WRITE)return -2;
                    if(n==MBEDTLS_ERR_SSL_RECEIVED_NEW_SESSION_TICKET)continue;
                    if(n==MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY)return 0;
                    if(!n){if(socketPtr->eof){N6Fail(issue,OR6APIHTTPIOFailure,nil);return -1;}return 0;}
                    N6Fail(issue,socketPtr->issue?:OR6APIHTTPIOFailure,nil);return -1;
                }N6Fail(issue,OR6APIHTTPInvalidResponse,nil);return -1;
            };
            OR6APIHTTPDuplexWrite send=^BOOL(NSData *bytes,NSError **issue){
                if(![bytes isKindOfClass:NSData.class]||bytes.length>65536||state->sent>8*1024*1024||bytes.length>8*1024*1024-state->sent)return N6Fail(issue,OR6APIHTTPSizeLimit,nil);
                return N6Write(sslPtr,socketPtr,bytes.bytes,bytes.length,issue);
            };
            if(pump(receive,send,error)&&N6Alive(state,error))result=@{@"certificateVerified":@YES};break;
        }
        N6Reader *reader=[[N6Reader alloc] initWithRead:read limit:state->encodedLimit+4*N6HeaderLimit+256*1024];NSDictionary *parsed=nil;
        @try{parsed=[N6Parse(reader,prepared[@"method"],state,onHeaders,onBytes,error) retain];}@finally{[reader release];}
        [parsed autorelease];if(!parsed || !N6Alive(state,error))break;
        NSMutableDictionary *response=[NSMutableDictionary dictionaryWithDictionary:parsed];response[@"tlsVersion"]=[NSString stringWithUTF8String:mbedtls_ssl_get_version(&ssl)];
        response[@"cipher"]=[NSString stringWithUTF8String:mbedtls_ssl_get_ciphersuite(&ssl)];response[@"certificateVerified"]=@YES;result=response;
    }while(0);}@finally{
        if(socket.fd>=0)close(socket.fd);mbedtls_ssl_free(&ssl);mbedtls_ssl_config_free(&conf);mbedtls_x509_crt_free(&ca);mbedtls_ctr_drbg_free(&rng);mbedtls_entropy_free(&entropy);
    }return result;
}
static NSDictionary *N6Counters(N6State*s,BOOL written){
 NSDictionary*d=@{@"requestWritten":@(written),@"requestBytesSent":@(s->sent),@"bytesSent":@(s->sent),@"responseBytesRead":@(s->received),@"encodedBytes":@(s->encoded),@"decodedBytes":@(s->decoded),@"connectionAttempts":@(s->connections),@"dispatchCount":@(s->sent?1:0),@"timings":N6Timings(s),@"timingOriginMonotonic":@(s->started),@"configuredAcceptEncoding":s->identityEncoding?@"identity":@"gzip",@"responseContentEncoding":s->responseEncoding==1?@"identity":s->responseEncoding==2?@"gzip":@"unobserved",@"responseFraming":s->responseFraming==1?@"none":s->responseFraming==2?@"chunked":s->responseFraming==3?@"length":s->responseFraming==4?@"eof":@"unobserved",@"connectionReused":@NO};
 if(!s->traceEnabled)return d;NSMutableDictionary*r=[[d mutableCopy]autorelease];r[@"streamTiming"]=N6StreamTiming(s);return r;
}
static BOOL N6Option(NSDictionary *options,NSString *key,double fallback,double minimum,double maximum,double *out){
    id value=options[key];if(!value){*out=fallback;return YES;}
    if(![value isKindOfClass:[NSNumber class]])return NO;double n=[value doubleValue];if(!isfinite(n) || n<minimum || n>maximum)return NO;*out=n;return YES;
}
NSDictionary *OR6APIHTTPPerform(NSURLRequest *request,NSString *CAFile,NSSet *allowedHosts,NSDictionary *options,BOOL (^cancelled)(void),OR6APIHTTPHeaders onHeaders,OR6APIHTTPBytes onBytes,NSError **error){
    NSAutoreleasePool *pool=[NSAutoreleasePool new];NSError *failure=nil;NSDictionary *result=nil,*prepared=nil;
    NSURLRequest *fixed=nil;NSString *roots=nil;NSSet *hosts=nil;NSDictionary *settings=nil;BOOL (^stop)(void)=nil;OR6APIHTTPHeaders headerBlock=nil;OR6APIHTTPBytes byteBlock=nil;
    N6State state;memset(&state,0,sizeof(state));state.started=N6Now();BOOL written=NO;
    @try{
        if(![request isKindOfClass:[NSURLRequest class]] || (options && ![options isKindOfClass:[NSDictionary class]]) || ![CAFile isKindOfClass:[NSString class]] || ![allowedHosts isKindOfClass:[NSSet class]]){
            N6Fail(&failure,OR6APIHTTPInvalidRequest,nil);
        }else{
            fixed=[request copy];roots=[CAFile copy];hosts=[allowedHosts copy];settings=[options copy];stop=[cancelled copy];headerBlock=[onHeaders copy];byteBlock=[onBytes copy];
            double connect=0,idle=0,overall=0,requestMax=0,encodedMax=0,decodedMax=0;BOOL valid=YES;
            NSSet *keys=[NSSet setWithArray:@[@"connectTimeout",@"idleTimeout",@"overallTimeout",@"maxRequestBytes",@"maxEncodedBytes",@"maxDecodedBytes",@"collectBody",@"acceptEncoding",@"traceReadTiming"]];
            for(id key in settings)if(![keys containsObject:key])valid=NO;
            valid=valid && N6Option(settings,@"connectTimeout",20,.01,120,&connect) && N6Option(settings,@"idleTimeout",30,.01,600,&idle) && N6Option(settings,@"overallTimeout",300,.01,3600,&overall) &&
                N6Option(settings,@"maxRequestBytes",1024*1024,1,N6HardLimit,&requestMax) && N6Option(settings,@"maxEncodedBytes",8*1024*1024,1,N6HardLimit,&encodedMax) && N6Option(settings,@"maxDecodedBytes",8*1024*1024,1,N6HardLimit,&decodedMax);
            if(settings[@"acceptEncoding"]&&![@[@"identity",@"gzip"]containsObject:settings[@"acceptEncoding"]])valid=NO;
            if(settings[@"traceReadTiming"]&&(![settings[@"traceReadTiming"]isKindOfClass:NSNumber.class]||![@[@0,@1]containsObject:settings[@"traceReadTiming"]]))valid=NO;
            if(settings[@"collectBody"] && ![settings[@"collectBody"] isKindOfClass:[NSNumber class]])valid=NO;
            if(requestMax!=floor(requestMax) || encodedMax!=floor(encodedMax) || decodedMax!=floor(decodedMax))valid=NO;
            if(!valid)N6Fail(&failure,OR6APIHTTPInvalidRequest,nil);
            else{
                double now=N6Now();state.overall=now+overall;state.connect=now+connect;state.idle=idle;state.lastProgress=now;state.connecting=YES;state.cancelled=stop;
                state.requestLimit=(NSUInteger)requestMax;state.encodedLimit=(NSUInteger)encodedMax;state.decodedLimit=(NSUInteger)decodedMax;state.collect=settings[@"collectBody"]?[settings[@"collectBody"] boolValue]:YES;state.identityEncoding=[settings[@"acceptEncoding"]isEqual:@"identity"];state.traceEnabled=[settings[@"traceReadTiming"]boolValue];
                if(N6Alive(&state,&failure) && N6ValidateURL(fixed.URL,hosts,&failure)){
                    prepared=N6Prepare(fixed,&state,&failure);
                    if(prepared)N6Mark(&state,N6Prepared);
                    if(prepared)result=N6Network(fixed,prepared,roots,&state,headerBlock,byteBlock,nil,&failure);
                    written=prepared && state.sent==[prepared[@"head"] length]+[prepared[@"length"] unsignedIntegerValue];
                }
            }
        }
    }@catch(NSException *exception){(void)exception;failure=N6Error(OR6APIHTTPInvalidRequest);result=nil;}
    @finally{[fixed release];[roots release];[hosts release];[settings release];[stop release];[headerBlock release];[byteBlock release];}
    N6Mark(&state,N6Finished);NSDictionary *counts=N6Counters(&state,written);
    if(result){NSMutableDictionary *response=[NSMutableDictionary dictionaryWithDictionary:result];[response addEntriesFromDictionary:counts];result=response;}
    else{if(!failure)failure=N6Error(OR6APIHTTPIOFailure);NSMutableDictionary *info=[NSMutableDictionary dictionaryWithDictionary:counts];info[NSLocalizedDescriptionKey]=failure.localizedDescription;
        failure=[NSError errorWithDomain:OR6APIHTTPErrorDomain code:failure.code userInfo:info];}
    [result retain];[failure retain];[pool drain];if(error)*error=[failure autorelease];else[failure release];return [result autorelease];
}

NSDictionary *OR6APIHTTPDuplex(NSURLRequest *request,NSString *CAFile,NSSet *allowedHosts,BOOL(^cancelled)(void),OR6APIHTTPDuplexPump pump,NSError **error){
 NSAutoreleasePool*pool=[NSAutoreleasePool new];NSError*failure=nil;NSDictionary*result=nil;NSURLRequest*fixed=nil;NSString*roots=nil;NSSet*hosts=nil;BOOL(^stop)(void)=nil;OR6APIHTTPDuplexPump processor=nil;N6State state;memset(&state,0,sizeof(state));state.started=N6Now();state.overall=state.started+90;state.connect=state.started+15;state.idle=25;state.lastProgress=state.started;state.connecting=YES;state.requestLimit=32768;state.encodedLimit=8*1024*1024;state.decodedLimit=state.encodedLimit;state.identityEncoding=YES;
 @try{
  if([request isKindOfClass:NSURLRequest.class]&&[CAFile isKindOfClass:NSString.class]&&[allowedHosts isKindOfClass:NSSet.class]){fixed=[request copy];roots=[CAFile copy];hosts=[allowedHosts copy];stop=[cancelled copy];processor=[pump copy];state.cancelled=stop;}
  if(!fixed||!roots||!processor||![fixed.HTTPMethod isEqual:@"GET"]||fixed.HTTPBody.length||fixed.HTTPBodyStream||!N6ValidateURL(fixed.URL,hosts,&failure))N6Fail(&failure,OR6APIHTTPInvalidRequest,nil);
  else{
   NSString*authority=fixed.URL.host;
#if defined(OR6_API_HTTP_TESTING)
   if(fixed.URL.port&&fixed.URL.port.integerValue!=443)authority=[authority stringByAppendingFormat:@":%@",fixed.URL.port];
#endif
   NSDictionary*headers=fixed.allHTTPHeaderFields;BOOL valid=headers.count<=32;NSMutableSet*seen=[NSMutableSet set];NSMutableString*head=[NSMutableString stringWithFormat:@"GET %@ HTTP/1.1\r\nHost: %@\r\nConnection: Upgrade\r\nUpgrade: websocket\r\n",N6Target(fixed.URL,&failure),authority];
   for(NSString*k in headers){NSString*v=headers[k],*lower=k.lowercaseString;if(!N6Token(k)||!N6HeaderValue(v)||k.length+v.length>16384||[seen containsObject:lower]||[@[@"host",@"connection",@"upgrade",@"content-length",@"transfer-encoding",@"proxy-authorization"]containsObject:lower]){valid=NO;break;}[seen addObject:lower];[head appendFormat:@"%@: %@\r\n",k,v];}
   valid=valid&&[[fixed valueForHTTPHeaderField:@"Sec-WebSocket-Version"]isEqual:@"13"]&&[[fixed valueForHTTPHeaderField:@"Sec-WebSocket-Key"]length]==24;[head appendString:@"\r\n"];NSData*wire=[head dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:NO];
   if(!valid||!wire||wire.length>32768)N6Fail(&failure,OR6APIHTTPInvalidRequest,nil);
   else result=N6Network(fixed,@{@"head":wire,@"length":@0,@"method":@"GET"},roots,&state,nil,nil,processor,&failure);
  }
 }@catch(NSException*exception){(void)exception;failure=N6Error(OR6APIHTTPInvalidRequest);result=nil;}
 @finally{[fixed release];[roots release];[hosts release];[stop release];[processor release];}
 if(!result&&!failure)failure=N6Error(OR6APIHTTPIOFailure);[result retain];[failure retain];[pool drain];if(error)*error=[failure autorelease];else[failure release];return[result autorelease];
}
