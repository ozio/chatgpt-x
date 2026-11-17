#import <UIKit/UIKit.h>
#import "OR6WebLoginController.h"
@interface OR6WebRootController:UIViewController<OR6WebSessionDelegate,OR6WebLoginControllerDelegate>{
    OR6WebSession *_session;OR6WebLoginController *_login;NSDictionary *_lastLogin;
    UILabel *_heading,*_message,*_requirements;UIButton *_signIn,*_signOut,*_retry,*_renew;UIActivityIndicatorView *_spinner;
    NSTimer *_renewalTimer;BOOL _started,_active;NSUInteger _events,_signOuts,_cancellations;
}
- (id)initWithSession:(OR6WebSession *)session;
- (void)start;
- (void)activate;
- (void)deactivate;
- (void)writeReceipt;
@end
