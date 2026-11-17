#import "OR6Chat7Models.h"
#import "../../api/priority7all/OR6API7AllCore.h"
#import "../../chat/OR6ChatUIState.h"
#import "../../localization/OR6Localization.h"
#import "../../api/priority7/OR6API7Policy.h" // OR6API7UUID
#include <sys/stat.h>
#include <errno.h>

static NSDictionary *gTiers;
static NSMutableSet *gUnresolved;

void OR6Chat7SetTiers(NSDictionary *tiers) { NSDictionary *t = [tiers isKindOfClass:NSDictionary.class] ? [tiers copy] : nil; [gTiers release]; gTiers = t; }
NSString *OR6Chat7Tier(NSString *op) { id t = op ? gTiers[op] : nil; return [t isKindOfClass:NSString.class] ? t : nil; }
BOOL OR6Chat7Callable(OR6APICore *core, NSString *op) {
    if (![core isKindOfClass:OR6API7AllCore.class]) return NO;
    NSString *t = OR6Chat7Tier(op);
    // user_action (stage 6): a source-backed write the user starts and confirms explicitly; it is not
    // live evidence and is never reported as such (tests/chat-ui6/admission.py).
    return [@[@"local", @"candidate_read", @"handoff", @"user_action", @"live_verified"] containsObject:t ?: @""];
}
BOOL OR6Chat7On(OR6APICore *core, NSString *op) { return OR6Chat7Callable(core, op); }
BOOL OR6Chat7AllOn(OR6APICore *core, NSArray *ops) { if (!ops.count) return NO; for (NSString *op in ops) if (!OR6Chat7On(core, op)) return NO; return YES; }
BOOL OR6Chat7Unverified(NSString *op) { return [@[@"candidate_read", @"handoff", @"user_action"] containsObject:OR6Chat7Tier(op) ?: @""]; }
NSUInteger OR6Chat7Generation(OR6APICore *core) { return [core.diagnostics[@"generation"] unsignedIntegerValue]; }
NSString *OR6Chat7OperationID(void) { return [OR6ChatUUID() lowercaseString]; }
void OR6Chat7MarkUnresolved(NSString *key) { if (!key.length) return; if (!gUnresolved) gUnresolved = [NSMutableSet new]; [gUnresolved addObject:key]; }
BOOL OR6Chat7IsUnresolved(NSString *key) { return key.length && [gUnresolved containsObject:key]; }
void OR6Chat7ForgetUnresolvedKey(NSString *key) { if (key) [gUnresolved removeObject:key]; }
void OR6Chat7ForgetUnresolved(void) { [gUnresolved removeAllObjects]; }
BOOL OR6Chat7MigrateAppearance(OR6APICore *core, NSString *path, id choice) {
    if (![path isKindOfClass:NSString.class] || !path.isAbsolutePath || ![choice isKindOfClass:NSNumber.class] || !OR6Chat7Callable(core, @"clientPreferences.theme")) return NO;
    int v = [choice intValue]; if ((v != 0 && v != 1) || [choice doubleValue] != v) return NO;
    struct stat st; if (!lstat(path.fileSystemRepresentation, &st) || errno != ENOENT) return NO; // an established (or unreadable) G store stays as it is
    [core perform:@"clientPreferences.theme" parameters:@{@"theme": v ? @"dark" : @"light"} event:nil completion:^(NSDictionary *r, NSError *e) { (void)r; (void)e; }];
    return YES;
}
NSString *OR6Chat7ErrorText(NSError *e) {
    NSString *code = e.userInfo[@"code"] ?: @"", *dispatch = e.userInfo[@"dispatch"];
    if ([code isEqual:@"capability_unverified"]) return OR6L(@"This function is not available in this build.");
    if ([code isEqual:@"permission_denied"] || [code isEqual:@"owner_mismatch"]) return OR6L(@"This account cannot change it from ChatGPT X.");
    if ([code isEqual:@"conflict"]) return OR6L(@"The data changed or another request is running. Read it again first.");
    if ([code isEqual:@"duplicate_operation"]) return OR6L(@"This request was already made. It is not sent again.");
    if ([code isEqual:@"unsupported_media"]) return OR6L(@"This kind of request is not supported in ChatGPT X.");
    if ([code isEqual:@"invalid_operation_state"] || [code isEqual:@"invalid_request"]) return OR6L(@"This action is not possible in the current state.");
    if ([dispatch isEqual:@"possible"] && ![code isEqual:@"uncertain_outcome"]) return [NSString stringWithFormat:@"%@ %@", OR6ChatErrorText(e), OR6L(@"It may have been applied; it is not repeated.")];
    return OR6ChatErrorText(e);
}

