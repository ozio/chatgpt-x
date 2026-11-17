#import "RCActionBar.h"
#import "RCTheme.h"
#import "RCGlyph.h"

@interface RCActionBar () { NSMutableArray *_buttons; UIButton *_sources, *_pager; }
@end

@implementation RCActionBar
@synthesize sourceIcons = _sourceIcons;
@synthesize actions = _actions, sourcesCount = _sourcesCount, pagerIndex = _pagerIndex, pagerCount = _pagerCount, speaking = _speaking, delegate = _delegate;

+ (CGFloat)height { return 36; }

+ (UIImage *)pressedImage {
    return [RCTheme imageForKey:@"actionbar-pressed" size:CGSizeMake(4, 4) capInsets:UIEdgeInsetsMake(1, 1, 1, 1) drawing:^(CGContextRef ctx, CGRect r) {
        CGContextSetFillColorWithColor(ctx, RCHexA(0x1f8a57, .15).CGColor); CGContextFillRect(ctx, r);
    }];
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        _buttons = [[NSMutableArray alloc] init];
        _sources = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        _sources.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        [_sources setTitleColor:[RCTheme linkColor] forState:UIControlStateNormal];
        [_sources setBackgroundImage:[RCActionBar pressedImage] forState:UIControlStateHighlighted];
        [_sources addTarget:self action:@selector(tapSources) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_sources];
        _pager = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        _pager.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        [_pager setTitleColor:RCHex(0x2f7a55) forState:UIControlStateNormal];
        [_pager addTarget:self action:@selector(tapPager) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_pager];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rebuild) name:RCThemeAppearanceDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; [_sourceIcons release]; [_buttons release]; [_sources release]; [_pager release]; [super dealloc]; }

- (BOOL)isEmpty { return (_actions & 0x1f) == 0 && _sourcesCount == 0 && _pagerCount < 2; }

- (void)setActions:(NSUInteger)a { _actions = a; [self rebuild]; }
- (void)setSourcesCount:(NSUInteger)n { _sourcesCount = n; [self rebuild]; }
- (void)setPagerIndex:(NSUInteger)i { _pagerIndex = i; [self rebuild]; }
- (void)setPagerCount:(NSUInteger)n { _pagerCount = n; [self rebuild]; }
- (void)setSpeaking:(BOOL)s { _speaking = s; [self rebuild]; }

- (void)setSourceIcons:(NSArray *)images { if ([_sourceIcons isEqual:images]) return; [_sourceIcons release]; _sourceIcons = [images copy]; [self rebuild]; }
- (UIImage *)favicons {
    NSUInteger count = MIN((NSUInteger)3,_sourceIcons.count);
    if (!count) return [RCGlyph imageNamed:@"link" size:16 color:[RCTheme answerSecondaryColor]];
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(26,16),NO,0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    for (NSUInteger i=0;i<count;i++) { CGRect r=CGRectMake(i*5,0,16,16); CGPathRef p=RCCreateRoundedRectPath(r,4); CGContextSaveGState(ctx); CGContextAddPath(ctx,p); CGContextClip(ctx); [[UIColor whiteColor]setFill]; CGContextFillRect(ctx,r); [_sourceIcons[i] drawInRect:CGRectInset(r,1,1)]; CGContextRestoreGState(ctx); CGContextAddPath(ctx,p); CGContextSetStrokeColorWithColor(ctx,[RCTheme cardStrokeColor].CGColor); CGContextSetLineWidth(ctx,.5); CGContextStrokePath(ctx); CGPathRelease(p); }
    UIImage *image=UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return image;
}

