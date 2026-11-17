// Projects (API6C) on the API7 screens (OR6Chat7Collections.m): «New project…» on the Projects
// list (projects.create), and the project screen's «⋯» sheet: «Edit project…» (fresh
// projects.detail, then projects.update with exactly the edited name/icon), «Instructions…»
// (fresh projects.detail; projects.instructions.update when granted, else read-only) and «Delete
// project» (purpose-specific destructive confirmation, then projects.delete). The list's search
// (projects.list query) is the lead's code in OR6Chat7Collections.m. Writes are offered only for
// the account's own, non-shared project (canWrite) and only when granted; each runs once after an
// explicit tap with one operation ID, and an unknown outcome offers only catalog.reconcile.
#import "OR6Chat6Base.h"
#import "OR6Chat6TasksLogic.h"

BOOL OR6Chat6RunFormWrite(RCFormViewController *form, OR6APICore *core, NSString *op, NSDictionary *params, NSString *intent, NSString *reconcile, NSString *doneText, void (^done)(NSDictionary *receipt)); // OR6Chat6Tasks.m

static BOOL WriteOn(OR6APICore *core, NSString *op) { return OR6Chat6On(core, op) && OR6Chat6On(core, @"catalog.reconcile"); }
BOOL OR6Chat6ProjectCreateAvailable(OR6APICore *core) { return WriteOn(core, @"projects.create"); }

#pragma mark - Editor (create / edit / instructions)

