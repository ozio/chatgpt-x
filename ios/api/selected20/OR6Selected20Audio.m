#import "OR6Selected20Audio.h"
#import "../OR6APICore.h"
#import <AudioToolbox/AudioToolbox.h>
BOOL OR6Selected20DecodeAudio(NSURL *input,NSURL *output,BOOL(^cancelled)(void),NSError **error){
 ExtAudioFileRef source=NULL,dest=NULL;BOOL ok=NO;NSString *code=@"unsupported_media";
 AudioStreamBasicDescription format={0};format.mSampleRate=16000;format.mFormatID=kAudioFormatLinearPCM;format.mFormatFlags=kLinearPCMFormatFlagIsSignedInteger|kAudioFormatFlagIsPacked;format.mBytesPerPacket=2;format.mFramesPerPacket=1;format.mBytesPerFrame=2;format.mChannelsPerFrame=1;format.mBitsPerChannel=16;
 if(!input.isFileURL||!output.isFileURL||[input.path isEqual:output.path])goto done;
 if(ExtAudioFileOpenURL((CFURLRef)input,&source)!=noErr)goto done;
 if(ExtAudioFileSetProperty(source,kExtAudioFileProperty_ClientDataFormat,sizeof(format),&format)!=noErr)goto done;
 if(ExtAudioFileCreateWithURL((CFURLRef)output,kAudioFileWAVEType,&format,NULL,kAudioFileFlags_EraseFile,&dest)!=noErr){code=@"storage_failure";goto done;}
 if(ExtAudioFileSetProperty(dest,kExtAudioFileProperty_ClientDataFormat,sizeof(format),&format)!=noErr)goto done;
 {unsigned long total=0;SInt16 pcm[4096];for(;;){if(cancelled&&cancelled()){code=@"cancelled";goto done;}UInt32 frames=4096;AudioBufferList buffers={0};buffers.mNumberBuffers=1;buffers.mBuffers[0].mNumberChannels=1;buffers.mBuffers[0].mDataByteSize=sizeof(pcm);buffers.mBuffers[0].mData=pcm;if(ExtAudioFileRead(source,&frames,&buffers)!=noErr)goto done;if(!frames){ok=total>0;break;}total+=frames;if(total>180*16000){code=@"size_limit";goto done;}if(ExtAudioFileWrite(dest,frames,&buffers)!=noErr){code=@"storage_failure";goto done;}}}
 done:if(source)ExtAudioFileDispose(source);if(dest&&ExtAudioFileDispose(dest)!=noErr){ok=NO;code=@"storage_failure";}if(!ok){[NSFileManager.defaultManager removeItemAtURL:output error:NULL];if(error)*error=OR6APIError(code,@"none");}return ok;
}
