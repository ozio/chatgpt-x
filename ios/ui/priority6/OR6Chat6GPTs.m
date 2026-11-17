// «GPT» (prototype s-tools.js gptsScreen, stage 6): search bar «Поиск GPT» (one query per keyboard
// «Найти»), «Мои GPT» (gpts.personal) and the discovery collections (gpts.explore); a collection
// continues with gpts.category; then a GPT card (gpts.get) with its external actions
// (gpts.actions.get, read only) and «Начать чат» (gpts.send through the conversation's GPT mode).
// Every list keeps the service's opaque nextPageToken (sent back unchanged) and its own error and
// «Прочитать снова»: a failed «Мои GPT» is shown even when discovery succeeded, and vice versa.
#import "OR6Chat6Base.h"
#import "RCGridViewController.h"
#import "RCGlyph.h"

@interface OR6Chat6GPTCard : OR6Chat6Form { NSDictionary *_gpt; OR6Chat7Call *_actions; }
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav gpt:(NSDictionary *)gpt;
@end

static RCGridItem *GPTItem(NSDictionary *g) {
    RCGridItem *i = [RCGridItem itemWithTitle:OR6Chat6Text(g[@"name"], OR6L(@"Untitled")) subtitle:OR6Chat6Text(g[@"description"], @"") glyph:@"gpt" tile:RCTilePurple];
    i.userInfo = g; i.showsDisclosure = YES; return i;
}
static RCGridItem *StateItem(NSString *title, NSString *glyph, id info) { RCGridItem *i = [RCGridItem itemWithTitle:title subtitle:nil glyph:glyph tile:RCTileGray]; i.userInfo = info; return i; }
// The state rows of one list inside its own section: error + «Read again», «Show more», «Loading…».
static void PagerItems(OR6Chat6Pager *p, NSMutableArray *items) {
    if (p.busy) { [items addObject:StateItem(OR6L(@"Loading…"), @"clock", nil)]; return; }
    if (p.error) { RCGridItem *e = StateItem(p.retryAvailable ? OR6L(@"Read again") : OR6Chat7ErrorText(p.error), @"regen", p.retryAvailable ? @{@"pager": p, @"action": @"retry"} : nil); e.subtitle = p.retryAvailable ? OR6Chat7ErrorText(p.error) : nil; [items addObject:e]; return; }
    if (p.hasMore) [items addObject:StateItem(OR6L(@"Show more"), @"down", @{@"pager": p, @"action": @"more"})];
}

#pragma mark - One collection (gpts.category)

@interface OR6Chat6GPTCategory : RCGridViewController <RCGridViewControllerDelegate, OR6Chat8ModelDelegate> { OR6APICore *_core; id<OR6Chat7Navigator> _nav; OR6Chat6Pager *_list; NSArray *_first; BOOL _loaded; }
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav category:(NSDictionary *)category;
@end
@implementation OR6Chat6GPTCategory
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav category:(NSDictionary *)c {
    if ((self = [super initWithStyle:RCGridStyleGPT title:OR6Chat6Text(c[@"name"], OR6L(@"GPT"))])) {
        _core = [core retain]; _nav = nav; self.delegate = self; self.emptyGlyph = @"gpt"; _first = [c[@"gpts"] isKindOfClass:NSArray.class] ? [c[@"gpts"] copy] : [@[] retain];
        _list = [[OR6Chat6Pager alloc] initWithCore:core operation:@"gpts.category" parameters:@{@"categoryId": c[@"id"]} tokenKey:@"pageToken" nextKey:@"nextPageToken" idKey:@"id"]; _list.delegate = self;
    }
    return self;
}
- (void)viewDidLoad { [super viewDidLoad]; self.tableView.accessibilityIdentifier = @"chat.gpts.category"; }
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; if (!_loaded) { _loaded = YES; [_list reload]; } [self render]; }
- (void)chat8ModelChanged:(id)m { (void)m; [self render]; }
- (void)render {
    if (![self isViewLoaded]) return;
    NSMutableArray *items = [NSMutableArray array]; NSMutableSet *seen = [NSMutableSet set];
    for (NSDictionary *g in _list.loaded ? _list.items : _first) if ([g isKindOfClass:NSDictionary.class] && OR6Chat6Text(g[@"id"], nil) && ![seen containsObject:g[@"id"]]) { [seen addObject:g[@"id"]]; [items addObject:GPTItem(g)]; }
    PagerItems(_list, items);
    self.sections = items.count ? @[[RCGridSection sectionWithTitle:nil items:items]] : @[];
    self.emptyTitle = self.title; self.emptyText = _list.loaded && !_list.items.count ? OR6L(@"This collection is empty.") : nil;
    [self reloadData];
}
- (void)grid:(RCGridViewController *)g didSelectItem:(RCGridItem *)item {
    (void)g; id i = item.userInfo;
    if ([i isKindOfClass:NSDictionary.class] && [i[@"pager"] isKindOfClass:OR6Chat6Pager.class]) { if ([i[@"action"] isEqual:@"retry"]) [i[@"pager"] retry]; else [i[@"pager"] loadMore]; [self render]; return; }
    if ([i isKindOfClass:NSDictionary.class] && i[@"id"]) [self.navigationController pushViewController:[[[OR6Chat6GPTCard alloc] initWithCore:_core navigator:_nav gpt:i] autorelease] animated:YES];
}
- (void)dealloc { _list.delegate = nil; [_list cancel]; [_list release]; [_first release]; self.delegate = nil; [_core release]; [super dealloc]; }
@end

