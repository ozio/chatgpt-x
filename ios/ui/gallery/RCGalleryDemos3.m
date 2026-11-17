// Gallery pages for the shell screens and small elements (second kit pass).
// Offline demos only: every "service" answer is a local timer.
#import "RCGalleryDemos.h"
#import "RCEmptyChatView.h"
#import "RCTransition.h"
#import "RCTheme.h"
#import "RCGlyph.h"
#import "RCButton.h"
#import "RCHUD.h"
#import "RCStage.h"
#import "RCTextSizeSlider.h"
#import "RCSegmentedControl.h"
#import "RCAccountHeaderView.h"
#import "RCSwipeToDelete.h"
#import "RCSelectTextViewController.h"
#import "RCWelcomeViewController.h"
#import "RCLaunchView.h"
#import "RCWebFrameController.h"
#import "RCVoiceViewController.h"
#import "RCPINViewController.h"
#import <objc/runtime.h>
#import "RCImageViewerController.h"
#import "RCScannerViewController.h"
#import "RCGridViewController.h"
#import "RCRefreshControl.h"
#import "RCTranslateViewController.h"
#import "RCSourcesSheet.h"
#import "RCShareLinkSheet.h"
#import "RCReportViewController.h"
#import <QuartzCore/QuartzCore.h> // headers only (layer messages)

static UIImage *RCDemoArt(unsigned top, unsigned bottom, CGSize size) {
    UIGraphicsBeginImageContextWithOptions(size, YES, 1);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect r = CGRectMake(0, 0, size.width, size.height);
    RCDrawVerticalGradient(ctx, r, [NSArray arrayWithObjects:RCHex(top), RCHex(bottom), nil], nil);
    CGContextSetFillColorWithColor(ctx, RCHexA(0xffffff, .55).CGColor);
    CGContextFillEllipseInRect(ctx, CGRectMake(size.width * .62, size.height * .14, size.width * .18, size.width * .18));
    CGContextSetFillColorWithColor(ctx, RCHexA(0x10301f, .45).CGColor);
    CGContextMoveToPoint(ctx, 0, size.height);
    CGContextAddLineToPoint(ctx, size.width * .35, size.height * .5);
    CGContextAddLineToPoint(ctx, size.width * .6, size.height * .78);
    CGContextAddLineToPoint(ctx, size.width * .8, size.height * .6);
    CGContextAddLineToPoint(ctx, size.width, size.height);
    CGContextFillPath(ctx);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

static NSString *RCDemoAnswer(void) { return RCL(@"For the city, a hybrid or city bike works well.\n\nA step-through frame is comfortable in everyday clothes, an internal gear hub needs less maintenance, and fenders and a rack are usually included.\n\nBudget: from 35,000 ₽ and up."); }

@interface RCGalleryPage (Shells)
- (RCButton *)addDemoButton:(NSString *)title action:(SEL)action;
- (UINavigationController *)presentJade:(UIViewController *)vc;
@end

@implementation RCGalleryPage (Shells)
- (RCButton *)addDemoButton:(NSString *)title action:(SEL)action {
    RCButton *b = [RCButton buttonWithStyle:RCButtonStyleLarge title:title];
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    UIView *wrap = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 52)] autorelease];
    b.frame = CGRectMake(0, 0, 300, 44);
    b.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [wrap addSubview:b];
    [self addInsetView:wrap height:52];
    return b;
}
- (UINavigationController *)presentJade:(UIViewController *)vc {
    UINavigationController *nav = [vc isKindOfClass:[UINavigationController class]] ? (UINavigationController *)vc : [[[UINavigationController alloc] initWithRootViewController:vc] autorelease];
    if (nav != vc) [RCTheme styleNavigationBar:nav.navigationBar variant:RCBarVariantJade];
    [self presentViewController:nav animated:YES completion:nil];
    return nav;
}
@end

static void RCDemoDismiss(UIViewController *vc) {
    UIViewController *p = vc.presentingViewController;
    while (p.presentingViewController) p = p.presentingViewController;
    [p dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Small elements

@interface RCGalleryControlsPage () <RCSwipeToDeleteDelegate, UITableViewDataSource, UITableViewDelegate> {
    UILabel *_preview;
    RCSwipeToDelete *_swipeLight, *_swipeDark;
    UITableView *_light, *_dark;
    NSMutableArray *_lightRows, *_darkRows;
}
@end

@implementation RCGalleryControlsPage
- (id)init {
    if ((self = [super init])) {
        _lightRows = [[NSMutableArray alloc] initWithObjects:RCL(@"How to choose a bike"), RCL(@"Weekly menu"), RCL(@"Email to landlord"), nil];
        _darkRows = [[NSMutableArray alloc] initWithObjects:RCL(@"Trip plan to Kazan"), RCL(@"Contract translation"), RCL(@"Gift ideas"), nil];
    }
    return self;
}
- (void)dealloc {
    [_swipeLight detach]; [_swipeDark detach];
    [_swipeLight release]; [_swipeDark release]; _light.dataSource = nil; _dark.dataSource = nil; _light.delegate = nil; _dark.delegate = nil;
    [_light release]; [_dark release]; [_preview release]; [_lightRows release]; [_darkRows release];
    [super dealloc];
}

- (void)build {
    [self addCaption:RCL(@"Text size (stage 8)")];
    UIView *box = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 120)] autorelease];
    box.backgroundColor = [RCTheme cardColor];
    box.layer.cornerRadius = 9; box.layer.borderWidth = 1; box.layer.borderColor = [RCTheme cardStrokeColor].CGColor;
    [_preview release];
    _preview = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, 268, 50)];
    _preview.backgroundColor = [UIColor clearColor];
    _preview.textColor = [RCTheme answerTextColor];
    _preview.font = [RCTheme bodyFontForSize:[RCTheme textSize]];
    _preview.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    RCLabelSetText(_preview, RCL(@"This is how ChatGPT answers and your messages will look."));
    [box addSubview:_preview];
    RCTextSizeSlider *slider = [[[RCTextSizeSlider alloc] initWithFrame:CGRectMake(16, 70, 268, 44)] autorelease];
    slider.showsStepName = YES;
    slider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [slider addTarget:self action:@selector(sizeMoved:) forControlEvents:UIControlEventValueChanged];
    [box addSubview:slider];
    [self addInsetView:box height:124];
    [self addNote:RCL(@"The slider only changes the sample on this page; the global size is the toggle in the component list.")];

    [self addCaption:RCL(@"Segments: light and jade")];
    RCSegmentedControl *light = [[[RCSegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:RCL(@"Less"), RCL(@"Normal"), RCL(@"More"), nil] style:RCSegmentedLight] autorelease];
    light.selectedSegmentIndex = 1;
    [light addTarget:self action:@selector(segment:) forControlEvents:UIControlEventValueChanged];
    [self addInsetView:light height:31];
    [self addSpace:10];
    RCSegmentedControl *three = [[[RCSegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:RCL(@"All"), RCL(@"Favorites"), RCL(@"Deleted"), nil] style:RCSegmentedLight] autorelease];
    [self addInsetView:three height:31];
    [self addSpace:10];
    UIImageView *bar = [[[UIImageView alloc] initWithImage:[RCTheme navigationBarBackgroundForVariant:RCBarVariantJade]] autorelease];
    bar.frame = CGRectMake(0, 0, 320, 44);
    bar.userInteractionEnabled = YES;
    RCSegmentedControl *jade = [[[RCSegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:RCL(@"Chats"), RCL(@"Projects"), nil] style:RCSegmentedJade] autorelease];
    jade.frame = CGRectMake(60, 7, 200, 31);
    jade.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [bar addSubview:jade];
    [self addView:bar height:44];

    [self addCaption:RCGalleryOn(7) ? RCL(@"Account header (plan — stage 7)") : RCL(@"Account header")];
    RCAccountHeaderView *h = [[[RCAccountHeaderView alloc] initWithFrame:CGRectZero] autorelease];
    h.name = RCL(@"Anna Smirnova"); h.email = @"anna@example.com"; h.planTitle = RCGalleryOn(7) ? @"Plus" : nil;
    [self addView:h];
    RCAccountHeaderView *h2 = [[[RCAccountHeaderView alloc] initWithFrame:CGRectZero] autorelease];
    h2.name = RCL(@"Ivan"); h2.email = @"ivan@example.com"; h2.planTitle = RCGalleryOn(7) ? @"Free" : nil; h2.showsDisclosure = YES;
    h2.avatarImage = RCDemoArt(0x8fb8e6, 0x2d6fb8, CGSizeMake(128, 128));
    [h2 addTarget:self action:@selector(headerTapped) forControlEvents:UIControlEventTouchUpInside];
    [self addView:h2];

    [self addCaption:RCGalleryOn(7) ? RCL(@"Swipe to delete (stage 7)") : RCL(@"Swipe to delete — from stage 7")];
    if (!RCGalleryOn(7)) { [self addNote:RCL(@"At this stage chat deletion is not available yet: rows do not respond to swiping.")]; }
    [_swipeLight detach]; [_swipeLight release]; _swipeLight = nil;
    [_swipeDark detach]; [_swipeDark release]; _swipeDark = nil;
    [_light release];
    _light = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 160) style:UITableViewStyleGrouped];
    _light.scrollEnabled = NO; _light.dataSource = self; _light.delegate = self;
    [RCTheme styleGroupedTableView:_light];
    [self addView:_light height:44 * _lightRows.count + 20];
    [self addNote:RCL(@"Dark drawer linen:")];
    [_dark release];
    _dark = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 132) style:UITableViewStylePlain];
    _dark.scrollEnabled = NO; _dark.dataSource = self; _dark.delegate = self;
    _dark.backgroundColor = [RCTheme linenDarkColor];
    _dark.separatorColor = RCHexA(0, .35);
    [self addView:_dark height:44 * _darkRows.count];
    if (RCGalleryOn(7)) {
        _swipeLight = [[RCSwipeToDelete alloc] initWithTableView:_light]; _swipeLight.delegate = self;
        _swipeDark = [[RCSwipeToDelete alloc] initWithTableView:_dark]; _swipeDark.delegate = self;
    }
    [self addSpace:12];
}

