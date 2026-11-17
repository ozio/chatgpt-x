// RCRefreshControl — native iOS 6 pull-to-refresh, themed for a linen list.
// States: idle / refreshing / enabled=NO during a local mutation. The app owns
// all reads and ends refreshing; UIControlEventValueChanged reports one pull.
#import <UIKit/UIKit.h>
@interface RCRefreshControl : UIRefreshControl
// iOS 6 requires the native UITableViewController owner; addSubview alone does
// not wire the gesture. Attaches a child controller once, preserving the app's
// table, delegate/dataSource and placement. The parent owns the child.
- (void)attachToTableView:(UITableView*)table inViewController:(UIViewController*)parent;
@end
