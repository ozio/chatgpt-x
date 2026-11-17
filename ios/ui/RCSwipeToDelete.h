// RCSwipeToDelete — the kit's own swipe-to-delete (kit.css .delete-btn, K.swipeDelete):
// a horizontal swipe on a row pops a glossy red «Удалить» button at the row's right
// edge (it grows from the right, .2 s); a tap elsewhere hides it, a tap on it asks
// the delegate to delete. Attach it to any UITableView — grouped settings rows or
// the dark-linen drawer — and do NOT implement -tableView:commitEditingStyle:… so
// the stock iOS 6 delete control never appears. VoiceOver cannot swipe: also offer
// deletion elsewhere (an action sheet or an edit mode).
#import <UIKit/UIKit.h>

// The red button alone (e.g. for an edit mode).
@interface RCDeleteButton : UIButton
+ (id)deleteButtonWithTitle:(NSString *)title; // sized to fit, 30 pt high
@end

@class RCSwipeToDelete;
@protocol RCSwipeToDeleteDelegate <NSObject>
- (void)swipeToDelete:(RCSwipeToDelete *)swipe deleteRowAtIndexPath:(NSIndexPath *)indexPath;
@optional
- (BOOL)swipeToDelete:(RCSwipeToDelete *)swipe canDeleteRowAtIndexPath:(NSIndexPath *)indexPath; // default YES
@end

@interface RCSwipeToDelete : NSObject <UIGestureRecognizerDelegate>
- (id)initWithTableView:(UITableView *)tableView; // installs gesture recognizers; table is not retained
@property (nonatomic, copy) NSString *title;      // «Удалить»
@property (nonatomic, assign) id<RCSwipeToDeleteDelegate> delegate;
@property (nonatomic, readonly) NSIndexPath *revealedIndexPath;
- (void)hideAnimated:(BOOL)animated;              // call before reloading the table
- (void)detach;                                   // removes the recognizers (call before the table goes away)
@end
