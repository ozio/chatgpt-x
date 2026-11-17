// Foundation-only UI models for the API 7/10 inventory (support/priority7all/coverage.json).
// They run the real Core operations of the composed OR6API7AllCore with the exact DTOs
// of support/priority7*/contracts.json, keep immutable operation IDs, drop stale
// callbacks by epoch and never replay a write whose outcome is unknown. The UIKit
// screens (OR6Chat7Screens, OR6Chat7Conversation) only render what they report.
//
// Availability = the operation's admission tier (bundled
// priority7-admission.json, OR6API7AllComposition): local / candidate_read / handoff /
// user_action (stage 6: a source-backed write the user explicitly starts and confirms; not live
// evidence) / live_verified are callable, denied is not. candidate_read results are unverified
// service data and are labelled so; other writes are callable only when live_verified.
#import <Foundation/Foundation.h>
#import "../../api/OR6APICore.h"
#import "../priority8/OR6Chat8Models.h"

#ifdef __cplusplus
extern "C" {
#endif
// From the composition (nil: API7 is not composed, nothing of it is shown).
void OR6Chat7SetTiers(NSDictionary *tiers);
NSString *OR6Chat7Tier(NSString *operation);           // local | candidate_read | handoff | live_verified | denied | nil
BOOL OR6Chat7Callable(OR6APICore *core, NSString *operation); // composed AllCore and a granted tier (no stage check)
BOOL OR6Chat7On(OR6APICore *core, NSString *operation);       // callable
BOOL OR6Chat7AllOn(OR6APICore *core, NSArray *operations);
BOOL OR6Chat7Unverified(NSString *operation);          // candidate_read/handoff (inventory/diagnostics label; screens show plain states)
NSString *OR6Chat7OperationID(void);                   // new lowercase UUID
// Core context generation: changes with every owner/credential transition (setContextKey) and cancelAll.
NSUInteger OR6Chat7Generation(OR6APICore *core);
// Unknown-outcome writes, keyed by intent (e.g. "conversations.delete:<id>"): never sent
// again with a new operation ID; the owner change (sign-out) forgets them.
void OR6Chat7MarkUnresolved(NSString *key);
BOOL OR6Chat7IsUnresolved(NSString *key);
void OR6Chat7ForgetUnresolvedKey(NSString *key); // only after proof: confirmed completion or a proven unsent refusal
void OR6Chat7ForgetUnresolved(void);
// Honest one-line explanation of an API7 error (dispatch none/possible, stop signals).
NSString *OR6Chat7ErrorText(NSError *error);
// First API7 launch only: while the private G preference file does not exist, an explicit old app
// appearance (NSNumber 0 light / 1 dark, the app's own stored choice) is written through
// clientPreferences.theme. An existing G file is never overwritten; language is not migrated.
BOOL OR6Chat7MigrateAppearance(OR6APICore *core, NSString *preferencesPath, id explicitChoice);
#ifdef __cplusplus
}
#endif

// One Core operation at a time (reads and local work). A new -perform: cancels the old
// call; late callbacks are dropped. Reports through OR6Chat8ModelDelegate.
@interface OR6Chat7Call : NSObject
- (id)initWithCore:(OR6APICore *)core;
@property (nonatomic, assign) id<OR6Chat8ModelDelegate> delegate;
@property (nonatomic, readonly) BOOL busy;
@property (nonatomic, readonly) NSString *operation;
@property (nonatomic, readonly) NSDictionary *result, *lastEvent;
@property (nonatomic, readonly) NSError *error;
@property (nonatomic, readonly) NSUInteger events;
- (BOOL)perform:(NSString *)operation parameters:(NSDictionary *)parameters; // NO: not callable (nothing runs)
- (void)cancel;
- (void)reset;
@end

// One remote mutation with an immutable operation ID.
// phase: idle | running | done | failed (proven not dispatched: a NEW explicit attempt is
// allowed) | blocked (service stop signal) | uncertain (possibly applied: only the read-only
// reconcile operation is offered, never a resend).
@interface OR6Chat7Write : NSObject
- (id)initWithCore:(OR6APICore *)core reconcile:(NSString *)reconcileOperation;
@property (nonatomic, assign) id<OR6Chat8ModelDelegate> delegate;
@property (nonatomic, readonly) NSString *phase, *operationId, *operation, *intent;
@property (nonatomic, readonly) NSDictionary *receipt;
@property (nonatomic, readonly) NSError *error;
@property (nonatomic, readonly) BOOL verified;  // receipt.verified (read-back proof), not just acknowledged
// parameters without operationId; intent: the unresolved key (refused while unresolved).
- (BOOL)perform:(NSString *)operation parameters:(NSDictionary *)parameters intent:(NSString *)intent;
// The same with an operation ID the trusted host already bound private data to (PIN secrets, account
// authorization): the ID must be a UUID and is used unchanged for the write and its reconcile.
- (BOOL)perform:(NSString *)operation parameters:(NSDictionary *)parameters intent:(NSString *)intent operationId:(NSString *)operationId;
- (BOOL)reconcile; // uncertain/unverified only: read-only check with the same operation ID
- (void)cancel;    // a running write becomes uncertain (it may have been applied)
@end

