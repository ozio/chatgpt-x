#import "RCGlyph.h"
#import "RCTheme.h"
#include <ctype.h>
#include <math.h>

typedef struct {
    const char *glyph;
    char shape;  // 'p' path, 'r' rect "x y w h rx", 'c' circle "cx cy r"
    char paint;  // 's' stroke, 'f' fill
    float width; // stroke width in the 24-unit box
    const char *flags; // W knock-out detail, D dashed, H 60 % opacity
    const char *data;
} RCGlyphElement;

static const RCGlyphElement kElements[] = {
#include "RCGlyphData.inc"
};
static const NSUInteger kElementCount = sizeof(kElements) / sizeof(kElements[0]);

#pragma mark - Minimal SVG path reader (M L H V C S Q A Z, absolute and relative)

static const char *RCSkip(const char *s) {
    while (*s == ' ' || *s == ',' || *s == '\n' || *s == '\t') s++;
    return s;
}

static BOOL RCReadNumber(const char **ps, CGFloat *out) {
    const char *s = RCSkip(*ps);
    if (!(isdigit((unsigned char)*s) || *s == '-' || *s == '+' || *s == '.')) return NO;
    char *end = NULL;
    double v = strtod(s, &end);
    if (end == s) return NO;
    *out = (CGFloat)v;
    *ps = end;
    return YES;
}

static BOOL RCReadNumbers(const char **ps, CGFloat *out, int n) {
    const char *s = *ps;
    for (int i = 0; i < n; i++) if (!RCReadNumber(&s, &out[i])) return NO;
    *ps = s;
    return YES;
}

static void RCAddArc(CGMutablePathRef p, CGFloat x1, CGFloat y1, CGFloat rx, CGFloat ry, CGFloat phiDeg, int large, int sweep, CGFloat x2, CGFloat y2) {
    if (x1 == x2 && y1 == y2) return;
    if (rx == 0 || ry == 0) { CGPathAddLineToPoint(p, NULL, x2, y2); return; }
    double Rx = fabs(rx), Ry = fabs(ry);
    double phi = phiDeg * M_PI / 180.0, cphi = cos(phi), sphi = sin(phi);
    double dx = (x1 - x2) / 2.0, dy = (y1 - y2) / 2.0;
    double x1p = cphi * dx + sphi * dy, y1p = -sphi * dx + cphi * dy;
    double lam = (x1p * x1p) / (Rx * Rx) + (y1p * y1p) / (Ry * Ry);
    if (lam > 1) { double s = sqrt(lam); Rx *= s; Ry *= s; }
    double num = Rx * Rx * Ry * Ry - Rx * Rx * y1p * y1p - Ry * Ry * x1p * x1p;
    double den = Rx * Rx * y1p * y1p + Ry * Ry * x1p * x1p;
    double coef = den == 0 ? 0 : sqrt(fmax(0, num / den));
    if (large == sweep) coef = -coef;
    double cxp = coef * Rx * y1p / Ry, cyp = -coef * Ry * x1p / Rx;
    double cx = cphi * cxp - sphi * cyp + (x1 + x2) / 2.0, cy = sphi * cxp + cphi * cyp + (y1 + y2) / 2.0;
    double th1 = atan2((y1p - cyp) / Ry, (x1p - cxp) / Rx);
    double th2 = atan2((-y1p - cyp) / Ry, (-x1p - cxp) / Rx);
    double dth = th2 - th1;
    if (sweep && dth < 0) dth += 2 * M_PI;
    else if (!sweep && dth > 0) dth -= 2 * M_PI;
    int segs = (int)ceil(fabs(dth) / (M_PI / 2) - 1e-9);
    if (segs < 1) segs = 1;
    double delta = dth / segs, t = 4.0 / 3.0 * tan(delta / 4), th = th1;
#define RCMAPX(u, v) (cx + Rx * (u) * cphi - Ry * (v) * sphi)
#define RCMAPY(u, v) (cy + Rx * (u) * sphi + Ry * (v) * cphi)
    for (int i = 0; i < segs; i++) {
        double c1 = cos(th), s1 = sin(th), c2 = cos(th + delta), s2 = sin(th + delta);
        double u1 = c1 - t * s1, v1 = s1 + t * c1, u2 = c2 + t * s2, v2 = s2 - t * c2;
        CGPathAddCurveToPoint(p, NULL, RCMAPX(u1, v1), RCMAPY(u1, v1), RCMAPX(u2, v2), RCMAPY(u2, v2), RCMAPX(c2, s2), RCMAPY(c2, s2));
        th += delta;
    }
#undef RCMAPX
#undef RCMAPY
}

