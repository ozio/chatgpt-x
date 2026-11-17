// Drawer collections and chat actions of API 7/10: Library (library.*), conversation
// files, archive (archives.list), projects (projects.*), read-only shared snapshots
// (shares.get) and the chat row/title actions (rename, pin, archive, delete, share link,
// move). Writes run through OR6Chat7Write: one operation ID, confirmation for destructive
// changes, «Проверить» (read-only reconcile) after an unknown result, never a resend.
#import "OR6Chat7Screens.h"
#import "../priority6/OR6Chat6Screens.h"
#import "../priority8/OR6Chat8Screens.h"
#import "RCGlyph.h"
#import "../../localization/OR6Localization.h"
#import "../../chat/OR6ChatUIState.h"
#import "RCFormViewController.h"
#import "RCGridViewController.h"
#import "RCShareLinkSheet.h"
#import "RCReportViewController.h"
#import "RCTheme.h"
#import "RCHUD.h"

static NSMutableArray *gProjects;
void OR6Chat7RememberProject(NSDictionary *p) {
    if (![p[@"projectId"] isKindOfClass:NSString.class] || ![p[@"name"] isKindOfClass:NSString.class]) return;
    if (!gProjects) gProjects = [NSMutableArray new];
    for (NSDictionary *o in [[gProjects copy] autorelease]) if ([o[@"projectId"] isEqual:p[@"projectId"]]) [gProjects removeObject:o];
    [gProjects insertObject:@{@"projectId": p[@"projectId"], @"name": p[@"name"]} atIndex:0];
    while (gProjects.count > 12) [gProjects removeLastObject];
}
NSArray *OR6Chat7RecentProjects(void) { return gProjects ? [[gProjects copy] autorelease] : @[]; }
void OR6Chat7ForgetSession(void) { [gProjects removeAllObjects]; OR6Chat7ForgetUnresolved(); }
BOOL OR6Chat7LibraryAvailable(OR6APICore *c) { return OR6Chat7On(c, @"library.list"); }
BOOL OR6Chat7ArchiveAvailable(OR6APICore *c) { return OR6Chat7On(c, @"archives.list"); }
BOOL OR6Chat7ProjectsAvailable(OR6APICore *c) { return OR6Chat7On(c, @"projects.get") && OR6Chat7On(c, @"routes.resolve"); }
BOOL OR6Chat7SharedViewAvailable(OR6APICore *c) { return OR6Chat7On(c, @"shares.get"); }
static BOOL UUIDString(NSString *s) { return s.length == 36 && [[NSRegularExpression regularExpressionWithPattern:@"^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$" options:0 error:NULL] numberOfMatchesInString:s options:0 range:NSMakeRange(0, s.length)] == 1; }
NSString *OR6Chat7ShareIdFromURL(NSURL *u) {
    if (![u.scheme.lowercaseString isEqual:@"https"] || ![u.host.lowercaseString isEqual:@"chatgpt.com"] || u.user || u.password || u.port || u.query || u.fragment) return nil;
    NSArray *c = [u.path componentsSeparatedByString:@"/"]; // "", "share", ["e",] id
    NSString *i = c.count == 3 && [c[1] isEqual:@"share"] ? c[2] : c.count == 4 && [c[1] isEqual:@"share"] && [c[2] isEqual:@"e"] ? c[3] : nil;
    return UUIDString(i) ? i.lowercaseString : nil;
}

#pragma mark - Write runner (alerts and HUDs for chat actions)

// Runners and share sheets stay alive until their write/sheet ends (no owner holds them).
static NSMutableSet *gLive;
static void Keep(id o) { if (!gLive) gLive = [NSMutableSet new]; [gLive addObject:o]; }
static void Drop(id o) { [[o retain] autorelease]; [gLive removeObject:o]; }

@interface OR6Chat7Runner : NSObject <OR6Chat8ModelDelegate, UIAlertViewDelegate> {
@public OR6Chat7Write *write; UIView *hud; NSString *done; void (^finished)(NSDictionary *receipt); RCHUD *busy;
}
@end
@implementation OR6Chat7Runner
+ (OR6Chat7Runner *)runWithCore:(OR6APICore *)core op:(NSString *)op params:(NSDictionary *)p intent:(NSString *)intent reconcile:(NSString *)rec view:(UIView *)view done:(NSString *)text finished:(void (^)(NSDictionary *))block {
    return [self runWithCore:core op:op params:p intent:intent reconcile:rec view:view done:text operationId:nil finished:block];
}
+ (OR6Chat7Runner *)runWithCore:(OR6APICore *)core op:(NSString *)op params:(NSDictionary *)p intent:(NSString *)intent reconcile:(NSString *)rec view:(UIView *)view done:(NSString *)text operationId:(NSString *)given finished:(void (^)(NSDictionary *))block {
    if (OR6Chat7IsUnresolved(intent)) { [RCHUD showText:OR6L(@"The previous attempt has an unknown result. It is not sent again; check the chat first.") kind:RCHUDTextOnly inView:view seconds:2.2]; return nil; }
    OR6Chat7Runner *r = [[[OR6Chat7Runner alloc] init] autorelease]; Keep(r); // kept until the write ends
    r->write = [[OR6Chat7Write alloc] initWithCore:core reconcile:rec]; r->write.delegate = r; r->hud = [view retain]; r->done = [text copy]; r->finished = [block copy];
    r->busy = [[RCHUD showText:OR6L(@"Saving…") kind:RCHUDBusy inView:view seconds:0] retain];
    if (![r->write perform:op parameters:p intent:intent operationId:given]) { [r->busy hide]; [RCHUD showText:OR6L(@"This change cannot be sent now.") kind:RCHUDTextOnly inView:view seconds:1.6]; [r end]; return nil; }
    return r;
}
- (void)chat8ModelChanged:(id)m {
    (void)m; NSString *p = write.phase;
    if ([p isEqual:@"running"] || [p isEqual:@"reconciling"]) return;
    [busy hide]; [busy release]; busy = nil;
    // A receipt can state the outcome itself without an error (API6B/6D/6F): rejected = not made,
    // uncertain = unknown (latched, only the read-only check is offered), never shown as done.
    NSString *state = [write.receipt[@"state"] isKindOfClass:NSString.class] ? write.receipt[@"state"] : nil;
    if ([p isEqual:@"done"] && [state isEqual:@"rejected"]) { [RCHUD showText:OR6L(@"The service did not make this change.") kind:RCHUDTextOnly inView:hud seconds:2.2]; [self end]; return; }
    if ([p isEqual:@"done"] && [state isEqual:@"uncertain"]) { OR6Chat7MarkUnresolved(write.intent); p = @"uncertain"; }
    if ([p isEqual:@"done"]) {
        [RCHUD showText:(write.verified ? done : [NSString stringWithFormat:@"%@ %@", done, OR6L(@"(not read back yet)")]) kind:RCHUDDone inView:hud seconds:1.4];
        if (finished) finished(write.receipt);
        [self end]; return;
    }
    if ([p isEqual:@"uncertain"]) {
        UIAlertView *a = [[[UIAlertView alloc] initWithTitle:OR6L(@"Result unknown") message:OR6L(@"The connection ended before the service confirmed the change. It is not sent again. Check the current state?") delegate:self cancelButtonTitle:OR6L(@"Later") otherButtonTitles:OR6L(@"Check"), nil] autorelease];
        [a show]; return;
    }
    [RCHUD showText:OR6Chat7ErrorText(write.error) kind:RCHUDTextOnly inView:hud seconds:2.2];
    [self end];
}
- (void)alertView:(UIAlertView *)a clickedButtonAtIndex:(NSInteger)i {
    if (i != a.cancelButtonIndex && [write reconcile]) { busy = [[RCHUD showText:OR6L(@"Checking…") kind:RCHUDBusy inView:hud seconds:0] retain]; return; }
    [self end];
}
- (void)end { write.delegate = nil; Drop(self); }
- (void)dealloc { [write release]; [hud release]; [done release]; [finished release]; [busy release]; [super dealloc]; }
@end

BOOL OR6Chat7RunWrite(UIView *view, OR6APICore *core, NSString *op, NSDictionary *p, NSString *intent, NSString *rec, NSString *text, void (^finished)(NSDictionary *)) {
    return [OR6Chat7Runner runWithCore:core op:op params:p intent:intent reconcile:rec view:view done:text finished:finished] != nil;
}
BOOL OR6Chat7RunWriteWithId(UIView *view, OR6APICore *core, NSString *op, NSDictionary *p, NSString *intent, NSString *rec, NSString *text, NSString *operationId, void (^finished)(NSDictionary *)) {
    return operationId && [OR6Chat7Runner runWithCore:core op:op params:p intent:intent reconcile:rec view:view done:text operationId:operationId finished:finished] != nil;
}

