#import "RCWelcomeViewController.h"
#import "RCTheme.h"
#import "RCButton.h"
#import "RCLampView.h"
#import <QuartzCore/QuartzCore.h> // headers only (layer messages)

@interface RCWelcomeViewController () {
    UIImageView *_logo;
    UILabel *_titleLabel, *_messageLabel, *_statusLabel, *_footLabel;
    RCLampView *_lamp;
    UIActivityIndicatorView *_spinner;
    RCButton *_signIn, *_signUp;
}
@end

@implementation RCWelcomeViewController
@synthesize state = _state, statusText = _statusText, appTitle = _appTitle, message = _message, footnote = _footnote, signUpAvailable = _signUpAvailable, delegate = _delegate;

// Bare white embossed mark on the dark linen. The 108×110 canvas, and the mark
// centred where the old 96 pt tile was (54, 52), keep RCLaunchView and
// ios/ui/tools/render-launch.swift in place: 104 pt mark at (2, 0).
+ (UIImage *)logoImage {
    return [RCTheme imageForKey:@"welcome-mark" size:CGSizeMake(108, 110) capInsets:UIEdgeInsetsZero drawing:^(CGContextRef ctx, CGRect b) {
        (void)ctx; (void)b;
        [RCTheme drawBrandMark:RCBrandMarkEmbossedWhite inRect:CGRectMake(2, 0, 104, 104) grey:NO];
    }];
}

+ (CGFloat)logoTopForHeight:(CGFloat)height { return height > 500 ? 56 : 30; }

static UILabel *RCWelcomeLabel(UIFont *font, UIColor *color) {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectZero];
    l.backgroundColor = [UIColor clearColor];
    l.font = font;
    l.textColor = color;
    l.textAlignment = NSTextAlignmentCenter;
    l.shadowColor = RCHexA(0, .65);
    l.shadowOffset = CGSizeMake(0, -1);
    return l;
}

- (id)initWithNibName:(NSString *)nib bundle:(NSBundle *)bundle {
    if ((self = [super initWithNibName:nib bundle:bundle])) {
        _appTitle = [@"ChatGPT X" copy];
        _message = nil;
        _footnote = [RCL(@"Unofficial app. Not affiliated with OpenAI.") copy];
        self.wantsFullScreenLayout = NO;
    }
    return self;
}

- (void)dealloc {
    [_logo release]; [_titleLabel release]; [_messageLabel release]; [_statusLabel release]; [_footLabel release];
    [_lamp release]; [_spinner release]; [_signIn release]; [_signUp release];
    [_statusText release]; [_appTitle release]; [_message release]; [_footnote release];
    [super dealloc];
}

