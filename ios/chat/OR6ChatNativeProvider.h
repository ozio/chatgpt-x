#import <UIKit/UIKit.h>
#import "../api/OR6APICore.h"
@class OR6APIWebAdapter;
@protocol OR6ChatPreparation;
// One real minimal WebPort document; native authenticated HTTPS and SSE.
@interface OR6ChatNativeProvider:NSObject<OR6APIProvider>
- (id)initWithAdapter:(OR6APIWebAdapter*)adapter hostView:(UIView*)view roots:(NSString*)roots;
- (id)initWithAdapter:(OR6APIWebAdapter*)adapter hostView:(UIView*)view roots:(NSString*)roots recoveryDirectory:(NSString*)directory;
- (id)initWithAdapter:(OR6APIWebAdapter*)adapter preparation:(id<OR6ChatPreparation>)preparation roots:(NSString*)roots recoveryDirectory:(NSString*)directory;
- (NSDictionary*)recoverySnapshotForConversation:(NSString*)identifier;
- (void)clearRecoveryForCurrentAccount;
// Trusted API composition only. Plan is inert, prevalidated request data;
// ordinary UI Send keeps its existing policy when this method is unused.
- (id<OR6APITask>)executeNativePlan:(NSDictionary*)plan context:(NSDictionary*)context event:(OR6APIEvent)event completion:(OR6APIReply)completion;
- (void)prepareConversation:(NSString*)identifier;
// Trusted composition: models.list shares the Core's read epoch, not the credential generation.
// Preparation itself remains bound to the adapter's credential generation.
- (void)setReadContextSource:(NSDictionary*(^)(void))source;
- (void)deactivate;
- (NSDictionary*)diagnostics;
@end
