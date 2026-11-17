// Foundation-only models of the stage-6 screens (no UIKit): they run the real Core operations of
// the composed OR6API6AllCore with the exact DTOs of support/priority6[a-f]/contracts.json, keep
// opaque continuation tokens exactly as the service returned them, drop late callbacks by epoch
// and Core generation (owner/credential change), and never invent data. The UIKit screens only
// render what these report. Tests: tests/chat-ui6/models.m (held provider, no network).
#import <Foundation/Foundation.h>
#import "../../api/OR6APICore.h"
#import "../priority7/OR6Chat7Models.h"

// One paged list read. The continuation token is opaque (sent back unchanged, never parsed);
// a page that repeats the requested token ends the list; at most maxPages pages per reload.
// A failed page keeps the items read so far and its own error; -retry repeats exactly that page
// (same token) unless the error is a service stop signal. Items are deduplicated by idKey.
// phase via busy/loaded/error; every change reaches the delegate (main thread).
@interface OR6Chat6Pager : NSObject
- (id)initWithCore:(OR6APICore *)core operation:(NSString *)operation parameters:(NSDictionary *)parameters
          tokenKey:(NSString *)tokenKey nextKey:(NSString *)nextKey idKey:(NSString *)idKey;
@property (nonatomic, assign) id<OR6Chat8ModelDelegate> delegate;
@property (nonatomic, assign) NSUInteger maxPages;          // default 8
@property (nonatomic, copy) NSString *itemsKey;             // default "items"
@property (nonatomic, readonly) NSString *operation;
@property (nonatomic, copy) NSDictionary *parameters;       // base parameters (without the token); setting it resets
@property (nonatomic, readonly) NSArray *items;             // validated NSDictionary items in service order
@property (nonatomic, readonly) NSDictionary *lastPage;     // the last accepted page (partial, sourceStatuses, view…)
@property (nonatomic, readonly) NSArray *pageResults;       // every accepted page in order
@property (nonatomic, readonly) NSError *error;             // error of the last request (items so far stay)
@property (nonatomic, readonly) BOOL busy, loaded, hasMore; // loaded: the first page arrived
@property (nonatomic, readonly) BOOL retryAvailable;        // an error that is not a stop signal / context change
@property (nonatomic, readonly) NSUInteger pages;
- (BOOL)reload;                 // first page (drops items); NO: not callable
- (BOOL)loadMore;               // the stored next token; NO: nothing more or busy
- (BOOL)retry;                  // the failed page again (same token)
- (void)removeItemWithId:(NSString *)identifier; // after a confirmed delete/move
- (void)cancel;
- (void)reset;
- (NSDictionary *)diagnostics;  // counts and flags only (no IDs, no tokens)
@end