- (void)sizeMoved:(RCTextSizeSlider *)s { _preview.font = [RCTheme bodyFontForSize:s.value]; RCLabelSetText(_preview, _preview.text); }
- (void)segment:(RCSegmentedControl *)s { RCGalleryHUD(self.view, [s.items objectAtIndex:(NSUInteger)s.selectedSegmentIndex]); }
- (void)headerTapped { RCGalleryHUD(self.view, RCL(@"Profile")); }

- (NSMutableArray *)rowsFor:(UITableView *)t { return t == _light ? _lightRows : _darkRows; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return (NSInteger)[self rowsFor:t].count; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil] autorelease];
    c.textLabel.text = [[self rowsFor:t] objectAtIndex:(NSUInteger)ip.row];
    if (t == _light) [RCTheme styleGroupedCell:c position:[RCTheme positionForRow:ip.row count:(NSInteger)_lightRows.count]];
    else { c.textLabel.textColor = RCHex(0xe6f2ec); c.textLabel.font = [UIFont systemFontOfSize:15]; c.textLabel.backgroundColor = [UIColor clearColor]; c.backgroundColor = [UIColor clearColor]; c.selectionStyle = UITableViewCellSelectionStyleGray; }
    return c;
}
- (void)tableView:(UITableView *)t willDisplayCell:(UITableViewCell *)c forRowAtIndexPath:(NSIndexPath *)ip { if (t == _dark) c.backgroundColor = [UIColor clearColor]; }
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip { [t deselectRowAtIndexPath:ip animated:YES]; }
- (void)swipeToDelete:(RCSwipeToDelete *)s deleteRowAtIndexPath:(NSIndexPath *)ip {
    UITableView *t = s == _swipeLight ? _light : _dark;
    NSMutableArray *rows = [self rowsFor:t];
    if ((NSUInteger)ip.row >= rows.count) return;
    [rows removeObjectAtIndex:(NSUInteger)ip.row];
    [t deleteRowsAtIndexPaths:[NSArray arrayWithObject:ip] withRowAnimation:UITableViewRowAnimationFade];
    RCGalleryHUD(self.view, RCL(@"Deleted"));
    [self performSelector:@selector(rebuild) withObject:nil afterDelay:.35];
}
@end

#pragma mark - Select text

@interface RCGallerySelectPage () <RCSelectTextViewControllerDelegate>
@end
@implementation RCGallerySelectPage
- (void)build {
    [self addCaption:RCGalleryOn(9) ? RCL(@"“Select Text” (stage 9)") : RCL(@"“Select Text” — from stage 9")];
    [self addNote:RCL(@"Hold an answer → “Select Text”. Plain text without markup, matching the chat size and appearance; “Copy” copies the selection or all text.")];
    if (!RCGalleryOn(9)) return;
    [self addDemoButton:RCL(@"Open “Selection”") action:@selector(open)];
    [self addDemoButton:RCL(@"Via custom copy handler") action:@selector(openRouted)];
}
- (void)open { [self presentViewController:[RCSelectTextViewController navigationControllerWithText:RCDemoAnswer() delegate:nil] animated:YES completion:nil]; }
- (void)openRouted { [self presentViewController:[RCSelectTextViewController navigationControllerWithText:RCDemoAnswer() delegate:self] animated:YES completion:nil]; }
- (void)selectTextController:(RCSelectTextViewController *)c copyText:(NSString *)text {
    [UIPasteboard generalPasteboard].string = text;
    [RCHUD showText:[NSString stringWithFormat:RCL(@"Copied: %d chars"), (int)text.length] kind:RCHUDDone inView:c.view.window seconds:0];
}
@end

#pragma mark - Welcome and sign-in page frame

#pragma mark - Flip demo (logout → sign-in)

