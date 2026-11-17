// RCTimelineNoteView — small engraved status lines between items of a task history
// (prototype css/codex.css .cx-gap / .cx-working, Codex tier 1 «codex.transcript»):
//   Capsule   centred translucent capsule with a lamp — «Connection restored ·
//             3 events loaded» after a reconnect; nothing the agent did is hidden.
//   Activity  left-aligned bold engraved line with a stock spinner — «Codex is
//             working…» while the task runs and nothing else is visible.
//   Meta      small monospaced engraved line with a 6 pt lamp (tier 3 «codex.hooks»):
//             «hook pre-run · passed · 0,4 s»; an error lamp turns the text red.
// Light/dark (engraved white / black shadow), VoiceOver reads the text.
#import <UIKit/UIKit.h>
#import "RCLampView.h"

typedef enum { RCTimelineNoteCapsule = 0, RCTimelineNoteActivity, RCTimelineNoteMeta } RCTimelineNoteStyle;

@interface RCTimelineNoteView : UIView
- (id)initWithStyle:(RCTimelineNoteStyle)style;
@property (nonatomic, readonly) RCTimelineNoteStyle style;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, assign) RCLampState lamp; // Capsule, Meta; Off hides the lamp
- (CGFloat)heightForWidth:(CGFloat)width;
@end
