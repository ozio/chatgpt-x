// RCProgressView — kit.css .progress (UIProgressView bar style, jade gloss):
// determinate green or amber, or an indeterminate barber-pole stripe.
#import <UIKit/UIKit.h>

typedef enum { RCProgressGreen = 0, RCProgressAmber } RCProgressTint;

@interface RCProgressView : UIView
@property (nonatomic, assign) CGFloat progress;      // 0…1, animated over .35 s like the prototype
@property (nonatomic, assign) RCProgressTint tint;
@property (nonatomic, assign) BOOL indeterminate;    // striped, moving
- (void)setProgress:(CGFloat)progress animated:(BOOL)animated;
@end
