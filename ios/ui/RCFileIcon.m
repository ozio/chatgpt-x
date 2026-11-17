#import "RCFileIcon.h"
#import "RCTheme.h"
#import "RCGlyph.h"
#import "RCUserMessageView.h"
#include <math.h>

typedef struct { unsigned top, bottom; } RCFileBand;

static RCFileBand RCFileBandForKind(RCFileKind k) {
    switch (k) {
        case RCFileKindPDF:     return (RCFileBand){0xe0503f, 0xb02a1c};
        case RCFileKindWord:    return (RCFileBand){0x4b8ade, 0x2259ad};
        case RCFileKindSheet:   return (RCFileBand){0x3fae66, 0x1e7d40};
        case RCFileKindSlides:  return (RCFileBand){0xec8c36, 0xbd5e12};
        case RCFileKindText:    return (RCFileBand){0x8f9b95, 0x5f6b65};
        case RCFileKindCode:    return (RCFileBand){0x4e5f84, 0x27344f};
        case RCFileKindArchive: return (RCFileBand){0xc09a4e, 0x8a672a};
        case RCFileKindAudio:   return (RCFileBand){0x9a62d2, 0x6b35a0};
        case RCFileKindVideo:   return (RCFileBand){0x4a5157, 0x1b2024};
        default:                return (RCFileBand){0x8f9b95, 0x5f6b65};
    }
}

@implementation RCFileIcon
+ (void)drawFailureBadgeInCanvas:(CGSize)size {
    CGFloat side=MIN(26,MAX(14,round(size.width*.34)));
    [[RCUserMessageView badgeImage:NO]drawInRect:CGRectMake(size.width-side,size.height-side*27/26,side,side*27/26)];
}


+ (NSString *)badgeForFileName:(NSString *)name {
    NSString *ext = [[name lastPathComponent] pathExtension];
    if (ext.length < 1 || ext.length > 4) return nil;
    if ([ext rangeOfCharacterFromSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]].location != NSNotFound) return nil;
    return [ext uppercaseString];
}

+ (RCFileKind)kindForFileName:(NSString *)name glyph:(NSString *)glyph {
    if ([glyph isEqualToString:@"photo"] || [glyph isEqualToString:@"image"]) return RCFileKindImage;
    if ([glyph isEqualToString:@"voice"] || [glyph isEqualToString:@"mic"]) return RCFileKindAudio;
    NSString *e = [[[name lastPathComponent] pathExtension] lowercaseString];
    if (!e.length) return RCFileKindDocument;
    static NSDictionary *map = nil;
    if (!map) {
        NSMutableDictionary *m = [NSMutableDictionary dictionary];
        NSArray *groups = [NSArray arrayWithObjects:
            [NSArray arrayWithObjects:[NSNumber numberWithInt:RCFileKindPDF], @"pdf", nil],
            [NSArray arrayWithObjects:[NSNumber numberWithInt:RCFileKindWord], @"doc", @"docx", @"rtf", @"pages", @"odt", nil],
            [NSArray arrayWithObjects:[NSNumber numberWithInt:RCFileKindSheet], @"xls", @"xlsx", @"csv", @"tsv", @"numbers", @"ods", nil],
            [NSArray arrayWithObjects:[NSNumber numberWithInt:RCFileKindSlides], @"ppt", @"pptx", @"key", @"odp", nil],
            [NSArray arrayWithObjects:[NSNumber numberWithInt:RCFileKindText], @"txt", @"md", @"log", @"text", nil],
            [NSArray arrayWithObjects:[NSNumber numberWithInt:RCFileKindCode], @"json", @"js", @"ts", @"py", @"html", @"htm", @"css", @"xml", @"swift", @"m", @"h", @"c", @"cpp", @"java", @"sh", @"yml", @"yaml", @"sql", @"rb", @"go", @"rs", @"php", nil],
            [NSArray arrayWithObjects:[NSNumber numberWithInt:RCFileKindArchive], @"zip", @"rar", @"7z", @"gz", @"tar", @"tgz", @"bz2", nil],
            [NSArray arrayWithObjects:[NSNumber numberWithInt:RCFileKindAudio], @"m4a", @"mp3", @"wav", @"caf", @"aac", @"ogg", @"flac", @"aiff", nil],
            [NSArray arrayWithObjects:[NSNumber numberWithInt:RCFileKindVideo], @"mp4", @"mov", @"m4v", @"avi", @"webm", @"mkv", nil],
            [NSArray arrayWithObjects:[NSNumber numberWithInt:RCFileKindImage], @"png", @"jpg", @"jpeg", @"gif", @"heic", @"webp", @"tif", @"tiff", @"bmp", nil], nil];
        for (NSArray *g in groups) for (NSUInteger i = 1; i < g.count; i++) [m setObject:[g objectAtIndex:0] forKey:[g objectAtIndex:i]];
        map = [m copy];
    }
    NSNumber *k = [map objectForKey:e];
    return k ? (RCFileKind)[k intValue] : RCFileKindDocument;
}

