#import "OR6ChatVoice8.h"
#import "../../localization/OR6Localization.h"
#import "../OR6ChatUIState.h"
#import "../OR6ChatScreens.h"
@interface OR6APICore(Voice8Availability)
- (BOOL)or6_voice8Available;
@end
@implementation OR6APICore(Voice8Availability)
- (BOOL)or6_voice8Available{return[@[@"local_composition",@"native_realtime"]containsObject:_operations[@"voice.start"][@"transport"]];}
@end
BOOL OR6ChatVoice8Available(OR6APICore*core){return[core or6_voice8Available];}
@interface OR6ChatVoice8(){OR6APICore*_core;NSString*_session;NSDictionary*_snapshot;NSTimer*_poll;NSUInteger _lines;BOOL _closing;id<OR6ChatVoice8Host>_host;}
@end
@implementation OR6ChatVoice8
@synthesize host=_host;
- (id)initWithCore:(OR6APICore*)core{if((self=[super init])){_core=[core retain];self.delegate=self;self.showsMuteControls=YES;self.showsTranscriptToggle=YES;self.showsSettings=NO;[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(ownerChanged:)name:@"OR6Voice8OwnerChanged"object:nil];}return self;}
- (void)apply:(NSDictionary*)s{
 if(!s||[_snapshot isEqual:s])return;[_snapshot release];_snapshot=[s copy];NSString*p=s[@"state"];
 self.muted=[s[@"microphoneMuted"]boolValue];self.soundOff=[s[@"outputMuted"]boolValue];
 self.stateText=nil;self.hintText=nil;self.noticeText=nil;
 self.state=[p isEqual:@"listening"]?RCVoiceListening:[p isEqual:@"sending"]?RCVoiceSending:[p isEqual:@"thinking"]?RCVoiceThinking:[p isEqual:@"speaking"]?RCVoiceSpeaking:[p isEqual:@"failed"]?RCVoiceError:RCVoiceReconnecting;
 if([s[@"mode"]isEqual:@"realtime"]&&[p isEqual:@"listening"]&&![s[@"microphoneMuted"]boolValue])self.hintText=OR6L(@"Speak naturally. You can interrupt by speaking.");
 self.interruptAvailable=[p isEqual:@"speaking"];
 if([p isEqual:@"reconnecting"]&&![s[@"issue"]length]){self.stateText=OR6L(@"Connecting…");self.hintText=OR6L(@"Preparing voice conversation…");}
 if([p isEqual:@"ended"]){self.stateText=OR6L(@"Voice ended");self.hintText=[s[@"canResume"]boolValue]?OR6L(@"Tap the orb to resume"):OR6L(@"Voice unavailable");}
 if([p isEqual:@"paused"]){self.stateText=OR6L(@"Voice paused");self.hintText=OR6L(@"Tap the orb to resume");}
 else if([p isEqual:@"reconnecting"]&&[s[@"canResume"]boolValue]){self.hintText=OR6L(@"Tap to reconnect. Your last message will not be sent again.");}
 if([s[@"issue"]length])self.noticeText=OR6ChatErrorText(OR6APIError(s[@"issue"],@"none"));
 if([s[@"uncertain"]boolValue])self.noticeText=OR6L(@"The last result is unconfirmed. Reconnect checks the existing send without sending it again.");
 NSArray*transcript=s[@"transcript"];for(;_lines<transcript.count;_lines++){NSDictionary*l=transcript[_lines];[self appendTranscriptLine:l[@"text"]speaker:[l[@"role"]isEqual:@"user"]?OR6L(@"You"):@"ChatGPT"];}
}
- (void)call:(NSString*)op parameters:(NSDictionary*)p{
 if(_closing)return;[_core perform:op parameters:p event:nil completion:^(NSDictionary*r,NSError*e){if(_closing)return;if(e){if([e.userInfo[@"code"]isEqual:@"stale_context"]){[_session release];_session=nil;[_snapshot release];_snapshot=nil;_lines=0;[self clearTranscript];}self.state=RCVoiceError;self.stateText=OR6L(@"Voice unavailable");self.noticeText=OR6ChatErrorText(e);}else{if(!_session)_session=[r[@"sessionId"]copy];[self apply:r];}}];
}
- (void)tick:(NSTimer*)timer{(void)timer;if(_session)[self call:@"voice.state"parameters:@{@"sessionId":_session}];}
- (void)beginInConversation:(NSString*)conversation model:(NSString*)model effort:(NSString*)effort{
 _closing=NO;self.view.accessibilityIdentifier=@"chat.voice";self.state=RCVoiceReconnecting;
 if(_session&&[_snapshot[@"canResume"]boolValue])[self call:@"voice.resume"parameters:@{@"sessionId":_session,@"operationId":OR6ChatUUID()}];
 else{[_session release];_session=nil;[_snapshot release];_snapshot=nil;_lines=0;[self clearTranscript];[self call:@"voice.start"parameters:@{@"operationId":OR6ChatUUID(),@"conversationId":conversation?:(id)NSNull.null,@"voiceId":NSNull.null,@"modelId":model?:@"web-current",@"thinkingEffort":effort?:(id)NSNull.null}];}
 [_poll invalidate];[_poll release];_poll=[[NSTimer timerWithTimeInterval:.35 target:self selector:@selector(tick:)userInfo:nil repeats:YES]retain];[NSRunLoop.mainRunLoop addTimer:_poll forMode:NSRunLoopCommonModes];
}
- (void)voiceDidTapOrb:(RCVoiceViewController*)voice{
 (void)voice;if(!_session)return;NSString*op=[_snapshot[@"state"]isEqual:@"listening"]?@"voice.submit":[_snapshot[@"state"]isEqual:@"speaking"]?@"voice.interrupt":[_snapshot[@"canResume"]boolValue]?@"voice.resume":nil;
 if(op){NSMutableDictionary*p=[NSMutableDictionary dictionaryWithObject:_session forKey:@"sessionId"];if([op isEqual:@"voice.resume"])p[@"operationId"]=OR6ChatUUID();[self call:op parameters:p];}
}
- (void)voice:(RCVoiceViewController*)voice didChangeMuted:(BOOL)muted{(void)voice;if(_session)[self call:@"voice.mute"parameters:@{@"sessionId":_session,@"microphoneMuted":muted?@YES:@NO,@"outputMuted":self.soundOff?@YES:@NO}];}
- (void)voice:(RCVoiceViewController*)voice didChangeSoundOff:(BOOL)off{(void)voice;if(_session)[self call:@"voice.mute"parameters:@{@"sessionId":_session,@"microphoneMuted":self.muted?@YES:@NO,@"outputMuted":off?@YES:@NO}];}
- (void)voiceDidEnd:(RCVoiceViewController*)voice{
 (void)voice;if(_session)[self call:@"voice.end"parameters:@{@"sessionId":_session}];[_poll invalidate];[_poll release];_poll=nil;_closing=YES;
 NSString*cid=[_snapshot[@"conversationId"]isKindOfClass:NSString.class]?_snapshot[@"conversationId"]:nil;[_host voice8:self endedInConversation:cid];
}
- (void)ownerChanged:(NSNotification*)note{(void)note;[self invalidate];}
- (void)invalidate{if(_session)[_core perform:@"voice.end"parameters:@{@"sessionId":_session}event:nil completion:^(NSDictionary*r,NSError*e){(void)r;(void)e;}];_closing=YES;[_poll invalidate];[_poll release];_poll=nil;[_session release];_session=nil;[_snapshot release];_snapshot=nil;_lines=0;[self clearTranscript];self.state=RCVoiceError;self.noticeText=OR6L(@"Voice ended because the account changed.");}
- (NSDictionary*)diagnostics{return@{@"open":_closing?@NO:@YES,@"state":_snapshot[@"state"]?:@"idle",@"lines":@(_lines),@"muted":self.muted?@YES:@NO,@"soundOff":self.soundOff?@YES:@NO};}
- (void)dealloc{[NSNotificationCenter.defaultCenter removeObserver:self];_host=nil;[self invalidate];self.delegate=nil;[_core release];[super dealloc];}
@end
