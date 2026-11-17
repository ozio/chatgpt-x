#import "OR6Rev67Account.h"
#import <dispatch/dispatch.h>
static BOOL Context(id v){return OR6APISchemaCheck(v,@{@"type":@"object",@"properties":@{@"key":@{@"type":@"string",@"minLength":@1,@"maxLength":@256},@"generation":@{@"type":@"integer",@"minimum":@1}},@"required":@[@"key",@"generation"],@"additionalProperties":@NO},@{});}
static BOOL Identity(id v){return OR6APISchemaCheck(v,@{@"type":@"object",@"properties":@{@"accountId":@{@"type":@"string",@"minLength":@1,@"maxLength":@128},@"userId":@{@"type":@"string",@"minLength":@1,@"maxLength":@256}},@"required":@[@"accountId",@"userId"],@"additionalProperties":@NO},@{});}
@class OR6Rev67AccountCall;
@interface OR6Rev67AccountProvider(){id<OR6APIProvider> _next;id<OR6API7HTTP> _HTTP;NSDictionary *_registry,*_identity,*_context;OR6Rev67AccountCall *_active;NSUInteger _requests;BOOL _transitioning;}
- (void)cancel:(OR6Rev67AccountCall *)call;
@end
@interface OR6Rev67AccountCall:NSObject<OR6APITask>{@public OR6Rev67AccountProvider *owner;NSString *operation;NSDictionary *context,*identity,*account;OR6APIReply reply;id<OR6APITask> child;NSUInteger serial;BOOL terminal;}
@end
@implementation OR6Rev67AccountCall
- (void)cancel{if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self cancel];});return;}[owner cancel:self];}
- (void)dealloc{[owner release];[operation release];[context release];[identity release];[account release];[reply release];[child release];[super dealloc];}
@end
@implementation OR6Rev67AccountProvider
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP registry:(NSDictionary *)registry{if((self=[super init])){if(!next||!HTTP||!OR6APIJSONSnapshot(registry,4*1024*1024)){[self release];return nil;}_next=[next retain];_HTTP=[HTTP retain];_registry=[OR6APIJSONSnapshot(registry,4*1024*1024)retain];}return self;}
- (BOOL)current:(OR6Rev67AccountCall *)c{return !c->terminal&&!_transitioning&&[_context isEqual:c->context]&&[_identity isEqual:c->identity];}
- (void)finish:(OR6Rev67AccountCall *)c result:(NSDictionary *)result error:(NSError *)error{if(!c||c->terminal)return;[c retain];c->terminal=YES;OR6APIReply callback=[[c->reply copy]autorelease];[c->reply release];c->reply=nil;id<OR6APITask>task=[[c->child retain]autorelease];[c->child release];c->child=nil;if(_active==c){[_active release];_active=nil;}OR6Rev67AccountProvider *held=c->owner;c->owner=nil;if(error)[task cancel];if(callback)callback(error?nil:result,error);[held release];[c release];}
- (void)cancel:(OR6Rev67AccountCall *)call{[self finish:call result:nil error:OR6APIError(@"cancelled",@"none")];}
- (void)deactivate{if(!NSThread.isMainThread||_transitioning)return;[[self retain]autorelease];_transitioning=YES;[self cancel:_active];[_identity release];_identity=nil;[_context release];_context=nil;_transitioning=NO;}
- (BOOL)bindIdentity:(NSDictionary *)identity context:(NSDictionary *)context{if(!NSThread.isMainThread||_transitioning)return NO;NSDictionary *i=OR6APIJSONSnapshot(identity,4096),*ctx=OR6APIJSONSnapshot(context,4096);if(!Identity(i)||!Context(ctx))return NO;if(![_identity isEqual:i]||![_context isEqual:ctx]){[self deactivate];[_identity release];_identity=[i retain];[_context release];_context=[ctx retain];}return YES;}
- (void)request:(NSString *)route call:(OR6Rev67AccountCall *)c consume:(void(^)(id raw))consume{
 if(![self current:c])return;NSURLRequest *r=OR6Rev67AccountRequest(route,c->identity);if(!OR6Rev67AccountAllowedRequest(r)){[self finish:c result:nil error:OR6APIError(@"invalid_request",@"none")];return;}
 NSMutableDictionary *ctx=[[c->context mutableCopy]autorelease];[ctx addEntriesFromDictionary:c->identity];NSUInteger serial=++c->serial;_requests++;__block BOOL delivered=NO;
 id<OR6APITask>task=[_HTTP request:r context:ctx completion:^(NSDictionary *value,NSError *issue){@synchronized(c){if(delivered)return;delivered=YES;}NSDictionary *snapshot=OR6APIJSONSnapshot(value,2*1024*1024);NSError *safe=issue?OR6APIError([issue.userInfo[@"code"]isKindOfClass:NSString.class]?issue.userInfo[@"code"]:@"network_unavailable",@"none"):nil;void(^receive)(void)=^{if(![self current:c]||serial!=c->serial)return;if(safe){[self finish:c result:nil error:safe];return;}if(!OR6APISchemaCheck(snapshot[@"status"],@{@"type":@"integer",@"minimum":@100,@"maximum":@599},@{})){[self finish:c result:nil error:OR6APIError(@"unknown_wire_shape",@"none")];return;}NSInteger status=[snapshot[@"status"]integerValue];if(status<200||status>299){[self finish:c result:nil error:OR6APIError(status==401?@"not_authenticated":status==403?@"service_challenge":status==429?@"rate_limited":@"upstream_error",@"none")];return;}consume(snapshot[@"json"]);};if(NSThread.isMainThread)receive();else dispatch_async(dispatch_get_main_queue(),receive);}];
 if(![self current:c]||serial!=c->serial)[task cancel];else if(task){[c->child release];c->child=[task retain];}else[self finish:c result:nil error:OR6APIError(@"unavailable",@"none")];
}
- (id<OR6APITask>)execute:(NSString *)op parameters:(NSDictionary *)parameters context:(NSDictionary *)context event:(OR6APIEvent)event completion:(OR6APIReply)reply{
 if(!NSThread.isMainThread){if(reply)dispatch_async(dispatch_get_main_queue(),^{reply(nil,OR6APIError(@"invalid_request",@"none"));});return nil;}
 NSDictionary *p=OR6APIJSONSnapshot(parameters,4096),*ctx=OR6APIJSONSnapshot(context,4096);
 // Observing an owner transition revokes the old grant even on a forwarded operation.
 if(_context&&(!Context(ctx)||![_context isEqual:ctx]))[self deactivate];
 if(!OR6Rev67AccountTiers()[op]){if([op isEqual:@"auth.logout"])[self deactivate];return[_next execute:op parameters:p context:ctx event:event completion:reply];}
 if(!p||p.count||!Context(ctx)){if(reply)reply(nil,OR6APIError(@"invalid_request",@"none"));return nil;}
 if(!_identity||![_context isEqual:ctx]||_transitioning){if(reply)reply(nil,OR6APIError(@"stale_context",@"none"));return nil;}
 if(_active){if(reply)reply(nil,OR6APIError(@"conflict",@"none"));return nil;}
 OR6Rev67AccountCall *c=[[[OR6Rev67AccountCall alloc]init]autorelease];c->owner=[self retain];c->operation=[op copy];c->context=[ctx retain];c->identity=[_identity retain];c->reply=[reply copy];_active=[c retain];
 [self request:@"account"call:c consume:^(id raw){NSError *error=nil;NSDictionary *a=OR6Rev67AccountDecodeAccount(raw,c->identity[@"accountId"],&error);if(!a){[self finish:c result:nil error:error];return;}c->account=[a retain];if([c->operation isEqual:@"subscription6.status"]||[c->operation isEqual:@"subscription6.billingRecovery"]){[self request:@"subscription"call:c consume:^(id subscription){NSError *e=nil;NSDictionary *s=OR6Rev67AccountDecodeSubscription(subscription,&e);if(!s){[self finish:c result:nil error:e];return;}if(![s[@"plan"]isEqual:c->account[@"plan"]]){[self finish:c result:nil error:OR6APIError(@"conflict",@"none")];return;}NSDictionary *result=[c->operation isEqual:@"subscription6.status"]?@{@"account":c->account,@"billing":s,@"purchasesRestored":@NO}:OR6Rev67AccountHandoff(c->operation,c->account,s,&e);[self finish:c result:result error:e];}];}else{NSDictionary *result=OR6Rev67AccountHandoff(c->operation,a,nil,&error);[self finish:c result:result error:error];}}];return c;
}
- (void)didValidate:(NSString *)op result:(NSDictionary *)result context:(NSDictionary *)ctx{if([_next respondsToSelector:_cmd])[_next didValidate:op result:result context:ctx];}
- (void)releaseCompletedDraft:(NSString *)draft context:(NSDictionary *)ctx{if([_next respondsToSelector:_cmd])[_next releaseCompletedDraft:draft context:ctx];}
- (NSDictionary *)diagnostics{return @{@"identityBound":@(_identity!=nil),@"activeCount":@(_active!=nil),@"requests":@(_requests),@"automaticRetry":@NO,@"chargeOrCancelSubmitted":@NO};}
- (void)dealloc{[_next release];[_HTTP release];[_registry release];[_identity release];[_context release];[_active release];[super dealloc];}
@end
