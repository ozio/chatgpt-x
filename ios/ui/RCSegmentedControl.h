// RCSegmentedControl — kit.css .seg in two looks: jade (on jade bars and drawer
// panels) and light (.seg.light: white-to-mist segments, jade selected segment)
// for grouped screens on linen («Меньше | Обычно | Больше», library tabs, GPT
// categories). Own UIControl: no private UIKit; UIControlEventValueChanged.
#import <UIKit/UIKit.h>

typedef enum { RCSegmentedLight = 0, RCSegmentedJade } RCSegmentedStyle;

@interface RCSegmentedControl : UIControl
- (id)initWithItems:(NSArray *)titles style:(RCSegmentedStyle)style;
@property (nonatomic, copy) NSArray *items;                // NSString titles
@property (nonatomic, assign) RCSegmentedStyle style;
@property (nonatomic, assign) NSInteger selectedSegmentIndex; // -1: none
+ (CGFloat)height;                                         // 30
@end
