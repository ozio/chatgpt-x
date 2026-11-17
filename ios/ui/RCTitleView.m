#import "RCTitleView.h"
#import "RCGlyph.h"

@interface RCTitleView () {
    UILabel *_titleLabel, *_subLabel;
    RCLampView *_lamp;
    UIImageView *_caret;
}
@end

@implementation RCTitleView
@synthesize title = _title, subtitle = _subtitle, animatesSubtitleAppearance = _animatesSubtitleAppearance, showsLamp = _showsLamp, showsCaret = _showsCaret, variant = _variant;

- (id)initWithFrame:(CGRect)frame {
    if (CGRectIsEmpty(frame)) frame = CGRectMake(0, 0, 200, 44);
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _subLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        for (UILabel *l in [NSArray arrayWithObjects:_titleLabel, _subLabel, nil]) {
            l.backgroundColor = [UIColor clearColor];
            l.textAlignment = NSTextAlignmentCenter;
            l.lineBreakMode = NSLineBreakByTruncatingTail;
            l.shadowOffset = CGSizeMake(0, -1);
            l.userInteractionEnabled = NO;
            [self addSubview:l];
        }
        _titleLabel.textColor = [UIColor whiteColor];
        _subLabel.font = [UIFont boldSystemFontOfSize:12];
        _subLabel.textColor = [UIColor colorWithWhite:1 alpha:.88];
        _subLabel.textAlignment = NSTextAlignmentLeft;
        _lamp = [[RCLampView alloc] initWithDiameter:8];
        [self addSubview:_lamp];
        _caret = [[UIImageView alloc] initWithImage:[RCGlyph imageNamed:@"down" size:10 color:[UIColor whiteColor]]];
        [self addSubview:_caret];
        self.isAccessibilityElement = YES;
        self.accessibilityTraits = UIAccessibilityTraitHeader;
        [self applyVariant];
    }
    return self;
}

- (void)dealloc {
    [_title release]; [_subtitle release];
    [_titleLabel release]; [_subLabel release]; [_lamp release]; [_caret release];
    [super dealloc];
}

- (void)applyVariant {
    UIColor *shadow = _variant == RCBarVariantJade ? RCHexA(0x00371c, .65) : RCHexA(0, .6);
    _titleLabel.shadowColor = shadow;
    _subLabel.shadowColor = _variant == RCBarVariantJade ? RCHexA(0x002d16, .55) : RCHexA(0, .55);
}

- (void)setVariant:(RCBarVariant)variant { _variant = variant; [self applyVariant]; }

- (void)setTitle:(NSString *)title subtitle:(NSString *)subtitle lamp:(RCLampState)lamp showsLamp:(BOOL)showsLamp caret:(BOOL)caret {
    BOOL unfold = _animatesSubtitleAppearance && !_subtitle.length && subtitle.length && self.window;
    [self layoutIfNeeded]; CGRect oldTitle = _titleLabel.frame;
    NSString *nextTitle = [title copy], *nextSubtitle = [subtitle copy];
    [_title release]; _title = nextTitle;
    [_subtitle release]; _subtitle = nextSubtitle;
    _lamp.state = lamp;
    _showsLamp = showsLamp;
    _showsCaret = caret;
    [self refresh]; [self layoutIfNeeded];
    if (unfold) {
        CGRect finalTitle = _titleLabel.frame; _titleLabel.frame = oldTitle;
        _subLabel.alpha = _caret.alpha = _lamp.alpha = 0;
        _subLabel.transform = CGAffineTransformMakeScale(1, .05);
        [UIView animateWithDuration:.25 delay:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionCurveEaseInOut animations:^{
            _titleLabel.frame = finalTitle; _subLabel.transform = CGAffineTransformIdentity;
            _subLabel.alpha = _caret.alpha = _lamp.alpha = 1;
        } completion:nil];
    }
}
- (void)setTitle:(NSString *)title { [self setTitle:title subtitle:_subtitle lamp:_lamp.state showsLamp:_showsLamp caret:_showsCaret]; }
- (void)setSubtitle:(NSString *)subtitle { [self setTitle:_title subtitle:subtitle lamp:_lamp.state showsLamp:_showsLamp caret:_showsCaret]; }
- (void)setShowsLamp:(BOOL)v { _showsLamp = v; [self refresh]; }
- (void)setShowsCaret:(BOOL)v { _showsCaret = v; [self refresh]; }
- (RCLampState)lampState { return _lamp.state; }
- (void)setLampState:(RCLampState)s { _lamp.state = s; }

- (void)refresh {
    BOOL solo = _subtitle.length == 0;
    _titleLabel.text = _title;
    _titleLabel.font = [UIFont boldSystemFontOfSize:solo ? 20 : 18];
    _subLabel.text = _subtitle;
    _subLabel.hidden = solo;
    _lamp.hidden = solo || !_showsLamp;
    _caret.hidden = solo || !_showsCaret;
    self.accessibilityLabel = solo ? _title : [NSString stringWithFormat:@"%@, %@", _title ? _title : @"", _subtitle];
    self.accessibilityTraits = _showsCaret ? (UIAccessibilityTraitHeader | UIAccessibilityTraitButton) : UIAccessibilityTraitHeader;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width, h = self.bounds.size.height;
    if (_subLabel.hidden) { _titleLabel.frame = CGRectMake(0, 0, w, h); return; }
    CGFloat top = floor((h - 44) / 2);
    _titleLabel.frame = CGRectMake(0, top + 4, w, 21);
    CGFloat lampW = _lamp.hidden ? 0 : 8 + 4, caretW = _caret.hidden ? 0 : 3 + 10;
    CGFloat textW = ceil([_subtitle sizeWithFont:_subLabel.font].width);
    textW = MIN(textW, w - lampW - caretW);
    CGFloat x = floor((w - lampW - textW - caretW) / 2), y = top + 25;
    if (!_lamp.hidden) {
        CGRect f = _lamp.frame;
        f.origin = CGPointMake(x - (f.size.width - 8) / 2, y + 3.5 - (f.size.height - 8) / 2);
        _lamp.frame = f;
        x += lampW;
    }
    _subLabel.frame = CGRectMake(x, y, textW, 15);
    x += textW;
    if (!_caret.hidden) _caret.frame = CGRectMake(x + 3, y + 3, 10, 10);
}

- (void)setHighlighted:(BOOL)highlighted { [super setHighlighted:highlighted]; self.alpha = highlighted ? .7 : 1; }
@end
