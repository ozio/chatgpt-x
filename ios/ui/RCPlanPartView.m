#import "RCPlanPartView.h"
#import "RCGlyph.h"
#import "RCButton.h"
#import "RCTheme.h"

#define RC_PL_HEAD 31

@implementation RCPlanStep
@synthesize text = _text, done = _done;
+ (id)stepWithText:(NSString *)text done:(BOOL)done { RCPlanStep *s = [[[self alloc] init] autorelease]; s.text = text; s.done = done; return s; }
- (void)dealloc { [_text release]; [super dealloc]; }
@end

static UIImage *RCPlanCircle(BOOL done, NSUInteger n) {
    BOOL dark = [RCTheme isDark];
    NSString *key = done ? [NSString stringWithFormat:@"cx-plan-ok-%d", dark] : [NSString stringWithFormat:@"cx-plan-%lu-%d", (unsigned long)n, dark];
    return [RCTheme imageForKey:key size:CGSizeMake(21, 21) capInsets:UIEdgeInsetsZero drawing:^(CGContextRef ctx, CGRect r) {
        CGRect c = CGRectMake(1, 1, 19, 19);
        CGContextSaveGState(ctx); CGContextAddEllipseInRect(ctx, c); CGContextClip(ctx);
        RCDrawVerticalGradient(ctx, c, done ? [NSArray arrayWithObjects:RCHex(0x7fdcab), RCHex(0x1e9656), nil]
                                            : [NSArray arrayWithObjects:RCHex(dark ? 0x3a4d44 : 0xffffff), RCHex(dark ? 0x26352e : 0xe6ece9), nil], nil);
        CGContextRestoreGState(ctx);
        CGContextAddEllipseInRect(ctx, CGRectInset(c, .5, .5));
        CGContextSetStrokeColorWithColor(ctx, RCHex(done ? 0x0f5c37 : (dark ? 0x4a5e55 : 0xaebbb4)).CGColor); CGContextSetLineWidth(ctx, 1); CGContextStrokePath(ctx);
        if (done) {
            CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor); CGContextSetLineWidth(ctx, 2.2);
            CGContextSetLineCap(ctx, kCGLineCapRound); CGContextSetLineJoin(ctx, kCGLineJoinRound);
            CGContextMoveToPoint(ctx, 6.5, 11); CGContextAddLineToPoint(ctx, 9.5, 14); CGContextAddLineToPoint(ctx, 15, 7.5); CGContextStrokePath(ctx);
        } else {
            NSString *s = [NSString stringWithFormat:@"%lu", (unsigned long)n];
            CGContextSetFillColorWithColor(ctx, RCHex(dark ? 0xcfe0d7 : 0x4b5d55).CGColor);
            [s drawInRect:CGRectMake(1, 4, 19, 13) withFont:[UIFont boldSystemFontOfSize:11] lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentCenter];
        }
        (void)r;
    }];
}

@interface RCPlanPartView () { NSArray *_steps; UIImageView *_glyph; UILabel *_head, *_wait; NSMutableArray *_rows; RCButton *_edit, *_go; UIActivityIndicatorView *_spin; CGFloat _buttonsTop; }
@end

@implementation RCPlanPartView
@synthesize state = _state, busy = _busy, planDelegate = _planDelegate;

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.plainFill = YES; self.fillTop = 0xffffff;
        _glyph = [[UIImageView alloc] initWithFrame:CGRectMake(10, 8, 16, 16)]; [self addSubview:_glyph];
        _head = [[self labelWithRole:RCPartTextTitle font:[UIFont boldSystemFontOfSize:14]] retain];
        _head.text = RCL(@"Plan"); _head.accessibilityTraits = UIAccessibilityTraitHeader;
        _wait = [[UILabel alloc] initWithFrame:CGRectZero]; _wait.backgroundColor = [UIColor clearColor]; _wait.font = [UIFont boldSystemFontOfSize:12]; _wait.textAlignment = NSTextAlignmentRight; _wait.text = RCL(@"waiting for approval"); _wait.isAccessibilityElement = NO; [self addSubview:_wait];
        _rows = [[NSMutableArray alloc] init];
        _edit = [[RCButton buttonWithStyle:RCButtonStyleLarge title:RCL(@"Change")] retain]; _edit.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        _edit.accessibilityHint = RCL(@"Write what to change in the plan");
        [_edit addTarget:self action:@selector(tapEdit) forControlEvents:UIControlEventTouchUpInside]; [self addSubview:_edit];
        _go = [[RCButton buttonWithStyle:RCButtonStyleLargeGreen title:RCL(@"Run the plan")] retain]; _go.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        [_go addTarget:self action:@selector(tapGo) forControlEvents:UIControlEventTouchUpInside]; [self addSubview:_go];
        _spin = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray]; _spin.hidesWhenStopped = YES; [self addSubview:_spin];
        [self refresh];
    }
    return self;
}
- (void)dealloc { [_steps release]; [_glyph release]; [_head release]; [_wait release]; [_rows release]; [_edit release]; [_go release]; [_spin release]; [super dealloc]; }

