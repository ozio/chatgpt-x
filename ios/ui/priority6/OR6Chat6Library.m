// Library, stage 6 (API6C library.*; prototype s-tools.js libraryScreen): the destinations the
// API7 Library grid shows above its files — «Files and folders» (browse with search, type and
// source filters, list/grid and name/service order, folders with their path, «New folder…»),
// «Favorites» (with favorite folders), «Trash» (restore, delete forever, empty), «Connected
// sources» (read-only provider browse/search) and «Use in answers» (auto context). A node card
// (library.node.get) offers rename, move to a folder (fresh destination path, no folder into
// itself or its subfolders), favorite and delete — each only when its operation is granted and
// the node can be changed. Every write: explicit tap (+ purpose-specific confirmation when it
// deletes), one operation ID through OR6Chat7RunWrite with catalog.reconcile, then a fresh read.
#import "OR6Chat6Base.h"
#import "OR6Chat6Library.h"
#import "OR6Chat6LibraryLogic.h"
#import "RCGridViewController.h"
#import "RCGlyph.h"

static NSString *Intent(NSString *op, NSString *target) { return [NSString stringWithFormat:@"%@:%@", op, target ?: @"root"]; }
static BOOL NativeId(id v) {
    return [v isKindOfClass:NSString.class] && [v length] && [v length] <= 128 && ![v hasPrefix:@"external-"]
        && [v rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"] invertedSet]].location == NSNotFound;
}
static NSArray *Nodes(NSArray *items) { NSMutableArray *a = [NSMutableArray array]; for (id i in items) if (OR6Chat6LibraryNode(i)) [a addObject:i]; return a; }
static UIView *Host(UIViewController *c) { return c.view.window ?: c.view; }

static NSString *NodeSubtitle(NSDictionary *n) {
    NSMutableArray *a = [NSMutableArray array];
    if (OR6Chat6LibraryIsFolder(n)) [a addObject:OR6L(@"Folder")]; else [a addObject:OR6Chat6Bytes(n[@"bytes"]) ?: OR6Chat6LibraryKindTitle(n)];
    NSString *d = OR6Chat6RelativeDate(n[@"updatedAt"]); if (d) [a addObject:d];
    if ([n[@"access"] isEqual:@"shared"] || [n[@"access"] isEqual:@"mounted"]) [a addObject:OR6Chat6LibraryAccessTitle(n[@"access"])];
    return [a componentsJoinedByString:@" · "];
}
static RCTileColor NodeTile(NSDictionary *n) { return OR6Chat6LibraryIsFolder(n) ? RCTileBlue : OR6Chat6LibraryIsPicture(n) ? RCTileOrange : RCTileGray; }
static RCFormRow *NodeRow(NSDictionary *n, NSString *identifier, BOOL tappable) {
    RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:OR6Chat6Text(n[@"name"], OR6L(@"Untitled"))];
    r.subtitle = NodeSubtitle(n); r.glyph = OR6Chat6LibraryNodeGlyph(n); r.tile = NodeTile(n);
    r.disclosure = tappable; r.enabled = tappable; r.userInfo = n; r.identifier = identifier; return r;
}

#pragma mark - Name prompt (stock UIAlertView with a text field; the delegate lives until the choice)

static NSMutableSet *gPrompts;
@interface OR6Chat6LibraryPrompt : NSObject <UIAlertViewDelegate> { void (^_done)(NSString *text); }
@end
@implementation OR6Chat6LibraryPrompt
+ (void)askTitle:(NSString *)title text:(NSString *)text confirm:(NSString *)confirm done:(void (^)(NSString *text))done {
    OR6Chat6LibraryPrompt *p = [[[OR6Chat6LibraryPrompt alloc] init] autorelease]; p->_done = [done copy];
    if (!gPrompts) gPrompts = [NSMutableSet new]; [gPrompts addObject:p];
    UIAlertView *a = [[[UIAlertView alloc] initWithTitle:title message:nil delegate:p cancelButtonTitle:OR6L(@"Cancel") otherButtonTitles:confirm, nil] autorelease];
    a.alertViewStyle = UIAlertViewStylePlainTextInput; [a textFieldAtIndex:0].text = text; [a textFieldAtIndex:0].autocapitalizationType = UITextAutocapitalizationTypeSentences;
    [a show];
}
- (void)alertView:(UIAlertView *)a clickedButtonAtIndex:(NSInteger)i {
    [[self retain] autorelease]; [gPrompts removeObject:self]; a.delegate = nil;
    if (i != a.cancelButtonIndex && _done) _done([a textFieldAtIndex:0].text);
}
- (void)alertViewCancel:(UIAlertView *)a { a.delegate = nil; [[self retain] autorelease]; [gPrompts removeObject:self]; }
- (void)dealloc { [_done release]; [super dealloc]; }
@end

// Validated name → block, or an explanation HUD.
static void AskName(UIViewController *host, NSString *title, NSString *text, NSString *confirm, void (^named)(NSString *name)) {
    void (^n)(NSString *) = [[named copy] autorelease];
    [OR6Chat6LibraryPrompt askTitle:title text:text confirm:confirm done:^(NSString *t) {
        NSString *problem = nil, *name = OR6Chat6LibraryName(t, &problem);
        if (name) n(name); else OR6Chat6Say(Host(host), problem);
    }];
}
// library.folder.create under parentId (nil: the top level) after the name prompt.
static void CreateFolder(UIViewController *host, OR6APICore *core, NSString *parentId, void (^created)(void)) {
    void (^c)(void) = [[created copy] autorelease];
    AskName(host, OR6L(@"New folder"), @"", OR6L(@"Create"), ^(NSString *name) {
        OR6Chat7RunWrite(Host(host), core, @"library.folder.create", @{@"parentId": parentId ?: (id)NSNull.null, @"name": name},
                         Intent(@"library.folder.create", [NSString stringWithFormat:@"%@/%@", parentId ?: @"root", name]), @"catalog.reconcile", OR6L(@"Folder created."), ^(NSDictionary *r) { (void)r; if (c) c(); });
    });
}

@interface OR6Chat6LibraryBrowser : RCGridViewController <RCGridViewControllerDelegate, OR6Chat8ModelDelegate> {
    OR6APICore *_core; id<OR6Chat7Navigator> _nav; NSString *_directoryId, *_query, *_category, *_source;
    OR6Chat6Pager *_pager; OR6Chat7Call *_path, *_viewGet, *_viewSet; NSTimer *_timer; BOOL _loaded, _reloadAfterView; void (^_changed)(void);
}
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav directory:(NSString *)directoryId title:(NSString *)title changed:(void (^)(void))changed;
@end

@interface OR6Chat6LibraryNodeScreen : OR6Chat6Form {
    NSString *_id, *_kind; NSDictionary *_seed; OR6Chat7Call *_fav, *_where; BOOL _favorites; void (^_changed)(NSString *change);
}
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav node:(NSDictionary *)node identifier:(NSString *)nodeId kind:(NSString *)kind favorites:(BOOL)favorites changed:(void (^)(NSString *change))changed;
@end

@interface OR6Chat6LibraryFolderPicker : OR6Chat6Form {
    NSDictionary *_node; NSString *_dir; BOOL _favorites, _moveAfterCheck; OR6Chat6Pager *_list; OR6Chat7Call *_check; void (^_moved)(void);
}
- (id)initWithCore:(OR6APICore *)core node:(NSDictionary *)node directory:(NSString *)directoryId title:(NSString *)title favorites:(BOOL)favorites moved:(void (^)(void))moved;
@end

#pragma mark - Files and folders (library.browse, view, path, folder.create)

