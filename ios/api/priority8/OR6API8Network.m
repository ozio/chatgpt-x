#import "OR6API8Network.h"
#import "OR6API8Policy.h"
#import "../OR6APIWebAdapter.h"
#import "../OR6APIHTTP.h"
#import <dispatch/dispatch.h>
#import <CommonCrypto/CommonDigest.h>
@interface OR6API8NetworkTask:NSObject<OR6APITask>{BOOL _cancelled;}
- (BOOL)cancelled;
@end
@implementation OR6API8NetworkTask
- (void)cancel{@synchronized(self){_cancelled=YES;}}
- (BOOL)cancelled{@synchronized(self){return _cancelled;}}
@end
static NSString*HashUpload8(NSData*d){unsigned char h[CC_SHA256_DIGEST_LENGTH];CC_SHA256(d.bytes,(CC_LONG)d.length,h);NSMutableString*s=[NSMutableString string];for(NSUInteger n=0;n<sizeof(h);n++)[s appendFormat:@"%02x",h[n]];return s;}
static BOOL UploadHeader8(NSString*k){k=k.lowercaseString;return[k isEqual:@"content-type"]||[k hasPrefix:@"x-ms-"]||[k hasPrefix:@"x-amz-"];}
static NSString*UploadFingerprint8(NSURLRequest*r){NSMutableArray*parts=[NSMutableArray arrayWithObjects:r.HTTPMethod?:@"",r.URL.absoluteString?:@"",HashUpload8(r.HTTPBody?:[NSData data]),nil];for(NSString*k in [[r.allHTTPHeaderFields allKeys]sortedArrayUsingSelector:@selector(compare:)])[parts addObject:@[k,r.allHTTPHeaderFields[k]]];return HashUpload8([NSJSONSerialization dataWithJSONObject:parts options:0 error:NULL]);}
@implementation OR6API8Network
- (BOOL)admitSignedUploadRequest:(NSURLRequest*)r file:(NSString*)file context:(NSDictionary*)ctx{
 // Private capability minted only from an authenticated /files upload reply.
 // Bind the exact request instead of guessing a service storage/CDN hostname.
 NSURL*u=r.URL;BOOL headersOkay=r.allHTTPHeaderFields.count<=16;
 for(NSString*k in r.allHTTPHeaderFields){NSString*v=r.allHTTPHeaderFields[k];if(!UploadHeader8(k)||![v isKindOfClass:NSString.class]||v.length>4096||[v rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound)headersOkay=NO;}
 if(!NSThread.isMainThread||!OR6API8RemoteID(file)||![ctx[@"key"]isEqual:_adapter.contextKey]||![r.HTTPMethod isEqual:@"PUT"]||!r.HTTPBody.length||r.HTTPBody.length>8*1024*1024||r.HTTPBodyStream||!headersOkay||![u.scheme isEqual:@"https"]||u.user||u.password||u.fragment||(u.port&&u.port.integerValue!=443)||u.absoluteString.length>8192||[u.host isEqual:@"chatgpt.com"])return NO;
 if(![_storageHosts containsObject:u.host]){NSArray*labels=[u.host componentsSeparatedByString:@"."];NSString*tld=labels.lastObject;NSCharacterSet*letters=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz"],*dns=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789-"];if(labels.count<2||u.host.length>253||tld.length<2||[tld rangeOfCharacterFromSet:letters.invertedSet].location!=NSNotFound||[@[@"local",@"localhost",@"internal",@"invalid",@"test",@"example",@"onion"]containsObject:tld])return NO;for(NSString*l in labels)if(!l.length||l.length>63||[l hasPrefix:@"-"]||[l hasSuffix:@"-"]||[l rangeOfCharacterFromSet:dns.invertedSet].location!=NSNotFound)return NO;}
 if(!_signedUploads)_signedUploads=[NSMutableDictionary new];for(NSString*k in [[_signedUploads.allKeys copy]autorelease]){NSDictionary*g=_signedUploads[k];if([g[@"deadline"]doubleValue]<NSDate.timeIntervalSinceReferenceDate||![g[@"key"]isEqual:ctx[@"key"]]||[g[@"credential"]unsignedIntegerValue]!=_adapter.credentialGeneration)[_signedUploads removeObjectForKey:k];}
 if(_signedUploads.count>=8||_signedUploads[file])return NO;
 _signedUploads[file]=@{@"hash":UploadFingerprint8(r),@"key":ctx[@"key"],@"generation":ctx[@"generation"]?:@0,@"credential":@(_adapter.credentialGeneration),@"deadline":@(NSDate.timeIntervalSinceReferenceDate+120)};return YES;
}
- (NSDictionary*)diagnostics{return _diagnostics?:@{};}
- (id)initWithAdapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots storageHosts:(NSSet*)hosts {
 if((self=[super init])){if(!adapter||!roots.length||![hosts isKindOfClass:NSSet.class]){[self release];return nil;}
  for(id h in hosts)if(![h isKindOfClass:NSString.class]||![h length]||[h length]>253||[h rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789.-"]invertedSet]].location!=NSNotFound){[self release];return nil;}
  _adapter=[adapter retain];_roots=[roots copy];_storageHosts=[hosts copy];
 }return self;
}
- (id<OR6APITask>)request:(NSURLRequest*)request kind:(NSString*)kind file:(NSString*)file context:(NSDictionary*)ctx completion:(OR6APIReply)reply {
 OR6API8NetworkTask*task=[[[OR6API8NetworkTask alloc]init]autorelease];if(!NSThread.isMainThread){reply(nil,OR6APIError(@"invalid_request",@"none"));return task;}NSURL*u=request.URL;
 BOOL same=[u.host isEqual:@"chatgpt.com"],blob=[kind isEqual:@"blob"],process=[kind isEqual:@"process"],content=[kind isEqual:@"content"],estuary=[kind isEqual:@"upload-content"];
 BOOL route=NO;
 NSDictionary*grant=blob&&file?_signedUploads[file]:nil;BOOL granted=grant&&[grant[@"hash"]isEqual:UploadFingerprint8(request)]&&[grant[@"key"]isEqual:ctx[@"key"]]&&[grant[@"key"]isEqual:_adapter.contextKey]&&[grant[@"generation"]isEqual:ctx[@"generation"]]&&[grant[@"credential"]unsignedIntegerValue]==_adapter.credentialGeneration&&[grant[@"deadline"]doubleValue]>=NSDate.timeIntervalSinceReferenceDate;
 if(blob&&file)[_signedUploads removeObjectForKey:file];
 if(blob)route=[request.HTTPMethod isEqual:@"PUT"]&&!same&&([_storageHosts containsObject:u.host]||granted);
 else if(estuary)route=same&&[request.HTTPMethod isEqual:@"POST"]&&[u.path isEqual:@"/backend-api/estuary/upload_content_bytes"];
 else if(process)route=same&&[request.HTTPMethod isEqual:@"POST"]&&[u.path isEqual:@"/backend-api/files/process_upload_stream"]&&OR6API8RemoteID(file);
 else if(content)route=same&&[request.HTTPMethod isEqual:@"GET"]&&[u.path isEqual:@"/backend-api/estuary/content"];
 else if([kind isEqual:@"json"]&&same){
  route=([request.HTTPMethod isEqual:@"POST"]&&[u.path isEqual:@"/backend-api/files"]&& !u.query)||([request.HTTPMethod isEqual:@"GET"]&&[u.path hasPrefix:@"/backend-api/files/download/"]&&OR6API8RemoteID(u.path.lastPathComponent)&&[u.query isEqual:@"download_intent=false"]);
 }
 // Only non-secret shape facts: never retain URLs, query/signature or header values.
 NSMutableArray*unexpected=[NSMutableArray array];NSSet*allowed=[NSSet setWithArray:blob?@[@"content-type",@"x-ms-blob-type",@"x-ms-version",@"x-ms-blob-content-type"]:@[@"content-type"]];
 for(NSString*k in request.allHTTPHeaderFields)if(![allowed containsObject:k.lowercaseString]&&!(granted&&UploadHeader8(k)))[unexpected addObject:@"unexpected"];
 [_diagnostics release];_diagnostics=[@{@"kind":kind?:@"",@"mainThread":@(NSThread.isMainThread),@"routeAccepted":@(route),@"sameOrigin":@(same),@"https":@([u.scheme isEqual:@"https"]),@"hasUser":@(u.user!=nil),@"hasPassword":@(u.password!=nil),@"hasFragment":@(u.fragment!=nil),@"portAccepted":@(!u.port||u.port.integerValue==443),@"URLCharacters":@(u.absoluteString.length),@"bodyBytes":@(request.HTTPBody.length),@"headerCount":@(request.allHTTPHeaderFields.count),@"unexpectedHeaderCount":@(unexpected.count)}copy];
 if(!NSThread.isMainThread||!route||![u.scheme isEqual:@"https"]||u.user||u.password||u.fragment||(u.port&&u.port.integerValue!=443)||u.absoluteString.length>8192||request.HTTPBody.length>8*1024*1024+16384){reply(nil,OR6APIError(@"invalid_request",@"none"));return task;}
 NSSet*headers=[NSSet setWithArray:blob?@[@"content-type",@"x-ms-blob-type",@"x-ms-version",@"x-ms-blob-content-type"]:@[@"content-type"]];
 for(NSString*k in request.allHTTPHeaderFields)if(![headers containsObject:k.lowercaseString]&&!(granted&&UploadHeader8(k))){reply(nil,OR6APIError(@"invalid_request",@"none"));return task;}
 NSMutableURLRequest*r=[[request mutableCopy]autorelease];[r setValue:content?@"*/*":process?@"application/x-ndjson":@"application/json" forHTTPHeaderField:@"Accept"];
 NSDictionary*attemptFacts=[[_diagnostics copy]autorelease];NSUInteger generation=_adapter.credentialGeneration;
 // Signed off-origin uploads never receive account authorization or cookies.
 BOOL authenticated=!blob;NSURLRequest*authorized=authenticated?[_adapter authorizeChatRequest:r expectedKey:ctx[@"key"]]:r;
 if(!authorized||![ctx[@"key"]isEqual:_adapter.contextKey]){reply(nil,OR6APIError(@"not_authenticated",@"none"));return task;}
 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{NSAutoreleasePool*pool=[NSAutoreleasePool new];NSError*network=nil;__block NSInteger status=0;__block NSDictionary*ready=nil;__block NSError*processingError=nil;NSMutableData*buffer=[NSMutableData data];
  NSDictionary*response=OR6APIHTTPPerform(authorized,_roots,[NSSet setWithObject:u.host],@{@"connectTimeout":@15,@"idleTimeout":@35,@"overallTimeout":@120,@"maxRequestBytes":@(8*1024*1024+81920),@"maxDecodedBytes":@(content?8*1024*1024:262144),@"collectBody":@(!process),@"acceptEncoding":@"identity"},^BOOL{return task.cancelled;},^BOOL(NSInteger code,NSDictionary*h){(void)h;status=code;return YES;},process?^BOOL(NSData*b){
   if(status!=200)return YES;if(buffer.length+b.length>262144){[processingError release];processingError=[OR6APIError(@"size_limit",@"possible")retain];return NO;}[buffer appendData:b];NSError*e=nil;NSDictionary*next=[OR6API8Processing(buffer,file,NO,&e)retain];NSError*issue=[e retain];[ready release];ready=next;[processingError release];processingError=issue;return !ready&&!processingError;
  }:nil,&network);
  id sent=response[@"requestBytesSent"]?:network.userInfo[@"requestBytesSent"];NSString*dispatch=[sent isKindOfClass:NSNumber.class]&&![sent unsignedLongLongValue]?@"none":@"possible";NSError*error=nil;NSDictionary*result=nil;
  BOOL deliberateReady=process&&status==200&&ready&&[network.domain isEqual:OR6APIHTTPErrorDomain]&&network.code==OR6APIHTTPConsumerStopped;
  if(task.cancelled)error=OR6APIError(@"cancelled",dispatch);
  else if(processingError)error=OR6APIError(processingError.userInfo[@"code"],@"possible");
  else if(!response&&!deliberateReady)error=OR6APIError(@"network_unavailable",dispatch);
  else if(response&&![response[@"certificateVerified"]boolValue])error=OR6APIError(@"tls",dispatch);
  else if(status<200||status>299)error=OR6APIError(status==401?@"not_authenticated":status==403?@"service_challenge":status==429?@"rate_limited":status==404?@"not_found":@"upstream_error",@"possible");
  else if(process){NSError*e=nil;NSDictionary*v=ready?:OR6API8Processing(buffer,file,YES,&e);if(!v)error=OR6APIError(e.userInfo[@"code"]?:@"uncertain_outcome",@"possible");else result=@{@"status":@(status),@"json":v};}
  else if(blob||estuary)result=@{@"status":@(status)};
  else if(content){NSData*d=response[@"data"];if(!d.length)error=OR6APIError(@"invalid_response",@"possible");else result=@{@"status":@(status),@"bytes":d};}
  else{id v=[NSJSONSerialization JSONObjectWithData:response[@"data"]?:[NSData data] options:0 error:NULL];if(![v isKindOfClass:NSDictionary.class])error=OR6APIError(@"unknown_wire_shape",@"possible");else result=@{@"status":@(status),@"json":v};}
  BOOL hadReady=ready!=nil;dispatch_async(dispatch_get_main_queue(),^{
   NSMutableDictionary*f=[NSMutableDictionary dictionaryWithDictionary:attemptFacts];f[@"responseStatus"]=@(status);f[@"processingReady"]=@(hadReady);f[@"error"]=error.userInfo[@"code"]?:@"";[_diagnostics release];_diagnostics=[f copy];
   if(task.cancelled){reply(nil,OR6APIError(@"cancelled",dispatch));return;}
   if(generation!=_adapter.credentialGeneration||![ctx[@"key"]isEqual:_adapter.contextKey]){reply(nil,OR6APIError(@"stale_context",dispatch));return;}
   if(!error&&authenticated&&![_adapter acceptChatCookies:response[@"setCookies"]?:@[] expectedKey:ctx[@"key"]generation:generation]){reply(nil,OR6APIError(@"storage_failure",@"possible"));return;}
   reply(result,error);
  });[ready release];[processingError release];[pool drain];
 });return task;
}
- (void)dealloc{[_adapter release];[_roots release];[_storageHosts release];[_diagnostics release];[_signedUploads release];[super dealloc];}
@end