#pragma mark - GPT screen

@interface OR6Chat6GPTScreen : RCGridViewController <RCGridViewControllerDelegate, OR6Chat8ModelDelegate> {
    OR6APICore *_core; id<OR6Chat7Navigator> _nav;
    OR6Chat7Call *_explore; OR6Chat6Pager *_mine, *_search; NSString *_query; BOOL _loaded;
}
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav;
@end

@implementation OR6Chat6GPTScreen
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav {
    // The screen IS the grid (like the Library screen): one view, one view controller.
    if ((self = [super initWithStyle:RCGridStyleGPT title:OR6L(@"GPT")])) {
        _core = [core retain]; _nav = nav; self.delegate = self; self.emptyGlyph = @"gpt";
        if (OR6Chat6On(core, @"gpts.search")) self.searchPlaceholder = OR6L(@"Search GPTs");
        _explore = [[OR6Chat7Call alloc] initWithCore:core]; _explore.delegate = self;
        _mine = [[OR6Chat6Pager alloc] initWithCore:core operation:@"gpts.personal" parameters:@{} tokenKey:@"pageToken" nextKey:@"nextPageToken" idKey:@"id"]; _mine.delegate = self;
        _search = [[OR6Chat6Pager alloc] initWithCore:core operation:@"gpts.search" parameters:@{@"query": @""} tokenKey:@"pageToken" nextKey:@"nextPageToken" idKey:@"id"]; _search.delegate = self;
    }
    return self;
}
- (void)viewDidLoad { [super viewDidLoad]; self.tableView.accessibilityIdentifier = @"chat.gpts.table"; }
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; if (!_loaded) { _loaded = YES; [self load]; } [self render]; }
- (void)load {
    [_explore perform:@"gpts.explore" parameters:@{}];
    if (OR6Chat6On(_core, @"gpts.personal")) [_mine reload];
}
- (void)grid:(RCGridViewController *)g searchTextDidChange:(NSString *)text {
    (void)g; if ([[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] length]) return;
    [_query release]; _query = nil; [_search reset]; [self render]; // cleared: back to the collections, nothing sent
}
- (void)grid:(RCGridViewController *)g searchDidSubmit:(NSString *)text {
    (void)g; NSString *q = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!q.length || q.length > 240) return;
    [_query release]; _query = [q copy]; _search.parameters = @{@"query": q}; [_search reload]; [self render];
}
- (void)chat8ModelChanged:(id)m { (void)m; [self render]; }
- (void)render {
    if (![self isViewLoaded]) return;
    NSMutableArray *sections = [NSMutableArray array]; NSString *state = nil;
    if (_query) {
        NSMutableArray *items = [NSMutableArray array]; for (NSDictionary *g in _search.items) [items addObject:GPTItem(g)];
        if (items.count || _search.error || _search.hasMore) { PagerItems(_search, items); [sections addObject:[RCGridSection sectionWithTitle:OR6L(@"Results") items:items]]; }
        state = _search.busy ? OR6L(@"Searching…") : _search.loaded ? OR6L(@"Nothing found.") : nil;
        self.emptyTitle = OR6L(@"Search GPTs");
    } else {
        // «Мои GPT»: its own section with its own error/retry/continuation, independent of discovery.
        if (OR6Chat6On(_core, @"gpts.personal")) {
            NSMutableArray *items = [NSMutableArray array]; for (NSDictionary *g in _mine.items) [items addObject:GPTItem(g)];
            PagerItems(_mine, items);
            if (items.count) [sections addObject:[RCGridSection sectionWithTitle:OR6L(@"My GPTs") items:items]];
        }
        for (NSDictionary *c in [_explore.result[@"items"] isKindOfClass:NSArray.class] ? _explore.result[@"items"] : @[]) {
            if (![c isKindOfClass:NSDictionary.class]) continue;
            NSMutableArray *items = [NSMutableArray array]; for (NSDictionary *g in c[@"gpts"]) if ([g isKindOfClass:NSDictionary.class] && OR6Chat6Text(g[@"id"], nil)) [items addObject:GPTItem(g)];
            if (OR6Chat6Text(c[@"id"], nil) && OR6Chat6On(_core, @"gpts.category")) [items addObject:StateItem(OR6L(@"Show all"), @"down", @{@"category": c})];
            if (items.count) [sections addObject:[RCGridSection sectionWithTitle:OR6Chat6Text(c[@"name"], nil) items:items]];
        }
        if (_explore.error && OR6Chat7Retryable(_explore.error)) [sections addObject:[RCGridSection sectionWithTitle:nil items:@[StateItem(OR6L(@"Read again"), @"regen", @"explore-retry")]]];
        state = _explore.busy ? OR6L(@"Loading…") : _explore.error ? OR6Chat7ErrorText(_explore.error) : _explore.result ? OR6L(@"The service returned no GPTs.") : nil;
        if (_explore.error && sections.count) { RCGridSection *last = sections.lastObject; last.footer = OR6Chat7ErrorText(_explore.error); }
        self.emptyTitle = OR6L(@"GPT");
    }
    self.sections = sections; self.emptyText = sections.count ? nil : state; [self reloadData];
}
- (void)grid:(RCGridViewController *)g didSelectItem:(RCGridItem *)item {
    (void)g; id i = item.userInfo;
    if ([i isEqual:@"explore-retry"]) { if (OR6Chat7Retryable(_explore.error)) [_explore perform:@"gpts.explore" parameters:@{}]; [self render]; return; }
    if (![i isKindOfClass:NSDictionary.class]) return;
    if ([i[@"pager"] isKindOfClass:OR6Chat6Pager.class]) { if ([i[@"action"] isEqual:@"retry"]) [i[@"pager"] retry]; else [i[@"pager"] loadMore]; [self render]; return; }
    if (i[@"category"]) { [self.navigationController pushViewController:[[[OR6Chat6GPTCategory alloc] initWithCore:_core navigator:_nav category:i[@"category"]] autorelease] animated:YES]; return; }
    [self.navigationController pushViewController:[[[OR6Chat6GPTCard alloc] initWithCore:_core navigator:_nav gpt:i] autorelease] animated:YES];
}
- (void)dealloc {
    _explore.delegate = nil; _mine.delegate = nil; _search.delegate = nil; [_explore cancel]; [_mine cancel]; [_search cancel];
    [_explore release]; [_mine release]; [_search release]; self.delegate = nil; [_core release]; [_query release]; [super dealloc];
}
@end