@implementation OR6Chat6LibraryBrowser
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav directory:(NSString *)directoryId title:(NSString *)title changed:(void (^)(void))changed {
    if ((self = [super initWithStyle:RCGridStyleLibrary title:title])) {
        _core = [core retain]; _nav = nav; _directoryId = [directoryId copy]; _changed = [changed copy]; self.delegate = self;
        self.searchPlaceholder = _directoryId ? OR6L(@"Search in this folder") : OR6L(@"Search files"); self.emptyGlyph = @"folder";
        _pager = [[OR6Chat6Pager alloc] initWithCore:core operation:@"library.browse" parameters:OR6Chat6LibraryBrowseParameters(_directoryId, @"", nil, nil) tokenKey:@"pageToken" nextKey:@"nextPageToken" idKey:@"id"]; _pager.delegate = self;
        _path = [[OR6Chat7Call alloc] initWithCore:core]; _path.delegate = self;
        _viewGet = [[OR6Chat7Call alloc] initWithCore:core]; _viewGet.delegate = self;
        _viewSet = [[OR6Chat7Call alloc] initWithCore:core]; _viewSet.delegate = self;
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.tableView.accessibilityIdentifier = @"chat.library6.browser";
    UIBarButtonItem *b = [[[UIBarButtonItem alloc] initWithImage:[RCGlyph imageNamed:@"sliders" size:20 color:[UIColor whiteColor]] style:UIBarButtonItemStyleBordered target:self action:@selector(options)] autorelease];
    b.accessibilityLabel = OR6L(@"Filters and view"); self.navigationItem.rightBarButtonItem = b;
}
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; if (!_loaded) { _loaded = YES; [self load]; } [self render]; }
- (void)viewWillDisappear:(BOOL)a { [super viewWillDisappear:a]; [_timer invalidate]; _timer = nil; }
- (void)load {
    [_pager reload];
    if (_directoryId && OR6Chat6On(_core, @"library.folder.path")) [_path perform:@"library.folder.path" parameters:@{@"directoryId": _directoryId}];
    if (!_viewGet.result && !_viewGet.busy && OR6Chat6On(_core, @"library.view.get")) [_viewGet perform:@"library.view.get" parameters:@{}];
    [self render];
}
- (void)applyFilters { _pager.parameters = OR6Chat6LibraryBrowseParameters(_directoryId, _query, _category, _source); [_pager reload]; [self render]; }
- (NSDictionary *)currentView {
    for (NSDictionary *v in @[_viewSet.result ?: @{}, _viewGet.result ?: @{}, _pager.lastPage[@"view"] ?: @{}]) if ([v isKindOfClass:NSDictionary.class] && v[@"layout"] && v[@"sort"]) return v;
    return nil;
}
- (NSDictionary *)folder { NSDictionary *last = OR6Chat6LibraryNode([_path.result[@"items"] lastObject]); return [last[@"id"] isEqual:_directoryId] ? last : nil; }
- (BOOL)canCreate { return OR6Chat6On(_core, @"library.folder.create") && (!_directoryId || OR6Chat6LibraryCanMutate([self folder])); }
- (void)chat8ModelChanged:(id)m {
    if (m == _viewSet && !_viewSet.busy && _viewSet.result && _reloadAfterView) { _reloadAfterView = NO; [_pager reload]; } // name order applies to pages read from now on
    if (m == _viewSet && !_viewSet.busy && _viewSet.error) { _reloadAfterView = NO; OR6Chat6Say(Host(self), OR6Chat7ErrorText(_viewSet.error)); }
    if (m == _path && [self folder]) self.title = OR6Chat6Text([self folder][@"name"], self.title);
    [self render];
}
- (void)render {
    if (![self isViewLoaded]) return;
    NSDictionary *view = [self currentView]; self.showsGrid = [view[@"layout"] isEqual:@"grid"];
    NSMutableArray *items = [NSMutableArray array];
    for (NSDictionary *n in Nodes(_pager.items)) {
        RCGridItem *g = [RCGridItem itemWithTitle:OR6Chat6Text(n[@"name"], OR6L(@"Untitled")) subtitle:NodeSubtitle(n) glyph:OR6Chat6LibraryNodeGlyph(n) tile:NodeTile(n)];
        g.fileIcon = !OR6Chat6LibraryIsFolder(n); g.showsDisclosure = YES; g.userInfo = n; [items addObject:g];
    }
    NSMutableArray *sections = [NSMutableArray array], *notes = [NSMutableArray array];
    if (_category || _source) [notes addObject:[NSString stringWithFormat:OR6L(@"Showing: %@ · %@."), OR6Chat6LibraryCategoryTitle(_category), OR6Chat6LibrarySourceTitle(_source)]];
    if ([view[@"sort"] isEqual:@"name"]) [notes addObject:OR6L(@"Sorted by name within each page the service returns.")];
    if (_pager.busy) [notes addObject:OR6L(@"Loading…")]; else if (_pager.error) [notes addObject:OR6Chat7ErrorText(_pager.error)];
    if (items.count) {
        RCGridSection *s = [RCGridSection sectionWithTitle:(_path.result ? OR6Chat6LibraryPathText(_path.result[@"items"]) : nil) items:items];
        s.footer = notes.count ? [notes componentsJoinedByString:@"\n"] : nil; [sections addObject:s];
    }
    RCGridItem *more = nil;
    if (_pager.error && _pager.retryAvailable) { more = [RCGridItem itemWithTitle:OR6L(@"Read again") subtitle:nil glyph:@"regen" tile:RCTileGray]; more.userInfo = @"retry"; }
    else if (!_pager.busy && !_pager.error && _pager.hasMore) { more = [RCGridItem itemWithTitle:OR6L(@"Show more") subtitle:nil glyph:@"down" tile:RCTileGray]; more.userInfo = @"more"; }
    if (more) [sections addObject:[RCGridSection sectionWithTitle:nil items:@[more]]];
    self.sections = sections;
    self.emptyTitle = _pager.busy ? OR6L(@"Loading…") : _query.length ? OR6L(@"Nothing found") : OR6L(@"No files");
    self.emptyText = _pager.error ? OR6Chat7ErrorText(_pager.error) : notes.count && !_pager.busy ? [notes componentsJoinedByString:@"\n"] : _directoryId ? OR6L(@"This folder is empty.") : OR6L(@"Your uploaded and created files appear here.");
    [self reloadData];
}
- (void)options {
    NSDictionary *view = [self currentView]; BOOL viewable = view && OR6Chat6On(_core, @"library.view.set");
    NSMutableArray *titles = [NSMutableArray array], *keys = [NSMutableArray array];
    void (^add)(NSString *, NSString *) = ^(NSString *t, NSString *k) { [titles addObject:t]; [keys addObject:k]; };
    add([NSString stringWithFormat:OR6L(@"Type: %@"), OR6Chat6LibraryCategoryTitle(_category)], @"category");
    add([NSString stringWithFormat:OR6L(@"Source: %@"), OR6Chat6LibrarySourceTitle(_source)], @"source");
    if (viewable) add([view[@"layout"] isEqual:@"grid"] ? OR6L(@"Show as list") : OR6L(@"Show as grid"), @"layout");
    if (viewable) add([view[@"sort"] isEqual:@"name"] ? OR6L(@"Service order") : OR6L(@"Sort by name"), @"sort");
    if ([self canCreate]) add(OR6L(@"New folder…"), @"create");
    if (_directoryId && OR6Chat6On(_core, @"library.node.get")) add(OR6L(@"Folder details"), @"details");
    OR6Chat8ShowSheet(Host(self), nil, titles, nil, ^(NSInteger i, NSString *t) { (void)t; if (i >= 0 && (NSUInteger)i < keys.count) [self option:keys[(NSUInteger)i]]; });
}
- (void)option:(NSString *)key {
    NSDictionary *view = [self currentView];
    if ([key isEqual:@"category"] || [key isEqual:@"source"]) {
        BOOL cat = [key isEqual:@"category"]; NSArray *values = cat ? OR6Chat6LibraryCategories() : OR6Chat6LibrarySources();
        NSMutableArray *titles = [NSMutableArray arrayWithObject:(cat ? OR6Chat6LibraryCategoryTitle(nil) : OR6Chat6LibrarySourceTitle(nil))];
        for (NSString *v in values) [titles addObject:cat ? OR6Chat6LibraryCategoryTitle(v) : OR6Chat6LibrarySourceTitle(v)];
        OR6Chat8ShowSheet(Host(self), (cat ? OR6L(@"File type") : OR6L(@"Source")), titles, nil, ^(NSInteger i, NSString *t) {
            (void)t; if (i < 0 || (NSUInteger)i > values.count) return;
            NSString *v = i == 0 ? nil : values[(NSUInteger)i - 1];
            if (cat) { [_category release]; _category = [v copy]; } else { [_source release]; _source = [v copy]; }
            [self applyFilters];
        });
    } else if ([key isEqual:@"layout"] || [key isEqual:@"sort"]) {
        BOOL layout = [key isEqual:@"layout"];
        NSString *l = layout ? ([view[@"layout"] isEqual:@"grid"] ? @"list" : @"grid") : view[@"layout"];
        NSString *s = layout ? view[@"sort"] : ([view[@"sort"] isEqual:@"name"] ? @"server" : @"name");
        _reloadAfterView = !layout;
        [_viewSet perform:@"library.view.set" parameters:@{@"layout": l, @"sort": s}]; [self render];
    } else if ([key isEqual:@"create"]) {
        CreateFolder(self, _core, _directoryId, ^{ [self load]; });
    } else if ([key isEqual:@"details"]) {
        NSString *selfId = _directoryId; UINavigationController *nc = self.navigationController; void (^changed)(void) = [[_changed copy] autorelease];
        OR6Chat6LibraryNodeScreen *c = [[[OR6Chat6LibraryNodeScreen alloc] initWithCore:_core navigator:_nav node:[self folder] identifier:selfId kind:@"directory" favorites:NO changed:^(NSString *change) {
            if (changed) changed();
            if ([change isEqual:@"renamed"] || [change isEqual:@"favorite"]) { [self load]; return; }
            NSUInteger at = [nc.viewControllers indexOfObject:self]; // moved/deleted: this folder's screen is no longer where it was
            if (at != NSNotFound && at > 0) [nc popToViewController:nc.viewControllers[at - 1] animated:YES]; else [self load];
        }] autorelease];
        [self.navigationController pushViewController:c animated:YES];
    }
}
- (void)grid:(RCGridViewController *)g didSelectItem:(RCGridItem *)item {
    (void)g; id i = item.userInfo;
    if ([i isEqual:@"more"]) { [_pager loadMore]; [self render]; return; }
    if ([i isEqual:@"retry"]) { [_pager retry]; [self render]; return; }
    NSDictionary *n = OR6Chat6LibraryNode(i); if (!n) return;
    if (OR6Chat6LibraryIsFolder(n)) {
        if (!NativeId(n[@"id"])) return;
        [self.navigationController pushViewController:[[[OR6Chat6LibraryBrowser alloc] initWithCore:_core navigator:_nav directory:n[@"id"] title:OR6Chat6Text(n[@"name"], OR6L(@"Folder")) changed:^{ [self load]; }] autorelease] animated:YES];
        return;
    }
    UINavigationController *nc = self.navigationController;
    [nc pushViewController:[[[OR6Chat6LibraryNodeScreen alloc] initWithCore:_core navigator:_nav node:n identifier:n[@"id"] kind:@"file" favorites:NO changed:^(NSString *change) { (void)change; [self load]; }] autorelease] animated:YES];
}
// One read after typing pauses (0.45 s); the keyboard «Search» reads at once.
- (void)grid:(RCGridViewController *)g searchTextDidChange:(NSString *)text {
    (void)g; [_timer invalidate]; _timer = nil;
    NSString *q = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]; if ([q isEqual:_query ?: @""]) return;
    [_query release]; _query = [q copy]; [_pager cancel];
    _timer = [NSTimer scheduledTimerWithTimeInterval:.45 target:self selector:@selector(searchTimer:) userInfo:nil repeats:NO];
}
- (void)grid:(RCGridViewController *)g searchDidSubmit:(NSString *)text {
    (void)g; (void)text; if (!_timer) return; [_timer invalidate]; _timer = nil; [self applyFilters];
}
- (void)searchTimer:(NSTimer *)t { (void)t; _timer = nil; [self applyFilters]; }
- (void)dealloc {
    [_timer invalidate]; self.delegate = nil;
    _pager.delegate = nil; [_pager cancel]; [_pager release]; _path.delegate = nil; [_path cancel]; [_path release];
    _viewGet.delegate = nil; [_viewGet cancel]; [_viewGet release]; _viewSet.delegate = nil; [_viewSet cancel]; [_viewSet release];
    [_core release]; [_directoryId release]; [_query release]; [_category release]; [_source release]; [_changed release]; [super dealloc];
}
@end

