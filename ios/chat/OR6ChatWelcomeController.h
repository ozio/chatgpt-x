#import <UIKit/UIKit.h>
#import "RCWelcomeViewController.h"
@class OR6ChatWelcomeController;
@protocol OR6ChatWelcomeDelegate <NSObject>
- (void)welcomeDidRequestSignIn:(OR6ChatWelcomeController *)controller;
@end
// Launch / signed-out screen (the kit's RCWelcomeViewController): restoring the
// saved session, or «Войти» with the service page in the kit's web frame.
@interface OR6ChatWelcomeController : RCWelcomeViewController
@property (nonatomic, assign) id<OR6ChatWelcomeDelegate> chatDelegate;
- (void)applySessionSummary:(NSDictionary *)summary notice:(NSString *)notice;
@end
