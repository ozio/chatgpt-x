#import "OR6RealtimeRuntime.h"
#import "OR6VoicePeer.h"
#import "OR6VoiceAudio.h"
#import <dispatch/dispatch.h>
@interface OR6RealtimeRuntime(){dispatch_queue_t _queue;OR6VoicePeer*_peer;OR6VoiceAudio*_audio;uint32_t _stopped;BOOL _quiescent,_ready,_mic,_output,_speech;NSTimeInterval _started,_nextAudio,_lastSpeech;void(^_event)(NSDictionary*);void(^_failure)(NSString*);void(^_opened)(void);NSDictionary*_stats;}
- (void)received:(NSData*)data;
- (void)decoded:(const int16_t*)pcm count:(NSUInteger)count;
- (void)pump;
@end
static void Audio(const int16_t*p,size_t n,void*u){[(OR6RealtimeRuntime*)u decoded:p count:n];}
static void Event(const char*p,size_t n,void*u){NSAutoreleasePool*pool=[NSAutoreleasePool new];[(OR6RealtimeRuntime*)u received:[NSData dataWithBytes:p length:n]];[pool drain];}
@implementation OR6RealtimeRuntime
- (BOOL)stopped{return __atomic_load_n(&_stopped,__ATOMIC_ACQUIRE);}
- (id)init{if((self=[super init])){_queue=dispatch_queue_create("io.ozio.chatgptx.voice.realtime",DISPATCH_QUEUE_SERIAL);_audio=[OR6VoiceAudio new];_quiescent=YES;}return self;}
- (void)offer:(void(^)(NSString*,NSError*))reply{
 @synchronized(self){if(!_quiescent||[self stopped]){reply(nil,[NSError errorWithDomain:@"io.ozio.chatgptx.voice"code:1 userInfo:nil]);return;}_quiescent=NO;}
 dispatch_async(_queue,^{NSAutoreleasePool*pool=[NSAutoreleasePool new];char sdp[8192]={0};@synchronized(self){if(![self stopped])_peer=OR6VoicePeerCreateService(Audio,Event,self);}BOOL ok=_peer&&OR6VoicePeerOffer(_peer,sdp,sizeof(sdp));NSString*s=ok?[NSString stringWithUTF8String:sdp]:nil;dispatch_async(dispatch_get_main_queue(),^{if(![self stopped])reply(s,ok?nil:[NSError errorWithDomain:@"io.ozio.chatgptx.voice"code:1 userInfo:nil]);});if(!ok||[self stopped])[self retire];[pool drain];});
}
- (void)connect:(NSString*)answer event:(void(^)(NSDictionary*))event ready:(void(^)(void))ready failure:(void(^)(NSString*))failure{
 _event=[event copy];_failure=[failure copy];_opened=[ready copy];
 dispatch_async(_queue,^{NSAutoreleasePool*pool=[NSAutoreleasePool new];if([self stopped]||!OR6VoicePeerAnswer(_peer,answer.UTF8String,[answer lengthOfBytesUsingEncoding:NSUTF8StringEncoding])){[self fail:@"unknown_wire_shape"];}else{_started=NSProcessInfo.processInfo.systemUptime;_nextAudio=_started;[self pump];}[pool drain];});
}
- (void)fail:(NSString*)code{dispatch_async(dispatch_get_main_queue(),^{if(![self stopped]&&_failure)_failure(code);});[self retire];}
- (void)retire{ @synchronized(self){if(_peer){OR6VoicePeerDestroy(_peer);_peer=NULL;}NSMutableDictionary*s=[NSMutableDictionary dictionaryWithDictionary:_stats?:@{}];s[@"connected"]=@NO;s[@"channelOpen"]=@NO;[_stats release];_stats=[s copy];_quiescent=YES;} }
- (void)pump{
 NSAutoreleasePool*pool=[NSAutoreleasePool new];if([self stopped]){[self retire];[pool drain];return;}
 if(!OR6VoicePeerTick(_peer)){[self fail:@"network_unavailable"];[pool drain];return;}
 OR6VoicePeerStats s=OR6VoicePeerGetStats(_peer);NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;
 if(_ready&&!s.channelOpen){[self fail:@"network_unavailable"];[pool drain];return;}
 BOOL speaking=_lastSpeech>0&&now-_lastSpeech<.45;if(speaking!=_speech){_speech=speaking;dispatch_async(dispatch_get_main_queue(),^{if(![self stopped]&&_event)_event(@{@"type":@"or6_audio_activity",@"payload":@{@"active":@(speaking)}});});}
 if(now-_started>1200||(!_ready&&now-_started>20)){[self fail:@"timeout"];[pool drain];return;}
 if(s.channelOpen&&!_ready){_ready=YES;dispatch_async(dispatch_get_main_queue(),^{if([self stopped])return;NSError*e=nil;if(![_audio startCapture:&e]){if(_failure)_failure(@"unavailable");[self stop];return;}[_audio setMicrophoneMuted:_mic outputMuted:_output];if(_opened)_opened();});}
 if(s.transportConnected&&now>=_nextAudio){int16_t pcm[960]={0};[_audio readMicrophone:pcm frames:960];OR6VoicePeerSendPCM(_peer,pcm,960);_nextAudio+=.02;if(now-_nextAudio>.06)_nextAudio=now+.02;}
 uint32_t consentRequests=0,consentResponses=0,consentAge=0;OR6VoicePeerConsent(_peer,&consentRequests,&consentResponses,&consentAge);
 NSDictionary*stats=@{@"consentRequests":@(consentRequests),@"consentResponses":@(consentResponses),@"consentAgeMS":@(consentAge),@"connected":@(s.transportConnected),@"channelOpen":@(s.channelOpen),@"sentFrames":@(s.sentFrames),@"receivedFrames":@(s.receivedFrames),@"receivedPackets":@(s.receivedPackets),@"receivedEvents":@(s.receivedEvents),@"sentEvents":@(s.sentEvents),@"failed":@(s.failed)};@synchronized(self){[_stats release];_stats=[stats copy];}
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_MSEC),_queue,^{[self pump];});[pool drain];
}
- (void)decoded:(const int16_t*)pcm count:(NSUInteger)n{if(![self stopped]){uint64_t sum=0;for(NSUInteger i=0;i<n;i++)sum+=(uint64_t)abs(pcm[i]);if(n&&sum/n>70)_lastSpeech=NSProcessInfo.processInfo.systemUptime;[_audio enqueueOutput:pcm frames:n];}}
- (void)received:(NSData*)data{
 id outer=[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];if(![outer isKindOfClass:NSDictionary.class])return;
 if([outer[@"type"]isEqual:@"error"]){dispatch_async(dispatch_get_main_queue(),^{if(![self stopped]&&_event)_event(@{@"type":@"error",@"payload":outer});});return;}
 if(![outer[@"type"]isEqual:@"data_message"]||![outer[@"data"]isKindOfClass:NSString.class])return;NSData*inner=[outer[@"data"]dataUsingEncoding:NSUTF8StringEncoding];if(inner.length>16384)return;id e=[NSJSONSerialization JSONObjectWithData:inner options:0 error:NULL];if(![e isKindOfClass:NSDictionary.class]||![e[@"type"]isKindOfClass:NSString.class])return;if(![e[@"payload"]isKindOfClass:NSDictionary.class]){if(![e[@"type"]isEqual:@"error"])return;e=@{@"type":@"error",@"payload":e};}
 dispatch_async(dispatch_get_main_queue(),^{if(![self stopped]&&_event)_event(e);});
}
- (void)send:(NSDictionary*)event{if(!NSThread.isMainThread||[self stopped])return;NSData*inner=[NSJSONSerialization dataWithJSONObject:event options:0 error:NULL];if(!inner||inner.length>8192)return;NSString*s=[[[NSString alloc]initWithData:inner encoding:NSUTF8StringEncoding]autorelease];NSData*outer=[NSJSONSerialization dataWithJSONObject:@{@"type":@"data_message",@"data":s}options:0 error:NULL];dispatch_async(_queue,^{if(![self stopped])OR6VoicePeerSendEvent(_peer,outer.bytes,outer.length);});}
- (void)setMicrophoneMuted:(BOOL)mic outputMuted:(BOOL)output{_mic=mic;_output=output;[_audio setMicrophoneMuted:mic outputMuted:output];@synchronized(self){if(_peer)OR6VoicePeerMute(_peer,mic,output);}}
- (void)flushOutput{[_audio flushOutput];}
- (void)stop{[_event release];_event=nil;[_failure release];_failure=nil;[_opened release];_opened=nil;@synchronized(self){__atomic_store_n(&_stopped,1,__ATOMIC_RELEASE);if(_peer)OR6VoicePeerCancel(_peer);}[_audio stop];dispatch_async(_queue,^{[self retire];});}
- (BOOL)isQuiescent{@synchronized(self){return _quiescent;}}
- (NSDictionary*)diagnostics{@synchronized(self){NSMutableDictionary*d=[NSMutableDictionary dictionaryWithDictionary:_stats?:@{}];d[@"audio"]=_audio.diagnostics;d[@"quiescent"]=@(_quiescent);return d;}}
- (void)dealloc{[_event release];[_failure release];[_opened release];[_stats release];[_audio release];dispatch_release(_queue);[super dealloc];}
@end
