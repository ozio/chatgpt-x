// RCTextStackView — multi-line attributed text as a stack of UILabels.
// On the iPhone 5 a layer taller than the GPU texture limit (4096 px = 2048 pt
// at 2x) is not drawn at all, so a long answer or pasted message in one UILabel
// would turn blank. The text is cut into chunks at line breaks (or, for a huge
// paragraph, at a space); every chunk is far below the limit. Chunks share the
// same attributes, so line metrics match a single label.
#import <UIKit/UIKit.h>
@interface RCTextStackView : UIView
@property (nonatomic, copy) NSAttributedString *attributedText;
- (CGFloat)heightForWidth:(CGFloat)width;
+ (NSArray *)chunksOfAttributedString:(NSAttributedString *)text; // NSAttributedString pieces
@end
