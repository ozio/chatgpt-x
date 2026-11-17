// Stage-6 «Account settings» screens built only from the ChatGPT X kit:
//   «Apps»   connectors.catalog / installed / get, install, turn on/off, remove (API6B)
//   «App permissions» (Privacy) connectors.permissions.default.get/set; per-link permissions,
//            connection state and Disconnect through OR6Chat6CreateConnectorSettings (needs the
//            service's exact connector ID, which no public read returns in this build)
//   «Voice»  voice.settings.get, voices, sample, voice mode, language (API6F account settings;
//            ChatGPT X has no voice conversations) and the host-bound voice session screen
//   «Models» Auto preference and the model/effort catalogue (API6F model controls, local)
// and the API6E «Other ways to sign in…» Safari handoffs. Reads run when a screen opens or on an
// explicit tap; every remote write is an explicit tap (+ confirmation where it matters) through
// OR6Chat6SettingsWrite: one operation ID, never resent, an unconfirmed/unknown result offers only
// the read-only reconcile («Check»), and a confirmed write re-reads the state.
#import "OR6Chat6Base.h"
#import "OR6Chat6Settings.h"
#import "OR6Chat6SettingsLogic.h"
#import "RCHUD.h"

typedef void (^OR6Chat6Written)(NSString *outcome, NSDictionary *receipt);
static NSString *YesNo(id v) { return [v isEqual:@YES] ? OR6L(@"Yes") : [v isEqual:@NO] ? OR6L(@"No") : OR6L(@"Unknown"); }
static UIView *HUDView(UIViewController *c) { return c.view.window ?: c.view; }

#pragma mark - Write runner (HUDs and the «Check» alert)

static NSMutableSet *gSettingsRunners; // a runner lives until its write and alerts end
@interface OR6Chat6SettingsRunner : NSObject <OR6Chat8ModelDelegate, UIAlertViewDelegate> {
@public OR6Chat6SettingsWrite *write; UIView *hud; NSString *done, *intent; OR6Chat6Written finished; RCHUD *busy;
}
@end
@implementation OR6Chat6SettingsRunner
- (void)end { write.delegate = nil; [[self retain] autorelease]; [gSettingsRunners removeObject:self]; }
- (void)busyText:(NSString *)t { if (!busy) busy = [[RCHUD showText:t kind:RCHUDBusy inView:hud seconds:0] retain]; }
- (void)unbusy { [busy hide]; [busy release]; busy = nil; }
- (void)report:(NSString *)o { if (finished) finished(o, write.receipt); }
- (void)ask:(NSString *)title message:(NSString *)message {
    UIAlertView *a = [[[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:OR6L(@"Later") otherButtonTitles:OR6L(@"Check"), nil] autorelease];
    [a show];
}
- (void)chat8ModelChanged:(id)m {
    (void)m; NSString *o = write.outcome;
    if ([o isEqual:@"running"]) { [self busyText:OR6L(@"Saving…")]; return; }
    if ([o isEqual:@"checking"]) { [self busyText:OR6L(@"Checking…")]; return; }
    [self unbusy];
    if ([o isEqual:@"confirmed"]) { [RCHUD showText:done kind:RCHUDDone inView:hud seconds:1.4]; UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, done); [self report:o]; [self end]; return; }
    if ([o isEqual:@"rejected"]) { OR6Chat6Say(hud, OR6L(@"The service did not make this change.")); [self report:o]; [self end]; return; }
    if ([o isEqual:@"unconfirmed"]) { [self report:o]; [self ask:OR6L(@"Not confirmed yet") message:OR6L(@"The service has not confirmed this change yet. It is not sent again. Check the current state?")]; return; }
    if ([o isEqual:@"uncertain"]) { [self report:o]; [self ask:OR6L(@"Result unknown") message:OR6L(@"The connection ended before the service confirmed the change. It is not sent again. Check the current state?")]; return; }
    OR6Chat6Say(hud, OR6Chat7ErrorText(write.error)); [self report:o]; [self end]; // failed (not sent) / blocked (stop signal)
}
- (void)alertView:(UIAlertView *)a clickedButtonAtIndex:(NSInteger)i {
    if (i == a.cancelButtonIndex) { [self end]; return; }
    if ([write check] || [write checkIntent:intent]) return; // read-only reconcile; the outcome arrives through the delegate
    OR6Chat6Say(hud, OR6L(@"This change cannot be checked now.")); [self end];
}
- (void)dealloc { write.delegate = nil; [write release]; [hud release]; [done release]; [intent release]; [finished release]; [busy release]; [super dealloc]; }
@end

// One explicit settings write. An intent whose earlier write is still unknown is not sent again:
// the user is asked to check it (read-only) instead. NO: nothing was sent.
static BOOL RunSettingsWrite(UIView *view, OR6APICore *core, NSString *op, NSDictionary *p, NSString *intent, NSString *reconcile, NSString *done, OR6Chat6Written finished) {
    if (!view) return NO;
    if (!p || !intent || !OR6Chat6On(core, op)) { OR6Chat6Say(view, OR6L(@"This change cannot be sent now.")); return NO; }
    if (!gSettingsRunners) gSettingsRunners = [NSMutableSet new];
    OR6Chat6SettingsRunner *r = [[[OR6Chat6SettingsRunner alloc] init] autorelease];
    r->write = [[OR6Chat6SettingsWrite alloc] initWithCore:core reconcile:reconcile]; r->write.delegate = r;
    r->hud = [view retain]; r->done = [done copy]; r->intent = [intent copy]; r->finished = [finished copy];
    [gSettingsRunners addObject:r];
    if (OR6Chat7IsUnresolved(intent)) {
        [r ask:OR6L(@"Result unknown") message:OR6L(@"An earlier attempt of this change has an unknown result. It is not sent again. Check the current state?")];
        return NO;
    }
    if ([r->write perform:op parameters:p intent:intent]) return YES;
    OR6Chat6Say(view, OR6L(@"This change cannot be sent now.")); [r end];
    return NO;
}

#pragma mark - App permissions (default for all apps, or one connection)

