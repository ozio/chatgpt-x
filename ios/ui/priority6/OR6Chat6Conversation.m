#import "OR6Chat6Conversation.h"
#import "OR6Chat6Base.h"
#import "../priority8/OR6Chat8Models.h"
#import "RCTaskPartView.h"
#import "RCButton.h"
#import "RCComposerView.h"
#import "RCActivitySheet.h"
#import "RCHUD.h"

UIViewController *OR6Chat6CreateVoiceSession(OR6APICore *core, NSString *conversationId); // OR6Chat6Settings.m (nil without a host-bound session)

static NSMutableDictionary *gGPTChats; // conversationId → GPT (this session only)
void OR6Chat6AccountForgetSession(void); // OR6Chat6Account.m
void OR6Chat6ForgetSession(void) { [gGPTChats removeAllObjects]; OR6Chat6AccountForgetSession(); }
static BOOL RealId(id i) { return OR6Chat7ConversationUUID(i); }
static NSString *Trim(NSString *s) { return [s isKindOfClass:NSString.class] ? [s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : @""; }

#pragma mark - Report (conversations.reportReasons → reason tree → details → conversations.report)

@interface OR6Chat6ReportScreen : OR6Chat6Form { NSString *_conversationId, *_parentId; NSDictionary *_reasons, *_reason; NSMutableDictionary *_values; NSString *_details, *_problem; BOOL _consent; }
- (id)initWithCore:(OR6APICore *)core conversation:(NSString *)cid reasons:(NSDictionary *)reasons parent:(NSString *)parent reason:(NSDictionary *)reason;
@end
@implementation OR6Chat6ReportScreen
- (id)initWithCore:(OR6APICore *)core conversation:(NSString *)cid reasons:(NSDictionary *)reasons parent:(NSString *)parent reason:(NSDictionary *)reason {
    if ((self = [super initWithCore:core navigator:nil title:(reason ? OR6Chat6Text(reason[@"label"], OR6L(@"Report")) : OR6L(@"Report"))])) {
        _conversationId = [cid copy]; _reasons = [reasons copy]; _parentId = [parent copy]; _reason = [reason copy]; _values = [NSMutableDictionary new];
        self.tableView.accessibilityIdentifier = @"chat.report.table";
    }
    return self;
}
- (NSDictionary *)reasons { return _reasons ?: ([_read.result[@"catalogId"] isKindOfClass:NSString.class] ? _read.result : nil); }
- (void)load { if (!_reasons) [_read perform:@"conversations.reportReasons" parameters:@{}]; [self render]; }
- (void)render {
    NSDictionary *reasons = [self reasons]; NSMutableArray *sections = [NSMutableArray array];
    if (!reasons) { NSMutableArray *rows = [NSMutableArray array]; if (![self addStateOf:_read to:rows empty:nil hasItems:NO identifier:@"chat.report"]) [rows addObject:[self note:OR6L(@"Loading…")]]; self.sections = @[[RCFormSection sectionWithTitle:nil rows:rows]]; return; }
    if (!_reason) {
        NSMutableArray *rows = [NSMutableArray array];
        for (NSDictionary *r in OR6Chat6ReportChildren(reasons, _parentId)) { RCFormRow *row = [RCFormRow rowWithKind:RCFormRowValue title:r[@"label"]]; row.disclosure = YES; row.userInfo = @{@"reason": r}; row.identifier = @"chat.report.reason"; [rows addObject:row]; }
        if (!rows.count) [rows addObject:[self note:OR6L(@"The service offered no reasons.")]];
        RCFormSection *s = [RCFormSection sectionWithTitle:(_parentId ? nil : OR6L(@"Why are you reporting this chat?")) rows:rows];
        [sections addObject:s]; self.sections = sections; return;
    }
    NSMutableArray *fields = [NSMutableArray array];
    if ([_reason[@"hasDetails"] isEqual:@YES]) { RCFormRow *d = [RCFormRow rowWithKind:RCFormRowLongText title:OR6L(@"Details")]; d.text = _details; d.placeholder = OR6L(@"What happened? (optional)"); d.maxLength = 4000; d.identifier = @"chat.report.details"; d.userInfo = @"details"; [fields addObject:d]; }
    for (NSDictionary *f in [_reason[@"additionalFields"] isKindOfClass:NSArray.class] ? _reason[@"additionalFields"] : @[]) {
        if (![f isKindOfClass:NSDictionary.class] || ![f[@"id"] isKindOfClass:NSString.class]) continue;
        RCFormRow *r = [RCFormRow rowWithKind:[f[@"type"] isEqual:@"multi_line_text"] ? RCFormRowLongText : RCFormRowText title:OR6Chat6Text(f[@"placeholder"], f[@"id"])];
        r.placeholder = [f[@"required"] isEqual:@YES] ? OR6Chat6Text(f[@"placeholder"], @"") : [NSString stringWithFormat:OR6L(@"%@ (optional)"), OR6Chat6Text(f[@"placeholder"], @"")];
        r.text = _values[f[@"id"]]; r.maxLength = 4000; r.userInfo = @{@"field": f[@"id"]}; r.identifier = @"chat.report.field"; [fields addObject:r];
    }
    if (fields.count) [sections addObject:[RCFormSection sectionWithTitle:nil rows:fields]];
    RCFormRow *consent = [RCFormRow rowWithKind:RCFormRowCheck title:OR6L(@"Send this conversation with the report")]; consent.checked = _consent; consent.userInfo = @"consent"; consent.identifier = @"chat.report.consent";
    RCFormSection *c = [RCFormSection sectionWithTitle:nil rows:@[consent]]; c.footer = OR6L(@"OpenAI reviews the report together with this conversation. Nothing is sent until you tap Send report."); [sections addObject:c];
    NSMutableArray *act = [NSMutableArray array];
    if ([_reason[@"linkURL"] isKindOfClass:NSString.class]) [act addObject:[self button:OR6L(@"More about this reason") info:@"link" identifier:@"chat.report.link"]];
    if ([_reason[@"canSubmit"] isEqual:@YES] && OR6Chat6On(_core, @"conversations.report")) { RCFormRow *send = [self button:OR6L(@"Send report") info:@"send" identifier:@"chat.report.send"]; send.enabled = _consent; [act addObject:send]; }
    else [act addObject:[self note:OR6L(@"This reason cannot be sent from ChatGPT X.")]];
    RCFormSection *a = [RCFormSection sectionWithTitle:nil rows:act]; a.footer = _problem; [sections addObject:a];
    self.sections = sections;
}
- (void)form:(RCFormViewController *)f didChangeTextOfRow:(RCFormRow *)row {
    (void)f; if ([row.userInfo isEqual:@"details"]) { [_details release]; _details = [row.text copy]; }
    else if ([row.userInfo isKindOfClass:NSDictionary.class] && row.userInfo[@"field"]) _values[row.userInfo[@"field"]] = row.text ?: @"";
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    id i = row.userInfo; NSDictionary *reasons = [self reasons];
    if ([i isKindOfClass:NSDictionary.class] && i[@"reason"]) {
        NSDictionary *r = i[@"reason"]; BOOL children = OR6Chat6ReportChildren(reasons, r[@"id"]).count > 0;
        OR6Chat6ReportScreen *next = [[[OR6Chat6ReportScreen alloc] initWithCore:_core conversation:_conversationId reasons:reasons parent:(children ? r[@"id"] : nil) reason:(children ? nil : r)] autorelease];
        if (children) next.title = r[@"label"];
        [self.navigationController pushViewController:next animated:YES]; return;
    }
    if ([i isEqual:@"consent"]) { _consent = !_consent; [self render]; return; }
    if ([i isEqual:@"link"]) { NSURL *u = [NSURL URLWithString:_reason[@"linkURL"]]; if ([u.scheme.lowercaseString isEqual:@"https"]) [UIApplication.sharedApplication openURL:u]; return; }
    if ([i isEqual:@"send"]) {
        [self endEditing]; NSString *problem = nil;
        NSDictionary *p = _consent ? OR6Chat6ReportRequest(_conversationId, reasons, _reason, _details, _values, &problem) : nil;
        if (!_consent) problem = OR6L(@"Allow sending this conversation with the report first.");
        [_problem release]; _problem = [problem copy]; if (!p) { [self render]; return; }
        UINavigationController *nc = self.navigationController; UIViewController *root = nil;
        for (UIViewController *v in nc.viewControllers) if ([v isKindOfClass:OR6Chat6ReportScreen.class]) { NSUInteger k = [nc.viewControllers indexOfObject:v]; root = k ? nc.viewControllers[k - 1] : nil; break; }
        OR6Chat7RunWrite(self.view.window, _core, @"conversations.report", p, [@"conversations.report:" stringByAppendingString:_conversationId], @"locked.reconcile", OR6L(@"Report sent."), ^(NSDictionary *r) { (void)r; if (root && [nc.viewControllers containsObject:root]) [nc popToViewController:root animated:YES]; });
        return;
    }
    [super form:f didSelectRow:row];
}
- (void)dealloc { [_conversationId release]; [_parentId release]; [_reasons release]; [_reason release]; [_values release]; [_details release]; [_problem release]; [super dealloc]; }
@end

#pragma mark - Memory used in an answer (memories.citations → feedback / correction)

@interface OR6Chat6CitationsScreen : OR6Chat6Form <UIAlertViewDelegate> { NSString *_conversationId, *_messageId; NSDictionary *_target; UIAlertView *_alert; }
- (id)initWithCore:(OR6APICore *)core conversation:(NSString *)cid message:(NSString *)mid;
@end
@implementation OR6Chat6CitationsScreen
- (id)initWithCore:(OR6APICore *)core conversation:(NSString *)cid message:(NSString *)mid {
    if ((self = [super initWithCore:core navigator:nil title:OR6L(@"Memory used")])) { _conversationId = [cid copy]; _messageId = [mid copy]; self.tableView.accessibilityIdentifier = @"chat.citations.table"; }
    return self;
}
- (void)load { [_read perform:@"memories.citations" parameters:@{@"conversationId": _conversationId, @"messageId": _messageId}]; [self render]; }
- (NSDictionary *)page { NSDictionary *r = _read.result; return [r[@"messageId"] isEqual:_messageId] && [r[@"conversationId"] isEqual:_conversationId] ? r : nil; }
- (BOOL)canRate:(NSDictionary *)c { return [c[@"canFeedback"] isEqual:@YES] && OR6Chat6Text([self page][@"revision"], nil) && (OR6Chat6On(_core, @"memories.feedback") || OR6Chat6On(_core, @"memories.correctCitation")); }
- (void)render {
    NSMutableArray *rows = [NSMutableArray array]; NSDictionary *page = [self page];
    NSDictionary *kinds = @{@"user_instructions": OR6L(@"Your instructions"), @"user_memory": OR6L(@"Saved memory"), @"general_memory": OR6L(@"Memory"), @"past_conversation": OR6L(@"Earlier chat")};
    for (NSDictionary *c in [page[@"items"] isKindOfClass:NSArray.class] ? page[@"items"] : @[]) {
        if (![c isKindOfClass:NSDictionary.class] || !OR6Chat6Text(c[@"id"], nil)) continue;
        RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:OR6Chat6Text(c[@"title"], OR6L(@"Untitled"))];
        NSString *rating = [c[@"feedback"] isEqual:@"positive"] ? OR6L(@"Rated helpful") : [c[@"feedback"] isEqual:@"negative"] ? OR6L(@"Rated not helpful") : nil;
        r.subtitle = [[NSArray arrayWithObjects:(kinds[c[@"kind"]] ?: OR6L(@"Memory")), (OR6Chat6Text(c[@"snippet"], nil) ?: @""), nil] componentsJoinedByString:@" · "];
        r.value = rating; r.glyph = [c[@"kind"] isEqual:@"past_conversation"] ? @"compose" : @"brain"; r.tile = RCTilePurple; r.identifier = @"chat.citations.row";
        BOOL rate = [self canRate:c]; r.enabled = rate; r.disclosure = rate; r.userInfo = rate ? c : nil; [rows addObject:r];
    }
    [self addStateOf:_read to:rows empty:OR6L(@"This answer did not use your memory.") hasItems:rows.count > 0 identifier:@"chat.citations"];
    if (!page && !_read.busy && !_read.error && _read.result) [rows addObject:[self note:OR6L(@"The answer could not be matched. Read it again.")]];
    RCFormSection *s = [RCFormSection sectionWithTitle:nil rows:rows];
    if (rows.count && page) s.footer = OR6L(@"What ChatGPT remembered and used for this answer. Tap one to rate it or correct it.");
    self.sections = @[s];
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    if (![row.userInfo isKindOfClass:NSDictionary.class]) { [super form:f didSelectRow:row]; return; }
    NSDictionary *c = row.userInfo; [_target release]; _target = [c retain];
    NSMutableArray *b = [NSMutableArray array], *k = [NSMutableArray array];
    if (OR6Chat6On(_core, @"memories.feedback")) {
        if (![c[@"feedback"] isEqual:@"positive"]) { [b addObject:OR6L(@"Helpful")]; [k addObject:@"positive"]; }
        if (![c[@"feedback"] isEqual:@"negative"]) { [b addObject:OR6L(@"Not helpful")]; [k addObject:@"negative"]; }
        if ([c[@"feedback"] isKindOfClass:NSString.class]) { [b addObject:OR6L(@"Clear rating")]; [k addObject:@"clear"]; }
    }
    if (OR6Chat6On(_core, @"memories.correctCitation")) { [b addObject:OR6L(@"Correct this…")]; [k addObject:@"correct"]; }
    OR6Chat8ShowSheet(self.view.window ?: self.view, row.title, b, nil, ^(NSInteger n, NSString *t) {
        (void)t; if (n < 0 || (NSUInteger)n >= k.count) return; NSString *key = k[(NSUInteger)n];
        if ([key isEqual:@"correct"]) {
            UIAlertView *a = [[[UIAlertView alloc] initWithTitle:OR6L(@"Correct this memory") message:OR6L(@"Say what is wrong. ChatGPT uses your correction from now on.") delegate:self cancelButtonTitle:OR6L(@"Cancel") otherButtonTitles:OR6L(@"Send"), nil] autorelease];
            a.alertViewStyle = UIAlertViewStylePlainTextInput; [_alert release]; _alert = [a retain]; [a show]; return;
        }
        [self feedback:[key isEqual:@"clear"] ? (id)NSNull.null : key];
    });
}
- (NSDictionary *)base { NSDictionary *p = [self page]; NSString *rev = OR6Chat6Text(p[@"revision"], nil), *cit = OR6Chat6Text(_target[@"id"], nil); return rev && cit ? @{@"expectedRevision": rev, @"conversationId": _conversationId, @"messageId": _messageId, @"citationId": cit} : nil; }
- (void)feedback:(id)value {
    if (!_target || ![self base]) return; NSMutableDictionary *p = [[[self base] mutableCopy] autorelease]; p[@"feedback"] = value;
    OR6Chat7RunWrite(self.view.window, _core, @"memories.feedback", p, [NSString stringWithFormat:@"memories.feedback:%@:%@", _messageId, _target[@"id"]], @"memories.reconcile", OR6L(@"Thanks for the rating."), ^(NSDictionary *r) { (void)r; [self load]; });
}
- (void)alertView:(UIAlertView *)a clickedButtonAtIndex:(NSInteger)i {
    if (a == _alert) { [_alert autorelease]; _alert = nil; }
    if (i == a.cancelButtonIndex || !_target || ![self base]) return;
    NSString *text = Trim([a textFieldAtIndex:0].text); if (!text.length || text.length > 8000) { OR6Chat6Say(self.view.window, OR6L(@"Write the correction first.")); return; }
    NSMutableDictionary *p = [[[self base] mutableCopy] autorelease]; p[@"correction"] = text;
    OR6Chat7RunWrite(self.view.window, _core, @"memories.correctCitation", p, [NSString stringWithFormat:@"memories.correctCitation:%@:%@", _messageId, _target[@"id"]], @"memories.reconcile", OR6L(@"Correction sent."), ^(NSDictionary *r) { (void)r; [self load]; });
}
- (void)dealloc { _alert.delegate = nil; [_alert dismissWithClickedButtonIndex:_alert.cancelButtonIndex animated:NO]; [_alert release]; [_conversationId release]; [_messageId release]; [_target release]; [super dealloc]; }
@end