#pragma mark - Node card (library.node.get; rename, move, favorite, delete)

@implementation OR6Chat6LibraryNodeScreen
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav node:(NSDictionary *)node identifier:(NSString *)nodeId kind:(NSString *)kind favorites:(BOOL)favorites changed:(void (^)(NSString *))changed {
    if ((self = [super initWithCore:core navigator:nav title:OR6Chat6Text(node[@"name"], [kind isEqual:@"directory"] ? OR6L(@"Folder") : OR6L(@"File"))])) {
        _id = [nodeId copy]; _kind = [kind copy]; _seed = [([node[@"id"] isEqual:nodeId] ? node : nil) copy]; _favorites = favorites; _changed = [changed copy];
        _fav = [self call]; _where = [self call];
        self.tableView.accessibilityIdentifier = @"chat.library6.node";
    }
    return self;
}
- (BOOL)isFile { return [_kind isEqual:@"file"]; }
- (void)load {
    if (OR6Chat6On(_core, @"library.node.get")) [_read perform:@"library.node.get" parameters:@{@"id": _id, @"kind": _kind}];
    if ([self isFile] && OR6Chat6On(_core, @"library.favorite.status")) [_fav perform:@"library.favorite.status" parameters:@{@"id": _id}];
    [self render];
}
- (NSDictionary *)node {
    NSDictionary *n = OR6Chat6LibraryNode(_read.result);
    if ([n[@"id"] isEqual:_id] && [n[@"kind"] isEqual:_kind]) return n;
    return _read.busy || _read.error || !OR6Chat6On(_core, @"library.node.get") ? _seed : nil;
}
- (BOOL)fresh { NSDictionary *n = OR6Chat6LibraryNode(_read.result); return [n[@"id"] isEqual:_id] && !_read.busy; } // writes only from a fresh card
- (BOOL)can:(NSString *)op { return [self fresh] && OR6Chat6LibraryCanMutate([self node]) && ![self node][@"trashedAt"] && OR6Chat6On(_core, op); }
- (void)chat8ModelChanged:(id)m {
    if (m == _read && [self fresh]) {
        NSDictionary *n = [self node]; self.title = OR6Chat6Text(n[@"name"], self.title);
        id parent = n[@"parentId"];
        if (NativeId(parent) && OR6Chat6On(_core, @"library.folder.path")) [_where perform:@"library.folder.path" parameters:@{@"directoryId": parent}];
        else [_where reset];
    }
    [super chat8ModelChanged:m];
}
- (void)render {
    NSDictionary *n = [self node]; NSMutableArray *sections = [NSMutableArray array];
    if (!n) {
        NSMutableArray *rows = [NSMutableArray array];
        if (![self addStateOf:_read to:rows empty:nil hasItems:NO identifier:@"chat.library6.node"]) [rows addObject:[self note:(OR6Chat6On(_core, @"library.node.get") ? OR6L(@"Loading…") : OR6L(@"This item cannot be read now."))]];
        self.sections = @[[RCFormSection sectionWithTitle:nil rows:rows]]; return;
    }
    RCFormRow *head = NodeRow(n, @"chat.library6.node.name", NO); head.subtitle = OR6Chat6LibraryKindTitle(n);
    NSMutableArray *info = [NSMutableArray arrayWithObject:head];
    if (!OR6Chat6LibraryIsFolder(n) && OR6Chat6Text(n[@"mediaType"], nil)) [info addObject:[self value:OR6L(@"Type") value:n[@"mediaType"] info:nil identifier:@"chat.library6.node.type"]];
    if (OR6Chat6Bytes(n[@"bytes"])) [info addObject:[self value:OR6L(@"Size") value:OR6Chat6Bytes(n[@"bytes"]) info:nil identifier:@"chat.library6.node.size"]];
    if (OR6Chat6RelativeDate(n[@"updatedAt"])) [info addObject:[self value:OR6L(@"Updated") value:OR6Chat6RelativeDate(n[@"updatedAt"]) info:nil identifier:@"chat.library6.node.updated"]];
    NSString *where = n[@"parentId"] == nil || n[@"parentId"] == NSNull.null ? OR6L(@"Library") : _where.result ? OR6Chat6LibraryPathText(_where.result[@"items"]) : nil;
    if (where) [info addObject:[self value:OR6L(@"Location") value:where info:nil identifier:@"chat.library6.node.location"]];
    [info addObject:[self value:OR6L(@"Access") value:OR6Chat6LibraryAccessTitle(n[@"access"]) info:nil identifier:@"chat.library6.node.access"]];
    if (n[@"trashedAt"] && n[@"trashedAt"] != NSNull.null) [info addObject:[self value:OR6L(@"In Trash since") value:(OR6Chat6RelativeDate(n[@"trashedAt"]) ?: OR6L(@"Unknown")) info:nil identifier:@"chat.library6.node.trashed"]];
    [self addStateOf:_read to:info empty:nil hasItems:YES identifier:@"chat.library6.node"];
    [sections addObject:[RCFormSection sectionWithTitle:nil rows:info]];
    // Favorite state (files): library.favorite.status, then library.favorite.set on an explicit tap.
    if ([self isFile] && OR6Chat6On(_core, @"library.favorite.status")) {
        NSMutableArray *rows = [NSMutableArray array]; NSDictionary *f = [_fav.result[@"targetId"] isEqual:_id] ? _fav.result : nil;
        if (f) {
            BOOL on = [f[@"isFavorited"] isEqual:@YES];
            [rows addObject:[self value:OR6L(@"In favorites") value:(on ? OR6L(@"Yes") : OR6L(@"No")) info:nil identifier:@"chat.library6.node.favorite_state"]];
            if (![f[@"available"] isEqual:@YES]) [rows addObject:[self note:OR6L(@"This file cannot be added to favorites.")]];
            else if ([self can:@"library.favorite.set"]) [rows addObject:[self button:(on ? OR6L(@"Remove from favorites") : OR6L(@"Add to favorites")) info:@"favorite" identifier:@"chat.library6.node.favorite"]];
        } else [self addStateOf:_fav to:rows empty:nil hasItems:NO identifier:@"chat.library6.node.favorite_state"];
        if (rows.count) [sections addObject:[RCFormSection sectionWithTitle:OR6L(@"Favorites") rows:rows]];
    }
    NSMutableArray *acts = [NSMutableArray array];
    if ([self can:@"library.node.rename"]) [acts addObject:[self button:OR6L(@"Rename…") info:@"rename" identifier:@"chat.library6.node.rename"]];
    if ([self can:@"library.node.move"] && (OR6Chat6On(_core, @"library.browse") || (_favorites && OR6Chat6On(_core, @"library.favoriteFolders.list")))) [acts addObject:[self button:OR6L(@"Move to folder…") info:@"move" identifier:@"chat.library6.node.move"]];
    if ([self can:@"library.node.delete"]) { RCFormRow *d = [self button:OR6L(@"Move to Trash") info:@"delete" identifier:@"chat.library6.node.delete"]; d.destructive = YES; [acts addObject:d]; }
    RCFormSection *a = [RCFormSection sectionWithTitle:nil rows:acts];
    if ([self fresh] && !OR6Chat6LibraryCanMutate(n)) a.footer = OR6L(@"This item cannot be changed from ChatGPT X: it is shared with you, comes from a connected source or is managed by the service.");
    else if ([self fresh] && n[@"trashedAt"] && n[@"trashedAt"] != NSNull.null) a.footer = OR6L(@"This item is in Trash. Restore it from Trash first.");
    if (acts.count || a.footer) [sections addObject:a];
    self.sections = sections;
}
- (void)write:(NSString *)op parameters:(NSDictionary *)p done:(NSString *)done change:(NSString *)change {
    UINavigationController *nc = self.navigationController; void (^changed)(NSString *) = [[_changed copy] autorelease];
    OR6Chat7RunWrite(Host(self), _core, op, p, Intent(op, _id), @"catalog.reconcile", done, ^(NSDictionary *r) {
        (void)r; if (changed) changed(change);
        if ([change isEqual:@"deleted"]) { if (nc.topViewController == self) [nc popViewControllerAnimated:YES]; }
        else [self load]; // read the card again
    });
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    NSDictionary *n = [self node]; id i = row.userInfo;
    if ([i isEqual:@"rename"] && [self can:@"library.node.rename"]) {
        NSString *old = OR6Chat6Text(n[@"name"], @"");
        AskName(self, ([self isFile] ? OR6L(@"Rename file") : OR6L(@"Rename folder")), old, OR6L(@"Rename"), ^(NSString *name) {
            if ([name isEqual:old]) return;
            [self write:@"library.node.rename" parameters:@{@"id": _id, @"kind": _kind, @"name": name} done:OR6L(@"Renamed.") change:@"renamed"];
        });
        return;
    }
    if ([i isEqual:@"move"] && [self can:@"library.node.move"]) {
        UINavigationController *nc = self.navigationController; void (^changed)(NSString *) = [[_changed copy] autorelease];
        OR6Chat6LibraryFolderPicker *p = [[[OR6Chat6LibraryFolderPicker alloc] initWithCore:_core node:n directory:nil title:OR6L(@"Move to") favorites:_favorites moved:^{
            if ([nc.viewControllers containsObject:self]) [nc popToViewController:self animated:YES]; [self load]; if (changed) changed(@"moved");
        }] autorelease];
        [nc pushViewController:p animated:YES]; return;
    }
    if ([i isEqual:@"favorite"] && [self can:@"library.favorite.set"]) {
        BOOL on = ![_fav.result[@"isFavorited"] isEqual:@YES]; NSDictionary *p = OR6Chat6LibraryFavoriteParameters(_id, on); if (!p) return;
        [self write:@"library.favorite.set" parameters:p done:(on ? OR6L(@"Added to favorites.") : OR6L(@"Removed from favorites.")) change:@"favorite"]; return;
    }
    if ([i isEqual:@"delete"] && [self can:@"library.node.delete"]) {
        NSString *name = OR6Chat6Text(n[@"name"], OR6L(@"Untitled"));
        NSString *q = [self isFile] ? [NSString stringWithFormat:OR6L(@"Move «%@» to Trash? You can restore it from Trash."), name]
                                    : [NSString stringWithFormat:OR6L(@"Move the folder «%@» and everything in it to Trash?"), name];
        OR6Chat6Confirm(Host(self), q, OR6L(@"Move to Trash"), YES, ^{ [self write:@"library.node.delete" parameters:@{@"id": _id, @"kind": _kind} done:OR6L(@"Moved to Trash.") change:@"deleted"]; });
        return;
    }
    [super form:f didSelectRow:row];
}
- (void)dealloc { [_id release]; [_kind release]; [_seed release]; [_changed release]; [super dealloc]; }
@end

