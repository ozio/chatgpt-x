#import "OR6API6CNetwork.h"
@interface OR6API6CProvider:NSObject<OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP extension:(NSDictionary*)extension journalDirectory:(NSString*)directory capabilities:(NSSet*)capabilities error:(NSError**)error;
// Trusted session composition only, never editable request claims.
// {userId:string,workspaceId:string|null} bound to exact opaque context.
- (BOOL)bindIdentity:(NSDictionary*)identity context:(NSDictionary*)context;
// Source workspace permission and registration-country admission from trusted
// account host. {eligible:bool}; missing/false policy denies setting writes.
- (BOOL)bindAutoContextPolicy:(NSDictionary*)policy context:(NSDictionary*)context;
- (BOOL)hasAutoContextPolicyForContext:(NSDictionary*)context;
// Trusted source entity request {saved_target,display_data,origin?}; raw metadata
// stays private and is bound to the caller supplied UUID and exact session.
- (BOOL)bindSavedEntity:(NSDictionary*)descriptor reference:(NSString*)reference context:(NSDictionary*)context;
// Deactivation marshals to main; trusted bindings and normal ownership use main.
- (void)deactivate;
- (NSDictionary*)diagnostics;
@end
