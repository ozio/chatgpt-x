#import <UIKit/UIKit.h>
#import "../OR6APISessionProvider.h"
#import "OR6API8Media.h"
@class OR6WebLoginController;
@interface OR6API8AuthHost:NSObject<OR6APIInteractionHost>
- (id)initWithPresenter:(UIViewController*)presenter;
- (void)sessionChanged;
@end
// iOS 6 Open In / Inbox list ("document" source). The screen is the app's (its UI
// kit, OR6L strings, empty state), found at run time by class name so this module
// links no UI kit. Without it the document source is unavailable rather than shown
// as an unthemed list. files: [{name, bytes}] (names inside Inbox only); chosen(nil)
// cancels; a name outside the list is ignored.
#define OR6API8InboxScreenClassName @"OR6Chat8InboxController"
@protocol OR6API8InboxScreen <NSObject>
+ (UIViewController *)inboxScreenWithFiles:(NSArray *)files chosen:(void (^)(NSString *name))chosen;
@end
@interface OR6API8Picker:NSObject<OR6API8Acquisition>
- (id)initWithPresenter:(UIViewController*)presenter inbox:(NSString*)inbox;
// Set once after the app's Core/root are composed. The host owns the presenter.
- (void)setPresenter:(UIViewController*)presenter;
@end