// Container showing the kit card flip: a chat front side with “Log out”, the
// signed-out welcome on the back; “Log in” flips back. Offline.
@interface RCGalleryFlipDemo : UIViewController <RCWelcomeViewControllerDelegate> { UINavigationController *_chat; RCWelcomeViewController *_welcome; }
@end
@implementation RCGalleryFlipDemo
- (void)dealloc { _welcome.delegate = nil; [_chat release]; [_welcome release]; [super dealloc]; }
- (void)loadView {
    UIView *v = [[[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame] autorelease];
    v.backgroundColor = [UIColor blackColor];
    self.view = v;
    UIViewController *front = [[[UIViewController alloc] init] autorelease];
    front.title = RCL(@"New chat");
    front.view.backgroundColor = [RCTheme contentBackgroundColor];
    RCEmptyChatView *empty = [[[RCEmptyChatView alloc] initWithFrame:CGRectMake(0, 60, 320, 260)] autorelease];
    empty.title = RCL(@"What can I help with?"); empty.message = RCL(@"Demo: “Log out” flips the screen like a card.");
    empty.frame = CGRectMake(0, 40, 320, [empty heightForWidth:320]);
    [front.view addSubview:empty];
    RCButton *out = [RCButton buttonWithStyle:RCButtonStyleLargeRed title:RCL(@"Log out")];
    out.frame = CGRectMake(10, 340, 300, 44);
    [out addTarget:self action:@selector(signOut) forControlEvents:UIControlEventTouchUpInside];
    [front.view addSubview:out];
    front.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:RCL(@"Close") style:UIBarButtonItemStyleBordered target:self action:@selector(close)] autorelease];
    _chat = [[UINavigationController alloc] initWithRootViewController:front];
    [RCTheme styleNavigationBar:_chat.navigationBar variant:RCBarVariantJade];
    _welcome = [[RCWelcomeViewController alloc] init];
    _welcome.delegate = self;
    [_welcome setState:RCWelcomeSignedOut text:nil];
    RCFlipChildViewControllers(self, nil, _chat, RCFlipFromRight, nil);
}
- (void)signOut { RCFlipChildViewControllers(self, _chat, _welcome, RCFlipFromLeft, nil); }
- (void)welcomeDidTapSignIn:(RCWelcomeViewController *)w { RCFlipChildViewControllers(self, _welcome, _chat, RCFlipFromRight, nil); }
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
@end

#pragma mark - Launch demo

// The kit launch screen over the screen ChatGPT X starts on: a chat (signed in)
// or the welcome screen (signed out). Appears without animation, like the system
// launch image it matches. Offline.
@interface RCGalleryLaunchDemo : UIViewController <RCWelcomeViewControllerDelegate> {
    UIViewController *_under; RCLaunchView *_launch; RCLaunchFinish _finish; NSTimeInterval _after; BOOL _status;
}
- (id)initWithFinish:(RCLaunchFinish)finish after:(NSTimeInterval)after status:(BOOL)status;
@end
@implementation RCGalleryLaunchDemo
- (id)initWithFinish:(RCLaunchFinish)finish after:(NSTimeInterval)after status:(BOOL)status {
    if ((self = [super init])) { _finish = finish; _after = after; _status = status; }
    return self;
}
- (void)dealloc { [NSObject cancelPreviousPerformRequestsWithTarget:self]; [_under release]; [_launch release]; [super dealloc]; }
- (void)loadView {
    UIView *v = [[[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame] autorelease];
    v.backgroundColor = [UIColor blackColor];
    self.view = v;
    if (_finish == RCLaunchFinishWelcome) {
        RCWelcomeViewController *w = [[[RCWelcomeViewController alloc] init] autorelease];
        w.delegate = self;
        w.state = RCWelcomeIdle;
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:w];
        nav.navigationBarHidden = YES;
        _under = nav;
    } else {
        UIViewController *front = [[[UIViewController alloc] init] autorelease];
        front.title = RCL(@"New chat");
        front.view.backgroundColor = [RCTheme contentBackgroundColor];
        RCEmptyChatView *empty = [[[RCEmptyChatView alloc] initWithFrame:CGRectMake(0, 60, 320, 260)] autorelease];
        empty.title = RCL(@"What can I help with?"); empty.message = RCL(@"Demo: the launch screen fades into the chat.");
        empty.frame = CGRectMake(0, 40, 320, [empty heightForWidth:320]);
        [front.view addSubview:empty];
        front.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:RCL(@"Close") style:UIBarButtonItemStyleBordered target:self action:@selector(close)] autorelease];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:front];
        [RCTheme styleNavigationBar:nav.navigationBar variant:RCBarVariantJade];
        _under = nav;
    }
    [self addChildViewController:_under];
    _under.view.frame = v.bounds;
    _under.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [v addSubview:_under.view];
    [_under didMoveToParentViewController:self];
    _launch = [[RCLaunchView alloc] initWithFrame:v.bounds];
    _launch.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [v addSubview:_launch];
    if (_status) [_launch showStatusAfterDelay:1.5];
    [self performSelector:@selector(finishLaunch) withObject:nil afterDelay:_after];
}
- (void)finishLaunch { [_launch finish:_finish completion:nil]; }
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)welcomeDidTapSignIn:(RCWelcomeViewController *)w { (void)w; [self close]; }
@end

