#import "OR6ChatNativeProvider.h"
#import "OR6ChatWebPreparation.h"
#import "OR6ChatNativePolicy.h"
#import "OR6ChatNativeHTTP.h"
#import "OR6ChatUIState.h"
#import "OR6ChatRecoveryStore.h"
#import "../api/OR6APIWebAdapter.h"
#import "../api/OR6APIOperations.h"
#import "../api/OR6APIWire.h"
#import "../auth/OR6AuthEngine.h"
#import <dispatch/dispatch.h>
#include <mach/mach_time.h>
static double Clock(void){mach_timebase_info_data_t t;mach_timebase_info(&t);return(double)mach_absolute_time()*t.numer/t.denom/1e9;}
static NSArray*PlanFileIDs(NSDictionary*plan){
 if(!plan)return @[];NSDictionary*last=[plan[@"body"][@"messages"]lastObject];NSMutableSet*expected=[NSMutableSet set];for(NSDictionary*f in last[@"metadata"][@"attachments"])if([f[@"id"]isKindOfClass:NSString.class])[expected addObject:f[@"id"]];
 for(id p in last[@"content"][@"parts"]){if(![p isKindOfClass:NSDictionary.class])continue;NSString*pointer=p[@"asset_pointer"];for(NSString*prefix in @[@"sediment://",@"file-service://"])if([pointer hasPrefix:prefix])[expected addObject:[pointer substringFromIndex:prefix.length]];}return[expected.allObjects sortedArrayUsingSelector:@selector(compare:)];
}
static BOOL PlanFilesMatch(NSArray*identifiers,NSDictionary*conversation,NSString*uid){
 if(!identifiers)return YES;if(![identifiers isKindOfClass:NSArray.class]||identifiers.count>8)return NO;for(id f in identifiers)if(![f isKindOfClass:NSString.class]||![f length]||[f length]>128)return NO;NSSet*expected=[NSSet setWithArray:identifiers];if(!expected.count)return YES;
 NSMutableSet*found=[NSMutableSet set];for(NSDictionary*m in conversation[@"messages"]){if(!OR6CNSameUUID(m[@"id"],uid)||![m[@"role"]isEqual:@"user"])continue;
  for(NSDictionary*p in m[@"parts"]){NSDictionary*d=p[@"data"];if([p[@"kind"]isEqual:@"asset"]&&[d[@"id"]isKindOfClass:NSString.class])[found addObject:d[@"id"]];NSString*pointer=d[@"asset_pointer"];for(NSString*prefix in @[@"sediment://",@"file-service://"])if([pointer hasPrefix:prefix])[found addObject:[pointer substringFromIndex:prefix.length]];}}
 return[expected isSubsetOfSet:found];
}
@class OR6ChatNativeTask;
@interface OR6ChatNativeProvider(){
 OR6APIWebAdapter*_adapter;id<OR6ChatPreparation>_preparation;NSString*_roots;OR6APIOperations*_journal;OR6ChatRecoveryStore*_recovery;NSDictionary*_snapshot;
 NSTimer*_timer;NSString*_pageKey,*_UA,*_model,*_blocked,*_phase,*_issue;
 NSUInteger _credentialGeneration,_generation,_workers,_reuses,_prepares,_sends,_readbacks,_requests,_sequence;
 BOOL _reconcilingOnly,_journalCompleted,_modelLoading,_ownerChecked,_preparing,_dispatched,_terminal,_finishedAssistantText;
 NSString*_readbackIssue,*_assistantText,*_conversationTitle;NSArray*_messageParts;
 BOOL _recoveringPartial,_readInFlight;NSUInteger _recoveryAttempts;double _recoveryDeadline,_nextReadbackAt;
 double _began;NSMutableDictionary*_timings;
 NSDictionary*_parameters,*_context,*_plan,*_nextPlan,*_planMessage;NSDictionary*(^_readContextSource)(void);NSString*_nonce,*_cid,*_uid,*_aid,*_persistedIdentity;
 OR6APIReply _reply;OR6APIEvent _event;OR6ChatNativeTask*_task,*_networkTask;id<OR6APITask>_readTask,_modelTask;
}
- (void)cancelGeneration:(NSUInteger)generation;
- (void)stopRecoveryForGeneration:(NSUInteger)generation;
@end
@interface OR6ChatNativeTask:NSObject<OR6APITask>{@public OR6ChatNativeProvider*owner;NSUInteger generation;BOOL stopped;}
- (BOOL)cancelled;
- (void)cancelForUserStop;
- (void)prepareForUserStop;
@end
@implementation OR6ChatNativeTask
- (void)cancel{@synchronized(self){stopped=YES;}if(owner)[owner cancelGeneration:generation];}
- (BOOL)cancelled{@synchronized(self){return stopped;}}
- (void)prepareForUserStop{[owner stopRecoveryForGeneration:generation];}
- (void)cancelForUserStop{[self prepareForUserStop];[self cancel];}
@end
@implementation OR6ChatNativeProvider
- (id)initWithAdapter:(OR6APIWebAdapter*)adapter hostView:(UIView*)host roots:(NSString*)roots{
 NSString*dir=[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES)[0]stringByAppendingPathComponent:@"ChatGPTXRecovery-v1"];return[self initWithAdapter:adapter hostView:host roots:roots recoveryDirectory:dir];
}
- (id)initWithAdapter:(OR6APIWebAdapter*)adapter hostView:(UIView*)host roots:(NSString*)roots recoveryDirectory:(NSString*)directory{
 return[self initWithAdapter:adapter preparation:[[[OR6ChatWebPreparation alloc]initWithHostView:host]autorelease]roots:roots recoveryDirectory:directory];
}
- (id)initWithAdapter:(OR6APIWebAdapter*)adapter preparation:(id<OR6ChatPreparation>)preparation roots:(NSString*)roots recoveryDirectory:(NSString*)directory{
 if((self=[super init])){_adapter=[adapter retain];_preparation=[preparation retain];_roots=[roots copy];NSString*dir=[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES)[0]stringByAppendingPathComponent:@"ChatGPTXWebOps-v1"];_journal=[[OR6APIOperations alloc]initWithDirectory:dir error:NULL];_recovery=[[OR6ChatRecoveryStore alloc]initWithDirectory:directory];if(!adapter||!preparation||!_journal||!_recovery){[self release];return nil;}[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(memoryWarning:)name:UIApplicationDidReceiveMemoryWarningNotification object:nil];}return self;
}
- (BOOL)saveRecoveryCompleted:(BOOL)completed{
 if(_plan||!_snapshot)return YES;NSMutableDictionary*s=[[_snapshot mutableCopy]autorelease];s[@"conversationId"]=_cid?:(id)NSNull.null;s[@"userMessageId"]=_uid;s[@"assistantMessageId"]=_aid?:(id)NSNull.null;s[@"text"]=_assistantText?:@"";s[@"finished"]=@(_finishedAssistantText);s[@"completed"]=@(completed);s[@"updatedAt"]=@([[NSDate date]timeIntervalSince1970]);if(completed)s[@"autoResume"]=@NO;
 if(![_recovery save:s])return NO;[_snapshot release];_snapshot=[s copy];return YES;
}
- (NSDictionary*)recoverySnapshotForConversation:(NSString*)identifier{
 NSString*scope=_adapter.contextKey;NSDictionary*s=[_recovery latestForScope:scope conversation:identifier];if(!s)return nil;NSDictionary*r=[_journal record:s[@"operationId"]scope:scope error:NULL];if(!r||[r[@"state"]isEqual:@"rejected"])return nil;
 NSString*hash=r[@"request"][@"textSHA256"];if(hash&&![hash isEqual:OR6CNHash(s[@"request"][@"text"])])return nil;
 NSDictionary*m=r[@"result"]?:r[@"metadata"];for(NSString*k in @[@"conversationId",@"userMessageId",@"assistantMessageId"])if(OR6CNUUID(m[k])&&!OR6CNSameUUID(m[k],s[k]))return nil;return s;
}
- (void)clearRecoveryForCurrentAccount{[self deactivate];[_recovery clearScope:_adapter.contextKey];}
- (void)stopRecoveryForGeneration:(NSUInteger)generation{
 if(generation!=_generation||!_snapshot)return;NSMutableDictionary*s=[[_snapshot mutableCopy]autorelease];s[@"autoResume"]=@NO;[_snapshot release];_snapshot=[s copy];[self saveRecoveryCompleted:NO];
}
- (BOOL)contextCurrent{return _pageKey.length&&[_pageKey isEqual:_adapter.contextKey]&&_credentialGeneration==_adapter.credentialGeneration;}
- (BOOL)current{return _reply&&!_terminal&&[self contextCurrent]&&[_context[@"key"]isEqual:_pageKey];}
- (void)phase:(NSString*)p{[_phase release];_phase=[p copy];}
- (void)mark:(NSString*)name{if(_timings&&!_timings[name])_timings[name]=@((Clock()-_began)*1000);}
- (NSDictionary*)receipt:(NSString*)state persisted:(BOOL)saved{return @{@"operationId":_parameters[@"operationId"],@"state":state,@"conversationId":_cid?:(id)NSNull.null,@"userMessageId":_uid?:(id)NSNull.null,@"assistantMessageId":_aid?:(id)NSNull.null,@"persisted":@(saved)};}
- (void)emit:(NSString*)state{if(_event&&[self current]){OR6APIEvent event=[[_event copy]autorelease];event(@{@"name":@"state",@"payload":[self receipt:state persisted:NO]});}}
- (BOOL)persistUncertain{
 if(_journalCompleted)return YES;
 NSString*identity=[NSString stringWithFormat:@"%@|%@|%@",_cid?:@"",_uid?:@"",_aid?:@""];if([identity isEqual:_persistedIdentity])return YES;
 if(![_journal finish:_parameters[@"operationId"]scope:_context[@"key"]state:@"uncertain"metadata:[self receipt:@"uncertain"persisted:NO]error:NULL])return NO;[_persistedIdentity release];_persistedIdentity=[identity copy];return YES;
}
- (void)stopTimer{[_timer invalidate];[_timer release];_timer=nil;}
- (NSDictionary*)preparationContext{return _pageKey?@{@"key":_pageKey,@"generation":@(_credentialGeneration)}:nil;}
- (void)releasePage{[self stopTimer];[_preparation deactivate];[_UA release];_UA=nil;}
- (void)park{[self stopTimer];[_preparation endAttempt:_nonce context:[self preparationContext]reuseDocument:YES];}
- (void)memoryWarning:(NSNotification*)n{(void)n;if(!_reply)[self releasePage];}
- (void)blockIssue:(NSString*)code{if([@[@"not_authenticated",@"service_challenge",@"rate_limited"]containsObject:code]){[_blocked release];_blocked=[code copy];}}
- (void)finish:(NSDictionary*)result error:(NSError*)error{
 if(!_reply||_terminal)return;_terminal=YES;[self blockIssue:error.userInfo[@"code"]];
 if(_snapshot){NSString*code=error.userInfo[@"code"];if([@[@"not_authenticated",@"access_denied",@"service_challenge",@"rate_limited",@"owner_mismatch",@"stale_context",@"invalid_response"]containsObject:code]){NSMutableDictionary*s=[[_snapshot mutableCopy]autorelease];s[@"autoResume"]=@NO;[_snapshot release];_snapshot=[s copy];}
  if(![self saveRecoveryCompleted:!error&&[result[@"state"]isEqual:@"completed"]]){error=OR6APIError(@"storage_failure",_dispatched?@"possible":@"none");result=nil;}}
 if(error){if(_dispatched)[self persistUncertain];else[_journal finish:_parameters[@"operationId"]scope:_context[@"key"]state:@"rejected"metadata:@{}error:NULL];}
 NSDictionary*planResult=_plan&&result?@{@"receipt":result,@"streamComplete":_timings[@"streamComplete"]?:@NO,@"assistant":_planMessage?:@{}}:nil;OR6APIReply reply=[[_reply copy]autorelease];[_reply release];_reply=nil;[_event release];_event=nil;_task->owner=nil;[_task release];_task=nil;[_networkTask cancel];[_networkTask release];_networkTask=nil;[_readTask cancel];[_readTask release];_readTask=nil;
 [self mark:@"finishedMs"];[self phase:error?@"failed":result[@"state"]?:@"uncertain"];[_issue release];_issue=[(error.userInfo[@"code"]?:@"")copy];if(!error&&[result[@"state"]isEqual:@"completed"])[self park];else[self releasePage];
 [_snapshot release];_snapshot=nil;[_readbackIssue release];_readbackIssue=nil;[_assistantText release];_assistantText=nil;[_conversationTitle release];_conversationTitle=nil;[_messageParts release];_messageParts=nil;_recoveringPartial=_readInFlight=NO;_nextReadbackAt=-1;[_plan release];_plan=nil;[_planMessage release];_planMessage=nil;[_parameters release];_parameters=nil;[_context release];_context=nil;[_nonce release];_nonce=nil;[_cid release];_cid=nil;[_uid release];_uid=nil;[_aid release];_aid=nil;[_persistedIdentity release];_persistedIdentity=nil;_preparing=NO;
 reply(planResult?:result,error);[NSNotificationCenter.defaultCenter postNotificationName:@"OR6ChatTransportChanged"object:self];
}
- (void)cancelGeneration:(NSUInteger)generation{if(generation==_generation&&_reply)[self finish:nil error:OR6APIError(@"cancelled",_dispatched?@"possible":@"none")];}
- (void)deactivate{
 if(_reply)[self finish:nil error:OR6APIError(@"cancelled",_dispatched?@"possible":@"none")];[self releasePage];[_modelTask cancel];[_modelTask release];_modelTask=nil;_modelLoading=NO;[_model release];_model=nil;[_pageKey release];_pageKey=nil;
}
- (void)loadModel{
 if(_model||_modelLoading||_blocked||![self contextCurrent])return;
 NSDictionary*ctx=_context?:(_readContextSource?_readContextSource():[self preparationContext]);
 if(![ctx isKindOfClass:NSDictionary.class]||![ctx[@"key"]isEqual:_pageKey]||![ctx[@"generation"]isKindOfClass:NSNumber.class]||![ctx[@"generation"]unsignedIntegerValue])return;
 ctx=[[ctx copy]autorelease];_modelLoading=YES;NSString*key=[[_pageKey copy]autorelease];NSUInteger generation=_credentialGeneration;__block BOOL finished=NO;
 id<OR6APITask>task=[_adapter execute:@"models.list"parameters:@{}context:ctx event:nil completion:^(NSDictionary*r,NSError*e){
  finished=YES;if(![self contextCurrent]||![key isEqual:_pageKey]||generation!=_credentialGeneration)return;_modelLoading=NO;[_modelTask release];_modelTask=nil;
  if(e){[self blockIssue:e.userInfo[@"code"]];if(_reply&&!_reconcilingOnly)[self finish:nil error:OR6APIError(e.userInfo[@"code"],@"none")];return;}
  NSString*choice=nil;for(NSDictionary*m in r[@"items"])if([m[@"id"]isEqual:r[@"selectedModelId"]]){choice=m[@"id"];break;}
  if(!choice.length){if(_reply)[self finish:nil error:OR6APIError(@"unknown_wire_shape",@"none")];return;}[_model release];_model=[choice copy];if(_reply)[self advance];
 }];if(!finished)_modelTask=[task retain];
}
- (void)setReadContextSource:(NSDictionary*(^)(void))source{[_readContextSource release];_readContextSource=[source copy];}
- (void)prepareConversation:(NSString*)identifier{
 (void)identifier;if(!NSThread.isMainThread||_reply)return;NSString*key=_adapter.contextKey;if(!key.length)return;
 BOOL same=[self contextCurrent];if(!same){[self deactivate];_pageKey=[key copy];_credentialGeneration=_adapter.credentialGeneration;[_blocked release];_blocked=nil;}
 _prepares++;if(_blocked)return;[self loadModel];[_preparation prepareForContext:[self preparationContext]];
}
- (void)request:(NSString*)path body:(NSDictionary*)body headers:(NSDictionary*)headers stream:(BOOL)stream completion:(void(^)(NSDictionary*))completion{
 if(![self current]||_networkTask){[self finish:nil error:OR6APIError(@"stale_context",_dispatched?@"possible":@"none")];return;}
 NSMutableURLRequest*r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:[@"https://chatgpt.com"stringByAppendingString:path]]];r.HTTPMethod=body?@"POST":@"GET";r.HTTPBody=body?[NSJSONSerialization dataWithJSONObject:body options:0 error:NULL]:nil;
 [r setValue:_UA forHTTPHeaderField:@"User-Agent"];[r setValue:stream?@"text/event-stream":@"application/json"forHTTPHeaderField:@"Accept"];[r setValue:@"identity"forHTTPHeaderField:@"Accept-Encoding"];
 if(body){[r setValue:@"application/json"forHTTPHeaderField:@"Content-Type"];[r setValue:@"https://chatgpt.com"forHTTPHeaderField:@"Origin"];[r setValue:@"https://chatgpt.com/robots.txt"forHTTPHeaderField:@"Referer"];}for(NSString*k in headers)[r setValue:headers[k]forHTTPHeaderField:k];
 NSURLRequest*authorized=[_adapter authorizeChatRequest:r expectedKey:_context[@"key"]];if(!authorized){[self finish:nil error:OR6APIError(@"not_authenticated",_dispatched?@"possible":@"none")];return;}
 NSString*step=stream?@"send":[path isEqual:@"/backend-api/me"]?@"owner":@"requirements";double dispatched=(Clock()-_began)*1000;
 OR6ChatNativeTask*task=[[[OR6ChatNativeTask alloc]init]autorelease];_networkTask=[task retain];NSUInteger generation=_generation;double operationBegan=_began;_workers++;_requests++;
 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{NSAutoreleasePool*pool=[NSAutoreleasePool new];NSMutableArray*consumerRows=[NSMutableArray array];__block BOOL consumerTruncated=NO;NSDictionary*raw=OR6ChatNativeHTTP(authorized,_roots,stream,^BOOL{return task.cancelled;},^BOOL(NSArray*events){
  double queued=Clock();__block double entered=0,left=0;__block BOOL accepted=NO;dispatch_sync(dispatch_get_main_queue(),^{entered=Clock();if(generation==_generation&&[self current]&&!task.cancelled){[self wireEvents:events];accepted=[self current]&&!task.cancelled;}left=Clock();});double returned=Clock();
  if(consumerRows.count<128)[consumerRows addObject:@[@((queued-operationBegan)*1000),@((entered-operationBegan)*1000),@((left-operationBegan)*1000),@((returned-operationBegan)*1000),@(events.count)]];else consumerTruncated=YES;return accepted;
 });
 NSMutableDictionary*result=[[raw mutableCopy]autorelease];if(stream){NSMutableDictionary*metrics=[NSMutableDictionary dictionaryWithDictionary:raw[@"metrics"]?:@{}];metrics[@"consumerTiming"]=@{@"originMonotonic":@(operationBegan),@"rows":consumerRows,@"truncated":@(consumerTruncated)};result[@"metrics"]=metrics;}
 dispatch_async(dispatch_get_main_queue(),^{_workers--;if(generation!=_generation||!_reply||_terminal)return;[_networkTask release];_networkTask=nil;
  if(![self current]){[self finish:nil error:OR6APIError(@"stale_context",_dispatched?@"possible":@"none")];return;}
  NSMutableDictionary*metrics=[NSMutableDictionary dictionaryWithDictionary:result[@"metrics"]?:@{}];metrics[@"dispatchedMs"]=@(dispatched);metrics[@"mainReturnedMs"]=@((Clock()-_began)*1000);if(!_timings[@"requests"])_timings[@"requests"]=[NSMutableDictionary dictionary];_timings[@"requests"][step]=metrics;
  if(![_adapter acceptChatCookies:result[@"setCookies"]expectedKey:_pageKey generation:_credentialGeneration]){[self finish:nil error:OR6APIError(@"storage_failure",_dispatched?@"possible":@"none")];return;}
  metrics[@"cookiesCommittedMs"]=@((Clock()-_began)*1000);
  if(!stream&&result[@"issue"]){[self finish:nil error:OR6APIError(result[@"issue"],@"none")];return;}completion(result);
 });[pool drain];});
}
- (void)advance{
 if(_reconcilingOnly||![self current])return;NSDictionary*pc=[self preparationContext];if(![_preparation isReadyForContext:pc]){[_preparation prepareForContext:pc];NSString*issue=[_preparation diagnostics][@"issue"];if(issue.length)[self finish:nil error:OR6APIError(issue,@"none")];return;}
 NSString*agent=[_preparation userAgentForContext:pc];if(![agent isEqual:_UA]){[_UA release];_UA=[agent copy];}
 if(!_ownerChecked){
  if(_networkTask)return;NSTimeInterval age=[_adapter recentChatOwnerValidationAgeForKey:_pageKey generation:_credentialGeneration];_timings[@"ownerValidationTTLms"]=@60000;_timings[@"ownerValidationReused"]=@(age>=0);
  if(age>=0){_timings[@"ownerValidationAgeMs"]=@(age*1000);_ownerChecked=YES;[self mark:@"ownerReadyMs"];}
  else{[self phase:@"authorizing"];[self request:@"/backend-api/me"body:nil headers:nil stream:NO completion:^(NSDictionary*r){if(![_adapter recordChatOwnerValidation:r[@"json"][@"id"]expectedKey:_pageKey generation:_credentialGeneration]){[self finish:nil error:OR6APIError(@"owner_mismatch",@"none")];return;}_ownerChecked=YES;[self mark:@"ownerReadyMs"];[self advance];}];return;}
 }
 if(!_model){[self loadModel];return;}if(_preparing)return;_preparing=YES;[self mark:@"sentinelBeginMs"];_timings[@"documentLoadMs"]=[_preparation diagnostics][@"pageLoadMs"]?:@0;[self mark:@"contextReadyMs"];
 if(![_preparation beginAttempt:_nonce context:pc]){[self finish:nil error:OR6APIError(@"capability_unavailable",@"none")];return;}[self phase:@"preparing_sentinel"];
}
- (void)tick:(NSTimer*)t{
 (void)t;if(![self current]){if(_reply)[self finish:nil error:OR6APIError(@"stale_context",_dispatched?@"possible":@"none")];return;}if(Clock()-_began>240){[self finish:nil error:OR6APIError(@"timeout",_dispatched?@"possible":@"none")];return;}
 if(_recoveringPartial){if(Clock()>=_recoveryDeadline){_timings[@"recoveryDeadlineExpired"]=@YES;[self finish:nil error:OR6APIError(_readbackIssue,@"possible")];return;}if(!_readInFlight&&_nextReadbackAt>=0&&Clock()>=_nextReadbackAt){_nextReadbackAt=-1;[self readback];}return;}
 if(!_preparing&&!_dispatched&&!_networkTask)[self advance];if(![self current]||!_preparing||_networkTask)return;
 NSDictionary*s=[_preparation pollAttempt:_nonce context:[self preparationContext]];
 if(![s isKindOfClass:NSDictionary.class]){[self finish:nil error:OR6APIError(@"invalid_response",@"none")];return;}
 for(NSString*k in @[@"resourceCount",@"chatBootstrapResources",@"computeMs",@"proofRequired",@"vmRequired",@"prepareKeyMs",@"requirementsWaitMs",@"readyWaitMs"])if([s[k]isKindOfClass:NSNumber.class])_timings[k]=s[k];
 if([s[@"phase"]isEqual:@"failed"]){[self finish:nil error:OR6APIError(s[@"issue"]?:@"invalid_response",@"none")];return;}
 if([s[@"phase"]isEqual:@"requirements"]){[self mark:@"prepareKeyObservedMs"];id p=s[@"p"];if(![p isKindOfClass:NSString.class]||![p length]||[p length]>32768){[self finish:nil error:OR6APIError(@"invalid_response",@"none")];return;}
  [self request:@"/backend-api/sentinel/chat-requirements/prepare"body:@{@"p":p}headers:nil stream:NO completion:^(NSDictionary*r){[self mark:@"requirementsReadyMs"];if(![_preparation supplyRequirements:r[@"json"]attempt:_nonce context:[self preparationContext]])[self finish:nil error:OR6APIError(@"service_challenge",@"none")];else[self mark:@"requirementsSuppliedMs"];}];
 }else if([s[@"phase"]isEqual:@"ready"]){NSDictionary*h=OR6CNHeaders(s[@"headers"]);_preparing=NO;if(!h){[self finish:nil error:OR6APIError(@"invalid_response",@"none")];return;}[self mark:@"integrityReadyMs"];[self send:h];}
}
- (void)emitMessage {
 if(!_event||!_aid||!_cid)return;
 NSMutableDictionary *p=[NSMutableDictionary dictionaryWithDictionary:@{@"operationId":_parameters[@"operationId"],@"conversationId":_cid,@"messageId":_aid,@"text":_assistantText?:@"",@"finished":@(_finishedAssistantText)}];
 if(_messageParts)p[@"parts"]=_messageParts;if(_conversationTitle)p[@"conversationTitle"]=_conversationTitle;
 p[@"sequence"]=@(++_sequence);
 OR6APIEvent cb=[[_event copy]autorelease];cb(@{@"name":@"message",@"payload":p});
}
- (void)wireEvents:(NSArray*)events{
 for(NSDictionary*e in events){if(![self current])return;NSString*t=e[@"type"];
  if([t isEqual:@"identity"]){if(!OR6CNUUID(e[@"conversationId"])||(_cid&&!OR6CNSameUUID(_cid,e[@"conversationId"]))){[self finish:nil error:OR6APIError(@"invalid_response",@"possible")];return;}if(!_cid)_cid=[e[@"conversationId"]copy];if(![self persistUncertain]||![self saveRecoveryCompleted:NO]){[self finish:nil error:OR6APIError(@"storage_failure",@"possible")];return;}[self emit:@"streaming"];}
  else if([t isEqual:@"title"]){if(!OR6CNUUID(e[@"conversationId"])||(_cid&&!OR6CNSameUUID(_cid,e[@"conversationId"]))){[self finish:nil error:OR6APIError(@"invalid_response",@"possible")];return;}if(!_cid)_cid=[e[@"conversationId"]copy];[_conversationTitle release];_conversationTitle=[e[@"title"]copy];[self emitMessage];}
  else if([t isEqual:@"messageSnapshot"]&&[e[@"message"][@"role"]isEqual:@"assistant"]){NSDictionary*m=e[@"message"];if(_plan){[_planMessage release];_planMessage=[m copy];}if(!OR6CNUUID(m[@"id"])||!OR6CNUUID(_cid)||(_aid&&!OR6CNSameUUID(_aid,m[@"id"])&&!(_plan&&![_plan[@"temporary"]boolValue]))){[self finish:nil error:OR6APIError(@"invalid_response",@"possible")];return;}_finishedAssistantText=[m[@"finished"]isEqual:@YES]&&[m[@"text"]length]>0;[_assistantText release];_assistantText=[m[@"text"]copy];if(!_aid||!OR6CNSameUUID(_aid,m[@"id"])){[_aid release];_aid=[m[@"id"]copy];}if([m[@"text"]length])[self mark:@"firstAssistantTextMs"];if(![self persistUncertain]||![self saveRecoveryCompleted:NO]){[self finish:nil error:OR6APIError(@"storage_failure",@"possible")];return;}
   if(m[@"parts"]){[_messageParts release];_messageParts=[m[@"parts"]copy];}[self emitMessage];
  }
  else if([t isEqual:@"status"]&&[e[@"status"]isEqual:@"in_progress"]&&_event){OR6APIEvent cb=[[_event copy]autorelease];cb(@{@"name":@"status",@"payload":@{@"operationId":_parameters[@"operationId"],@"phase":e[@"phase"]?:(_assistantText.length?@"writing":@"thinking"),@"label":e[@"label"]?:@"",@"sequence":@(++_sequence)}});}
  if([self current]&&![self persistUncertain]){[self finish:nil error:OR6APIError(@"storage_failure",@"possible")];return;}
 }
}
- (void)send:(NSDictionary*)headers{
 if(_dispatched||![self current])return;NSDictionary*body=_plan?_plan[@"body"]:OR6CNBody(_parameters[@"text"],_uid,_parameters[@"parentMessageId"],_cid,_model);if(!body){[self finish:nil error:OR6APIError(@"invalid_request",@"none")];return;}
 if(!_plan){_snapshot=[@{@"schema":@1,@"scope":_context[@"key"],@"operationId":_parameters[@"operationId"],@"request":_parameters,@"conversationId":_cid?:(id)NSNull.null,@"userMessageId":_uid,@"assistantMessageId":NSNull.null,@"text":@"",@"finished":@NO,@"completed":@NO,@"autoResume":@YES,@"updatedAt":@([[NSDate date]timeIntervalSince1970])}copy];}
 if(![self persistUncertain]||![self saveRecoveryCompleted:NO]){[self finish:nil error:OR6APIError(@"storage_failure",@"none")];return;}_dispatched=YES;_sends++;[self mark:@"nativeDispatchMs"];[self phase:@"streaming"];[self emit:@"dispatching"];if(![self current])return;
 [self request:@"/backend-api/f/conversation"body:body headers:headers stream:YES completion:^(NSDictionary*r){
  NSDictionary*m=r[@"metrics"];double origin=([m[@"startedMonotonic"]doubleValue]-_began)*1000;_timings[@"nativeTransportStartMs"]=@(origin);if(m[@"headersMs"])_timings[@"sseHeadersMs"]=@(origin+[m[@"headersMs"]doubleValue]);_timings[@"transport"]=m;_timings[@"streamComplete"]=r[@"streamComplete"]?:@NO;
  if(r[@"issue"]){
   // Recover only by reading history, never by another generation. Finished
   // text keeps its one-read policy; partial text has a bounded serial budget.
   if(!_plan&&_assistantText.length&&OR6CNUUID(_cid)&&OR6CNUUID(_aid)&&[@[@"timeout",@"network_unavailable",@"uncertain_outcome",@"upstream_error",@"unknown_wire_shape"]containsObject:r[@"issue"]]){
    [_readbackIssue release];_readbackIssue=[r[@"issue"]copy];_recoveringPartial=!_finishedAssistantText;_recoveryAttempts=0;_recoveryDeadline=Clock()+90;_nextReadbackAt=-1;_timings[@"recoveryIssue"]=_readbackIssue;_timings[@"recoveryPartial"]=@(_recoveringPartial);_timings[@"recoveryInitialCharacters"]=@(_assistantText.length);_timings[@"recoveryMaxReads"]=@(_recoveringPartial?6:1);_timings[@"recoveryWindowMs"]=@(_recoveringPartial?90000:0);_timings[@"recoveryReadbackConfirmed"]=@NO;NSUInteger generation=_generation;[self phase:@"reconciling"];[self emit:@"reconciling"];if(generation==_generation&&[self current])[self readback];return;
   }[self finish:nil error:OR6APIError(r[@"issue"],@"possible")];return;
  }
  if(![r[@"streamComplete"]boolValue]||!OR6CNUUID(_cid)||!OR6CNUUID(_aid)){[self finish:nil error:OR6APIError(@"uncertain_outcome",@"possible")];return;}[self mark:@"streamCompleteMs"];if([_plan[@"temporary"]boolValue]){NSDictionary*receipt=[self receipt:@"completed"persisted:NO];if(![_journal finish:_parameters[@"operationId"]scope:_context[@"key"]state:@"completed"metadata:receipt error:NULL]){[self finish:nil error:OR6APIError(@"storage_failure",@"possible")];return;}[self finish:receipt error:nil];return;}[self phase:@"reconciling"];[self emit:@"reconciling"];if([self current])[self readback];
 }];
}
- (NSTimeInterval)recoveryRetryDelay:(NSUInteger)attempt{return OR6CNRecoveryDelay(attempt);}
- (BOOL)waitForRecovery{
 if(!_recoveringPartial||_readInFlight)return NO;NSTimeInterval delay=[self recoveryRetryDelay:_recoveryAttempts];
 if(_recoveryAttempts>=6||delay<0||Clock()+delay>=_recoveryDeadline){_timings[@"recoveryBudgetExhausted"]=@YES;return NO;}
 _nextReadbackAt=Clock()+delay;_timings[@"recoveryNextDelayMs"]=@(delay*1000);NSUInteger generation=_generation;[self phase:@"reconciling"];[self emit:@"reconciling"];if(generation==_generation&&_reply&&!_terminal&&![self current])[self finish:nil error:OR6APIError(@"stale_context",@"possible")];return YES;
}
- (void)readback{
 if(_readInFlight)return;if(!OR6CNUUID(_cid)){[self finish:[self receipt:@"uncertain"persisted:NO]error:nil];return;}
 if(_recoveringPartial&&(_recoveryAttempts>=6||Clock()>=_recoveryDeadline)){_timings[@"recoveryBudgetExhausted"]=@YES;[self finish:nil error:OR6APIError(_readbackIssue,@"possible")];return;}
 _readbacks++;_readInFlight=YES;if(_readbackIssue)_timings[@"recoveryReadbackAttempts"]=@(++_recoveryAttempts);NSUInteger generation=_generation;__block BOOL finished=NO;
 id<OR6APITask>task=[_adapter execute:@"history.get"parameters:@{@"conversationId":_cid}context:_context event:nil completion:^(NSDictionary*c,NSError*e){
  finished=YES;if(generation!=_generation||!_reply||_terminal)return;_readInFlight=NO;[_readTask release];_readTask=nil;if(![self current]){[self finish:nil error:OR6APIError(@"stale_context",@"possible")];return;}
  if(e){NSString*code=OR6APIError(e.userInfo[@"code"],@"possible").userInfo[@"code"];if(_readbackIssue){_timings[@"recoveryReadbackIssue"]=code;if(_recoveringPartial&&[@[@"network_unavailable",@"timeout",@"upstream_error",@"not_found"]containsObject:code]&&[self waitForRecovery])return;if(![@[@"rate_limited",@"not_authenticated",@"access_denied",@"service_challenge",@"stale_context",@"owner_mismatch",@"cancelled"]containsObject:code])code=_readbackIssue;}[self finish:nil error:OR6APIError(code,@"possible")];return;}
  if(_recoveringPartial){NSError*storage=nil;NSDictionary*record=[_journal record:_parameters[@"operationId"]scope:_context[@"key"]error:&storage];if(!record||storage){[self finish:nil error:OR6APIError(@"storage_failure",@"possible")];return;}NSDictionary*m=record?OR6CNRecoveryMessage(c,_cid,_uid,_aid,(record[@"request"][@"textSHA256"]?:OR6CNHash(_snapshot[@"request"][@"text"]))):nil;NSString*next=m[@"text"];
   // A finished, identity-bound history snapshot is canonical. The server may
   // escape Markdown differently from SSE; only unfinished progress needs a prefix.
   BOOL extends=m&&next.length&&([m[@"finished"]isEqual:@YES]||[next hasPrefix:_assistantText?:@""]);
   if(extends&&([m[@"finished"]isEqual:@YES]||next.length>_assistantText.length)){_timings[@"recoveryRecoveredCharacters"]=@(next.length);[self wireEvents:@[@{@"type":@"messageSnapshot",@"message":m}]];if(generation!=_generation||!_reply||_terminal)return;if(![self current]){[self finish:nil error:OR6APIError(@"stale_context",@"possible")];return;}}
   if(!extends||![m[@"finished"]isEqual:@YES]){if([self waitForRecovery])return;[self finish:nil error:OR6APIError(_readbackIssue,@"possible")];return;}
  }
  NSError*storage=nil;NSDictionary*record=[_journal record:_parameters[@"operationId"]scope:_context[@"key"]error:&storage];NSDictionary*request=record[@"request"];NSString*hash=request[@"textSHA256"]?:OR6CNHash(_snapshot[@"request"][@"text"]);BOOL canonical=(_plan&&![_plan[@"temporary"]boolValue])||(_reconcilingOnly&&([request[@"planReadback"]isEqual:@YES]||(!request[@"planReadback"]&&[request[@"expectedFiles"]count]>0)));NSString*aid=record?(canonical?OR6CNPlanReadback(c,_cid,_uid,hash):OR6CNReadback(c,_cid,_uid,_aid,hash)):nil;if(aid&&!PlanFilesMatch(record[@"request"][@"expectedFiles"],c,_uid))aid=nil;if(!aid){if(_readbackIssue)[self finish:nil error:OR6APIError(_readbackIssue,@"possible")];else[self finish:[self receipt:@"uncertain"persisted:NO]error:nil];return;}
  if([c[@"title"]isKindOfClass:NSString.class]&&[c[@"title"]length]<=2000)[self wireEvents:@[@{@"type":@"title",@"conversationId":c[@"id"],@"title":c[@"title"]}]];if(![self current])return;
  NSDictionary*final=nil;for(NSDictionary*m in c[@"messages"])if(OR6CNSameUUID(m[@"id"],aid)&&[m[@"role"]isEqual:@"assistant"])final=m;
  if(canonical||(final[@"parts"]&&![final[@"parts"]isEqual:_messageParts])){if(!final){[self finish:[self receipt:@"uncertain"persisted:NO]error:nil];return;}[_aid release];_aid=[aid copy];[self wireEvents:@[@{@"type":@"messageSnapshot",@"message":final}]];if(generation!=_generation||!_reply||_terminal||![self current])return;}
  if(_readbackIssue&&!_recoveringPartial){NSDictionary*confirmed=nil;for(NSDictionary*m in c[@"messages"])if(OR6CNSameUUID(m[@"id"],aid)&&[m[@"role"]isEqual:@"assistant"]&&[m[@"finished"]isEqual:@YES]&&[m[@"text"]isKindOfClass:NSString.class]&&[m[@"text"]length]>0&&[m[@"text"]length]<=262144){confirmed=m;break;}if(!confirmed){[self finish:nil error:OR6APIError(_readbackIssue,@"possible")];return;}[self wireEvents:@[@{@"type":@"messageSnapshot",@"message":confirmed}]];if(generation!=_generation||!_reply||_terminal)return;if(![self current]){[self finish:nil error:OR6APIError(@"stale_context",@"possible")];return;}}
  if(!_aid)_aid=[aid copy];NSDictionary*r=[self receipt:@"completed"persisted:YES];if(!_journalCompleted&&![_journal finish:_parameters[@"operationId"]scope:_context[@"key"]state:@"completed"metadata:r error:&storage]){[self finish:nil error:OR6APIError(@"storage_failure",@"possible")];return;}if(_readbackIssue)_timings[@"recoveryReadbackConfirmed"]=@YES;[self finish:r error:nil];
 }];if(!finished&&generation==_generation&&_reply&&!_terminal)_readTask=[task retain];
}
- (id<OR6APITask>)executeNativePlan:(NSDictionary*)plan context:(NSDictionary*)ctx event:(OR6APIEvent)event completion:(OR6APIReply)reply{
 NSDictionary*safe=OR6APIJSONSnapshot(plan,512*1024);NSDictionary*p=safe[@"parameters"],*body=safe[@"body"];
 if(!NSThread.isMainThread||_nextPlan||_reply||![safe[@"schema"]isEqual:@1]||![p isKindOfClass:NSDictionary.class]||![body isKindOfClass:NSDictionary.class]||!OR6CNUUID(safe[@"userMessageId"])||!OR6CNUUID(body[@"parent_message_id"])||![@[@"next",@"variant",@"continue"]containsObject:body[@"action"]]||![body[@"messages"]isKindOfClass:NSArray.class]||([body[@"action"]isEqual:@"continue"]&&(!OR6CNUUID(body[@"conversation_id"])||[body[@"messages"]count]!=0))||[body[@"messages"]count]>2||![body[@"model"]isKindOfClass:NSString.class]||![p[@"text"]isKindOfClass:NSString.class]||[p[@"text"]length]>200000){reply(nil,OR6APIError(@"invalid_request",@"none"));return nil;}
 _nextPlan=[safe retain];id<OR6APITask>task=[self execute:@"messages.send"parameters:p context:ctx event:event completion:reply];[_nextPlan release];_nextPlan=nil;return task;
}
- (id<OR6APITask>)execute:(NSString*)op parameters:(NSDictionary*)p context:(NSDictionary*)ctx event:(OR6APIEvent)event completion:(OR6APIReply)reply{
 if(![op isEqual:@"messages.send"]&&![op isEqual:@"messages.reconcile"])return[_adapter execute:op parameters:p context:ctx event:event completion:reply];
 OR6ChatNativeTask*task=[[[OR6ChatNativeTask alloc]init]autorelease];if(!NSThread.isMainThread||_reply||(_workers&&[op isEqual:@"messages.send"])){reply(nil,OR6APIError(@"conflict",@"none"));return task;}
 NSString*key=_adapter.contextKey;if(!key.length||![key isEqual:ctx[@"key"]]){reply(nil,OR6APIError(@"not_authenticated",@"none"));return task;}
 BOOL send=[op isEqual:@"messages.send"];if(send&&!_nextPlan&&((p[@"thinkingEffort"]&&p[@"thinkingEffort"]!=NSNull.null)||![p[@"modelId"]isEqual:@"web-current"]||[p[@"temporary"]boolValue]||[p[@"attachments"]count]||!OR6CNUUID(p[@"parentMessageId"])||(p[@"conversationId"]&&!OR6CNUUID(p[@"conversationId"]))||![p[@"text"]length]||[p[@"text"]length]>16000)){reply(nil,OR6APIError(@"capability_unavailable",@"none"));return task;}
 if(![self contextCurrent]){[self deactivate];_pageKey=[key copy];_credentialGeneration=_adapter.credentialGeneration;[_blocked release];_blocked=nil;}
 if(send&&_blocked){reply(nil,OR6APIError(_blocked,@"none"));return task;}
 NSError*error=nil;NSDictionary*record=nil;
 if(send){NSMutableDictionary*request=[NSMutableDictionary dictionaryWithDictionary:@{@"textSHA256":OR6CNHash(p[@"text"]),@"expectedFiles":PlanFileIDs(_nextPlan)}];if(_nextPlan)request[@"planReadback"]=@(![_nextPlan[@"temporary"]boolValue]);if(![_journal reserve:p[@"operationId"]command:@"native.send.v1"request:request scope:key error:&error]){reply(nil,error);return task;}}
 else{record=[_journal record:p[@"operationId"]scope:key error:&error];if(error||!record){reply(nil,error?:OR6APIError(@"not_found",@"none"));return task;}NSDictionary*saved=[_recovery snapshotForOperation:p[@"operationId"]scope:key];if([record[@"state"]isEqual:@"completed"]&&(!saved||[saved[@"completed"]boolValue])){if(event&&[saved[@"text"]length]&&OR6CNSameUUID(saved[@"conversationId"],record[@"result"][@"conversationId"])&&OR6CNSameUUID(saved[@"assistantMessageId"],record[@"result"][@"assistantMessageId"]))event(@{@"name":@"message",@"payload":@{@"operationId":p[@"operationId"],@"sequence":@1,@"conversationId":saved[@"conversationId"],@"messageId":saved[@"assistantMessageId"],@"text":saved[@"text"],@"finished":@YES}});reply(record[@"result"],nil);return task;}if([record[@"state"]isEqual:@"rejected"]){reply(@{@"operationId":p[@"operationId"],@"state":@"rejected",@"conversationId":NSNull.null,@"userMessageId":NSNull.null,@"assistantMessageId":NSNull.null,@"persisted":@NO},nil);return task;}}
 _reconcilingOnly=!send;_journalCompleted=[record[@"state"]isEqual:@"completed"];_generation++;task->generation=_generation;task->owner=self;_task=[task retain];_reply=[reply copy];_event=[event copy];_parameters=[p copy];_plan=[_nextPlan copy];_context=[ctx copy];_terminal=NO;_finishedAssistantText=NO;_recoveringPartial=_readInFlight=NO;_recoveryAttempts=0;_nextReadbackAt=-1;[_assistantText release];_assistantText=nil;[_conversationTitle release];_conversationTitle=nil;[_messageParts release];_messageParts=nil;[_readbackIssue release];_readbackIssue=nil;_ownerChecked=_preparing=NO;_dispatched=!send;_sequence=0;[_issue release];_issue=nil;[_timings release];_timings=[NSMutableDictionary new];_began=Clock();[self phase:send?@"preparing":@"reconciling"];
 if(!send){[self releasePage];[_modelTask cancel];[_modelTask release];_modelTask=nil;_modelLoading=NO;_snapshot=[[_recovery snapshotForOperation:p[@"operationId"]scope:key]retain];if(_snapshot&&record[@"request"][@"textSHA256"]&&![record[@"request"][@"textSHA256"]isEqual:OR6CNHash(_snapshot[@"request"][@"text"])]){[self finish:nil error:OR6APIError(@"storage_failure",@"possible")];return task;}NSDictionary*m=record[@"result"]?:record[@"metadata"];if(OR6CNUUID(m[@"conversationId"]))_cid=[m[@"conversationId"]copy];if(OR6CNUUID(m[@"userMessageId"]))_uid=[m[@"userMessageId"]copy];if(OR6CNUUID(m[@"assistantMessageId"]))_aid=[m[@"assistantMessageId"]copy];
  if(_snapshot){_assistantText=[_snapshot[@"text"]copy];_finishedAssistantText=[_snapshot[@"finished"]boolValue];_readbackIssue=[@"uncertain_outcome"copy];_recoveringPartial=OR6CNUUID(_aid);_recoveryDeadline=Clock()+90;_timings[@"restoredRecovery"]=@YES;_timings[@"recoveryInitialCharacters"]=@(_assistantText.length);_timings[@"recoveryMaxReads"]=@(_recoveringPartial?6:1);_timer=[[NSTimer scheduledTimerWithTimeInterval:.15 target:self selector:@selector(tick:)userInfo:nil repeats:YES]retain];[self emit:@"reconciling"];}
  if([self current])[self readback];return task;}
 _uid=[(_plan[@"userMessageId"]?:OR6ChatUUID().lowercaseString)copy];_nonce=[OR6ChatUUID().lowercaseString copy];if(p[@"conversationId"])_cid=[p[@"conversationId"]lowercaseString].copy;BOOL prepared=[_preparation isReadyForContext:[self preparationContext]];_timings[@"preparedBeforeSend"]=@(prepared);_timings[@"documentLoadedAtSend"]=@(prepared);if(prepared)_reuses++;
 if(![_preparation reserveAttempt:_nonce context:[self preparationContext]]){[self finish:nil error:OR6APIError(@"capability_unavailable",@"none")];return task;}
 _timer=[[NSTimer scheduledTimerWithTimeInterval:.15 target:self selector:@selector(tick:)userInfo:nil repeats:YES]retain];[self advance];return task;
}
- (NSDictionary*)diagnostics{NSDictionary*d=[_preparation diagnostics];return @{@"preparation":d,@"bootstrap":d[@"bootstrap"]?:@{},@"transport":@"minimal-sentinel-native-sse",@"active":@(_reply!=nil),@"webViewPresent":d[@"webViewPresent"]?:@NO,@"pageLoaded":d[@"pageLoaded"]?:@NO,@"pageLoads":d[@"pageLoads"]?:@0,@"pageReuses":@(_reuses),@"prepares":@(_prepares),@"modelPreloaded":@(_model!=nil),@"pageLoadMs":d[@"pageLoadMs"]?:@0,@"nativeRequests":@(_requests),@"sendsAttempted":@(_sends),@"readbacks":@(_readbacks),@"workers":@(_workers),@"phase":_phase?:@"idle",@"issue":_issue?:@"",@"timings":_timings?:@{},@"requiresMacBridge":@NO,@"credentialsExposed":@NO};}
- (void)dealloc{[NSNotificationCenter.defaultCenter removeObserver:self];[self deactivate];[_readContextSource release];[_adapter release];[_roots release];[_journal release];[_recovery release];[_blocked release];[_phase release];[_issue release];[_timings release];[_preparation release];[super dealloc];}
@end
