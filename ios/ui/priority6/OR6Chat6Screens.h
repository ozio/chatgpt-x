// Stage-6 screens (usefulness 6/10, support/priority6all/coverage.json and the exact 80-row
// map work/priority6-ui-complete-20261112/ui/coverage.json) built only from the ChatGPT X kit
// and placed where the approved prototype puts them (design/uxui, features.js):
//   drawer        «GPT», «Задачи», «Закрытые чаты»; the drawer search also finds projects, pages and files
//   account       «Устройства и сеансы», «Ответы», «Приложения», «Голос», «Модели»; Memory / Privacy rows
//   library       folders, favorites, trash, connected sources and «use in answers» (API6C)
//   projects      search, create, edit, instructions, delete (API6C)
//   conversation  branch, report, lock, saved responses, memory citations, research PDF, Work,
//                 mentions, GPT chats (OR6Chat6Conversation)
// Every operation goes through the composed OR6API6AllCore with the bundled admission tiers
// (ios/api/priority6all/admission.json). Reads run only on an explicit user action (opening a
// screen counts). A remote mutation runs only after the user's explicit choice/confirmation,
// with one stable operation ID; an unknown outcome offers only the read-only reconcile, never a
// resend. A slot whose operation is not granted is not shown at all (no disabled «coming soon»).
#import <UIKit/UIKit.h>
#import "../../api/OR6APICore.h"
#import "../priority7/OR6Chat7Screens.h"

// The coordinator (trusted composition host). Secrets, private authorization, account claims and
// file paths never travel through Core parameters; these calls carry only opaque IDs.
// work/priority6-ui-complete-20261112/ui/HOST-NEEDS.md has the exact contract of each method.
@protocol OR6Chat6TrustedHost <NSObject>
// One-use PIN binding for exactly one locked.pin.* operation ID: {pin} (verify),
// {pin, pin_confirmation} (create) or {current_pin, new_pin} (change).
- (BOOL)chat6BindLockedSecrets:(NSDictionary *)secrets operationId:(NSString *)operationId error:(NSError **)error;
- (void)chat6ClearLockedAccess; // drop the short server grant (leaving the screen, background)
@optional
// YES only when the host bound this trusted eligibility policy for the CURRENT Core context from
// actual account evidence (6D bindPreferencesPolicy / bindLocationCache, 6C bindAutoContextPolicy).
// policy: webSearch | imageCreation | location | automaticMemoryManagement | autoContext.
// NO / unimplemented: the setting is shown read-only (the provider would refuse the write anyway).
- (BOOL)chat6PolicyBound:(NSString *)policy;
// Root contract (work/priority6-ui-complete-20261112/ui/HOST-CONTRACT.md): right before a policy-bound
// setting write (preferences.setAutoWebSearch, preferences.setImageCreation,
// privacy.locationControls.update, memories.management.update, library.autoContext.update) the
// host binds the recently observed source policy for the current context. nil error: the policy
// is bound (no write happened yet); an error: the write is not attempted. The async form (one
// private owner-matched read for library auto-context) calls back once on main; the screen keeps
// and cancels its task. Use OR6Chat6Prepare (OR6Chat6Base.h), which picks the available form.
- (BOOL)chat6PrepareOperation:(NSString *)operation error:(NSError **)error;
- (id<OR6APITask>)chat6PrepareOperation:(NSString *)operation completion:(void (^)(NSError *error))completion;
// One-use private account authorization (6D bindAccountAuthorization) for exactly this operation ID
// and command (privacy.exportData | privacy.deleteAccount). NO with error code
// reauthentication_required when the host has no real recent authentication: the screen then offers
// the first-party page and never claims the operation was done.
- (BOOL)chat6BindAccountAuthorizationForOperation:(NSString *)operationId command:(NSString *)command error:(NSError **)error;
// PIN reset: authorization is the locked.pin.resetChallenge result {authorizationId, returnURL,
// browserRequired:true, completed:false}. The host opens the first-party reauthentication page and,
// when the exact return arrives, calls 6A acceptResetReturn for this authorizationId; completion
// (main thread, once) says whether the return was accepted. NO: nothing was opened.
- (BOOL)chat6BeginPINReset:(NSDictionary *)authorization completion:(void (^)(BOOL accepted, NSError *error))completion;
// research.exportPDF exportToken → one-use local file URLs for the system sheet (6F takeExportURLs).
- (NSArray *)chat6TakeExportURLs:(NSString *)token;
// Saved entities of one answer (6C bindSavedEntity done by the host from the actual history
// content): [{referenceId (UUID bound to the descriptor), title, category}]; nil/empty: none.
- (NSArray *)chat6SavedEntitiesForConversation:(NSString *)conversationId message:(NSString *)messageId;
// The voice session bound through 6F bindVoiceSession for this conversation, else nil.
- (NSString *)chat6VoiceSessionIdForConversation:(NSString *)conversationId;
// The scan draft staged through 6F stageScanPages for the open composer, else nil.
- (NSString *)chat6StagedScanDraftId;
@end

