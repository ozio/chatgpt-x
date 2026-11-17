// Foundation-only UI models for the 23 ready API 8/10 functions
// (support/priority8/features.json). They drive the real Core operations with
// the exact DTOs of support/native-api/contracts.json + OR6API8Registry, keep
// immutable operation IDs, drop stale callbacks by epoch, and never Send. The
// UIKit screens (ios/chat, OR6Chat8Screens) only render what they report.
#import <Foundation/Foundation.h>
#import "../../api/OR6APICore.h"

#ifdef __cplusplus
extern "C" {
#endif
// Feature keys from features.json (voice R&D features are deliberately absent).
extern NSString *const OR6Chat8FTemporary, *const OR6Chat8FEdit, *const OR6Chat8FSources, *const OR6Chat8FRegenerate,
 *const OR6Chat8FModels, *const OR6Chat8FStatus, *const OR6Chat8FTranslate, *const OR6Chat8FHistorySearch,
 *const OR6Chat8FWebSearch, *const OR6Chat8FDictationCancel, *const OR6Chat8FDictationRetry, *const OR6Chat8FCamera,
 *const OR6Chat8FPhotos, *const OR6Chat8FFiles, *const OR6Chat8FAttachmentEdit, *const OR6Chat8FLimits,
 *const OR6Chat8FExpiry, *const OR6Chat8FDownload, *const OR6Chat8FLargeText, *const OR6Chat8FLoginEmail,
 *const OR6Chat8FLoginGoogle, *const OR6Chat8FMFA, *const OR6Chat8FLoginRetry;
NSArray *OR6Chat8FeatureKeys(void);
// Optional explicit admission from the composition owner (nil: every feature
// whose operations the composed Core registry really has).
void OR6Chat8SetAdmittedFeatures(NSSet *features);
// YES when the Core is the API8 composition (OR6API8Registry adds assets.attach)
// and every operation of the feature is registered and admitted. 
BOOL OR6Chat8Supports(OR6APICore *core, NSString *feature);
NSArray *OR6Chat8Operations(NSString *feature);

// Truthful generation.status text: no invented reasoning, no ETA. nil for
// writing/complete (the streamed text itself is the progress).
NSString *OR6Chat8StatusTitle(NSString *phase);
// content.scale ↔ RCTextSize steps 0…4 (14/15/16/19/22 pt over the 16 pt base).
double OR6Chat8ScaleForTextSize(int size);
int OR6Chat8TextSizeForScale(double scale);
// UI sources {id?,title,url,host} → Source DTOs for content.sources (safe URLs only).
NSArray *OR6Chat8SourceDTOs(NSArray *sources);
// Source DTOs → UI rows {id,title,url,host}; unsafe URLs are dropped.
NSArray *OR6Chat8SourceRows(NSArray *dtos);
// Message parts (history.get) → files {fileId,name,mediaType,bytes} and images
// {fileId,width,height}; image pointers win over their duplicate attachment entry.
NSDictionary *OR6Chat8MessageAssets(NSArray *parts);
BOOL OR6Chat8FileID(id value);
// auth Interaction DTO → {"phase": idle|interactive|complete|cancelled|failed, "text": localized or ""}.
NSDictionary *OR6Chat8InteractionNotice(NSDictionary *interaction);
// Service stop signals (challenge, rate limit, login/session): never offered as a retry.
BOOL OR6Chat8StopSignal(NSString *code);
// Unknown-outcome translation/download requests and the tool stop signal are kept
// process-wide; the owner change (sign-out) forgets them.
void OR6Chat8ForgetUnresolved(void);
BOOL OR6Chat8ToolsHalted(void);
// While a safe Retry of a refused send waits: the attachments model and the state keep the
// reserved draft's options (OR6ChatConversationState.optionsLocked). Called by the conversation
// screen after every Send/Retry receipt; returns the lock.
@class OR6ChatConversationState, OR6Chat9Actions, OR6Chat8Attachments;
BOOL OR6Chat8SyncRetryLock(OR6ChatConversationState *state, OR6Chat9Actions *actions, OR6Chat8Attachments *files, BOOL retryStage);
// Human byte size: "820 KB".
NSString *OR6Chat8Bytes(unsigned long long bytes);
#ifdef __cplusplus
}
#endif