#pragma mark - Base list form

@interface OR6Chat7ListForm : RCFormViewController <RCFormDelegate, OR6Chat8ModelDelegate, UIActionSheetDelegate> {
@protected OR6APICore *_core; id<OR6Chat7Navigator> _nav; OR6Chat7Call *_read; BOOL _loaded; NSDictionary *_sheetItem;
}
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav title:(NSString *)title;
@end
@implementation OR6Chat7ListForm
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav title:(NSString *)title {
    if ((self = [super init])) { _core = [core retain]; _nav = nav; self.title = title; self.delegate = self; _read = [[OR6Chat7Call alloc] initWithCore:core]; _read.delegate = self; }
    return self;
}
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; if (!_loaded) { _loaded = YES; [self load]; } [self render]; }
- (void)load {}
- (void)render {}
- (void)chat8ModelChanged:(id)m { (void)m; self.busy = NO; [self render]; }
- (RCFormRow *)note:(NSString *)t { return [RCFormRow rowWithKind:RCFormRowNote title:t]; }
- (RCFormRow *)button:(NSString *)t info:(id)info identifier:(NSString *)i { RCFormRow *r = [RCFormRow rowWithKind:RCFormRowButton title:t]; r.userInfo = info; r.identifier = i; return r; }
- (void)dealloc { _read.delegate = nil; [_read cancel]; [_read release]; [_core release]; [_sheetItem release]; [super dealloc]; }
@end

#pragma mark - Archive (archives.list; unarchive/delete only when live_verified)

@interface OR6Chat7ArchiveScreen : OR6Chat7ListForm { NSMutableArray *_items; NSNumber *_next; }
@end
@implementation OR6Chat7ArchiveScreen
- (void)load { [_items release]; _items = [NSMutableArray new]; [_next release]; _next = nil; [_read perform:@"archives.list" parameters:@{@"offset": @0, @"limit": @20}]; }
- (void)chat8ModelChanged:(id)m {
    if (m == _read && !_read.busy && !_read.error && [_read.result[@"items"] isKindOfClass:NSArray.class]) {
        NSMutableSet *seen = [NSMutableSet set]; for (NSDictionary *i in _items) [seen addObject:i[@"id"]];
        for (NSDictionary *i in _read.result[@"items"]) if (![seen containsObject:i[@"id"]]) [_items addObject:i];
        [_next release]; _next = [_read.result[@"nextOffset"] isKindOfClass:NSNumber.class] ? [_read.result[@"nextOffset"] retain] : nil;
    }
    [super chat8ModelChanged:m];
}
- (void)render {
    NSMutableArray *rows = [NSMutableArray array];
    for (NSDictionary *i in _items) { RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:([i[@"title"] length] ? i[@"title"] : OR6L(@"Untitled"))]; r.disclosure = YES; r.userInfo = i; r.identifier = @"chat.archive.row"; [rows addObject:r]; }
    if (_read.busy) [rows addObject:[self note:OR6L(@"Loading…")]];
    else if (_read.error) { [rows addObject:[self note:OR6Chat7ErrorText(_read.error)]]; if (OR6Chat7Retryable(_read.error)) [rows addObject:[self button:OR6L(@"Read again") info:@"retry" identifier:@"chat.archive.retry"]]; }
    else if (_next) [rows addObject:[self button:OR6L(@"Show more") info:@"more" identifier:@"chat.archive.more"]];
    else if (!_items.count && _loaded) [rows addObject:[self note:OR6L(@"No archived chats.")]];
    RCFormSection *s = [RCFormSection sectionWithTitle:nil rows:rows];
    self.sections = @[s];
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    (void)f; id i = row.userInfo;
    if ([i isEqual:@"retry"]) { if (!OR6Chat7Retryable(_read.error)) return; if (_next) [_read perform:@"archives.list" parameters:@{@"offset": _next, @"limit": @20}]; else [self load]; return; }
    if ([i isEqual:@"more"]) { [_read perform:@"archives.list" parameters:@{@"offset": _next, @"limit": @20}]; return; }
    if (![i isKindOfClass:NSDictionary.class]) return;
    [_sheetItem release]; _sheetItem = [i retain];
    UIActionSheet *s = [[[UIActionSheet alloc] initWithTitle:row.title delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:OR6L(@"Open"), nil] autorelease];
    if (OR6Chat7On(_core, @"conversations.unarchive")) [s addButtonWithTitle:OR6L(@"Return from archive")];
    if (OR6Chat7On(_core, @"conversations.delete")) s.destructiveButtonIndex = [s addButtonWithTitle:OR6L(@"Delete")];
    s.cancelButtonIndex = [s addButtonWithTitle:OR6L(@"Cancel")];
    [s showInView:self.view.window ?: self.view];
}
- (void)actionSheet:(UIActionSheet *)s clickedButtonAtIndex:(NSInteger)n {
    NSDictionary *i = [[_sheetItem retain] autorelease]; if (n == s.cancelButtonIndex || !i) return;
    NSString *t = [s buttonTitleAtIndex:n];
    if ([t isEqual:OR6L(@"Open")]) [_nav chat7OpenConversation:i[@"id"] title:i[@"title"]];
    else OR6Chat7RunConversationAction(self, _core, [t isEqual:OR6L(@"Delete")] ? @"delete" : @"unarchive", @{@"id": i[@"id"], @"title": i[@"title"] ?: @"", @"archived": @YES}, _nav);
}
- (void)dealloc { [_items release]; [_next release]; [super dealloc]; }
@end

#pragma mark - Library (library.list/search/get, conversationFiles; attach when live_verified)