#pragma mark - Folder picker for «Move to folder…»

@implementation OR6Chat6LibraryFolderPicker
- (id)initWithCore:(OR6APICore *)core node:(NSDictionary *)node directory:(NSString *)dir title:(NSString *)title favorites:(BOOL)favorites moved:(void (^)(void))moved {
    if ((self = [super initWithCore:core navigator:nil title:title])) {
        _node = [node copy]; _dir = [dir copy]; _favorites = favorites && !dir && OR6Chat6On(core, @"library.favoriteFolders.list"); _moved = [moved copy];
        _list = _favorites ? [self pager:@"library.favoriteFolders.list" parameters:@{} tokenKey:@"pageToken" nextKey:@"nextPageToken" idKey:@"id"]
                           : [self pager:@"library.browse" parameters:OR6Chat6LibraryBrowseParameters(_dir, @"", nil, nil) tokenKey:@"pageToken" nextKey:@"nextPageToken" idKey:@"id"];
        _check = [self call];
        self.tableView.accessibilityIdentifier = @"chat.library6.picker";
    }
    return self;
}
- (void)load {
    [_list reload];
    if (_dir && OR6Chat6On(_core, @"library.folder.path")) [_read perform:@"library.folder.path" parameters:@{@"directoryId": _dir}];
    [self render];
}
- (NSString *)knownProblem { // what is already clear before the fresh check
    if (!_dir) return OR6Chat6LibraryMoveProblem(_node, nil, nil);
    if (!OR6Chat6On(_core, @"library.folder.path")) return OR6L(@"ChatGPT X cannot check this folder, so it cannot move items into it.");
    NSArray *path = _read.result[@"items"]; // only a path that ends at this folder tells anything yet
    return [OR6Chat6LibraryNode([path lastObject])[@"id"] isEqual:_dir] ? OR6Chat6LibraryMoveProblem(_node, _dir, path) : nil;
}
- (void)render {
    NSMutableArray *sections = [NSMutableArray array], *top = [NSMutableArray array];
    NSString *problem = [self knownProblem];
    if (problem) [top addObject:[self note:problem]];
    else { RCFormRow *b = [self button:OR6L(@"Move here") info:@"move" identifier:@"chat.library6.picker.move"]; b.busy = _check.busy; [top addObject:b]; }
    if (_check.error) [top addObject:[self note:OR6Chat7ErrorText(_check.error)]];
    NSString *where = !_dir ? OR6L(@"Library") : _read.result ? OR6Chat6LibraryPathText(_read.result[@"items"]) : nil;
    RCFormSection *s = [RCFormSection sectionWithTitle:where rows:top];
    s.footer = [NSString stringWithFormat:OR6L(@"«%@» is moved here."), OR6Chat6Text(_node[@"name"], OR6L(@"Untitled"))];
    [sections addObject:s];
    NSMutableArray *rows = [NSMutableArray array];
    for (NSDictionary *n in Nodes(_list.items)) {
        if (!OR6Chat6LibraryIsFolder(n) || !NativeId(n[@"id"]) || [n[@"id"] isEqual:_node[@"id"]]) continue; // a folder is never offered inside itself
        [rows addObject:NodeRow(n, @"chat.library6.picker.folder", YES)];
    }
    BOOL state = [self addStateOfPager:_list to:rows empty:nil identifier:@"chat.library6.picker"];
    if (!rows.count && !state && _list.loaded) [rows addObject:[self note:OR6L(@"No folders here.")]];
    [sections addObject:[RCFormSection sectionWithTitle:(_favorites ? OR6L(@"Favorite folders") : OR6L(@"Folders")) rows:rows]];
    self.sections = sections;
}
- (void)move {
    NSString *problem = OR6Chat6LibraryMoveProblem(_node, _dir, _check.result[@"items"]);
    if (problem) { OR6Chat6Say(Host(self), problem); [self render]; return; }
    void (^moved)(void) = [[_moved copy] autorelease];
    OR6Chat7RunWrite(Host(self), _core, @"library.node.move", @{@"id": _node[@"id"], @"kind": _node[@"kind"], @"parentId": _dir ?: (id)NSNull.null},
                     Intent(@"library.node.move", _node[@"id"]), @"catalog.reconcile", OR6L(@"Moved."), ^(NSDictionary *r) { (void)r; if (moved) moved(); });
}
- (void)chat8ModelChanged:(id)m {
    if (m == _check && _moveAfterCheck && !_check.busy) { _moveAfterCheck = NO; if (_check.result && !_check.error) [self move]; }
    [super chat8ModelChanged:m];
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    id i = row.userInfo;
    if ([i isEqual:@"move"]) {
        if ([self knownProblem] || _check.busy) return;
        if (!_dir) { [self move]; return; }
        _moveAfterCheck = YES; // the destination's path is read fresh right before the move
        if (![_check perform:@"library.folder.path" parameters:@{@"directoryId": _dir}]) _moveAfterCheck = NO;
        [self render]; return;
    }
    NSDictionary *n = OR6Chat6LibraryNode(i);
    if (n && OR6Chat6LibraryIsFolder(n)) {
        [self.navigationController pushViewController:[[[OR6Chat6LibraryFolderPicker alloc] initWithCore:_core node:_node directory:n[@"id"] title:OR6Chat6Text(n[@"name"], OR6L(@"Folder")) favorites:NO moved:_moved] autorelease] animated:YES];
        return;
    }
    [super form:f didSelectRow:row];
}
- (void)dealloc { [_node release]; [_dir release]; [_moved release]; [super dealloc]; }
@end

