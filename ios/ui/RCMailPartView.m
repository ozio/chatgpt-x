#import "RCMailPartView.h"
#import "RCTheme.h"

@interface RCMailPartView () { NSMutableArray *_fields, *_fieldLabels; UITextView *_bodyView; }
@end

@implementation RCMailPartView
@synthesize clipboardButton = _copy, sendButton = _send, sendEnabled = _sendEnabled;

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.plainFill = YES; self.fillTop = 0xffffff;
        _fields = [[NSMutableArray alloc] init];
        _fieldLabels = [[NSMutableArray alloc] init];
        NSArray *names = [NSArray arrayWithObjects:RCL(@"To:"), RCL(@"Cc:"), RCL(@"Subject:"), nil];
        for (NSString *n in names) {
            UILabel *l = [self labelWithRole:RCPartTextSecondary font:[UIFont systemFontOfSize:14]];
            l.text = n;
            [_fieldLabels addObject:l];
            UITextField *f = [[[UITextField alloc] initWithFrame:CGRectZero] autorelease];
            f.font = [UIFont systemFontOfSize:14];
            f.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
            f.delegate = self;
            f.accessibilityLabel = [n stringByReplacingOccurrencesOfString:@":" withString:@""];
            [self addSubview:f];
            [_fields addObject:f];
        }
        [[_fields objectAtIndex:0] setPlaceholder:RCL(@"address")];
        [[_fields objectAtIndex:0] setKeyboardType:UIKeyboardTypeEmailAddress];
        [[_fields objectAtIndex:0] setAutocapitalizationType:UITextAutocapitalizationTypeNone];
        [[_fields objectAtIndex:1] setKeyboardType:UIKeyboardTypeEmailAddress];
        [[_fields objectAtIndex:1] setAutocapitalizationType:UITextAutocapitalizationTypeNone];
        _bodyView = [[UITextView alloc] initWithFrame:CGRectZero];
        _bodyView.backgroundColor = [UIColor clearColor];
        _bodyView.font = [UIFont systemFontOfSize:14];
        _bodyView.accessibilityLabel = RCL(@"Message body");
        [self addSubview:_bodyView];
        _copy = [[RCButton buttonWithStyle:RCButtonStylePill title:RCL(@"Copy")] retain];
        _send = [[RCButton buttonWithStyle:RCButtonStylePillGo title:RCL(@"Send…")] retain];
        [self addSubview:_copy]; [self addSubview:_send];
        _send.hidden = YES;
        [self applyAppearance];
    }
    return self;
}

- (void)dealloc { for (UITextField *f in _fields) f.delegate = nil; [_fields release]; [_fieldLabels release]; [_bodyView release]; [_copy release]; [_send release]; [super dealloc]; }

- (void)applyAppearance {
    [super applyAppearance];
    UIColor *ink = [RCPartView colorForRole:RCPartTextTitle];
    for (UITextField *f in _fields) f.textColor = ink;
    _bodyView.textColor = ink;
}

- (UITextField *)field:(NSUInteger)i { return [_fields objectAtIndex:i]; }
- (NSString *)to { return [self field:0].text; }
- (void)setTo:(NSString *)v { [self field:0].text = v; }
- (NSString *)cc { return [self field:1].text; }
- (void)setCc:(NSString *)v { [self field:1].text = v; }
- (NSString *)subject { return [self field:2].text; }
- (void)setSubject:(NSString *)v { [self field:2].text = v; }
- (NSString *)body { return _bodyView.text; }
- (void)setBody:(NSString *)v {
    // iOS 6.1.4 UITextView -setText: flattens line breaks; attributedText keeps them.
    NSDictionary *a = RCTextViewAttributes(_bodyView.font, [RCPartView colorForRole:RCPartTextTitle]);
    _bodyView.attributedText = [[[NSAttributedString alloc] initWithString:(v ? v : @"") attributes:a] autorelease];
}
- (void)setSendEnabled:(BOOL)v { _sendEnabled = v; _send.hidden = !v; [self setNeedsLayout]; }

- (BOOL)textFieldShouldReturn:(UITextField *)f {
    NSUInteger i = [_fields indexOfObject:f];
    if (i + 1 < _fields.count) [[_fields objectAtIndex:i + 1] becomeFirstResponder]; else [_bodyView becomeFirstResponder];
    return NO;
}

- (CGFloat)layoutForWidth:(CGFloat)w apply:(BOOL)apply {
    CGFloat y = 0;
    for (NSUInteger i = 0; i < 3; i++) {
        if (apply) { [[_fieldLabels objectAtIndex:i] setFrame:CGRectMake(10, y, 56, 36)]; [[_fields objectAtIndex:i] setFrame:CGRectMake(68, y + 1, w - 78, 34)]; }
        y += 37;
    }
    if (apply) _bodyView.frame = CGRectMake(2, y, w - 4, 150);
    y += 150;
    if (apply) {
        CGFloat x = w - 10;
        for (RCButton *b in [NSArray arrayWithObjects:_send, _copy, nil]) { if (b.hidden) continue; x -= b.frame.size.width; b.frame = CGRectMake(x, y + 8, b.frame.size.width, 26); x -= 6; }
    }
    return y + 8 + 26 + 8;
}

- (void)drawContent:(CGContextRef)ctx {
    for (int i = 1; i <= 3; i++) [self drawHairlineAtY:i * 37 - 1 context:ctx];
    [self drawFooterFromY:3 * 37 + 150 context:ctx];
}
@end
