#import "RCWebFrameController.h"
#import "RCTheme.h"
#import "RCGlyph.h"
#import "RCLampView.h"
#import "RCBannerView.h"

@interface RCWebAddressStrip : UIView { @public UILabel *label; RCLampView *lamp; UIImageView *lock; }
@end
@implementation RCWebAddressStrip
- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.contentMode = UIViewContentModeRedraw;
        label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.backgroundColor = [UIColor clearColor];
        label.font = [UIFont systemFontOfSize:12];
        label.textColor = RCHex(0x4b5d55);
        label.shadowColor = RCHexA(0xffffff, .8); label.shadowOffset = CGSizeMake(0, 1);
        label.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [self addSubview:label];
        lamp = [[RCLampView alloc] initWithDiameter:7];
        [self addSubview:lamp];
        lock = [[UIImageView alloc] initWithImage:[RCGlyph imageNamed:@"lock" size:11 color:RCHex(0x2f7a55)]];
        [self addSubview:lock];
        self.isAccessibilityElement = YES;
    }
    return self;
}
- (void)dealloc { [label release]; [lamp release]; [lock release]; [super dealloc]; }
- (void)layoutSubviews {
    CGFloat w = self.bounds.size.width;
    CGSize s = [label.text sizeWithFont:label.font];
    CGFloat tw = MIN(ceil(s.width), w - 60), total = 7 + 5 + (lock.hidden ? 0 : 14) + tw;
    CGFloat x = round((w - total) / 2);
    CGRect lf = lamp.frame; lf.origin = CGPointMake(x - (lf.size.width - 7) / 2, 11.5 - (lf.size.height - 7) / 2); lamp.frame = lf;
    x += 12;
    if (!lock.hidden) { lock.frame = CGRectMake(x, 9, 11, 11); x += 14; }
    label.frame = CGRectMake(x, 0, tw, 29);
}
- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    RCDrawVerticalGradient(ctx, b, [NSArray arrayWithObjects:RCHex(0xedf1ef), RCHex(0xd7dfdb), nil], nil);
    CGContextSetFillColorWithColor(ctx, RCHex(0xa9b6af).CGColor);
    CGContextFillRect(ctx, CGRectMake(0, b.size.height - 1, b.size.width, 1));
}
@end

@interface RCWebFrameController () {
    RCWebAddressStrip *_strip;
    UIView *_bar;
    RCBannerView *_banner;
}
@end

@implementation RCWebFrameController
@synthesize contentView = _content, host = _host, secure = _secure, progress = _progress, delegate = _delegate;

+ (UINavigationController *)navigationControllerWithContentView:(UIView *)content title:(NSString *)title delegate:(id<RCWebFrameControllerDelegate>)delegate {
    RCWebFrameController *c = [[[self alloc] initWithContentView:content title:title] autorelease];
    c.delegate = delegate;
    UINavigationController *nav = [[[UINavigationController alloc] initWithRootViewController:c] autorelease];
    [RCTheme styleNavigationBar:nav.navigationBar variant:RCBarVariantJade];
    return nav;
}

- (id)initWithContentView:(UIView *)content title:(NSString *)title {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _content = [content retain];
        _secure = YES;
        _progress = -1;
        self.title = title.length ? title : RCL(@"Log In");
    }
    return self;
}

- (void)dealloc { [_content release]; [_host release]; [_strip release]; [_bar release]; [_banner release]; [super dealloc]; }

- (void)loadView {
    UIView *v = [[[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame] autorelease];
    v.backgroundColor = [UIColor whiteColor];
    self.view = v;
    if (_content) [v addSubview:_content];
    _strip = [[RCWebAddressStrip alloc] initWithFrame:CGRectZero];
    [v addSubview:_strip];
    _bar = [[UIView alloc] initWithFrame:CGRectZero];
    _bar.backgroundColor = RCHex(0x2fae6c);
    _bar.isAccessibilityElement = NO;
    [v addSubview:_bar];
    self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:RCL(@"Cancel") style:UIBarButtonItemStyleBordered target:self action:@selector(cancel)] autorelease];
    [self refreshStrip];
}

- (void)refreshStrip {
    if (!_strip) return;
    _strip->label.text = _host.length ? _host : @"…";
    _strip->lock.hidden = !_secure;
    _strip->lamp.state = _secure ? RCLampOK : RCLampWarn;
    _strip.accessibilityLabel = [NSString stringWithFormat:@"%@%@", _secure ? RCL(@"Secure connection, ") : RCL(@"Connection not secure, "), _strip->label.text];
    [_strip setNeedsLayout];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width, h = self.view.bounds.size.height, y = 30;
    _strip.frame = CGRectMake(0, 0, w, 30);
    if (_banner) { CGFloat bh = [_banner heightForWidth:w]; _banner.frame = CGRectMake(0, y, w, bh); y += bh; }
    _content.frame = CGRectMake(0, y, w, MAX(0, h - y));
    [self layoutBar];
}

- (void)layoutBar {
    CGFloat w = self.view.bounds.size.width;
    _bar.frame = CGRectMake(0, 28, round(w * MAX(0, MIN(1, _progress))), 2);
}

- (void)setContentView:(UIView *)v {
    if (v == _content) return;
    [_content removeFromSuperview]; [_content release]; _content = [v retain];
    if ([self isViewLoaded] && v) { [self.view insertSubview:v atIndex:0]; [self.view setNeedsLayout]; }
}
- (void)setHost:(NSString *)host { [_host release]; _host = [host copy]; [self refreshStrip]; }
- (void)setSecure:(BOOL)s { _secure = s; [self refreshStrip]; }
- (void)setProgress:(CGFloat)p { [self setProgress:p animated:NO]; }
- (void)setProgress:(CGFloat)p animated:(BOOL)animated {
    BOOL wasHidden = _progress < 0 || _progress >= 1;
    _progress = p;
    if (![self isViewLoaded]) return;
    if (p < 0) { _bar.alpha = 0; return; }
    if (wasHidden) { _bar.alpha = 1; _bar.frame = CGRectMake(0, 28, 0, 2); }
    [UIView animateWithDuration:(animated ? .4 : 0) animations:^{ [self layoutBar]; } completion:^(BOOL f) {
        if (_progress >= 1) [UIView animateWithDuration:(animated ? .25 : 0) animations:^{ _bar.alpha = 0; }];
    }];
}

- (void)showErrorText:(NSString *)text actionTitle:(NSString *)actionTitle {
    [self view];
    [_banner removeFromSuperview]; [_banner release];
    _banner = [[RCBannerView alloc] initWithKind:RCBannerError text:text actionTitle:actionTitle];
    [_banner.actionButton addTarget:self action:@selector(errorAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_banner];
    [self.view setNeedsLayout];
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, _banner);
}
- (void)hideError { [_banner removeFromSuperview]; [_banner release]; _banner = nil; [self.view setNeedsLayout]; }

- (void)cancel { [_delegate webFrameDidCancel:self]; }
- (void)errorAction { if ([_delegate respondsToSelector:@selector(webFrameDidTapErrorAction:)]) [_delegate webFrameDidTapErrorAction:self]; }
@end
