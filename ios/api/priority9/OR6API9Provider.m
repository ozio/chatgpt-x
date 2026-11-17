#import "OR6API9Provider.h"
#import "OR6API9Policy.h"
#import "../OR6APIOperations.h"
#import <dispatch/dispatch.h>
#import <CoreFoundation/CoreFoundation.h>
@class OR6API9Call;
@interface OR6API9Provider(){
 id<OR6APIProvider>_next;id<OR6API9HTTP>_HTTP;id<OR6API9Recorder>_recorder;OR6APIOperations*_coreJournal,*_controls;
 NSSet*_capabilities;NSMutableSet*_calls;NSMutableDictionary*_generations,*_drafts;NSString*_scope,*_recordingKey,*_recordingID;NSUInteger _epoch,_retries,_stopRequests,_transcriptions;
}
- (void)cancel:(OR6API9Call*)call;
@end
@interface OR6API9Call:NSObject<OR6APITask>{@public OR6API9Provider*owner;NSString*command,*control,*capture,*retryDraft;NSDictionary*parameters,*context;OR6APIReply reply;OR6APIEvent event;id<OR6APITask>child;BOOL terminal,dispatched,ownsCore;}
@end
@implementation OR6API9Call
- (void)cancel{if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self cancel];});return;}[owner cancel:self];}
- (void)dealloc{[command release];[control release];[capture release];[retryDraft release];[parameters release];[context release];[reply release];[event release];[child release];[super dealloc];}
@end
static BOOL Text(id v){return[v isKindOfClass:NSString.class]&&[v length]&&[v length]<=256&&[v rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location==NSNotFound;}
static NSString*Boundary(void){CFUUIDRef u=CFUUIDCreate(NULL);NSString*s=[(NSString*)CFUUIDCreateString(NULL,u)autorelease];CFRelease(u);return[@"LegacyClient-"stringByAppendingString:s];}
static NSString*DraftKey(NSDictionary*c,NSString*op){return[NSString stringWithFormat:@"%@:%@",c[@"key"],op];}
@interface NSObject(OR6UserStop)
- (void)cancelForUserStop;
- (void)prepareForUserStop;
@end
@implementation OR6API9Provider
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API9HTTP>)HTTP recorder:(id<OR6API9Recorder>)recorder coreJournalDirectory:(NSString*)directory controlJournalDirectory:(NSString*)controls capabilities:(NSSet*)capabilities error:(NSError**)error{
 if((self=[super init])){NSSet*allowed=[NSSet setWithArray:@[@"stop",@"transcribe"]];if(!next||![capabilities isKindOfClass:NSSet.class]||![capabilities isSubsetOfSet:allowed]||(capabilities.count&&!HTTP)){if(error)*error=OR6APIError(@"invalid_request",@"none");[self release];return nil;}
  _next=[next retain];_HTTP=[HTTP retain];_recorder=[recorder retain];_capabilities=[capabilities copy];_coreJournal=[[OR6APIOperations alloc]initWithDirectory:directory error:error];_controls=[[OR6APIOperations alloc]initWithDirectory:controls error:error];_calls=[NSMutableSet new];_generations=[NSMutableDictionary new];_drafts=[NSMutableDictionary new];if(!_coreJournal||!_controls){[self release];return nil;}
 }return self;
}
- (BOOL)current:(OR6API9Call*)c{return!c->terminal&&[c->context[@"key"]isEqual:_scope]&&[c->context[@"generation"]unsignedIntegerValue]==_epoch;}
- (void)complete:(OR6API9Call*)c result:(NSDictionary*)result error:(NSError*)error{
 if(c->terminal)return;[c retain];c->terminal=YES;
 if(![c->context[@"key"]isEqual:_scope]||[c->context[@"generation"]unsignedIntegerValue]!=_epoch){result=nil;error=OR6APIError(@"stale_context",c->dispatched?@"possible":@"none");}
 if(c->control){NSString*state=error?([error.userInfo[@"dispatch"]isEqual:@"none"]?@"rejected":@"uncertain"):([c->command isEqual:@"messages.retry"]&&![result[@"state"]isEqual:@"completed"]?@"uncertain":@"completed");NSError*storage=nil;if(![_controls finish:c->control scope:c->context[@"key"]state:state metadata:result?:@{}error:&storage]){result=nil;error=OR6APIError(@"storage_failure",c->dispatched?@"possible":@"none");}}
 if(c->capture){NSString*state=error?([error.userInfo[@"dispatch"]isEqual:@"none"]?@"rejected":@"uncertain"):@"completed";if(![_controls finish:c->capture scope:c->context[@"key"]state:state metadata:result?:@{}error:NULL]){result=nil;error=OR6APIError(@"storage_failure",c->dispatched?@"possible":@"none");}}
 if(c->ownsCore){NSString*state=error?([error.userInfo[@"dispatch"]isEqual:@"none"]?@"rejected":@"uncertain"):@"completed";if(![_coreJournal finish:c->parameters[@"operationId"]scope:c->context[@"key"]state:state metadata:result?:@{}error:NULL]){result=nil;error=OR6APIError(@"storage_failure",c->dispatched?@"possible":@"none");}}
 if([@[@"messages.send",@"messages.retry",@"messages.edit",@"messages.regenerate",@"messages.reconcile"]containsObject:c->command])[_generations removeObjectForKey:c->parameters[@"operationId"]];
 if(error)[c->child cancel];[c->child release];c->child=nil;c->owner=nil;[_calls removeObject:c];OR6APIReply completion=[[c->reply copy]autorelease];[c->reply release];c->reply=nil;[c->event release];c->event=nil;
 NSString*k=DraftKey(c->context,c->parameters[@"operationId"]?:@"");if(c->retryDraft&&!error&&[result[@"state"]isEqual:@"completed"])_drafts[k]=c->retryDraft;
 if(completion)completion(result,error);[_drafts removeObjectForKey:k];[c release];
}
- (void)cancel:(OR6API9Call*)c{if(!c->terminal)[self complete:c result:nil error:OR6APIError(@"cancelled",c->dispatched?@"possible":@"none")];}
- (void)adopt:(id<OR6APITask>)task call:(OR6API9Call*)c{if(c->terminal)[task cancel];else if(task)c->child=[task retain];else[self complete:c result:nil error:OR6APIError(@"unavailable",@"none")];}
- (void)deactivate{for(OR6API9Call*c in [[_calls.allObjects copy]autorelease])[self cancel:c];[_recorder suspend];[_generations removeAllObjects];}
- (void)context:(NSDictionary*)ctx{
 BOOL same=[_scope isEqual:ctx[@"key"]];if(same&&_epoch==[ctx[@"generation"]unsignedIntegerValue])return;[self deactivate];if(!same&&_scope){if(_recordingID)[_recorder cancel];[_recordingKey release];_recordingKey=nil;[_recordingID release];_recordingID=nil;}
 [_scope release];_scope=[ctx[@"key"]copy];_epoch=[ctx[@"generation"]unsignedIntegerValue];
 // A recovered file can be adopted only with a durable marker for THIS owner.
 // Unrelated/legacy recordings stay private to the recorder until its host
 // explicitly resolves them; no capture or upload starts during restoration.
 if(!_recordingID){NSDictionary*s=[_recorder snapshot];NSString*rid=s[@"recordingId"];if(OR6API9UUID(rid)){NSDictionary*marker=[_controls record:[@"recording:"stringByAppendingString:rid.lowercaseString]scope:_scope error:NULL];NSString*bound=marker[@"result"][@"recordingId"]?:marker[@"request"][@"recordingId"];
  if([marker[@"command"]isEqual:@"dictation.start"]&&[bound isKindOfClass:NSString.class]&&[bound caseInsensitiveCompare:rid]==NSOrderedSame&&[@[@"dispatching",@"completed"]containsObject:marker[@"state"]]&&[@[@"recording",@"stopped"]containsObject:s[@"state"]]){_recordingID=[bound copy];_recordingKey=[_scope copy];}
 }}
}
- (void)didValidate:(NSString*)op result:(NSDictionary*)r context:(NSDictionary*)ctx{
 NSString*k=DraftKey(ctx,r[@"operationId"]?:@"");NSString*d=_drafts[k];
 if([op isEqual:@"messages.reconcile"]&&[r[@"state"]isEqual:@"completed"]){NSString*cursor=r[@"operationId"];NSMutableSet*seen=[NSMutableSet set];for(NSUInteger n=0;n<32&&cursor;n++){if([seen containsObject:cursor])break;[seen addObject:cursor];NSDictionary*old=[_coreJournal record:cursor scope:ctx[@"key"]error:NULL];if([old[@"command"]isEqual:@"messages.send"]){d=old[@"request"][@"draftId"];break;}if(![old[@"command"]isEqual:@"messages.retry"])break;cursor=old[@"request"][@"previousOperationId"];}if(d&&[_next respondsToSelector:@selector(releaseCompletedDraft:context:)])[_next releaseCompletedDraft:d context:ctx];}
if([op isEqual:@"messages.retry"]&&d&&[r[@"state"]isEqual:@"completed"]&&[_next respondsToSelector:@selector(releaseCompletedDraft:context:)])[_next releaseCompletedDraft:d context:ctx];
 if([_next respondsToSelector:@selector(didValidate:result:context:)])[_next didValidate:op result:r context:ctx];
}
- (void)releaseCompletedDraft:(NSString*)draft context:(NSDictionary*)ctx{if([_next respondsToSelector:@selector(releaseCompletedDraft:context:)])[_next releaseCompletedDraft:draft context:ctx];}
- (BOOL)bindConduitToken:(NSString*)token operation:(NSString*)op context:(NSDictionary*)ctx{
 if(!NSThread.isMainThread||![token isKindOfClass:NSString.class]||![token length]||[token length]>32768||[token rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound)return NO;NSMutableDictionary*g=_generations[op];OR6API9Call*c=g[@"call"];if(!c||![self current:c]||![ctx isEqual:c->context])return NO;g[@"conduit"]=token;return YES;
}
- (void)receive:(NSDictionary*)e call:(OR6API9Call*)c{
 if(![self current:c])return;NSDictionary*p=e[@"payload"];if([p[@"operationId"]isEqual:c->parameters[@"operationId"]]){
  NSMutableDictionary*g=_generations[c->parameters[@"operationId"]];id cid=p[@"conversationId"],aid=p[@"messageId"]?:p[@"assistantMessageId"];if(OR6API9UUID(cid)){if(g[@"conversationId"]&&[g[@"conversationId"]caseInsensitiveCompare:cid]!=NSOrderedSame){[self complete:c result:nil error:OR6APIError(@"invalid_response",@"possible")];return;}g[@"conversationId"]=[cid lowercaseString];}if(OR6API9UUID(aid))g[@"assistantId"]=[aid lowercaseString];
  if([e[@"name"]isEqual:@"state"]&&[@[@"dispatching",@"streaming",@"reconciling"]containsObject:p[@"state"]])c->dispatched=YES;if([e[@"name"]isEqual:@"message"]){c->dispatched=YES;g[@"serverObserved"]=@YES;}if([e[@"name"]isEqual:@"state"]&&[@[@"streaming",@"reconciling"]containsObject:p[@"state"]]&&OR6API9UUID(cid))g[@"serverObserved"]=@YES;
 }if(c->event){OR6APIEvent callback=[[c->event copy]autorelease];callback(e);}
}
- (void)delegate:(NSString*)op parameters:(NSDictionary*)p call:(OR6API9Call*)c{
 if([@[@"messages.send",@"messages.edit",@"messages.regenerate",@"messages.reconcile"]containsObject:op]){c->dispatched=YES;if(_generations[p[@"operationId"]]){[self complete:c result:nil error:OR6APIError(@"duplicate_operation",@"none")];return;}_generations[p[@"operationId"]]=[NSMutableDictionary dictionaryWithObject:c forKey:@"call"];}
 id<OR6APITask>task=[_next execute:op parameters:p context:c->context event:^(NSDictionary*e){[self receive:e call:c];}completion:^(NSDictionary*r,NSError*e){[self complete:c result:r error:e];}];[self adopt:task call:c];
}
- (NSDictionary*)retryRequest:(NSString*)prior newID:(NSString*)identifier scope:(NSString*)scope root:(NSString**)root error:(NSError**)error{
 NSMutableSet*seen=[NSMutableSet setWithObject:identifier];NSString*cursor=prior;
 for(NSUInteger depth=0;depth<32;depth++){
  if(!Text(cursor)||[seen containsObject:cursor])break;[seen addObject:cursor];NSDictionary*r=[_coreJournal record:cursor scope:scope error:error];if(!r||![r[@"state"]isEqual:@"rejected"]||![r[@"request"]isKindOfClass:NSDictionary.class]||![r[@"request"][@"operationId"]isEqual:cursor])break;
  NSDictionary*p=r[@"request"];if([r[@"command"]isEqual:@"messages.retry"]){cursor=p[@"previousOperationId"];continue;}if(![r[@"command"]isEqual:@"messages.send"]||![p[@"text"]isKindOfClass:NSString.class]||![p[@"text"]length]||[p[@"text"]length]>16000||!Text(p[@"draftId"])||!OR6API9UUID(p[@"parentMessageId"]))break;
  NSMutableDictionary*out=[[p mutableCopy]autorelease];out[@"operationId"]=identifier;if(root)*root=cursor;return OR6APIJSONSnapshot(out,512*1024);
 }if(error&&!*error)*error=OR6APIError(@"invalid_operation_state",@"none");return nil;
}
- (BOOL)reserveRetry:(OR6API9Call*)c root:(NSString*)root error:(NSError**)error{
 for(NSUInteger n=0;n<32;n++){NSString*k=[NSString stringWithFormat:@"retry:%@:%lu",root,(unsigned long)n];NSDictionary*r=[_controls record:k scope:_scope error:error];if(error&&*error)return NO;
  if(r){if(![r[@"command"]isEqual:@"messages.retry"]){if(error)*error=OR6APIError(@"storage_failure",@"none");return NO;}if([r[@"state"]isEqual:@"rejected"])continue;if(error)*error=OR6APIError(@"invalid_operation_state",@"none");return NO;}
  if(![_controls reserve:k command:@"messages.retry"request:@{@"operationId":c->parameters[@"operationId"],@"rootOperationId":root}scope:_scope error:error])return NO;c->control=[k copy];return[_controls finish:k scope:_scope state:@"uncertain"metadata:@{}error:error];
 }if(error)*error=OR6APIError(@"unavailable",@"none");return NO;
}
- (void)stop:(OR6API9Call*)c{
 if(![_capabilities containsObject:@"stop"]){[self complete:c result:nil error:OR6APIError(@"capability_unverified",@"none")];return;}
 NSString*op=c->parameters[@"operationId"];NSMutableDictionary*g=_generations[op];OR6API9Call*send=g[@"call"];if(!send||![self current:send]||(!OR6API9UUID(g[@"conversationId"])||![g[@"serverObserved"]boolValue])){[self complete:c result:nil error:OR6APIError(@"invalid_operation_state",@"none")];return;}
 if([send->child respondsToSelector:@selector(prepareForUserStop)])[(id)send->child prepareForUserStop];
 NSError*error=nil;NSURLRequest*r=OR6API9StopRequest(g[@"conversationId"],g[@"conduit"],&error);NSString*control=[@"stop:"stringByAppendingString:op];
 if(!r||![_controls reserve:control command:@"messages.stop"request:@{@"operationId":op,@"conversationId":g[@"conversationId"]}scope:_scope error:&error]){[self complete:c result:nil error:error];return;}c->control=[control copy];if(![_controls finish:control scope:_scope state:@"uncertain"metadata:@{}error:&error]){[self complete:c result:nil error:error];return;}
 _stopRequests++;c->dispatched=YES;id<OR6APITask>task=[_HTTP performRequest:r context:c->context completion:^(NSDictionary*v,NSError*e){
  if(![self current:c])return;if(e){[self complete:c result:nil error:e];return;}NSInteger status=[v[@"status"]integerValue];id json=v[@"json"];if(json==NSNull.null)json=nil;if(json&&(![json isKindOfClass:NSDictionary.class]||json[@"error"]||[json[@"success"]isEqual:@NO])){[self complete:c result:nil error:OR6APIError(@"invalid_response",@"possible")];return;}
  if(status!=200&&status!=204){[self complete:c result:nil error:OR6APIError(@"upstream_error",@"possible")];return;}BOOL confirmed=YES;BOOL local=NO;if(confirmed&&_generations[op]==g&&[self current:send]){local=YES;if([send->child respondsToSelector:@selector(cancelForUserStop)])[(id)send->child cancelForUserStop];[send cancel];}
  NSDictionary*receipt=@{@"operationId":op,@"requested":@YES,@"localConsumptionStopped":@(local),@"serverStopConfirmed":@(confirmed),@"persisted":@NO};[self complete:c result:receipt error:nil];
 }];[self adopt:task call:c];
}
- (NSDictionary*)recording:(NSString*)identifier{
 NSDictionary*s=[_recorder snapshot];BOOL active=[s[@"state"]isEqual:@"recording"],ready=[s[@"state"]isEqual:@"stopped"];return @{@"recordingId":identifier,@"state":active?@"recording":ready?@"stopped":@"failed",@"assetId":ready?(s[@"assetId"]?:(id)NSNull.null):(id)NSNull.null,@"durationMS":s[@"durationMS"]?:@0,@"bytes":s[@"bytes"]?:@0,@"mediaType":@"audio/wav"};
}
- (void)transcribe:(OR6API9Call*)c{
 if(![_capabilities containsObject:@"transcribe"]){[self complete:c result:nil error:OR6APIError(@"capability_unverified",@"none")];return;}
 NSString*recording=c->parameters[@"recordingId"];NSDictionary*s=[_recorder snapshot];if(![_recordingKey isEqual:_scope]||![_recordingID isEqual:recording]||![s[@"state"]isEqual:@"stopped"]||![c->parameters[@"assetId"]isEqual:s[@"assetId"]]){[self complete:c result:nil error:OR6APIError(@"invalid_operation_state",@"none")];return;}
 NSString*capture=nil;
 for(NSUInteger attempt=0;attempt<32;attempt++){NSString*k=[NSString stringWithFormat:@"capture:%@:%lu",recording,(unsigned long)attempt];NSError*storage=nil;NSDictionary*old=[_controls record:k scope:_scope error:&storage];if(storage){[self complete:c result:nil error:storage];return;}if(!old){capture=k;break;}
  if([old[@"state"]isEqual:@"completed"]){NSMutableDictionary*result=[[old[@"result"]mutableCopy]autorelease];if(![result[@"recordingId"]isEqual:recording]||![result[@"text"]isKindOfClass:NSString.class]){[self complete:c result:nil error:OR6APIError(@"storage_failure",@"none")];return;}result[@"operationId"]=c->parameters[@"operationId"];[self complete:c result:result error:nil];return;}
  if(![old[@"state"]isEqual:@"rejected"]){[self complete:c result:nil error:OR6APIError(@"invalid_operation_state",@"none")];return;}
 }
 if(!capture){[self complete:c result:nil error:OR6APIError(@"unavailable",@"none")];return;}
 NSError*error=nil;NSData*data=[_recorder recordingData:recording error:&error];NSString*boundary=Boundary();NSURLRequest*r=data?OR6API9TranscriptionRequest(data,boundary,&error):nil;
 if(!r){[self complete:c result:nil error:error?:OR6APIError(@"unsupported_media",@"none")];return;}NSString*op=c->parameters[@"operationId"],*control=[@"transcribe:"stringByAppendingString:op];
 if(![_controls reserve:control command:@"dictation.transcribe"request:@{@"operationId":op,@"recordingId":recording,@"assetId":s[@"assetId"]}scope:_scope error:&error]){[self complete:c result:nil error:error];return;}c->control=[control copy];if(![_controls finish:control scope:_scope state:@"uncertain"metadata:@{}error:&error]){[self complete:c result:nil error:error];return;}
 if(![_controls reserve:capture command:@"capture.transcribe"request:@{@"operationId":op,@"recordingId":recording}scope:_scope error:&error]){[self complete:c result:nil error:error];return;}c->capture=[capture copy];if(![_controls finish:capture scope:_scope state:@"uncertain"metadata:@{}error:&error]){[self complete:c result:nil error:error];return;}
 _transcriptions++;c->dispatched=YES;id<OR6APITask>task=[_HTTP performRequest:r context:c->context completion:^(NSDictionary*v,NSError*e){
  if(![self current:c])return;if(e){[self complete:c result:nil error:e];return;}id json=v[@"json"];id text=[json isKindOfClass:NSDictionary.class]?json[@"text"]:nil;if([v[@"status"]integerValue]!=200||![text isKindOfClass:NSString.class]||[text length]>16000){[self complete:c result:nil error:OR6APIError(@"unknown_wire_shape",@"possible")];return;}
  NSDictionary*result=@{@"operationId":op,@"recordingId":recording,@"text":text,@"editable":@YES,@"insertedIntoDraft":@NO};if(c->event&&[c->command isEqual:@"dictation.transcribe"]){OR6APIEvent emit=[[c->event copy]autorelease];emit(@{@"name":@"transcript",@"payload":result});}if([self current:c])[self complete:c result:result error:nil];
 }];[self adopt:task call:c];
}
- (NSDictionary*)retryTranscription:(NSString*)prior newID:(NSString*)identifier recording:(NSString*)recording{
 NSMutableSet*seen=[NSMutableSet setWithObject:identifier];NSString*cursor=prior;
 for(NSUInteger depth=0;depth<32;depth++){if(!Text(cursor)||[seen containsObject:cursor])return nil;[seen addObject:cursor];NSError*error=nil;NSDictionary*r=[_controls record:[@"transcribe:"stringByAppendingString:cursor]scope:_scope error:&error];if(error)return nil;
  if(!r)r=[_coreJournal record:cursor scope:_scope error:&error];if(error||![r[@"state"]isEqual:@"rejected"]||![r[@"request"][@"recordingId"]isEqual:recording])return nil;
  if([r[@"command"]isEqual:@"dictation.retry"]){cursor=r[@"request"][@"priorOperationId"];continue;}if([r[@"command"]isEqual:@"dictation.transcribe"]&&Text(r[@"request"][@"assetId"]))return r[@"request"];return nil;
 }return nil;
}
- (id<OR6APITask>)execute:(NSString*)op parameters:(NSDictionary*)p context:(NSDictionary*)ctx event:(OR6APIEvent)event completion:(OR6APIReply)reply{
 if(!NSThread.isMainThread||!Text(ctx[@"key"])||![ctx[@"generation"]isKindOfClass:NSNumber.class]||![ctx[@"generation"]unsignedIntegerValue]||!OR6APIJSONSnapshot(p,512*1024)){reply(nil,OR6APIError(@"invalid_request",@"none"));return nil;}[self context:ctx];if(_calls.count>=8){reply(nil,OR6APIError(@"unavailable",@"none"));return nil;}
 OR6API9Call*c=[[[OR6API9Call alloc]init]autorelease];c->owner=self;c->command=[op copy];c->parameters=[p copy];c->context=[ctx copy];c->reply=[reply copy];c->event=[event copy];[_calls addObject:c];
 if([op isEqual:@"messages.retry"]){NSError*error=nil;NSString*root=nil;NSDictionary*request=[self retryRequest:p[@"previousOperationId"]newID:p[@"operationId"]scope:_scope root:&root error:&error];if(!request||![self reserveRetry:c root:root error:&error])[self complete:c result:nil error:error];else{c->retryDraft=[request[@"draftId"]copy];_retries++;[self delegate:@"messages.send"parameters:request call:c];}}
 else if([op isEqual:@"messages.stop"])[self stop:c];
 else if([op isEqual:@"dictation.transcribe"])[self transcribe:c];
 else if([op isEqual:@"dictation.retry"]){NSDictionary*r=[self retryTranscription:p[@"priorOperationId"]newID:p[@"operationId"]recording:p[@"recordingId"]];NSError*error=nil;if(!r)[self complete:c result:nil error:OR6APIError(@"invalid_operation_state",@"none")];else if(![_coreJournal reserve:p[@"operationId"]command:op request:p scope:_scope error:&error])[self complete:c result:nil error:error];else{c->ownsCore=YES;NSMutableDictionary*q=[[p mutableCopy]autorelease];[q removeObjectForKey:@"priorOperationId"];q[@"assetId"]=r[@"assetId"];[c->parameters release];c->parameters=[q copy];[self transcribe:c];}}
 else if([@[@"dictation.start",@"dictation.stop",@"dictation.cancel"]containsObject:op]){
  NSString*identifier=p[@"recordingId"];if(!_recorder||!OR6API9UUID(identifier)){[self complete:c result:nil error:OR6APIError(_recorder?@"invalid_request":@"capability_unavailable",@"none")];return c;}
  if([op isEqual:@"dictation.start"]){NSError*error=nil;NSUInteger maximum=[p[@"maxDurationMS"]unsignedIntegerValue];if(_recordingID||!maximum||maximum>60000){[self complete:c result:nil error:OR6APIError(@"conflict",@"none")];return c;}
   NSString*marker=[@"recording:"stringByAppendingString:identifier.lowercaseString];if(![_controls reserve:marker command:@"dictation.start"request:@{@"recordingId":identifier}scope:_scope error:&error]){[self complete:c result:nil error:error];return c;}
   if(![_recorder start:identifier maxDurationMS:maximum error:&error]){[_controls finish:marker scope:_scope state:@"rejected"metadata:@{}error:NULL];[self complete:c result:nil error:error?:OR6APIError(@"unavailable",@"none")];return c;}
   _recordingID=[identifier copy];_recordingKey=[_scope copy];if(![_controls finish:marker scope:_scope state:@"completed"metadata:@{@"recordingId":identifier}error:&error]){[_recorder suspend];[self complete:c result:nil error:error];return c;}}
  else{if(![_recordingKey isEqual:_scope]||![_recordingID isEqual:identifier]){[self complete:c result:nil error:OR6APIError(@"invalid_operation_state",@"none")];return c;}if([op isEqual:@"dictation.stop"])[_recorder stop];else{for(OR6API9Call*other in [[_calls.allObjects copy]autorelease])if(other!=c&&[@[@"dictation.transcribe",@"dictation.retry"]containsObject:other->command]&&[other->parameters[@"recordingId"]isEqual:identifier])[self cancel:other];[_recorder cancel];if(![[_recorder snapshot][@"state"]isEqual:@"idle"]){[self complete:c result:nil error:OR6APIError(@"storage_failure",@"none")];return c;}[_recordingID release];_recordingID=nil;[_recordingKey release];_recordingKey=nil;[self complete:c result:@{@"recordingId":identifier,@"state":@"cancelled",@"assetId":NSNull.null,@"durationMS":@0,@"bytes":@0,@"mediaType":@"audio/wav"}error:nil];return c;}}
  [self complete:c result:[self recording:identifier]error:nil];
 }
 else{if([op isEqual:@"auth.logout"]){for(OR6API9Call*other in [[_calls.allObjects copy]autorelease])if(other!=c)[self cancel:other];[_recorder cancel];[_recordingID release];_recordingID=nil;[_recordingKey release];_recordingKey=nil;}[self delegate:op parameters:p call:c];}return c;
}
- (NSDictionary*)diagnostics{return @{@"schema":@1,@"activeCount":@(_calls.count),@"activeGenerations":@(_generations.count),@"retryDispatches":@(_retries),@"stopDispatches":@(_stopRequests),@"transcribeDispatches":@(_transcriptions),@"hasOwnedRecording":@(_recordingID!=nil),@"credentialsExposed":@NO,@"automaticResend":@NO};}
- (void)dealloc{[self deactivate];[_next release];[_HTTP release];[_recorder release];[_coreJournal release];[_controls release];[_capabilities release];[_calls release];[_generations release];[_drafts release];[_scope release];[_recordingKey release];[_recordingID release];[super dealloc];}
@end
