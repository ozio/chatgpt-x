// Stage-6 account screens (prototype s-account.js): «Devices and sessions» (account.sessions.*),
// «Answers» (preferences.advanced.get / set…), «Saved memories» from the Memory screen
// (memories.*), and from Privacy «Apps with access» (API6B), «Precise location», «Export data» and
// «Delete account» (API6D). Values are what the service reports. A switch exists only when its write
// is callable AND the trusted host bound the eligibility policy for the current account; otherwise the
// state is read-only with an honest note. Every write is an explicit tap (destructive ones confirmed
// with purpose-specific wording), one operation ID, the contract's reconcile, never an automatic resend.
// Export and deletion additionally need the host's one-use account authorization; without it the
// screen says so and offers the first-party page — nothing is ever claimed as done.
#import "OR6Chat6Base.h"
#import "OR6Chat6AccountLogic.h"
#import "RCHUD.h"

static NSString *OnOffUnknown(id v) { return [v isEqual:@YES] ? OR6L(@"On") : [v isEqual:@NO] ? OR6L(@"Off") : OR6L(@"Unknown"); }
static NSString *PolicyNote(void) { return OR6L(@"Shown for reference. You can change this in the web version."); }
static NSDictionary *Dict(id v) { return [v isKindOfClass:NSDictionary.class] ? v : nil; }
static NSArray *Items(NSDictionary *d) { return [d[@"items"] isKindOfClass:NSArray.class] ? d[@"items"] : @[]; }
static UIView *HUDView(UIViewController *c) { return c.view.window ?: c.view; }

// Loading / error (+ its own «Read again») of one secondary read; YES when a state row was added.
static BOOL State(OR6Chat6Form *f, OR6Chat7Call *c, NSMutableArray *rows, NSString *info, NSString *ident) {
    if (c.busy) { [rows addObject:[f note:OR6L(@"Loading…")]]; return YES; }
    if (!c.error) return NO;
    [rows addObject:[f note:OR6Chat7ErrorText(c.error)]];
    if (OR6Chat7Retryable(c.error)) [rows addObject:[f button:OR6L(@"Read again") info:info identifier:[ident stringByAppendingString:@".retry"]]];
    return YES;
}

#pragma mark - Devices and sessions

@interface OR6Chat6DevicesScreen : OR6Chat6Form { NSDate *_readAt; }
@end
@implementation OR6Chat6DevicesScreen
- (void)load { [_readAt release]; _readAt = nil; [_read perform:@"account.sessions.list" parameters:@{@"includeTrustedDevices": @YES}]; [self render]; }
- (void)chat8ModelChanged:(id)m {
    if (m == _read && !_read.busy && !_read.error && _read.result && !_readAt) _readAt = [NSDate new]; // the catalogue IDs expire 5 min after this read
    [super chat8ModelChanged:m];
}
- (NSArray *)devices { NSMutableArray *a = [NSMutableArray array]; for (NSDictionary *d in Items(Dict(_read.result))) if ([d isKindOfClass:NSDictionary.class] && OR6Chat6Text(d[@"targetId"], nil)) [a addObject:d]; return a; }
- (BOOL)canRevoke:(NSDictionary *)d { return OR6Chat6On(_core, @"account.sessions.revoke") && !OR6Chat6SessionRefusal(d) && OR6Chat6Text(_read.result[@"catalogId"], nil); }
- (RCFormRow *)rowFor:(NSDictionary *)d {
    NSString *name = OR6Chat6Text(d[@"displayName"], OR6Chat6Text(d[@"deviceModel"], OR6Chat6Text(d[@"platform"], OR6L(@"Unknown device"))));
    RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:name]; NSMutableArray *sub = [NSMutableArray array];
    NSString *kind = OR6Chat6SessionKindText(d); if (kind) [sub addObject:kind];
    NSString *place = OR6Chat6Text(d[@"location"], nil) ?: [[[NSArray arrayWithObjects:OR6Chat6Text(d[@"city"], @""), OR6Chat6Text(d[@"country"], @""), nil] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]] componentsJoinedByString:@", "];
    if (place.length) [sub addObject:place];
    NSString *when = OR6Chat6RelativeDate(d[@"lastSignedInAtSeconds"]); if (when) [sub addObject:when];
    r.subtitle = sub.count ? [sub componentsJoinedByString:@" · "] : nil;
    r.glyph = @"devices"; r.tile = RCTileGray; r.identifier = @"chat.devices.row";
    if ([d[@"isTrusted"] isEqual:@YES]) r.value = OR6L(@"Trusted");
    BOOL revoke = [self canRevoke:d]; r.enabled = revoke; r.disclosure = revoke; r.userInfo = revoke ? d : nil;
    return r;
}
- (void)render {
    NSArray *devices = [self devices]; NSMutableArray *current = [NSMutableArray array], *others = [NSMutableArray array], *sections = [NSMutableArray array];
    for (NSDictionary *d in devices) [([d[@"isCurrent"] isEqual:@YES] ? current : others) addObject:[self rowFor:d]];
    if (current.count) [sections addObject:[RCFormSection sectionWithTitle:OR6L(@"This iPhone") rows:current]];
    NSMutableArray *rest = [NSMutableArray arrayWithArray:others];
    [self addStateOf:_read to:rest empty:OR6L(@"No other devices.") hasItems:others.count > 0 identifier:@"chat.devices"];
    RCFormSection *o = [RCFormSection sectionWithTitle:(others.count ? OR6L(@"Other devices") : nil) rows:rest]; [sections addObject:o];
    if (others.count) o.footer = OR6Chat6On(_core, @"account.sessions.revoke") ? OR6L(@"Tap a device to sign it out. Signing out ends its session there.") : OR6Chat7WriteClosedNote();
    if (devices.count && OR6Chat6On(_core, @"account.sessions.revokeAll")) {
        RCFormRow *all = [self button:OR6L(@"Sign out everywhere") info:@"all" identifier:@"chat.devices.all"]; all.destructive = YES;
        RCFormSection *s = [RCFormSection sectionWithTitle:nil rows:@[all]]; s.footer = OR6L(@"Signs out on every device, this iPhone included. You will need to sign in again."); [sections addObject:s];
    }
    self.sections = sections;
}
- (BOOL)refreshIfStale {
    if (OR6Chat6SessionCatalogFresh(_readAt, [NSDate date])) return NO;
    [self load]; OR6Chat6Say(HUDView(self), OR6L(@"The device list was out of date and has been read again. Choose the device again."));
    return YES;
}
- (void)revoke:(NSDictionary *)d {
    NSDictionary *p = OR6Chat6SessionRevokeRequest(Dict(_read.result), d, _readAt, [NSDate date]);
    if (!p) { [self refreshIfStale]; return; }
    BOOL trust = [d[@"kind"] isEqual:@"signed_out_trusted"];
    OR6Chat7RunWrite(HUDView(self), _core, @"account.sessions.revoke", p, [@"account.sessions.revoke:" stringByAppendingString:d[@"targetId"]], @"account.sessions.reconcile",
                     trust ? OR6L(@"The device is no longer trusted.") : OR6L(@"Signed out on that device."), ^(NSDictionary *r) { (void)r; [self load]; });
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    if ([row.userInfo isEqual:@"all"]) {
        OR6Chat6Confirm(HUDView(self), OR6L(@"Sign out everywhere, including this iPhone? Every session ends and you will need to sign in again here too."), OR6L(@"Sign out everywhere"), YES, ^{
            OR6Chat7RunWrite(HUDView(self), _core, @"account.sessions.revokeAll", OR6Chat6SessionRevokeAllRequest(), @"account.sessions.revokeAll:all", @"account.sessions.reconcile", OR6L(@"Signed out everywhere."), ^(NSDictionary *r) {
                if ([r[@"affectsCurrentSession"] isEqual:@YES]) OR6Chat6Say(HUDView(self), OR6L(@"This iPhone is signed out too. Sign in again to keep using ChatGPT."));
                else [self load];
            });
        });
        return;
    }
    if ([row.userInfo isKindOfClass:NSDictionary.class]) {
        if ([self refreshIfStale]) return;
        NSDictionary *d = row.userInfo; NSString *name = row.title; BOOL trust = [d[@"kind"] isEqual:@"signed_out_trusted"];
        NSString *title = trust ? [NSString stringWithFormat:OR6L(@"Stop trusting «%@»? It will need full verification at its next sign-in."), name]
                                : [NSString stringWithFormat:OR6L(@"Sign out on «%@»? That device will need to sign in again."), name];
        OR6Chat6Confirm(HUDView(self), title, trust ? OR6L(@"Stop trusting") : OR6L(@"Sign out on this device"), YES, ^{ [self revoke:d]; });
        return;
    }
    [super form:f didSelectRow:row];
}
- (void)dealloc { [_readAt release]; [super dealloc]; }
@end

