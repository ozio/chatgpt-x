#import "RCSegmentedControl.h"
#import "RCTheme.h"

@interface RCSegmentedControl () { NSInteger _pressed; NSMutableArray *_elements; }
@end

@implementation RCSegmentedControl
@synthesize items = _items, style = _style, selectedSegmentIndex = _selected;

+ (CGFloat)height { return 30; }

- (id)initWithItems:(NSArray *)titles style:(RCSegmentedStyle)style {
    if ((self = [super initWithFrame:CGRectMake(0, 0, 300, 30)])) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        _items = [titles copy];
        _style = style;
        _selected = titles.count ? 0 : -1;
        _pressed = -1;
    }
    return self;
}
- (id)initWithFrame:(CGRect)frame { return [self initWithItems:nil style:RCSegmentedLight]; }
- (void)dealloc { [_items release]; [_elements release]; [super dealloc]; }

- (void)setItems:(NSArray *)items { [_items release]; _items = [items copy]; if (_selected >= (NSInteger)items.count) _selected = items.count ? 0 : -1; [_elements release]; _elements = nil; [self setNeedsDisplay]; }
- (void)setStyle:(RCSegmentedStyle)style { _style = style; [self setNeedsDisplay]; }
- (void)setSelectedSegmentIndex:(NSInteger)i { _selected = (i >= 0 && i < (NSInteger)_items.count) ? i : -1; [_elements release]; _elements = nil; [self setNeedsDisplay]; }

- (CGRect)rectForSegment:(NSInteger)i {
    CGFloat w = self.bounds.size.width / MAX(1, _items.count);
    return CGRectMake(round(i * w), 0, round((i + 1) * w) - round(i * w), self.bounds.size.height);
}

