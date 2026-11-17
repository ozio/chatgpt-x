#import "RCTheme.h"

NSString *const RCThemeTextSizeDidChangeNotification = @"RCThemeTextSizeDidChangeNotification";
NSString *const RCThemeAppearanceDidChangeNotification = @"RCThemeAppearanceDidChangeNotification";

UIColor *RCHexA(unsigned rgb, CGFloat alpha) {
    return [UIColor colorWithRed:((rgb >> 16) & 0xff) / 255.0 green:((rgb >> 8) & 0xff) / 255.0 blue:(rgb & 0xff) / 255.0 alpha:alpha];
}
UIColor *RCHex(unsigned rgb) { return RCHexA(rgb, 1); }

static NSParagraphStyle *RCWrapStyle(NSTextAlignment alignment) {
    NSMutableParagraphStyle *ps = [[[NSMutableParagraphStyle alloc] init] autorelease];
    ps.alignment = alignment;
    ps.lineBreakMode = NSLineBreakByWordWrapping;
    return ps;
}

void RCLabelSetText(UILabel *label, NSString *text) {
    label.numberOfLines = 0;
    if (!text.length) { label.attributedText = nil; label.text = text; return; }
    NSDictionary *a = [NSDictionary dictionaryWithObjectsAndKeys:label.font, NSFontAttributeName,
                       (label.textColor ? label.textColor : [UIColor blackColor]), NSForegroundColorAttributeName,
                       RCWrapStyle(label.textAlignment), NSParagraphStyleAttributeName, nil];
    label.attributedText = [[[NSAttributedString alloc] initWithString:text attributes:a] autorelease];
}

NSString *RCL(NSString *english) {
    if (!english.length) return english;
    return [[NSBundle mainBundle] localizedStringForKey:english value:english table:@"Kit"];
}

UIFont *RCTextViewFont(UIFont *font) {
    CGFloat size = font ? font.pointSize : 16;
    NSString *name = font.fontName;
    if (font && ![name hasPrefix:@"."]) return font;
    BOOL bold = [name rangeOfString:@"Bold"].location != NSNotFound, italic = [name rangeOfString:@"Italic"].location != NSNotFound;
    NSString *named = bold ? (italic ? @"HelveticaNeue-BoldItalic" : @"HelveticaNeue-Bold") : (italic ? @"HelveticaNeue-Italic" : @"HelveticaNeue");
    UIFont *f = [UIFont fontWithName:named size:size];
    if (!f) f = [UIFont fontWithName:(bold ? @"Helvetica-Bold" : @"Helvetica") size:size];
    return f ? f : (font ? font : [UIFont systemFontOfSize:size]);
}

NSDictionary *RCTextViewAttributes(UIFont *font, UIColor *color) {
    return [NSDictionary dictionaryWithObjectsAndKeys:RCTextViewFont(font), NSFontAttributeName, (color ? color : [UIColor blackColor]), NSForegroundColorAttributeName, nil];
}

CGSize RCMeasureText(NSString *text, UIFont *font, CGFloat width) {
    if (!text.length || !font) return CGSizeZero;
    NSDictionary *a = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, RCWrapStyle(NSTextAlignmentLeft), NSParagraphStyleAttributeName, nil];
    CGRect r = [[[[NSAttributedString alloc] initWithString:text attributes:a] autorelease] boundingRectWithSize:CGSizeMake(width, 100000) options:NSStringDrawingUsesLineFragmentOrigin context:nil];
    return CGSizeMake(ceil(r.size.width), ceil(r.size.height));
}

NSString *RCDisplayText(NSString *text) {
    if (!text || [text rangeOfString:@"\u20BD"].location == NSNotFound) return text;
    return [text stringByReplacingOccurrencesOfString:@"\u20BD" withString:RCL(@"RUB")];
}

