// RCRatingRowView — «Как результат?» under a finished Codex task (prototype
// css/codex.css .cx-fb, Codex tier 3 «codex.feedback»): engraved label on linen and
// two small glossy square buttons, thumb up / thumb down. The chosen one turns jade
// (up) or red (down); the app sends the rating (a down vote may open a report).
// Light/dark, VoiceOver (buttons with the selected trait).
#import <UIKit/UIKit.h>

@class RCRatingRowView;
@protocol RCRatingRowViewDelegate <NSObject>
- (void)ratingRow:(RCRatingRowView *)row didRate:(NSInteger)rating; // 1 good, -1 bad
@end

@interface RCRatingRowView : UIView
@property (nonatomic, copy) NSString *prompt;   // default «How is the result?»
@property (nonatomic, assign) NSInteger rating; // 0 none, 1, -1 (set by the app when sent)
@property (nonatomic, assign) id<RCRatingRowViewDelegate> delegate;
- (CGFloat)heightForWidth:(CGFloat)width; // 36
@end
