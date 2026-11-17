#import "../priority7/OR6API7Network.h"
#import "../priority8/OR6API8Provider.h"
#import "../priority7g/OR6API7GProvider.h"
@class OR6Files;
NSDictionary *OR6API6FRegistry(NSDictionary *base,NSDictionary *extension,NSError **error);
BOOL OR6API6FMutation(NSString *operation);
@interface OR6API6FProvider:NSObject<OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP generation:(id<OR6API8Generation>)generation extension:(NSDictionary*)extension journalDirectory:(NSString*)directory vault:(OR6Files*)vault inboxDirectory:(NSString*)inbox platform:(id<OR6API7GPlatform>)platform capabilities:(NSSet*)capabilities error:(NSError**)error;
// Trusted existing runtime/capture boundaries, never public operation parameters.
// These methods accept no URLs/paths, credentials or editable account claims.
- (BOOL)bindVoiceSession:(NSString*)sessionId conversationId:(NSString*)conversationId context:(NSDictionary*)context error:(NSError**)error;
- (BOOL)applyVoiceEvent:(NSDictionary*)event sessionId:(NSString*)sessionId sequence:(NSUInteger)sequence context:(NSDictionary*)context error:(NSError**)error;
- (NSDictionary*)stageScanPages:(NSArray*)pages context:(NSDictionary*)context error:(NSError**)error;
// One-use host transfer relinquishes this provider's staged-page ownership.
- (NSArray*)takeScanPages:(NSString*)draftId context:(NSDictionary*)context error:(NSError**)error;
- (NSArray*)takeExportURLs:(NSString*)token context:(NSDictionary*)context;
- (void)deactivate;
- (NSDictionary*)diagnostics;
@end
