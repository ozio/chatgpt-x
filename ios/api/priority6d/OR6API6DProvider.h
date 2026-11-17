#import "OR6API6DNetwork.h"
@protocol OR6API6DLocationCache <NSObject>
// Clears only the current account's cached precise location. No GPS acquisition.
- (BOOL)clearPreciseLocationForContext:(NSDictionary*)context error:(NSError**)error;
@end
@interface OR6API6DProvider:NSObject<OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP extension:(NSDictionary*)extension journalDirectory:(NSString*)directory capabilities:(NSSet*)capabilities error:(NSError**)error;
- (BOOL)bindIdentity:(NSDictionary*)identity context:(NSDictionary*)context;
// Optional booleans webSearch/imageCreation/location/automaticMemoryManagement;
// missing eligibility denies the associated setting write.
- (BOOL)bindPreferencesPolicy:(NSDictionary*)policy context:(NSDictionary*)context;
- (BOOL)bindLocationCache:(id<OR6API6DLocationCache>)cache context:(NSDictionary*)context;
// Private host data: headers, purpose, userId, recentAuthentication,
// contactConfirmed, expiresAt. Bound to exactly one lowercase operation UUID.
- (BOOL)bindAccountAuthorization:(NSDictionary*)authorization operationId:(NSString*)operationId command:(NSString*)command context:(NSDictionary*)context;
- (void)deactivate;
- (NSDictionary*)diagnostics;
@end
