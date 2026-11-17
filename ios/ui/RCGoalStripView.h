// RCGoalStripView — the task goal and budget above a Codex history (prototype
// css/codex.css .cx-goal, Codex tier 3 «codex.goals»): white rounded box,
// «Цель: <text>» with «бюджет N %» on the right and a jade progress bar under it;
// amber once the budget is almost used (≥ 90 %), with «бюджет исчерпан» at 100 %.
// Optional tap (UIControlEventTouchUpInside) edits the goal. Light/dark, VoiceOver.
#import <UIKit/UIKit.h>

@interface RCGoalStripView : UIControl
@property (nonatomic, copy) NSString *goal;
@property (nonatomic, assign) CGFloat budgetUsed; // 0…1; < 0 hides the budget
- (CGFloat)heightForWidth:(CGFloat)width;
@end
