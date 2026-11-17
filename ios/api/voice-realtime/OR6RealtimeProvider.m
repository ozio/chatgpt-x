#import "OR6Realtime.h"
#import "OR6RealtimeNetwork.h"
#import "OR6RealtimeDelta.h"
#import <TargetConditionals.h>
#if TARGET_OS_IPHONE
#import <AVFoundation/AVFoundation.h>
#define RTAudioType AVAudioSessionInterruptionTypeKey
#define RTAudioRouteReason AVAudioSessionRouteChangeReasonKey
#else
#define RTAudioType @"AVAudioSessionInterruptionTypeKey"
#define RTAudioRouteReason @"AVAudioSessionRouteChangeReasonKey"
#endif
#import "../voice8/OR6Voice8.h"
#import "../OR6APIWebAdapter.h"
#import "../../voice/OR6RealtimeRuntime.h"
#import <dispatch/dispatch.h>
static NSString*UUID(void){CFUUIDRef u=CFUUIDCreate(NULL);NSString*s=[(NSString*)CFUUIDCreateString(NULL,u)autorelease];CFRelease(u);return s;}
static BOOL Text(id v){return[v isKindOfClass:NSString.class]&&[v length]>0&&[v length]<=128;}
static NSDictionary*D(id v){return[v isKindOfClass:NSDictionary.class]?v:nil;}
static NSString*StopIssue(NSDictionary*p){NSDictionary*e=D(p[@"error"])?:p;id c=e[@"code"]?:p[@"code"]?:e[@"type"]?:p[@"type"];
 if(![c isKindOfClass:NSString.class])return nil;
 if([@[@"session_limit_exceeded",@"global_limits_exceeded",@"rate_limit_exceeded",@"rate_limit_error",@"rate_limited"]containsObject:c])return @"rate_limited";
 if([@[@"token_expired",@"invalid_token",@"unauthorized",@"authentication_error",@"not_authenticated"]containsObject:c])return @"not_authenticated";
 if([@[@"service_challenge",@"security_challenge"]containsObject:c])return @"service_challenge";
 if([@[@"forbidden",@"permission_denied",@"access_denied"]containsObject:c])return @"access_denied";return nil;
}