#pragma mark - Document sheet

+ (void)drawDocumentInCanvas:(CGSize)size kind:(RCFileKind)kind badge:(NSString *)badge failed:(BOOL)failed {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat aw = size.width - 4, ah = size.height - 4;
    CGFloat sh = floor(MIN(ah, aw / .8)), sw = floor(sh * .8);
    CGFloat x = floor((size.width - sw) / 2), y = floor(1 + (ah - sh) / 2);
    CGFloat f = round(sw * .3), rr = MAX(1, sw * .05);
    CGMutablePathRef p = CGPathCreateMutable();
    CGPathMoveToPoint(p, NULL, x + sw - f, y);
    CGPathAddLineToPoint(p, NULL, x + sw, y + f);
    CGPathAddArcToPoint(p, NULL, x + sw, y + sh, x, y + sh, rr);
    CGPathAddArcToPoint(p, NULL, x, y + sh, x, y, rr);
    CGPathAddArcToPoint(p, NULL, x, y, x + sw - f, y, rr);
    CGPathCloseSubpath(p);

    // paper with its drop shadow
    CGContextSaveGState(ctx);
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1), 2, RCHexA(0, .3).CGColor);
    CGContextAddPath(ctx, p); CGContextSetFillColorWithColor(ctx, RCHex(0xffffff).CGColor); CGContextFillPath(ctx);
    CGContextRestoreGState(ctx);

    CGContextSaveGState(ctx);
    CGContextAddPath(ctx, p); CGContextClip(ctx);
    RCDrawVerticalGradient(ctx, CGRectMake(x, y, sw, sh), [NSArray arrayWithObjects:RCHex(0xffffff), RCHex(0xedf1ef), nil], nil);
    BOOL band = kind != RCFileKindDocument || badge.length;
    CGFloat bandH = round(sh * .25), bandY = round(y + sh - bandH - sh * .11);
    // faint text lines
    if (sw >= 20) {
        CGFloat lh = MAX(1, round(sh * .035)), gap = MAX(lh + 1, round(sh * .085));
        CGFloat ly = y + f + round(gap * .4), stop = band ? bandY - round(gap * .35) : y + sh - gap;
        CGFloat widths[4] = {.68, .58, .68, .44};
        CGContextSetFillColorWithColor(ctx, RCHex(0xd2d9d5).CGColor);
        for (int i = 0; ly + lh <= stop; i++, ly += gap) CGContextFillRect(ctx, CGRectMake(x + round(sw * .16), ly, round(sw * widths[i % 4]), lh));
    }
    if (band) {
        RCFileBand c = RCFileBandForKind(kind);
        CGRect br = CGRectMake(x, bandY, sw, bandH);
        RCDrawVerticalGradient(ctx, br, [NSArray arrayWithObjects:RCHex(c.top), RCHex(c.bottom), nil], nil);
        CGContextSetFillColorWithColor(ctx, RCHexA(0xffffff, .35).CGColor); CGContextFillRect(ctx, CGRectMake(x, bandY, sw, MAX(.5, bandH * .06)));
        CGContextSetFillColorWithColor(ctx, RCHexA(0, .18).CGColor); CGContextFillRect(ctx, CGRectMake(x, bandY + bandH - .5, sw, .5));
        if (badge.length) {
            CGFloat pt = MAX(5, floor(bandH * .62));
            UIFont *font = [UIFont boldSystemFontOfSize:pt];
            CGSize ts = [badge sizeWithFont:font];
            while (ts.width > sw * .86 && pt > 5) { pt -= .5; font = [UIFont boldSystemFontOfSize:pt]; ts = [badge sizeWithFont:font]; }
            CGContextSetShadowWithColor(ctx, CGSizeMake(0, -.5), 0, RCHexA(0, .35).CGColor);
            CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
            [badge drawAtPoint:CGPointMake(x + round((sw - ts.width) / 2), bandY + round((bandH - ts.height) / 2)) withFont:font];
            CGContextSetShadowWithColor(ctx, CGSizeZero, 0, NULL);
        } else {
            CGFloat gs = floor(bandH * .78);
            UIImage *g = [RCGlyph imageNamed:(kind == RCFileKindAudio ? @"voice" : @"file") size:gs color:[UIColor whiteColor]];
            [g drawInRect:CGRectMake(x + round((sw - gs) / 2), bandY + round((bandH - gs) / 2), gs, gs)];
        }
    }
    CGContextRestoreGState(ctx);

    // folded corner
    CGMutablePathRef fold = CGPathCreateMutable();
    CGPathMoveToPoint(fold, NULL, x + sw - f, y);
    CGPathAddLineToPoint(fold, NULL, x + sw, y + f);
    CGPathAddArcToPoint(fold, NULL, x + sw - f, y + f, x + sw - f, y, MAX(.5, rr * .8));
    CGPathCloseSubpath(fold);
    CGContextSaveGState(ctx);
    CGContextSetShadowWithColor(ctx, CGSizeMake(-.5, 1), 1.5, RCHexA(0, .22).CGColor);
    CGContextAddPath(ctx, fold); CGContextSetFillColorWithColor(ctx, RCHex(0xe6ece9).CGColor); CGContextFillPath(ctx);
    CGContextRestoreGState(ctx);
    CGContextSaveGState(ctx);
    CGContextAddPath(ctx, fold); CGContextClip(ctx);
    RCDrawVerticalGradient(ctx, CGRectMake(x + sw - f, y, f, f), [NSArray arrayWithObjects:RCHex(0xfbfcfb), RCHex(0xd6deda), nil], nil);
    CGContextRestoreGState(ctx);
    CGContextAddPath(ctx, fold); CGContextSetStrokeColorWithColor(ctx, RCHex(0xb3beb8).CGColor); CGContextSetLineWidth(ctx, .5); CGContextStrokePath(ctx);

    // outline
    CGContextAddPath(ctx, p);
    CGContextSetStrokeColorWithColor(ctx, RCHex(0xa9b5af).CGColor);
    CGContextSetLineWidth(ctx, .75);
    CGContextStrokePath(ctx);
    CGPathRelease(fold); CGPathRelease(p);
    if(failed)[self drawFailureBadgeInCanvas:size];
}

