#import "../priority7/OR6API7Network.h"
@interface OR6API6ANetwork:NSObject<OR6API7HTTP>{OR6APIWebAdapter *_adapter;NSString *_roots;}
- (id)initWithAdapter:(OR6APIWebAdapter *)adapter roots:(NSString *)roots;
// Private boolean proof only; bearer/JWT claims never leave this adapter.
- (BOOL)validatePasswordReauthenticationForAccount:(NSString *)account user:(NSString *)user context:(NSDictionary *)context issuedAt:(NSTimeInterval)issuedAt;
@end
