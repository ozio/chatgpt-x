// «Задачи» (prototype s-tools.js tasksScreen, stage 6, API6D): the paged list (tasks.list with the
// opaque nextCursor sent back unchanged and a «Show» filter: all / scheduled / paused / finished),
// «New task…» (tasks.create), and the task card (tasks.get): request, schedule, next runs, time
// zone, timing, model. The card's writes — «Active» (tasks.setEnabled), «Edit…» (tasks.update),
// «Change schedule…» (tasks.setSchedule), «Run now» (tasks.runNow), «Delete task» (tasks.delete)
// — are bound to the task's freshly read revision, appear only for a task the account can manage
// and only when the operation is granted, and run after an explicit tap (confirmation for run and
// delete). The editors read the task again (tasks.get) before they offer anything. The schedule is
// edited with form rows and choice lists only (the kit has no date picker); a schedule this editor
// cannot represent is shown read-only and sent back unchanged. An unknown outcome offers only the
// read-only tasks.reconcile, never a resend.
#import "OR6Chat6Base.h"
#import "OR6Chat6TasksLogic.h"
#import "../../chat/OR6ChatScreens.h"
#import "RCHUD.h"

#pragma mark - Form write (shared with OR6Chat6Projects.m)

// One remote write the form waits for: the form is busy (taps ignored, its bar buttons off) until
// the write ends, so a second tap cannot send a second write. Stock feedback like OR6Chat7RunWrite:
// «Saving…», the done HUD (or «not read back yet»), «Result unknown» → «Check» (read-only reconcile,
// never a resend), failures as a text HUD. `done` runs only after a confirmed write.
BOOL OR6Chat6RunFormWrite(RCFormViewController *form, OR6APICore *core, NSString *op, NSDictionary *params, NSString *intent, NSString *reconcile, NSString *doneText, void (^done)(NSDictionary *receipt));

@interface OR6Chat6FormWrite : NSObject <OR6Chat8ModelDelegate, UIAlertViewDelegate> {
@public OR6Chat7Write *_write; RCFormViewController *_form; NSString *_done; void (^_finished)(NSDictionary *); RCHUD *_hud;
}
@end
static NSMutableSet *gFormWrites; // each write stays alive until it ends (-end)
@implementation OR6Chat6FormWrite
- (UIView *)view { return _form.view.window ?: _form.view; }
- (void)setBusy:(BOOL)busy {
    _form.busy = busy; _form.navigationItem.leftBarButtonItem.enabled = !busy; _form.navigationItem.hidesBackButton = busy;
}
- (void)chat8ModelChanged:(id)m {
    (void)m; NSString *p = _write.phase;
    if ([p isEqual:@"running"] || [p isEqual:@"reconciling"]) return;
    [_hud hide]; [_hud release]; _hud = nil;
    if ([p isEqual:@"done"]) {
        [RCHUD showText:(_write.verified ? _done : [NSString stringWithFormat:@"%@ %@", _done, OR6L(@"(not read back yet)")]) kind:RCHUDDone inView:[self view] seconds:1.4];
        [self setBusy:NO]; void (^f)(NSDictionary *) = [[_finished retain] autorelease]; NSDictionary *r = [[_write.receipt retain] autorelease];
        [self end]; if (f) f(r); return;
    }
    if ([p isEqual:@"uncertain"]) {
        UIAlertView *a = [[[UIAlertView alloc] initWithTitle:OR6L(@"Result unknown") message:OR6L(@"The connection ended before the service confirmed the change. It is not sent again. Check the current state?") delegate:self cancelButtonTitle:OR6L(@"Later") otherButtonTitles:OR6L(@"Check"), nil] autorelease];
        [a show]; return;
    }
    [RCHUD showText:OR6Chat7ErrorText(_write.error) kind:RCHUDTextOnly inView:[self view] seconds:2.2];
    [self setBusy:NO]; [self end];
}
- (void)alertView:(UIAlertView *)a clickedButtonAtIndex:(NSInteger)i {
    if (i != a.cancelButtonIndex && [_write reconcile]) { _hud = [[RCHUD showText:OR6L(@"Checking…") kind:RCHUDBusy inView:[self view] seconds:0] retain]; return; }
    [self setBusy:NO]; [self end];
}
- (void)end { _write.delegate = nil; [[self retain] autorelease]; [gFormWrites removeObject:self]; }
- (void)dealloc { [_write release]; [_form release]; [_done release]; [_finished release]; [_hud release]; [super dealloc]; }
@end

