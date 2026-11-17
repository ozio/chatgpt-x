#import "RCRatingRowView.h"
#import "RCGlyph.h"
#import "RCTheme.h"

@interface RCRatingRowView () { NSString *_prompt; UILabel *_label; UIButton *_up, *_down; }
@end

@implementation RCRatingRowView
@synthesize rating = _rating, delegate = _delegate;

static UIImage *RCRatingKey(BOOL pressed, NSInteger tint) {
    BOOL dark = [RCTheme isDark];
    return [RCTheme imageForKey:[NSString stringWithFormat:@"cx-rate-%d%d%ld", dark, pressed, (long)tint] size:CGSizeMake(16, 28) capInsets:UIEdgeInsetsMake(7, 7, 7, 7) drawing:^(CGContextRef ctx, CGRect r) {
        CGRect b = CGRectInset(r, .5, .5); CGPathRef p = RCCreateRoundedRectPath(b, 6);
        unsigned t = tint > 0 ? 0x7fdcab : (tint < 0 ? 0xef8378 : (dark ? 0x3a4d44 : 0xffffff)), bo = tint > 0 ? 0x1e9656 : (tint < 0 ? 0xc51c0b : (dark ? 0x26352e : 0xe6ece9));
        if (pressed && !tint) { t = dark ? 0x22302a : 0xd2dad6; bo = dark ? 0x2c3d35 : 0xe1e7e4; }
        CGContextSaveGState(ctx); CGContextAddPath(ctx, p); CGContextClip(ctx); RCDrawVerticalGradient(ctx, b, [NSArray arrayWithObjects:RCHex(t), RCHex(bo), nil], nil); CGContextRestoreGState(ctx);
        CGContextAddPath(ctx, p); CGContextSetStrokeColorWithColor(ctx, RCHex(tint > 0 ? 0x0f5c37 : (tint < 0 ? 0x7d0f05 : (dark ? 0x4a5e55 : 0xaebbb4))).CGColor); CGContextSetLineWidth(ctx, 1); CGContextStrokePath(ctx); CGPathRelease(p);
    }];
}

- (id)initWithFrame:(CGRect)frame {
    if (CGRectIsEmpty(frame)) frame = CGRectMake(0, 0, 300, 36);
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        _label = [[UILabel alloc] initWithFrame:CGRectZero]; _label.backgroundColor = [UIColor clearColor]; _label.font = [UIFont boldSystemFontOfSize:13]; [self addSubview:_label];
        _up = [[UIButton buttonWithType:UIButtonTypeCustom] retain]; _down = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        _up.accessibilityLabel = RCL(@"Good result"); _down.accessibilityLabel = RCL(@"Bad result");
        [_up addTarget:self action:@selector(tapUp) forControlEvents:UIControlEventTouchUpInside]; [_down addTarget:self action:@selector(tapDown) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_up]; [self addSubview:_down];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh) name:RCThemeAppearanceDidChangeNotification object:nil];
        [self refresh];
    }
    return self;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; [_prompt release]; [_label release]; [_up release]; [_down release]; [super dealloc]; }
- (NSString *)prompt { return _prompt; }
- (void)setPrompt:(NSString *)p { [_prompt release]; _prompt = [p copy]; [self refresh]; }
- (void)setRating:(NSInteger)r { _rating = r; [self refresh]; }

- (void)refresh {
    BOOL dark = [RCTheme isDark];
    _label.text = _prompt.length ? _prompt : RCL(@"How is the result?");
    _label.textColor = [RCTheme noteTextColor]; _label.shadowColor = [RCTheme engravedShadowColor]; _label.shadowOffset = [RCTheme engravedShadowOffset];
    UIColor *dim = RCHex(dark ? 0xb8c9c0 : 0x5f6f67);
    UIImage *thumb = [RCGlyph imageNamed:@"thumb" size:18 color:dim], *thumbW = [RCGlyph imageNamed:@"thumb" size:18 color:[UIColor whiteColor]];
    [_up setBackgroundImage:RCRatingKey(NO, _rating > 0 ? 1 : 0) forState:UIControlStateNormal]; [_up setBackgroundImage:RCRatingKey(YES, _rating > 0 ? 1 : 0) forState:UIControlStateHighlighted];
    [_down setBackgroundImage:RCRatingKey(NO, _rating < 0 ? -1 : 0) forState:UIControlStateNormal]; [_down setBackgroundImage:RCRatingKey(YES, _rating < 0 ? -1 : 0) forState:UIControlStateHighlighted];
    [_up setImage:(_rating > 0 ? thumbW : thumb) forState:UIControlStateNormal];
    [_down setImage:(_rating < 0 ? thumbW : thumb) forState:UIControlStateNormal];
    _down.imageView.transform = CGAffineTransformMakeScale(1, -1);
    _up.accessibilityTraits = UIAccessibilityTraitButton | (_rating > 0 ? UIAccessibilityTraitSelected : 0);
    _down.accessibilityTraits = UIAccessibilityTraitButton | (_rating < 0 ? UIAccessibilityTraitSelected : 0);
    [self setNeedsLayout];
}
- (CGFloat)heightForWidth:(CGFloat)w { (void)w; return 36; }
- (CGSize)sizeThatFits:(CGSize)s { return CGSizeMake(s.width, 36); }
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat lw = ceil([_label.text sizeWithFont:_label.font].width);
    _label.frame = CGRectMake(4, 4, lw, 28);
    _up.frame = CGRectMake(4 + lw + 8, 4, 40, 28);
    _down.frame = CGRectMake(4 + lw + 8 + 40 + 6, 4, 40, 28);
}
- (void)tapUp { [_delegate ratingRow:self didRate:1]; }
- (void)tapDown { [_delegate ratingRow:self didRate:-1]; }
@end
