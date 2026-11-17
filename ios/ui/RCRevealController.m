#import "RCRevealController.h"
#import "RCTheme.h"
#import <QuartzCore/QuartzCore.h> // headers only (layer messages), no QuartzCore link

@interface RCRevealController () <UIGestureRecognizerDelegate> {
    UIViewController *_front, *_drawer;
    UIView *_frontContainer, *_catcher;
    UIPanGestureRecognizer *_barPan;
    CGFloat _panStart;
    BOOL _open;
}
@end

NSString *const RCRevealControllerWillOpenDrawerNotification = @"RCRevealControllerWillOpenDrawer";

@implementation RCRevealController
@synthesize frontViewController = _front, drawerViewController = _drawer, drawerWidth = _drawerWidth;

- (id)initWithFrontViewController:(UIViewController *)front drawerViewController:(UIViewController *)drawer {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _front = [front retain];
        _drawer = [drawer retain];
        _drawerWidth = 270;
    }
    return self;
}

- (void)dealloc {
    [_front release]; [_drawer release]; [_frontContainer release]; [_catcher release]; [_barPan release];
    [super dealloc];
}

- (void)loadView {
    UIView *v = [[[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame] autorelease];
    v.backgroundColor = [UIColor blackColor];
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view = v;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self addChildViewController:_drawer];
    _drawer.view.frame = CGRectMake(0, 0, _drawerWidth, self.view.bounds.size.height);
    _drawer.view.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_drawer.view];
    [_drawer didMoveToParentViewController:self];

    _frontContainer = [[UIView alloc] initWithFrame:self.view.bounds];
    _frontContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _frontContainer.backgroundColor = [UIColor blackColor];
    // box-shadow: -3px 0 10px rgba(0,0,0,.55)
    _frontContainer.layer.shadowColor = [UIColor blackColor].CGColor;
    _frontContainer.layer.shadowOpacity = .55;
    _frontContainer.layer.shadowOffset = CGSizeMake(-3, 0);
    _frontContainer.layer.shadowRadius = 5;
    [self.view addSubview:_frontContainer];

    _catcher = [[UIView alloc] initWithFrame:_frontContainer.bounds];
    _catcher.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _catcher.hidden = YES;
    [_catcher addGestureRecognizer:[[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closeTap)] autorelease]];
    [_catcher addGestureRecognizer:[[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)] autorelease]];
    _catcher.isAccessibilityElement = YES;
    _catcher.accessibilityLabel = RCL(@"Close menu");
    _catcher.accessibilityTraits = UIAccessibilityTraitButton;
    [self installFront:_front];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _frontContainer.layer.shadowPath = [UIBezierPath bezierPathWithRect:_frontContainer.bounds].CGPath;
}

- (void)installFront:(UIViewController *)front {
    [self addChildViewController:front];
    front.view.frame = _frontContainer.bounds;
    front.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_frontContainer addSubview:front.view];
    [_frontContainer addSubview:_catcher];
    [front didMoveToParentViewController:self];
    // Drag the navigation bar to open, as in the 2012 drawer apps (scroll views keep their pans).
    [_barPan.view removeGestureRecognizer:_barPan];
    [_barPan release];
    _barPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
    UIView *target = [front isKindOfClass:[UINavigationController class]] ? [(UINavigationController *)front navigationBar] : front.view;
    [target addGestureRecognizer:_barPan];
}

- (void)setFrontViewController:(UIViewController *)front closeDrawer:(BOOL)close {
    if (front != _front) {
        [_front willMoveToParentViewController:nil];
        [_front.view removeFromSuperview];
        [_front removeFromParentViewController];
        [_front release];
        _front = [front retain];
        if (self.isViewLoaded) [self installFront:_front];
    }
    if (close) [self setDrawerOpen:NO animated:YES];
}

- (BOOL)isDrawerOpen { return _open; }

- (void)placeFront:(CGFloat)x { CGRect f = _frontContainer.frame; f.origin.x = x; _frontContainer.frame = f; }

- (void)setDrawerOpen:(BOOL)open animated:(BOOL)animated {
    if (open && !_open && _frontContainer.frame.origin.x == 0) [[NSNotificationCenter defaultCenter] postNotificationName:RCRevealControllerWillOpenDrawerNotification object:self];
    _open = open;
    _catcher.hidden = !open;
    _front.view.userInteractionEnabled = !open;
    _front.view.accessibilityElementsHidden = open;
    _drawer.view.accessibilityElementsHidden = !open;
    void (^move)(void) = ^{ [self placeFront:open ? _drawerWidth : 0]; };
    if (animated) [UIView animateWithDuration:.3 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:move completion:nil];
    else move();
    if (open) [_front.view endEditing:YES];
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, nil);
}

- (IBAction)toggleDrawer:(id)sender { [self setDrawerOpen:!_open animated:YES]; }
- (void)closeTap { [self setDrawerOpen:NO animated:YES]; }

- (void)pan:(UIPanGestureRecognizer *)g {
    CGFloat tx = [g translationInView:self.view].x;
    switch (g.state) {
        case UIGestureRecognizerStateBegan:
            _panStart = _frontContainer.frame.origin.x;
            if (!_open) { [_front.view endEditing:YES]; [[NSNotificationCenter defaultCenter] postNotificationName:RCRevealControllerWillOpenDrawerNotification object:self]; }
            break;
        case UIGestureRecognizerStateChanged: [self placeFront:MIN(_drawerWidth, MAX(0, _panStart + tx))]; break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            CGFloat vx = [g velocityInView:self.view].x, x = _frontContainer.frame.origin.x;
            BOOL open = fabs(vx) > 300 ? vx > 0 : x > _drawerWidth / 2;
            [self setDrawerOpen:open animated:YES];
            break;
        }
        default: break;
    }
}

- (NSUInteger)supportedInterfaceOrientations { return UIInterfaceOrientationMaskPortrait; }
@end

@implementation UIViewController (RCReveal)
- (RCRevealController *)rc_revealController {
    UIViewController *vc = self.parentViewController;
    while (vc && ![vc isKindOfClass:[RCRevealController class]]) vc = vc.parentViewController;
    return (RCRevealController *)vc;
}
@end
