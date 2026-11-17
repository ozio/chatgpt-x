// RCTheme — ChatGPT X "jade glass" iOS 6 look in one place.
// Colours, fonts, metrics and text-size steps come from the approved prototype
// (design/uxui/css/kit.css, app.css). UIKit + CoreGraphics only, MRC, iOS 6.0+.
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif
UIColor *RCHex(unsigned rgb);
// Kit strings are written in English (the bundle development region). An app supplies
// other languages in its "Kit" strings table, keyed by the English text; without
// an entry the English text is shown.
NSString *RCL(NSString *english);
UIColor *RCHexA(unsigned rgb, CGFloat alpha);
// Fills rect with a vertical gradient. colors: UIColor array; locations: NSNumber 0…1 (nil = evenly spaced).
// Text prepared for iOS 6 system fonts: they have no ₽ (U+20BD, Unicode 7.0), shown as "руб.".
// Display only; copy and send the original string.
NSString *RCDisplayText(NSString *text);
// iOS 6.1.4 (device-verified): plain UILabel.text and -sizeWithFont: disagree on line
// breaks, so a multi-line label draws the boundary word clipped or truncated. Multi-line
// labels get an attributed string (label font, colour, alignment, word wrap) and are
// measured with the same attributes. Later font/textColor/shadow changes still apply.
void RCLabelSetText(UILabel *label, NSString *text);
CGSize RCMeasureText(NSString *text, UIFont *font, CGFloat width);
// iOS 6.1.4 (device-verified): UITextView draws through WebKit, which does not know
// the private system font (".HelveticaNeueUI") inside an attributed string and
// falls back to Times. Text views get the same face by name. A nil font is the
// 16 pt body font (an empty UITextView may return nil from -font).
UIFont *RCTextViewFont(UIFont *font);
// Attributes for -[UITextView setAttributedText:] (the only setter that keeps "\n" on iOS 6).
NSDictionary *RCTextViewAttributes(UIFont *font, UIColor *color);
void RCDrawVerticalGradient(CGContextRef ctx, CGRect rect, NSArray *colors, NSArray *locations);
// Rounded-rect path helper (radius clamped to half the shorter side).
CGPathRef RCCreateRoundedRectPath(CGRect rect, CGFloat radius) CF_RETURNS_RETAINED;
#ifdef __cplusplus
}
#endif

typedef enum {
    RCTextSizeXSmall = 0, // 14/18
    RCTextSizeSmall,      // 15/20
    RCTextSizeNormal,     // 16/21 (bubbles) 16/22 (answers)
    RCTextSizeLarge,      // 19/26
    RCTextSizeXLarge      // 22/29
} RCTextSize;

typedef enum {
    RCBarVariantJade = 0,   // normal green jade glass
    RCBarVariantTemporary,  // graphite: temporary chat
    RCBarVariantDark        // dark appearance / media
} RCBarVariant;

typedef enum {
    RCGroupedRowSingle = 0, RCGroupedRowTop, RCGroupedRowMiddle, RCGroupedRowBottom
} RCGroupedRowPosition;

extern NSString *const RCThemeTextSizeDidChangeNotification;
extern NSString *const RCThemeAppearanceDidChangeNotification;

typedef enum {
    RCAppearanceLight = 0, // default
    RCAppearanceDark       // app.css #app.dark: preferences.appearance (stage 7)
} RCAppearance;

// Bare brand mark (no tile, border or drop shadow): the app icon's silhouette as
// transparent artwork in ios/ui/Resources (rc-mark-*@2x.png, 288 px = 144 pt,
// ~12.5 % padding on each side, the silhouette ~75 % of the square). The small
// app headers keep +appIconImage:.
typedef enum {
    RCBrandMarkDebossed = 0,    // engraved into the linen (empty chat); light or dark artwork by appearance
    RCBrandMarkEmbossedEmerald, // raised emerald, for light backgrounds
    RCBrandMarkEmbossedWhite    // raised white, for dark linen (welcome, launch)
} RCBrandMark;

@interface RCTheme : NSObject
// Installs the UIAppearance proxies (navigation bar, toolbar, bar buttons, switch,
// segmented control, search bar, progress view). Call once before the first window.
+ (void)applyAppearance;

// Text size step for message/answer bodies (persisted by the caller, not here).
+ (RCTextSize)textSize;
+ (void)setTextSize:(RCTextSize)size; // posts RCThemeTextSizeDidChangeNotification
+ (UIFont *)bodyFontForSize:(RCTextSize)size;
+ (CGFloat)bodyLineHeightForSize:(RCTextSize)size answer:(BOOL)answer;
+ (UIFont *)bodyFont;
+ (CGFloat)bodyLineHeight:(BOOL)answer;
+ (NSString *)nameForTextSize:(RCTextSize)size;