@interface RCGalleryWelcomePage () <RCWelcomeViewControllerDelegate, RCWebFrameControllerDelegate> { RCWebFrameController *_frame; NSTimer *_timer; }
@end
@implementation RCGalleryWelcomePage
- (void)dealloc { [_timer invalidate]; [_frame release]; [super dealloc]; }
- (void)build {
    [self addCaption:RCL(@"Welcome and sign-in")];
    [self addNote:RCL(@"First launch and logging out. The logo is the white embossed mark without a tile (RCBrandMarkEmbossedWhite).")];
    [self addDemoButton:RCL(@"Welcome") action:@selector(open)];
    [self addDemoButton:RCL(@"Checking saved login") action:@selector(openChecking)];
    [self addDemoButton:RCL(@"Login error") action:@selector(openError)];
    [self addDemoButton:RCL(@"After logout") action:@selector(openSignedOut)];
    [self addDemoButton:RCL(@"Logout: flip to sign-in") action:@selector(openFlip)];
    [self addCaption:RCL(@"Launch")];
    [self addNote:RCL(@"RCLaunchView matches the launch image (Default*.png): only the white mark in the centre, no text or spinner. It leaves once the app knows what to show: fades into the chat or raises the mark to its place on the welcome screen.")];
    [self addDemoButton:RCL(@"Launch → chat") action:@selector(openLaunchChat)];
    [self addDemoButton:RCL(@"Launch → welcome (long restore)") action:@selector(openLaunchWelcome)];
    [self addDemoButton:RCL(@"Launch without transition (10 s)") action:@selector(openLaunchHold)];
    [self addCaption:RCL(@"Sign-in page frame")];
    [self addNote:RCL(@"The real service page is the app’s WebView; here a schematic is shown instead.")];
    [self addDemoButton:RCL(@"Sign-in page") action:@selector(openWithDrawer)];
    [self addDemoButton:RCL(@"Sign-in page with error") action:@selector(openFrameError)];
}
- (void)showWelcome:(RCWelcomeState)state {
    RCWelcomeViewController *w = [[[RCWelcomeViewController alloc] init] autorelease];
    w.delegate = self;
    w.signUpAvailable = RCGalleryOn(6);
    w.state = state;
    UINavigationController *nav = [[[UINavigationController alloc] initWithRootViewController:w] autorelease];
    nav.navigationBarHidden = YES;
    [self presentViewController:nav animated:YES completion:nil];
    if (state == RCWelcomeChecking) { [_timer invalidate]; _timer = [NSTimer scheduledTimerWithTimeInterval:2.5 target:self selector:@selector(checked:) userInfo:w repeats:NO]; }
}
- (void)checked:(NSTimer *)t { _timer = nil; [(RCWelcomeViewController *)t.userInfo setState:RCWelcomeIdle]; }
- (void)open { [self showWelcome:RCWelcomeIdle]; }
- (void)openChecking { [self showWelcome:RCWelcomeChecking]; }
- (void)openError { [self showWelcome:RCWelcomeError]; }
- (void)openSignedOut { [self showWelcome:RCWelcomeSignedOut]; }
- (void)showLaunch:(RCLaunchFinish)finish after:(NSTimeInterval)after status:(BOOL)status {
    [self presentViewController:[[[RCGalleryLaunchDemo alloc] initWithFinish:finish after:after status:status] autorelease] animated:NO completion:nil];
}
- (void)openLaunchChat { [self showLaunch:RCLaunchFinishContent after:1 status:NO]; }
- (void)openLaunchWelcome { [self showLaunch:RCLaunchFinishWelcome after:3.5 status:YES]; }
- (void)openLaunchHold { [self showLaunch:RCLaunchFinishContent after:10 status:NO]; }
- (void)openFlip { [self presentViewController:[[[RCGalleryFlipDemo alloc] init] autorelease] animated:YES completion:nil]; }
- (void)openVariant:(NSNumber *)n {
    switch (n.intValue) { case 3: [self openChecking]; break; case 4: [self openError]; break; case 5: [self openSignedOut]; break; case 6: [self openFlip]; break; case 8: [self openLaunchHold]; break; case 9: [self openLaunchWelcome]; break; default: [self openFrameError]; }
}
- (UIView *)schematicPage {
    UIView *p = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 400)] autorelease];
    p.backgroundColor = [UIColor whiteColor];
    UILabel *l = [[[UILabel alloc] initWithFrame:CGRectMake(20, 40, 280, 120)] autorelease];
    l.font = [UIFont systemFontOfSize:15]; l.textColor = RCHex(0x888888); l.textAlignment = NSTextAlignmentCenter;
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    RCLabelSetText(l, RCL(@"Here the app displays its service sign-in page (WebView). After logging in, you return to ChatGPT X."));
    [p addSubview:l];
    return p;
}
- (void)showFrame:(BOOL)error from:(UIViewController *)host {
    [_frame release];
    _frame = [[RCWebFrameController alloc] initWithContentView:[self schematicPage] title:RCL(@"Log In")];
    _frame.delegate = self;
    _frame.host = @"auth.openai.com";
    UINavigationController *nav = [[[UINavigationController alloc] initWithRootViewController:_frame] autorelease];
    [RCTheme styleNavigationBar:nav.navigationBar variant:RCBarVariantJade];
    [(host ? host : self) presentViewController:nav animated:YES completion:nil];
    [_frame setProgress:.1 animated:NO];
    [_frame setProgress:.3 animated:YES];
    [_timer invalidate];
    _timer = [NSTimer scheduledTimerWithTimeInterval:.9 target:self selector:@selector(loaded:) userInfo:[NSNumber numberWithBool:error] repeats:NO];
}
- (void)loaded:(NSTimer *)t {
    _timer = nil;
    [_frame setProgress:1 animated:YES];
    if ([t.userInfo boolValue]) [_frame showErrorText:RCL(@"The page did not load. Check your connection.") actionTitle:RCL(@"Retry")];
}
- (void)openWithDrawer { [self showFrame:NO from:nil]; }
- (void)openFrameError { [self showFrame:YES from:nil]; }
- (void)welcomeDidTapSignIn:(RCWelcomeViewController *)w { [self showFrame:NO from:w]; }
- (void)welcomeDidTapSignUp:(RCWelcomeViewController *)w { [self showFrame:NO from:w]; _frame.title = RCL(@"Sign Up"); }
- (void)webFrameDidCancel:(RCWebFrameController *)f { [_timer invalidate]; _timer = nil; RCDemoDismiss(f); }
- (void)webFrameDidTapErrorAction:(RCWebFrameController *)f { [f hideError]; [f setProgress:.3 animated:YES]; [_timer invalidate]; _timer = [NSTimer scheduledTimerWithTimeInterval:.9 target:self selector:@selector(loaded:) userInfo:[NSNumber numberWithBool:NO] repeats:NO]; }
@end

#pragma mark - Voice

@interface RCGalleryVoicePage () <RCVoiceViewControllerDelegate> { RCVoiceViewController *_voice; NSTimer *_timer; NSUInteger _turn; }
@end
@implementation RCGalleryVoicePage
- (void)dealloc { [_timer invalidate]; [_voice release]; [super dealloc]; }
- (void)build {
    [self addCaption:RCGalleryOn(8) ? RCL(@"Turn-by-turn voice (stage 8)") : RCL(@"Voice — from stage 8")];
    [self addNote:RCL(@"Record → answer → read aloud. Tap the orb to finish your phrase; tap during the answer to interrupt. Transcript and limits are stage 6.")];
    if (!RCGalleryOn(8)) return;
    [self addDemoButton:RCL(@"Voice conversation") action:@selector(open)];
    [self addDemoButton:RCL(@"Thinking") action:@selector(openThinking)];
    [self addDemoButton:RCL(@"Speaking") action:@selector(openSpeaking)];
    [self addDemoButton:RCL(@"Poor connection") action:@selector(openReconnecting)];
    if (RCGalleryOn(6)) [self addDemoButton:RCL(@"Limit reached") action:@selector(openLimit)];
}
- (void)showVoice:(RCVoiceState)s {
    [_voice release];
    _voice = [[RCVoiceViewController alloc] init];
    _voice.delegate = self;
    _voice.showsTranscriptToggle = RCGalleryOn(6);
    _voice.showsSettings = RCGalleryOn(6);
    _voice.transcriptShown = RCGalleryOn(6);
    _voice.state = s;
    _turn = 0;
    if (s == RCVoiceSpeaking || s == RCVoiceThinking) { [_voice appendTranscriptLine:RCL(@"What is the weather in Kazan tomorrow?") speaker:RCL(@"You")]; if (s == RCVoiceSpeaking) [_voice appendTranscriptLine:RCL(@"Around freezing and sleet tomorrow.") speaker:@"ChatGPT"]; }
    _voice.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:_voice animated:YES completion:nil];
}
- (void)open { [self showVoice:RCVoiceListening]; }
- (void)openThinking { [self showVoice:RCVoiceThinking]; }
- (void)openSpeaking { [self showVoice:RCVoiceSpeaking]; }
- (void)openReconnecting { [self showVoice:RCVoiceReconnecting]; }
- (void)openLimit { [self showVoice:RCVoiceError]; _voice.stateText = RCL(@"Limit reached"); _voice.noticeText = RCL(@"Voice mode limit reached. Resets tomorrow at 03:00. You can continue by text in the same chat."); }
- (void)openVariant:(NSNumber *)n { switch (n.intValue) { case 3: [self openThinking]; break; case 4: [self openSpeaking]; break; case 5: [self openReconnecting]; break; case 6: [self open]; _voice.muted = YES; break; default: [self openLimit]; } }
- (void)step:(NSTimer *)t {
    _timer = nil;
    NSArray *q = [NSArray arrayWithObjects:RCL(@"What is the weather in Kazan tomorrow?"), RCL(@"What should I wear?"), RCL(@"Thanks!"), nil];
    NSArray *a = [NSArray arrayWithObjects:RCL(@"Around freezing and sleet tomorrow."), RCL(@"A warm jacket and waterproof shoes."), RCL(@"You’re welcome! Have a nice day."), nil];
    switch (_voice.state) {
        case RCVoiceSending: [_voice appendTranscriptLine:[q objectAtIndex:_turn % 3] speaker:RCL(@"You")]; _voice.state = RCVoiceThinking; _timer = [NSTimer scheduledTimerWithTimeInterval:1.4 target:self selector:@selector(step:) userInfo:nil repeats:NO]; break;
        case RCVoiceThinking: [_voice appendTranscriptLine:[a objectAtIndex:_turn % 3] speaker:@"ChatGPT"]; _turn++; _voice.state = RCVoiceSpeaking; _timer = [NSTimer scheduledTimerWithTimeInterval:3.2 target:self selector:@selector(step:) userInfo:nil repeats:NO]; break;
        case RCVoiceSpeaking: _voice.state = RCVoiceListening; break;
        default: break;
    }
}
- (void)voiceDidTapOrb:(RCVoiceViewController *)v {
    if (v.state == RCVoiceListening && !v.muted) { v.state = RCVoiceSending; [_timer invalidate]; _timer = [NSTimer scheduledTimerWithTimeInterval:.9 target:self selector:@selector(step:) userInfo:nil repeats:NO]; }
    else if (v.state == RCVoiceSpeaking) { [_timer invalidate]; _timer = nil; v.state = RCVoiceListening; }
    else if (v.state == RCVoiceReconnecting) v.state = RCVoiceListening;
}
- (void)voiceDidEnd:(RCVoiceViewController *)v { [_timer invalidate]; _timer = nil; [self dismissViewControllerAnimated:YES completion:^{ RCGalleryHUD(self.view, RCL(@"Conversation saved in chat")); }]; }
- (void)voiceDidTapSettings:(RCVoiceViewController *)v { RCGalleryHUD(v.view, RCL(@"Voice and language")); }
@end

