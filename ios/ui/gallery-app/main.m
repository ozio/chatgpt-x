// ChatGPTXKit: development host for the ChatGPT X component gallery. Offline only.
#import <UIKit/UIKit.h>
#import "RCGallery.h"

@interface ChatGPTXKitApp : NSObject <UIApplicationDelegate> { UIWindow *_window; }
@end

@implementation ChatGPTXKitApp
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    _window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _window.rootViewController = RCGalleryCreateRootController();
    [_window makeKeyAndVisible];
    return YES;
}
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url sourceApplication:(NSString *)source annotation:(id)annotation {
    return [url.scheme isEqualToString:@"chatgptxkit"] && RCGalleryOpenURL(_window.rootViewController, url);
}
- (void)dealloc { [_window release]; [super dealloc]; }
@end

int main(int argc, char **argv) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    int r = UIApplicationMain(argc, argv, nil, NSStringFromClass([ChatGPTXKitApp class]));
    [pool drain];
    return r;
}
