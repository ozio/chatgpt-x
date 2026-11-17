#import "OR6CodexProvider.h"
#import "OR6CodexTransport.h"
// Standalone API composition, deliberately not installed in ChatGPT's provider
// chain or UI. Main-thread lifetime and calls; retain tasks only for cancellation.
// Context is trusted, exact {owner: ChatGPT login email, workspace: account ID,
// connection: opaque configured host ID, credentialGeneration: positive integer}.
// Loading credentials and rotating/recreating this object belong to the trusted
// account/connection owner. Deactivation permanently fences this instance.
@interface OR6CodexAPI:NSObject {
 OR6CodexProvider *_provider;
 NSDictionary *_context;
}
- (id)initWithTransport:(id<OR6CodexTransport>)transport contracts:(NSDictionary*)contracts context:(NSDictionary*)context privateDirectory:(NSString*)directory error:(NSError**)error;
- (id)initWithURL:(NSURL*)URL capabilityToken:(NSString*)token roots:(NSString*)roots contracts:(NSDictionary*)contracts context:(NSDictionary*)context privateDirectory:(NSString*)directory error:(NSError**)error;
- (id<OR6APITask>)perform:(NSString*)operation parameters:(NSDictionary*)parameters event:(OR6APIEvent)event completion:(OR6APIReply)completion;
- (BOOL)matchesContext:(NSDictionary*)context;
- (void)deactivate;
@end
