// RCActivitySheet — the "+" sheet in the iOS 6 UIActivityViewController look
// (kit.css .actgrid): dark glass panel sliding up over a dim, 57 pt glossy tiles
// four per row, an "on" ring for an active mode, and a graphite Cancel button.
#import <UIKit/UIKit.h>
#import "RCGlyph.h"

@interface RCActivityItem : NSObject
+ (id)itemWithTitle:(NSString *)title glyph:(NSString *)glyph tile:(RCTileColor)tile;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *glyph;
@property (nonatomic, assign) RCTileColor tile;
@property (nonatomic, assign) BOOL on; // active mode (web search, image…) gets the ring
@end

@class RCActivitySheet;
@protocol RCActivitySheetDelegate <NSObject>
@optional
- (void)activitySheet:(RCActivitySheet *)sheet didSelectItemAtIndex:(NSUInteger)index; // after dismissal
- (void)activitySheetDidCancel:(RCActivitySheet *)sheet;
@end

@interface RCActivitySheet : UIView
- (id)initWithTitle:(NSString *)title items:(NSArray *)items;
@property (nonatomic, copy) NSString *cancelTitle; // "Отмена"
@property (nonatomic, assign) id<RCActivitySheetDelegate> delegate;
@property (nonatomic, readonly) NSArray *items;
- (void)showInView:(UIView *)view; // usually the window
- (void)dismiss;
@end