#pragma mark - Answers (automatic web search, image creation)

@interface OR6Chat6AnswersScreen : OR6Chat6Form
@end
@implementation OR6Chat6AnswersScreen
- (void)load { [_read perform:@"preferences.advanced.get" parameters:@{}]; [self render]; }
- (BOOL)writable:(NSString *)key op:(NSString *)op policy:(NSString *)policy locked:(BOOL)locked state:(NSDictionary *)s {
    return OR6Chat6On(_core, op) && OR6Chat6PolicyWritable(op, policy) && !locked && [s[key] isKindOfClass:NSNumber.class] && OR6Chat6SettingRequest(s, YES);
}
- (RCFormRow *)row:(NSString *)title subtitle:(NSString *)sub key:(NSString *)key op:(NSString *)op policy:(NSString *)policy locked:(BOOL)locked state:(NSDictionary *)s {
    NSString *ident = [@"chat.answers." stringByAppendingString:key]; RCFormRow *r;
    if ([self writable:key op:op policy:policy locked:locked state:s]) { r = [RCFormRow rowWithKind:RCFormRowSwitch title:title]; r.on = [s[key] boolValue]; r.userInfo = op; r.identifier = ident; }
    else r = [self value:title value:(locked ? [NSString stringWithFormat:OR6L(@"%@ · locked"), OnOffUnknown(s[key])] : OnOffUnknown(s[key])) info:nil identifier:ident];
    r.subtitle = sub; return r;
}
- (void)render {
    NSDictionary *s = Dict(_read.result); NSMutableArray *rows = [NSMutableArray array]; RCFormSection *sec;
    if (s) {
        BOOL imageLocked = [s[@"imageCreationLocked"] isEqual:@YES];
        [rows addObject:[self row:OR6L(@"Search the web automatically") subtitle:OR6L(@"ChatGPT decides when an answer needs a fresh search.") key:@"autoWebSearch" op:@"preferences.setAutoWebSearch" policy:@"webSearch" locked:NO state:s]];
        [rows addObject:[self row:OR6L(@"Create images") subtitle:nil key:@"imageCreation" op:@"preferences.setImageCreation" policy:@"imageCreation" locked:imageLocked state:s]];
        sec = [RCFormSection sectionWithTitle:nil rows:rows];
        BOOL web = [self writable:@"autoWebSearch" op:@"preferences.setAutoWebSearch" policy:@"webSearch" locked:NO state:s];
        BOOL image = [self writable:@"imageCreation" op:@"preferences.setImageCreation" policy:@"imageCreation" locked:imageLocked state:s];
        BOOL callable = OR6Chat6On(_core, @"preferences.setAutoWebSearch") || OR6Chat6On(_core, @"preferences.setImageCreation");
        NSMutableArray *foot = [NSMutableArray arrayWithObject:OR6L(@"ChatGPT uses these tools when an answer needs them.")];
        if (imageLocked) [foot addObject:OR6L(@"Image creation is locked for this account.")];
        if (!web || (!image && !imageLocked)) [foot addObject:(callable ? PolicyNote() : OR6Chat7WriteClosedNote())];
        sec.footer = [foot componentsJoinedByString:@" "];
    } else { [self addStateOf:_read to:rows empty:nil hasItems:NO identifier:@"chat.answers"]; sec = [RCFormSection sectionWithTitle:nil rows:rows]; }
    self.sections = @[sec];
}
- (void)form:(RCFormViewController *)f didToggleRow:(RCFormRow *)row {
    (void)f; NSString *op = row.userInfo; NSDictionary *p = OR6Chat6SettingRequest(Dict(_read.result), row.on); [self render]; // the switch shows the service value until the write is read back
    if (![op isKindOfClass:NSString.class] || !p) return;
    // The host binds the observed source policy right before the write (root HOST-CONTRACT); a refusal sends nothing.
    OR6Chat6Prepare(op, [op isEqual:@"preferences.setImageCreation"] ? @"imageCreation" : @"webSearch", ^(NSError *e) {
        if (e) { OR6Chat6Say(HUDView(self), OR6Chat7ErrorText(e)); [self render]; return; }
        OR6Chat7RunWrite(HUDView(self), _core, op, p, [op stringByAppendingString:@":account"], @"preferences.reconcile", OR6L(@"Saved."), ^(NSDictionary *r) { (void)r; [self load]; });
    });
}
@end