static void RCAddSVGPath(CGMutablePathRef path, const char *d) {
    CGFloat cx = 0, cy = 0, sx = 0, sy = 0, lcx = 0, lcy = 0;
    char cmd = 0, prev = 0;
    const char *s = d;
    for (;;) {
        s = RCSkip(s);
        if (!*s) break;
        if (isalpha((unsigned char)*s)) cmd = *s++;
        else if (!cmd) break;
        BOOL rel = islower((unsigned char)cmd) != 0;
        char C = (char)toupper((unsigned char)cmd);
        CGFloat a[7];
        CGFloat ox = rel ? cx : 0, oy = rel ? cy : 0;
        switch (C) {
            case 'Z':
                CGPathCloseSubpath(path);
                cx = sx; cy = sy; cmd = 0;
                break;
            case 'M':
                if (!RCReadNumbers(&s, a, 2)) return;
                cx = a[0] + ox; cy = a[1] + oy; sx = cx; sy = cy;
                CGPathMoveToPoint(path, NULL, cx, cy);
                cmd = rel ? 'l' : 'L';
                break;
            case 'L':
                if (!RCReadNumbers(&s, a, 2)) return;
                cx = a[0] + ox; cy = a[1] + oy;
                CGPathAddLineToPoint(path, NULL, cx, cy);
                break;
            case 'H':
                if (!RCReadNumbers(&s, a, 1)) return;
                cx = a[0] + ox;
                CGPathAddLineToPoint(path, NULL, cx, cy);
                break;
            case 'V':
                if (!RCReadNumbers(&s, a, 1)) return;
                cy = a[0] + oy;
                CGPathAddLineToPoint(path, NULL, cx, cy);
                break;
            case 'C':
                if (!RCReadNumbers(&s, a, 6)) return;
                CGPathAddCurveToPoint(path, NULL, a[0] + ox, a[1] + oy, a[2] + ox, a[3] + oy, a[4] + ox, a[5] + oy);
                lcx = a[2] + ox; lcy = a[3] + oy; cx = a[4] + ox; cy = a[5] + oy;
                break;
            case 'S': {
                if (!RCReadNumbers(&s, a, 4)) return;
                CGFloat x1 = (prev == 'C' || prev == 'S') ? 2 * cx - lcx : cx;
                CGFloat y1 = (prev == 'C' || prev == 'S') ? 2 * cy - lcy : cy;
                CGPathAddCurveToPoint(path, NULL, x1, y1, a[0] + ox, a[1] + oy, a[2] + ox, a[3] + oy);
                lcx = a[0] + ox; lcy = a[1] + oy; cx = a[2] + ox; cy = a[3] + oy;
                break;
            }
            case 'Q':
                if (!RCReadNumbers(&s, a, 4)) return;
                CGPathAddQuadCurveToPoint(path, NULL, a[0] + ox, a[1] + oy, a[2] + ox, a[3] + oy);
                cx = a[2] + ox; cy = a[3] + oy;
                break;
            case 'A':
                if (!RCReadNumbers(&s, a, 7)) return;
                RCAddArc(path, cx, cy, a[0], a[1], a[2], a[3] != 0, a[4] != 0, a[5] + ox, a[6] + oy);
                cx = a[5] + ox; cy = a[6] + oy;
                break;
            default:
                return; // unsupported command: stop rather than guess
        }
        prev = C;
    }
}

