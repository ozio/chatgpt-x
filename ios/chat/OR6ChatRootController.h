#import <UIKit/UIKit.h>
#import "../api/OR6APICore.h"
@protocol OR6ChatUIHost <NSObject>
- (void)chatPrepareConversation:(NSString*)identifier;
- (void)chatSignIn;
- (void)chatRenew;
- (void)chatRestore;
- (void)chatSignOut;
@optional
- (BOOL)chatCodexAvailable;
- (UIViewController*)chatCodexController;
// Sign-in with the chosen provider ("email" or "google") through auth.begin on the
// ordinary service page; MFA codes are entered there. Without it: -chatSignIn.
- (void)chatSignInWithProvider:(NSString*)provider;
// Latest interrupted-send snapshot for this conversation (nil: latest overall), current account only.
- (NSDictionary*)chatRecoveryForConversation:(NSString*)identifier;
@end
// Window root: welcome screen while signed out; otherwise the kit's reveal
// container with the history drawer and the conversation navigation stack.
@interface OR6ChatRootController:UIViewController
- (id)initWithCore:(OR6APICore*)core host:(id<OR6ChatUIHost>)host;
- (void)applySessionSummary:(NSDictionary*)summary;
- (void)applyAccountProfile:(NSDictionary*)profile; // {name?, email?}; display only, never in receipts
- (void)showSessionError:(NSError*)error;
// auth.begin / auth.status / auth.cancel Interaction DTO from the host: shows the
// waiting, cancelled or failed login honestly; «Войти» stays for a new attempt.
- (void)applySignInInteraction:(NSDictionary*)interaction;
// Optional admission of API 8/10 UI features (support/priority8 keys); nil: every
// feature whose operations the composed Core registry has.
- (void)setPriority8Features:(NSSet*)features;
- (void)prepareForBackground;
// The Core owner/credential context changed (API8Binding): API7 helpers, editors, exports and pins of the old context end.
- (void)invalidateAPI7Context;
- (BOOL)openConversationIdentifier:(NSString*)identifier;
// chatgpt:/openai:/com.openai.chat:/codex: URL (stage 7, routes.resolve); waits for the session, never sends.
- (BOOL)openRouteURL:(NSURL*)url;
// Called by the host once per activation after an authenticated sync with the
// latest snapshot. Resumes the matching screen, or fills the initial blank one;
// never replaces an unrelated draft, conversation or running send.
- (BOOL)restoreRecoverySnapshot:(NSDictionary*)snapshot;
- (UINavigationController*)frontNavigationController; // the visible stack (acceptance, presenting)
- (BOOL)setDictationLimitMS:(NSUInteger)milliseconds;  // development acceptance only
- (NSDictionary*)diagnostics;
#ifdef OR6_CHAT_ACCEPTANCE
// Development acceptance only (not in ordinary builds): drive navigation for screenshots.
- (NSDictionary*)acceptanceAction:(NSString*)action value:(id)value;
#endif
@end
