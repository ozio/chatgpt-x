#import "OR6API6AllCore.h"
#import "../priority7/OR6API7Network.h"
@class OR6APIWebAdapter,OR6Files;
@protocol OR6API8Generation,OR6API7GPlatform;
// Validate exact operation coverage and evidence/interaction tiers before
// constructing any provider. Returns {tiers:{op:string}, granted:{module:NSSet}}.
NSDictionary *OR6API6AllAdmission(NSDictionary *manifest,NSDictionary *extensions,NSError **error);
// Foundation composition above the existing complete API7/API8/API9 provider.
// The host supplies an already composed earlier registry/provider. No product
// screen or service admission is inferred by constructing this chain.
@interface OR6API6AllComposition:NSObject
- (id)initWithBase:(NSDictionary*)base extensions:(NSDictionary*)extensions
 adapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots next:(id<OR6APIProvider>)next
 generation:(id<OR6API8Generation>)generation vault:(OR6Files*)vault inboxDirectory:(NSString*)inbox
 platform:(id<OR6API7GPlatform>)platform directory:(NSString*)directory
 capabilities:(NSDictionary*)capabilities transport:(id<OR6API7HTTP>)transport error:(NSError**)error;
@property(nonatomic,readonly)NSDictionary *registry;
@property(nonatomic,readonly)id<OR6APIProvider> provider;
// Trusted native host only: access typed binders on the corresponding provider.
// Identity, eligibility, recent-auth, scanner/runtime and private authorization
// observations are never manufactured from editable phone-facing parameters.
- (id<OR6APIProvider>)providerForModule:(NSString*)module;
// Concrete private networks for host-only proofs/observations; never passed to UI.
// With an injected test transport this returns that transport instead.
- (id<OR6API7HTTP>)networkForModule:(NSString*)module;
- (void)deactivate;
- (NSDictionary*)diagnostics;
@end