#ifdef __cplusplus
extern "C" {
#endif
// search.global item → the row the drawer shows, or nil only for a malformed item:
// {kind: conversation|project|file|page, title, snippet, id, conversationId?, projectId?, libraryItemId?, pageId?}
// Files and pages are kept (shown honestly even when ChatGPT X cannot open them).
NSDictionary *OR6Chat6SearchEntry(NSDictionary *item);
// Honest one-line note for a partial result: which sources failed or were skipped; nil when complete.
NSString *OR6Chat6SearchNotice(NSArray *pages);
// Locked chat (locked.conversations.get Conversation DTO) → read-only transcript without any cache:
// {markdown, messages (original user/assistant messages), images, files, unsupported, sources:[{title,url,host}]}.
// Non-text parts become explicit placeholders; a message is never dropped because its text is empty.
NSDictionary *OR6Chat6LockedTranscript(NSDictionary *conversation);
// conversations.reportReasons: the reasons under parentId (nil: top level), in service order.
NSArray *OR6Chat6ReportChildren(NSDictionary *reasons, NSString *parentId);
// Validated conversations.report parameters (without operationId) or nil with *problem set to a
// localized message: required/typed additional fields (int, email, url), details length, canSubmit.
NSDictionary *OR6Chat6ReportRequest(NSString *conversationId, NSDictionary *reasons, NSDictionary *reason, NSString *details, NSDictionary *fieldValues, NSString **problem);
// Task schedule (iCalendar VEVENT as the service stores it). frequency: once | daily | weekdays |
// weekly | monthly. weekdays: NSNumbers 1 (Monday)…7 (Sunday) for weekly. date: the first/only run
// (its local hour and minute are the run time); timeZone: the zone the times are in.
NSString *OR6Chat6TaskSchedule(NSString *frequency, NSDate *date, NSArray *weekdays, NSTimeZone *timeZone);
// The reverse for the editor: {frequency, hour, minute, weekdays, date?} or nil (a schedule this
// editor cannot represent: it is shown read-only and sent back unchanged).
NSDictionary *OR6Chat6TaskScheduleParse(NSString *schedule, NSTimeZone *timeZone);
// Localized one-line description of a parsed schedule («Every day at 09:00»), nil when unknown.
NSString *OR6Chat6TaskScheduleText(NSDictionary *parsed);
// API6DTaskDraft from the editor fields (trimmed, bounded) or nil with *problem.
NSDictionary *OR6Chat6TaskDraft(NSString *title, NSString *prompt, NSString *schedule, NSString *timeZone, NSString *timingMode, NSDictionary *existing, NSString **problem);
// composer.mentions.send ranges: inserted = [{id, name, location}] recorded when the user picked
// a mention; only those whose «@name» still sits at its location are sent (UTF-16 indices).
NSArray *OR6Chat6MentionRanges(NSString *text, NSArray *inserted);
// Human «12 MB»; nil for an unknown size.
NSString *OR6Chat6Bytes(id bytes);
// ISO-8601 timestamp with its own zone: Z, ±hh:mm or ±hhmm, optional fractional seconds
// ("2026-11-12T09:00:00+09:00", "2026-11-12T00:00:00.250Z"); also epoch seconds/milliseconds.
// nil for anything malformed or without an explicit zone (never silently read as UTC).
NSDate *OR6Chat6ParseDate(id value);
// Account Models → the open chat: an API6F selection {modelId, thinkingEffort,…} applied to the
// shared API8 catalog the chats send with (models.select, local). YES only when the catalog is
// loaded and offers that model; the effort is applied only when that mode offers it.
@class OR6Chat8Catalog;
void OR6Chat6SetChatCatalog(OR6Chat8Catalog *catalog); // the root's shared catalog (retained), nil on teardown
OR6Chat8Catalog *OR6Chat6ChatCatalog(void);
BOOL OR6Chat6ApplySelection(OR6Chat8Catalog *catalog, NSDictionary *selection);
// PIN reset route: «native» only with a proven host reauthentication path and callable writes;
// otherwise «web» (the first-party account PIN settings page, nothing sent from the app).
NSString *OR6Chat6PINResetRoute(BOOL nativeHost, BOOL resetCallable);
NSURL *OR6Chat6PINSettingsURL(void);          // https://chatgpt.com/settings/security?view=account-pin
NSURL *OR6Chat6GPTPageURL(NSString *gptId);   // https://chatgpt.com/g/<id> for a well-formed GPT ID, else nil
#ifdef __cplusplus
}
#endif

// The stored Auto preference for new chats (modelControls.autoPreference.get, local but backed by
// account/catalog reads): one shared observation per Core, bound to the Core generation
// (owner/credential context). A success is cached for `lifetime` seconds (default 300) and
// dropped by -invalidate (explicit preference change) or a generation change. An error is kept as
// lastIssue; after a service stop signal or a lost session no further automatic read runs for
// that generation. Nothing here retries by itself.
@interface OR6Chat6AutoPreference : NSObject
+ (OR6Chat6AutoPreference *)forCore:(OR6APICore *)core;
@property (nonatomic, assign) NSTimeInterval lifetime;
@property (nonatomic, readonly) NSString *lastIssue;   // error code of the last read, nil after a success
@property (nonatomic, readonly) BOOL stopped, busy;
@property (nonatomic, readonly) NSUInteger reads;      // reads started (diagnostics)
// The cached preference at once, or one read whose result reaches `apply` (main thread, same
// generation only). NO: nothing to apply and nothing started (stopped, busy, not callable).
- (BOOL)request:(void (^)(NSDictionary *preference))apply;
- (void)invalidate;
- (NSDictionary *)diagnostics;
@end
