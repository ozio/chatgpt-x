#import "RCLaunchView.h"
#import "RCTheme.h"
#import "RCWelcomeViewController.h"

// Layout and light, shared with ios/ui/tools/render-launch.swift (keep in sync):
// only the logo canvas 108×110 (RCWelcomeViewController +logoImage), its mark
// (104 pt at 2, 0; centre 54, 52) centred on the middle of the view — no text;
// vignette: black 0 → .45 between 55 % and 100 % of 0.65 × height around the middle;
// spotlight: #3fd08a .28 → 0 over 170 pt around the centre of the mark.
static const CGFloat RCLaunchMarkCentre = 52;

@interface RCLaunchView () {
    UIImageView *_light, *_logo;
    CGSize _lightSize;
    BOOL _statusShown;
}
@end

@implementation RCLaunchView
@synthesize appTitle = _appTitle, statusText = _statusText, finishing = _finishing;

+ (CGFloat)logoTopForHeight:(CGFloat)height { return round(height / 2) - RCLaunchMarkCentre; }

// Not cached: a full-screen image is needed once per launch.
+ (UIImage *)lightImageForSize:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGPoint mid = CGPointMake(size.width / 2, size.height / 2);
    CGFloat vignette[8] = { 0, 0, 0, 0,  0, 0, 0, .45 }, vignetteAt[2] = { .55, 1 };
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, vignette, vignetteAt, 2);
    CGContextDrawRadialGradient(ctx, g, mid, 0, mid, .65 * size.height, kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(g);
    CGFloat r = 0x3f / 255.0, gr = 0xd0 / 255.0, b = 0x8a / 255.0;
    CGFloat spot[8] = { r, gr, b, .28,  r, gr, b, 0 }, spotAt[2] = { 0, 1 };
    CGPoint c = CGPointMake(size.width / 2, [self logoTopForHeight:size.height] + RCLaunchMarkCentre);
    g = CGGradientCreateWithColorComponents(cs, spot, spotAt, 2);
    CGContextDrawRadialGradient(ctx, g, c, 0, c, 170, 0);
    CGGradientRelease(g);
    CGColorSpaceRelease(cs);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [RCTheme linenDarkColor];
        _appTitle = [@"ChatGPT X" copy];
        _light = [[UIImageView alloc] initWithFrame:self.bounds];
        [self addSubview:_light];
        _logo = [[UIImageView alloc] initWithImage:[RCWelcomeViewController logoImage]];
        [self addSubview:_logo];
        self.isAccessibilityElement = YES;
        self.accessibilityLabel = _appTitle;
    }
    return self;
}

- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [_light release]; [_logo release];
    [_appTitle release]; [_statusText release];
    [super dealloc];
}

- (void)setAppTitle:(NSString *)appTitle {
    if (_appTitle == appTitle || [_appTitle isEqualToString:appTitle]) return;
    [_appTitle release]; _appTitle = [appTitle copy];
    if (_statusShown) [self applyStatus]; else self.accessibilityLabel = _appTitle;
}

- (void)setStatusText:(NSString *)statusText {
    if (_statusText == statusText || [_statusText isEqualToString:statusText]) return;
    [_statusText release]; _statusText = [statusText copy];
    if (_statusShown) [self applyStatus];
}

// VoiceOver only: the splash itself shows nothing but the mark.
- (void)applyStatus {
    NSString *s = _statusText.length ? _statusText : RCL(@"Restoring session…");
    self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", _appTitle ? _appTitle : @"", s];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (_finishing) return;
    CGSize s = self.bounds.size;
    if (s.height < 1) return;
    if (!CGSizeEqualToSize(s, _lightSize)) { _lightSize = s; _light.image = [RCLaunchView lightImageForSize:s]; }
    _light.frame = self.bounds;
    CGFloat top = [RCLaunchView logoTopForHeight:s.height];
    _logo.transform = CGAffineTransformIdentity;
    _logo.frame = CGRectMake(round((s.width - 108) / 2), top, 108, 110);
}

- (void)showStatusAfterDelay:(NSTimeInterval)delay {
    if (_finishing) return;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(revealStatus) object:nil];
    [self performSelector:@selector(revealStatus) withObject:nil afterDelay:delay];
}

- (void)revealStatus {
    if (_finishing || _statusShown) return;
    _statusShown = YES;
    [self applyStatus];
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
}

- (void)finish:(RCLaunchFinish)finish completion:(void (^)(void))completion {
    if (_finishing) return;
    _finishing = YES;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(revealStatus) object:nil];
    self.userInteractionEnabled = NO;
    void (^done)(void) = [[completion copy] autorelease];
    if (finish == RCLaunchFinishWelcome) {
        CGFloat dy = [RCWelcomeViewController logoTopForHeight:self.bounds.size.height] - _logo.frame.origin.y;
        [UIView animateWithDuration:.5 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            _light.alpha = 0;
            _logo.frame = CGRectOffset(_logo.frame, 0, dy);
        } completion:^(BOOL f) {
            (void)f;
            [UIView animateWithDuration:.25 animations:^{ self.alpha = 0; } completion:^(BOOL f2) {
                (void)f2; [self removeFromSuperview]; if (done) done();
            }];
        }];
    } else {
        [UIView animateWithDuration:.4 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            self.alpha = 0;
            _logo.transform = CGAffineTransformMakeScale(1.12, 1.12);
        } completion:^(BOOL f) {
            (void)f; [self removeFromSuperview]; if (done) done();
        }];
    }
}
@end
