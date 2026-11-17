#import "RCLampView.h"
#import "RCTheme.h"
#import <QuartzCore/QuartzCore.h> // headers only: CALayer messages, no QuartzCore link

// The view is larger than the lamp so the 5 pt glow is not clipped.
static const CGFloat kGlow = 3;

@interface RCLampView () { CGFloat _diameter; RCLampState _state; BOOL _pulsing; }
@end

@implementation RCLampView
@synthesize state = _state, diameter = _diameter;

+ (NSString *)nameForState:(RCLampState)state {
    switch (state) {
        case RCLampOK: return @"ok";
        case RCLampBusy: return @"busy";
        case RCLampWarn: return @"warn";
        case RCLampError: return @"err";
        case RCLampInfo: return @"info";
        default: return @"off";
    }
}

- (id)initWithDiameter:(CGFloat)diameter {
    if ((self = [super initWithFrame:CGRectMake(0, 0, diameter + kGlow * 2, diameter + kGlow * 2)])) {
        _diameter = diameter;
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.contentMode = UIViewContentModeRedraw;
        self.isAccessibilityElement = NO;
    }
    return self;
}
- (id)initWithFrame:(CGRect)frame { return [self initWithDiameter:9]; }

- (void)setState:(RCLampState)state {
    if (state == _state) return;
    _state = state;
    [self setNeedsDisplay];
    [self updatePulse];
}

- (void)didMoveToWindow { [super didMoveToWindow]; _pulsing = NO; [self updatePulse]; }

- (void)updatePulse {
    BOOL want = _state == RCLampBusy && self.window != nil;
    if (want == _pulsing) return;
    _pulsing = want;
    [self.layer removeAllAnimations];
    self.alpha = 1;
    if (want) {
        // lampbusy: opacity 1 → .45 → 1 over 1 s, ease-in-out, forever
        [UIView animateWithDuration:.5 delay:0
                            options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowUserInteraction
                         animations:^{ self.alpha = .45; } completion:nil];
    }
}

- (void)drawRect:(CGRect)rect {
    unsigned hi = 0xf2f4f3, mid = 0xb3bab6, lo = 0x848c88, glow = 0, rim = 0;
    CGFloat glowA = 0, rimA = .18;
    switch (_state) {
        case RCLampOK: hi = 0xeaffd9; mid = 0x6bd83c; lo = 0x279b0c; glow = 0x56d228; glowA = .75; rim = 0x005000; rimA = .25; break;
        case RCLampBusy:
        case RCLampWarn: hi = 0xfff4cf; mid = 0xffc22c; lo = 0xd47c00; glow = 0xffb414; glowA = .8; rim = 0x783c00; rimA = .25; break;
        case RCLampError: hi = 0xffe0da; mid = 0xff5a3c; lo = 0xb8170a; glow = 0xff3c1e; glowA = .7; rim = 0x640000; rimA = .3; break;
        case RCLampInfo: hi = 0xe3f0ff; mid = 0x4c9bff; lo = 0x1453b8; glow = 0x3c8cff; glowA = .7; rim = 0x00145a; rimA = .3; break;
        default: break;
    }
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat d = _diameter;
    CGRect lamp = CGRectMake(floor((self.bounds.size.width - d) / 2), floor((self.bounds.size.height - d) / 2), d, d);
    if (glowA > 0) {
        CGContextSaveGState(ctx);
        CGContextSetShadowWithColor(ctx, CGSizeZero, 5, RCHexA(glow, glowA).CGColor);
        CGContextSetFillColorWithColor(ctx, RCHex(mid).CGColor);
        CGContextFillEllipseInRect(ctx, lamp);
        CGContextRestoreGState(ctx);
    } else {
        // off: 0 1px 0 rgba(255,255,255,.5) highlight under the lamp
        CGContextSetFillColorWithColor(ctx, RCHexA(0xffffff, .5).CGColor);
        CGContextFillEllipseInRect(ctx, CGRectOffset(lamp, 0, 1));
    }
    // radial-gradient(35% 30%, circle, hi, mid 40%, lo)
    CGContextSaveGState(ctx);
    CGContextAddEllipseInRect(ctx, lamp);
    CGContextClip(ctx);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    NSArray *colors = [NSArray arrayWithObjects:(id)RCHex(hi).CGColor, (id)RCHex(mid).CGColor, (id)RCHex(lo).CGColor, nil];
    CGFloat locs[3] = {0, .4, 1};
    CGGradientRef g = CGGradientCreateWithColors(space, (CFArrayRef)colors, locs);
    CGPoint c = CGPointMake(lamp.origin.x + d * .35, lamp.origin.y + d * .30);
    CGFloat far = hypot(d * .65, d * .70);
    CGContextDrawRadialGradient(ctx, g, c, 0, c, far, kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(g);
    CGColorSpaceRelease(space);
    CGContextRestoreGState(ctx);
    CGContextSetStrokeColorWithColor(ctx, RCHexA(rim, rimA).CGColor);
    CGContextSetLineWidth(ctx, 1);
    CGContextStrokeEllipseInRect(ctx, CGRectInset(lamp, .5, .5));
}

- (void)dealloc { [self.layer removeAllAnimations]; [super dealloc]; }
@end