#pragma mark - Trash (library.trash.list; restore, delete forever, empty)

@interface OR6Chat6LibraryTrash : OR6Chat6Form { OR6Chat6Pager *_list; }
@end
@implementation OR6Chat6LibraryTrash
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav title:(NSString *)title {
    if ((self = [super initWithCore:core navigator:nav title:title])) {
        _list = [self pager:@"library.trash.list" parameters:@{} tokenKey:@"pageToken" nextKey:@"nextPageToken" idKey:@"id"];
        self.tableView.accessibilityIdentifier = @"chat.library6.trash";
    }
    return self;
}
- (void)load { [_list reload]; [self render]; }
- (BOOL)actionable:(NSDictionary *)n { return !OR6Chat6LibraryIsFolder(n) && OR6Chat6LibraryCanMutate(n) && (OR6Chat6On(_core, @"library.node.restore") || OR6Chat6On(_core, @"library.node.deleteForever")); }
- (void)render {
    NSMutableArray *rows = [NSMutableArray array]; BOOL folders = NO;
    for (NSDictionary *n in Nodes(_list.items)) { if (OR6Chat6LibraryIsFolder(n)) folders = YES; [rows addObject:NodeRow(n, @"chat.library6.trash.row", [self actionable:n])]; }
    [self addStateOfPager:_list to:rows empty:OR6L(@"Trash is empty.") identifier:@"chat.library6.trash"];
    RCFormSection *s = [RCFormSection sectionWithTitle:nil rows:rows];
    s.footer = folders ? OR6L(@"Files in Trash can be restored. Folders in Trash cannot be restored or deleted from ChatGPT X.") : OR6L(@"Files in Trash can be restored.");
    NSMutableArray *sections = [NSMutableArray arrayWithObject:s];
    if (OR6Chat6On(_core, @"library.trash.empty") && _list.loaded && _list.items.count) {
        RCFormRow *e = [self button:OR6L(@"Empty Trash") info:@"empty" identifier:@"chat.library6.trash.empty"]; e.destructive = YES;
        RCFormSection *x = [RCFormSection sectionWithTitle:nil rows:@[e]]; x.footer = OR6L(@"Emptying Trash deletes every file in it forever, including files not shown yet."); [sections addObject:x];
    }
    self.sections = sections;
}
- (void)write:(NSString *)op parameters:(NSDictionary *)p target:(NSString *)target done:(NSString *)done {
    OR6Chat7RunWrite(Host(self), _core, op, p, Intent(op, target), @"catalog.reconcile", done, ^(NSDictionary *r) { (void)r; [self load]; });
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    id i = row.userInfo;
    if ([i isEqual:@"empty"]) {
        OR6Chat6Confirm(Host(self), OR6L(@"Delete everything in Trash forever? This cannot be undone."), OR6L(@"Empty Trash"), YES, ^{
            [self write:@"library.trash.empty" parameters:@{} target:@"account" done:OR6L(@"Trash emptied.")];
        });
        return;
    }
    NSDictionary *n = OR6Chat6LibraryNode(i);
    if (n && [self actionable:n]) {
        NSString *nodeId = n[@"id"], *name = OR6Chat6Text(n[@"name"], OR6L(@"Untitled"));
        BOOL restore = OR6Chat6On(_core, @"library.node.restore"), forever = OR6Chat6On(_core, @"library.node.deleteForever");
        OR6Chat8ShowSheet(Host(self), name, (restore ? @[OR6L(@"Restore")] : @[]), (forever ? OR6L(@"Delete forever") : nil), ^(NSInteger k, NSString *t) {
            (void)t;
            if (k == 0 && restore) [self write:@"library.node.restore" parameters:@{@"id": nodeId} target:nodeId done:OR6L(@"Restored.")];
            else if (k == -2 && forever) OR6Chat6Confirm(Host(self), [NSString stringWithFormat:OR6L(@"Delete «%@» forever? This cannot be undone."), name], OR6L(@"Delete forever"), YES, ^{
                [self write:@"library.node.deleteForever" parameters:@{@"id": nodeId} target:nodeId done:OR6L(@"Deleted forever.")];
            });
        });
        return;
    }
    [super form:f didSelectRow:row];
}
@end