NSDictionary*OR6RealtimeRegistry(NSDictionary*base){NSMutableDictionary*r=[[OR6Voice8Registry(base)mutableCopy]autorelease],*types=[[r[@"types"]mutableCopy]autorelease],*type=[[types[@"Voice8State"]mutableCopy]autorelease],*properties=[[type[@"properties"]mutableCopy]autorelease];properties[@"mode"]=@{@"enum":@[@"realtime"]};type[@"properties"]=properties;types[@"Voice8State"]=type;r[@"types"]=types;NSMutableArray*ops=[NSMutableArray array];for(NSDictionary*o in r[@"operations"]){if([o[@"id"]hasPrefix:@"voice."]&&[o[@"transport"]isEqual:@"local_composition"]){NSMutableDictionary*m=[[o mutableCopy]autorelease];m[@"transport"]=@"native_realtime";m[@"notes"]=@"Existing ChatGPT account: multipart SDP, negotiated SCTP SID0, duplex Opus. No automatic reconnect or replay.";[ops addObject:m];}else[ops addObject:o];}r[@"operations"]=ops;return OR6APIJSONSnapshot(r,4*1024*1024);}
@interface OR6RealtimeDone:NSObject<OR6APITask>@end
@implementation OR6RealtimeDone
- (void)cancel{}
@end
@interface OR6RealtimeProvider(){id<OR6APIProvider>_next;OR6APIWebAdapter*_adapter;NSString*_roots;OR6APICore*_core;NSDictionary*_context;OR6RealtimeRuntime*_runtime;id<OR6APITask>_child;NSString*_session,*_phase,*_issue,*_conversation,*_parent,*_model,*_effort;NSMutableArray*_lines;NSMutableSet*_intents,*_messages;NSUInteger _epoch,_sequence,_signaling,_events;BOOL _mic,_output,_blocked,_activity,_connected,_playbackInterrupted,_finishPhrase,_remoteSpeech,_assistantActive;NSString*_assistantID,*_userID;NSTimer*_submitLimit;NSString*_stage;OR6RealtimeDelta*_delta;}
@end
@implementation OR6RealtimeProvider
@synthesize core=_core;
- (id)initWithNext:(id<OR6APIProvider>)next adapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots{if((self=[super init])){_next=[next retain];_adapter=[adapter retain];_roots=[roots copy];_phase=[@"ended"copy];_issue=[@""copy];_delta=[OR6RealtimeDelta new];_lines=[NSMutableArray new];_messages=[NSMutableSet new];_intents=[NSMutableSet new];[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(interrupted:)name:@"AVAudioSessionInterruptionNotification"object:nil];[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(interrupted:)name:@"UIApplicationWillResignActiveNotification"object:nil];[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(routeChanged:)name:@"AVAudioSessionRouteChangeNotification"object:nil];}return self;}
- (void)stage:(NSString*)stage{[_stage release];_stage=[stage copy];}
- (void)phase:(NSString*)phase issue:(NSString*)issue{NSString*p=[phase copy],*i=[(issue?:@"")copy];[_phase release];_phase=p;[_issue release];_issue=i;_sequence++;}
- (BOOL)valid:(NSUInteger)epoch{return epoch==_epoch&&_core&&[_context[@"generation"]isEqual:_core.diagnostics[@"generation"]]&&[_context[@"key"]isEqual:_adapter.contextKey];}
- (void)stop{[_submitLimit invalidate];[_submitLimit release];_submitLimit=nil;_finishPhrase=NO;_epoch++;[_child cancel];[_child release];_child=nil;[_runtime stop];_connected=NO;}
- (void)fail:(NSError*)error{NSString*code=error.userInfo[@"code"]?:@"unavailable";_blocked=[@[@"not_authenticated",@"stale_context",@"owner_mismatch",@"service_challenge",@"rate_limited",@"access_denied",@"permission_denied"]containsObject:code];[self stop];[self phase:_blocked?@"failed":@"reconnecting"issue:code];}
- (void)child:(NSString*)op parameters:(NSDictionary*)p completion:(OR6APIReply)reply{NSUInteger epoch=_epoch;__block BOOL done=NO;id<OR6APITask>t=[_core perform:op parameters:p event:nil completion:^(NSDictionary*r,NSError*e){done=YES;if(![self valid:epoch])return;[_child release];_child=nil;reply(r,e);}];if(!done&&[self valid:epoch]){[_child release];_child=[t retain];}}
- (void)line:(NSString*)text role:(NSString*)role identifier:(NSString*)identifier{if(![text isKindOfClass:NSString.class]||!text.length||![@[@"user",@"assistant"]containsObject:role]||_lines.count>=128||_messages.count>=512)return;if(identifier&&[_messages containsObject:identifier])return;if(identifier)[_messages addObject:identifier];[_lines addObject:@{@"role":role,@"text":[text substringToIndex:MIN((NSUInteger)16000,text.length)]}];_sequence++;}
- (void)inputGate{[_runtime setMicrophoneMuted:_mic||_finishPhrase outputMuted:_output||_playbackInterrupted];}
- (void)finishLimit:(NSTimer*)timer{(void)timer;[_submitLimit invalidate];[_submitLimit release];_submitLimit=nil;_finishPhrase=NO;[self inputGate];if([_phase isEqual:@"sending"])[self phase:@"listening"issue:nil];}
- (void)message:(NSDictionary*)m{NSString*role=D(m[@"author"])[@"role"];BOOL finished=[m[@"status"]isEqual:@"finished_successfully"]||[m[@"end_turn"]isEqual:@YES];NSString*identifier=m[@"id"];if(Text(identifier)&&[role isEqual:@"assistant"]){BOOL fresh=![_assistantID isEqual:identifier];if(fresh){[_assistantID release];_assistantID=[identifier copy];_playbackInterrupted=NO;_finishPhrase=NO;[_submitLimit invalidate];[_submitLimit release];_submitLimit=nil;[self inputGate];}_assistantActive=!finished;if(finished&&!_remoteSpeech)[self phase:@"listening"issue:nil];else if(!finished&&!_remoteSpeech&&!_playbackInterrupted)[self phase:@"thinking"issue:nil];}
 if(Text(identifier)&&[role isEqual:@"user"]){if(![_userID isEqual:identifier]){[_userID release];_userID=[identifier copy];[_runtime flushOutput];}_activity=YES;if(finished&&!_remoteSpeech)[self phase:@"thinking"issue:nil];}
 if(!finished)return;NSDictionary*c=D(m[@"content"]);NSMutableArray*text=[NSMutableArray array];id parts=c[@"parts"];if([parts isKindOfClass:NSArray.class]&&[parts count]<=128)for(id p in parts){if([p isKindOfClass:NSString.class])[text addObject:p];else if([D(p)[@"text"]isKindOfClass:NSString.class])[text addObject:p[@"text"]];}if([c[@"text"]isKindOfClass:NSString.class])[text addObject:c[@"text"]];[self line:[text componentsJoinedByString:@"\n"]role:role identifier:Text(m[@"id"])?m[@"id"]:nil];}
