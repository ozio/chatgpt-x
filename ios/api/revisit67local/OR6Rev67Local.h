#import "../OR6APICore.h"
#import "../priority9/OR6API9Provider.h"
#import "../priority7g/OR6API7GProvider.h"
@class OR6Files,OR6API8Media;
NSDictionary *OR6Rev67LocalRegistry(NSDictionary *base,NSError **error);
NSDictionary *OR6Rev67LocalOperations(void);
NSDictionary *OR6Rev67LocalResponseSchema(NSString *op);
NSDictionary *OR6Rev67LocalTiers(void);
BOOL OR6Rev67LocalMutation(NSString *op);
// Native-only bytes/URLs; never represented in the public JSON interface.
@protocol OR6Rev67LocalPlatform <NSObject>
- (id<OR6APITask>)capturePage:(void(^)(NSData *,NSError *))completion;
- (id<OR6APITask>)locate:(OR6APIReply)completion;
- (NSData *)PDFForPages:(NSArray *)pages error:(NSError **)error; // {URL, crop:[x,y,w,h], rotation}
- (NSDictionary *)notificationPreferences:(NSString *)scope enabled:(NSNumber *)enabled error:(NSError **)error;
- (BOOL)scheduleNotice:(NSString *)identifier scope:(NSString *)scope title:(NSString *)title date:(NSDate *)date error:(NSError **)error;
- (void)cancelNotices:(NSString *)scope;
// Reconcile OS-persisted notices from prior launches; cancel only other Rev67 owners.
- (void)activateNotificationScope:(NSString *)scope;
- (void)suspend;
@end
@interface OR6Rev67LocalProvider : NSObject <OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next registry:(NSDictionary *)registry vault:(OR6Files *)vault inboxDirectory:(NSString *)inbox recorder:(id<OR6API9Recorder>)recorder playback:(id<OR6API7GPlatform>)playback platform:(id<OR6Rev67LocalPlatform>)platform;
// Trusted current Media chain; imports must register there before success.
- (void)setMedia:(OR6API8Media*)media;
- (BOOL)bindIdentity:(NSDictionary *)identity context:(NSDictionary *)context;
// Trusted current composer only. No draft can be supplied through public parameters.
- (BOOL)bindDraft:(NSString *)draftId context:(NSDictionary *)context;
// Only current-owner loaded media can become playable or scan page input.
- (BOOL)bindAssets:(NSArray *)assets context:(NSDictionary *)context;
// Minted only after host observes a completed response, never on Send or stream failure.
- (NSString *)bindCompletedResponse:(NSString *)responseId context:(NSDictionary *)context;
// Background teardown keeps staged pages/assets/notices for the same trusted owner.
- (void)suspend;
- (void)deactivate;
- (NSDictionary *)diagnostics;
@end
