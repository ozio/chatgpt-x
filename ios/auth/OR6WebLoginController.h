#import <UIKit/UIKit.h>
#import "OR6WebSession.h"
@class OR6WebLoginController;
@protocol OR6WebLoginControllerDelegate<NSObject>
- (void)loginControllerCancelled:(OR6WebLoginController *)controller;
@optional
// Main-document navigation for native chrome (host strip, load progress). Read-only.
- (void)loginController:(OR6WebLoginController *)controller didNavigateToURL:(NSURL *)url loading:(BOOL)loading;
@end
@interface OR6WebLoginController:UIViewController<UIWebViewDelegate>{
    OR6WebSession *_session;NSUInteger _generation;
    id<OR6WebLoginControllerDelegate> _delegate;
    UIWebView *_web;UIView *_cover;UILabel *_message;UIButton *_retry;
    UIActivityIndicatorView *_spinner;NSTimer *_timer;
    NSString *_nonce;NSDate *_probeStarted,*_lastAttempt;
    BOOL _onChatGPT,_completionRequested,_stopped,_googleSeen,_submitted;
    NSInteger _webStatus;NSUInteger _documentCount;
}
@property(nonatomic,assign)id<OR6WebLoginControllerDelegate> delegate;
- (id)initWithSession:(OR6WebSession *)session generation:(NSUInteger)generation;
- (void)sessionChanged;
- (void)stop;
- (NSDictionary *)diagnostics;
@end
