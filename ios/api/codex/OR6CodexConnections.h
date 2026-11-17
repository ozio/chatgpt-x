#import "OR6CodexAPI.h"
#import "OR6CodexPrivateState.h"
typedef OR6CodexAPI*(^OR6CodexConnectionFactory)(NSDictionary*profile,NSDictionary*context,NSError**error);
// Factory is a trusted Keychain/transport owner. Profiles carry secret references
// only. Selection fences the previous API; no implicit login or connection probe.
@interface OR6CodexConnections:NSObject {
 OR6CodexPrivateState *_store;
 NSDictionary *_context;
 OR6CodexConnectionFactory _factory;
 OR6CodexAPI *_active;
 NSString *_selected;
 BOOL _deactivated;
}
- (id)initWithDirectory:(NSString*)directory accountContext:(NSDictionary*)context factory:(OR6CodexConnectionFactory)factory error:(NSError**)error;
// Stable owner/workspace profile storage may outlive a credential generation.
// Runtime accountContext still supplies the exact live generation to the factory.
- (id)initWithDirectory:(NSString*)directory accountContext:(NSDictionary*)context storageContext:(NSDictionary*)storageContext factory:(OR6CodexConnectionFactory)factory error:(NSError**)error;
- (NSArray*)list;
- (BOOL)upsert:(NSDictionary*)profile error:(NSError**)error;
- (BOOL)remove:(NSString*)identifier error:(NSError**)error;
- (BOOL)select:(NSString*)identifier error:(NSError**)error;
- (id<OR6APITask>)performActive:(NSString*)operation parameters:(NSDictionary*)parameters event:(OR6APIEvent)event completion:(OR6APIReply)completion;
- (void)deactivate;
@end
