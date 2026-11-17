#import "OR6Chat8Models.h"
#import "../../chat/OR6ChatUIState.h"
#import "../../localization/OR6Localization.h"
#import "../../OR6Content.h"

NSString *const OR6Chat8FTemporary = @"chat.temporary", *const OR6Chat8FEdit = @"chat.edit_message",
 *const OR6Chat8FSources = @"chat.sources", *const OR6Chat8FRegenerate = @"chat.regenerate",
 *const OR6Chat8FModels = @"tools.model_picker", *const OR6Chat8FStatus = @"tools.reasoning_status",
 *const OR6Chat8FTranslate = @"tools.translate", *const OR6Chat8FHistorySearch = @"search.history",
 *const OR6Chat8FWebSearch = @"search.web", *const OR6Chat8FDictationCancel = @"audio.dictation_cancel",
 *const OR6Chat8FDictationRetry = @"audio.dictation_retry", *const OR6Chat8FCamera = @"media.camera_photo",
 *const OR6Chat8FPhotos = @"media.photo_picker", *const OR6Chat8FFiles = @"media.file_upload",
 *const OR6Chat8FAttachmentEdit = @"media.attachment_remove_replace", *const OR6Chat8FLimits = @"media.attachment_constraints",
 *const OR6Chat8FExpiry = @"media.file_expiry", *const OR6Chat8FDownload = @"media.download_file",
 *const OR6Chat8FLargeText = @"accessibility.large_text", *const OR6Chat8FLoginEmail = @"account.login.email_password",
 *const OR6Chat8FLoginGoogle = @"account.login.google", *const OR6Chat8FMFA = @"account.mfa.authenticator",
 *const OR6Chat8FLoginRetry = @"account.login.cancel_retry";

static NSDictionary *OR6Chat8OperationMap(void) {
    static NSDictionary *map;
    if (!map) {
        NSArray *media = @[@"assets.acquire", @"assets.upload", @"assets.attach"], *login = @[@"auth.begin", @"auth.status"];
        map = [@{OR6Chat8FTemporary: @[@"messages.newDraft", @"messages.send"], OR6Chat8FEdit: @[@"messages.edit"],
                 OR6Chat8FSources: @[@"content.sources"], OR6Chat8FRegenerate: @[@"messages.regenerate"],
                 OR6Chat8FModels: @[@"models.list", @"models.select"], OR6Chat8FStatus: @[@"generation.status"],
                 OR6Chat8FTranslate: @[@"translation.translate"], OR6Chat8FHistorySearch: @[@"history.search", @"history.get"],
                 OR6Chat8FWebSearch: @[@"search.web", @"content.sources"], OR6Chat8FDictationCancel: @[@"dictation.stop", @"dictation.cancel"],
                 OR6Chat8FDictationRetry: @[@"dictation.retry"], OR6Chat8FCamera: media, OR6Chat8FPhotos: media, OR6Chat8FFiles: media,
                 OR6Chat8FAttachmentEdit: @[@"assets.detach", @"assets.attach", @"assets.acquire", @"assets.upload"],
                 OR6Chat8FLimits: @[@"assets.limits"], OR6Chat8FExpiry: @[@"assets.status"], OR6Chat8FDownload: @[@"assets.download"],
                 OR6Chat8FLargeText: @[@"content.scale"], OR6Chat8FLoginEmail: login, OR6Chat8FLoginGoogle: login, OR6Chat8FMFA: login,
                 OR6Chat8FLoginRetry: @[@"auth.begin", @"auth.cancel", @"auth.status"]} retain];
    }
    return map;
}
NSArray *OR6Chat8FeatureKeys(void) { return [OR6Chat8OperationMap().allKeys sortedArrayUsingSelector:@selector(compare:)]; }
NSArray *OR6Chat8Operations(NSString *feature) { return OR6Chat8OperationMap()[feature]; }

static NSSet *gAdmitted;
void OR6Chat8SetAdmittedFeatures(NSSet *features) { [gAdmitted release]; gAdmitted = [features copy]; }

// The registry's operation table is protected Core state; a category reads it
// without a new public Core API or any change to the composition.
@interface OR6APICore (OR6Chat8Registry)
- (BOOL)or6chat8_hasOperation:(NSString *)operation;
@end
@implementation OR6APICore (OR6Chat8Registry)
- (BOOL)or6chat8_hasOperation:(NSString *)operation { return [_operations[operation] isKindOfClass:[NSDictionary class]]; }
@end

BOOL OR6Chat8Supports(OR6APICore *core, NSString *feature) {
    NSArray *ops = OR6Chat8Operations(feature);
    if (!core || !ops || ![core or6chat8_hasOperation:@"assets.attach"]) return NO;
    if (gAdmitted && ![gAdmitted containsObject:feature]) return NO;
    for (NSString *op in ops) if (![core or6chat8_hasOperation:op]) return NO;
    return YES;
}

NSString *OR6Chat8StatusTitle(NSString *phase) {
    if ([phase isEqual:@"queued"]) return OR6L(@"Queued…");
    if ([phase isEqual:@"preparing"]) return OR6L(@"Preparing the request…");
    if ([phase isEqual:@"thinking"]) return OR6L(@"Thinking…");
    if ([phase isEqual:@"searching"]) return OR6L(@"Searching the web…");
    if ([phase isEqual:@"interrupted"]) return OR6L(@"Interrupted");
    if ([phase isEqual:@"unknown"]) return OR6L(@"Status unknown");
    return nil;
}

static const double kOR6Chat8Sizes[5] = {14, 15, 16, 19, 22};
double OR6Chat8ScaleForTextSize(int size) { return kOR6Chat8Sizes[MAX(0, MIN(4, size))] / 16.0; }
int OR6Chat8TextSizeForScale(double scale) {
    int best = 2; double distance = 1e9;
    for (int i = 0; i < 5; i++) { double d = fabs(kOR6Chat8Sizes[i] / 16.0 - scale); if (d < distance) { distance = d; best = i; } }
    return best;
}

static BOOL O8String(id v, NSUInteger max) { return [v isKindOfClass:[NSString class]] && [v length] > 0 && [v length] <= max; }
NSArray *OR6Chat8SourceDTOs(NSArray *sources) {
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *s in sources) {
        if (![s isKindOfClass:[NSDictionary class]] || !O8String(s[@"url"], 4096) || !OR6ContentSafeURL(s[@"url"], NO) || out.count >= 100) continue;
        NSString *identifier = O8String(s[@"id"], 128) ? s[@"id"] : [NSString stringWithFormat:@"source-%lu", (unsigned long)out.count];
        NSString *title = [s[@"title"] isKindOfClass:[NSString class]] ? s[@"title"] : @"";
        [out addObject:@{@"id": identifier, @"title": [title substringToIndex:MIN(title.length, (NSUInteger)2000)], @"url": s[@"url"], @"start": [NSNull null], @"end": [NSNull null]}];
    }
    return out;
}
NSArray *OR6Chat8SourceRows(NSArray *dtos) {
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *s in dtos) {
        if (![s isKindOfClass:[NSDictionary class]]) continue;
        NSString *safe = O8String(s[@"url"], 4096) ? OR6ContentSafeURL(s[@"url"], NO) : nil;
        NSURL *u = safe ? [NSURL URLWithString:safe] : nil;
        if (!u.host.length) continue;
        NSString *title = O8String(s[@"title"], 2000) ? s[@"title"] : u.host;
        [out addObject:@{@"id": O8String(s[@"id"], 128) ? s[@"id"] : @"source", @"title": [title substringToIndex:MIN(title.length, (NSUInteger)300)], @"url": safe, @"host": u.host}];
    }
    return out;
}

