#import <UIKit/UIKit.h>
#import "../api/OR6APICore.h"
@class OR6ChatConversationController,OR6Chat8Catalog;
// Implemented by OR6ChatRootController (drawer, new chat, sign-in, account).
@protocol OR6ChatConversationHost <NSObject>
- (void)conversationRequestsNewChat:(OR6ChatConversationController *)controller;
- (void)conversationRequestsSignIn:(OR6ChatConversationController *)controller;
- (void)conversationDidChange:(OR6ChatConversationController *)controller; // identifier/title/busy changed
@optional
- (id)conversationNavigator;                                   // API 7/10 navigation (OR6Chat7Navigator)
- (NSDictionary *)conversationInfo:(NSString *)identifier;     // history row + pin state {currentNode, archived, pinned}
@end
@interface OR6ChatConversationController:UIViewController
- (id)initWithCore:(OR6APICore*)core conversationId:(NSString*)identifier;
@property(nonatomic,assign)id<OR6ChatConversationHost> host;
@property(nonatomic,copy)NSString *conversationTitle; // from history; nil for a new chat
@property(nonatomic,readonly)NSString *conversationId;
@property(nonatomic,retain)OR6Chat8Catalog *catalog; // shared models.list/models.select state (stage 8), set by the root
@property(nonatomic,readonly)BOOL temporary;         // temporary chat: never read back from history
- (void)prepareForBackground;
- (void)applySessionReady:(BOOL)ready;
- (void)applySessionSummary:(NSDictionary*)summary;
// Interrupted ordinary send (snapshot from the host; schema in OR6ChatConversationState).
- (BOOL)matchesRecoverySnapshot:(NSDictionary*)snapshot;  // same operation as this screen's send
- (BOOL)restoreRecoverySnapshot:(NSDictionary*)snapshot;  // only into an empty screen: question + partial answer
- (BOOL)resumeRecoverySnapshot:(NSDictionary*)snapshot;   // once per activation: history check (messages.reconcile), never a new Send
- (BOOL)setDictationLimitMS:(NSUInteger)milliseconds; // development acceptance only
// API 7/10
- (void)setProject:(NSDictionary*)project;  // new chat in a project (projects.newDraft / projects.send)
- (void)setGPT:(NSDictionary*)gpt;          // stage 6: new chat with a GPT (gpts.send for its messages)
- (BOOL)attachLibraryDraft:(NSDictionary*)draft item:(NSDictionary*)item; // library.attach Draft of this chat's draft
- (NSString*)chat7DraftId;
- (void)composeRouteText:(NSString*)text;
- (void)invalidateAPI7;                      // owner/credential context change (host)   // never sent; an existing draft is kept
- (NSDictionary*)diagnostics;
#ifdef OR6_CHAT_ACCEPTANCE
- (NSDictionary*)acceptanceAction:(NSDictionary*)action; // development acceptance only
- (BOOL)acceptanceInject:(NSDictionary*)conversation;  // synthetic conversation, no network
#endif
@end