static CGPathRef RCCreateElementPath(const RCGlyphElement *e) {
    CGMutablePathRef p = CGPathCreateMutable();
    if (e->shape == 'p') {
        RCAddSVGPath(p, e->data);
    } else {
        CGFloat v[5] = {0, 0, 0, 0, 0};
        const char *s = e->data;
        int n = e->shape == 'r' ? 5 : 3;
        RCReadNumbers(&s, v, n);
        if (e->shape == 'r') {
            CGRect r = CGRectMake(v[0], v[1], v[2], v[3]);
            if (v[4] > 0) { CGPathRef rr = RCCreateRoundedRectPath(r, v[4]); CGPathAddPath(p, NULL, rr); CGPathRelease(rr); }
            else CGPathAddRect(p, NULL, r);
        } else {
            CGPathAddEllipseInRect(p, NULL, CGRectMake(v[0] - v[2], v[1] - v[2], v[2] * 2, v[2] * 2));
        }
    }
    return p;
}

@implementation RCGlyph

+ (BOOL)hasGlyph:(NSString *)name {
    const char *n = name.UTF8String;
    for (NSUInteger i = 0; i < kElementCount; i++) if (n && strcmp(kElements[i].glyph, n) == 0) return YES;
    return NO;
}

+ (NSArray *)allGlyphNames {
    NSMutableArray *names = [NSMutableArray array];
    for (NSUInteger i = 0; i < kElementCount; i++) {
        NSString *n = [NSString stringWithUTF8String:kElements[i].glyph];
        if (![names containsObject:n]) [names addObject:n];
    }
    return names;
}

+ (void)drawGlyph:(NSString *)name inRect:(CGRect)rect color:(UIColor *)color {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    const char *n = name.UTF8String;
    if (!ctx || !n) return;
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, rect.origin.x, rect.origin.y);
    CGContextScaleCTM(ctx, rect.size.width / 24.0, rect.size.height / 24.0);
    CGContextBeginTransparencyLayer(ctx, NULL);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    for (NSUInteger i = 0; i < kElementCount; i++) {
        const RCGlyphElement *e = &kElements[i];
        if (strcmp(e->glyph, n) != 0) continue;
        BOOL knock = strchr(e->flags, 'W') != NULL, dashed = strchr(e->flags, 'D') != NULL, half = strchr(e->flags, 'H') != NULL;
        CGContextSaveGState(ctx);
        UIColor *c = color;
        if (knock) {
            // White details in the source (gear hub, camera lens) are holes in the glyph.
            CGContextSetBlendMode(ctx, kCGBlendModeDestinationOut);
            c = [UIColor colorWithWhite:0 alpha:half ? .6 : 1];
        } else if (half) {
            c = [color colorWithAlphaComponent:.6];
        }
        CGPathRef p = RCCreateElementPath(e);
        CGContextAddPath(ctx, p);
        if (e->paint == 's') {
            CGContextSetLineWidth(ctx, e->width);
            if (dashed) { CGFloat dash[2] = {3, 2.6}; CGContextSetLineDash(ctx, 0, dash, 2); }
            CGContextSetStrokeColorWithColor(ctx, c.CGColor);
            CGContextStrokePath(ctx);
        } else {
            CGContextSetFillColorWithColor(ctx, c.CGColor);
            CGContextFillPath(ctx);
        }
        CGPathRelease(p);
        CGContextRestoreGState(ctx);
    }
    CGContextEndTransparencyLayer(ctx);
    CGContextRestoreGState(ctx);
}

+ (NSString *)keyForColor:(UIColor *)color {
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) { CGFloat w = 0; [color getWhite:&w alpha:&a]; r = g = b = w; }
    return [NSString stringWithFormat:@"%.3f,%.3f,%.3f,%.3f", r, g, b, a];
}

