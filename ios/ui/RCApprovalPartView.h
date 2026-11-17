// RCApprovalPartView — the agent stopped and asks for permission (prototype
// css/codex.css .cx-approve, Codex tier 1 «codex.approvals»). Header with a status
// lamp (blue info while pending, green allowed, red denied) and the title; optional
// target line (bold, with a 29 pt tile, e.g. a domain for network access); the reason
// and place in grey; the exact command in a dark monospaced box; then either
// «Deny» / «Allow» (large white / green, 44 pt) or the resolved line. While pending
// the card has a blue ring so it stands out in a long history.
// The view never resolves itself: the app reports the decision to the service and
// sets `state` when it is confirmed (`busy` hides the buttons behind a spinner).
#import "RCPartView.h"
#import "RCGlyph.h"

typedef enum { RCApprovalPending = 0, RCApprovalAllowed, RCApprovalDenied } RCApprovalState;

@class RCApprovalPartView;
@protocol RCApprovalPartViewDelegate <NSObject>
@optional
- (void)approvalPartDidAllow:(RCApprovalPartView *)part;
- (void)approvalPartDidDeny:(RCApprovalPartView *)part;
@end

@interface RCApprovalPartView : RCPartView
@property (nonatomic, copy) NSString *title;        // default «Codex is waiting for permission» / resolved «Codex asked for permission»
@property (nonatomic, copy) NSString *target;       // optional bold line (domain, tool)
@property (nonatomic, copy) NSString *targetGlyph;  // optional tile glyph for the target
@property (nonatomic, assign) RCTileColor targetTile;
@property (nonatomic, copy) NSString *detail;       // reason · where
@property (nonatomic, copy) NSString *command;      // monospaced, may be nil
@property (nonatomic, copy) NSString *allowTitle;   // default «Allow» (a later tier: «Allow…» with choices)
@property (nonatomic, copy) NSString *resolvedText; // default «Allowed» / «Denied»
@property (nonatomic, assign) RCApprovalState state;
@property (nonatomic, assign) BOOL allowAvailable, denyAvailable; // default YES; hides an unavailable decision, preserves slots
@property (nonatomic, assign) BOOL busy;            // decision sent, waiting for the service
@property (nonatomic, assign) id<RCApprovalPartViewDelegate> approvalDelegate;
@end
