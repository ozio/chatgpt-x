#import "OR6API7ENetwork.h"
@interface OR6API7EProvider : NSObject <OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP extension:(NSDictionary *)extension journalDirectory:(NSString *)directory capabilities:(NSSet *)capabilities error:(NSError **)error;
// Trusted composition host: current account/workspace training entitlement, not UI flags.
- (BOOL)bindPrivacyPolicy:(NSDictionary *)policy context:(NSDictionary *)context;
- (void)deactivate;
- (NSDictionary *)diagnostics;
@end