@protocol OR6Chat8ModelDelegate <NSObject>
- (void)chat8ModelChanged:(id)model;
@end

// Draft attachments: assets.acquire → assets.upload → assets.attach (replace
// keeps the old one until the replacement is ready), assets.detach, assets.status,
// assets.limits. Items are NSDictionary snapshots:
// {key, assetId?, name, mediaType, bytes, image, phase, progress, issue, attached,
//  replaces?, retryable, operationId?}; phase: acquiring | uploading | processing |
// attaching | ready | failed (proven not dispatched; retry allowed unless a stop
// signal) | uncertain (no re-upload) | expired | unavailable.
@interface OR6Chat8Attachments : NSObject
- (id)initWithCore:(OR6APICore *)core;
@property (nonatomic, assign) id<OR6Chat8ModelDelegate> delegate;
@property (nonatomic, copy) NSString *draftId;   // set once messages.newDraft succeeded; ready items attach then
@property (nonatomic, readonly) NSArray *items;
@property (nonatomic, readonly) NSDictionary *limits; // AssetLimits DTO once read
@property (nonatomic, readonly) NSString *notice;     // localized constraint/failure note for the tray, or nil
@property (nonatomic, assign) BOOL locked;            // a safe Retry waits: no acquire/replace/retry/detach of attached files
@property (nonatomic, readonly) BOOL halted;          // a stop signal arrived: no new uploads until -reset
- (void)loadLimits;
- (BOOL)canAdd;
- (BOOL)acquireFrom:(NSString *)source replacing:(NSString *)key; // camera | photo_library | document
- (BOOL)checkUpload:(NSString *)key; // uncertain upload: inspect local receipt, processing-only resume with original ID; never resend bytes
- (BOOL)retry:(NSString *)key;   // only a proven no-dispatch failure, new operation ID
- (void)remove:(NSString *)key;  // cancels its task; detaches when attached
- (void)checkStatus;             // assets.status for every attached asset (expiry/unavailable)
- (NSArray *)attachedAssetIds;   // exactly the draft's attachments, in order
// API7 library.attach returned this Draft (same draftId): its one new opaque Library handle joins
// the tray as ready/attached ("library": YES); removing it uses library.detach.
- (BOOL)adoptLibraryDraft:(NSDictionary *)draft item:(NSDictionary *)item;
- (NSArray *)sentItems;          // display copies for the sent bubble
- (BOOL)busy;
- (BOOL)blocksSend;              // something is in flight or not ready
- (void)clearAfterSend;          // the draft was consumed by a completed send
- (void)reset;                   // owner/session change: forget everything (no network)
- (void)prepareForBackground;    // cancel in-flight work; uploads become uncertain
- (NSDictionary *)diagnostics;
@end

// history.search paging (replaces the drawer's local title filter).
@interface OR6Chat8HistorySearch : NSObject
- (id)initWithCore:(OR6APICore *)core;
@property (nonatomic, assign) id<OR6Chat8ModelDelegate> delegate;
@property (nonatomic, readonly) NSString *query;
@property (nonatomic, readonly) NSArray *items;   // SearchItem DTOs
@property (nonatomic, readonly) NSString *nextToken;
@property (nonatomic, readonly) BOOL busy, loaded;
@property (nonatomic, readonly) NSString *issue;  // error code or nil
- (void)setQuery:(NSString *)query;               // trims; cancels the previous query; does not read
- (BOOL)search;                                   // first page of the current query
- (BOOL)loadMore;
- (void)cancel;
- (void)reset;
@end

