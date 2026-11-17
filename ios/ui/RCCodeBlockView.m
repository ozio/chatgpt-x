#import "RCCodeBlockView.h"
#import "RCTextStackView.h"
#import "RCTheme.h"
#import <QuartzCore/QuartzCore.h> // headers only (layer messages), no QuartzCore link

@interface RCCodeBlockView () { NSString *_code; UILabel *_lang; RCTextStackView *_text; UIImageView *_head; UIButton *_copy; UIScrollView *_scroll; CGSize _textSize; BOOL _dying; }
@end

@implementation RCCodeBlockView
@synthesize code = _code, copyEnabled = _copyEnabled, delegate = _delegate, blockIndex = _blockIndex;

+ (UIFont *)codeFont {
    UIFont *f = [UIFont fontWithName:@"Menlo-Regular" size:11.5];
    return f ? f : [UIFont fontWithName:@"Courier" size:12];
}

static NSAttributedString *RCHighlight(NSString *code) {
    UIFont *font = [RCCodeBlockView codeFont];
    NSMutableParagraphStyle *ps = [[[NSMutableParagraphStyle alloc] init] autorelease];
    ps.minimumLineHeight = 16; ps.maximumLineHeight = 16;
    NSMutableAttributedString *s = [[[NSMutableAttributedString alloc] initWithString:code attributes:
        [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, RCHex(0xd8efe2), NSForegroundColorAttributeName, ps, NSParagraphStyleAttributeName, nil]] autorelease];
    NSArray *rules = [NSArray arrayWithObjects:
        [NSArray arrayWithObjects:@"\\b(import|from|with|as|for|in|if|else|elif|return|def|class|print|open|float|sum|len|list|let|var|const|function|NSString|alloc|init|initWithFormat|release|self)\\b", RCHex(0xf3b95f), nil],
        [NSArray arrayWithObjects:@"@?\"[^\"\\n]*\"|'[^'\\n]*'", RCHex(0x9fe0a9), nil],
        [NSArray arrayWithObjects:@"//[^\\n]*|#[^\\n]*", RCHex(0x7c958a), nil], nil];
    for (NSArray *rule in rules) {
        NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:[rule objectAtIndex:0] options:0 error:NULL];
        for (NSTextCheckingResult *m in [re matchesInString:code options:0 range:NSMakeRange(0, code.length)])
            [s addAttribute:NSForegroundColorAttributeName value:[rule objectAtIndex:1] range:m.range];
    }
    return s;
}

