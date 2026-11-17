#import "RCClarifyPartView.h"
#import "RCTheme.h"
#import <QuartzCore/QuartzCore.h> // headers only (layer messages), no QuartzCore link

@implementation RCClarifyQuestion
@synthesize text = _text, options = _options, multiple = _multiple, requiresAnswer = _requiresAnswer;
+ (id)questionWithText:(NSString *)text options:(NSArray *)options multiple:(BOOL)multiple {
    RCClarifyQuestion *q = [[[self alloc] init] autorelease]; q.text = text; q.options = options; q.multiple = multiple; return q;
}
- (void)dealloc { [_text release]; [_options release]; [super dealloc]; }
@end

@interface RCClarifyOption : UIControl { @public UILabel *_label; UIView *_check; BOOL _checked; }
@end
@implementation RCClarifyOption
- (id)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        _label = [[UILabel alloc] initWithFrame:CGRectZero];
        _label.backgroundColor = [UIColor clearColor]; _label.font = [UIFont systemFontOfSize:15]; _label.numberOfLines = 0; _label.lineBreakMode = NSLineBreakByWordWrapping;
        [self addSubview:_label];
        _check = [[RCTheme checkmarkAccessoryView] retain];
        [self addSubview:_check];
        self.isAccessibilityElement = YES;
        [self apply];
    }
    return self;
}
- (void)dealloc { [_label release]; [_check release]; [super dealloc]; }
- (void)apply {
    BOOL dark = [RCTheme isDark];
    self.backgroundColor = self.highlighted ? RCHex(dark ? 0x2a3a33 : 0xe2f1e9) : (dark ? RCHex(0x1d2a24) : [UIColor whiteColor]);
    _label.textColor = [RCPartView colorForRole:RCPartTextTitle];
    _check.hidden = !_checked;
    self.accessibilityLabel = _label.text;
    self.accessibilityTraits = UIAccessibilityTraitButton | (_checked ? UIAccessibilityTraitSelected : 0);
}
- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; [self apply]; }
- (void)layoutSubviews {
    [super layoutSubviews];
    _label.frame = CGRectMake(10, 10, self.bounds.size.width - 44, self.bounds.size.height - 20);
    _check.frame = CGRectMake(self.bounds.size.width - 12 - 16, floor((self.bounds.size.height - 16) / 2), 16, 16);
}
@end

@interface RCClarifyPartView () { NSArray *_questions; NSMutableArray *_selections, *_own, *_options; UILabel *_question, *_counter; UITextField *_ownField; UIView *_ownWrap; RCButton *_skip, *_next; NSUInteger _index; BOOL _answered; CGFloat _ownTop, _footTop; }
@end

@implementation RCClarifyPartView
@synthesize currentIndex = _index, answered = _answered;

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.plainFill = YES; self.fillTop = 0xf4f7f5;
        _selections = [[NSMutableArray alloc] init];
        _own = [[NSMutableArray alloc] init];
        _options = [[NSMutableArray alloc] init];
        _question = [[self labelWithRole:RCPartTextTitle font:[UIFont boldSystemFontOfSize:15]] retain];
        _question.numberOfLines = 0;
        _question.lineBreakMode = NSLineBreakByWordWrapping;
        _counter = [[self labelWithRole:RCPartTextSecondary font:[UIFont boldSystemFontOfSize:12]] retain];
        _counter.textAlignment = NSTextAlignmentRight;
        _ownWrap = [[UIView alloc] initWithFrame:CGRectZero];
        [self addSubview:_ownWrap];
        _ownField = [[UITextField alloc] initWithFrame:CGRectZero];
        _ownField.borderStyle = UITextBorderStyleNone;
        _ownField.font = [UIFont systemFontOfSize:14];
        _ownField.placeholder = RCL(@"Your own answer");
        _ownField.layer.cornerRadius = 5;
        _ownField.layer.borderWidth = 1;
        _ownField.layer.borderColor = RCHex(0xb7c5be).CGColor;
        _ownField.backgroundColor = [UIColor whiteColor];
        _ownField.leftView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 8)] autorelease];
        _ownField.leftViewMode = UITextFieldViewModeAlways;
        _ownField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        _ownField.returnKeyType = UIReturnKeyNext;
        _ownField.delegate = self;
        [_ownField addTarget:self action:@selector(ownAnswerChanged) forControlEvents:UIControlEventEditingChanged];
        [_ownWrap addSubview:_ownField];
        _skip = [[RCButton buttonWithStyle:RCButtonStylePill title:RCL(@"Skip")] retain];
        _next = [[RCButton buttonWithStyle:RCButtonStylePillGo title:RCL(@"Next")] retain];
        [_skip addTarget:self action:@selector(advance) forControlEvents:UIControlEventTouchUpInside];
        [_next addTarget:self action:@selector(advance) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_skip]; [self addSubview:_next];
        [self applyAppearance];
    }
    return self;
}

