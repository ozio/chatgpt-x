#import <UIKit/UIKit.h>
#import "../api/OR6APICore.h"
// Internal normal on-phone website adapter. No credentials enter public DTOs.
@interface OR6ChatWebProvider:NSObject<OR6APIProvider,UIWebViewDelegate>
- (id)initWithNext:(id<OR6APIProvider>)next hostView:(UIView*)view
 contextKey:(NSString*(^)(void))contextKey verifyWebOwner:(BOOL(^)(NSString*))verifyOwner;
// Explicit native navigation may load one page before the user presses Send.
- (void)prepareConversation:(NSString*)identifier;
- (void)deactivate;
- (NSDictionary*)diagnostics;
@end
