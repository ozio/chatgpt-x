#import "OR6CodexTransport.h"
#import "../OR6APIHTTP.h"
#import "../priority7h/OR6API7HWire.h"
#import <Security/SecRandom.h>
#import <dispatch/dispatch.h>
#import <mach/mach_time.h>
#import <unistd.h>
static id WireFail(NSError**e,NSString*c){if(e)*e=OR6CodexError(c,NO);return nil;}
static double Clock(void){mach_timebase_info_data_t t;mach_timebase_info(&t);return(double)mach_absolute_time()*t.numer/t.denom/1e9;}
static void Drain(NSAutoreleasePool*p,NSError**e){NSError*saved=e?[*e retain]:nil;[p drain];[saved autorelease];}
static void Main(void(^b)(void)){if(NSThread.isMainThread)b();else dispatch_sync(dispatch_get_main_queue(),b);}
// Strict RFC6455 validation adapted from the existing companion reader. This
// session has separate auth, RPC tables, frame limits and duplex lifecycle.
BOOL OR6CodexHandshake(NSData *data,NSString *key,NSError **error){return OR6CodexHandshakeProtocol(data,key,nil,error);}
BOOL OR6CodexHandshakeProtocol(NSData *data,NSString *key,NSString *protocol,NSError **error){
 if(![data isKindOfClass:NSData.class]||data.length>16384){WireFail(error,@"size_limit");return NO;}NSString*s=[[[NSString alloc]initWithData:data encoding:NSASCIIStringEncoding]autorelease];if(!s||![s hasSuffix:@"\r\n\r\n"]||[s rangeOfString:@"\0"].location!=NSNotFound){WireFail(error,@"unknown_wire_shape");return NO;}
 NSArray*lines=[s componentsSeparatedByString:@"\r\n"];NSString*first=lines[0];if(![first hasPrefix:@"HTTP/1.1 101 "]){NSString*code=[first hasPrefix:@"HTTP/1.1 401 "]?@"not_authenticated":[first hasPrefix:@"HTTP/1.1 403 "]?@"service_challenge":[first hasPrefix:@"HTTP/1.1 429 "]?@"rate_limited":@"unknown_wire_shape";WireFail(error,code);return NO;}NSMutableDictionary*h=[NSMutableDictionary dictionary];for(NSUInteger i=1;i+2<lines.count;i++){NSString*line=lines[i];NSRange r=[line rangeOfString:@":"];if(!r.length||!r.location||[line hasPrefix:@" "]||[line hasPrefix:@"\t"]){WireFail(error,@"unknown_wire_shape");return NO;}NSString*k=[[line substringToIndex:r.location]lowercaseString],*v=[[line substringFromIndex:r.location+1]stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];if(h[k]||k.length>128||v.length>8192||[k rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789-_"]invertedSet]].location!=NSNotFound||[v rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound){WireFail(error,@"unknown_wire_shape");return NO;}h[k]=v;}
 BOOL upgrade=NO;for(NSString*t in [h[@"connection"]componentsSeparatedByString:@","])if([[[t stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]lowercaseString]isEqual:@"upgrade"])upgrade=YES;
 if(!upgrade||![h[@"upgrade"]lowercaseString]||![[h[@"upgrade"]lowercaseString]isEqual:@"websocket"]||![h[@"sec-websocket-accept"]isEqual:OR6API7HAccept(key)]||(protocol?![h[@"sec-websocket-protocol"]isEqual:protocol]:h[@"sec-websocket-protocol"]!=nil)||h[@"sec-websocket-extensions"]||h[@"content-length"]||h[@"transfer-encoding"]){WireFail(error,@"unknown_wire_shape");return NO;}return YES;
}
static BOOL CloseCode(NSUInteger n){return(n>=1000&&n<=1014&&n!=1004&&n!=1005&&n!=1006)||(n>=3000&&n<=4999);}
@implementation OR6CodexFrames
- (id)init{if((self=[super init])){_buffer=[NSMutableData new];_fragment=[NSMutableData new];}return self;}
- (NSArray *)append:(NSData *)bytes error:(NSError **)error{
 if(![bytes isKindOfClass:NSData.class]||bytes.length>65536||_buffer.length+bytes.length>(1024*1024+65536))return WireFail(error,@"size_limit");if(_closed&&bytes.length)return WireFail(error,@"unknown_wire_shape");[_buffer appendData:bytes];NSMutableArray*out=[NSMutableArray array];
 while(_buffer.length>=2){const unsigned char*p=_buffer.bytes;BOOL fin=(p[0]&0x80)!=0;NSUInteger op=p[0]&15,tag=p[1]&127,head=2;unsigned long long n=tag;if((p[0]&0x70)||(p[1]&0x80)||![@[@0,@1,@8,@9,@10]containsObject:@(op)])return WireFail(error,@"unknown_wire_shape");if(tag==126){if(_buffer.length<4)break;n=((NSUInteger)p[2]<<8)|p[3];head=4;if(n<126)return WireFail(error,@"unknown_wire_shape");}else if(tag==127){if(_buffer.length<10)break;n=0;for(NSUInteger i=2;i<10;i++)n=(n<<8)|p[i];head=10;if((p[2]&0x80)||n<=65535)return WireFail(error,@"unknown_wire_shape");}if(n>1024*1024||((op&8)&&(!fin||n>125)))return WireFail(error,@"size_limit");if(_buffer.length<head+n)break;if(++_count>8192)return WireFail(error,@"size_limit");NSData*payload=[NSData dataWithBytes:p+head length:(NSUInteger)n];[_buffer replaceBytesInRange:NSMakeRange(0,head+(NSUInteger)n)withBytes:NULL length:0];
  if(op==8){if(n==1)return WireFail(error,@"unknown_wire_shape");if(n>=2){const unsigned char*c=payload.bytes;NSUInteger code=((NSUInteger)c[0]<<8)|c[1];NSData*reason=[payload subdataWithRange:NSMakeRange(2,(NSUInteger)n-2)];if(!CloseCode(code)||![[[NSString alloc]initWithData:reason encoding:NSUTF8StringEncoding]autorelease])return WireFail(error,@"unknown_wire_shape");}[_fragment setLength:0];_fragmentOpcode=0;_closed=YES;[out addObject:@{@"kind":@"close",@"data":payload}];if(_buffer.length)return WireFail(error,@"unknown_wire_shape");break;}
  if(op==9||op==10){[out addObject:@{@"kind":op==9?@"ping":@"pong",@"data":payload}];continue;}
  if(op==0){if(!_fragmentOpcode)return WireFail(error,@"unknown_wire_shape");if(_fragment.length+payload.length>1024*1024)return WireFail(error,@"size_limit");[_fragment appendData:payload];if(fin){payload=[NSData dataWithData:_fragment];[_fragment setLength:0];_fragmentOpcode=0;}else continue;}
  else{if(_fragmentOpcode)return WireFail(error,@"unknown_wire_shape");if(!fin){_fragmentOpcode=op;[_fragment setData:payload];continue;}}
  NSString*s=[[[NSString alloc]initWithData:payload encoding:NSUTF8StringEncoding]autorelease];if(!s)return WireFail(error,@"unknown_wire_shape");[out addObject:@{@"kind":@"text",@"data":payload}];
 }return out;
}
- (void)dealloc{[_buffer release];[_fragment release];[super dealloc];}
@end

@implementation OR6CodexWSS
- (NSDictionary*)handshakeHeaders{return@{@"Authorization":[@"Bearer "stringByAppendingString:_token]};}
- (NSString*)handshakeProtocol{return nil;}
- (BOOL)channelIsCurrent{return YES;}
- (id)initWithURL:(NSURL*)u capabilityToken:(NSString*)t roots:(NSString*)r error:(NSError**)error{
 if(!(self=[super init]))return nil;
 NSString*h=u.host.lowercaseString;
 BOOL own=h.length&&![h isEqual:@"chatgpt.com"]&&![h hasSuffix:@".chatgpt.com"]&&![h isEqual:@"openai.com"]&&![h hasSuffix:@".openai.com"];
 if(![u.scheme isEqual:@"wss"]||!own||u.user||u.password||u.query||u.fragment||(u.port&&![u.port isEqual:@443])||!OR6CodexText(t,4096,NO)||[t rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~+/="]invertedSet]].location!=NSNotFound||!OR6CodexPath(r)){
  if(error)*error=OR6CodexError(@"invalid_request",NO);[self release];return nil;}
 _URL=[u copy];_token=[t copy];_roots=[r copy];_outgoing=[NSMutableArray new];return self;
}
- (BOOL)send:(NSDictionary*)m error:(NSError**)error{
 if(!NSThread.isMainThread){if(error)*error=OR6CodexError(@"invalid_request",NO);return NO;}
 NSDictionary*s=OR6APIJSONSnapshot(m,[@[@"turn/start",@"turn/steer"]containsObject:m[@"method"]]?262144:24576);@synchronized(self){if(!_running||_cancelled||!_upgraded||!s||_outgoing.count>=32||!OR6APIJSONSnapshot([_outgoing arrayByAddingObject:s?:@{}],1048576)||![self channelIsCurrent]){if(error)*error=OR6CodexError(@"unavailable",NO);return NO;}[_outgoing addObject:s];}return YES;
}
- (void)close{
 @synchronized(self){_cancelled=YES;_upgraded=NO;[_outgoing removeAllObjects];}
 // Break session/transport callback retention on the owning main thread.
 [_receiver release];_receiver=nil;[_closedCallback release];_closedCallback=nil;[_readyCallback release];_readyCallback=nil;
}
- (BOOL)cancelled:(NSUInteger)revision{@synchronized(self){return _cancelled||revision!=_revision;}}
- (BOOL)pumpKey:(NSString*)key revision:(NSUInteger)revision read:(OR6APIHTTPDuplexRead)read write:(OR6APIHTTPDuplexWrite)write error:(NSError**)error{
 NSMutableData*head=[NSMutableData data];OR6CodexFrames*frames=[[[OR6CodexFrames alloc]init]autorelease];BOOL upgraded=NO;double start=Clock(),lastPing=start;NSUInteger bytes=0;unsigned char buffer[4096];
 while(![self cancelled:revision]){
  NSAutoreleasePool*iteration=[NSAutoreleasePool new];BOOL okay=YES;
  __block BOOL current=NO;Main(^{current=[self channelIsCurrent];});if(!current){if(error)*error=OR6CodexError(@"stale_context",YES);Drain(iteration,error);return NO;}
  if(Clock()-start>80){if(error)*error=OR6CodexError(@"timeout",YES);Drain(iteration,error);return NO;}
  if(upgraded){NSArray*queue=nil;@synchronized(self){queue=[_outgoing copy];[_outgoing removeAllObjects];}
   for(NSDictionary*m in queue){NSData*raw=[NSJSONSerialization dataWithJSONObject:m options:0 error:NULL];NSData*f=OR6API7HRandomFrame(1,raw,error);if([self cancelled:revision]||!f||!write(f,error)){okay=NO;break;}}[queue release];
   if(okay&&Clock()-lastPing>10){NSData*f=OR6API7HRandomFrame(9,[NSData data],error);okay=f&&write(f,error);lastPing=Clock();}}
  if(!okay){Drain(iteration,error);return NO;}
  NSInteger n=read(buffer,sizeof(buffer),error);if(n==-2){Drain(iteration,error);usleep(10000);continue;}if(n<=0||n>(NSInteger)sizeof(buffer)){if(error&&!*error)*error=OR6CodexError(@"network_unavailable",YES);Drain(iteration,error);return NO;}if((bytes+=(NSUInteger)n)>8*1024*1024){if(error)*error=OR6CodexError(@"size_limit",YES);Drain(iteration,error);return NO;}
  NSData*incoming=[NSData dataWithBytes:buffer length:(NSUInteger)n];
  if(!upgraded){[head appendData:incoming];NSRange end=[head rangeOfData:[@"\r\n\r\n"dataUsingEncoding:NSASCIIStringEncoding]options:0 range:NSMakeRange(0,head.length)];if(!end.length){if(head.length>16384){if(error)*error=OR6CodexError(@"size_limit",YES);Drain(iteration,error);return NO;}Drain(iteration,error);continue;}NSUInteger boundary=NSMaxRange(end);if(!OR6CodexHandshakeProtocol([head subdataWithRange:NSMakeRange(0,boundary)],key,[self handshakeProtocol],error)){Drain(iteration,error);return NO;}incoming=[head subdataWithRange:NSMakeRange(boundary,head.length-boundary)];upgraded=YES;@synchronized(self){_upgraded=YES;}
   Main(^{if(![self cancelled:revision]&&[self channelIsCurrent]){void(^ready)(NSError*)=[[_readyCallback copy]autorelease];[_readyCallback release];_readyCallback=nil;if(ready)ready(nil);}});}
  NSArray*events=[frames append:incoming error:error];if(!events){Drain(iteration,error);return NO;}
  for(NSDictionary*f in events){NSString*k=f[@"kind"];if([k isEqual:@"ping"]){NSData*response=OR6API7HRandomFrame(10,f[@"data"],error);if(!response||!write(response,error)){okay=NO;break;}}else if([k isEqual:@"close"]){if(error)*error=OR6CodexError(@"network_unavailable",YES);okay=NO;break;}else if([k isEqual:@"text"]){NSDictionary*m=[NSJSONSerialization JSONObjectWithData:f[@"data"]options:0 error:NULL];if(![m isKindOfClass:NSDictionary.class]){if(error)*error=OR6CodexError(@"unknown_wire_shape",YES);okay=NO;break;}Main(^{if(![self cancelled:revision]&&[self channelIsCurrent]){void(^receive)(NSDictionary*)=[[_receiver copy]autorelease];if(receive)receive(m);}});}if([self cancelled:revision]){okay=NO;break;}}
  Drain(iteration,error);if(!okay)return NO;
 }
 if(error)*error=OR6CodexError(@"cancelled",YES);return NO;
}
- (void)open:(void(^)(NSDictionary*))receiver closed:(void(^)(NSError*))closed ready:(void(^)(NSError*))ready{
 if(!NSThread.isMainThread){if(ready)ready(OR6CodexError(@"invalid_request",NO));return;}
 if(![self channelIsCurrent]){if(ready)ready(OR6CodexError(@"stale_context",NO));return;}
 NSDictionary*headers=[[self handshakeHeaders]copy];if(!headers){if(ready)ready(OR6CodexError(@"stale_context",NO));return;}
 @synchronized(self){if(_running){if(ready)ready(OR6CodexError(@"conflict",NO));[headers release];return;}_running=YES;_cancelled=NO;_upgraded=NO;_revision++;}
 _receiver=[receiver copy];_closedCallback=[closed copy];_readyCallback=[ready copy];NSUInteger revision=_revision;
 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{NSAutoreleasePool*pool=[NSAutoreleasePool new];NSError*failure=nil;unsigned char random[16];NSDictionary*result=nil;
  __block BOOL current=NO;Main(^{current=[self channelIsCurrent];});
  if(!current)failure=OR6CodexError(@"stale_context",NO);
  else if(SecRandomCopyBytes(kSecRandomDefault,sizeof(random),random))failure=OR6CodexError(@"unavailable",NO);
  else {NSString*key=OR6API7HBase64([NSData dataWithBytes:random length:sizeof(random)]);NSString*address=[@"https"stringByAppendingString:[_URL.absoluteString substringFromIndex:3]];NSMutableURLRequest*request=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:address]];for(NSString*k in headers)[request setValue:headers[k]forHTTPHeaderField:k];[request setValue:@"13"forHTTPHeaderField:@"Sec-WebSocket-Version"];[request setValue:key forHTTPHeaderField:@"Sec-WebSocket-Key"];
   result=OR6APIHTTPDuplex(request,_roots,[NSSet setWithObject:_URL.host.lowercaseString],^BOOL{return[self cancelled:revision];},^BOOL(OR6APIHTTPDuplexRead read,OR6APIHTTPDuplexWrite write,NSError**e){return[self pumpKey:key revision:revision read:read write:write error:e];},&failure);}
  NSString*code=failure.userInfo[@"code"];NSError*safe=OR6CodexError(code?:@"network_unavailable",YES);if(result&&![result[@"certificateVerified"]isEqual:@YES])safe=OR6CodexError(@"tls",YES);
  Main(^{if(revision==_revision){void(^first)(NSError*)=[[_readyCallback copy]autorelease];void(^end)(NSError*)=[[_closedCallback copy]autorelease];@synchronized(self){_running=NO;}[self close];if(first)first(safe);else if(end)end(safe);}});[pool drain];});[headers release];
}
- (void)dealloc{[_URL release];[_token release];[_roots release];[_outgoing release];[_receiver release];[_closedCallback release];[_readyCallback release];[super dealloc];}
@end