#pragma mark - PIN

@interface RCGalleryPINPage () <RCPINViewControllerDelegate>
@end
@implementation RCGalleryPINPage
- (void)build {
    [self addCaption:RCGalleryOn(6) ? RCL(@"Locked chats (stage 6)") : RCL(@"Locked chats — stage 6")];
    [self addNote:RCL(@"The app stores and verifies the PIN; the kit only shows the keypad. In this demo the valid PIN is 1234.")];
    if (!RCGalleryOn(6)) return;
    [self addDemoButton:RCL(@"Enter PIN") action:@selector(open)];
    [self addDemoButton:RCL(@"Create PIN") action:@selector(openSet)];
    [self addDemoButton:RCL(@"Too many attempts") action:@selector(openLocked)];
    [self addDemoButton:RCL(@"Checking with the service") action:@selector(openChecking)];
    [self addDemoButton:RCL(@"Locked for 5 min") action:@selector(openLongLock)];
}
- (RCPINViewController *)show:(RCPINMode)mode {
    RCPINViewController *p = [[[RCPINViewController alloc] initWithMode:mode] autorelease];
    p.delegate = self;
    p.message = mode == RCPINModeUnlock ? RCL(@"Chats locked with a PIN are hidden from the list and search.") : RCL(@"4 digits. A forgotten PIN cannot be recovered — only reset along with locked chats.");
    [self presentJade:p];
    return p;
}
- (void)open { [self show:RCPINModeUnlock]; }
- (void)openSet { [self show:RCPINModeSet]; }
- (void)openLocked { RCPINViewController *p = [self show:RCPINModeUnlock]; [p view]; [p lockForSeconds:30]; }
// checking: the app verifies asynchronously (locked.pin.verify); the demo answers after 1.5 s.
- (void)openChecking { RCPINViewController *p = [self show:RCPINModeUnlock]; p.titleText = RCL(@"Enter PIN"); objc_setAssociatedObject(p, "async", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (void)openLongLock { RCPINViewController *p = [self show:RCPINModeUnlock]; [p view]; [p lockForSeconds:300]; }
- (void)openVariant:(NSNumber *)n { if (n.intValue == 3) [self openSet]; else if (n.intValue == 4) { RCPINViewController *p = [self show:RCPINModeUnlock]; [p view]; [p showError:RCL(@"Wrong PIN")]; } else [self openLocked]; }
- (BOOL)pinController:(RCPINViewController *)c checkPIN:(NSString *)pin {
    if (objc_getAssociatedObject(c, "async")) {
        c.checking = YES; BOOL ok = [pin isEqualToString:@"1234"];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (ok) [self dismissViewControllerAnimated:YES completion:^{ RCGalleryHUD(self.view, RCL(@"Unlocked")); }]; else [c showError:RCL(@"Wrong PIN")];
        });
        return YES;
    }
    if ([pin isEqualToString:@"1234"]) { [self dismissViewControllerAnimated:YES completion:^{ RCGalleryHUD(self.view, RCL(@"Unlocked")); }]; return YES; }
    if (c.failures + 1 >= 3) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [c lockForSeconds:30]; }); // privacy.locked_retry_limits
    return NO;
}
- (void)pinController:(RCPINViewController *)c didSetPIN:(NSString *)pin { [self dismissViewControllerAnimated:YES completion:^{ RCGalleryHUD(self.view, RCL(@"PIN set")); }]; }
- (void)pinControllerDidCancel:(RCPINViewController *)c { [self dismissViewControllerAnimated:YES completion:nil]; }
@end

#pragma mark - Image viewer and scanner

