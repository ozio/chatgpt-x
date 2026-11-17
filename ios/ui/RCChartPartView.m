#import "RCChartPartView.h"
#import "RCTheme.h"

@interface RCChartPartView () { UILabel *_titleLabel; NSMutableArray *_valueLabels, *_catLabels; UIButton *_showCode; RCCodeBlockView *_codeView; NSString *_title, *_code, *_codeLanguage; NSArray *_values; }
@end

@implementation RCChartPartView
@synthesize codeCopyEnabled = _codeCopyEnabled;

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _valueLabels = [[NSMutableArray alloc] init];
        _catLabels = [[NSMutableArray alloc] init];
        _titleLabel = [[self labelWithRole:RCPartTextSecondary font:[UIFont boldSystemFontOfSize:12]] retain];
        _showCode = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        _showCode.titleLabel.font = [UIFont boldSystemFontOfSize:13];
        _showCode.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        [_showCode setTitle:RCL(@"Show analysis code ›") forState:UIControlStateNormal];
        [_showCode addTarget:self action:@selector(revealCode) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_showCode];
        [self applyAppearance];
    }
    return self;
}

- (void)dealloc { [_titleLabel release]; [_valueLabels release]; [_catLabels release]; [_showCode release]; [_codeView release]; [_title release]; [_code release]; [_codeLanguage release]; [_values release]; [super dealloc]; }

- (void)applyAppearance {
    [super applyAppearance];
    [_showCode setTitleColor:[RCPartView colorForRole:RCPartTextLink] forState:UIControlStateNormal];
    _titleLabel.textColor = [RCTheme isDark] ? RCHex(0xb8c9c0) : RCHex(0x4b5d55);
    for (UILabel *l in _valueLabels) l.textColor = [RCPartView colorForRole:RCPartTextTitle];
    for (UILabel *l in _catLabels) l.textColor = [RCPartView colorForRole:RCPartTextSecondary];
}

- (NSString *)title { return _title; }
- (void)setTitle:(NSString *)t { [_title release]; _title = [t copy]; _titleLabel.text = RCDisplayText(t); [self setNeedsLayout]; }
- (NSString *)code { return _code; }
- (void)setCode:(NSString *)c { [_code release]; _code = [c copy]; _showCode.hidden = c == nil; [self setNeedsLayout]; }
- (NSString *)codeLanguage { return _codeLanguage; }
- (void)setCodeLanguage:(NSString *)l { [_codeLanguage release]; _codeLanguage = [l copy]; }
- (NSArray *)values { return _values; }
- (void)setValues:(NSArray *)v {
    [_values release]; _values = [v copy];
    for (UIView *l in _valueLabels) [l removeFromSuperview];
    for (UIView *l in _catLabels) [l removeFromSuperview];
    [_valueLabels removeAllObjects]; [_catLabels removeAllObjects];
    NSMutableArray *ax = [NSMutableArray array];
    for (NSArray *d in _values) {
        UILabel *vl = [[[UILabel alloc] init] autorelease];
        vl.backgroundColor = [UIColor clearColor]; vl.font = [UIFont boldSystemFontOfSize:11]; vl.textAlignment = NSTextAlignmentCenter;
        vl.text = [[[d objectAtIndex:1] stringValue] stringByReplacingOccurrencesOfString:@"." withString:@","];
        UILabel *cl = [[[UILabel alloc] init] autorelease];
        cl.backgroundColor = [UIColor clearColor]; cl.font = [UIFont systemFontOfSize:11]; cl.textAlignment = NSTextAlignmentCenter;
        cl.text = [d objectAtIndex:0];
        [self addSubview:vl]; [self addSubview:cl];
        [_valueLabels addObject:vl]; [_catLabels addObject:cl];
        [ax addObject:[NSString stringWithFormat:@"%@ %@", cl.text, vl.text]];
    }
    self.isAccessibilityElement = YES;
    self.accessibilityLabel = [NSString stringWithFormat:RCL(@"Chart. %@"), [ax componentsJoinedByString:@", "]];
    [self applyAppearance];
    [self setNeedsLayout];
}