@interface OR6Chat7LibraryScreen : RCGridViewController <RCGridViewControllerDelegate, OR6Chat8ModelDelegate> {
    OR6APICore *_core; id<OR6Chat7Navigator> _nav; OR6Chat7Call *_read; NSMutableArray *_items; NSString *_next, *_query, *_conversation; NSTimer *_timer; BOOL _loaded;
}
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav conversation:(NSString *)conversation;
@end
@interface OR6Chat7LibraryItemScreen : OR6Chat7ListForm { NSDictionary *_item; OR6Chat7Call *_attach; }
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav item:(NSDictionary *)item;
@end
@implementation OR6Chat7LibraryScreen
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav conversation:(NSString *)conversation {
    if ((self = [super initWithStyle:RCGridStyleLibrary title:(conversation ? OR6L(@"Files in this chat") : OR6L(@"Library"))])) {
        _core = [core retain]; _nav = nav; _conversation = [conversation copy]; _items = [NSMutableArray new]; self.delegate = self;
        _read = [[OR6Chat7Call alloc] initWithCore:core]; _read.delegate = self;
        if (!conversation && OR6Chat7On(core, @"library.search")) self.searchPlaceholder = OR6L(@"Search in Library");
        self.emptyGlyph = @"library";
    }
    return self;
}
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; if (!_loaded) { _loaded = YES; [self page:nil]; } [self render]; }
- (void)page:(NSString *)token {
    NSMutableDictionary *p = [NSMutableDictionary dictionaryWithObjectsAndKeys:(token ?: (id)NSNull.null), @"pageToken", @25, @"limit", nil];
    NSString *op = @"library.list";
    if (_conversation) { op = @"library.conversationFiles"; p[@"conversationId"] = _conversation; }
    else if (_query.length) { op = @"library.search"; p[@"query"] = _query; }
    if (!token) { [_items removeAllObjects]; [_next release]; _next = nil; }
    if (![_read perform:op parameters:p]) [self render];
}
- (void)chat8ModelChanged:(id)m {
    if (m == _read && !_read.busy && !_read.error && [_read.result[@"items"] isKindOfClass:NSArray.class]) {
        [_items addObjectsFromArray:_read.result[@"items"]]; [_next release]; _next = [_read.result[@"nextPageToken"] isKindOfClass:NSString.class] ? [_read.result[@"nextPageToken"] copy] : nil;
    }
    [self render];
}
- (void)render {
    NSMutableArray *items = [NSMutableArray array];
    for (NSDictionary *i in _items) {
        NSString *size = [i[@"bytes"] isKindOfClass:NSNumber.class] ? OR6Chat8Bytes([i[@"bytes"] unsignedLongLongValue]) : nil;
        NSString *sub = [[NSArray arrayWithObjects:(([i[@"mediaType"] isKindOfClass:NSString.class]) ? i[@"mediaType"] : OR6L(@"File")), (size ?: @""), nil] componentsJoinedByString:@" · "];
        BOOL picture = [i[@"mediaType"] isKindOfClass:NSString.class] && [i[@"mediaType"] hasPrefix:@"image/"];
        RCGridItem *g = [RCGridItem itemWithTitle:i[@"name"] subtitle:sub glyph:(picture ? @"photo" : @"file") tile:([i[@"canAttach"] isEqual:@YES] ? RCTileBlue : RCTileGray)];
        g.fileIcon = YES; if(picture)g.image=OR6Chat8LocalThumbnail(i[@"fileId"]); g.showsDisclosure = YES; g.userInfo = i; [items addObject:g];
    }
    NSMutableArray *sections = [NSMutableArray array];
    // Stage 6 (API6C): folders, favorites, trash, connected sources, «use in answers» — only when granted.
    NSMutableArray *six = [NSMutableArray array];
    if (!_conversation && !_query.length) for (NSDictionary *e in OR6Chat6LibraryEntries(_core)) { RCGridItem *g = [RCGridItem itemWithTitle:e[@"title"] subtitle:e[@"subtitle"] glyph:e[@"glyph"] tile:(RCTileColor)[e[@"tile"] intValue]]; g.showsDisclosure = YES; g.userInfo = @{@"stage6": e[@"key"]}; [six addObject:g]; }
    if (six.count) [sections addObject:[RCGridSection sectionWithTitle:nil items:six]];
    RCGridSection *s = [RCGridSection sectionWithTitle:(six.count && items.count ? OR6L(@"Files") : nil) items:items];
    if (_read.busy) s.footer = OR6L(@"Loading…"); else if (_read.error) s.footer = OR6Chat7ErrorText(_read.error);
    [sections addObject:s];
    if (!_read.busy && ((_next && !_read.error) || OR6Chat7Retryable(_read.error))) { RCGridItem *more = [RCGridItem itemWithTitle:(_read.error ? OR6L(@"Read again") : OR6L(@"Show more")) subtitle:nil glyph:@"down" tile:RCTileGray]; more.userInfo = _read.error ? @"retry" : @"more"; [sections addObject:[RCGridSection sectionWithTitle:nil items:@[more]]]; }
    self.sections = sections;
    self.emptyTitle = _read.busy ? OR6L(@"Loading…") : _query.length ? OR6L(@"Nothing found") : OR6L(@"No files");
    self.emptyText = _read.error ? OR6Chat7ErrorText(_read.error) : nil;
    self.tableView.accessibilityIdentifier = _conversation ? @"chat.conversation.files" : @"chat.library";
}
- (void)grid:(RCGridViewController *)g didSelectItem:(RCGridItem *)item {
    (void)g; id i = item.userInfo;
    if ([i isEqual:@"more"]) { [self page:_next]; return; }
    if ([i isEqual:@"retry"]) { if (OR6Chat7Retryable(_read.error)) [self page:_next]; return; }
    if ([i isKindOfClass:NSDictionary.class] && i[@"stage6"]) { UIViewController *c = OR6Chat6CreateLibraryScreen(_core, i[@"stage6"], _nav); if (c) [self.navigationController pushViewController:c animated:YES]; return; }
    if ([i isKindOfClass:NSDictionary.class]) [self.navigationController pushViewController:[[[OR6Chat7LibraryItemScreen alloc] initWithCore:_core navigator:_nav item:i] autorelease] animated:YES];
}
// One request after typing pauses (0.45 s), like the history search.
- (void)grid:(RCGridViewController *)g searchTextDidChange:(NSString *)text {
    (void)g; [_timer invalidate]; _timer = nil; [_query release]; _query = [[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] copy];
    [_read cancel]; _timer = [NSTimer scheduledTimerWithTimeInterval:.45 target:self selector:@selector(searchTimer:) userInfo:nil repeats:NO];
}
- (void)searchTimer:(NSTimer *)t { (void)t; _timer = nil; [self page:nil]; }
- (void)viewWillDisappear:(BOOL)a { [super viewWillDisappear:a]; [_timer invalidate]; _timer = nil; }
- (void)dealloc { [_timer invalidate]; _read.delegate = nil; [_read cancel]; [_read release]; [_core release]; [_items release]; [_next release]; [_query release]; [_conversation release]; [super dealloc]; }
@end

@implementation OR6Chat7LibraryItemScreen
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav item:(NSDictionary *)item {
    if ((self = [super initWithCore:core navigator:nav title:item[@"name"]])) { _item = [item copy]; _attach = [[OR6Chat7Call alloc] initWithCore:core]; _attach.delegate = self; }
    return self;
}
- (void)load { [_read perform:@"library.get" parameters:@{@"libraryId": _item[@"id"]}]; } // fresh detail before any attach
- (NSDictionary *)item { return [_read.result[@"id"] isEqual:_item[@"id"]] ? _read.result : _item; }
- (void)render {
    NSDictionary *i = [self item]; NSMutableArray *rows = [NSMutableArray array];
    void (^v)(NSString *, id) = ^(NSString *t, id x) { RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:t]; r.value = [x isKindOfClass:NSString.class] ? x : [x isKindOfClass:NSNumber.class] ? [x description] : OR6L(@"Unknown"); [rows addObject:r]; };
    v(OR6L(@"Name"), i[@"name"]); v(OR6L(@"Type"), i[@"mediaType"]);
    v(OR6L(@"Size"), [i[@"bytes"] isKindOfClass:NSNumber.class] ? OR6Chat8Bytes([i[@"bytes"] unsignedLongLongValue]) : nil);
    v(OR6L(@"State"), i[@"state"]); v(OR6L(@"Access"), [i[@"access"] isEqual:@"owned"] ? OR6L(@"Yours") : [i[@"access"] isEqual:@"shared"] ? OR6L(@"Shared with you") : [i[@"access"] isEqual:@"mounted"] ? OR6L(@"Connected source") : OR6L(@"Unknown"));
    NSMutableArray *sections = [NSMutableArray arrayWithObject:[RCFormSection sectionWithTitle:nil rows:rows]];
    NSMutableArray *act = [NSMutableArray array];
    if (_read.busy) [act addObject:[self note:OR6L(@"Checking the file…")]];
    else if (_read.error) [act addObject:[self note:OR6Chat7ErrorText(_read.error)]];
    BOOL can = !_read.busy && !_read.error && [i[@"canAttach"] isEqual:@YES];
    NSString *draft = [_nav chat7CurrentDraftId];
    if (can && OR6Chat7On(_core, @"library.attach") && draft) { RCFormRow *b = [self button:OR6L(@"Add to message") info:@"attach" identifier:@"chat.library.attach"]; b.busy = _attach.busy; [act addObject:b]; }
    else if (can && OR6Chat7On(_core, @"library.attach")) [act addObject:[self note:OR6L(@"Open a chat and start typing to add this file to a message.")]];
    else if (![i[@"canAttach"] isEqual:@YES]) [act addObject:[self note:OR6L(@"This file cannot be added to a message from ChatGPT X (only your own ready documents up to 8 MB).")]];
    if (_attach.error) [act addObject:[self note:OR6Chat7ErrorText(_attach.error)]];
    RCFormSection *a = [RCFormSection sectionWithTitle:nil rows:act]; a.footer = OR6Chat7On(_core, @"library.attach") ? nil : OR6Chat7WriteClosedNote();
    [sections addObject:a];
    self.sections = sections;
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    (void)f; NSString *draft = [_nav chat7CurrentDraftId];
    if ([row.userInfo isEqual:@"attach"] && draft) [_attach perform:@"library.attach" parameters:@{@"libraryId": _item[@"id"], @"draftId": draft, @"replaceAssetId": NSNull.null}];
}
- (void)chat8ModelChanged:(id)m {
    if (m == _attach && !_attach.busy && !_attach.error && _attach.result) {
        if ([_nav chat7AttachLibraryDraft:_attach.result item:[self item]]) { [RCHUD showText:OR6L(@"Added to the message. Nothing is sent until you tap Send.") kind:RCHUDDone inView:self.view.window seconds:1.6]; [self.navigationController popToRootViewControllerAnimated:YES]; return; }
    }
    [super chat8ModelChanged:m];
}
- (void)dealloc { _attach.delegate = nil; [_attach cancel]; [_attach release]; [_item release]; [super dealloc]; }
@end

