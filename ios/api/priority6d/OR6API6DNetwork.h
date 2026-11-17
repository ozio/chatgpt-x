#import "../priority7/OR6API7Network.h"
@class OR6APIWebAdapter;
@interface OR6API6DNetwork : NSObject <OR6API7HTTP> { OR6APIWebAdapter *_adapter; NSString *_roots; NSDictionary *_policyContext; NSMutableDictionary *_observedPolicy; NSUInteger _policyCredentialGeneration; NSTimeInterval _policyAt; }
- (id)initWithAdapter:(OR6APIWebAdapter *)adapter roots:(NSString *)roots;
// Private host-only eligibility observations from successful authenticated reads.
// Contains booleans only, never custom instructions, account IDs or credentials.
// Exact Core context + credential generation and a five-minute monotonic TTL.
- (NSDictionary *)trustedPreferencesPolicyForContext:(NSDictionary *)context;
@end
