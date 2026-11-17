// «Аккаунт» screens of API 7/10 on RCFormViewController. Reads run only when the user
// opens a screen or taps «Обновить»; candidate (unverified) results carry a note; writes
// are offered only for live_verified operations, and memory/training writes additionally
// need a trusted policy that this build does not have (see OR6API7AllComposition.h).
#import "OR6Chat7Screens.h"
#import "../priority6/OR6Chat6Screens.h"
#import "../../localization/OR6Localization.h"
#import "../../chat/OR6ChatUIState.h"
#import "../../chat/OR6ChatScreens.h"
#import "RCFormViewController.h"
#import "RCChecklistViewController.h"
#import "RCTheme.h"
#import "RCHUD.h"

NSString *OR6Chat7WriteClosedNote(void) { return OR6L(@"You can change this in the web version."); }
BOOL OR6Chat7Retryable(NSError *e) { return e && !OR6Chat8StopSignal(e.userInfo[@"code"]); } // no new attempt after a service stop signal
static NSString *PolicyClosedNote(void) { return OR6L(@"Shown for reference. You can change this in the web version."); }
static NSString *OnOff(id v) { return [v isEqual:@YES] ? OR6L(@"On") : [v isEqual:@NO] ? OR6L(@"Off") : OR6L(@"Unknown"); }

#pragma mark - Handoff

static BOOL HandoffURL(NSURL *u) {
    NSString *h = u.host.lowercaseString;
    return [u.scheme.lowercaseString isEqual:@"https"] && !u.user && !u.password && !u.port && [@[@"chatgpt.com", @"auth.openai.com", @"openai.com", @"privacy.openai.com", @"help.openai.com"] containsObject:h ?: @""];
}
void OR6Chat7OpenHandoff(UIViewController *host, OR6APICore *core, NSString *op) {
    if (!OR6Chat7On(core, op)) return;
    UIView *hud = host.view.window ?: host.view;
    [core perform:op parameters:@{} event:nil completion:^(NSDictionary *r, NSError *e) {
        NSURL *u = [r[@"url"] isKindOfClass:NSString.class] ? [NSURL URLWithString:r[@"url"]] : nil;
        if (e || !u || !HandoffURL(u) || ![r[@"completed"] isEqual:@NO]) { [RCHUD showText:e ? OR6Chat7ErrorText(e) : OR6L(@"This page cannot be opened.") kind:RCHUDTextOnly inView:hud seconds:2]; return; }
        // The user tapped this Safari row: open it. The step finishes on the web page; the app shows nothing as done.
        if ([UIApplication.sharedApplication openURL:u]) [RCHUD showText:OR6L(@"Continue in Safari.") kind:RCHUDTextOnly inView:hud seconds:1.2];
    }];
}

#pragma mark - Base form

@interface OR6Chat7Form : RCFormViewController <RCFormDelegate, OR6Chat8ModelDelegate> {
@protected OR6APICore *_core; OR6Chat7Call *_read; OR6Chat7Write *_write; BOOL _loaded;
}
- (id)initWithCore:(OR6APICore *)core title:(NSString *)title;
- (void)load;
- (void)render;
- (void)written; // a write finished (done/failed/uncertain): default reloads after done
@end
@implementation OR6Chat7Form
- (id)initWithCore:(OR6APICore *)core title:(NSString *)title {
    if ((self = [super init])) { _core = [core retain]; self.title = title; self.delegate = self; _read = [[OR6Chat7Call alloc] initWithCore:core]; _read.delegate = self; }
    return self;
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; if (!_loaded) { _loaded = YES; [self load]; } [self render]; }
- (void)load {}
- (void)render {}
- (void)written { if ([_write.phase isEqual:@"done"]) [self load]; }
- (void)chat8ModelChanged:(id)model {
    self.busy = _read.busy || [_write.phase isEqual:@"running"] || [_write.phase isEqual:@"reconciling"];
    if (model == _write && ![_write.phase isEqual:@"running"] && ![_write.phase isEqual:@"reconciling"]) [self written];
    [self render];
}
- (RCFormRow *)row:(RCFormRowKind)k title:(NSString *)t value:(NSString *)v identifier:(NSString *)i { RCFormRow *r = [RCFormRow rowWithKind:k title:t]; r.value = v; r.identifier = i; return r; }
- (RCFormRow *)note:(NSString *)t { RCFormRow *r = [RCFormRow rowWithKind:RCFormRowNote title:t]; return r; }
- (RCFormRow *)button:(NSString *)t identifier:(NSString *)i info:(id)info { RCFormRow *r = [RCFormRow rowWithKind:RCFormRowButton title:t]; r.identifier = i; r.userInfo = info; return r; }
- (RCFormRow *)handoff:(NSString *)t op:(NSString *)op identifier:(NSString *)i { RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:t]; r.disclosure = YES; r.value = OR6L(@"Safari"); r.userInfo = @{@"handoff": op}; r.identifier = i; return r; }
// Error/empty state of the screen's read with an explicit new attempt (a read; nothing is written).
- (RCFormSection *)issueSection {
    if (_read.busy || !_read.error) return nil;
    NSArray *rows = OR6Chat7Retryable(_read.error) ? @[[self note:OR6Chat7ErrorText(_read.error)], [self button:OR6L(@"Read again") identifier:@"chat.api7.reload" info:@"reload"]] : @[[self note:OR6Chat7ErrorText(_read.error)]];
    RCFormSection *s = [RCFormSection sectionWithTitle:nil rows:rows];
    return s;
}
// Write status: running / done (verified or only acknowledged) / failed / uncertain with «Проверить».
- (RCFormSection *)writeSection {
    NSString *p = _write.phase; if (!p || [p isEqual:@"idle"]) return nil;
    NSMutableArray *rows = [NSMutableArray array];
    if ([p isEqual:@"done"]) [rows addObject:[self note:_write.verified ? OR6L(@"The change was saved and read back from the service.") : OR6L(@"The service accepted the change, but it was not read back yet.")]];
    else if ([p isEqual:@"failed"] || [p isEqual:@"blocked"]) [rows addObject:[self note:OR6Chat7ErrorText(_write.error)]];
    else if ([p isEqual:@"uncertain"]) [rows addObject:[self note:OR6L(@"The result of the change is unknown. It is not sent again; check the current state.")]];
    else [rows addObject:[self note:OR6L(@"Saving…")]];
    if (([p isEqual:@"uncertain"] || ([p isEqual:@"done"] && !_write.verified))) [rows addObject:[self button:OR6L(@"Check") identifier:@"chat.api7.reconcile" info:@"reconcile"]];
    return [RCFormSection sectionWithTitle:nil rows:rows];
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    (void)f; id info = row.userInfo;
    if ([info isEqual:@"reload"]) { if (!_read.error || OR6Chat7Retryable(_read.error)) [self load]; return; }
    if ([info isEqual:@"reconcile"]) { [_write reconcile]; return; }
    if ([info isKindOfClass:NSDictionary.class] && info[@"handoff"]) { OR6Chat7OpenHandoff(self, _core, info[@"handoff"]); return; }
    if ([info isKindOfClass:NSDictionary.class] && info[@"stage6"]) { UIViewController *c = OR6Chat6CreateAccountScreen(_core, info[@"stage6"]); if (c) [self.navigationController pushViewController:c animated:YES]; return; }
    [self selected:row];
}
- (void)selected:(RCFormRow *)row { (void)row; }
- (void)form:(RCFormViewController *)f didToggleRow:(RCFormRow *)row { (void)f; (void)row; [self render]; }
- (void)form:(RCFormViewController *)f didChangeTextOfRow:(RCFormRow *)row { (void)f; (void)row; }
- (void)dealloc { _read.delegate = nil; _write.delegate = nil; [_read cancel]; [_read release]; [_write release]; [_core release]; [super dealloc]; }
@end

