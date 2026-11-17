#import "../selected20/OR6Selected20.h"
@class OR6Rev67LocalProvider, OR6Files, OR6API8Media;
NSDictionary *OR6Rev67AllRegistry(NSDictionary *base,NSError **error);
NSDictionary *OR6Rev67AllTiers(void);
@interface OR6Rev67AllCore:OR6Selected20Core
@end
// Observes only Core-validated outcomes; public input cannot grant draft/asset
// ownership or mint completion notices. Forwards all earlier provider hooks.
@interface OR6Rev67AllObserver:NSObject<OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next local:(OR6Rev67LocalProvider *)local media:(OR6API8Media *)media vault:(OR6Files *)vault;
// Sink is the existing project provider, bound to the same trusted identity.
- (void)setProjectUploadBinder:(BOOL(^)(NSArray *files,NSDictionary *context))binder;
@end
