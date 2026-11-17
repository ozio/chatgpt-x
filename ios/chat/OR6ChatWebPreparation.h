#import <UIKit/UIKit.h>
#import "OR6ChatPreparation.h"
// Existing real-document WebPort implementation. No stock-engine fallback is
// selected by the production composition; research is a separate executable.
@interface OR6ChatWebPreparation:NSObject<OR6ChatPreparation,UIWebViewDelegate>
- (id)initWithHostView:(UIView*)host;
@end
