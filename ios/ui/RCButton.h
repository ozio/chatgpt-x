// RCButton — content buttons from kit.css: large 44 pt (.button white/green/red/dark)
// and the App Store 2012 capsule (.pill plain/go/red). Bar buttons stay UIBarButtonItem.
#import <UIKit/UIKit.h>

typedef enum {
    RCButtonStyleLarge = 0, RCButtonStyleLargeGreen, RCButtonStyleLargeRed, RCButtonStyleLargeDark,
    RCButtonStylePill, RCButtonStylePillGo, RCButtonStylePillRed,
    RCButtonStylePillDark // graphite capsule for dark media bars (read-aloud player)
} RCButtonStyle;

@interface RCButton : UIButton
+ (id)buttonWithStyle:(RCButtonStyle)style title:(NSString *)title;
@property (nonatomic, assign) RCButtonStyle style;
+ (UIImage *)backgroundImageForStyle:(RCButtonStyle)style pressed:(BOOL)pressed;
@end
