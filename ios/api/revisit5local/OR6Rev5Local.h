#import "../OR6APICore.h"
#import "../priority9/OR6API9Provider.h"
#import "../priority7g/OR6API7GProvider.h"
@class OR6Files,OR6API8Media;
NSDictionary *OR6Rev5LocalRegistry(NSDictionary *base,NSError **error);
NSDictionary *OR6Rev5LocalOperations(void);
NSDictionary *OR6Rev5LocalTiers(void);
BOOL OR6Rev5LocalMutation(NSString *operation);
// Native-only interface. Media callbacks carry bounded NSData, never a public
// path or library URL. EventKit write callbacks return their original local ID,
// even when readback fails; the provider durably retains that ID for reconcile.
@protocol OR6Rev5LocalPlatform <NSObject>
- (NSString *)authorizationForDomain:(NSString *)domain;
- (BOOL)consentForScope:(NSString *)scope domain:(NSString *)domain access:(NSString *)access;
- (BOOL)setConsent:(BOOL)granted scope:(NSString *)scope domain:(NSString *)domain access:(NSString *)access error:(NSError **)error;
- (id<OR6APITask>)perform:(NSString *)operation parameters:(NSDictionary *)parameters completion:(OR6APIReply)completion;
- (NSDictionary *)inspectVideo:(NSURL *)URL error:(NSError **)error;
- (NSDictionary *)video:(NSString *)command URL:(NSURL *)URL assetId:(NSString *)assetId position:(NSNumber *)position error:(NSError **)error;
- (void)stopVideo;
- (void)suspend;
@end
@interface OR6Rev5LocalProvider:NSObject<OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next registry:(NSDictionary *)registry vault:(OR6Files *)vault media:(OR6API8Media *)media inboxDirectory:(NSString *)inbox platform:(id<OR6Rev5LocalPlatform>)platform recorder:(id<OR6API9Recorder>)recorder playback:(id<OR6API7GPlatform>)playback journalDirectory:(NSString *)directory error:(NSError **)error;
- (BOOL)bindIdentity:(NSDictionary *)identity context:(NSDictionary *)context;
// Host-issued exact descriptors of current-owner loaded files only. An API
// asset ID, extension or MIME claim cannot establish that a file is a movie.
- (BOOL)bindAssets:(NSArray *)assets context:(NSDictionary *)context;
// Stop own video/capture before another feature starts shared audio. No shared
// recorder/player is stopped by suspend; only explicit video start stops audio.
- (void)stopVideo;
- (void)suspend;
- (void)deactivate;
- (NSDictionary *)diagnostics;
@end
