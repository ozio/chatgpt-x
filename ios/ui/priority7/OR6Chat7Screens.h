// UIKit glue for the API 7/10 inventory, built only from the ChatGPT X kit
// (RCFormViewController, RCGridViewController, RCShareLinkSheet, RCReportViewController,
// RCPlaybackView, RCHUD, stock UIActionSheet/UIAlertView). Every action goes through the
// Foundation models in OR6Chat7Models. Read results of candidate (unverified) routes are
// labelled; writes appear only when their operation is live_verified; browser handoffs say
// that nothing is completed in ChatGPT X.
#import <UIKit/UIKit.h>
#import "OR6Chat7Models.h"

// Implemented by OR6ChatRootController: navigation that only the window root can do.
@protocol OR6Chat7Navigator <NSObject>
- (void)chat7OpenConversation:(NSString *)identifier title:(NSString *)title;          // existing history.get path
- (void)chat7Conversation:(NSString *)identifier changed:(NSString *)change;            // renamed|pinned|archived|unarchived|deleted|moved
- (BOOL)chat7AttachLibraryDraft:(NSDictionary *)draft item:(NSDictionary *)item;       // library.attach Draft → current composer
- (NSString *)chat7CurrentDraftId;                                                      // the open chat's prepared draft, or nil
- (void)chat7ComposeText:(NSString *)text;                                              // route compose?text=…: into the field, never sent
- (void)chat7OpenProject:(NSString *)projectId;
- (void)chat7NewChatInProject:(NSDictionary *)project;                                  // projects.newDraft/send path
- (void)chat7ShowHome;                                                                   // route home: back to the open chat (draft kept), never a new chat
- (void)chat7RouteToConversation:(NSString *)identifier;                                // route conversation: refused while the open chat has an unsent draft/files
@optional
- (void)chat6NewChatWithGPT:(NSDictionary *)gpt;                                        // stage 6: a new chat whose messages go to this GPT (gpts.send)
- (void)chat6OpenLibraryItem:(NSString *)libraryItemId;                                  // stage 6: a file found by the global search
@end

#ifdef __cplusplus
extern "C" {
#endif
// «Аккаунт» rows at stage 7: [{key,title,glyph,tile(NSNumber)}] for screens whose reads (or local work) are callable.
NSArray *OR6Chat7AccountEntries(OR6APICore *core);
UIViewController *OR6Chat7CreateAccountScreen(OR6APICore *core, NSString *key);
// Drawer collections (stage 7, reads callable).
BOOL OR6Chat7LibraryAvailable(OR6APICore *core);
BOOL OR6Chat7ArchiveAvailable(OR6APICore *core);
BOOL OR6Chat7ProjectsAvailable(OR6APICore *core);
UIViewController *OR6Chat7CreateLibrary(OR6APICore *core, id<OR6Chat7Navigator> navigator);
UIViewController *OR6Chat7CreateConversationFiles(OR6APICore *core, NSString *conversationId, id<OR6Chat7Navigator> navigator);
UIViewController *OR6Chat7CreateArchive(OR6APICore *core, id<OR6Chat7Navigator> navigator);
UIViewController *OR6Chat7CreateProjects(OR6APICore *core, id<OR6Chat7Navigator> navigator);
UIViewController *OR6Chat7CreateProject(OR6APICore *core, NSString *projectId, id<OR6Chat7Navigator> navigator);
// Projects seen through a validated projects.get in this session (memory only; cleared on sign-out).
void OR6Chat7RememberProject(NSDictionary *project);
NSArray *OR6Chat7RecentProjects(void);
void OR6Chat7ForgetSession(void);   // sign-out / owner change: projects, unresolved writes
// Read-only snapshot of a shared link (shares.get).
BOOL OR6Chat7SharedViewAvailable(OR6APICore *core);
UIViewController *OR6Chat7CreateSharedView(OR6APICore *core, NSString *shareId);
NSString *OR6Chat7ShareIdFromURL(NSURL *url);       // https://chatgpt.com/share/<uuid> (or /share/e/<uuid>) → id, else nil
// Chat row/title actions: rename, pin, archive, delete, share link, move to project, files,
// pending questions/actions. conversation: {id,title,pinned?,archived?,currentNode?}. Nil when none is available.
NSArray *OR6Chat7ConversationActions(OR6APICore *core, NSDictionary *conversation);
void OR6Chat7RunConversationAction(UIViewController *host, OR6APICore *core, NSString *action, NSDictionary *conversation, id<OR6Chat7Navigator> navigator);
NSDictionary *OR6Chat7SharePresentationDiagnostics(void); // the last Share sheet presentation: class names, booleans, integers only
// Browser entry page (E handoff): explains, asks, then opens Safari; completed:false is shown as such.
void OR6Chat7OpenHandoff(UIViewController *host, OR6APICore *core, NSString *operation);
// Trusted policies the composition really bound ("memory", "training"); none in this build.
void OR6Chat7SetPolicies(NSSet *policies);
// One remote write with the stock flow: «Saving…» HUD, done HUD (or «not read back yet»), an
// unknown result asks «Check» (read-only reconcile, never a resend), failures as a text HUD.
// intent: the unresolved latch key (refused while unresolved). NO: nothing was sent.
BOOL OR6Chat7RunWrite(UIView *view, OR6APICore *core, NSString *operation, NSDictionary *parameters, NSString *intent, NSString *reconcile, NSString *doneText, void (^finished)(NSDictionary *receipt));
// The same with the operation ID the trusted host bound private data to (PIN, account authorization).
BOOL OR6Chat7RunWriteWithId(UIView *view, OR6APICore *core, NSString *operation, NSDictionary *parameters, NSString *intent, NSString *reconcile, NSString *doneText, NSString *operationId, void (^finished)(NSDictionary *receipt));
// Shared texts.
NSString *OR6Chat7WriteClosedNote(void);
BOOL OR6Chat7Retryable(NSError *error); // an error after which a new explicit read may be offered (not a stop signal)
#ifdef __cplusplus
}
#endif

