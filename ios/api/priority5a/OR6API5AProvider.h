#import "../priority7/OR6API7Network.h"
@interface OR6API5AProvider:NSObject<OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP extension:(NSDictionary *)extension journalDirectory:(NSString *)directory capabilities:(NSSet *)capabilities error:(NSError **)error;
// Trusted native identity; never sourced from Core operation parameters.
- (BOOL)bindIdentity:(NSDictionary *)identity context:(NSDictionary *)context;
// Calpico account-user ID comes from trusted native messaging identity, not public parameters.
- (BOOL)bindMessagingIdentity:(NSString *)accountUserId context:(NSDictionary *)context;
// Native sharing boundary; never a Core response or durable journal field.
- (NSString *)bindInvitationURL:(NSString *)URL context:(NSDictionary *)context;
- (NSURL *)inviteURLForHandle:(NSString *)handle context:(NSDictionary *)context;
- (void)deactivate;
- (NSDictionary *)diagnostics;
@end