@interface RCGalleryMediaPage () <RCImageViewerControllerDelegate, RCScannerViewControllerDelegate, UIActionSheetDelegate> { RCScannerViewController *_scanner; NSMutableArray *_pages; }
@end
@implementation RCGalleryMediaPage
- (void)dealloc { [_scanner release]; [_pages release]; [super dealloc]; }
- (void)build {
    [self addCaption:RCGalleryOn(7) ? RCL(@"Image viewer (stage 7)") : RCL(@"Image viewer — from stage 7")];
    [self addNote:RCL(@"Double-tap zooms in, single-tap hides the bars. “Edit” is stage 6.")];
    if (RCGalleryOn(7)) [self addDemoButton:RCL(@"Open image") action:@selector(open)];
    [self addCaption:RCGalleryOn(6) ? RCL(@"Document scanner (stage 6)") : RCL(@"Scanner — stage 6")];
    [self addNote:RCL(@"The app manages the camera and pages; without a camera, the viewfinder layout is shown.")];
    if (RCGalleryOn(6)) [self addDemoButton:RCL(@"Scan") action:@selector(openWithDrawer)];
}
- (void)open {
    [self presentViewController:[RCImageViewerController navigationControllerWithImage:RCDemoArt(0x7fd7c4, 0x1e6f8a, CGSizeMake(640, 640)) caption:RCL(@"Watercolor: lighthouse on a cliff at sunset") delegate:self] animated:YES completion:nil];
    RCImageViewerController *v = (RCImageViewerController *)[(UINavigationController *)self.presentedViewController topViewController];
    v.editAvailable = RCGalleryOn(6);
}
// Save: busy HUD over the image, then the check (the app resolves it when Photos answers).
- (void)imageViewerDidTapSave:(RCImageViewerController *)v { [v showHUDText:RCL(@"Saving to Photos…") kind:RCHUDBusy seconds:0]; [v performSelector:@selector(finishHUDWithText:) withObject:RCL(@"Saved to Photos") afterDelay:1.2]; }
- (void)imageViewerDidTapShare:(RCImageViewerController *)v { RCGalleryHUD(v.view, RCL(@"Share…")); }
- (void)imageViewerDidTapEdit:(RCImageViewerController *)v { RCGalleryHUD(v.view, RCL(@"What would you like to change?")); }
- (void)openWithDrawer {
    [_pages release]; _pages = [[NSMutableArray alloc] init];
    UINavigationController *nav = [RCScannerViewController navigationControllerWithDelegate:self];
    [_scanner release]; _scanner = [(RCScannerViewController *)nav.topViewController retain];
    [self presentViewController:nav animated:YES completion:nil];
}
- (void)openVariant:(NSNumber *)n { [self openWithDrawer]; for (int i = 0; i < 3; i++) [self scannerDidTapShutter:_scanner]; _scanner.selectedPage = 1; }
- (void)scannerDidTapShutter:(RCScannerViewController *)s { [_pages addObject:[NSNull null]]; s.pages = _pages; }
- (void)scannerDidCancel:(RCScannerViewController *)s { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)scannerDidSave:(RCScannerViewController *)s {
    if (!_pages.count) { [RCHUD showText:RCL(@"Capture at least one page") kind:RCHUDTextOnly inView:s.view.window seconds:0]; return; }
    [self dismissViewControllerAnimated:YES completion:^{ RCGalleryHUD(self.view, RCL(@"PDF ready")); }];
}
- (void)scanner:(RCScannerViewController *)s didSelectPageAtIndex:(NSUInteger)i {
    UIActionSheet *a = [[[UIActionSheet alloc] initWithTitle:[NSString stringWithFormat:RCL(@"Page %d"), (int)i + 1] delegate:self cancelButtonTitle:RCL(@"Cancel") destructiveButtonTitle:RCL(@"Delete page") otherButtonTitles:RCL(@"Retake"), RCL(@"Rotate"), nil] autorelease];
    a.tag = (NSInteger)i;
    [a showInView:s.view];
}
- (void)actionSheet:(UIActionSheet *)a clickedButtonAtIndex:(NSInteger)b {
    if (b == a.destructiveButtonIndex && a.tag < (NSInteger)_pages.count) { [_pages removeObjectAtIndex:(NSUInteger)a.tag]; _scanner.pages = _pages; _scanner.selectedPage = -1; }
}
@end

#pragma mark - Grids

@interface RCGalleryGridsPage () <RCGridViewControllerDelegate>
@end
@implementation RCGalleryGridsPage
- (void)build {
    [self addCaption:RCL(@"Drawer sections")];
    [self addNote:RCL(@"Images and GPTs are stage 6; library is stage 7 (folders, favorites, and grid are stage 6).")];
    if (RCGalleryOn(6)) [self addDemoButton:RCL(@"Images") action:@selector(open)];
    if (RCGalleryOn(6)) [self addDemoButton:@"GPT" action:@selector(openGPT)];
    if (RCGalleryOn(7)) [self addDemoButton:RCL(@"Library") action:@selector(openWithDrawer)];
    if (RCGalleryOn(6)) [self addDemoButton:RCL(@"Library grid") action:@selector(openLibraryGrid)];
    if (RCGalleryOn(7)) [self addDemoButton:RCL(@"Empty library") action:@selector(openEmpty)];
}
- (void)refreshDemo:(RCRefreshControl*)sender { [sender performSelector:@selector(endRefreshing) withObject:nil afterDelay:.8]; }
- (void)push:(RCGridViewController *)g { g.delegate = self;RCRefreshControl*r=[[[RCRefreshControl alloc]init]autorelease];[r addTarget:self action:@selector(refreshDemo:)forControlEvents:UIControlEventValueChanged];(void)g.view;[r attachToTableView:g.tableView inViewController:g];g.tableView.alwaysBounceVertical=YES; [self.navigationController pushViewController:g animated:YES]; }
- (void)open {
    RCGridViewController *g = [[[RCGridViewController alloc] initWithStyle:RCGridStyleImages title:RCL(@"Images")] autorelease];
    unsigned c[8][2] = {{0x7fd7c4, 0x1e6f8a}, {0xf5b46a, 0xd06a10}, {0xc6a1e6, 0x7a45b0}, {0x8fb8e6, 0x2d6fb8}, {0x7fdcab, 0x1e9656}, {0xffd36e, 0xe29a0e}, {0xef8378, 0xb81506}, {0xa9b6af, 0x5f6f67}};
    NSMutableArray *items = [NSMutableArray array];
    for (int i = 0; i < 8; i++) [items addObject:[RCGridItem itemWithImage:RCDemoArt(c[i][0], c[i][1], CGSizeMake(200, 200)) title:[NSString stringWithFormat:RCL(@"Image %d"), i + 1]]];
    g.sections = [NSArray arrayWithObject:[RCGridSection sectionWithTitle:nil items:items]];
    [self push:g];
}
- (void)openGPT {
    RCGridViewController *g = [[[RCGridViewController alloc] initWithStyle:RCGridStyleGPT title:@"GPT"] autorelease];
    g.searchPlaceholder = RCL(@"Search GPTs");
    g.segmentTitles = [NSArray arrayWithObjects:RCL(@"Popular"), RCL(@"Study"), RCL(@"Work"), nil];
    RCGridItem *mine = [RCGridItem itemWithTitle:RCL(@"My Chef") subtitle:RCL(@"Recipes from what’s in your fridge") glyph:@"star" tile:RCTileOrange];
    RCGridItem *a = [RCGridItem itemWithTitle:RCL(@"Math Tutor") subtitle:RCL(@"Explains step by step without giving away the answer") glyph:@"book" tile:RCTileBlue];
    a.detail = RCL(@"By example.com");
    RCGridItem *b = [RCGridItem itemWithTitle:RCL(@"Email Editor") subtitle:RCL(@"Polite, concise, and to the point") glyph:@"mail" tile:RCTileGreen];
    b.detail = RCL(@"By community");
    g.sections = [NSArray arrayWithObjects:[RCGridSection sectionWithTitle:RCL(@"My GPTs") items:[NSArray arrayWithObject:mine]], [RCGridSection sectionWithTitle:RCL(@"Featured") items:[NSArray arrayWithObjects:a, b, nil]], nil];
    [self push:g];
}
- (NSArray *)libraryItems {
    RCGridItem *f1 = [RCGridItem itemWithTitle:RCL(@"Lease agreement.pdf") subtitle:RCL(@"1.2 MB · yesterday") glyph:@"file" tile:RCTileRed];
    RCGridItem *f2 = [RCGridItem itemWithTitle:RCL(@"Trip budget.xlsx") subtitle:RCL(@"84 KB · 3 days ago") glyph:@"chart" tile:RCTileGreen];
    RCGridItem *f3 = [RCGridItem itemWithImage:RCDemoArt(0xc6a1e6, 0x7a45b0, CGSizeMake(200, 200)) title:RCL(@"Passport scan.jpg")];
    f3.subtitle = RCL(@"640 KB · a week ago");
    RCGridItem *f4 = [RCGridItem itemWithTitle:RCL(@"Notes.txt") subtitle:RCL(@"2 KB · a month ago") glyph:@"file" tile:RCTileGray];
    f1.fileIcon = f2.fileIcon = f3.fileIcon = f4.fileIcon = YES; f3.glyph = @"photo";
    return [NSArray arrayWithObjects:f1, f2, f3, f4, nil];
}
- (RCGridViewController *)library {
    RCGridViewController *g = [[[RCGridViewController alloc] initWithStyle:RCGridStyleLibrary title:RCL(@"Library")] autorelease];
    g.searchPlaceholder = RCL(@"Search library");
    if (RCGalleryOn(6)) g.segmentTitles = [NSArray arrayWithObjects:RCL(@"All"), RCL(@"Favorites"), RCL(@"Deleted"), nil];
    NSMutableArray *sections = [NSMutableArray array];
    if (RCGalleryOn(6)) {
        RCGridItem *fo = [RCGridItem itemWithTitle:RCL(@"Documents") subtitle:nil glyph:@"folder" tile:RCTileBlue];
        fo.value = @"12"; fo.showsDisclosure = YES;
        [sections addObject:[RCGridSection sectionWithTitle:RCL(@"Folders") items:[NSArray arrayWithObject:fo]]];
    }
    [sections addObject:[RCGridSection sectionWithTitle:RCL(@"Files") items:[self libraryItems]]];
    g.sections = sections;
    return g;
}
- (void)openWithDrawer { [self push:[self library]]; }
- (void)openLibraryGrid { RCGridViewController *g = [self library]; g.sections = [NSArray arrayWithObject:[RCGridSection sectionWithTitle:nil items:[self libraryItems]]]; g.showsGrid = YES; [self push:g]; }
- (void)openEmpty {
    RCGridViewController *g = [[[RCGridViewController alloc] initWithStyle:RCGridStyleLibrary title:RCL(@"Library")] autorelease];
    g.emptyGlyph = @"library"; g.emptyTitle = RCL(@"Nothing here yet"); g.emptyText = RCL(@"Files you send in chats will appear here.");
    g.sections = [NSArray array];
    [self push:g];
}
- (void)openVariant:(NSNumber *)n { switch (n.intValue) { case 3: [self openGPT]; break; case 4: [self openLibraryGrid]; break; default: [self openEmpty]; } }
- (void)grid:(RCGridViewController *)g didSelectItem:(RCGridItem *)item {
    if (g.style == RCGridStyleImages) { [self presentViewController:[RCImageViewerController navigationControllerWithImage:item.image caption:item.title delegate:nil] animated:YES completion:nil]; return; }
    RCGalleryHUD(g.view, item.title);
}
- (void)grid:(RCGridViewController *)g didSelectSegment:(NSInteger)i { RCGalleryHUD(g.view, [g.segmentTitles objectAtIndex:(NSUInteger)i]); }
@end

