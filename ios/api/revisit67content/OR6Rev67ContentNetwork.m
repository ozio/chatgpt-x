#import "OR6Rev67Content.h"
#import "../OR6APIWebAdapter.h"
#import "../OR6APIHTTP.h"
#import <dispatch/dispatch.h>
// Requests are private values, not live mutable objects supplied by a caller
// or session adapter. Authorization may add credentials, never alter semantics.
static NSURLRequest*FrozenRequest(NSURLRequest*r){
 if(![r isKindOfClass:NSURLRequest.class]||r.HTTPBodyStream)return nil;
 NSDictionary*headers=OR6APIJSONSnapshot(r.allHTTPHeaderFields?:@{},128*1024);if(!headers)return nil;
 NSMutableURLRequest*m=[[r mutableCopy]autorelease];m.HTTPBody=[[r.HTTPBody copy]autorelease];m.allHTTPHeaderFields=headers;return[[m copy]autorelease];
}
static BOOL SameSemantics(NSURLRequest*a,NSURLRequest*b){
 if(!a||!b||b.HTTPBodyStream||![a.URL.absoluteString isEqual:b.URL.absoluteString]||![a.HTTPMethod isEqual:b.HTTPMethod]||![(a.HTTPBody?:[NSData data])isEqual:(b.HTTPBody?:[NSData data])])return NO;
 for(NSString*k in @[@"ChatGPT-Account-ID",@"OAI-Product-Sku",@"Content-Type",@"Accept",@"Origin",@"Referer"]){id x=[a valueForHTTPHeaderField:k],y=[b valueForHTTPHeaderField:k];if(x!=y&&![x isEqual:y])return NO;}return YES;
}
static NSArray*FrozenCookies(id raw){if(![raw isKindOfClass:NSArray.class]||[raw count]>128)return nil;for(id h in raw)if(![h isKindOfClass:NSString.class]||[h length]>16384)return nil;return OR6APIJSONSnapshot(@{@"cookies":raw},128*1024)[@"cookies"];}
@interface OR6R67NetworkTask:NSObject<OR6APITask>{BOOL _cancelled,_terminal;}
- (BOOL)cancelled;
- (BOOL)complete;
@end
@implementation OR6R67NetworkTask
- (void)cancel{@synchronized(self){_cancelled=YES;}}
- (BOOL)cancelled{@synchronized(self){return _cancelled;}}
- (BOOL)complete{@synchronized(self){if(_terminal)return NO;_terminal=YES;return!_cancelled;}}
@end
@interface OR6Rev67ContentNetwork(){OR6APIWebAdapter*_adapter;NSString*_roots;}
@end
@implementation OR6Rev67ContentNetwork
- (id)initWithAdapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots{if((self=[super init])){if(!adapter||![roots isKindOfClass:NSString.class]||!roots.length){[self release];return nil;}_adapter=[adapter retain];_roots=[roots copy];}return self;}
- (id<OR6APITask>)request:(NSURLRequest*)request context:(NSDictionary*)context completion:(OR6APIReply)reply{
 OR6R67NetworkTask*task=[[[OR6R67NetworkTask alloc]init]autorelease];
 if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{if(reply)reply(nil,OR6APIError(@"invalid_request",@"none"));});return task;}
 NSDictionary*ctx=OR6APIJSONSnapshot(context,4096);request=FrozenRequest(request);
 NSDictionary*schema=@{@"type":@"object",@"properties":@{@"key":@{@"type":@"string",@"minLength":@1,@"maxLength":@256},@"generation":@{@"type":@"integer",@"minimum":@1},@"accountId":@{@"type":@"string",@"minLength":@1,@"maxLength":@128},@"userId":@{@"type":@"string",@"minLength":@1,@"maxLength":@256}},@"required":@[@"key",@"generation",@"accountId",@"userId"],@"additionalProperties":@NO};
 if(!OR6Rev67ContentAllowedRequest(request)||!OR6APISchemaCheck(ctx,schema,@{})||![[request valueForHTTPHeaderField:@"ChatGPT-Account-ID"]isEqual:ctx[@"accountId"]]){if(reply)reply(nil,OR6APIError(@"invalid_request",@"none"));return task;}
 if(![ctx[@"key"]isEqual:_adapter.contextKey]||![_adapter chatMatchesOwner:ctx[@"userId"]]){if(reply)reply(nil,OR6APIError(@"owner_mismatch",@"none"));return task;}
 NSUInteger generation=_adapter.credentialGeneration;
 BOOL appRPC=[request.URL.path isEqual:@"/backend-api/ecosystem/call_mcp"];
 BOOL canvas=[request.URL.path hasSuffix:@"/textdocs"];
 BOOL stream=[request.URL.path hasSuffix:@"/regenerate"]||[request.URL.path hasSuffix:@"/correction"];
 NSMutableURLRequest*r=[[request mutableCopy]autorelease];[r setValue:stream?@"text/event-stream":@"application/json"forHTTPHeaderField:@"Accept"];[r setValue:@"https://chatgpt.com"forHTTPHeaderField:@"Origin"];[r setValue:@"https://chatgpt.com/"forHTTPHeaderField:@"Referer"];
 NSURLRequest*expected=FrozenRequest(r),*authorized=FrozenRequest([_adapter authorizeChatRequest:r expectedKey:ctx[@"key"]]);
 if(!authorized){if(reply)reply(nil,OR6APIError(@"not_authenticated",@"none"));return task;}
 if(!SameSemantics(expected,authorized)){if(reply)reply(nil,OR6APIError(@"invalid_request",@"none"));return task;}
 if(task.cancelled||generation!=_adapter.credentialGeneration||![ctx[@"key"]isEqual:_adapter.contextKey]||![_adapter chatMatchesOwner:ctx[@"userId"]]){if(reply)reply(nil,OR6APIError(@"stale_context",@"none"));return task;}
 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
  NSAutoreleasePool*pool=[NSAutoreleasePool new];
  BOOL(^invalid)(void)=^BOOL{
   if(task.cancelled)return YES;
   __block BOOL current=NO;
   dispatch_sync(dispatch_get_main_queue(),^{current=generation==_adapter.credentialGeneration&&[ctx[@"key"]isEqual:_adapter.contextKey]&&[_adapter chatMatchesOwner:ctx[@"userId"]];});
   return!current;
  };
  if(invalid()){dispatch_async(dispatch_get_main_queue(),^{BOOL active=[task complete];if(reply)reply(nil,OR6APIError(active?@"stale_context":@"cancelled",@"none"));});[pool drain];return;}
  NSError*wire=nil;
  NSDictionary*response=OR6APIHTTPPerform(authorized,_roots,[NSSet setWithObject:@"chatgpt.com"],@{@"connectTimeout":@15,@"idleTimeout":@30,@"overallTimeout":@90,@"collectBody":@YES,@"maxRequestBytes":@(512*1024),@"maxDecodedBytes":@(1024*1024)},invalid,nil,nil,&wire);
  id bytes=response[@"requestBytesSent"]?:wire.userInfo[@"requestBytesSent"];
  NSString*sent=[bytes isKindOfClass:NSNumber.class]&&![bytes unsignedLongLongValue]?@"none":@"possible";
  NSInteger status=[response[@"status"]integerValue];NSError*error=nil;id json=nil;
  if(!response)error=OR6APIError(task.cancelled?@"cancelled":@"network_unavailable",sent);
  else if(![response[@"certificateVerified"]isEqual:@YES])error=OR6APIError(@"tls",sent);
  else if(status<200||status>299)error=OR6APIError(status==401?@"not_authenticated":status==403?@"service_challenge":status==429?@"rate_limited":@"upstream_error",sent);
  else if(stream){NSError*parse=nil;json=OR6Rev67ContentSSE(response[@"data"],[r.URL.path hasSuffix:@"/correction"],&parse);if(!json)error=OR6APIError(parse.userInfo[@"code"]?:@"unknown_wire_shape",sent);}
  else{NSData*d=response[@"data"];if(d.length)json=[NSJSONSerialization JSONObjectWithData:d options:appRPC?NSJSONReadingAllowFragments:0 error:NULL];if((d.length&&(!json||(!appRPC&&!(canvas?[json isKindOfClass:NSArray.class]:[json isKindOfClass:NSDictionary.class]))))||(!d.length&&[r.HTTPMethod isEqual:@"GET"]))error=OR6APIError(@"unknown_wire_shape",sent);else if(!appRPC&&[json isKindOfClass:NSDictionary.class]&&(json[@"error"]||json[@"error_code"]||[json[@"success"]isEqual:@NO]))error=OR6APIError(@"upstream_error",sent);}
  NSArray*cookies=FrozenCookies(response[@"setCookies"]?:@[]);if(!cookies&&!error)error=OR6APIError(@"invalid_response",sent);
  NSDictionary*result=OR6APIJSONSnapshot(@{@"status":@(status),@"json":json?:NSNull.null},2*1024*1024);
  dispatch_async(dispatch_get_main_queue(),^{
   if(![task complete]){if(reply)reply(nil,OR6APIError(@"cancelled",sent));return;}
   if(generation!=_adapter.credentialGeneration||![ctx[@"key"]isEqual:_adapter.contextKey]||![_adapter chatMatchesOwner:ctx[@"userId"]]){if(reply)reply(nil,OR6APIError(@"stale_context",sent));return;}
   BOOL accepted=error?YES:[_adapter acceptChatCookies:cookies expectedKey:ctx[@"key"]generation:generation];
   if(task.cancelled||generation!=_adapter.credentialGeneration||![ctx[@"key"]isEqual:_adapter.contextKey]||![_adapter chatMatchesOwner:ctx[@"userId"]]){if(reply)reply(nil,OR6APIError(task.cancelled?@"cancelled":@"stale_context",sent));return;}
   if(!error&&!accepted){if(reply)reply(nil,OR6APIError(@"storage_failure",sent));return;}
   if(reply)reply(error?nil:result,error);
  });[pool drain];
 });return task;
}
- (void)dealloc{[_adapter release];[_roots release];[super dealloc];}
@end