@interface OR6Chat6ProjectEditor : OR6Chat6Form {
    NSString *_mode, *_projectId, *_name, *_emoji, *_instructions; BOOL _projectOnly, _dirty; void (^_saved)(NSString *projectId); UIBarButtonItem *_save;
}
- (id)initWithCore:(OR6APICore *)core mode:(NSString *)mode project:(NSString *)projectId saved:(void (^)(NSString *projectId))saved;
@end
@implementation OR6Chat6ProjectEditor
- (id)initWithCore:(OR6APICore *)core mode:(NSString *)mode project:(NSString *)projectId saved:(void (^)(NSString *))saved {
    NSString *title = [mode isEqual:@"create"] ? OR6L(@"New project") : [mode isEqual:@"instructions"] ? OR6L(@"Instructions") : OR6L(@"Edit project");
    if ((self = [super initWithCore:core navigator:nil title:title])) {
        _mode = [mode copy]; _projectId = [projectId copy]; _saved = [saved copy];
        self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:OR6L(@"Cancel") style:UIBarButtonItemStyleBordered target:self action:@selector(cancel)] autorelease];
        _save = [[UIBarButtonItem alloc] initWithTitle:OR6L(@"Save") style:UIBarButtonItemStyleDone target:self action:@selector(save)];
        _save.enabled = NO; self.navigationItem.rightBarButtonItem = _save;
    }
    return self;
}
- (BOOL)create { return [_mode isEqual:@"create"]; }
- (BOOL)instructionsMode { return [_mode isEqual:@"instructions"]; }
- (void)load {
    if ([self create]) { [self render]; return; }
    [_name release]; _name = nil; [_emoji release]; _emoji = nil; [_instructions release]; _instructions = nil; _dirty = NO;
    [_read perform:@"projects.detail" parameters:@{@"projectId": _projectId}]; [self render]; // fresh metadata and instructions
}
- (NSDictionary *)fresh { return [_read.result[@"projectId"] isEqual:_projectId] ? _read.result : nil; }
- (BOOL)writable { NSDictionary *p = [self fresh]; return p && [p[@"canWrite"] isEqual:@YES] && WriteOn(_core, [self instructionsMode] ? @"projects.instructions.update" : @"projects.update"); }
- (BOOL)canSave {
    if (self.busy) return NO;
    if ([self create]) return [[_name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] length] > 0;
    return [self writable] && _dirty;
}
- (RCFormRow *)field:(RCFormRowKind)kind title:(NSString *)title text:(NSString *)text placeholder:(NSString *)placeholder max:(NSUInteger)max key:(NSString *)key {
    RCFormRow *r = [RCFormRow rowWithKind:kind title:title]; r.text = text; r.placeholder = placeholder; r.maxLength = max; r.userInfo = key; r.identifier = [@"chat.project_editor." stringByAppendingString:key]; return r;
}
- (void)render {
    NSMutableArray *sections = [NSMutableArray array]; NSDictionary *p = [self fresh];
    if ([self create]) {
        [sections addObject:[RCFormSection sectionWithTitle:OR6L(@"Project") rows:@[
            [self field:RCFormRowText title:OR6L(@"Title") text:_name placeholder:OR6L(@"Project title") max:240 key:@"name"],
            [self field:RCFormRowText title:OR6L(@"Icon") text:_emoji placeholder:OR6L(@"Emoji (optional)") max:64 key:@"emoji"]]]];
        RCFormRow *sw = [RCFormRow rowWithKind:RCFormRowSwitch title:OR6L(@"Keep memory inside this project")]; sw.on = _projectOnly; sw.identifier = @"chat.project_editor.project_only";
        RCFormSection *m = [RCFormSection sectionWithTitle:OR6L(@"Memory") rows:@[sw]];
        m.footer = OR6L(@"When on, chats in this project use only memories from this project.");
        [sections addObject:m];
    } else if (!p) {
        NSMutableArray *rows = [NSMutableArray array];
        if (![self addStateOf:_read to:rows empty:nil hasItems:NO identifier:@"chat.project_editor"]) [rows addObject:[self note:OR6L(@"Loading…")]];
        [sections addObject:[RCFormSection sectionWithTitle:nil rows:rows]];
    } else if ([self instructionsMode]) {
        NSString *current = _instructions ?: ([p[@"instructions"] isKindOfClass:NSString.class] ? p[@"instructions"] : nil);
        RCFormRow *r;
        if ([self writable]) r = [self field:RCFormRowLongText title:OR6L(@"Instructions") text:current placeholder:OR6L(@"How should ChatGPT answer in this project?") max:16000 key:@"instructions"];
        else r = [self note:(current.length ? current : OR6L(@"No instructions."))];
        RCFormSection *s = [RCFormSection sectionWithTitle:OR6Chat6Text(p[@"name"], nil) rows:@[r]];
        s.footer = [self writable] ? OR6L(@"ChatGPT follows these instructions in every chat of this project. Up to 16,000 characters.") : OR6L(@"These instructions cannot be changed from ChatGPT X.");
        [sections addObject:s];
    } else if ([self writable]) {
        [sections addObject:[RCFormSection sectionWithTitle:OR6L(@"Project") rows:@[
            [self field:RCFormRowText title:OR6L(@"Title") text:(_name ?: p[@"name"]) placeholder:OR6L(@"Project title") max:240 key:@"name"],
            [self field:RCFormRowText title:OR6L(@"Icon") text:(_emoji ?: OR6Chat6Text(p[@"emoji"], nil)) placeholder:OR6L(@"Emoji (optional)") max:64 key:@"emoji"]]]];
    } else {
        RCFormSection *s = [RCFormSection sectionWithTitle:nil rows:@[[self value:OR6L(@"Title") value:OR6Chat6Text(p[@"name"], @"—") info:nil identifier:@"chat.project_editor.name"]]];
        s.footer = OR6L(@"This project cannot be changed from ChatGPT X."); [sections addObject:s];
    }
    self.sections = sections; _save.enabled = [self canSave];
    if (!self.busy) self.navigationItem.rightBarButtonItem = ([self create] || !p || [self writable]) ? _save : nil; // read-only: no Save at all
}
- (void)form:(RCFormViewController *)f didChangeTextOfRow:(RCFormRow *)row {
    (void)f; NSString *t = [[row.text ?: @"" copy] autorelease];
    if ([row.userInfo isEqual:@"name"]) { [_name release]; _name = [t retain]; }
    else if ([row.userInfo isEqual:@"emoji"]) { [_emoji release]; _emoji = [t retain]; }
    else if ([row.userInfo isEqual:@"instructions"]) { [_instructions release]; _instructions = [t retain]; }
    else return;
    _dirty = YES; _save.enabled = [self canSave];
}
- (void)form:(RCFormViewController *)f didToggleRow:(RCFormRow *)row { (void)f; if ([row.identifier isEqual:@"chat.project_editor.project_only"]) { _projectOnly = row.on; _dirty = YES; } }
- (void)leave { UINavigationController *nc = self.navigationController; if (nc.topViewController == self) [nc popViewControllerAnimated:YES]; }
- (void)cancel {
    if (self.busy) return; [self endEditing];
    if (!_dirty) { [self leave]; return; }
    OR6Chat6Confirm(self.view.window ?: self.view, OR6L(@"Discard your changes?"), OR6L(@"Discard"), YES, ^{ [self leave]; });
}
- (void)save {
    [self endEditing]; if (![self canSave]) return;
    NSString *problem = nil, *op, *intent, *done; NSDictionary *p;
    if ([self create]) {
        p = OR6Chat6ProjectCreateRequest(_name, _emoji, _projectOnly, &problem); op = @"projects.create"; intent = OR6Chat6ProjectIntent(op, _name); done = OR6L(@"The project was created.");
    } else if ([self instructionsMode]) {
        p = OR6Chat6ProjectInstructionsRequest([self fresh], _instructions, &problem); op = @"projects.instructions.update"; intent = OR6Chat6ProjectIntent(op, _projectId); done = OR6L(@"The instructions were saved.");
    } else {
        p = OR6Chat6ProjectUpdateRequest([self fresh], _name, _emoji, &problem); op = @"projects.update"; intent = OR6Chat6ProjectIntent(op, _projectId); done = OR6L(@"The project was saved.");
    }
    if (!p) { OR6Chat6Say(self.view.window ?: self.view, problem ?: OR6L(@"This change cannot be sent now.")); return; }
    BOOL create = [self create]; void (^saved)(NSString *) = [[_saved copy] autorelease];
    OR6Chat6RunFormWrite(self, _core, op, p, intent, @"catalog.reconcile", done, ^(NSDictionary *r) {
        _dirty = NO;
        NSString *pid = create ? OR6Chat6Text(r[@"targetId"], nil) : _projectId;
        UINavigationController *nc = self.navigationController;
        if (nc.topViewController == self) [nc popViewControllerAnimated:!(create && pid)]; // the new project opens right after
        if (saved) saved(pid);
    });
}
- (void)dealloc { [_mode release]; [_projectId release]; [_name release]; [_emoji release]; [_instructions release]; [_saved release]; [_save release]; [super dealloc]; }
@end

