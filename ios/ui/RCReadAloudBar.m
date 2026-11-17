#import "RCReadAloudBar.h"
#import <QuartzCore/QuartzCore.h> // headers only (layer messages), no QuartzCore link
#import "RCTheme.h"
#import "RCGlyph.h"
#import "RCButton.h"

// Graphite glass strip. Metrics: 44pt minimum (grows with text size or wrapped
// failure text); 34pt convex knob in a 44pt target; 26pt capsules with 44pt-tall
// hit areas; 4pt progress groove; 3pt drop shadow below the strip.
static const CGFloat kKnob = 34, kGroove = 4, kSpeedW = 42, kCloseW = 32, kPillH = 26, kShadowH = 3;

static UIColor *RCRABlend(UIColor *a, UIColor *b, CGFloat t) {
    CGFloat r1 = 0, g1 = 0, b1 = 0, a1 = 1, r2 = 0, g2 = 0, b2 = 0, a2 = 1;
    [a getRed:&r1 green:&g1 blue:&b1 alpha:&a1]; [b getRed:&r2 green:&g2 blue:&b2 alpha:&a2];
    return [UIColor colorWithRed:r1 + (r2 - r1) * t green:g1 + (g2 - g1) * t blue:b1 + (b2 - b1) * t alpha:a1 + (a2 - a1) * t];
}

// White glyph with the dark-bar engraving (black shadow one point above).
static UIImage *RCRAGlyph(NSString *name, CGFloat size, CGFloat dx) {
    NSString *key = [NSString stringWithFormat:@"readaloud-glyph-%@-%g-%g", name, size, dx];
    return [RCTheme imageForKey:key size:CGSizeMake(size + 2, size + 2) capInsets:UIEdgeInsetsZero drawing:^(CGContextRef c, CGRect r) {
        (void)c; (void)r;
        [RCGlyph drawGlyph:name inRect:CGRectMake(1 + dx, 0, size, size) color:RCHexA(0, .6)];
        [RCGlyph drawGlyph:name inRect:CGRectMake(1 + dx, 1, size, size) color:[RCTheme readAloudInkColor]];
    }];
}

static UIImage *RCRACloseGlyph(void) {
    return [RCTheme imageForKey:@"readaloud-close" size:CGSizeMake(12, 13) capInsets:UIEdgeInsetsZero drawing:^(CGContextRef c, CGRect r) {
        (void)r; CGContextSetLineCap(c, kCGLineCapRound); CGContextSetLineWidth(c, 2);
        for (int pass = 0; pass < 2; pass++) {
            CGFloat y = pass ? 1 : 0;
            CGContextSetStrokeColorWithColor(c, pass ? [RCTheme readAloudInkColor].CGColor : RCHexA(0, .6).CGColor);
            CGContextMoveToPoint(c, 2, 2 + y); CGContextAddLineToPoint(c, 10, 10 + y);
            CGContextMoveToPoint(c, 10, 2 + y); CGContextAddLineToPoint(c, 2, 10 + y);
            CGContextStrokePath(c);
        }
    }];
}

// Convex round knob (pressed: concave), seated in the glass by a light lower lip.
static UIImage *RCRAKnob(BOOL pressed) {
    NSString *key = [NSString stringWithFormat:@"readaloud-knob-%d-%d", pressed, [RCTheme isDark]];
    return [RCTheme imageForKey:key size:CGSizeMake(44, 44) capInsets:UIEdgeInsetsZero drawing:^(CGContextRef c, CGRect r) {
        (void)r; CGFloat o = (44 - kKnob) / 2;
        CGRect ring = CGRectMake(o, o, kKnob, kKnob), body = CGRectInset(ring, 1, 1);
        CGContextSetFillColorWithColor(c, RCHexA(0xffffff, .14).CGColor); CGContextFillEllipseInRect(c, CGRectOffset(ring, 0, 1));
        CGContextSetFillColorWithColor(c, [RCTheme readAloudStrokeColor].CGColor); CGContextFillEllipseInRect(c, ring);
        CGContextSaveGState(c); CGContextAddEllipseInRect(c, body); CGContextClip(c);
        NSArray *colors = pressed ? [NSArray arrayWithObjects:RCHex(0x23292c), RCHex(0x485055), nil]
                                  : [NSArray arrayWithObjects:RCHex(0x89939a), RCHex(0x555e64), RCHex(0x3a4146), nil];
        RCDrawVerticalGradient(c, body, colors, nil);
        if (!pressed) { // glass sheen on the upper half
            CGContextSetFillColorWithColor(c, RCHexA(0xffffff, .16).CGColor);
            CGContextFillEllipseInRect(c, CGRectMake(body.origin.x + 3, body.origin.y + 1, body.size.width - 6, body.size.height * .55));
        } else {
            CGContextSetShadowWithColor(c, CGSizeMake(0, 1), 3, RCHexA(0, .7).CGColor);
            CGContextSetStrokeColorWithColor(c, RCHexA(0, .5).CGColor); CGContextSetLineWidth(c, 2);
            CGContextStrokeEllipseInRect(c, CGRectInset(body, -1, -1));
        }
        CGContextRestoreGState(c);
    }];
}

