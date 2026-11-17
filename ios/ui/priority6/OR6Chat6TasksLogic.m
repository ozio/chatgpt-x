#import "OR6Chat6TasksLogic.h"
#import "OR6Chat6Models.h"
#import "../../localization/OR6Localization.h"

static NSString *Str(id v, NSUInteger max) { return [v isKindOfClass:NSString.class] && [v length] && [v length] <= max ? v : nil; }
static NSString *Trim(id v) { return [v isKindOfClass:NSString.class] ? [v stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : nil; }
static void Problem(NSString **problem, NSString *text) { if (problem) *problem = text; }

#pragma mark - Projects

NSDictionary *OR6Chat6ProjectCreateRequest(NSString *name, NSString *emoji, BOOL projectOnly, NSString **problem) {
    NSString *n = Trim(name) ?: @"", *e = Trim(emoji) ?: @"";
    if (!n.length) { Problem(problem, OR6L(@"Enter a project title.")); return nil; }
    if (n.length > 240) { Problem(problem, OR6L(@"The title is too long.")); return nil; }
    if (e.length > 64) { Problem(problem, OR6L(@"The icon is too long.")); return nil; }
    return @{@"name": n, @"emoji": e.length ? e : (id)NSNull.null, @"theme": NSNull.null, @"projectOnly": projectOnly ? @YES : @NO};
}
static BOOL Writable(NSDictionary *fresh) { return [fresh isKindOfClass:NSDictionary.class] && Str(fresh[@"projectId"], 128) && [fresh[@"canWrite"] isEqual:@YES]; }
NSDictionary *OR6Chat6ProjectUpdateRequest(NSDictionary *fresh, NSString *name, NSString *emoji, NSString **problem) {
    if (!Writable(fresh) || !Str(fresh[@"name"], 240)) { Problem(problem, OR6L(@"This project cannot be changed from ChatGPT X.")); return nil; }
    NSString *n = name ? (Trim(name) ?: @"") : fresh[@"name"];
    id oldEmoji = Str(fresh[@"emoji"], 64) ?: (id)NSNull.null, newEmoji = oldEmoji;
    if (emoji) { NSString *e = Trim(emoji) ?: @""; if (e.length > 64) { Problem(problem, OR6L(@"The icon is too long.")); return nil; } newEmoji = e.length ? e : (id)NSNull.null; }
    if (!n.length) { Problem(problem, OR6L(@"Enter a project title.")); return nil; }
    if (n.length > 240) { Problem(problem, OR6L(@"The title is too long.")); return nil; }
    if ([n isEqual:fresh[@"name"]] && [newEmoji isEqual:oldEmoji]) { Problem(problem, OR6L(@"Nothing has changed.")); return nil; }
    return @{@"projectId": fresh[@"projectId"], @"name": n, @"emoji": newEmoji, @"theme": Str(fresh[@"theme"], 128) ?: (id)NSNull.null};
}
NSDictionary *OR6Chat6ProjectInstructionsRequest(NSDictionary *fresh, NSString *instructions, NSString **problem) {
    if (!Writable(fresh) || ![fresh[@"instructions"] isKindOfClass:NSString.class]) { Problem(problem, OR6L(@"This project cannot be changed from ChatGPT X.")); return nil; }
    NSString *t = Trim(instructions) ?: @"";
    if (t.length > 16000) { Problem(problem, OR6L(@"The instructions are too long.")); return nil; }
    if ([t isEqual:Trim(fresh[@"instructions"])]) { Problem(problem, OR6L(@"Nothing has changed.")); return nil; }
    return @{@"projectId": fresh[@"projectId"], @"instructions": t};
}
NSString *OR6Chat6ProjectIntent(NSString *op, NSString *target) {
    NSString *t = [op isEqual:@"projects.create"] ? [Trim(target) lowercaseString] : target;
    return [NSString stringWithFormat:@"%@:%@", op ?: @"", t ?: @""];
}

#pragma mark - Tasks

NSDictionary *OR6Chat6TaskListParameters(NSString *filter) {
    NSString *f = [filter isKindOfClass:NSString.class] && [@[@"scheduled", @"paused", @"finished"] containsObject:filter] ? filter : nil;
    return @{@"filter": f ?: (id)NSNull.null};
}
static NSCalendar *Cal(NSTimeZone *tz) { NSCalendar *c = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease]; c.timeZone = tz; return c; }
static NSUInteger const YMD = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit;
static NSInteger ISOWeekday(NSCalendar *cal, NSDate *d) { return ([cal components:NSWeekdayCalendarUnit fromDate:d].weekday + 5) % 7 + 1; } // NSCalendar: 1 = Sunday
// The wall-clock time y-m-d h:mi in the calendar's zone; nil when the day does not exist (31 Feb).
static NSDate *At(NSCalendar *cal, NSInteger y, NSInteger m, NSInteger d, NSInteger h, NSInteger mi) {
    NSDateComponents *c = [[[NSDateComponents alloc] init] autorelease]; c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = mi; c.second = 0;
    NSDate *date = [cal dateFromComponents:c]; if (!date) return nil;
    NSDateComponents *back = [cal components:YMD fromDate:date];
    return back.year == y && back.month == m && back.day == d ? date : nil;
}
// The calendar day `offset` days after the day of `date` (computed at noon, safe across DST).
static NSDateComponents *DayAfter(NSCalendar *cal, NSDate *date, NSInteger offset) {
    NSDateComponents *c = [cal components:YMD fromDate:date]; c.hour = 12;
    NSDateComponents *add = [[[NSDateComponents alloc] init] autorelease]; add.day = offset;
    return [cal components:YMD fromDate:[cal dateByAddingComponents:add toDate:[cal dateFromComponents:c] options:0]];
}

