#import "OR6Chat20Screens.h"
#import "OR6Chat20Models.h"
#import "../priority6/OR6Chat6Base.h"
#import "RCGridViewController.h"
#import "RCImageViewerController.h"
#import "../priority7/OR6Chat7ImagePreview.h"
#import "../priority6/OR6Chat6Library.h"

static NSString *Text(id v) { return [v isKindOfClass:NSString.class] ? v : @""; }
static NSString *ComposeOp(NSString *kind) {
    return [kind isEqual:@"suggestions"] ? @"compose.suggestions" : [kind isEqual:@"autocomplete"] ? @"compose.autocomplete.get" : [kind isEqual:@"prediction"] ? @"compose.workPrediction.get" : @"skills.list";
}
static NSString *ComposeTitle(NSString *kind) {
    return [kind isEqual:@"suggestions"] ? OR6L(@"Conversation starters") : [kind isEqual:@"autocomplete"] ? OR6L(@"Complete my draft") : [kind isEqual:@"prediction"] ? OR6L(@"Suggested next request") : OR6L(@"Skills");
}

@interface OR6Chat20Skill : OR6Chat6Form {
    NSString *_skillId, *_seenReceipt, *_recoveryId; OR6Chat7Call *_pending; BOOL _pendingReady; OR6Chat7Write *_write; NSUInteger _generation; BOOL _visible;
}
- (id)initWithCore:(OR6APICore *)core skill:(NSDictionary *)skill;
@end
@implementation OR6Chat20Skill
- (id)initWithCore:(OR6APICore *)core skill:(NSDictionary *)skill {
    if ((self = [super initWithCore:core navigator:nil title:Text(skill[@"name"])])) { _skillId = [skill[@"id"] copy]; _generation = OR6Chat7Generation(core); _write = [[OR6Chat7Write alloc] initWithCore:core reconcile:@"skills.reconcile"]; _write.delegate = self; _pending = [self call]; } return self;
}
- (void)viewWillAppear:(BOOL)a { _visible = YES; [super viewWillAppear:a]; }
- (void)viewWillDisappear:(BOOL)a { [super viewWillDisappear:a]; _visible = NO; if (self.isMovingFromParentViewController) { [_read cancel]; [_write cancel]; } }
- (void)load { if (_generation == OR6Chat7Generation(_core)) { _pendingReady = NO; [_read perform:@"skills.get" parameters:@{@"skillId":_skillId}]; [_pending perform:@"skills.pending" parameters:@{@"skillId":_skillId}]; } }
- (void)render {
    NSMutableArray *rows = [NSMutableArray array]; NSDictionary *item = _read.result;
    if (_generation != OR6Chat7Generation(_core)) { item = nil; [rows addObject:[self note:OR6L(@"The session changed. Open this screen again.")]]; }
    if (item) {
        self.title = Text(item[@"displayName"]).length ? item[@"displayName"] : Text(item[@"name"]);
        [rows addObject:[self note:Text(item[@"description"])]];
        [rows addObject:[self value:OR6L(@"Status") value:[item[@"enabled"] boolValue] ? OR6L(@"Installed") : OR6L(@"Not installed") info:nil identifier:@"chat.skills.status"]];
        for (NSString *file in item[@"files"]) [rows addObject:[self note:file]];
        BOOL busy = [_write.phase isEqual:@"running"] || [_write.phase isEqual:@"reconciling"] || _pending.busy;
        BOOL unresolved = _recoveryId.length || [_write.phase isEqual:@"uncertain"] || ([_write.phase isEqual:@"done"] && !_write.verified);
        BOOL blocked = [_write.phase isEqual:@"blocked"] || OR6Chat7IsUnresolved([@"skill:" stringByAppendingString:_skillId]);
        if (!busy && unresolved && OR6Chat7Callable(_core, @"skills.reconcile")) [rows addObject:[self button:OR6L(@"Check result") info:@"check" identifier:@"chat.skills.check"]];
        else if (_pendingReady && !_pending.error && !busy && !unresolved && !blocked && !_read.busy && !_read.error && ![item[@"system"] boolValue] && [item[@"canRead"] boolValue]) {
            BOOL enabled = [item[@"enabled"] boolValue]; NSString *op = enabled ? @"skills.remove" : @"skills.install";
            if (OR6Chat7Callable(_core, op) && (enabled || [item[@"safety"] isEqual:@"allowed"])) [rows addObject:[self button:enabled ? OR6L(@"Remove skill") : OR6L(@"Install skill") info:op identifier:enabled ? @"chat.skills.remove" : @"chat.skills.install"]];
        }
        if (!busy && ![item[@"enabled"] boolValue] && ![item[@"safety"] isEqual:@"allowed"]) [rows addObject:[self note:OR6L(@"This skill is not approved for installation.")]];
        if (busy) [rows addObject:[self note:OR6L(@"Checking…")]];
        if (_write.error) [rows addObject:[self note:OR6Chat7ErrorText(_write.error)]];
        if (_pending.error) [rows addObject:[self note:OR6Chat7ErrorText(_pending.error)]];
    }
    [self addStateOf:_read to:rows empty:nil hasItems:item != nil identifier:@"chat.skills.detail"]; self.sections = @[[RCFormSection sectionWithTitle:nil rows:rows]];
}
- (void)chat8ModelChanged:(id)m {
    if (m == _pending && !_pending.busy && _generation == OR6Chat7Generation(_core)) {
        if ([_pending.operation isEqual:@"skills.pending"] && !_pending.error) {
            _pendingReady = YES; [_recoveryId release]; _recoveryId = [Text(_pending.result[@"operationId"]) copy];
        } else if ([_pending.operation isEqual:@"skills.reconcile"] && !_pending.error && [_pending.result[@"verified"] isEqual:@YES]) {
            OR6Chat7ForgetUnresolvedKey([@"skill:" stringByAppendingString:_skillId]); [_recoveryId release]; _recoveryId = nil; [self load];
        }
    }
    if (m == _write && [_write.phase isEqual:@"done"] && _write.verified && ![_seenReceipt isEqual:_write.operationId] && _visible && _generation == OR6Chat7Generation(_core)) {
        [_seenReceipt release]; _seenReceipt = [_write.operationId copy]; [self load];
    } [self render];
}
- (void)form:(RCFormViewController *)form didSelectRow:(RCFormRow *)row {
    NSString *op = [row.userInfo isKindOfClass:NSString.class] ? row.userInfo : nil;
    if ([op isEqual:@"check"]) { if (_write.operationId) [_write reconcile]; else if (_recoveryId.length) [_pending perform:@"skills.reconcile" parameters:@{@"operationId":_recoveryId}]; return; }
    if (![@[@"skills.install", @"skills.remove"] containsObject:op ?: @""]) { [super form:form didSelectRow:row]; return; }
    BOOL remove = [op isEqual:@"skills.remove"]; NSUInteger gen = _generation;
    OR6Chat6Confirm(self.view.window ?: self.view, self.title, remove ? OR6L(@"Remove skill") : OR6L(@"Install skill"), remove, ^{
        if (!_visible || gen != OR6Chat7Generation(_core)) return;
        [_write perform:op parameters:@{@"skillId":_skillId} intent:[@"skill:" stringByAppendingString:_skillId]];
    });
}
- (void)dealloc { _write.delegate = nil; [_write cancel]; [_write release]; [_skillId release]; [_seenReceipt release]; [_recoveryId release]; [super dealloc]; }
@end