- (void)dealloc { _ownField.delegate = nil; [_questions release]; [_selections release]; [_own release]; [_options release]; [_question release]; [_counter release]; [_ownField release]; [_ownWrap release]; [_skip release]; [_next release]; [super dealloc]; }

- (void)applyAppearance {
    [super applyAppearance];
    BOOL dark = [RCTheme isDark];
    _ownWrap.backgroundColor = dark ? RCHex(0x1d2a24) : [UIColor whiteColor];
    for (RCClarifyOption *o in _options) [o apply];
}

- (NSArray *)questions { return _questions; }
- (void)setQuestions:(NSArray *)q {
    [_questions release]; _questions = [q copy];
    [_selections removeAllObjects]; [_own removeAllObjects];
    for (NSUInteger i = 0; i < _questions.count; i++) { [_selections addObject:[NSMutableIndexSet indexSet]]; [_own addObject:@""]; }
    _index = 0; _answered = NO;
    [self show];
}

- (void)show {
    for (UIView *v in _options) [v removeFromSuperview];
    [_options removeAllObjects];
    if (!_questions.count) return;
    RCClarifyQuestion *q = [_questions objectAtIndex:_index];
    RCLabelSetText(_question, RCDisplayText(q.text));
    _counter.text = [NSString stringWithFormat:RCL(@"%lu of %lu"), (unsigned long)_index + 1, (unsigned long)_questions.count];
    NSIndexSet *sel = [_selections objectAtIndex:_index];
    NSUInteger i = 0;
    for (NSString *t in q.options) {
        RCClarifyOption *o = [[[RCClarifyOption alloc] initWithFrame:CGRectZero] autorelease];
        RCLabelSetText(o->_label, RCDisplayText(t)); o->_checked = [sel containsIndex:i]; o.tag = i++;
        [o addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventTouchUpInside];
        o.enabled = !_answered;
        [o apply];
        [self addSubview:o];
        [_options addObject:o];
    }
    _ownField.text = [_own objectAtIndex:_index];
    _ownField.enabled = !_answered;
    _ownWrap.hidden = q.ownAnswerHidden;
    [_next setTitle:(_index + 1 < _questions.count ? RCL(@"Next") : RCL(@"Answer")) forState:UIControlStateNormal];
    [_next sizeToFit];
    _skip.enabled = !_answered;
    [self updateAnswerAvailability];
    self.alpha = _answered ? .6 : 1;
    [self notifyHeightChange];
}

- (void)toggle:(RCClarifyOption *)o {
    RCClarifyQuestion *q = [_questions objectAtIndex:_index];
    NSMutableIndexSet *sel = [_selections objectAtIndex:_index];
    NSUInteger n = (NSUInteger)o.tag;
    if (q.multiple) { if ([sel containsIndex:n]) [sel removeIndex:n]; else [sel addIndex:n]; }
    else { [sel removeAllIndexes]; [sel addIndex:n]; }
    if (!q.multiple) { _ownField.text = @""; [_own replaceObjectAtIndex:_index withObject:@""]; }
    for (RCClarifyOption *x in _options) { x->_checked = [sel containsIndex:(NSUInteger)x.tag]; [x apply]; }
    [self updateAnswerAvailability];
}

- (void)updateAnswerAvailability {
    if (!_questions.count) return;
    RCClarifyQuestion *q = _questions[_index];
    BOOL selected = [_selections[_index] count] > 0;
    BOOL own = !q.ownAnswerHidden && [[_ownField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] length] > 0;
    _skip.hidden = q.requiresAnswer;
    _next.enabled = !_answered && (!q.requiresAnswer || selected || own);
}
- (void)ownAnswerChanged {
    if (!_questions.count) return;
    RCClarifyQuestion *q = _questions[_index];
    if (!q.multiple && _ownField.text.length) {
        [_selections[_index] removeAllIndexes];
        for (RCClarifyOption *x in _options) { x->_checked = NO; [x apply]; }
    }
    [self updateAnswerAvailability];
}
- (BOOL)textFieldShouldReturn:(UITextField *)f { [self advance]; return NO; }

