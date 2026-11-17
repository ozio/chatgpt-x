// RCStatsRowView — engraved figures under a profile header (prototype
// css/codex.css .cx-prof .st, Codex tier 3 «codex.profile»): up to four equal
// columns, a bold number over a small grey caption; a number may be tinted green
// (added lines) or red (removed). Use under RCAccountHeaderView. Light/dark, VoiceOver
// (one element per column: «caption: value»).
#import <UIKit/UIKit.h>

typedef enum { RCStatPlain = 0, RCStatAdded, RCStatRemoved } RCStatTint;

@interface RCStatItem : NSObject
+ (id)itemWithValue:(NSString *)value caption:(NSString *)caption tint:(RCStatTint)tint;
@property (nonatomic, copy) NSString *value, *caption;
@property (nonatomic, assign) RCStatTint tint;
@end

@interface RCStatsRowView : UIView
@property (nonatomic, copy) NSArray *items; // RCStatItem, up to 4
- (CGFloat)heightForWidth:(CGFloat)width;   // 46
@end
