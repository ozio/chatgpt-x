#import "../OR6APIWebAdapter.h"
#import "../priority5d/OR6API5DNetwork.h"
// Private native boundary. Preserves the existing owner's initial legacy journal
// namespace; any other authenticated account gets its own explicit account key.
@interface OR6Rev5Host:NSObject
- (id)initWithAdapter:(OR6APIWebAdapter*)adapter session:(OR6WebSession*)session directory:(NSString*)directory error:(NSError**)error;
- (BOOL)synchronizeAccountScope:(NSError**)error;
- (NSDictionary*)identity;
- (NSDictionary*)liveContext;
- (NSString*)messagingIdentity;
- (NSDictionary*)diagnostics;
@end
// Same authenticated account/context as the shared adapter, with the explicit
// account header required by family and Library endpoints. No token getter.
@interface OR6Rev5AccountAdapter:OR6APIWebAdapter
- (id)initWithBase:(OR6APIWebAdapter*)base session:(OR6WebSession*)session roots:(NSString*)roots;
@end
@interface OR6Rev5WorkspaceNetwork:OR6API5DNetwork
- (id)initWithAdapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots host:(OR6Rev5Host*)host;
- (void)setWorkspaceAllowed:(BOOL(^)(void))allowed;
- (void)setContextChanged:(void(^)(void))changed;
@end
