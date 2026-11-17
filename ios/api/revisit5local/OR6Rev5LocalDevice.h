#import "OR6Rev5Local.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
// App-owned native adapters. No access prompt runs during construction or bind.
// A presenter is required only by explicit camera capture. AVPlayer is private
// host state for a future kit media surface, never a public URL or JSON object.
@interface OR6Rev5LocalDevice:NSObject<OR6Rev5LocalPlatform,UIImagePickerControllerDelegate,UINavigationControllerDelegate>
- (void)setPresenter:(UIViewController *)presenter; // non-retaining; clear before teardown
- (AVPlayer *)videoPlayer;
@end
