// RCPartPlaceholderView — honest stand-in for an answer part this stage cannot
// render yet (app.css .part.ph): tile + bold kind + "saved in the conversation".
// Account content is never dropped silently.
#import <UIKit/UIKit.h>
#import "RCGlyph.h"

@interface RCPartPlaceholderView : UIView
- (id)initWithGlyph:(NSString *)glyph tile:(RCTileColor)tile title:(NSString *)title text:(NSString *)text;
+ (NSString *)defaultText; // "Этот элемент ответа пока не показывается на iPhone — он сохранён в разговоре."
- (CGFloat)heightForWidth:(CGFloat)width;
@end