#pragma mark - Mention an app (composer.mentions.list)

@interface OR6Chat6MentionPicker : OR6Chat6Form { NSString *_query; NSTimer *_timer; void (^_chosen)(NSDictionary *); }
- (id)initWithCore:(OR6APICore *)core chosen:(void (^)(NSDictionary *mention))chosen;
@end
@implementation OR6Chat6MentionPicker
- (id)initWithCore:(OR6APICore *)core chosen:(void (^)(NSDictionary *))chosen {
    if ((self = [super initWithCore:core navigator:nil title:OR6L(@"Mention an app")])) { _chosen = [chosen copy]; self.tableView.accessibilityIdentifier = @"chat.mentions.table"; }
    return self;
}
- (void)load { [_read perform:@"composer.mentions.list" parameters:@{@"query": _query ?: @""}]; [self render]; }
- (void)render {
    RCFormRow *q = [RCFormRow rowWithKind:RCFormRowText title:OR6L(@"Search")]; q.text = _query; q.placeholder = OR6L(@"App name"); q.maxLength = 240; q.identifier = @"chat.mentions.search";
    NSMutableArray *rows = [NSMutableArray array];
    for (NSDictionary *m in [_read.result[@"items"] isKindOfClass:NSArray.class] ? _read.result[@"items"] : @[]) {
        if (![m isKindOfClass:NSDictionary.class] || !OR6Chat6Text(m[@"id"], nil) || !OR6Chat6Text(m[@"name"], nil)) continue;
        RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:m[@"name"]]; r.subtitle = OR6Chat6Text(m[@"description"], nil); r.glyph = @"at"; r.tile = RCTilePurple; r.userInfo = m; r.identifier = @"chat.mentions.row"; [rows addObject:r];
    }
    [self addStateOf:_read to:rows empty:(_query.length ? OR6L(@"Nothing found.") : OR6L(@"No apps can be mentioned on this account.")) hasItems:rows.count > 0 identifier:@"chat.mentions"];
    RCFormSection *s = [RCFormSection sectionWithTitle:nil rows:rows]; s.footer = OR6L(@"The app you mention helps with the next message. It may read what you write in it.");
    self.sections = @[[RCFormSection sectionWithTitle:nil rows:@[q]], s];
}
- (void)form:(RCFormViewController *)f didChangeTextOfRow:(RCFormRow *)row {
    (void)f; NSString *t = Trim(row.text); if ([t isEqual:_query ?: @""]) return; [_query release]; _query = [t copy];
    [_timer invalidate]; _timer = [NSTimer scheduledTimerWithTimeInterval:.45 target:self selector:@selector(fire:) userInfo:nil repeats:NO];
}
- (void)fire:(NSTimer *)t { (void)t; _timer = nil; [self load]; }
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    if (![row.userInfo isKindOfClass:NSDictionary.class]) { [super form:f didSelectRow:row]; return; }
    void (^c)(NSDictionary *) = [[_chosen copy] autorelease]; NSDictionary *m = row.userInfo; [self endEditing];
    [self.navigationController popViewControllerAnimated:YES]; if (c) c(m);
}
- (void)viewWillDisappear:(BOOL)a { [super viewWillDisappear:a]; [_timer invalidate]; _timer = nil; }
- (void)dealloc { [_timer invalidate]; [_query release]; [_chosen release]; [super dealloc]; }
@end