NSString *OR6Chat6TaskTimingText(id m) {
    if ([m isEqual:@"exact_schedule"]) return OR6L(@"Exact time");
    if ([m isEqual:@"flexible_schedule"]) return OR6L(@"Flexible time");
    if ([m isEqual:@"condition_watch"]) return OR6L(@"When a condition is met");
    return nil;
}

NSMutableDictionary *OR6Chat6TaskEditorState(NSDictionary *task, NSDate *now, NSTimeZone *local) {
    if (![task isKindOfClass:NSDictionary.class]) task = nil;
    NSDate *n = [now isKindOfClass:NSDate.class] ? now : [NSDate date]; NSTimeZone *l = [local isKindOfClass:NSTimeZone.class] ? local : [NSTimeZone localTimeZone];
    NSString *tzName = task ? Str(task[@"timezone"], 128) : l.name; NSTimeZone *tz = tzName ? [NSTimeZone timeZoneWithName:tzName] : nil;
    NSCalendar *cal = Cal(tz ?: l); NSDateComponents *tomorrow = DayAfter(cal, n, 1), *today = [cal components:YMD fromDate:n];
    id mode = task[@"timingMode"]; NSString *timing = [mode isKindOfClass:NSString.class] && [@[@"exact_schedule", @"flexible_schedule", @"condition_watch"] containsObject:mode] ? mode : nil;
    NSMutableDictionary *s = [NSMutableDictionary dictionaryWithDictionary:@{
        @"title": Str(task[@"title"], 1000) ?: @"", @"prompt": Str(task[@"prompt"], 16000) ?: @"", @"timezone": tzName ?: @"",
        @"timingMode": timing ?: @"exact_schedule",
        @"frequency": @"daily", @"hour": @9, @"minute": @0, @"weekdays": @[@(ISOWeekday(cal, n))], @"monthDay": @(MIN(today.day, (NSInteger)28)),
        @"year": @(tomorrow.year), @"month": @(tomorrow.month), @"day": @(tomorrow.day),
        @"original": Str(task[@"schedule"], 4096) ?: @"", @"representable": @(task == nil), @"scheduleEdited": @(task == nil)}];
    NSDictionary *p = task && tz ? OR6Chat6TaskScheduleParse(task[@"schedule"], tz) : nil;
    if (p) {
        s[@"representable"] = @YES; s[@"frequency"] = p[@"frequency"]; s[@"hour"] = p[@"hour"]; s[@"minute"] = p[@"minute"];
        if ([p[@"weekdays"] isKindOfClass:NSArray.class] && [p[@"weekdays"] count]) s[@"weekdays"] = p[@"weekdays"];
        if ([p[@"monthDay"] isKindOfClass:NSNumber.class]) s[@"monthDay"] = p[@"monthDay"];
        if ([p[@"date"] isKindOfClass:NSDate.class]) { NSDateComponents *d = [cal components:YMD fromDate:p[@"date"]]; s[@"year"] = @(d.year); s[@"month"] = @(d.month); s[@"day"] = @(d.day); }
    }
    return s;
}
BOOL OR6Chat6TaskScheduleEditable(NSDictionary *s) { return [s[@"representable"] isEqual:@YES] && ![s[@"timingMode"] isEqual:@"condition_watch"]; }