#pragma mark - Favorites (library.favorites.list, favorite folders)

@interface OR6Chat6LibraryFavorites : OR6Chat6Form { OR6Chat6Pager *_list, *_folders; NSString *_kind; }
@end
@implementation OR6Chat6LibraryFavorites
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav title:(NSString *)title {
    if ((self = [super initWithCore:core navigator:nav title:title])) {
        _list = [self pager:@"library.favorites.list" parameters:@{@"kind": NSNull.null} tokenKey:@"pageToken" nextKey:@"nextPageToken" idKey:@"favoriteId"];
        if (OR6Chat6On(core, @"library.favoriteFolders.list")) _folders = [self pager:@"library.favoriteFolders.list" parameters:@{} tokenKey:@"pageToken" nextKey:@"nextPageToken" idKey:@"id"];
        self.tableView.accessibilityIdentifier = @"chat.library6.favorites";
    }
    return self;
}
- (void)load { [_list reload]; [_folders reload]; [self render]; }
- (BOOL)opens:(NSDictionary *)item { NSDictionary *n = OR6Chat6LibraryNode(item[@"node"]); return n && [@[@"file", @"image"] containsObject:item[@"kind"] ?: @""] && !OR6Chat6LibraryIsFolder(n) && NativeId(n[@"id"]) && OR6Chat6On(_core, @"library.node.get"); }
- (void)render {
    NSMutableArray *sections = [NSMutableArray array];
    RCFormRow *k = [self value:OR6L(@"Show") value:OR6Chat6LibraryFavoriteKindTitle(_kind) info:@"kind" identifier:@"chat.library6.favorites.kind"];
    [sections addObject:[RCFormSection sectionWithTitle:nil rows:@[k]]];
    NSMutableArray *rows = [NSMutableArray array]; BOOL others = NO;
    for (NSDictionary *item in _list.items) {
        NSDictionary *n = OR6Chat6LibraryNode(item[@"node"]); if (!n) continue;
        BOOL opens = [self opens:item]; if (!opens) others = YES;
        RCFormRow *r = NodeRow(n, @"chat.library6.favorites.row", opens);
        NSString *d = OR6Chat6RelativeDate(n[@"updatedAt"]); NSString *kind = OR6Chat6LibraryFavoriteKindTitle(item[@"kind"]);
        r.subtitle = d ? [NSString stringWithFormat:@"%@ · %@", kind, d] : kind;
        if (![item[@"kind"] isEqual:@"file"]) { r.glyph = OR6Chat6LibraryFavoriteKindGlyph(item[@"kind"]); r.tile = RCTileYellow; }
        r.userInfo = item; [rows addObject:r];
    }
    [self addStateOfPager:_list to:rows empty:(_kind ? OR6L(@"Nothing of this kind in favorites.") : OR6L(@"No favorites yet.")) identifier:@"chat.library6.favorites"];
    RCFormSection *s = [RCFormSection sectionWithTitle:nil rows:rows];
    if (others) s.footer = OR6L(@"Saved answers, places, products and other saved items are listed here; ChatGPT X opens only files from favorites.");
    [sections addObject:s];
    if (_folders) {
        NSMutableArray *f = [NSMutableArray array];
        for (NSDictionary *n in Nodes(_folders.items)) if (OR6Chat6LibraryIsFolder(n)) [f addObject:NodeRow(n, @"chat.library6.favorites.folder", NativeId(n[@"id"]) && OR6Chat6On(_core, @"library.browse"))];
        [self addStateOfPager:_folders to:f empty:OR6L(@"No folders yet.") identifier:@"chat.library6.favorites.folders"];
        if (OR6Chat6On(_core, @"library.folder.create")) [f addObject:[self button:OR6L(@"New folder…") info:@"create" identifier:@"chat.library6.favorites.create"]];
        RCFormSection *x = [RCFormSection sectionWithTitle:OR6L(@"Folders") rows:f];
        if (OR6Chat6On(_core, @"library.node.move")) x.footer = OR6L(@"To put a favorite file into a folder, open it and choose Move to folder.");
        [sections addObject:x];
    }
    self.sections = sections;
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    id i = row.userInfo;
    if ([i isEqual:@"kind"]) {
        NSArray *kinds = OR6Chat6LibraryFavoriteKinds(); NSMutableArray *titles = [NSMutableArray arrayWithObject:OR6Chat6LibraryFavoriteKindTitle(nil)];
        for (NSString *k in kinds) [titles addObject:OR6Chat6LibraryFavoriteKindTitle(k)];
        OR6Chat8ShowSheet(Host(self), OR6L(@"Show"), titles, nil, ^(NSInteger n, NSString *t) {
            (void)t; if (n < 0 || (NSUInteger)n > kinds.count) return;
            NSString *k = n == 0 ? nil : kinds[(NSUInteger)n - 1]; [_kind release]; _kind = [k copy];
            _list.parameters = @{@"kind": _kind ?: (id)NSNull.null}; [_list reload]; [self render];
        });
        return;
    }
    if ([i isEqual:@"create"]) { CreateFolder(self, _core, nil, ^{ [_folders reload]; [self render]; }); return; }
    if ([i isKindOfClass:NSDictionary.class] && i[@"favoriteId"] && [self opens:i]) {
        NSDictionary *n = i[@"node"];
        [self.navigationController pushViewController:[[[OR6Chat6LibraryNodeScreen alloc] initWithCore:_core navigator:_nav node:n identifier:n[@"id"] kind:@"file" favorites:YES changed:^(NSString *c) { (void)c; [self load]; }] autorelease] animated:YES];
        return;
    }
    NSDictionary *n = OR6Chat6LibraryNode(i);
    if (n && OR6Chat6LibraryIsFolder(n) && NativeId(n[@"id"]) && OR6Chat6On(_core, @"library.browse")) {
        [self.navigationController pushViewController:[[[OR6Chat6LibraryBrowser alloc] initWithCore:_core navigator:_nav directory:n[@"id"] title:OR6Chat6Text(n[@"name"], OR6L(@"Folder")) changed:^{ [self load]; }] autorelease] animated:YES];
        return;
    }
    [super form:f didSelectRow:row];
}
- (void)dealloc { [_kind release]; [super dealloc]; }
@end

#pragma mark - Connected sources (read-only: capabilities, roots, browse, search)