static UIImage *RCRAGroove(void) {
    NSString *key = [NSString stringWithFormat:@"readaloud-groove-%d", [RCTheme isDark]];
    return [RCTheme imageForKey:key size:CGSizeMake(8, kGroove + 1) capInsets:UIEdgeInsetsMake(0, 3, 0, 3) drawing:^(CGContextRef c, CGRect r) {
        CGRect g = CGRectMake(0, 0, r.size.width, kGroove);
        CGPathRef lip = RCCreateRoundedRectPath(CGRectOffset(g, 0, 1), kGroove / 2);
        CGContextAddPath(c, lip); CGContextSetFillColorWithColor(c, RCHexA(0xffffff, .13).CGColor); CGContextFillPath(c); CGPathRelease(lip);
        CGPathRef p = RCCreateRoundedRectPath(g, kGroove / 2);
        CGContextAddPath(c, p); CGContextSetFillColorWithColor(c, [RCTheme readAloudGrooveColor].CGColor); CGContextFillPath(c); CGPathRelease(p);
    }];
}

static UIImage *RCRAFill(void) {
    return [RCTheme imageForKey:@"readaloud-fill" size:CGSizeMake(8, kGroove) capInsets:UIEdgeInsetsMake(0, 3, 0, 3) drawing:^(CGContextRef c, CGRect r) {
        CGPathRef p = RCCreateRoundedRectPath(r, kGroove / 2);
        CGContextAddPath(c, p); CGContextClip(c); CGPathRelease(p);
        RCDrawVerticalGradient(c, r, [NSArray arrayWithObjects:[RCTheme readAloudFillColor], RCHex(0xbfc8cd), nil], nil);
    }];
}

static UIImage *RCRAShadow(void) {
    return [RCTheme imageForKey:@"readaloud-shadow" size:CGSizeMake(1, kShadowH) capInsets:UIEdgeInsetsZero drawing:^(CGContextRef c, CGRect r) {
        RCDrawVerticalGradient(c, r, [NSArray arrayWithObjects:RCHexA(0, .38), RCHexA(0, 0), nil], nil);
    }];
}

// Capsules are 26pt tall; their independent hit areas remain 44pt tall.
@interface RCReadAloudPill : RCButton
@end
@implementation RCReadAloudPill
- (BOOL)pointInside:(CGPoint)p withEvent:(UIEvent *)event { (void)event; return self.enabled && CGRectContainsPoint(CGRectInset(self.bounds, -MAX(0, (44 - self.bounds.size.width) / 2), -9), p); }
@end

@interface RCReadAloudGlass : UIView
@end
@implementation RCReadAloudGlass
- (void)drawRect:(CGRect)rect {
    (void)rect; CGContextRef c = UIGraphicsGetCurrentContext(); CGRect b = self.bounds; CGFloat px = 1 / UIScreen.mainScreen.scale;
    UIColor *top = [RCTheme readAloudTopColor], *bottom = [RCTheme readAloudBottomColor];
    RCDrawVerticalGradient(c, b, [NSArray arrayWithObjects:top, RCRABlend(top, bottom, .42), RCRABlend(top, bottom, .6), bottom, nil],
                           [NSArray arrayWithObjects:[NSNumber numberWithFloat:0], [NSNumber numberWithFloat:.5], [NSNumber numberWithFloat:.502], [NSNumber numberWithFloat:1], nil]);
    CGContextSetFillColorWithColor(c, RCHexA(0xffffff, [RCTheme isDark] ? .16 : .26).CGColor); CGContextFillRect(c, CGRectMake(0, 0, b.size.width, px));
    CGContextSetFillColorWithColor(c, [RCTheme readAloudStrokeColor].CGColor); CGContextFillRect(c, CGRectMake(0, b.size.height - px, b.size.width, px));
}
@end

