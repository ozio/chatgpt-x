#import "../priority7/OR6API7Network.h"
@class OR6APIWebAdapter;
NSDictionary *OR6Rev5SystemRegistry(NSDictionary *base,NSError **error);
NSDictionary *OR6Rev5SystemTiers(void);
BOOL OR6Rev5SystemMutation(NSString *operation);
NSURLRequest *OR6Rev5SystemRequest(NSString *route,NSDictionary *identity,NSString *factorId);
BOOL OR6Rev5SystemAllowedRequest(NSURLRequest *request);
NSDictionary *OR6Rev5SystemPasskeys(id raw,NSError **error);
// Private native-token evidence only; never accepted as registry input. The
// original disable-factor flow requires millisecond pwd_auth_time <240s old
// plus https://api.openai.com/mfa.required == yes. Does not initiate reauth.
BOOL OR6Rev5SystemRecentToken(NSString *authorization,NSTimeInterval now);
BOOL OR6Rev5SystemTokenMatches(NSString *authorization,NSDictionary *identity);
@interface OR6Rev5SystemNetwork:NSObject<OR6API7HTTP>{OR6APIWebAdapter *_adapter;NSString *_roots;}
- (id)initWithAdapter:(OR6APIWebAdapter *)adapter roots:(NSString *)roots;
@end
@interface OR6Rev5SystemProvider:NSObject<OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP registry:(NSDictionary *)registry journalDirectory:(NSString *)directory error:(NSError **)error;
- (BOOL)bindIdentity:(NSDictionary *)identity context:(NSDictionary *)context;
- (void)deactivate;
- (NSDictionary *)diagnostics;
@end
