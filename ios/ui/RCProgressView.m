#import "RCProgressView.h"
#import "RCTheme.h"
#import <QuartzCore/QuartzCore.h> // headers only (layer messages), no QuartzCore link

@interface RCProgressFill : UIView { @public RCProgressTint _tint; BOOL _striped; }
@end
@implementation RCProgressFill
- (id)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) { self.opaque = NO; self.backgroundColor = [UIColor clearColor]; self.contentMode = UIViewContentModeRedraw; } return self; }
- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    if (b.size.width < 1) return;
    CGFloat r = b.size.height / 2;
    CGPathRef p = RCCreateRoundedRectPath(b, r);
    CGContextSaveGState(ctx);
    CGContextAddPath(ctx, p); CGContextClip(ctx);
    if (_striped) {
        // repeating-linear-gradient(-45deg, #2fae6c 0 6px, #93e2b8 6px 12px)
        CGContextSetFillColorWithColor(ctx, RCHex(0x2fae6c).CGColor); CGContextFillRect(ctx, b);
        CGContextSetFillColorWithColor(ctx, RCHex(0x93e2b8).CGColor);
        for (CGFloat x = -b.size.height; x < b.size.width + b.size.height; x += 12) {
            CGContextMoveToPoint(ctx, x, b.size.height); CGContextAddLineToPoint(ctx, x + 6, b.size.height);
            CGContextAddLineToPoint(ctx, x + 6 + b.size.height, 0); CGContextAddLineToPoint(ctx, x + b.size.height, 0);
            CGContextClosePath(ctx);
        }
        CGContextFillPath(ctx);
    } else {
        BOOL amber = _tint == RCProgressAmber;
        NSArray *c = amber ? [NSArray arrayWithObjects:RCHex(0xffe39b), RCHex(0xf6b52c), RCHex(0xe59c0c), RCHex(0xeda81a), nil]
                           : [NSArray arrayWithObjects:RCHex(0xa6ecc4), RCHex(0x42bb7a), RCHex(0x27a463), RCHex(0x33ad6c), nil];
        NSArray *l = [NSArray arrayWithObjects:[NSNumber numberWithFloat:0], [NSNumber numberWithFloat:.5], [NSNumber numberWithFloat:.51], [NSNumber numberWithFloat:1], nil];
        RCDrawVerticalGradient(ctx, b, c, l);
        CGContextSetFillColorWithColor(ctx, RCHexA(0xffffff, .5).CGColor);
        CGContextFillRect(ctx, CGRectMake(0, 0, b.size.width, 1));
        CGContextRestoreGState(ctx);
        CGContextAddPath(ctx, p);
        CGContextSetStrokeColorWithColor(ctx, RCHexA(amber ? 0x8c5000 : 0x0a5a28, .35).CGColor);
        CGContextSetLineWidth(ctx, 1);
        CGContextStrokePath(ctx);
        CGPathRelease(p);
        return;
    }
    CGContextRestoreGState(ctx);
    CGPathRelease(p);
}
@end

@interface RCProgressView () { RCProgressFill *_fill; UIView *_clip; BOOL _moving; }
@end

@implementation RCProgressView
@synthesize progress = _progress, tint = _tint, indeterminate = _indeterminate;

- (id)initWithFrame:(CGRect)frame {
    if (frame.size.height < 1) frame.size.height = 9;
    if ((self = [super initWithFrame:frame])) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        _clip = [[UIView alloc] initWithFrame:self.bounds];
        _clip.clipsToBounds = YES;
        _clip.layer.cornerRadius = frame.size.height / 2;
        _clip.userInteractionEnabled = NO;
        [self addSubview:_clip];
        _fill = [[RCProgressFill alloc] initWithFrame:CGRectZero];
        [_clip addSubview:_fill];
        self.isAccessibilityElement = YES;
        self.accessibilityTraits = UIAccessibilityTraitUpdatesFrequently;
    }
    return self;
}
- (void)dealloc { [_fill release]; [_clip release]; [super dealloc]; }

- (void)setTint:(RCProgressTint)t { _tint = t; _fill->_tint = t; [_fill setNeedsDisplay]; }
- (void)setProgress:(CGFloat)p { [self setProgress:p animated:NO]; }
- (void)setProgress:(CGFloat)p animated:(BOOL)animated {
    _progress = MAX(0, MIN(1, p));
    self.accessibilityValue = [NSString stringWithFormat:@"%d %%", (int)lround(_progress * 100)];
    if (animated && !_indeterminate) [UIView animateWithDuration:.35 delay:0 options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionBeginFromCurrentState animations:^{ [self layoutFill]; } completion:nil];
    else [self setNeedsLayout];
}
- (void)setIndeterminate:(BOOL)v { _indeterminate = v; _fill->_striped = v; [_fill setNeedsDisplay]; _moving = NO; [self setNeedsLayout]; [self updateMotion]; }

- (void)layoutFill {
    CGFloat w = self.bounds.size.width, h = self.bounds.size.height;
    if (_indeterminate) { if (!_moving) _fill.frame = CGRectMake(-12 - h, 0, w + 24 + 2 * h, h); }
    else _fill.frame = CGRectMake(0, 0, (_progress > 0 ? MAX(h, w * _progress) : 0), h);
    [_fill setNeedsDisplay];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _clip.frame = self.bounds;
    _clip.layer.cornerRadius = self.bounds.size.height / 2;
    [self layoutFill];
}

- (void)didMoveToWindow { [super didMoveToWindow]; _moving = NO; [self updateMotion]; }

- (void)updateMotion {
    [_fill.layer removeAllAnimations];
    if (!_indeterminate || !self.window) return;
    [self layoutFill];
    _moving = YES;
    CGRect f = _fill.frame;
    f.origin.x += 12; // one stripe period: seamless loop (barber .7 s)
    [UIView animateWithDuration:.35 delay:0 options:UIViewAnimationOptionRepeat | UIViewAnimationOptionCurveLinear animations:^{ _fill.frame = f; } completion:nil];
}

- (void)drawRect:(CGRect)rect {
    // track: linear-gradient(#bcc7c1, #e8eeeb), inset shadow, white highlight under
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    CGPathRef p = RCCreateRoundedRectPath(b, b.size.height / 2);
    CGContextSaveGState(ctx);
    CGContextAddPath(ctx, p); CGContextClip(ctx);
    BOOL dark = [RCTheme isDark];
    RCDrawVerticalGradient(ctx, b, [NSArray arrayWithObjects:RCHex(dark ? 0x101814 : 0xbcc7c1), RCHex(dark ? 0x2a3a33 : 0xe8eeeb), nil], nil);
    CGContextSetFillColorWithColor(ctx, RCHexA(0, .2).CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, b.size.width, 1));
    CGContextRestoreGState(ctx);
    CGPathRelease(p);
}
@end