#ifdef __cplusplus
extern "C" {
#endif
void OR6Chat6SetTrustedHost(id<OR6Chat6TrustedHost> host); // not retained; nil when API6 is not composed
BOOL OR6Chat6On(OR6APICore *core, NSString *operation);      // a granted tier
BOOL OR6Chat6AllOn(OR6APICore *core, NSArray *operations);
// Drawer rows: [{key, title, glyph, identifier}] in prototype order, granted reads only.
NSArray *OR6Chat6DrawerEntries(OR6APICore *core);
BOOL OR6Chat6IsDrawerKey(id key);
UIViewController *OR6Chat6CreateDrawerScreen(OR6APICore *core, NSString *key, id<OR6Chat7Navigator> navigator);
// «Аккаунт» rows: [{key, title, glyph, tile}] like OR6Chat7AccountEntries.
NSArray *OR6Chat6AccountEntries(OR6APICore *core);
// Any stage-6 account/privacy/memory key (answers, devices, memories, apps_access, location, apps,
// apps_permissions, voice, models, export, delete_account, locked_settings); nil: not a stage-6 key.
UIViewController *OR6Chat6CreateAccountScreen(OR6APICore *core, NSString *key);
// Rows the API7 Memory / Privacy screens add: [{key, title, glyph?, identifier}] (granted reads only).
NSArray *OR6Chat6MemoryEntries(OR6APICore *core);
NSArray *OR6Chat6PrivacyEntries(OR6APICore *core);
// Library (API7 screen): stage-6 destinations [{key, title, glyph, identifier}] and their screens.
NSArray *OR6Chat6LibraryEntries(OR6APICore *core);
UIViewController *OR6Chat6CreateLibraryScreen(OR6APICore *core, NSString *key, id<OR6Chat7Navigator> navigator);
// Projects (API7 screens): create/edit/instructions/delete. Each returns nil when not granted.
BOOL OR6Chat6ProjectCreateAvailable(OR6APICore *core);
UIViewController *OR6Chat6CreateProjectEditor(OR6APICore *core, NSDictionary *project, void (^saved)(NSString *projectId));
// Project actions for the project screen title menu: [{key, title, destructive?}].
NSArray *OR6Chat6ProjectActions(OR6APICore *core, NSDictionary *project);
void OR6Chat6RunProjectAction(UIViewController *host, OR6APICore *core, NSString *key, NSDictionary *project, id<OR6Chat7Navigator> navigator, void (^changed)(NSString *change));
// «Войти»: the first-party browser pages of API6E (other sign-in methods, two-step verification).
// [{key, title, operation}] for the sign-in sheet; OR6Chat7OpenHandoff opens one after the tap.
NSArray *OR6Chat6SignInHandoffs(OR6APICore *core);
// Locked chats: open the screen in «lock this chat» mode (PIN, then locked.conversations.lock).
UIViewController *OR6Chat6CreateLockConversation(OR6APICore *core, NSString *conversationId, NSString *title, id<OR6Chat7Navigator> navigator);
#ifdef __cplusplus
}
#endif