BOOL OR6Chat8FileID(id value) {
    if (!O8String(value, 128)) return NO;
    static NSRegularExpression *re;
    if (!re) re = [[NSRegularExpression alloc] initWithPattern:@"^file[-_][A-Za-z0-9_-]+$" options:0 error:NULL];
    return [re numberOfMatchesInString:value options:0 range:NSMakeRange(0, [value length])] == 1;
}
NSDictionary *OR6Chat8MessageAssets(NSArray *parts) {
    NSMutableArray *files = [NSMutableArray array], *images = [NSMutableArray array];
    NSMutableSet *imageIDs = [NSMutableSet set], *fileIDs = [NSMutableSet set];
    if ([parts isKindOfClass:[NSArray class]]) for (NSDictionary *p in parts) {
        if (![p isKindOfClass:[NSDictionary class]] || ![p[@"kind"] isEqual:@"asset"]) continue;
        NSDictionary *d = [p[@"data"] isKindOfClass:[NSDictionary class]] ? p[@"data"] : p;
        NSString *pointer = [d[@"asset_pointer"] isKindOfClass:[NSString class]] ? d[@"asset_pointer"] : nil;
        NSString *prefix = [pointer hasPrefix:@"sediment://"] ? @"sediment://" : [pointer hasPrefix:@"file-service://"] ? @"file-service://" : nil;
        if (pointer) {
            NSString *file = prefix ? [pointer substringFromIndex:prefix.length] : nil;
            if (!file || !OR6Chat8FileID(file) || [imageIDs containsObject:file] || images.count >= 16) continue;
            [imageIDs addObject:file];
            [images addObject:@{@"fileId": file, @"width": d[@"width"] ?: @0, @"height": d[@"height"] ?: @0}];
        } else if (OR6Chat8FileID(d[@"id"]) && ![fileIDs containsObject:d[@"id"]] && files.count < 16) {
            [fileIDs addObject:d[@"id"]];
            NSString *name = O8String(d[@"name"], 240) ? d[@"name"] : OR6L(@"File");
            [files addObject:@{@"fileId": d[@"id"], @"name": name, @"mediaType": O8String(d[@"mime_type"], 128) ? d[@"mime_type"] : @"application/octet-stream", @"bytes": [d[@"size"] isKindOfClass:[NSNumber class]] ? d[@"size"] : @0}];
        }
    }
    NSMutableArray *plain = [NSMutableArray array];
    for (NSDictionary *f in files) if (![imageIDs containsObject:f[@"fileId"]]) [plain addObject:f];
    return @{@"files": plain, @"images": images};
}

NSDictionary *OR6Chat8InteractionNotice(NSDictionary *interaction) {
    NSString *state = [interaction isKindOfClass:[NSDictionary class]] ? interaction[@"state"] : nil;
    if (![state isKindOfClass:[NSString class]] || ![@[@"idle", @"interactive", @"complete", @"cancelled", @"failed"] containsObject:state]) state = @"idle";
    NSString *text = @"";
    if ([state isEqual:@"interactive"]) text = [interaction[@"provider"] isEqual:@"google"] ? OR6L(@"Continue with Google on the service page. A code from your authenticator app is entered there too.") : OR6L(@"Enter your e-mail and password on the service page. A code from your authenticator app is entered there too.");
    else if ([state isEqual:@"cancelled"]) text = OR6L(@"Login was cancelled. You can try again.");
    else if ([state isEqual:@"failed"]) text = OR6L(@"Login did not complete. Try again.");
    return @{@"phase": state, @"text": text};
}

NSString *OR6Chat8Bytes(unsigned long long bytes) {
    if (bytes < 1024) return [NSString stringWithFormat:OR6L(@"%lu bytes"), (unsigned long)bytes];
    if (bytes < 1024 * 1024) return [NSString stringWithFormat:OR6L(@"%lu KB"), (unsigned long)((bytes + 512) / 1024)];
    NSNumberFormatter *f = [[[NSNumberFormatter alloc] init] autorelease];
    f.numberStyle = NSNumberFormatterDecimalStyle; f.maximumFractionDigits = 1; f.minimumFractionDigits = 1;
    return [NSString stringWithFormat:OR6L(@"%@ MB"), [f stringFromNumber:@((double)bytes / 1048576.0)]];
}

static NSString *O8Issue(NSError *e) { NSString *c = e.userInfo[@"code"]; return [c isKindOfClass:[NSString class]] ? c : @"unknown"; }
static BOOL O8Possible(NSError *e) { return ![e.userInfo[@"dispatch"] isEqual:@"none"]; }

BOOL OR6Chat8StopSignal(NSString *code) {
    return [@[@"service_challenge", @"rate_limited", @"access_denied", @"not_authenticated", @"login_required", @"auth_failed", @"session_recovery", @"stale_context"] containsObject:code ?: @""];
}
// Requests whose outcome is unknown (possible dispatch, cancelled after start). The
// same request is not issued again under a new operation ID; process-wide, cleared
// on an owner change. Also the service stop signal for repeatable tool requests.
static NSMutableSet *gUnresolved; static BOOL gToolsHalted;
static void O8Unresolved(NSString *signature) { if (!gUnresolved) gUnresolved = [NSMutableSet new]; if (signature) [gUnresolved addObject:signature]; }
static BOOL O8IsUnresolved(NSString *signature) { return signature && [gUnresolved containsObject:signature]; }
void OR6Chat8ForgetUnresolved(void) { [gUnresolved removeAllObjects]; gToolsHalted = NO; }
BOOL OR6Chat8ToolsHalted(void) { return gToolsHalted; }
static NSString *O8Signature(NSString *kind, NSArray *parts) { NSMutableString *s = [NSMutableString stringWithString:kind]; for (id p in parts) [s appendFormat:@"\x1f%@", p]; return s; }

#pragma mark - Attachments

@interface OR6Chat8Attachments () {
    OR6APICore *_core; NSMutableArray *_items, *_order; NSMutableDictionary *_tasks;
    NSUInteger _epoch; NSDictionary *_limits; NSString *_notice, *_draftId; id<OR6Chat8ModelDelegate> _delegate; BOOL _locked, _halted;
}
@end