// Three-bar level meter: bounces while playing, rests low when paused.
// UIView repeat/autoreverse animations only (the kit links no QuartzCore).
@interface RCReadAloudMeter : UIView { UIView *_bars[3]; BOOL _animating, _bouncing; }
@property(nonatomic, assign) BOOL animating;
@end
@implementation RCReadAloudMeter
@synthesize animating = _animating;
- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.userInteractionEnabled = NO; self.isAccessibilityElement = NO; self.backgroundColor = UIColor.clearColor;
        for (int i = 0; i < 3; i++) { _bars[i] = [[UIView alloc] initWithFrame:CGRectZero]; _bars[i].backgroundColor = [RCTheme readAloudInkColor]; [self addSubview:_bars[i]]; }
    } return self;
}
- (CGRect)barFrame:(int)i level:(CGFloat)level { CGFloat h = self.bounds.size.height, b = MAX(2, round(h * level)); return CGRectMake(i * 4.25, h - b, 2.5, b); }
- (void)rest {
    static const CGFloat rest[3] = {.45, .8, .3};
    _bouncing = NO;
    for (int i = 0; i < 3; i++) { [_bars[i].layer removeAllAnimations]; _bars[i].frame = [self barFrame:i level:rest[i]]; }
}
- (void)bounce {
    static const CGFloat from[3] = {.3, .95, .25}, to[3] = {1, .35, .9}; static const NSTimeInterval period[3] = {.42, .56, .36};
    if (_bouncing || self.bounds.size.height <= 0) return;
    _bouncing = YES;
    for (int i = 0; i < 3; i++) {
        [_bars[i].layer removeAllAnimations]; _bars[i].frame = [self barFrame:i level:from[i]];
        UIView *bar = _bars[i]; CGRect end = [self barFrame:i level:to[i]];
        [UIView animateWithDuration:period[i] delay:0 options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction animations:^{ bar.frame = end; } completion:nil];
    }
}
- (void)layoutSubviews { [super layoutSubviews]; BOOL b = _bouncing; [self rest]; if (b || (_animating && self.window)) [self bounce]; }
- (void)setAnimating:(BOOL)animating { if (_animating == animating && (_bouncing == (animating && self.window != nil))) return; _animating = animating; if (animating && self.window) [self bounce]; else [self rest]; }
- (void)didMoveToWindow { [super didMoveToWindow]; [self rest]; if (_animating && self.window) [self bounce]; }
- (void)dealloc { for (int i = 0; i < 3; i++) [_bars[i] release]; [super dealloc]; }
@end

@interface RCReadAloudBar () {
    UIView *_clip; RCReadAloudGlass *_glass; UIImageView *_shadow, *_groove, *_fill;
    UILabel *_status, *_time; UIButton *_play; RCButton *_speed, *_close; UIActivityIndicatorView *_spinner; RCReadAloudMeter *_meter;
    NSString *_failure; BOOL _presented; CGFloat _fraction, _reportedHeight;
}
@end

