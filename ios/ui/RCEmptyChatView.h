// RCEmptyChatView — new-chat state (app.css .empty-chat): the bare debossed brand
// mark (72 pt, RCBrandMarkDebossed, light/dark artwork), title, hint, and (stage 8)
// a grouped "Временный чат" row with a switch. The temporary variant greys the
// mark; the caller supplies the texts for each variant.
#import <UIKit/UIKit.h>

@interface RCEmptyChatView : UIView
@property (nonatomic, copy) NSString *title;        // "Чем могу помочь?" / "Временный чат"
@property (nonatomic, copy) NSString *message;
@property (nonatomic, assign) BOOL temporary;       // grey mark
@property (nonatomic, assign) BOOL showsTemporaryToggle;
@property (nonatomic, readonly) UISwitch *temporarySwitch; // add a target for UIControlEventValueChanged
- (CGFloat)heightForWidth:(CGFloat)width;
@end
