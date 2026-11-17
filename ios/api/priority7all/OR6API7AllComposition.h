#import "OR6API7AllCore.h"
#import "../priority7g/OR6API7GProvider.h"
#import "../priority7h/OR6API7HCapture.h"
#import "../priority7/OR6API7Network.h"
@class OR6APIWebAdapter,OR6API8Media,OR6Files;
@protocol OR6API8Generation;
// Production composition of the complete API7 inventory for the ordinary app:
//   Core → observer → G → E → D → F → C → B → 7 → next (API9 → API8 → Media → …)
// with C on the same Media instance and D/F on the API8 native generator.
//
// Capabilities are default-denied. `admission` (bundled priority7-admission.json)
// names every API7 operation with a tier; only candidate_read, handoff and
// live_verified (with an evidence record) are granted. A narrow allowlist also
// accepts source-backed user_action with explicit confirmation and provider guards.
// Tiers are evidence labels, not proof of service eligibility.
//
// Personal memory/text-training policies may be bound only by the fresh, identity-
// scoped preflight wrapper. Workspace/media-training availability is not inferred.
// Project workspace remains unresolved until the trusted host binds actual D identity.
#ifdef __cplusplus
extern "C" {
#endif
extern NSString *const OR6API7TierLocal,*const OR6API7TierRead,*const OR6API7TierHandoff,*const OR6API7TierVerified,*const OR6API7TierDenied,*const OR6API7TierUserAction;
// Remote mutation or generation (also library attach/detach and the project draft preflight).
BOOL OR6API7AllWrite(NSString *operation);
// Validated {operations:{op:tier}, granted:{module:NSSet}, streaming:BOOL}; nil + error on any
// unknown/missing operation, unknown tier, write in a read tier or live_verified without evidence.
NSDictionary *OR6API7AllAdmission(NSDictionary *manifest,NSDictionary *extensions,NSError **error);
#ifdef __cplusplus
}
#endif
@interface OR6API7AllComposition:NSObject
- (id)initWithBase:(NSDictionary*)base extensions:(NSDictionary*)extensions admission:(NSDictionary*)manifest
 adapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots next:(id<OR6APIProvider>)next media:(OR6API8Media*)media
 generation:(id<OR6API8Generation>)generation vault:(OR6Files*)vault directory:(NSString*)directory
 platform:(id<OR6API7GPlatform>)platform capture:(id<OR6API7HPCM>)capture error:(NSError**)error;
// Same composition with one injected private transport for every module (offline fixtures);
// nil selects the real per-module networks. The adapter still authorizes H streaming.
- (id)initWithBase:(NSDictionary*)base extensions:(NSDictionary*)extensions admission:(NSDictionary*)manifest
 adapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots next:(id<OR6APIProvider>)next media:(OR6API8Media*)media
 generation:(id<OR6API8Generation>)generation vault:(OR6Files*)vault directory:(NSString*)directory
 platform:(id<OR6API7GPlatform>)platform capture:(id<OR6API7HPCM>)capture transport:(id<OR6API7HTTP>)transport error:(NSError**)error;
@property(nonatomic,readonly)NSDictionary *registry;   // base + seven extensions
@property(nonatomic,readonly)id<OR6APIProvider> provider; // top of the chain, for OR6API7AllCore
@property(nonatomic,readonly)NSDictionary *tiers;      // every API7 operation (+ dictation.streaming) → tier
@property(nonatomic,readonly)NSString *preferencesPath; // G's private preferences.json (may not exist yet)
// Trusted host only: exact authenticated user/workspace and Core context.
// Unknown workspace must not be represented by an invented identifier.
// Trusted upload metadata from the owner-bound Media journal, never UI JSON.
// Private native preflight only; never call from public parameters or cached UI eligibility.
- (BOOL)bindMemoryPolicy:(NSDictionary*)policy context:(NSDictionary*)context;
- (BOOL)bindPrivacyPolicy:(NSDictionary*)policy context:(NSDictionary*)context;
- (BOOL)bindProjectUploadedFiles:(NSArray*)files context:(NSDictionary*)context;
- (BOOL)bindProjectIdentity:(NSDictionary*)identity context:(NSDictionary*)context;
// Interruption, background, logout, context change, teardown: cancels every API7
// call, suspends the player and closes the streaming recorder. Idempotent.
- (void)deactivate;
// Trusted host only: a one-use images.export share token → revalidated vault file URLs (exact current Core context).
- (NSArray*)exportURLsForToken:(NSString*)token;
- (NSData*)imagePreviewDataForAsset:(NSString*)assetId;
- (NSDictionary*)diagnostics;
@end
