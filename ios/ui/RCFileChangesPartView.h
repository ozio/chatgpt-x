// RCFileChangesPartView — files a coding agent changed, inside a task history
// (prototype design/uxui css/codex.css .cx-files, Codex tier 1 «codex.file-changes»):
// header «Changed files: N» with the +added −removed total, then one row per file
// with a glossy A/M/D badge, dim directory + bold file name and its own counts.
// Tapping a row reports the change (the app opens RCDiffViewController).
// RCChangesStripView (.cx-strip) is the one-line summary above the history
// («Changes · files: N  +a −d ›») that opens the change list.
// Shared helpers draw the +/− counts and the A/M/D badge for every Codex surface.
// Light/dark, VoiceOver (each row is a button: kind, path, counts).
#import "RCPartView.h"

typedef enum { RCFileChangeModified = 0, RCFileChangeAdded, RCFileChangeDeleted } RCFileChangeKind;

@interface RCFileChange : NSObject
+ (id)changeWithPath:(NSString *)path kind:(RCFileChangeKind)kind added:(NSInteger)added removed:(NSInteger)removed;
@property (nonatomic, copy) NSString *path;      // project-relative, "src/auth/link.js"
@property (nonatomic, assign) RCFileChangeKind kind;
@property (nonatomic, assign) NSInteger added, removed;
@property (nonatomic, retain) id userInfo;
@property (nonatomic, readonly) NSString *fileName, *directory; // "link.js", "src/auth/"
@end

#ifdef __cplusplus
extern "C" {
#endif
// "+12 −3": green added, red removed, bold monospaced (Courier on iOS 6).
NSAttributedString *RCChangeCountsText(NSInteger added, NSInteger removed, CGFloat fontSize);
NSString *RCChangeCountsAccessibilityText(NSInteger added, NSInteger removed); // "12 lines added, 3 removed"
UIImage *RCFileChangeBadge(RCFileChangeKind kind);  // 17 pt glossy tile with A / M / D
NSString *RCFileChangeKindName(RCFileChangeKind kind); // "Added", "Modified", "Deleted"
#ifdef __cplusplus
}
#endif

@class RCFileChangesPartView;
@protocol RCFileChangesPartViewDelegate <NSObject>
@optional
- (void)fileChangesPart:(RCFileChangesPartView *)part didSelectChange:(RCFileChange *)change;
@end

@interface RCFileChangesPartView : RCPartView
@property (nonatomic, copy) NSArray *changes;   // RCFileChange
@property (nonatomic, assign) id<RCFileChangesPartViewDelegate> changesDelegate;
@end

// One-line summary control; UIControlEventTouchUpInside opens the change list.
// review = YES (tier 2 «codex.review», .cx-strip.review): yellow «Ревью · замечаний: N ›»
// that opens the diff with the review notes; the +/− counts are not shown.
@interface RCChangesStripView : UIControl
@property (nonatomic, assign) BOOL review;
@property (nonatomic, assign) NSUInteger reviewCount;
@property (nonatomic, assign) NSUInteger fileCount;
@property (nonatomic, assign) NSInteger added, removed;
- (CGFloat)heightForWidth:(CGFloat)width; // 38
@end
