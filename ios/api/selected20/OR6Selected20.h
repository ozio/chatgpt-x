#import "../priority6all/OR6API6AllCore.h"
#import "../priority7/OR6API7Network.h"
@class OR6APIWebAdapter, OR6Files;
@protocol OR6API7GPlatform;
// Selected additions only; all existing API6/7/8/9 contracts stay in the chain.
NSDictionary *OR6Selected20Registry(NSDictionary *base, NSDictionary *suggestions, NSDictionary *autocomplete, NSError **error);
NSDictionary *OR6Selected20Tiers(void);
BOOL OR6Selected20AllowedRequest(NSURLRequest *request);
@interface OR6Selected20Core : OR6API6AllCore
@end
// Private HTTP may return NSData in `data` for synthesize only. These bytes never cross Core.
@interface OR6Selected20Network : NSObject <OR6API7HTTP>
- (id)initWithAdapter:(OR6APIWebAdapter *)adapter roots:(NSString *)roots;
// Last transport failure (main thread): URL path only (no query), transport cause, bytes read, framing.
- (NSDictionary *)diagnostics;
@end
@interface OR6Selected20Provider : NSObject <OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP registry:(NSDictionary *)registry vault:(OR6Files *)vault inboxDirectory:(NSString *)inbox journalDirectory:(NSString *)journal platform:(id<OR6API7GPlatform>)platform;
// Trusted native identity, captured from serviceAccount; no editable public parameters.
- (BOOL)bindIdentity:(NSDictionary *)identity context:(NSDictionary *)context;
// Current-owner loaded image bytes only, same boundary as the conversation preview.
- (void)setImagePreviewResolver:(NSData *(^)(NSString *assetId))resolver;
// Also resolves a previously opened Library ID to its unchanged current-node cached asset.
- (NSData *)imagePreviewDataForAsset:(NSString *)assetId;
- (void)deactivate;
- (NSDictionary *)diagnostics;
@end