#pragma mark - Saved memories (server search, delete, priority, capacity, automatic management)

@interface OR6Chat6MemoriesScreen : OR6Chat6Form { OR6Chat7Call *_capacity, *_management, *_search; NSString *_query, *_searched; }
@end
@implementation OR6Chat6MemoriesScreen
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav title:(NSString *)title {
    if ((self = [super initWithCore:core navigator:nav title:title])) { _capacity = [self call]; _management = [self call]; _search = [self call]; } // owned by the form
    return self;
}
- (BOOL)serverSearch { return OR6Chat6On(_core, @"memories.search"); }
- (NSString *)currentQuery { return OR6Chat6MemorySearchQuery(_query); }
- (void)readList { [_read perform:@"memories.list" parameters:@{}]; }
- (void)readCapacity { if (OR6Chat6On(_core, @"memories.capacity")) [_capacity perform:@"memories.capacity" parameters:@{}]; }
- (void)readManagement { if (OR6Chat6On(_core, @"memories.management.get")) [_management perform:@"memories.management.get" parameters:@{}]; }
- (void)runSearch {
    NSString *q = [self currentQuery]; if (!q || ![self serverSearch]) return;
    [_searched release]; _searched = [q copy];
    [_search perform:@"memories.search" parameters:@{@"query": q}]; [self render];
}
- (void)scheduleSearch {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(runSearch) object:nil];
    NSString *q = [self currentQuery];
    if (q && [self serverSearch] && !([q isEqual:_searched] && (_search.busy || _search.result))) [self performSelector:@selector(runSearch) withObject:nil afterDelay:0.6]; // one read after typing pauses
}
- (void)load { [self readList]; [self readCapacity]; [self readManagement]; if ([self currentQuery]) [self runSearch]; [self render]; }
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; [self scheduleSearch]; }
- (void)viewWillDisappear:(BOOL)a { [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(runSearch) object:nil]; [super viewWillDisappear:a]; }

