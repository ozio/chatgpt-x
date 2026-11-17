#import <UIKit/UIKit.h>
#import "../OR6ChatPreparation.h"
@interface OR6ChatStockPreparation:NSObject<OR6ChatPreparation,UIWebViewDelegate>
- (id)initWithHostView:(UIView*)host roots:(NSString*)roots;
@end
