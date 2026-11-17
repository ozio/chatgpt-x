#import "OR6API6AProvider.h"
#import "OR6API6APolicy.h"
#import "OR6API6ANetwork.h"
#import "../OR6APIOperations.h"
#import "../priority7/OR6API7Policy.h"
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>
static NSError*ErrorSnapshot(NSError*error){if(!error)return nil;if(![error isKindOfClass:NSError.class])return OR6APIError(@"invalid_response",@"possible");id code=error.userInfo[@"code"],dispatch=error.userInfo[@"dispatch"];NSString*c=[code isKindOfClass:NSString.class]?[[code copy]autorelease]:nil,*d=[dispatch isKindOfClass:NSString.class]?[[dispatch copy]autorelease]:nil;return OR6APIError(c,d);}
static NSString*Issue(NSInteger status){return status==401?@"not_authenticated":status==403?@"service_challenge":status==429?@"rate_limited":status==404?@"not_found":@"upstream_error";}
static NSTimeInterval Now(void){return NSProcessInfo.processInfo.systemUptime;}
static NSString *NewID(void){CFUUIDRef v=CFUUIDCreate(NULL);NSString*s=[(NSString*)CFUUIDCreateString(NULL,v)autorelease];CFRelease(v);return s.lowercaseString;}
static BOOL Context(id c){return[c isKindOfClass:NSDictionary.class]&&[c[@"key"]isKindOfClass:NSString.class]&&[c[@"key"]length]&&[c[@"key"]length]<=256&&OR6APISchemaCheck(c[@"generation"],@{@"type":@"integer",@"minimum":@1},@{});}
@class OR6API6ACall;
@interface OR6API6AProvider(){id<OR6APIProvider>_next;id<OR6API7HTTP>_HTTP;OR6APIOperations*_journal;NSDictionary*_extension,*_ops,*_identity,*_identityContext,*_grant,*_reasons;NSString*_catalogId;NSTimeInterval _catalogAt;NSSet*_caps;NSMutableSet*_calls;NSMutableDictionary*_secrets,*_authorizations,*_cursors;NSString*_scope;NSUInteger _epoch,_writes,_requests;BOOL _mutating,_foreground,_deactivating;NSUInteger _backgroundEpoch;NSTimeInterval _backgroundAt;NSTimeInterval(^_clock)(void);}
- (void)cancel:(OR6API6ACall*)c;
@end
@interface OR6API6ACall:NSObject<OR6APITask>{@public OR6API6AProvider*owner;NSString*op;NSDictionary*p,*ctx,*secret;OR6APIReply reply;id<OR6APITask>child;NSUInteger serial;NSTimeInterval secretAt;BOOL terminal,mutation,reserved,possible,protected,responded;}
@end
@implementation OR6API6ACall
- (void)cancel{if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self cancel];});return;}if(!terminal)[owner cancel:self];}
- (void)dealloc{[op release];[p release];[ctx release];[secret release];[reply release];[child release];[super dealloc];}
@end
@implementation OR6API6AProvider
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP extension:(NSDictionary*)ext journalDirectory:(NSString*)dir capabilities:(NSSet*)caps error:(NSError**)error{
 return[self initWithNext:next HTTP:HTTP extension:ext journalDirectory:dir capabilities:caps clock:nil error:error];
}
- (NSTimeInterval)now{return _clock?_clock():Now();}
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP extension:(NSDictionary*)ext journalDirectory:(NSString*)dir capabilities:(NSSet*)caps clock:(NSTimeInterval(^)(void))clock error:(NSError**)error{
 if(!(self=[super init]))return nil;_extension=[OR6APIJSONSnapshot(ext,1024*1024)retain];if(!next||!HTTP||(caps&&![caps isKindOfClass:NSSet.class])||![_extension[@"operations"]isKindOfClass:NSArray.class]){if(error)*error=OR6APIError(@"invalid_request",@"none");[self release];return nil;}NSMutableDictionary*ops=[NSMutableDictionary dictionary];for(NSDictionary*o in _extension[@"operations"]){if(!OR6API6ACommand(o[@"id"])||ops[o[@"id"]]){[self release];return nil;}ops[o[@"id"]]=o;}if(caps&&![caps isSubsetOfSet:[NSSet setWithArray:ops.allKeys]]){if(error)*error=OR6APIError(@"invalid_request",@"none");[self release];return nil;}_ops=[ops copy];_next=[next retain];_HTTP=[HTTP retain];_caps=[(caps?:[NSSet set])copy];_calls=[NSMutableSet new];_secrets=[NSMutableDictionary new];_authorizations=[NSMutableDictionary new];_cursors=[NSMutableDictionary new];_foreground=YES;_clock=[clock copy];[[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(background:)name:@"UIApplicationWillResignActiveNotification"object:nil];[[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(foreground:)name:@"UIApplicationDidBecomeActiveNotification"object:nil];_journal=[[OR6APIOperations alloc]initWithDirectory:dir error:error];if(!_journal){[self release];return nil;}return self;
}
- (BOOL)identityCurrent:(NSDictionary*)ctx{return[_identityContext isEqual:ctx]&&_identity.count==2;}
- (void)observeContext:(NSDictionary*)ctx{
 if(_deactivating||!NSThread.isMainThread||!Context(ctx)||([_scope isEqual:ctx[@"key"]]&&_epoch==[ctx[@"generation"]unsignedIntegerValue]))return;
 // Adopt the epoch before cancelling old calls. Reentrant callbacks cannot
 // restore the old scope, and a trusted initial binding for this epoch survives.
 [_scope release];_scope=[ctx[@"key"]copy];_epoch=[ctx[@"generation"]unsignedIntegerValue];
 if(![_identityContext isEqual:ctx]){[self deactivate];return;}
 _deactivating=YES;for(OR6API6ACall*c in [[_calls.allObjects copy]autorelease])[self cancel:c];_deactivating=NO;
}
- (BOOL)bindIdentity:(NSDictionary*)identity context:(NSDictionary*)ctx{
 NSDictionary*s=@{@"type":@"object",@"properties":@{@"accountId":@{@"type":@"string",@"minLength":@1,@"maxLength":@128},@"userId":@{@"type":@"string",@"minLength":@1,@"maxLength":@256}},@"required":@[@"accountId",@"userId"],@"additionalProperties":@NO};if(_deactivating||!NSThread.isMainThread||!Context(ctx)||!OR6APISchemaCheck(identity,s,@{}))return NO;for(NSString*k in identity)if([identity[k]rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound)return NO;
 if(![_identity isEqual:identity]||![_identityContext isEqual:ctx])[self deactivate];[_identity release];_identity=[OR6APIJSONSnapshot(identity,4096)retain];[_identityContext release];_identityContext=[OR6APIJSONSnapshot(ctx,4096)retain];return YES;
}
- (BOOL)bindPINSecrets:(NSDictionary*)secret operationId:(NSString*)identifier context:(NSDictionary*)ctx error:(NSError**)error{
 BOOL valid=NSThread.isMainThread&&[self identityCurrent:ctx]&&OR6API7UUID(identifier)&&[identifier isEqual:identifier.lowercaseString]&&[secret isKindOfClass:NSDictionary.class]&&secret.count>0&&secret.count<=2&&_secrets.count<8&&!_secrets[identifier];if([secret isKindOfClass:NSDictionary.class])for(NSString*k in secret)if(![@[@"pin",@"pin_confirmation",@"current_pin",@"new_pin"]containsObject:k]||!OR6API6APIN(secret[k]))valid=NO;
 if(!valid){if(error)*error=OR6APIError(@"invalid_request",@"none");return NO;}_secrets[identifier]=@{@"value":OR6APIJSONSnapshot(secret,4096),@"context":OR6APIJSONSnapshot(ctx,4096),@"at":@([self now])};return YES;
}
- (BOOL)current:(OR6API6ACall*)c{return!c->terminal&&[_scope isEqual:c->ctx[@"key"]]&&_epoch==[c->ctx[@"generation"]unsignedIntegerValue];}
- (void)finish:(OR6API6ACall*)c result:(NSDictionary*)r error:(NSError*)e{
 if(c->terminal)return;if(c->responded&&e&&[e.userInfo[@"dispatch"]isEqual:@"none"])e=OR6APIError(e.userInfo[@"code"],@"possible");[c retain];c->terminal=YES;if(c->reserved){NSDictionary*saved=r;if([c->op isEqual:@"conversations.branch"]&&r)saved=@{@"operationId":c->p[@"operationId"],@"branchId":r[@"conversation"][@"id"]};NSString*state=e?([e.userInfo[@"dispatch"]isEqual:@"none"]?@"rejected":@"uncertain"):@"completed";if(![_journal finish:c->p[@"operationId"]scope:c->ctx[@"key"]state:state metadata:saved?@{@"receipt":saved,@"parameters":[self journalParameters:c]}:@{} error:NULL]){r=nil;e=OR6APIError(@"storage_failure",c->possible?@"possible":@"none");}}
 if(c->mutation)_mutating=NO;[c->secret release];c->secret=nil;OR6APIReply cb=[[c->reply copy]autorelease];[c->reply release];c->reply=nil;id<OR6APITask>task=[[c->child retain]autorelease];[c->child release];c->child=nil;[_calls removeObject:c];if(e)[task cancel];if(cb)cb(r,e);[c release];
}
- (void)cancel:(OR6API6ACall*)c{[self finish:c result:nil error:OR6APIError(@"cancelled",c->possible?@"possible":@"none")];}
- (void)clearLockedAccess{[_grant release];_grant=nil;[_cursors removeAllObjects];for(OR6API6ACall*c in [[_calls.allObjects copy]autorelease])if(c->protected)[self cancel:c];}
- (void)deactivate{BOOL nested=_deactivating;_deactivating=YES;[_identity release];_identity=nil;[_identityContext release];_identityContext=nil;[_secrets removeAllObjects];[_authorizations removeAllObjects];[_reasons release];_reasons=nil;[_catalogId release];_catalogId=nil;[self clearLockedAccess];for(OR6API6ACall*c in [[_calls.allObjects copy]autorelease])[self cancel:c];_deactivating=nested;}
- (void)background:(NSNotification*)note{(void)note;[self setForeground:NO];}
- (void)foreground:(NSNotification*)note{(void)note;[self setForeground:YES];}
- (void)setForeground:(BOOL)foreground{if(!NSThread.isMainThread)return;if(!foreground&&_foreground){_backgroundAt=[self now];NSUInteger serial=++_backgroundEpoch;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,60*NSEC_PER_SEC),dispatch_get_main_queue(),^{if(!_foreground&&serial==_backgroundEpoch)[self clearLockedAccess];});}if(foreground&&!_foreground){++_backgroundEpoch;if([self now]-_backgroundAt>=60)[self clearLockedAccess];}_foreground=foreground;}
- (BOOL)grantCurrent:(NSDictionary*)ctx{if(!_foreground&&[self now]-_backgroundAt>=60)[self clearLockedAccess];return _grant&&[self identityCurrent:ctx]&&[_grant[@"context"]isEqual:ctx];}
- (BOOL)acceptResetReturn:(NSString*)state authorizationId:(NSString*)identifier context:(NSDictionary*)ctx network:(OR6API6ANetwork*)network{
 NSDictionary*a=_authorizations[identifier];if(!NSThread.isMainThread||![self identityCurrent:ctx]||![a[@"context"]isEqual:ctx]||![a[@"state"]isEqual:state]||[self now]-[a[@"at"]doubleValue]<0||[self now]-[a[@"at"]doubleValue]>600||![network validatePasswordReauthenticationForAccount:_identity[@"accountId"]user:_identity[@"userId"]context:ctx issuedAt:[a[@"wall"]doubleValue]])return NO;NSMutableDictionary*b=[[a mutableCopy]autorelease];b[@"verified"]=@YES;_authorizations[identifier]=b;return YES;
}
- (void)request:(NSURLRequest*)r write:(BOOL)write call:(OR6API6ACall*)c completion:(OR6APIReply)completion{
 if(!r||!OR6API6AAllowedRequest(r)){[self finish:c result:nil error:OR6APIError(@"invalid_request",@"none")];return;}NSUInteger serial=++c->serial;_requests++;if(write){_writes++;c->possible=YES;}__block BOOL delivered=NO,queued=NO;
 id<OR6APITask>task=[_HTTP request:r context:c->ctx completion:^(NSDictionary*v,NSError*e){
  // Claim only the first producer callback, then snapshot while its values are
  // valid. All provider/call lifecycle state remains on the main thread.
  @synchronized(c){if(queued)return;queued=YES;}
  NSAutoreleasePool*pool=[NSAutoreleasePool new];NSDictionary*snapshot=OR6APIJSONSnapshot(v,2*1024*1024);NSError*failure=ErrorSnapshot(e);
  void(^consume)(void)=^{
   if(delivered||![self current:c]||serial!=c->serial)return;delivered=YES;
   if(failure){[self finish:c result:nil error:OR6APIError(failure.userInfo[@"code"],c->possible?failure.userInfo[@"dispatch"]:@"none")];return;}
   if(![snapshot isKindOfClass:NSDictionary.class]||!OR6APISchemaCheck(snapshot[@"status"],@{@"type":@"integer",@"minimum":@100,@"maximum":@599},@{})){[self finish:c result:nil error:OR6APIError(@"unknown_wire_shape",write?@"possible":@"none")];return;}
   if(write)c->responded=YES;completion(snapshot,nil);
  };
  if(NSThread.isMainThread)consume();else dispatch_async(dispatch_get_main_queue(),consume);
  [pool drain];
 }];if(c->terminal||serial!=c->serial)[task cancel];else if(task){[c->child release];c->child=[task retain];}else[self finish:c result:nil error:OR6APIError(@"unavailable",write?@"possible":@"none")];
}
- (void)loadStatus:(OR6API6ACall*)c completion:(OR6APIReply)completion{
 [self request:OR6API6ARequest(@"locked.status",@{},@{})write:NO call:c completion:^(NSDictionary*v,NSError*unused){(void)unused;NSError*e=nil;NSDictionary*r=[v[@"status"]integerValue]==200?OR6API6AStatus(v[@"json"],&e):nil;if(!r)[self finish:c result:nil error:e?:OR6APIError(Issue([v[@"status"]integerValue]),@"none")];else completion(r,nil);}];
}
- (NSDictionary*)receipt:(OR6API6ACall*)c acknowledged:(BOOL)ack verified:(BOOL)verified{return@{@"operationId":c->p[@"operationId"],@"serverAcknowledged":@(ack),@"verified":@(verified),@"completed":@(ack)};}
- (NSDictionary*)journalParameters:(OR6API6ACall*)c{if(![c->op isEqual:@"conversations.report"])return c->p;return@{@"operationId":c->p[@"operationId"],@"conversationId":c->p[@"conversationId"],@"reasonId":c->p[@"reasonId"],@"consentToSendConversation":@YES};}
- (void)dispatchWrite:(OR6API6ACall*)c{
 if(c->secret&&([self now]-c->secretAt<0||[self now]-c->secretAt>300)){[self finish:c result:nil error:OR6APIError(@"expired",@"none")];return;}
 if(c->protected&&![self grantCurrent:c->ctx]){[self finish:c result:nil error:OR6APIError(@"access_denied",@"none")];return;}
 if([c->op isEqual:@"locked.pin.reset"]){NSDictionary*a=_authorizations[c->p[@"authorizationId"]];if(![a[@"verified"]isEqual:@YES]||![a[@"context"]isEqual:c->ctx]||[self now]-[a[@"at"]doubleValue]<0||[self now]-[a[@"at"]doubleValue]>600){[self finish:c result:nil error:OR6APIError(@"login_required",@"none")];return;}}
 NSError*e=nil;if(![_journal reserve:c->p[@"operationId"]command:c->op request:@{@"parameters":[self journalParameters:c]}scope:c->ctx[@"key"]error:&e]){[self finish:c result:nil error:e];return;}c->reserved=YES;if(![_journal finish:c->p[@"operationId"]scope:c->ctx[@"key"]state:@"uncertain"metadata:@{}error:&e]){[self finish:c result:nil error:e];return;}
 NSMutableDictionary*private=[[c->secret mutableCopy]autorelease]?:[NSMutableDictionary dictionary];if([self grantCurrent:c->ctx])private[@"grant_pin"]=_grant[@"pin"];
 if([c->op isEqual:@"locked.pin.reset"]){NSDictionary*a=_authorizations[c->p[@"authorizationId"]];private[@"reset_challenge"]=a[@"challenge"];[_authorizations removeObjectForKey:c->p[@"authorizationId"]];[self clearLockedAccess];}
 [self request:OR6API6ARequest(c->op,c->p,private)write:YES call:c completion:^(NSDictionary*v,NSError*unused){(void)unused;NSInteger status=[v[@"status"]integerValue];id raw=v[@"json"];NSString*wire=OR6API6AWireErrorCode(raw);
  if(status<200||status>299){BOOL locked=[wire isEqual:@"pin_locked"],invalid=[wire isEqual:@"invalid_pin"];if(locked||invalid){[self clearLockedAccess];[self loadStatus:c completion:^(NSDictionary*s,NSError*ignored){(void)s;(void)ignored;[self finish:c result:nil error:OR6APIError(locked?@"rate_limited":@"access_denied",@"confirmed")];}];return;}[self finish:c result:nil error:OR6APIError(status==401?@"not_authenticated":status==403?@"service_challenge":status==429?@"rate_limited":@"uncertain_outcome",@"possible")];return;}
  NSError*error=nil;NSDictionary*r=OR6API6ADecode(c->op,raw,c->p,&error);if(!r){[self finish:c result:nil error:error?:OR6APIError(@"unknown_wire_shape",@"possible")];return;}
  if([c->op isEqual:@"locked.pin.resetChallenge"]){NSString*handle=NewID(),*state=NewID();if(_authorizations.count>=4)[_authorizations removeAllObjects];_authorizations[handle]=@{@"challenge":raw[@"reauth_challenge"],@"context":c->ctx,@"state":state,@"at":@([self now]),@"wall":@([NSDate timeIntervalSinceReferenceDate]+978307200),@"verified":@NO};r=@{@"authorizationId":handle,@"returnURL":[NSString stringWithFormat:@"https://chatgpt.com/settings/security?view=account-pin&account_pin_reset_reauth_state=%@",state],@"browserRequired":@YES,@"completed":@NO};}
  else if([c->op isEqual:@"locked.pin.create"]||[c->op isEqual:@"locked.pin.verify"]){[self clearLockedAccess];if([r[@"hasPIN"]isEqual:@YES]&&r[@"projectId"]!=NSNull.null)_grant=[@{@"pin":c->secret[@"pin"],@"projectId":r[@"projectId"],@"context":c->ctx}retain];r=@{@"operationId":c->p[@"operationId"],@"status":r,@"accessGranted":@([self grantCurrent:c->ctx])};}
  else if([c->op isEqual:@"locked.pin.change"]){[self clearLockedAccess];r=@{@"operationId":c->p[@"operationId"],@"status":r,@"accessGranted":@NO};}
  else if([c->op isEqual:@"conversations.branch"])r=@{@"operationId":c->p[@"operationId"],@"conversation":r};
  else if(![c->op isEqual:@"locked.pin.reset"])r=[self receipt:c acknowledged:YES verified:NO];
  [self finish:c result:r error:nil];
 }];
}
- (void)mutate:(OR6API6ACall*)c{
 if([c->op hasPrefix:@"locked.pin."]){[self loadStatus:c completion:^(NSDictionary*s,NSError*unused){(void)unused;BOOL pinAttempt=[@[@"locked.pin.create",@"locked.pin.verify",@"locked.pin.change"]containsObject:c->op];if((pinAttempt&&[s[@"retryAfterSeconds"]doubleValue]>0)||[s[@"resetStatus"]isEqual:@"in_progress"]||[s[@"resetStatus"]isEqual:@"unknown"]){[self finish:c result:nil error:OR6APIError(@"rate_limited",@"none")];return;}BOOL create=[c->op isEqual:@"locked.pin.create"],change=[c->op isEqual:@"locked.pin.change"],verify=[c->op isEqual:@"locked.pin.verify"];if((create&&[s[@"hasPIN"]boolValue])||((change||verify)&&![s[@"hasPIN"]boolValue])||((change||verify)&&[s[@"resetStatus"]isEqual:@"failed"])){[self finish:c result:nil error:OR6APIError(@"conflict",@"none")];return;}[self dispatchWrite:c];}];}else[self dispatchWrite:c];
}
- (void)reconcile:(OR6API6ACall*)c{
 for(OR6API6ACall*active in _calls)if(active!=c&&active->mutation&&[active->p[@"operationId"]isEqual:c->p[@"operationId"]]){[self finish:c result:nil error:OR6APIError(@"conflict",@"none")];return;}
 NSError*e=nil;NSDictionary*record=[_journal record:c->p[@"operationId"]scope:c->ctx[@"key"]error:&e];NSString*command=record[@"command"];if(!record||!OR6API6AMutation(command)||[record[@"state"]isEqual:@"rejected"]){[self finish:c result:nil error:e?:OR6APIError(@"invalid_operation_state",@"none")];return;}
 if([command isEqual:@"locked.pin.reset"]||[command isEqual:@"locked.pin.create"]){[self loadStatus:c completion:^(NSDictionary*status,NSError*unused){(void)unused;BOOL matches=[command isEqual:@"locked.pin.reset"]?([status[@"hasPIN"]isEqual:@NO]&&status[@"resetStatus"]==NSNull.null):[status[@"hasPIN"]isEqual:@YES];if(!matches){[self finish:c result:nil error:OR6APIError(@"uncertain_outcome",@"possible")];return;}NSDictionary*r=[self receipt:c acknowledged:[record[@"state"]isEqual:@"completed"]verified:YES];if(![record[@"state"]isEqual:@"completed"]&&![_journal finish:c->p[@"operationId"]scope:c->ctx[@"key"]state:@"completed"metadata:@{@"receipt":r}error:NULL]){[self finish:c result:nil error:OR6APIError(@"storage_failure",@"possible")];return;}[self finish:c result:r error:nil];}];return;}
 if([@[@"locked.conversations.lock",@"locked.conversations.unlock"]containsObject:command]&&[self grantCurrent:c->ctx]){NSDictionary*p=record[@"request"][@"parameters"]?:record[@"result"][@"parameters"];c->protected=YES;if(![p[@"projectId"]isEqual:_grant[@"projectId"]]){[self finish:c result:nil error:OR6APIError(@"access_denied",@"none")];return;}[self request:OR6API6ARequest(@"locked.conversations.get",p,@{@"grant_pin":_grant[@"pin"]})write:NO call:c completion:^(NSDictionary*v,NSError*unused){(void)unused;id raw=v[@"json"];BOOL matching=[raw isKindOfClass:NSDictionary.class]&&[raw[@"conversation_id"]isEqual:p[@"conversationId"]];BOOL locked=matching&&[raw[@"gizmo_id"]isEqual:p[@"projectId"]];if([v[@"status"]integerValue]!=200||!matching||([command isEqual:@"locked.conversations.lock"]?!locked:locked)){[self finish:c result:nil error:OR6APIError(@"uncertain_outcome",@"possible")];return;}NSDictionary*r=[self receipt:c acknowledged:[record[@"state"]isEqual:@"completed"]verified:YES];if(![record[@"state"]isEqual:@"completed"]&&![_journal finish:c->p[@"operationId"]scope:c->ctx[@"key"]state:@"completed"metadata:@{@"receipt":r}error:NULL]){[self finish:c result:nil error:OR6APIError(@"storage_failure",@"possible")];return;}[self finish:c result:r error:nil];}];return;}
 [self finish:c result:nil error:OR6APIError(@"uncertain_outcome",@"possible")];
}
- (void)read:(OR6API6ACall*)c{
 NSMutableDictionary*s=[NSMutableDictionary dictionary];if([self grantCurrent:c->ctx])s[@"grant_pin"]=_grant[@"pin"];
 [self request:OR6API6ARequest(c->op,c->p,s)write:NO call:c completion:^(NSDictionary*v,NSError*unused){(void)unused;NSError*e=nil;NSDictionary*r=[v[@"status"]integerValue]==200?OR6API6ADecode(c->op,v[@"json"],c->p,&e):nil;if([c->op isEqual:@"conversations.reportReasons"]&&r){NSMutableDictionary*reasons=[NSMutableDictionary dictionary];for(NSDictionary*reason in r[@"items"])reasons[reason[@"id"]]=reason;[_reasons release];_reasons=[reasons copy];[_catalogId release];_catalogId=[NewID()copy];_catalogAt=[self now];r=@{@"catalogId":_catalogId,@"items":r[@"items"]};}if([c->op isEqual:@"locked.conversations.list"]&&r){id cursor=r[@"nextCursor"];NSMutableSet*seen=_cursors[c->p[@"projectId"]];if(cursor!=NSNull.null){if([seen containsObject:cursor]||seen.count>=8){[self finish:c result:nil error:OR6APIError(@"unknown_wire_shape",@"none")];return;}[seen addObject:cursor];}}[self finish:c result:r error:r?nil:e?:OR6APIError(Issue([v[@"status"]integerValue]),@"none")];}];
}
- (id<OR6APITask>)execute:(NSString*)op parameters:(NSDictionary*)p context:(NSDictionary*)ctx event:(OR6APIEvent)event completion:(OR6APIReply)reply{
 if(!NSThread.isMainThread){if(reply)dispatch_async(dispatch_get_main_queue(),^{reply(nil,OR6APIError(@"invalid_request",@"none"));});return nil;}
 [self observeContext:ctx];
 if(!OR6API6ACommand(op)){if([op isEqual:@"auth.logout"])[self deactivate];return[_next execute:op parameters:p context:ctx event:event completion:reply];}
 if(!NSThread.isMainThread||!Context(ctx)||!OR6APIJSONSnapshot(p,32768)||!OR6APISchemaCheck(p,_ops[op][@"requestSchema"],_extension[@"types"])||(p[@"operationId"]&&(!OR6API7UUID(p[@"operationId"])||![p[@"operationId"]isEqual:[p[@"operationId"]lowercaseString]]))){reply(nil,OR6APIError(@"invalid_request",@"none"));return nil;}
 if(_deactivating){reply(nil,OR6APIError(@"stale_context",@"none"));return nil;}if(![_caps containsObject:op]){reply(nil,OR6APIError(@"capability_unverified",@"none"));return nil;}if(![self identityCurrent:ctx]){reply(nil,OR6APIError(@"owner_mismatch",@"none"));return nil;}
 BOOL mutation=OR6API6AMutation(op),protected=[@[@"locked.conversations.list",@"locked.conversations.get",@"locked.conversations.lock",@"locked.conversations.unlock",@"locked.memory"]containsObject:op];if(_calls.count>=8||(mutation&&_mutating)){reply(nil,OR6APIError(@"conflict",@"none"));return nil;}
 if(protected&&(![self grantCurrent:ctx]||(p[@"projectId"]&&![p[@"projectId"]isEqual:_grant[@"projectId"]]))){reply(nil,OR6APIError(@"access_denied",@"none"));return nil;}
 if(mutation){NSError*e=nil;if([_journal record:p[@"operationId"]scope:_scope error:&e]||e){reply(nil,e?:OR6APIError(@"duplicate_operation",@"none"));return nil;}}
 if([op isEqual:@"conversations.report"]){NSDictionary*reason=_reasons[p[@"reasonId"]];BOOL valid=[_catalogId isEqual:p[@"catalogId"]]&&[self now]-_catalogAt<=300&&[reason[@"canSubmit"]isEqual:@YES];NSMutableSet*seen=[NSMutableSet set];for(NSDictionary*f in p[@"additionalFields"]){NSDictionary*definition=nil;for(NSDictionary*d in reason[@"additionalFields"])if([d[@"id"]isEqual:f[@"id"]])definition=d;if(!definition||[seen containsObject:f[@"id"]])valid=NO;[seen addObject:f[@"id"]];}for(NSDictionary*d in reason[@"additionalFields"])if([d[@"required"]isEqual:@YES]){BOOL present=NO;for(NSDictionary*f in p[@"additionalFields"])if([f[@"id"]isEqual:d[@"id"]]&&[f[@"value"]length])present=YES;if(!present)valid=NO;}if(!valid){reply(nil,OR6APIError(@"invalid_request",@"none"));return nil;}}
 NSTimeInterval secretAt=0;NSDictionary*secret=nil;if([@[@"locked.pin.create",@"locked.pin.verify",@"locked.pin.change"]containsObject:op]){NSDictionary*entry=_secrets[p[@"operationId"]];secretAt=[entry[@"at"]doubleValue];secret=[[entry[@"value"]retain]autorelease];[_secrets removeObjectForKey:p[@"operationId"]];NSSet*keys=secret?[NSSet setWithArray:[secret allKeys]]:[NSSet set],*expected=[NSSet setWithArray:[op isEqual:@"locked.pin.create"]?@[@"pin",@"pin_confirmation"]:[op isEqual:@"locked.pin.verify"]?@[@"pin"]:@[@"current_pin",@"new_pin"]];if(![entry[@"context"]isEqual:ctx]||[self now]-[entry[@"at"]doubleValue]>300||![keys isEqual:expected]||([op isEqual:@"locked.pin.create"]&&![secret[@"pin"]isEqual:secret[@"pin_confirmation"]])){reply(nil,OR6APIError(@"invalid_request",@"none"));return nil;}}
 if([op isEqual:@"locked.pin.reset"]){NSDictionary*a=_authorizations[p[@"authorizationId"]];if(![a[@"verified"]isEqual:@YES]||![a[@"context"]isEqual:ctx]||[self now]-[a[@"at"]doubleValue]>600){reply(nil,OR6APIError(@"login_required",@"none"));return nil;}}
 if([op isEqual:@"locked.conversations.list"]){if(p[@"cursor"]==NSNull.null)_cursors[p[@"projectId"]]=[NSMutableSet set];else if(![_cursors[p[@"projectId"]]containsObject:p[@"cursor"]]){reply(nil,OR6APIError(@"invalid_request",@"none"));return nil;}}
 OR6API6ACall*c=[[[OR6API6ACall alloc]init]autorelease];c->owner=self;c->op=[op copy];c->p=[OR6APIJSONSnapshot(p,32768)retain];c->ctx=[OR6APIJSONSnapshot(ctx,4096)retain];c->secret=[secret retain];c->secretAt=secretAt;c->reply=[reply copy];c->mutation=mutation;c->protected=protected;[_calls addObject:c];if(mutation){_mutating=YES;[self mutate:c];}
 else if([op isEqual:@"locked.access.clear"]){[self clearLockedAccess];[self finish:c result:@{@"accessGranted":@NO}error:nil];}
 else if([op isEqual:@"locked.status"])[self loadStatus:c completion:^(NSDictionary*r,NSError*e){[self finish:c result:r error:e];}];
 else if([op isEqual:@"locked.reconcile"])[self reconcile:c];
 else if([op isEqual:@"locked.memory"]){[self request:OR6API6ARequest(@"locked.conversations.get",p,@{@"grant_pin":_grant[@"pin"]})write:NO call:c completion:^(NSDictionary*v,NSError*unused){(void)unused;id raw=v[@"json"];if([v[@"status"]integerValue]!=200||![raw isKindOfClass:NSDictionary.class]||![raw[@"conversation_id"]isEqual:p[@"conversationId"]]||![raw[@"gizmo_id"]isEqual:p[@"projectId"]]){[self finish:c result:nil error:OR6APIError(@"access_denied",@"none")];return;}[self read:c];}];}
 else[self read:c];return c;
}
- (void)didValidate:(NSString*)o result:(NSDictionary*)r context:(NSDictionary*)c{if([_next respondsToSelector:_cmd])[_next didValidate:o result:r context:c];}
- (void)releaseCompletedDraft:(NSString*)d context:(NSDictionary*)c{if([_next respondsToSelector:_cmd])[_next releaseCompletedDraft:d context:c];}
- (NSDictionary*)diagnostics{return@{@"activeCount":@(_calls.count),@"requests":@(_requests),@"writeAttempts":@(_writes),@"accessGranted":@(_grant!=nil),@"automaticReplay":@NO,@"credentialsExposed":@NO};}
- (void)dealloc{[[NSNotificationCenter defaultCenter]removeObserver:self];[self deactivate];[_next release];[_HTTP release];[_journal release];[_extension release];[_ops release];[_caps release];[_calls release];[_secrets release];[_authorizations release];[_cursors release];[_scope release];[_clock release];[super dealloc];}
@end