void RCDrawVerticalGradient(CGContextRef ctx, CGRect rect, NSArray *colors, NSArray *locations) {
    if (colors.count == 0) return;
    if (colors.count == 1) { CGContextSetFillColorWithColor(ctx, [[colors objectAtIndex:0] CGColor]); CGContextFillRect(ctx, rect); return; }
    NSMutableArray *cg = [NSMutableArray arrayWithCapacity:colors.count];
    for (UIColor *c in colors) [cg addObject:(id)c.CGColor];
    CGFloat *locs = NULL;
    if (locations.count == colors.count) {
        locs = malloc(sizeof(CGFloat) * colors.count);
        for (NSUInteger i = 0; i < colors.count; i++) locs[i] = [[locations objectAtIndex:i] floatValue];
    }
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGGradientRef g = CGGradientCreateWithColors(space, (CFArrayRef)cg, locs);
    CGContextSaveGState(ctx);
    CGContextClipToRect(ctx, rect);
    CGContextDrawLinearGradient(ctx, g, CGPointMake(0, CGRectGetMinY(rect)), CGPointMake(0, CGRectGetMaxY(rect)), 0);
    CGContextRestoreGState(ctx);
    CGGradientRelease(g);
    CGColorSpaceRelease(space);
    free(locs);
}

CGPathRef RCCreateRoundedRectPath(CGRect r, CGFloat radius) {
    radius = MIN(radius, MIN(r.size.width, r.size.height) / 2);
    CGMutablePathRef p = CGPathCreateMutable();
    CGPathMoveToPoint(p, NULL, CGRectGetMinX(r) + radius, CGRectGetMinY(r));
    CGPathAddArcToPoint(p, NULL, CGRectGetMaxX(r), CGRectGetMinY(r), CGRectGetMaxX(r), CGRectGetMaxY(r), radius);
    CGPathAddArcToPoint(p, NULL, CGRectGetMaxX(r), CGRectGetMaxY(r), CGRectGetMinX(r), CGRectGetMaxY(r), radius);
    CGPathAddArcToPoint(p, NULL, CGRectGetMinX(r), CGRectGetMaxY(r), CGRectGetMinX(r), CGRectGetMinY(r), radius);
    CGPathAddArcToPoint(p, NULL, CGRectGetMinX(r), CGRectGetMinY(r), CGRectGetMaxX(r), CGRectGetMinY(r), radius);
    CGPathCloseSubpath(p);
    return p;
}

static RCTextSize gTextSize = RCTextSizeNormal;
static RCAppearance gAppearance = RCAppearanceLight;

// iOS 6 grouped cells: selected background must round only its outer corners.
@interface RCGroupedSelectionView : UIView { RCGroupedRowPosition _position; }
- (id)initWithPosition:(RCGroupedRowPosition)position;
@end
@implementation RCGroupedSelectionView
- (id)initWithPosition:(RCGroupedRowPosition)position {
    if ((self = [super initWithFrame:CGRectMake(0, 0, 300, 44)])) { _position = position; self.opaque = NO; self.contentMode = UIViewContentModeRedraw; }
    return self;
}
- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect b = CGRectInset(self.bounds, 1, 0);
    CGFloat r = 8, minX = CGRectGetMinX(b), maxX = CGRectGetMaxX(b), minY = CGRectGetMinY(b), maxY = CGRectGetMaxY(b);
    BOOL top = _position == RCGroupedRowTop || _position == RCGroupedRowSingle;
    BOOL bottom = _position == RCGroupedRowBottom || _position == RCGroupedRowSingle;
    if (top) minY += 1;
    if (bottom) maxY -= 1;
    CGMutablePathRef p = CGPathCreateMutable();
    CGPathMoveToPoint(p, NULL, minX, (minY + maxY) / 2);
    if (top) { CGPathAddArcToPoint(p, NULL, minX, minY, maxX, minY, r); CGPathAddArcToPoint(p, NULL, maxX, minY, maxX, maxY, r); }
    else { CGPathAddLineToPoint(p, NULL, minX, minY); CGPathAddLineToPoint(p, NULL, maxX, minY); }
    if (bottom) { CGPathAddArcToPoint(p, NULL, maxX, maxY, minX, maxY, r); CGPathAddArcToPoint(p, NULL, minX, maxY, minX, minY, r); }
    else { CGPathAddLineToPoint(p, NULL, maxX, maxY); CGPathAddLineToPoint(p, NULL, minX, maxY); }
    CGPathCloseSubpath(p);
    CGContextAddPath(ctx, p);
    CGContextClip(ctx);
    RCDrawVerticalGradient(ctx, CGRectMake(minX, minY, maxX - minX, maxY - minY), [NSArray arrayWithObjects:RCHex(0x3cb67b), RCHex(0x13804c), nil], nil);
    CGPathRelease(p);
}
@end