@interface OR6Chat6PermissionScreen : OR6Chat6Form { NSString *_linkId; }
- (id)initWithCore:(OR6APICore *)core linkId:(NSString *)linkId title:(NSString *)title;
@end
@implementation OR6Chat6PermissionScreen
- (id)initWithCore:(OR6APICore *)core linkId:(NSString *)linkId title:(NSString *)title {
    if ((self = [super initWithCore:core navigator:nil title:title])) _linkId = [linkId copy];
    return self;
}
- (void)viewDidLoad { [super viewDidLoad]; self.tableView.accessibilityIdentifier = @"chat.permissions.table"; }
- (NSString *)readOp { return _linkId ? @"connectors.permissions.get" : @"connectors.permissions.default.get"; }
- (NSString *)writeOp { return _linkId ? @"connectors.permissions.set" : @"connectors.permissions.default.set"; }
- (void)load { [_read perform:[self readOp] parameters:(_linkId ? @{@"linkId": _linkId} : @{})]; [self render]; }
- (id)current {
    NSDictionary *s = _read.result;
    if (_linkId && [s[@"usingDefault"] isEqual:@YES]) return NSNull.null;
    return s[@"policy"] ?: NSNull.null;
}
- (NSString *)explain:(id)p {
    if (p == NSNull.null) { NSString *d = OR6Chat6PolicyLabel(_read.result[@"defaultPolicy"]); return [_read.result[@"defaultPolicy"] isKindOfClass:NSString.class] && d ? [NSString stringWithFormat:OR6L(@"Your default: %@"), d] : nil; }
    if ([p isEqual:@"always_ask"]) return OR6L(@"Apps ask you before every action.");
    if ([p isEqual:@"ask_before_writes"]) return OR6L(@"Apps ask before they change or send anything.");
    if ([p isEqual:@"review_important_actions"]) return OR6L(@"Apps ask you to review important actions.");
    if ([p isEqual:@"full_access"]) return OR6L(@"Apps act without asking. Use only with apps you trust.");
    return nil;
}
- (void)render {
    NSMutableArray *rows = [NSMutableArray array]; RCFormSection *sec;
    if (_read.result) {
        BOOL write = OR6Chat6On(_core, [self writeOp]); id cur = [self current];
        NSMutableArray *policies = [NSMutableArray arrayWithArray:(_linkId ? OR6Chat6LinkPolicies() : OR6Chat6DefaultPolicies())];
        if (![policies containsObject:cur]) [policies addObject:cur]; // e.g. full access set elsewhere: shown, not offered
        for (id p in policies) {
            NSString *label = OR6Chat6PolicyLabel(p); if (!label) continue;
            RCFormRow *r = [RCFormRow rowWithKind:RCFormRowCheck title:label]; r.subtitle = [self explain:p]; r.checked = [p isEqual:cur];
            BOOL offered = write && (_linkId ? [OR6Chat6LinkPolicies() containsObject:p] : [OR6Chat6DefaultPolicies() containsObject:p]);
            r.enabled = offered; r.userInfo = offered ? @{@"policy": p} : nil;
            r.identifier = [@"chat.permissions." stringByAppendingString:(p == NSNull.null ? @"default" : p)]; [rows addObject:r];
        }
        sec = [RCFormSection sectionWithTitle:OR6L(@"When apps act for you") rows:rows];
        sec.footer = !write ? OR6Chat7WriteClosedNote() : _linkId ? OR6L(@"Applies to this connection only.") : OR6L(@"Applies to apps that do not have their own setting.");
    } else { [self addStateOf:_read to:rows empty:nil hasItems:NO identifier:@"chat.permissions"]; sec = [RCFormSection sectionWithTitle:nil rows:rows]; }
    self.sections = @[sec];
}
- (void)save:(id)policy {
    NSDictionary *p = _linkId ? OR6Chat6LinkPolicyParameters(_linkId, policy) : OR6Chat6DefaultPolicyParameters(policy);
    NSString *intent = [NSString stringWithFormat:@"%@:%@", [self writeOp], _linkId ?: @"default"];
    RunSettingsWrite(HUDView(self), _core, [self writeOp], p, intent, @"connectors.operation.reconcile", OR6L(@"Saved."), ^(NSString *o, NSDictionary *r) { (void)o; (void)r; [self load]; });
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    if (![row.userInfo isKindOfClass:NSDictionary.class] || !row.userInfo[@"policy"]) { [super form:f didSelectRow:row]; return; }
    id p = row.userInfo[@"policy"]; [self render]; // the check moves only after a confirmed change
    if ([p isEqual:[self current]]) return;
    if ([p isEqual:@"full_access"]) {
        OR6Chat6Confirm(HUDView(self), OR6L(@"With full access, this app acts for you without asking, including changing and sending things. Allow full access?"), OR6L(@"Allow full access"), YES, ^{ [self save:p]; });
        return;
    }
    NSString *t = p == NSNull.null ? OR6L(@"Use your default setting for this connection?") : _linkId ? [NSString stringWithFormat:OR6L(@"Use «%@» for this connection?"), row.title]
                : [NSString stringWithFormat:OR6L(@"Use «%@» for all apps without their own setting?"), row.title];
    OR6Chat6Confirm(HUDView(self), t, OR6L(@"Change"), NO, ^{ [self save:p]; });
}
- (void)dealloc { [_linkId release]; [super dealloc]; }
@end

#pragma mark - Connector connection state and links

@interface OR6Chat6ConnectorScreen : OR6Chat6Form { NSString *_connectorId; }
- (id)initWithCore:(OR6APICore *)core connectorId:(NSString *)connectorId;
@end
@implementation OR6Chat6ConnectorScreen
- (id)initWithCore:(OR6APICore *)core connectorId:(NSString *)cid {
    if ((self = [super initWithCore:core navigator:nil title:OR6L(@"Connection")])) _connectorId = [cid copy];
    return self;
}
- (void)viewDidLoad { [super viewDidLoad]; self.tableView.accessibilityIdentifier = @"chat.connector.table"; }
- (void)load { [_read perform:@"connectors.settings.get" parameters:@{@"connectorId": _connectorId}]; [self render]; }
- (void)render {
    NSDictionary *c = [_read.result isKindOfClass:NSDictionary.class] ? _read.result : nil; NSMutableArray *sections = [NSMutableArray array], *rows = [NSMutableArray array];
    if (!c) { [self addStateOf:_read to:rows empty:nil hasItems:NO identifier:@"chat.connector"]; self.sections = @[[RCFormSection sectionWithTitle:nil rows:rows]]; return; }
    if (OR6Chat6Text(c[@"name"], nil)) self.title = c[@"name"];
    NSArray *facts = @[@[OR6L(@"Status"), c[@"status"] ?: NSNull.null, @"status"], @[OR6L(@"Sign-in"), c[@"authStatus"] ?: NSNull.null, @"auth"], @[OR6L(@"Sync"), c[@"syncStatus"] ?: NSNull.null, @"sync"]];
    for (NSArray *f in facts) { NSString *v = OR6Chat6ServiceLabel(f[1]); if (v) [rows addObject:[self value:f[0] value:v info:nil identifier:[@"chat.connector." stringByAppendingString:f[2]]]]; }
    if ([c[@"privacyControl"] isKindOfClass:NSString.class] && OR6Chat6PolicyLabel(c[@"privacyControl"])) [rows addObject:[self value:OR6L(@"Permissions") value:OR6Chat6PolicyLabel(c[@"privacyControl"]) info:nil identifier:@"chat.connector.policy"]];
    if ([c[@"adminDisabled"] isEqual:@YES]) [rows addObject:[self note:OR6L(@"Your admin turned this app off.")]];
    if (rows.count) [sections addObject:[RCFormSection sectionWithTitle:nil rows:rows]];
    NSMutableArray *links = [NSMutableArray array]; NSUInteger n = 0;
    BOOL perm = OR6Chat6On(_core, @"connectors.permissions.get"), disc = OR6Chat6On(_core, @"connectors.disconnect");
    for (NSDictionary *l in c[@"links"]) {
        if (![l isKindOfClass:NSDictionary.class] || !OR6Chat6Text(l[@"id"], nil)) continue;
        RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:[NSString stringWithFormat:OR6L(@"Connection %lu"), (unsigned long)++n]];
        r.subtitle = OR6Chat6ServiceLabel(l[@"authStatus"]); r.value = OR6Chat6PolicyLabel(l[@"privacyControl"]); r.glyph = @"link"; r.tile = RCTileBlue;
        BOOL act = perm || disc; r.enabled = act; r.disclosure = act; r.userInfo = act ? @{@"link": l} : nil; r.identifier = @"chat.connector.link"; [links addObject:r];
    }
    if (links.count) { RCFormSection *s = [RCFormSection sectionWithTitle:OR6L(@"Connected accounts") rows:links]; if (!perm && !disc) s.footer = OR6Chat7WriteClosedNote(); [sections addObject:s]; }
    else [sections addObject:[RCFormSection sectionWithTitle:OR6L(@"Connected accounts") rows:@[[self note:OR6L(@"No accounts are connected.")]]]];
    self.sections = sections;
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    NSDictionary *l = [row.userInfo isKindOfClass:NSDictionary.class] ? row.userInfo[@"link"] : nil;
    if (!l) { [super form:f didSelectRow:row]; return; }
    NSMutableArray *buttons = [NSMutableArray array];
    BOOL perm = OR6Chat6On(_core, @"connectors.permissions.get"), disc = OR6Chat6On(_core, @"connectors.disconnect");
    if (perm) [buttons addObject:OR6L(@"Permissions")];
    NSString *name = OR6Chat6Text(_read.result[@"name"], OR6L(@"this app")), *title = row.title;
    OR6Chat8ShowSheet(HUDView(self), title, buttons, disc ? OR6L(@"Disconnect") : nil, ^(NSInteger i, NSString *t) {
        (void)t;
        if (i == 0 && perm) { [self.navigationController pushViewController:[[[OR6Chat6PermissionScreen alloc] initWithCore:_core linkId:l[@"id"] title:title] autorelease] animated:YES]; return; }
        if (i != -2) return;
        OR6Chat6Confirm(HUDView(self), [NSString stringWithFormat:OR6L(@"Disconnect this account from «%@»? ChatGPT can no longer use it until you connect it again on the web."), name], OR6L(@"Disconnect"), YES, ^{
            RunSettingsWrite(HUDView(self), _core, @"connectors.disconnect", OR6Chat6DisconnectParameters(l[@"id"]), [@"connectors.disconnect:" stringByAppendingString:l[@"id"]],
                             @"connectors.operation.reconcile", OR6L(@"Disconnected."), ^(NSString *o, NSDictionary *r) { (void)o; (void)r; [self load]; });
        });
    });
}
- (void)dealloc { [_connectorId release]; [super dealloc]; }
@end