@implementation OR6Chat8Attachments
@synthesize delegate = _delegate, limits = _limits, notice = _notice, locked = _locked, halted = _halted;
- (BOOL)refuseLocked {
    if (_halted) { [self setNotice:OR6ChatErrorText(OR6APIError(@"service_challenge", @"none"))]; [self changed]; return YES; }
    if (!_locked) return NO;
    [self setNotice:OR6L(@"The unsent message keeps its files until you send it again or send a new message.")]; [self changed]; return YES;
}
- (id)initWithCore:(OR6APICore *)core {
    if ((self = [super init])) { _core = [core retain]; _items = [NSMutableArray new]; _order = [NSMutableArray new]; _tasks = [NSMutableDictionary new]; }
    return self;
}
- (void)dealloc {
    _delegate = nil; _epoch++;
    for (id<OR6APITask> t in _tasks.allValues) [t cancel];
    [_tasks release]; [_items release]; [_order release]; [_core release]; [_limits release]; [_notice release]; [_draftId release];
    [super dealloc];
}
- (NSArray *)items { NSMutableArray *out = [NSMutableArray array]; for (NSDictionary *i in _items) [out addObject:[[i copy] autorelease]]; return out; }
- (NSMutableDictionary *)item:(NSString *)key { for (NSMutableDictionary *i in _items) if ([i[@"key"] isEqual:key]) return i; return nil; }
- (void)changed { [_delegate chat8ModelChanged:self]; }
- (void)setNotice:(NSString *)n { if (n == _notice || [n isEqual:_notice]) return; [_notice release]; _notice = [n copy]; }
- (NSUInteger)maxCount { NSUInteger n = [_limits[@"maxCount"] unsignedIntegerValue]; return n ? n : 4; }
- (unsigned long long)maxBytes { unsigned long long n = [_limits[@"maxBytes"] unsignedLongLongValue]; return n ? n : 8 * 1024 * 1024; }
- (void)loadLimits {
    if (_limits) return;
    NSUInteger epoch = _epoch;
    [_core perform:@"assets.limits" parameters:@{} event:nil completion:^(NSDictionary *r, NSError *e) {
        if (epoch != _epoch || e || ![r isKindOfClass:[NSDictionary class]]) return;
        [_limits release]; _limits = [r copy]; [self changed];
    }];
}
- (NSString *)limitText {
    return [NSString stringWithFormat:OR6L(@"Up to %lu files, %@ each. These are this app's limits; the service may set its own."), (unsigned long)[self maxCount], OR6Chat8Bytes([self maxBytes])];
}
- (BOOL)canAdd {
    NSUInteger live = 0; for (NSDictionary *i in _items) if (!i[@"replaces"]) live++;
    return live < [self maxCount];
}
- (BOOL)acquiring { for (NSDictionary *i in _items) if ([i[@"phase"] isEqual:@"acquiring"]) return YES; return NO; }
- (void)track:(id<OR6APITask>)task key:(NSString *)key finished:(BOOL)finished { if (!finished && task) _tasks[key] = task; }
- (BOOL)acquireFrom:(NSString *)source replacing:(NSString *)replaced {
    if (![@[@"camera", @"photo_library", @"document"] containsObject:source] || [self acquiring] || [self refuseLocked]) return NO;
    NSMutableDictionary *old = replaced ? [self item:replaced] : nil;
    if (replaced && !old) return NO;
    if (!old && ![self canAdd]) { [self setNotice:[self limitText]]; [self changed]; return NO; }
    NSString *key = OR6ChatUUID();
    NSMutableDictionary *item = [NSMutableDictionary dictionaryWithDictionary:@{@"key": key, @"phase": @"acquiring", @"name": @"", @"progress": @0, @"attached": @NO, @"retryable": @NO, @"image": @([source isEqual:@"camera"] || [source isEqual:@"photo_library"])}];
    if (old) item[@"replaces"] = replaced;
    [_items addObject:item]; [self setNotice:nil]; [self changed];
    NSUInteger epoch = _epoch; __block BOOL finished = NO;
    id<OR6APITask> task = [_core perform:@"assets.acquire" parameters:@{@"source": source, @"selectionId": OR6ChatUUID()} event:nil completion:^(NSDictionary *r, NSError *e) {
        finished = YES; if (epoch != _epoch) return; [_tasks removeObjectForKey:key];
        NSMutableDictionary *i = [self item:key]; if (!i) return;
        if (e || !O8String(r[@"assetId"], 128)) {
            NSString *code = e ? O8Issue(e) : @"invalid_response";
            [_items removeObject:i];
            if ([code isEqual:@"size_limit"]) [self setNotice:[NSString stringWithFormat:OR6L(@"The file is larger than %@ and was not attached."), OR6Chat8Bytes([self maxBytes])]];
            else if ([code isEqual:@"unsupported_media"]) [self setNotice:OR6L(@"This file cannot be attached.")];
            else if ([code isEqual:@"capability_unavailable"]) [self setNotice:OR6L(@"This source is not available on this iPhone.")];
            else if (![code isEqual:@"cancelled"]) [self setNotice:OR6ChatErrorText(e ?: OR6APIError(code, @"none"))];
            [self changed]; return;
        }
        if ([r[@"bytes"] unsignedLongLongValue] > [self maxBytes]) { [_items removeObject:i]; [self setNotice:[NSString stringWithFormat:OR6L(@"The file is larger than %@ and was not attached."), OR6Chat8Bytes([self maxBytes])]]; [self changed]; return; }
        for (NSString *k in @[@"assetId", @"name", @"mediaType", @"bytes"]) if (r[k]) i[k] = r[k];
        i[@"image"] = @([r[@"mediaType"] hasPrefix:@"image/"]);
        [self upload:i];
    }];
    [self track:task key:key finished:finished];
    return YES;
}
- (void)upload:(NSMutableDictionary *)i { [self upload:i resuming:NO]; }
- (void)upload:(NSMutableDictionary *)i resuming:(BOOL)resuming {
    NSString *key = [[i[@"key"] copy] autorelease], *op = resuming ? i[@"operationId"] : OR6ChatUUID();
    i[@"operationId"] = op; i[@"phase"] = @"uploading"; i[@"progress"] = @0; i[@"retryable"] = @NO; [i removeObjectForKey:@"issue"];
    [self changed];
    NSUInteger epoch = _epoch; __block BOOL finished = NO;
    id<OR6APITask> task = [_core perform:resuming ? @"assets.processing.resume" : @"assets.upload" parameters:@{@"operationId": op, @"assetId": i[@"assetId"]} event:^(NSDictionary *event) {
        if (epoch != _epoch || finished) return;
        NSMutableDictionary *x = [self item:key]; NSDictionary *p = event[@"payload"];
        if (!x || ![event[@"name"] isEqual:@"progress"] || ![p[@"operationId"] isEqual:op]) return;
        double total = MAX(1, [p[@"totalBytes"] doubleValue]), done = MIN(total, [p[@"completedBytes"] doubleValue]);
        BOOL processing = [p[@"phase"] isEqual:@"processing"];
        x[@"phase"] = processing ? @"processing" : @"uploading"; x[@"progress"] = @(processing ? .95 : .9 * done / total);
        [self changed];
    } completion:^(NSDictionary *r, NSError *e) {
        finished = YES; if (epoch != _epoch) return; [_tasks removeObjectForKey:key];
        NSMutableDictionary *x = [self item:key]; if (!x) return;
        if (e || ![r[@"state"] isEqual:@"ready"]) {
            NSString *code = e ? O8Issue(e) : @"invalid_response"; x[@"issue"] = code; x[@"progress"] = @1;
            if ([code isEqual:@"expired"]) x[@"phase"] = @"expired";
            // A service stop signal is never retried and stops new uploads until the session changes.
            else if (OR6Chat8StopSignal(code)) { x[@"phase"] = @"failed"; x[@"retryable"] = @NO; _halted = YES; [self setNotice:OR6ChatErrorText(e)]; }
            else if (!resuming && e && !O8Possible(e) && ![code isEqual:@"invalid_operation_state"]) { x[@"phase"] = @"failed"; x[@"retryable"] = @YES; }
            else x[@"phase"] = @"uncertain";
            [self changed]; return;
        }
        x[@"phase"] = @"ready"; x[@"progress"] = @1; if (r[@"remoteId"] != [NSNull null] && r[@"remoteId"]) x[@"remoteId"] = r[@"remoteId"];
        [self attach:x];
    }];
    [self track:task key:key finished:finished];
}
- (void)attach:(NSMutableDictionary *)x {
    if (!_draftId || [x[@"attached"] boolValue] || ![x[@"phase"] isEqual:@"ready"]) { [self changed]; return; }
    NSString *key = [[x[@"key"] copy] autorelease], *asset = [[x[@"assetId"] copy] autorelease], *draft = [[_draftId copy] autorelease];
    NSMutableDictionary *old = x[@"replaces"] ? [self item:x[@"replaces"]] : nil;
    NSString *replaced = [old[@"attached"] boolValue] ? old[@"assetId"] : nil;
    x[@"phase"] = @"attaching"; [self changed];
    NSUInteger epoch = _epoch; __block BOOL finished = NO;
    id<OR6APITask> task = [_core perform:@"assets.attach" parameters:@{@"draftId": draft, @"assetId": asset, @"replaceAssetId": replaced ?: (id)[NSNull null]} event:nil completion:^(NSDictionary *r, NSError *e) {
        finished = YES; if (epoch != _epoch) return; [_tasks removeObjectForKey:key];
        NSMutableDictionary *i = [self item:key]; if (!i) return;
        i[@"phase"] = @"ready";
        if (e || ![r[@"draftId"] isEqual:draft] || ![r[@"attachments"] containsObject:asset]) {
            i[@"issue"] = e ? O8Issue(e) : @"invalid_response";
            [self setNotice:[i[@"issue"] isEqual:@"size_limit"] ? [self limitText] : OR6L(@"The file is ready but was not added to the message. Tap it to try again.")];
            [self changed]; return;
        }
        // The draft's order is the order Send must repeat exactly.
        [_order setArray:r[@"attachments"]]; i[@"attached"] = @YES; [i removeObjectForKey:@"issue"];
        NSMutableDictionary *previous = i[@"replaces"] ? [self item:i[@"replaces"]] : nil;
        [i removeObjectForKey:@"replaces"];
        if (previous) { NSString *pk = previous[@"key"]; [(id<OR6APITask>)_tasks[pk] cancel]; [_tasks removeObjectForKey:pk]; [_items removeObject:previous]; }
        [self changed];
    }];
    [self track:task key:key finished:finished];
}
- (NSString *)draftId { return _draftId; }
- (void)setDraftId:(NSString *)draftId {
    if (draftId == _draftId || [draftId isEqual:_draftId]) return;
    [_draftId release]; _draftId = [draftId copy];
    if (!draftId) return;
    for (NSMutableDictionary *i in [[_items copy] autorelease]) if ([i[@"phase"] isEqual:@"ready"] && ![i[@"attached"] boolValue] && [self item:i[@"key"]]) [self attach:i];
}
- (BOOL)checkUpload:(NSString *)key {
    NSMutableDictionary *i = [self item:key];
    if (!i || _halted || [self refuseLocked] || ![i[@"phase"] isEqual:@"uncertain"] || !i[@"assetId"] || !i[@"operationId"] || _tasks[key]) return NO;
    NSUInteger epoch = _epoch; NSString *asset = [[i[@"assetId"] copy] autorelease]; __block BOOL finished = NO;
    i[@"phase"] = @"processing"; [self changed];
    id<OR6APITask> t = [_core perform:@"assets.status" parameters:@{@"assetId":asset} event:nil completion:^(NSDictionary *r, NSError *e) {
        finished = YES; if (epoch != _epoch) return; [_tasks removeObjectForKey:key];
        NSMutableDictionary *x = [self item:key]; if (!x || ![x[@"assetId"] isEqual:asset]) return;
        if (!e && [r[@"state"] isEqual:@"ready"] && [r[@"available"] isEqual:@YES]) { x[@"phase"] = @"ready"; [self attach:x]; return; }
        if (!e && [r[@"processingResumable"] isEqual:@YES]) { [self upload:x resuming:YES]; return; }
        x[@"phase"] = @"uncertain";
        if (e) { x[@"issue"] = O8Issue(e); if (OR6Chat8StopSignal(O8Issue(e))) _halted = YES; }
        [self setNotice:e ? OR6ChatErrorText(e) : OR6L(@"The upload is still unconfirmed. Its bytes were not sent again.")]; [self changed];
    }];
    [self track:t key:key finished:finished]; return YES;
}
- (BOOL)retry:(NSString *)key {
    NSMutableDictionary *i = [self item:key]; if (!i || [self refuseLocked]) return NO;
    if ([i[@"phase"] isEqual:@"failed"] && [i[@"retryable"] boolValue] && i[@"assetId"]) { [self upload:i]; return YES; }
    if ([i[@"phase"] isEqual:@"ready"] && ![i[@"attached"] boolValue] && _draftId) { [self attach:i]; return YES; }
    return NO;
}
- (void)remove:(NSString *)key {
    NSMutableDictionary *i = [self item:key]; if (!i) return;
    if (_locked && [i[@"attached"] boolValue] && [self refuseLocked]) return; // the reserved draft's selection is immutable
    id<OR6APITask> t = [[_tasks[key] retain] autorelease]; [_tasks removeObjectForKey:key];
    for (NSMutableDictionary *other in _items) if ([other[@"replaces"] isEqual:key]) [other removeObjectForKey:@"replaces"];
    BOOL attached = [i[@"attached"] boolValue]; NSString *asset = [[i[@"assetId"] copy] autorelease], *draft = [[_draftId copy] autorelease];
    [[i retain] autorelease]; [_items removeObject:i]; [t cancel];
    if (!attached || !draft) { [self changed]; return; }
    NSUInteger epoch = _epoch;
    // Detach changes only the draft's selection; the uploaded file stays on the service.
    // A Library selection (API7 library.attach) is released with library.detach; the remote file stays.
    NSString *detach = [i[@"library"] boolValue] ? @"library.detach" : @"assets.detach";
    [_core perform:detach parameters:@{@"draftId": draft, @"assetId": asset} event:nil completion:^(NSDictionary *r, NSError *e) {
        if (epoch != _epoch) return;
        if (!e && [r[@"detached"] boolValue]) [_order removeObject:asset];
        else if ([e.userInfo[@"code"] isEqual:@"not_found"]) [_order removeObject:asset];
        else { [i setObject:O8Issue(e) forKey:@"issue"]; [_items addObject:i]; [self setNotice:OR6L(@"The file could not be removed from the message.")]; }
        [self changed];
    }];
    [self changed];
}
- (void)checkStatus {
    NSUInteger epoch = _epoch;
    for (NSDictionary *i in [[_items copy] autorelease]) {
        if (!i[@"assetId"] || ![i[@"phase"] isEqual:@"ready"] || [i[@"library"] boolValue]) continue; // Library handles are re-read before every Send by the resolver
        NSString *key = i[@"key"];
        [_core perform:@"assets.status" parameters:@{@"assetId": i[@"assetId"]} event:nil completion:^(NSDictionary *r, NSError *e) {
            if (epoch != _epoch) return;
            NSMutableDictionary *x = [self item:key]; if (!x || ![x[@"phase"] isEqual:@"ready"]) return;
            NSString *state = r[@"state"];
            if (e) { x[@"phase"] = @"unavailable"; x[@"issue"] = O8Issue(e); }
            else if ([state isEqual:@"expired"]) x[@"phase"] = @"expired";
            else if (![r[@"available"] boolValue]) { x[@"phase"] = @"unavailable"; x[@"issue"] = state ?: @"unknown"; }
            else return;
            [self setNotice:OR6L(@"A file is no longer available. Remove it or replace it with a new copy.")];
            [self changed];
        }];
    }
}
- (NSArray *)attachedAssetIds { return [[_order copy] autorelease]; }
- (BOOL)adoptLibraryDraft:(NSDictionary *)draft item:(NSDictionary *)item {
    NSArray *ids = draft[@"attachments"];
    if (_locked || !_draftId || ![draft[@"draftId"] isEqual:_draftId] || ![ids isKindOfClass:NSArray.class] || ids.count > 4) return NO;
    for (NSString *a in _order) if (![ids containsObject:a]) return NO; // the returned Draft must keep every current attachment
    NSMutableArray *added = [NSMutableArray array]; for (NSString *a in ids) if (![_order containsObject:a]) [added addObject:a];
    if (added.count != 1) return NO;
    NSString *handle = added[0];
    [_items addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:handle, @"key", handle, @"assetId", (item[@"name"] ?: @""), @"name", ([item[@"mediaType"] isKindOfClass:NSString.class] ? item[@"mediaType"] : @"application/octet-stream"), @"mediaType",
        ([item[@"bytes"] isKindOfClass:NSNumber.class] ? item[@"bytes"] : @0), @"bytes", @NO, @"image", @"ready", @"phase", @1, @"progress", @YES, @"attached", @YES, @"library", @NO, @"retryable", nil]];
    [_order release]; _order = [ids mutableCopy];
    [self setNotice:nil]; [self changed]; return YES;
}
- (NSArray *)sentItems {
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *i in _items) if ([i[@"attached"] boolValue]) [out addObject:@{@"name": i[@"name"] ?: @"", @"image": i[@"image"] ?: @NO, @"assetId":i[@"assetId"]?:@""}];
    return out;
}
- (BOOL)busy { for (NSDictionary *i in _items) if ([@[@"acquiring", @"uploading", @"processing", @"attaching"] containsObject:i[@"phase"]]) return YES; return NO; }
- (BOOL)blocksSend {
    if ([self busy]) return YES;
    for (NSDictionary *i in _items) if (![i[@"phase"] isEqual:@"ready"] || ![i[@"attached"] boolValue]) return YES;
    return NO;
}
- (void)clearAfterSend { _epoch++; for (id<OR6APITask> t in _tasks.allValues) [t cancel]; [_tasks removeAllObjects]; [_items removeAllObjects]; [_order removeAllObjects]; [_draftId release]; _draftId = nil; [self setNotice:nil]; [self changed]; }
- (void)reset { _locked = NO; _halted = NO; [self clearAfterSend]; [_limits release]; _limits = nil; }
- (void)setLocked:(BOOL)locked { if (locked == _locked) return; _locked = locked; if (!locked && [_notice isEqual:OR6L(@"The unsent message keeps its files until you send it again or send a new message.")]) [self setNotice:nil]; [self changed]; }
- (void)prepareForBackground {
    // Cancel through Core: a started upload reports dispatch "possible" and becomes uncertain.
    for (id<OR6APITask> t in [[_tasks.allValues copy] autorelease]) [t cancel];
}
- (NSDictionary *)diagnostics {
    NSMutableArray *phases = [NSMutableArray array]; for (NSDictionary *i in _items) [phases addObject:i[@"phase"]];
    return @{@"items": @(_items.count), @"phases": phases, @"attached": @(_order.count), @"hasDraft": @(_draftId != nil), @"busy": @([self busy]), @"blocksSend": @([self blocksSend])};
}
@end