+ (UIImage *)documentIconForFileName:(NSString *)name kind:(RCFileKind)kind size:(CGSize)size failed:(BOOL)failed {
    NSString *badge = [self badgeForFileName:name];
    NSString *key = [NSString stringWithFormat:@"file-doc-%d-%@-%gx%g-%d", (int)kind, badge ? badge : @"", size.width, size.height, failed ? 1 : 0];
    return [RCTheme imageForKey:key size:size capInsets:UIEdgeInsetsZero drawing:^(CGContextRef ctx, CGRect r) {
        (void)ctx; (void)r; [RCFileIcon drawDocumentInCanvas:size kind:kind badge:badge failed:failed];
    }];
}

#pragma mark - Polaroid

+ (void)drawLandscapeInRect:(CGRect)w context:(CGContextRef)ctx {
    RCDrawVerticalGradient(ctx, w, [NSArray arrayWithObjects:RCHex(0x8fc9e3), RCHex(0xdff0f3), nil], nil);
    CGFloat s = w.size.width;
    CGContextSetFillColorWithColor(ctx, RCHex(0xf6d35a).CGColor);
    CGContextFillEllipseInRect(ctx, CGRectMake(w.origin.x + s * .62, w.origin.y + s * .16, s * .2, s * .2));
    CGFloat bx = w.origin.x, by = CGRectGetMaxY(w);
    CGMutablePathRef back = CGPathCreateMutable();
    CGPathMoveToPoint(back, NULL, bx, by - s * .38);
    CGPathAddCurveToPoint(back, NULL, bx + s * .25, by - s * .58, bx + s * .5, by - s * .5, bx + s * .7, by - s * .36);
    CGPathAddCurveToPoint(back, NULL, bx + s * .82, by - s * .3, bx + s * .92, by - s * .34, bx + s, by - s * .42);
    CGPathAddLineToPoint(back, NULL, bx + s, by); CGPathAddLineToPoint(back, NULL, bx, by); CGPathCloseSubpath(back);
    CGContextAddPath(ctx, back); CGContextSetFillColorWithColor(ctx, RCHex(0x7dbf96).CGColor); CGContextFillPath(ctx);
    CGMutablePathRef front = CGPathCreateMutable();
    CGPathMoveToPoint(front, NULL, bx, by - s * .2);
    CGPathAddCurveToPoint(front, NULL, bx + s * .3, by - s * .34, bx + s * .6, by - s * .14, bx + s, by - s * .26);
    CGPathAddLineToPoint(front, NULL, bx + s, by); CGPathAddLineToPoint(front, NULL, bx, by); CGPathCloseSubpath(front);
    CGContextAddPath(ctx, front); CGContextSetFillColorWithColor(ctx, RCHex(0x2f8a57).CGColor); CGContextFillPath(ctx);
    CGPathRelease(back); CGPathRelease(front);
}

