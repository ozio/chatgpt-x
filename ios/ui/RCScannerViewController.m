#import "RCScannerViewController.h"
#import "RCTheme.h"
#import <QuartzCore/QuartzCore.h> // headers only (layer messages)

@interface RCScannerViewfinder : UIView { @public BOOL placeholder; }
@end
@implementation RCScannerViewfinder
- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    if (placeholder) {
        NSArray *c = [NSArray arrayWithObjects:(id)RCHex(0x4a4f4c).CGColor, (id)RCHex(0x1b1e1c).CGColor, nil];
        CGColorSpaceRef sp = CGColorSpaceCreateDeviceRGB();
        CGGradientRef g = CGGradientCreateWithColors(sp, (CFArrayRef)c, NULL);
        CGPoint m = CGPointMake(CGRectGetMidX(b), CGRectGetMidY(b));
        CGContextDrawRadialGradient(ctx, g, m, 0, m, MAX(b.size.width, b.size.height) * .6, kCGGradientDrawsAfterEndLocation);
        CGGradientRelease(g); CGColorSpaceRelease(sp);
        // a slightly turned paper sheet with text lines (.docshape)
        CGContextSaveGState(ctx);
        CGContextTranslateCTM(ctx, CGRectGetMidX(b), CGRectGetMidY(b));
        CGContextRotateCTM(ctx, -3 * M_PI / 180);
        CGRect doc = CGRectMake(-(b.size.width / 2 - 50), -(b.size.height / 2 - 40), b.size.width - 100, b.size.height - 80);
        CGContextSetShadowWithColor(ctx, CGSizeMake(0, 6), 20, RCHexA(0, .6).CGColor);
        CGContextSetFillColorWithColor(ctx, RCHex(0xf2f2ec).CGColor);
        CGContextFillRect(ctx, doc);
        CGContextSetShadowWithColor(ctx, CGSizeZero, 0, NULL);
        CGContextSetFillColorWithColor(ctx, RCHexA(0x999999, .5).CGColor);
        for (CGFloat y = doc.origin.y + doc.size.height * .12; y < CGRectGetMaxY(doc) - doc.size.height * .2; y += 12)
            CGContextFillRect(ctx, CGRectMake(doc.origin.x + doc.size.width * .14, y, doc.size.width * .72, 2));
        CGContextRestoreGState(ctx);
    }
    // dim outside the frame and the green guide
    CGRect fr = CGRectInset(b, 44, 34);
    CGContextSetFillColorWithColor(ctx, RCHexA(0, .15).CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, b.size.width, fr.origin.y));
    CGContextFillRect(ctx, CGRectMake(0, CGRectGetMaxY(fr), b.size.width, b.size.height - CGRectGetMaxY(fr)));
    CGContextFillRect(ctx, CGRectMake(0, fr.origin.y, fr.origin.x, fr.size.height));
    CGContextFillRect(ctx, CGRectMake(CGRectGetMaxX(fr), fr.origin.y, b.size.width - CGRectGetMaxX(fr), fr.size.height));
    CGContextSetStrokeColorWithColor(ctx, RCHex(0x4cd38e).CGColor);
    CGContextSetLineWidth(ctx, 2);
    CGContextStrokeRect(ctx, fr);
    // heavier corner guides
    CGContextSetLineWidth(ctx, 5);
    CGContextSetLineCap(ctx, kCGLineCapSquare);
    CGFloat L = 18, x0 = CGRectGetMinX(fr), x1 = CGRectGetMaxX(fr), y0 = CGRectGetMinY(fr), y1 = CGRectGetMaxY(fr);
    CGPoint pts[16] = {{x0, y0 + L}, {x0, y0}, {x0, y0}, {x0 + L, y0}, {x1 - L, y0}, {x1, y0}, {x1, y0}, {x1, y0 + L},
                       {x0, y1 - L}, {x0, y1}, {x0, y1}, {x0 + L, y1}, {x1 - L, y1}, {x1, y1}, {x1, y1}, {x1, y1 - L}};
    CGContextStrokeLineSegments(ctx, pts, 16);
}
@end

