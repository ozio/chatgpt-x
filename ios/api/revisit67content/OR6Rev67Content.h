#import "../priority7/OR6API7Network.h"
#import "../priority8/OR6API8Provider.h"
@class OR6API8Media, OR6Files, OR6APIWebAdapter;
NSDictionary *OR6Rev67ContentRegistry(NSDictionary *base,NSError **error);
NSDictionary *OR6Rev67ContentTiers(void);
BOOL OR6Rev67ContentMutation(NSString *operation);
// Exact private transport allowlist; raw SSE is normalized before returning.
BOOL OR6Rev67ContentLinkID(id value);
BOOL OR6Rev67ContentAllowedRequest(NSURLRequest *request);
NSURLRequest *OR6Rev67ContentRequest(NSString *action,NSDictionary *values,NSDictionary *identity,NSError **error);
NSDictionary *OR6Rev67ContentSummary(id raw,NSError **error);
NSDictionary *OR6Rev67ContentSSE(NSData *data,BOOL correction,NSError **error);
NSDictionary *OR6Rev67ContentSettings(id raw,NSError **error);
NSData *OR6Rev67ContentRender(NSData *source,NSDictionary *parameters,NSError **error);
@interface OR6Rev67ContentNetwork:NSObject<OR6API7HTTP>
- (id)initWithAdapter:(OR6APIWebAdapter *)adapter roots:(NSString *)roots;
@end
@protocol OR6Rev67MailPlatform <NSObject>
- (id<OR6APITask>)compose:(NSDictionary*)parameters completion:(OR6APIReply)reply;
@end
// Native system mail compose sheet; Send remains the user's final action.
@interface OR6Rev67ContentMail:NSObject<OR6Rev67MailPlatform>
- (id)initWithPresenter:(id)presenter;
@end
@interface OR6Rev67ContentProvider:NSObject<OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP registry:(NSDictionary *)registry media:(OR6API8Media *)media generation:(id<OR6API8Generation>)generation vault:(OR6Files *)vault inboxDirectory:(NSString *)inbox journalDirectory:(NSString *)journal error:(NSError **)error;
- (BOOL)bindIdentity:(NSDictionary *)identity context:(NSDictionary *)context;
// Browser host only: never expose authorization/callback URLs through public DTOs.
- (NSURL*)takeOAuthURLForToken:(NSString*)token context:(NSDictionary*)context;
- (BOOL)captureOAuthRedirect:(NSURL*)URL forToken:(NSString*)token context:(NSDictionary*)context error:(NSError**)error;
// Only an authenticated native renderer may issue these descriptors. A missing
// fresh authority resolver denies all RPCs; public JSON never grants authority.
- (NSString*)bindServiceAppBlockDescriptor:(NSDictionary*)descriptor context:(NSDictionary*)context error:(NSError**)error;
- (void)setAppBlockAuthorityResolver:(BOOL(^)(NSDictionary*descriptor,NSString*method,NSDictionary*params,NSDictionary*context))resolver;
- (void)setMailPresenter:(id)presenter; // non-retaining native UIViewController
- (void)setMailPlatform:(id<OR6Rev67MailPlatform>)platform;
- (void)setImagePreviewResolver:(NSData *(^)(NSString *assetId))resolver;
- (void)deactivate;
- (NSDictionary *)diagnostics;
@end