#pragma mark - Personalization (personalization.get, personalities.list, traits.list; updates)

@class OR6Chat7PersonalizationScreen;
@interface OR6Chat7CatalogScreen : OR6Chat7Form
- (id)initWithCore:(OR6APICore *)core kind:(NSString *)kind state:(NSDictionary *)state owner:(OR6Chat7PersonalizationScreen *)owner;
@end
@interface OR6Chat7PersonalizationScreen : OR6Chat7Form { NSMutableDictionary *_edits; NSString *_pending; }
@end
@implementation OR6Chat7PersonalizationScreen
- (void)load { [_edits release]; _edits = [NSMutableDictionary new]; [_read perform:@"personalization.get" parameters:@{}]; }
- (NSDictionary *)state { return [_read.operation isEqual:@"personalization.get"] ? _read.result : nil; }
- (BOOL)can:(NSString *)op { return OR6Chat7On(_core, op) && [self state][@"revision"]; }
- (NSString *)text:(NSString *)key { id v = _edits[key] ?: [self state][key]; return [v isKindOfClass:NSString.class] ? v : nil; }
- (RCFormRow *)field:(NSString *)key title:(NSString *)t editable:(BOOL)e long:(BOOL)l {
    NSString *v = [self text:key];
    if (!e) { RCFormRow *r = [RCFormRow rowWithKind:RCFormRowNote title:t]; r.subtitle = v.length ? [NSString stringWithFormat:@"%@: %@", t, v] : [NSString stringWithFormat:@"%@: %@", t, ([self state][key] == NSNull.null ? OR6L(@"Unknown") : OR6L(@"Not set"))]; return r; }
    RCFormRow *r = [RCFormRow rowWithKind:(l ? RCFormRowLongText : RCFormRowText) title:t]; r.text = v; r.placeholder = t; r.maxLength = 1500; r.userInfo = key; r.identifier = [@"chat.personalization." stringByAppendingString:key];
    return r;
}
- (void)render {
    NSDictionary *s = [self state]; NSMutableArray *sections = [NSMutableArray array];
    RCFormSection *issue = [self issueSection]; if (issue) [sections addObject:issue];
    if (s) {
        BOOL ins = [self can:@"instructions.update"], pro = [self can:@"profile.update"];
        RCFormRow *on = [RCFormRow rowWithKind:(ins ? RCFormRowSwitch : RCFormRowValue) title:OR6L(@"Use personalization")]; on.on = [(_edits[@"enabled"] ?: s[@"enabled"]) isEqual:@YES]; on.value = OnOff(s[@"enabled"]); on.userInfo = @"enabled"; on.identifier = @"chat.personalization.enabled";
        NSMutableArray *a = [NSMutableArray arrayWithObjects:on, [self field:@"instructions" title:OR6L(@"Custom instructions") editable:ins long:YES], nil];
        if (ins) [a addObject:[self button:OR6L(@"Save instructions") identifier:@"chat.personalization.save_instructions" info:@"save-instructions"]];
        RCFormSection *i = [RCFormSection sectionWithTitle:OR6L(@"Instructions") rows:a]; i.footer = ins ? OR6L(@"Up to 1,500 characters. The service may have its own limits.") : nil; [sections addObject:i];
        NSMutableArray *b = [NSMutableArray arrayWithObjects:[self field:@"nickname" title:OR6L(@"What should ChatGPT call you?") editable:pro long:NO], [self field:@"occupation" title:OR6L(@"Occupation") editable:pro long:NO], [self field:@"about" title:OR6L(@"More about you") editable:pro long:YES], nil];
        if (pro) [b addObject:[self button:OR6L(@"Save profile") identifier:@"chat.personalization.save_profile" info:@"save-profile"]];
        [sections addObject:[RCFormSection sectionWithTitle:OR6L(@"About you") rows:b]];
        RCFormRow *style = [self row:RCFormRowValue title:OR6L(@"Base style and tone") value:([s[@"personality"] isKindOfClass:NSString.class] && [s[@"personality"] length] ? s[@"personality"] : OR6L(@"Default")) identifier:@"chat.personalization.personality"];
        style.disclosure = OR6Chat7On(_core, @"personalities.list"); style.userInfo = @"personality";
        RCFormRow *traits = [self row:RCFormRowValue title:OR6L(@"Characteristics") value:[NSString stringWithFormat:@"%lu", (unsigned long)([s[@"traits"] isKindOfClass:NSArray.class] ? [s[@"traits"] count] : 0)] identifier:@"chat.personalization.traits"];
        traits.disclosure = OR6Chat7On(_core, @"traits.list"); traits.userInfo = @"traits";
        RCFormSection *st = [RCFormSection sectionWithTitle:OR6L(@"Style") rows:@[style, traits]]; [sections addObject:st];
        RCFormSection *w = [self writeSection]; if (w) [sections addObject:w];
        RCFormSection *note = [RCFormSection sectionWithTitle:nil rows:@[]]; note.footer = (ins && pro) ? nil : OR6Chat7WriteClosedNote(); [sections addObject:note];
    }
    self.sections = sections;
}
- (void)form:(RCFormViewController *)f didToggleRow:(RCFormRow *)row { (void)f; if ([row.userInfo isEqual:@"enabled"]) _edits[@"enabled"] = @(row.on); }
- (void)form:(RCFormViewController *)f didChangeTextOfRow:(RCFormRow *)row { (void)f; if ([row.userInfo isKindOfClass:NSString.class]) _edits[row.userInfo] = row.text ?: @""; }
- (void)writeOp:(NSString *)op params:(NSDictionary *)p {
    if (!_write) { _write = [[OR6Chat7Write alloc] initWithCore:_core reconcile:@"settings.reconcile"]; _write.delegate = self; }
    [self endEditing];
    if (![_write perform:op parameters:p intent:[@"personalization:" stringByAppendingString:op]]) [RCHUD showText:OR6L(@"This change cannot be sent now.") kind:RCHUDTextOnly inView:self.view.window seconds:1.6];
}
- (void)selected:(RCFormRow *)row {
    NSDictionary *s = [self state]; NSString *rev = s[@"revision"]; if (!rev) return;
    if ([row.userInfo isEqual:@"save-instructions"]) {
        NSMutableDictionary *c = [NSMutableDictionary dictionary]; if (_edits[@"enabled"]) c[@"enabled"] = _edits[@"enabled"]; if (_edits[@"instructions"]) c[@"text"] = _edits[@"instructions"];
        if (c.count) [self writeOp:@"instructions.update" params:@{@"expectedRevision": rev, @"changes": c}];
    } else if ([row.userInfo isEqual:@"save-profile"]) {
        NSMutableDictionary *c = [NSMutableDictionary dictionary]; for (NSString *k in @[@"nickname", @"occupation", @"about"]) if (_edits[k]) c[k] = _edits[k];
        if (c.count) [self writeOp:@"profile.update" params:@{@"expectedRevision": rev, @"changes": c}];
    } else if ([row.userInfo isEqual:@"personality"] || [row.userInfo isEqual:@"traits"]) {
        [self.navigationController pushViewController:[[[OR6Chat7CatalogScreen alloc] initWithCore:_core kind:row.userInfo state:s owner:self] autorelease] animated:YES];
    }
}
- (void)dealloc { [_edits release]; [_pending release]; [super dealloc]; }
@end