#pragma mark - App detail

@interface OR6Chat6AppScreen : OR6Chat6Form { NSDictionary *_plugin; void (^_changed)(void); }
- (id)initWithCore:(OR6APICore *)core plugin:(NSDictionary *)plugin changed:(void (^)(void))changed;
@end
@implementation OR6Chat6AppScreen
- (id)initWithCore:(OR6APICore *)core plugin:(NSDictionary *)plugin changed:(void (^)(void))changed {
    if ((self = [super initWithCore:core navigator:nil title:OR6Chat6Text(plugin[@"name"], OR6L(@"App"))])) { _plugin = [plugin copy]; _changed = [changed copy]; }
    return self;
}
- (void)viewDidLoad { [super viewDidLoad]; self.tableView.accessibilityIdentifier = @"chat.app.table"; }
- (void)load { if (OR6Chat6On(_core, @"connectors.get")) [_read perform:@"connectors.get" parameters:@{@"pluginId": _plugin[@"id"]}]; [self render]; }
- (NSDictionary *)plugin { return [_read.result isKindOfClass:NSDictionary.class] ? _read.result : _plugin; }
- (NSString *)operationOf:(NSString *)a { return @{@"install": @"connectors.install", @"enable": @"connectors.enable", @"disable": @"connectors.disable", @"remove": @"connectors.remove"}[a]; }
- (void)render {
    NSDictionary *p = [self plugin]; NSMutableArray *sections = [NSMutableArray array];
    RCFormRow *head = [RCFormRow rowWithKind:RCFormRowValue title:OR6Chat6Text(p[@"name"], OR6L(@"App"))];
    head.subtitle = OR6Chat6Text(p[@"description"], nil); head.glyph = @"apps"; head.tile = RCTilePurple; head.enabled = NO; head.identifier = @"chat.app.name";
    NSMutableArray *top = [NSMutableArray arrayWithObject:head];
    [self addStateOf:_read to:top empty:nil hasItems:YES identifier:@"chat.app"];
    [sections addObject:[RCFormSection sectionWithTitle:nil rows:top]];
    NSMutableArray *facts = [NSMutableArray array];
    [facts addObject:[self value:OR6L(@"Installed") value:YesNo(p[@"installed"]) info:nil identifier:@"chat.app.installed"]];
    if ([p[@"installed"] isEqual:@YES]) [facts addObject:[self value:OR6L(@"Turned on") value:YesNo(p[@"enabled"]) info:nil identifier:@"chat.app.enabled"]];
    if (OR6Chat6ServiceLabel(p[@"status"])) [facts addObject:[self value:OR6L(@"Availability") value:OR6Chat6ServiceLabel(p[@"status"]) info:nil identifier:@"chat.app.status"]];
    if (OR6Chat6ServiceLabel(p[@"installationPolicy"])) [facts addObject:[self value:OR6L(@"Installation") value:OR6Chat6ServiceLabel(p[@"installationPolicy"]) info:nil identifier:@"chat.app.policy"]];
    RCFormSection *state = [RCFormSection sectionWithTitle:nil rows:facts];
    if ([p[@"requiresLocalExecutor"] isEqual:@YES]) state.footer = OR6L(@"This app needs a ChatGPT app on a computer. It is not available on iPhone.");
    [sections addObject:state];
    // Actions on fresh state only: after connectors.get when it is callable (the list row may be old).
    NSMutableArray *acts = [NSMutableArray array]; BOOL closed = NO;
    BOOL fresh = !OR6Chat6On(_core, @"connectors.get") || (_read.result && !_read.busy);
    NSDictionary *titles = @{@"install": OR6L(@"Install"), @"enable": OR6L(@"Turn on"), @"disable": OR6L(@"Turn off"), @"remove": OR6L(@"Remove")};
    if (fresh) for (NSString *a in OR6Chat6AppActions(p)) {
        if (!OR6Chat6On(_core, [self operationOf:a])) { closed = YES; continue; }
        RCFormRow *r = [self button:titles[a] info:@{@"action": a} identifier:[@"chat.app." stringByAppendingString:a]]; r.destructive = [a isEqual:@"remove"]; [acts addObject:r];
    }
    if (acts.count || closed) { RCFormSection *s = [RCFormSection sectionWithTitle:nil rows:acts]; if (closed) s.footer = OR6Chat7WriteClosedNote(); [sections addObject:s]; }
    self.sections = sections;
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    NSString *a = [row.userInfo isKindOfClass:NSDictionary.class] ? row.userInfo[@"action"] : nil;
    if (!a) { [super form:f didSelectRow:row]; return; }
    NSDictionary *p = [self plugin], *m = OR6Chat6AppMutation(a, p); if (!m) return;
    NSString *name = OR6Chat6Text(p[@"name"], OR6L(@"this app"));
    NSDictionary *ask = @{@"install": [NSString stringWithFormat:OR6L(@"Install «%@»? ChatGPT can then use it in your chats."), name],
                          @"enable": [NSString stringWithFormat:OR6L(@"Turn on «%@»? ChatGPT can then use it in your chats."), name],
                          @"disable": [NSString stringWithFormat:OR6L(@"Turn off «%@»? ChatGPT stops using it until you turn it on again."), name],
                          @"remove": [NSString stringWithFormat:OR6L(@"Remove «%@» from your apps? ChatGPT can no longer use it."), name]};
    NSDictionary *done = @{@"install": OR6L(@"App installed."), @"enable": OR6L(@"App turned on."), @"disable": OR6L(@"App turned off."), @"remove": OR6L(@"App removed.")};
    OR6Chat6Confirm(HUDView(self), ask[a], row.title, [a isEqual:@"remove"], ^{
        RunSettingsWrite(HUDView(self), _core, m[@"operation"], m[@"parameters"], m[@"intent"], @"connectors.operation.reconcile", done[a], ^(NSString *o, NSDictionary *r) {
            (void)o; (void)r; [self load]; if (_changed) _changed();
        });
    });
}
- (void)dealloc { [_plugin release]; [_changed release]; [super dealloc]; }
@end

#pragma mark - Apps

#pragma mark - Connections (connectors.installed with includeConnections → connection settings)