#pragma mark - Library folder chooser for a saved answer (library.favoriteFolders.list)

@interface OR6Chat6FolderChooser : OR6Chat6Form { OR6Chat6Pager *_folders; void (^_chosen)(id parentId); }
- (id)initWithCore:(OR6APICore *)core chosen:(void (^)(id parentId))chosen;
@end
@implementation OR6Chat6FolderChooser
- (id)initWithCore:(OR6APICore *)core chosen:(void (^)(id))chosen {
    if ((self = [super initWithCore:core navigator:nil title:OR6L(@"Move to folder")])) {
        _chosen = [chosen copy]; _folders = [[self pager:@"library.favoriteFolders.list" parameters:@{} tokenKey:@"pageToken" nextKey:@"nextPageToken" idKey:@"id"] retain];
        self.tableView.accessibilityIdentifier = @"chat.saved.folders";
    }
    return self;
}
- (void)load { [_folders reload]; [self render]; }
- (void)render {
    NSMutableArray *rows = [NSMutableArray array];
    RCFormRow *root = [RCFormRow rowWithKind:RCFormRowValue title:OR6L(@"Library (no folder)")]; root.glyph = @"library"; root.tile = RCTileTeal; root.userInfo = @{@"parent": NSNull.null}; root.identifier = @"chat.saved.folder"; [rows addObject:root];
    for (NSDictionary *n in _folders.items) {
        if (![n[@"kind"] isEqual:@"directory"]) continue;
        RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:OR6Chat6Text(n[@"name"], OR6L(@"Folder"))]; r.glyph = @"folder"; r.tile = RCTileTeal; r.userInfo = @{@"parent": n[@"id"]}; r.identifier = @"chat.saved.folder"; [rows addObject:r];
    }
    [self addStateOfPager:_folders to:rows empty:nil identifier:@"chat.saved.folders"];
    self.sections = @[[RCFormSection sectionWithTitle:nil rows:rows]];
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    if (![row.userInfo isKindOfClass:NSDictionary.class] || !row.userInfo[@"parent"]) { [super form:f didSelectRow:row]; return; }
    void (^c)(id) = [[_chosen copy] autorelease]; id parent = row.userInfo[@"parent"];
    [self.navigationController popViewControllerAnimated:YES]; if (c) c(parent);
}
- (void)dealloc { [_folders release]; [_chosen release]; [super dealloc]; }
@end

