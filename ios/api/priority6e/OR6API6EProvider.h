#import "../priority7/OR6API7Network.h"
@interface OR6API6EProvider:NSObject<OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP extension:(NSDictionary *)extension journalDirectory:(NSString *)directory capabilities:(NSSet *)capabilities error:(NSError **)error;
// Trusted native composition only: current authenticated account and owner.
- (BOOL)bindIdentity:(NSDictionary *)identity context:(NSDictionary *)context;
- (void)deactivate;
- (NSDictionary *)diagnostics;
@end
