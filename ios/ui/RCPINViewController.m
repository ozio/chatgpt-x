#import "RCPINViewController.h"
#import "RCTheme.h"
#import <QuartzCore/QuartzCore.h> // headers only (layer messages)

// One keypad key (.keypad .k): white glossy, blue when pressed, blank keys grey.
@interface RCPINKey : UIControl { @public NSString *key; BOOL blank; }
@end
@implementation RCPINKey
- (id)initWithKey:(NSString *)k {
    if ((self = [super initWithFrame:CGRectZero])) {
        key = [k copy]; blank = !k.length;
        self.contentMode = UIViewContentModeRedraw;
        self.isAccessibilityElement = !blank;
        self.accessibilityLabel = [k isEqualToString:@"⌫"] ? RCL(@"Delete") : k;
        self.accessibilityTraits = UIAccessibilityTraitButton | UIAccessibilityTraitKeyboardKey;
        self.userInteractionEnabled = !blank;
    }
    return self;
}
- (void)dealloc { [key release]; [super dealloc]; }
- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    BOOL p = self.highlighted;
    if (blank) RCDrawVerticalGradient(ctx, b, [NSArray arrayWithObjects:RCHex(0x8e9498), RCHex(0x6a7074), nil], nil);
    else if (p) RCDrawVerticalGradient(ctx, b, [NSArray arrayWithObjects:RCHex(0x2f8bf1), RCHex(0x0d5ad9), nil], nil);
    else {
        RCDrawVerticalGradient(ctx, b, [NSArray arrayWithObjects:RCHex(0xfdfdfd), RCHex(0xd9dcde), nil], nil);
        CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
        CGContextFillRect(ctx, CGRectMake(0, 0, b.size.width, 1));
    }
    CGContextSetFillColorWithColor(ctx, RCHex(0x8a9094).CGColor);
    CGContextFillRect(ctx, CGRectMake(b.size.width - 1, 0, 1, b.size.height));
    CGContextFillRect(ctx, CGRectMake(0, b.size.height - 1, b.size.width, 1));
    if (blank) return;
    UIFont *f = [UIFont boldSystemFontOfSize:24];
    CGSize s = [key sizeWithFont:f];
    CGPoint at = CGPointMake(round((b.size.width - s.width) / 2), round((b.size.height - s.height) / 2));
    CGContextSetShadowWithColor(ctx, p ? CGSizeMake(0, -1) : CGSizeMake(0, 1), 0, (p ? [UIColor blackColor] : [UIColor whiteColor]).CGColor);
    [(p ? [UIColor whiteColor] : RCHex(0x222222)) set];
    [key drawAtPoint:at withFont:f];
}
@end

@interface RCPINViewController () {
    UILabel *_titleLabel, *_messageLabel;
    UIView *_boxes;
    NSMutableArray *_boxLabels;
    UIView *_keypad;
    NSMutableString *_entered;
    NSString *_first;     // Set: the first entry while confirming
    BOOL _confirming, _locked, _error, _checking;
    NSTimer *_lockTimer;
    NSDate *_lockUntil;
}
@end

@implementation RCPINViewController
@synthesize mode = _mode, titleText = _titleText, message = _message, failures = _failures, showsCancel = _showsCancel, delegate = _delegate, checking = _checking;

- (id)initWithMode:(RCPINMode)mode {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _mode = mode;
        _entered = [[NSMutableString alloc] init];
        _boxLabels = [[NSMutableArray alloc] init];
        _showsCancel = YES;
        self.title = mode == RCPINModeSet ? RCL(@"New PIN") : RCL(@"Locked chats");
    }
    return self;
}
- (id)initWithNibName:(NSString *)n bundle:(NSBundle *)b { return [self initWithMode:RCPINModeUnlock]; }

- (void)dealloc {
    [_lockTimer invalidate];
    [_titleLabel release]; [_messageLabel release]; [_boxes release]; [_boxLabels release]; [_keypad release];
    [_entered release]; [_first release]; [_titleText release]; [_message release]; [_lockUntil release];
    [super dealloc];
}

static UIImage *RCPINBoxImage(void) {
    return [RCTheme imageForKey:@"pin-box" size:CGSizeMake(52, 53) capInsets:UIEdgeInsetsZero drawing:^(CGContextRef ctx, CGRect b) {
        CGRect r = CGRectMake(.5, .5, 51, 51);
        CGPathRef p = RCCreateRoundedRectPath(r, 6);
        CGContextSaveGState(ctx); CGContextTranslateCTM(ctx, 0, 1);
        CGContextAddPath(ctx, p); CGContextSetStrokeColorWithColor(ctx, RCHexA(0xffffff, .2).CGColor); CGContextStrokePath(ctx);
        CGContextRestoreGState(ctx);
        CGContextSaveGState(ctx);
        CGContextAddPath(ctx, p); CGContextClip(ctx);
        CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor); CGContextFillRect(ctx, r);
        RCDrawVerticalGradient(ctx, CGRectMake(0, 0, 52, 5), [NSArray arrayWithObjects:RCHexA(0, .3), RCHexA(0, 0), nil], nil);
        CGContextRestoreGState(ctx);
        CGContextAddPath(ctx, p); CGContextSetStrokeColorWithColor(ctx, RCHex(0x0a2219).CGColor); CGContextStrokePath(ctx);
        CGPathRelease(p);
    }];
}

