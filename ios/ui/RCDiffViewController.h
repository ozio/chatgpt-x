// RCDiffViewController — unified diff of one file (prototype css/codex.css .cx-diff,
// Codex tier 1 «codex.diff»): white paper, a header strip with the A/M/D badge, the
// full path and +/− counts, grey glossy hunk bars «@@ function name», then one row
// per line: old and new line numbers in narrow grey gutters, a green «+» or red «−»,
// and the monospaced text wrapping by character. Added lines are pale green, removed
// pale red (deeper tints in dark). One table row per line: long diffs scroll without
// any layer over the 2048 pt limit; row heights are computed arithmetically from the
// monospaced advance, so no text is measured before the first frame.
// Read only; the app sets the title and any «Next» bar button.
// Tier 2 review («codex.review»): a hunk may carry comments, drawn after their line
// as yellow notes («Codex · ревью», text, optional «Исправить» reported to the
// delegate — the app sends it to the task, the view changes nothing itself).
#import <UIKit/UIKit.h>
#import "RCFileChangesPartView.h"

@interface RCDiffComment : NSObject
+ (id)commentAfterLine:(NSUInteger)lineIndex text:(NSString *)text; // index into the hunk's lines
@property (nonatomic, assign) NSUInteger lineIndex;
@property (nonatomic, copy) NSString *title;   // default «Codex · review»
@property (nonatomic, copy) NSString *text;
@property (nonatomic, retain) id userInfo;
@end

@interface RCDiffHunk : NSObject
// lines: NSString with the unified prefix: "+added", "-removed", " context".
+ (id)hunkWithHeader:(NSString *)header oldStart:(NSInteger)oldStart newStart:(NSInteger)newStart lines:(NSArray *)lines;
@property (nonatomic, copy) NSString *header;
@property (nonatomic, assign) NSInteger oldStart, newStart;
@property (nonatomic, copy) NSArray *lines;
@property (nonatomic, copy) NSArray *comments; // RCDiffComment (tier 2)
@end

@class RCDiffViewController;
@protocol RCDiffViewControllerDelegate <NSObject>
@optional
- (void)diffController:(RCDiffViewController *)controller didTapFixComment:(RCDiffComment *)comment;
@end

@interface RCDiffViewController : UITableViewController
@property (nonatomic, retain) RCFileChange *change; // path, kind, counts for the header
@property (nonatomic, copy) NSArray *hunks;          // RCDiffHunk
@property (nonatomic, assign) BOOL fixAvailable;     // «Fix» under review comments
@property (nonatomic, assign) id<RCDiffViewControllerDelegate> delegate;
@end