BOOL OR6Chat6RunFormWrite(RCFormViewController *form, OR6APICore *core, NSString *op, NSDictionary *params, NSString *intent, NSString *reconcile, NSString *doneText, void (^done)(NSDictionary *)) {
    UIView *view = form.view.window ?: form.view;
    if (form.busy) return NO;
    if (OR6Chat7IsUnresolved(intent)) { OR6Chat6Say(view, OR6L(@"The previous attempt has an unknown result. It is not sent again.")); return NO; }
    OR6Chat6FormWrite *w = [[[OR6Chat6FormWrite alloc] init] autorelease];
    if (!gFormWrites) gFormWrites = [NSMutableSet new]; [gFormWrites addObject:w]; // kept until the write ends (-end)
    w->_write = [[OR6Chat7Write alloc] initWithCore:core reconcile:reconcile]; w->_write.delegate = w; w->_form = [form retain]; w->_done = [doneText copy]; w->_finished = [done copy];
    [w setBusy:YES];
    w->_hud = [[RCHUD showText:OR6L(@"Saving…") kind:RCHUDBusy inView:view seconds:0] retain];
    if (![w->_write perform:op parameters:params intent:intent]) {
        [w->_hud hide]; [w setBusy:NO]; OR6Chat6Say(view, OR6L(@"This change cannot be sent now.")); [w end]; return NO;
    }
    return YES;
}

#pragma mark - Shared pieces

static NSArray *NextRuns(NSDictionary *t, NSUInteger max) {
    NSMutableArray *out = [NSMutableArray array];
    for (id v in [t[@"nextRunTimes"] isKindOfClass:NSArray.class] ? t[@"nextRunTimes"] : @[]) { NSString *d = OR6Chat6RelativeDate(v); if (d) [out addObject:d]; if (out.count >= max) break; }
    return out;
}
static NSString *ScheduleText(NSDictionary *t) {
    NSTimeZone *tz = [t[@"timezone"] isKindOfClass:NSString.class] ? [NSTimeZone timeZoneWithName:t[@"timezone"]] : nil;
    return (tz ? OR6Chat6TaskScheduleText(OR6Chat6TaskScheduleParse(t[@"schedule"], tz)) : nil) ?: OR6L(@"Custom schedule");
}
static NSString *ZoneTitle(NSString *name) { return [name stringByReplacingOccurrencesOfString:@"_" withString:@" "]; }
static BOOL WriteOn(OR6APICore *core, NSString *op) { return OR6Chat6On(core, op) && OR6Chat6On(core, @"tasks.reconcile"); }

#pragma mark - Editor (create / edit / schedule)

