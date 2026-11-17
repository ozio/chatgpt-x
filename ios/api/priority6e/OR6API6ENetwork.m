#import "OR6API6ENetwork.h"
#import "OR6API6EPolicy.h"
#import "../OR6APIWebAdapter.h"
#import "../OR6APIHTTP.h"
#import <dispatch/dispatch.h>
// This private category never returns the WebSession or its credentials.
@interface OR6APIWebAdapter(OR6API6EPrivateLogout)
- (BOOL)or6eSignOutForKey:(NSString*)key generation:(NSUInteger)generation user:(NSString*)user;
@end
@implementation OR6APIWebAdapter(OR6API6EPrivateLogout)
- (BOOL)or6eSignOutForKey:(NSString*)key generation:(NSUInteger)generation user:(NSString*)user{
 if(!NSThread.isMainThread||generation!=self.credentialGeneration||![key isEqual:self.contextKey]||![self chatMatchesOwner:user])return NO;return[_session signOut];
}
@end
@interface OR6API6ENetworkTask:NSObject<OR6APITask>{BOOL _cancelled,_terminal;}
- (BOOL)cancelled;
- (BOOL)complete;
@end
@implementation OR6API6ENetworkTask
- (void)cancel{@synchronized(self){if(!_terminal)_cancelled=YES;}}
- (BOOL)cancelled{@synchronized(self){return _cancelled;}}
- (BOOL)complete{@synchronized(self){_terminal=YES;return!_cancelled;}}
@end
@implementation OR6API6ENetwork
- (id)initWithAdapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots{if((self=[super init])){if(!adapter||![roots isKindOfClass:NSString.class]||!roots.length){[self release];return nil;}_adapter=[adapter retain];_roots=[roots copy];}return self;}
- (id<OR6APITask>)request:(NSURLRequest*)request context:(NSDictionary*)ctx completion:(OR6APIReply)reply{
 OR6API6ENetworkTask*task=[[[OR6API6ENetworkTask alloc]init]autorelease];if(!NSThread.isMainThread){if(reply)dispatch_async(dispatch_get_main_queue(),^{reply(nil,OR6APIError(@"invalid_request",@"none"));});return task;}ctx=OR6APIJSONSnapshot(ctx,4096);NSDictionary*schema=@{@"type":@"object",@"properties":@{@"key":@{@"type":@"string",@"minLength":@1,@"maxLength":@256},@"generation":@{@"type":@"integer",@"minimum":@1},@"accountId":@{@"type":@"string",@"minLength":@1,@"maxLength":@128},@"userId":@{@"type":@"string",@"minLength":@1,@"maxLength":@256}},@"required":@[@"key",@"generation",@"accountId",@"userId"],@"additionalProperties":@NO};if(!NSThread.isMainThread||!OR6API6EAllowedRequest(request)||!OR6APISchemaCheck(ctx,schema,@{})||![[request valueForHTTPHeaderField:@"ChatGPT-Account-ID"]isEqual:ctx[@"accountId"]]){reply(nil,OR6APIError(@"invalid_request",@"none"));return task;}
 if(![_adapter chatMatchesOwner:ctx[@"userId"]]){reply(nil,OR6APIError(@"owner_mismatch",@"none"));return task;}NSMutableURLRequest*r=[[request mutableCopy]autorelease];[r setValue:@"application/json"forHTTPHeaderField:@"Accept"];[r setValue:@"https://chatgpt.com"forHTTPHeaderField:@"Origin"];[r setValue:@"https://chatgpt.com/"forHTTPHeaderField:@"Referer"];if(r.HTTPBody.length)[r setValue:@"application/json"forHTTPHeaderField:@"Content-Type"];NSUInteger generation=_adapter.credentialGeneration;NSURLRequest*authorized=[_adapter authorizeChatRequest:r expectedKey:ctx[@"key"]];if(!authorized){reply(nil,OR6APIError(@"not_authenticated",@"none"));return task;}if(![[authorized valueForHTTPHeaderField:@"ChatGPT-Account-ID"]isEqual:ctx[@"accountId"]]){reply(nil,OR6APIError(@"owner_mismatch",@"none"));return task;}
 BOOL logout=[r.URL.path isEqual:@"/backend-api/accounts/logout_all"];dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{NSAutoreleasePool*pool=[NSAutoreleasePool new];NSError*network=nil;NSDictionary*response=OR6APIHTTPPerform(authorized,_roots,[NSSet setWithObject:@"chatgpt.com"],@{@"connectTimeout":@15,@"idleTimeout":@25,@"overallTimeout":@45,@"collectBody":@YES,@"maxRequestBytes":@32768,@"maxDecodedBytes":@(2*1024*1024)},^BOOL{return task.cancelled;},nil,nil,&network);id bytes=response[@"requestBytesSent"]?:network.userInfo[@"requestBytesSent"];NSString*sent=[bytes isKindOfClass:NSNumber.class]&&![bytes unsignedLongLongValue]?@"none":@"possible";NSInteger status=[response[@"status"]integerValue];NSError*error=nil;id json=nil;
  if(!response)error=OR6APIError(task.cancelled?@"cancelled":@"network_unavailable",sent);else if(![response[@"certificateVerified"]boolValue])error=OR6APIError(@"tls",sent);else if((status<200||status>299)&&status!=409&&status!=404)error=OR6APIError(status==401?@"not_authenticated":status==403?@"service_challenge":status==429?@"rate_limited":@"upstream_error",sent);else{NSData*d=response[@"data"];if(d.length)json=[NSJSONSerialization JSONObjectWithData:d options:0 error:NULL];if(d.length&&![json isKindOfClass:NSDictionary.class])error=OR6APIError(@"unknown_wire_shape",sent);if(!d.length&&status!=200&&status!=204)error=OR6APIError(@"unknown_wire_shape",sent);}
  NSDictionary*result=@{@"status":@(status),@"json":json?:(id)NSNull.null};dispatch_async(dispatch_get_main_queue(),^{if(![task complete]){reply(nil,OR6APIError(@"cancelled",sent));return;}if(generation!=_adapter.credentialGeneration||![ctx[@"key"]isEqual:_adapter.contextKey]||![_adapter chatMatchesOwner:ctx[@"userId"]]){reply(nil,OR6APIError(@"stale_context",sent));return;}if(!error&&![_adapter acceptChatCookies:response[@"setCookies"]?:@[]expectedKey:ctx[@"key"]generation:generation]){reply(nil,OR6APIError(@"storage_failure",sent));return;}reply(error?nil:result,error);
   // Deliver the acknowledged server result before invalidating the old local
   // session. A completion may install a replacement login synchronously.
   if(!error&&logout&&OR6API6EAcknowledged(result)&&!task.cancelled)[_adapter or6eSignOutForKey:ctx[@"key"]generation:generation user:ctx[@"userId"]];
  });[pool drain];});return task;
}
- (void)dealloc{[_adapter release];[_roots release];[super dealloc];}
@end