#pragma mark - Translate

@interface RCGalleryTranslatePage () <RCTranslateViewControllerDelegate, UIActionSheetDelegate> { RCTranslateViewController *_tr; }
@end
@implementation RCGalleryTranslatePage
- (void)dealloc { [_tr release]; [super dealloc]; }
- (void)build {
    [self addCaption:RCGalleryOn(8) ? RCL(@"Translate (stage 8)") : RCL(@"Translate — from stage 8")];
    [self addNote:RCL(@"Language selection and “Copy / Share” are stage 7. At stage 8 the pair is fixed: “Detect → English”.")];
    if (!RCGalleryOn(8)) return;
    [self addDemoButton:RCL(@"Open “Translate”") action:@selector(openPlain)];
    [self addDemoButton:RCL(@"With completed translation") action:@selector(open)];
}
- (RCTranslateViewController *)make {
    [_tr release];
    _tr = [[RCTranslateViewController alloc] init];
    _tr.delegate = self;
    _tr.languagesEditable = RCGalleryOn(7);
    _tr.shareAvailable = RCGalleryOn(7);
    _tr.sourceText = RCL(@"Please postpone the rent payment by five days.");
    [self.navigationController pushViewController:_tr animated:YES];
    return _tr;
}
- (void)openPlain { [self make]; }
- (void)open { RCTranslateViewController *t = [self make]; t.detectedText = RCL(@"Detected: Russian"); t.resultText = @"I would like to postpone the rent payment by five days."; }
- (void)openVariant:(NSNumber *)n { RCTranslateViewController *t = [self make]; t.busy = YES; }
- (void)translate:(RCTranslateViewController *)t translateText:(NSString *)text {
    t.busy = YES;
    if ([t.sourceLanguage isEqualToString:RCL(@"Detect")]) t.detectedText = RCL(@"Detected: Russian");
    [self performSelector:@selector(finish) withObject:nil afterDelay:.9];
}
- (void)finish { _tr.busy = NO; _tr.resultText = [_tr.targetLanguage isEqualToString:@"Deutsch"] ? @"Ich möchte die Mietzahlung um fünf Tage verschieben." : @"I would like to postpone the rent payment by five days."; }
- (void)pick:(BOOL)source {
    UIActionSheet *a = [[[UIActionSheet alloc] initWithTitle:(source ? RCL(@"Translate from") : RCL(@"Translate to")) delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil] autorelease];
    if (source) [a addButtonWithTitle:RCL(@"Detect")];
    for (NSString *l in [NSArray arrayWithObjects:RCL(@"Russian"), @"English", @"Deutsch", @"Français", RCL(@"Tatar"), nil]) [a addButtonWithTitle:l];
    a.cancelButtonIndex = [a addButtonWithTitle:RCL(@"Cancel")];
    a.tag = source;
    [a showInView:_tr.view];
}
- (void)translateDidTapSourceLanguage:(RCTranslateViewController *)t { [self pick:YES]; }
- (void)translateDidTapTargetLanguage:(RCTranslateViewController *)t { [self pick:NO]; }
- (void)translateDidSwapLanguages:(RCTranslateViewController *)t { if ([t.targetLanguage isEqualToString:RCL(@"Detect")]) t.targetLanguage = RCL(@"Russian"); }
- (void)actionSheet:(UIActionSheet *)a clickedButtonAtIndex:(NSInteger)i {
    if (i == a.cancelButtonIndex) return;
    NSString *l = [a buttonTitleAtIndex:i];
    if (a.tag) _tr.sourceLanguage = l; else _tr.targetLanguage = l;
    _tr.resultText = nil;
}
- (void)translate:(RCTranslateViewController *)t shareResult:(NSString *)text { RCGalleryHUD(t.view, RCL(@"Share…")); }
@end

#pragma mark - Sheets