+ (void)drawPolaroidInCanvas:(CGSize)size photo:(UIImage *)photo tilt:(CGFloat)degrees failed:(BOOL)failed {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat t = degrees * (CGFloat)M_PI / 180, c = fabs(cos(t)), s = fabs(sin(t));
    CGFloat aw = size.width - 5, ah = size.height - 5, k = .86;
    CGFloat u = floor(MIN(aw / (k * c + s), ah / (k * s + c)));
    CGFloat cw = round(u * k), ch = u;
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, size.width / 2, (size.height - 1) / 2);
    CGContextRotateCTM(ctx, t);
    CGRect card = CGRectMake(-cw / 2, -ch / 2, cw, ch);
    CGPathRef cp = RCCreateRoundedRectPath(card, MAX(.5, cw * .02));
    CGContextSaveGState(ctx);
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1.5), 2.5, RCHexA(0, .38).CGColor);
    CGContextAddPath(ctx, cp); CGContextSetFillColorWithColor(ctx, RCHex(0xfcfcf8).CGColor); CGContextFillPath(ctx);
    CGContextRestoreGState(ctx);
    CGContextSaveGState(ctx);
    CGContextAddPath(ctx, cp); CGContextClip(ctx);
    RCDrawVerticalGradient(ctx, card, [NSArray arrayWithObjects:RCHex(0xfefefb), RCHex(0xf0f0ea), nil], nil);
    CGContextRestoreGState(ctx);
    CGFloat m = MAX(2, round(cw * .075));
    CGRect win = CGRectMake(card.origin.x + m, card.origin.y + m, cw - 2 * m, cw - 2 * m);
    CGContextSaveGState(ctx);
    CGContextClipToRect(ctx, win);
    if (photo) {
        CGSize ps = photo.size; CGFloat q = MAX(win.size.width / MAX(1, ps.width), win.size.height / MAX(1, ps.height));
        [photo drawInRect:CGRectMake(CGRectGetMidX(win) - ps.width * q / 2, CGRectGetMidY(win) - ps.height * q / 2, ps.width * q, ps.height * q)];
    } else [self drawLandscapeInRect:win context:ctx];
    CGContextRestoreGState(ctx);
    CGContextSetStrokeColorWithColor(ctx, RCHexA(0, .16).CGColor); CGContextSetLineWidth(ctx, .5);
    CGContextStrokeRect(ctx, CGRectInset(win, .25, .25));
    CGContextAddPath(ctx, cp);
    CGContextSetStrokeColorWithColor(ctx, RCHexA(0x55615b, .35).CGColor);
    CGContextSetLineWidth(ctx, .5);
    CGContextStrokePath(ctx);
    CGPathRelease(cp);
    CGContextRestoreGState(ctx);
    if(failed)[self drawFailureBadgeInCanvas:size];
}

+ (UIImage *)polaroidWithPhoto:(UIImage *)photo size:(CGSize)size tilt:(CGFloat)degrees failed:(BOOL)failed {
    if (!photo) {
        NSString *key = [NSString stringWithFormat:@"file-polaroid-%gx%g-%g-%d", size.width, size.height, degrees, failed ? 1 : 0];
        return [RCTheme imageForKey:key size:size capInsets:UIEdgeInsetsZero drawing:^(CGContextRef ctx, CGRect r) {
            (void)ctx; (void)r; [RCFileIcon drawPolaroidInCanvas:size photo:nil tilt:degrees failed:failed];
        }];
    }
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    [self drawPolaroidInCanvas:size photo:photo tilt:degrees failed:failed];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)iconForFileName:(NSString *)name glyph:(NSString *)glyph photo:(UIImage *)photo size:(CGSize)size failed:(BOOL)failed {
    RCFileKind kind = [self kindForFileName:name glyph:glyph];
    if (photo || kind == RCFileKindImage) return [self polaroidWithPhoto:photo size:size tilt:0 failed:failed];
    return [self documentIconForFileName:name kind:kind size:size failed:failed];
}
@end