#pragma mark - Saved items of an answer (library.entity.*, trusted host descriptors only)

@interface OR6Chat6EntitiesScreen : OR6Chat6Form { NSArray *_entities; NSMutableDictionary *_status; NSMutableArray *_calls; }
- (id)initWithCore:(OR6APICore *)core entities:(NSArray *)entities;
@end
@implementation OR6Chat6EntitiesScreen
- (id)initWithCore:(OR6APICore *)core entities:(NSArray *)entities {
    if ((self = [super initWithCore:core navigator:nil title:OR6L(@"Saved items")])) { _entities = [entities copy]; _status = [NSMutableDictionary new]; _calls = [NSMutableArray new]; self.tableView.accessibilityIdentifier = @"chat.entities.table"; }
    return self;
}
- (void)load {
    [_calls removeAllObjects]; [_status removeAllObjects];
    for (NSDictionary *e in _entities) { OR6Chat7Call *c = [self call]; [_calls addObject:c]; [c perform:@"library.entity.status" parameters:@{@"referenceId": e[@"referenceId"]}]; }
    [self render];
}
- (NSDictionary *)statusOf:(NSDictionary *)e { for (OR6Chat7Call *c in _calls) if ([c.result[@"referenceId"] isEqual:e[@"referenceId"]]) return c.result; return nil; }
- (OR6Chat7Call *)callOf:(NSUInteger)i { return i < _calls.count ? _calls[i] : nil; }
- (void)render {
    NSMutableArray *rows = [NSMutableArray array]; NSUInteger i = 0;
    for (NSDictionary *e in _entities) {
        OR6Chat7Call *c = [self callOf:i++]; NSDictionary *s = [self statusOf:e];
        RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:OR6Chat6Text(e[@"title"], OR6L(@"Untitled"))]; r.subtitle = OR6Chat6Text(e[@"category"], nil); r.glyph = @"star"; r.tile = RCTileYellow; r.identifier = @"chat.entities.row";
        r.busy = c.busy; r.value = c.error ? OR6L(@"Unknown") : s ? ([s[@"isSaved"] isEqual:@YES] ? OR6L(@"Saved") : OR6L(@"Not saved")) : nil;
        BOOL act = s && (OR6Chat6On(_core, @"library.entity.set") || ([s[@"isSaved"] isEqual:@YES] && OR6Chat6On(_core, @"library.entity.move")));
        r.enabled = act; r.disclosure = act; r.userInfo = act ? @{@"entity": e, @"status": s} : nil; [rows addObject:r];
    }
    RCFormSection *sec = [RCFormSection sectionWithTitle:nil rows:rows]; sec.footer = OR6L(@"Places, products and images from this answer that you can keep in your Library.");
    self.sections = @[sec];
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    if (![row.userInfo isKindOfClass:NSDictionary.class] || !row.userInfo[@"entity"]) { [super form:f didSelectRow:row]; return; }
    NSDictionary *e = row.userInfo[@"entity"], *s = row.userInfo[@"status"]; BOOL saved = [s[@"isSaved"] isEqual:@YES];
    NSMutableArray *b = [NSMutableArray array], *k = [NSMutableArray array];
    if (OR6Chat6On(_core, @"library.entity.set")) { [b addObject:saved ? OR6L(@"Remove from Library") : OR6L(@"Save to Library")]; [k addObject:@"set"]; }
    if (saved && OR6Chat6On(_core, @"library.entity.move") && OR6Chat6On(_core, @"library.favoriteFolders.list")) { [b addObject:OR6L(@"Move to folder…")]; [k addObject:@"move"]; }
    NSString *ref = e[@"referenceId"];
    OR6Chat8ShowSheet(self.view.window ?: self.view, row.title, b, nil, ^(NSInteger n, NSString *t) {
        (void)t; if (n < 0 || (NSUInteger)n >= k.count) return;
        if ([k[(NSUInteger)n] isEqual:@"set"]) { OR6Chat7RunWrite(self.view.window, _core, @"library.entity.set", @{@"referenceId": ref, @"isSaved": @(!saved)}, [@"library.entity.set:" stringByAppendingString:ref], @"catalog.reconcile", saved ? OR6L(@"Removed from Library.") : OR6L(@"Saved to Library."), ^(NSDictionary *r) { (void)r; [self load]; }); return; }
        [self.navigationController pushViewController:[[[OR6Chat6FolderChooser alloc] initWithCore:_core chosen:^(id parent) {
            OR6Chat7RunWrite(self.view.window, _core, @"library.entity.move", @{@"referenceId": ref, @"parentId": parent}, [@"library.entity.move:" stringByAppendingString:ref], @"catalog.reconcile", OR6L(@"Moved."), ^(NSDictionary *r) { (void)r; [self load]; });
        }] autorelease] animated:YES];
    });
}
- (void)dealloc { [_entities release]; [_status release]; [_calls release]; [super dealloc]; }
@end

#pragma mark - Helper

@interface OR6Chat6Conversation () <OR6Chat8ModelDelegate> {
    OR6APICore *_core; id<OR6Chat7ConversationHost> _host; OR6Chat7Conversation *_api7; OR6Chat8Catalog *_catalog;
    NSDictionary *_gpt; NSMutableArray *_mentions; NSDictionary *_handoff; NSString *_handoffFor, *_saveMessage;
    OR6Chat7Call *_aux; NSUInteger _life; BOOL _handoffRead, _workForHandoff, _autoChecked;
}
@end