UIViewController *OR6Chat6CreateProjectEditor(OR6APICore *core, NSDictionary *project, void (^saved)(NSString *projectId)) {
    if (!project) return OR6Chat6ProjectCreateAvailable(core) ? [[[OR6Chat6ProjectEditor alloc] initWithCore:core mode:@"create" project:nil saved:saved] autorelease] : nil;
    NSString *pid = OR6Chat6Text(project[@"projectId"], nil);
    if (!pid || !WriteOn(core, @"projects.update") || !OR6Chat6On(core, @"projects.detail")) return nil;
    return [[[OR6Chat6ProjectEditor alloc] initWithCore:core mode:@"edit" project:pid saved:saved] autorelease];
}

#pragma mark - Project actions

NSArray *OR6Chat6ProjectActions(OR6APICore *core, NSDictionary *project) {
    NSMutableArray *a = [NSMutableArray array];
    if (![project isKindOfClass:NSDictionary.class] || !OR6Chat6Text(project[@"projectId"], nil) || ![project[@"canWrite"] isEqual:@YES] || [project[@"shared"] isEqual:@YES]) return a;
    if (WriteOn(core, @"projects.update") && OR6Chat6On(core, @"projects.detail")) [a addObject:@{@"key": @"edit", @"title": OR6L(@"Edit project…")}];
    if (OR6Chat6On(core, @"projects.detail")) [a addObject:@{@"key": @"instructions", @"title": OR6L(@"Instructions…")}];
    if (WriteOn(core, @"projects.delete")) [a addObject:@{@"key": @"delete", @"title": OR6L(@"Delete project"), @"destructive": @YES}];
    return a;
}

void OR6Chat6RunProjectAction(UIViewController *host, OR6APICore *core, NSString *key, NSDictionary *project, id<OR6Chat7Navigator> nav, void (^changed)(NSString *change)) {
    (void)nav;
    NSString *pid = OR6Chat6Text(project[@"projectId"], nil); BOOL offered = NO;
    for (NSDictionary *x in OR6Chat6ProjectActions(core, project)) if ([x[@"key"] isEqual:key]) offered = YES;
    if (!pid || !offered || !host) return;
    void (^c)(NSString *) = [[changed copy] autorelease];
    if ([key isEqual:@"edit"] || [key isEqual:@"instructions"]) {
        OR6Chat6ProjectEditor *e = [[[OR6Chat6ProjectEditor alloc] initWithCore:core mode:key project:pid saved:^(NSString *unused) { (void)unused; if (c) c([key isEqual:@"edit"] ? @"updated" : @"instructions"); }] autorelease];
        [host.navigationController pushViewController:e animated:YES]; return;
    }
    if ([key isEqual:@"delete"]) {
        NSString *name = OR6Chat6Text(project[@"name"], OR6L(@"Untitled"));
        NSString *title = [NSString stringWithFormat:OR6L(@"Delete the project «%@»? It is deleted from your ChatGPT account and cannot be restored in ChatGPT X."), name];
        UIView *v = host.view.window ?: host.view; NSDictionary *params = @{@"projectId": pid}; NSString *intent = OR6Chat6ProjectIntent(@"projects.delete", pid);
        void (^finished)(NSDictionary *) = ^(NSDictionary *r) { (void)r; if (c) c(@"deleted"); };
        OR6Chat6Confirm(v, title, OR6L(@"Delete project"), YES, ^{
            if ([host isKindOfClass:RCFormViewController.class]) OR6Chat6RunFormWrite((RCFormViewController *)host, core, @"projects.delete", params, intent, @"catalog.reconcile", OR6L(@"The project was deleted."), finished);
            else OR6Chat7RunWrite(v, core, @"projects.delete", params, intent, @"catalog.reconcile", OR6L(@"The project was deleted."), finished);
        });
    }
}