// The service's real connections (source connector IDs, never guessed from an app ID). Read on open
// only; its own error and «Read again»; leaving cancels the read (OR6Chat6Form owns the call).
@interface OR6Chat6ConnectionsScreen : OR6Chat6Form
@end
@implementation OR6Chat6ConnectionsScreen
- (void)viewDidLoad { [super viewDidLoad]; self.tableView.accessibilityIdentifier = @"chat.connections.table"; }
- (void)load { [_read perform:@"connectors.installed" parameters:OR6Chat6ConnectionsParameters()]; [self render]; }
- (void)render {
    NSMutableArray *rows = [NSMutableArray array]; NSArray *list = _read.error ? @[] : OR6Chat6Connections(_read.result); NSUInteger n = 0;
    for (NSDictionary *c in list) {
        RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:OR6Chat6Text(c[@"name"], [NSString stringWithFormat:OR6L(@"Connection %lu"), (unsigned long)++n])];
        r.subtitle = OR6Chat6ServiceLabel(c[@"authStatus"]);
        r.value = OR6Chat6PolicyLabel(c[@"privacyControl"]); r.glyph = @"link"; r.tile = RCTileBlue; r.identifier = @"chat.connections.row";
        BOOL open = OR6Chat6On(_core, @"connectors.settings.get"); r.disclosure = open; r.enabled = open; r.userInfo = open ? @{@"connection": c} : nil; [rows addObject:r];
    }
    [self addStateOf:_read to:rows empty:OR6L(@"No accounts are connected.") hasItems:list.count > 0 identifier:@"chat.connections"];
    RCFormSection *s = [RCFormSection sectionWithTitle:nil rows:rows];
    if (list.count) s.footer = OR6L(@"Accounts of other services that your apps use. Open one to see its state, permissions or disconnect it.");
    self.sections = @[s];
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    NSDictionary *c = [row.userInfo isKindOfClass:NSDictionary.class] ? row.userInfo[@"connection"] : nil;
    if (!c) { [super form:f didSelectRow:row]; return; }
    UIViewController *v = OR6Chat6CreateConnectorSettings(_core, c[@"connectorId"]); if (v) [self.navigationController pushViewController:v animated:YES];
}
@end

@interface OR6Chat6AppsScreen : OR6Chat6Form { OR6Chat6Pager *_catalog, *_installed; NSString *_query, *_searched; BOOL _dirty; }
@end
@implementation OR6Chat6AppsScreen
- (void)viewDidLoad { [super viewDidLoad]; self.tableView.accessibilityIdentifier = @"chat.apps.table"; }
- (void)viewWillAppear:(BOOL)a { if (_dirty && _loaded) { _dirty = NO; [self load]; } [super viewWillAppear:a]; }
- (void)load {
    if (!_installed && OR6Chat6On(_core, @"connectors.installed")) _installed = [self pager:@"connectors.installed" parameters:@{} tokenKey:@"pageToken" nextKey:@"nextPageToken" idKey:@"id"];
    if (!_catalog && OR6Chat6On(_core, @"connectors.catalog")) _catalog = [self pager:@"connectors.catalog" parameters:OR6Chat6AppsCatalogParameters(_searched) tokenKey:@"pageToken" nextKey:@"nextPageToken" idKey:@"id"];
    [_installed reload]; [_catalog reload]; [self render];
}
- (RCFormRow *)row:(NSDictionary *)p {
    RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:OR6Chat6Text(p[@"name"], OR6L(@"App"))];
    r.subtitle = OR6Chat6Text(p[@"description"], nil); r.glyph = @"apps"; r.tile = RCTilePurple;
    if ([p[@"installed"] isEqual:@YES]) r.value = [p[@"enabled"] isEqual:@YES] ? OR6L(@"On") : OR6L(@"Off");
    r.userInfo = @{@"plugin": p}; r.disclosure = YES; r.identifier = @"chat.apps.row"; return r;
}
- (NSString *)trimmed { return [_query ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]; }
- (void)render {
    NSMutableArray *sections = [NSMutableArray array];
    if (_catalog) {
        RCFormRow *q = [RCFormRow rowWithKind:RCFormRowText title:OR6L(@"Search")]; q.text = _query; q.placeholder = OR6L(@"Search apps"); q.maxLength = 240; q.identifier = @"chat.apps.search";
        NSMutableArray *rows = [NSMutableArray arrayWithObject:q];
        if (![[self trimmed] isEqual:_searched ?: @""]) [rows addObject:[self button:([self trimmed].length ? OR6L(@"Search") : OR6L(@"Show all apps")) info:@"search" identifier:@"chat.apps.search.go"]];
        [sections addObject:[RCFormSection sectionWithTitle:nil rows:rows]];
    }
    if (OR6Chat6AllOn(_core, @[@"connectors.installed", @"connectors.settings.get"]) && !_searched.length) {
        RCFormRow *c = [RCFormRow rowWithKind:RCFormRowValue title:OR6L(@"Connections")]; c.glyph = @"link"; c.tile = RCTileBlue; c.disclosure = YES; c.userInfo = @"connections"; c.identifier = @"chat.apps.connections";
        [sections addObject:[RCFormSection sectionWithTitle:nil rows:@[c]]];
    }
    if (_installed && !_searched.length) {
        NSMutableArray *rows = [NSMutableArray array]; for (NSDictionary *p in _installed.items) [rows addObject:[self row:p]];
        [self addStateOfPager:_installed to:rows empty:OR6L(@"No apps are installed.") identifier:@"chat.apps.installed"];
        [sections addObject:[RCFormSection sectionWithTitle:OR6L(@"Installed") rows:rows]];
    }
    if (_catalog) {
        NSMutableArray *rows = [NSMutableArray array]; for (NSDictionary *p in _catalog.items) [rows addObject:[self row:p]];
        [self addStateOfPager:_catalog to:rows empty:(_searched.length ? OR6L(@"Nothing found.") : OR6L(@"The service returned no apps.")) identifier:@"chat.apps.catalog"];
        RCFormSection *s = [RCFormSection sectionWithTitle:(_searched.length ? OR6L(@"Results") : OR6L(@"All apps")) rows:rows];
        s.footer = OR6L(@"Apps let ChatGPT use other services in your chats. Open an app to see what you can do with it.");
        [sections addObject:s];
    }
    self.sections = sections;
}
- (void)form:(RCFormViewController *)f didChangeTextOfRow:(RCFormRow *)row { (void)f; [_query release]; _query = [row.text copy]; [self render]; }
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    if ([row.userInfo isEqual:@"connections"]) { [self.navigationController pushViewController:[[[OR6Chat6ConnectionsScreen alloc] initWithCore:_core navigator:nil title:OR6L(@"Connections")] autorelease] animated:YES]; return; }
    if ([row.userInfo isEqual:@"search"]) {
        NSDictionary *p = OR6Chat6AppsCatalogParameters([self trimmed]); if (!p) return;
        [self endEditing]; [_searched release]; _searched = [p[@"query"] copy];
        _catalog.parameters = p; [_catalog reload]; [self render]; return; // one explicit search per tap
    }
    NSDictionary *p = [row.userInfo isKindOfClass:NSDictionary.class] ? row.userInfo[@"plugin"] : nil;
    if (!p) { [super form:f didSelectRow:row]; return; }
    OR6Chat6AppScreen *d = [[[OR6Chat6AppScreen alloc] initWithCore:_core plugin:p changed:^{ _dirty = YES; }] autorelease];
    [self.navigationController pushViewController:d animated:YES];
}
- (void)dealloc { [_query release]; [_searched release]; [super dealloc]; }
@end

#pragma mark - Voice language

@interface OR6Chat6VoiceLanguageScreen : OR6Chat6Form { NSString *_current; void (^_changed)(void); }
- (id)initWithCore:(OR6APICore *)core current:(NSString *)current changed:(void (^)(void))changed;
@end
@implementation OR6Chat6VoiceLanguageScreen
- (id)initWithCore:(OR6APICore *)core current:(NSString *)current changed:(void (^)(void))changed {
    if ((self = [super initWithCore:core navigator:nil title:OR6L(@"Language")])) { _current = [current copy]; _changed = [changed copy]; }
    return self;
}
- (void)viewDidLoad { [super viewDidLoad]; self.tableView.accessibilityIdentifier = @"chat.voice.languages"; }
- (void)load { [_read perform:@"voice.languages.list" parameters:@{}]; [self render]; }
- (void)render {
    NSMutableArray *rows = [NSMutableArray array]; BOOL write = OR6Chat6On(_core, @"voice.languages.select");
    for (NSDictionary *l in OR6Chat6VoiceLanguages(_read.result, [NSLocale currentLocale])) {
        RCFormRow *r = [RCFormRow rowWithKind:RCFormRowCheck title:l[@"title"]]; r.checked = [l[@"id"] isEqual:_current];
        r.enabled = write; r.userInfo = write ? @{@"language": l[@"id"]} : nil; r.identifier = @"chat.voice.language"; [rows addObject:r];
    }
    BOOL has = rows.count > 0;
    [self addStateOf:_read to:rows empty:OR6L(@"No languages are available.") hasItems:has identifier:@"chat.voice.languages"];
    RCFormSection *s = [RCFormSection sectionWithTitle:nil rows:rows];
    if (has) s.footer = write ? OR6L(@"The language you speak in voice conversations. Automatic lets ChatGPT detect it.") : OR6Chat7WriteClosedNote();
    self.sections = @[s];
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    NSString *lang = [row.userInfo isKindOfClass:NSDictionary.class] ? row.userInfo[@"language"] : nil;
    if (!lang) { [super form:f didSelectRow:row]; return; }
    [self render]; if ([lang isEqual:_current]) return;
    RunSettingsWrite(HUDView(self), _core, @"voice.languages.select", OR6Chat6VoiceLanguageParameters(lang, _read.result), @"voice.languages.select:account",
                     @"configuration.operation.reconcile", OR6L(@"Language saved."), ^(NSString *o, NSDictionary *r) {
        (void)r; if ([o isEqual:@"confirmed"]) { [_current release]; _current = [lang copy]; }
        if (_changed) _changed(); [self render];
    });
}
- (void)dealloc { [_current release]; [_changed release]; [super dealloc]; }
@end