@interface OR6Chat7Call () { OR6APICore *_core; id<OR6APITask> _task; NSUInteger _epoch; NSString *_operation; NSDictionary *_result, *_lastEvent; NSError *_error; NSUInteger _events; BOOL _busy; id<OR6Chat8ModelDelegate> _delegate; }
@end
@implementation OR6Chat7Call
@synthesize delegate = _delegate, busy = _busy, operation = _operation, result = _result, lastEvent = _lastEvent, error = _error, events = _events;
- (id)initWithCore:(OR6APICore *)core { if ((self = [super init])) _core = [core retain]; return self; }
- (void)changed { [[self retain] autorelease]; [_delegate chat8ModelChanged:self]; }
- (BOOL)perform:(NSString *)op parameters:(NSDictionary *)p {
    if (!OR6Chat7Callable(_core, op) || ![p isKindOfClass:NSDictionary.class]) return NO;
    [self cancel];
    NSUInteger epoch = ++_epoch; _busy = YES; [_operation release]; _operation = [op copy];
    [_result release]; _result = nil; [_error release]; _error = nil; [_lastEvent release]; _lastEvent = nil; _events = 0;
    __block BOOL finished = NO;
    id<OR6APITask> t = [_core perform:op parameters:p event:^(NSDictionary *ev) {
        if (epoch != _epoch) return; _events++; [_lastEvent release]; _lastEvent = [ev copy]; [self changed];
    } completion:^(NSDictionary *r, NSError *e) {
        finished = YES; if (epoch != _epoch) return;
        _busy = NO; [_task release]; _task = nil; [_result release]; _result = [r copy]; [_error release]; _error = [e retain];
        [self changed];
    }];
    if (!finished && epoch == _epoch) _task = [t retain];
    if (!finished) [self changed];
    return YES;
}
- (void)cancel { _epoch++; [_task cancel]; [_task release]; _task = nil; _busy = NO; }
- (void)reset { [self cancel]; [_result release]; _result = nil; [_error release]; _error = nil; [_operation release]; _operation = nil; [_lastEvent release]; _lastEvent = nil; _events = 0; }
- (void)dealloc { [self cancel]; [_core release]; [_operation release]; [_result release]; [_error release]; [_lastEvent release]; [super dealloc]; }
@end