- (RCFormRow *)rowFor:(NSDictionary *)m {
    NSString *text = OR6Chat6Text(m[@"content"], nil); if (!text) return nil;
    BOOL del = OR6Chat6On(_core, @"memories.delete") && OR6Chat6MemoryDeleteRequest(m), prio = OR6Chat6On(_core, @"memories.prioritize") && OR6Chat6MemoryPrioritizeRequest(m);
    RCFormRow *r;
    if (del || prio) {
        r = [RCFormRow rowWithKind:RCFormRowValue title:text]; r.disclosure = YES; r.userInfo = m;
        NSMutableArray *sub = [NSMutableArray array];
        if (OR6Chat6MemoryIsPriority(m)) [sub addObject:OR6L(@"Priority")];
        NSString *when = OR6Chat6RelativeDate(m[@"updatedAt"]) ?: OR6Chat6RelativeDate(m[@"createdAt"]); if (when) [sub addObject:when];
        r.subtitle = sub.count ? [sub componentsJoinedByString:@" · "] : nil;
    } else r = [self note:(OR6Chat6MemoryIsPriority(m) ? [NSString stringWithFormat:OR6L(@"%@ · priority"), text] : text)]; // read-only: the whole text
    r.identifier = @"chat.memories.row"; return r;
}
- (RCFormSection *)capacitySection {
    if (!OR6Chat6On(_core, @"memories.capacity")) return nil;
    NSMutableArray *rows = [NSMutableArray array];
    if (!State(self, _capacity, rows, @"capacity.retry", @"chat.memories.capacity") && _capacity.result) {
        NSDictionary *c = Dict(_capacity.result); RCFormRow *r = [self value:(OR6Chat6MemoryCapacityText(c) ?: OR6L(@"The service does not report how full memory is.")) value:nil info:nil identifier:@"chat.memories.capacity"];
        if (OR6Chat6MemoryAlmostFull(c)) r.subtitle = OR6L(@"Memory is almost full. Delete what ChatGPT no longer needs to remember.");
        [rows addObject:r];
    }
    return rows.count ? [RCFormSection sectionWithTitle:nil rows:rows] : nil;
}
- (RCFormSection *)listSection {
    NSDictionary *list = Dict(_read.result); NSArray *all = Items(list); NSString *q = [self currentQuery];
    NSArray *shown = all; BOOL server = q && [self serverSearch], authoritative = NO;
    if (server && [_searched isEqual:q] && !_search.busy && !_search.error && Dict(_search.result)) { shown = Items(Dict(_search.result)); authoritative = YES; }
    else if (q) shown = OR6Chat6MemoryFilter(all, q); // instant feedback over the list already read
    NSMutableArray *rows = [NSMutableArray array]; BOOL actions = NO;
    for (NSDictionary *m in shown) { RCFormRow *r = [m isKindOfClass:NSDictionary.class] ? [self rowFor:m] : nil; if (r) { [rows addObject:r]; actions |= r.userInfo != nil; } }
    BOOL has = rows.count > 0;
    if (server && !authoritative) {
        if (_search.error && [_searched isEqual:q]) {
            [rows addObject:[self note:OR6Chat7ErrorText(_search.error)]];
            if (OR6Chat7Retryable(_search.error)) [rows addObject:[self button:OR6L(@"Search again") info:@"search.retry" identifier:@"chat.memories.search.retry"]];
        } else [rows addObject:[self note:OR6L(@"Searching…")]];
    } else if (authoritative) { if (!has) [rows addObject:[self note:OR6L(@"Nothing found.")]]; }
    else [self addStateOf:_read to:rows empty:(q ? OR6L(@"Nothing found.") : OR6L(@"ChatGPT has not saved any memories yet.")) hasItems:has identifier:@"chat.memories"];
    RCFormSection *s = [RCFormSection sectionWithTitle:(q ? OR6L(@"Search results") : nil) rows:rows];
    if (has) {
        BOOL del = OR6Chat6On(_core, @"memories.delete"), prio = OR6Chat6On(_core, @"memories.prioritize");
        s.footer = !actions ? OR6Chat7WriteClosedNote() : (del && prio) ? OR6L(@"Tap a memory to delete it or keep it a priority.") : del ? OR6L(@"Tap a memory to delete it.") : OR6L(@"Tap a memory to keep it a priority.");
    }
    return s;
}
- (RCFormSection *)managementSection {
    if (!OR6Chat6On(_core, @"memories.management.get")) return nil;
    NSMutableArray *rows = [NSMutableArray array]; NSDictionary *m = Dict(_management.result); RCFormSection *s;
    if (State(self, _management, rows, @"management.retry", @"chat.memories.auto") || !m) return rows.count ? [RCFormSection sectionWithTitle:nil rows:rows] : nil;
    BOOL callable = OR6Chat6On(_core, @"memories.management.update"), write = callable && OR6Chat6PolicyWritable(@"memories.management.update", @"automaticMemoryManagement") && [m[@"automaticallyManaged"] isKindOfClass:NSNumber.class] && OR6Chat6SettingRequest(m, YES);
    RCFormRow *r;
    if (write) { r = [RCFormRow rowWithKind:RCFormRowSwitch title:OR6L(@"Manage memories automatically")]; r.on = [m[@"automaticallyManaged"] boolValue]; r.userInfo = @"management"; }
    else r = [self value:OR6L(@"Manage memories automatically") value:OnOffUnknown(m[@"automaticallyManaged"]) info:nil identifier:nil];
    r.identifier = @"chat.memories.auto"; [rows addObject:r];
    s = [RCFormSection sectionWithTitle:nil rows:rows];
    s.footer = write ? OR6L(@"When memory is full, ChatGPT keeps the most relevant memories in use. Priority memories stay in use.") : callable ? PolicyNote() : OR6Chat7WriteClosedNote();
    return s;
}
- (void)render {
    NSMutableArray *sections = [NSMutableArray array]; NSDictionary *list = Dict(_read.result); NSString *q = [self currentQuery];
    RCFormSection *c = [self capacitySection]; if (c) [sections addObject:c];
    if ([self serverSearch] || Items(list).count > 8 || _query.length) {
        RCFormRow *f = [RCFormRow rowWithKind:RCFormRowText title:OR6L(@"Search")]; f.text = _query; f.placeholder = OR6L(@"Search memories"); f.maxLength = 1000; f.identifier = @"chat.memories.search";
        if (Items(list).count || _query.length) [sections addObject:[RCFormSection sectionWithTitle:nil rows:@[f]]];
    }
    [sections addObject:[self listSection]];
    RCFormSection *m = [self managementSection]; if (m) [sections addObject:m];
    if (!q && OR6Chat6On(_core, @"memories.deleteAll") && OR6Chat6MemoryDeleteAllRequest(list)) {
        RCFormRow *all = [self button:OR6L(@"Delete all memories") info:@"deleteAll" identifier:@"chat.memories.delete_all"]; all.destructive = YES;
        [sections addObject:[RCFormSection sectionWithTitle:nil rows:@[all]]];
    }
    self.sections = sections;
}
- (void)written:(NSDictionary *)r { (void)r; [self readList]; [self readCapacity]; if ([self currentQuery]) [self runSearch]; [self render]; } // read back after a confirmed write
- (void)deleteMemory:(NSDictionary *)m {
    NSDictionary *p = OR6Chat6MemoryDeleteRequest(m); if (!p) return;
    OR6Chat6Confirm(HUDView(self), OR6L(@"Delete this memory? ChatGPT will no longer use it. This cannot be undone."), OR6L(@"Delete memory"), YES, ^{
        OR6Chat7RunWrite(HUDView(self), _core, @"memories.delete", p, [@"memories.delete:" stringByAppendingString:p[@"memoryId"]], @"memories.reconcile", OR6L(@"Memory deleted."), ^(NSDictionary *r) { [self written:r]; });
    });
}
- (void)prioritize:(NSDictionary *)m {
    NSDictionary *p = OR6Chat6MemoryPrioritizeRequest(m); if (!p) return;
    OR6Chat7RunWrite(HUDView(self), _core, @"memories.prioritize", p, [@"memories.prioritize:" stringByAppendingString:p[@"memoryId"]], @"memories.reconcile", OR6L(@"This memory is now a priority."), ^(NSDictionary *r) { [self written:r]; });
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    id i = row.userInfo;
    if ([i isEqual:@"retry"]) { [self readList]; [self render]; return; }
    if ([i isEqual:@"capacity.retry"]) { [self readCapacity]; [self render]; return; }
    if ([i isEqual:@"management.retry"]) { [self readManagement]; [self render]; return; }
    if ([i isEqual:@"search.retry"]) { [self runSearch]; return; }
    if ([i isEqual:@"deleteAll"]) {
        NSDictionary *p = OR6Chat6MemoryDeleteAllRequest(Dict(_read.result)); if (!p) return;
        OR6Chat6Confirm(HUDView(self), OR6L(@"Delete all saved memories? ChatGPT will forget everything it has saved about you. This cannot be undone."), OR6L(@"Delete all memories"), YES, ^{
            OR6Chat7RunWrite(HUDView(self), _core, @"memories.deleteAll", p, @"memories.deleteAll:all", @"memories.reconcile", OR6L(@"All memories deleted."), ^(NSDictionary *r) { [self written:r]; });
        });
        return;
    }
    if (![i isKindOfClass:NSDictionary.class]) { [super form:f didSelectRow:row]; return; }
    NSDictionary *m = i; NSString *text = OR6Chat6Text(m[@"content"], @"");
    BOOL del = OR6Chat6On(_core, @"memories.delete") && OR6Chat6MemoryDeleteRequest(m), prio = OR6Chat6On(_core, @"memories.prioritize") && OR6Chat6MemoryPrioritizeRequest(m);
    if (text.length > 300) text = [[text substringToIndex:[text rangeOfComposedCharacterSequenceAtIndex:300].location] stringByAppendingString:@"…"];
    OR6Chat8ShowSheet(HUDView(self), text, prio ? @[OR6L(@"Keep this memory a priority")] : @[], del ? OR6L(@"Delete") : nil, ^(NSInteger index, NSString *t) {
        (void)t; if (index == -2) [self deleteMemory:m]; else if (index == 0) [self prioritize:m];
    });
}
- (void)form:(RCFormViewController *)f didToggleRow:(RCFormRow *)row {
    (void)f; NSDictionary *p = [row.userInfo isEqual:@"management"] ? OR6Chat6SettingRequest(Dict(_management.result), row.on) : nil; [self render];
    if (!p) return;
    OR6Chat6Prepare(@"memories.management.update", @"automaticMemoryManagement", ^(NSError *e) {
        if (e) { OR6Chat6Say(HUDView(self), OR6Chat7ErrorText(e)); [self render]; return; }
        OR6Chat7RunWrite(HUDView(self), _core, @"memories.management.update", p, @"memories.management.update:account", @"memories.reconcile", OR6L(@"Saved."), ^(NSDictionary *r) { (void)r; [self readManagement]; [self render]; });
    });
}
- (void)form:(RCFormViewController *)f didChangeTextOfRow:(RCFormRow *)row {
    (void)f; [_query release]; _query = [row.text copy];
    if (![self currentQuery]) { [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(runSearch) object:nil]; [_search cancel]; [_search reset]; [_searched release]; _searched = nil; }
    else [self scheduleSearch];
    [self render];
}
- (void)dealloc { [NSObject cancelPreviousPerformRequestsWithTarget:self]; [_query release]; [_searched release]; [super dealloc]; }
@end

