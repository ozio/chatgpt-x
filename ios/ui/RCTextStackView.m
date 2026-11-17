#import "RCTextStackView.h"

static const NSUInteger RCChunkSoft = 700, RCChunkHard = 1200;

@interface RCTextStackView () { NSAttributedString *_text; NSMutableArray *_labels; NSArray *_chunks; BOOL _dying; }
@end

@implementation RCTextStackView

+ (NSArray *)chunksOfAttributedString:(NSAttributedString *)text {
    NSString *s = text.string;
    NSUInteger n = s.length, start = 0;
    if (n <= RCChunkHard) return text ? [NSArray arrayWithObject:text] : [NSArray array];
    NSMutableArray *out = [NSMutableArray array];
    while (start < n) {
        NSUInteger end = MIN(n, start + RCChunkHard);
        if (end < n) {
            // prefer the last line break after the soft size, then a space
            NSRange window = NSMakeRange(start + RCChunkSoft, end - start - RCChunkSoft);
            NSRange br = [s rangeOfString:@"\n" options:NSBackwardsSearch range:window];
            if (br.location != NSNotFound) end = br.location + 1;
            else {
                NSRange sp = [s rangeOfString:@" " options:NSBackwardsSearch range:window];
                if (sp.location != NSNotFound) end = sp.location + 1;
            }
            end = NSMaxRange([s rangeOfComposedCharacterSequencesForRange:NSMakeRange(start, end - start)]);
        }
        NSRange r = NSMakeRange(start, end - start);
        // a chunk that ends with a line break would draw an empty last line
        NSRange visible = r;
        if (visible.length > 1 && [s characterAtIndex:NSMaxRange(visible) - 1] == '\n') visible.length--;
        [out addObject:[text attributedSubstringFromRange:visible]];
        start = end;
    }
    return out;
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        _labels = [[NSMutableArray alloc] init];
    }
    return self;
}
- (void)dealloc { _dying = YES; [_text release]; [_labels release]; [_chunks release]; [super dealloc]; }

- (NSAttributedString *)attributedText { return _text; }
- (void)setAttributedText:(NSAttributedString *)t {
    if (t == _text || [t isEqualToAttributedString:_text]) return;
    [_text release]; _text = [t copy];
    [_chunks release]; _chunks = [[RCTextStackView chunksOfAttributedString:_text] retain];
    while (_labels.count < _chunks.count) {
        UILabel *l = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
        l.backgroundColor = [UIColor clearColor];
        l.numberOfLines = 0;
        l.lineBreakMode = NSLineBreakByWordWrapping;
        l.isAccessibilityElement = NO;
        [self addSubview:l];
        [_labels addObject:l];
    }
    while (_labels.count > _chunks.count) { [[_labels lastObject] removeFromSuperview]; [_labels removeLastObject]; }
    for (NSUInteger i = 0; i < _chunks.count; i++) [[_labels objectAtIndex:i] setAttributedText:[_chunks objectAtIndex:i]];
    self.accessibilityLabel = _text.string;
    [self setNeedsLayout];
}

static CGFloat RCChunkHeight(NSAttributedString *s, CGFloat w) {
    if (!s.length) return 0;
    return ceil([s boundingRectWithSize:CGSizeMake(w, 100000) options:NSStringDrawingUsesLineFragmentOrigin context:nil].size.height);
}

- (CGFloat)layout:(CGFloat)w apply:(BOOL)apply {
    CGFloat y = 0;
    for (NSUInteger i = 0; i < _chunks.count; i++) {
        CGFloat h = RCChunkHeight([_chunks objectAtIndex:i], w);
        if (apply) [[_labels objectAtIndex:i] setFrame:CGRectMake(0, y, w, h)];
        y += h;
    }
    return y;
}
- (CGFloat)heightForWidth:(CGFloat)width { return [self layout:width apply:NO]; }
- (CGSize)sizeThatFits:(CGSize)size { return CGSizeMake(size.width, [self heightForWidth:size.width]); }
- (void)layoutSubviews { [super layoutSubviews]; if (_dying) return; [self layout:self.bounds.size.width apply:YES]; }
@end