@interface OR6Chat7Write () { OR6APICore *_core; NSString *_reconcile, *_phase, *_operationId, *_operation, *_intent; NSDictionary *_receipt; NSError *_error; id<OR6APITask> _task; NSUInteger _epoch; id<OR6Chat8ModelDelegate> _delegate; }
@end
@implementation OR6Chat7Write
@synthesize delegate = _delegate, phase = _phase, operationId = _operationId, operation = _operation, intent = _intent, receipt = _receipt, error = _error;
- (id)initWithCore:(OR6APICore *)core reconcile:(NSString *)reconcile {
    if ((self = [super init])) { _core = [core retain]; _reconcile = [reconcile copy]; _phase = [@"idle" copy]; }
    return self;
}
// verified: read-back proof — receipt.verified, a confirmed delete, or an API6B/6F mutation receipt
// {state:"completed", confirmed:true} (those contracts name their read-back "confirmed").
// API6D receipts also say state:"verified" (with verified:true); an acknowledged/local receipt is not proof.
- (BOOL)verified { return [_receipt[@"verified"] isEqual:@YES] || [_receipt[@"deleted"] isEqual:@YES] || ([_receipt[@"confirmed"] isEqual:@YES] && [_receipt[@"state"] isEqual:@"completed"]) || ([_receipt[@"state"] isEqual:@"verified"] && ![_receipt[@"verified"] isEqual:@NO]); }
- (void)phase:(NSString *)p { [_phase release]; _phase = [p copy]; [[self retain] autorelease]; [_delegate chat8ModelChanged:self]; }
- (void)finish:(NSDictionary *)r error:(NSError *)e epoch:(NSUInteger)epoch {
    if (epoch != _epoch) return;
    [_task release]; _task = nil; [_error release]; _error = [e retain];
    if (r) { [_receipt release]; _receipt = [r copy]; }
    NSString *code = e.userInfo[@"code"];
    if (!e) { if (_intent && [self verified]) [gUnresolved removeObject:_intent]; [self phase:@"done"]; return; }
    if (OR6Chat8StopSignal(code)) { [self phase:@"blocked"]; return; }
    BOOL none = [e.userInfo[@"dispatch"] isEqual:@"none"] && ![code isEqual:@"cancelled"] && ![code isEqual:@"uncertain_outcome"];
    if (none && ![_phase isEqual:@"reconciling"]) { [self phase:@"failed"]; return; }
    OR6Chat7MarkUnresolved(_intent);
    [self phase:@"uncertain"];
}
- (BOOL)perform:(NSString *)op parameters:(NSDictionary *)p intent:(NSString *)intent { return [self perform:op parameters:p intent:intent operationId:nil]; }
- (BOOL)perform:(NSString *)op parameters:(NSDictionary *)p intent:(NSString *)intent operationId:(NSString *)given {
    if ([_phase isEqual:@"running"] || [_phase isEqual:@"reconciling"] || [_phase isEqual:@"uncertain"] || [_phase isEqual:@"blocked"]) return NO;
    if (!OR6Chat7Callable(_core, op) || OR6Chat7IsUnresolved(intent) || ![p isKindOfClass:NSDictionary.class]) return NO;
    if (given && (!OR6Chat7ConversationUUID(given) || ![given isEqual:given.lowercaseString])) return NO; // the host bound exactly this canonical value: never altered
    NSMutableDictionary *q = [[p mutableCopy] autorelease];
    [_operationId release]; _operationId = [(given ?: OR6Chat7OperationID()) copy]; q[@"operationId"] = _operationId; // immutable for this intent
    [_operation release]; _operation = [op copy]; [_intent release]; _intent = [intent copy]; [_receipt release]; _receipt = nil;
    NSUInteger epoch = ++_epoch; __block BOOL finished = NO;
    [self phase:@"running"];
    id<OR6APITask> t = [_core perform:op parameters:q event:nil completion:^(NSDictionary *r, NSError *e) { finished = YES; [self finish:r error:e epoch:epoch]; }];
    if (!finished && epoch == _epoch) _task = [t retain];
    return YES;
}
- (BOOL)reconcile {
    BOOL open = [_phase isEqual:@"uncertain"] || ([_phase isEqual:@"done"] && ![self verified]);
    if (!open || !_operationId || !_reconcile || !OR6Chat7Callable(_core, _reconcile)) return NO;
    NSUInteger epoch = ++_epoch; __block BOOL finished = NO;
    [self phase:@"reconciling"];
    id<OR6APITask> t = [_core perform:_reconcile parameters:@{@"operationId": _operationId} event:nil completion:^(NSDictionary *r, NSError *e) { finished = YES; [self finish:r error:e epoch:epoch]; }];
    if (!finished && epoch == _epoch) _task = [t retain];
    return YES;
}
- (void)cancel {
    if (!_task) return;
    BOOL running = [_phase isEqual:@"running"];
    _epoch++; [_task cancel]; [_task release]; _task = nil;
    if (running) OR6Chat7MarkUnresolved(_intent);
    [self phase:@"uncertain"]; // reconciling also returns to uncertain: the write stays unknown
}
- (void)dealloc { if ([_phase isEqual:@"running"]) OR6Chat7MarkUnresolved(_intent); _epoch++; [_task cancel]; [_task release]; [_core release]; [_reconcile release]; [_phase release]; [_operationId release]; [_operation release]; [_intent release]; [_receipt release]; [_error release]; [super dealloc]; }
@end

#pragma mark - Image export

#pragma mark - Asset gate

