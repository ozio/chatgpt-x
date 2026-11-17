#import <UIKit/UIKit.h>
#import "OR6ChatRootController.h"
#import "../api/OR6APISessionProvider.h"
#import "../auth/OR6WebLoginController.h"
@class OR6RealtimeProvider;
@class OR6Selected20Provider,OR6ChatCodexRuntime,OR6Rev67LocalProvider,OR6Rev67ContentProvider,OR6Rev67AccountProvider,OR6Rev67PersonalPolicy;
@class OR6Rev5ASRProvider,OR6Rev5LocalProvider,OR6Rev5LocalDevice,OR6Rev5ContentProvider,OR6Rev5SystemProvider;
@class OR6Rev5Observer,OR6Rev5WorkspaceNetwork;
@class OR6API5AllComposition,OR6Rev5Host,OR6Rev5FamilyPolicy,OR6Rev5AccountAdapter;
@class OR6API7AllComposition,OR6API6AllComposition,OR6APIWebAdapter,OR6ChatNativeProvider,OR6API9Provider,OR6API8Provider,OR6API8Media,OR6API8Binding;
@interface OR6ChatCoordinator:NSObject<OR6ChatUIHost,OR6APISessionObserver,OR6WebLoginControllerDelegate>{
 OR6RealtimeProvider *_voice8;
 OR6ChatCodexRuntime *_codex;
 OR6Rev5ASRProvider *_rev5ASR;OR6Rev5LocalProvider *_rev5Local;OR6Rev5LocalDevice *_rev5Device;OR6Rev5ContentProvider *_rev5Content;OR6Rev5SystemProvider *_rev5System;
 OR6API5AllComposition *_api5;NSDictionary *_api5Tiers;OR6Rev5Host *_rev5Host;OR6Rev5FamilyPolicy *_rev5Family;OR6Rev5AccountAdapter *_api5Adapter;OR6Rev5Observer *_rev5Observer;OR6Rev5WorkspaceNetwork *_rev5Workspace;
 OR6Rev67LocalProvider *_rev67Local;OR6Rev67ContentProvider *_rev67Content;OR6Rev67AccountProvider *_rev67Account;OR6Rev67PersonalPolicy *_rev67Personal;
 OR6WebSession *_session;OR6APICore *_core;OR6APISessionProvider *_auth;
 OR6APIWebAdapter *_reads;OR6ChatNativeProvider *_web;OR6ChatRootController *_root;
 OR6WebLoginController *_login;UIView *_webHost;id _authHost;
 void(^_loginCompletion)(NSString*);NSTimer *_renewTimer,*_receiptTimer;NSDictionary *_receiptSnapshot;NSString *_interactionId;
 BOOL _started,_active,_closing,_recoveryChecked,_syncPending;NSUInteger _restores,_renews,_changes;NSString*_pendingConversation;
 OR6API9Provider *_priority9;
 OR6API8Provider *_priority8;OR6API8Media *_media8;OR6API8Binding *_binding8;
 OR6API7AllComposition *_api7;NSString *_api7Issue;
 OR6Selected20Provider *_selected20;id _playbackDevice;
 OR6API6AllComposition *_api6;NSString *_api6Issue;NSDictionary *_api6Tiers;
}
@property(nonatomic,readonly)OR6ChatRootController *root;
- (id)initWithWindow:(UIWindow*)window error:(NSError**)error;
- (void)start;
- (void)activate;
- (void)deactivate;
- (void)writeReceipt;
- (void)chatSignInWithProvider:(NSString*)provider;
- (BOOL)openConversationIdentifier:(NSString*)identifier;
- (BOOL)openRouteURL:(NSURL*)url; // API 7/10 app routes (routes.resolve), never sends
@end