@interface RCScannerShutter : UIControl
@end
@implementation RCScannerShutter
- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; [self setNeedsDisplay]; }
- (void)setEnabled:(BOOL)e { [super setEnabled:e]; self.alpha = e ? 1 : .5; }
- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect o = CGRectInset(self.bounds, 1, 1);
    CGContextSetFillColorWithColor(ctx, RCHex(0x333333).CGColor); CGContextFillEllipseInRect(ctx, o);
    CGRect ring = CGRectInset(o, 2, 2);
    CGContextSetFillColorWithColor(ctx, RCHex(0xdddddd).CGColor); CGContextFillEllipseInRect(ctx, ring);
    CGRect in = CGRectInset(ring, 4, 4);
    CGContextSaveGState(ctx); CGContextAddEllipseInRect(ctx, in); CGContextClip(ctx);
    RCDrawVerticalGradient(ctx, in, self.highlighted ? [NSArray arrayWithObjects:RCHex(0xbbbbbb), RCHex(0x999999), nil] : [NSArray arrayWithObjects:RCHex(0xffffff), RCHex(0xcccccc), nil], nil);
    CGContextRestoreGState(ctx);
}
@end

@interface RCScannerViewController () {
    RCScannerViewfinder *_finder;
    UIScrollView *_strip;
    RCScannerShutter *_shutter;
    UILabel *_count;
}
@end

@implementation RCScannerViewController
@synthesize previewView = _preview, pages = _pages, selectedPage = _selected, shutterEnabled = _shutterEnabled, delegate = _delegate;
@synthesize readingCode = _readingCode;

+ (UINavigationController *)navigationControllerWithDelegate:(id<RCScannerViewControllerDelegate>)delegate {
    RCScannerViewController *c = [[[self alloc] initWithNibName:nil bundle:nil] autorelease];
    c.delegate = delegate;
    UINavigationController *nav = [[[UINavigationController alloc] initWithRootViewController:c] autorelease];
    [RCTheme styleNavigationBar:nav.navigationBar variant:RCBarVariantDark];
    return nav;
}

- (id)initWithNibName:(NSString *)n bundle:(NSBundle *)b {
    if ((self = [super initWithNibName:n bundle:b])) { _selected = -1; _shutterEnabled = YES; _pages = [[NSArray alloc] init]; self.title = RCL(@"Scan"); }
    return self;
}

- (void)dealloc { [_preview release]; [_pages release]; [_finder release]; [_strip release]; [_shutter release]; [_count release]; [super dealloc]; }

- (void)loadView {
    UIView *v = [[[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame] autorelease];
    v.backgroundColor = RCHex(0x111111);
    self.view = v;
    _finder = [[RCScannerViewfinder alloc] initWithFrame:CGRectZero];
    _finder.backgroundColor = [UIColor clearColor];
    _finder.contentMode = UIViewContentModeRedraw;
    _finder.userInteractionEnabled = NO;
    _finder.isAccessibilityElement = YES;
    _finder.accessibilityLabel = RCL(@"Viewfinder: frame the page");
    if (_preview) [v addSubview:_preview];
    [v addSubview:_finder];
    _strip = [[UIScrollView alloc] initWithFrame:CGRectZero];
    _strip.backgroundColor = RCHexA(0, .6);
    _strip.showsHorizontalScrollIndicator = NO;
    [v addSubview:_strip];
    _shutter = [[RCScannerShutter alloc] initWithFrame:CGRectMake(0, 0, 70, 70)];
    _shutter.backgroundColor = [UIColor clearColor];
    _shutter.isAccessibilityElement = YES;
    _shutter.accessibilityLabel = RCL(@"Capture page");
    _shutter.accessibilityTraits = UIAccessibilityTraitButton;
    [_shutter addTarget:self action:@selector(shoot) forControlEvents:UIControlEventTouchUpInside];
    [v addSubview:_shutter];
    _count = [[UILabel alloc] initWithFrame:CGRectZero];
    _count.backgroundColor = [UIColor clearColor];
    _count.font = [UIFont boldSystemFontOfSize:15];
    _count.textColor = [UIColor whiteColor];
    [v addSubview:_count];
    self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:RCL(@"Cancel") style:UIBarButtonItemStyleBordered target:self action:@selector(cancel)] autorelease];
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:RCL(@"Done") style:UIBarButtonItemStyleDone target:self action:@selector(save)] autorelease];
    [self refresh];
}