// personalities.list / traits.list: the server catalogue; a choice is sent only when the
// update operation is live_verified (otherwise the list is shown read-only).
@interface OR6Chat7CatalogScreen () { NSString *_kind; NSDictionary *_state; OR6Chat7PersonalizationScreen *_owner; }
@end
@implementation OR6Chat7CatalogScreen
- (id)initWithCore:(OR6APICore *)core kind:(NSString *)kind state:(NSDictionary *)state owner:(OR6Chat7PersonalizationScreen *)owner {
    if ((self = [super initWithCore:core title:([kind isEqual:@"traits"] ? OR6L(@"Characteristics") : OR6L(@"Base style and tone"))])) { _kind = [kind copy]; _state = [state copy]; _owner = owner; }
    return self;
}
- (BOOL)traits { return [_kind isEqual:@"traits"]; }
- (void)load { [_read perform:([self traits] ? @"traits.list" : @"personalities.list") parameters:@{}]; }
- (BOOL)editable { return OR6Chat7On(_core, [self traits] ? @"traits.update" : @"personality.update") && _state[@"revision"]; }
- (NSString *)levelOf:(NSString *)key { for (NSDictionary *t in ([_state[@"traits"] isKindOfClass:NSArray.class] ? _state[@"traits"] : @[])) if ([t[@"key"] isEqual:key]) return t[@"level"]; return @"default"; }
- (void)render {
    NSMutableArray *sections = [NSMutableArray array]; RCFormSection *issue = [self issueSection]; if (issue) [sections addObject:issue];
    NSArray *items = [_read.result[@"items"] isKindOfClass:NSArray.class] ? _read.result[@"items"] : nil; BOOL edit = [self editable];
    if ([self traits]) {
        for (NSDictionary *t in items) { NSMutableArray *rows = [NSMutableArray array];
            for (NSDictionary *l in t[@"levels"]) { RCFormRow *r = [RCFormRow rowWithKind:RCFormRowCheck title:l[@"label"]]; r.subtitle = [l[@"description"] length] ? l[@"description"] : nil; r.checked = [[self levelOf:t[@"key"]] isEqual:l[@"key"]]; r.enabled = edit; r.userInfo = @{@"key": t[@"key"], @"level": l[@"key"]}; [rows addObject:r]; }
            [sections addObject:[RCFormSection sectionWithTitle:t[@"label"] rows:rows]]; }
    } else if (items) {
        NSMutableArray *rows = [NSMutableArray array];
        for (NSDictionary *p in items) { RCFormRow *r = [RCFormRow rowWithKind:RCFormRowCheck title:p[@"label"]]; r.subtitle = [p[@"description"] length] ? p[@"description"] : nil; r.checked = [_state[@"personality"] isEqual:p[@"key"]]; r.enabled = edit; r.userInfo = @{@"key": p[@"key"]}; [rows addObject:r]; }
        [sections addObject:[RCFormSection sectionWithTitle:nil rows:rows]];
    }
    RCFormSection *w = [self writeSection]; if (w) [sections addObject:w];
    RCFormSection *n = [RCFormSection sectionWithTitle:nil rows:@[]]; n.footer = edit ? nil : OR6Chat7WriteClosedNote(); [sections addObject:n];
    self.sections = sections;
}
- (void)selected:(RCFormRow *)row {
    NSDictionary *i = row.userInfo; if (![i isKindOfClass:NSDictionary.class] || ![self editable]) return;
    if (!_write) { _write = [[OR6Chat7Write alloc] initWithCore:_core reconcile:@"settings.reconcile"]; _write.delegate = self; }
    if ([self traits]) [_write perform:@"traits.update" parameters:@{@"expectedRevision": _state[@"revision"], @"changes": @[@{@"key": i[@"key"], @"level": i[@"level"]}]} intent:[@"traits:" stringByAppendingString:i[@"key"]]];
    else [_write perform:@"personality.update" parameters:@{@"expectedRevision": _state[@"revision"], @"key": i[@"key"]} intent:@"personality"];
}
- (void)written { if ([_write.phase isEqual:@"done"]) { [_owner load]; [self.navigationController popViewControllerAnimated:YES]; } }
- (void)dealloc { [_kind release]; [_state release]; [super dealloc]; }
@end