@interface OR6Chat7AssetGate () { OR6APICore *_core; id<OR6APITask> _task; NSUInteger _life; BOOL _busy; }
@end
@implementation OR6Chat7AssetGate
@synthesize busy = _busy;
- (id)initWithCore:(OR6APICore *)core { if ((self = [super init])) _core = [core retain]; return self; }
- (BOOL)revalidate:(NSString *)assetId completion:(void (^)(NSDictionary *, NSError *))block {
    if (_busy || ![assetId isKindOfClass:NSString.class] || !assetId.length || !block) return NO;
    // assets.status in the CURRENT Core context: Media answers only for this owner's stored asset,
    // and G (re)binds the validated result. A late reply of an older life/context is dropped.
    NSUInteger life = ++_life, gen = OR6Chat7Generation(_core); void (^done)(NSDictionary *, NSError *) = [[block copy] autorelease];
    _busy = YES; __block BOOL finished = NO;
    id<OR6APITask> t = [_core perform:@"assets.status" parameters:@{@"assetId": assetId} event:nil completion:^(NSDictionary *r, NSError *e) {
        finished = YES; if (life != _life) return;
        _busy = NO; [_task release]; _task = nil;
        if (gen != OR6Chat7Generation(_core)) e = OR6APIError(@"stale_context", @"none"); // another owner/context now: fail closed, never use the result
        if (!e && (![r[@"assetId"] isEqual:assetId] || ![r[@"available"] isEqual:@YES])) e = OR6APIError(@"unavailable", @"none");
        done(e ? nil : r, e);
    }];
    if (!finished && life == _life) _task = [t retain];
    return YES;
}
- (void)invalidate { _life++; _busy = NO; [_task cancel]; [_task release]; _task = nil; }
- (void)dealloc { [self invalidate]; [_core release]; [super dealloc]; }
@end

#pragma mark - Image export