- (void)advance {
    if (_answered) return;
    [self updateAnswerAvailability]; if (!_next.enabled) return;
    [_own replaceObjectAtIndex:_index withObject:(_ownField.text ? _ownField.text : @"")];
    [_ownField resignFirstResponder];
    if (_index + 1 < _questions.count) { _index++; [self show]; return; }
    _answered = YES;
    NSMutableArray *lines = [NSMutableArray array];
    for (NSUInteger k = 0; k < _questions.count; k++) {
        RCClarifyQuestion *q = [_questions objectAtIndex:k];
        NSMutableArray *picked = [NSMutableArray array];
        [[_selections objectAtIndex:k] enumerateIndexesUsingBlock:^(NSUInteger i, BOOL *stop) { if (i < q.options.count) [picked addObject:[q.options objectAtIndex:i]]; }];
        NSString *own = [_own objectAtIndex:k];
        if (own.length) [picked addObject:own];
        [lines addObject:[NSString stringWithFormat:@"%@ %@", q.text, (picked.count ? [picked componentsJoinedByString:@", "] : RCL(@"no preference"))]];
    }
    [self show];
    id d = self.delegate;
    if ([d respondsToSelector:@selector(clarifyPart:didFinishWithSelections:)]) {
        NSMutableArray *structured = [NSMutableArray array];
        for (NSUInteger k = 0; k < _questions.count; k++) {
            NSMutableArray *indexes = [NSMutableArray array];
            [[_selections objectAtIndex:k] enumerateIndexesUsingBlock:^(NSUInteger i, BOOL *stop) { [indexes addObject:[NSNumber numberWithUnsignedInteger:i]]; }];
            [structured addObject:[NSDictionary dictionaryWithObjectsAndKeys:indexes, @"options", ([[_questions objectAtIndex:k] ownAnswerHidden] ? @"" : [_own objectAtIndex:k]), @"text", nil]];
        }
        [d clarifyPart:self didFinishWithSelections:structured];
    }
    if ([d respondsToSelector:@selector(clarifyPart:didFinishWithAnswer:)]) [d clarifyPart:self didFinishWithAnswer:[lines componentsJoinedByString:@"\n"]];
}

- (CGFloat)layoutForWidth:(CGFloat)w apply:(BOOL)apply {
    CGFloat qh = _question.text.length ? RCMeasureText(_question.text, _question.font, w - 20 - 50).height : 18;
    if (apply) { _question.frame = CGRectMake(10, 9, w - 20 - 50, qh); _counter.frame = CGRectMake(w - 10 - 60, 11, 60, 15); }
    CGFloat y = 9 + qh + 6;
    for (RCClarifyOption *o in _options) {
        CGFloat h = RCMeasureText(o->_label.text, o->_label.font, w - 44).height + 20;
        if (apply) o.frame = CGRectMake(0, y + 1, w, h);
        y += 1 + h;
    }
    _ownTop = y;
    BOOL own = !_questions.count || ![[_questions objectAtIndex:_index] ownAnswerHidden];
    if (apply) { _ownWrap.frame = CGRectMake(0, y + 1, w, own ? 44 : 0); _ownField.frame = CGRectMake(10, 7, w - 20, 30); }
    if (own) y += 1 + 44;
    _footTop = y;
    if (apply) {
        CGFloat x = w - 10;
        for (RCButton *b in [NSArray arrayWithObjects:_next, _skip, nil]) { x -= b.frame.size.width; b.frame = CGRectMake(x, y + 8, b.frame.size.width, 26); x -= 6; }
    }
    return y + 8 + 26 + 8;
}

- (void)drawContent:(CGContextRef)ctx {
    for (RCClarifyOption *o in _options) [self drawHairlineAtY:o.frame.origin.y - 1 context:ctx];
    if (_ownTop != _footTop) [self drawHairlineAtY:_ownTop context:ctx];
    [self drawHairlineAtY:_footTop context:ctx];
}
@end
