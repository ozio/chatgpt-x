#import "RCAccountHeaderView.h"
#import "RCTheme.h"
#import "RCGlyph.h"

@interface RCAccountHeaderView () { UIImageView *_avatar; UILabel *_nameLabel, *_emailLabel, *_badge; UIImageView *_chevron; }
@end

@implementation RCAccountHeaderView
@synthesize name = _name, email = _email, initials = _initials, avatarImage = _avatarImage, planTitle = _planTitle, showsDisclosure = _showsDisclosure;

+ (NSString *)initialsForName:(NSString *)name {
    NSMutableString *s = [NSMutableString string];
    for (NSString *w in [name componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]) {
        if (!w.length) continue;
        [s appendString:[[w substringWithRange:[w rangeOfComposedCharacterSequenceAtIndex:0]] uppercaseString]];
        if (s.length >= 2) break;
    }
    return s.length ? s : @"?";
}

+ (UIImage *)avatarImageWithInitials:(NSString *)initials diameter:(CGFloat)d {
    NSString *key = [NSString stringWithFormat:@"avatar-%@-%g", initials, d];
    return [RCTheme imageForKey:key size:CGSizeMake(d + 4, d + 5) capInsets:UIEdgeInsetsZero drawing:^(CGContextRef ctx, CGRect r) {
        CGRect c = CGRectMake(2, 1, d, d);
        CGContextSaveGState(ctx);
        CGContextSetShadowWithColor(ctx, CGSizeMake(0, 2), 3, RCHexA(0, .35).CGColor);
        CGContextSetFillColorWithColor(ctx, RCHex(0x2b9a62).CGColor);
        CGContextFillEllipseInRect(ctx, c);
        CGContextRestoreGState(ctx);
        CGContextSaveGState(ctx);
        CGContextAddEllipseInRect(ctx, c); CGContextClip(ctx);
        RCDrawVerticalGradient(ctx, c, [NSArray arrayWithObjects:RCHex(0x8bd6ae), RCHex(0x2b9a62), nil], nil);
        CGContextSetFillColorWithColor(ctx, RCHexA(0xffffff, .45).CGColor);
        CGContextFillRect(ctx, CGRectMake(c.origin.x, c.origin.y, d, 1));
        CGContextRestoreGState(ctx);
        UIFont *f = [UIFont boldSystemFontOfSize:round(d * .375)];
        CGSize ts = [initials sizeWithFont:f];
        CGContextSetShadowWithColor(ctx, CGSizeMake(0, -1), 0, RCHexA(0x003c19, .5).CGColor);
        [[UIColor whiteColor] set];
        [initials drawAtPoint:CGPointMake(c.origin.x + (d - ts.width) / 2, c.origin.y + (d - ts.height) / 2) withFont:f];
    }];
}

+ (UIImage *)photo:(UIImage *)photo diameter:(CGFloat)d {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(d + 4, d + 5), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect c = CGRectMake(2, 1, d, d);
    CGContextSaveGState(ctx);
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, 2), 3, RCHexA(0, .35).CGColor);
    CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGContextFillEllipseInRect(ctx, c);
    CGContextRestoreGState(ctx);
    CGContextAddEllipseInRect(ctx, c); CGContextClip(ctx);
    CGSize s = photo.size; CGFloat k = MAX(d / MAX(1, s.width), d / MAX(1, s.height));
    [photo drawInRect:CGRectMake(c.origin.x + (d - s.width * k) / 2, c.origin.y + (d - s.height * k) / 2, s.width * k, s.height * k)];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

static UILabel *RCHeroLabel(UIFont *font) {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectZero];
    l.backgroundColor = [UIColor clearColor];
    l.font = font;
    l.textAlignment = NSTextAlignmentCenter;
    l.lineBreakMode = NSLineBreakByTruncatingTail;
    return l;
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _avatar = [[UIImageView alloc] initWithFrame:CGRectZero];
        [self addSubview:_avatar];
        _nameLabel = RCHeroLabel([UIFont boldSystemFontOfSize:19]);
        _emailLabel = RCHeroLabel([UIFont systemFontOfSize:14]);
        _badge = RCHeroLabel([UIFont boldSystemFontOfSize:11]);
        _badge.textColor = [UIColor whiteColor];
        _badge.shadowColor = RCHexA(0, .3);
        _badge.shadowOffset = CGSizeMake(0, -1);
        [self addSubview:_nameLabel]; [self addSubview:_emailLabel]; [self addSubview:_badge];
        _chevron = [[UIImageView alloc] initWithFrame:CGRectZero];
        [self addSubview:_chevron];
        self.isAccessibilityElement = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyAppearance) name:RCThemeAppearanceDidChangeNotification object:nil];
        [self applyAppearance];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_avatar release]; [_nameLabel release]; [_emailLabel release]; [_badge release]; [_chevron release];
    [_name release]; [_email release]; [_initials release]; [_avatarImage release]; [_planTitle release];
    [super dealloc];
}