#pragma mark - Apps with access to the account

@interface OR6Chat6AppsAccessScreen : OR6Chat6Form
@end
@implementation OR6Chat6AppsAccessScreen
- (void)load { [_read perform:@"privacy.appsAccess.list" parameters:@{}]; [self render]; }
- (void)render {
    BOOL revoke = OR6Chat6On(_core, @"privacy.appsAccess.revoke"); NSMutableArray *rows = [NSMutableArray array];
    for (NSDictionary *g in Items(Dict(_read.result))) {
        if (![g isKindOfClass:NSDictionary.class] || !OR6Chat6Text(g[@"id"], nil)) continue;
        RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:OR6Chat6Text(g[@"name"], OR6L(@"Untitled"))]; r.glyph = @"apps"; r.tile = RCTilePurple;
        r.enabled = revoke; r.disclosure = revoke; r.userInfo = revoke ? g : nil; r.identifier = @"chat.apps_access.row"; [rows addObject:r];
    }
    BOOL has = rows.count > 0;
    [self addStateOf:_read to:rows empty:OR6L(@"No apps have access to your account.") hasItems:has identifier:@"chat.apps_access"];
    RCFormSection *s = [RCFormSection sectionWithTitle:nil rows:rows];
    if (has) s.footer = revoke ? OR6L(@"Tap an app to remove its access.") : OR6Chat7WriteClosedNote();
    self.sections = @[s];
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    if (![row.userInfo isKindOfClass:NSDictionary.class]) { [super form:f didSelectRow:row]; return; }
    NSString *grant = row.userInfo[@"id"];
    OR6Chat6Confirm(HUDView(self), [NSString stringWithFormat:OR6L(@"Remove the access of «%@»? The app will no longer see your account information."), row.title], OR6L(@"Remove access"), YES, ^{
        OR6Chat7RunWrite(HUDView(self), _core, @"privacy.appsAccess.revoke", @{@"grantId": grant, @"confirm": @YES}, [@"privacy.appsAccess.revoke:" stringByAppendingString:grant],
                         @"connectors.operation.reconcile", OR6L(@"Access removed."), ^(NSDictionary *r) { (void)r; [self load]; });
    });
}
@end