#pragma mark - Memory (memory.get; writes closed: no trusted eligibility policy)

static NSSet *gPolicies;
@interface OR6Chat7MemoryScreen : OR6Chat7Form
@end
@implementation OR6Chat7MemoryScreen
- (void)load { [_read perform:@"memory.get" parameters:@{}]; }
- (RCFormRow *)value:(NSString *)t key:(NSString *)k locked:(NSString *)l state:(NSDictionary *)s {
    NSString *v = OnOff(s[k]); if ([s[l] isEqual:@YES]) v = [NSString stringWithFormat:OR6L(@"%@ · locked"), v];
    return [self row:RCFormRowValue title:t value:v identifier:[@"chat.memory." stringByAppendingString:k]];
}
- (void)render {
    NSDictionary *s = _read.result; NSMutableArray *sections = [NSMutableArray array]; RCFormSection *issue = [self issueSection]; if (issue) [sections addObject:issue];
    if (s) {
        NSString *mode = s[@"mode"]; NSMutableArray *rows = [NSMutableArray arrayWithObject:[self value:OR6L(@"Saved memory") key:@"enabled" locked:@"enabledLocked" state:s]];
        if ([mode isEqual:@"legacy"]) [rows addObject:[self value:OR6L(@"Reference chat history") key:@"history" locked:@"historyLocked" state:s]];
        [rows addObject:[self value:OR6L(@"Memory in search") key:@"search" locked:@"searchLocked" state:s]];
        RCFormSection *m = [RCFormSection sectionWithTitle:OR6L(@"Memory") rows:rows];
        m.footer = [mode isEqual:@"unavailable"] ? OR6L(@"The service reports no memory settings for this account.") : nil;
        [sections addObject:m];
        // Stage 6: the saved memories themselves (memories.list), prototype «Сохранённые воспоминания».
        NSMutableArray *six = [NSMutableArray array]; // stage 6 (API6D): saved memories and their management, granted reads only
        for (NSDictionary *e in OR6Chat6MemoryEntries(_core)) { RCFormRow *r = [self row:RCFormRowValue title:e[@"title"] value:e[@"value"] identifier:e[@"identifier"]]; r.disclosure = YES; r.enabled = YES; r.userInfo = @{@"stage6": e[@"key"]}; [six addObject:r]; }
        if (six.count) [sections addObject:[RCFormSection sectionWithTitle:nil rows:six]];
        RCFormSection *n = [RCFormSection sectionWithTitle:nil rows:@[]];
        BOOL write = [gPolicies containsObject:@"memory"] && OR6Chat7On(_core, @"memory.setEnabled");
        n.footer = write ? nil : PolicyClosedNote();
        [sections addObject:n];
    }
    self.sections = sections;
}
@end

