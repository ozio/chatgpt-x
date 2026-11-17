#import "RCTransition.h"

const NSTimeInterval RCFlipDuration = .75;

void RCFlipChildViewControllers(UIViewController *parent, UIViewController *from, UIViewController *to,
                                RCFlipDirection direction, void (^completion)(void)) {
    if (!parent || !to || to == from) { if (completion) completion(); return; }
    void (^done)(void) = [[completion copy] autorelease];
    [parent addChildViewController:to];
    to.view.frame = parent.view.bounds;
    to.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    BOOL animated = from && from.parentViewController == parent && from.isViewLoaded && from.view.window;
    if (!animated) {
        if (from.parentViewController == parent) { [from willMoveToParentViewController:nil]; [from.view removeFromSuperview]; [from removeFromParentViewController]; }
        [parent.view addSubview:to.view];
        [to didMoveToParentViewController:parent];
        if (done) done();
        return;
    }
    [from willMoveToParentViewController:nil];
    UIViewAnimationOptions options = (direction == RCFlipFromRight ? UIViewAnimationOptionTransitionFlipFromRight : UIViewAnimationOptionTransitionFlipFromLeft)
        | UIViewAnimationOptionCurveEaseInOut;
    // The flip turns the whole parent view, so whatever lies behind it in the window
    // shows through (in ChatGPT X: the session's hidden web view, a white page).
    // A black backdrop under the parent for the duration, as behind iOS 6's own flip.
    UIView *backdrop = nil, *superview = parent.view.superview;
    if (superview) {
        backdrop = [[[UIView alloc] initWithFrame:parent.view.frame] autorelease];
        backdrop.backgroundColor = [UIColor blackColor];
        backdrop.userInteractionEnabled = NO;
        [superview insertSubview:backdrop belowSubview:parent.view];
    }
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [parent transitionFromViewController:from toViewController:to duration:RCFlipDuration options:options animations:nil completion:^(BOOL finished) {
        [backdrop removeFromSuperview];
        [from removeFromParentViewController];
        [to didMoveToParentViewController:parent];
        [[UIApplication sharedApplication] endIgnoringInteractionEvents];
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, nil);
        if (done) done();
    }];
}
