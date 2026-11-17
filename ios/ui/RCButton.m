#import "RCButton.h"
#import "RCTheme.h"

typedef struct { unsigned c[4]; unsigned p[2]; unsigned border; unsigned text; BOOL light; CGFloat h, r, font; } RCButtonSpec;

static RCButtonSpec RCSpec(RCButtonStyle s) {
    RCButtonSpec k;
    memset(&k, 0, sizeof k);
    BOOL pill = s >= RCButtonStylePill;
    k.h = pill ? 26 : 44; k.r = pill ? 5 : 9; k.font = pill ? 12 : 18;
    switch (s) {
        case RCButtonStyleLargeGreen: { RCButtonSpec t = {{0x7fdcab, 0x35b06f, 0x22a05e, 0x1e9656}, {0x157c45, 0x22a05e}, 0x0f5c37, 0xffffff, NO, 44, 9, 18}; return t; }
        case RCButtonStyleLargeRed:   { RCButtonSpec t = {{0xef8378, 0xd4301f, 0xc51c0b, 0xb81506}, {0x8e1105, 0xb81506}, 0x7d0f05, 0xffffff, NO, 44, 9, 18}; return t; }
        case RCButtonStyleLargeDark:  { RCButtonSpec t = {{0x4f6d61, 0x2b4a3e, 0x1d3d31, 0x234437}, {0x1d3d31, 0x2b4a3e}, 0x08251a, 0xffffff, NO, 44, 9, 18}; return t; }
        case RCButtonStylePill:       { RCButtonSpec t = {{0xffffff, 0xf2f5f3, 0xedf1ef, 0xe6ebe8}, {0xd3dbd7, 0xe9eeeb}, 0xa3afa9, 0x3f4d47, YES, 26, 5, 12}; return t; }
        case RCButtonStylePillGo:     { RCButtonSpec t = {{0x77d6a3, 0x31a96a, 0x24a05f, 0x229b5b}, {0x157c45, 0x24a05f}, 0x136239, 0xffffff, NO, 26, 5, 12}; return t; }
        case RCButtonStylePillDark:   { RCButtonSpec t = {{0x6e777d, 0x4a5257, 0x3b4247, 0x353c40}, {0x1f2427, 0x2e3438}, 0x121517, 0xffffff, NO, 26, 5, 12}; return t; }
        case RCButtonStylePillRed:    { RCButtonSpec t = {{0xee857a, 0xd23322, 0xc41e0d, 0xbd1a0a}, {0x8e1105, 0xbd1a0a}, 0x861207, 0xffffff, NO, 26, 5, 12}; return t; }
        default:                      { RCButtonSpec t = {{0xffffff, 0xeef2f0, 0xe2e8e5, 0xe8edea}, {0xd2dad6, 0xe1e7e4}, 0x9eaba5, 0x1d2924, YES, 44, 9, 18}; return t; }
    }
}

@implementation RCButton
@synthesize style = _style;

+ (UIImage *)backgroundImageForStyle:(RCButtonStyle)style pressed:(BOOL)pressed {
    RCButtonSpec k = RCSpec(style);
    NSString *key = [NSString stringWithFormat:@"rcbutton-%d-%d", style, pressed];
    CGFloat w = k.r * 2 + 4;
    return [RCTheme imageForKey:key size:CGSizeMake(w, k.h) capInsets:UIEdgeInsetsMake(k.r + 1, k.r + 1, k.r + 1, k.r + 1) drawing:^(CGContextRef ctx, CGRect b) {
        CGRect r = CGRectInset(b, .5, .5);
        CGPathRef p = RCCreateRoundedRectPath(r, k.r);
        CGContextSaveGState(ctx);
        CGContextAddPath(ctx, p);
        CGContextClip(ctx);
        if (pressed) {
            RCDrawVerticalGradient(ctx, b, [NSArray arrayWithObjects:RCHex(k.p[0]), RCHex(k.p[1]), nil], nil);
            // inset 0 1px 3px shadow
            CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1), 3, RCHexA(0, k.light ? .25 : .45).CGColor);
            CGContextSetStrokeColorWithColor(ctx, RCHexA(0, .4).CGColor);
            CGContextSetLineWidth(ctx, 2);
            CGPathRef outer = RCCreateRoundedRectPath(CGRectInset(r, -1, -1), k.r + 1);
            CGContextAddPath(ctx, outer); CGContextStrokePath(ctx); CGPathRelease(outer);
        } else {
            NSArray *locs = [NSArray arrayWithObjects:[NSNumber numberWithFloat:0], [NSNumber numberWithFloat:.5], [NSNumber numberWithFloat:.51], [NSNumber numberWithFloat:1], nil];
            RCDrawVerticalGradient(ctx, b, [NSArray arrayWithObjects:RCHex(k.c[0]), RCHex(k.c[1]), RCHex(k.c[2]), RCHex(k.c[3]), nil], locs);
            CGContextSetFillColorWithColor(ctx, RCHexA(0xffffff, k.light ? 1 : .45).CGColor);
            CGContextFillRect(ctx, CGRectMake(0, 1, b.size.width, 1)); // inset 0 1px 0 highlight
        }
        CGContextRestoreGState(ctx);
        CGContextAddPath(ctx, p);
        CGContextSetStrokeColorWithColor(ctx, RCHex(k.border).CGColor);
        CGContextSetLineWidth(ctx, 1);
        CGContextStrokePath(ctx);
        CGPathRelease(p);
    }];
}

+ (id)buttonWithStyle:(RCButtonStyle)style title:(NSString *)title {
    RCButton *b = [self buttonWithType:UIButtonTypeCustom];
    b.style = style;
    [b setTitle:title forState:UIControlStateNormal];
    [b sizeToFit];
    return b;
}

- (void)setStyle:(RCButtonStyle)style {
    _style = style;
    RCButtonSpec k = RCSpec(style);
    [self setBackgroundImage:[RCButton backgroundImageForStyle:style pressed:NO] forState:UIControlStateNormal];
    [self setBackgroundImage:[RCButton backgroundImageForStyle:style pressed:YES] forState:UIControlStateHighlighted];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:k.font];
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self setTitleColor:RCHex(k.text) forState:UIControlStateNormal];
    [self setTitleShadowColor:(k.light ? RCHexA(0xffffff, .8) : (style == RCButtonStylePillDark ? RCHexA(0, .6) : RCHexA(style == RCButtonStylePillRed || style == RCButtonStyleLargeRed ? 0x500000 : 0x003c19, .55))) forState:UIControlStateNormal];
    self.titleLabel.shadowOffset = k.light ? CGSizeMake(0, 1) : CGSizeMake(0, -1);
    self.contentEdgeInsets = UIEdgeInsetsMake(0, style >= RCButtonStylePill ? 10 : 14, 0, style >= RCButtonStylePill ? 10 : 14);
}

- (void)setEnabled:(BOOL)enabled { [super setEnabled:enabled]; self.alpha = enabled ? 1 : .5; }

- (CGSize)sizeThatFits:(CGSize)size {
    RCButtonSpec k = RCSpec(_style);
    CGSize t = [[self titleForState:UIControlStateNormal] sizeWithFont:self.titleLabel.font];
    CGFloat w = ceil(t.width) + self.contentEdgeInsets.left + self.contentEdgeInsets.right;
    if (_style >= RCButtonStylePill) w = MAX(w, 56);
    else w = MAX(w, size.width > 0 ? size.width : w);
    return CGSizeMake(w, k.h);
}
@end