#pragma mark - Privacy center (privacy.center or privacy.get + safety.ageStatus; handoffs)

@interface OR6Chat7PrivacyScreen : OR6Chat7Form { OR6Chat7Call *_age; }
@end
@implementation OR6Chat7PrivacyScreen
- (void)load {
    if (OR6Chat7On(_core, @"privacy.center")) [_read perform:@"privacy.center" parameters:@{}];
    else { [_read perform:@"privacy.get" parameters:@{}]; [self loadAge]; }
}
- (void)loadAge { if (!_age) { _age = [[OR6Chat7Call alloc] initWithCore:_core]; _age.delegate = self; } [_age perform:@"safety.ageStatus" parameters:@{}]; }
- (NSDictionary *)settings { return [_read.operation isEqual:@"privacy.center"] ? _read.result[@"settings"] : _read.result; }
- (NSDictionary *)age { return _age.result ?: ([_read.operation isEqual:@"privacy.center"] ? _read.result[@"age"] : nil); }
- (RCFormRow *)value:(NSString *)t key:(NSString *)k s:(NSDictionary *)s {
    NSString *v = OnOff(s[k]); if ([s[[k stringByAppendingString:@"Locked"]] isEqual:@YES]) v = [NSString stringWithFormat:OR6L(@"%@ · locked"), v];
    return [self row:RCFormRowValue title:t value:v identifier:[@"chat.privacy." stringByAppendingString:k]];
}
- (void)render {
    NSMutableArray *sections = [NSMutableArray array]; RCFormSection *issue = [self issueSection]; if (issue) [sections addObject:issue];
    NSDictionary *s = [self settings];
    if (s) {
        RCFormSection *t = [RCFormSection sectionWithTitle:OR6L(@"Improve the model for everyone") rows:@[[self value:OR6L(@"Chats") key:@"trainingText" s:s], [self value:OR6L(@"Audio") key:@"trainingAudio" s:s], [self value:OR6L(@"Video") key:@"trainingVideo" s:s]]];
        t.footer = PolicyClosedNote(); [sections addObject:t];
        BOOL sens = OR6Chat7On(_core, @"safety.sensitiveContent.set") && s[@"revision"] && ![s[@"sensitiveContentLocked"] isEqual:@YES] && [s[@"sensitiveContent"] isKindOfClass:NSNumber.class];
        RCFormRow *r = [RCFormRow rowWithKind:(sens ? RCFormRowSwitch : RCFormRowValue) title:OR6L(@"Extra protection from sensitive content")]; r.on = [s[@"sensitiveContent"] isEqual:@YES]; r.value = OnOff(s[@"sensitiveContent"]); r.userInfo = @"sensitive"; r.identifier = @"chat.privacy.sensitive";
        RCFormSection *c = [RCFormSection sectionWithTitle:OR6L(@"Content") rows:@[r]]; c.footer = sens ? nil : OR6Chat7WriteClosedNote(); [sections addObject:c];
    }
    NSDictionary *a = [self age];
    if (a || OR6Chat7On(_core, @"safety.ageStatus")) {
        NSString *g = [a[@"ageGroup"] isEqual:@"adult"] ? OR6L(@"Adult") : [a[@"ageGroup"] isEqual:@"teen"] ? OR6L(@"Under 18") : a ? OR6L(@"Not determined") : (_age.busy ? OR6L(@"Checking…") : OR6L(@"Unknown"));
        NSMutableArray *rows = [NSMutableArray arrayWithObject:[self row:RCFormRowValue title:OR6L(@"Age group") value:g identifier:@"chat.privacy.age"]];
        if (a) [rows addObject:[self row:RCFormRowValue title:OR6L(@"Age or birth date verified") value:([a[@"hasVerifiedAgeOrDOB"] isEqual:@YES] ? OR6L(@"Yes") : OR6L(@"No")) identifier:@"chat.privacy.age_verified"]];
        if ([a[@"canVerifyAge"] isEqual:@YES] && OR6Chat7On(_core, @"safety.ageVerify")) [rows addObject:[self handoff:OR6L(@"Verify age") op:@"safety.ageVerify" identifier:@"chat.privacy.age_verify"]];
        if (OR6Chat7On(_core, @"safety.ageStatus")) [rows addObject:[self button:OR6L(@"Check age status again") identifier:@"chat.privacy.age_check" info:@"age"]];
        RCFormSection *x = [RCFormSection sectionWithTitle:OR6L(@"Age") rows:rows]; x.footer = _age.error ? OR6Chat7ErrorText(_age.error) : nil; [sections addObject:x];
    }
    NSMutableArray *links = [NSMutableArray array];
    if (OR6Chat7On(_core, @"privacy.openCenter")) [links addObject:[self handoff:OR6L(@"Privacy center") op:@"privacy.openCenter" identifier:@"chat.privacy.center"]];
    if (OR6Chat7On(_core, @"privacy.requestsHelp")) [links addObject:[self handoff:OR6L(@"Privacy Portal: data requests") op:@"privacy.requestsHelp" identifier:@"chat.privacy.requests"]];
    // Stage 6: account data controls read in the app (API6B/6D), before the Safari pages.
    NSMutableArray *data = [NSMutableArray array];
    for (NSDictionary *e in OR6Chat6PrivacyEntries(_core)) { RCFormRow *r = [self row:RCFormRowValue title:e[@"title"] value:e[@"value"] identifier:e[@"identifier"]]; r.disclosure = YES; r.enabled = YES; r.userInfo = @{@"stage6": e[@"key"]}; [data addObject:r]; }
    if (data.count) [sections addObject:[RCFormSection sectionWithTitle:OR6L(@"Data controls") rows:data]];
    if (links.count) { RCFormSection *l = [RCFormSection sectionWithTitle:OR6L(@"Your data") rows:links]; l.footer = OR6L(@"These pages open in Safari. Requests made there are not tracked in ChatGPT X."); [sections addObject:l]; }
    RCFormSection *w = [self writeSection]; if (w) [sections addObject:w];
    self.sections = sections;
}
- (void)form:(RCFormViewController *)f didToggleRow:(RCFormRow *)row {
    (void)f; NSDictionary *s = [self settings];
    if (![row.userInfo isEqual:@"sensitive"] || !s[@"revision"]) { [self render]; return; }
    if (!_write) { _write = [[OR6Chat7Write alloc] initWithCore:_core reconcile:@"privacy.reconcile"]; _write.delegate = self; }
    if (![_write perform:@"safety.sensitiveContent.set" parameters:@{@"expectedRevision": s[@"revision"], @"enabled": @(row.on)} intent:@"privacy:sensitive"]) [self render];
}
- (void)selected:(RCFormRow *)row { if ([row.userInfo isEqual:@"age"]) [self loadAge]; }
- (void)dealloc { _age.delegate = nil; [_age cancel]; [_age release]; [super dealloc]; }
@end