@interface OR6Chat7ImageExport () { OR6APICore *_core; OR6Chat7AssetGate *_gate; id<OR6APITask> _task; NSUInteger _life; NSString *_phase, *_token, *_refusal, *_pendingKey, *_photosKey; NSError *_error; NSMutableDictionary *_assets; id<OR6Chat8ModelDelegate> _delegate; }
@end
@implementation OR6Chat7ImageExport
@synthesize delegate = _delegate, phase = _phase, token = _token, refusal = _refusal, error = _error;
- (id)initWithCore:(OR6APICore *)core { if ((self = [super init])) { _core = [core retain]; _gate = [[OR6Chat7AssetGate alloc] initWithCore:core]; _phase = [@"idle" copy]; _assets = [NSMutableDictionary new]; } return self; }
- (BOOL)busy { return [_phase isEqual:@"downloading"] || [_phase isEqual:@"checking"] || [_phase isEqual:@"exporting"]; }
- (void)phase:(NSString *)p { [_phase release]; _phase = [p copy]; [[self retain] autorelease]; [_delegate chat8ModelChanged:self]; }
- (BOOL)refuse:(NSString *)why { [_refusal release]; _refusal = [why copy]; return NO; }
- (void)fail:(NSError *)e { [_error release]; _error = [e retain]; [self phase:@"failed"]; }
// life AND the Core generation of the request: an owner/credential change drops the callback even without -invalidate.
- (void)export:(NSString *)assetId destination:(NSString *)dest fileId:(NSString *)fileId life:(NSUInteger)life generation:(NSUInteger)gen {
    if (life != _life || gen != OR6Chat7Generation(_core) || ![assetId isKindOfClass:NSString.class] || ![dest isKindOfClass:NSString.class]) return;
    if ([dest isEqual:@"photos"]) { [_photosKey release]; _photosKey = [[@"photos:" stringByAppendingString:fileId] copy]; OR6Chat7MarkUnresolved(_photosKey); } // before the write
    [self phase:@"exporting"]; __block BOOL finished = NO;
    id<OR6APITask> t = [_core perform:@"images.export" parameters:@{@"assetIds": @[assetId], @"destination": dest} event:nil completion:^(NSDictionary *r, NSError *e) {
        finished = YES; if (life != _life) return; [_task release]; _task = nil;
        if (gen != OR6Chat7Generation(_core)) { [_photosKey release]; _photosKey = nil; [self fail:OR6APIError(@"stale_context", @"possible")]; return; } // owner changed: a started Photos save keeps its latch
        [_error release]; _error = [e retain];
        NSString *photos = [[_photosKey retain] autorelease]; [_photosKey release]; _photosKey = nil;
        BOOL none = e && [e.userInfo[@"dispatch"] isEqual:@"none"] && ![e.userInfo[@"code"] isEqual:@"cancelled"];
        if (photos && (none || (!e && [r[@"completed"] isEqual:@YES] && [r[@"saved"] integerValue] > 0))) OR6Chat7ForgetUnresolvedKey(photos);
        if (e) { [self phase:none ? @"failed" : @"uncertain"]; return; }
        if ([r[@"token"] isKindOfClass:NSString.class]) { [_token release]; _token = [r[@"token"] copy]; [self phase:@"shared"]; return; }
        [self phase:([r[@"completed"] isEqual:@YES] && [r[@"saved"] integerValue] > 0) ? @"saved" : @"uncertain"];
    }];
    if (!finished && life == _life) _task = [t retain];
}
- (BOOL)begin:(NSString *)key destination:(NSString *)dest {
    if ([self busy]) return [self refuse:@"busy"];
    if (![key isKindOfClass:NSString.class] || ![@[@"photos", @"share"] containsObject:dest ?: @""] || !OR6Chat7Callable(_core, @"images.export")) return [self refuse:@"invalid"];
    if ([dest isEqual:@"photos"] && OR6Chat7IsUnresolved([@"photos:" stringByAppendingString:key])) return [self refuse:@"unresolved"];
    [_token release]; _token = nil; [_error release]; _error = nil; [_refusal release]; _refusal = nil; return YES;
}
// A known vault asset (cached download, saved file): revalidated through assets.status first, so
// a G binding cleared by deactivate is rebound only for this owner; another owner fails closed.
- (BOOL)exportAsset:(NSString *)assetId key:(NSString *)key destination:(NSString *)dest {
    if (![self begin:key destination:dest]) return NO;
    NSUInteger life = _life, gen = OR6Chat7Generation(_core);
    [self phase:@"checking"]; // before dispatch: a synchronous reply may already finish the export
    if (![_gate revalidate:assetId completion:^(NSDictionary *status, NSError *e) {
        if (life != _life) return;
        if (e) { [self fail:e]; return; } // a read: wrong owner, missing or unavailable asset fails closed
        (void)status; [self export:assetId destination:dest fileId:key life:life generation:gen];
    }]) { [_phase release]; _phase = [@"idle" copy]; return [self refuse:@"invalid"]; }
    return YES;
}
- (BOOL)exportFile:(NSString *)fileId message:(NSString *)messageId conversation:(NSString *)cid destination:(NSString *)dest {
    if (![messageId isKindOfClass:NSString.class] || ![cid isKindOfClass:NSString.class]) return [self refuse:@"invalid"];
    NSString *asset = [fileId isKindOfClass:NSString.class] ? _assets[fileId] : nil;
    if (asset) return [self exportAsset:asset key:fileId destination:dest];
    if (![self begin:fileId destination:dest]) return NO;
    NSString *key = [NSString stringWithFormat:@"download:%@:%@", messageId, fileId];
    if (OR6Chat7IsUnresolved(key)) return [self refuse:@"unresolved"];
    NSUInteger life = _life, gen = OR6Chat7Generation(_core);
    [_pendingKey release]; _pendingKey = [key copy];
    [self phase:@"downloading"]; __block BOOL finished = NO;
    id<OR6APITask> t = [_core perform:@"assets.download" parameters:@{@"operationId": OR6Chat7OperationID(), @"conversationId": cid, @"messageId": messageId, @"fileId": fileId} event:nil completion:^(NSDictionary *r, NSError *e) {
        finished = YES; if (life != _life) return; // invalidated: no Photos, no share, no callback
        [_task release]; _task = nil; [_pendingKey release]; _pendingKey = nil;
        if (gen != OR6Chat7Generation(_core)) { OR6Chat7MarkUnresolved(key); [self fail:OR6APIError(@"stale_context", @"possible")]; return; } // owner changed: the asset is not used, not repeated
        if (e || ![r[@"assetId"] isKindOfClass:NSString.class]) { if (![e.userInfo[@"dispatch"] isEqual:@"none"]) OR6Chat7MarkUnresolved(key); [self fail:e]; return; }
        _assets[fileId] = r[@"assetId"]; [self export:r[@"assetId"] destination:dest fileId:fileId life:life generation:gen]; // just validated by the download in this context
    }];
    if (!finished && life == _life) _task = [t retain];
    return YES;
}
- (void)invalidate {
    _life++; [_gate invalidate];
    if ([_phase isEqual:@"downloading"]) OR6Chat7MarkUnresolved(_pendingKey); // never repeated, like API8 downloads
    [_task cancel]; [_task release]; _task = nil; [_pendingKey release]; _pendingKey = nil; [_photosKey release]; _photosKey = nil; // a started Photos save keeps its latch
    [_phase release]; _phase = [@"idle" copy];
}
- (NSDictionary *)diagnostics { return @{@"phase": _phase, @"assets": @(_assets.count), @"life": @(_life)}; }
- (void)dealloc { _delegate = nil; [self invalidate]; [_gate release]; [_core release]; [_phase release]; [_token release]; [_refusal release]; [_error release]; [_assets release]; [super dealloc]; }
@end

