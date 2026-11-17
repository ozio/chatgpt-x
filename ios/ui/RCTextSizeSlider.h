// RCTextSizeSlider — «Размер текста» slider (app.css .slider): small and large «A»
// at the ends, a jade-filled rail with a tick for each of the five RCTextSize
// steps and the iOS 6 knob. Dragging snaps to the nearest step and sends
// UIControlEventValueChanged whenever the step changes. VoiceOver: adjustable.
#import <UIKit/UIKit.h>
#import "RCTheme.h"

@interface RCTextSizeSlider : UIControl
@property (nonatomic, assign) RCTextSize value;      // RCTextSizeXSmall … RCTextSizeXLarge
@property (nonatomic, assign) BOOL showsStepName;    // «Обычный» under the knob row (+18 pt)
- (void)setValue:(RCTextSize)value animated:(BOOL)animated;
- (CGFloat)heightForWidth:(CGFloat)width;            // 26, or 44 with the step name
+ (NSString *)titleForTextSize:(RCTextSize)size;      // «Мелкий» … «Очень крупный» (RCTheme's names are XS…XL)
@end