// Appearance. Dark follows the prototype's #app.dark: black status bar, dark linen,
// dark answer cards, action bar and composer; jade bars, bubbles, banners, drawer
// and sheets stay as they are. Components observe the notification and recolour.
+ (RCAppearance)appearance;
+ (void)setAppearance:(RCAppearance)appearance; // also sets the status bar style
+ (BOOL)isDark;
+ (UIColor *)contentBackgroundColor;  // light linen / dark linen
+ (UIColor *)engravedTextColor;       // group heads, empty states: #4b5d55 / #b8c9c0
+ (UIColor *)noteTextColor;           // notes, footers: #5f6f67 / #b8c9c0
+ (UIColor *)metaTextColor;           // message meta: #6b7a72 / #b8c9c0
+ (UIColor *)engravedShadowColor;     // white .8 / black
+ (CGSize)engravedShadowOffset;       // (0, 1) / (0, -1)
+ (UIColor *)answerTextColor;         // #1d2924 / #e3ece7
+ (UIColor *)answerSecondaryColor;    // "ChatGPT", reasoning: #6b7a72 / #8fa39a
+ (UIColor *)cardColor;               // #fff / #1d2a24
+ (UIColor *)cardHeldColor;           // #eef5f1 / #24342c
+ (UIColor *)cardStrokeColor;         // #c7d2cc / #2c3d35

// Palette (kit.css / app.css names in comments; appearance-independent).
+ (UIColor *)inkColor;          // #1d2924 body text
+ (UIColor *)secondaryInkColor; // #6b7a72 meta / who / notes
+ (UIColor *)headerInkColor;    // #4b5d55 group headers, dim glyphs
+ (UIColor *)linkColor;         // #1c7449
// Read-aloud player (graphite glass): gradient ends, title/time/failure ink,
// bottom stroke, progress groove and fill.
+ (UIColor *)readAloudTopColor;
+ (UIColor *)readAloudBottomColor;
+ (UIColor *)readAloudInkColor;
+ (UIColor *)readAloudSecondaryInkColor;
+ (UIColor *)readAloudFailureInkColor;
+ (UIColor *)readAloudStrokeColor;
+ (UIColor *)readAloudGrooveColor;
+ (UIColor *)readAloudFillColor;
+ (UIColor *)jadeColor;         // #1f8a57 accents, "on" glyphs
+ (UIColor *)warningInkColor;   // #a26b00 "answer incomplete"
+ (UIColor *)errorInkColor;     // #a3261a
+ (UIColor *)cardBorderColor;   // #c7d2cc
+ (UIColor *)hairlineColor;     // #dfe6e2
+ (UIColor *)linenLightColor;   // pattern: rc-linen-light.png on #e8eee9
+ (UIColor *)linenDarkColor;    // pattern: rc-linen-dark.png on #1e4838
+ (UIColor *)textShadowLight;   // rgba(255,255,255,.8) for engraved text on linen

// Bars.
+ (UIImage *)navigationBarBackgroundForVariant:(RCBarVariant)variant;
+ (UIImage *)toolbarBackground;
+ (UIColor *)barButtonTintForVariant:(RCBarVariant)variant;
+ (void)styleNavigationBar:(UINavigationBar *)bar variant:(RCBarVariant)variant;
+ (void)styleToolbar:(UIToolbar *)toolbar;
+ (void)styleDarkSearchBar:(UISearchBar *)bar; // drawer search: dark green

// Grouped tables (iOS 6 grouped look, green selection, linen behind).
+ (void)styleGroupedTableView:(UITableView *)table;
+ (void)styleGroupedCell:(UITableViewCell *)cell position:(RCGroupedRowPosition)position;
+ (RCGroupedRowPosition)positionForRow:(NSInteger)row count:(NSInteger)count;
+ (UIView *)groupedHeaderViewWithTitle:(NSString *)title width:(CGFloat)width;
+ (UIView *)checkmarkAccessoryView; // jade check (kit.css .cell .check) instead of the blue iOS 6 one

// Cached resizable images for custom controls.
+ (UIImage *)imageForKey:(NSString *)key size:(CGSize)size capInsets:(UIEdgeInsets)caps drawing:(void (^)(CGContextRef ctx, CGRect rect))draw;
+ (UIImage *)appIconImage:(CGFloat)points; // 29 or 57 pt (rounded app tile); drawn fallback if the PNG is missing
// Bare mark, points × points, cached per mark, size, grey and (debossed) appearance.
// grey: luminosity only (temporary chat). Without the PNG: the app tile, so a build
// missing the artwork still shows the logo.
+ (UIImage *)brandMarkImage:(RCBrandMark)mark size:(CGFloat)points grey:(BOOL)grey;
+ (void)drawBrandMark:(RCBrandMark)mark inRect:(CGRect)rect grey:(BOOL)grey; // into the current UIKit context
@end
