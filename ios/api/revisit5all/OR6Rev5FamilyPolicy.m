#import "OR6Rev5All.h"
#import "../priority5e/OR6API5EProvider.h"
#import "../revisit67account/OR6Rev67Account.h"
#import <dispatch/dispatch.h>
static BOOL Text(id s,NSUInteger max){return[s isKindOfClass:NSString.class]&&[s length]&&[s length]<=max;}
static NSError *Safe(NSError *e,BOOL forwarded){if(!e)return nil;id c=e.userInfo[@"code"],d=e.userInfo[@"dispatch"];return OR6APIError([c isKindOfClass:NSString.class]?[[c copy]autorelease]:@"invalid_response",forwarded&&[d isKindOfClass:NSString.class]?[[d copy]autorelease]:@"none");}
@class OR6R5FamilyCall;
@interface OR6Rev5FamilyPolicy(){id<OR6APIProvider>_next;id<OR6API7HTTP>_HTTP;OR6API5EProvider *_family;NSDictionary *_identity,*_context,*_binding,*_registry,*_schemas;NSSet *_ops;OR6R5FamilyCall *_active;NSUInteger _epoch,_checks;BOOL _transitioning;}
- (void)cancel:(OR6R5FamilyCall*)c;
@end
@interface OR6R5FamilyCall:NSObject<OR6APITask>{@public OR6Rev5FamilyPolicy *owner;NSString *op;NSDictionary *parameters,*context,*identity;OR6APIReply reply;OR6APIEvent event;id<OR6APITask>child;NSUInteger epoch,stage;BOOL terminal,forwarded;}
@end
@implementation OR6R5FamilyCall
- (void)cancel{if(NSThread.isMainThread)[owner cancel:self];else dispatch_async(dispatch_get_main_queue(),^{[self cancel];});}
- (void)dealloc{[owner release];[op release];[parameters release];[context release];[identity release];[reply release];[event release];[child release];[super dealloc];}
@end
@implementation OR6Rev5FamilyPolicy
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP registry:(NSDictionary*)registry family:(OR6API5EProvider*)family{
 if((self=[super init])){if(!next||!HTTP||!family||![registry isKindOfClass:NSDictionary.class]){[self release];return nil;}NSMutableSet *ops=[NSMutableSet set];for(NSDictionary *f in registry[@"featureMap"])if([f[@"featureId"]hasPrefix:@"safety."]){for(NSString *op in f[@"operations"])if([op hasPrefix:@"family."]||[op hasPrefix:@"safety.quiet_hours."]||[op hasPrefix:@"safety.study_hours."]||[op hasPrefix:@"safety.age."]||[op hasPrefix:@"safety.graduation."])[ops addObject:op];}_ops=[ops copy];_registry=[OR6APIJSONSnapshot(registry,4*1024*1024)retain];NSMutableDictionary *schemas=[NSMutableDictionary dictionary];for(NSDictionary *op in _registry[@"operations"])schemas[op[@"id"]]=op;_schemas=[schemas copy];_next=[next retain];_HTTP=[HTTP retain];_family=[family retain];}return self;
}
- (BOOL)current:(OR6R5FamilyCall*)c{return c&&!c->terminal&&!_transitioning&&_active==c&&c->epoch==_epoch&&[_identity isEqual:c->identity]&&[_context isEqual:c->context];}
- (void)finish:(OR6R5FamilyCall*)c result:(NSDictionary*)r error:(NSError*)e{if(!c||c->terminal)return;[c retain];c->terminal=YES;id<OR6APITask>child=[[c->child retain]autorelease];[c->child release];c->child=nil;OR6APIReply reply=[[c->reply copy]autorelease];[c->reply release];c->reply=nil;if(_active==c){[_active release];_active=nil;}OR6Rev5FamilyPolicy *held=c->owner;c->owner=nil;if(e)[child cancel];if(reply)reply(e?nil:r,e);[held release];[c release];}
- (void)cancel:(OR6R5FamilyCall*)c{[self finish:c result:nil error:OR6APIError(@"cancelled",c->forwarded?@"possible":@"none")];}
- (void)deactivate{if(!NSThread.isMainThread)return;_transitioning=YES;_epoch++;if(_active)[self cancel:_active];[_identity release];_identity=nil;[_context release];_context=nil;[_binding release];_binding=nil;_transitioning=NO;}
- (BOOL)bindIdentity:(NSDictionary*)identity context:(NSDictionary*)context{
 NSDictionary *i=OR6APIJSONSnapshot(identity,4096),*c=OR6APIJSONSnapshot(context,4096);if(!NSThread.isMainThread||_transitioning||![i isKindOfClass:NSDictionary.class]||i.count!=2||!Text(i[@"accountId"],128)||!Text(i[@"userId"],256)||![c isKindOfClass:NSDictionary.class]||c.count!=2||!Text(c[@"key"],256)||!OR6APISchemaCheck(c[@"generation"],@{@"type":@"integer",@"minimum":@1},@{}))return NO;if(![_identity isEqual:i]||![_context isEqual:c]){[self deactivate];_identity=[i retain];_context=[c retain];}return YES;
}
- (void)adopt:(id<OR6APITask>)task call:(OR6R5FamilyCall*)c stage:(NSUInteger)stage{if(![self current:c]||c->stage!=stage){if(task&&!c->terminal)[task cancel];return;}if(!task){[self finish:c result:nil error:OR6APIError(@"unavailable",c->forwarded?@"possible":@"none")];return;}[c->child release];c->child=[task retain];}
- (void)forward:(OR6R5FamilyCall*)c{
 if(![self current:c])return;c->forwarded=YES;NSUInteger stage=++c->stage;__block BOOL delivered=NO;
 id<OR6APITask>task=[_next execute:c->op parameters:c->parameters context:c->context event:^(NSDictionary *e){NSDictionary *copy=OR6APIJSONSnapshot(e,1024*1024);dispatch_async(dispatch_get_main_queue(),^{if([self current:c]&&c->stage==stage&&c->event&&copy)c->event(copy);});}completion:^(NSDictionary *r,NSError *e){@synchronized(c){if(delivered)return;delivered=YES;}NSDictionary *result=OR6APIJSONSnapshot(r,1024*1024);NSError *error=Safe(e,YES);void(^receive)(void)=^{if(![self current:c]||c->stage!=stage)return;[self finish:c result:result error:error?:(![result isKindOfClass:NSDictionary.class]?OR6APIError(@"invalid_response",@"possible"):nil)];};if(NSThread.isMainThread)receive();else dispatch_async(dispatch_get_main_queue(),receive);}];[self adopt:task call:c stage:stage];
}
- (void)preflight:(OR6R5FamilyCall*)c{
 NSUInteger stage=++c->stage;__block BOOL delivered=NO;NSMutableDictionary *context=[[c->context mutableCopy]autorelease];[context addEntriesFromDictionary:c->identity];_checks++;
 id<OR6APITask>task=[_HTTP request:OR6Rev67AccountRequest(@"account",c->identity)context:context completion:^(NSDictionary *r,NSError *e){@synchronized(c){if(delivered)return;delivered=YES;}NSDictionary *raw=OR6APIJSONSnapshot(r,4*1024*1024);NSError *error=Safe(e,NO);void(^receive)(void)=^{if(![self current:c]||c->stage!=stage)return;NSError *problem=error;NSDictionary *account=nil;if(!problem){if(![raw isKindOfClass:NSDictionary.class]||!OR6APISchemaCheck(raw[@"status"],@{@"type":@"integer",@"minimum":@100,@"maximum":@599},@{}))problem=OR6APIError(@"invalid_response",@"none");else if(![raw[@"status"]isEqual:@200])problem=OR6APIError([raw[@"status"]isEqual:@429]?@"rate_limited":[raw[@"status"]isEqual:@403]?@"service_challenge":[raw[@"status"]isEqual:@401]?@"not_authenticated":@"upstream_error",@"none");else account=OR6Rev67AccountDecodeAccount(raw[@"json"],c->identity[@"accountId"],&problem);}
 BOOL supported=[account[@"structure"]isEqual:@"personal"]&&[@[@"free",@"go",@"plus",@"pro",@"promax",@"prolite"]containsObject:account[@"plan"]];if(problem||!supported){[self finish:c result:nil error:problem?:OR6APIError(@"permission_denied",@"none")];return;}
 // Schedule/Persona need separately recovered rollout+settings observations.
 // Do not substitute personal-account permission for those independent flags.
 NSString *locale=NSLocale.preferredLanguages.count?NSLocale.preferredLanguages[0]:@"en";if(!Text(locale,32))locale=@"en";
 NSDictionary *binding=@{@"accountId":c->identity[@"accountId"],@"userId":c->identity[@"userId"],@"personal":@YES,@"canFamily":@YES,@"canSchedule":@NO,@"canAge":@YES,@"canVerifyAge":@NO,@"locale":locale};
 if(![_binding isEqual:binding]){if([_family.diagnostics[@"active"]unsignedIntegerValue]){[self finish:c result:nil error:OR6APIError(@"conflict",@"none")];return;}NSError *bindError=nil;if(![_family observeIdentity:binding context:c->context error:&bindError]){[self finish:c result:nil error:bindError?:OR6APIError(@"permission_denied",@"none")];return;}[_binding release];_binding=[binding retain];}
 if([self current:c])[self forward:c];};if(NSThread.isMainThread)receive();else dispatch_async(dispatch_get_main_queue(),receive);}];[self adopt:task call:c stage:stage];
}
- (id<OR6APITask>)execute:(NSString*)op parameters:(NSDictionary*)p context:(NSDictionary*)ctx event:(OR6APIEvent)event completion:(OR6APIReply)reply{
 if(![_ops containsObject:op]){if([op isEqual:@"auth.logout"])[self deactivate];return[_next execute:op parameters:p context:ctx event:event completion:reply];}
 if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{if(reply)reply(nil,OR6APIError(@"invalid_request",@"none"));});return nil;}
 NSDictionary *parameters=OR6APIJSONSnapshot(p,512*1024),*context=OR6APIJSONSnapshot(ctx,4096);if(![parameters isKindOfClass:NSDictionary.class]||!OR6APISchemaCheck(parameters,_schemas[op][@"requestSchema"],_registry[@"types"])||![_context isEqual:context]||!_identity||_transitioning||_active){if(reply)reply(nil,OR6APIError(_active?@"conflict":@"stale_context",@"none"));return nil;}
 OR6R5FamilyCall *c=[[[OR6R5FamilyCall alloc]init]autorelease];c->owner=[self retain];c->op=[op copy];c->parameters=[parameters retain];c->context=[context retain];c->identity=[_identity retain];c->epoch=_epoch;c->event=[event copy];c->reply=[reply copy];_active=[c retain];[self preflight:c];return c;
}
- (void)didValidate:(NSString*)op result:(NSDictionary*)r context:(NSDictionary*)ctx{if([_next respondsToSelector:_cmd])[_next didValidate:op result:r context:ctx];}
- (void)releaseCompletedDraft:(NSString*)draft context:(NSDictionary*)ctx{if([_next respondsToSelector:_cmd])[_next releaseCompletedDraft:draft context:ctx];}
- (NSDictionary*)diagnostics{return@{@"checks":@(_checks),@"active":@(_active!=nil),@"automaticRetry":@NO};}
- (void)dealloc{[_next release];[_HTTP release];[_family release];[_identity release];[_context release];[_binding release];[_ops release];[_registry release];[_schemas release];[_active release];[super dealloc];}
@end
