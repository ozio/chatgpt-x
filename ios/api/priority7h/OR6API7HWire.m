#import "OR6API7HWire.h"
#import <CommonCrypto/CommonDigest.h>
#import <Security/SecRandom.h>
static id Fail(NSError **e,NSString *code){if(e)*e=OR6APIError(code,@"none");return nil;}
static BOOL Text(id v,NSUInteger n,BOOL empty){return [v isKindOfClass:NSString.class]&&[v length]<=n&&(empty||[v length]>0);}
static BOOL BoolH(id v){return OR6APISchemaCheck(v,@{@"type":@"boolean"},@{});}
static BOOL Integer(id v){return OR6APISchemaCheck(v,@{@"type":@"integer",@"minimum":@0,@"maximum":@9007199254740991LL},@{});}
static BOOL Number(id v,double maximum){return OR6APISchemaCheck(v,@{@"type":@"number",@"minimum":@0,@"maximum":@(maximum)},@{});}
static BOOL Keys(NSDictionary*d,NSArray*required,NSArray*optional){if(![d isKindOfClass:NSDictionary.class])return NO;for(NSString*k in required)if(!d[k])return NO;for(NSString*k in d)if(![required containsObject:k]&&![optional containsObject:k])return NO;return YES;}
NSString *OR6API7HBase64(NSData *d){if(![d isKindOfClass:NSData.class]||d.length>65536)return nil;static const char table[]="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";const unsigned char*p=d.bytes;NSMutableData*out=[NSMutableData dataWithLength:4*((d.length+2)/3)];char*q=out.mutableBytes;for(NSUInteger i=0,j=0;i<d.length;i+=3){unsigned long a=p[i],b=i+1<d.length?p[i+1]:0,c=i+2<d.length?p[i+2]:0;q[j++]=table[a>>2];q[j++]=table[((a&3)<<4)|(b>>4)];q[j++]=i+1<d.length?table[((b&15)<<2)|(c>>6)]:'=';q[j++]=i+2<d.length?table[c&63]:'=';}return[[[NSString alloc]initWithData:out encoding:NSASCIIStringEncoding]autorelease];}
NSString *OR6API7HAccept(NSString *key){if(!Text(key,24,NO)||key.length!=24)return nil;NSData*d=[[key stringByAppendingString:@"258EAFA5-E914-47DA-95CA-C5AB0DC85B11"]dataUsingEncoding:NSASCIIStringEncoding];unsigned char b[CC_SHA1_DIGEST_LENGTH];CC_SHA1(d.bytes,(CC_LONG)d.length,b);return OR6API7HBase64([NSData dataWithBytes:b length:sizeof(b)]);}
BOOL OR6API7HHandshake(NSData *data,NSString *key,NSError **error){
 if(![data isKindOfClass:NSData.class]||data.length>16384){Fail(error,@"size_limit");return NO;}NSString*s=[[[NSString alloc]initWithData:data encoding:NSASCIIStringEncoding]autorelease];if(!s||![s hasSuffix:@"\r\n\r\n"]||[s rangeOfString:@"\0"].location!=NSNotFound){Fail(error,@"unknown_wire_shape");return NO;}
 NSArray*lines=[s componentsSeparatedByString:@"\r\n"];NSString*first=lines[0];if(![first hasPrefix:@"HTTP/1.1 101 "]){NSString*code=[first hasPrefix:@"HTTP/1.1 401 "]?@"not_authenticated":[first hasPrefix:@"HTTP/1.1 403 "]?@"service_challenge":[first hasPrefix:@"HTTP/1.1 429 "]?@"rate_limited":@"unknown_wire_shape";Fail(error,code);return NO;}NSMutableDictionary*h=[NSMutableDictionary dictionary];for(NSUInteger i=1;i+2<lines.count;i++){NSString*line=lines[i];NSRange r=[line rangeOfString:@":"];if(!r.length||!r.location||[line hasPrefix:@" "]||[line hasPrefix:@"\t"]){Fail(error,@"unknown_wire_shape");return NO;}NSString*k=[[line substringToIndex:r.location]lowercaseString],*v=[[line substringFromIndex:r.location+1]stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];if(h[k]||k.length>128||v.length>8192||[k rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789-_"]invertedSet]].location!=NSNotFound||[v rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound){Fail(error,@"unknown_wire_shape");return NO;}h[k]=v;}
 BOOL upgrade=NO;for(NSString*t in [h[@"connection"]componentsSeparatedByString:@","])if([[[t stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]lowercaseString]isEqual:@"upgrade"])upgrade=YES;
 if(!upgrade||![h[@"upgrade"]lowercaseString]||![[h[@"upgrade"]lowercaseString]isEqual:@"websocket"]||![h[@"sec-websocket-accept"]isEqual:OR6API7HAccept(key)]||![h[@"sec-websocket-protocol"]isEqual:@"chatgpt-dictation"]||h[@"sec-websocket-extensions"]||h[@"content-length"]||h[@"transfer-encoding"]){Fail(error,@"unknown_wire_shape");return NO;}return YES;
}
static BOOL CloseCode(NSUInteger n){return(n>=1000&&n<=1014&&n!=1004&&n!=1005&&n!=1006)||(n>=3000&&n<=4999);}
NSData *OR6API7HFrame(NSUInteger op,NSData *payload,NSData *mask,NSError **error){
 if(![@[@1,@8,@9,@10]containsObject:@(op)]||![payload isKindOfClass:NSData.class]||payload.length>32768||mask.length!=4||((op&8)&&payload.length>125))return Fail(error,@"invalid_request");NSMutableData*r=[NSMutableData data];unsigned char h[4]={(unsigned char)(0x80|op),(unsigned char)(0x80|(payload.length<126?payload.length:126)),(unsigned char)(payload.length>>8),(unsigned char)payload.length};[r appendBytes:h length:payload.length<126?2:4];[r appendData:mask];NSMutableData*masked=[[payload mutableCopy]autorelease];unsigned char*p=masked.mutableBytes;const unsigned char*m=mask.bytes;for(NSUInteger i=0;i<masked.length;i++)p[i]^=m[i%4];[r appendData:masked];return r;
}
NSData *OR6API7HRandomFrame(NSUInteger op,NSData *payload,NSError **error){unsigned char m[4];if(SecRandomCopyBytes(kSecRandomDefault,4,m)!=0)return Fail(error,@"unavailable");return OR6API7HFrame(op,payload,[NSData dataWithBytes:m length:4],error);}
@implementation OR6API7HFrames
- (id)init{if((self=[super init])){_buffer=[NSMutableData new];_fragment=[NSMutableData new];}return self;}
- (NSArray *)append:(NSData *)bytes error:(NSError **)error{
 if(![bytes isKindOfClass:NSData.class]||bytes.length>65536||_buffer.length+bytes.length>131072)return Fail(error,@"size_limit");if(_closed&&bytes.length)return Fail(error,@"unknown_wire_shape");[_buffer appendData:bytes];NSMutableArray*out=[NSMutableArray array];
 while(_buffer.length>=2){const unsigned char*p=_buffer.bytes;BOOL fin=(p[0]&0x80)!=0;NSUInteger op=p[0]&15,tag=p[1]&127,head=2;unsigned long long n=tag;if((p[0]&0x70)||(p[1]&0x80)||![@[@0,@1,@8,@9,@10]containsObject:@(op)])return Fail(error,@"unknown_wire_shape");if(tag==126){if(_buffer.length<4)break;n=((NSUInteger)p[2]<<8)|p[3];head=4;if(n<126)return Fail(error,@"unknown_wire_shape");}else if(tag==127){if(_buffer.length<10)break;n=0;for(NSUInteger i=2;i<10;i++)n=(n<<8)|p[i];head=10;if((p[2]&0x80)||n<=65535)return Fail(error,@"unknown_wire_shape");}if(n>65536||((op&8)&&(!fin||n>125)))return Fail(error,@"size_limit");if(_buffer.length<head+n)break;if(++_count>8192)return Fail(error,@"size_limit");NSData*payload=[NSData dataWithBytes:p+head length:(NSUInteger)n];[_buffer replaceBytesInRange:NSMakeRange(0,head+(NSUInteger)n)withBytes:NULL length:0];
  if(op==8){if(n==1)return Fail(error,@"unknown_wire_shape");if(n>=2){const unsigned char*c=payload.bytes;NSUInteger code=((NSUInteger)c[0]<<8)|c[1];NSData*reason=[payload subdataWithRange:NSMakeRange(2,(NSUInteger)n-2)];if(!CloseCode(code)||![[[NSString alloc]initWithData:reason encoding:NSUTF8StringEncoding]autorelease])return Fail(error,@"unknown_wire_shape");}[_fragment setLength:0];_fragmentOpcode=0;_closed=YES;[out addObject:@{@"kind":@"close",@"data":payload}];if(_buffer.length)return Fail(error,@"unknown_wire_shape");break;}
  if(op==9||op==10){[out addObject:@{@"kind":op==9?@"ping":@"pong",@"data":payload}];continue;}
  if(op==0){if(!_fragmentOpcode)return Fail(error,@"unknown_wire_shape");if(_fragment.length+payload.length>65536)return Fail(error,@"size_limit");[_fragment appendData:payload];if(fin){payload=[NSData dataWithData:_fragment];[_fragment setLength:0];_fragmentOpcode=0;}else continue;}
  else{if(_fragmentOpcode)return Fail(error,@"unknown_wire_shape");if(!fin){_fragmentOpcode=op;[_fragment setData:payload];continue;}}
  NSString*s=[[[NSString alloc]initWithData:payload encoding:NSUTF8StringEncoding]autorelease];if(!s)return Fail(error,@"unknown_wire_shape");[out addObject:@{@"kind":@"text",@"data":payload}];
 }return out;
}
- (void)dealloc{[_buffer release];[_fragment release];[super dealloc];}
@end
static BOOL ErrorBody(id raw){return Keys(raw,@[@"code",@"message",@"retryable"],@[])&&Text(raw[@"code"],128,NO)&&Text(raw[@"message"],4096,YES)&&BoolH(raw[@"retryable"]);}
static BOOL SessionBody(id s){return Keys(s,@[@"session_id",@"status",@"config"],@[])&&Text(s[@"session_id"],128,NO)&&[@[@"active",@"closed"]containsObject:s[@"status"]]&&Keys(s[@"config"],@[@"provider_mode",@"transcript_delivery_mode"],@[])&&[s[@"config"][@"provider_mode"]isEqual:@"streaming_sse"]&&[s[@"config"][@"transcript_delivery_mode"]isEqual:@"segment"];}
@implementation OR6API7HSession
- (id)init{if((self=[super init])){_sequence=-1;_order=[NSMutableArray new];_utterances=[NSMutableDictionary new];}return self;}
- (NSString *)text:(BOOL)partial error:(NSError **)error{NSMutableArray*a=[NSMutableArray array];NSUInteger length=0;for(NSString*k in _order){NSDictionary*u=_utterances[k];NSString*s=u[@"final"]?: (partial?u[@"partial"]:nil);if(s.length){length+=s.length+(a.count?1:0);if(length>16000)return Fail(error,@"size_limit");[a addObject:s];}}return[a componentsJoinedByString:@" "];}
- (NSDictionary *)consume:(NSDictionary *)m closing:(BOOL)closing error:(NSError **)error{
 if(![m isKindOfClass:NSDictionary.class]||!Text(m[@"type"],64,NO)||!Integer(m[@"sequence_no"])||_closed||++_count>8192)return Fail(error,@"unknown_wire_shape");NSString*t=m[@"type"];NSArray*base=@[@"type",@"sequence_no"];BOOL valid=NO,stop=NO,change=NO;
 if([t isEqual:@"session.started"]||[t isEqual:@"session.updated"]){valid=Keys(m,[@[@"session"]arrayByAddingObjectsFromArray:base],[t isEqual:@"session.started"]?@[@"frame_rtt_supported"]:@[])&&SessionBody(m[@"session"])&&(!m[@"frame_rtt_supported"]||BoolH(m[@"frame_rtt_supported"]));}
 else if([t isEqual:@"session.stop_requested"])valid=Keys(m,[@[@"reason",@"grace_period_ms"]arrayByAddingObjectsFromArray:base],@[])&&Text(m[@"reason"],256,YES)&&Number(m[@"grace_period_ms"],300000);
 else if([t isEqual:@"speech.started"]||[t isEqual:@"speech.stopped"])valid=Keys(m,[@[@"utterance_id"]arrayByAddingObjectsFromArray:base],@[])&&Text(m[@"utterance_id"],128,NO);
 else if([@[@"transcript.delta",@"transcript.segment",@"transcript.final"]containsObject:t])valid=Keys(m,[@[@"utterance_id",@"revision",@"text"]arrayByAddingObjectsFromArray:base],@[])&&Text(m[@"utterance_id"],128,NO)&&Integer(m[@"revision"])&&Text(m[@"text"],16000,YES);
 else if([t isEqual:@"transcript.failed"])valid=Keys(m,[@[@"error"]arrayByAddingObjectsFromArray:base],@[@"utterance_id"])&&(!m[@"utterance_id"]||m[@"utterance_id"]==NSNull.null||Text(m[@"utterance_id"],128,NO))&&ErrorBody(m[@"error"]);
 else if([t isEqual:@"session.error"])valid=Keys(m,[@[@"fatal",@"error"]arrayByAddingObjectsFromArray:base],@[])&&BoolH(m[@"fatal"])&&ErrorBody(m[@"error"]);
 else if([t isEqual:@"audio.frame_processed"])valid=Keys(m,[@[@"rtt_sample_id",@"frame_id",@"server_duration_ms"]arrayByAddingObjectsFromArray:base],@[])&&Integer(m[@"rtt_sample_id"])&&Integer(m[@"frame_id"])&&Number(m[@"server_duration_ms"],300000);
 else if([@[@"asset.ready",@"asset.committed",@"asset.failed"]containsObject:t])valid=Keys(m,base,@[]);
 if(!valid)return Fail(error,@"unknown_wire_shape");long long seq=[m[@"sequence_no"]longLongValue];if(seq<_sequence)return @{@"changed":@NO,@"stop":@NO};if(seq==_sequence){if(![_last isEqual:m])return Fail(error,@"unknown_wire_shape");return @{@"changed":@NO,@"stop":@NO};}[_last release];_last=[m copy];_sequence=seq;
 if([t isEqual:@"session.started"]){if(_started||![m[@"session"][@"status"]isEqual:@"active"])return Fail(error,@"unknown_wire_shape");_started=YES;_sessionID=[m[@"session"][@"session_id"]copy];change=YES;}
 else{if(!_started)return Fail(error,@"unknown_wire_shape");if([t isEqual:@"session.updated"]){if(![_sessionID isEqual:m[@"session"][@"session_id"]])return Fail(error,@"unknown_wire_shape");if([m[@"session"][@"status"]isEqual:@"closed"]){if(!closing)return Fail(error,@"upstream_error");for(NSDictionary*u in _utterances.allValues)if(!u[@"final"]&&(u[@"partial"]||[u[@"speech"]isEqual:@YES]||[u[@"delta"]isEqual:@YES]))return Fail(error,@"unknown_wire_shape");_closed=YES;change=YES;}}
  else if([t isEqual:@"session.stop_requested"])stop=YES;
  else if([t isEqual:@"transcript.failed"]||([t isEqual:@"session.error"]&&[m[@"fatal"]boolValue]))return Fail(error,@"upstream_error");
  else if(m[@"utterance_id"]){NSString*k=m[@"utterance_id"];NSMutableDictionary*u=_utterances[k];if(!u){if(_order.count>=128)return Fail(error,@"size_limit");u=[NSMutableDictionary dictionary];_utterances[k]=u;[_order addObject:k];}
   if([t hasPrefix:@"speech."])u[@"speech"]=@YES;
   else if([t isEqual:@"transcript.delta"])u[@"delta"]=@YES;
   else if([t isEqual:@"transcript.final"]){if(!u[@"finalRevision"]||[m[@"revision"]longLongValue]>=[u[@"finalRevision"]longLongValue]){u[@"finalRevision"]=m[@"revision"];u[@"final"]=m[@"text"];[u removeObjectForKey:@"partial"];change=YES;}}
   else if([t isEqual:@"transcript.segment"]&&!u[@"final"]&&(!u[@"partialRevision"]||[m[@"revision"]longLongValue]>=[u[@"partialRevision"]longLongValue])){u[@"partialRevision"]=m[@"revision"];u[@"partial"]=m[@"text"];change=YES;}
  }
 }
 if(![self text:YES error:error])return nil;return @{@"changed":@(change),@"stop":@(stop)};
}
- (BOOL)started{return _started;}- (BOOL)closed{return _closed;}
- (void)dealloc{[_order release];[_utterances release];[_last release];[_sessionID release];[super dealloc];}
@end