@interface OR6Chat6LibraryMounted : OR6Chat6Form { NSString *_provider, *_dir, *_query; OR6Chat6Pager *_list; OR6Chat7Call *_search; NSTimer *_timer; }
- (id)initWithCore:(OR6APICore *)core provider:(NSString *)provider directory:(NSString *)dir title:(NSString *)title;
@end
@implementation OR6Chat6LibraryMounted
- (id)initWithCore:(OR6APICore *)core provider:(NSString *)provider directory:(NSString *)dir title:(NSString *)title {
    if ((self = [super initWithCore:core navigator:nil title:title])) {
        _provider = [provider copy]; _dir = [dir copy]; _search = [self call];
        NSDictionary *p = OR6Chat6LibraryMountedBrowseParameters(provider, dir);
        if (p && OR6Chat6On(core, @"library.mounted.browse")) _list = [self pager:@"library.mounted.browse" parameters:p tokenKey:@"pageToken" nextKey:@"nextPageToken" idKey:@"id"];
        self.tableView.accessibilityIdentifier = @"chat.library6.mounted";
    }
    return self;
}
- (BOOL)searchable { return !_dir && OR6Chat6On(_core, @"library.mounted.search"); }
- (void)load { [_list reload]; [self render]; }
- (void)viewWillDisappear:(BOOL)a { [super viewWillDisappear:a]; [_timer invalidate]; _timer = nil; }
- (NSArray *)rowsFor:(NSArray *)items {
    NSMutableArray *rows = [NSMutableArray array];
    for (NSDictionary *n in Nodes(items)) {
        BOOL open = OR6Chat6LibraryIsFolder(n) && OR6Chat6On(_core, @"library.mounted.browse") && OR6Chat6LibraryMountedBrowseParameters(_provider, n[@"id"]) && [OR6Chat6LibraryProviderOfId(n[@"id"]) isEqual:_provider];
        [rows addObject:NodeRow(n, @"chat.library6.mounted.row", open)];
    }
    return rows;
}
- (void)render {
    NSMutableArray *sections = [NSMutableArray array];
    if ([self searchable]) {
        RCFormRow *q = [RCFormRow rowWithKind:RCFormRowText title:OR6L(@"Search")]; q.text = _query; q.maxLength = 256; q.identifier = @"chat.library6.mounted.search";
        q.placeholder = [NSString stringWithFormat:OR6L(@"Search in %@"), OR6Chat6LibraryProviderTitle(_provider)];
        [sections addObject:[RCFormSection sectionWithTitle:nil rows:@[q]]];
        if (_query.length) {
            NSMutableArray *rows = [NSMutableArray arrayWithArray:[self rowsFor:_search.result[@"items"]]];
            [self addStateOf:_search to:rows empty:OR6L(@"Nothing found.") hasItems:rows.count > 0 identifier:@"chat.library6.mounted.results"];
            [sections addObject:[RCFormSection sectionWithTitle:OR6L(@"Results") rows:rows]];
        }
    }
    if (_list) {
        NSMutableArray *rows = [NSMutableArray arrayWithArray:[self rowsFor:_list.items]];
        [self addStateOfPager:_list to:rows empty:OR6L(@"This folder is empty.") identifier:@"chat.library6.mounted.list"];
        [sections addObject:[RCFormSection sectionWithTitle:nil rows:rows]];
    } else if (![self searchable]) [sections addObject:[RCFormSection sectionWithTitle:nil rows:@[[self note:OR6L(@"ChatGPT X cannot open this source now.")]]]];
    RCFormSection *last = sections.lastObject;
    last.footer = OR6L(@"Connected sources are read-only here: files are not downloaded, copied or attached.");
    self.sections = sections;
}
- (void)form:(RCFormViewController *)f didChangeTextOfRow:(RCFormRow *)row {
    (void)f; if (![row.identifier isEqual:@"chat.library6.mounted.search"]) return;
    NSString *t = [row.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]; if ([t isEqual:_query ?: @""]) return;
    [_query release]; _query = [t copy]; [_timer invalidate]; _timer = nil; [_search cancel];
    if (!_query.length) { [_search reset]; [self render]; return; }
    _timer = [NSTimer scheduledTimerWithTimeInterval:.45 target:self selector:@selector(searchTimer:) userInfo:nil repeats:NO]; // one read after typing pauses
}
- (void)searchTimer:(NSTimer *)t {
    (void)t; _timer = nil; NSDictionary *p = OR6Chat6LibraryMountedSearchParameters(_provider, _query);
    if (p) [_search perform:@"library.mounted.search" parameters:p]; [self render];
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    NSDictionary *n = OR6Chat6LibraryNode(row.userInfo);
    if (n && OR6Chat6LibraryIsFolder(n) && OR6Chat6LibraryMountedBrowseParameters(_provider, n[@"id"]) && OR6Chat6On(_core, @"library.mounted.browse")) {
        [self.navigationController pushViewController:[[[OR6Chat6LibraryMounted alloc] initWithCore:_core provider:_provider directory:n[@"id"] title:OR6Chat6Text(n[@"name"], OR6L(@"Folder"))] autorelease] animated:YES];
        return;
    }
    if ([row.userInfo isEqual:@"retry"] && _query.length) { [self searchTimer:nil]; return; } // the search's own «Read again»
    [super form:f didSelectRow:row];
}
- (void)dealloc { [_timer invalidate]; [_provider release]; [_dir release]; [_query release]; [super dealloc]; }
@end

@interface OR6Chat6LibrarySourcesScreen : OR6Chat6Form { OR6Chat7Call *_roots; }
@end
@implementation OR6Chat6LibrarySourcesScreen
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav title:(NSString *)title {
    if ((self = [super initWithCore:core navigator:nav title:title])) { _roots = [self call]; self.tableView.accessibilityIdentifier = @"chat.library6.sources"; }
    return self;
}
- (void)load {
    [_read perform:@"library.mounted.capabilities" parameters:@{}];
    if (OR6Chat6On(_core, @"library.mounted.roots")) [_roots perform:@"library.mounted.roots" parameters:@{}];
    [self render];
}
- (BOOL)available:(NSString *)provider {
    for (NSDictionary *p in _read.result[@"providers"]) if ([p isKindOfClass:NSDictionary.class] && [p[@"provider"] isEqual:provider]) return [p[@"state"] isEqual:@"available"];
    return NO;
}
- (void)render {
    NSMutableArray *sections = [NSMutableArray array], *rows = [NSMutableArray array]; BOOL unavailable = NO;
    for (NSDictionary *p in [_read.result[@"providers"] isKindOfClass:NSArray.class] ? _read.result[@"providers"] : @[]) {
        if (![p isKindOfClass:NSDictionary.class] || ![OR6Chat6LibraryProviders() containsObject:p[@"provider"] ?: @""]) continue;
        BOOL on = [p[@"state"] isEqual:@"available"], open = on && OR6Chat6On(_core, @"library.mounted.search"); if (!on) unavailable = YES;
        RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:OR6Chat6LibraryProviderTitle(p[@"provider"])];
        r.value = on ? OR6L(@"Connected") : [p[@"state"] isEqual:@"unavailable"] ? OR6L(@"Not available") : OR6L(@"Unknown");
        r.showsLamp = YES; r.lamp = on ? RCLampOK : [p[@"state"] isEqual:@"unavailable"] ? RCLampOff : RCLampWarn;
        r.glyph = @"cloud"; r.tile = RCTileTeal; r.disclosure = open; r.enabled = open; r.userInfo = open ? @{@"provider": p[@"provider"]} : nil; r.identifier = @"chat.library6.sources.provider";
        [rows addObject:r];
    }
    [self addStateOf:_read to:rows empty:OR6L(@"No connected sources.") hasItems:rows.count > 0 identifier:@"chat.library6.sources"];
    RCFormSection *s = [RCFormSection sectionWithTitle:OR6L(@"Services") rows:rows];
    NSString *readOnly = OR6L(@"Connected sources are read-only here: files are not downloaded, copied or attached.");
    NSString *reconnect = unavailable ? OR6L(@"Services are connected and reconnected in the web version; ChatGPT X does not change connections.") : nil;
    BOOL roots = OR6Chat6On(_core, @"library.mounted.roots");
    s.footer = roots ? reconnect : reconnect ? [NSString stringWithFormat:@"%@\n%@", reconnect, readOnly] : readOnly;
    [sections addObject:s];
    if (roots) {
        NSMutableArray *f = [NSMutableArray array];
        for (NSDictionary *n in Nodes(_roots.result[@"items"])) {
            NSString *provider = OR6Chat6LibraryProviderOfId(n[@"id"]);
            BOOL open = provider && [self available:provider] && OR6Chat6On(_core, @"library.mounted.browse");
            RCFormRow *r = NodeRow(n, @"chat.library6.sources.root", open); r.glyph = OR6Chat6LibraryIsFolder(n) ? @"folder" : @"file"; r.tile = RCTileTeal;
            r.subtitle = provider ? OR6Chat6LibraryProviderTitle(provider) : r.subtitle; r.userInfo = open ? @{@"provider": provider, @"node": n} : nil; [f addObject:r];
        }
        [self addStateOf:_roots to:f empty:OR6L(@"No folders from connected sources.") hasItems:f.count > 0 identifier:@"chat.library6.sources.roots"];
        RCFormSection *x = [RCFormSection sectionWithTitle:OR6L(@"Folders") rows:f];
        x.footer = readOnly; [sections addObject:x];
    }
    self.sections = sections;
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    id i = row.userInfo;
    if ([i isKindOfClass:NSDictionary.class] && i[@"provider"] && !i[@"pager"]) {
        NSDictionary *n = i[@"node"]; NSString *provider = i[@"provider"];
        UIViewController *c = [[[OR6Chat6LibraryMounted alloc] initWithCore:_core provider:provider directory:(n ? n[@"id"] : nil) title:(n ? OR6Chat6Text(n[@"name"], OR6Chat6LibraryProviderTitle(provider)) : OR6Chat6LibraryProviderTitle(provider))] autorelease];
        [self.navigationController pushViewController:c animated:YES]; return;
    }
    [super form:f didSelectRow:row];
}
@end

