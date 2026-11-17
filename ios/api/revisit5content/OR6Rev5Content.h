#import "../OR6APICore.h"
#import "../priority7/OR6API7Network.h"
@class OR6Files,OR6API8Media,OR6APIWebAdapter;
@protocol OR6API7GPlatform;
NSDictionary *OR6Rev5ContentRegistry(NSDictionary *base,NSError **error);
NSDictionary *OR6Rev5ContentTiers(void);
BOOL OR6Rev5ContentMutation(NSString *operation);
NSURLRequest *OR6Rev5ContentRequest(NSString *route,NSDictionary *parameters);
BOOL OR6Rev5ContentAllowedRequest(NSURLRequest *request);
// Normalized original service references, never caller-supplied renderer authority.
NSDictionary *OR6Rev5ContentMessage(id raw,NSString *conversation,NSString *message,NSError **error);
NSArray *OR6Rev5ContentPlaces(NSDictionary *message,NSError **error);
NSArray *OR6Rev5ContentProducts(NSDictionary *message,NSError **error);
NSArray *OR6Rev5ContentImages(NSDictionary *message,NSError **error);
NSArray *OR6Rev5ContentTemplates(id raw,NSError **error);
@interface OR6Rev5ContentNetwork:NSObject<OR6API7HTTP>
- (id)initWithAdapter:(OR6APIWebAdapter *)adapter roots:(NSString *)roots;
@end
@interface OR6Rev5ContentProvider:NSObject<OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP registry:(NSDictionary *)registry vault:(OR6Files *)vault media:(OR6API8Media *)media inboxDirectory:(NSString *)inbox playback:(id<OR6API7GPlatform>)playback journalDirectory:(NSString *)directory error:(NSError **)error;
- (BOOL)bindIdentity:(NSDictionary *)identity context:(NSDictionary *)context;
// Trusted host receives a frozen full original history only after authenticated
// current-context fetch and canonical branch validation. Never exposed via Core.
- (void)setHistoryObserver:(void(^)(NSDictionary *history,NSString *conversationId,NSDictionary *context))observer;
- (void)suspend;
- (void)deactivate;
- (NSDictionary *)diagnostics;
@end
