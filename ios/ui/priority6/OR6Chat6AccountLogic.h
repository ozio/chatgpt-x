// Foundation-only logic of the stage-6 account screens (OR6Chat6Account.m): request building for the
// API6D memory / settings / account writes and the API6E session writes (exact contract parameters of
// support/priority6d and priority6e contracts.json, without operationId — OR6Chat7Write adds it),
// input validation and the honest texts of capacity, receipts and operation status.
// Tests: tests/chat-ui6/account.m. No UIKit.
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif
// memories.delete {expectedRevision, memoryId, confirmed:true}. The 6D provider checks expectedRevision
// against the revision of THIS memory (API6DMemory.revision), not the list revision. nil: malformed.
NSDictionary *OR6Chat6MemoryDeleteRequest(NSDictionary *memory);
// memories.prioritize {expectedRevision, memoryId} (memory revision); nil: malformed or already a priority.
NSDictionary *OR6Chat6MemoryPrioritizeRequest(NSDictionary *memory);
// memories.deleteAll {expectedRevision (API6DMemoryList.revision of memories.list), confirmed:true};
// nil: no revision, not the full list (a search result) or an empty list.
NSDictionary *OR6Chat6MemoryDeleteAllRequest(NSDictionary *list);
// A revision-bound switch (memories.management.update, preferences.set*, privacy.locationControls.update):
// {expectedRevision: state.revision, enabled}. nil: no revision.
NSDictionary *OR6Chat6SettingRequest(NSDictionary *state, BOOL enabled);
BOOL OR6Chat6MemoryIsPriority(NSDictionary *memory);       // status "warm" (what memories.prioritize sets)
// memories.search query: trimmed, at most 1000 UTF-16 units without splitting a character; nil when empty.
NSString *OR6Chat6MemorySearchQuery(NSString *typed);
// Instant local feedback while the server search runs: items whose content contains the query.
NSArray *OR6Chat6MemoryFilter(NSArray *items, NSString *query);
// API6DCapacity → «Memory is 42% full» or «1,200 of 8,000 tokens used»; nil when nothing is reported.
NSString *OR6Chat6MemoryCapacityText(NSDictionary *capacity);
BOOL OR6Chat6MemoryAlmostFull(NSDictionary *capacity);     // ≥ 80 % (percentUsed or used/max)

// Account requests (privacy.exportData / privacy.deleteAccount) without operationId.
extern NSString *const OR6Chat6DeleteConfirmationWord;     // "DELETE" (the 6D provider requires exactly this)
BOOL OR6Chat6DeleteConfirmationValid(NSString *typed);     // trimmed text equals the word (case-sensitive)
NSDictionary *OR6Chat6DeleteAccountRequest(NSString *typed); // {confirmed:true, confirmation:"DELETE"} or nil
NSDictionary *OR6Chat6ExportRequest(void);                 // {confirmed:true}
// receipt.actionRequired → what the user has to do (localized); nil for null/unknown.
NSString *OR6Chat6AccountActionText(id actionRequired);
// API6DReceipt of an account request → one honest line. Deletion is only called done when verified.
NSString *OR6Chat6AccountReceiptText(NSDictionary *receipt, NSString *command);
// API6DOperationStatus (privacy.operationStatus) → one honest line; nil for a malformed status.
NSString *OR6Chat6AccountStatusText(NSDictionary *status);
BOOL OR6Chat6AccountStatusSettled(NSDictionary *status, NSString *operationId); // completed/rejected for this ID

// Sessions (API6E). Refusal: nil (revocable) | current | unavailable | not_allowed | invalid.
NSString *OR6Chat6SessionRefusal(NSDictionary *device);
// The catalogue/target IDs expire after 5 minutes: fresh means read less than 4.5 minutes ago.
BOOL OR6Chat6SessionCatalogFresh(NSDate *readAt, NSDate *now);
// account.sessions.revoke {catalogId, targetId, confirm:true}; nil: refused, stale or malformed.
NSDictionary *OR6Chat6SessionRevokeRequest(NSDictionary *sessions, NSDictionary *device, NSDate *readAt, NSDate *now);
NSDictionary *OR6Chat6SessionRevokeAllRequest(void);       // {confirmRevokeAllSessions:true}
NSString *OR6Chat6SessionKindText(NSDictionary *device);   // signed-out trusted / unavailable; nil for a session
#ifdef __cplusplus
}
#endif