#pragma mark - Projects

// https://chatgpt.com/g/g-p-<32 hex>[-slug]/project → chatgpt://project/<id>, then routes.resolve
// validates it and projects.get proves it; nothing else is accepted.
static NSString *ProjectRoute(NSString *text) {
    NSString *t = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]; NSURL *u = [NSURL URLWithString:t];
    if ([@[@"chatgpt", @"openai", @"com.openai.chat"] containsObject:u.scheme.lowercaseString ?: @""]) return t;
    if (![u.scheme.lowercaseString isEqual:@"https"] || ![u.host.lowercaseString isEqual:@"chatgpt.com"] || u.query || u.fragment) return nil;
    NSTextCheckingResult *m = [[NSRegularExpression regularExpressionWithPattern:@"^/g/(g-p-[0-9a-f]{32})(-[A-Za-z0-9-]*)?/project/?$" options:0 error:NULL] firstMatchInString:u.path options:0 range:NSMakeRange(0, u.path.length)];
    return m ? [@"chatgpt://project/" stringByAppendingString:[u.path substringWithRange:[m rangeAtIndex:1]]] : nil;
}
@interface OR6Chat7ProjectsScreen : OR6Chat7ListForm <UIAlertViewDelegate> { OR6Chat7Call *_list; NSMutableArray *_listItems; NSString *_listNext, *_query; NSTimer *_queryTimer; }
@end
@implementation OR6Chat7ProjectsScreen
// Stage 6 (API6C projects.list): the account's own projects, paged; the link entry stays.
- (BOOL)listed { return OR6Chat6On(_core, @"projects.list"); }
- (void)load { if ([self listed]) [self loadList:YES]; }
- (void)loadList:(BOOL)first {
    if (!_list) { _list = [[OR6Chat7Call alloc] initWithCore:_core]; _list.delegate = self; }
    if (first) { [_listItems release]; _listItems = [NSMutableArray new]; [_listNext release]; _listNext = nil; }
    [_list perform:@"projects.list" parameters:@{@"pageToken": _listNext ?: (id)NSNull.null, @"query": _query ?: @""}]; // query: a filter over each server page
}
- (void)render {
    if ([self listed]) { [self renderListed]; return; }
    NSMutableArray *rows = [NSMutableArray array];
    for (NSDictionary *p in OR6Chat7RecentProjects()) { RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:p[@"name"]]; r.glyph = @"folder"; r.tile = RCTileTeal; r.disclosure = YES; r.userInfo = p; r.identifier = @"chat.projects.row"; [rows addObject:r]; }
    if (!rows.count) [rows addObject:[self note:OR6L(@"Projects you open by link appear here until you log out.")]];
    RCFormSection *recent = [RCFormSection sectionWithTitle:OR6L(@"Recent") rows:rows];
    RCFormRow *open = [self button:OR6L(@"Open by link…") info:@"open" identifier:@"chat.projects.open"]; open.busy = _read.busy;
    NSMutableArray *a = [NSMutableArray arrayWithObject:open]; if (_read.error) [a addObject:[self note:OR6Chat7ErrorText(_read.error)]];
    RCFormSection *s = [RCFormSection sectionWithTitle:nil rows:a];
    s.footer = OR6L(@"ChatGPT X cannot list your projects: the service has no such request in this build. Paste a project link from the web version (chatgpt.com/g/…/project).");
    self.sections = @[recent, s];
}
- (void)renderListed {
    NSMutableArray *rows = [NSMutableArray array], *top = [NSMutableArray array];
    RCFormRow *q = [RCFormRow rowWithKind:RCFormRowText title:OR6L(@"Search")]; q.text = _query; q.placeholder = OR6L(@"Search projects"); q.maxLength = 256; q.identifier = @"chat.projects.search"; [top addObject:q];
    if (OR6Chat6ProjectCreateAvailable(_core)) {
        UIBarButtonItem *create = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(createProject)] autorelease];
        create.accessibilityLabel = OR6L(@"New project…"); self.navigationItem.rightBarButtonItem = create;
    } else self.navigationItem.rightBarButtonItem = nil;
    for (NSDictionary *p in _listItems) { RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:p[@"name"]]; r.glyph = @"folder"; r.tile = RCTileTeal; r.disclosure = YES; r.userInfo = p; r.identifier = @"chat.projects.row"; [rows addObject:r]; }
    if (_list.busy) [rows addObject:[self note:OR6L(@"Loading…")]];
    else if (_list.error) { [rows addObject:[self note:OR6Chat7ErrorText(_list.error)]]; if (OR6Chat7Retryable(_list.error)) [rows addObject:[self button:OR6L(@"Read again") info:@"list" identifier:@"chat.projects.retry"]]; }
    else if (_listNext) [rows addObject:[self button:OR6L(@"Show more") info:@"list-more" identifier:@"chat.projects.more"]];
    else if (!_listItems.count && _list.result) [rows addObject:[self note:(_query.length ? OR6L(@"Nothing found.") : OR6L(@"No projects yet."))]];
    if (_query.length && [_list.result[@"scanned"] isKindOfClass:NSNumber.class] && !_list.busy && _listNext) [rows addObject:[self note:OR6L(@"Search looks through one page of projects at a time. Show more to look further.")]];
    RCFormRow *open = [self button:OR6L(@"Open by link…") info:@"open" identifier:@"chat.projects.open"]; open.busy = _read.busy;
    NSMutableArray *a = [NSMutableArray arrayWithObject:open]; if (_read.error) [a addObject:[self note:OR6Chat7ErrorText(_read.error)]];
    self.sections = @[[RCFormSection sectionWithTitle:nil rows:top], [RCFormSection sectionWithTitle:nil rows:rows], [RCFormSection sectionWithTitle:nil rows:a]];
}
- (void)form:(RCFormViewController *)f didChangeTextOfRow:(RCFormRow *)row {
    (void)f; if (![row.identifier isEqual:@"chat.projects.search"]) return;
    NSString *t = [row.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]; if ([t isEqual:_query ?: @""]) return;
    [_query release]; _query = [t copy]; [_queryTimer invalidate]; _queryTimer = [NSTimer scheduledTimerWithTimeInterval:.45 target:self selector:@selector(queryTimer:) userInfo:nil repeats:NO]; // one read after typing pauses
}
- (void)createProject {
    if (!OR6Chat6ProjectCreateAvailable(_core)) return;
    UIViewController *c = OR6Chat6CreateProjectEditor(_core, nil, ^(NSString *projectId) { [self loadList:YES]; if (projectId) [_nav chat7OpenProject:projectId]; });
    if (c) [self.navigationController pushViewController:c animated:YES];
}
- (void)queryTimer:(NSTimer *)t { (void)t; _queryTimer = nil; [self loadList:YES]; }
- (void)viewWillDisappear:(BOOL)a { [super viewWillDisappear:a]; [_queryTimer invalidate]; _queryTimer = nil; }
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    (void)f;
    if ([row.userInfo isEqual:@"list"]) { [self loadList:YES]; return; }
    if ([row.userInfo isEqual:@"list-more"]) { [self loadList:NO]; return; }
    if ([row.userInfo isEqual:@"create"]) {
        UIViewController *c = OR6Chat6CreateProjectEditor(_core, nil, ^(NSString *projectId) { [self loadList:YES]; if (projectId) [_nav chat7OpenProject:projectId]; });
        if (c) [self.navigationController pushViewController:c animated:YES]; return;
    }
    if ([row.userInfo isKindOfClass:NSDictionary.class]) { OR6Chat7RememberProject(row.userInfo); [_nav chat7OpenProject:row.userInfo[@"projectId"]]; return; }
    if ([row.userInfo isEqual:@"open"]) {
        UIAlertView *a = [[[UIAlertView alloc] initWithTitle:OR6L(@"Project link") message:nil delegate:self cancelButtonTitle:OR6L(@"Cancel") otherButtonTitles:OR6L(@"Open"), nil] autorelease];
        a.alertViewStyle = UIAlertViewStylePlainTextInput; [a textFieldAtIndex:0].keyboardType = UIKeyboardTypeURL; [a textFieldAtIndex:0].autocorrectionType = UITextAutocorrectionTypeNo; [a textFieldAtIndex:0].autocapitalizationType = UITextAutocapitalizationTypeNone;
        [a show];
    }
}
- (void)alertView:(UIAlertView *)a clickedButtonAtIndex:(NSInteger)i {
    if (i == a.cancelButtonIndex) return;
    NSString *route = ProjectRoute([a textFieldAtIndex:0].text);
    if (!route || ![_read perform:@"routes.resolve" parameters:@{@"url": route}]) [RCHUD showText:OR6L(@"This is not a project link.") kind:RCHUDTextOnly inView:self.view.window seconds:1.6];
}
- (void)chat8ModelChanged:(id)m {
    if (m == _read && !_read.busy) {
        if (!_read.error && [_read.result[@"destination"] isEqual:@"project"] && [_read.result[@"projectId"] isKindOfClass:NSString.class]) { [_nav chat7OpenProject:_read.result[@"projectId"]]; [_read reset]; }
        else if (_read.error) [RCHUD showText:OR6L(@"This is not a project link.") kind:RCHUDTextOnly inView:self.view.window seconds:1.6];
    }
    if (m == _list && !_list.busy && !_list.error) {
        NSMutableSet *seen = [NSMutableSet set]; for (NSDictionary *p in _listItems) [seen addObject:p[@"projectId"]];
        for (NSDictionary *p in _list.result[@"items"]) if ([p isKindOfClass:NSDictionary.class] && [p[@"projectId"] isKindOfClass:NSString.class] && [p[@"name"] isKindOfClass:NSString.class] && ![seen containsObject:p[@"projectId"]]) [_listItems addObject:p];
        [_listNext release]; _listNext = [_list.result[@"nextPageToken"] isKindOfClass:NSString.class] && [_list.result[@"nextPageToken"] length] ? [_list.result[@"nextPageToken"] copy] : nil;
    }
    [super chat8ModelChanged:m];
}
- (void)dealloc { [_queryTimer invalidate]; _list.delegate = nil; [_list cancel]; [_list release]; [_listItems release]; [_listNext release]; [_query release]; [super dealloc]; }
@end

