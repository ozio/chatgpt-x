// RCWelcomeViewController — first launch / signed-out screen (app.css .welcome):
// dark linen, the bare white embossed brand mark, «ChatGPT X», large green
// «Войти» (and dark «Создать аккаунт» when available) and a short footnote
// (by default: an unofficial app, not affiliated with OpenAI).
// States: idle; checking (spinner + status, buttons hidden: restoring a saved
// login); error (amber/red lamp + text above the buttons); signed out (note).
#import <UIKit/UIKit.h>

typedef enum {
    RCWelcomeIdle = 0,
    RCWelcomeChecking,   // «Проверяю сохранённый вход…»
    RCWelcomeError,      // statusText in the error line, buttons stay
    RCWelcomeSignedOut   // «Вы вышли…» note, buttons stay
} RCWelcomeState;

@class RCWelcomeViewController;
@protocol RCWelcomeViewControllerDelegate <NSObject>
- (void)welcomeDidTapSignIn:(RCWelcomeViewController *)welcome;
@optional
- (void)welcomeDidTapSignUp:(RCWelcomeViewController *)welcome;
@end

@interface RCWelcomeViewController : UIViewController
@property (nonatomic, assign) RCWelcomeState state;
@property (nonatomic, copy) NSString *statusText;    // nil: the default text of the state
@property (nonatomic, copy) NSString *appTitle;      // «ChatGPT X»
@property (nonatomic, copy) NSString *message;       // optional line under the title (nil: none)
@property (nonatomic, copy) NSString *footnote;      // bottom note
@property (nonatomic, assign) BOOL signUpAvailable;  // «Создать аккаунт» (stage 7)
@property (nonatomic, assign) id<RCWelcomeViewControllerDelegate> delegate;
- (void)setState:(RCWelcomeState)state text:(NSString *)text;
+ (UIImage *)logoImage; // 108×110 canvas: bare white embossed mark (104 pt, centre 54,52)
+ (CGFloat)logoTopForHeight:(CGFloat)height; // logo top in a view of this height (RCLaunchView rises to it)
@end