#pragma mark - History search

@interface OR6Chat8HistorySearch () { OR6APICore *_core; id<OR6APITask> _task; NSUInteger _epoch; NSMutableArray *_items; NSMutableSet *_tokens, *_ids; NSString *_query, *_next, *_issue; BOOL _busy, _loaded; id<OR6Chat8ModelDelegate> _delegate; }
@end
@implementation OR6Chat8HistorySearch
@synthesize delegate = _delegate, query = _query, nextToken = _next, busy = _busy, loaded = _loaded, issue = _issue;
- (id)initWithCore:(OR6APICore *)core { if ((self = [super init])) { _core = [core retain]; _items = [NSMutableArray new]; _tokens = [NSMutableSet new]; _ids = [NSMutableSet new]; } return self; }
- (void)dealloc { _delegate = nil; [self cancel]; [_core release]; [_items release]; [_tokens release]; [_ids release]; [_query release]; [_next release]; [_issue release]; [super dealloc]; }
- (NSArray *)items { return [[_items copy] autorelease]; }
- (void)cancel { _epoch++; [_task cancel]; [_task release]; _task = nil; _busy = NO; }
- (void)reset { [self cancel]; [_items removeAllObjects]; [_tokens removeAllObjects]; [_ids removeAllObjects]; [_next release]; _next = nil; [_issue release]; _issue = nil; _loaded = NO; }
- (void)setQuery:(NSString *)query {
    NSString *q = [query isKindOfClass:[NSString class]] ? [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";
    if (q.length > 256) q = [q substringToIndex:[q rangeOfComposedCharacterSequenceAtIndex:255].location];
    if ([q isEqual:_query]) return;
    [self reset]; [_query release]; _query = [q copy];
}
- (BOOL)page:(NSString *)token {
    if (_busy || !_query.length) return NO;
    _busy = YES; [_issue release]; _issue = nil;
    NSUInteger epoch = ++_epoch; __block BOOL finished = NO; NSString *query = [[_query copy] autorelease];
    id<OR6APITask> t = [_core perform:@"history.search" parameters:@{@"query": query, @"pageToken": token ?: (id)[NSNull null], @"limit": @20} event:nil completion:^(NSDictionary *r, NSError *e) {
        finished = YES; if (epoch != _epoch || ![query isEqual:_query]) return;
        [_task release]; _task = nil; _busy = NO;
        if (e || ![self accept:r token:token]) { [_issue release]; _issue = [(e ? O8Issue(e) : @"invalid_response") copy]; }
        [_delegate chat8ModelChanged:self];
    }];
    if (!finished && epoch == _epoch) _task = [t retain];
    [_delegate chat8ModelChanged:self];
    return YES;
}
- (BOOL)accept:(NSDictionary *)page token:(NSString *)token {
    if (![page isKindOfClass:[NSDictionary class]] || ![page[@"items"] isKindOfClass:[NSArray class]]) return NO;
    id next = page[@"nextToken"];
    if (next != [NSNull null] && (!O8String(next, 1024) || [next isEqual:token] || [_tokens containsObject:next])) return NO;
    NSMutableArray *add = [NSMutableArray array];
    for (NSDictionary *row in page[@"items"]) {
        if (![row isKindOfClass:[NSDictionary class]] || !O8String(row[@"id"], 128) || ![row[@"title"] isKindOfClass:[NSString class]]) return NO;
        if ([_ids containsObject:row[@"id"]]) continue;
        [_ids addObject:row[@"id"]]; [add addObject:row];
    }
    if (_items.count + add.count > 500) return NO;
    [_items addObjectsFromArray:add];
    if (token) [_tokens addObject:token];
    [_next release]; _next = next == [NSNull null] ? nil : [next copy];
    if (_next) [_tokens addObject:_next];
    _loaded = YES; return YES;
}
- (BOOL)search { if (_loaded || _busy) return NO; return [self page:nil]; }
- (BOOL)loadMore { return _next ? [self page:_next] : NO; }
@end

#pragma mark - Model catalog

NSString *const OR6Chat8CatalogDidChangeNotification = @"OR6Chat8CatalogDidChange";

// Efforts of one mode: [{id,title}] with unique IDs; nil when malformed.
static NSArray *O8Efforts(id v) {
    if (!v || v == [NSNull null]) return @[];
    if (![v isKindOfClass:[NSArray class]] || [v count] > 32) return nil; // the Model DTO's limits
    NSMutableArray *out = [NSMutableArray array]; NSMutableSet *seen = [NSMutableSet set];
    for (NSDictionary *e in v) {
        if (![e isKindOfClass:[NSDictionary class]] || !O8String(e[@"id"], 64) || !O8String(e[@"title"], 240) || [seen containsObject:e[@"id"]]) return nil;
        [seen addObject:e[@"id"]]; [out addObject:@{@"id": e[@"id"], @"title": e[@"title"]}];
    }
    return out;
}

// models.list → admitted items and the family/mode/effort presentation. A Model with any of the
// family/mode fields must carry all four valid; a flat legacy Model becomes its own family with one
// untitled mode. Duplicate send slugs and duplicate family/mode pairs keep the first entry.
static NSArray *O8Project(NSArray *raw, NSMutableArray *admitted, BOOL *structured) {
    NSMutableArray *families = [NSMutableArray array]; NSMutableDictionary *byKey = [NSMutableDictionary dictionary];
    NSMutableSet *ids = [NSMutableSet set], *pairs = [NSMutableSet set]; *structured = NO;
    for (NSDictionary *m in [raw isKindOfClass:[NSArray class]] ? raw : @[]) {
        if (![m isKindOfClass:[NSDictionary class]] || !O8String(m[@"id"], 128) || !O8String(m[@"title"], 240) || [ids containsObject:m[@"id"]]) continue;
        BOOL meta = m[@"familyId"] || m[@"familyTitle"] || m[@"modeId"] || m[@"modeTitle"];
        if (meta && !(O8String(m[@"familyId"], 128) && O8String(m[@"familyTitle"], 240) && O8String(m[@"modeId"], 128) && O8String(m[@"modeTitle"], 240))) continue;
        NSArray *efforts = O8Efforts(m[@"efforts"]); if (!efforts) continue;
        NSString *key = meta ? [@"f:" stringByAppendingString:m[@"familyId"]] : [@"m:" stringByAppendingString:m[@"id"]];
        NSString *pair = [NSString stringWithFormat:@"%@\n%@", key, meta ? m[@"modeId"] : m[@"id"]];
        if ([pairs containsObject:pair]) continue;
        [ids addObject:m[@"id"]]; [pairs addObject:pair]; [admitted addObject:m]; if (meta) *structured = YES;
        NSMutableDictionary *mode = [NSMutableDictionary dictionaryWithDictionary:@{@"id": meta ? m[@"modeId"] : m[@"id"], @"title": meta ? m[@"modeTitle"] : @"", @"modelId": m[@"id"], @"efforts": efforts}];
        id def = m[@"defaultEffort"]; if (O8String(def, 64) && [[efforts valueForKey:@"id"] containsObject:def]) mode[@"defaultEffort"] = def;
        NSMutableDictionary *family = byKey[key];
        if (!family) { family = [NSMutableDictionary dictionaryWithDictionary:@{@"id": meta ? m[@"familyId"] : m[@"id"], @"title": meta ? m[@"familyTitle"] : m[@"title"], @"modes": [NSMutableArray array]}]; byKey[key] = family; [families addObject:family]; }
        [family[@"modes"] addObject:mode];
    }
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *f in families) [out addObject:@{@"id": f[@"id"], @"title": f[@"title"], @"modes": [[f[@"modes"] copy] autorelease]}];
    return out;
}

