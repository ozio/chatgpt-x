#import "OR6CodexPair.h"
// Payload-free diagnostics only: fixed stages/reasons, HTTP status and the
// transport's numeric error. Never retain callback URLs, codes, tokens,
// error_description, response bodies or arbitrary server text.
NSDictionary *OR6CodexPairOAuthSafeDiagnostic(id value);
NSError *OR6CodexPairOAuthFailure(NSString *code,BOOL possible,NSString *stage,NSDictionary *details);
@interface OR6CodexPairOAuth : NSObject {
    NSString *_state,*_verifier,*_workspace; NSTimeInterval _created; BOOL _consumed;
}
- (id)initWithWorkspace:(NSString *)workspace;
- (NSURL *)URL;
// Callback is intercepted by the app before localhost navigation. One-shot;
// random state + PKCE. No socket listener, session replacement or token logging.
- (NSDictionary *)consume:(NSURL *)URL error:(NSError **)error;
@end