- (id)initWithCode:(NSString *)code language:(NSString *)language {
    if ((self = [super initWithFrame:CGRectMake(0, 0, 280, 60)])) {
        _code = [code copy]; _blockIndex = -1;
        self.backgroundColor = RCHex(0x1b2b24);
        self.contentMode = UIViewContentModeRedraw;
        self.layer.cornerRadius = 7;
        self.layer.borderWidth = 1;
        self.layer.borderColor = RCHex(0x10241b).CGColor;
        self.clipsToBounds = YES;
        _lang = [[UILabel alloc] initWithFrame:CGRectZero];
        _lang.backgroundColor = [UIColor clearColor];
        NSDictionary *la = [NSDictionary dictionaryWithObjectsAndKeys:[UIFont boldSystemFontOfSize:11], NSFontAttributeName, RCHex(0xa9c4b6), NSForegroundColorAttributeName, [NSNumber numberWithFloat:.5], NSKernAttributeName, nil];
        _lang.attributedText = [[[NSAttributedString alloc] initWithString:[(language.length ? language : RCL(@"code")) uppercaseString] attributes:la] autorelease];
        _lang.shadowColor = [UIColor blackColor]; _lang.shadowOffset = CGSizeMake(0, -1);
        [self addSubview:_lang];
        _copy = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        _copy.titleLabel.font = [UIFont boldSystemFontOfSize:11];
        [_copy setTitle:RCL(@"Copy") forState:UIControlStateNormal];
        [_copy setTitleColor:RCHex(0xe6f4ec) forState:UIControlStateNormal];
        [_copy setTitleColor:RCHex(0x7fdcab) forState:UIControlStateHighlighted];
        _copy.titleLabel.shadowOffset = CGSizeMake(0, -1);
        [_copy setTitleShadowColor:[UIColor blackColor] forState:UIControlStateNormal];
        _copy.accessibilityLabel = RCL(@"Copy code");
        [_copy addTarget:self action:@selector(copyCode) forControlEvents:UIControlEventTouchUpInside];
        _copy.hidden = YES;
        [self addSubview:_copy];
        _scroll = [[UIScrollView alloc] initWithFrame:CGRectZero];
        _scroll.showsVerticalScrollIndicator = NO;
        _scroll.indicatorStyle = UIScrollViewIndicatorStyleWhite;
        _scroll.alwaysBounceHorizontal = NO;
        [self addSubview:_scroll];
        // Long code is a stack of labels and at most 1800 pt wide: on the iPhone 5 a
        // layer beyond the GPU texture limit (2048 pt at 2x) is not drawn.
        _text = [[RCTextStackView alloc] initWithFrame:CGRectZero];
        _text.attributedText = RCHighlight(_code);
        _text.isAccessibilityElement = YES;
        _text.accessibilityLabel = _code;
        [_scroll addSubview:_text];
        CGFloat tw = 0;
        for (NSAttributedString *chunk in [RCTextStackView chunksOfAttributedString:_text.attributedText]) tw = MAX(tw, [chunk boundingRectWithSize:CGSizeMake(1800, 100000) options:NSStringDrawingUsesLineFragmentOrigin context:nil].size.width);
        tw = MIN(1800, ceil(tw));
        _textSize = CGSizeMake(tw, [_text heightForWidth:tw]);
        _head = [[UIImageView alloc] initWithImage:[RCTheme imageForKey:@"code-head" size:CGSizeMake(4, 27) capInsets:UIEdgeInsetsMake(0, 1, 0, 1) drawing:^(CGContextRef ctx, CGRect r) {
            RCDrawVerticalGradient(ctx, CGRectMake(0, 0, r.size.width, 26), [NSArray arrayWithObjects:RCHex(0x3a5045), RCHex(0x26392f), nil], nil);
            CGContextSetFillColorWithColor(ctx, RCHex(0x0c1a13).CGColor);
            CGContextFillRect(ctx, CGRectMake(0, 26, r.size.width, 1));
            CGContextSetFillColorWithColor(ctx, RCHexA(0xffffff, .08).CGColor);
            CGContextFillRect(ctx, CGRectMake(0, 0, r.size.width, 1));
        }]];
        [self insertSubview:_head atIndex:0];
    }
    return self;
}

- (void)dealloc { _dying = YES; [_code release]; [_lang release]; [_text release]; [_head release]; [_copy release]; [_scroll release]; [super dealloc]; }

- (void)setCopyEnabled:(BOOL)v { _copyEnabled = v; _copy.hidden = !v; }
- (CGFloat)heightForWidth:(CGFloat)width { return 26 + 8 + _textSize.height + 8 + 1; }
- (CGSize)sizeThatFits:(CGSize)size { return CGSizeMake(size.width, [self heightForWidth:size.width]); }

- (void)layoutSubviews {
    [super layoutSubviews];
    if (_dying) return;
    CGFloat w = self.bounds.size.width;
    _head.frame = CGRectMake(0, 0, w, 27);
    _lang.frame = CGRectMake(8, 0, w - 100, 26);
    _copy.frame = CGRectMake(w - 84, 0, 84, 26);
    _scroll.frame = CGRectMake(0, 27, w, self.bounds.size.height - 27);
    _text.frame = CGRectMake(10, 8, _textSize.width, _textSize.height);
    _scroll.contentSize = CGSizeMake(_textSize.width + 20, _scroll.bounds.size.height);
}

- (void)copyCode {
    if ([_delegate respondsToSelector:@selector(codeBlockViewShouldCopy:)] && ![_delegate codeBlockViewShouldCopy:self]) return;
    [UIPasteboard generalPasteboard].string = _code;
    if ([_delegate respondsToSelector:@selector(codeBlockViewDidCopy:)]) [_delegate codeBlockViewDidCopy:self];
}
@end
