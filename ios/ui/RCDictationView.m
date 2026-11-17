#import "RCDictationView.h"
#import "RCTheme.h"
#import <QuartzCore/QuartzCore.h> // headers only (layer messages), no QuartzCore link

static const int kBars = 18;

@interface RCRecDot : UIView @end
@implementation RCRecDot
- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    CGContextAddEllipseInRect(ctx, b); CGContextClip(ctx);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    NSArray *c = [NSArray arrayWithObjects:(id)RCHex(0xffd0c8).CGColor, (id)RCHex(0xff4a2c).CGColor, (id)RCHex(0xb8170a).CGColor, nil];
    CGFloat l[3] = {0, .45, 1};
    CGGradientRef g = CGGradientCreateWithColors(space, (CFArrayRef)c, l);
    CGPoint p = CGPointMake(b.size.width * .35, b.size.height * .3);
    CGContextDrawRadialGradient(ctx, g, p, 0, p, b.size.width * .8, kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(g); CGColorSpaceRelease(space);
}
@end

@interface RCDictationView () {
    RCRecDot *_dot; UILabel *_time, *_live, *_busy; UIView *_wave; UIActivityIndicatorView *_spin;
    RCButton *_cancel, *_done; NSTimer *_timer; NSString *_liveText, *_failureText; CGFloat _level; BOOL _hasLevel;
}
@end

@implementation RCDictationView
@synthesize state = _state, elapsed = _elapsed, cancelAvailable = _cancelAvailable, cancelsRecognition = _cancelsRecognition, cancelButton = _cancel, doneButton = _done;

- (id)initWithFrame:(CGRect)frame {
    if (frame.size.height < 1) frame = CGRectMake(0, 0, 308, 32);
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        _dot = [[RCRecDot alloc] initWithFrame:CGRectMake(4, 10, 12, 12)];
        _dot.opaque = NO; _dot.backgroundColor = [UIColor clearColor];
        [self addSubview:_dot];
        _time = [[UILabel alloc] initWithFrame:CGRectMake(22, 7, 40, 18)];
        _time.font = [UIFont boldSystemFontOfSize:14];
        _wave = [[UIView alloc] initWithFrame:CGRectZero];
        _wave.clipsToBounds = YES;
        for (int i = 0; i < kBars; i++) {
            UIView *b = [[[UIView alloc] initWithFrame:CGRectMake(i * 5, 10, 3, 4)] autorelease];
            b.backgroundColor = RCHex(0x2fae6c); b.layer.cornerRadius = 1.5;
            [_wave addSubview:b];
        }
        [self addSubview:_wave];
        _live = [[UILabel alloc] initWithFrame:CGRectZero];
        _live.font = [UIFont systemFontOfSize:13];
        _live.numberOfLines = 2;
        _busy = [[UILabel alloc] initWithFrame:CGRectZero];
        _busy.font = [UIFont boldSystemFontOfSize:14];
        _busy.numberOfLines = 2;
        for (UILabel *l in [NSArray arrayWithObjects:_time, _live, _busy, nil]) { l.backgroundColor = [UIColor clearColor]; [self addSubview:l]; }
        _spin = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        [self addSubview:_spin];
        _cancel = [[RCButton buttonWithStyle:RCButtonStylePill title:RCL(@"Cancel")] retain];
        _done = [[RCButton buttonWithStyle:RCButtonStylePillGo title:RCL(@"Done")] retain];
        [self addSubview:_cancel]; [self addSubview:_done];
        self.isAccessibilityElement = NO;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh) name:RCThemeAppearanceDidChangeNotification object:nil];
        [self refresh];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_timer invalidate];
    [_dot release]; [_time release]; [_live release]; [_busy release]; [_wave release]; [_spin release]; [_cancel release]; [_done release]; [_liveText release]; [_failureText release];
    [super dealloc];
}

