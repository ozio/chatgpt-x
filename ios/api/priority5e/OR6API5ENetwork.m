#import "OR6API5ENetwork.h"
#import "OR6API5EPolicy.h"
#import "../OR6APIWebAdapter.h"
#import "../OR6APIHTTP.h"
#import <dispatch/dispatch.h>
static BOOL Context(id v){return[v isKindOfClass:NSDictionary.class]&&[v[@"key"]isKindOfClass:NSString.class]&&[v[@"key"]length]&&[v[@"key"]length]<=256&&OR6APISchemaCheck(v[@"generation"],@{@"type":@"integer",@"minimum":@1,@"maximum":@2147483647},@{});}
@interface OR6API5ENetworkTask:NSObject<OR6APITask>{BOOL _cancelled;}
- (BOOL)cancelled;
@end
@implementation OR6API5ENetworkTask
- (void)cancel{@synchronized(self){_cancelled=YES;}}
- (BOOL)cancelled{@synchronized(self){return _cancelled;}}
@end
@implementation OR6API5ENetwork
- (id)initWithAdapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots{if((self=[super init])){if(!adapter||![roots isKindOfClass:NSString.class]||!roots.length){[self release];return nil;}_adapter=[adapter retain];_roots=[roots copy];}return self;}
- (BOOL)current:(NSDictionary*)ctx generation:(NSUInteger)generation task:(OR6API5ENetworkTask*)task{return!task.cancelled&&generation==_adapter.credentialGeneration&&[ctx[@"key"]isEqual:_adapter.contextKey];}
- (void)load:(NSURLRequest*)request context:(NSDictionary*)ctx generation:(NSUInteger)generation task:(OR6API5ENetworkTask*)task public:(BOOL)public reply:(OR6APIReply)reply{
 if(![self current:ctx generation:generation task:task]){reply(nil,OR6APIError(task.cancelled?@"cancelled":@"stale_context",@"none"));return;}
 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{NSAutoreleasePool*pool=[NSAutoreleasePool new];NSError*wire=nil;NSDictionary*response=OR6APIHTTPPerform(request,_roots,[NSSet setWithObject:request.URL.host],@{@"connectTimeout":@15,@"idleTimeout":@25,@"overallTimeout":@45,@"collectBody":@YES,@"maxRequestBytes":@(512*1024),@"maxDecodedBytes":@(1024*1024)},^BOOL{return task.cancelled;},nil,nil,&wire);id count=response[@"requestBytesSent"]?:wire.userInfo[@"requestBytesSent"];NSString*sent=[count isKindOfClass:NSNumber.class]&&![count unsignedLongLongValue]?@"none":@"possible";NSInteger status=[response[@"status"]integerValue];NSError*error=nil;id json=nil;
 if(!response)error=OR6APIError(task.cancelled?@"cancelled":@"network_unavailable",sent);else if(![response[@"certificateVerified"]isEqual:@YES])error=OR6APIError(@"tls",sent);else if((status<200||status>299)&&!(status==404&&[request.HTTPMethod isEqual:@"GET"]&&!public))error=OR6APIError(status==401?@"not_authenticated":status==403?@"service_challenge":status==409?@"conflict":status==429?@"rate_limited":@"upstream_error",sent);else{NSData*d=response[@"data"];json=d.length?[NSJSONSerialization JSONObjectWithData:d options:0 error:NULL]:NSNull.null;if((!d.length&&status!=204&&status!=404)||(d.length&&![json isKindOfClass:NSDictionary.class]&&![json isKindOfClass:NSArray.class]))error=OR6APIError(@"unknown_wire_shape",sent);}
 NSDictionary*snapshot=error?nil:OR6APIJSONSnapshot(@{@"status":@(status),@"json":json?:NSNull.null},1024*1024);NSError*safe=error?OR6APIError(error.userInfo[@"code"],error.userInfo[@"dispatch"]):nil;NSArray*cookies=[response[@"setCookies"]isKindOfClass:NSArray.class]?[[response[@"setCookies"]copy]autorelease]:@[];
 dispatch_async(dispatch_get_main_queue(),^{
  if(![self current:ctx generation:generation task:task]){reply(nil,OR6APIError(task.cancelled?@"cancelled":@"stale_context",sent));return;}
  if(safe){reply(nil,safe);return;}if(!snapshot){reply(nil,OR6APIError(@"unknown_wire_shape",sent));return;}
  if(!public){BOOL accepted=[_adapter acceptChatCookies:cookies expectedKey:ctx[@"key"]generation:generation];if(![self current:ctx generation:generation task:task]){reply(nil,OR6APIError(task.cancelled?@"cancelled":@"stale_context",sent));return;}if(!accepted){reply(nil,OR6APIError(@"storage_failure",sent));return;}}
  reply(snapshot,nil);
 });[pool drain];
 });
}
- (id<OR6APITask>)request:(NSURLRequest*)request context:(NSDictionary*)ctx completion:(OR6APIReply)reply{
 OR6API5ENetworkTask*task=[[[OR6API5ENetworkTask alloc]init]autorelease];if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{reply(nil,OR6APIError(@"invalid_request",@"none"));});return task;}request=[[request copy]autorelease];ctx=OR6APIJSONSnapshot(ctx,4096);if(!Context(ctx)||!OR6API5EAllowedRequest(request)){reply(nil,OR6APIError(@"invalid_request",@"none"));return task;}NSUInteger generation=_adapter.credentialGeneration;NSMutableURLRequest*r=[[request mutableCopy]autorelease];[r setValue:@"https://chatgpt.com"forHTTPHeaderField:@"Origin"];[r setValue:@"https://chatgpt.com/"forHTTPHeaderField:@"Referer"];NSURLRequest*authorized=[_adapter authorizeChatRequest:r expectedKey:ctx[@"key"]];if(!authorized||![self current:ctx generation:generation task:task]){reply(nil,OR6APIError(@"not_authenticated",@"none"));return task;}[self load:[[authorized copy]autorelease]context:ctx generation:generation task:task public:NO reply:reply];return task;
}
- (void)dealloc{[_adapter release];[_roots release];[super dealloc];}
@end
