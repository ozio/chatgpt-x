#import "RCTextSizeSlider.h"
#import "RCTheme.h"

static const CGFloat RCSliderInset = 26, RCSliderRow = 26;

@interface RCTextSizeSlider () { CGFloat _knobX; BOOL _dragging; UILabel *_name; }
@end

@implementation RCTextSizeSlider
+ (NSString *)titleForTextSize:(RCTextSize)size {
    NSArray *n = [NSArray arrayWithObjects:RCL(@"Smaller"), RCL(@"Small"), RCL(@"Normal"), RCL(@"Large"), RCL(@"Larger"), nil];
    return [n objectAtIndex:(NSUInteger)MAX(0, MIN(4, (int)size))];
}
@synthesize value = _value, showsStepName = _showsStepName;

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        _value = [RCTheme textSize];
        _name = [[UILabel alloc] initWithFrame:CGRectZero];
        _name.backgroundColor = [UIColor clearColor];
        _name.font = [UIFont boldSystemFontOfSize:12];
        _name.textAlignment = NSTextAlignmentCenter;
        _name.hidden = YES;
        [self addSubview:_name];
        self.isAccessibilityElement = YES;
        self.accessibilityLabel = RCL(@"Text size");
        self.accessibilityTraits = UIAccessibilityTraitAdjustable;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeChanged) name:RCThemeAppearanceDidChangeNotification object:nil];
        [self themeChanged];
    }
    return self;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; [_name release]; [super dealloc]; }

- (void)themeChanged {
    _name.textColor = [RCTheme metaTextColor];
    _name.shadowColor = [RCTheme engravedShadowColor];
    _name.shadowOffset = [RCTheme engravedShadowOffset];
    [self setNeedsDisplay];
}

- (CGFloat)heightForWidth:(CGFloat)width { return _showsStepName ? RCSliderRow + 18 : RCSliderRow; }
- (CGSize)sizeThatFits:(CGSize)size { CGFloat w = size.width > 0 ? size.width : 280; return CGSizeMake(w, [self heightForWidth:w]); }

- (CGFloat)railWidth { return MAX(1, self.bounds.size.width - RCSliderInset * 2); }
- (CGFloat)xForStep:(NSInteger)step { return RCSliderInset + [self railWidth] * step / 4.0; }
- (NSInteger)stepForX:(CGFloat)x { return MAX(0, MIN(4, (NSInteger)lround((x - RCSliderInset) / [self railWidth] * 4))); }

- (void)setShowsStepName:(BOOL)shows { _showsStepName = shows; _name.hidden = !shows; [self setNeedsLayout]; [self setNeedsDisplay]; }

- (void)setValue:(RCTextSize)value { [self setValue:value animated:NO]; }
- (void)setValue:(RCTextSize)value animated:(BOOL)animated {
    _value = (RCTextSize)MAX(0, MIN(4, (int)value));
    _name.text = [RCTextSizeSlider titleForTextSize:_value];
    self.accessibilityValue = _name.text;
    [self setNeedsDisplay];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _name.text = [RCTextSizeSlider titleForTextSize:_value];
    _name.frame = CGRectMake(0, RCSliderRow + 2, self.bounds.size.width, 16);
}

- (CGFloat)knobX { return _dragging ? _knobX : [self xForStep:_value]; }

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat w = self.bounds.size.width, kx = [self knobX];
    UIColor *a = [RCTheme metaTextColor];
    [a set];
    [@"A" drawAtPoint:CGPointMake(4, 5) withFont:[UIFont boldSystemFontOfSize:12]];
    CGSize big = [@"A" sizeWithFont:[UIFont boldSystemFontOfSize:19]];
    [@"A" drawAtPoint:CGPointMake(w - 4 - big.width, 1) withFont:[UIFont boldSystemFontOfSize:19]];
    // rail: inset groove
    CGRect rail = CGRectMake(RCSliderInset, 11, [self railWidth], 5);
    CGPathRef p = RCCreateRoundedRectPath(rail, 2.5);
    CGContextSaveGState(ctx);
    CGContextAddPath(ctx, p); CGContextClip(ctx);
    RCDrawVerticalGradient(ctx, rail, [NSArray arrayWithObjects:RCHex(0xb5c2bb), RCHex(0xe5ebe8), nil], nil);
    CGContextSetFillColorWithColor(ctx, RCHexA(0, .25).CGColor);
    CGContextFillRect(ctx, CGRectMake(rail.origin.x, rail.origin.y, rail.size.width, 1));
    CGRect fill = CGRectMake(RCSliderInset, 11, MAX(0, kx - RCSliderInset), 5);
    RCDrawVerticalGradient(ctx, fill, [NSArray arrayWithObjects:RCHex(0x6fd29d), RCHex(0x1f9a5a), nil], nil);
    CGContextRestoreGState(ctx);
    CGPathRelease(p);
    // ticks
    CGContextSetFillColorWithColor(ctx, ([RCTheme isDark] ? RCHex(0x5f7268) : RCHex(0x9eaba5)).CGColor);
    for (NSInteger i = 0; i < 5; i++) CGContextFillRect(ctx, CGRectMake(round([self xForStep:i]) - .5, 19, 1, 5));
    // knob
    CGRect k = CGRectMake(round(kx) - 13 + .5, .5, 25, 25);
    CGContextSaveGState(ctx);
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1), 2, RCHexA(0, .3).CGColor);
    CGContextSetFillColorWithColor(ctx, RCHex(0xe6e9e8).CGColor);
    CGContextFillEllipseInRect(ctx, k);
    CGContextRestoreGState(ctx);
    CGContextSaveGState(ctx);
    CGContextAddEllipseInRect(ctx, k); CGContextClip(ctx);
    RCDrawVerticalGradient(ctx, k, [NSArray arrayWithObjects:RCHex(0xcfd3d1), RCHex(0xfafbfa), nil], nil);
    CGContextRestoreGState(ctx);
    CGContextSetStrokeColorWithColor(ctx, RCHex(0x949c98).CGColor);
    CGContextSetLineWidth(ctx, 1);
    CGContextStrokeEllipseInRect(ctx, k);
}

- (void)moveTo:(CGFloat)x {
    _knobX = MAX(RCSliderInset, MIN(RCSliderInset + [self railWidth], x));
    NSInteger step = [self stepForX:_knobX];
    if (step != _value) { [self setValue:(RCTextSize)step]; [self sendActionsForControlEvents:UIControlEventValueChanged]; }
    [self setNeedsDisplay];
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    _dragging = YES;
    [self moveTo:[touch locationInView:self].x];
    return YES;
}
- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event { [self moveTo:[touch locationInView:self].x]; return YES; }
- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event { _dragging = NO; [self setNeedsDisplay]; }
- (void)cancelTrackingWithEvent:(UIEvent *)event { _dragging = NO; [self setNeedsDisplay]; }

- (void)step:(int)delta {
    int v = MAX(0, MIN(4, (int)_value + delta));
    if (v == (int)_value) return;
    [self setValue:(RCTextSize)v];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}
- (void)accessibilityIncrement { [self step:1]; }
- (void)accessibilityDecrement { [self step:-1]; }
@end
