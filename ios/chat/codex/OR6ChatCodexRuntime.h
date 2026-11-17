#import <Foundation/Foundation.h>
#import "../../api/OR6APICore.h"
@class OR6APIWebAdapter,OR6CodexConnections,OR6CodexCloud,OR6CodexPair,OR6CodexAPI;
extern NSString*const OR6ChatCodexChanged;
@protocol OR6ChatCodexBackend<NSObject>
- (id<OR6APITask>)perform:(NSString*)operation parameters:(NSDictionary*)parameters event:(OR6APIEvent)event completion:(OR6APIReply)completion;
- (NSUInteger)epoch;
- (BOOL)available;
- (NSString*)scopeID;
@end
// Trusted composition and Keychain owner, never passed raw session credentials
// by a screen. UI operations accept public host fields and opaque tokens only.
@interface OR6ChatCodexRuntime:NSObject<OR6ChatCodexBackend>{
 OR6APIWebAdapter *_adapter;NSDictionary *_contracts,*_context,*_lastOAuthError,*_oauthErrorContext;
 NSString *_directory,*_credentialService,*_selection,*_probeToken;NSDictionary *_probe,*_environment;
 OR6CodexConnections *_connections;OR6CodexCloud *_cloud;
 OR6CodexPair *_pair;OR6CodexAPI *_relay;
 NSMutableSet *_calls;NSUInteger _epoch;BOOL _suspended;
}
- (id)initWithAdapter:(OR6APIWebAdapter*)adapter contracts:(NSDictionary*)contracts directory:(NSString*)directory;
- (void)updateIdentity;
- (void)suspend;
- (NSDictionary*)diagnostics;
@end
