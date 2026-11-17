#import <UIKit/UIKit.h>
#import "../../api/OR6APICore.h"
// Native selectable text. Only explicit Copy writes to the system clipboard.
@interface OR6Chat9MessageController:UIViewController
- (id)initWithCore:(OR6APICore *)core message:(NSDictionary *)message;
- (id)initWithCore:(OR6APICore *)core message:(NSDictionary *)message block:(NSDictionary *)block;
@end
NSAttributedString *OR6Chat9AttributedBlock(NSDictionary *block,CGFloat fontSize);
void OR6Chat9ApplyControlAccessibility(UIView *view,NSString *label,NSString *hint,BOOL enabled);