@implementation RCReadAloudBar
@synthesize delegate = _delegate, state = _state, busy = _busy, position = _position, duration = _duration, rate = _rate, rateAvailable = _rateAvailable, presented = _presented;
+ (NSTimeInterval)presentationDuration { return .3; }
- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _rate = 1; _rateAvailable = YES; _presented = YES; self.backgroundColor = UIColor.clearColor;
        _shadow = [[UIImageView alloc] initWithImage:RCRAShadow()]; _shadow.userInteractionEnabled = NO; [self addSubview:_shadow];
        _clip = [[UIView alloc] initWithFrame:CGRectZero]; _clip.clipsToBounds = YES; _clip.backgroundColor = UIColor.clearColor; [self addSubview:_clip];
        _glass = [[RCReadAloudGlass alloc] initWithFrame:CGRectZero]; _glass.contentMode = UIViewContentModeRedraw; [_clip addSubview:_glass];
        _play = [[UIButton buttonWithType:UIButtonTypeCustom] retain]; _play.adjustsImageWhenHighlighted = NO;
        [_play addTarget:self action:@selector(playTapped) forControlEvents:UIControlEventTouchUpInside]; [_glass addSubview:_play];
        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite]; _spinner.hidesWhenStopped = YES; [_glass addSubview:_spinner];
        _meter = [[RCReadAloudMeter alloc] initWithFrame:CGRectZero]; [_glass addSubview:_meter];
        _status = [[UILabel alloc] initWithFrame:CGRectZero]; _status.backgroundColor = UIColor.clearColor;
        _status.shadowColor = RCHexA(0, .6); _status.shadowOffset = CGSizeMake(0, -1); [_glass addSubview:_status];
        _time = [[UILabel alloc] initWithFrame:CGRectZero]; _time.backgroundColor = UIColor.clearColor; _time.textAlignment = NSTextAlignmentRight;
        _time.shadowColor = RCHexA(0, .55); _time.shadowOffset = CGSizeMake(0, -1); _time.isAccessibilityElement = NO; [_glass addSubview:_time];
        _groove = [[UIImageView alloc] initWithFrame:CGRectZero]; _fill = [[UIImageView alloc] initWithFrame:CGRectZero];
        [_glass addSubview:_groove]; [_glass addSubview:_fill];
        _speed = [[RCReadAloudPill buttonWithStyle:RCButtonStylePillDark title:RCL(@"1×")] retain]; _speed.contentEdgeInsets = UIEdgeInsetsZero;
        [_speed addTarget:self action:@selector(speedTapped) forControlEvents:UIControlEventTouchUpInside]; [_glass addSubview:_speed];
        _close = [[RCReadAloudPill buttonWithStyle:RCButtonStylePillDark title:nil] retain]; _close.contentEdgeInsets = UIEdgeInsetsZero; _close.adjustsImageWhenHighlighted = NO;
        [_close setImage:RCRACloseGlyph() forState:UIControlStateNormal];
        [_close addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside]; [_glass addSubview:_close];
        _play.accessibilityIdentifier = @"chat.read_aloud.play"; _speed.accessibilityIdentifier = @"chat.read_aloud.rate"; _close.accessibilityIdentifier = @"chat.read_aloud.close";
        NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
        [nc addObserver:self selector:@selector(lookChanged:) name:RCThemeAppearanceDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(lookChanged:) name:RCThemeTextSizeDidChangeNotification object:nil];
        [self refresh];
    } return self;
}
- (UIButton *)playButton { return _play; }
- (UIButton *)speedButton { return _speed; }
- (UIButton *)closeButton { return _close; }
- (NSString *)failureText { return _failure; }
- (void)setFailureText:(NSString *)text { if (_failure == text || [_failure isEqual:text]) return; [_failure release]; _failure = [text copy]; [self refresh]; }
- (void)setState:(RCPlaybackState)s { if (_state == s) return; _state = s; [self refresh]; }
- (void)setBusy:(BOOL)b { if (_busy == b) return; _busy = b; [self refresh]; }
- (void)setPosition:(NSTimeInterval)p { if (_position == p) return; _position = p; [self refresh]; }
- (void)setDuration:(NSTimeInterval)d { if (_duration == d) return; _duration = d; [self refresh]; }
- (void)setRate:(double)r { if (_rate == r) return; _rate = r; [self refresh]; }
- (void)setRateAvailable:(BOOL)b { if (_rateAvailable == b) return; _rateAvailable = b; [self refresh]; }
- (void)lookChanged:(NSNotification *)n { (void)n; [_glass setNeedsDisplay]; [self refresh]; }

- (void)setPresented:(BOOL)presented animated:(BOOL)animated {
    if (_presented == presented) return;
    _presented = presented; self.userInteractionEnabled = presented; self.accessibilityElementsHidden = !presented;
    _meter.animating = presented && !_busy && _state == RCPlaybackPlaying;
    [self setNeedsLayout];
    void (^change)(void) = ^{ [self layoutIfNeeded]; _shadow.alpha = _presented ? 1 : 0; };
    if (animated && self.window)
        [UIView animateWithDuration:[RCReadAloudBar presentationDuration] delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveEaseInOut animations:change completion:nil];
    else change();
    if (presented) UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
}

