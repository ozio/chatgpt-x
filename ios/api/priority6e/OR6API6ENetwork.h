#import "../priority7/OR6API7Network.h"
// Private HTTP context adds accountId/userId to Core key/generation. No raw token API.
@interface OR6API6ENetwork:NSObject<OR6API7HTTP>{OR6APIWebAdapter *_adapter;NSString *_roots;}
- (id)initWithAdapter:(OR6APIWebAdapter *)adapter roots:(NSString *)roots;
@end