@interface OR6Chat8Catalog () { OR6APICore *_core; NSUInteger _epoch; NSArray *_items, *_families; NSString *_chosen, *_effort, *_issue, *_serverDefault; BOOL _busy, _loaded, _structured, _dropped; id<OR6Chat8ModelDelegate> _delegate; }
@end
@implementation OR6Chat8Catalog
@synthesize delegate = _delegate, items = _items, families = _families, chosenModelId = _chosen, chosenEffort = _effort, busy = _busy, loaded = _loaded, structured = _structured, choiceDropped = _dropped, issue = _issue, catalogDefaultModelId = _serverDefault;
- (id)initWithCore:(OR6APICore *)core { if ((self = [super init])) { _core = [core retain]; _items = [@[] retain]; _families = [@[] retain]; } return self; }
- (void)dealloc { _delegate = nil; _epoch++; [_core release]; [_items release]; [_families release]; [_chosen release]; [_effort release]; [_issue release]; [_serverDefault release]; [super dealloc]; }
- (void)setIssue:(NSString *)i { NSString *n = [i copy]; [_issue release]; _issue = n; }
- (void)changed { [_delegate chat8ModelChanged:self]; [[NSNotificationCenter defaultCenter] postNotificationName:OR6Chat8CatalogDidChangeNotification object:self]; }
// Copies before releases: a reload passes the catalog's own _chosen/_effort back in.
- (void)setChosen:(NSString *)modelId effort:(NSString *)effort { NSString *m = [modelId copy], *e = modelId ? [effort copy] : nil; [_chosen release]; _chosen = m; [_effort release]; _effort = e; }
- (NSDictionary *)familyForModel:(NSString *)modelId {
    for (NSDictionary *f in _families) for (NSDictionary *m in f[@"modes"]) if ([m[@"modelId"] isEqual:modelId]) return f;
    return nil;
}
- (NSDictionary *)modeForModel:(NSString *)modelId {
    for (NSDictionary *f in _families) for (NSDictionary *m in f[@"modes"]) if ([m[@"modelId"] isEqual:modelId]) return m;
    return nil;
}
- (BOOL)effort:(NSString *)effort validFor:(NSString *)modelId { return !effort || [[[self modeForModel:modelId][@"efforts"] valueForKey:@"id"] containsObject:effort]; }
- (BOOL)load {
    if (_busy) return NO;
    _busy = YES; [self setIssue:nil]; NSUInteger epoch = ++_epoch;
    [_core perform:@"models.list" parameters:@{} event:nil completion:^(NSDictionary *r, NSError *e) {
        if (epoch != _epoch) return; _busy = NO;
        if (e) [self setIssue:O8Issue(e)];
        else {
            NSMutableArray *ok = [NSMutableArray array]; BOOL structured = NO; NSArray *families = O8Project(r[@"items"], ok, &structured);
            [_items release]; _items = [ok copy]; [_families release]; _families = [families retain]; _structured = structured; _loaded = YES;
            id def = r[@"selectedModelId"]; NSString *d = (O8String(def, 128) && [self modeForModel:def]) ? [def copy] : nil; [_serverDefault release]; _serverDefault = d;
            // A choice the new catalog no longer offers falls back explicitly: a missing mode to
            // Default, a missing effort to the mode's default effort. Valid choices are kept.
            _dropped = NO;
            if (_chosen && ![self modeForModel:_chosen]) { [self setChosen:nil effort:nil]; _dropped = YES; }
            else if (_chosen && ![self effort:_effort validFor:_chosen]) { [self setChosen:_chosen effort:nil]; _dropped = YES; } }
        [self changed];
    }];
    [self changed];
    return YES;
}
- (BOOL)select:(NSString *)modelId { return [self selectModel:modelId effort:nil]; }
// One local models.select; the reply must confirm the exact model and effort.
- (BOOL)perform:(NSString *)modelId effort:(NSString *)effort done:(void (^)(void))done {
    _busy = YES; _dropped = NO; [self setIssue:nil]; NSUInteger epoch = ++_epoch;
    NSMutableDictionary *p = [NSMutableDictionary dictionaryWithObject:modelId forKey:@"modelId"];
    if (_structured) p[@"thinkingEffort"] = effort ?: (id)[NSNull null]; // explicit: a null resets a previous effort
    void (^finish)(void) = [[done copy] autorelease];
    [_core perform:@"models.select" parameters:p event:nil completion:^(NSDictionary *r, NSError *e) {
        if (epoch != _epoch) return; _busy = NO;
        id got = r[@"thinkingEffort"]; if (got == [NSNull null]) got = nil;
        if (e || ![r[@"modelId"] isEqual:modelId] || (got != effort && ![got isEqual:effort])) [self setIssue:e ? O8Issue(e) : @"invalid_response"];
        else finish();
        [self changed];
    }];
    [self changed];
    return YES;
}
- (BOOL)selectModel:(NSString *)modelId effort:(NSString *)effort {
    if (_busy || !O8String(modelId, 128) || ![self modeForModel:modelId] || ![self effort:effort validFor:modelId]) return NO;
    NSString *m = [[modelId copy] autorelease], *f = [[effort copy] autorelease];
    return [self perform:m effort:f done:^{ [self setChosen:m effort:f]; }];
}
- (BOOL)canUseDefault { return !_chosen || _serverDefault != nil; }
- (BOOL)useDefault {
    if (_busy) return NO;
    if (!_chosen) return YES;
    // The provider keeps the last models.select for planned generations (temporary, files, edit…).
    // Going back selects the catalog's own default with no effort (local, no account request); if
    // the catalog named none, the choice cannot be undone honestly and stays.
    if (!_serverDefault) { [self setIssue:@"default_unknown"]; [self changed]; return NO; }
    return [self perform:[[_serverDefault copy] autorelease] effort:nil done:^{ [self setChosen:nil effort:nil]; }];
}
- (NSString *)sendModelId { return _chosen ?: @"web-current"; }
- (NSString *)sendThinkingEffort { return _chosen ? _effort : nil; }
- (NSString *)titleForModel:(NSString *)modelId effort:(NSString *)effortId {
    NSDictionary *f = [self familyForModel:modelId], *m = [self modeForModel:modelId]; if (!f) return nil;
    NSMutableArray *parts = [NSMutableArray arrayWithObject:f[@"title"]];
    if ([m[@"title"] length]) [parts addObject:m[@"title"]];
    for (NSDictionary *e in m[@"efforts"]) if ([e[@"id"] isEqual:effortId]) [parts addObject:e[@"title"]];
    return [parts componentsJoinedByString:@" · "];
}
- (NSString *)title { return _chosen ? [self titleForModel:_chosen effort:_effort] : nil; }
- (void)reset { _epoch++; _busy = NO; _loaded = NO; _structured = NO; _dropped = NO; [_items release]; _items = [@[] retain]; [_families release]; _families = [@[] retain]; [self setChosen:nil effort:nil]; [_serverDefault release]; _serverDefault = nil; [self setIssue:nil]; }
@end