- (void)refresh {
    if (![self isViewLoaded]) return;
    _finder->placeholder = _preview == nil && !_readingCode;
    _finder.accessibilityLabel = _readingCode ? RCL(@"Viewfinder: frame the QR code") : RCL(@"Viewfinder: frame the page");
    _strip.hidden = _shutter.hidden = _count.hidden = _readingCode;
    self.navigationItem.rightBarButtonItem = _readingCode ? nil : [[[UIBarButtonItem alloc] initWithTitle:RCL(@"Done") style:UIBarButtonItemStyleDone target:self action:@selector(save)] autorelease];
    [_finder setNeedsDisplay];
    _shutter.enabled = _shutterEnabled;
    _count.text = _pages.count ? [NSString stringWithFormat:RCL(@"%d p."), (int)_pages.count] : @"";
    for (UIView *s in [[_strip.subviews copy] autorelease]) if ([s isKindOfClass:[UIButton class]]) [s removeFromSuperview];
    CGFloat x = 8;
    for (NSUInteger i = 0; i < _pages.count; i++) {
        UIButton *p = [UIButton buttonWithType:UIButtonTypeCustom];
        p.frame = CGRectMake(x, 8, 42, 54);
        p.tag = (NSInteger)i;
        id img = [_pages objectAtIndex:i];
        p.backgroundColor = RCHex(0xf2f2ec);
        if ([img isKindOfClass:[UIImage class]]) [p setImage:img forState:UIControlStateNormal];
        p.imageView.contentMode = UIViewContentModeScaleAspectFill;
        p.layer.borderWidth = 2;
        p.layer.borderColor = ((NSInteger)i == _selected ? RCHex(0x4cd38e) : [UIColor whiteColor]).CGColor;
        UILabel *n = [[[UILabel alloc] initWithFrame:CGRectMake(0, 38, 38, 12)] autorelease];
        n.backgroundColor = [UIColor clearColor]; n.font = [UIFont boldSystemFontOfSize:9]; n.textColor = RCHex(0x555555); n.textAlignment = NSTextAlignmentRight;
        n.text = [NSString stringWithFormat:@"%d", (int)i + 1];
        [p addSubview:n];
        p.accessibilityLabel = [NSString stringWithFormat:RCL(@"Page %d"), (int)i + 1];
        [p addTarget:self action:@selector(pageTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_strip addSubview:p];
        x += 48;
    }
    _strip.contentSize = CGSizeMake(x + 2, 66);
    if (_strip.bounds.size.width > 0) [_strip setContentOffset:CGPointMake(MAX(0, x + 2 - _strip.bounds.size.width), 0) animated:YES];
    [self.view setNeedsLayout];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width, h = self.view.bounds.size.height;
    CGRect vf = CGRectMake(0, 0, w, MAX(0, h - (_readingCode ? 0 : 150)));
    _finder.frame = vf;
    _preview.frame = vf;
    _strip.frame = CGRectMake(0, h - 150, w, 66);
    _strip.contentOffset = CGPointMake(MAX(0, MIN(_strip.contentOffset.x, _strip.contentSize.width - w)), 0);
    _shutter.center = CGPointMake(w / 2, h - 12 - 35);
    _count.frame = CGRectMake(16, h - 54, 100, 22);
}

- (void)setPreviewView:(UIView *)v {
    if (v == _preview) return;
    [_preview removeFromSuperview]; [_preview release]; _preview = [v retain];
    if ([self isViewLoaded] && v) [self.view insertSubview:v belowSubview:_finder];
    [self refresh];
}
- (void)setPages:(NSArray *)p { [_pages release]; _pages = [(p ? p : [NSArray array]) copy]; if (_selected >= (NSInteger)_pages.count) _selected = -1; [self refresh]; }
- (void)setSelectedPage:(NSInteger)s { _selected = s; [self refresh]; }
- (void)setShutterEnabled:(BOOL)e { _shutterEnabled = e; [self refresh]; }
- (void)setReadingCode:(BOOL)reading { _readingCode = reading; self.title = reading ? RCL(@"Scan QR code") : RCL(@"Scan"); [self refresh]; }

- (void)shoot { [_delegate scannerDidTapShutter:self]; }
- (void)cancel { [_delegate scannerDidCancel:self]; }
- (void)save { [_delegate scannerDidSave:self]; }
- (void)pageTapped:(UIButton *)b {
    self.selectedPage = b.tag;
    if ([_delegate respondsToSelector:@selector(scanner:didSelectPageAtIndex:)]) [_delegate scanner:self didSelectPageAtIndex:(NSUInteger)b.tag];
}
@end
