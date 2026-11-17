#import "OR6VoiceAudio.h"
#import "OR6VoicePCM.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

typedef struct {
    AudioUnit unit;
    OR6VoicePCM input,output;
    uint32_t active,microphoneMuted,outputMuted,captureFrames,renderFrames,overflows;
    BOOL sessionActivated;
    int16_t capture[4096];
} OR6VoiceAudioIO;
@interface OR6VoiceAudio(){OR6VoiceAudioIO*_io;}
@end
static OSStatus Capture(void*context,AudioUnitRenderActionFlags*flags,const AudioTimeStamp*time,UInt32 bus,UInt32 frames,AudioBufferList*unused) {
    (void)bus;(void)unused;OR6VoiceAudioIO*io=context;
    if(!__atomic_load_n(&io->active,__ATOMIC_ACQUIRE)||frames>4096)return noErr;
    AudioBufferList buffers={.mNumberBuffers=1,.mBuffers={{.mNumberChannels=1,.mDataByteSize=frames*2,.mData=io->capture}}};
    OSStatus result=AudioUnitRender(io->unit,flags,time,1,frames,&buffers);
    if(!result&&!__atomic_load_n(&io->microphoneMuted,__ATOMIC_ACQUIRE)){__atomic_fetch_add(&io->captureFrames,frames,__ATOMIC_RELAXED);if(OR6VoicePCMWrite(&io->input,io->capture,frames)!=frames)__atomic_fetch_add(&io->overflows,1,__ATOMIC_RELAXED);}
    return result;
}
static OSStatus Render(void*context,AudioUnitRenderActionFlags*flags,const AudioTimeStamp*time,UInt32 bus,UInt32 frames,AudioBufferList*buffers) {
    (void)flags;(void)time;(void)bus;OR6VoiceAudioIO*io=context;
    if(!buffers||frames>4096||buffers->mNumberBuffers!=1)return kAudio_ParamError;
    for(UInt32 i=0;i<buffers->mNumberBuffers;i++) {
        AudioBuffer*b=&buffers->mBuffers[i];
        if(!b->mData||b->mDataByteSize<frames*2||b->mNumberChannels!=1)return kAudio_ParamError;
        memset(b->mData,0,frames*2);
    }
    if(!__atomic_load_n(&io->active,__ATOMIC_ACQUIRE)||__atomic_load_n(&io->outputMuted,__ATOMIC_ACQUIRE)) {
        OR6VoicePCMFlush(&io->output);int16_t discard;OR6VoicePCMRead(&io->output,&discard,1);return noErr;
    }
    NSUInteger read=OR6VoicePCMRead(&io->output,buffers->mBuffers[0].mData,frames);__atomic_fetch_add(&io->renderFrames,read,__ATOMIC_RELAXED);return noErr;
}
static NSError*AudioError(void){return[NSError errorWithDomain:@"io.ozio.chatgptx.voice.audio"code:1 userInfo:@{NSLocalizedDescriptionKey:@"Audio setup failed"}];}
@implementation OR6VoiceAudio
- (id)init {
    if((self=[super init])) {
        _io=calloc(1,sizeof(*_io));if(!_io){[self release];return nil;}
        OR6VoicePCMInit(&_io->input);OR6VoicePCMInit(&_io->output);
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(interrupted:)name:AVAudioSessionInterruptionNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(interrupted:)name:UIApplicationDidEnterBackgroundNotification object:nil];
    }return self;
}
- (void)interrupted:(NSNotification*)notification {
    if([notification.name isEqual:AVAudioSessionInterruptionNotification]&&[notification.userInfo[AVAudioSessionInterruptionTypeKey]unsignedIntegerValue]!=AVAudioSessionInterruptionTypeBegan)return;
    [self stop];
}
- (BOOL)startCapture:(NSError**)error {
    if(!NSThread.isMainThread||self.isActive){if(error)*error=AudioError();return NO;}
    AVAudioSession*session=AVAudioSession.sharedInstance;
    if(![session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:NULL]||![session setMode:AVAudioSessionModeVoiceChat error:NULL]||
       ![session setPreferredSampleRate:48000 error:NULL]||![session setPreferredIOBufferDuration:.02 error:NULL]||![session setActive:YES error:NULL])goto fail;
    _io->sessionActivated=YES;
    AudioComponentDescription description={kAudioUnitType_Output,kAudioUnitSubType_VoiceProcessingIO,kAudioUnitManufacturer_Apple,0,0};
    AudioComponent component=AudioComponentFindNext(NULL,&description);
    if(!component||AudioComponentInstanceNew(component,&_io->unit))goto fail;
    UInt32 on=1,off=0,maximum=4096;
    AudioStreamBasicDescription format={48000,kAudioFormatLinearPCM,kAudioFormatFlagIsSignedInteger|kAudioFormatFlagIsPacked,2,1,2,1,16,0};
    AURenderCallbackStruct capture={Capture,_io},render={Render,_io};
    if(AudioUnitSetProperty(_io->unit,kAUVoiceIOProperty_BypassVoiceProcessing,kAudioUnitScope_Global,0,&off,sizeof(off))||
       AudioUnitSetProperty(_io->unit,kAUVoiceIOProperty_VoiceProcessingEnableAGC,kAudioUnitScope_Global,0,&on,sizeof(on))||
       AudioUnitSetProperty(_io->unit,kAudioOutputUnitProperty_EnableIO,kAudioUnitScope_Input,1,&on,sizeof(on))||
       AudioUnitSetProperty(_io->unit,kAudioUnitProperty_MaximumFramesPerSlice,kAudioUnitScope_Global,0,&maximum,sizeof(maximum))||
       AudioUnitSetProperty(_io->unit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Output,1,&format,sizeof(format))||
       AudioUnitSetProperty(_io->unit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Input,0,&format,sizeof(format))||
       AudioUnitSetProperty(_io->unit,kAudioOutputUnitProperty_SetInputCallback,kAudioUnitScope_Global,1,&capture,sizeof(capture))||
       AudioUnitSetProperty(_io->unit,kAudioUnitProperty_SetRenderCallback,kAudioUnitScope_Input,0,&render,sizeof(render))||AudioUnitInitialize(_io->unit))goto fail;
    __atomic_store_n(&_io->active,1,__ATOMIC_RELEASE);
    if(AudioOutputUnitStart(_io->unit))goto fail;
    return YES;
fail:
    [self stop];if(error)*error=AudioError();return NO;
}
- (BOOL)isActive{return _io&&__atomic_load_n(&_io->active,__ATOMIC_ACQUIRE);}
- (void)stop {
    if(!_io)return;__atomic_store_n(&_io->active,0,__ATOMIC_RELEASE);
    if(_io->unit){AudioOutputUnitStop(_io->unit);AudioUnitUninitialize(_io->unit);AudioComponentInstanceDispose(_io->unit);_io->unit=NULL;}
    /* Consumers flush their own cursors; the worker may still be unwinding. */
    OR6VoicePCMFlush(&_io->input);OR6VoicePCMFlush(&_io->output);
    if(_io->sessionActivated){[AVAudioSession.sharedInstance setActive:NO error:NULL];_io->sessionActivated=NO;}
}
- (void)setMicrophoneMuted:(BOOL)mic outputMuted:(BOOL)output {
    __atomic_store_n(&_io->microphoneMuted,!!mic,__ATOMIC_RELEASE);__atomic_store_n(&_io->outputMuted,!!output,__ATOMIC_RELEASE);
    if(mic)OR6VoicePCMFlush(&_io->input);if(output)OR6VoicePCMFlush(&_io->output);
}
- (NSUInteger)readMicrophone:(int16_t*)samples frames:(NSUInteger)frames {
    if(!self.isActive||__atomic_load_n(&_io->microphoneMuted,__ATOMIC_ACQUIRE))return 0;
    return OR6VoicePCMRead(&_io->input,samples,frames);
}
- (BOOL)enqueueOutput:(const int16_t*)samples frames:(NSUInteger)frames {
    if(!self.isActive||__atomic_load_n(&_io->outputMuted,__ATOMIC_ACQUIRE))return NO;
    return OR6VoicePCMWrite(&_io->output,samples,frames)==frames;
}
- (void)flushOutput{OR6VoicePCMFlush(&_io->output);}
- (NSDictionary*)diagnostics{return@{@"active":@(self.isActive),@"voiceProcessing":@YES,@"captureFrames":@(__atomic_load_n(&_io->captureFrames,__ATOMIC_RELAXED)),@"renderFrames":@(__atomic_load_n(&_io->renderFrames,__ATOMIC_RELAXED)),@"overflows":@(__atomic_load_n(&_io->overflows,__ATOMIC_RELAXED)),@"sampleRate":@([(AVAudioSession*)[AVAudioSession sharedInstance]sampleRate])};}
- (void)dealloc{[NSNotificationCenter.defaultCenter removeObserver:self];[self stop];free(_io);[super dealloc];}
@end