@implementation OR6Chat6Conversation
@synthesize catalog = _catalog, gpt = _gpt;
- (id)initWithCore:(OR6APICore *)core host:(id<OR6Chat7ConversationHost>)host api7:(OR6Chat7Conversation *)api7 {
    if ((self = [super init])) {
        _core = [core retain]; _host = host; _api7 = [api7 retain]; _mentions = [NSMutableArray new];
        _aux = [[OR6Chat7Call alloc] initWithCore:core]; _aux.delegate = self;
        __block OR6Chat6Conversation *me = self; // the API7 helper is detached before this one is released
        _api7.sendFinished = ^(NSString *op, NSDictionary *r) { [me sendFinished:op result:r]; };
    }
    return self;
}
- (UIView *)hud { UIViewController *p = [_host chat7Presenter]; return p.view.window ?: p.view; }
- (void)say:(NSString *)t { OR6Chat6Say([self hud], t); }
- (BOOL)temporary { return [[_host chat7DraftRequest][@"temporary"] boolValue]; }
- (NSString *)cid { NSString *c = [_host chat7ConversationId]; return RealId(c) ? c : nil; }
- (BOOL)realMessage:(NSDictionary *)r { return RealId(r[@"id"]) && [self cid] && ![self temporary]; }
- (void)chat8ModelChanged:(id)m { if (m == _aux) [self auxChanged]; }

#pragma mark Send modes (GPT, Work, mentions)

- (void)applyMode:(NSDictionary *)mode { [_api7 setSendMode:mode]; [_host chat7Render]; }
- (void)setGPT:(NSDictionary *)gpt {
    if (![gpt isKindOfClass:NSDictionary.class] || !OR6Chat6Text(gpt[@"id"], nil) || !OR6Chat6On(_core, @"gpts.send")) return;
    [_gpt release]; _gpt = [@{@"id": gpt[@"id"], @"name": OR6Chat6Text(gpt[@"name"], OR6L(@"GPT"))} copy];
    NSString *gid = _gpt[@"id"];
    [self applyMode:@{@"operation": @"gpts.send", @"reconcile": @"connectors.operation.reconcile", @"title": _gpt[@"name"], @"glyph": @"gpt", @"chip": @(RCChipPurple), @"sticky": @YES,
                      @"build": [[^NSDictionary *(NSString *text) { (void)text; return @{@"gptId": gid}; } copy] autorelease]}];
}
- (void)sendFinished:(NSString *)op result:(NSDictionary *)r {
    if ([op isEqual:@"gpts.send"] && _gpt && RealId(r[@"conversationId"])) { if (!gGPTChats) gGPTChats = [NSMutableDictionary new]; gGPTChats[r[@"conversationId"]] = _gpt; }
    if ([op isEqual:@"composer.mentions.send"]) [_mentions removeAllObjects];
}
- (void)conversationLoaded {
    NSString *cid = [self cid]; if (!cid) return;
    NSDictionary *g = gGPTChats[cid]; if (g && !_api7.sendMode && !_api7.toolMode) [self setGPT:g]; // a GPT chat of this session keeps talking to its GPT
    if (!_handoffRead && ![self temporary] && OR6Chat6On(_core, @"work.handoff.get")) { _handoffRead = YES; [_handoffFor release]; _handoffFor = [cid copy]; [_aux perform:@"work.handoff.get" parameters:@{@"conversationId": cid}]; }
}
// Called on appearance and again when the catalog becomes ready: the latch is set only once a
// request actually started (or the cached observation applied); a stop signal ends automatic reads
// for this context (OR6Chat6AutoPreference), and the draft and chosen model are never touched by a failure.
- (void)newChatOpened {
    if (_autoChecked || [_host chat7ConversationId] || !_catalog || !_catalog.loaded || _catalog.chosenModelId || !OR6Chat6On(_core, @"modelControls.autoPreference.get")) return;
    NSUInteger life = _life; OR6Chat8Catalog *catalog = _catalog;
    _autoChecked = [[OR6Chat6AutoPreference forCore:_core] request:^(NSDictionary *r) {
        if (life != _life || !_host || catalog != _catalog || catalog.chosenModelId || [_host chat7ConversationId]) return;
        NSString *model = [r[@"selection"] isKindOfClass:NSDictionary.class] ? r[@"selection"][@"modelId"] : nil;
        if ([r[@"prefersAuto"] isEqual:@YES] && [r[@"eligible"] isEqual:@YES] && [r[@"selection"][@"lane"] isEqual:@"auto"] && [catalog modeForModel:model]) [catalog select:model]; // the stored preference: new chats start on Auto
    }];
}
- (void)addPlusItems:(NSMutableArray *)items actions:(NSMutableArray *)actions {
    if ([self temporary] || _gpt) return;
    if (OR6Chat6AllOn(_core, @[@"work.models", @"work.send"])) { RCActivityItem *i = [RCActivityItem itemWithTitle:OR6L(@"Work") glyph:@"bag" tile:RCTileGraphite]; i.on = [_api7.sendMode[@"operation"] isEqual:@"work.send"]; [items addObject:i]; [actions addObject:@"six:work"]; }
}
- (BOOL)handlePlusAction:(NSString *)a {
    if ([a isEqual:@"six:mention"]) {
        OR6Chat6MentionPicker *p = [[[OR6Chat6MentionPicker alloc] initWithCore:_core chosen:^(NSDictionary *m) { [self insertMention:m]; }] autorelease];
        [[_host chat7Presenter].navigationController pushViewController:p animated:YES]; return YES;
    }
    if ([a isEqual:@"six:work"]) {
        if ([_api7.sendMode[@"operation"] isEqual:@"work.send"]) { [self applyMode:nil]; UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, OR6L(@"Work is off")); return YES; }
        [_aux perform:@"work.models" parameters:@{}]; [RCHUD showText:OR6L(@"Loading…") kind:RCHUDTextOnly inView:[self hud] seconds:0.8]; return YES;
    }
    return NO;
}
- (void)insertMention:(NSDictionary *)m {
    if (!_host || !OR6Chat6On(_core, @"composer.mentions.send")) return;
    NSString *text = [_host chat7Composer].text ?: @"", *sep = text.length && ![text hasSuffix:@" "] && ![text hasSuffix:@"\n"] ? @" " : @"";
    NSString *token = [@"@" stringByAppendingString:m[@"name"]]; NSUInteger at = text.length + sep.length;
    if (at + token.length + 1 > 16000) { [self say:OR6L(@"The message is too long.")]; return; }
    if (_mentions.count >= 16) { [self say:OR6L(@"You can mention up to 16 apps in one message.")]; return; }
    [_host chat7SetDraftText:[NSString stringWithFormat:@"%@%@%@ ", text, sep, token]];
    [_mentions addObject:@{@"id": m[@"id"], @"name": m[@"name"], @"location": @(at)}];
    NSMutableArray *mentions = _mentions; UIView *hud = [self hud];
    [self applyMode:@{@"operation": @"composer.mentions.send", @"reconcile": @"connectors.operation.reconcile", @"title": OR6L(@"App mention"), @"glyph": @"at", @"chip": @(RCChipPurple),
                      @"build": [[^NSDictionary *(NSString *t) { NSArray *r = OR6Chat6MentionRanges(t, mentions);
                          if (!r.count) { OR6Chat6Say(hud, OR6L(@"The app mention is no longer in the text. Mention the app again or turn the mode off.")); return nil; }
                          return @{@"mentions": r}; } copy] autorelease]}];
}
- (void)chooseWork:(NSArray *)models {
    NSMutableArray *titles = [NSMutableArray array], *ids = [NSMutableArray array];
    for (NSDictionary *m in models) if ([m isKindOfClass:NSDictionary.class] && OR6Chat6Text(m[@"id"], nil)) { [titles addObject:OR6Chat6Text(m[@"name"], m[@"id"])]; [ids addObject:m[@"id"]]; }
    if (!ids.count) { [self say:OR6L(@"Work is not available on this account.")]; return; }
    NSUInteger life = _life;
    OR6Chat8ShowSheet([self hud], OR6L(@"Work does longer tasks with files, spreadsheets and documents. Choose the model for the next message."), titles, nil, ^(NSInteger n, NSString *t) {
        if (life != _life || !_host || n < 0 || (NSUInteger)n >= ids.count) return; NSString *model = ids[(NSUInteger)n];
        [self applyMode:@{@"operation": @"work.send", @"reconcile": @"connectors.operation.reconcile", @"title": [NSString stringWithFormat:OR6L(@"Work · %@"), t], @"glyph": @"bag", @"chip": @(RCChipGreen),
                          @"build": [[^NSDictionary *(NSString *x) { (void)x; return @{@"modelId": model}; } copy] autorelease]}];
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, OR6L(@"Work is on for the next message"));
    });
}