- (void)rebuild {
    for (UIView *b in _buttons) [b removeFromSuperview];
    [_buttons removeAllObjects];
    struct { RCAnswerAction a; const char *glyph; NSString *label; } spec[] = {
        {RCAnswerActionCopy, "copy", RCL(@"Copy")}, {RCAnswerActionRegenerate, "regen", RCL(@"Regenerate")},
        {RCAnswerActionSpeak, "speaker", RCL(@"Read aloud")}, {RCAnswerActionShare, "share", RCL(@"Share")}, {RCAnswerActionMore, "more", RCL(@"More")}};
    for (int i = 0; i < 5; i++) {
        if (!(_actions & spec[i].a)) continue;
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        BOOL on = spec[i].a == RCAnswerActionSpeak && _speaking;
        // dark: prototype keeps #5d6f66 glyphs; lightened here for contrast on #22302a (kit extension)
        UIColor *glyphColor = on ? ([RCTheme isDark] ? RCHex(0x6fd29d) : [RCTheme jadeColor]) : ([RCTheme isDark] ? RCHex(0x8fa39a) : RCHex(0x5d6f66));
        [b setImage:[RCGlyph imageNamed:[NSString stringWithUTF8String:spec[i].glyph] size:18 color:glyphColor] forState:UIControlStateNormal];
        [b setBackgroundImage:[RCActionBar pressedImage] forState:UIControlStateHighlighted];
        b.adjustsImageWhenHighlighted = NO;
        b.tag = spec[i].a;
        b.accessibilityLabel = spec[i].label;
        [b addTarget:self action:@selector(tapAction:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:b];
        [_buttons addObject:b];
    }
    UIColor *link = [RCTheme isDark] ? RCHex(0x7fdcab) : [RCTheme linkColor];
    [_sources setTitleColor:link forState:UIControlStateNormal];
    [_pager setTitleColor:([RCTheme isDark] ? RCHex(0x7fdcab) : RCHex(0x2f7a55)) forState:UIControlStateNormal];
    _sources.hidden = _sourcesCount == 0;
    if (_sourcesCount) {
        [_sources setImage:[self favicons] forState:UIControlStateNormal];
        [_sources setTitle:[NSString stringWithFormat:RCL(@" Sources %lu"), (unsigned long)_sourcesCount] forState:UIControlStateNormal];
        _sources.adjustsImageWhenHighlighted = NO;
    }
    _pager.hidden = _pagerCount < 2;
    if (_pagerCount >= 2) [_pager setTitle:[NSString stringWithFormat:@"‹  %lu / %lu  ›", (unsigned long)_pagerIndex + 1, (unsigned long)_pagerCount] forState:UIControlStateNormal];
    [self setNeedsLayout];
    [self setNeedsDisplay];
}

- (void)applyTitles:(BOOL)compact {
    if (_sourcesCount) [_sources setTitle:(compact ? [NSString stringWithFormat:@" %lu", (unsigned long)_sourcesCount] : [NSString stringWithFormat:RCL(@" Sources %lu"), (unsigned long)_sourcesCount]) forState:UIControlStateNormal];
    if (_pagerCount >= 2) [_pager setTitle:(compact ? [NSString stringWithFormat:@"%lu/%lu", (unsigned long)_pagerIndex + 1, (unsigned long)_pagerCount] : [NSString stringWithFormat:@"‹  %lu / %lu  ›", (unsigned long)_pagerIndex + 1, (unsigned long)_pagerCount]) forState:UIControlStateNormal];
}

- (CGFloat)sourcesWidth { return ceil([[_sources titleForState:UIControlStateNormal] sizeWithFont:_sources.titleLabel.font].width) + 26 + 16; }
- (CGFloat)pagerWidth { return ceil([[_pager titleForState:UIControlStateNormal] sizeWithFont:_pager.titleLabel.font].width) + 10; }

- (void)layoutSubviews {
    [super layoutSubviews];
    // Five actions + pager + "Источники N" overflow 278 pt: fall back to "3" and "1/2".
    [self applyTitles:NO];
    CGFloat need = _buttons.count * 34 + (_sources.hidden ? 0 : [self sourcesWidth]) + (_pager.hidden ? 0 : [self pagerWidth] + 6);
    if (need > self.bounds.size.width) [self applyTitles:YES];
    _sources.accessibilityLabel = [NSString stringWithFormat:RCL(@"Sources: %lu"), (unsigned long)_sourcesCount];
    CGFloat x = 0, h = self.bounds.size.height;
    for (UIButton *b in _buttons) { b.frame = CGRectMake(x, 1, 34, h - 1); x += 34; }
    CGFloat right = self.bounds.size.width;
    if (!_sources.hidden) {
        CGFloat w = [self sourcesWidth];
        _sources.frame = CGRectMake(right - w, 1, w, h - 1);
        right -= w;
    }
    if (!_pager.hidden) {
        CGFloat w = [self pagerWidth];
        _pager.frame = CGRectMake(right - w - 6, 1, w, h - 1);
    }
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    // bottom corners follow the card (radius 10 outside, 9 inside its border)
    CGMutablePathRef p = CGPathCreateMutable();
    CGFloat r = 9, maxX = CGRectGetMaxX(b), maxY = CGRectGetMaxY(b);
    CGPathMoveToPoint(p, NULL, 0, 0);
    CGPathAddLineToPoint(p, NULL, maxX, 0);
    CGPathAddArcToPoint(p, NULL, maxX, maxY, 0, maxY, r);
    CGPathAddArcToPoint(p, NULL, 0, maxY, 0, 0, r);
    CGPathCloseSubpath(p);
    CGContextAddPath(ctx, p);
    CGContextClip(ctx);
    BOOL dark = [RCTheme isDark];
    RCDrawVerticalGradient(ctx, b, [NSArray arrayWithObjects:RCHex(dark ? 0x22302a : 0xfbfcfb), RCHex(dark ? 0x1a2621 : 0xf0f4f2), nil], nil);
    CGContextSetFillColorWithColor(ctx, RCHex(dark ? 0x2c3d35 : 0xe3e9e6).CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, b.size.width, 1));
    CGPathRelease(p);
}

- (void)tapAction:(UIButton *)b { [_delegate actionBar:self didSelectAction:(RCAnswerAction)b.tag]; }
- (void)tapSources { [_delegate actionBar:self didSelectAction:RCAnswerActionSources]; }
- (void)tapPager { [_delegate actionBar:self didSelectAction:RCAnswerActionPager]; }
@end
