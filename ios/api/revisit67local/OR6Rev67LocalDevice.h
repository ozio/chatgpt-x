#import "OR6Rev67Local.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreLocation/CoreLocation.h>
// Public iOS6 hardware only, explicit requests only. No location caching or upload.
@interface OR6Rev67LocalDevice:NSObject<OR6Rev67LocalPlatform,CLLocationManagerDelegate>
// Optional trusted scanner viewfinder. Owns no UIKit screen; preview lifetime is capture only.
- (AVCaptureSession *)captureSession;
@end