- (NSArray *)steps { return _steps; }
- (void)setSteps:(NSArray *)steps {
    [_steps release]; _steps = [steps copy];
    for (NSArray *r in _rows) for (UIView *v in r) [v removeFromSuperview];
    [_rows removeAllObjects];
    for (NSUInteger i = 0; i < _steps.count; i++) {
        UIImageView *c = [[[UIImageView alloc] initWithFrame:CGRectZero] autorelease]; [self addSubview:c];
        UILabel *t = [self labelWithRole:RCPartTextBody font:[UIFont systemFontOfSize:14]]; t.numberOfLines = 0; t.lineBreakMode = NSLineBreakByWordWrapping;
        [_rows addObject:[NSArray arrayWithObjects:c, t, nil]];
    }
    [self refresh]; [self notifyHeightChange];
}
- (void)setState:(RCPlanState)s { _state = s; if (s != RCPlanProposed) _busy = NO; [self refresh]; [self notifyHeightChange]; }
- (void)setBusy:(BOOL)b { _busy = b; [self refresh]; [self notifyHeightChange]; }
- (void)applyAppearance { [super applyAppearance]; [self refresh]; }

- (void)refresh {
    BOOL dark = [RCTheme isDark], proposed = _state == RCPlanProposed;
    _glyph.image = [RCGlyph imageNamed:@"sliders" size:16 color:RCHex(dark ? 0x8fcfab : 0x3c6f57)];
    _wait.hidden = !proposed; _wait.textColor = RCHex(dark ? 0x7fb5f5 : 0x1a5fc4);
    _head.accessibilityValue = proposed ? RCL(@"waiting for approval") : (_state == RCPlanFinished ? RCL(@"done") : nil);
    NSUInteger i = 0;
    for (NSArray *r in _rows) {
        RCPlanStep *s = [_steps objectAtIndex:i];
        UIImageView *c = [r objectAtIndex:0]; UILabel *t = [r objectAtIndex:1];
        c.image = RCPlanCircle(s.done, i + 1);
        RCLabelSetText(t, RCDisplayText(s.text));
        t.textColor = s.done ? [RCPartView colorForRole:RCPartTextSecondary] : [RCPartView colorForRole:RCPartTextTitle];
        t.accessibilityLabel = [NSString stringWithFormat:@"%lu. %@", (unsigned long)(i + 1), s.text];
        t.accessibilityValue = s.done ? RCL(@"done") : nil;
        i++;
    }
    _edit.hidden = _go.hidden = !proposed || _busy;
    if (proposed && _busy) [_spin startAnimating]; else [_spin stopAnimating];
    _spin.activityIndicatorViewStyle = dark ? UIActivityIndicatorViewStyleWhite : UIActivityIndicatorViewStyleGray;
    [self setNeedsLayout]; [self setNeedsDisplay];
}

- (CGFloat)layoutForWidth:(CGFloat)w apply:(BOOL)apply {
    if (apply) { _head.frame = CGRectMake(32, 0, w - 140, RC_PL_HEAD); _wait.frame = CGRectMake(w - 140, 0, 130, RC_PL_HEAD); }
    CGFloat y = RC_PL_HEAD + 1;
    for (NSArray *r in _rows) {
        UILabel *t = [r objectAtIndex:1];
        CGFloat tw = w - 38 - 10, th = ceil(RCMeasureText(t.text, t.font, tw).height), h = MAX(35, th + 16);
        if (apply) { [[r objectAtIndex:0] setFrame:CGRectMake(9, y + 7, 21, 21)]; t.frame = CGRectMake(38, y + floor((h - th) / 2), tw, th); }
        y += h;
    }
    _buttonsTop = -1;
    if (_state == RCPlanProposed) {
        _buttonsTop = y;
        if (_busy) { if (apply) _spin.center = CGPointMake(w / 2, y + 10 + 22); }
        else if (apply) { CGFloat ew = MIN(floor((w - 30) / 2), ceil([_edit.currentTitle sizeWithFont:_edit.titleLabel.font].width) + 32); _edit.frame = CGRectMake(10, y + 10, ew, 44); _go.frame = CGRectMake(10 + ew + 10, y + 10, w - 30 - ew, 44); }
        y += 10 + 44 + 10;
    }
    return y + 1;
}

- (void)drawContent:(CGContextRef)ctx {
    BOOL dark = [RCTheme isDark];
    if (dark) { CGContextSetFillColorWithColor(ctx, RCHex(0x1d2a24).CGColor); CGContextFillRect(ctx, self.bounds); }
    RCDrawVerticalGradient(ctx, CGRectMake(0, 0, self.bounds.size.width, RC_PL_HEAD), [NSArray arrayWithObjects:RCHex(dark ? 0x26352e : 0xf7faf8), RCHex(dark ? 0x1f2c26 : 0xe9efec), nil], nil);
    [self drawHairlineAtY:RC_PL_HEAD context:ctx];
    CGFloat y = RC_PL_HEAD + 1;
    for (NSUInteger i = 0; i < _rows.count; i++) {
        UILabel *t = [[_rows objectAtIndex:i] objectAtIndex:1];
        if (i) [self drawHairlineAtY:y context:ctx];
        y += MAX(35, ceil(RCMeasureText(t.text, t.font, self.bounds.size.width - 48).height) + 16);
    }
    if (_buttonsTop >= 0) [self drawHairlineAtY:_buttonsTop context:ctx];
}

- (void)tapGo { if ([_planDelegate respondsToSelector:@selector(planPartDidAccept:)]) [_planDelegate planPartDidAccept:self]; }
- (void)tapEdit { if ([_planDelegate respondsToSelector:@selector(planPartDidAskToEdit:)]) [_planDelegate planPartDidAskToEdit:self]; }
@end