#pragma mark - Precise location (account setting; no GPS is read)

@interface OR6Chat6LocationScreen : OR6Chat6Form
@end
@implementation OR6Chat6LocationScreen
- (void)load { [_read perform:@"privacy.locationControls.get" parameters:@{}]; [self render]; }
- (void)render {
    NSDictionary *s = Dict(_read.result); NSMutableArray *rows = [NSMutableArray array]; RCFormSection *sec;
    if (s) {
        BOOL locked = [s[@"locked"] isEqual:@YES] || OR6Chat6Text(s[@"restrictedReason"], nil), callable = OR6Chat6On(_core, @"privacy.locationControls.update");
        BOOL write = callable && OR6Chat6PolicyWritable(@"privacy.locationControls.update", @"location") && !locked && [s[@"preciseLocationAllowed"] isKindOfClass:NSNumber.class] && OR6Chat6SettingRequest(s, YES);
        if (write) { RCFormRow *r = [RCFormRow rowWithKind:RCFormRowSwitch title:OR6L(@"Precise location")]; r.on = [s[@"preciseLocationAllowed"] boolValue]; r.userInfo = @"location"; r.identifier = @"chat.location.precise"; [rows addObject:r]; }
        else [rows addObject:[self value:OR6L(@"Precise location") value:(locked ? [NSString stringWithFormat:OR6L(@"%@ · locked"), OnOffUnknown(s[@"preciseLocationAllowed"])] : OnOffUnknown(s[@"preciseLocationAllowed"])) info:nil identifier:@"chat.location.precise"]];
        sec = [RCFormSection sectionWithTitle:nil rows:rows];
        NSMutableArray *foot = [NSMutableArray array];
        if (OR6Chat6Text(s[@"restrictedReason"], nil)) [foot addObject:s[@"restrictedReason"]]; // the service's own explanation
        else if (!write && !locked) [foot addObject:(callable ? PolicyNote() : OR6Chat7WriteClosedNote())];
        [foot addObject:OR6L(@"This is an account setting of the service. ChatGPT X never reads the iPhone's location.")];
        sec.footer = [foot componentsJoinedByString:@" "];
    } else { [self addStateOf:_read to:rows empty:nil hasItems:NO identifier:@"chat.location"]; sec = [RCFormSection sectionWithTitle:nil rows:rows]; }
    self.sections = @[sec];
}
- (void)form:(RCFormViewController *)f didToggleRow:(RCFormRow *)row {
    (void)f; NSDictionary *p = [row.userInfo isEqual:@"location"] ? OR6Chat6SettingRequest(Dict(_read.result), row.on) : nil; [self render];
    if (!p) return;
    OR6Chat6Prepare(@"privacy.locationControls.update", @"location", ^(NSError *e) {
        if (e) { OR6Chat6Say(HUDView(self), OR6Chat7ErrorText(e)); [self render]; return; }
        OR6Chat7RunWrite(HUDView(self), _core, @"privacy.locationControls.update", p, @"privacy.locationControls.update:account", @"privacy.locationControls.reconcile", OR6L(@"Saved."), ^(NSDictionary *r) { (void)r; [self load]; });
    });
}
@end

#pragma mark - Export data / Delete account (one-use account authorization from the host)

