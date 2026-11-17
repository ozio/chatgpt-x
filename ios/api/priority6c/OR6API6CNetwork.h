#import "../priority7/OR6API7Network.h"
@interface OR6API6CNetwork:NSObject<OR6API7HTTP>{OR6APIWebAdapter*_adapter;NSString*_roots;NSDictionary*_policyContext,*_observedPolicy;NSUInteger _policyCredentialGeneration;NSTimeInterval _policyAt;}
- (id)initWithAdapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots;
// Source registration-country flag observed privately from settings/user.
// Unknown is omitted; absence never grants permission.
- (NSDictionary*)trustedAutoContextPolicyForContext:(NSDictionary*)context;
@end