#pragma mark - Security (security.policy; browser handoffs)

@interface OR6Chat7SecurityScreen : OR6Chat7Form
@end
@implementation OR6Chat7SecurityScreen
- (void)load { if (OR6Chat7On(_core, @"security.policy")) [_read perform:@"security.policy" parameters:@{}]; }
- (void)render {
    NSMutableArray *sections = [NSMutableArray array]; RCFormSection *issue = [self issueSection]; if (issue) [sections addObject:issue];
    NSDictionary *p = _read.result; BOOL known = p != nil;
    if (known) [sections addObject:[RCFormSection sectionWithTitle:OR6L(@"Protection") rows:@[[self row:RCFormRowValue title:OR6L(@"Two-step verification") value:OnOff(p[@"mfaEnabled"]) identifier:@"chat.security.mfa"], [self row:RCFormRowValue title:OR6L(@"Advanced account security") value:OnOff(p[@"advancedSecurity"]) identifier:@"chat.security.advanced"]]]];
    NSMutableArray *rows = [NSMutableArray array];
    for (NSArray *e in @[@[OR6L(@"Confirm it is you"), @"security.reauthenticate", @"chat.security.reauth"], @[OR6L(@"Change password"), @"security.passwordChange", @"chat.security.password"], @[OR6L(@"Change e-mail"), @"security.emailChange", @"chat.security.email"]])
        if (OR6Chat7On(_core, e[1])) [rows addObject:[self handoff:e[0] op:e[1] identifier:e[2]]];
    // MFA management only when the read policy allows it (advanced security turns it off).
    BOOL mfa = OR6Chat7On(_core, @"security.mfaSetup") && known && [p[@"mfaManagementAllowed"] isEqual:@YES];
    if (mfa) [rows addObject:[self handoff:OR6L(@"Authenticator app") op:@"security.mfaSetup" identifier:@"chat.security.mfa_setup"]];
    else if (known && OR6Chat7On(_core, @"security.mfaSetup")) [rows addObject:[self note:OR6L(@"Two-step verification cannot be changed while advanced account security is on.")]];
    if (OR6Chat7On(_core, @"security.recovery")) [rows addObject:[self handoff:OR6L(@"Lost access to two-step verification") op:@"security.recovery" identifier:@"chat.security.recovery"]];
    if (rows.count) { RCFormSection *s = [RCFormSection sectionWithTitle:OR6L(@"On the service page") rows:rows]; s.footer = OR6L(@"Entered in Safari. ChatGPT X does not see them."); [sections addObject:s]; }
    self.sections = sections;
}
@end

#pragma mark - Plans (subscription.plans for the device region; subscription.openPlans)