@interface OR6Chat20Compose : OR6Chat6Form {
    NSString *_kind, *_original, *_scope; NSDictionary *_catalog; id<OR6Chat7ConversationHost> _host;
    NSUInteger _generation; BOOL _visible;
}
- (id)initWithCore:(OR6APICore *)core kind:(NSString *)kind host:(id<OR6Chat7ConversationHost>)host;
@end
@implementation OR6Chat20Compose
- (id)initWithCore:(OR6APICore *)core kind:(NSString *)kind host:(id<OR6Chat7ConversationHost>)host {
    if ((self = [super initWithCore:core navigator:[host chat7Navigator] title:ComposeTitle(kind)])) {
        _kind = [kind copy]; _host = host; _original = [[host chat7Composer].text copy]; _scope = [@"installed" copy]; _generation = OR6Chat7Generation(core);
    } return self;
}
- (void)viewWillAppear:(BOOL)a { _visible = YES; [super viewWillAppear:a]; }
- (void)viewWillDisappear:(BOOL)a { [super viewWillDisappear:a]; _visible = NO; [_read cancel]; }
- (void)load {
    if (_generation != OR6Chat7Generation(_core)) return;
    NSString *op = ComposeOp(_kind); NSDictionary *p = @{};
    if ([_kind isEqual:@"autocomplete"]) p = @{@"inputText": _original ?: @""};
    else if ([_kind isEqual:@"skills"]) p = @{@"scope": _scope};
    else if ([_kind isEqual:@"prediction"]) { NSString *cid = [_host chat7ConversationId]; p = cid ? @{@"conversationId":cid, @"expectedMessageId":[_host chat7LastMessageId] ?: (id)NSNull.null, @"generationTrigger":@"live"} : @{}; }
    [_read perform:op parameters:p]; [self render];
}
- (void)render {
    NSMutableArray *rows = [NSMutableArray array];
    if ([_kind isEqual:@"skills"]) [rows addObject:[self value:OR6L(@"Show") value:[self scopeTitle:_scope] info:@"scope" identifier:@"chat.skills.scope"]];
    if (_generation != OR6Chat7Generation(_core)) { [rows addObject:[self note:OR6L(@"The session changed. Open this screen again.")]]; }
    else {
        NSArray *items = [_catalog[@"items"] isKindOfClass:NSArray.class] ? _catalog[@"items"] : @[];
        for (NSDictionary *item in items) {
            NSString *name = Text(item[@"displayName"]); if (!name.length) name = Text(item[@"title"]); if (!name.length) name = Text(item[@"name"]); if (!name.length) name = Text(item[@"text"]);
            RCFormRow *r = [self value:name value:nil info:item identifier:[@"chat.compose20." stringByAppendingString:_kind]];
            r.subtitle = Text(item[@"description"]); r.enabled = !_read.busy; [rows addObject:r];
        }
        [self addStateOf:_read to:rows empty:OR6L(@"Nothing to show yet.") hasItems:items.count > 0 identifier:@"chat.compose20"];
    }
    self.sections = @[[RCFormSection sectionWithTitle:nil rows:rows]];
}
- (NSString *)scopeTitle:(NSString *)scope {
    NSDictionary *labels = @{@"installed":OR6L(@"Installed"), @"created":OR6L(@"Created by me"), @"shared-personal":OR6L(@"Shared with me"), @"workspace-shared":OR6L(@"Workspace")};
    return labels[scope] ?: scope;
}
- (void)chat8ModelChanged:(id)m {
    (void)m; if (!_visible || _read.busy || _generation != OR6Chat7Generation(_core)) { [self render]; return; }
    NSString *op = _read.operation;
    if (!_read.error && ([op isEqual:@"compose.suggestions.select"] || [op isEqual:@"compose.autocomplete.select"] || [op isEqual:@"compose.workPrediction.select"])) {
        NSString *selected = Text(_read.result[[_kind isEqual:@"suggestions"] ? @"prompt" : @"text"]);
        NSString *draft = OR6Chat20SelectedDraft([_host chat7Composer].text ?: @"", _original ?: @"", OR6Chat7Generation(_core), _generation, selected, [_kind isEqual:@"autocomplete"]);
        if (draft && [_host chat7Idle]) { [_host chat7SetDraftText:draft]; [self.navigationController popViewControllerAnimated:YES]; }
        else OR6Chat6Say(self.view.window ?: self.view, selected.length ? OR6L(@"The draft changed. Open the suggestions again.") : OR6L(@"This suggestion opens a feature that is not available here."));
    } else if (!_read.error && _read.result) {
        [_catalog release];
        if ([_kind isEqual:@"prediction"]) {
            NSString *suggestion = Text(_read.result[@"suggestion"]); NSString *response = Text(_read.result[@"responseId"]);
            _catalog = [@{@"items":suggestion.length && response.length ? @[@{@"text":suggestion, @"responseId":response}] : @[]} copy];
        } else _catalog = [_read.result copy];
    }
    [self render];
}
- (void)form:(RCFormViewController *)form didSelectRow:(RCFormRow *)row {
    id info = row.userInfo;
    if ([info isEqual:@"scope"]) {
        NSArray *scopes = @[@"installed", @"created", @"shared-personal", @"workspace-shared"]; NSMutableArray *titles = [NSMutableArray array]; for (NSString *s in scopes) [titles addObject:[self scopeTitle:s]];
        OR6Chat8ShowSheet(self.view.window ?: self.view, OR6L(@"Skills"), titles, nil, ^(NSInteger i, NSString *t) { (void)t; if (i >= 0 && i < (NSInteger)scopes.count && _visible && _generation == OR6Chat7Generation(_core)) { [_scope release]; _scope = [scopes[(NSUInteger)i] copy]; [_catalog release]; _catalog = nil; [self load]; } }); return;
    }
    if (![info isKindOfClass:NSDictionary.class]) { [super form:form didSelectRow:row]; return; }
    if (_read.busy || !_visible || _generation != OR6Chat7Generation(_core)) return;
    if ([_kind isEqual:@"skills"]) [self.navigationController pushViewController:[[[OR6Chat20Skill alloc] initWithCore:_core skill:info] autorelease] animated:YES];
    else if ([_kind isEqual:@"suggestions"]) [_read perform:@"compose.suggestions.select" parameters:@{@"catalogId":_catalog[@"catalogId"], @"suggestionId":info[@"id"]}];
    else if ([_kind isEqual:@"autocomplete"]) [_read perform:@"compose.autocomplete.select" parameters:@{@"referenceId":info[@"referenceId"], @"inputText":_original ?: @""}];
    else [_read perform:@"compose.workPrediction.select" parameters:@{@"responseId":info[@"responseId"]}];
    [self render];
}
- (void)dealloc { _host = nil; [_kind release]; [_original release]; [_scope release]; [_catalog release]; [super dealloc]; }
@end
UIViewController *OR6Chat20ComposeScreen(OR6APICore *core, NSString *kind, id<OR6Chat7ConversationHost> host) {
    if (!OR6Chat7Callable(core, ComposeOp(kind))) return nil;
    if ([kind isEqual:@"autocomplete"] && (![host chat7Composer].text.length || [host chat7Composer].text.length > 512)) return nil;
    return [[[OR6Chat20Compose alloc] initWithCore:core kind:kind host:host] autorelease];
}
NSArray *OR6Chat20DrawerEntries(OR6APICore *core) {
    NSMutableArray *entries = [NSMutableArray array];
    if (OR6Chat7Callable(core, @"images.library")) [entries addObject:@{@"key":@"images20", @"title":OR6L(@"Images"), @"glyph":@"images", @"identifier":@"chat.drawer.images"}];
    if (OR6Chat7Callable(core, @"codex.home")) [entries addObject:@{@"key":@"codex20", @"title":OR6L(@"Codex"), @"glyph":@"cloud", @"identifier":@"chat.drawer.codex"}];
    return entries;
}