+ (UIImage *)imageNamed:(NSString *)name size:(CGFloat)size color:(UIColor *)color {
    if (!color) color = [UIColor whiteColor];
    NSString *key = [NSString stringWithFormat:@"glyph-%@-%g-%@", name, size, [self keyForColor:color]];
    return [RCTheme imageForKey:key size:CGSizeMake(size, size) capInsets:UIEdgeInsetsZero drawing:^(CGContextRef ctx, CGRect r) {
        (void)ctx;
        [RCGlyph drawGlyph:name inRect:r color:color];
    }];
}

+ (UIImage *)tileNamed:(NSString *)name color:(RCTileColor)color size:(CGFloat)size {
    static const unsigned tiles[][2] = {
        {0x7fdcab, 0x1e9656}, {0x7fb5f5, 0x2a66cc}, {0xffc874, 0xe07a0c}, {0xff8c7f, 0xc9200f},
        {0xc6a4f4, 0x6c3fc2}, {0xc9d0cd, 0x6b7672}, {0x7ee0dd, 0x13878a}, {0xffa3c8, 0xd0377a},
        {0x8a959b, 0x353e43}, {0xffe27a, 0xd9a400}, {0x4f6d61, 0x163328}};
    int ci = (int)color;
    if (ci < 0 || ci > RCTileDark) ci = 0;
    NSString *key = [NSString stringWithFormat:@"tile-%@-%d-%g", name, ci, size];
    CGFloat radius = size >= 57 ? 10 : (size >= 40 ? 8 : 6);
    CGFloat glyph = size >= 57 ? 34 : (size >= 40 ? 26 : 19);
    return [RCTheme imageForKey:key size:CGSizeMake(size, size + 2) capInsets:UIEdgeInsetsZero drawing:^(CGContextRef ctx, CGRect bounds) {
        CGRect r = CGRectMake(0, 0, size, size);
        CGPathRef p = RCCreateRoundedRectPath(r, radius);
        // drop shadow: 0 1px 1px rgba(0,0,0,.35)
        CGContextSaveGState(ctx);
        CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1), 1, RCHexA(0, .35).CGColor);
        CGContextAddPath(ctx, p);
        CGContextSetFillColorWithColor(ctx, RCHex(tiles[ci][1]).CGColor);
        CGContextFillPath(ctx);
        CGContextRestoreGState(ctx);
        CGContextSaveGState(ctx);
        CGContextAddPath(ctx, p);
        CGContextClip(ctx);
        RCDrawVerticalGradient(ctx, r, [NSArray arrayWithObjects:RCHex(tiles[ci][0]), RCHex(tiles[ci][1]), nil], nil);
        [RCGlyph drawGlyph:name inRect:CGRectMake((size - glyph) / 2, (size - glyph) / 2, glyph, glyph) color:[UIColor whiteColor]];
        // gloss: lower half of an ellipse hanging from the top edge
        CGRect gloss = CGRectMake(-size * .1, -size * 1.05, size * 1.2, size * 1.5);
        CGContextAddEllipseInRect(ctx, gloss);
        CGContextClip(ctx);
        RCDrawVerticalGradient(ctx, CGRectMake(0, 0, size, size * .45), [NSArray arrayWithObjects:RCHexA(0xffffff, .55), RCHexA(0xffffff, .12), nil], nil);
        CGContextRestoreGState(ctx);
        // inset hairline: inset 0 0 0 1px rgba(0,0,0,.12)
        CGContextAddPath(ctx, p);
        CGContextSetStrokeColorWithColor(ctx, RCHexA(0, .12).CGColor);
        CGContextSetLineWidth(ctx, 1);
        CGContextStrokePath(ctx);
        CGPathRelease(p);
        (void)bounds;
    }];
}

@end