@interface OR6Chat7ProjectScreen : OR6Chat7ListForm { NSString *_projectId; OR6Chat7Call *_chats, *_files, *_memory; NSMutableArray *_chatItems; NSString *_chatsNext; }
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav project:(NSString *)projectId;
@end
@implementation OR6Chat7ProjectScreen
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav project:(NSString *)projectId {
    if ((self = [super initWithCore:core navigator:nav title:OR6L(@"Project")])) {
        _projectId = [projectId copy]; _chatItems = [NSMutableArray new];
        _chats = [[OR6Chat7Call alloc] initWithCore:core]; _chats.delegate = self; _files = [[OR6Chat7Call alloc] initWithCore:core]; _files.delegate = self; _memory = [[OR6Chat7Call alloc] initWithCore:core]; _memory.delegate = self;
    }
    return self;
}
- (void)load {
    [_read perform:@"projects.get" parameters:@{@"projectId": _projectId}];
    [_chatItems removeAllObjects]; [_chatsNext release]; _chatsNext = nil;
    if (OR6Chat7On(_core, @"projects.conversations")) [_chats perform:@"projects.conversations" parameters:@{@"projectId": _projectId, @"pageToken": NSNull.null, @"limit": @20}];
    if (OR6Chat7On(_core, @"projects.filesList")) [_files perform:@"projects.filesList" parameters:@{@"projectId": _projectId, @"pageToken": NSNull.null, @"limit": @20}];
}
- (NSDictionary *)project { NSDictionary *p = _memory.result[@"projectId"] ? _memory.result : _read.result; return [p[@"projectId"] isEqual:_projectId] ? p : nil; }
// Stage 6 (API6C): «⋯» with rename/appearance, instructions and delete, each only when granted.
- (void)renderActions {
    NSDictionary *p = [self project]; NSArray *a = p ? OR6Chat6ProjectActions(_core, p) : nil;
    if (!a.count) { self.navigationItem.rightBarButtonItem = nil; return; }
    UIBarButtonItem *b = [[[UIBarButtonItem alloc] initWithImage:[RCGlyph imageNamed:@"more" size:20 color:[UIColor whiteColor]] style:UIBarButtonItemStyleBordered target:self action:@selector(projectActions)] autorelease];
    b.accessibilityLabel = OR6L(@"Project actions"); self.navigationItem.rightBarButtonItem = b;
}
- (void)projectActions {
    NSDictionary *p = [self project]; NSArray *a = p ? OR6Chat6ProjectActions(_core, p) : nil; if (!a.count) return;
    NSMutableArray *titles = [NSMutableArray array], *keys = [NSMutableArray array]; NSString *destructive = nil, *destructiveKey = nil;
    for (NSDictionary *x in a) { if ([x[@"destructive"] boolValue]) { destructive = x[@"title"]; destructiveKey = x[@"key"]; } else { [titles addObject:x[@"title"]]; [keys addObject:x[@"key"]]; } }
    NSDictionary *project = [[p copy] autorelease]; id<OR6Chat7Navigator> nav = _nav; UINavigationController *nc = self.navigationController;
    OR6Chat8ShowSheet(self.view.window ?: self.view, project[@"name"], titles, destructive, ^(NSInteger n, NSString *t) {
        (void)t; NSString *key = n == -2 ? destructiveKey : (n >= 0 && (NSUInteger)n < keys.count) ? keys[(NSUInteger)n] : nil; if (!key) return;
        OR6Chat6RunProjectAction(self, _core, key, project, nav, ^(NSString *change) { if ([change isEqual:@"deleted"]) { if (nc.topViewController == self) [nc popViewControllerAnimated:YES]; } else [self load]; });
    });
}
- (void)chat8ModelChanged:(id)m {
    if (m == _read && !_read.busy && [self project]) { OR6Chat7RememberProject([self project]); self.title = [self project][@"name"]; }
    if (m == _read && !_read.busy) [self renderActions];
    if (m == _chats && !_chats.busy && !_chats.error && [_chats.result[@"items"] isKindOfClass:NSArray.class]) { [_chatItems addObjectsFromArray:_chats.result[@"items"]]; [_chatsNext release]; _chatsNext = [_chats.result[@"nextPageToken"] isKindOfClass:NSString.class] ? [_chats.result[@"nextPageToken"] copy] : nil; }
    [super chat8ModelChanged:m];
}
- (void)render {
    NSDictionary *p = [self project]; NSMutableArray *sections = [NSMutableArray array];
    if (!p) { RCFormSection *s = [RCFormSection sectionWithTitle:nil rows:@[[self note:(_read.busy ? OR6L(@"Loading…") : _read.error ? OR6Chat7ErrorText(_read.error) : OR6L(@"The project could not be read."))]]]; if (OR6Chat7Retryable(_read.error)) s.rows = [s.rows arrayByAddingObject:[self button:OR6L(@"Read again") info:@"reload" identifier:@"chat.project.reload"]]; [sections addObject:s]; self.sections = sections; return; }
    BOOL write = [p[@"canWrite"] isEqual:@YES];
    NSString *scope = [p[@"memoryScope"] isEqual:@"project-only"] ? OR6L(@"Only this project") : [p[@"memoryScope"] isEqual:@"default"] ? OR6L(@"Default") : OR6L(@"Unknown");
    RCFormRow *mem = [RCFormRow rowWithKind:RCFormRowValue title:OR6L(@"Memory")]; mem.value = scope; mem.identifier = @"chat.project.memory";
    RCFormRow *src = [RCFormRow rowWithKind:RCFormRowValue title:OR6L(@"Sources")]; src.value = [p[@"fileCount"] description];
    NSMutableArray *info = [NSMutableArray arrayWithObjects:mem, src, nil];
    if (OR6Chat7On(_core, @"projects.memoryGet")) { RCFormRow *r = [self button:OR6L(@"Read project memory again") info:@"memory" identifier:@"chat.project.memory_read"]; r.busy = _memory.busy; [info addObject:r]; }
    if (write && OR6Chat7On(_core, @"projects.memoryUpdate") && ![p[@"memoryScope"] isEqual:@"project-only"]) [info addObject:[self button:OR6L(@"Use only this project's memory") info:@"memory-update" identifier:@"chat.project.memory_update"]];
    if ([p[@"shared"] isEqual:@YES]) [info addObject:[self note:OR6L(@"This project is shared. ChatGPT X does not change shared projects.")]];
    RCFormSection *is = [RCFormSection sectionWithTitle:nil rows:info];
    is.footer = write ? nil : OR6L(@"Changes to this project are not available: ChatGPT X cannot confirm your user and workspace for it.");
    [sections addObject:is];
    if (write && OR6Chat7On(_core, @"projects.newDraft") && OR6Chat7On(_core, @"projects.send")) [sections addObject:[RCFormSection sectionWithTitle:nil rows:@[[self button:OR6L(@"New chat in this project") info:@"new" identifier:@"chat.project.new"]]]];
    NSMutableArray *chats = [NSMutableArray array];
    for (NSDictionary *c in _chatItems) { RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:([c[@"title"] length] ? c[@"title"] : OR6L(@"Untitled"))]; r.disclosure = YES; r.userInfo = @{@"chat": c}; [chats addObject:r]; }
    if (_chats.busy) [chats addObject:[self note:OR6L(@"Loading…")]]; else if (_chats.error) [chats addObject:[self note:OR6Chat7ErrorText(_chats.error)]]; else if (_chatsNext) [chats addObject:[self button:OR6L(@"Show more") info:@"chats-more" identifier:@"chat.project.chats_more"]]; else if (!chats.count && OR6Chat7On(_core, @"projects.conversations")) [chats addObject:[self note:OR6L(@"No chats in this project.")]];
    if (chats.count) [sections addObject:[RCFormSection sectionWithTitle:OR6L(@"Chats") rows:chats]];
    NSMutableArray *files = [NSMutableArray array];
    for (NSDictionary *f in ([_files.result[@"items"] isKindOfClass:NSArray.class] ? _files.result[@"items"] : @[])) {
        RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:f[@"name"]]; r.value = [f[@"bytes"] isKindOfClass:NSNumber.class] ? OR6Chat8Bytes([f[@"bytes"] unsignedLongLongValue]) : nil; r.glyph = @"file"; r.tile = RCTileBlue;
        if (write && OR6Chat7On(_core, @"projects.filesRemove")) { r.disclosure = YES; r.userInfo = @{@"file": f}; }
        [files addObject:r];
    }
    if (_files.busy) [files addObject:[self note:OR6L(@"Loading…")]]; else if (_files.error) [files addObject:[self note:OR6Chat7ErrorText(_files.error)]];
    if (files.count) { RCFormSection *fs = [RCFormSection sectionWithTitle:OR6L(@"Sources") rows:files]; fs.footer = OR6L(@"Adding sources needs files uploaded in this session; removing a source does not delete the file from your Library."); [sections addObject:fs]; }
    self.sections = sections;
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    (void)f; id i = row.userInfo; NSDictionary *p = [self project];
    if ([i isEqual:@"reload"]) { if (OR6Chat7Retryable(_read.error)) [self load]; }
    else if ([i isEqual:@"memory"]) [_memory perform:@"projects.memoryGet" parameters:@{@"projectId": _projectId}];
    else if ([i isEqual:@"chats-more"]) [_chats perform:@"projects.conversations" parameters:@{@"projectId": _projectId, @"pageToken": _chatsNext, @"limit": @20}];
    else if ([i isEqual:@"new"] && p) [_nav chat7NewChatInProject:p];
    else if ([i isEqual:@"memory-update"]) {
        [OR6Chat7Runner runWithCore:_core op:@"projects.memoryUpdate" params:@{@"projectId": _projectId, @"memoryScope": @"project-only"} intent:[@"project-memory:" stringByAppendingString:_projectId] reconcile:@"projects.reconcile" view:self.view.window done:OR6L(@"Project memory changed.") finished:^(NSDictionary *r) { (void)r; [self load]; }];
    } else if ([i isKindOfClass:NSDictionary.class] && i[@"chat"]) [_nav chat7OpenConversation:i[@"chat"][@"conversationId"] title:i[@"chat"][@"title"]];
    else if ([i isKindOfClass:NSDictionary.class] && i[@"file"]) {
        [_sheetItem release]; _sheetItem = [i[@"file"] retain];
        UIActionSheet *s = [[[UIActionSheet alloc] initWithTitle:OR6L(@"Remove this source from the project? The file stays in your Library.") delegate:self cancelButtonTitle:OR6L(@"Cancel") destructiveButtonTitle:OR6L(@"Remove") otherButtonTitles:nil] autorelease];
        [s showInView:self.view.window ?: self.view];
    }
}
- (void)actionSheet:(UIActionSheet *)s clickedButtonAtIndex:(NSInteger)n {
    NSDictionary *f = [[_sheetItem retain] autorelease]; if (n != s.destructiveButtonIndex || !f) return;
    [OR6Chat7Runner runWithCore:_core op:@"projects.filesRemove" params:@{@"projectId": _projectId, @"fileId": f[@"fileId"]} intent:[NSString stringWithFormat:@"project-file:%@:%@", _projectId, f[@"fileId"]] reconcile:@"projects.reconcile" view:self.view.window done:OR6L(@"Source removed.") finished:^(NSDictionary *r) { (void)r; [self load]; }];
}
- (void)dealloc { for (OR6Chat7Call *c in @[_chats, _files, _memory]) { c.delegate = nil; [c cancel]; } [_chats release]; [_files release]; [_memory release]; [_chatItems release]; [_chatsNext release]; [_projectId release]; [super dealloc]; }
@end