@interface OR6Chat20CodexDetail : OR6Chat6Form { NSString *_identifier; BOOL _environment; }
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav identifier:(NSString *)identifier environment:(BOOL)environment;
@end
@implementation OR6Chat20CodexDetail
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav identifier:(NSString *)identifier environment:(BOOL)environment {
    if ((self = [super initWithCore:core navigator:nav title:environment ? OR6L(@"Environment") : OR6L(@"Codex task")])) { _identifier = [identifier copy]; _environment = environment; } return self;
}
- (void)load { [_read perform:_environment ? @"codex.environment.get" : @"codex.task.get" parameters:@{_environment ? @"environmentId" : @"taskId":_identifier}]; }
- (void)render {
    NSMutableArray *rows = [NSMutableArray array]; NSDictionary *r = _read.result;
    if (r) {
        NSString *title = Text(r[_environment ? @"label" : @"title"]); if (title.length) { self.title = title; [rows addObject:[self note:title]]; }
        if (Text(r[@"status"]).length) [rows addObject:[self value:OR6L(@"Status") value:r[@"status"] info:nil identifier:@"chat.codex.status"]];
        NSString *summary = Text(r[_environment ? @"description" : @"summary"]); if (summary.length) [rows addObject:[self note:summary]];
        if (!_environment && Text(r[@"environmentId"]).length && OR6Chat7Callable(_core, @"codex.environment.get")) [rows addObject:[self button:OR6L(@"Environment") info:r[@"environmentId"] identifier:@"chat.codex.environment"]];
    }
    [self addStateOf:_read to:rows empty:nil hasItems:r != nil identifier:@"chat.codex.detail"];
    self.sections = @[[RCFormSection sectionWithTitle:nil rows:rows]];
}
- (void)form:(RCFormViewController *)form didSelectRow:(RCFormRow *)row {
    if ([row.identifier isEqual:@"chat.codex.environment"]) [self.navigationController pushViewController:[[[OR6Chat20CodexDetail alloc] initWithCore:_core navigator:_nav identifier:row.userInfo environment:YES] autorelease] animated:YES];
    else [super form:form didSelectRow:row];
}
- (void)dealloc { [_identifier release]; [super dealloc]; }
@end
@interface OR6Chat20Codex : OR6Chat6Form { OR6Chat6Pager *_tasks; }
@end
@implementation OR6Chat20Codex
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav title:(NSString *)title {
    if ((self = [super initWithCore:core navigator:nav title:title])) _tasks = [self pager:@"codex.home" parameters:@{} tokenKey:@"pageToken" nextKey:@"nextPageToken" idKey:@"id"]; return self;
}
- (void)load { [_tasks reload]; }
- (void)render {
    NSMutableArray *tasks = [NSMutableArray array], *envs = [NSMutableArray array];
    for (NSDictionary *t in _tasks.items) { RCFormRow *r = [self value:Text(t[@"title"]) value:Text(t[@"status"]) info:@{@"task":t[@"id"]} identifier:@"chat.codex.task"]; r.enabled = OR6Chat7Callable(_core, @"codex.task.get"); [tasks addObject:r]; }
    [self addStateOfPager:_tasks to:tasks empty:OR6L(@"No Codex tasks yet.") identifier:@"chat.codex.home"];
    NSMutableSet *seen = [NSMutableSet set];
    for (NSDictionary *page in _tasks.pageResults) for (NSDictionary *e in page[@"environments"]) {
        if ([seen containsObject:e[@"id"]]) continue; [seen addObject:e[@"id"]];
        RCFormRow *r = [self value:Text(e[@"label"]) value:nil info:@{@"environment":e[@"id"]} identifier:@"chat.codex.environment_row"]; r.enabled = OR6Chat7Callable(_core, @"codex.environment.get"); [envs addObject:r];
    }
    NSMutableArray *sections = [NSMutableArray arrayWithObject:[RCFormSection sectionWithTitle:OR6L(@"Cloud tasks") rows:tasks]];
    if (envs.count) [sections addObject:[RCFormSection sectionWithTitle:OR6L(@"Environments") rows:envs]]; self.sections = sections;
}
- (void)form:(RCFormViewController *)form didSelectRow:(RCFormRow *)row {
    NSDictionary *info = [row.userInfo isKindOfClass:NSDictionary.class] ? row.userInfo : nil;
    if (info[@"task"] || info[@"environment"]) [self.navigationController pushViewController:[[[OR6Chat20CodexDetail alloc] initWithCore:_core navigator:_nav identifier:info[@"task"] ?: info[@"environment"] environment:info[@"environment"] != nil] autorelease] animated:YES];
    else [super form:form didSelectRow:row];
}
@end