@interface OR6Chat6AccountRequestScreen : OR6Chat6Form { NSString *_command, *_typed; OR6Chat7Write *_write; OR6Chat7Call *_status; BOOL _web; }
- (id)initWithCore:(OR6APICore *)core command:(NSString *)command;
@end
// The export/delete write outlives its screen: leaving never cancels it (a cancel would make it unknown),
// and a reopened screen adopts it, so its operation ID stays checkable (privacy.operationStatus).
static NSMutableDictionary *gAccountWrites; // intent → OR6Chat7Write, this session only
void OR6Chat6AccountForgetSession(void) { for (OR6Chat7Write *w in gAccountWrites.allValues) w.delegate = nil; [gAccountWrites removeAllObjects]; }
@implementation OR6Chat6AccountRequestScreen
- (id)initWithCore:(OR6APICore *)core command:(NSString *)command {
    BOOL del = [command isEqual:@"privacy.deleteAccount"];
    if ((self = [super initWithCore:core navigator:nil title:(del ? OR6L(@"Delete account") : OR6L(@"Export data"))])) {
        _command = [command copy]; _status = [self call];
        _write = [gAccountWrites[[self intent]] retain]; _write.delegate = self;
    }
    return self;
}
- (BOOL)isDelete { return [_command isEqual:@"privacy.deleteAccount"]; }
- (NSString *)intent { return [_command stringByAppendingString:@":account"]; }
- (NSString *)area { return [self isDelete] ? @"chat.delete_account" : @"chat.export"; }
- (NSString *)phase { return _write.phase ?: @"idle"; }
- (NSDictionary *)receipt { return [[self phase] isEqual:@"done"] ? Dict(_write.receipt) : nil; }
- (id)action { NSDictionary *s = Dict(_status.result), *r = Dict(s[@"receipt"]) ?: [self receipt]; return OR6Chat6AccountActionText(r[@"actionRequired"]) ? r[@"actionRequired"] : nil; }
- (BOOL)canStart {
    NSString *p = [self phase]; NSDictionary *r = [self receipt];
    return OR6Chat6On(_core, _command) && ([p isEqual:@"idle"] || [p isEqual:@"failed"] || [r[@"state"] isEqual:@"rejected"]);
}
- (void)load {}
- (void)chat8ModelChanged:(id)m {
    self.busy = [[self phase] isEqual:@"running"];
    if (m == _status && OR6Chat6AccountStatusSettled(Dict(_status.result), _write.operationId)) OR6Chat7ForgetUnresolvedKey([self intent]); // proven outcome
    [super chat8ModelChanged:m];
}
- (RCFormSection *)introSection {
    NSArray *rows = [self isDelete]
        ? @[[self note:OR6L(@"Deleting your ChatGPT account is permanent and cannot be undone. Your chats, memories and settings are removed with it.")],
            [self note:OR6L(@"A subscription bought through the App Store must be cancelled separately.")]]
        : @[[self note:OR6L(@"ChatGPT prepares a copy of your account data and sends a download link to the e-mail address of your account. Preparing it can take a while.")]];
    return [RCFormSection sectionWithTitle:nil rows:rows];
}
- (RCFormSection *)actionSection {
    if (![self canStart]) return nil;
    NSString *a = [self area]; NSMutableArray *rows = [NSMutableArray array]; RCFormSection *s;
    if ([self isDelete]) {
        RCFormRow *t = [RCFormRow rowWithKind:RCFormRowText title:OR6L(@"Type DELETE to confirm")]; t.text = _typed; t.placeholder = OR6L(@"Type DELETE to confirm"); t.maxLength = 32; t.identifier = [a stringByAppendingString:@".confirmation"];
        RCFormRow *b = [self button:OR6L(@"Delete account") info:@"start" identifier:[a stringByAppendingString:@".delete"]]; b.destructive = YES; b.enabled = OR6Chat6DeleteConfirmationValid(_typed);
        [rows addObject:t]; [rows addObject:b];
        s = [RCFormSection sectionWithTitle:nil rows:rows]; s.footer = OR6L(@"Type the word DELETE in capital letters.");
    } else s = [RCFormSection sectionWithTitle:nil rows:@[[self button:OR6L(@"Request export") info:@"start" identifier:[a stringByAppendingString:@".request"]]]];
    return s;
}
- (RCFormSection *)resultSection {
    NSString *p = [self phase], *a = [self area]; NSMutableArray *rows = [NSMutableArray array];
    BOOL status = OR6Chat6On(_core, @"privacy.operationStatus") && _write.operationId, check = NO;
    if ([p isEqual:@"running"]) [rows addObject:[self note:OR6L(@"Sending the request…")]];
    else if ([p isEqual:@"done"]) {
        NSDictionary *r = [self receipt]; [rows addObject:[self note:OR6Chat6AccountReceiptText(r, _command)]];
        check = ![r[@"verified"] isEqual:@YES] && ![r[@"state"] isEqual:@"rejected"];
    } else if ([p isEqual:@"uncertain"]) { [rows addObject:[self note:OR6L(@"The connection ended before the service confirmed the request. It is not sent again.")]]; check = YES; }
    else if (([p isEqual:@"failed"] || [p isEqual:@"blocked"]) && _write.error) [rows addObject:[self note:OR6Chat7ErrorText(_write.error)]];
    if (status && check) {
        if (_status.busy) [rows addObject:[self note:OR6L(@"Checking…")]];
        else if (_status.error) [rows addObject:[self note:OR6Chat7ErrorText(_status.error)]];
        else if (Dict(_status.result)) [rows addObject:[self note:(OR6Chat6AccountStatusText(Dict(_status.result)) ?: OR6L(@"The result of the request is not known yet."))]];
        if (!_status.busy && (!_status.error || OR6Chat7Retryable(_status.error))) [rows addObject:[self button:OR6L(@"Check status") info:@"status" identifier:[a stringByAppendingString:@".status"]]];
    }
    return rows.count ? [RCFormSection sectionWithTitle:nil rows:rows] : nil;
}
- (RCFormSection *)webSection {
    id action = [self action]; if (!_web && !action) return nil;
    NSMutableArray *rows = [NSMutableArray array]; NSString *a = [self area];
    if (_web) [rows addObject:[self note:OR6L(@"ChatGPT X cannot confirm your recent sign-in for this request. Continue on the web.")]];
    if ([action isEqual:@"reauthenticate"] && OR6Chat7On(_core, @"security.reauthenticate"))
        [rows addObject:[self button:OR6L(@"Sign in again on the web") info:@{@"handoff": @"security.reauthenticate"} identifier:[a stringByAppendingString:@".reauthenticate"]]];
    if (OR6Chat7On(_core, @"privacy.requestsHelp")) [rows addObject:[self button:OR6L(@"Continue on the web") info:@{@"handoff": @"privacy.requestsHelp"} identifier:[a stringByAppendingString:@".web"]]];
    RCFormSection *s = [RCFormSection sectionWithTitle:nil rows:rows];
    s.footer = rows.count > (_web ? 1 : 0) ? OR6L(@"These pages open in Safari. Requests made there are not tracked in ChatGPT X.") : OR6L(@"Open chatgpt.com in a browser to continue.");
    return s;
}
- (void)render {
    NSMutableArray *sections = [NSMutableArray arrayWithObject:[self introSection]];
    RCFormSection *result = [self resultSection], *web = [self webSection], *action = [self actionSection];
    if (result) [sections addObject:result];
    if (web) [sections addObject:web];
    if (action) [sections addObject:action];
    self.sections = sections;
}
- (void)start {
    NSDictionary *p = [self isDelete] ? OR6Chat6DeleteAccountRequest(_typed) : OR6Chat6ExportRequest();
    if (!p || ![self canStart]) return;
    if (OR6Chat7IsUnresolved([self intent])) { OR6Chat6Say(HUDView(self), OR6L(@"The previous request has an unknown result. It is not sent again.")); return; }
    // One-use private account authorization bound by the host to exactly this operation ID; ChatGPT X never sees it.
    NSString *opId = OR6Chat7OperationID(); id<OR6Chat6TrustedHost> host = OR6Chat6TrustedHostNow(); NSError *e = nil;
    BOOL bound = [host respondsToSelector:@selector(chat6BindAccountAuthorizationForOperation:command:error:)] && [host chat6BindAccountAuthorizationForOperation:opId command:_command error:&e];
    _web = !bound; [_status reset];
    if (bound) {
        if (!_write) { _write = [[OR6Chat7Write alloc] initWithCore:_core reconcile:nil]; _write.delegate = self; if (!gAccountWrites) gAccountWrites = [NSMutableDictionary new]; gAccountWrites[[self intent]] = _write; } // status is read separately (privacy.operationStatus)
        if (![_write perform:_command parameters:p intent:[self intent] operationId:opId]) OR6Chat6Say(HUDView(self), OR6L(@"This change cannot be sent now."));
    }
    self.busy = [[self phase] isEqual:@"running"]; [self render];
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    id i = row.userInfo;
    if ([i isEqual:@"start"]) {
        if ([self isDelete]) {
            if (!OR6Chat6DeleteConfirmationValid(_typed)) { OR6Chat6Say(HUDView(self), OR6L(@"Type DELETE to confirm")); return; }
            [self endEditing];
            OR6Chat6Confirm(HUDView(self), OR6L(@"Delete your ChatGPT account permanently? Your chats, memories and settings will be removed. This cannot be undone."), OR6L(@"Delete account"), YES, ^{ [self start]; });
        } else OR6Chat6Confirm(HUDView(self), OR6L(@"Request a copy of your ChatGPT data? A download link will be sent to the e-mail address of your account."), OR6L(@"Request export"), NO, ^{ [self start]; });
        return;
    }
    if ([i isEqual:@"status"]) { if (_write.operationId) [_status perform:@"privacy.operationStatus" parameters:@{@"operationId": _write.operationId}]; [self render]; return; }
    if ([i isKindOfClass:NSDictionary.class] && [i[@"handoff"] isKindOfClass:NSString.class]) { OR6Chat7OpenHandoff(self, _core, i[@"handoff"]); return; }
    [super form:f didSelectRow:row];
}
- (void)form:(RCFormViewController *)f didChangeTextOfRow:(RCFormRow *)row { (void)f; [_typed release]; _typed = [row.text copy]; [self render]; }
- (void)dealloc { if (_write.delegate == (id)self) _write.delegate = nil; [_write release]; [_command release]; [_typed release]; [super dealloc]; } // gAccountWrites keeps a running write: it finishes on its own (no cancel, no resend)
@end