NSDate *OR6Chat6TaskEditorStart(NSDictionary *s, NSDate *now) {
    NSTimeZone *tz = Str(s[@"timezone"], 128) ? [NSTimeZone timeZoneWithName:s[@"timezone"]] : nil; if (!tz || ![now isKindOfClass:NSDate.class]) return nil;
    NSInteger h = [s[@"hour"] integerValue], mi = [s[@"minute"] integerValue]; NSString *f = s[@"frequency"];
    if (h < 0 || h > 23 || mi < 0 || mi > 59) return nil;
    NSCalendar *cal = Cal(tz);
    if ([f isEqual:@"once"]) return At(cal, [s[@"year"] integerValue], [s[@"month"] integerValue], [s[@"day"] integerValue], h, mi);
    if ([f isEqual:@"monthly"]) {
        NSInteger md = [s[@"monthDay"] integerValue]; if (md < 1 || md > 31) return nil;
        NSDateComponents *c = [cal components:YMD fromDate:now];
        for (NSInteger i = 0; i < 24; i++) { // the next month that has this day
            NSInteger m = c.month - 1 + i, y = c.year + m / 12; NSDate *d = At(cal, y, m % 12 + 1, md, h, mi);
            if (d && [d compare:now] == NSOrderedDescending) return d;
        }
        return nil;
    }
    NSArray *days = [f isEqual:@"weekdays"] ? @[@1, @2, @3, @4, @5] : [f isEqual:@"weekly"] ? s[@"weekdays"] : nil;
    if (![f isEqual:@"daily"] && ![days isKindOfClass:NSArray.class]) return nil;
    for (NSInteger i = 0; i <= 8; i++) {
        NSDateComponents *c = DayAfter(cal, now, i); NSDate *d = At(cal, c.year, c.month, c.day, h, mi);
        if (!d || [d compare:now] != NSOrderedDescending) continue;
        if (days && ![days containsObject:@(ISOWeekday(cal, d))]) continue;
        return d;
    }
    return nil;
}
NSString *OR6Chat6TaskEditorSchedule(NSDictionary *s, NSDate *now, NSString **problem) {
    NSString *original = Str(s[@"original"], 4096);
    if (![s[@"scheduleEdited"] isEqual:@YES] || ![s[@"representable"] isEqual:@YES]) { // kept exactly as the service stores it
        if (!original) Problem(problem, OR6L(@"Choose when the task runs."));
        return original;
    }
    NSTimeZone *tz = Str(s[@"timezone"], 128) ? [NSTimeZone timeZoneWithName:s[@"timezone"]] : nil;
    if (!tz) { Problem(problem, OR6L(@"Choose a time zone.")); return nil; }
    NSString *f = s[@"frequency"]; NSArray *w = [s[@"weekdays"] isKindOfClass:NSArray.class] ? s[@"weekdays"] : @[];
    if ([f isEqual:@"weekly"] && !w.count) { Problem(problem, OR6L(@"Choose at least one day of the week.")); return nil; }
    NSDate *start = OR6Chat6TaskEditorStart(s, now);
    if (!start) { Problem(problem, OR6L(@"Choose when the task runs.")); return nil; }
    if ([f isEqual:@"once"] && [start compare:now] != NSOrderedDescending) { Problem(problem, OR6L(@"Choose a time in the future.")); return nil; }
    NSString *v = OR6Chat6TaskSchedule(f, start, [f isEqual:@"weekly"] ? w : nil, tz);
    if (!v) Problem(problem, OR6L(@"Choose when the task runs."));
    return v;
}
static NSString *CreatableTiming(NSDictionary *s) { return [s[@"timingMode"] isEqual:@"flexible_schedule"] ? @"flexible_schedule" : @"exact_schedule"; }
NSDictionary *OR6Chat6TaskCreateRequest(NSDictionary *s, NSDate *now, NSString **problem) {
    NSString *t = Trim(s[@"title"]), *p = Trim(s[@"prompt"]);
    NSDictionary *draft = OR6Chat6TaskDraft(t, p, @"-", @"UTC", nil, nil, problem); if (!draft) return nil; // name and request first
    NSString *schedule = OR6Chat6TaskEditorSchedule(s, now, problem); if (!schedule) return nil;
    draft = OR6Chat6TaskDraft(t, p, schedule, s[@"timezone"], CreatableTiming(s), nil, problem);
    return draft ? @{@"task": draft} : nil;
}
static BOOL Fresh(NSDictionary *f, NSString **problem) {
    if ([f isKindOfClass:NSDictionary.class] && Str(f[@"id"], 128) && [Str(f[@"revision"], 64) length] == 64 && [f[@"canManage"] isEqual:@YES]) return YES; // revision: exactly 64 (contract)
    Problem(problem, OR6L(@"This task cannot be changed from ChatGPT X.")); return NO;
}
NSDictionary *OR6Chat6TaskUpdateRequest(NSDictionary *fresh, NSDictionary *s, NSDate *now, NSString **problem) {
    if (!Fresh(fresh, problem)) return nil;
    NSString *t = Trim(s[@"title"]), *p = Trim(s[@"prompt"]);
    if (!OR6Chat6TaskDraft(t, p, @"-", @"UTC", nil, nil, problem)) return nil;
    NSString *schedule = OR6Chat6TaskEditorSchedule(s, now, problem); if (!schedule) return nil;
    NSDictionary *draft = OR6Chat6TaskDraft(t, p, schedule, s[@"timezone"], s[@"timingMode"], fresh, problem);
    return draft ? @{@"expectedRevision": fresh[@"revision"], @"taskId": fresh[@"id"], @"task": draft} : nil;
}
NSDictionary *OR6Chat6TaskSetScheduleRequest(NSDictionary *fresh, NSDictionary *s, NSDate *now, NSString **problem) {
    if (!Fresh(fresh, problem)) return nil;
    if (!OR6Chat6TaskScheduleEditable(s)) { Problem(problem, OR6L(@"This schedule cannot be changed in ChatGPT X.")); return nil; }
    if (![s[@"scheduleEdited"] isEqual:@YES]) { Problem(problem, OR6L(@"Nothing has changed.")); return nil; }
    NSString *schedule = OR6Chat6TaskEditorSchedule(s, now, problem); if (!schedule) return nil;
    return @{@"expectedRevision": fresh[@"revision"], @"taskId": fresh[@"id"], @"schedule": schedule, @"timezone": s[@"timezone"], @"timingMode": s[@"timingMode"]};
}