@implementation RCTheme

#pragma mark - Text sizes

+ (RCTextSize)textSize { return gTextSize; }
+ (void)setTextSize:(RCTextSize)size {
    if (size > RCTextSizeXLarge) size = RCTextSizeXLarge;
    if (size == gTextSize) return;
    gTextSize = size;
    [[NSNotificationCenter defaultCenter] postNotificationName:RCThemeTextSizeDidChangeNotification object:nil];
}
+ (UIFont *)bodyFontForSize:(RCTextSize)size {
    static const CGFloat pts[] = {14, 15, 16, 19, 22};
    return [UIFont systemFontOfSize:pts[MIN((int)size, 4)]];
}
+ (CGFloat)bodyLineHeightForSize:(RCTextSize)size answer:(BOOL)answer {
    static const CGFloat lh[] = {18, 20, 21, 26, 29};
    if (size == RCTextSizeNormal && answer) return 22;
    return lh[MIN((int)size, 4)];
}
+ (UIFont *)bodyFont { return [self bodyFontForSize:gTextSize]; }
+ (CGFloat)bodyLineHeight:(BOOL)answer { return [self bodyLineHeightForSize:gTextSize answer:answer]; }
+ (NSString *)nameForTextSize:(RCTextSize)size {
    NSArray *n = [NSArray arrayWithObjects:@"XS", @"S", @"M", @"L", @"XL", nil];
    return [n objectAtIndex:MIN((int)size, 4)];
}

#pragma mark - Appearance

+ (RCAppearance)appearance { return gAppearance; }
+ (BOOL)isDark { return gAppearance == RCAppearanceDark; }
+ (void)setAppearance:(RCAppearance)appearance {
    if (appearance != RCAppearanceDark) appearance = RCAppearanceLight;
    if (appearance == gAppearance) return;
    gAppearance = appearance;
    // iOS 6 tints the default status bar from the navigation bar; dark uses black (#app.dark #statusbar).
    [[UIApplication sharedApplication] setStatusBarStyle:(appearance == RCAppearanceDark ? UIStatusBarStyleBlackOpaque : UIStatusBarStyleDefault) animated:YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:RCThemeAppearanceDidChangeNotification object:nil];
}
+ (UIColor *)contentBackgroundColor { return gAppearance == RCAppearanceDark ? [self linenDarkColor] : [self linenLightColor]; }
+ (UIColor *)engravedTextColor { return gAppearance == RCAppearanceDark ? RCHex(0xb8c9c0) : RCHex(0x4b5d55); }
+ (UIColor *)noteTextColor { return gAppearance == RCAppearanceDark ? RCHex(0xb8c9c0) : RCHex(0x5f6f67); }
+ (UIColor *)metaTextColor { return gAppearance == RCAppearanceDark ? RCHex(0xb8c9c0) : RCHex(0x6b7a72); }
+ (UIColor *)engravedShadowColor { return gAppearance == RCAppearanceDark ? [UIColor blackColor] : RCHexA(0xffffff, .8); }
+ (CGSize)engravedShadowOffset { return gAppearance == RCAppearanceDark ? CGSizeMake(0, -1) : CGSizeMake(0, 1); }
+ (UIColor *)answerTextColor { return gAppearance == RCAppearanceDark ? RCHex(0xe3ece7) : RCHex(0x1d2924); }
+ (UIColor *)answerSecondaryColor { return gAppearance == RCAppearanceDark ? RCHex(0x8fa39a) : RCHex(0x6b7a72); }
+ (UIColor *)cardColor { return gAppearance == RCAppearanceDark ? RCHex(0x1d2a24) : [UIColor whiteColor]; }
+ (UIColor *)cardHeldColor { return gAppearance == RCAppearanceDark ? RCHex(0x24342c) : RCHex(0xeef5f1); }
// Read-aloud player: graphite glass (iOS 6 media controls), deeper in dark appearance.
+ (UIColor *)readAloudTopColor { return gAppearance == RCAppearanceDark ? RCHex(0x4a5257) : RCHex(0x6a7379); }
+ (UIColor *)readAloudBottomColor { return gAppearance == RCAppearanceDark ? RCHex(0x1c2023) : RCHex(0x2b3134); }
+ (UIColor *)readAloudInkColor { return RCHex(0xf6f8f9); }
+ (UIColor *)readAloudSecondaryInkColor { return gAppearance == RCAppearanceDark ? RCHex(0x99a3a9) : RCHex(0xaeb8be); }
+ (UIColor *)readAloudFailureInkColor { return RCHex(0xffb3a6); }
+ (UIColor *)readAloudStrokeColor { return gAppearance == RCAppearanceDark ? RCHex(0x050607) : RCHex(0x15191b); }
+ (UIColor *)readAloudGrooveColor { return gAppearance == RCAppearanceDark ? RCHex(0x0c0e0f) : RCHex(0x181c1f); }
+ (UIColor *)readAloudFillColor { return RCHex(0xf4f7f8); }
+ (UIColor *)cardStrokeColor { return gAppearance == RCAppearanceDark ? RCHex(0x2c3d35) : RCHex(0xc7d2cc); }

