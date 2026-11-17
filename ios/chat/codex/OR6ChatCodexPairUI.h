#import "OR6ChatCodexScreens.h"
#import "OR6ChatCodexPairPayload.h"
// Public code data only. The scanner never opens the decoded URL or sends it.
UIViewController *OR6ChatCodexPairScreen(id<OR6ChatCodexBackend>backend,NSString *code,BOOL scan);
UIViewController *OR6ChatCodexPairScanner(void(^done)(NSString *code));
UIViewController *OR6ChatCodexPairAuthorization(id<OR6ChatCodexBackend>backend,NSURL *URL,void(^done)(BOOL authorized));
NSString *OR6ChatCodexPairAuthorizationFailureText(NSDictionary *diagnostic);
