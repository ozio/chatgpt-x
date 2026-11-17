#import "OR6Chat6Base.h"
#import "RCGlyph.h"
#import "RCHUD.h"

static id<OR6Chat6TrustedHost> gHost;
void OR6Chat6SetTrustedHost(id<OR6Chat6TrustedHost> host) { gHost = host; }
id<OR6Chat6TrustedHost> OR6Chat6TrustedHostNow(void) { return gHost; }
BOOL OR6Chat6On(OR6APICore *core, NSString *op) { return OR6Chat7Callable(core, op); }
BOOL OR6Chat6AllOn(OR6APICore *core, NSArray *ops) { if (!ops.count) return NO; for (NSString *op in ops) if (!OR6Chat6On(core, op)) return NO; return YES; }
BOOL OR6Chat6PolicyBound(NSString *policy) { return [gHost respondsToSelector:@selector(chat6PolicyBound:)] && [gHost chat6PolicyBound:policy]; }
BOOL OR6Chat6PolicyWritable(NSString *op, NSString *policy) {
    return [gHost respondsToSelector:@selector(chat6PrepareOperation:completion:)] || [gHost respondsToSelector:@selector(chat6PrepareOperation:error:)] || OR6Chat6PolicyBound(policy);
}
@interface OR6Chat6PrepareTask : NSObject <OR6APITask> { @public id<OR6APITask> inner; BOOL cancelled; }
@end
@implementation OR6Chat6PrepareTask
- (void)cancel { cancelled = YES; [inner cancel]; }
- (void)dealloc { [inner release]; [super dealloc]; }
@end
id<OR6APITask> OR6Chat6Prepare(NSString *op, NSString *policy, void (^ready)(NSError *)) {
    OR6Chat6PrepareTask *t = [[[OR6Chat6PrepareTask alloc] init] autorelease]; void (^go)(NSError *) = [[ready copy] autorelease];
    id<OR6Chat6TrustedHost> h = gHost;
    if ([h respondsToSelector:@selector(chat6PrepareOperation:completion:)]) {
        __block BOOL once = NO;
        id<OR6APITask> inner = [h chat6PrepareOperation:op completion:^(NSError *e) { if (once || t->cancelled) return; once = YES; if (go) go(e); }];
        t->inner = [(id)inner retain]; return t;
    }
    NSError *e = nil;
    if ([h respondsToSelector:@selector(chat6PrepareOperation:error:)]) { if (![h chat6PrepareOperation:op error:&e] && !e) e = OR6APIError(@"capability_unverified", @"none"); }
    else if (!OR6Chat6PolicyBound(policy)) e = OR6APIError(@"capability_unverified", @"none");
    if (go) go(e);
    return t;
}

NSString *OR6Chat6Text(id v, NSString *fallback) { return [v isKindOfClass:NSString.class] && [v length] ? v : fallback; }

NSString *OR6Chat6RelativeDate(id v) {
    NSDate *d = OR6Chat6ParseDate(v); // the timestamp's own zone (Z / ±hh:mm, fractions); malformed or zoneless: unknown
    if (!d) return nil;
    NSDateFormatter *out = [[[NSDateFormatter alloc] init] autorelease];
    NSCalendar *cal = [NSCalendar currentCalendar]; NSUInteger u = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit;
    BOOL today = [[cal components:u fromDate:d] isEqual:[cal components:u fromDate:[NSDate date]]];
    out.dateStyle = today ? NSDateFormatterNoStyle : NSDateFormatterMediumStyle; out.timeStyle = NSDateFormatterShortStyle;
    return [out stringFromDate:d];
}
void OR6Chat6Confirm(UIView *view, NSString *title, NSString *confirm, BOOL destructive, void (^confirmed)(void)) {
    void (^c)(void) = [[confirmed copy] autorelease];
    OR6Chat8ShowSheet(view, title, destructive ? @[] : @[confirm], destructive ? confirm : nil, ^(NSInteger i, NSString *t) { (void)t; if ((destructive ? i == -2 : i == 0) && c) c(); });
}
void OR6Chat6Say(UIView *view, NSString *text) { if (!text.length) return; [RCHUD showText:text kind:RCHUDTextOnly inView:view seconds:2]; UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, text); }

