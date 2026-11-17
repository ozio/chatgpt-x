// RCTransition — screen-level transitions in the iOS 6 manner.
// Card flip (UIViewAnimationOptionTransitionFlip…, as in Weather/Stocks and many
// 2012 apps) between two child view controllers of a container: used when the app
// leaves the account (chat → sign-in, from the left) or returns to it (from the
// right). iOS 5+ view-controller containment, UIKit only.
#import <UIKit/UIKit.h>
typedef enum { RCFlipFromLeft = 0, RCFlipFromRight } RCFlipDirection;
#ifdef __cplusplus
extern "C" {
#endif
extern const NSTimeInterval RCFlipDuration; // .75 s, the iOS 6 flip
// `from` must be a child of `parent` whose view is on screen; `to` must not have a
// parent yet. Ends with `to` as the child filling parent.view, `from` removed.
// Interaction is ignored during the flip; VoiceOver gets a screen change.
// Without a window (or with from == nil) it swaps instantly.
void RCFlipChildViewControllers(UIViewController *parent, UIViewController *from, UIViewController *to,
                                RCFlipDirection direction, void (^completion)(void));
#ifdef __cplusplus
}
#endif
