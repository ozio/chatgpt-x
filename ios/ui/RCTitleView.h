// RCTitleView — navigation bar title with an optional second line (app.css .tv-inner):
// "Новый чат" over "● Готов к отправке" / "● Подготовка отправки… 42 с" / "GPT-5 ▾".
// Tappable (UIControlEventTouchUpInside) when the second line is a model picker.
#import <UIKit/UIKit.h>
#import "RCLampView.h"
#import "RCTheme.h"

@interface RCTitleView : UIControl
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;     // nil → single-line ("solo") title
@property (nonatomic, assign) BOOL animatesSubtitleAppearance; // opt-in unfold when a previously unknown model becomes known
@property (nonatomic, assign) BOOL showsLamp;
@property (nonatomic, assign) RCLampState lampState;
@property (nonatomic, assign) BOOL showsCaret;      // model picker affordance
@property (nonatomic, assign) RCBarVariant variant; // text shadow follows the bar
- (void)setTitle:(NSString *)title subtitle:(NSString *)subtitle lamp:(RCLampState)lamp showsLamp:(BOOL)showsLamp caret:(BOOL)caret;
@end