- (void)loadView {
    UIView *v = [[[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame] autorelease];
    v.backgroundColor = [RCTheme linenDarkColor];
    self.view = v;
    _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _titleLabel.backgroundColor = [UIColor clearColor];
    _titleLabel.font = [UIFont boldSystemFontOfSize:17];
    _titleLabel.textColor = RCHex(0xe6f2ec);
    _titleLabel.shadowColor = [UIColor blackColor]; _titleLabel.shadowOffset = CGSizeMake(0, -1);
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [v addSubview:_titleLabel];
    _boxes = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 4 * 52 + 3 * 12, 53)];
    _boxes.isAccessibilityElement = YES;
    _boxes.accessibilityTraits = UIAccessibilityTraitUpdatesFrequently;
    for (int i = 0; i < 4; i++) {
        UIImageView *box = [[[UIImageView alloc] initWithImage:RCPINBoxImage()] autorelease];
        box.frame = CGRectMake(i * 64, 0, 52, 53);
        [_boxes addSubview:box];
        UILabel *dot = [[[UILabel alloc] initWithFrame:CGRectMake(i * 64, 0, 52, 52)] autorelease];
        dot.backgroundColor = [UIColor clearColor];
        dot.font = [UIFont systemFontOfSize:30];
        dot.textColor = [RCTheme inkColor];
        dot.textAlignment = NSTextAlignmentCenter;
        [_boxes addSubview:dot];
        [_boxLabels addObject:dot];
    }
    [v addSubview:_boxes];
    _messageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _messageLabel.backgroundColor = [UIColor clearColor];
    _messageLabel.font = [UIFont systemFontOfSize:14];
    _messageLabel.shadowColor = [UIColor blackColor]; _messageLabel.shadowOffset = CGSizeMake(0, -1);
    _messageLabel.textAlignment = NSTextAlignmentCenter;
    [v addSubview:_messageLabel];
    _keypad = [[UIView alloc] initWithFrame:CGRectZero];
    _keypad.backgroundColor = RCHex(0x1d2124);
    NSArray *keys = [NSArray arrayWithObjects:@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @"", @"0", @"⌫", nil];
    for (NSUInteger i = 0; i < keys.count; i++) {
        RCPINKey *k = [[[RCPINKey alloc] initWithKey:[keys objectAtIndex:i]] autorelease];
        k.tag = (NSInteger)i;
        [k addTarget:self action:@selector(keyTapped:) forControlEvents:UIControlEventTouchDown];
        [_keypad addSubview:k];
    }
    [v addSubview:_keypad];
    [self refresh];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (_locked) { [self tick:nil]; [self startLockTimer]; } // the lock counts by the clock, also while hidden
    self.navigationItem.leftBarButtonItem = _showsCancel ? [[[UIBarButtonItem alloc] initWithTitle:RCL(@"Cancel") style:UIBarButtonItemStyleBordered target:self action:@selector(cancel)] autorelease] : nil;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width, h = self.view.bounds.size.height;
    CGFloat top = h > 400 ? 30 : 14;
    _titleLabel.frame = CGRectMake(10, top, w - 20, 22);
    CGRect bf = CGRectMake(round((w - 4 * 52 - 3 * 12) / 2), top + 38, 4 * 52 + 3 * 12, 53);
    _boxes.center = CGPointMake(CGRectGetMidX(bf), CGRectGetMidY(bf));
    _messageLabel.frame = CGRectMake(30, CGRectGetMaxY(bf) + 12, w - 60, 36);
    _keypad.frame = CGRectMake(0, h - 216, w, 216);
    for (RCPINKey *k in _keypad.subviews) {
        NSInteger i = k.tag, col = i % 3, row = i / 3;
        CGFloat x0 = round(w * col / 3), x1 = round(w * (col + 1) / 3);
        k.frame = CGRectMake(x0, 1 + row * 54, x1 - x0, 54);
    }
}

- (NSString *)currentTitle {
    if (_titleText.length) return _titleText;
    if (_mode == RCPINModeSet) return _confirming ? RCL(@"Repeat PIN") : RCL(@"Create a PIN");
    return RCL(@"Enter PIN");
}

- (void)refresh {
    if (![self isViewLoaded]) return;
    _titleLabel.text = [self currentTitle];
    for (NSUInteger i = 0; i < 4; i++) [(UILabel *)[_boxLabels objectAtIndex:i] setText:(i < _entered.length ? @"●" : @"")];
    _boxes.accessibilityLabel = [NSString stringWithFormat:RCL(@"%@: %d of 4 entered"), _titleLabel.text, (int)_entered.length];
    if (_checking && !_locked) {
        RCLabelSetText(_messageLabel, RCL(@"Checking…"));
        _messageLabel.textColor = RCHexA(0xe6f2ec, .8);
    } else if (!_error && !_locked) {
        RCLabelSetText(_messageLabel, _message);
        _messageLabel.textColor = RCHexA(0xe6f2ec, .8);
    }
    _keypad.userInteractionEnabled = !_locked && !_checking;
    _keypad.alpha = _locked || _checking ? .6 : 1;
}