#pragma mark - Translation

@interface OR6Chat8Translation () { OR6APICore *_core; id<OR6APITask> _task; NSUInteger _epoch; NSString *_result, *_issue, *_op, *_signature, *_refusal; BOOL _busy, _uncertain; id<OR6Chat8ModelDelegate> _delegate; }
@end
@implementation OR6Chat8Translation
@synthesize delegate = _delegate, busy = _busy, uncertain = _uncertain, result = _result, issue = _issue, operationId = _op, refusal = _refusal;
- (BOOL)refuse:(NSString *)why { [_refusal release]; _refusal = [why copy]; return NO; }
- (id)initWithCore:(OR6APICore *)core { if ((self = [super init])) _core = [core retain]; return self; }
- (void)dealloc { _delegate = nil; [self cancel]; [_core release]; [_result release]; [_issue release]; [_op release]; [_signature release]; [_refusal release]; [super dealloc]; }
- (BOOL)translate:(NSString *)text from:(NSString *)source to:(NSString *)target {
    if (_busy) return [self refuse:@"busy"];
    if (![text isKindOfClass:[NSString class]] || ![text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length || text.length > 16000 || !O8String(target, 64)) return [self refuse:@"invalid"];
    if (gToolsHalted) return [self refuse:@"restricted"];
    NSString *signature = O8Signature(@"translate", @[text, O8String(source, 64) ? source : @"", target]);
    if (O8IsUnresolved(signature)) return [self refuse:@"not_repeated"]; // the same request may already have run
    [_refusal release]; _refusal = nil; [_signature release]; _signature = [signature copy];
    NSString *op = OR6ChatUUID();
    [_op release]; _op = [op copy]; [_result release]; _result = nil; [_issue release]; _issue = nil; _uncertain = NO; _busy = YES;
    NSUInteger epoch = ++_epoch; __block BOOL finished = NO;
    id<OR6APITask> t = [_core perform:@"translation.translate" parameters:@{@"operationId": op, @"text": text, @"sourceLanguage": O8String(source, 64) ? source : (id)[NSNull null], @"targetLanguage": target} event:nil completion:^(NSDictionary *r, NSError *e) {
        finished = YES; if (epoch != _epoch) return;
        [_task release]; _task = nil; _busy = NO;
        if (e || ![r[@"text"] isKindOfClass:[NSString class]]) {
            _issue = [(e ? O8Issue(e) : @"invalid_response") copy]; _uncertain = !e || O8Possible(e);
            if (_uncertain) O8Unresolved(signature);
            if (OR6Chat8StopSignal(_issue)) gToolsHalted = YES;
        }
        else _result = [r[@"text"] copy];
        [_delegate chat8ModelChanged:self];
    }];
    if (!finished && epoch == _epoch) _task = [t retain];
    [_delegate chat8ModelChanged:self];
    return YES;
}
- (void)cancel {
    if (!_busy) return;
    // The request may already run on the service: it is not repeated, its result is not shown.
    _epoch++; [_task cancel]; [_task release]; _task = nil; _busy = NO; _uncertain = YES; O8Unresolved(_signature);
    [_issue release]; _issue = [@"cancelled" copy];
}
@end

#pragma mark - Downloads

@interface OR6Chat8Downloads () { OR6APICore *_core; NSMutableDictionary *_states, *_tasks, *_signatures; NSUInteger _epoch; id<OR6Chat8ModelDelegate> _delegate; }
@end
@implementation OR6Chat8Downloads
@synthesize delegate = _delegate;
- (id)initWithCore:(OR6APICore *)core { if ((self = [super init])) { _core = [core retain]; _states = [NSMutableDictionary new]; _tasks = [NSMutableDictionary new]; _signatures = [NSMutableDictionary new]; } return self; }
- (void)dealloc { _delegate = nil; [self cancelAll]; [_core release]; [_states release]; [_tasks release]; [_signatures release]; [super dealloc]; }
- (NSString *)keyFor:(NSString *)file message:(NSString *)message { return [NSString stringWithFormat:@"%@|%@", message ?: @"", file ?: @""]; }
- (NSDictionary *)stateForFile:(NSString *)fileId message:(NSString *)messageId { return _states[[self keyFor:fileId message:messageId]] ?: @{@"state": @"ready", @"progress": @0}; }
- (BOOL)download:(NSString *)fileId message:(NSString *)messageId conversation:(NSString *)conversationId {
    NSString *key = [self keyFor:fileId message:messageId], *signature = O8Signature(@"download", @[conversationId ?: @"", key]);
    if (!OR6Chat8FileID(fileId) || !O8String(messageId, 128) || !O8String(conversationId, 128) || gToolsHalted) return NO;
    // Only ready or a proven no-dispatch failure may start; unknown outcomes and stop signals never repeat.
    NSString *state = _states[key][@"state"];
    if ((state && ![@[@"ready", @"failed"] containsObject:state]) || O8IsUnresolved(signature)) return NO;
    NSString *op = OR6ChatUUID();
    _states[key] = @{@"state": @"downloading", @"progress": @0, @"operationId": op};
    NSUInteger epoch = _epoch; __block BOOL finished = NO;
    id<OR6APITask> t = [_core perform:@"assets.download" parameters:@{@"operationId": op, @"conversationId": conversationId, @"messageId": messageId, @"fileId": fileId} event:^(NSDictionary *event) {
        NSDictionary *p = event[@"payload"];
        if (epoch != _epoch || finished || ![p[@"operationId"] isEqual:op]) return;
        _states[key] = @{@"state": @"downloading", @"progress": @(MIN(1.0, [p[@"completedBytes"] doubleValue] / MAX(1.0, [p[@"totalBytes"] doubleValue]))), @"operationId": op};
        [_delegate chat8ModelChanged:self];
    } completion:^(NSDictionary *r, NSError *e) {
        finished = YES; if (epoch != _epoch) return; [_tasks removeObjectForKey:key]; [_signatures removeObjectForKey:key];
        if (e || !O8String(r[@"assetId"], 128)) {
            NSString *code = e ? O8Issue(e) : @"invalid_response";
            NSString *outcome = [code isEqual:@"not_found"] || [code isEqual:@"expired"] ? @"unavailable" : OR6Chat8StopSignal(code) ? @"blocked" : (!e || O8Possible(e)) ? @"uncertain" : @"failed";
            if ([outcome isEqual:@"uncertain"]) O8Unresolved(signature);
            if ([outcome isEqual:@"blocked"]) gToolsHalted = YES;
            _states[key] = @{@"state": outcome, @"progress": @0, @"issue": code};
        } else _states[key] = @{@"state": @"saved", @"progress": @1, @"assetId": r[@"assetId"], @"bytes": r[@"bytes"] ?: @0, @"name": r[@"name"] ?: @""};
        [_delegate chat8ModelChanged:self];
    }];
    if (!finished && epoch == _epoch) { _tasks[key] = t; [_signatures setObject:signature forKey:key]; }
    [_delegate chat8ModelChanged:self];
    return YES;
}
- (void)cancelAll {
    // A cancelled download may already have reached the service: unknown, not repeated.
    _epoch++;
    for (NSString *key in _tasks.allKeys) { [(id<OR6APITask>)_tasks[key] cancel]; O8Unresolved(_signatures[key]); _states[key] = @{@"state": @"uncertain", @"progress": @0, @"issue": @"cancelled"}; }
    [_tasks removeAllObjects]; [_signatures removeAllObjects];
}
@end

#pragma mark - Retry lock

#import "../priority9/OR6Chat9Actions.h"
BOOL OR6Chat8SyncRetryLock(OR6ChatConversationState *state, OR6Chat9Actions *actions, OR6Chat8Attachments *files, BOOL retryStage) {
    BOOL lock = retryStage && actions.canRetry;
    state.optionsLocked = lock; files.locked = lock;
    return lock;
}