#pragma mark - Palette

+ (UIColor *)inkColor { return RCHex(0x1d2924); }
+ (UIColor *)secondaryInkColor { return RCHex(0x6b7a72); }
+ (UIColor *)headerInkColor { return RCHex(0x4b5d55); }
+ (UIColor *)linkColor { return RCHex(0x1c7449); }
+ (UIColor *)jadeColor { return RCHex(0x1f8a57); }
+ (UIColor *)warningInkColor { return RCHex(0xa26b00); }
+ (UIColor *)errorInkColor { return RCHex(0xa3261a); }
+ (UIColor *)cardBorderColor { return RCHex(0xc7d2cc); }
+ (UIColor *)hairlineColor { return RCHex(0xdfe6e2); }
+ (UIColor *)textShadowLight { return RCHexA(0xffffff, .8); }
+ (UIColor *)linenLightColor {
    UIImage *img = [UIImage imageNamed:@"rc-linen-light.png"];
    return img ? [UIColor colorWithPatternImage:img] : RCHex(0xe8eee9);
}
+ (UIColor *)linenDarkColor {
    UIImage *img = [UIImage imageNamed:@"rc-linen-dark.png"];
    return img ? [UIColor colorWithPatternImage:img] : RCHex(0x1e4838);
}

#pragma mark - Image cache

+ (UIImage *)imageForKey:(NSString *)key size:(CGSize)size capInsets:(UIEdgeInsets)caps drawing:(void (^)(CGContextRef, CGRect))draw {
    static NSMutableDictionary *cache = nil;
    if (!cache) cache = [[NSMutableDictionary alloc] init];
    UIImage *img = [cache objectForKey:key];
    if (img) return img;
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    draw(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, size.width, size.height));
    img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    // Stretch, never the iOS 6 default (tile): a tiled stretchable image in a UIImageView
    // that keeps resizing (a streaming answer card) crashed UIKit on iOS 6.1.4 (device).
    if (!UIEdgeInsetsEqualToEdgeInsets(caps, UIEdgeInsetsZero)) img = [img resizableImageWithCapInsets:caps resizingMode:UIImageResizingModeStretch];
    if (img) [cache setObject:img forKey:key];
    return img;
}

+ (UIImage *)appIconImage:(CGFloat)points {
    UIImage *img = [UIImage imageNamed:(points > 40 ? @"rc-app-icon-57.png" : @"rc-app-icon-29.png")];
    if (img) return img;
    NSString *key = [NSString stringWithFormat:@"appicon-fallback-%g", points];
    return [self imageForKey:key size:CGSizeMake(points, points) capInsets:UIEdgeInsetsZero drawing:^(CGContextRef ctx, CGRect r) {
        CGPathRef p = RCCreateRoundedRectPath(r, points * .18);
        CGContextAddPath(ctx, p); CGContextClip(ctx); CGPathRelease(p);
        RCDrawVerticalGradient(ctx, r, [NSArray arrayWithObjects:RCHex(0x7fdcab), RCHex(0x1e9656), nil], nil);
    }];
}

