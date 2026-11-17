#import "../OR6APICore.h"
#import "../priority7/OR6API7Network.h"
typedef BOOL(^OR6Rev67PersonalPolicyBinder)(NSDictionary *policy,NSDictionary *context);
// Source-recovered PERSONAL-account preflight for exactly three existing writes.
// Separate private AccountNetwork supplies authenticated account structure;
// existing B/E providers supply fresh setting DTOs and still own revision/locks,
// durable mutation journal, no-replay, dispatch receipts and readback.
@interface OR6Rev67PersonalPolicy:NSObject<OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP registry:(NSDictionary *)registry memoryBinder:(OR6Rev67PersonalPolicyBinder)memory privacyBinder:(OR6Rev67PersonalPolicyBinder)privacy;
- (BOOL)bindIdentity:(NSDictionary *)identity context:(NSDictionary *)context;
- (void)deactivate;
- (NSDictionary *)diagnostics;
@end