- (NSInteger)segmentAtPoint:(CGPoint)p {
    if (!_items.count || !CGRectContainsPoint(CGRectInset(self.bounds, -10, -12), p)) return -1;
    return MAX(0, MIN((NSInteger)_items.count - 1, (NSInteger)(p.x / (self.bounds.size.width / _items.count))));
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    BOOL light = _style == RCSegmentedLight;
    CGRect b = CGRectMake(.5, .5, self.bounds.size.width - 1, self.bounds.size.height - 2); // 1 pt for the outer highlight
    CGPathRef outer = RCCreateRoundedRectPath(b, 5);
    // box-shadow 0 1px 0 highlight
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, 0, 1);
    CGContextAddPath(ctx, outer);
    CGContextSetStrokeColorWithColor(ctx, (light ? RCHexA(0xffffff, .8) : RCHexA(0xdcffec, .25)).CGColor);
    CGContextStrokePath(ctx);
    CGContextRestoreGState(ctx);
    CGContextSaveGState(ctx);
    CGContextAddPath(ctx, outer); CGContextClip(ctx);
    NSArray *locs = [NSArray arrayWithObjects:[NSNumber numberWithFloat:0], [NSNumber numberWithFloat:.5], [NSNumber numberWithFloat:.51], [NSNumber numberWithFloat:1], nil];
    for (NSInteger i = 0; i < (NSInteger)_items.count; i++) {
        CGRect r = [self rectForSegment:i];
        BOOL sel = i == _selected || i == _pressed;
        if (light) {
            if (sel) RCDrawVerticalGradient(ctx, r, [NSArray arrayWithObjects:RCHex(0x157a49), RCHex(0x3fb47b), nil], nil);
            else RCDrawVerticalGradient(ctx, r, [NSArray arrayWithObjects:RCHex(0xffffff), RCHex(0xe5ebe8), nil], nil);
        } else {
            if (sel) RCDrawVerticalGradient(ctx, r, [NSArray arrayWithObjects:RCHex(0x094c30), RCHex(0x0f6340), nil], nil);
            else RCDrawVerticalGradient(ctx, r, [NSArray arrayWithObjects:RCHex(0x6fbc96), RCHex(0x3ea275), RCHex(0x22905d), RCHex(0x1e7f52), nil], locs);
        }
        if (sel) { // inset shadow on the selected segment
            CGContextSetFillColorWithColor(ctx, RCHexA(0, light ? .25 : .45).CGColor);
            CGContextFillRect(ctx, CGRectMake(r.origin.x, 0, r.size.width, 2));
        }
        if (i > 0) {
            CGContextSetFillColorWithColor(ctx, (light ? RCHex(0xb3bfb9) : RCHexA(0x04341e, .85)).CGColor);
            CGContextFillRect(ctx, CGRectMake(r.origin.x, 0, 1, r.size.height));
        }
        NSString *t = [_items objectAtIndex:i];
        UIFont *f = [UIFont boldSystemFontOfSize:light ? 13 : 12];
        CGSize ts = [t sizeWithFont:f constrainedToSize:CGSizeMake(r.size.width - 8, 20) lineBreakMode:NSLineBreakByTruncatingTail];
        CGRect tr = CGRectMake(r.origin.x + (r.size.width - ts.width) / 2, round((b.size.height - ts.height) / 2), ts.width, ts.height);
        BOOL whiteText = !light || sel;
        CGContextSetShadowWithColor(ctx, whiteText ? CGSizeMake(0, -1) : CGSizeMake(0, 1), 0, (whiteText ? RCHexA(0, .35) : RCHex(0xffffff)).CGColor);
        [(whiteText ? [UIColor whiteColor] : RCHex(0x4b5a53)) set];
        [t drawInRect:tr withFont:f lineBreakMode:NSLineBreakByTruncatingTail alignment:NSTextAlignmentCenter];
        CGContextSetShadowWithColor(ctx, CGSizeZero, 0, NULL);
    }
    CGContextRestoreGState(ctx);
    CGContextAddPath(ctx, outer);
    CGContextSetStrokeColorWithColor(ctx, (light ? RCHex(0x9eaba5) : RCHexA(0x04341e, .85)).CGColor);
    CGContextSetLineWidth(ctx, 1);
    CGContextStrokePath(ctx);
    CGPathRelease(outer);
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event { _pressed = [self segmentAtPoint:[touch locationInView:self]]; [self setNeedsDisplay]; return YES; }
- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    NSInteger s = [self segmentAtPoint:[touch locationInView:self]];
    if (s != _pressed) { _pressed = s; [self setNeedsDisplay]; }
    return YES;
}
- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    NSInteger s = [self segmentAtPoint:[touch locationInView:self]];
    _pressed = -1;
    if (s >= 0 && s != _selected) { self.selectedSegmentIndex = s; [self sendActionsForControlEvents:UIControlEventValueChanged]; }
    [self setNeedsDisplay];
}
- (void)cancelTrackingWithEvent:(UIEvent *)event { _pressed = -1; [self setNeedsDisplay]; }

#pragma mark - VoiceOver: one button per segment

- (BOOL)isAccessibilityElement { return NO; }
- (NSArray *)accessibilityElementsArray {
    if (!_elements) {
        _elements = [[NSMutableArray alloc] init];
        for (NSInteger i = 0; i < (NSInteger)_items.count; i++) {
            UIAccessibilityElement *e = [[[UIAccessibilityElement alloc] initWithAccessibilityContainer:self] autorelease];
            e.accessibilityLabel = [_items objectAtIndex:i];
            e.accessibilityTraits = UIAccessibilityTraitButton | (i == _selected ? UIAccessibilityTraitSelected : 0);
            e.accessibilityHint = [NSString stringWithFormat:RCL(@"%d of %d"), (int)i + 1, (int)_items.count];
            [_elements addObject:e];
        }
    }
    for (NSInteger i = 0; i < (NSInteger)_elements.count; i++)
        [(UIAccessibilityElement *)[_elements objectAtIndex:i] setAccessibilityFrame:[self.window convertRect:[self convertRect:[self rectForSegment:i] toView:nil] toWindow:nil]];
    return _elements;
}
- (NSInteger)accessibilityElementCount { return [self accessibilityElementsArray].count; }
- (id)accessibilityElementAtIndex:(NSInteger)index { NSArray *a = [self accessibilityElementsArray]; return index >= 0 && index < (NSInteger)a.count ? [a objectAtIndex:index] : nil; }
- (NSInteger)indexOfAccessibilityElement:(id)element { return [[self accessibilityElementsArray] indexOfObject:element]; }
@end
