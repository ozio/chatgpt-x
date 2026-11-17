// Stage 6 inside one conversation screen (prototype s-chat.js answer «⋯», chat «⋯», «+» sheet).
// The conversation controller owns this helper next to OR6Chat7Conversation and calls it from the
// same hooks. Generations of stage 6 (GPT chat gpts.send, Work work.send, app mentions
// composer.mentions.send) run as send modes of the API7 helper, so streaming, Stop, the unknown-
// result banner and the read-only check are shared. Every other remote change here is one
// explicit user action with one operation ID and a read-only check after an unknown result:
//   answer «⋯»  branch (conversations.branch), save to Library / folder (library.response.*),
//               saved items (library.entity.*, host-bound only), memory used + feedback
//               (memories.citations/feedback/correctCitation), research PDF (research.exportPDF),
//               report (conversations.reportReasons/report)
//   chat «⋯»    lock (locked.*), report, voice conversation (host-bound session only)
//   «+»         Mention an app, Work
//   answer card Work handoff offer (work.handoff.get/accept/decline)
#import <UIKit/UIKit.h>
#import "../priority7/OR6Chat7Conversation.h"

@class OR6Chat8Catalog;
@interface OR6Chat6Conversation : NSObject
- (id)initWithCore:(OR6APICore *)core host:(id<OR6Chat7ConversationHost>)host api7:(OR6Chat7Conversation *)api7;
@property (nonatomic, retain) OR6Chat8Catalog *catalog; // the shared model catalog (Auto preference of a new chat)
- (void)addPlusItems:(NSMutableArray *)items actions:(NSMutableArray *)actions;
- (BOOL)handlePlusAction:(NSString *)action;          // NO: not a stage-6 action
- (void)setGPT:(NSDictionary *)gpt;                   // a new chat with this GPT (API6BGpt): gpts.send for its messages
@property (nonatomic, readonly) NSDictionary *gpt;
- (void)conversationLoaded;                           // history.get finished: GPT mode of a known GPT chat; one Work handoff read
- (void)newChatOpened;                                // empty new chat: the stored Auto preference (local read)
- (NSArray *)moreTitlesForRow:(NSDictionary *)row isLast:(BOOL)last;
- (BOOL)performMore:(NSString *)title row:(NSDictionary *)row;
- (void)configureAnswerRow:(NSDictionary *)row parts:(NSMutableArray *)parts isLast:(BOOL)last measuring:(BOOL)measuring;
- (NSString *)answerRevisionForRow:(NSDictionary *)row isLast:(BOOL)last; // row data that changes what -configureAnswerRow adds (nil: nothing)
// Staged scan pages of the composer (host-bound only): scanDraft.leave asks Keep / Discard first.
// YES: it asked (proceed runs after Discard); NO: nothing staged, the caller proceeds at once.
- (BOOL)confirmLeaving:(void (^)(void))proceed;
- (void)prepareForBackground;   // drops every late callback (life epoch)
- (void)detach;                 // controller teardown
- (NSDictionary *)diagnostics;  // flags and counts only
@end

#ifdef __cplusplus
extern "C" {
#endif
// Chat «⋯» / drawer long press: [{key, title, destructive?}] — lock, report, voice. conversation: {id, title}.
NSArray *OR6Chat6ConversationActions(OR6APICore *core, NSDictionary *conversation);
void OR6Chat6RunConversationAction(UIViewController *host, OR6APICore *core, NSString *key, NSDictionary *conversation, id<OR6Chat7Navigator> navigator);
// Owner change (sign-out): GPT chats of this session are forgotten.
void OR6Chat6ForgetSession(void);
#ifdef __cplusplus
}
#endif
