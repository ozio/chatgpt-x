#import "RCPartView.h"
#import "RCTheme.h"

@interface RCPartView () { NSMutableArray *_roleLabels; }
@end

@implementation RCPartView
@synthesize dashed = _dashed, plainFill = _plainFill, fillTop = _fillTop, fillBottom = _fillBottom, delegate = _delegate;

+ (UIColor *)colorForRole:(RCPartTextRole)role {
    BOOL dark = [RCTheme isDark];
    switch (role) {
        case RCPartTextTitle: return dark ? RCHex(0xe3ece7) : RCHex(0x1d2924);
        case RCPartTextBody: return dark ? RCHex(0xb8c9c0) : RCHex(0x3f5249);
        case RCPartTextLink: return dark ? RCHex(0x7fdcab) : RCHex(0x1c7449);
        default: return dark ? RCHex(0x8fa39a) : RCHex(0x6b7a72);
    }
}

- (id)initWithFrame:(CGRect)frame {
    if (CGRectIsEmpty(frame)) frame = CGRectMake(0, 0, 274, 60);
    if ((self = [super initWithFrame:frame])) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        _fillTop = 0xfdfefd; _fillBottom = 0xf1f5f3;
        _roleLabels = [[NSMutableArray alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyAppearance) name:RCThemeAppearanceDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; [_roleLabels release]; [super dealloc]; }

- (UILabel *)labelWithRole:(RCPartTextRole)role font:(UIFont *)font {
    UILabel *l = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
    l.backgroundColor = [UIColor clearColor];
    l.font = font;
    l.textColor = [RCPartView colorForRole:role];
    l.tag = role;
    [self addSubview:l];
    [_roleLabels addObject:l];
    return l;
}

- (void)applyAppearance {
    for (UILabel *l in _roleLabels) l.textColor = [RCPartView colorForRole:(RCPartTextRole)l.tag];
    [self setNeedsDisplay];
}

- (CGFloat)layoutForWidth:(CGFloat)width apply:(BOOL)apply { return 50; }
- (CGFloat)heightForWidth:(CGFloat)width { return [self layoutForWidth:width apply:NO]; }
- (CGSize)sizeThatFits:(CGSize)size { return CGSizeMake(size.width, [self heightForWidth:size.width]); }
- (void)layoutSubviews { [super layoutSubviews]; [self layoutForWidth:self.bounds.size.width apply:YES]; [self setNeedsDisplay]; }
- (void)notifyHeightChange { [self setNeedsLayout]; if ([_delegate respondsToSelector:@selector(partViewDidChangeHeight:)]) [_delegate partViewDidChangeHeight:self]; }
- (void)drawContent:(CGContextRef)ctx {}

- (void)drawHairlineAtY:(CGFloat)y context:(CGContextRef)ctx {
    CGContextSetFillColorWithColor(ctx, RCHex([RCTheme isDark] ? 0x2c3d35 : 0xe0e7e3).CGColor);
    CGContextFillRect(ctx, CGRectMake(0, y, self.bounds.size.width, 1));
}

- (void)drawFooterFromY:(CGFloat)y context:(CGContextRef)ctx {
    BOOL dark = [RCTheme isDark];
    RCDrawVerticalGradient(ctx, CGRectMake(0, y, self.bounds.size.width, self.bounds.size.height - y),
                           [NSArray arrayWithObjects:RCHex(dark ? 0x22302a : 0xfbfcfb), RCHex(dark ? 0x1a2621 : 0xeef3f0), nil], nil);
    [self drawHairlineAtY:y context:ctx];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    BOOL dark = [RCTheme isDark];
    CGRect b = CGRectInset(self.bounds, .5, .5);
    CGPathRef p = RCCreateRoundedRectPath(b, 8);
    CGContextSaveGState(ctx);
    CGContextAddPath(ctx, p); CGContextClip(ctx);
    if (dark) RCDrawVerticalGradient(ctx, self.bounds, [NSArray arrayWithObjects:RCHex(0x22302a), RCHex(0x1d2a24), nil], nil);
    else if (_plainFill) { CGContextSetFillColorWithColor(ctx, RCHex(_fillTop).CGColor); CGContextFillRect(ctx, self.bounds); }
    else RCDrawVerticalGradient(ctx, self.bounds, [NSArray arrayWithObjects:RCHex(_fillTop), RCHex(_fillBottom), nil], nil);
    [self drawContent:ctx];
    CGContextRestoreGState(ctx);
    if (_dashed) { CGFloat d[2] = {3, 2}; CGContextSetLineDash(ctx, 0, d, 2); }
    CGContextAddPath(ctx, p);
    CGContextSetStrokeColorWithColor(ctx, RCHex(dark ? 0x3d5248 : 0xb7c5be).CGColor);
    CGContextSetLineWidth(ctx, 1);
    CGContextStrokePath(ctx);
    CGPathRelease(p);
}
@end
