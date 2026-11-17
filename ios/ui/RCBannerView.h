// RCBannerView — strip under the navigation bar (app.css .banner): warn (amber,
// "session expired · Войти") and err (red, "no connection, draft saved").
#import <UIKit/UIKit.h>
#import "RCButton.h"

typedef enum { RCBannerWarning = 0, RCBannerError, RCBannerBusy } RCBannerKind;

@interface RCBannerView : UIView
- (id)initWithKind:(RCBannerKind)kind text:(NSString *)text actionTitle:(NSString *)actionTitle;
@property (nonatomic, assign) RCBannerKind kind;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, readonly) RCButton *actionButton; // nil without actionTitle; add a target
- (CGFloat)heightForWidth:(CGFloat)width;
@end