@interface OR6Chat6Form () { NSMutableArray *_owned; }
@end
@implementation OR6Chat6Form
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav title:(NSString *)title {
    if ((self = [super init])) { _core = [core retain]; _nav = nav; self.title = title; self.delegate = self; _read = [[OR6Chat7Call alloc] initWithCore:core]; _read.delegate = self; _owned = [NSMutableArray new]; }
    return self;
}
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; if (!_loaded) { _loaded = YES; [self load]; } [self render]; }
- (void)load {}
- (void)render {}
- (void)chat8ModelChanged:(id)m { (void)m; [self render]; }
- (RCFormRow *)note:(NSString *)t { return [RCFormRow rowWithKind:RCFormRowNote title:t]; }
- (RCFormRow *)button:(NSString *)t info:(id)info identifier:(NSString *)i { RCFormRow *r = [RCFormRow rowWithKind:RCFormRowButton title:t]; r.userInfo = info; r.identifier = i; return r; }
- (RCFormRow *)value:(NSString *)t value:(NSString *)v info:(id)info identifier:(NSString *)i {
    RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:t]; r.value = v; r.userInfo = info; r.identifier = i; r.disclosure = info != nil; r.enabled = info != nil; return r;
}
- (BOOL)addStateOf:(OR6Chat7Call *)c to:(NSMutableArray *)rows empty:(NSString *)empty hasItems:(BOOL)has identifier:(NSString *)ident {
    if (c.busy) { [rows addObject:[self note:OR6L(@"Loading…")]]; return YES; }
    if (c.error) {
        [rows addObject:[self note:OR6Chat7ErrorText(c.error)]];
        if (OR6Chat7Retryable(c.error)) [rows addObject:[self button:OR6L(@"Read again") info:@"retry" identifier:[ident stringByAppendingString:@".retry"]]];
        return YES;
    }
    if (!has && empty && c.result) { [rows addObject:[self note:empty]]; return YES; }
    return NO;
}
- (BOOL)addStateOfPager:(OR6Chat6Pager *)p to:(NSMutableArray *)rows empty:(NSString *)empty identifier:(NSString *)ident {
    if (p.busy) { [rows addObject:[self note:OR6L(@"Loading…")]]; return YES; }
    if (p.error) {
        [rows addObject:[self note:OR6Chat7ErrorText(p.error)]];
        if (p.retryAvailable) [rows addObject:[self button:OR6L(@"Read again") info:@{@"pager": p, @"action": @"retry"} identifier:[ident stringByAppendingString:@".retry"]]];
        return YES;
    }
    if (p.hasMore) { [rows addObject:[self button:OR6L(@"Show more") info:@{@"pager": p, @"action": @"more"} identifier:[ident stringByAppendingString:@".more"]]]; return YES; }
    if (p.loaded && !p.items.count && empty) { [rows addObject:[self note:empty]]; return YES; }
    return NO;
}
- (OR6Chat6Pager *)pager:(NSString *)op parameters:(NSDictionary *)p tokenKey:(NSString *)tk nextKey:(NSString *)nk idKey:(NSString *)ik {
    OR6Chat6Pager *g = [[[OR6Chat6Pager alloc] initWithCore:_core operation:op parameters:p tokenKey:tk nextKey:nk idKey:ik] autorelease];
    g.delegate = self; [_owned addObject:g]; return g;
}
- (OR6Chat7Call *)call { OR6Chat7Call *c = [[[OR6Chat7Call alloc] initWithCore:_core] autorelease]; c.delegate = self; [_owned addObject:c]; return c; }
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    (void)f; id i = row.userInfo;
    if ([i isEqual:@"retry"]) { [self load]; return; }
    if ([i isKindOfClass:NSDictionary.class] && [i[@"pager"] isKindOfClass:OR6Chat6Pager.class]) {
        OR6Chat6Pager *p = i[@"pager"]; if ([i[@"action"] isEqual:@"retry"]) [p retry]; else [p loadMore]; [self render];
    }
}
- (void)dealloc {
    for (id o in _owned) { [o setDelegate:nil]; [o cancel]; } [_owned release];
    _read.delegate = nil; [_read cancel]; [_read release]; [_core release]; [super dealloc];
}
@end

#pragma mark - Entry points (each part implements its own; this file only composes them)

