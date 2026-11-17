// RCWebFrameController — native chrome around the service's sign-in page (app.css
// .webview): jade navbar with «Отмена» and the title («Вход»), an address strip
// with a lamp, lock and the real host («auth.openai.com»), a thin jade load
// progress line, an optional error banner, and the caller's content view (the
// app's existing UIWebView / login view) filling the rest. No web code here.
#import <UIKit/UIKit.h>

@class RCWebFrameController;
@protocol RCWebFrameControllerDelegate <NSObject>
- (void)webFrameDidCancel:(RCWebFrameController *)frame;
@optional
- (void)webFrameDidTapErrorAction:(RCWebFrameController *)frame; // «Повторить»
@end

@interface RCWebFrameController : UIViewController
- (id)initWithContentView:(UIView *)content title:(NSString *)title;
@property (nonatomic, retain) UIView *contentView;
@property (nonatomic, copy) NSString *host;          // shown in the strip; nil: «…»
@property (nonatomic, assign) BOOL secure;           // https: green lamp + lock; otherwise amber, no lock
@property (nonatomic, assign) CGFloat progress;      // 0…1; hidden at 1 (fades) or below 0
- (void)setProgress:(CGFloat)progress animated:(BOOL)animated;
- (void)showErrorText:(NSString *)text actionTitle:(NSString *)actionTitle; // red banner under the strip
- (void)hideError;
@property (nonatomic, assign) id<RCWebFrameControllerDelegate> delegate;
+ (UINavigationController *)navigationControllerWithContentView:(UIView *)content title:(NSString *)title delegate:(id<RCWebFrameControllerDelegate>)delegate;
@end