- (void)applyAppearance {
    BOOL dark = [RCTheme isDark];
    _nameLabel.textColor = dark ? RCHex(0xe3ece7) : [RCTheme inkColor];
    _emailLabel.textColor = [RCTheme metaTextColor];
    for (UILabel *l in [NSArray arrayWithObjects:_nameLabel, _emailLabel, nil]) { l.shadowColor = [RCTheme engravedShadowColor]; l.shadowOffset = [RCTheme engravedShadowOffset]; }
    _chevron.image = [RCGlyph imageNamed:@"down" size:16 color:[RCTheme metaTextColor]];
    _chevron.transform = CGAffineTransformMakeRotation(-M_PI_2);
    [self refresh];
}

- (void)refresh {
    NSString *ini = _initials.length ? _initials : [RCAccountHeaderView initialsForName:_name];
    _avatar.image = _avatarImage ? [RCAccountHeaderView photo:_avatarImage diameter:64] : [RCAccountHeaderView avatarImageWithInitials:ini diameter:64];
    _nameLabel.text = _name;
    _emailLabel.text = _email;
    _badge.text = _planTitle;
    _badge.hidden = !_planTitle.length;
    _chevron.hidden = !_showsDisclosure;
    self.accessibilityLabel = [[NSArray arrayWithObjects:(_name ? _name : @""), (_email ? _email : @""), (_planTitle.length ? [RCL(@"Plan ") stringByAppendingString:_planTitle] : @""), nil] componentsJoinedByString:@", "];
    self.accessibilityTraits = _showsDisclosure ? UIAccessibilityTraitButton : UIAccessibilityTraitStaticText;
    [self setNeedsLayout];
    [self setNeedsDisplay];
}

- (void)setName:(NSString *)v { [_name release]; _name = [v copy]; [self refresh]; }
- (void)setEmail:(NSString *)v { [_email release]; _email = [v copy]; [self refresh]; }
- (void)setInitials:(NSString *)v { [_initials release]; _initials = [v copy]; [self refresh]; }
- (void)setAvatarImage:(UIImage *)v { [_avatarImage release]; _avatarImage = [v retain]; [self refresh]; }
- (void)setPlanTitle:(NSString *)v { [_planTitle release]; _planTitle = [v copy]; [self refresh]; }
- (void)setShowsDisclosure:(BOOL)v { _showsDisclosure = v; [self refresh]; }

- (CGFloat)heightForWidth:(CGFloat)width { return 18 + 64 + 8 + 23 + 18 + (_planTitle.length ? 6 + 16 : 0) + 8; }
- (CGSize)sizeThatFits:(CGSize)size { CGFloat w = size.width > 0 ? size.width : 320; return CGSizeMake(w, [self heightForWidth:w]); }

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    _avatar.frame = CGRectMake(round((w - 68) / 2), 17, 68, 69);
    _nameLabel.frame = CGRectMake(30, 90, w - 60, 23);
    _emailLabel.frame = CGRectMake(30, 113, w - 60, 18);
    CGSize bs = [_badge.text sizeWithFont:_badge.font];
    _badge.frame = CGRectMake(round((w - bs.width - 16) / 2), 137, ceil(bs.width) + 16, 16);
    _chevron.frame = CGRectMake(w - 30, 42, 16, 16);
}

- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; self.alpha = (h && _showsDisclosure) ? .6 : 1; }

- (void)drawRect:(CGRect)rect {
    if (_badge.hidden) return;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect r = _badge.frame;
    CGPathRef p = RCCreateRoundedRectPath(r, 8);
    CGContextSaveGState(ctx);
    CGContextAddPath(ctx, p); CGContextClip(ctx);
    RCDrawVerticalGradient(ctx, r, [NSArray arrayWithObjects:RCHex(0x6fd29d), RCHex(0x1f9a5a), nil], nil);
    CGContextRestoreGState(ctx);
    CGPathRelease(p);
}
@end