#pragma mark Answer «⋯»

- (BOOL)researchExportAvailable:(NSDictionary *)r {
    id<OR6Chat6TrustedHost> h = OR6Chat6TrustedHostNow();
    return [r[@"role"] isEqual:@"assistant"] && [r[@"researchReport"] isEqual:@YES] && [self realMessage:r] && OR6Chat6On(_core, @"research.exportPDF") && [h respondsToSelector:@selector(chat6TakeExportURLs:)];
}
- (NSArray *)entitiesFor:(NSDictionary *)r {
    id<OR6Chat6TrustedHost> h = OR6Chat6TrustedHostNow(); if (![h respondsToSelector:@selector(chat6SavedEntitiesForConversation:message:)] || ![self realMessage:r]) return nil;
    NSMutableArray *a = [NSMutableArray array];
    for (NSDictionary *e in [h chat6SavedEntitiesForConversation:[self cid] message:r[@"id"]]) if ([e isKindOfClass:NSDictionary.class] && OR6Chat7ConversationUUID(e[@"referenceId"])) [a addObject:e];
    return a;
}
- (NSArray *)moreTitlesForRow:(NSDictionary *)r isLast:(BOOL)last {
    (void)last; NSMutableArray *t = [NSMutableArray array];
    if (![self realMessage:r] || [r[@"continued"] isEqual:@YES]) return t; // one entry per message, not per text chunk
    BOOL answer = [r[@"role"] isEqual:@"assistant"];
    if (OR6Chat6On(_core, @"conversations.branch")) [t addObject:OR6L(@"Branch into a new chat")];
    if (answer && OR6Chat6AllOn(_core, @[@"library.responses.list", @"library.response.set"])) [t addObject:OR6L(@"Save to Library…")];
    if (answer && [self entitiesFor:r].count && OR6Chat6On(_core, @"library.entity.status")) [t addObject:OR6L(@"Saved items…")];
    if (answer && OR6Chat6On(_core, @"memories.citations")) [t addObject:OR6L(@"Memory used")];
    if ([self researchExportAvailable:r]) [t addObject:OR6L(@"Research report as PDF")];
    if (OR6Chat6AllOn(_core, @[@"conversations.reportReasons", @"conversations.report"])) [t addObject:OR6L(@"Report…")];
    return t;
}
- (BOOL)performMore:(NSString *)title row:(NSDictionary *)r {
    NSString *cid = [self cid], *mid = r[@"id"]; if (!cid || !RealId(mid)) return NO;
    UIViewController *p = [_host chat7Presenter];
    if ([title isEqual:OR6L(@"Branch into a new chat")]) { [self branch:mid]; return YES; }
    if ([title isEqual:OR6L(@"Save to Library…")]) { [_saveMessage release]; _saveMessage = [mid copy]; [_aux perform:@"library.responses.list" parameters:@{@"conversationId": cid, @"pageToken": NSNull.null}]; return YES; }
    if ([title isEqual:OR6L(@"Saved items…")]) { [p.navigationController pushViewController:[[[OR6Chat6EntitiesScreen alloc] initWithCore:_core entities:[self entitiesFor:r]] autorelease] animated:YES]; return YES; }
    if ([title isEqual:OR6L(@"Memory used")]) { [p.navigationController pushViewController:[[[OR6Chat6CitationsScreen alloc] initWithCore:_core conversation:cid message:mid] autorelease] animated:YES]; return YES; }
    if ([title isEqual:OR6L(@"Research report as PDF")]) { [self exportPDF:mid]; return YES; }
    if ([title isEqual:OR6L(@"Report…")]) { OR6Chat6RunConversationAction(p, _core, @"report", @{@"id": cid}, [_host chat7Navigator]); return YES; }
    return NO;
}
- (void)branch:(NSString *)mid {
    NSString *cid = [self cid]; id<OR6Chat7ConversationHost> host = _host; NSUInteger life = _life;
    OR6Chat6Confirm([self hud], OR6L(@"Start a new chat that continues from this message? This chat stays as it is."), OR6L(@"Branch into a new chat"), NO, ^{
        if (life != _life || !_host) return;
        OR6Chat7RunWrite([self hud], _core, @"conversations.branch", @{@"conversationId": cid, @"messageId": mid}, [@"conversations.branch:" stringByAppendingString:mid], @"locked.reconcile", OR6L(@"New chat created."), ^(NSDictionary *r) {
            NSString *n = [r[@"conversation"] isKindOfClass:NSDictionary.class] ? r[@"conversation"][@"id"] : nil;
            if (life == _life && _host == host && RealId(n)) [host chat7OpenConversation:n];
        });
    });
}
- (void)savedState:(NSDictionary *)page message:(NSString *)mid {
    NSString *cid = [self cid]; if (!cid) return; NSDictionary *saved = nil;
    for (NSDictionary *i in [page[@"items"] isKindOfClass:NSArray.class] ? page[@"items"] : @[]) if ([i isKindOfClass:NSDictionary.class] && [i[@"messageId"] isEqual:mid]) saved = i;
    BOOL more = [page[@"nextPageToken"] isKindOfClass:NSString.class] && !saved; // only the first page was read: unknown beyond it
    NSMutableArray *b = [NSMutableArray array], *k = [NSMutableArray array];
    if (saved) { [b addObject:OR6L(@"Remove from Library")]; [k addObject:@"remove"]; if (OR6Chat6AllOn(_core, @[@"library.response.move", @"library.favoriteFolders.list"])) { [b addObject:OR6L(@"Move to folder…")]; [k addObject:@"move"]; } }
    else { [b addObject:OR6L(@"Save to Library")]; [k addObject:@"save"]; }
    NSString *title = saved ? OR6L(@"This answer is saved in your Library.") : more ? OR6L(@"Save this answer to your Library? (Saved answers of long chats may not all be listed.)") : OR6L(@"Save this answer to your Library? The saved copy keeps the answer as it is now.");
    NSUInteger life = _life;
    OR6Chat8ShowSheet([self hud], title, b, nil, ^(NSInteger n, NSString *t) {
        (void)t; if (life != _life || !_host || n < 0 || (NSUInteger)n >= k.count) return; NSString *key = k[(NSUInteger)n];
        if ([key isEqual:@"move"]) {
            [[_host chat7Presenter].navigationController pushViewController:[[[OR6Chat6FolderChooser alloc] initWithCore:_core chosen:^(id parent) {
                OR6Chat7RunWrite([self hud], _core, @"library.response.move", @{@"conversationId": cid, @"messageId": mid, @"parentId": parent}, [@"library.response.move:" stringByAppendingString:mid], @"catalog.reconcile", OR6L(@"Moved."), nil);
            }] autorelease] animated:YES];
            return;
        }
        BOOL save = [key isEqual:@"save"];
        OR6Chat7RunWrite([self hud], _core, @"library.response.set", @{@"conversationId": cid, @"messageId": mid, @"isSaved": @(save)}, [@"library.response.set:" stringByAppendingString:mid], @"catalog.reconcile", save ? OR6L(@"Saved to Library.") : OR6L(@"Removed from Library."), nil);
    });
}
- (void)exportPDF:(NSString *)mid {
    NSString *cid = [self cid]; NSUInteger life = _life;
    RCHUD *busy = [[RCHUD showText:OR6L(@"Preparing the PDF…") kind:RCHUDBusy inView:[self hud] seconds:0] retain];
    [_core perform:@"research.exportPDF" parameters:@{@"operationId": OR6Chat7OperationID(), @"conversationId": cid, @"messageId": mid} event:nil completion:^(NSDictionary *r, NSError *e) {
        [busy hide]; [busy autorelease]; if (life != _life || !_host) return;
        if (e) { [self say:[e.userInfo[@"code"] isEqual:@"not_found"] || [e.userInfo[@"code"] isEqual:@"invalid_request"] ? OR6L(@"Only a research report can be saved as PDF.") : OR6Chat7ErrorText(e)]; return; }
        id<OR6Chat6TrustedHost> h = OR6Chat6TrustedHostNow(); NSArray *urls = [h respondsToSelector:@selector(chat6TakeExportURLs:)] ? [h chat6TakeExportURLs:r[@"exportToken"]] : nil;
        if (!urls.count) { [self say:OR6L(@"The PDF was prepared but could not be handed to other apps.")]; return; }
        UIActivityViewController *a = [[[UIActivityViewController alloc] initWithActivityItems:urls applicationActivities:nil] autorelease];
        [[_host chat7Presenter] presentViewController:a animated:YES completion:nil];
    }];
}