#pragma mark - Shared snapshot (shares.get, read only)

@interface OR6Chat7SharedScreen : OR6Chat7ListForm { @public NSString *_shareId; }
@end
@implementation OR6Chat7SharedScreen
- (void)load { [_read perform:@"shares.get" parameters:@{@"shareId": _shareId}]; }
- (void)render {
    NSMutableArray *rows = [NSMutableArray arrayWithObject:[self note:(_read.busy ? OR6L(@"Loading the shared chat…") : _read.error ? OR6Chat7ErrorText(_read.error) : OR6L(@"Loading the shared chat…"))]];
    if (OR6Chat7Retryable(_read.error)) [rows addObject:[self button:OR6L(@"Read again") info:@"reload" identifier:@"chat.shared.reload"]];
    self.sections = @[[RCFormSection sectionWithTitle:nil rows:rows]];
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row { (void)f; if ([row.userInfo isEqual:@"reload"] && OR6Chat7Retryable(_read.error)) [self load]; }
- (void)chat8ModelChanged:(id)m {
    NSDictionary *c = _read.result[@"conversation"];
    if (m == _read && !_read.busy && !_read.error && [c isKindOfClass:NSDictionary.class] && self.navigationController) {
        NSMutableString *md = [NSMutableString string]; NSUInteger n = 0;
        for (NSDictionary *r in OR6ChatDisplayRows(c[@"messages"])) { NSString *t = r[@"text"]; if (![t isKindOfClass:NSString.class] || !t.length) continue; n++;
            [md appendFormat:@"### %@\n\n%@\n\n", [r[@"role"] isEqual:@"user"] ? OR6L(@"Question") : @"ChatGPT", t]; }
        RCReportViewController *report = [[[RCReportViewController alloc] initWithTitle:([c[@"title"] length] ? c[@"title"] : OR6L(@"Shared chat")) markdown:md] autorelease];
        report.meta = [NSString stringWithFormat:OR6L(@"Shared link · read only · %lu messages"), (unsigned long)n]; report.title = OR6L(@"Shared chat");
        NSMutableArray *vcs = [[self.navigationController.viewControllers mutableCopy] autorelease]; NSUInteger i = [vcs indexOfObject:self];
        if (i != NSNotFound) { [vcs replaceObjectAtIndex:i withObject:report]; [self.navigationController setViewControllers:vcs animated:NO]; return; }
    }
    [super chat8ModelChanged:m];
}
- (void)dealloc { [_shareId release]; [super dealloc]; }
@end

#pragma mark - Share link sheet (history.get → shares.create; chat.sharedLink.delete; open → shares.get)

// The sheet opens Preparing: one read-only history.get of the exact conversation supplies its
// current node (list summaries may lack it). «Создать ссылку» appears only after that read;
// the tap re-checks the prepared conversation/node/context. Nothing is published automatically.
@interface OR6Chat7ShareController : NSObject <RCShareLinkSheetDelegate, OR6Chat8ModelDelegate, UIActionSheetDelegate> {
@public OR6APICore *core; RCShareLinkSheet *sheet; OR6Chat7Write *create; OR6Chat7SharePreparation *prep; NSString *cid; NSString *shareId; UIViewController *host;
}
@end
@implementation OR6Chat7ShareController
- (void)prepare { if (![prep prepareConversation:cid]) { sheet.preparationRetryAvailable = NO; sheet.failureText = nil; sheet.state = RCShareLinkPreparationFailed; } }
- (void)shareLinkSheetRetryPreparation:(RCShareLinkSheet *)s { (void)s; [prep retry]; } // a read again, never a create
- (void)preparationChanged {
    RCShareLinkState st = sheet.state; NSString *p = prep.phase;
    if (st == RCShareLinkCreating || st == RCShareLinkCreated || st == RCShareLinkFailed) return; // the create path owns the sheet now
    if ([p isEqual:@"preparing"]) { sheet.failureText = nil; sheet.state = RCShareLinkPreparing; }
    else if ([p isEqual:@"ready"]) { sheet.failureText = nil; sheet.state = RCShareLinkIdle; }
    else if ([p isEqual:@"failed"]) { sheet.failureText = nil; sheet.preparationRetryAvailable = prep.retryAvailable; sheet.state = RCShareLinkPreparationFailed; } // kit text: no service details
}
- (void)shareLinkSheet:(RCShareLinkSheet *)s createLinkIncludingName:(BOOL)name {
    (void)name; NSDictionary *params = [prep createParametersForConversation:cid]; // bound to the prepared conversation, node and context, re-checked now
    if (!params) { if (s.state != RCShareLinkPreparationFailed) { sheet.preparationRetryAvailable = prep.retryAvailable; s.failureText = nil; s.state = RCShareLinkPreparationFailed; } return; }
    if (!create) { create = [[OR6Chat7Write alloc] initWithCore:core reconcile:@"conversations.reconcile"]; create.delegate = self; }
    // Busy BEFORE the dispatch: a synchronous reply (done / failed / uncertain) lands in
    // -chat8ModelChanged: and must not be overwritten afterwards. A refusal sends nothing.
    s.failureText = nil; s.state = RCShareLinkCreating;
    if (![create perform:@"shares.create" parameters:params intent:[@"share:" stringByAppendingString:cid]]) { s.failureText = OR6L(@"The previous attempt has an unknown result. It is not sent again; check the chat first."); s.state = RCShareLinkFailed; }
}
- (void)chat8ModelChanged:(id)m {
    if (m == prep) { [self preparationChanged]; return; }
    if (m != create) return;
    NSString *p = create.phase; NSDictionary *share = create.receipt[@"share"];
    if ([p isEqual:@"running"] || [p isEqual:@"reconciling"]) return;
    if (([p isEqual:@"done"]) && [share[@"url"] isKindOfClass:NSString.class]) { [shareId release]; shareId = [share[@"id"] copy]; sheet.link = share[@"url"]; sheet.state = RCShareLinkCreated;
        sheet.openAvailable = OR6Chat7On(core, @"shares.get"); sheet.revokeAvailable = OR6Chat7On(core, @"chat.sharedLink.delete"); return; }
    sheet.state = RCShareLinkFailed;
    sheet.failureText = [p isEqual:@"uncertain"] ? OR6L(@"The link may have been created. It is not created again; check your shared links in the web version.") : OR6Chat7ErrorText(create.error);
}
- (void)shareLinkSheet:(RCShareLinkSheet *)s shareLink:(NSString *)link { (void)s; UIActivityViewController *a = [[[UIActivityViewController alloc] initWithActivityItems:@[link] applicationActivities:nil] autorelease]; [sheet presentViewController:a animated:YES completion:nil]; }
- (void)shareLinkSheet:(RCShareLinkSheet *)s openLink:(NSString *)link { (void)s; (void)link; if (shareId) [sheet.navigationController pushViewController:OR6Chat7CreateSharedView(core, shareId) animated:YES]; }
- (void)shareLinkSheet:(RCShareLinkSheet *)s revokeLink:(NSString *)link {
    (void)link; UIActionSheet *a = [[[UIActionSheet alloc] initWithTitle:OR6L(@"Delete this link? People who have it can no longer open the chat.") delegate:self cancelButtonTitle:OR6L(@"Cancel") destructiveButtonTitle:OR6L(@"Delete link") otherButtonTitles:nil] autorelease];
    [a showInView:s.view.window ?: s.view];
}
- (void)actionSheet:(UIActionSheet *)a clickedButtonAtIndex:(NSInteger)i {
    if (i != a.destructiveButtonIndex || !shareId) return;
    [OR6Chat7Runner runWithCore:core op:@"chat.sharedLink.delete" params:@{@"shareId": shareId} intent:[@"share-delete:" stringByAppendingString:shareId] reconcile:@"tools.operation.reconcile" view:sheet.view.window done:OR6L(@"Link deleted.") finished:^(NSDictionary *r) { if ([r[@"deleted"] isEqual:@YES]) { sheet.revokeAvailable = NO; sheet.openAvailable = NO; } }];
}
- (void)shareLinkSheetDidFinish:(RCShareLinkSheet *)s { [s dismissViewControllerAnimated:YES completion:nil]; create.delegate = nil; prep.delegate = nil; [prep cancel]; Drop(self); }
- (void)dealloc { prep.delegate = nil; [prep cancel]; [prep release]; [core release]; [sheet release]; [create release]; [cid release]; [shareId release]; [super dealloc]; }
@end

#pragma mark - Conversation actions

// Physical diagnosis of the Share modal (no text, IDs or account data): who presented it, whether
// it was refused, and whether its view really reached a visible window when the transition ended.
static NSMutableDictionary *gSharePresentation;
NSDictionary *OR6Chat7SharePresentationDiagnostics(void) { return gSharePresentation ? [[gSharePresentation copy] autorelease] : @{}; }
static void ShareNote(NSDictionary *d) { if (!gSharePresentation) gSharePresentation = [NSMutableDictionary new]; [gSharePresentation addEntriesFromDictionary:d]; }

NSArray *OR6Chat7ConversationActions(OR6APICore *c, NSDictionary *v) {
    if (![v[@"id"] isKindOfClass:NSString.class]) return nil;
    NSMutableArray *a = [NSMutableArray array];
    if (OR6Chat7On(c, @"conversations.rename")) [a addObject:@"rename"];
    if (OR6Chat7On(c, @"conversations.pin")) [a addObject:[v[@"pinned"] isEqual:@YES] ? @"unpin" : @"pin"];
    if (OR6Chat7On(c, @"shares.create") && OR6Chat7ConversationUUID(v[@"id"])) [a addObject:@"share"]; // the node is read when the sheet opens
    if (OR6Chat7On(c, @"projects.moveConversation")) [a addObject:@"move"];
    if (OR6Chat7On(c, @"library.conversationFiles")) [a addObject:@"files"];
    if ([v[@"archived"] isEqual:@YES]) { if (OR6Chat7On(c, @"conversations.unarchive")) [a addObject:@"unarchive"]; }
    else if (OR6Chat7On(c, @"conversations.archive")) [a addObject:@"archive"];
    if (OR6Chat7On(c, @"conversations.delete")) [a addObject:@"delete"];
    return a.count ? a : nil;
}
@interface OR6Chat7Prompt : NSObject <UIAlertViewDelegate, UIActionSheetDelegate> { @public void (^block)(NSInteger index, NSString *text); NSInteger destructive; }
@end
@implementation OR6Chat7Prompt
- (void)alertView:(UIAlertView *)a clickedButtonAtIndex:(NSInteger)i { if (i != a.cancelButtonIndex && block) block(i, a.alertViewStyle == UIAlertViewStylePlainTextInput ? [a textFieldAtIndex:0].text : nil); [self autorelease]; }
- (void)actionSheet:(UIActionSheet *)s clickedButtonAtIndex:(NSInteger)i { if (i != s.cancelButtonIndex && i >= 0 && block) block(i, [s buttonTitleAtIndex:i]); [self autorelease]; }
- (void)dealloc { [block release]; [super dealloc]; }
@end
static OR6Chat7Prompt *Prompt(void (^b)(NSInteger, NSString *)) { OR6Chat7Prompt *p = [[OR6Chat7Prompt alloc] init]; p->block = [b copy]; return p; } // released after the choice

void OR6Chat7RunConversationAction(UIViewController *host, OR6APICore *core, NSString *action, NSDictionary *v, id<OR6Chat7Navigator> nav) {
    NSString *cid = v[@"id"]; UIView *view = host.view.window ?: host.view; if (![cid isKindOfClass:NSString.class]) return;
    void (^run)(NSString *, NSDictionary *, NSString *, NSString *, NSString *) = ^(NSString *op, NSDictionary *p, NSString *intent, NSString *done, NSString *change) {
        [OR6Chat7Runner runWithCore:core op:op params:p intent:intent reconcile:([op hasPrefix:@"projects."] ? @"projects.reconcile" : @"conversations.reconcile") view:view done:done finished:^(NSDictionary *r) { (void)r; [nav chat7Conversation:cid changed:change]; }];
    };
    if ([action isEqual:@"rename"]) {
        UIAlertView *a = [[[UIAlertView alloc] initWithTitle:OR6L(@"Rename chat") message:nil delegate:Prompt(^(NSInteger i, NSString *t) {
            (void)i; NSString *title = [t stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (title.length && title.length <= 200 && ![title isEqual:v[@"title"]]) run(@"conversations.rename", @{@"conversationId": cid, @"title": title}, [@"rename:" stringByAppendingString:cid], OR6L(@"Chat renamed."), @"renamed");
        }) cancelButtonTitle:OR6L(@"Cancel") otherButtonTitles:OR6L(@"Rename"), nil] autorelease];
        a.alertViewStyle = UIAlertViewStylePlainTextInput; [a textFieldAtIndex:0].text = v[@"title"]; [a show];
    } else if ([action isEqual:@"pin"] || [action isEqual:@"unpin"]) {
        BOOL pin = [action isEqual:@"pin"]; run(@"conversations.pin", @{@"conversationId": cid, @"pinned": @(pin)}, [@"pin:" stringByAppendingString:cid], pin ? OR6L(@"Chat pinned.") : OR6L(@"Chat unpinned."), @"pinned");
    } else if ([action isEqual:@"archive"] || [action isEqual:@"unarchive"] || [action isEqual:@"delete"]) {
        BOOL del = [action isEqual:@"delete"], arch = [action isEqual:@"archive"];
        NSString *q = del ? OR6L(@"Delete this chat from your account? This cannot be undone here.") : arch ? OR6L(@"Move this chat to the archive? It stays in your account.") : OR6L(@"Return this chat from the archive?");
        NSString *b = del ? OR6L(@"Delete chat") : arch ? OR6L(@"Archive") : OR6L(@"Return");
        UIActionSheet *s = [[[UIActionSheet alloc] initWithTitle:q delegate:Prompt(^(NSInteger i, NSString *t) {
            (void)i; (void)t;
            if (del) run(@"conversations.delete", @{@"conversationId": cid}, [@"delete:" stringByAppendingString:cid], OR6L(@"Delete requested."), @"deleted");
            else run(arch ? @"conversations.archive" : @"conversations.unarchive", @{@"conversationId": cid}, [NSString stringWithFormat:@"%@:%@", action, cid], arch ? OR6L(@"Chat archived.") : OR6L(@"Chat returned."), arch ? @"archived" : @"unarchived");
        }) cancelButtonTitle:OR6L(@"Cancel") destructiveButtonTitle:((del || arch) ? b : nil) otherButtonTitles:((del || arch) ? nil : b), nil] autorelease];
        [s showInView:view];
    } else if ([action isEqual:@"share"]) {
        if (!OR6Chat7ConversationUUID(cid) || !OR6Chat7On(core, @"shares.create")) return;
        NSInteger attempts = [gSharePresentation[@"attempts"] integerValue] + 1; [gSharePresentation removeAllObjects]; // one record per attempt
        ShareNote(@{@"attempts": @(attempts), @"presenter": NSStringFromClass(host.class) ?: @"", @"presenterInWindow": @(host.view.window != nil),
                    @"presenterBusy": NSStringFromClass(host.presentedViewController.class) ?: @"", @"keyWindowIsMain": @(UIApplication.sharedApplication.keyWindow == host.view.window), @"completed": @NO});
        if (host.presentedViewController || !host.view.window) { ShareNote(@{@"refused": @YES}); [RCHUD showText:OR6L(@"This change cannot be sent now.") kind:RCHUDTextOnly inView:view seconds:1.6]; return; } // never a modal on a busy/hidden presenter
        OR6Chat7ShareController *c = [[[OR6Chat7ShareController alloc] init] autorelease]; Keep(c); // kept until the sheet finishes
        // cid is canonical lowercase: one latch key and one comparison per UUID.
        c->core = [core retain]; c->cid = [[cid lowercaseString] copy];
        c->host = host;
        c->sheet = [[RCShareLinkSheet alloc] init];
        if (!c->sheet) { ShareNote(@{@"refused": @YES, @"sheetMissing": @YES}); Drop(c); return; } // never present an empty navigation controller
        c->prep = [[OR6Chat7SharePreparation alloc] initWithCore:core]; c->prep.delegate = c;
        NSString *title = [v[@"title"] isKindOfClass:NSString.class] && [v[@"title"] length] ? v[@"title"] : OR6L(@"Chat");
        c->sheet.delegate = c; c->sheet.chatTitle = title; c->sheet.showsNameSwitch = NO; c->sheet.title = OR6L(@"Share link"); c->sheet.state = RCShareLinkPreparing;
        UINavigationController *nav = [RCShareLinkSheet navigationControllerWithSheet:c->sheet]; RCShareLinkSheet *sheet = c->sheet;
        [host presentViewController:nav animated:YES completion:^{
            UIWindow *w = nav.view.window; CGRect f = nav.view.frame;
            ShareNote(@{@"completed": @YES, @"presentedInWindow": @(w != nil), @"presentedWindowIsKey": @(w != nil && w.isKeyWindow), @"sheetLoaded": @(sheet.isViewLoaded), @"sheetInWindow": @(sheet.isViewLoaded && sheet.view.window != nil),
                        @"presentedFrame": NSStringFromCGRect(f), @"sheetState": @((int)sheet.state), @"presentingClass": NSStringFromClass(nav.presentingViewController.class) ?: @""});
        }];
        [c prepare];
    } else if ([action isEqual:@"move"]) {
        NSArray *projects = OR6Chat7RecentProjects();
        UIActionSheet *s = [[[UIActionSheet alloc] initWithTitle:OR6L(@"Move to project") delegate:Prompt(^(NSInteger i, NSString *t) {
            NSInteger k = i; id dest = (k >= 0 && (NSUInteger)k < projects.count) ? projects[(NSUInteger)k][@"projectId"] : NSNull.null;
            if (dest == NSNull.null && ![t isEqual:OR6L(@"Remove from project")]) return;
            run(@"projects.moveConversation", @{@"projectId": dest, @"conversationId": cid}, [@"move:" stringByAppendingString:cid], dest == NSNull.null ? OR6L(@"Removed from the project.") : OR6L(@"Moved to the project."), @"moved");
        }) cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil] autorelease];
        for (NSDictionary *p in projects) [s addButtonWithTitle:p[@"name"]];
        [s addButtonWithTitle:OR6L(@"Remove from project")];
        s.cancelButtonIndex = [s addButtonWithTitle:OR6L(@"Cancel")];
        [s showInView:view];
    } else if ([action isEqual:@"files"]) {
        [host.navigationController pushViewController:OR6Chat7CreateConversationFiles(core, cid, nav) animated:YES];
    }
}

#pragma mark - Factories

UIViewController *OR6Chat7CreateLibrary(OR6APICore *c, id<OR6Chat7Navigator> n) { return [[[OR6Chat7LibraryScreen alloc] initWithCore:c navigator:n conversation:nil] autorelease]; }
UIViewController *OR6Chat7CreateConversationFiles(OR6APICore *c, NSString *cid, id<OR6Chat7Navigator> n) { return [[[OR6Chat7LibraryScreen alloc] initWithCore:c navigator:n conversation:cid] autorelease]; }
UIViewController *OR6Chat7CreateArchive(OR6APICore *c, id<OR6Chat7Navigator> n) { return [[[OR6Chat7ArchiveScreen alloc] initWithCore:c navigator:n title:OR6L(@"Archive (collection)")] autorelease]; }
UIViewController *OR6Chat7CreateProjects(OR6APICore *c, id<OR6Chat7Navigator> n) { return [[[OR6Chat7ProjectsScreen alloc] initWithCore:c navigator:n title:OR6L(@"Projects")] autorelease]; }
UIViewController *OR6Chat7CreateProject(OR6APICore *c, NSString *p, id<OR6Chat7Navigator> n) { return [[[OR6Chat7ProjectScreen alloc] initWithCore:c navigator:n project:p] autorelease]; }
UIViewController *OR6Chat7CreateSharedView(OR6APICore *c, NSString *shareId) {
    OR6Chat7SharedScreen *s = [[[OR6Chat7SharedScreen alloc] initWithCore:c navigator:nil title:OR6L(@"Shared chat")] autorelease]; s->_shareId = [shareId copy]; return s;
}
