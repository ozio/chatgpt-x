#import "OR6CodexSession.h"
#import "OR6CodexDiff.h"
// Explicit standalone Codex provider. The app's ChatGPT composition/UI is not
// modified. Trusted context must match exactly; no URL, credential or arbitrary
// RPC, shell command, policy escalation or hardware enrollment in parameters.
@interface OR6CodexProvider:NSObject<OR6APIProvider> {
 OR6CodexSession *_session;
 NSDictionary *_context;
 NSMutableSet *_active;
 BOOL _deactivated;
 NSMutableDictionary *_state7;
}
- (id)initWithSession:(OR6CodexSession*)session context:(NSDictionary*)context;
- (void)deactivate;
- (NSDictionary*)diagnostics;
@end