#pragma mark - Editor binding

@interface OR6Chat7EditorBinding () { OR6APICore *_core; NSString *_draftId, *_conversationId, *_text; NSRange _selection; BOOL _invalidated; NSUInteger _generation; }
@end
@implementation OR6Chat7EditorBinding
@synthesize draftId = _draftId, conversationId = _conversationId, invalidated = _invalidated;
- (id)initWithCore:(OR6APICore *)core draftId:(NSString *)d conversationId:(NSString *)c text:(NSString *)t selection:(NSRange)s {
    if ((self = [super init])) { _core = [core retain]; _draftId = [d copy]; _conversationId = [c copy]; _text = [(t ?: @"") copy]; _selection = s; _generation = OR6Chat7Generation(core); } // the exact Core context it was opened in
    return self;
}
- (NSDictionary *)state:(NSString *)text selection:(NSRange)r expanded:(BOOL)e {
    if (r.location == NSNotFound || NSMaxRange(r) > text.length) r = NSMakeRange(text.length, 0);
    return @{@"draftId": _draftId, @"text": text, @"selectionStart": @(r.location), @"selectionLength": @(r.length), @"expanded": @(e)};
}
- (void)openRestoring:(void (^)(NSRange))restored {
    void (^done)(NSRange) = [[restored copy] autorelease];
    [_core perform:@"composer.editor.get" parameters:@{@"draftId": _draftId} event:nil completion:^(NSDictionary *saved, NSError *e) {
        if (_invalidated || _generation != OR6Chat7Generation(_core)) return; // owner/credential change while the editor opened
        // A previous expanded session of the same draft with the same text keeps its selection.
        if (!e && [saved[@"text"] isEqual:_text]) _selection = NSMakeRange([saved[@"selectionStart"] unsignedIntegerValue], [saved[@"selectionLength"] unsignedIntegerValue]);
        if (done) done(_selection);
        [_core perform:@"composer.editor.set" parameters:[self state:_text selection:_selection expanded:YES] event:nil completion:^(NSDictionary *x, NSError *f) { (void)x; (void)f; }];
    }];
}
- (BOOL)finishText:(NSString *)text selection:(NSRange)r currentDraft:(NSString *)draft currentConversation:(NSString *)cid {
    BOOL same = !_invalidated && _generation == OR6Chat7Generation(_core) && [draft isEqual:_draftId] && ((!cid && !_conversationId) || [cid isEqual:_conversationId]);
    if (!same) { _invalidated = YES; return NO; }
    _invalidated = YES; // one completion
    [_core perform:@"composer.editor.set" parameters:[self state:(text ?: _text) selection:r expanded:NO] event:nil completion:^(NSDictionary *x, NSError *f) { (void)x; (void)f; }];
    return YES;
}
- (void)invalidate { _invalidated = YES; }
- (void)dealloc { [_core release]; [_draftId release]; [_conversationId release]; [_text release]; [super dealloc]; }
@end

#pragma mark - Share preparation

BOOL OR6Chat7ConversationUUID(id v) { return OR6API7UUID(v); }

