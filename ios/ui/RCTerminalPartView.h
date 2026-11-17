// RCTerminalPartView — a command the agent runs, inside a task history (prototype
// css/codex.css .cx-term, Codex tier 1 «codex.commands»). The dark-green code panel
// of RCCodeBlockView with «TERMINAL» in the header and the observed state on the
// right: running (amber pulsing lamp, «running», red «Stop» capsule when the app can
// stop it), finished (green lamp for exit 0, red otherwise, «exit N · 1.6 s»,
// «stopped» when the user stopped it). The body is «$ command» and the output tail:
// the last 4 lines collapsed with «… N more lines», up to the last 200 expanded.
// Tapping the body toggles expansion (the delegate relayouts). Text wraps; long
// output is a label stack (RCTextStackView), never one layer above 2048 pt.
#import <UIKit/UIKit.h>

typedef enum { RCTerminalRunning = 0, RCTerminalFinished } RCTerminalState;

@class RCTerminalPartView;
@protocol RCTerminalPartViewDelegate <NSObject>
@optional
- (void)terminalPartDidTapStop:(RCTerminalPartView *)part;           // app stops it, then sets state
- (void)terminalPartDidChangeHeight:(RCTerminalPartView *)part;      // expanded / output grew
@end

@interface RCTerminalPartView : UIView
@property (nonatomic, copy) NSString *command;
@property (nonatomic, copy) NSArray *outputLines;       // NSString, oldest first
@property (nonatomic, assign) RCTerminalState state;
@property (nonatomic, assign) NSInteger exitCode;       // Finished
@property (nonatomic, assign) NSTimeInterval duration;  // Finished, seconds; < 0 hides it
@property (nonatomic, assign) BOOL stopped;             // Finished because the user stopped it
@property (nonatomic, assign) BOOL stopAvailable;       // Running: shows «Stop»
@property (nonatomic, assign) BOOL expanded;
@property (nonatomic, assign) id<RCTerminalPartViewDelegate> delegate;
- (CGFloat)heightForWidth:(CGFloat)width;
@end