#pragma mark Work handoff card

- (BOOL)handoffPending { return [_handoff[@"state"] isEqual:@"pending"] && RealId(_handoff[@"handoffId"]) && [_handoff[@"conversationId"] isEqual:[self cid]]; }
- (NSString *)answerRevisionForRow:(NSDictionary *)r isLast:(BOOL)last { return last && [self handoffPending] && [r[@"role"] isEqual:@"assistant"] && RealId(r[@"id"]) ? [@"handoff:" stringByAppendingString:_handoff[@"handoffId"]] : nil; }
- (void)configureAnswerRow:(NSDictionary *)r parts:(NSMutableArray *)parts isLast:(BOOL)last measuring:(BOOL)measuring {
    if (!last || ![self handoffPending] || ![r[@"role"] isEqual:@"assistant"] || !RealId(r[@"id"])) return;
    RCTaskPartView *t = [[[RCTaskPartView alloc] initWithGlyph:@"bag" tile:RCTileGraphite] autorelease];
    t.title = OR6L(@"Continue in Work?"); t.subtitle = OR6Chat6Text(_handoff[@"reason"], OR6L(@"ChatGPT suggests doing this task in Work mode.")); t.progress = -1;
    NSMutableArray *pills = [NSMutableArray array];
    if (OR6Chat6AllOn(_core, @[@"work.handoff.accept", @"work.models"])) { RCButton *b = [RCButton buttonWithStyle:RCButtonStylePillGo title:OR6L(@"Continue")]; if (!measuring) [b addTarget:self action:@selector(acceptHandoff) forControlEvents:UIControlEventTouchUpInside]; [b sizeToFit]; b.accessibilityIdentifier = @"chat.work.accept"; [pills addObject:b]; }
    if (OR6Chat6On(_core, @"work.handoff.decline")) { RCButton *b = [RCButton buttonWithStyle:RCButtonStylePill title:OR6L(@"No, thanks")]; if (!measuring) [b addTarget:self action:@selector(declineHandoff) forControlEvents:UIControlEventTouchUpInside]; [b sizeToFit]; b.accessibilityIdentifier = @"chat.work.decline"; [pills addObject:b]; }
    t.footerButtons = pills; [parts addObject:t];
}
- (void)acceptHandoff { if (![self handoffPending] || ![_host chat7Idle]) return; _workForHandoff = YES; if (![_aux perform:@"work.models" parameters:@{}]) _workForHandoff = NO; }
- (void)handoffWrite:(NSString *)op extra:(NSDictionary *)extra done:(NSString *)done {
    NSDictionary *h = [[_handoff retain] autorelease]; if (![self handoffPending]) return;
    NSMutableDictionary *p = [NSMutableDictionary dictionaryWithDictionary:@{@"conversationId": h[@"conversationId"], @"handoffId": h[@"handoffId"]}]; [p addEntriesFromDictionary:extra];
    NSUInteger life = _life; id<OR6Chat7ConversationHost> host = _host;
    OR6Chat7RunWrite([self hud], _core, op, p, [NSString stringWithFormat:@"%@:%@", op, h[@"handoffId"]], @"connectors.operation.reconcile", done, ^(NSDictionary *r) {
        if (life != _life || _host != host) return;
        [_handoff release]; _handoff = nil; [host chat7Render];
        if (RealId(r[@"conversationId"]) && ![r[@"conversationId"] isEqual:[host chat7ConversationId]]) [host chat7OpenConversation:r[@"conversationId"]]; else [host chat7Reload];
    });
}
- (void)declineHandoff {
    NSUInteger life = _life;
    OR6Chat6Confirm([self hud], OR6L(@"Keep working in this chat without Work mode?"), OR6L(@"No, thanks"), NO, ^{ if (life == _life) [self handoffWrite:@"work.handoff.decline" extra:@{} done:OR6L(@"You stay in this chat.")]; });
}

#pragma mark Reads

