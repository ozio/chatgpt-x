#import "../OR6APICore.h"
#import "OR6API8Network.h"
@class OR6Files;
// Trusted remote attachment source. Handles are owner/draft-bound; this source
// never supplies bytes, file paths or credentials. The Media host outlives it.
@protocol OR6API8RemoteAssets <NSObject>
- (BOOL)canResolveRemoteAsset:(NSString*)identifier;
- (NSDictionary*)remoteAsset:(NSString*)identifier draft:(NSString*)draft context:(NSDictionary*)context error:(NSError**)error;
- (id<OR6APITask>)prepareRemoteAssets:(NSArray*)identifiers draft:(NSString*)draft context:(NSDictionary*)context completion:(OR6APIReply)completion;
- (void)releaseRemoteDraft:(NSString*)draft context:(NSDictionary*)context;
@end
@protocol OR6API8Acquisition <NSObject>
- (id<OR6APITask>)acquire:(NSString*)source selection:(NSString*)selection completion:(void(^)(NSURL*url,NSError*error))completion;
@optional
- (void)releaseSelectionURL:(NSURL*)url;
@end
@interface OR6API8Media:NSObject<OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next vault:(OR6Files*)vault inbox:(NSString*)inbox HTTP:(id<OR6API8HTTP>)HTTP picker:(id<OR6API8Acquisition>)picker journal:(NSString*)directory capabilities:(NSSet*)capabilities error:(NSError**)error;
- (NSArray*)attachments:(NSArray*)identifiers draft:(NSString*)draft context:(NSDictionary*)context error:(NSError**)error;
// Trusted host: bounded explicit processing-only recovery (at most two attempts) for an unavailable
// owner-scoped remote file. Never repeats metadata creation or byte upload.
- (id<OR6APITask>)resumeProcessingAsset:(NSString*)asset operation:(NSString*)operation context:(NSDictionary*)context completion:(OR6APIReply)reply;
// Trusted host only: current-owner local PNG/JPEG bytes, with length/hash checks.
- (NSData*)imagePreviewDataForAsset:(NSString*)identifier context:(NSDictionary*)context;
// Trusted native import only: validate the exact vault descriptor and bytes,
// then register a local asset for this already-current owner/generation. This
// does not upload or attach it. Public parameters cannot invoke this binding.
// Trusted Core/host context synchronization for operations intercepted above Media.
- (BOOL)bindContext:(NSDictionary*)context;
// Current-owner ready uploads only; exact metadata for the trusted project binder.
- (NSArray*)uploadedProjectFilesForContext:(NSDictionary*)context error:(NSError**)error;
- (NSDictionary*)adoptLocalAsset:(NSDictionary*)asset context:(NSDictionary*)context error:(NSError**)error;
// Trusted inpainting builder only. Purpose is immutable before upload; ordinary
// attachment parameters cannot mint this marker or upload the mask as a chat file.
- (BOOL)bindImageEditMaskAsset:(NSString*)assetId context:(NSDictionary*)context error:(NSError**)error;
- (NSDictionary*)imageEditMaskAsset:(NSString*)assetId context:(NSDictionary*)context error:(NSError**)error;
- (void)deactivate;
// Non-retaining to avoid a provider-chain cycle. Clear before source dealloc.
- (BOOL)setRemoteAssets:(id<OR6API8RemoteAssets>)source;
- (id<OR6API8RemoteAssets>)remoteAssets;
- (BOOL)needsRemotePreparation:(NSArray*)identifiers;
- (id<OR6APITask>)prepareRemoteAssets:(NSArray*)identifiers draft:(NSString*)draft context:(NSDictionary*)context completion:(OR6APIReply)completion;
@end
