#import "OR6ChatCodexPairUI.h"
#import "../../ui/RCScannerViewController.h"
#import "../../ui/RCTheme.h"
#import "../../ui/RCHUD.h"
#import "../../localization/OR6Localization.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>
#import <QuartzCore/QuartzCore.h>
#import <dispatch/dispatch.h>
#include "qr/quirc.h"

@interface OR6CodexCameraView:UIView {AVCaptureVideoPreviewLayer *_preview;}
- (id)initWithSession:(AVCaptureSession *)session;
@end
@implementation OR6CodexCameraView
- (id)initWithSession:(AVCaptureSession *)session{if((self=[super initWithFrame:CGRectZero])){_preview=[[AVCaptureVideoPreviewLayer alloc]initWithSession:session];_preview.videoGravity=AVLayerVideoGravityResizeAspectFill;if(_preview.connection.isVideoOrientationSupported)_preview.connection.videoOrientation=AVCaptureVideoOrientationPortrait;[self.layer addSublayer:_preview];}return self;}
- (void)layoutSubviews{[super layoutSubviews];_preview.frame=self.bounds;}
- (void)dealloc{[_preview release];[super dealloc];}
@end
@interface OR6CodexQRScanner:RCScannerViewController<AVCaptureVideoDataOutputSampleBufferDelegate,RCScannerViewControllerDelegate>{
    AVCaptureSession *_capture;AVCaptureVideoDataOutput *_output;NSMutableData *_gray;dispatch_queue_t _queue;
    struct quirc *_decoder;void(^_done)(NSString *);BOOL _closed,_warned;CFTimeInterval _lastFrame;size_t _decoderWidth,_decoderHeight;
}
- (id)initWithCompletion:(void(^)(NSString *))done;
- (void)finish:(NSString *)code;
@end
@implementation OR6CodexQRScanner
- (id)initWithCompletion:(void(^)(NSString *))done{if((self=[super initWithNibName:nil bundle:nil])){self.readingCode=YES;self.delegate=self;_done=[done copy];_queue=dispatch_queue_create("io.ozio.chatgptx.codex.qr",DISPATCH_QUEUE_SERIAL);[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(background:)name:UIApplicationDidEnterBackgroundNotification object:nil];}return self;}
- (void)viewDidLoad{
    [super viewDidLoad];OR6ChatCodexPairQRReset();self.view.accessibilityIdentifier=@"chat.codex.pair.scanner";
    _capture=[AVCaptureSession new];_capture.sessionPreset=[_capture canSetSessionPreset:AVCaptureSessionPreset1280x720]?AVCaptureSessionPreset1280x720:AVCaptureSessionPreset640x480;
    NSError *error=nil;AVCaptureDevice *camera=[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];AVCaptureDeviceInput *input=camera?[AVCaptureDeviceInput deviceInputWithDevice:camera error:&error]:nil;
    _output=[AVCaptureVideoDataOutput new];_output.alwaysDiscardsLateVideoFrames=YES;_output.videoSettings=@{(id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA)};
    if(camera&&[camera lockForConfiguration:&error]){if([camera isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus])camera.focusMode=AVCaptureFocusModeContinuousAutoFocus;if([camera isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure])camera.exposureMode=AVCaptureExposureModeContinuousAutoExposure;[camera unlockForConfiguration];}
    if(!input||error||![_capture canAddInput:input]||![_capture canAddOutput:_output]){[RCHUD showText:OR6L(@"The camera is unavailable. Enter the connection code instead.")kind:RCHUDTextOnly inView:self.view seconds:3];return;}
    [_capture addInput:input];[_capture addOutput:_output];self.previewView=[[[OR6CodexCameraView alloc]initWithSession:_capture]autorelease];
    [_output setSampleBufferDelegate:self queue:_queue];dispatch_async(_queue,^{@synchronized(self){if(_closed)return;}[_capture startRunning];});
}
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sample fromConnection:(AVCaptureConnection *)connection{
    (void)output;(void)connection;@synchronized(self){if(_closed)return;}
    CFTimeInterval now=CFAbsoluteTimeGetCurrent();if(now-_lastFrame<.4)return;_lastFrame=now;
    CVPixelBufferRef pixel=CMSampleBufferGetImageBuffer(sample);if(!pixel||CVPixelBufferGetPixelFormatType(pixel)!=kCVPixelFormatType_32BGRA)return;
    size_t w=CVPixelBufferGetWidth(pixel),h=CVPixelBufferGetHeight(pixel),stride=CVPixelBufferGetBytesPerRow(pixel);if(!w||!h||w>1280||h>1280||stride<w*4)return;
    if(!_decoder)_decoder=quirc_new();if(!_decoder)return;if(w!=_decoderWidth||h!=_decoderHeight){if(quirc_resize(_decoder,(int)w,(int)h))return;_decoderWidth=w;_decoderHeight=h;}
    if(CVPixelBufferLockBaseAddress(pixel,kCVPixelBufferLock_ReadOnly))return;
    const unsigned char *source=CVPixelBufferGetBaseAddress(pixel);if(_gray.length!=w*h){[_gray release];_gray=[[NSMutableData alloc]initWithLength:w*h];}unsigned char *target=_gray.mutableBytes;
    if(source&&target)for(size_t y=0;y<h;y++)for(size_t x=0;x<w;x++){const unsigned char *b=source+y*stride+x*4;target[y*w+x]=(unsigned char)((b[2]*77+b[1]*150+b[0]*29)>>8);}
    CVPixelBufferUnlockBaseAddress(pixel,kCVPixelBufferLock_ReadOnly);if(!source||!target)return;
    NSAutoreleasePool *pool=[NSAutoreleasePool new];
    NSString *value=OR6ChatCodexPairDecodeGray(_decoder,_gray.bytes,_gray.length);if(!value&&[OR6ChatCodexPairQRDiagnostics()[@"lastPayload"][@"accepted"]isEqual:@NO]){dispatch_async(dispatch_get_main_queue(),^{if(!_closed&&!_warned){_warned=YES;[RCHUD showText:OR6L(@"QR code recognized, but its connection format is unsupported.")kind:RCHUDTextOnly inView:self.view seconds:3];}});}if(value)dispatch_async(dispatch_get_main_queue(),^{[self finish:value];});[pool drain];
}
- (void)finish:(NSString *)code{
    @synchronized(self){if(_closed)return;_closed=YES;}
    dispatch_async(_queue,^{[_output setSampleBufferDelegate:nil queue:NULL];[_capture stopRunning];});
    void(^done)(NSString *)=[[_done copy]autorelease];[_done release];_done=nil;
    [self dismissViewControllerAnimated:YES completion:^{if(done)done(code);}];
}
- (void)background:(NSNotification *)n{(void)n;[self finish:nil];}
- (void)scannerDidCancel:(RCScannerViewController *)s{(void)s;[self finish:nil];}
- (void)scannerDidTapShutter:(RCScannerViewController *)s{(void)s;}
- (void)scannerDidSave:(RCScannerViewController *)s{(void)s;}
- (void)viewDidDisappear:(BOOL)a{[super viewDidDisappear:a];[self finish:nil];}
- (void)dealloc{[NSNotificationCenter.defaultCenter removeObserver:self];self.delegate=nil;[_capture release];[_output release];[_gray release];[_done release];if(_decoder)quirc_destroy(_decoder);if(_queue)dispatch_release(_queue);[super dealloc];}
@end
UIViewController *OR6ChatCodexPairScanner(void(^done)(NSString *)){
    OR6CodexQRScanner *s=[[[OR6CodexQRScanner alloc]initWithCompletion:done]autorelease];
    UINavigationController *nav=[[[UINavigationController alloc]initWithRootViewController:s]autorelease];[RCTheme styleNavigationBar:nav.navigationBar variant:RCBarVariantDark];return nav;
}