@interface OR6Chat20Images : RCGridViewController <RCGridViewControllerDelegate, OR6Chat8ModelDelegate, RCImageViewerControllerDelegate> {
    OR6APICore *_core; id<OR6Chat7Navigator> _nav; OR6Chat6Pager *_pager; OR6Chat7Call *_open;
    BOOL _loaded, _visible, _wantsViewer, _previewsStopped; NSUInteger _generation, _previewBudget;
    NSString *_caption, *_openingId, *_requestedId; NSMutableDictionary *_thumbnails; NSMutableArray *_thumbnailOrder; NSMutableSet *_attempted;
}
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav;
@end
@implementation OR6Chat20Images
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav {
    if ((self = [super initWithStyle:RCGridStyleImages title:OR6L(@"Images")])) {
        _core = [core retain]; _nav = nav; _generation = OR6Chat7Generation(core); self.delegate = self; _previewBudget = 3;
        _thumbnails = [NSMutableDictionary new]; _thumbnailOrder = [NSMutableArray new]; _attempted = [NSMutableSet new];
        _pager = [[OR6Chat6Pager alloc] initWithCore:core operation:@"images.library" parameters:@{} tokenKey:@"pageToken" nextKey:@"nextPageToken" idKey:@"id"]; _pager.delegate = self;
        _open = [[OR6Chat7Call alloc] initWithCore:core]; _open.delegate = self; self.emptyGlyph = @"images";
    } return self;
}
- (void)viewWillAppear:(BOOL)a { _visible = YES; [super viewWillAppear:a]; if (!_loaded) { _loaded = YES; [_pager reload]; } [self render]; }
- (void)viewDidAppear:(BOOL)a { [super viewDidAppear:a]; [self schedulePreview]; }
- (void)viewWillDisappear:(BOOL)a { [super viewWillDisappear:a]; _visible = NO; [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(nextPreview) object:nil]; if (self.isMovingFromParentViewController) { [_pager cancel]; [_open cancel]; } }
- (UIImage *)thumbnail:(NSString *)identifier { return _thumbnails[identifier]; }
- (UIImage *)cacheThumbnail:(NSString *)identifier {
    UIImage *image = _thumbnails[identifier]; if (image) return image;
    NSData *data = OR6Chat7LoadedImageData(identifier); CGImageRef cg = data ? OR6Chat7PreviewThumbnail(data, 160) : NULL;
    if (!cg) return nil; image = [UIImage imageWithCGImage:cg]; CGImageRelease(cg); _thumbnails[identifier] = image; [_thumbnailOrder addObject:identifier];
    while (_thumbnailOrder.count > 16) { [_thumbnails removeObjectForKey:_thumbnailOrder[0]]; [_thumbnailOrder removeObjectAtIndex:0]; } return image;
}
- (void)render {
    NSMutableArray *items = [NSMutableArray array], *sections = [NSMutableArray array];
    for (NSDictionary *node in _pager.items) {
        RCGridItem *i = [RCGridItem itemWithTitle:Text(node[@"name"]) subtitle:nil glyph:@"photo" tile:RCTileBlue]; i.image = [self thumbnail:node[@"id"]]; i.fileIcon = YES; i.userInfo = node; [items addObject:i];
    }
    RCGridSection *s = [RCGridSection sectionWithTitle:nil items:items]; if (_pager.error) s.footer = OR6Chat7ErrorText(_pager.error); else if (_previewsStopped && _open.error) s.footer = OR6Chat7ErrorText(_open.error); else if (_pager.busy || _open.busy) s.footer = OR6L(@"Loading…"); [sections addObject:s];
    if (_pager.retryAvailable || _pager.hasMore) { RCGridItem *m = [RCGridItem itemWithTitle:_pager.retryAvailable ? OR6L(@"Read again") : OR6L(@"Show more") subtitle:nil glyph:@"down" tile:RCTileGray]; m.userInfo = _pager.retryAvailable ? @"retry" : @"more"; [sections addObject:[RCGridSection sectionWithTitle:nil items:@[m]]]; }
    self.sections = sections; self.emptyTitle = _pager.busy ? OR6L(@"Loading…") : OR6L(@"No images yet."); self.emptyText = _pager.error ? OR6Chat7ErrorText(_pager.error) : nil; self.tableView.accessibilityIdentifier = @"chat.images.library";
}
- (void)schedulePreview { [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(nextPreview) object:nil]; if (_visible && !_open.busy && !_previewsStopped) [self performSelector:@selector(nextPreview) withObject:nil afterDelay:0.1]; }
- (void)openImage:(NSString *)identifier viewer:(BOOL)viewer {
    if (_generation != OR6Chat7Generation(_core) || _open.busy || _previewsStopped) return;
    [_openingId release]; _openingId = [identifier copy]; _wantsViewer = viewer; [_attempted addObject:identifier];
    for (NSDictionary *n in _pager.items) if ([n[@"id"] isEqual:identifier]) { [_caption release]; _caption = [Text(n[@"name"]) copy]; break; }
    [_open perform:@"images.library.open" parameters:@{@"libraryId":identifier}];
}
- (void)nextPreview {
    if (!_visible || !self.view.window || UIApplication.sharedApplication.applicationState != UIApplicationStateActive || _open.busy || _pager.busy || _pager.error || _previewsStopped || _generation != OR6Chat7Generation(_core)) return;
    if (_requestedId) { NSString *identifier = [[_requestedId retain] autorelease]; [_requestedId release]; _requestedId = nil; [self openImage:identifier viewer:YES]; return; }
    if (!_previewBudget) return;
    // Three initial on-screen thumbnails at most; every other image waits for an explicit tap.
    NSUInteger count = MIN((NSUInteger)3, _pager.items.count);
    for (NSUInteger n = 0; n < count; n++) { NSDictionary *node = _pager.items[n]; if (![@[@"image/png", @"image/jpeg"] containsObject:node[@"mediaType"]]) continue; NSString *identifier = node[@"id"]; if ([_attempted containsObject:identifier] || [self thumbnail:identifier]) continue; _previewBudget--; [self openImage:identifier viewer:NO]; return; }
}
- (void)grid:(RCGridViewController *)grid didSelectItem:(RCGridItem *)item {
    (void)grid; if (_generation != OR6Chat7Generation(_core) || _previewsStopped) return; id info = item.userInfo;
    if ([info isEqual:@"more"]) { [_pager loadMore]; return; } if ([info isEqual:@"retry"]) { [_pager retry]; return; }
    if (![info isKindOfClass:NSDictionary.class]) return;
    if (!OR6Chat7Callable(_core, @"images.library.open")) { UIViewController *detail = OR6Chat6CreateLibraryItem(_core, info[@"id"], _nav); if (detail) [self.navigationController pushViewController:detail animated:YES]; return; }
    if (_open.busy) { [_requestedId release]; _requestedId = [info[@"id"] copy]; return; }
    [self openImage:info[@"id"] viewer:YES];
}
- (void)chat8ModelChanged:(id)m {
    if (m == _open && !_open.busy && _generation == OR6Chat7Generation(_core)) {
        if (_open.error) { if (OR6Chat8StopSignal(_open.error.userInfo[@"code"])) _previewsStopped = YES; if (_wantsViewer && _visible) OR6Chat6Say(self.view.window ?: self.view, OR6Chat7ErrorText(_open.error)); }
        else if (_visible) {
            [self cacheThumbnail:_openingId];
            if (_wantsViewer) {
                NSString *asset = _open.result[@"assetId"]; NSUInteger gen = _generation;
                [_core perform:@"images.gallery.prepare" parameters:@{@"assetId":asset ?: @""} event:nil completion:^(NSDictionary *r, NSError *e) {
                    if (!_visible || gen != OR6Chat7Generation(_core)) return;
                    NSData *data = !e && [r[@"available"] isEqual:@YES] ? OR6Chat7LoadedImageData(asset) : nil; CGImageRef cg = data ? OR6Chat7PreviewThumbnail(data, 2048) : NULL;
                    if (!cg) { OR6Chat6Say(self.view.window ?: self.view, e ? OR6Chat7ErrorText(e) : OR6L(@"The image is no longer available.")); return; }
                    UINavigationController *viewer = [RCImageViewerController navigationControllerWithImage:[UIImage imageWithCGImage:cg] caption:_caption delegate:self]; CGImageRelease(cg);
                    RCImageViewerController *v = (id)viewer.topViewController; v.saveAvailable = v.shareAvailable = v.editAvailable = NO; v.view.accessibilityIdentifier = @"chat.images.gallery"; [self presentViewController:viewer animated:YES completion:nil];
                }];
            }
        }
    }
    [self render]; [self schedulePreview];
}
- (void)imageViewerDidFinish:(RCImageViewerController *)viewer { viewer.delegate = nil; [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)dealloc { [NSObject cancelPreviousPerformRequestsWithTarget:self]; _pager.delegate = nil; [_pager cancel]; [_pager release]; _open.delegate = nil; [_open cancel]; [_open release]; [_core release]; [_caption release]; [_openingId release]; [_requestedId release]; [_thumbnails release]; [_thumbnailOrder release]; [_attempted release]; [super dealloc]; }
@end
UIViewController *OR6Chat20DrawerScreen(OR6APICore *core, NSString *key, id<OR6Chat7Navigator> navigator) {
    if ([key isEqual:@"images20"] && OR6Chat7Callable(core, @"images.library")) return [[[OR6Chat20Images alloc] initWithCore:core navigator:navigator] autorelease];
    if ([key isEqual:@"codex20"] && OR6Chat7Callable(core, @"codex.home")) return [[[OR6Chat20Codex alloc] initWithCore:core navigator:navigator title:OR6L(@"Codex")] autorelease];
    return nil;
}
