#import "RCGoalStripView.h"
#import "RCProgressView.h"
#import "RCTheme.h"

@interface RCGoalStripView () { NSString *_goal; UIImageView *_bg; UILabel *_text, *_budget; RCProgressView *_bar; }
@end

@implementation RCGoalStripView
@synthesize budgetUsed = _budgetUsed;

- (id)initWithFrame:(CGRect)frame {
    if (CGRectIsEmpty(frame)) frame = CGRectMake(0, 0, 300, 50);
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        _bg = [[UIImageView alloc] initWithFrame:CGRectZero]; [self addSubview:_bg];
        _text = [[UILabel alloc] initWithFrame:CGRectZero]; _text.backgroundColor = [UIColor clearColor]; _text.numberOfLines = 0; _text.lineBreakMode = NSLineBreakByWordWrapping; [self addSubview:_text];
        _budget = [[UILabel alloc] initWithFrame:CGRectZero]; _budget.backgroundColor = [UIColor clearColor]; _budget.font = [UIFont boldSystemFontOfSize:12]; _budget.textAlignment = NSTextAlignmentRight; [self addSubview:_budget];
        _bar = [[RCProgressView alloc] initWithFrame:CGRectMake(0, 0, 100, 9)]; [self addSubview:_bar];
        self.isAccessibilityElement = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh) name:RCThemeAppearanceDidChangeNotification object:nil];
        [self refresh];
    }
    return self;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; [_goal release]; [_bg release]; [_text release]; [_budget release]; [_bar release]; [super dealloc]; }

- (NSString *)goal { return _goal; }
- (void)setGoal:(NSString *)g { [_goal release]; _goal = [g copy]; [self refresh]; }
- (void)setBudgetUsed:(CGFloat)u { _budgetUsed = u; [self refresh]; }
- (void)addTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvents)events { [super addTarget:target action:action forControlEvents:events]; self.accessibilityTraits = UIAccessibilityTraitButton; }

- (NSAttributedString *)goalText {
    BOOL dark = [RCTheme isDark];
    UIColor *ink = RCHex(dark ? 0xcfe0d7 : 0x33453d);
    NSMutableAttributedString *s = [[[NSMutableAttributedString alloc] initWithString:[RCL(@"Goal:") stringByAppendingString:@" "] attributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIFont boldSystemFontOfSize:13], NSFontAttributeName, ink, NSForegroundColorAttributeName, nil]] autorelease];
    [s appendAttributedString:[[[NSAttributedString alloc] initWithString:RCDisplayText(_goal ? _goal : @"") attributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIFont systemFontOfSize:13], NSFontAttributeName, ink, NSForegroundColorAttributeName, nil]] autorelease]];
    return s;
}
- (NSString *)budgetText {
    if (_budgetUsed < 0) return nil;
    if (_budgetUsed >= 1) return RCL(@"budget used up");
    return [NSString stringWithFormat:RCL(@"budget %d %%"), (int)lround(_budgetUsed * 100)];
}

- (void)refresh {
    BOOL dark = [RCTheme isDark], hl = self.highlighted;
    _bg.image = [RCTheme imageForKey:[NSString stringWithFormat:@"cx-goal-%d%d", dark, hl] size:CGSizeMake(20, 20) capInsets:UIEdgeInsetsMake(9, 9, 9, 9) drawing:^(CGContextRef ctx, CGRect r) {
        CGRect b = CGRectInset(r, .5, .5); CGPathRef p = RCCreateRoundedRectPath(b, 9);
        CGContextAddPath(ctx, p); CGContextSetFillColorWithColor(ctx, RCHex(hl ? (dark ? 0x24342c : 0xe2f1e9) : (dark ? 0x1d2a24 : 0xffffff)).CGColor); CGContextFillPath(ctx);
        CGContextAddPath(ctx, p); CGContextSetStrokeColorWithColor(ctx, RCHex(dark ? 0x2c3d35 : 0xaebbb4).CGColor); CGContextSetLineWidth(ctx, 1); CGContextStrokePath(ctx); CGPathRelease(p);
    }];
    _text.attributedText = [self goalText];
    _budget.text = [self budgetText];
    _budget.textColor = _budgetUsed >= .9 ? RCHex(dark ? 0xffc874 : 0xa26b00) : RCHex(dark ? 0x8fa39a : 0x6b7a72);
    _bar.hidden = _budgetUsed < 0;
    _bar.tint = _budgetUsed >= .9 ? RCProgressAmber : RCProgressGreen;
    _bar.progress = MAX(0, MIN(1, _budgetUsed));
    self.accessibilityLabel = [NSString stringWithFormat:@"%@ %@", RCL(@"Goal:"), _goal ? _goal : @""];
    self.accessibilityValue = [self budgetText];
    [self setNeedsLayout];
}
- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; [self refresh]; }

- (CGFloat)textWidth:(CGFloat)w { return w - 20 - (_budgetUsed < 0 ? 0 : 128); }
- (CGFloat)heightForWidth:(CGFloat)w {
    CGFloat th = ceil([[self goalText] boundingRectWithSize:CGSizeMake([self textWidth:w], 1000) options:NSStringDrawingUsesLineFragmentOrigin context:nil].size.height);
    return 8 + MAX(17, th) + (_budgetUsed < 0 ? 0 : 6 + 9) + 9;
}
- (CGSize)sizeThatFits:(CGSize)s { return CGSizeMake(s.width, [self heightForWidth:s.width]); }
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width, tw = [self textWidth:w];
    CGFloat th = MAX(17, ceil([_text.attributedText boundingRectWithSize:CGSizeMake(tw, 1000) options:NSStringDrawingUsesLineFragmentOrigin context:nil].size.height));
    _bg.frame = self.bounds;
    _text.frame = CGRectMake(10, 8, tw, th);
    _budget.frame = CGRectMake(w - 10 - 122, 8, 122, 17);
    _bar.frame = CGRectMake(10, 8 + th + 6, w - 20, 9);
}
@end