#pragma mark - Entries

NSArray *OR6Chat6AccountRows(OR6APICore *core) {
    NSMutableArray *e = [NSMutableArray array];
    if (OR6Chat6On(core, @"preferences.advanced.get")) [e addObject:@{@"key": @"answers", @"title": OR6L(@"Answers"), @"glyph": @"chart", @"tile": @(RCTileTeal)}];
    if (OR6Chat6On(core, @"account.sessions.list")) [e addObject:@{@"key": @"devices", @"title": OR6L(@"Devices and sessions"), @"glyph": @"devices", @"tile": @(RCTileGray)}];
    return e;
}
NSArray *OR6Chat6AccountMemoryEntries(OR6APICore *core) {
    // Entries never read anything: the capacity is shown inside the screen.
    return OR6Chat6On(core, @"memories.list") ? @[@{@"key": @"memories", @"title": OR6L(@"Saved memories"), @"glyph": @"brain", @"identifier": @"chat.memory.saved"}] : @[];
}
NSArray *OR6Chat6AccountPrivacyEntries(OR6APICore *core) {
    NSMutableArray *e = [NSMutableArray array];
    if (OR6Chat6On(core, @"privacy.appsAccess.list")) [e addObject:@{@"key": @"apps_access", @"title": OR6L(@"Apps with access"), @"glyph": @"apps", @"identifier": @"chat.privacy.apps_access"}];
    if (OR6Chat6On(core, @"privacy.locationControls.get")) [e addObject:@{@"key": @"location", @"title": OR6L(@"Precise location"), @"glyph": @"location", @"identifier": @"chat.privacy.location"}];
    if (OR6Chat6On(core, @"privacy.exportData")) [e addObject:@{@"key": @"export", @"title": OR6L(@"Export data"), @"glyph": @"mail", @"identifier": @"chat.privacy.export"}];
    if (OR6Chat6On(core, @"privacy.deleteAccount")) [e addObject:@{@"key": @"delete_account", @"title": OR6L(@"Delete account"), @"glyph": @"trash", @"identifier": @"chat.privacy.delete_account"}];
    return e;
}
UIViewController *OR6Chat6CreateAccount(OR6APICore *core, NSString *key) {
    if ([key isEqual:@"export"] || [key isEqual:@"delete_account"])
        return [[[OR6Chat6AccountRequestScreen alloc] initWithCore:core command:([key isEqual:@"export"] ? @"privacy.exportData" : @"privacy.deleteAccount")] autorelease];
    Class c = [key isEqual:@"devices"] ? OR6Chat6DevicesScreen.class : [key isEqual:@"answers"] ? OR6Chat6AnswersScreen.class : [key isEqual:@"memories"] ? OR6Chat6MemoriesScreen.class
            : [key isEqual:@"apps_access"] ? OR6Chat6AppsAccessScreen.class : [key isEqual:@"location"] ? OR6Chat6LocationScreen.class : nil;
    NSString *title = [key isEqual:@"devices"] ? OR6L(@"Devices and sessions") : [key isEqual:@"answers"] ? OR6L(@"Answers") : [key isEqual:@"memories"] ? OR6L(@"Saved memories")
            : [key isEqual:@"apps_access"] ? OR6L(@"Apps with access") : OR6L(@"Precise location");
    return c ? [[[c alloc] initWithCore:core navigator:nil title:title] autorelease] : nil;
}