// models.list / models.select for the ordinary chat. The catalog is presented as
// families (versions), their modes (one Model DTO each: the exact send slug) and the
// mode's thinking efforts, all from the received metadata (familyId/familyTitle,
// modeId/modeTitle, efforts [{id,title}], defaultEffort); nothing is named by the app.
// A flat legacy Model without that metadata is its own family with one untitled mode.
// Until the user chooses, Send uses "Default": the account's default model with the
// service's default effort. It is not synchronized with any browser's selection.
extern NSString *const OR6Chat8CatalogDidChangeNotification; // object: the catalog (every delegate change)
@interface OR6Chat8Catalog : NSObject
- (id)initWithCore:(OR6APICore *)core;
@property (nonatomic, assign) id<OR6Chat8ModelDelegate> delegate;
@property (nonatomic, readonly) NSArray *items;          // admitted Model DTOs (unique IDs, unique family/mode)
// Presentation: [{id, title, modes: [{id, title, modelId, efforts: [{id,title}], defaultEffort?}]}] in catalog order.
@property (nonatomic, readonly) NSArray *families;
@property (nonatomic, readonly) NSString *chosenModelId; // the user's explicit choice (nil: Default)
@property (nonatomic, readonly) NSString *chosenEffort;  // effort ID of the chosen mode (nil: the service's default effort)
@property (nonatomic, readonly) BOOL busy, loaded;
@property (nonatomic, readonly) BOOL structured;         // the catalog carries family/mode metadata (models.select gets thinkingEffort)
@property (nonatomic, readonly) BOOL choiceDropped;      // the last reload no longer offered the chosen mode/effort: it fell back
@property (nonatomic, readonly) NSString *issue;
- (BOOL)load;
- (BOOL)select:(NSString *)modelId;                                   // effort: nil (service default)
- (BOOL)selectModel:(NSString *)modelId effort:(NSString *)effortId;  // effort must be one of the mode's efforts, or nil
// Back to "Default": selects the catalog's selectedModelId with no effort (local models.select)
// so planned generations use it again; the ordinary Send goes back to web-current.
// NO when the catalog named no default (the choice then stays: issue "default_unknown").
- (BOOL)useDefault;
- (BOOL)canUseDefault;
@property (nonatomic, readonly) NSString *catalogDefaultModelId; // selectedModelId of the received catalog, if in it
- (NSDictionary *)familyForModel:(NSString *)modelId;  // family containing the mode
- (NSDictionary *)modeForModel:(NSString *)modelId;
- (NSString *)sendModelId;        // chosen ID or "web-current"
- (NSString *)sendThinkingEffort; // chosen effort of the chosen mode, or nil (default)
- (NSString *)title;              // "Family · Mode · Effort" of the choice, or nil for Default
- (NSString *)titleForModel:(NSString *)modelId effort:(NSString *)effortId;
- (void)reset;
@end

// translation.translate: one explicit request per tap; a running or uncertain
// translation is never repeated automatically.
@interface OR6Chat8Translation : NSObject
- (id)initWithCore:(OR6APICore *)core;
@property (nonatomic, assign) id<OR6Chat8ModelDelegate> delegate;
@property (nonatomic, readonly) BOOL busy, uncertain;
@property (nonatomic, readonly) NSString *result, *issue, *operationId;
@property (nonatomic, readonly) NSString *refusal; // why the last -translate: returned NO: busy | invalid | restricted | not_repeated
- (BOOL)translate:(NSString *)text from:(NSString *)source to:(NSString *)target;
- (void)cancel;
@end

// assets.download per (message, file): {state: ready|downloading|saved|failed (no dispatch, may try again)|
// uncertain (possible dispatch or cancelled: never repeated)|blocked (stop signal)|unavailable, progress, bytes, name, issue, assetId}.
@interface OR6Chat8Downloads : NSObject
- (id)initWithCore:(OR6APICore *)core;
@property (nonatomic, assign) id<OR6Chat8ModelDelegate> delegate;
- (NSDictionary *)stateForFile:(NSString *)fileId message:(NSString *)messageId;
- (BOOL)download:(NSString *)fileId message:(NSString *)messageId conversation:(NSString *)conversationId;
- (void)cancelAll;
@end