- (NSString *)liveText { return _liveText; }
- (void)setLiveText:(NSString *)t { [_liveText release]; _liveText = [t copy]; [self refresh]; }
- (void)setState:(RCDictationState)s { _state = s; [self refresh]; }
- (void)setCancelAvailable:(BOOL)v { _cancelAvailable = v; [self refresh]; }
- (void)setCancelsRecognition:(BOOL)v { _cancelsRecognition = v; [self refresh]; }
- (NSString *)failureText { return _failureText; }
- (void)setFailureText:(NSString *)t { if (t == _failureText || [t isEqual:_failureText]) return; [_failureText release]; _failureText = [t copy]; [self refresh]; }
- (void)setElapsed:(NSTimeInterval)e { _elapsed = e; int s = (int)e; _time.text = [NSString stringWithFormat:@"%d:%02d", s / 60, s % 60]; _time.accessibilityLabel = [NSString stringWithFormat:RCL(@"Recording %@"), _time.text]; }
- (void)setLevel:(CGFloat)level { _level = MAX(0, MIN(1, level)); _hasLevel = YES; }

- (void)refresh {
    BOOL dark = [RCTheme isDark];
    UIColor *ink = dark ? RCHex(0xd8e4de) : RCHex(0x3f5249);
    _time.textColor = ink; _live.textColor = ink;
    BOOL rec = _state == RCDictationRecording, failed = _state == RCDictationFailed;
    _busy.textColor = failed ? (dark ? RCHex(0xff8c7f) : RCHex(0xa3261a)) : ink;
    _dot.hidden = _time.hidden = !rec;
    _wave.hidden = !rec || _liveText != nil;
    _live.hidden = !rec || _liveText == nil;
    _live.text = _liveText.length ? _liveText : RCL(@"Speak…");
    _busy.hidden = rec;
    RCLabelSetText(_busy, failed ? (_failureText.length ? _failureText : RCL(@"Not recognized. The recording is saved.")) : RCL(@"Recognizing…"));
    if (_state == RCDictationRecognising) [_spin startAnimating]; else [_spin stopAnimating];
    _cancel.hidden = !(_cancelAvailable && (rec || failed || (_cancelsRecognition && _state == RCDictationRecognising)));
    _done.hidden = _state == RCDictationRecognising;
    [_done setTitle:(failed ? RCL(@"Retry") : RCL(@"Done")) forState:UIControlStateNormal];
    [self setElapsed:_elapsed];
    [self updateMotion];
    [self setNeedsLayout];
}

- (void)didMoveToWindow { [super didMoveToWindow]; [self updateMotion]; }

- (void)updateMotion {
    BOOL want = _state == RCDictationRecording && self.window;
    [_dot.layer removeAllAnimations];
    _dot.alpha = 1;
    if (want) [UIView animateWithDuration:.5 delay:0 options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionCurveEaseInOut animations:^{ _dot.alpha = .45; } completion:nil];
    if (want && !_timer) _timer = [NSTimer scheduledTimerWithTimeInterval:.25 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    else if (!want && _timer) { [_timer invalidate]; _timer = nil; }
}

- (void)tick {
    for (UIView *b in _wave.subviews) {
        CGFloat amp = _hasLevel ? _level * (.4 + .6 * (arc4random() % 100) / 100.0) : (arc4random() % 100) / 100.0;
        CGFloat h = 3 + round(amp * 20);
        [UIView animateWithDuration:.1 animations:^{ b.frame = CGRectMake(b.frame.origin.x, floor((24 - h) / 2), 3, h); }];
    }
}

- (void)removeFromSuperview { [_timer invalidate]; _timer = nil; [super removeFromSuperview]; }

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    CGRect df = _done.frame; df.size.width = MAX(64, df.size.width);
    _done.frame = CGRectMake(w - df.size.width, 3, df.size.width, 26);
    CGRect cf = _cancel.frame;
    CGFloat cancelRight = _done.hidden ? 0 : 70; // alone at the right edge while recognising
    _cancel.frame = CGRectMake(w - cancelRight - cf.size.width, 3, cf.size.width, 26);
    CGFloat textRight = w - (_cancel.hidden ? (_done.hidden ? 0 : df.size.width + 8) : cancelRight + cf.size.width + 8);
    _wave.frame = CGRectMake(64, 4, MAX(0, w - 140 - 64), 24);
    _live.frame = CGRectMake(64, 0, MAX(0, textRight - 64), 32);
    BOOL spin = _state == RCDictationRecognising;
    _spin.frame = CGRectMake(4, 6, 20, 20);
    _busy.frame = CGRectMake(spin ? 30 : 4, 0, textRight - (spin ? 30 : 4), 32);
}
@end