@interface OR6Chat6TaskEditor : OR6Chat6Form { NSString *_mode, *_taskId; NSMutableDictionary *_state; void (^_changed)(void); BOOL _dirty; UIBarButtonItem *_save; }
- (id)initWithCore:(OR6APICore *)core mode:(NSString *)mode task:(NSString *)taskId changed:(void (^)(void))changed;
@end
@implementation OR6Chat6TaskEditor
- (id)initWithCore:(OR6APICore *)core mode:(NSString *)mode task:(NSString *)taskId changed:(void (^)(void))changed {
    NSString *title = [mode isEqual:@"create"] ? OR6L(@"New task") : [mode isEqual:@"schedule"] ? OR6L(@"Schedule") : OR6L(@"Edit task");
    if ((self = [super initWithCore:core navigator:nil title:title])) {
        _mode = [mode copy]; _taskId = [taskId copy]; _changed = [changed copy];
        self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:OR6L(@"Cancel") style:UIBarButtonItemStyleBordered target:self action:@selector(cancel)] autorelease];
        _save = [[UIBarButtonItem alloc] initWithTitle:OR6L(@"Save") style:UIBarButtonItemStyleDone target:self action:@selector(save)];
        _save.enabled = NO; self.navigationItem.rightBarButtonItem = _save;
    }
    return self;
}
- (BOOL)create { return [_mode isEqual:@"create"]; }
- (void)load {
    if ([self create]) { [_state release]; _state = [OR6Chat6TaskEditorState(nil, [NSDate date], [NSTimeZone localTimeZone]) retain]; [self render]; return; }
    [_state release]; _state = nil; _dirty = NO;
    [_read perform:@"tasks.get" parameters:@{@"taskId": _taskId}]; [self render]; // the fresh task and revision
}
- (NSDictionary *)fresh { return [_read.result[@"id"] isEqual:_taskId] ? _read.result : nil; }
- (void)chat8ModelChanged:(id)m {
    if (m == _read && !_read.busy && !_state && [self fresh]) _state = [OR6Chat6TaskEditorState([self fresh], [NSDate date], [NSTimeZone localTimeZone]) retain];
    [super chat8ModelChanged:m];
}
- (BOOL)canSave {
    if (!_state || self.busy) return NO;
    if ([self create]) return YES;
    if (![[self fresh][@"canManage"] isEqual:@YES]) return NO;
    return [_mode isEqual:@"schedule"] ? (OR6Chat6TaskScheduleEditable(_state) && [_state[@"scheduleEdited"] isEqual:@YES]) : _dirty;
}
- (RCFormRow *)choice:(NSString *)title value:(NSString *)value key:(NSString *)key {
    RCFormRow *r = [self value:title value:value info:key identifier:[@"chat.task_editor." stringByAppendingString:key]]; return r;
}
- (NSString *)frequencyTitle:(NSString *)f {
    NSUInteger i = [@[@"once", @"daily", @"weekdays", @"weekly", @"monthly"] indexOfObject:f ?: @""];
    return i == NSNotFound ? OR6L(@"Custom schedule") : @[OR6L(@"Once"), OR6L(@"Every day"), OR6L(@"On weekdays"), OR6L(@"Every week"), OR6L(@"Every month")][i];
}
- (NSTimeZone *)taskZone { return [NSTimeZone timeZoneWithName:_state[@"timezone"]] ?: [NSTimeZone localTimeZone]; }
- (NSString *)dayTitle {
    NSCalendar *cal = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease]; cal.timeZone = [self taskZone];
    NSDateComponents *c = [[[NSDateComponents alloc] init] autorelease]; c.year = [_state[@"year"] integerValue]; c.month = [_state[@"month"] integerValue]; c.day = [_state[@"day"] integerValue]; c.hour = 12;
    NSDate *d = [cal dateFromComponents:c]; if (!d) return @"—";
    NSDateFormatter *f = [[[NSDateFormatter alloc] init] autorelease]; f.timeZone = [self taskZone]; f.dateFormat = [NSDateFormatter dateFormatFromTemplate:@"EEEdMMMMy" options:0 locale:[NSLocale currentLocale]];
    return [f stringFromDate:d];
}
- (void)render {
    if (!_state) {
        NSMutableArray *rows = [NSMutableArray array];
        if (![self addStateOf:_read to:rows empty:nil hasItems:NO identifier:@"chat.task_editor"]) [rows addObject:[self note:OR6L(@"Loading…")]];
        self.sections = @[[RCFormSection sectionWithTitle:nil rows:rows]]; _save.enabled = NO; return;
    }
    NSMutableArray *sections = [NSMutableArray array];
    if (![_mode isEqual:@"schedule"]) {
        RCFormRow *t = [RCFormRow rowWithKind:RCFormRowText title:OR6L(@"Title")]; t.text = _state[@"title"]; t.placeholder = OR6L(@"Task title"); t.maxLength = 1000; t.userInfo = @"title"; t.identifier = @"chat.task_editor.title";
        RCFormRow *p = [RCFormRow rowWithKind:RCFormRowLongText title:OR6L(@"Task request")]; p.text = _state[@"prompt"]; p.placeholder = OR6L(@"What should ChatGPT do?"); p.maxLength = 16000; p.userInfo = @"prompt"; p.identifier = @"chat.task_editor.prompt";
        [sections addObject:[RCFormSection sectionWithTitle:OR6L(@"Task") rows:@[t, p]]];
    }
    NSString *timing = OR6Chat6TaskTimingText(_state[@"timingMode"]);
    if (OR6Chat6TaskScheduleEditable(_state)) {
        NSString *f = _state[@"frequency"]; NSMutableArray *rows = [NSMutableArray arrayWithObject:[self choice:OR6L(@"Repeat") value:[self frequencyTitle:f] key:@"frequency"]];
        if ([f isEqual:@"once"]) [rows addObject:[self choice:OR6L(@"Date") value:[self dayTitle] key:@"date"]];
        if ([f isEqual:@"monthly"]) [rows addObject:[self choice:OR6L(@"Day of the month") value:[_state[@"monthDay"] description] key:@"monthDay"]];
        [rows addObject:[self choice:OR6L(@"Hour") value:[NSString stringWithFormat:@"%02d", [_state[@"hour"] intValue]] key:@"hour"]];
        [rows addObject:[self choice:OR6L(@"Minute") value:[NSString stringWithFormat:@"%02d", [_state[@"minute"] intValue]] key:@"minute"]];
        [rows addObject:[self choice:OR6L(@"Time zone") value:ZoneTitle(_state[@"timezone"]) key:@"timezone"]];
        if (![self create] && timing) [rows addObject:[self value:OR6L(@"Timing") value:timing info:nil identifier:@"chat.task_editor.timing"]];
        RCFormSection *s = [RCFormSection sectionWithTitle:OR6L(@"Schedule") rows:rows];
        if (![f isEqual:@"once"]) s.footer = OR6Chat6TaskScheduleText(_state);
        [sections addObject:s];
        if ([f isEqual:@"weekly"]) {
            NSDateFormatter *df = [[[NSDateFormatter alloc] init] autorelease]; NSArray *names = df.standaloneWeekdaySymbols; NSMutableArray *days = [NSMutableArray array]; // Sunday first
            for (int n = 1; n <= 7 && names.count == 7; n++) {
                RCFormRow *d = [RCFormRow rowWithKind:RCFormRowCheck title:names[(NSUInteger)(n % 7)]]; d.checked = [_state[@"weekdays"] containsObject:@(n)]; d.userInfo = @{@"weekday": @(n)}; d.identifier = @"chat.task_editor.weekday"; [days addObject:d];
            }
            [sections addObject:[RCFormSection sectionWithTitle:OR6L(@"Days of the week") rows:days]];
        }
    } else {
        NSMutableArray *rows = [NSMutableArray arrayWithObject:[self value:OR6L(@"Schedule") value:ScheduleText([self fresh] ?: @{}) info:nil identifier:@"chat.task_editor.schedule"]];
        if ([_state[@"timezone"] length]) [rows addObject:[self value:OR6L(@"Time zone") value:ZoneTitle(_state[@"timezone"]) info:nil identifier:@"chat.task_editor.timezone"]];
        if (timing) [rows addObject:[self value:OR6L(@"Timing") value:timing info:nil identifier:@"chat.task_editor.timing"]];
        RCFormSection *s = [RCFormSection sectionWithTitle:OR6L(@"Schedule") rows:rows];
        s.footer = [_state[@"timingMode"] isEqual:@"condition_watch"] ? OR6L(@"This task runs when its condition is met. Its schedule cannot be changed in ChatGPT X.") : OR6L(@"ChatGPT X cannot edit this schedule. It is kept exactly as it is.");
        [sections addObject:s];
    }
    if (![self create] && ![[self fresh][@"canManage"] isEqual:@YES]) { RCFormSection *s = [RCFormSection sectionWithTitle:nil rows:@[]]; s.footer = OR6L(@"Changes to this task are not available."); [sections addObject:s]; }
    self.sections = sections; _save.enabled = [self canSave];
}
- (void)form:(RCFormViewController *)f didChangeTextOfRow:(RCFormRow *)row {
    (void)f; if (!_state || ![row.userInfo isKindOfClass:NSString.class]) return;
    _state[row.userInfo] = row.text ?: @""; _dirty = YES; _save.enabled = [self canSave];
}
- (void)scheduleChanged { _state[@"scheduleEdited"] = @YES; _dirty = YES; [self render]; }
- (void)choose:(NSString *)title options:(NSArray *)options selected:(NSUInteger)selected apply:(void (^)(NSUInteger i))apply {
    [self endEditing];
    void (^a)(NSUInteger) = [[apply copy] autorelease];
    OR6ChatChoiceController *c = [[[OR6ChatChoiceController alloc] initWithTitle:title options:options selected:selected footer:nil choose:^(NSUInteger i) { a(i); [self scheduleChanged]; }] autorelease];
    [self.navigationController pushViewController:c animated:YES];
}
- (void)chooseKey:(NSString *)key {
    NSMutableDictionary *s = _state;
    if ([key isEqual:@"frequency"]) {
        NSArray *keys = @[@"once", @"daily", @"weekdays", @"weekly", @"monthly"]; NSMutableArray *titles = [NSMutableArray array]; for (NSString *k in keys) [titles addObject:[self frequencyTitle:k]];
        [self choose:OR6L(@"Repeat") options:titles selected:[keys indexOfObject:s[@"frequency"]] apply:^(NSUInteger i) { s[@"frequency"] = keys[i]; }];
    } else if ([key isEqual:@"hour"]) {
        NSMutableArray *o = [NSMutableArray array]; for (int h = 0; h < 24; h++) [o addObject:[NSString stringWithFormat:@"%02d", h]];
        [self choose:OR6L(@"Hour") options:o selected:(NSUInteger)[s[@"hour"] integerValue] apply:^(NSUInteger i) { s[@"hour"] = @(i); }];
    } else if ([key isEqual:@"minute"]) {
        NSMutableArray *values = [NSMutableArray array], *o = [NSMutableArray array]; int cur = [s[@"minute"] intValue];
        for (int m = 0; m < 60; m += 5) { if (cur > m - 5 && cur < m && cur % 5) [values addObject:@(cur)]; [values addObject:@(m)]; }
        if (cur > 55) [values addObject:@(cur)];
        for (NSNumber *v in values) [o addObject:[NSString stringWithFormat:@"%02d", v.intValue]];
        [self choose:OR6L(@"Minute") options:o selected:[values indexOfObject:@(cur)] apply:^(NSUInteger i) { s[@"minute"] = values[i]; }];
    } else if ([key isEqual:@"monthDay"]) {
        NSMutableArray *values = [NSMutableArray array], *o = [NSMutableArray array]; NSInteger cur = [s[@"monthDay"] integerValue];
        for (NSInteger d = 1; d <= 28; d++) [values addObject:@(d)]; if (cur > 28 && cur <= 31) [values addObject:@(cur)];
        for (NSNumber *v in values) [o addObject:v.description];
        [self choose:OR6L(@"Day of the month") options:o selected:[values indexOfObject:@(cur)] apply:^(NSUInteger i) { s[@"monthDay"] = values[i]; }];
    } else if ([key isEqual:@"date"]) {
        NSCalendar *cal = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease]; cal.timeZone = [self taskZone];
        NSDateFormatter *df = [[[NSDateFormatter alloc] init] autorelease]; df.timeZone = [self taskZone]; df.dateFormat = [NSDateFormatter dateFormatFromTemplate:@"EEEdMMMM" options:0 locale:[NSLocale currentLocale]];
        NSMutableArray *days = [NSMutableArray array], *o = [NSMutableArray array]; NSUInteger selected = NSNotFound;
        NSDateComponents *noon = [cal components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit fromDate:[NSDate date]]; noon.hour = 12; NSDate *base = [cal dateFromComponents:noon];
        for (NSInteger i = 0; i < 60; i++) {
            NSDateComponents *add = [[[NSDateComponents alloc] init] autorelease]; add.day = i; NSDate *d = [cal dateByAddingComponents:add toDate:base options:0];
            NSDateComponents *c = [cal components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit fromDate:d];
            [days addObject:@[@(c.year), @(c.month), @(c.day)]];
            [o addObject:i == 0 ? OR6L(@"Today") : i == 1 ? OR6L(@"Tomorrow") : [df stringFromDate:d]];
            if (c.year == [s[@"year"] integerValue] && c.month == [s[@"month"] integerValue] && c.day == [s[@"day"] integerValue]) selected = (NSUInteger)i;
        }
        [self choose:OR6L(@"Date") options:o selected:selected apply:^(NSUInteger i) { s[@"year"] = days[i][0]; s[@"month"] = days[i][1]; s[@"day"] = days[i][2]; }];
    } else if ([key isEqual:@"timezone"]) {
        NSMutableArray *names = [NSMutableArray array], *o = [NSMutableArray array];
        for (NSString *n in [@[s[@"timezone"] ?: @"", [NSTimeZone localTimeZone].name ?: @""] arrayByAddingObjectsFromArray:[[NSTimeZone knownTimeZoneNames] sortedArrayUsingSelector:@selector(compare:)]])
            if (n.length && ![names containsObject:n] && [NSTimeZone timeZoneWithName:n]) { [names addObject:n]; [o addObject:ZoneTitle(n)]; }
        [self choose:OR6L(@"Time zone") options:o selected:[names indexOfObject:s[@"timezone"] ?: @""] apply:^(NSUInteger i) { s[@"timezone"] = names[i]; }];
    }
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    if (_state && OR6Chat6TaskScheduleEditable(_state) && [row.userInfo isKindOfClass:NSDictionary.class] && row.userInfo[@"weekday"]) {
        [self endEditing]; NSMutableArray *w = [NSMutableArray arrayWithArray:[_state[@"weekdays"] isKindOfClass:NSArray.class] ? _state[@"weekdays"] : @[]]; id n = row.userInfo[@"weekday"];
        if ([w containsObject:n]) [w removeObject:n]; else [w addObject:n];
        [w sortUsingSelector:@selector(compare:)]; _state[@"weekdays"] = w; [self scheduleChanged]; return;
    }
    if (_state && OR6Chat6TaskScheduleEditable(_state) && [row.userInfo isKindOfClass:NSString.class] && ![row.userInfo isEqual:@"retry"]) { [self chooseKey:row.userInfo]; return; }
    [super form:f didSelectRow:row];
}
- (void)leave { UINavigationController *nc = self.navigationController; if (nc.topViewController == self) [nc popViewControllerAnimated:YES]; }
- (void)cancel {
    if (self.busy) return; [self endEditing];
    if (!_dirty) { [self leave]; return; }
    OR6Chat6Confirm(self.view.window ?: self.view, OR6L(@"Discard your changes?"), OR6L(@"Discard"), YES, ^{ [self leave]; });
}
- (void)save {
    [self endEditing]; if (![self canSave]) return;
    NSString *problem = nil, *op = nil, *intent = nil, *done = nil; NSDictionary *p = nil; NSDate *now = [NSDate date];
    if ([self create]) { p = OR6Chat6TaskCreateRequest(_state, now, &problem); op = @"tasks.create"; intent = [@"tasks.create:" stringByAppendingString:[[_state[@"title"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString]]; done = OR6L(@"The task was created."); }
    else if ([_mode isEqual:@"schedule"]) { p = OR6Chat6TaskSetScheduleRequest([self fresh], _state, now, &problem); op = @"tasks.setSchedule"; intent = [@"tasks.setSchedule:" stringByAppendingString:_taskId]; done = OR6L(@"The schedule was changed."); }
    else { p = OR6Chat6TaskUpdateRequest([self fresh], _state, now, &problem); op = @"tasks.update"; intent = [@"tasks.update:" stringByAppendingString:_taskId]; done = OR6L(@"The task was saved."); }
    if (!p) { OR6Chat6Say(self.view.window ?: self.view, problem ?: OR6L(@"This change cannot be sent now.")); return; }
    void (^changed)(void) = [[_changed copy] autorelease];
    OR6Chat6RunFormWrite(self, _core, op, p, intent, @"tasks.reconcile", done, ^(NSDictionary *r) { (void)r; _dirty = NO; if (changed) changed(); [self leave]; });
}
- (void)dealloc { [_mode release]; [_taskId release]; [_state release]; [_changed release]; [_save release]; [super dealloc]; }
@end

#pragma mark - Card

@interface OR6Chat6TaskCard : OR6Chat6Form { NSString *_taskId; void (^_changed)(void); }
- (id)initWithCore:(OR6APICore *)core task:(NSDictionary *)task changed:(void (^)(void))changed;
@end
@implementation OR6Chat6TaskCard
- (id)initWithCore:(OR6APICore *)core task:(NSDictionary *)t changed:(void (^)(void))changed {
    if ((self = [super initWithCore:core navigator:nil title:OR6Chat6Text(t[@"title"], OR6L(@"Task"))])) { _taskId = [t[@"id"] copy]; _changed = [changed copy]; }
    return self;
}
- (void)load { [_read perform:@"tasks.get" parameters:@{@"taskId": _taskId}]; [self render]; }
- (NSDictionary *)task { return [_read.result[@"id"] isEqual:_taskId] ? _read.result : nil; }
// A write is offered only for a task read now (its revision), that the account manages, when granted.
- (BOOL)can:(NSString *)op { NSDictionary *t = [self task]; return t && !_read.busy && OR6Chat6Text(t[@"revision"], nil) && [t[@"canManage"] isEqual:@YES] && WriteOn(_core, op); }
- (void)render {
    NSDictionary *t = [self task]; NSMutableArray *sections = [NSMutableArray array];
    if (!t) { NSMutableArray *rows = [NSMutableArray array]; if (![self addStateOf:_read to:rows empty:nil hasItems:NO identifier:@"chat.task"]) [rows addObject:[self note:OR6L(@"Loading…")]]; self.sections = @[[RCFormSection sectionWithTitle:nil rows:rows]]; return; }
    self.title = OR6Chat6Text(t[@"title"], OR6L(@"Task"));
    BOOL on = [t[@"enabled"] isEqual:@YES];
    RCFormRow *prompt = [RCFormRow rowWithKind:RCFormRowValue title:OR6L(@"Task request")]; prompt.subtitle = OR6Chat6Text(t[@"prompt"], @"—"); prompt.enabled = NO; prompt.identifier = @"chat.task.prompt";
    NSMutableArray *rows = [NSMutableArray arrayWithObject:prompt];
    [rows addObject:[self value:OR6L(@"Schedule") value:ScheduleText(t) info:nil identifier:@"chat.task.schedule"]];
    if (OR6Chat6Text(t[@"timezone"], nil)) [rows addObject:[self value:OR6L(@"Time zone") value:ZoneTitle(t[@"timezone"]) info:nil identifier:@"chat.task.timezone"]];
    NSString *timing = OR6Chat6TaskTimingText(t[@"timingMode"]); if (timing && ![t[@"timingMode"] isEqual:@"exact_schedule"]) [rows addObject:[self value:OR6L(@"Timing") value:timing info:nil identifier:@"chat.task.timing"]];
    if (OR6Chat6Text(t[@"modelId"], nil)) [rows addObject:[self value:OR6L(@"Model") value:t[@"modelId"] info:nil identifier:@"chat.task.model"]];
    if ([self can:@"tasks.setEnabled"]) { RCFormRow *sw = [RCFormRow rowWithKind:RCFormRowSwitch title:OR6L(@"Active")]; sw.on = on; sw.identifier = @"chat.task.enabled"; [rows addObject:sw]; }
    else [rows addObject:[self value:OR6L(@"Status") value:(on ? OR6L(@"Active") : OR6L(@"Paused")) info:nil identifier:@"chat.task.status"]];
    [sections addObject:[RCFormSection sectionWithTitle:nil rows:rows]];
    NSArray *next = on ? NextRuns(t, 5) : @[]; NSMutableArray *runs = [NSMutableArray array];
    for (NSString *d in next) { RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:d]; r.enabled = NO; r.identifier = @"chat.task.next"; [runs addObject:r]; }
    if (!runs.count) [runs addObject:[self value:OR6L(@"Next run") value:OR6L(@"Not scheduled") info:nil identifier:@"chat.task.next"]];
    [sections addObject:[RCFormSection sectionWithTitle:OR6L(@"Next runs") rows:runs]];
    NSMutableArray *acts = [NSMutableArray array];
    if ([self can:@"tasks.update"]) [acts addObject:[self value:OR6L(@"Edit…") value:nil info:@"edit" identifier:@"chat.task.edit"]];
    if ([self can:@"tasks.setSchedule"]) {
        if (OR6Chat6TaskScheduleEditable(OR6Chat6TaskEditorState(t, [NSDate date], [NSTimeZone localTimeZone]))) [acts addObject:[self value:OR6L(@"Change schedule…") value:nil info:@"schedule" identifier:@"chat.task.change_schedule"]];
        else [acts addObject:[self note:([t[@"timingMode"] isEqual:@"condition_watch"] ? OR6L(@"This task runs when its condition is met. Its schedule cannot be changed in ChatGPT X.") : OR6L(@"ChatGPT X cannot edit this schedule. It is kept exactly as it is."))]];
    }
    if ([self can:@"tasks.runNow"] && [t[@"runNowAllowed"] isEqual:@YES]) [acts addObject:[self button:OR6L(@"Run now") info:@"run" identifier:@"chat.task.run"]];
    if ([self can:@"tasks.delete"] && [t[@"canDelete"] isEqual:@YES]) { RCFormRow *d = [self button:OR6L(@"Delete task") info:@"delete" identifier:@"chat.task.delete"]; d.destructive = YES; [acts addObject:d]; }
    RCFormSection *a = [RCFormSection sectionWithTitle:nil rows:acts];
    if (![t[@"canManage"] isEqual:@YES]) a.footer = OR6L(@"Changes to this task are not available.");
    else a.footer = OR6L(@"Tasks run on the service; the result appears in the task's chat. iOS 6 gets no notification: you see it when you open the app.");
    [sections addObject:a];
    self.sections = sections;
}
- (void)write:(NSString *)op extra:(NSDictionary *)extra done:(NSString *)done pop:(BOOL)pop {
    NSDictionary *t = [self task]; if (!t || ![self can:op]) return;
    NSMutableDictionary *p = [NSMutableDictionary dictionaryWithDictionary:@{@"taskId": _taskId, @"expectedRevision": t[@"revision"]}]; [p addEntriesFromDictionary:extra]; // this card's fresh revision
    void (^changed)(void) = [[_changed copy] autorelease];
    OR6Chat6RunFormWrite(self, _core, op, p, [NSString stringWithFormat:@"%@:%@", op, _taskId], @"tasks.reconcile", done, ^(NSDictionary *r) {
        (void)r; if (changed) changed();
        UINavigationController *nc = self.navigationController;
        if (pop && nc.topViewController == self) [nc popViewControllerAnimated:YES]; else if (!pop) [self load];
    });
}
- (void)form:(RCFormViewController *)f didToggleRow:(RCFormRow *)row {
    (void)f; BOOL on = row.on; [self render]; // the switch shows the server state until the write is confirmed
    [self write:@"tasks.setEnabled" extra:@{@"enabled": @(on)} done:(on ? OR6L(@"The task is active.") : OR6L(@"The task is paused.")) pop:NO];
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    NSString *name = OR6Chat6Text([self task][@"title"], OR6L(@"Task")); UIView *v = self.view.window ?: self.view;
    if ([row.userInfo isEqual:@"edit"] || [row.userInfo isEqual:@"schedule"]) {
        void (^changed)(void) = [[_changed copy] autorelease];
        OR6Chat6TaskEditor *e = [[[OR6Chat6TaskEditor alloc] initWithCore:_core mode:row.userInfo task:_taskId changed:^{ if (changed) changed(); [self load]; }] autorelease];
        [self.navigationController pushViewController:e animated:YES]; return;
    }
    if ([row.userInfo isEqual:@"run"]) {
        OR6Chat6Confirm(v, [NSString stringWithFormat:OR6L(@"Run «%@» now? The result appears in the task's chat."), name], OR6L(@"Run now"), NO, ^{
            [self write:@"tasks.runNow" extra:@{} done:OR6L(@"The task was started. The result appears in its chat.") pop:NO]; });
        return;
    }
    if ([row.userInfo isEqual:@"delete"]) {
        OR6Chat6Confirm(v, [NSString stringWithFormat:OR6L(@"Delete the task «%@»? It will no longer run."), name], OR6L(@"Delete"), YES, ^{
            [self write:@"tasks.delete" extra:@{@"confirmed": @YES} done:OR6L(@"The task was deleted.") pop:YES]; });
        return;
    }
    [super form:f didSelectRow:row];
}
- (void)dealloc { [_taskId release]; [_changed release]; [super dealloc]; }
@end

#pragma mark - List

@interface OR6Chat6TasksScreen : OR6Chat6Form { OR6Chat6Pager *_pager; NSString *_filter; }
@end
@implementation OR6Chat6TasksScreen
- (OR6Chat6Pager *)list {
    if (!_pager) _pager = [[self pager:@"tasks.list" parameters:OR6Chat6TaskListParameters(_filter) tokenKey:@"cursor" nextKey:@"nextCursor" idKey:@"id"] retain];
    return _pager;
}
- (void)load { [[self list] reload]; [self render]; }
- (NSArray *)filters { return @[@"all", @"scheduled", @"paused", @"finished"]; }
- (NSString *)filterTitle:(NSString *)k {
    NSUInteger i = [[self filters] indexOfObject:k ?: @"all"]; if (i == NSNotFound) i = 0;
    return @[OR6L(@"All tasks"), OR6L(@"Scheduled"), OR6L(@"Paused"), OR6L(@"Finished")][i];
}
- (RCFormRow *)rowFor:(NSDictionary *)t {
    RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:OR6Chat6Text(t[@"title"], OR6L(@"Untitled"))];
    BOOL on = [t[@"enabled"] isEqual:@YES]; NSString *next = on ? [NextRuns(t, 1) lastObject] : nil;
    r.subtitle = next ? [NSString stringWithFormat:OR6L(@"Next run: %@"), next] : ScheduleText(t);
    r.showsLamp = YES; r.lamp = on ? RCLampOK : RCLampOff; r.disclosure = YES; r.userInfo = t; r.identifier = @"chat.tasks.row"; return r;
}
- (void)render {
    OR6Chat6Pager *p = [self list]; NSMutableArray *sections = [NSMutableArray array];
    NSMutableArray *top = [NSMutableArray arrayWithObject:[self value:OR6L(@"Show") value:[self filterTitle:_filter] info:@"filter" identifier:@"chat.tasks.filter"]];
    if (WriteOn(_core, @"tasks.create")) [top addObject:[self button:OR6L(@"New task…") info:@"create" identifier:@"chat.tasks.create"]];
    [sections addObject:[RCFormSection sectionWithTitle:nil rows:top]];
    NSMutableArray *active = [NSMutableArray array], *other = [NSMutableArray array];
    for (NSDictionary *t in p.items) [(!_filter && [t[@"enabled"] isEqual:@YES] ? active : other) addObject:[self rowFor:t]];
    if (active.count) [sections addObject:[RCFormSection sectionWithTitle:OR6L(@"Active tasks") rows:active]];
    if (other.count) [sections addObject:[RCFormSection sectionWithTitle:(_filter ? [self filterTitle:_filter] : OR6L(@"Paused or finished")) rows:other]];
    NSMutableArray *state = [NSMutableArray array];
    NSString *empty = _filter ? OR6L(@"No tasks here.") : WriteOn(_core, @"tasks.create") ? OR6L(@"No tasks yet.") : OR6L(@"No tasks. Tasks are created in a chat with ChatGPT.");
    [self addStateOfPager:p to:state empty:empty identifier:@"chat.tasks"];
    RCFormSection *s = [RCFormSection sectionWithTitle:nil rows:state];
    s.footer = OR6L(@"Tasks run on the service; the result appears in the task's chat. iOS 6 gets no notification: you see it when you open the app.");
    [sections addObject:s];
    self.sections = sections;
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    if ([row.userInfo isEqual:@"filter"]) {
        NSArray *keys = [self filters]; NSMutableArray *titles = [NSMutableArray array]; for (NSString *k in keys) [titles addObject:[self filterTitle:k]];
        OR6ChatChoiceController *c = [[[OR6ChatChoiceController alloc] initWithTitle:OR6L(@"Show") options:titles selected:[keys indexOfObject:_filter ?: @"all"] footer:nil choose:^(NSUInteger i) {
            NSString *k = i == 0 ? nil : keys[i]; if ((k == nil && _filter == nil) || [k isEqual:_filter]) return;
            [_filter release]; _filter = [k copy]; [self list].parameters = OR6Chat6TaskListParameters(_filter); [self load]; // a new first page (the old cursor belongs to the old filter)
        }] autorelease];
        [self.navigationController pushViewController:c animated:YES]; return;
    }
    if ([row.userInfo isEqual:@"create"]) {
        OR6Chat6TaskEditor *e = [[[OR6Chat6TaskEditor alloc] initWithCore:_core mode:@"create" task:nil changed:^{ [self load]; }] autorelease];
        [self.navigationController pushViewController:e animated:YES]; return;
    }
    if ([row.userInfo isKindOfClass:NSDictionary.class] && [row.userInfo[@"id"] isKindOfClass:NSString.class]) {
        [self.navigationController pushViewController:[[[OR6Chat6TaskCard alloc] initWithCore:_core task:row.userInfo changed:^{ [self load]; }] autorelease] animated:YES]; return;
    }
    [super form:f didSelectRow:row];
}
- (void)dealloc { [_pager release]; [_filter release]; [super dealloc]; }
@end

UIViewController *OR6Chat6CreateTasks(OR6APICore *core, id<OR6Chat7Navigator> nav) { return [[[OR6Chat6TasksScreen alloc] initWithCore:core navigator:nav title:OR6L(@"Tasks")] autorelease]; }