UIViewController *OR6Chat6CreateLocked(OR6APICore *core, id<OR6Chat7Navigator> nav);       // OR6Chat6Locked.m
UIViewController *OR6Chat6CreateLockedSettings(OR6APICore *core);                         // OR6Chat6Locked.m
NSArray *OR6Chat6LockedPrivacyEntries(OR6APICore *core);                                  // OR6Chat6Locked.m
UIViewController *OR6Chat6CreateGPTs(OR6APICore *core, id<OR6Chat7Navigator> nav);         // OR6Chat6GPTs.m
UIViewController *OR6Chat6CreateTasks(OR6APICore *core, id<OR6Chat7Navigator> nav);        // OR6Chat6Tasks.m
NSArray *OR6Chat6AccountRows(OR6APICore *core);                                           // OR6Chat6Account.m
UIViewController *OR6Chat6CreateAccount(OR6APICore *core, NSString *key);                 // OR6Chat6Account.m
NSArray *OR6Chat6AccountMemoryEntries(OR6APICore *core);                                  // OR6Chat6Account.m
NSArray *OR6Chat6AccountPrivacyEntries(OR6APICore *core);                                 // OR6Chat6Account.m
NSArray *OR6Chat6SettingsRows(OR6APICore *core);                                          // OR6Chat6Settings.m
UIViewController *OR6Chat6CreateSettings(OR6APICore *core, NSString *key);                // OR6Chat6Settings.m
NSArray *OR6Chat6SettingsPrivacyEntries(OR6APICore *core);                                // OR6Chat6Settings.m

NSArray *OR6Chat6DrawerEntries(OR6APICore *core) {
    NSMutableArray *e = [NSMutableArray array];
    if (OR6Chat6On(core, @"gpts.explore")) [e addObject:@{@"key": @"gpts", @"title": OR6L(@"GPT"), @"glyph": @"gpt", @"identifier": @"chat.drawer.gpts"}];
    if (OR6Chat6On(core, @"tasks.list")) [e addObject:@{@"key": @"tasks", @"title": OR6L(@"Tasks"), @"glyph": @"clock", @"identifier": @"chat.drawer.tasks"}];
    if (OR6Chat6On(core, @"locked.status") && OR6Chat6On(core, @"locked.pin.verify") && OR6Chat6On(core, @"locked.conversations.list"))
        [e addObject:@{@"key": @"locked", @"title": OR6L(@"Locked chats"), @"glyph": @"lock", @"identifier": @"chat.drawer.locked"}];
    return e;
}
BOOL OR6Chat6IsDrawerKey(id key) { return [@[@"gpts", @"tasks", @"locked"] containsObject:key ?: @""]; }
UIViewController *OR6Chat6CreateDrawerScreen(OR6APICore *core, NSString *key, id<OR6Chat7Navigator> nav) {
    if ([key isEqual:@"locked"]) return OR6Chat6CreateLocked(core, nav);
    if ([key isEqual:@"gpts"]) return OR6Chat6CreateGPTs(core, nav);
    if ([key isEqual:@"tasks"]) return OR6Chat6CreateTasks(core, nav);
    return nil;
}
NSArray *OR6Chat6AccountEntries(OR6APICore *core) { return [OR6Chat6AccountRows(core) arrayByAddingObjectsFromArray:OR6Chat6SettingsRows(core)]; }
NSArray *OR6Chat6MemoryEntries(OR6APICore *core) { return OR6Chat6AccountMemoryEntries(core); }
NSArray *OR6Chat6PrivacyEntries(OR6APICore *core) {
    NSMutableArray *e = [NSMutableArray arrayWithArray:OR6Chat6AccountPrivacyEntries(core)];
    [e addObjectsFromArray:OR6Chat6SettingsPrivacyEntries(core)]; [e addObjectsFromArray:OR6Chat6LockedPrivacyEntries(core)];
    return e;
}
UIViewController *OR6Chat6CreateAccountScreen(OR6APICore *core, NSString *key) {
    if (![key isKindOfClass:NSString.class]) return nil;
    if ([key isEqual:@"locked_settings"]) return OR6Chat6CreateLockedSettings(core);
    return OR6Chat6CreateAccount(core, key) ?: OR6Chat6CreateSettings(core, key);
}