- (NSString *)phaseText {
    if (_busy) return RCL(@"Preparing…");
    switch (_state) {
        case RCPlaybackPlaying: return RCL(@"Reading aloud");
        case RCPlaybackPaused: return RCL(@"Paused");
        case RCPlaybackStopped: return RCL(@"Stopped");
        case RCPlaybackFailed: return _failure.length ? _failure : RCL(@"Could not play.");
        default: return RCL(@"Ready to play");
    }
}
- (BOOL)failed { return !_busy && _state == RCPlaybackFailed; }
- (NSString *)timeString {
    if (_busy || [self failed]) return @"";
    NSString *pos = [RCPlaybackView timeText:_position];
    return _duration > 0 ? [NSString stringWithFormat:@"%@ / %@", pos, [RCPlaybackView timeText:_duration]] : pos;
}
- (CGFloat)targetFraction {
    if (_busy || _duration <= 0) return 0;
    if (_state == RCPlaybackStopped && _position <= 0) return 1;
    return MAX(0, MIN(1, _position / _duration));
}

- (void)refresh {
    BOOL failed = [self failed];
    NSString *phase = [self phaseText], *time = [self timeString];
    UIFont *body = [RCTheme bodyFont];
    _status.font = [UIFont boldSystemFontOfSize:MAX(12, body.pointSize - 3)];
    _status.textColor = failed ? [RCTheme readAloudFailureInkColor] : [RCTheme readAloudInkColor];
    _status.numberOfLines = failed ? 0 : 1; _status.lineBreakMode = failed ? NSLineBreakByWordWrapping : NSLineBreakByTruncatingTail;
    RCLabelSetText(_status, RCDisplayText(phase));
    _status.accessibilityLabel = time.length ? [NSString stringWithFormat:@"%@, %@", phase, time] : phase;
    _time.font = [UIFont systemFontOfSize:MAX(11, body.pointSize - 5)]; _time.textColor = [RCTheme readAloudSecondaryInkColor]; _time.text = time; _time.hidden = !time.length;

    NSString *glyph = failed ? @"regen" : _state == RCPlaybackPlaying ? @"pause" : @"play";
    [_play setBackgroundImage:RCRAKnob(NO) forState:UIControlStateNormal];
    [_play setBackgroundImage:RCRAKnob(YES) forState:UIControlStateHighlighted];
    [_play setImage:_busy ? nil : RCRAGlyph(glyph, 16, [glyph isEqual:@"play"] ? 1 : 0) forState:UIControlStateNormal];
    _play.accessibilityLabel = failed ? RCL(@"Retry") : _state == RCPlaybackPlaying ? RCL(@"Pause") : _state == RCPlaybackPaused ? RCL(@"Resume") : RCL(@"Listen");
    _play.enabled = !_busy;
    if (_busy) [_spinner startAnimating]; else [_spinner stopAnimating];

    _meter.hidden = _busy || failed || (_state != RCPlaybackPlaying && _state != RCPlaybackPaused);
    _meter.animating = _presented && !_meter.hidden && _state == RCPlaybackPlaying;
    _groove.image = RCRAGroove(); _fill.image = RCRAFill(); _groove.hidden = _fill.hidden = failed;

    NSString *rate = fabs(_rate - .5) < .01 ? RCL(@"0.5×") : fabs(_rate - 1.5) < .01 ? RCL(@"1.5×") : fabs(_rate - 2) < .01 ? RCL(@"2×") : RCL(@"1×");
    [_speed setTitle:rate forState:UIControlStateNormal]; _speed.accessibilityLabel = RCL(@"Playback speed"); _speed.accessibilityValue = rate;
    _speed.hidden = !_rateAvailable; _speed.enabled = !_busy;
    _close.accessibilityLabel = RCL(@"Close player"); _close.accessibilityHint = RCL(@"Stops reading aloud");

    // Elapsed time moves the fill smoothly across the one-second status ticks.
    CGFloat target = [self targetFraction];
    BOOL glide = _state == RCPlaybackPlaying && !_busy && self.window && target > _fraction && target - _fraction < .3;
    _fraction = target;
    if (glide) [UIView animateWithDuration:1 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionCurveLinear | UIViewAnimationOptionAllowUserInteraction animations:^{ [self layoutFill]; } completion:nil];
    else [self layoutFill];

    [self setNeedsLayout];
    CGFloat h = [self heightForWidth:self.bounds.size.width > 0 ? self.bounds.size.width : 320];
    if (h != _reportedHeight) { BOOL first = _reportedHeight == 0; _reportedHeight = h; if (!first && [_delegate respondsToSelector:@selector(readAloudBarDidChangeHeight:)]) [_delegate readAloudBarDidChangeHeight:self]; }
}