- (void)received:(NSDictionary*)event{
 _events++;NSString*t=event[@"type"];NSDictionary*p=event[@"payload"];
 if(Text(p[@"conversation_id"])&&[@[@"conversation_update",@"conversation_detail_metadata",@"streaming_message_update",@"startup_telemetry"]containsObject:t]){[_conversation release];_conversation=[p[@"conversation_id"]copy];}
 if([t isEqual:@"state_update"]){NSString*s=p[@"new_state"];if([@[@"listening",@"listening_intently",@"thinking",@"speaking"]containsObject:s]){if([s isEqual:@"thinking"]||[s isEqual:@"speaking"])_activity=YES;if(![s isEqual:@"speaking"])[_runtime flushOutput];[self phase:[s isEqual:@"listening_intently"]?@"listening":s issue:nil];}}
 else if([t isEqual:@"or6_audio_activity"]){_remoteSpeech=[p[@"active"]boolValue];if(_remoteSpeech&&!_playbackInterrupted){_activity=YES;[self phase:@"speaking"issue:nil];}else if(!_assistantActive&&[_phase isEqual:@"speaking"])[self phase:@"listening"issue:nil];}
 else if([t isEqual:@"spawn_update"]&&[p[@"state"]isEqual:@"start"]){_activity=YES;if(![_phase isEqual:@"speaking"])[self phase:@"thinking"issue:nil];}
 else if([t isEqual:@"chat_message_delta"]){NSDictionary*m=[_delta apply:D(p[@"delta"])];if(m)[self message:D(m[@"message"])];}
 else if([t isEqual:@"full_chat_message"])[self message:D(p[@"message"])];
 else if([t isEqual:@"user_transcription_text"]){_activity=YES;[self line:p[@"text"]role:@"user"identifier:Text(p[@"message_id"])?p[@"message_id"]:nil];}
 else if([t isEqual:@"startup_telemetry"]&&[p[@"success"]isEqual:@NO])[self fail:OR6APIError(@"upstream_error",@"confirmed")];
 else if([t isEqual:@"error"])[self fail:OR6APIError(StopIssue(p)?:@"upstream_error",@"confirmed")];
 else if([t isEqual:@"goodbye"]){NSString*issue=StopIssue(p);if(issue)[self fail:OR6APIError(issue,@"confirmed")];else{[self stop];[self phase:@"ended"issue:nil];}}
 else if([t isEqual:@"usage_update"]&&([D(p[@"instructions"])[@"hang_up"]isEqual:@YES]||D(D(p[@"rate_limit_message"])[@"exceed_limit_message"]))){_blocked=YES;[self stop];[self phase:@"ended"issue:@"rate_limited"];}
}
- (void)trackState{[_runtime send:@{@"type":@"track_state",@"payload":@{@"type":@"track_state",@"track_id":@"microphone",@"media_type":@"audio",@"media_source":@"microphone",@"state":_mic?@"muted":@"live"}}];}
- (void)signal:(NSDictionary*)settings{
 if(!Text(settings[@"voiceId"])||[settings[@"voiceEnabled"]isEqual:@NO]||!Text(_model)||[_model isEqual:@"web-current"]){[self fail:OR6APIError(@"capability_unavailable",@"none")];return;}
 if(_runtime&&!_runtime.isQuiescent){[self fail:OR6APIError(@"conflict",@"none")];return;}[_runtime release];_runtime=[OR6RealtimeRuntime new];[self inputGate];[self stage:@"offer"];NSUInteger epoch=_epoch;
 [_runtime offer:^(NSString*offer,NSError*error){if(![self valid:epoch])return;if(error){[self fail:OR6APIError(@"unavailable",@"none")];return;}
  NSString*sid=UUID();NSMutableDictionary*session=[NSMutableDictionary dictionaryWithDictionary:@{@"parent_message_id":_parent,@"requested_default_model":@"",@"voice":settings[@"voiceId"],@"voice_session_id":sid,@"voice_status_request_id":sid,@"timezone_offset_min":@(-NSTimeZone.localTimeZone.secondsFromGMT/60),@"timezone":NSTimeZone.localTimeZone.name?:@"UTC",@"user_locale":(NSLocale.preferredLanguages.count?[NSLocale.preferredLanguages objectAtIndex:0]:nil)?:@"en-US",@"voice_mode":@"wingman",@"model_slug":@"",@"model_slug_advanced":@"",@"client_tools":@[],@"history_and_training_disabled":@NO,@"conversation_mode":@{@"kind":@"primary_assistant"},@"chat_mode":@"chat",@"backend_model":_model,@"enable_message_streaming":@YES,@"deprecate_celsius":@YES}];
  if(_conversation)session[@"conversation_id"]=_conversation;if(_effort){session[@"thinking_effort"]=_effort;session[@"backend_thinking_effort"]=_effort;}if(Text(settings[@"language"])&&![settings[@"language"]isEqual:@"auto"])session[@"language_code"]=settings[@"language"];
  [self stage:@"signaling"];_signaling++;__block BOOL done=NO;id<OR6APITask>task=OR6RealtimeConnect(_adapter,_roots,_context,session,offer,^(NSDictionary*r,NSError*e){done=YES;if(![self valid:epoch])return;[_child release];_child=nil;if(e){[self fail:e];return;}[self stage:@"transport"];
   [_runtime connect:r[@"sdp"]event:^(NSDictionary*event){if([self valid:epoch])[self received:event];}ready:^{if(![self valid:epoch])return;_connected=YES;[self stage:@"connected"];[self trackState];if([_phase isEqual:@"reconnecting"])[self phase:@"listening"issue:nil];}failure:^(NSString*code){if([self valid:epoch])[self fail:OR6APIError(code,@"possible")];}];
  });if(!done&&[self valid:epoch])_child=[task retain];
 }];
}
- (void)prepare{[self stage:@"settings"];[self child:@"voice.settings.get"parameters:@{}completion:^(NSDictionary*s,NSError*e){if(e){[self fail:e];return;}void(^next)(void)=^{if(_conversation){[self stage:@"history"];[self child:@"history.get"parameters:@{@"conversationId":_conversation}completion:^(NSDictionary*h,NSError*problem){if(problem){[self fail:problem];return;}if(!Text(h[@"currentNode"])||![h[@"id"]isEqual:_conversation]){[self fail:OR6APIError(@"unknown_wire_shape",@"none")];return;}[_parent release];_parent=[h[@"currentNode"]copy];[self signal:s];}];}else[self signal:s];};
  if([_model isEqual:@"web-current"]){[self child:@"models.list"parameters:@{}completion:^(NSDictionary*m,NSError*problem){if(problem||!Text(m[@"selectedModelId"])){[self fail:problem?:OR6APIError(@"capability_unavailable",@"none")];return;}[_model release];_model=[m[@"selectedModelId"]copy];next();}];}else next();
 }];}