+ (void)drawBrandMark:(RCBrandMark)mark inRect:(CGRect)r grey:(BOOL)grey {
    NSString *name = mark == RCBrandMarkEmbossedWhite ? @"rc-mark-embossed-white.png"
        : mark == RCBrandMarkEmbossedEmerald ? @"rc-mark-embossed-emerald.png"
        : [self isDark] ? @"rc-mark-debossed-dark.png" : @"rc-mark-debossed-light.png";
    UIImage *src = [UIImage imageNamed:name];
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSaveGState(ctx);
    if (!src) {
        // Artwork missing: the app tile with its iOS 6 corner, inset like the mark's padding.
        src = [self appIconImage:57];
        r = CGRectInset(r, round(r.size.width * .125), round(r.size.height * .125));
        CGPathRef p = RCCreateRoundedRectPath(r, r.size.width * .18);
        CGContextAddPath(ctx, p); CGContextClip(ctx); CGPathRelease(p);
    }
    CGContextBeginTransparencyLayer(ctx, NULL);
    [src drawInRect:r];
    if (grey) {
        // -webkit-filter: grayscale(1): keep luminosity, drop colour, then cut back to the mark's alpha
        CGContextSetBlendMode(ctx, kCGBlendModeColor);
        CGContextSetFillColorWithColor(ctx, [UIColor grayColor].CGColor);
        CGContextFillRect(ctx, r);
        [src drawInRect:r blendMode:kCGBlendModeDestinationIn alpha:1];
    }
    CGContextEndTransparencyLayer(ctx);
    CGContextRestoreGState(ctx);
}

+ (UIImage *)brandMarkImage:(RCBrandMark)mark size:(CGFloat)points grey:(BOOL)grey {
    BOOL dark = mark == RCBrandMarkDebossed && [self isDark];
    NSString *key = [NSString stringWithFormat:@"brandmark-%d-%g-%d-%d", mark, points, grey, dark];
    return [self imageForKey:key size:CGSizeMake(points, points) capInsets:UIEdgeInsetsZero drawing:^(CGContextRef ctx, CGRect r) {
        (void)ctx; [RCTheme drawBrandMark:mark inRect:r grey:grey];
    }];
}

#pragma mark - Bars

static void RCDrawBar(CGContextRef ctx, CGRect r, unsigned c0, unsigned c1, unsigned c2, unsigned c3, unsigned hi, CGFloat hiAlpha, unsigned border, BOOL borderBottom) {
    NSArray *colors = [NSArray arrayWithObjects:RCHex(c0), RCHex(c1), RCHex(c2), RCHex(c3), nil];
    NSArray *locs = [NSArray arrayWithObjects:[NSNumber numberWithFloat:0], [NSNumber numberWithFloat:.5], [NSNumber numberWithFloat:.51], [NSNumber numberWithFloat:1], nil];
    RCDrawVerticalGradient(ctx, r, colors, locs);
    CGFloat px = 1.0 / [UIScreen mainScreen].scale;
    CGContextSetFillColorWithColor(ctx, RCHexA(hi, hiAlpha).CGColor);
    CGContextFillRect(ctx, CGRectMake(0, borderBottom ? 0 : px, r.size.width, px * (borderBottom ? 1 : 1)));
    CGContextSetFillColorWithColor(ctx, RCHex(border).CGColor);
    CGContextFillRect(ctx, borderBottom ? CGRectMake(0, r.size.height - px, r.size.width, px) : CGRectMake(0, 0, r.size.width, px));
}

+ (UIImage *)navigationBarBackgroundForVariant:(RCBarVariant)variant {
    NSString *key = [NSString stringWithFormat:@"navbar-%d", variant];
    return [self imageForKey:key size:CGSizeMake(8, 44) capInsets:UIEdgeInsetsMake(0, 3, 0, 3) drawing:^(CGContextRef ctx, CGRect r) {
        if (variant == RCBarVariantTemporary) RCDrawBar(ctx, r, 0x8b969c, 0x5b666c, 0x4b555b, 0x3a4348, 0xffffff, .4, 0x1d2326, YES);
        else if (variant == RCBarVariantDark) RCDrawBar(ctx, r, 0x4a4a4c, 0x2a2a2c, 0x1c1c1e, 0x111111, 0xffffff, .2, 0x000000, YES);
        else RCDrawBar(ctx, r, 0x6fcf9f, 0x36a774, 0x23935f, 0x1a7f51, 0xdcffec, .55, 0x0d4f33, YES);
    }];
}