- (CGFloat)rightInset:(CGFloat)width { (void)width; return 8 + kCloseW + (_rateAvailable ? 6 + kSpeedW : 0) + 10; }
- (CGFloat)middleWidth:(CGFloat)width { return MAX(40, width - 48 - [self rightInset:width]); }
- (CGFloat)titleLineHeight { return ceil(_status.font.lineHeight); }
- (CGFloat)heightForWidth:(CGFloat)width {
    if ([self failed]) return MAX(44, ceil(RCMeasureText(_status.text, _status.font, [self middleWidth:width]).height) + 16);
    return MAX(44, 7 + [self titleLineHeight] + 6 + kGroove + 1 + 8);
}

- (void)layoutFill {
    CGRect g = _groove.frame; CGFloat w = round((g.size.width) * _fraction);
    _fill.frame = CGRectMake(g.origin.x, g.origin.y, w < kGroove && _fraction > 0 ? kGroove : w, kGroove);
    _fill.alpha = _fraction > 0 ? 1 : 0;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width, h = self.bounds.size.height, H = [self heightForWidth:w];
    _clip.frame = self.bounds;
    _glass.frame = CGRectMake(0, _presented ? h - H : -H, w, H);
    _shadow.frame = CGRectMake(0, h, w, kShadowH); _shadow.alpha = _presented && h > 0 ? 1 : 0;
    _play.frame = CGRectMake(2, round((H - 44) / 2), 44, 44); _spinner.center = _play.center;
    CGFloat cx = w - 8 - kCloseW, py = round((H - kPillH) / 2);
    _close.frame = CGRectMake(cx, py, kCloseW, kPillH);
    _speed.frame = CGRectMake(cx - 6 - kSpeedW, py, kSpeedW, kPillH);
    CGFloat x = 50, mw = [self middleWidth:w];
    if ([self failed]) { _status.frame = CGRectMake(x, 8, mw, H - 16); return; }
    CGFloat lh = [self titleLineHeight], ty = 7;
    CGFloat tw = _time.hidden ? 0 : ceil([_time.text sizeWithFont:_time.font].width);
    _time.frame = CGRectMake(x + mw - tw, ty + lh - ceil(_time.font.lineHeight) - 1, tw, ceil(_time.font.lineHeight));
    CGFloat sx = x;
    if (!_meter.hidden) { CGFloat mh = MIN(11, round(lh * .62)); _meter.frame = CGRectMake(x, ty + lh - mh - round(lh * .18), 11, mh); sx += 16; }
    _status.frame = CGRectMake(sx, ty, MAX(10, x + mw - sx - (tw ? tw + 6 : 0)), lh);
    _groove.frame = CGRectMake(x, ty + lh + 6, mw, kGroove + 1);
    [self layoutFill];
}

- (void)playTapped { if (_busy) return; if (_state == RCPlaybackFailed) [_delegate readAloudBarDidTapRetry:self]; else if (_state == RCPlaybackPlaying) [_delegate readAloudBarDidTapPause:self]; else [_delegate readAloudBarDidTapPlay:self]; }
- (void)speedTapped { static const double rates[] = {1, 1.5, 2, .5}; NSUInteger n = 0; for (NSUInteger i = 0; i < 4; i++) if (fabs(_rate - rates[i]) < .01) n = i; [_delegate readAloudBar:self didChooseRate:rates[(n + 1) % 4]]; }
- (void)closeTapped { [_delegate readAloudBarDidClose:self]; }
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [_shadow release]; [_clip release]; [_glass release]; [_groove release]; [_fill release]; [_play release]; [_speed release]; [_close release];
    [_status release]; [_time release]; [_spinner release]; [_meter release]; [_failure release]; [super dealloc];
}
@end
