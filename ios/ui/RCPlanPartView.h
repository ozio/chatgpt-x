// RCPlanPartView — the agent's work plan inside a task history (prototype
// css/codex.css .cx-plan, Codex tier 2 «codex.plan»): header «План» with the sliders
// glyph and, while proposed, a blue «ждёт согласия»; numbered steps in glossy
// circles that turn into jade checks when done (the text dims); while proposed,
// «Изменить» / «Выполнить план» (44 pt, white / green). The view never accepts the
// plan by itself: the app sends the decision and sets `state` when confirmed.
// Light/dark, VoiceOver (each step reads its number and done state).
#import "RCPartView.h"

typedef enum { RCPlanProposed = 0, RCPlanAccepted, RCPlanFinished } RCPlanState;

@interface RCPlanStep : NSObject
+ (id)stepWithText:(NSString *)text done:(BOOL)done;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, assign) BOOL done;
@end

@class RCPlanPartView;
@protocol RCPlanPartViewDelegate <NSObject>
@optional
- (void)planPartDidAccept:(RCPlanPartView *)part;  // «Выполнить план»
- (void)planPartDidAskToEdit:(RCPlanPartView *)part; // «Изменить»: the app focuses its composer
@end

@interface RCPlanPartView : RCPartView
@property (nonatomic, copy) NSArray *steps;   // RCPlanStep
@property (nonatomic, assign) RCPlanState state;
@property (nonatomic, assign) BOOL busy;      // acceptance sent, waiting for the service
@property (nonatomic, assign) id<RCPlanPartViewDelegate> planDelegate;
@end
