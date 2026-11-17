#import "../OR6APICore.h"
@class OR6Files;
// No app UI is constructed. Platform work uses a trusted native host adapter;
// share preparation returns an opaque token, never a private file URL in JSON.
@protocol OR6API7GPlatform <NSObject>
- (NSDictionary*)playback:(NSString*)action assetURL:(NSURL*)URL assetId:(NSString*)assetId rate:(NSNumber*)rate error:(NSError**)error;
- (id<OR6APITask>)saveImages:(NSArray*)URLs completion:(OR6APIReply)completion;
- (void)suspend;
@optional
- (BOOL)holdsPlayback; // suspend keeps the current player (app background)
@end
@protocol OR6API7GStreaming <NSObject>
- (id<OR6APITask>)start:(NSDictionary*)parameters context:(NSDictionary*)context event:(OR6APIEvent)event completion:(OR6APIReply)completion;
- (BOOL)stop:(NSError**)error;
- (void)cancel;
@end
NSDictionary *OR6API7GRegistry(NSDictionary *base,NSDictionary *extension,NSError **error);
@interface OR6API7GProvider:NSObject<OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next extension:(NSDictionary*)extension directory:(NSString*)directory vault:(OR6Files*)vault platform:(id<OR6API7GPlatform>)platform streaming:(id<OR6API7GStreaming>)streaming error:(NSError**)error;
// Trusted host only: successful current-scope Media/Vault records. Core-validated
// assets.acquire/download/upload/status results also establish this binding.
- (BOOL)bindAssets:(NSArray*)assets context:(NSDictionary*)context;
// Trusted host only: token is one-use and expires after300 monotonic seconds.
- (NSArray*)takeExportURLs:(NSString*)token context:(NSDictionary*)context;
// Trusted in-process image preview only; exact owner/generation binding, bounded
// PNG/JPEG bytes. No file path or data is added to the Core/JSON registry.
- (NSData*)imagePreviewDataForAsset:(NSString*)assetId context:(NSDictionary*)context;
- (void)deactivate;
- (NSDictionary*)diagnostics;
@end