- (void)auxChanged {
    if (_aux.busy) return; NSString *op = _aux.operation; NSDictionary *r = _aux.result;
    if ([op isEqual:@"work.handoff.get"]) {
        if (!_aux.error && [r[@"conversationId"] isEqual:_handoffFor] && [r[@"conversationId"] isEqual:[self cid]]) { [_handoff release]; _handoff = [r copy]; [_host chat7Render]; }
        return; // a failed offer read stays silent: nothing is offered
    }
    if (_aux.error) { _workForHandoff = NO; [self say:OR6Chat7ErrorText(_aux.error)]; return; }
    if ([op isEqual:@"work.models"]) {
        NSArray *items = [r[@"items"] isKindOfClass:NSArray.class] ? r[@"items"] : @[];
        if ([self handoffPending] && _workForHandoff) {
            _workForHandoff = NO; NSMutableArray *titles = [NSMutableArray array], *ids = [NSMutableArray array];
            for (NSDictionary *m in items) if ([m isKindOfClass:NSDictionary.class] && OR6Chat6Text(m[@"id"], nil)) { [titles addObject:OR6Chat6Text(m[@"name"], m[@"id"])]; [ids addObject:m[@"id"]]; }
            if (!ids.count) { [self say:OR6L(@"Work is not available on this account.")]; return; }
            NSUInteger life = _life;
            OR6Chat8ShowSheet([self hud], OR6L(@"Continue this task in Work with:"), titles, nil, ^(NSInteger n, NSString *t) { (void)t; if (life == _life && n >= 0 && (NSUInteger)n < ids.count) [self handoffWrite:@"work.handoff.accept" extra:@{@"modelId": ids[(NSUInteger)n]} done:OR6L(@"Work started.")]; });
        } else [self chooseWork:items];
        return;
    }
    if ([op isEqual:@"library.responses.list"]) { NSString *mid = [[_saveMessage retain] autorelease]; if (mid) [self savedState:r message:mid]; return; }
}
- (BOOL)confirmLeaving:(void (^)(void))proceed {
    id<OR6Chat6TrustedHost> h = OR6Chat6TrustedHostNow(); NSString *draft = [h respondsToSelector:@selector(chat6StagedScanDraftId)] ? [h chat6StagedScanDraftId] : nil;
    if (!draft || !OR6Chat7ConversationUUID(draft) || !OR6Chat6AllOn(_core, @[@"scanDraft.leave", @"scanDraft.discard", @"scanDraft.keep"])) return NO;
    void (^go)(void) = [[proceed copy] autorelease]; NSUInteger life = _life;
    [_core perform:@"scanDraft.leave" parameters:@{@"draftId": draft} event:nil completion:^(NSDictionary *r, NSError *e) {
        if (life != _life || !_host) return;
        if (e || ![r[@"requiresConfirmation"] isEqual:@YES] || !OR6Chat7ConversationUUID(r[@"confirmationToken"])) { if (!e && go) go(); else if (e) [self say:OR6Chat7ErrorText(e)]; return; }
        NSString *token = r[@"confirmationToken"], *title = [NSString stringWithFormat:@"%@\n%@", OR6Chat6Text(r[@"title"], OR6L(@"Scanned pages")), OR6Chat6Text(r[@"message"], @"")];
        OR6Chat8ShowSheet([self hud], title, @[OR6L(@"Keep pages")], OR6L(@"Discard pages"), ^(NSInteger n, NSString *t) {
            (void)t; if (life != _life) return;
            if (n == -2) [_core perform:@"scanDraft.discard" parameters:@{@"operationId": OR6Chat7OperationID(), @"draftId": draft, @"confirmationToken": token, @"confirm": @YES} event:nil completion:^(NSDictionary *d, NSError *de) {
                if (life != _life) return; if (de || ![d[@"discarded"] isEqual:@YES]) { [self say:de ? OR6Chat7ErrorText(de) : OR6L(@"The pages were not discarded.")]; return; } if (go) go(); }];
            else [_core perform:@"scanDraft.keep" parameters:@{@"draftId": draft, @"confirmationToken": token} event:nil completion:^(NSDictionary *k, NSError *ke) { (void)k; (void)ke; }];
        });
    }];
    return YES;
}

#pragma mark Lifecycle

- (void)prepareForBackground { _life++; [_aux cancel]; }
- (void)detach { [self prepareForBackground]; _host = nil; _aux.delegate = nil; _api7.sendFinished = nil; }
- (NSDictionary *)diagnostics { NSString *auxIssue = [_aux.error.userInfo[@"code"] isKindOfClass:NSString.class] ? _aux.error.userInfo[@"code"] : nil; NSString *issue = auxIssue ?: [OR6Chat6AutoPreference forCore:_core].lastIssue; return @{@"gpt": @(_gpt != nil), @"mentions": @(_mentions.count), @"handoff": @([self handoffPending]), @"sendMode": _api7.sendMode[@"operation"] ?: @"", @"autoChecked": @(_autoChecked), @"lastIssue": issue ?: @"", @"auxIssue": auxIssue ?: @"", @"autoPreference": [[OR6Chat6AutoPreference forCore:_core] diagnostics] ?: @{}}; }
- (void)dealloc { [self detach]; [_aux release]; [_core release]; [_api7 release]; [_catalog release]; [_gpt release]; [_mentions release]; [_handoff release]; [_handoffFor release]; [_saveMessage release]; [super dealloc]; }
@end

#pragma mark - Chat «⋯» actions

NSArray *OR6Chat6ConversationActions(OR6APICore *core, NSDictionary *v) {
    NSString *cid = v[@"id"]; NSMutableArray *a = [NSMutableArray array]; if (!RealId(cid)) return a;
    if (OR6Chat6AllOn(core, @[@"locked.status", @"locked.pin.verify", @"locked.conversations.lock"])) [a addObject:@{@"key": @"lock", @"title": OR6L(@"Lock chat…")}];
    if (OR6Chat6AllOn(core, @[@"conversations.reportReasons", @"conversations.report"])) [a addObject:@{@"key": @"report", @"title": OR6L(@"Report…")}];
    id<OR6Chat6TrustedHost> h = OR6Chat6TrustedHostNow();
    if ([h respondsToSelector:@selector(chat6VoiceSessionIdForConversation:)] && [h chat6VoiceSessionIdForConversation:cid] && OR6Chat6On(core, @"voice.usage.get")) [a addObject:@{@"key": @"voice", @"title": OR6L(@"Voice conversation")}];
    return a;
}
void OR6Chat6RunConversationAction(UIViewController *host, OR6APICore *core, NSString *key, NSDictionary *v, id<OR6Chat7Navigator> nav) {
    NSString *cid = v[@"id"]; UINavigationController *nc = [host isKindOfClass:UINavigationController.class] ? (id)host : host.navigationController; if (!RealId(cid) || !nc) return;
    UIViewController *c = nil;
    if ([key isEqual:@"lock"]) c = OR6Chat6CreateLockConversation(core, cid, OR6Chat6Text(v[@"title"], nil), nav);
    else if ([key isEqual:@"report"]) c = [[[OR6Chat6ReportScreen alloc] initWithCore:core conversation:cid reasons:nil parent:nil reason:nil] autorelease];
    else if ([key isEqual:@"voice"]) c = OR6Chat6CreateVoiceSession(core, cid);
    if (c) [nc pushViewController:c animated:YES];
}
