#import "OR6API5BNetwork.h"
@interface OR6API5BProvider:NSObject<OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP extension:(NSDictionary*)extension journalDirectory:(NSString*)directory capabilities:(NSSet*)capabilities error:(NSError**)error;
// Trusted composition only: exact authenticated account/user/workspace context.
- (BOOL)bindIdentity:(NSDictionary*)identity context:(NSDictionary*)context;
// Source eligibility comes from trusted account policy, never a public DTO.
- (BOOL)bindEligibility:(BOOL)eligible context:(NSDictionary*)context;
// Identity is {userId,accountId,workspaceId:string|null}.
// Source picker association observation. Payload retained privately, immutable
// per reference/context. Caller DTO receives only the opaque lower-case UUID.
- (BOOL)bindSource:(NSDictionary*)descriptor reference:(NSString*)reference context:(NSDictionary*)context;
- (void)deactivate;
- (NSDictionary*)diagnostics;
@end
