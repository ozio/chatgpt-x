// RCFileIcon — the picture of one concrete file (not the "attach a file" action, which
// stays an RCGlyph / glossy tile). iOS 6 Mail-style document: a paper sheet with a
// folded corner, faint text lines and a glossy colour band carrying the extension
// (PDF red, DOC blue, XLS green, PPT orange, TXT grey, code navy, archive bronze,
// audio violet with a voice glyph, video graphite). Pictures are Polaroid prints:
// a white card with a wide bottom margin, upright by default, with the thumbnail or,
// while there is none, a neutral landscape. Paper stays paper in dark appearance.
// Used by the composer tray, user-message attachments, answer file cards and the
// library rows/grid. `failed` keeps the frame and adds the shared red exclamation badge.
#import <UIKit/UIKit.h>

typedef enum {
    RCFileKindDocument = 0, // unknown / no extension: plain sheet
    RCFileKindPDF, RCFileKindWord, RCFileKindSheet, RCFileKindSlides, RCFileKindText,
    RCFileKindCode, RCFileKindArchive, RCFileKindAudio, RCFileKindVideo,
    RCFileKindImage         // drawn as a Polaroid
} RCFileKind;

@interface RCFileIcon : NSObject
// Kind from the extension; the hint glyph wins when it names the kind ("photo" → image,
// "voice" → audio), so "Recording 0:07" or "Image" without an extension still read right.
+ (RCFileKind)kindForFileName:(NSString *)name glyph:(NSString *)glyph;
+ (NSString *)badgeForFileName:(NSString *)name; // "PDF", "DOCX"; nil without a short extension
// The sheet is fitted (aspect 4:5) and centred in a canvas of `size`; cached per look.
+ (UIImage *)documentIconForFileName:(NSString *)name kind:(RCFileKind)kind size:(CGSize)size failed:(BOOL)failed;
// The print is fitted in `size` after a tilt of `degrees` (negative leans left); photo nil
// draws the landscape placeholder (cached), a photo is aspect-filled into the window.
+ (UIImage *)polaroidWithPhoto:(UIImage *)photo size:(CGSize)size tilt:(CGFloat)degrees failed:(BOOL)failed;
// One call for callers: a Polaroid for pictures (or any photo), otherwise the sheet.
+ (UIImage *)iconForFileName:(NSString *)name glyph:(NSString *)glyph photo:(UIImage *)photo size:(CGSize)size failed:(BOOL)failed;
@end
