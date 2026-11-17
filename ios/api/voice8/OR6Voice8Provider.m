#import "OR6Voice8.h"
#import <dispatch/dispatch.h>
static NSString *UUID(void){CFUUIDRef u=CFUUIDCreate(NULL);NSString*s=[(NSString*)CFUUIDCreateString(NULL,u)autorelease];CFRelease(u);return s;}
static BOOL Text(id s){return[s isKindOfClass:NSString.class]&&[s length]>0;}
@interface OR6Voice8Done:NSObject<OR6APITask>@end
@implementation OR6Voice8Done
- (void)cancel{}
@end
@interface OR6Voice8Provider(){
 id<OR6APIProvider>_next;OR6APICore*_core;id<OR6APITask>_child;
 NSDictionary*_context;NSString*_session,*_phase,*_issue,*_conversation,*_parent,*_model,*_effort,*_recording,*_asset,*_send,*_assistant,*_playAsset;
 NSMutableArray*_transcript;NSMutableSet*_intents;NSTimer*_timer,*_limit;
 NSUInteger _epoch,_sequence;BOOL _mic,_sound,_uncertain,_querying,_ownsPlayback,_blocked,_synthesizing;
}
@end
@implementation OR6Voice8Provider
@synthesize core=_core;
- (id)initWithNext:(id<OR6APIProvider>)next{if((self=[super init])){_next=[next retain];_transcript=[NSMutableArray new];_intents=[NSMutableSet new];_phase=[@"ended"copy];_issue=[@""copy];[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(interrupted:)name:@"AVAudioSessionInterruptionNotification"object:nil];[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(interrupted:)name:@"UIApplicationWillResignActiveNotification"object:nil];}return self;}
- (void)phase:(NSString*)phase issue:(NSString*)issue{NSString*p=[phase copy],*i=[(issue?:@"")copy];[_phase release];_phase=p;[_issue release];_issue=i;_sequence++;[NSNotificationCenter.defaultCenter postNotificationName:@"OR6Voice8Changed"object:self];}
- (BOOL)valid:(NSUInteger)epoch{return _core&&epoch==_epoch&&[_context[@"generation"]isEqual:_core.diagnostics[@"generation"]];}
- (void)clearChild{_epoch++;id<OR6APITask>t=[[_child retain]autorelease];[_child release];_child=nil;[t cancel];_querying=NO;_synthesizing=NO;}
- (void)call:(NSString*)op parameters:(NSDictionary*)p completion:(OR6APIReply)reply{
 NSUInteger epoch=_epoch;__block BOOL done=NO;
 id<OR6APITask>task=[_core perform:op parameters:p event:nil completion:^(NSDictionary*r,NSError*e){done=YES;if(![self valid:epoch])return;[_child release];_child=nil;reply(r,e);}];
 if(!done&&[self valid:epoch]){[_child release];_child=[task retain];}
}
- (void)device:(NSString*)op parameters:(NSDictionary*)p{if(_core)[_core perform:op parameters:p event:nil completion:^(NSDictionary*r,NSError*e){(void)r;(void)e;}];}
- (void)clearLimit{[_limit invalidate];[_limit release];_limit=nil;}
- (void)discardRecording{[self clearLimit];if(_recording){[self device:@"dictation.cancel"parameters:@{@"recordingId":_recording}];[_recording release];_recording=nil;}[_asset release];_asset=nil;}
- (void)stopPlayback{if(_ownsPlayback)[self device:@"playback.stop"parameters:@{}];_ownsPlayback=NO;[_playAsset release];_playAsset=nil;}
- (void)failure:(NSError*)e uncertain:(BOOL)uncertain{
 NSString*code=e.userInfo[@"code"]?:@"unavailable";_uncertain=uncertain;
 _blocked=[@[@"service_challenge",@"rate_limited",@"access_denied",@"not_authenticated",@"login_required",@"stale_context",@"auth_failed",@"owner_mismatch",@"permission_denied"]containsObject:code];
 [self phase:(_blocked?@"failed":@"reconnecting")issue:code];
}
- (void)listen{
 if(_blocked||[_phase isEqual:@"ended"]||!_core)return;
 [self clearLimit];[self stopPlayback];[self phase:@"listening"issue:nil];if(_mic)return;
 [self discardRecording];_recording=[UUID()copy];
 [self call:@"dictation.start"parameters:@{@"recordingId":_recording,@"maxDurationMS":@60000}completion:^(NSDictionary*r,NSError*e){
  if(e){[self discardRecording];[self failure:e uncertain:NO];return;}
  if(![r[@"state"]isEqual:@"recording"]){[self failure:OR6APIError(@"invalid_response",@"none")uncertain:NO];return;}
  _limit=[[NSTimer timerWithTimeInterval:60 target:self selector:@selector(expired:)userInfo:nil repeats:NO]retain];[NSRunLoop.mainRunLoop addTimer:_limit forMode:NSRunLoopCommonModes];
 }];
}
- (void)expired:(NSTimer*)timer{(void)timer;[self pause];[self phase:@"paused"issue:@"size_limit"];}
- (void)poll:(NSTimer*)timer{
 (void)timer;if(_querying||!_ownsPlayback||![_phase isEqual:@"speaking"])return;_querying=YES;
 [self call:@"playback.status"parameters:@{}completion:^(NSDictionary*r,NSError*e){_querying=NO;
  if(e||![r[@"assetId"]isEqual:_playAsset]){[self stopPlayback];[self failure:e?:OR6APIError(@"invalid_operation_state",@"none")uncertain:NO];return;}
  if([r[@"state"]isEqual:@"stopped"]||[r[@"state"]isEqual:@"idle"])[self listen];
  else if([r[@"state"]isEqual:@"failed"]){[self stopPlayback];[self failure:OR6APIError(@"unavailable",@"none")uncertain:NO];}
  else if([r[@"state"]isEqual:@"paused"]&&!_sound){[self pause];}
 }];
}
- (NSDictionary*)snapshot{
 BOOL resume=_session&&!_child&&!_blocked&&[@[@"paused",@"reconnecting",@"ended"]containsObject:_phase];
 return@{@"sessionId":_session?:@"none",@"state":_phase,@"microphoneMuted":_mic?@YES:@NO,@"outputMuted":_sound?@YES:@NO,@"canResume":resume?@YES:@NO,@"sequence":@(_sequence),@"conversationId":_conversation?:(id)NSNull.null,@"issue":_issue,@"uncertain":_uncertain?@YES:@NO,@"transcript":[[_transcript copy]autorelease],@"mode":@"turn_based"};
}
- (void)line:(NSString*)text role:(NSString*)role{if(Text(text)&&_transcript.count<128)[_transcript addObject:@{@"role":role,@"text":[text substringToIndex:MIN(text.length,(NSUInteger)16000)]}];}
- (void)readAnswer{
 if(!_conversation||!_assistant){[self failure:OR6APIError(@"invalid_response",@"possible")uncertain:YES];return;}
 [self call:@"history.get"parameters:@{@"conversationId":_conversation}completion:^(NSDictionary*r,NSError*e){
  if(e){[self failure:e uncertain:NO];return;}NSDictionary*answer=nil;
  if([r[@"id"]isEqual:_conversation])for(NSDictionary*m in r[@"messages"])if([m[@"id"]isEqual:_assistant]&&[m[@"role"]isEqual:@"assistant"]&&[m[@"finished"]boolValue])answer=m;
  if(!answer||!Text(answer[@"text"])){[self failure:OR6APIError(@"invalid_response",@"none")uncertain:NO];return;}
  [_parent release];_parent=[r[@"currentNode"]copy];[self line:answer[@"text"]role:@"assistant"];
  // Sound-off never starts an audible asset, even while synthesize would be pending.
  if(_sound){[self listen];return;}
  _synthesizing=YES;[self call:@"audio.readAloud"parameters:@{@"conversationId":_conversation,@"messageId":_assistant}completion:^(NSDictionary*a,NSError*problem){
   _synthesizing=NO;if(problem){[self failure:problem uncertain:NO];return;}_ownsPlayback=YES;[_playAsset release];_playAsset=[a[@"assetId"]copy];
   if(_sound)[self device:@"playback.pause"parameters:@{}];[self phase:@"speaking"issue:nil];
  }];
 }];
}
- (void)acceptReceipt:(NSDictionary*)r error:(NSError*)e{
 if(e||![r[@"persisted"]isEqual:@YES]||![r[@"operationId"]isEqual:_send]){[self failure:e?:OR6APIError(@"uncertain_outcome",@"possible")uncertain:e?![e.userInfo[@"dispatch"]isEqual:@"none"]:YES];return;}
 _uncertain=NO;[_conversation release];_conversation=[r[@"conversationId"]copy];[_assistant release];_assistant=[r[@"assistantMessageId"]copy];[self readAnswer];
}
- (void)sendText:(NSString*)text{
 [self line:text role:@"user"];[_send release];_send=[UUID()copy];[_assistant release];_assistant=nil;
 NSMutableDictionary*p=[NSMutableDictionary dictionaryWithDictionary:@{@"operationId":_send,@"draftId":UUID(),@"text":text,@"modelId":_model,@"parentMessageId":_parent,@"temporary":@NO,@"attachments":@[]}];if(_conversation)p[@"conversationId"]=_conversation;if(_effort)p[@"thinkingEffort"]=_effort;
 [self phase:@"thinking"issue:nil];[self call:@"messages.send"parameters:p completion:^(NSDictionary*r,NSError*e){[self acceptReceipt:r error:e];}];
}
- (void)submit{
 if(![_phase isEqual:@"listening"]||_mic||!_recording||_child)return;
 if(_transcript.count>=126){[self discardRecording];_blocked=YES;[self phase:@"failed"issue:@"size_limit"];return;}
 [self clearLimit];[_send release];_send=nil;[self phase:@"sending"issue:nil];
 [self call:@"dictation.stop"parameters:@{@"recordingId":_recording}completion:^(NSDictionary*r,NSError*e){
  if(e||![r[@"assetId"]isKindOfClass:NSString.class]){[self failure:e?:OR6APIError(@"unsupported_media",@"none")uncertain:NO];return;}
  [_asset release];_asset=[r[@"assetId"]copy];
  [self call:@"dictation.transcribe"parameters:@{@"operationId":UUID(),@"recordingId":_recording,@"assetId":_asset}completion:^(NSDictionary*t,NSError*problem){
   if(problem){[self failure:problem uncertain:![problem.userInfo[@"dispatch"]isEqual:@"none"]];return;}
   NSString*text=t[@"text"];NSString*trim=[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];[self discardRecording];
   if(!trim.length){[self listen];return;}[self sendText:text];
  }];
 }];
}
- (void)interrupted:(NSNotification*)notification{(void)notification;[self pause];}
- (void)pause{
 if(!_session||[_phase isEqual:@"ended"])return;
 BOOL unknown=[_phase isEqual:@"sending"]||([_phase isEqual:@"thinking"]&&!_assistant);[self clearChild];[self discardRecording];[self stopPlayback];_uncertain|=unknown;[self phase:@"paused"issue:unknown?@"uncertain_outcome":nil];
}
- (void)deactivate{
 [self clearChild];[self discardRecording];[self stopPlayback];[_timer invalidate];[_timer release];_timer=nil;
 [_context release];_context=nil;[_session release];_session=nil;[_conversation release];_conversation=nil;[_parent release];_parent=nil;[_model release];_model=nil;[_effort release];_effort=nil;[_send release];_send=nil;[_assistant release];_assistant=nil;
 [_transcript removeAllObjects];[_intents removeAllObjects];_uncertain=_blocked=_mic=_sound=NO;[self phase:@"ended"issue:nil];
}
- (void)resume{
 [self phase:@"reconnecting"issue:nil];
 if(_uncertain){
  if(!_send){_uncertain=NO;[self discardRecording];[self listen];return;}
  [self call:@"messages.reconcile"parameters:@{@"operationId":_send}completion:^(NSDictionary*r,NSError*e){[self acceptReceipt:r error:e];}];return;
 }
 // No phrase or failed mutation is replayed. Resume reuses this conversation's fresh parent.
 if(_conversation){[self call:@"history.get"parameters:@{@"conversationId":_conversation}completion:^(NSDictionary*r,NSError*e){if(e){[self failure:e uncertain:NO];return;}if(![r[@"id"]isEqual:_conversation]||!Text(r[@"currentNode"])){[self failure:OR6APIError(@"invalid_response",@"none")uncertain:NO];return;}[_parent release];_parent=[r[@"currentNode"]copy];[self listen];}];}else[self listen];
}
- (id<OR6APITask>)execute:(NSString*)op parameters:(NSDictionary*)p context:(NSDictionary*)ctx event:(OR6APIEvent)event completion:(OR6APIReply)reply{
 NSArray*ops=@[@"voice.start",@"voice.submit",@"voice.state",@"voice.mute",@"voice.interrupt",@"voice.end",@"voice.resume"];
 if(![ops containsObject:op])return[_next execute:op parameters:p context:ctx event:event completion:reply];
 OR6Voice8Done*done=[[[OR6Voice8Done alloc]init]autorelease];
 if(!NSThread.isMainThread||!_core||[ctx[@"key"]isEqual:@"anonymous"]){reply(nil,OR6APIError(@"not_authenticated",@"none"));return done;}
 if(_context&&![_context isEqual:ctx])[self deactivate];
 if([op isEqual:@"voice.start"]){
  if(_session&&![_phase isEqual:@"ended"]){reply(nil,OR6APIError(@"conflict",@"none"));return done;}
  [self deactivate];_context=[ctx copy];_session=[UUID()copy];_parent=[UUID()copy];_model=[(p[@"modelId"]?:@"web-current")copy];_effort=Text(p[@"thinkingEffort"])?[p[@"thinkingEffort"]copy]:nil;_conversation=Text(p[@"conversationId"])?[p[@"conversationId"]copy]:nil;
  [_intents addObject:p[@"operationId"]];[self phase:@"reconnecting"issue:nil];_timer=[[NSTimer timerWithTimeInterval:.35 target:self selector:@selector(poll:)userInfo:nil repeats:YES]retain];[NSRunLoop.mainRunLoop addTimer:_timer forMode:NSRunLoopCommonModes];[self resume];
 }else{
  if(!_session||![_session isEqual:p[@"sessionId"]]){reply(nil,OR6APIError(@"stale_context",@"none"));return done;}
  if([op isEqual:@"voice.end"]){[self pause];[self phase:@"ended"issue:_issue];[_timer invalidate];[_timer release];_timer=nil;}
  else if([op isEqual:@"voice.state"]){}
  else if([op isEqual:@"voice.resume"]){
   if(![[self snapshot][@"canResume"]boolValue]||[_intents containsObject:p[@"operationId"]]){reply(nil,OR6APIError(@"invalid_operation_state",@"none"));return done;}
   [_intents addObject:p[@"operationId"]];if(!_timer){_timer=[[NSTimer timerWithTimeInterval:.35 target:self selector:@selector(poll:)userInfo:nil repeats:YES]retain];[NSRunLoop.mainRunLoop addTimer:_timer forMode:NSRunLoopCommonModes];}[self resume];
  }else if([op isEqual:@"voice.submit"])[self submit];
  else if([op isEqual:@"voice.interrupt"]){if(![_phase isEqual:@"speaking"]){reply(nil,OR6APIError(@"invalid_operation_state",@"none"));return done;}[self clearChild];[self stopPlayback];[self listen];}
  else if([op isEqual:@"voice.mute"]){
   BOOL wasMic=_mic,wasSound=_sound;_mic=[p[@"microphoneMuted"]boolValue];_sound=[p[@"outputMuted"]boolValue];
   if(_mic&&!wasMic&&[_phase isEqual:@"listening"])[self discardRecording];
   if(!_mic&&wasMic&&[_phase isEqual:@"listening"])[self listen];
   if(_sound&&!wasSound&&_synthesizing){[self clearChild];_synthesizing=NO;[self listen];}
   if(_ownsPlayback&&_sound!=wasSound)[self device:_sound?@"playback.pause":@"playback.resume"parameters:@{}];_sequence++;
  }
 }
 reply([self snapshot],nil);return done;
}
- (void)didValidate:(NSString*)op result:(NSDictionary*)r context:(NSDictionary*)ctx{if([_next respondsToSelector:@selector(didValidate:result:context:)])[_next didValidate:op result:r context:ctx];}
- (void)releaseCompletedDraft:(NSString*)draft context:(NSDictionary*)ctx{if([_next respondsToSelector:@selector(releaseCompletedDraft:context:)])[_next releaseCompletedDraft:draft context:ctx];}
- (NSDictionary*)diagnostics{return@{@"active":_session?@YES:@NO,@"state":_phase,@"sequence":@(_sequence),@"uncertain":_uncertain?@YES:@NO,@"transcriptLines":@(_transcript.count),@"mode":@"turn_based",@"realtimeAdmission":@NO};}
- (void)dealloc{[NSNotificationCenter.defaultCenter removeObserver:self];[self deactivate];[_next release];[_transcript release];[_intents release];[_phase release];[_issue release];[super dealloc];}
@end
