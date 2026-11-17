#import "../OR6APISessionProvider.h"
@class OR6APIWebAdapter;
// Foundation-only session/context synchronization, exercised without UIKit.
@interface OR6API8Binding:NSObject<OR6APISessionObserver>
- (id)initWithCore:(OR6APICore*)core adapter:(OR6APIWebAdapter*)adapter session:(OR6WebSession*)session
 invalidate:(void(^)(void))invalidate changed:(void(^)(void))changed;
- (void)stop;
@end
