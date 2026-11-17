// RCSourcesSheet — «Источники» (prototype S.sources, stage 8): a modal grouped list
// «N источников» with a numbered row per source (site initial tile, title, host)
// with optional caller-supplied footer; «Готово» closes. Tapping a row
// goes to the delegate (the caller confirms and opens the URL). RCSourceRowView is
// the same row as a plain view for other screens (e.g. RCReportViewController).
#import <UIKit/UIKit.h>

@interface RCSourceItem : NSObject
+ (id)sourceWithTitle:(NSString *)title host:(NSString *)host URL:(NSURL *)url;
@property (nonatomic, copy) NSString *title, *host;
@property (nonatomic, retain) NSURL *URL;
@property (nonatomic, retain) UIImage *icon; // favicon; nil: initial on a tile
@end

// «1 источник», «3 источника», «12 источников»
NSString *RCSourcesCountTitle(NSUInteger count);

@interface RCSourceRowView : UIControl
- (id)initWithSource:(RCSourceItem *)source number:(NSUInteger)number;
@property (nonatomic, retain) RCSourceItem *source;
@property (nonatomic, assign) NSUInteger number; // 1-based, 0 hides it
@property (nonatomic, assign) BOOL followsAppearance; // YES: answer colours (cards); NO: ink on white grouped cells
- (CGFloat)heightForWidth:(CGFloat)width;
+ (UIImage *)tileForSource:(RCSourceItem *)source; // 29 pt
@end

@class RCSourcesSheet;
@protocol RCSourcesSheetDelegate <NSObject>
- (void)sourcesSheet:(RCSourcesSheet *)sheet didSelectSource:(RCSourceItem *)source;
@optional
- (void)sourcesSheetDidFinish:(RCSourcesSheet *)sheet; // without it the sheet dismisses itself
@end

@interface RCSourcesSheet : UITableViewController
- (id)initWithSources:(NSArray *)sources; // RCSourceItem
@property (nonatomic, copy) NSArray *sources;
@property (nonatomic, copy) NSString *footer; // nil by default
@property (nonatomic, assign) id<RCSourcesSheetDelegate> delegate;
+ (UINavigationController *)navigationControllerWithSources:(NSArray *)sources delegate:(id<RCSourcesSheetDelegate>)delegate;
@end