+ (UIImage *)toolbarBackground {
    return [self imageForKey:@"toolbar" size:CGSizeMake(8, 44) capInsets:UIEdgeInsetsMake(0, 3, 0, 3) drawing:^(CGContextRef ctx, CGRect r) {
        RCDrawBar(ctx, r, 0x5cc391, 0x2a9a68, 0x1f8b5b, 0x187a4f, 0xdcffec, .45, 0x0d4f33, NO);
    }];
}

+ (UIImage *)barShadow {
    return [self imageForKey:@"barshadow" size:CGSizeMake(1, 3) capInsets:UIEdgeInsetsZero drawing:^(CGContextRef ctx, CGRect r) {
        RCDrawVerticalGradient(ctx, r, [NSArray arrayWithObjects:RCHexA(0, .3), RCHexA(0, 0), nil], nil);
    }];
}

+ (UIColor *)barButtonTintForVariant:(RCBarVariant)variant {
    return variant == RCBarVariantJade ? RCHex(0x1f8656) : RCHex(0x4b555b);
}

+ (NSDictionary *)navigationTitleAttributes:(RCBarVariant)variant {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [UIFont boldSystemFontOfSize:20], UITextAttributeFont,
            [UIColor whiteColor], UITextAttributeTextColor,
            (variant == RCBarVariantJade ? RCHexA(0x00371c, .65) : RCHexA(0, .6)), UITextAttributeTextShadowColor,
            [NSValue valueWithUIOffset:UIOffsetMake(0, -1)], UITextAttributeTextShadowOffset, nil];
}

+ (void)styleNavigationBar:(UINavigationBar *)bar variant:(RCBarVariant)variant {
    [bar setBackgroundImage:[self navigationBarBackgroundForVariant:variant] forBarMetrics:UIBarMetricsDefault];
    bar.tintColor = variant == RCBarVariantJade ? RCHex(0x23935f) : (variant == RCBarVariantTemporary ? RCHex(0x4b555b) : RCHex(0x1c1c1e));
    bar.titleTextAttributes = [self navigationTitleAttributes:variant];
    if ([bar respondsToSelector:@selector(setShadowImage:)]) bar.shadowImage = [self barShadow];
}

