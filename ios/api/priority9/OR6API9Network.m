#import "OR6API9Network.h"
#import "../OR6APIWebAdapter.h"
#import "../OR6APIHTTP.h"
#import <dispatch/dispatch.h>
@interface OR6API9NetworkTask:NSObject<OR6APITask>{BOOL _cancelled;}
- (BOOL)cancelled;
@end
@implementation OR6API9NetworkTask
- (void)cancel{@synchronized(self){_cancelled=YES;}}
- (BOOL)cancelled{@synchronized(self){return _cancelled;}}
@end
@implementation OR6API9Network
- (id)initWithAdapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots{if((self=[super init])){if(!adapter||!roots.length){[self release];return nil;}_adapter=[adapter retain];_roots=[roots copy];}return self;}
- (id<OR6APITask>)performRequest:(NSURLRequest*)request context:(NSDictionary*)ctx completion:(void(^)(NSDictionary*,NSError*))reply{
 OR6API9NetworkTask*task=[[[OR6API9NetworkTask alloc]init]autorelease];NSURL*u=request.URL;
 BOOL stop=[u.path isEqual:@"/backend-api/stop_conversation"],transcribe=[u.path isEqual:@"/backend-api/transcribe"];
 if(!NSThread.isMainThread||(!stop&&!transcribe)||![u.scheme isEqual:@"https"]||![u.host isEqual:@"chatgpt.com"]||u.query||u.fragment||u.user||u.password||(u.port&&u.port.integerValue!=443)||![request.HTTPMethod isEqual:@"POST"]||!request.HTTPBody.length||request.HTTPBody.length>8*1024*1024){reply(nil,OR6APIError(@"invalid_request",@"none"));return task;}
 for(NSString*k in request.allHTTPHeaderFields)if(![@[@"content-type",@"x-conduit-token"]containsObject:k.lowercaseString]||(!stop&&[k.lowercaseString isEqual:@"x-conduit-token"])){reply(nil,OR6APIError(@"invalid_request",@"none"));return task;}
 NSMutableURLRequest*r=[[request mutableCopy]autorelease];[r setValue:@"application/json"forHTTPHeaderField:@"Accept"];[r setValue:@"LegacyClient/0.4 (iOS 6)"forHTTPHeaderField:@"User-Agent"];[r setValue:@"https://chatgpt.com"forHTTPHeaderField:@"Origin"];[r setValue:@"https://chatgpt.com/"forHTTPHeaderField:@"Referer"];
 NSURLRequest*authorized=[_adapter authorizeChatRequest:r expectedKey:ctx[@"key"]];NSUInteger generation=_adapter.credentialGeneration;if(!authorized){reply(nil,OR6APIError(@"not_authenticated",@"none"));return task;}
 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{NSAutoreleasePool*pool=[NSAutoreleasePool new];NSError*network=nil;NSDictionary*response=OR6APIHTTPPerform(authorized,_roots,[NSSet setWithObject:@"chatgpt.com"],@{@"connectTimeout":@15,@"idleTimeout":@35,@"overallTimeout":@(stop?45:90),@"collectBody":@YES,@"maxRequestBytes":@(8*1024*1024),@"maxDecodedBytes":@262144},^BOOL{return task.cancelled;},nil,nil,&network);
  NSInteger status=[response[@"status"]integerValue];NSError*error=nil;id bytes=response[@"requestBytesSent"]?:network.userInfo[@"requestBytesSent"];NSString*dispatch=[bytes isKindOfClass:NSNumber.class]&&![bytes unsignedLongLongValue]?@"none":@"possible";NSDictionary*json=nil;
  if(!response)error=OR6APIError(task.cancelled?@"cancelled":@"network_unavailable",dispatch);
  else if(![response[@"certificateVerified"]boolValue])error=OR6APIError(@"tls",dispatch);
  else if(status<200||status>299)error=OR6APIError(status==401?@"not_authenticated":status==403?@"service_challenge":status==429?@"rate_limited":@"upstream_error",@"possible");
  else{NSData*data=response[@"data"];if(data.length){id value=[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];if([value isKindOfClass:NSDictionary.class])json=value;else error=OR6APIError(@"unknown_wire_shape",@"possible");}}
  NSDictionary*result=@{@"status":@(status),@"json":json?:(id)NSNull.null,@"certificateVerified":response[@"certificateVerified"]?:@NO};
  dispatch_async(dispatch_get_main_queue(),^{
   if(task.cancelled){reply(nil,OR6APIError(@"cancelled",dispatch));return;}if(generation!=_adapter.credentialGeneration||![ctx[@"key"]isEqual:_adapter.contextKey]){reply(nil,OR6APIError(@"stale_context",dispatch));return;}
   if(!error&&![_adapter acceptChatCookies:response[@"setCookies"]?:@[] expectedKey:ctx[@"key"]generation:generation]){reply(nil,OR6APIError(@"storage_failure",@"possible"));return;}reply(error?nil:result,error);
  });[pool drain];
 });return task;
}
- (void)dealloc{[_adapter release];[_roots release];[super dealloc];}
@end