#pragma mark - Voice

@interface OR6Chat6VoiceScreen : OR6Chat6Form { OR6Chat7Call *_catalog, *_modes, *_preview, *_status; NSDictionary *_catalogFor, *_playback; NSString *_sampleName; NSTimer *_timer; BOOL _dirty; }
@end
@implementation OR6Chat6VoiceScreen
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav title:(NSString *)title {
    if ((self = [super initWithCore:core navigator:nav title:title])) {
        _catalog = [[self call] retain]; _modes = [[self call] retain]; _preview = [[self call] retain]; _status = [[self call] retain];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(background:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
    return self;
}
- (void)viewDidLoad { [super viewDidLoad]; self.tableView.accessibilityIdentifier = @"chat.voice.table"; }
- (void)viewWillAppear:(BOOL)a { if (_dirty && _loaded) { _dirty = NO; [self load]; } [super viewWillAppear:a]; }
- (void)viewWillDisappear:(BOOL)a { [super viewWillDisappear:a]; [self stopSample]; }
- (void)background:(NSNotification *)n { (void)n; [self stopSample]; [self render]; }
- (NSDictionary *)settings { return [_read.result isKindOfClass:NSDictionary.class] ? _read.result : nil; }
- (BOOL)voiceOff { return [[self settings][@"voiceEnabled"] isEqual:@NO]; }
- (void)load {
    [_catalogFor release]; _catalogFor = nil;
    [_read perform:@"voice.settings.get" parameters:@{}];
    if (OR6Chat6On(_core, @"voice.modes.list")) [_modes perform:@"voice.modes.list" parameters:@{}];
    [self render];
}
- (void)chat8ModelChanged:(id)m {
    // The voices depend on the account's mode and language: read them once the settings arrived.
    NSDictionary *want = m == _read ? OR6Chat6VoiceCatalogParameters([self settings]) : nil;
    if (want && ![want isEqual:_catalogFor] && OR6Chat6On(_core, @"voice.catalog.list")) { [_catalogFor release]; _catalogFor = [want copy]; [_catalog perform:@"voice.catalog.list" parameters:want]; }
    if (m == _preview || m == _status) {
        OR6Chat7Call *c = m; NSDictionary *r = [c.result isKindOfClass:NSDictionary.class] ? c.result : nil;
        if (r && !c.busy) { [_playback release]; _playback = [r copy]; }
        if (c.error && !c.busy) { [_playback release]; _playback = nil; OR6Chat6Say(HUDView(self), OR6Chat7ErrorText(c.error)); }
        BOOL playing = [_playback[@"state"] isEqual:@"playing"] || [_playback[@"state"] isEqual:@"paused"];
        if (playing && !_timer && OR6Chat6On(_core, @"voice.preview.status")) _timer = [[NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(tick:) userInfo:nil repeats:YES] retain];
        if (!playing && !c.busy) [self stopTimer];
    }
    [super chat8ModelChanged:m];
}
- (void)tick:(NSTimer *)t { (void)t; if (!_status.busy && !_preview.busy) [_status perform:@"voice.preview.status" parameters:@{}]; }
- (void)stopTimer { [_timer invalidate]; [_timer release]; _timer = nil; }
- (void)stopSample {
    BOOL active = _preview.busy || [_playback[@"state"] isEqual:@"playing"] || [_playback[@"state"] isEqual:@"paused"];
    [self stopTimer]; [_preview cancel]; [_status cancel];
    if (active && OR6Chat6On(_core, @"voice.preview.stop")) [_core perform:@"voice.preview.stop" parameters:@{} event:nil completion:^(NSDictionary *r, NSError *e) { (void)r; (void)e; }];
    [_playback release]; _playback = nil;
}
- (void)render {
    NSDictionary *s = [self settings], *cat = [_catalog.result isKindOfClass:NSDictionary.class] ? _catalog.result : nil;
    NSMutableArray *sections = [NSMutableArray array]; BOOL off = [self voiceOff];
    if (!s) { NSMutableArray *rows = [NSMutableArray array]; [self addStateOf:_read to:rows empty:nil hasItems:NO identifier:@"chat.voice"]; self.sections = @[[RCFormSection sectionWithTitle:nil rows:rows]]; return; }
    if (off) [sections addObject:[RCFormSection sectionWithTitle:nil rows:@[[self note:OR6L(@"Voice is turned off for this account.")]]]];
    // Voices of the current mode and language.
    NSMutableArray *voices = [NSMutableArray array]; NSString *selected = OR6Chat6Text(cat[@"selectedVoiceId"], OR6Chat6Text(s[@"voiceId"], nil));
    BOOL select = !off && OR6Chat6On(_core, @"voice.catalog.select"), sample = OR6Chat6On(_core, @"voice.preview.start");
    for (NSDictionary *v in cat[@"items"]) {
        if (![v isKindOfClass:NSDictionary.class] || !OR6Chat6Text(v[@"id"], nil)) continue;
        RCFormRow *r = [RCFormRow rowWithKind:RCFormRowCheck title:OR6Chat6Text(v[@"name"], OR6L(@"Voice"))];
        NSString *accent = OR6Chat6Text(v[@"accent"], nil), *desc = OR6Chat6Text(v[@"description"], nil);
        r.subtitle = accent && desc ? [NSString stringWithFormat:@"%@ · %@", desc, accent] : (desc ?: accent);
        r.checked = [v[@"id"] isEqual:selected];
        BOOL act = select || (sample && [v[@"previewAvailable"] isEqual:@YES]); r.enabled = act; r.userInfo = act ? @{@"voice": v} : nil; r.identifier = @"chat.voice.voice"; [voices addObject:r];
    }
    BOOL has = voices.count > 0;
    if (OR6Chat6On(_core, @"voice.catalog.list")) [self addStateOf:_catalog to:voices empty:OR6L(@"No voices for this mode and language.") hasItems:has identifier:@"chat.voice.voices"];
    if (voices.count) { RCFormSection *v = [RCFormSection sectionWithTitle:OR6L(@"Voice") rows:voices]; if (has && !select && !off) v.footer = OR6Chat7WriteClosedNote(); [sections addObject:v]; }
    // The sample that is playing (read back through voice.preview.status).
    NSString *playing = OR6Chat6PlaybackText(_playback);
    if (playing || _preview.busy) {
        RCFormRow *p = [self value:(_sampleName ?: OR6L(@"Sample")) value:(playing ?: OR6L(@"Loading…")) info:nil identifier:@"chat.voice.sample"]; p.glyph = @"speaker"; p.tile = RCTileOrange;
        NSMutableArray *rows = [NSMutableArray arrayWithObject:p];
        if (OR6Chat6On(_core, @"voice.preview.stop")) [rows addObject:[self button:OR6L(@"Stop") info:@"stop" identifier:@"chat.voice.sample.stop"]];
        [sections addObject:[RCFormSection sectionWithTitle:OR6L(@"Sample") rows:rows]];
    }
    // Voice mode.
    NSMutableArray *modes = [NSMutableArray array]; BOOL modeWrite = !off && OR6Chat6On(_core, @"voice.modes.select");
    for (NSDictionary *m in _modes.result[@"items"]) {
        NSString *name = [m isKindOfClass:NSDictionary.class] ? OR6Chat6VoiceModeName(m[@"id"]) : nil; if (!name) continue;
        RCFormRow *r = [RCFormRow rowWithKind:RCFormRowCheck title:name]; r.checked = [m[@"current"] isEqual:@YES];
        r.enabled = modeWrite; r.userInfo = modeWrite ? @{@"mode": m[@"id"]} : nil; r.identifier = [@"chat.voice.mode." stringByAppendingString:m[@"id"]]; [modes addObject:r];
    }
    if (!modes.count && OR6Chat6VoiceModeName(s[@"mode"])) [modes addObject:[self value:OR6L(@"Voice mode") value:OR6Chat6VoiceModeName(s[@"mode"]) info:nil identifier:@"chat.voice.mode"]];
    else if (!modes.count) [self addStateOf:_modes to:modes empty:nil hasItems:NO identifier:@"chat.voice.modes"];
    if (modes.count) [sections addObject:[RCFormSection sectionWithTitle:OR6L(@"Voice mode") rows:modes]];
    // Language (its own list screen).
    NSString *lang = OR6Chat6VoiceLanguageName(s[@"language"], [NSLocale currentLocale]) ?: OR6L(@"Unknown");
    BOOL langs = OR6Chat6On(_core, @"voice.languages.list") && OR6Chat6Text(s[@"language"], nil);
    RCFormSection *l = [RCFormSection sectionWithTitle:nil rows:@[[self value:OR6L(@"Language") value:lang info:(langs ? @"language" : nil) identifier:@"chat.voice.language"]]];
    l.footer = OR6L(@"ChatGPT X has no voice conversations. These settings are saved to your ChatGPT account and apply in other ChatGPT apps.");
    [sections addObject:l];
    self.sections = sections;
}
- (void)play:(NSDictionary *)v {
    NSDictionary *p = OR6Chat6VoicePreviewParameters(_catalog.result, v[@"id"]); if (!p) return;
    [self stopSample];
    [_sampleName release]; _sampleName = [OR6Chat6Text(v[@"name"], nil) copy];
    [_preview perform:@"voice.preview.start" parameters:p]; [self render];
}
- (void)useVoice:(NSDictionary *)v {
    RunSettingsWrite(HUDView(self), _core, @"voice.catalog.select", OR6Chat6VoiceSelectParameters(_catalog.result, v[@"id"]), @"voice.catalog.select:account",
                     @"configuration.operation.reconcile", OR6L(@"Voice saved."), ^(NSString *o, NSDictionary *r) { (void)o; (void)r; [self load]; });
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    id info = row.userInfo;
    if ([info isEqual:@"stop"]) { [self stopSample]; [self render]; return; }
    if ([info isEqual:@"language"]) {
        UIViewController *c = [[[OR6Chat6VoiceLanguageScreen alloc] initWithCore:_core current:[self settings][@"language"] changed:^{ _dirty = YES; }] autorelease];
        [self.navigationController pushViewController:c animated:YES]; return;
    }
    if ([info isKindOfClass:NSDictionary.class] && info[@"mode"]) {
        [self render]; NSDictionary *p = OR6Chat6VoiceModeParameters(info[@"mode"], [self settings]);
        if (row.checked || !p) return;
        RunSettingsWrite(HUDView(self), _core, @"voice.modes.select", p, @"voice.modes.select:account", @"configuration.operation.reconcile", OR6L(@"Voice mode saved."),
                         ^(NSString *o, NSDictionary *r) { (void)o; (void)r; [self load]; });
        return;
    }
    NSDictionary *v = [info isKindOfClass:NSDictionary.class] ? info[@"voice"] : nil;
    if (!v) { [super form:f didSelectRow:row]; return; }
    [self render];
    NSMutableArray *buttons = [NSMutableArray array], *actions = [NSMutableArray array];
    if (!row.checked && ![self voiceOff] && OR6Chat6On(_core, @"voice.catalog.select")) { [buttons addObject:OR6L(@"Use this voice")]; [actions addObject:@"use"]; }
    if ([v[@"previewAvailable"] isEqual:@YES] && OR6Chat6On(_core, @"voice.preview.start")) { [buttons addObject:OR6L(@"Play sample")]; [actions addObject:@"play"]; }
    if (!buttons.count) return;
    OR6Chat8ShowSheet(HUDView(self), row.title, buttons, nil, ^(NSInteger i, NSString *t) {
        (void)t; if (i < 0 || (NSUInteger)i >= actions.count) return;
        if ([actions[(NSUInteger)i] isEqual:@"use"]) [self useVoice:v]; else [self play:v];
    });
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopTimer]; [_catalog release]; [_modes release]; [_preview release]; [_status release]; [_catalogFor release]; [_playback release]; [_sampleName release];
    [super dealloc];
}
@end

#pragma mark - Voice session (transcript, voice limits)

@interface OR6Chat6VoiceSessionScreen : OR6Chat6Form { NSString *_session; OR6Chat7Call *_usage, *_set; }
- (id)initWithCore:(OR6APICore *)core session:(NSString *)session;
@end
@implementation OR6Chat6VoiceSessionScreen
- (id)initWithCore:(OR6APICore *)core session:(NSString *)session {
    if ((self = [super initWithCore:core navigator:nil title:OR6L(@"Voice conversation")])) { _session = [session copy]; _usage = [[self call] retain]; _set = [[self call] retain]; }
    return self;
}
- (void)viewDidLoad { [super viewDidLoad]; self.tableView.accessibilityIdentifier = @"chat.voice_session.table"; }
- (void)load {
    if (OR6Chat6On(_core, @"voice.transcript.get")) [_read perform:@"voice.transcript.get" parameters:@{@"sessionId": _session}];
    if (OR6Chat6On(_core, @"voice.usage.get")) [_usage perform:@"voice.usage.get" parameters:@{@"sessionId": _session}];
    [self render];
}
- (void)render {
    NSMutableArray *sections = [NSMutableArray array];
    NSDictionary *t = [_set.result isKindOfClass:NSDictionary.class] ? _set.result : [_read.result isKindOfClass:NSDictionary.class] ? _read.result : nil;
    if (OR6Chat6On(_core, @"voice.transcript.get")) {
        NSMutableArray *rows = [NSMutableArray array];
        if ([t[@"visible"] isKindOfClass:NSNumber.class]) {
            if (OR6Chat6On(_core, @"voice.transcript.set")) { RCFormRow *r = [RCFormRow rowWithKind:RCFormRowSwitch title:OR6L(@"Show transcript")]; r.on = [t[@"visible"] boolValue]; r.enabled = !_set.busy; r.identifier = @"chat.voice_session.transcript"; [rows addObject:r]; }
            else [rows addObject:[self value:OR6L(@"Show transcript") value:YesNo(t[@"visible"]) info:nil identifier:@"chat.voice_session.transcript"]];
        } else [self addStateOf:_read to:rows empty:nil hasItems:NO identifier:@"chat.voice_session.transcript"];
        if (_set.error) [rows addObject:[self note:OR6Chat7ErrorText(_set.error)]];
        RCFormSection *s = [RCFormSection sectionWithTitle:OR6L(@"Transcript") rows:rows];
        if ([t[@"uiShown"] isEqual:@NO]) s.footer = OR6L(@"ChatGPT X shows no live voice screen. The transcript appears where the voice conversation is shown.");
        [sections addObject:s];
    }
    if (OR6Chat6On(_core, @"voice.usage.get")) {
        NSDictionary *u = [_usage.result isKindOfClass:NSDictionary.class] ? _usage.result : nil; NSArray *notices = OR6Chat6VoiceNotices(u);
        BOOL canSwitch = OR6Chat6On(_core, @"voice.usage.useStandard");
        for (NSDictionary *n in notices) {
            NSMutableArray *rows = [NSMutableArray array];
            if ([n[@"text"] length]) [rows addObject:[self note:n[@"text"]]];
            if ([n[@"hint"] length]) [rows addObject:[self note:n[@"hint"]]];
            if (n[@"resetsAfter"]) [rows addObject:[self value:OR6L(@"Resets") value:(OR6Chat6RelativeDate(n[@"resetsAfter"]) ?: n[@"resetsAfter"]) info:nil identifier:@"chat.voice_session.resets"]];
            if ([n[@"switchToStandard"] isEqual:@YES] && canSwitch) [rows addObject:[self button:OR6L(@"Switch to standard voice") info:@{@"notice": n[@"id"]} identifier:@"chat.voice_session.standard"]];
            NSString *title = [n[@"title"] length] ? n[@"title"] : ([n[@"kind"] isEqual:@"exceeded"] ? OR6L(@"Voice limit reached") : OR6L(@"Voice limit"));
            [sections addObject:[RCFormSection sectionWithTitle:title rows:rows]];
        }
        if (!notices.count) {
            NSMutableArray *rows = [NSMutableArray array];
            if (![self addStateOf:_usage to:rows empty:nil hasItems:NO identifier:@"chat.voice_session.usage"] && u) [rows addObject:[self note:([u[@"observed"] isEqual:@YES] ? OR6L(@"No voice limit notices.") : OR6L(@"No voice limit information yet."))]];
            if (rows.count) [sections addObject:[RCFormSection sectionWithTitle:OR6L(@"Voice limits") rows:rows]];
        }
    }
    self.sections = sections;
}
- (void)form:(RCFormViewController *)f didToggleRow:(RCFormRow *)row {
    (void)f; BOOL on = row.on; [self render]; // the switch moves when the result arrives
    [_set perform:@"voice.transcript.set" parameters:@{@"sessionId": _session, @"visible": @(on)}]; [self render];
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    NSString *notice = [row.userInfo isKindOfClass:NSDictionary.class] ? row.userInfo[@"notice"] : nil;
    if (!notice) { [super form:f didSelectRow:row]; return; }
    OR6Chat6Confirm(HUDView(self), OR6L(@"Switch to standard voice? Your voice mode setting changes to Standard."), OR6L(@"Switch to standard voice"), NO, ^{
        RunSettingsWrite(HUDView(self), _core, @"voice.usage.useStandard", @{@"sessionId": _session, @"noticeId": notice}, [@"voice.usage.useStandard:" stringByAppendingString:_session],
                         @"configuration.operation.reconcile", OR6L(@"Switched to standard voice."), ^(NSString *o, NSDictionary *r) { (void)o; (void)r; [self load]; });
    });
}
- (void)dealloc { [_session release]; [_usage release]; [_set release]; [super dealloc]; }
@end

#pragma mark - Models (Auto preference, model and thinking effort)

@interface OR6Chat6ModelsScreen : OR6Chat6Form { OR6Chat7Call *_catalog; NSDictionary *_selection; }
@end
@implementation OR6Chat6ModelsScreen
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav title:(NSString *)title {
    if ((self = [super initWithCore:core navigator:nav title:title])) _catalog = [[self call] retain];
    return self;
}
- (void)viewDidLoad { [super viewDidLoad]; self.tableView.accessibilityIdentifier = @"chat.models.table"; }
- (void)load {
    if (OR6Chat6On(_core, @"modelControls.autoPreference.get")) [_read perform:@"modelControls.autoPreference.get" parameters:@{@"temporary": @NO}];
    if (OR6Chat6On(_core, @"modelControls.catalog")) [_catalog perform:@"modelControls.catalog" parameters:@{@"temporary": @NO}];
    [self render];
}
- (NSDictionary *)auto6 { return [_read.result isKindOfClass:NSDictionary.class] ? _read.result : nil; }
- (NSDictionary *)current { return _selection ?: ([[self auto6][@"selection"] isKindOfClass:NSDictionary.class] ? [self auto6][@"selection"] : nil); }
- (void)render {
    NSMutableArray *sections = [NSMutableArray array]; NSDictionary *a = [self auto6], *cat = [_catalog.result isKindOfClass:NSDictionary.class] ? _catalog.result : nil, *sel = [self current];
    if (OR6Chat6On(_core, @"modelControls.autoPreference.get")) {
        NSMutableArray *rows = [NSMutableArray array]; RCFormSection *s;
        if (a) {
            BOOL eligible = [a[@"eligible"] isEqual:@YES];
            if (eligible && OR6Chat6On(_core, @"modelControls.autoPreference.set")) { RCFormRow *r = [RCFormRow rowWithKind:RCFormRowSwitch title:OR6L(@"Prefer Auto")]; r.on = [a[@"prefersAuto"] isEqual:@YES]; r.identifier = @"chat.models.auto"; [rows addObject:r]; }
            else [rows addObject:[self value:OR6L(@"Prefer Auto") value:([a[@"prefersAuto"] isEqual:@YES] ? OR6L(@"On") : OR6L(@"Off")) info:nil identifier:@"chat.models.auto"]];
            NSString *now = OR6Chat6SelectionText(sel, cat); if (now) [rows addObject:[self value:OR6L(@"Next message") value:now info:nil identifier:@"chat.models.current"]];
            s = [RCFormSection sectionWithTitle:OR6L(@"Auto") rows:rows];
            s.footer = !eligible ? OR6L(@"Auto is not available for this account.") : [a[@"applied"] isEqual:@YES] ? OR6L(@"Auto picks a model for each message.") : OR6L(@"Auto is not in use for the next message.");
        } else { [self addStateOf:_read to:rows empty:nil hasItems:NO identifier:@"chat.models.auto"]; s = [RCFormSection sectionWithTitle:OR6L(@"Auto") rows:rows]; }
        [sections addObject:s];
    }
    if (OR6Chat6On(_core, @"modelControls.catalog")) {
        BOOL select = OR6Chat6On(_core, @"modelControls.select"); NSArray *families = OR6Chat6ModelFamilies(cat);
        for (NSDictionary *fam in families) {
            NSMutableArray *rows = [NSMutableArray array];
            for (NSDictionary *m in fam[@"versions"]) {
                RCFormRow *r = [RCFormRow rowWithKind:RCFormRowCheck title:OR6Chat6Text(m[@"title"], OR6Chat6LaneName(m[@"lane"]))];
                NSMutableArray *efforts = [NSMutableArray array]; for (NSDictionary *e in m[@"efforts"]) if ([e isKindOfClass:NSDictionary.class] && OR6Chat6Text(e[@"title"], nil)) [efforts addObject:e[@"title"]];
                NSString *lane = OR6Chat6LaneName(m[@"lane"]);
                r.subtitle = efforts.count ? [NSString stringWithFormat:@"%@ · %@", lane, [efforts componentsJoinedByString:@", "]] : lane;
                r.checked = [m[@"id"] isEqual:sel[@"modelId"]] && [m[@"lane"] isEqual:sel[@"lane"]];
                r.enabled = select; r.userInfo = select ? @{@"model": m} : nil; r.identifier = @"chat.models.version"; [rows addObject:r];
            }
            [sections addObject:[RCFormSection sectionWithTitle:fam[@"title"] rows:rows]];
        }
        NSMutableArray *state = [NSMutableArray array];
        [self addStateOf:_catalog to:state empty:OR6L(@"The service returned no models.") hasItems:families.count > 0 identifier:@"chat.models.catalog"];
        RCFormSection *last = [RCFormSection sectionWithTitle:nil rows:state];
        last.footer = OR6L(@"The model menu in a chat (tap the title) also chooses the model for the next message.");
        [sections addObject:last];
    }
    self.sections = sections;
}
- (void)choose:(NSDictionary *)m effort:(id)effort {
    NSDictionary *p = OR6Chat6ModelSelectParameters(m, effort); if (!p) return;
    RunSettingsWrite(HUDView(self), _core, @"modelControls.select", p, @"modelControls.select:selection", @"configuration.operation.reconcile", OR6L(@"Model selected."), ^(NSString *o, NSDictionary *r) {
        if ([o isEqual:@"confirmed"] && OR6Chat6Text(r[@"modelId"], nil)) {
            [_selection release]; _selection = [r copy];
            // The chats send with the shared catalog: the same model + effort for the next ordinary Send.
            if (!OR6Chat6ApplySelection(OR6Chat6ChatCatalog(), r)) OR6Chat6Say(HUDView(self), OR6L(@"Choose this model in the chat's model menu to use it there."));
        }
        [self load];
    });
}
- (void)form:(RCFormViewController *)f didToggleRow:(RCFormRow *)row {
    (void)f; BOOL on = row.on; [self render]; // the switch follows the confirmed preference
    RunSettingsWrite(HUDView(self), _core, @"modelControls.autoPreference.set", OR6Chat6AutoPreferenceParameters(on), @"modelControls.autoPreference.set:auto",
                     @"configuration.operation.reconcile", OR6L(@"Saved."), ^(NSString *o, NSDictionary *r) { (void)o; (void)r; [[OR6Chat6AutoPreference forCore:_core] invalidate]; [_selection release]; _selection = nil; [self load]; });
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    NSDictionary *m = [row.userInfo isKindOfClass:NSDictionary.class] ? row.userInfo[@"model"] : nil;
    if (!m) { [super form:f didSelectRow:row]; return; }
    [self render];
    NSMutableArray *titles = [NSMutableArray array], *ids = [NSMutableArray array];
    for (NSDictionary *e in m[@"efforts"]) {
        if (![e isKindOfClass:NSDictionary.class] || !OR6Chat6Text(e[@"id"], nil)) continue;
        NSString *t = OR6Chat6Text(e[@"title"], e[@"id"]);
        [titles addObject:([e[@"id"] isEqual:m[@"defaultEffort"]] ? [NSString stringWithFormat:OR6L(@"%@ (default)"), t] : t)]; [ids addObject:e[@"id"]];
    }
    if (!ids.count) { [self choose:m effort:nil]; return; }
    OR6Chat8ShowSheet(HUDView(self), OR6L(@"Thinking effort"), titles, nil, ^(NSInteger i, NSString *t) {
        (void)t; if (i >= 0 && (NSUInteger)i < ids.count) [self choose:m effort:ids[(NSUInteger)i]];
    });
}
- (void)dealloc { [_catalog release]; [_selection release]; [super dealloc]; }
@end

#pragma mark - Entries

NSArray *OR6Chat6SettingsRows(OR6APICore *core) {
    NSMutableArray *e = [NSMutableArray array];
    if (OR6Chat6On(core, @"connectors.catalog") || OR6Chat6On(core, @"connectors.installed")) [e addObject:@{@"key": @"apps", @"title": OR6L(@"Apps"), @"glyph": @"apps", @"tile": @(RCTilePurple)}];
    if (OR6Chat6On(core, @"voice.settings.get")) [e addObject:@{@"key": @"voice", @"title": OR6L(@"Voice"), @"glyph": @"voice", @"tile": @(RCTileOrange)}];
    if (OR6Chat6On(core, @"modelControls.autoPreference.get") || OR6Chat6On(core, @"modelControls.catalog")) [e addObject:@{@"key": @"models", @"title": OR6L(@"Models"), @"glyph": @"brain", @"tile": @(RCTileBlue)}];
    return e;
}
NSArray *OR6Chat6SettingsPrivacyEntries(OR6APICore *core) {
    if (!OR6Chat6On(core, @"connectors.permissions.default.get")) return @[];
    return @[@{@"key": @"apps_permissions", @"title": OR6L(@"App permissions"), @"identifier": @"chat.privacy.apps_permissions"}];
}
UIViewController *OR6Chat6CreateSettings(OR6APICore *core, NSString *key) {
    if ([key isEqual:@"apps"] && (OR6Chat6On(core, @"connectors.catalog") || OR6Chat6On(core, @"connectors.installed")))
        return [[[OR6Chat6AppsScreen alloc] initWithCore:core navigator:nil title:OR6L(@"Apps")] autorelease];
    if ([key isEqual:@"voice"] && OR6Chat6On(core, @"voice.settings.get")) return [[[OR6Chat6VoiceScreen alloc] initWithCore:core navigator:nil title:OR6L(@"Voice")] autorelease];
    if ([key isEqual:@"models"] && (OR6Chat6On(core, @"modelControls.autoPreference.get") || OR6Chat6On(core, @"modelControls.catalog")))
        return [[[OR6Chat6ModelsScreen alloc] initWithCore:core navigator:nil title:OR6L(@"Models")] autorelease];
    if ([key isEqual:@"apps_permissions"] && OR6Chat6On(core, @"connectors.permissions.default.get"))
        return [[[OR6Chat6PermissionScreen alloc] initWithCore:core linkId:nil title:OR6L(@"App permissions")] autorelease];
    return nil;
}
UIViewController *OR6Chat6CreateConnectorSettings(OR6APICore *core, NSString *connectorId) {
    if (![connectorId isKindOfClass:NSString.class] || !connectorId.length || connectorId.length > 256 || !OR6Chat6On(core, @"connectors.settings.get")) return nil;
    return [[[OR6Chat6ConnectorScreen alloc] initWithCore:core connectorId:connectorId] autorelease];
}
UIViewController *OR6Chat6CreateVoiceSession(OR6APICore *core, NSString *conversationId) {
    id<OR6Chat6TrustedHost> host = OR6Chat6TrustedHostNow();
    if (!(OR6Chat6On(core, @"voice.transcript.get") || OR6Chat6On(core, @"voice.usage.get")) || ![host respondsToSelector:@selector(chat6VoiceSessionIdForConversation:)]) return nil;
    NSString *session = [host chat6VoiceSessionIdForConversation:conversationId];
    if (![session isKindOfClass:NSString.class] || !session.length || session.length > 36) return nil;
    return [[[OR6Chat6VoiceSessionScreen alloc] initWithCore:core session:session] autorelease];
}

#pragma mark - Sign-in handoffs (API6E; work while signed out)

NSArray *OR6Chat6SignInHandoffs(OR6APICore *core) {
    NSMutableArray *e = [NSMutableArray array];
    for (NSDictionary *h in OR6Chat6SignInHandoffCandidates()) if (OR6Chat6On(core, h[@"operation"])) [e addObject:h];
    return e;
}
void OR6Chat6OpenSignInHandoff(UIView *view, OR6APICore *core, NSString *op) {
    if (!view || !OR6Chat6On(core, op)) return;
    UIView *hud = view.window ?: view;
    [core perform:op parameters:@{} event:nil completion:^(NSDictionary *r, NSError *e) {
        NSURL *u = e ? nil : OR6Chat6SignInHandoffURL(r);
        if (!u) { OR6Chat6Say(hud, e ? OR6Chat7ErrorText(e) : OR6L(@"This page cannot be opened.")); return; }
        // The user chose this page: Safari owns every code and password; nothing is done in ChatGPT X.
        OR6Chat6Say(hud, [UIApplication.sharedApplication openURL:u] ? OR6L(@"Continue in Safari. Then come back and sign in here.") : OR6L(@"This page cannot be opened."));
    }];
}
void OR6Chat6ChooseSignInHandoff(UIView *view, OR6APICore *core) {
    NSArray *pages = OR6Chat6SignInHandoffs(core); if (!view || !pages.count) return;
    NSMutableArray *titles = [NSMutableArray array]; for (NSDictionary *h in pages) [titles addObject:h[@"title"]];
    OR6Chat8ShowSheet(view, OR6L(@"These steps happen on the ChatGPT website in Safari. ChatGPT X does not see your codes or password."), titles, nil, ^(NSInteger i, NSString *t) {
        (void)t; if (i >= 0 && (NSUInteger)i < pages.count) OR6Chat6OpenSignInHandoff(view, core, pages[(NSUInteger)i][@"operation"]);
    });
}
