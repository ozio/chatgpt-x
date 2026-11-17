#import "OR6API6EProvider.h"
#import "OR6API6EPolicy.h"
#import "../OR6APIOperations.h"
#import "../priority7/OR6API7Policy.h"
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>
static NSTimeInterval Now(void){return NSProcessInfo.processInfo.systemUptime;}
static NSString*NewID(void){CFUUIDRef v=CFUUIDCreate(NULL);NSString*s=[(NSString*)CFUUIDCreateString(NULL,v)autorelease];CFRelease(v);return s.lowercaseString;}
static BOOL Context(id c){return[c isKindOfClass:NSDictionary.class]&&[c[@"key"]isKindOfClass:NSString.class]&&[c[@"key"]length]&&[c[@"key"]length]<=256&&OR6APISchemaCheck(c[@"generation"],@{@"type":@"integer",@"minimum":@1},@{});}
static NSString*Issue(NSInteger s){return s==401?@"not_authenticated":s==403?@"service_challenge":s==429?@"rate_limited":s==404?@"not_found":@"upstream_error";}
static NSError*ErrorSnapshot(NSError*error){if(!error)return nil;if(![error isKindOfClass:NSError.class])return OR6APIError(@"invalid_response",@"possible");id code=error.userInfo[@"code"],dispatch=error.userInfo[@"dispatch"];NSString*c=[code isKindOfClass:NSString.class]?[[code copy]autorelease]:nil,*d=[dispatch isKindOfClass:NSString.class]?[[dispatch copy]autorelease]:nil;return OR6APIError(c,d);}
static NSString*JournalScope(NSDictionary*ctx,NSDictionary*identity){NSString*s=[NSString stringWithFormat:@"%lu:%@|%lu:%@",(unsigned long)[identity[@"accountId"]length],identity[@"accountId"],(unsigned long)[identity[@"userId"]length],identity[@"userId"]];return OR6API6EFingerprint(ctx[@"key"],@"identity",s);}
static BOOL Hash(id v){return[v isKindOfClass:NSString.class]&&[v length]==64&&[v rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"]invertedSet]].location==NSNotFound;}
static BOOL Plan(id p){if(![p isKindOfClass:NSDictionary.class]||[p count]!=3)return NO;id session=p[@"sessionFingerprint"],trust=p[@"trustFingerprint"];if([p[@"mode"]isEqual:@"session"])return Hash(session)&&(trust==NSNull.null||Hash(trust));if([p[@"mode"]isEqual:@"trust"])return session==NSNull.null&&Hash(trust);return[p[@"mode"]isEqual:@"all"]&&session==NSNull.null&&trust==NSNull.null;}
@class OR6API6ECall;
@interface OR6API6EProvider(){id<OR6APIProvider>_next;id<OR6API7HTTP>_HTTP;OR6APIOperations*_journal;NSDictionary*_extension,*_ops,*_identity,*_identityContext,*_catalog;NSString*_scope,*_catalogId;NSSet*_caps;NSMutableSet*_calls;NSUInteger _epoch,_requests,_writes;NSTimeInterval _catalogAt;BOOL _mutating,_deactivating;}
- (void)cancel:(OR6API6ECall*)call;
@end
@interface OR6API6ECall:NSObject<OR6APITask>{@public OR6API6EProvider*owner;NSString*op,*journalScope;NSDictionary*p,*ctx,*target,*plan;OR6APIReply reply;id<OR6APITask>child;NSUInteger serial;NSTimeInterval selectionAt;BOOL terminal,mutation,reserved,possible,responded;}
@end
@implementation OR6API6ECall
- (void)cancel{if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self cancel];});return;}if(!terminal)[owner cancel:self];}
- (void)dealloc{[op release];[journalScope release];[p release];[ctx release];[target release];[plan release];[reply release];[child release];[super dealloc];}
@end
@implementation OR6API6EProvider
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP extension:(NSDictionary*)ext journalDirectory:(NSString*)dir capabilities:(NSSet*)caps error:(NSError**)error{
 if(!(self=[super init]))return nil;_extension=[OR6APIJSONSnapshot(ext,1024*1024)retain];if(!next||!HTTP||(caps&&![caps isKindOfClass:NSSet.class])||![_extension[@"operations"]isKindOfClass:NSArray.class]){if(error)*error=OR6APIError(@"invalid_request",@"none");[self release];return nil;}NSMutableDictionary*ops=[NSMutableDictionary dictionary];for(NSDictionary*o in _extension[@"operations"]){if(!OR6API6ECommand(o[@"id"])||ops[o[@"id"]]){if(error)*error=OR6APIError(@"invalid_request",@"none");[self release];return nil;}ops[o[@"id"]]=o;}if(caps&&![caps isSubsetOfSet:[NSSet setWithArray:ops.allKeys]]){if(error)*error=OR6APIError(@"invalid_request",@"none");[self release];return nil;}_ops=[ops copy];_next=[next retain];_HTTP=[HTTP retain];_caps=[(caps?:[NSSet set])copy];_calls=[NSMutableSet new];_journal=[[OR6APIOperations alloc]initWithDirectory:dir error:error];if(!_journal){[self release];return nil;}return self;
}
- (BOOL)identityCurrent:(NSDictionary*)ctx{return[_identityContext isEqual:ctx]&&_identity.count==2;}
- (void)clearCatalog{[_catalog release];_catalog=nil;[_catalogId release];_catalogId=nil;_catalogAt=0;}
- (void)deactivate{BOOL nested=_deactivating;_deactivating=YES;[_identity release];_identity=nil;[_identityContext release];_identityContext=nil;[self clearCatalog];for(OR6API6ECall*c in [[_calls.allObjects copy]autorelease])[self cancel:c];_deactivating=nested;}
- (void)observeContext:(NSDictionary*)ctx{
 if(_deactivating||!NSThread.isMainThread||!Context(ctx)||([_scope isEqual:ctx[@"key"]]&&_epoch==[ctx[@"generation"]unsignedIntegerValue]))return;[_scope release];_scope=[ctx[@"key"]copy];_epoch=[ctx[@"generation"]unsignedIntegerValue];if(![_identityContext isEqual:ctx]){[self deactivate];return;}_deactivating=YES;for(OR6API6ECall*c in [[_calls.allObjects copy]autorelease])[self cancel:c];_deactivating=NO;
}
- (BOOL)bindIdentity:(NSDictionary*)identity context:(NSDictionary*)ctx{
 NSDictionary*s=@{@"type":@"object",@"properties":@{@"accountId":@{@"type":@"string",@"minLength":@1,@"maxLength":@128},@"userId":@{@"type":@"string",@"minLength":@1,@"maxLength":@256}},@"required":@[@"accountId",@"userId"],@"additionalProperties":@NO};if(_deactivating||!NSThread.isMainThread||!Context(ctx)||!OR6APISchemaCheck(identity,s,@{}))return NO;for(NSString*k in identity)if([identity[k]rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound)return NO;if(![_identity isEqual:identity]||![_identityContext isEqual:ctx])[self deactivate];[_identity release];_identity=[OR6APIJSONSnapshot(identity,4096)retain];[_identityContext release];_identityContext=[OR6APIJSONSnapshot(ctx,4096)retain];return YES;
}
- (BOOL)current:(OR6API6ECall*)c{return!c->terminal&&[_scope isEqual:c->ctx[@"key"]]&&_epoch==[c->ctx[@"generation"]unsignedIntegerValue]&&[self identityCurrent:c->ctx];}
- (NSDictionary*)receipt:(OR6API6ECall*)c acknowledged:(BOOL)ack verified:(BOOL)verified{return@{@"operationId":c->p[@"operationId"],@"action":c->plan[@"mode"],@"serverAcknowledged":@(ack),@"verified":@(verified),@"affectsCurrentSession":@([c->plan[@"mode"]isEqual:@"all"])};}
- (void)finish:(OR6API6ECall*)c result:(NSDictionary*)r error:(NSError*)e{
 if(c->terminal)return;if(c->responded&&e&&[e.userInfo[@"dispatch"]isEqual:@"none"])e=OR6APIError(e.userInfo[@"code"],@"possible");[c retain];c->terminal=YES;if(c->reserved){NSString*state=e?([e.userInfo[@"dispatch"]isEqual:@"none"]?@"rejected":@"uncertain"):@"completed";if(![_journal finish:c->p[@"operationId"]scope:c->journalScope state:state metadata:r?@{@"receipt":r,@"plan":c->plan}:@{}error:NULL]){r=nil;e=OR6APIError(@"storage_failure",c->possible?@"possible":@"none");}}
 if(c->mutation)_mutating=NO;OR6APIReply cb=[[c->reply copy]autorelease];[c->reply release];c->reply=nil;id<OR6APITask>task=[[c->child retain]autorelease];[c->child release];c->child=nil;[_calls removeObject:c];if(e)[task cancel];if(!e&&[c->op isEqual:@"account.sessions.revokeAll"])[self deactivate];if(cb)cb(r,e);[c release];
}
- (void)cancel:(OR6API6ECall*)c{[self finish:c result:nil error:OR6APIError(@"cancelled",c->possible?@"possible":@"none")];}
- (void)request:(NSURLRequest*)r write:(BOOL)write call:(OR6API6ECall*)c completion:(OR6APIReply)completion{
 if(!r||!OR6API6EAllowedRequest(r)||![self identityCurrent:c->ctx]){[self finish:c result:nil error:OR6APIError(@"invalid_request",@"none")];return;}
 NSDictionary*privateContext=@{@"key":c->ctx[@"key"],@"generation":c->ctx[@"generation"],@"accountId":_identity[@"accountId"],@"userId":_identity[@"userId"]};NSUInteger serial=++c->serial;_requests++;if(write){_writes++;c->possible=YES;}__block BOOL delivered=NO,queued=NO;
 id<OR6APITask>task=[_HTTP request:r context:privateContext completion:^(NSDictionary*v,NSError*e){
  @synchronized(c){if(queued)return;queued=YES;}
  // OR6API7HTTP has no callback-queue or immutability guarantee. Copy while
  // the callback owns its arguments, before its producer can mutate them.
  NSAutoreleasePool*pool=[NSAutoreleasePool new];NSDictionary*snapshot=OR6APIJSONSnapshot(v,2*1024*1024);NSError*failure=ErrorSnapshot(e);
  void(^consume)(void)=^{
   if(delivered||![self current:c]||serial!=c->serial)return;delivered=YES;
   if(failure){[self finish:c result:nil error:OR6APIError(failure.userInfo[@"code"],c->possible?failure.userInfo[@"dispatch"]:@"none")];return;}
   if(![snapshot isKindOfClass:NSDictionary.class]||!OR6APISchemaCheck(snapshot[@"status"],@{@"type":@"integer",@"minimum":@100,@"maximum":@599},@{})){[self finish:c result:nil error:OR6APIError(@"unknown_wire_shape",write?@"possible":@"none")];return;}
   if(write)c->responded=YES;completion(snapshot,nil);
  };
  if(NSThread.isMainThread)consume();else dispatch_async(dispatch_get_main_queue(),consume);[pool drain];
 }];
 if(c->terminal||serial!=c->serial)[task cancel];else if(task){[c->child release];c->child=[task retain];}else[self finish:c result:nil error:OR6APIError(@"unavailable",write?@"possible":@"none")];
}
- (void)load:(BOOL)trusted call:(OR6API6ECall*)c completion:(void(^)(NSArray*))completion{
 [self request:OR6API6ERequest(@"account.sessions.list",@{@"includeTrustedDevices":@(trusted)},_identity[@"accountId"])write:NO call:c completion:^(NSDictionary*v,NSError*unused){(void)unused;NSError*e=nil;NSArray*records=[v[@"status"]integerValue]==200?OR6API6ERecords(v[@"json"],&e):nil;if(!records)[self finish:c result:nil error:e?:OR6APIError(Issue([v[@"status"]integerValue]),@"none")];else completion(records);}];
}
- (void)list:(OR6API6ECall*)c{
 [self load:[c->p[@"includeTrustedDevices"]boolValue]call:c completion:^(NSArray*rows){NSMutableDictionary*catalog=[NSMutableDictionary dictionary];NSMutableArray*items=[NSMutableArray array];for(NSDictionary*row in rows){NSString*t=NewID();catalog[t]=row;[items addObject:OR6API6EPublicDevice(row,t)];}[self clearCatalog];_catalog=[catalog copy];_catalogId=[NewID()copy];_catalogAt=Now();[self finish:c result:@{@"catalogId":_catalogId,@"items":items}error:nil];}];
}
- (BOOL)absent:(NSDictionary*)plan records:(NSArray*)rows scope:(NSString*)scope{
 BOOL sessionGone=YES,trustGone=YES;for(NSDictionary*r in rows){if(r[@"sessionId"]!=NSNull.null&&[OR6API6EFingerprint(scope,@"session",r[@"sessionId"])isEqual:plan[@"sessionFingerprint"]])sessionGone=NO;if(r[@"deviceHash"]!=NSNull.null&&[OR6API6EFingerprint(scope,@"trust",r[@"deviceHash"])isEqual:plan[@"trustFingerprint"]]&&![r[@"isTrusted"]isEqual:@NO])trustGone=NO;}return sessionGone&&trustGone;
}
- (void)write:(OR6API6ECall*)c records:(NSArray*)rows{
 if([c->op isEqual:@"account.sessions.revoke"]&&(Now()-c->selectionAt<0||Now()-c->selectionAt>300)){[self finish:c result:nil error:OR6APIError(@"expired",@"none")];return;}
 NSString*wireOp=c->op;NSDictionary*wire=@{};NSDictionary*plan=nil;
 if([c->op isEqual:@"account.sessions.revokeAll"])plan=@{@"mode":@"all",@"sessionFingerprint":NSNull.null,@"trustFingerprint":NSNull.null};
 else{NSDictionary*match=nil;BOOL trust=[c->target[@"kind"]isEqual:@"signed_out_trusted"];NSString*kind=trust?@"trust":@"session",*key=trust?@"deviceHash":@"sessionId",*fp=OR6API6EFingerprint(c->journalScope,kind,c->target[key]);for(NSDictionary*r in rows)if(r[key]!=NSNull.null&&[OR6API6EFingerprint(c->journalScope,kind,r[key])isEqual:fp]){if(match){[self finish:c result:nil error:OR6APIError(@"conflict",@"none")];return;}match=r;}if(!match){[self finish:c result:nil error:OR6APIError(@"not_found",@"none")];return;}if(![match[@"canRevoke"]isEqual:@YES]||(trust&&![match[@"kind"]isEqual:@"signed_out_trusted"])){[self finish:c result:nil error:OR6APIError(@"permission_denied",@"none")];return;}
  NSString*trustFP=(trust||[match[@"isTrusted"]isEqual:@YES])&&match[@"deviceHash"]!=NSNull.null?OR6API6EFingerprint(c->journalScope,@"trust",match[@"deviceHash"]):nil;plan=@{@"mode":trust?@"trust":@"session",@"sessionFingerprint":trust?(id)NSNull.null:fp,@"trustFingerprint":trustFP?:(id)NSNull.null};wireOp=trust?@"account.sessions.removeTrust":@"account.sessions.revoke";wire=trust?@{@"deviceHash":match[@"deviceHash"]}:@{@"sessionId":match[@"sessionId"]};}
 c->plan=[plan retain];NSError*e=nil;if(![_journal reserve:c->p[@"operationId"]command:c->op request:@{@"plan":plan}scope:c->journalScope error:&e]){[self finish:c result:nil error:e];return;}c->reserved=YES;if(![_journal finish:c->p[@"operationId"]scope:c->journalScope state:@"uncertain"metadata:@{}error:&e]){[self finish:c result:nil error:e];return;}
 [self request:OR6API6ERequest(wireOp,wire,_identity[@"accountId"])write:YES call:c completion:^(NSDictionary*v,NSError*unused){(void)unused;if(!OR6API6EAcknowledged(v)){[self finish:c result:nil error:OR6APIError([v[@"status"]integerValue]>=400?Issue([v[@"status"]integerValue]):@"unknown_wire_shape",@"possible")];return;}[self clearCatalog];[self finish:c result:[self receipt:c acknowledged:YES verified:NO]error:nil];}];
}
- (void)reconcile:(OR6API6ECall*)c{
 for(OR6API6ECall*active in _calls)if(active!=c&&active->mutation&&[active->p[@"operationId"]isEqual:c->p[@"operationId"]]){[self finish:c result:nil error:OR6APIError(@"conflict",@"none")];return;}
 NSError*e=nil;NSDictionary*r=[_journal record:c->p[@"operationId"]scope:c->journalScope error:&e];
 if(!r||!OR6API6EMutation(r[@"command"])||[r[@"state"]isEqual:@"rejected"]){[self finish:c result:nil error:e?:OR6APIError(@"invalid_operation_state",@"none")];return;}
 id request=r[@"request"],result=r[@"result"];NSDictionary*plan=[request isKindOfClass:NSDictionary.class]?request[@"plan"]:nil;if(!plan&&[result isKindOfClass:NSDictionary.class])plan=result[@"plan"];
 id oldReceipt=[result isKindOfClass:NSDictionary.class]?result[@"receipt"]:nil;BOOL completed=[r[@"state"]isEqual:@"completed"];
 if(!Plan(plan)||([r[@"command"]isEqual:@"account.sessions.revokeAll"]!=[plan[@"mode"]isEqual:@"all"])||(completed&&(!OR6APISchemaCheck(oldReceipt,_extension[@"types"][@"API6EReceipt"],_extension[@"types"])||![oldReceipt[@"operationId"]isEqual:c->p[@"operationId"]]||![oldReceipt[@"action"]isEqual:plan[@"mode"]]||![oldReceipt[@"affectsCurrentSession"]isEqual:@([plan[@"mode"]isEqual:@"all"])]) )){[self finish:c result:nil error:OR6APIError(@"storage_failure",@"none")];return;}
 if([plan[@"mode"]isEqual:@"all"]){[self finish:c result:nil error:OR6APIError(@"uncertain_outcome",@"possible")];return;}
 c->plan=[plan retain];BOOL acknowledged=completed&&[oldReceipt[@"serverAcknowledged"]isEqual:@YES];
 [self load:YES call:c completion:^(NSArray*rows){if(![self absent:plan records:rows scope:c->journalScope]){[self finish:c result:nil error:OR6APIError(@"uncertain_outcome",@"possible")];return;}NSDictionary*receipt=[self receipt:c acknowledged:acknowledged verified:YES];if(!completed&&![_journal finish:c->p[@"operationId"]scope:c->journalScope state:@"completed"metadata:@{@"receipt":receipt,@"plan":plan}error:NULL]){[self finish:c result:nil error:OR6APIError(@"storage_failure",@"possible")];return;}[self finish:c result:receipt error:nil];}];
}
- (id<OR6APITask>)execute:(NSString*)op parameters:(NSDictionary*)p context:(NSDictionary*)ctx event:(OR6APIEvent)event completion:(OR6APIReply)reply{
 if(!NSThread.isMainThread){if(reply)dispatch_async(dispatch_get_main_queue(),^{reply(nil,OR6APIError(@"invalid_request",@"none"));});return nil;}
 [self observeContext:ctx];
 if(!OR6API6ECommand(op)){if([op isEqual:@"auth.logout"])[self deactivate];return[_next execute:op parameters:p context:ctx event:event completion:reply];}
 if(!NSThread.isMainThread||!Context(ctx)||!OR6APIJSONSnapshot(p,16384)||!OR6APISchemaCheck(p,_ops[op][@"requestSchema"],_extension[@"types"])||(p[@"operationId"]&&(!OR6API7UUID(p[@"operationId"])||![p[@"operationId"]isEqual:[p[@"operationId"]lowercaseString]]))){reply(nil,OR6APIError(@"invalid_request",@"none"));return nil;}if(_deactivating){reply(nil,OR6APIError(@"stale_context",@"none"));return nil;}if(![_caps containsObject:op]){reply(nil,OR6APIError(@"capability_unverified",@"none"));return nil;}
 NSDictionary*handoff=OR6API6EHandoff(op);if(handoff){reply(handoff,nil);return nil;}if(![self identityCurrent:ctx]){reply(nil,OR6APIError(@"owner_mismatch",@"none"));return nil;}BOOL mutation=OR6API6EMutation(op);if(_calls.count>=8||(mutation&&_mutating)){reply(nil,OR6APIError(@"conflict",@"none"));return nil;}NSString*scope=JournalScope(ctx,_identity);if(mutation){NSError*e=nil;if([_journal record:p[@"operationId"]scope:scope error:&e]||e){reply(nil,e?:OR6APIError(@"duplicate_operation",@"none"));return nil;}}
 NSDictionary*target=nil;if([op isEqual:@"account.sessions.revoke"]){target=_catalog[p[@"targetId"]];if(![_catalogId isEqual:p[@"catalogId"]]||!target||Now()-_catalogAt<0||Now()-_catalogAt>300){reply(nil,OR6APIError(@"expired",@"none"));return nil;}if(![target[@"canRevoke"]isEqual:@YES]){reply(nil,OR6APIError(@"permission_denied",@"none"));return nil;}}
 OR6API6ECall*c=[[[OR6API6ECall alloc]init]autorelease];c->owner=self;c->op=[op copy];c->journalScope=[scope copy];c->p=[OR6APIJSONSnapshot(p,16384)retain];c->ctx=[OR6APIJSONSnapshot(ctx,4096)retain];c->target=[target retain];c->selectionAt=_catalogAt;c->reply=[reply copy];c->mutation=mutation;[_calls addObject:c];if(mutation){_mutating=YES;[self load:YES call:c completion:^(NSArray*rows){[self write:c records:rows];}];}else if([op isEqual:@"account.sessions.reconcile"])[self reconcile:c];else[self list:c];return c;
}
- (void)didValidate:(NSString*)o result:(NSDictionary*)r context:(NSDictionary*)c{if([_next respondsToSelector:_cmd])[_next didValidate:o result:r context:c];}
- (void)releaseCompletedDraft:(NSString*)d context:(NSDictionary*)c{if([_next respondsToSelector:_cmd])[_next releaseCompletedDraft:d context:c];}
- (NSDictionary*)diagnostics{return@{@"activeCount":@(_calls.count),@"requests":@(_requests),@"writeAttempts":@(_writes),@"catalogSize":@(_catalog.count),@"automaticReplay":@NO,@"credentialsExposed":@NO};}
- (void)dealloc{[self deactivate];[_next release];[_HTTP release];[_journal release];[_extension release];[_ops release];[_caps release];[_calls release];[_scope release];[super dealloc];}
@end