@interface OR6Chat7SharePreparation () { OR6APICore *_core; id<OR6APITask> _task; NSUInteger _epoch, _generation, _reads, _dropped; NSString *_phase, *_conversationId, *_currentNode; NSError *_error; }
@end
@implementation OR6Chat7SharePreparation
@synthesize delegate = _delegate, phase = _phase, conversationId = _conversationId, currentNode = _currentNode, error = _error;
- (id)initWithCore:(OR6APICore *)core { if ((self = [super init])) { _core = [core retain]; _phase = [@"idle" copy]; } return self; }
- (void)phase:(NSString *)p error:(NSError *)e {
    [_phase release]; _phase = [p copy]; [_error release]; _error = [e retain];
    [[self retain] autorelease]; [_delegate chat8ModelChanged:self];
}
- (BOOL)retryAvailable {
    NSString *code = _error.userInfo[@"code"];
    return [_phase isEqual:@"failed"] && _conversationId && _error && ![code isEqual:@"stale_context"] && !OR6Chat8StopSignal(code);
}
- (BOOL)prepareConversation:(NSString *)cid {
    if ([_phase isEqual:@"preparing"] || [_phase isEqual:@"cancelled"] || !_core || !OR6Chat7ConversationUUID(cid)) return NO;
    cid = [cid lowercaseString]; // UUID identity is case-insensitive; history IDs come back lowercase
    if (_conversationId && ![_conversationId isEqual:cid]) return NO; // one sheet, one conversation
    if (!_conversationId) _conversationId = [cid copy];
    [_currentNode release]; _currentNode = nil;
    NSUInteger epoch = ++_epoch, gen = OR6Chat7Generation(_core); _generation = gen; _reads++;
    [self phase:@"preparing" error:nil]; __block BOOL finished = NO, replied = NO;
    id<OR6APITask> t = [_core perform:@"history.get" parameters:@{@"conversationId": cid} event:nil completion:^(NSDictionary *r, NSError *e) {
        finished = YES;
        if (replied || epoch != _epoch) { _dropped++; return; } // duplicate, cancelled or superseded: nothing applies
        replied = YES; [_task release]; _task = nil;
        if (gen != OR6Chat7Generation(_core)) { [self phase:@"failed" error:OR6APIError(@"stale_context", @"none")]; return; } // another owner/context now
        if (e) { [self phase:@"failed" error:e]; return; }
        NSString *node = [r isKindOfClass:NSDictionary.class] ? r[@"currentNode"] : nil; NSArray *nodes = [r isKindOfClass:NSDictionary.class] ? r[@"nodes"] : nil; BOOL member = NO;
        BOOL uuid = OR6Chat7ConversationUUID(node), same = [r isKindOfClass:NSDictionary.class] && OR6Chat7ConversationUUID(r[@"id"]) && [[r[@"id"] lowercaseString] isEqual:cid];
        if (uuid && [nodes isKindOfClass:NSArray.class]) for (NSDictionary *n in nodes) if ([n isKindOfClass:NSDictionary.class] && [n[@"id"] isKindOfClass:NSString.class] && [[n[@"id"] lowercaseString] isEqual:[node lowercaseString]]) { member = YES; break; }
        if (!same || !uuid || !member) { [self phase:@"failed" error:OR6APIError(@"invalid_response", @"none")]; return; }
        _currentNode = [node copy]; [self phase:@"ready" error:nil];
    }];
    if (!finished && epoch == _epoch) _task = [t retain];
    return YES;
}
- (BOOL)retry { return [self retryAvailable] && [self prepareConversation:_conversationId]; }
- (NSDictionary *)createParametersForConversation:(NSString *)cid {
    if (![_phase isEqual:@"ready"] || !_currentNode || !_conversationId || !OR6Chat7ConversationUUID(cid) || ![[cid lowercaseString] isEqual:_conversationId]) return nil;
    if (_generation != OR6Chat7Generation(_core)) { [_currentNode release]; _currentNode = nil; [self phase:@"failed" error:OR6APIError(@"stale_context", @"none")]; return nil; } // prepared for another context
    return @{@"conversationId": _conversationId, @"currentNode": _currentNode, @"publish": @YES};
}
- (void)cancel { _epoch++; [_task cancel]; [_task release]; _task = nil; [_currentNode release]; _currentNode = nil; [_phase release]; _phase = [@"cancelled" copy]; }
- (NSDictionary *)diagnostics { return @{@"phase": _phase ?: @"", @"reads": @(_reads), @"droppedReplies": @(_dropped), @"ready": @(_currentNode != nil)}; }
- (void)dealloc { _delegate = nil; [self cancel]; [_core release]; [_phase release]; [_conversationId release]; [_currentNode release]; [_error release]; [super dealloc]; }
@end
