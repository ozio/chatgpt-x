#import "OR6CodexAPI.h"

// Trusted in-process session authority, called only on the main thread. Returns
// nil when signed out/unvalidated; otherwise exactly {context,userId,accessToken,
// expiresAt}. Context has the same four keys as OR6CodexAPI; connection MUST be
// "codex-cloud". The owner must already be validated by the existing ChatGPT
// session. Rotate credentialGeneration and recreate this API on any auth change.
// Never supply these values through perform parameters or a phone-facing bridge.
// The source must be cheap and side-effect free: it never signs in or refreshes.
typedef NSDictionary*(^OR6CodexCloudCredentialSource)(void);

@protocol OR6CodexCloudIO<OR6CodexTransport>
// Trusted transport injection for offline fixtures; paths come only from the
// hosted adapter. Production always uses the fixed HTTPS origin below.
- (id<OR6APITask>)readPath:(NSString*)path completion:(OR6APIReply)completion;
@end

// Main-thread lifetime and calls, matching OR6CodexAPI. Retain returned tasks
// only for cancellation; explicitly deactivate before discarding the owner.
@interface OR6CodexCloud:NSObject {
 id _binding;
 id<OR6CodexCloudIO> _wire;
 OR6CodexSession *_session;
 OR6CodexProvider *_provider;
 NSMutableDictionary *_catalog,*_cursors,*_selections;
 NSMutableSet *_active;
 NSString *_catalogRevision;
 id _catalogCall;
 BOOL _deactivated,_catalogBusy;
}
- (id)initWithCredentials:(OR6CodexCloudCredentialSource)credentials roots:(NSString*)CAFile contracts:(NSDictionary*)contracts privateDirectory:(NSString*)directory error:(NSError**)error;
- (id)initWithIO:(id<OR6CodexCloudIO>)IO credentials:(OR6CodexCloudCredentialSource)credentials contracts:(NSDictionary*)contracts privateDirectory:(NSString*)directory error:(NSError**)error;
- (id<OR6APITask>)perform:(NSString*)operation parameters:(NSDictionary*)parameters event:(OR6APIEvent)event completion:(OR6APIReply)completion;
- (BOOL)matchesContext:(NSDictionary*)context;
- (void)deactivate;
@end
