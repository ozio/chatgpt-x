#import "OR6API7HCapture.h"
#import <TargetConditionals.h>
#import <dispatch/dispatch.h>
#if TARGET_OS_IPHONE
#import <AudioToolbox/AudioToolbox.h>
@interface OR6API7HAudioQueueCapture(){AudioQueueRef _queue;BOOL _running,_stopping,_finished,_sessionActive;BOOL(^_consumer)(NSData*);void(^_completion)(NSError*);NSUInteger _bytes;}
- (void)finish:(NSError *)error;
- (void)input:(AudioQueueBufferRef)buffer queue:(AudioQueueRef)queue;
@end
static void Input(void*opaque,AudioQueueRef queue,AudioQueueBufferRef buffer,const AudioTimeStamp*time,UInt32 packets,const AudioStreamPacketDescription*descriptions){(void)time;(void)packets;(void)descriptions;NSAutoreleasePool*pool=[NSAutoreleasePool new];[(OR6API7HAudioQueueCapture*)opaque input:buffer queue:queue];[pool drain];}
static void Running(void*opaque,AudioQueueRef queue,AudioQueuePropertyID property){(void)property;UInt32 running=0,size=sizeof(running);if(AudioQueueGetProperty(queue,kAudioQueueProperty_IsRunning,&running,&size)==noErr&&!running){OR6API7HAudioQueueCapture*source=(OR6API7HAudioQueueCapture*)opaque;dispatch_async(dispatch_get_main_queue(),^{[source finish:nil];});}}
@implementation OR6API7HAudioQueueCapture
- (BOOL)startPCM:(BOOL(^)(NSData*))consumer finished:(void(^)(NSError*))finished error:(NSError**)error{
 if(!NSThread.isMainThread||!consumer||!finished||_queue){if(error)*error=OR6APIError(@"invalid_request",@"none");return NO;}_finished=NO;_stopping=NO;_bytes=0;_consumer=[consumer copy];_completion=[finished copy];AudioStreamBasicDescription format;memset(&format,0,sizeof(format));format.mSampleRate=16000;format.mFormatID=kAudioFormatLinearPCM;format.mFormatFlags=kLinearPCMFormatFlagIsSignedInteger|kLinearPCMFormatFlagIsPacked;format.mBytesPerPacket=2;format.mFramesPerPacket=1;format.mBytesPerFrame=2;format.mChannelsPerFrame=1;format.mBitsPerChannel=16;
 UInt32 category=kAudioSessionCategory_RecordAudio;OSStatus status=AudioSessionInitialize(NULL,NULL,NULL,NULL);if(status==kAudioSessionAlreadyInitialized)status=noErr;if(status==noErr)status=AudioSessionSetProperty(kAudioSessionProperty_AudioCategory,sizeof(category),&category);if(status==noErr){status=AudioSessionSetActive(true);_sessionActive=status==noErr;}if(status==noErr)status=AudioQueueNewInput(&format,Input,self,NULL,NULL,0,&_queue);if(status==noErr)status=AudioQueueAddPropertyListener(_queue,kAudioQueueProperty_IsRunning,Running,self);
 for(NSUInteger i=0;i<3&&status==noErr;i++){AudioQueueBufferRef b=NULL;status=AudioQueueAllocateBuffer(_queue,3200,&b);if(status==noErr)status=AudioQueueEnqueueBuffer(_queue,b,0,NULL);}
 if(status==noErr){@synchronized(self){_running=YES;}status=AudioQueueStart(_queue,NULL);}if(status!=noErr){if(error)*error=OR6APIError(@"capability_unavailable",@"none");[_completion release];_completion=nil;[self finish:nil];return NO;}return YES;
}
- (void)input:(AudioQueueBufferRef)b queue:(AudioQueueRef)queue{
 BOOL(^consumer)(NSData*)=nil;BOOL keep=NO;NSUInteger size=0;@synchronized(self){if(!_running||queue!=_queue)return;consumer=[_consumer copy];size=MIN((NSUInteger)b->mAudioDataByteSize,(NSUInteger)3200);if(size%2){[consumer release];dispatch_async(dispatch_get_main_queue(),^{[self finish:OR6APIError(@"upstream_error",@"none")];});return;}if(_bytes>=1920000)size=0;else size=MIN(size,1920000-_bytes);_bytes+=size;keep=!_stopping&&_bytes<1920000;}
 BOOL accepted=!size||consumer([NSData dataWithBytes:b->mAudioData length:size]);[consumer release];if(!accepted){dispatch_async(dispatch_get_main_queue(),^{[self finish:OR6APIError(@"size_limit",@"none")];});return;}
 if(keep){if(AudioQueueEnqueueBuffer(queue,b,0,NULL)!=noErr)dispatch_async(dispatch_get_main_queue(),^{[self finish:OR6APIError(@"upstream_error",@"none")];});}else dispatch_async(dispatch_get_main_queue(),^{[self stop];});
}
- (void)stop{if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self stop];});return;}AudioQueueRef q=NULL;@synchronized(self){if(_finished||_stopping)return;_stopping=YES;q=_queue;}if(!q){[self finish:nil];return;}if(AudioQueueStop(q,false)!=noErr)[self finish:OR6APIError(@"upstream_error",@"none")];}
- (void)cancel{if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self cancel];});return;}[self finish:nil];}
- (void)finish:(NSError*)error{
 if(_finished)return;_finished=YES;AudioQueueRef q=NULL;void(^completion)(NSError*)=nil;@synchronized(self){_running=NO;_stopping=YES;q=_queue;_queue=NULL;completion=[_completion copy];[_completion release];_completion=nil;[_consumer release];_consumer=nil;}if(q){AudioQueueRemovePropertyListener(q,kAudioQueueProperty_IsRunning,Running,self);AudioQueueStop(q,true);AudioQueueDispose(q,true);}if(_sessionActive){AudioSessionSetActive(false);_sessionActive=NO;}if(completion){completion(error);[completion release];}
}
- (void)dealloc{[self finish:nil];[super dealloc];}
@end
#else
@implementation OR6API7HAudioQueueCapture
- (BOOL)startPCM:(BOOL(^)(NSData*))consumer finished:(void(^)(NSError*))finished error:(NSError**)error{(void)consumer;(void)finished;if(error)*error=OR6APIError(@"capability_unavailable",@"none");return NO;}
- (void)stop{}- (void)cancel{}
@end
#endif
