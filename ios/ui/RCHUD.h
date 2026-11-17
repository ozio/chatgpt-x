// RCHUD — transient confirmation in the iOS 6 HUD look (kit.css .hud): 156 pt
// black .72 square with a check, a spinner (busy, resolves later) or text only.
#import <UIKit/UIKit.h>

typedef enum { RCHUDDone = 0, RCHUDBusy, RCHUDTextOnly } RCHUDKind;

@interface RCHUD : UIView
// Shows centred in `view` (usually the window). Done/TextOnly hide after `seconds`
// (default 1.1 when 0); Busy stays until -finishWithText: or -hide.
+ (RCHUD *)showText:(NSString *)text kind:(RCHUDKind)kind inView:(UIView *)view seconds:(NSTimeInterval)seconds;
- (void)finishWithText:(NSString *)text; // busy → check, hides after .9 s
- (void)hide;
@end