#pragma mark - GPT card

@implementation OR6Chat6GPTCard
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav gpt:(NSDictionary *)gpt {
    if ((self = [super initWithCore:core navigator:nav title:OR6Chat6Text(gpt[@"name"], OR6L(@"GPT"))])) {
        _gpt = [gpt retain]; _actions = [[OR6Chat7Call alloc] initWithCore:core]; _actions.delegate = self;
        self.tableView.accessibilityIdentifier = @"chat.gpt.card";
    }
    return self;
}
- (void)load {
    if (!OR6Chat6Text(_gpt[@"id"], nil)) return;
    if (OR6Chat6On(_core, @"gpts.get")) [_read perform:@"gpts.get" parameters:@{@"gptId": _gpt[@"id"]}];
    if (OR6Chat6On(_core, @"gpts.actions.get")) [_actions perform:@"gpts.actions.get" parameters:@{@"gptId": _gpt[@"id"]}];
    [self render];
}
- (NSDictionary *)fresh { return [_read.result[@"id"] isEqual:_gpt[@"id"]] ? _read.result : nil; }
- (BOOL)chatAvailable { NSDictionary *g = [self fresh]; return g && [g[@"canChat"] isEqual:@YES] && OR6Chat6On(_core, @"gpts.send") && [(id)_nav respondsToSelector:@selector(chat6NewChatWithGPT:)]; }
- (void)render {
    NSDictionary *g = [self fresh] ?: _gpt; NSMutableArray *sections = [NSMutableArray array];
    RCFormRow *head = [RCFormRow rowWithKind:RCFormRowValue title:OR6Chat6Text(g[@"name"], OR6L(@"GPT"))];
    head.subtitle = OR6Chat6Text(g[@"description"], nil); head.glyph = @"gpt"; head.tile = RCTilePurple; head.enabled = NO; head.identifier = @"chat.gpt.name";
    NSMutableArray *rows = [NSMutableArray arrayWithObject:head];
    [self addStateOf:_read to:rows empty:nil hasItems:YES identifier:@"chat.gpt"];
    RCFormSection *top = [RCFormSection sectionWithTitle:nil rows:rows];
    if ([self chatAvailable]) [rows addObject:[self button:OR6L(@"Start a chat") info:@"chat" identifier:@"chat.gpt.start"]];
    else if ([self fresh]) top.footer = [[self fresh][@"canChat"] isEqual:@NO] ? OR6L(@"This GPT is not available for chats on this account.") : OR6L(@"ChatGPT X cannot start a chat with a GPT.");
    top.rows = rows; [sections addObject:top];
    NSMutableArray *starters = [NSMutableArray array]; BOOL tap = [self chatAvailable];
    for (id s in [g[@"starters"] isKindOfClass:NSArray.class] ? g[@"starters"] : @[]) if ([s isKindOfClass:NSString.class] && [s length]) {
        RCFormRow *r = tap ? [RCFormRow rowWithKind:RCFormRowValue title:s] : [RCFormRow rowWithKind:RCFormRowNote title:s];
        if (tap) { r.userInfo = @{@"starter": s}; r.disclosure = YES; } r.identifier = @"chat.gpt.starter"; [starters addObject:r];
    }
    if (starters.count) { RCFormSection *s = [RCFormSection sectionWithTitle:OR6L(@"Examples") rows:starters]; if (tap) s.footer = OR6L(@"Tap an example to put it into a new chat with this GPT. It is sent only when you tap Send."); [sections addObject:s]; }
    NSMutableArray *acts = [NSMutableArray array];
    for (NSDictionary *a in [_actions.result[@"items"] isKindOfClass:NSArray.class] ? _actions.result[@"items"] : @[]) if ([a isKindOfClass:NSDictionary.class] && OR6Chat6Text(a[@"domain"], nil)) { RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:a[@"domain"]]; r.glyph = @"globe"; r.tile = RCTileBlue; r.enabled = NO; [acts addObject:r]; }
    // Action permissions themselves change only on the first-party GPT page (gpts.actions.get says settingsOpened:false).
    if (acts.count && OR6Chat6GPTPageURL(_gpt[@"id"])) [acts addObject:[self button:OR6L(@"Action permissions on the website…") info:@"web" identifier:@"chat.gpt.actions.web"]];
    if (acts.count) { RCFormSection *s = [RCFormSection sectionWithTitle:OR6L(@"Actions") rows:acts]; s.footer = OR6L(@"This GPT can contact these external services. Allowing or blocking them happens on the ChatGPT website; ChatGPT X changes nothing here."); [sections addObject:s]; }
    else if (_actions.error) { NSMutableArray *er = [NSMutableArray arrayWithObject:[self note:OR6Chat7ErrorText(_actions.error)]]; if (OR6Chat7Retryable(_actions.error)) [er addObject:[self button:OR6L(@"Read again") info:@"actions" identifier:@"chat.gpt.actions.retry"]]; [sections addObject:[RCFormSection sectionWithTitle:OR6L(@"Actions") rows:er]]; }
    self.sections = sections;
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    id i = row.userInfo;
    if ([i isEqual:@"web"]) {
        NSURL *u = OR6Chat6GPTPageURL(_gpt[@"id"]); if (!u) return;
        OR6Chat6Confirm(self.view.window ?: self.view, OR6L(@"Open this GPT on the ChatGPT website to manage its action permissions? Nothing changes in ChatGPT X."), OR6L(@"Open in Safari"), NO, ^{
            if ([UIApplication.sharedApplication openURL:u]) OR6Chat6Say(self.view.window, OR6L(@"Continue in Safari."));
        });
        return;
    }
    if ([i isEqual:@"actions"]) { [_actions perform:@"gpts.actions.get" parameters:@{@"gptId": _gpt[@"id"]}]; [self render]; return; }
    if (([i isEqual:@"chat"] || ([i isKindOfClass:NSDictionary.class] && i[@"starter"])) && [self chatAvailable]) {
        NSMutableDictionary *g = [[[self fresh] mutableCopy] autorelease]; if ([i isKindOfClass:NSDictionary.class]) g[@"starter"] = i[@"starter"];
        [(id)_nav chat6NewChatWithGPT:g]; return;
    }
    [super form:f didSelectRow:row];
}
- (void)dealloc { _actions.delegate = nil; [_actions cancel]; [_actions release]; [_gpt release]; [super dealloc]; }
@end

UIViewController *OR6Chat6CreateGPTs(OR6APICore *core, id<OR6Chat7Navigator> nav) { return [[[OR6Chat6GPTScreen alloc] initWithCore:core navigator:nav] autorelease]; }