@interface RCGallerySheetsPage () <RCSourcesSheetDelegate, RCShareLinkSheetDelegate, UIAlertViewDelegate> { RCShareLinkSheet *_share; RCSourceItem *_pending; }
@end
@implementation RCGallerySheetsPage
- (void)dealloc { [NSObject cancelPreviousPerformRequestsWithTarget:self]; [_share release]; [_pending release]; [super dealloc]; }
- (void)build {
    [self addCaption:RCGalleryOn(8) ? RCL(@"“Sources” (stage 8)") : RCL(@"“Sources” — from stage 8")];
    if (RCGalleryOn(8)) [self addDemoButton:RCL(@"Answer sources") action:@selector(open)];
    [self addCaption:RCGalleryOn(7) ? RCL(@"“Share link” (stage 7)") : RCL(@"Chat link — from stage 7")];
    [self addNote:RCL(@"The app creates the link. Shown here are the button states: create → creating → copy, or error with retry.")];
    if (!RCGalleryOn(7)) return;
    [self addDemoButton:RCL(@"Share link") action:@selector(openWithDrawer)];
    [self addDemoButton:RCL(@"Link already created") action:@selector(openCreated)];
    [self addDemoButton:RCL(@"Could not create") action:@selector(openFailed)];
    [self addNote:RCL(@"First the app reads the chat (read-only), then offers “Create link”. Retrying after an error is read-only again.")];
    [self addDemoButton:RCL(@"Checking chat → create") action:@selector(openPreparing)];
    [self addDemoButton:RCL(@"Could not check chat") action:@selector(openPreparationFailed)];
}
+ (NSArray *)demoSources {
    return [NSArray arrayWithObjects:
            [RCSourceItem sourceWithTitle:RCL(@"How to choose a city bike: complete guide") host:@"velo-guide.example" URL:[NSURL URLWithString:@"https://velo-guide.example/city"]],
            [RCSourceItem sourceWithTitle:RCL(@"Internal gear hubs — pros and cons") host:@"www.bike-lab.example" URL:[NSURL URLWithString:@"https://www.bike-lab.example/hubs"]],
            [RCSourceItem sourceWithTitle:RCL(@"2026 hybrid bike ratings") host:@"ratings.example" URL:[NSURL URLWithString:@"https://ratings.example/hybrid"]], nil];
}
- (void)open { [self presentViewController:[RCSourcesSheet navigationControllerWithSources:[RCGallerySheetsPage demoSources] delegate:self] animated:YES completion:nil]; }
- (void)sourcesSheet:(RCSourcesSheet *)s didSelectSource:(RCSourceItem *)src {
    [_pending release]; _pending = [src retain];
    UIAlertView *a = [[[UIAlertView alloc] initWithTitle:RCL(@"Open in Safari?") message:src.host delegate:self cancelButtonTitle:RCL(@"Cancel") otherButtonTitles:RCL(@"Open"), nil] autorelease];
    [a show];
}
- (void)alertView:(UIAlertView *)a clickedButtonAtIndex:(NSInteger)i { if (i != a.cancelButtonIndex) RCGalleryHUD(self.view, RCL(@"Demo: Safari is not opened")); }
- (RCShareLinkSheet *)showShare:(RCShareLinkState)state {
    [_share release];
    _share = [[RCShareLinkSheet alloc] init];
    _share.delegate = self;
    _share.chatTitle = RCL(@"How to choose a bike");
    _share.chatMeta = RCL(@"6 messages · today, 14:20");
    _share.excerpt = RCL(@"For the city, a hybrid or city bike works well: a step-through frame, an internal gear hub…");
    _share.state = state;
    if (state == RCShareLinkCreated) _share.link = @"https://chatgpt.com/share/6f2e…a91c";
    [self presentViewController:[RCShareLinkSheet navigationControllerWithSheet:_share] animated:YES completion:nil];
    return _share;
}
- (void)openWithDrawer { [self showShare:RCShareLinkIdle]; }
- (void)openCreated { [self showShare:RCShareLinkCreated]; }
- (void)openFailed { [self showShare:RCShareLinkFailed]; }
- (void)openPreparing { [self showShare:RCShareLinkPreparing]; [self performSelector:@selector(prepared) withObject:nil afterDelay:1.2]; }
- (void)openPreparationFailed { [self showShare:RCShareLinkPreparationFailed].preparationRetryAvailable = YES; }
- (void)prepared { if (_share.state == RCShareLinkPreparing) _share.state = RCShareLinkIdle; }
- (void)shareLinkSheetRetryPreparation:(RCShareLinkSheet *)s { s.state = RCShareLinkPreparing; [self performSelector:@selector(prepared) withObject:nil afterDelay:1.2]; }
- (void)openVariant:(NSNumber *)n { switch (n.intValue) { case 3: [self openCreated]; break; case 4: [self openFailed]; break; case 5: [self openPreparing]; break; case 6: [self openPreparationFailed]; break; default: [self showShare:RCShareLinkCreating]; } }
- (void)shareLinkSheet:(RCShareLinkSheet *)s createLinkIncludingName:(BOOL)include { s.state = RCShareLinkCreating; [self performSelector:@selector(created) withObject:nil afterDelay:.9]; }
- (void)created { _share.link = @"https://chatgpt.com/share/6f2e…a91c"; _share.state = RCShareLinkCreated; }
- (void)shareLinkSheet:(RCShareLinkSheet *)s shareLink:(NSString *)link { RCGalleryHUD(s.view, RCL(@"Mail, Messages…")); }
@end

#pragma mark - Research report

@interface RCGalleryReportPage () <RCReportViewControllerDelegate>
@end
@implementation RCGalleryReportPage
- (void)build {
    [self addCaption:RCGalleryOn(7) ? RCL(@"Research report (stage 7)") : RCL(@"Report — from stage 7")];
    [self addNote:RCL(@"Opens from the research card: “Open report”. “Save PDF” is stage 6.")];
    if (RCGalleryOn(7)) [self addDemoButton:RCL(@"Open report") action:@selector(open)];
}
- (void)open {
    NSString *md = RCL(@"### Summary\nThe market is growing for the third year in a row: demand is shifting to city models with a **500–700 Wh** battery.\n\n### Key figures\n- sales: +18% YoY\n- average price: 92,000 ₽\n- online sales share: 41%\n\n### What matters to buyers\n1. Range of at least 60 km\n2. Removable battery\n3. Service nearby\n\n> Data from public retailer reports and industry reviews.");
    RCReportViewController *r = [[[RCReportViewController alloc] initWithTitle:RCL(@"Electric bike market in Russia") markdown:md] autorelease];
    r.meta = RCL(@"Done · 12 min · 3 sources · 9 pp.");
    r.sources = [RCGallerySheetsPage demoSources];
    r.savePDFAvailable = RCGalleryOn(6);
    r.delegate = self;
    [self.navigationController pushViewController:r animated:YES];
}
- (void)report:(RCReportViewController *)r didSelectSource:(RCSourceItem *)s { RCGalleryHUD(r.view, s.host); }
- (void)reportDidTapSavePDF:(RCReportViewController *)r { RCGalleryHUD(r.view, RCL(@"PDF saved to Library")); }
- (void)reportDidTapShare:(RCReportViewController *)r { RCGalleryHUD(r.view, RCL(@"Share…")); }
@end
