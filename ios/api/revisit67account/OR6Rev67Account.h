#import "../priority7/OR6API7Network.h"
// Scoped billing adaptation only. No StoreKit restore, charge, cancel, auth or push registration.
NSDictionary *OR6Rev67AccountRegistry(NSDictionary *base, NSError **error);
NSDictionary *OR6Rev67AccountTiers(void);
NSURLRequest *OR6Rev67AccountRequest(NSString *route, NSDictionary *identity);
BOOL OR6Rev67AccountAllowedRequest(NSURLRequest *request);
NSDictionary *OR6Rev67AccountDecodeAccount(id raw, NSString *accountId, NSError **error);
NSDictionary *OR6Rev67AccountDecodeSubscription(id raw, NSError **error);
NSDictionary *OR6Rev67AccountHandoff(NSString *operation, NSDictionary *account, NSDictionary *subscription, NSError **error);
@interface OR6Rev67AccountNetwork : NSObject <OR6API7HTTP> {
 OR6APIWebAdapter *_adapter; NSString *_roots;
}
- (id)initWithAdapter:(OR6APIWebAdapter *)adapter roots:(NSString *)roots;
@end
@interface OR6Rev67AccountProvider : NSObject <OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP registry:(NSDictionary *)registry;
// Trusted service-account identity; no owner or origin can be supplied by a public request.
- (BOOL)bindIdentity:(NSDictionary *)identity context:(NSDictionary *)context;
- (void)deactivate;
- (NSDictionary *)diagnostics;
@end