- (void)setTitleText:(NSString *)t { [_titleText release]; _titleText = [t copy]; [self refresh]; }
- (void)setMessage:(NSString *)m { [_message release]; _message = [m copy]; [self refresh]; }

- (void)reset { [_entered setString:@""]; _confirming = NO; [_first release]; _first = nil; _error = NO; _checking = NO; [self refresh]; }
- (void)setChecking:(BOOL)c {
    if (c == _checking) return;
    _checking = c; [self refresh];
    if (c) UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, RCL(@"Checking…"));
}

- (void)keyTapped:(RCPINKey *)k {
    if (_locked || _checking) return;
    if ([k->key isEqualToString:@"⌫"]) { if (_entered.length) [_entered deleteCharactersInRange:NSMakeRange(_entered.length - 1, 1)]; [self refresh]; return; }
    if (_entered.length >= 4) return;
    [_entered appendString:k->key];
    [self refresh];
    if (_entered.length == 4) [self performSelector:@selector(complete) withObject:nil afterDelay:.15];
}

- (void)complete {
    NSString *pin = [[_entered copy] autorelease];
    if (_mode == RCPINModeSet) {
        if (!_confirming) { _first = [pin copy]; _confirming = YES; [_entered setString:@""]; _error = NO; [self refresh]; return; }
        if ([pin isEqualToString:_first]) {
            if ([_delegate respondsToSelector:@selector(pinController:didSetPIN:)]) [_delegate pinController:self didSetPIN:pin];
            return;
        }
        [_first release]; _first = nil; _confirming = NO;
        [self showError:RCL(@"The PINs do not match. Create the PIN again.")];
        return;
    }
    if ([_delegate pinController:self checkPIN:pin]) return;
    _failures++;
    [self showError:RCL(@"Wrong PIN")];
}

- (void)showError:(NSString *)text {
    [_entered setString:@""];
    _error = YES; _checking = NO;
    [self refresh];
    _messageLabel.textColor = RCHex(0xffd0c8);
    RCLabelSetText(_messageLabel, text);
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, text);
    // @keyframes shake: ±10 pt, .4 s (a transform, so layout may run meanwhile)
    void (^move)(CGFloat) = ^(CGFloat dx) { _boxes.transform = CGAffineTransformMakeTranslation(dx, 0); };
    [UIView animateWithDuration:.08 animations:^{ move(-10); } completion:^(BOOL a) {
        [UIView animateWithDuration:.08 animations:^{ move(10); } completion:^(BOOL b) {
            [UIView animateWithDuration:.08 animations:^{ move(-10); } completion:^(BOOL c) {
                [UIView animateWithDuration:.08 animations:^{ move(10); } completion:^(BOOL d) {
                    [UIView animateWithDuration:.08 animations:^{ move(0); }];
                }];
            }];
        }];
    }];
}

- (void)lockForSeconds:(NSUInteger)seconds {
    [_lockTimer invalidate]; _lockTimer = nil;
    [_lockUntil release]; _lockUntil = seconds ? [[NSDate dateWithTimeIntervalSinceNow:seconds] retain] : nil;
    _locked = seconds > 0; _checking = NO; [_entered setString:@""];
    [self tick:nil];
    [self startLockTimer];
}
- (void)startLockTimer {
    if (_locked && !_lockTimer && self.isViewLoaded && self.view.window) _lockTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
}

- (void)tick:(NSTimer *)t {
    (void)t;
    NSTimeInterval left = _lockUntil ? ceil([_lockUntil timeIntervalSinceNow]) : 0;
    if (left <= 0) { [_lockTimer invalidate]; _lockTimer = nil; [_lockUntil release]; _lockUntil = nil; _locked = NO; _error = NO; [self refresh]; return; }
    _messageLabel.textColor = RCHex(0xffd0c8);
    NSString *text = left >= 60 ? [NSString stringWithFormat:RCL(@"Too many attempts. Try again in %d min"), (int)ceil(left / 60)]
                                : [NSString stringWithFormat:RCL(@"Too many attempts. Try again in %d s"), (int)left];
    RCLabelSetText(_messageLabel, text);
    [self refresh];
}

- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [NSObject cancelPreviousPerformRequestsWithTarget:self]; }
- (void)viewDidDisappear:(BOOL)animated { [super viewDidDisappear:animated]; [_lockTimer invalidate]; _lockTimer = nil; }

- (void)cancel { if ([_delegate respondsToSelector:@selector(pinControllerDidCancel:)]) [_delegate pinControllerDidCancel:self]; else [self.presentingViewController dismissViewControllerAnimated:YES completion:nil]; }
@end