+ (void)styleToolbar:(UIToolbar *)toolbar {
    [toolbar setBackgroundImage:[self toolbarBackground] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
    toolbar.tintColor = RCHex(0x1f8b5b);
}

+ (void)styleDarkSearchBar:(UISearchBar *)bar {
    bar.tintColor = RCHex(0x234a3b);
    bar.backgroundImage = [self imageForKey:@"searchbar-dark" size:CGSizeMake(8, 44) capInsets:UIEdgeInsetsMake(0, 3, 0, 3) drawing:^(CGContextRef ctx, CGRect r) {
        RCDrawBar(ctx, r, 0x2c5143, 0x234a3b, 0x1f4535, 0x183a2d, 0xffffff, .12, 0x0a2219, YES);
    }];
}

+ (void)applyAppearance {
    UINavigationBar *nav = [UINavigationBar appearance];
    [nav setBackgroundImage:[self navigationBarBackgroundForVariant:RCBarVariantJade] forBarMetrics:UIBarMetricsDefault];
    [nav setTintColor:RCHex(0x23935f)];
    [nav setTitleTextAttributes:[self navigationTitleAttributes:RCBarVariantJade]];
    [nav setShadowImage:[self barShadow]];

    UIToolbar *tb = [UIToolbar appearance];
    [tb setBackgroundImage:[self toolbarBackground] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
    [tb setTintColor:RCHex(0x1f8b5b)];

    UIBarButtonItem *bbi = [UIBarButtonItem appearance];
    [bbi setTintColor:RCHex(0x1f8656)];
    NSDictionary *bt = [NSDictionary dictionaryWithObjectsAndKeys:
                        [UIFont boldSystemFontOfSize:12], UITextAttributeFont,
                        [UIColor whiteColor], UITextAttributeTextColor,
                        RCHexA(0x002d16, .7), UITextAttributeTextShadowColor,
                        [NSValue valueWithUIOffset:UIOffsetMake(0, -1)], UITextAttributeTextShadowOffset, nil];
    [bbi setTitleTextAttributes:bt forState:UIControlStateNormal];

    [[UISwitch appearance] setOnTintColor:RCHex(0x2ea96a)];
    [[UISegmentedControl appearance] setTintColor:RCHex(0x23905e)];
    [[UISearchBar appearance] setTintColor:RCHex(0xa7b7af)];
    [[UIProgressView appearance] setProgressTintColor:RCHex(0x33ad6c)];
    [[UISlider appearance] setMinimumTrackTintColor:RCHex(0x1f9a5a)];
    // Temporary-chat and dark bars recolour their own bar buttons.
    [[UIBarButtonItem appearanceWhenContainedIn:[UINavigationBar class], nil] setTintColor:RCHex(0x1f8656)];
}

#pragma mark - Grouped tables

+ (void)styleGroupedTableView:(UITableView *)table {
    UIView *bg = [[[UIView alloc] initWithFrame:table.bounds] autorelease];
    bg.backgroundColor = [self contentBackgroundColor];
    table.backgroundView = bg;
    table.separatorColor = RCHex(0xc6d1cb);
}

+ (RCGroupedRowPosition)positionForRow:(NSInteger)row count:(NSInteger)count {
    if (count <= 1) return RCGroupedRowSingle;
    if (row == 0) return RCGroupedRowTop;
    if (row == count - 1) return RCGroupedRowBottom;
    return RCGroupedRowMiddle;
}

+ (void)styleGroupedCell:(UITableViewCell *)cell position:(RCGroupedRowPosition)position {
    cell.selectedBackgroundView = [[[RCGroupedSelectionView alloc] initWithPosition:position] autorelease];
    cell.textLabel.textColor = [self inkColor];
    cell.textLabel.highlightedTextColor = [UIColor whiteColor];
    cell.detailTextLabel.textColor = RCHex(0x3c6f57);
    cell.detailTextLabel.highlightedTextColor = [UIColor whiteColor];
}

+ (UIView *)checkmarkAccessoryView {
    UIImage *img = [self imageForKey:@"cell-check" size:CGSizeMake(16, 16) capInsets:UIEdgeInsetsZero drawing:^(CGContextRef ctx, CGRect r) {
        CGContextSetStrokeColorWithColor(ctx, RCHex(0x1f7d52).CGColor);
        CGContextSetLineWidth(ctx, 3);
        CGContextSetLineCap(ctx, kCGLineCapRound);
        CGContextSetLineJoin(ctx, kCGLineJoinRound);
        CGContextMoveToPoint(ctx, 2.5, 8.5); CGContextAddLineToPoint(ctx, 6.5, 12.5); CGContextAddLineToPoint(ctx, 13.5, 3);
        CGContextStrokePath(ctx);
        (void)r;
    }];
    UIImage *hi = [self imageForKey:@"cell-check-hi" size:CGSizeMake(16, 16) capInsets:UIEdgeInsetsZero drawing:^(CGContextRef ctx, CGRect r) {
        CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
        CGContextSetLineWidth(ctx, 3);
        CGContextSetLineCap(ctx, kCGLineCapRound);
        CGContextSetLineJoin(ctx, kCGLineJoinRound);
        CGContextMoveToPoint(ctx, 2.5, 8.5); CGContextAddLineToPoint(ctx, 6.5, 12.5); CGContextAddLineToPoint(ctx, 13.5, 3);
        CGContextStrokePath(ctx);
        (void)r;
    }];
    UIImageView *v = [[[UIImageView alloc] initWithImage:img highlightedImage:hi] autorelease];
    v.isAccessibilityElement = NO;
    return v;
}

+ (UIView *)groupedHeaderViewWithTitle:(NSString *)title width:(CGFloat)width {
    UIView *v = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 44)] autorelease];
    UILabel *l = [[[UILabel alloc] initWithFrame:CGRectMake(20, 17, width - 40, 21)] autorelease];
    l.backgroundColor = [UIColor clearColor];
    l.font = [UIFont boldSystemFontOfSize:16];
    l.textColor = [self engravedTextColor];
    l.shadowColor = [self engravedShadowColor];
    l.shadowOffset = [self engravedShadowOffset];
    l.text = title;
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [v addSubview:l];
    return v;
}

@end
