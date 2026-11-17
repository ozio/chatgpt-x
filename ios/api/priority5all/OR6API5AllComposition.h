#import "OR6API5AllCore.h"
#import "../priority7/OR6API7Network.h"
@class OR6APIWebAdapter;
// Native host composes this above its existing complete API6 provider/registry.
// Empty capabilities never imply service admission or account/policy binding.
@interface OR6API5AllComposition:NSObject
- (id)initWithBase:(NSDictionary*)base extensions:(NSDictionary*)extensions adapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots next:(id<OR6APIProvider>)next directory:(NSString*)directory capabilities:(NSDictionary*)capabilities transport:(id<OR6API7HTTP>)transport contentHosts:(NSSet*)contentHosts error:(NSError**)error;
// Native host may supply a workspace transition transport that rebinds the
// shared account namespace after the original exchange. Nil keeps prior behavior.
- (id)initWithBase:(NSDictionary*)base extensions:(NSDictionary*)extensions adapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots next:(id<OR6APIProvider>)next directory:(NSString*)directory capabilities:(NSDictionary*)capabilities transport:(id<OR6API7HTTP>)transport contentHosts:(NSSet*)contentHosts workspaceTransport:(id<OR6API7HTTP>)workspaceTransport error:(NSError**)error;
@property(nonatomic,readonly)NSDictionary *registry;
@property(nonatomic,readonly)id<OR6APIProvider> provider;
- (id<OR6APIProvider>)providerForModule:(NSString*)module;
- (void)deactivate;
- (NSDictionary*)diagnostics;
@end
