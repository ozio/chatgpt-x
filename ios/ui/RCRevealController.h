// RCRevealController — Facebook-era reveal drawer (app.css #drawer/#front):
// the front screen slides 270 pt right over a dark linen drawer, with a soft
// left shadow; tap or drag the front back to close. Drag the front navigation
// bar (or the shadowed edge) to open. iOS 6 view-controller containment.
#import <UIKit/UIKit.h>
// Posted (object: the controller) when the drawer starts to open, by tap or drag.
extern NSString *const RCRevealControllerWillOpenDrawerNotification;

@interface RCRevealController : UIViewController
- (id)initWithFrontViewController:(UIViewController *)front drawerViewController:(UIViewController *)drawer;
@property (nonatomic, readonly) UIViewController *frontViewController;
@property (nonatomic, readonly) UIViewController *drawerViewController;
@property (nonatomic, assign) CGFloat drawerWidth; // 270
@property (nonatomic, readonly, getter = isDrawerOpen) BOOL drawerOpen;
- (void)setDrawerOpen:(BOOL)open animated:(BOOL)animated;
- (IBAction)toggleDrawer:(id)sender; // for the ☰ bar button
- (void)setFrontViewController:(UIViewController *)front closeDrawer:(BOOL)close; // drawer row picked
@end

@interface UIViewController (RCReveal)
@property (nonatomic, readonly) RCRevealController *rc_revealController;
@end