#pragma mark - Use in answers (library.autoContext)

// The host prepares the trusted eligibility policy right before the write (OR6Chat6Prepare); only a
// nil error lets the write run, otherwise the switch goes back to the last read value.
@interface OR6Chat6LibrarySettings : OR6Chat6Form { id<OR6APITask> _prepare; BOOL _preparing; }
@end
@implementation OR6Chat6LibrarySettings
- (void)load { [_read perform:@"library.autoContext.get" parameters:@{}]; [self render]; }
- (BOOL)writable { return OR6Chat6On(_core, @"library.autoContext.update") && OR6Chat6PolicyWritable(@"library.autoContext.update", @"autoContext"); }
- (void)stopPreparing { _preparing = NO; [_prepare cancel]; [(id)_prepare release]; _prepare = nil; self.busy = NO; }
- (void)viewDidDisappear:(BOOL)a { [super viewDidDisappear:a]; if (self.isMovingFromParentViewController || self.isBeingDismissed) [self stopPreparing]; }
- (void)render {
    NSMutableArray *rows = [NSMutableArray array]; id enabled = _read.busy ? nil : _read.result[@"enabled"];
    RCFormSection *s = [RCFormSection sectionWithTitle:nil rows:rows];
    if ([enabled isKindOfClass:NSNumber.class]) {
        if ([self writable]) {
            RCFormRow *sw = [RCFormRow rowWithKind:RCFormRowSwitch title:OR6L(@"Use Library files in answers")]; sw.on = [enabled boolValue]; sw.glyph = @"library"; sw.tile = RCTilePurple; sw.identifier = @"chat.library6.autocontext"; [rows addObject:sw];
            s.footer = OR6L(@"ChatGPT can look at files in your Library when they help with an answer.");
        } else {
            RCFormRow *v = [self value:OR6L(@"Use Library files in answers") value:([enabled boolValue] ? OR6L(@"On") : OR6L(@"Off")) info:nil identifier:@"chat.library6.autocontext"]; v.glyph = @"library"; v.tile = RCTilePurple; [rows addObject:v];
            s.footer = OR6L(@"ChatGPT X cannot confirm that this setting may be changed for your account, so it is shown read-only. You can change it in the web version.");
        }
    }
    [self addStateOf:_read to:rows empty:nil hasItems:YES identifier:@"chat.library6.autocontext"];
    if (!rows.count) [rows addObject:[self note:OR6L(@"Loading…")]];
    s.rows = rows; self.sections = @[s];
}
- (void)form:(RCFormViewController *)f didToggleRow:(RCFormRow *)row {
    (void)f; BOOL on = row.on; [self render]; // the switch shows the read state until the write is confirmed
    if (_preparing || ![self writable] || ![_read.result[@"enabled"] isKindOfClass:NSNumber.class]) return;
    _preparing = YES; self.busy = YES;
    id<OR6APITask> t = OR6Chat6Prepare(@"library.autoContext.update", @"autoContext", ^(NSError *e) { [self prepared:e on:on]; });
    if (_preparing) { [(id)_prepare release]; _prepare = [(id)t retain]; } // still pending (an asynchronous host)
}
- (void)prepared:(NSError *)e on:(BOOL)on {
    _preparing = NO; [(id)_prepare release]; _prepare = nil; self.busy = NO;
    if (e) { [self render]; OR6Chat6Say(Host(self), OR6Chat7ErrorText(e)); return; } // nothing was written
    OR6Chat7RunWrite(Host(self), _core, @"library.autoContext.update", @{@"enabled": @(on)}, Intent(@"library.autoContext.update", @"account"), @"catalog.reconcile",
                     (on ? OR6L(@"Library files will be used in answers.") : OR6L(@"Library files will not be used in answers.")), ^(NSDictionary *r) { (void)r; [self load]; });
}
- (void)dealloc { [_prepare cancel]; [(id)_prepare release]; [super dealloc]; }
@end

#pragma mark - Entry points

NSArray *OR6Chat6LibraryEntries(OR6APICore *core) {
    NSMutableArray *e = [NSMutableArray array];
    if (OR6Chat6On(core, @"library.browse")) [e addObject:@{@"key": @"files", @"title": OR6L(@"Files and folders"), @"subtitle": OR6L(@"Folders, filters and search"), @"glyph": @"folder", @"tile": @(RCTileBlue), @"identifier": @"chat.library6.files"}];
    if (OR6Chat6On(core, @"library.favorites.list")) [e addObject:@{@"key": @"favorites", @"title": OR6L(@"Favorites"), @"glyph": @"star", @"tile": @(RCTileYellow), @"identifier": @"chat.library6.favorites"}];
    if (OR6Chat6On(core, @"library.mounted.capabilities")) [e addObject:@{@"key": @"sources", @"title": OR6L(@"Connected sources"), @"subtitle": OR6L(@"Read only"), @"glyph": @"cloud", @"tile": @(RCTileTeal), @"identifier": @"chat.library6.sources"}];
    if (OR6Chat6On(core, @"library.autoContext.get")) [e addObject:@{@"key": @"settings", @"title": OR6L(@"Use in answers"), @"glyph": @"library", @"tile": @(RCTilePurple), @"identifier": @"chat.library6.settings"}];
    if (OR6Chat6On(core, @"library.trash.list")) [e addObject:@{@"key": @"trash", @"title": OR6L(@"Trash"), @"glyph": @"trash", @"tile": @(RCTileGray), @"identifier": @"chat.library6.trash"}];
    return e;
}
UIViewController *OR6Chat6CreateLibraryScreen(OR6APICore *core, NSString *key, id<OR6Chat7Navigator> nav) {
    if ([key isEqual:@"files"] && OR6Chat6On(core, @"library.browse")) return [[[OR6Chat6LibraryBrowser alloc] initWithCore:core navigator:nav directory:nil title:OR6L(@"Files and folders") changed:nil] autorelease];
    if ([key isEqual:@"favorites"] && OR6Chat6On(core, @"library.favorites.list")) return [[[OR6Chat6LibraryFavorites alloc] initWithCore:core navigator:nav title:OR6L(@"Favorites")] autorelease];
    if ([key isEqual:@"trash"] && OR6Chat6On(core, @"library.trash.list")) return [[[OR6Chat6LibraryTrash alloc] initWithCore:core navigator:nav title:OR6L(@"Trash")] autorelease];
    if ([key isEqual:@"sources"] && OR6Chat6On(core, @"library.mounted.capabilities")) return [[[OR6Chat6LibrarySourcesScreen alloc] initWithCore:core navigator:nav title:OR6L(@"Connected sources")] autorelease];
    if ([key isEqual:@"settings"] && OR6Chat6On(core, @"library.autoContext.get")) return [[[OR6Chat6LibrarySettings alloc] initWithCore:core navigator:nav title:OR6L(@"Use in answers")] autorelease];
    return nil;
}
UIViewController *OR6Chat6CreateLibraryItem(OR6APICore *core, NSString *libraryItemId, id<OR6Chat7Navigator> nav) {
    if (!NativeId(libraryItemId) || !OR6Chat6On(core, @"library.node.get")) return nil;
    return [[[OR6Chat6LibraryNodeScreen alloc] initWithCore:core navigator:nav node:nil identifier:libraryItemId kind:@"file" favorites:NO changed:nil] autorelease];
}