- (CGFloat)maxValue { CGFloat m = 0; for (NSArray *d in _values) m = MAX(m, [[d objectAtIndex:1] floatValue]); return m > 0 ? m : 1; }
- (CGFloat)step:(CGFloat)w { return _values.count ? MIN(74, floor((w - 8 - 18) / _values.count)) : 74; }

- (CGFloat)layoutForWidth:(CGFloat)w apply:(BOOL)apply {
    CGFloat y = 6;
    if (apply) _titleLabel.frame = CGRectMake(4, y, w - 8, 15);
    y += 15 + 6;
    CGFloat base = y + 120, step = [self step:w], max = [self maxValue];
    for (NSUInteger i = 0; i < _values.count && apply; i++) {
        CGFloat x = 4 + 18 + i * step, h = round([[[_values objectAtIndex:i] objectAtIndex:1] floatValue] / max * 100);
        [[_valueLabels objectAtIndex:i] setFrame:CGRectMake(x - 6, base - h - 17, 58, 14)];
        [[_catLabels objectAtIndex:i] setFrame:CGRectMake(x - 6, base + 3, 58, 14)];
    }
    y = base + 18 + 2;
    if (_codeView) {
        CGFloat ch = [_codeView heightForWidth:w];
        if (apply) _codeView.frame = CGRectMake(0, y + 6, w, ch);
        y += 6 + ch;
    } else if (_code) {
        if (apply) _showCode.frame = CGRectMake(0, y, w, 26);
        y += 6 + 20;
    }
    return y;
}

- (void)drawRect:(CGRect)rect {
    // no box: the chart sits directly in the answer card
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat w = self.bounds.size.width, top = 6 + 15 + 6, base = top + 120, step = [self step:w], max = [self maxValue];
    UIColor *axis = RCHex([RCTheme isDark] ? 0x3d5248 : 0xb7c5be);
    CGContextSetFillColorWithColor(ctx, axis.CGColor);
    CGContextFillRect(ctx, CGRectMake(4, top, 1, 120));
    CGContextFillRect(ctx, CGRectMake(4, base, w - 4, 1));
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    NSArray *gc = [NSArray arrayWithObjects:(id)RCHex(0x4fc489).CGColor, (id)RCHex(0x1f9a5a).CGColor, nil];
    CGGradientRef g = CGGradientCreateWithColors(space, (CFArrayRef)gc, NULL);
    for (NSUInteger i = 0; i < _values.count; i++) {
        CGFloat x = 4 + 18 + i * step, h = round([[[_values objectAtIndex:i] objectAtIndex:1] floatValue] / max * 100);
        CGRect bar = CGRectMake(x, base - h, 46, h);
        CGMutablePathRef p = CGPathCreateMutable();
        CGPathMoveToPoint(p, NULL, bar.origin.x, base);
        CGPathAddArcToPoint(p, NULL, bar.origin.x, bar.origin.y, CGRectGetMaxX(bar), bar.origin.y, 4);
        CGPathAddArcToPoint(p, NULL, CGRectGetMaxX(bar), bar.origin.y, CGRectGetMaxX(bar), base, 4);
        CGPathAddLineToPoint(p, NULL, CGRectGetMaxX(bar), base);
        CGPathCloseSubpath(p);
        CGContextSaveGState(ctx);
        CGContextAddPath(ctx, p); CGContextClip(ctx);
        CGContextDrawLinearGradient(ctx, g, CGPointMake(bar.origin.x, 0), CGPointMake(CGRectGetMaxX(bar), 0), 0);
        CGContextSetFillColorWithColor(ctx, RCHexA(0xffffff, .5).CGColor);
        CGContextFillRect(ctx, CGRectMake(bar.origin.x, bar.origin.y, 46, 1));
        CGContextRestoreGState(ctx);
        CGPathRelease(p);
    }
    CGGradientRelease(g);
    CGColorSpaceRelease(space);
}

- (void)revealCode {
    if (!_code || _codeView) return;
    _codeView = [[RCCodeBlockView alloc] initWithCode:_code language:(_codeLanguage ? _codeLanguage : @"python")];
    _codeView.copyEnabled = _codeCopyEnabled;
    [self addSubview:_codeView];
    _showCode.hidden = YES;
    [self notifyHeightChange];
}
@end
