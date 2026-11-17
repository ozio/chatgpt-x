#import "OR6API7BNetwork.h"
@interface OR6API7BProvider : NSObject <OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP extension:(NSDictionary *)extension journalDirectory:(NSString *)directory capabilities:(NSSet *)capabilities error:(NSError **)error;
// Trusted composition host only: policy from actual account/workspace checks.
// {eligible:bool,historyEligible:bool}; exact owner/workspace/generation binding.
// No policy means memory writes are unavailable. Never pass editable UI flags.
- (BOOL)bindMemoryPolicy:(NSDictionary *)policy context:(NSDictionary *)context;
- (void)deactivate;
- (NSDictionary *)diagnostics;
@end