- (NSDictionary*)snapshot{BOOL can=_session&&!_child&&!_blocked&&(!_runtime||_runtime.isQuiescent)&&[@[@"paused",@"ended",@"reconnecting"]containsObject:_phase]&&(!_activity||_conversation);return@{@"sessionId":_session?:@"none",@"state":_phase,@"microphoneMuted":@(_mic),@"outputMuted":@(_output),@"canResume":@(can),@"sequence":@(_sequence),@"conversationId":_conversation?:(id)NSNull.null,@"issue":_issue,@"uncertain":@NO,@"transcript":[[_lines copy]autorelease],@"mode":@"realtime"};}
- (id<OR6APITask>)execute:(NSString*)op parameters:(NSDictionary*)p context:(NSDictionary*)ctx event:(OR6APIEvent)event completion:(OR6APIReply)reply{
 if(![@[@"voice.start",@"voice.state",@"voice.submit",@"voice.mute",@"voice.interrupt",@"voice.end",@"voice.resume"]containsObject:op])return[_next execute:op parameters:p context:ctx event:event completion:reply];OR6RealtimeDone*done=[[[OR6RealtimeDone alloc]init]autorelease];if(!NSThread.isMainThread||!_core||![ctx[@"key"]isEqual:_adapter.contextKey]){reply(nil,OR6APIError(@"not_authenticated",@"none"));return done;}
 if(_context&&![_context isEqual:ctx])[self deactivate];
 if([op isEqual:@"voice.start"]){if((_session&&![_phase isEqual:@"ended"])||(_runtime&&!_runtime.isQuiescent)){reply(nil,OR6APIError(@"conflict",@"none"));return done;}[self deactivate];_session=[UUID()copy];_context=[ctx copy];_parent=[UUID()copy];_conversation=Text(p[@"conversationId"])?[p[@"conversationId"]copy]:nil;_model=[(p[@"modelId"]?:@"web-current")copy];_effort=Text(p[@"thinkingEffort"])?[p[@"thinkingEffort"]copy]:nil;[_intents addObject:p[@"operationId"]];[self phase:@"reconnecting"issue:nil];[self prepare];}
 else if(![_session isEqual:p[@"sessionId"]]){reply(nil,OR6APIError(@"stale_context",@"none"));return done;}
 else if([op isEqual:@"voice.end"]){[self stop];[self phase:@"ended"issue:nil];}
 else if([op isEqual:@"voice.resume"]){if(![[self snapshot][@"canResume"]boolValue]||[_intents containsObject:p[@"operationId"]]||_intents.count>=128){reply(nil,OR6APIError(@"invalid_operation_state",@"none"));return done;}[_intents addObject:p[@"operationId"]];_epoch++;_playbackInterrupted=_finishPhrase=_remoteSpeech=_assistantActive=NO;[self phase:@"reconnecting"issue:nil];[self prepare];}
 else if([op isEqual:@"voice.mute"]){_mic=[p[@"microphoneMuted"]boolValue];_output=[p[@"outputMuted"]boolValue];[self inputGate];if(_connected)[self trackState];_sequence++;}
 else if([op isEqual:@"voice.submit"]||[op isEqual:@"voice.interrupt"]){if(!_connected){reply(nil,OR6APIError(@"invalid_operation_state",@"none"));return done;}if([op isEqual:@"voice.interrupt"]){_playbackInterrupted=YES;[self inputGate];[_runtime flushOutput];[self phase:@"listening"issue:nil];}else if(!_mic&&[_phase isEqual:@"listening"]){_finishPhrase=YES;[self inputGate];[self phase:@"sending"issue:nil];[_submitLimit invalidate];[_submitLimit release];_submitLimit=[[NSTimer timerWithTimeInterval:2.5 target:self selector:@selector(finishLimit:)userInfo:nil repeats:NO]retain];[NSRunLoop.mainRunLoop addTimer:_submitLimit forMode:NSRunLoopCommonModes];}}

 reply([self snapshot],nil);return done;
}
- (void)interrupted:(NSNotification*)n{if([n.name isEqual:@"AVAudioSessionInterruptionNotification"]&&[n.userInfo[RTAudioType]unsignedIntegerValue]!=1)return;[self pause];}
- (void)routeChanged:(NSNotification*)n{if([n.userInfo[RTAudioRouteReason]unsignedIntegerValue]==2)[self pause];}
- (void)pause{if(!_session||[_phase isEqual:@"ended"])return;[self stop];[self phase:@"paused"issue:nil];}
- (void)deactivate{[self stop];[_context release];_context=nil;[_session release];_session=nil;[_conversation release];_conversation=nil;[_parent release];_parent=nil;[_model release];_model=nil;[_effort release];_effort=nil;[_delta clear];[_lines removeAllObjects];[_messages removeAllObjects];[_intents removeAllObjects];[_assistantID release];_assistantID=nil;[_userID release];_userID=nil;_blocked=_activity=_mic=_output=_playbackInterrupted=_finishPhrase=_remoteSpeech=_assistantActive=NO;[self phase:@"ended"issue:nil];}
- (NSDictionary*)diagnostics{return@{@"mode":@"realtime",@"state":_phase,@"issue":_issue,@"stage":_stage?:@"idle",@"signalingRequests":@(_signaling),@"events":@(_events),@"audioActive":@(_connected),@"peer":_runtime.diagnostics?:@{}};}
- (void)dealloc{[NSNotificationCenter.defaultCenter removeObserver:self];[self deactivate];[_runtime release];[_next release];[_adapter release];[_roots release];[_phase release];[_issue release];[_stage release];[_delta release];[_lines release];[_messages release];[_intents release];[super dealloc];}
@end
