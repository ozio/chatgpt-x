#import "../priority7/OR6API7Network.h"
@class OR6API6ANetwork;
@interface OR6API6AProvider:NSObject<OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP extension:(NSDictionary *)extension journalDirectory:(NSString *)directory capabilities:(NSSet *)capabilities error:(NSError **)error;
// Optional trusted monotonic clock injection for deterministic offline/lifecycle tests.
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP extension:(NSDictionary *)extension journalDirectory:(NSString *)directory capabilities:(NSSet *)capabilities clock:(NSTimeInterval (^)(void))clock error:(NSError **)error;
// Trusted, private native host boundary. Never send PINs or credentials through Core.
- (BOOL)bindIdentity:(NSDictionary *)identity context:(NSDictionary *)context;
- (BOOL)bindPINSecrets:(NSDictionary *)secrets operationId:(NSString *)identifier context:(NSDictionary *)context error:(NSError **)error;
// Called only after the browser completes force_challenge reauthentication.
// The concrete network privately checks current owner/account and fresh pwd_auth_time.
- (BOOL)acceptResetReturn:(NSString *)state authorizationId:(NSString *)authorizationId context:(NSDictionary *)context network:(OR6API6ANetwork *)network;
- (void)setForeground:(BOOL)foreground;
- (void)clearLockedAccess;
- (void)deactivate;
- (NSDictionary *)diagnostics;
@end