@interface OR6Chat7PlansScreen : OR6Chat7Form { NSString *_country; }
@end
@implementation OR6Chat7PlansScreen
- (void)load {
    NSString *c = [[[NSLocale currentLocale] objectForKey:NSLocaleCountryCode] uppercaseString];
    [_country release]; _country = (c.length == 2 && [c rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ"] invertedSet]].location == NSNotFound) ? [c copy] : nil;
    if (_country) [_read perform:@"subscription.plans" parameters:@{@"countryCode": _country}];
}
- (NSString *)amount:(id)v currency:(NSString *)cur { return [v isKindOfClass:NSNumber.class] ? [NSString stringWithFormat:@"%@ %@", v, cur] : @"—"; }
- (void)render {
    NSMutableArray *sections = [NSMutableArray array]; RCFormSection *issue = [self issueSection]; if (issue) [sections addObject:issue];
    NSDictionary *r = _read.result;
    if (!_country) [sections addObject:[RCFormSection sectionWithTitle:nil rows:@[[self note:OR6L(@"Region is not set.")]]]];
    if (r) {
        NSMutableArray *rows = [NSMutableArray array];
        for (NSDictionary *i in r[@"items"]) { RCFormRow *row = [self row:RCFormRowValue title:[i[@"plan"] capitalizedString] value:[self amount:i[@"monthlyAmount"] currency:r[@"currencyCode"]] identifier:[@"chat.plans." stringByAppendingString:i[@"plan"]]];
            row.subtitle = [NSString stringWithFormat:OR6L(@"Month: %@ · year: %@"), [self amount:i[@"monthlyAmount"] currency:r[@"currencyCode"]], [self amount:i[@"yearlyAmount"] currency:r[@"currencyCode"]]]; [rows addObject:row]; }
        RCFormSection *s = [RCFormSection sectionWithTitle:[NSString stringWithFormat:OR6L(@"Catalogue for %@"), r[@"countryCode"]] rows:rows];
        s.footer = OR6L(@"Buying is on the web page."); [sections addObject:s];
    }
    if (OR6Chat7On(_core, @"subscription.openPlans")) [sections addObject:[RCFormSection sectionWithTitle:nil rows:@[[self handoff:OR6L(@"Compare plans in Safari") op:@"subscription.openPlans" identifier:@"chat.plans.open"]]]];
    self.sections = sections;
}
- (void)dealloc { [_country release]; [super dealloc]; }
@end

#pragma mark - Local preferences (clientPreferences.*, cache.*)

@interface OR6Chat7PreferencesScreen : OR6Chat7Form { NSString *_kind; }
- (id)initWithCore:(OR6APICore *)core kind:(NSString *)kind;
@end
@implementation OR6Chat7PreferencesScreen
- (id)initWithCore:(OR6APICore *)core kind:(NSString *)kind {
    NSString *t = [kind isEqual:@"language"] ? OR6L(@"App language") : [kind isEqual:@"storage"] ? OR6L(@"Storage") : OR6L(@"Appearance");
    if ((self = [super initWithCore:core title:t])) _kind = [kind copy];
    return self;
}
- (void)load { [_read perform:([_kind isEqual:@"storage"] ? @"cache.status" : @"clientPreferences.get") parameters:@{}]; }
- (RCFormRow *)check:(NSString *)t value:(NSString *)v current:(NSString *)cur { RCFormRow *r = [RCFormRow rowWithKind:RCFormRowCheck title:t]; r.checked = [cur isEqual:v]; r.userInfo = v; r.identifier = [NSString stringWithFormat:@"chat.%@.%@", _kind, v]; return r; }
- (void)render {
    NSMutableArray *sections = [NSMutableArray array]; RCFormSection *issue = [self issueSection]; if (issue) [sections addObject:issue];
    NSDictionary *r = _read.result;
    if ([_kind isEqual:@"storage"]) {
        if (r) { RCFormSection *s = [RCFormSection sectionWithTitle:OR6L(@"Temporary files") rows:@[[self row:RCFormRowValue title:OR6L(@"Size") value:OR6Chat8Bytes([r[@"bytes"] unsignedLongLongValue]) identifier:@"chat.storage.bytes"], [self row:RCFormRowValue title:OR6L(@"Files") value:[r[@"files"] description] identifier:@"chat.storage.files"]]];
            s.footer = OR6L(@"Chats, recordings and downloads stay."); [sections addObject:s];
            RCFormRow *b = [self button:OR6L(@"Clear temporary files") identifier:@"chat.storage.clear" info:@"clear"]; b.destructive = YES; b.enabled = [r[@"files"] unsignedIntegerValue] > 0;
            [sections addObject:[RCFormSection sectionWithTitle:nil rows:@[b]]]; }
    } else if (r) {
        BOOL lang = [_kind isEqual:@"language"];
        NSString *cur = lang ? r[@"language"] : r[@"theme"];
        // A stored "system" theme is light on iOS 6. The screen only offers light and dark.
        if (!lang && ![cur isEqual:@"dark"]) cur = @"light";
        NSArray *rows = lang ? @[[self check:OR6L(@"As on the iPhone") value:@"system" current:cur], [self check:OR6L(@"Language name: English") value:@"en" current:cur], [self check:OR6L(@"Language name: Russian") value:@"ru" current:cur]]
                             : @[[self check:OR6L(@"Light") value:@"light" current:cur], [self check:OR6L(@"Dark") value:@"dark" current:cur]];
        RCFormSection *s = [RCFormSection sectionWithTitle:nil rows:rows];
        if (lang) s.footer = OR6L(@"Applies after a restart. Chats are not translated.");
        [sections addObject:s];
    }
    self.sections = sections;
}
- (void)selected:(RCFormRow *)row {
    if ([row.userInfo isEqual:@"clear"]) {
        UIActionSheet *s = [[[UIActionSheet alloc] initWithTitle:OR6L(@"Remove ChatGPT X's temporary files from this iPhone?") delegate:(id<UIActionSheetDelegate>)self cancelButtonTitle:OR6L(@"Cancel") destructiveButtonTitle:OR6L(@"Clear") otherButtonTitles:nil] autorelease];
        [s showInView:self.view.window ?: self.view]; return;
    }
    if (![row.userInfo isKindOfClass:NSString.class]) return;
    BOOL lang = [_kind isEqual:@"language"]; NSString *v = row.userInfo;
    [_read perform:(lang ? @"clientPreferences.language" : @"clientPreferences.theme") parameters:@{(lang ? @"language" : @"theme"): v}];
}
- (void)actionSheet:(UIActionSheet *)s clickedButtonAtIndex:(NSInteger)i { if (i == s.destructiveButtonIndex) [_read perform:@"cache.clear" parameters:@{}]; }
// Apply what the local preference store returned (not the tapped value).
- (void)chat8ModelChanged:(id)model {
    NSDictionary *r = _read.result;
    if (model == _read && !_read.busy && !_read.error && r) {
        if ([_read.operation isEqual:@"clientPreferences.theme"]) OR6ChatSetAppearance([r[@"effectiveTheme"] isEqual:@"dark"]);
        if ([_read.operation isEqual:@"clientPreferences.language"]) {
            NSString *l = r[@"language"];
            if ([l isEqual:@"system"]) [NSUserDefaults.standardUserDefaults removeObjectForKey:@"AppleLanguages"]; // app domain only
            else if ([@[@"en", @"ru"] containsObject:l ?: @""]) [NSUserDefaults.standardUserDefaults setObject:@[l] forKey:@"AppleLanguages"];
            [RCHUD showText:OR6L(@"The language changes after a restart.") kind:RCHUDTextOnly inView:self.view.window seconds:1.6];
        }
        if ([_read.operation isEqual:@"cache.clear"]) [RCHUD showText:OR6L(@"Temporary files removed.") kind:RCHUDDone inView:self.view.window seconds:0];
    }
    [super chat8ModelChanged:model];
}
- (void)dealloc { [_kind release]; [super dealloc]; }
@end

#pragma mark - Entries

void OR6Chat7SetPolicies(NSSet *policies) { NSSet *p = [policies copy]; [gPolicies release]; gPolicies = p; }
NSArray *OR6Chat7AccountEntries(OR6APICore *core) {
    NSMutableArray *e = [NSMutableArray array];
    void (^add)(NSString *, NSString *, NSString *, RCTileColor, NSArray *) = ^(NSString *k, NSString *t, NSString *g, RCTileColor c, NSArray *ops) {
        for (NSString *op in ops) if (OR6Chat7On(core, op)) { [e addObject:@{@"key": k, @"title": t, @"glyph": g, @"tile": @(c)}]; return; }
    };
    add(@"personalization", OR6L(@"Personalization"), @"person", RCTilePurple, @[@"personalization.get"]);
    add(@"memory", OR6L(@"Memory"), @"brain", RCTilePink, @[@"memory.get"]);
    add(@"privacy", OR6L(@"Privacy"), @"shield", RCTileBlue, @[@"privacy.center", @"privacy.get", @"safety.ageStatus"]);
    add(@"security", OR6L(@"Security"), @"lock", RCTileGraphite, @[@"security.policy", @"security.reauthenticate", @"security.passwordChange"]);
    add(@"plans", OR6L(@"Plans"), @"star", RCTileOrange, @[@"subscription.plans", @"subscription.openPlans"]);
    add(@"appearance", OR6L(@"Appearance"), @"sun", RCTileOrange, @[@"clientPreferences.theme"]);
    add(@"language", OR6L(@"App language"), @"globe", RCTileTeal, @[@"clientPreferences.language"]);
    add(@"storage", OR6L(@"Storage"), @"folder", RCTileGray, @[@"cache.status"]);
    return e;
}
UIViewController *OR6Chat7CreateAccountScreen(OR6APICore *core, NSString *k) {
    if ([k isEqual:@"personalization"]) return [[[OR6Chat7PersonalizationScreen alloc] initWithCore:core title:OR6L(@"Personalization")] autorelease];
    if ([k isEqual:@"memory"]) return [[[OR6Chat7MemoryScreen alloc] initWithCore:core title:OR6L(@"Memory")] autorelease];
    if ([k isEqual:@"privacy"]) return [[[OR6Chat7PrivacyScreen alloc] initWithCore:core title:OR6L(@"Privacy")] autorelease];
    if ([k isEqual:@"security"]) return [[[OR6Chat7SecurityScreen alloc] initWithCore:core title:OR6L(@"Security")] autorelease];
    if ([k isEqual:@"plans"]) return [[[OR6Chat7PlansScreen alloc] initWithCore:core title:OR6L(@"Plans")] autorelease];
    if ([@[@"appearance", @"language", @"storage"] containsObject:k ?: @""]) return [[[OR6Chat7PreferencesScreen alloc] initWithCore:core kind:k] autorelease];
    return nil;
}