// assets.status of a vault asset in the current Core context before any cached use (export,
// playback). Media answers only for this owner's stored asset and API7G rebinds the validated
// result after its deactivate; another owner/context fails closed. Late replies are dropped.
@interface OR6Chat7AssetGate : NSObject
- (id)initWithCore:(OR6APICore *)core;
@property (nonatomic, readonly) BOOL busy;
- (BOOL)revalidate:(NSString *)assetId completion:(void (^)(NSDictionary *status, NSError *error))completion;
- (void)invalidate;
@end

// Answer image → private vault (assets.download, owned and cancellable) → images.export.
// One request at a time; -invalidate (background, owner change, screen teardown) cancels and
// drops every late callback, so a delayed download can never start Photos or a share sheet.
// Photos is latched as unresolved before its write and released only by a confirmed save or a
// proven unsent refusal: an unknown/cancelled save is never submitted again.
// Callbacks also require the Core generation of the request (owner/credential change drops them).
// phase: idle | downloading | checking | exporting | saved | shared (token ready) | failed | uncertain
@interface OR6Chat7ImageExport : NSObject
- (id)initWithCore:(OR6APICore *)core;
@property (nonatomic, assign) id<OR6Chat8ModelDelegate> delegate;
@property (nonatomic, readonly) NSString *phase, *token, *refusal; // refusal: busy | unresolved | invalid
@property (nonatomic, readonly) NSError *error;
@property (nonatomic, readonly) BOOL busy;
- (BOOL)exportFile:(NSString *)fileId message:(NSString *)messageId conversation:(NSString *)conversationId destination:(NSString *)destination;
// A known vault asset: assets.status first (phase checking), then images.export. key: the Photos latch key.
- (BOOL)exportAsset:(NSString *)assetId key:(NSString *)key destination:(NSString *)destination;
- (void)invalidate;
- (NSDictionary *)diagnostics;
@end

// composer.editor.* around one full-screen editing session, bound to the draft, chat, Core
// generation (owner/credential context) and life it was opened for. -finish… applies (YES) only while all three still match; otherwise the old
// editor text is neither applied nor stored. -invalidate ends the binding.
@interface OR6Chat7EditorBinding : NSObject
- (id)initWithCore:(OR6APICore *)core draftId:(NSString *)draftId conversationId:(NSString *)conversationId text:(NSString *)text selection:(NSRange)selection;
@property (nonatomic, readonly) NSString *draftId, *conversationId;
@property (nonatomic, readonly) BOOL invalidated;
- (void)openRestoring:(void (^)(NSRange selection))restored; // get (same text: saved selection) then set expanded:YES
- (BOOL)finishText:(NSString *)text selection:(NSRange)selection currentDraft:(NSString *)draftId currentConversation:(NSString *)conversationId;
- (void)invalidate;
@end

// Share link preparation. shares.create needs the conversation's CURRENT node, which a list
// summary may lack or carry stale, so the sheet first reads it: one read-only history.get for
// the exact conversation in the current Core context. Nothing is created or published here.
// The reply must be the same conversation (id equal to the request), with a UUID currentNode
// that is one of its nodes; anything else fails closed. -createParametersForConversation:
// (asked at the Create tap) returns the shares.create parameters only while the prepared
// conversation, node and Core generation (owner/credential context) still match.
// One read at a time; -retry is only another READ after a failure that is not a stop signal or
// a context change. -cancel (dismissal, background) drops late/duplicate replies.
// phase: idle | preparing | ready | failed | cancelled
BOOL OR6Chat7ConversationUUID(id value); // exact 8-4-4-4-12 hex (OR6API7UUID policy)
@interface OR6Chat7SharePreparation : NSObject
- (id)initWithCore:(OR6APICore *)core;
@property (nonatomic, assign) id<OR6Chat8ModelDelegate> delegate;
@property (nonatomic, readonly) NSString *phase, *conversationId, *currentNode;
@property (nonatomic, readonly) NSError *error;
@property (nonatomic, readonly) BOOL retryAvailable;
- (BOOL)prepareConversation:(NSString *)conversationId; // NO: invalid ID, already preparing, cancelled
- (BOOL)retry;
- (NSDictionary *)createParametersForConversation:(NSString *)conversationId; // {conversationId, currentNode, publish:YES} or nil
- (void)cancel;
- (NSDictionary *)diagnostics; // counts and phase only (no IDs)
@end
