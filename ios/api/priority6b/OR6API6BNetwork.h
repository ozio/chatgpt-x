#import "../priority7/OR6API7Network.h"
@interface OR6API6BNetwork:NSObject<OR6API7HTTP>{OR6APIWebAdapter *_adapter;NSString *_roots;}
- (id)initWithAdapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots;
@end
