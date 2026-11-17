#import "OR6API5BTransfer.h"
#import "OR6API5BPolicy.h"
#import "../OR6APIWebAdapter.h"
#import "../OR6APIHTTP.h"
#import <dispatch/dispatch.h>
@interface OR6API5BTransferTask:NSObject<OR6APITask>{BOOL _cancelled;}
- (BOOL)cancelled;
@end
@implementation OR6API5BTransferTask
- (void)cancel{@synchronized(self){_cancelled=YES;}}
- (BOOL)cancelled{@synchronized(self){return _cancelled;}}
@end
@implementation OR6API5BTransfer
- (id)initWithAdapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots storageHosts:(NSSet*)hosts {
 if((self=[super init])){if(!adapter||!roots.length||![hosts isKindOfClass:NSSet.class]){[self release];return nil;}
  for(id h in hosts)if(![h isKindOfClass:NSString.class]||![h length]||[h length]>253||[h rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789.-"]invertedSet]].location!=NSNotFound){[self release];return nil;}
  _adapter=[adapter retain];_roots=[roots copy];NSMutableSet*snapshot=[NSMutableSet set];for(NSString*host in hosts)[snapshot addObject:[[host copy]autorelease]];_storageHosts=[snapshot copy];
 }return self;
}
- (id<OR6APITask>)request:(NSURLRequest*)request kind:(NSString*)kind file:(NSString*)file context:(NSDictionary*)ctx completion:(OR6APIReply)reply {
 ctx=OR6APIJSONSnapshot(ctx,4096);NSMutableURLRequest*frozen=[[request mutableCopy]autorelease];frozen.HTTPBody=[[request.HTTPBody copy]autorelease];frozen.allHTTPHeaderFields=OR6APIJSONSnapshot(request.allHTTPHeaderFields,16384);request=[[frozen copy]autorelease];OR6API5BTransferTask*task=[[[OR6API5BTransferTask alloc]init]autorelease];NSURL*u=request.URL;
 BOOL same=[u.host isEqual:@"chatgpt.com"],blob=[kind isEqual:@"blob"],process=[kind isEqual:@"process"],content=[kind isEqual:@"content"],estuary=[kind isEqual:@"upload-content"];
 BOOL route=NO;
 if(blob)route=[request.HTTPMethod isEqual:@"PUT"]&&!same&&[_storageHosts containsObject:u.host];
 else if(estuary)route=same&&[request.HTTPMethod isEqual:@"POST"]&&[u.path isEqual:@"/backend-api/estuary/upload_content_bytes"];
 else if(process)route=same&&[request.HTTPMethod isEqual:@"POST"]&&[u.path isEqual:@"/backend-api/files/process_upload_stream"]&&OR6API5BIdentifier(file);
 else if(content)route=same&&[request.HTTPMethod isEqual:@"GET"]&&[u.path isEqual:@"/backend-api/estuary/content"];
 else if([kind isEqual:@"json"]&&same){
  route=([request.HTTPMethod isEqual:@"POST"]&&[u.path isEqual:@"/backend-api/files"]&& !u.query)||([request.HTTPMethod isEqual:@"GET"]&&[u.path hasPrefix:@"/backend-api/files/download/"]&&OR6API5BIdentifier(u.path.lastPathComponent)&&[u.query isEqual:@"download_intent=false"]);
 }
 if(!NSThread.isMainThread||!OR6APISchemaCheck(ctx,@{@"type":@"object",@"properties":@{@"key":@{@"type":@"string",@"minLength":@1,@"maxLength":@256},@"generation":@{@"type":@"integer",@"minimum":@1}},@"required":@[@"key",@"generation"],@"additionalProperties":@NO},@{})||!route||![u.scheme isEqual:@"https"]||u.user||u.password||u.fragment||(u.port&&u.port.integerValue!=443)||u.absoluteString.length>8192||request.HTTPBody.length>8*1024*1024+16384){if(NSThread.isMainThread)reply(nil,OR6APIError(@"invalid_request",@"none"));else dispatch_async(dispatch_get_main_queue(),^{reply(nil,OR6APIError(@"invalid_request",@"none"));});return task;}
 NSSet*headers=[NSSet setWithArray:blob?@[@"content-type",@"x-ms-blob-type",@"x-ms-version",@"x-ms-blob-content-type"]:@[@"content-type",@"chatgpt-project-id",@"chatgpt-account-id",@"x-openai-attach-auth"]];
 for(NSString*k in request.allHTTPHeaderFields)if(![headers containsObject:k.lowercaseString]){if(NSThread.isMainThread)reply(nil,OR6APIError(@"invalid_request",@"none"));else dispatch_async(dispatch_get_main_queue(),^{reply(nil,OR6APIError(@"invalid_request",@"none"));});return task;}
 NSMutableURLRequest*r=[[request mutableCopy]autorelease];[r setValue:content?@"*/*":process?@"application/x-ndjson":@"application/json" forHTTPHeaderField:@"Accept"];
 NSUInteger generation=_adapter.credentialGeneration;
 // Signed off-origin uploads never receive account authorization or cookies.
 BOOL authenticated=!blob;NSURLRequest*authorized=authenticated?[_adapter authorizeChatRequest:r expectedKey:ctx[@"key"]]:r;
 if(!authorized||generation!=_adapter.credentialGeneration||![ctx[@"key"]isEqual:_adapter.contextKey]){reply(nil,OR6APIError(@"not_authenticated",@"none"));return task;}
 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{NSAutoreleasePool*pool=[NSAutoreleasePool new];NSError*network=nil;__block NSInteger status=0;__block NSDictionary*ready=nil;__block NSError*processingError=nil;NSMutableData*buffer=[NSMutableData data];
  NSDictionary*response=OR6APIHTTPPerform(authorized,_roots,[NSSet setWithObject:u.host],@{@"connectTimeout":@15,@"idleTimeout":@35,@"overallTimeout":@120,@"maxRequestBytes":@(8*1024*1024+81920),@"maxDecodedBytes":@(content?8*1024*1024:262144),@"collectBody":@(!process),@"acceptEncoding":@"identity"},^BOOL{return task.cancelled;},^BOOL(NSInteger code,NSDictionary*h){(void)h;status=code;return YES;},process?^BOOL(NSData*b){
   if(status!=200)return YES;if(buffer.length+b.length>262144){processingError=OR6APIError(@"size_limit",@"possible");return NO;}[buffer appendData:b];NSError*e=nil;ready=OR6API5BProcessing(buffer,file,NO,&e);processingError=e;return !ready&&!processingError;
  }:nil,&network);
  id sent=response[@"requestBytesSent"]?:network.userInfo[@"requestBytesSent"];NSString*dispatch=[sent isKindOfClass:NSNumber.class]&&![sent unsignedLongLongValue]?@"none":@"possible";NSError*error=nil;NSDictionary*result=nil;
  BOOL deliberateReady=process&&status==200&&ready&&[network.domain isEqual:OR6APIHTTPErrorDomain]&&network.code==OR6APIHTTPConsumerStopped;
  if(task.cancelled)error=OR6APIError(@"cancelled",dispatch);
  else if(processingError)error=OR6APIError(processingError.userInfo[@"code"],@"possible");
  else if(!response&&!deliberateReady)error=OR6APIError(@"network_unavailable",dispatch);
  else if(response&&![response[@"certificateVerified"]boolValue])error=OR6APIError(@"tls",dispatch);
  else if(status<200||status>299)error=OR6APIError(status==401?@"not_authenticated":status==403?@"service_challenge":status==429?@"rate_limited":status==404?@"not_found":@"upstream_error",@"possible");
  else if(process){NSError*e=nil;NSDictionary*v=ready?:OR6API5BProcessing(buffer,file,YES,&e);if(!v)error=OR6APIError(e.userInfo[@"code"]?:@"uncertain_outcome",@"possible");else result=@{@"status":@(status),@"json":v};}
  else if(blob||estuary)result=@{@"status":@(status)};
  else if(content){NSData*d=response[@"data"];if(!d.length)error=OR6APIError(@"invalid_response",@"possible");else result=@{@"status":@(status),@"bytes":d};}
  else{id v=[NSJSONSerialization JSONObjectWithData:response[@"data"]?:[NSData data] options:0 error:NULL];if(![v isKindOfClass:NSDictionary.class])error=OR6APIError(@"unknown_wire_shape",@"possible");else result=@{@"status":@(status),@"json":v};}
  dispatch_async(dispatch_get_main_queue(),^{
   if(task.cancelled){reply(nil,OR6APIError(@"cancelled",dispatch));return;}
   if(generation!=_adapter.credentialGeneration||![ctx[@"key"]isEqual:_adapter.contextKey]){reply(nil,OR6APIError(@"stale_context",dispatch));return;}
   if(!error&&authenticated&&![_adapter acceptChatCookies:response[@"setCookies"]?:@[] expectedKey:ctx[@"key"]generation:generation]){reply(nil,OR6APIError(@"storage_failure",@"possible"));return;}
   if(task.cancelled){reply(nil,OR6APIError(@"cancelled",dispatch));return;}
   if(generation!=_adapter.credentialGeneration||![ctx[@"key"]isEqual:_adapter.contextKey]){reply(nil,OR6APIError(@"stale_context",dispatch));return;}reply(result,error);
  });[pool drain];
 });return task;
}
- (void)dealloc{[_adapter release];[_roots release];[_storageHosts release];[super dealloc];}
@end
