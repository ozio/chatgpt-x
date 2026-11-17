#import "RCHUD.h"
#import "RCTheme.h"
#import <QuartzCore/QuartzCore.h> // headers only (layer messages), no QuartzCore link

@interface RCHUD () { UIImageView *_check; UIActivityIndicatorView *_spin; UILabel *_label; BOOL _hiding; }
@end

@implementation RCHUD

+ (UIImage *)checkImage {
    return [RCTheme imageForKey:@"hud-check" size:CGSizeMake(60, 60) capInsets:UIEdgeInsetsZero drawing:^(CGContextRef ctx, CGRect r) {
        CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
        CGContextSetLineWidth(ctx, 7);
        CGContextSetLineCap(ctx, kCGLineCapRound);
        CGContextSetLineJoin(ctx, kCGLineJoinRound);
        CGContextMoveToPoint(ctx, 10, 31); CGContextAddLineToPoint(ctx, 24, 45); CGContextAddLineToPoint(ctx, 50, 15);
        CGContextStrokePath(ctx);
        (void)r;
    }];
}

- (id)initWithText:(NSString *)text kind:(RCHUDKind)kind {
    if ((self = [super initWithFrame:CGRectMake(0, 0, 156, 156)])) {
        self.backgroundColor = RCHexA(0, .72);
        self.layer.cornerRadius = 12;
        self.userInteractionEnabled = NO;
        self.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        _check = [[UIImageView alloc] initWithImage:[RCHUD checkImage]];
        _check.frame = CGRectMake(48, 28, 60, 60);
        [self addSubview:_check];
        _spin = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        _spin.center = CGPointMake(78, 58);
        [self addSubview:_spin];
        _label = [[UILabel alloc] initWithFrame:CGRectZero];
        _label.backgroundColor = [UIColor clearColor];
        _label.font = [UIFont boldSystemFontOfSize:16];
        _label.textColor = [UIColor whiteColor];
        _label.textAlignment = NSTextAlignmentCenter;
        _label.numberOfLines = 0;
        _label.lineBreakMode = NSLineBreakByWordWrapping;
        [self addSubview:_label];
        [self setText:text kind:kind];
        self.isAccessibilityElement = YES;
    }
    return self;
}
- (void)dealloc { [_check release]; [_spin release]; [_label release]; [super dealloc]; }

- (void)setText:(NSString *)text kind:(RCHUDKind)kind {
    _check.hidden = kind != RCHUDDone;
    if (kind == RCHUDBusy) [_spin startAnimating]; else [_spin stopAnimating];
    RCLabelSetText(_label, text);
    self.accessibilityLabel = text;
    CGFloat top = kind == RCHUDTextOnly ? 22 : 22 + 74;
    CGSize s = RCMeasureText(text, _label.font, 136);
    CGFloat h = MAX(156, top + ceil(s.height) + 16);
    if (kind == RCHUDTextOnly) h = MAX(80, top + ceil(s.height) + 22);
    CGPoint c = self.center;
    self.bounds = CGRectMake(0, 0, 156, h);
    self.center = c;
    _label.frame = CGRectMake(10, top, 136, ceil(s.height));
}

+ (RCHUD *)showText:(NSString *)text kind:(RCHUDKind)kind inView:(UIView *)view seconds:(NSTimeInterval)seconds {
    RCHUD *h = [[[RCHUD alloc] initWithText:text kind:kind] autorelease];
    h.center = CGPointMake(floor(view.bounds.size.width / 2), floor(view.bounds.size.height / 2));
    [view addSubview:h];
    h.alpha = 0;
    h.transform = CGAffineTransformMakeScale(1.25, 1.25);
    [UIView animateWithDuration:.2 animations:^{ h.alpha = 1; h.transform = CGAffineTransformIdentity; }];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, text);
    if (kind != RCHUDBusy) [h performSelector:@selector(hide) withObject:nil afterDelay:(seconds > 0 ? seconds : 1.1)];
    return h;
}

- (void)finishWithText:(NSString *)text {
    [self setText:(text ? text : _label.text) kind:RCHUDDone];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, _label.text);
    [self performSelector:@selector(hide) withObject:nil afterDelay:.9];
}

- (void)hide {
    if (_hiding) return;
    _hiding = YES;
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self retain];
    [UIView animateWithDuration:.2 animations:^{ self.alpha = 0; self.transform = CGAffineTransformMakeScale(1.25, 1.25); } completion:^(BOOL f) { [self removeFromSuperview]; [self release]; }];
}
@end
