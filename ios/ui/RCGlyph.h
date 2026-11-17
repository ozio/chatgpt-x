// RCGlyph — the prototype's original 24×24 line glyphs (design/uxui/js/icons.js),
// rendered natively from the same SVG geometry (RCGlyphData.inc), plus the glossy
// rounded tiles used by the "+" grid and placeholders. UIKit + CoreGraphics only.
#import <UIKit/UIKit.h>

typedef enum {
    RCTileGreen = 0, RCTileBlue, RCTileOrange, RCTileRed, RCTilePurple, RCTileGray,
    RCTileTeal, RCTilePink, RCTileGraphite, RCTileYellow, RCTileDark
} RCTileColor;

@interface RCGlyph : NSObject
+ (BOOL)hasGlyph:(NSString *)name;
+ (NSArray *)allGlyphNames;
// Glyph drawn in `color` at `size` points (cached).
+ (UIImage *)imageNamed:(NSString *)name size:(CGFloat)size color:(UIColor *)color;
// Draws into the current context, glyph box = rect.
+ (void)drawGlyph:(NSString *)name inRect:(CGRect)rect color:(UIColor *)color;
// Glossy iOS 6 tile (29, 40 or 57 pt) with a white glyph.
+ (UIImage *)tileNamed:(NSString *)name color:(RCTileColor)color size:(CGFloat)size;
@end