- (void)loadView {
    UIView *v = [[[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame] autorelease];
    v.backgroundColor = [RCTheme linenDarkColor];
    self.view = v;
    _logo = [[UIImageView alloc] initWithImage:[RCWelcomeViewController logoImage]];
    _logo.isAccessibilityElement = NO;
    [v addSubview:_logo];
    _titleLabel = RCWelcomeLabel([UIFont boldSystemFontOfSize:28], [UIColor whiteColor]);
    _titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    _messageLabel = RCWelcomeLabel([UIFont systemFontOfSize:15], RCHexA(0xe6f2ec, .8));
    _statusLabel = RCWelcomeLabel([UIFont boldSystemFontOfSize:14], RCHexA(0xe6f2ec, .9));
    _footLabel = RCWelcomeLabel([UIFont systemFontOfSize:12], RCHexA(0xe6f2ec, .6));
    for (UILabel *l in [NSArray arrayWithObjects:_titleLabel, _messageLabel, _statusLabel, _footLabel, nil]) [v addSubview:l];
    _lamp = [[RCLampView alloc] initWithDiameter:9];
    [v addSubview:_lamp];
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    _spinner.hidesWhenStopped = YES;
    [v addSubview:_spinner];
    _signIn = [[RCButton buttonWithStyle:RCButtonStyleLargeGreen title:RCL(@"Log in")] retain];
    [_signIn addTarget:self action:@selector(signIn) forControlEvents:UIControlEventTouchUpInside];
    _signIn.accessibilityHint = RCL(@"Opens the ChatGPT login page");
    [v addSubview:_signIn];
    _signUp = [[RCButton buttonWithStyle:RCButtonStyleLargeDark title:RCL(@"Sign up")] retain];
    [_signUp addTarget:self action:@selector(signUp) forControlEvents:UIControlEventTouchUpInside];
    [v addSubview:_signUp];
    [self refresh];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (NSString *)defaultStatus {
    switch (_state) {
        case RCWelcomeChecking: return RCL(@"Checking the saved login…");
        case RCWelcomeError: return RCL(@"Could not log in. Try again.");
        case RCWelcomeSignedOut: return RCL(@"You logged out.");
        default: return nil;
    }
}

- (void)refresh {
    if (![self isViewLoaded]) return;
    _titleLabel.text = _appTitle;
    RCLabelSetText(_messageLabel, _message);
    RCLabelSetText(_footLabel, _footnote);
    NSString *status = _statusText.length ? _statusText : [self defaultStatus];
    RCLabelSetText(_statusLabel, status);
    _statusLabel.hidden = !status.length;
    BOOL checking = _state == RCWelcomeChecking;
    if (checking) [_spinner startAnimating]; else [_spinner stopAnimating];
    _lamp.hidden = !(_state == RCWelcomeError || _state == RCWelcomeSignedOut);
    _lamp.state = _state == RCWelcomeError ? RCLampError : RCLampInfo;
    _statusLabel.textColor = _state == RCWelcomeError ? RCHex(0xffd0c8) : RCHexA(0xe6f2ec, .9);
    _signIn.hidden = checking;
    _signUp.hidden = checking || !_signUpAvailable;
    [self.view setNeedsLayout];
    if (status.length) UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, _statusLabel);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width, h = self.view.bounds.size.height;
    BOOL tall = h > 500;
    CGRect lf = _logo.frame; lf.origin = CGPointMake(round((w - lf.size.width) / 2), [RCWelcomeViewController logoTopForHeight:h]); _logo.frame = lf;
    CGFloat y = CGRectGetMaxY(lf) + 14;
    _titleLabel.frame = CGRectMake(20, y, w - 40, 34); y += 40;
    CGFloat mh = RCMeasureText(_messageLabel.text, _messageLabel.font, w - 60).height;
    _messageLabel.frame = CGRectMake(30, y, w - 60, mh);
    CGFloat fh = RCMeasureText(_footLabel.text, _footLabel.font, w - 48).height;
    _footLabel.frame = CGRectMake(24, h - 16 - fh, w - 48, fh);
    CGFloat by = h - 16 - fh - (tall ? 30 : 18) - 44;
    if (!_signUp.hidden) { _signUp.frame = CGRectMake(20, by, w - 40, 44); by -= 54; }
    _signIn.frame = CGRectMake(20, by, w - 40, 44);
    CGFloat sh = _statusLabel.hidden ? 0 : RCMeasureText(_statusLabel.text, _statusLabel.font, w - 70).height;
    if (_state == RCWelcomeChecking) {
        _spinner.center = CGPointMake(w / 2, by + 6);
        _statusLabel.frame = CGRectMake(35, by + 26, w - 70, sh);
    } else {
        _statusLabel.frame = CGRectMake(44, by - 14 - sh, w - 70, sh);
        _lamp.center = CGPointMake(32, _statusLabel.frame.origin.y + 9);
    }
}

- (void)setState:(RCWelcomeState)state { _state = state; [self refresh]; }
- (void)setState:(RCWelcomeState)state text:(NSString *)text { _state = state; [_statusText release]; _statusText = [text copy]; [self refresh]; }
- (void)setStatusText:(NSString *)t { [_statusText release]; _statusText = [t copy]; [self refresh]; }
- (void)setAppTitle:(NSString *)t { [_appTitle release]; _appTitle = [t copy]; [self refresh]; }
- (void)setMessage:(NSString *)t { [_message release]; _message = [t copy]; [self refresh]; }
- (void)setFootnote:(NSString *)t { [_footnote release]; _footnote = [t copy]; [self refresh]; }
- (void)setSignUpAvailable:(BOOL)v { _signUpAvailable = v; [self refresh]; }

- (void)signIn { [_delegate welcomeDidTapSignIn:self]; }
- (void)signUp { if ([_delegate respondsToSelector:@selector(welcomeDidTapSignUp:)]) [_delegate welcomeDidTapSignUp:self]; }
@end
