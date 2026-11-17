#import "OR6Chat6Models.h"
#include <math.h>
#import "../priority8/OR6Chat8Models.h"
#import "../../localization/OR6Localization.h"

static NSString *Str(id v, NSUInteger max) { return [v isKindOfClass:NSString.class] && [v length] && [v length] <= max ? v : nil; }

#pragma mark - Pager

@interface OR6Chat6Pager () {
    OR6APICore *_core; NSString *_operation, *_tokenKey, *_nextKey, *_idKey, *_itemsKey, *_token, *_requested;
    NSDictionary *_parameters, *_lastPage; NSMutableArray *_items, *_pageResults; NSMutableSet *_seen; NSError *_error;
    id<OR6APITask> _task; NSUInteger _epoch, _generation, _pages, _maxPages; BOOL _busy, _loaded, _ended; id<OR6Chat8ModelDelegate> _delegate;
}
@end

@implementation OR6Chat6Pager
@synthesize delegate = _delegate, maxPages = _maxPages, operation = _operation, lastPage = _lastPage, error = _error, busy = _busy, loaded = _loaded, pages = _pages;
- (id)initWithCore:(OR6APICore *)core operation:(NSString *)op parameters:(NSDictionary *)p tokenKey:(NSString *)tk nextKey:(NSString *)nk idKey:(NSString *)ik {
    if ((self = [super init])) {
        _core = [core retain]; _operation = [op copy]; _parameters = [p copy] ?: [@{} retain]; _tokenKey = [tk copy]; _nextKey = [nk copy]; _idKey = [ik copy];
        _itemsKey = [@"items" copy]; _items = [NSMutableArray new]; _pageResults = [NSMutableArray new]; _seen = [NSMutableSet new]; _maxPages = 8;
    }
    return self;
}
- (NSString *)itemsKey { return _itemsKey; }
- (void)setItemsKey:(NSString *)k { if (![k isKindOfClass:NSString.class] || !k.length) return; [_itemsKey release]; _itemsKey = [k copy]; }
- (NSDictionary *)parameters { return _parameters; }
- (void)setParameters:(NSDictionary *)p { if ([p isEqual:_parameters]) return; [_parameters release]; _parameters = [p copy] ?: [@{} retain]; [self reset]; }
- (NSArray *)items { return [[_items copy] autorelease]; }
- (NSArray *)pageResults { return [[_pageResults copy] autorelease]; }
- (BOOL)hasMore { return _token != nil && !_ended && _pages < _maxPages; }
- (BOOL)retryAvailable { return _error && !_busy && !OR6Chat8StopSignal(_error.userInfo[@"code"]) && ![_error.userInfo[@"code"] isEqual:@"stale_context"]; }
- (void)changed { [[self retain] autorelease]; [_delegate chat8ModelChanged:self]; }
- (BOOL)request:(NSString *)token {
    if (!OR6Chat7Callable(_core, _operation)) return NO;
    [self cancel];
    NSMutableDictionary *q = [[_parameters mutableCopy] autorelease]; if (_tokenKey) q[_tokenKey] = token ?: (id)NSNull.null;
    NSUInteger epoch = ++_epoch; _generation = OR6Chat7Generation(_core); _busy = YES; [_error release]; _error = nil;
    [_requested release]; _requested = [token copy];
    __block BOOL finished = NO;
    id<OR6APITask> t = [_core perform:_operation parameters:q event:nil completion:^(NSDictionary *r, NSError *e) {
        finished = YES; if (epoch != _epoch) return;
        [_task release]; _task = nil; _busy = NO;
        if (OR6Chat7Generation(_core) != _generation) { // the owner/credential context changed: nothing of the old one is shown
            [_items removeAllObjects]; [_seen removeAllObjects]; [_pageResults removeAllObjects]; [_lastPage release]; _lastPage = nil;
            [_token release]; _token = nil; _pages = 0; _loaded = NO; _error = [OR6APIError(@"stale_context", @"none") retain]; [self changed]; return;
        }
        if (e || ![r isKindOfClass:NSDictionary.class]) { _error = [(e ?: OR6APIError(@"unknown_wire_shape", @"none")) retain]; [self changed]; return; }
        [self accept:r];
        [self changed];
    }];
    if (!finished && epoch == _epoch) _task = [t retain];
    if (!finished) [self changed];
    return YES;
}
- (void)accept:(NSDictionary *)r {
    id list = r[_itemsKey];
    for (NSDictionary *i in [list isKindOfClass:NSArray.class] ? list : @[]) {
        if (![i isKindOfClass:NSDictionary.class]) continue;
        id ident = _idKey ? i[_idKey] : nil;
        if (_idKey && !Str(ident, 4096)) continue;
        if (ident && [_seen containsObject:ident]) continue;
        if (ident) [_seen addObject:ident];
        [_items addObject:i];
    }
    NSString *next = _nextKey ? Str(r[_nextKey], 4096) : nil;
    _ended = !next || (_requested && [next isEqual:_requested]); // the same token again would loop
    [_token release]; _token = _ended ? nil : [next copy];
    [_lastPage release]; _lastPage = [r copy]; [_pageResults addObject:r]; _pages++; _loaded = YES;
}
- (BOOL)reload {
    [self cancel]; [_items removeAllObjects]; [_seen removeAllObjects]; [_pageResults removeAllObjects]; [_lastPage release]; _lastPage = nil;
    [_token release]; _token = nil; _pages = 0; _loaded = NO; _ended = NO; [_error release]; _error = nil;
    return [self request:nil];
}
- (BOOL)loadMore { if (_busy || ![self hasMore]) return NO; return [self request:_token]; }
- (BOOL)retry { if (![self retryAvailable]) return NO; if (!_loaded) return [self reload]; return [self request:_requested]; }
- (void)removeItemWithId:(NSString *)identifier {
    if (!_idKey || !identifier) return;
    for (NSUInteger i = 0; i < _items.count; i++) if ([_items[i][_idKey] isEqual:identifier]) { [_items removeObjectAtIndex:i]; i--; }
    [self changed];
}
- (void)cancel { _epoch++; [_task cancel]; [_task release]; _task = nil; _busy = NO; }
- (void)reset {
    [self cancel]; [_items removeAllObjects]; [_seen removeAllObjects]; [_pageResults removeAllObjects]; [_lastPage release]; _lastPage = nil;
    [_token release]; _token = nil; [_requested release]; _requested = nil; [_error release]; _error = nil; _pages = 0; _loaded = NO; _ended = NO;
}
- (NSDictionary *)diagnostics { return @{@"items": @(_items.count), @"pages": @(_pages), @"busy": @(_busy), @"more": @([self hasMore]), @"error": _error.userInfo[@"code"] ?: @""}; }
- (void)dealloc {
    [self cancel]; [_core release]; [_operation release]; [_tokenKey release]; [_nextKey release]; [_idKey release]; [_itemsKey release]; [_token release]; [_requested release];
    [_parameters release]; [_lastPage release]; [_items release]; [_pageResults release]; [_seen release]; [_error release]; [super dealloc];
}
@end

#pragma mark - Global search

NSDictionary *OR6Chat6SearchEntry(NSDictionary *i) {
    if (![i isKindOfClass:NSDictionary.class] || !Str(i[@"id"], 256)) return nil;
    NSString *title = Str(i[@"title"], 2000), *snippet = Str(i[@"snippet"], 8000);
    NSString *c = Str(i[@"conversationId"], 36), *p = Str(i[@"projectId"], 256), *l = Str(i[@"libraryItemId"], 256), *g = Str(i[@"pageId"], 256);
    NSString *kind = c ? @"conversation" : p ? @"project" : l ? @"file" : g ? @"page" : nil;
    if (!kind) return nil; // no target of any supported kind
    NSMutableDictionary *e = [NSMutableDictionary dictionaryWithObjectsAndKeys:kind, @"kind", i[@"id"], @"id", (title ?: OR6L(@"Untitled")), @"title", nil];
    if (snippet) e[@"snippet"] = snippet;
    if (c) e[@"conversationId"] = c; if (p) e[@"projectId"] = p; if (l) e[@"libraryItemId"] = l; if (g) e[@"pageId"] = g;
    return e;
}
NSString *OR6Chat6SearchNotice(NSArray *pages) {
    BOOL partial = NO; NSMutableArray *failed = [NSMutableArray array];
    for (NSDictionary *p in pages) {
        if (![p isKindOfClass:NSDictionary.class]) continue;
        if ([p[@"partial"] isEqual:@YES]) partial = YES;
        for (NSDictionary *s in [p[@"sourceStatuses"] isKindOfClass:NSArray.class] ? p[@"sourceStatuses"] : @[]) {
            if (![s isKindOfClass:NSDictionary.class] || ![@[@"error", @"skipped"] containsObject:s[@"status"] ?: @""]) continue;
            NSString *t = Str(s[@"sourceType"], 128) ?: OR6L(@"Unknown source"); partial = YES;
            NSString *name = [t isEqual:@"conversations"] || [t isEqual:@"chats"] ? OR6L(@"Chats") : [t isEqual:@"projects"] ? OR6L(@"Projects") : [t isEqual:@"files"] || [t isEqual:@"library"] ? OR6L(@"Files") : [t isEqual:@"pages"] ? OR6L(@"Pages") : t;
            if (![failed containsObject:name]) [failed addObject:name];
        }
    }
    if (!partial) return nil;
    return failed.count ? [NSString stringWithFormat:OR6L(@"Results may be incomplete: no answer from %@."), [failed componentsJoinedByString:@", "]] : OR6L(@"Results may be incomplete: some sources did not answer.");
}

#pragma mark - Locked transcript

static NSString *Escape(NSString *s) { // a file name never becomes markdown syntax
    NSMutableString *m = [NSMutableString string];
    for (NSUInteger i = 0; i < s.length; i++) { unichar c = [s characterAtIndex:i]; if (c == '\n' || c == '\r') { [m appendString:@" "]; continue; } if (strchr("\\`*_[]()#<>!|~", c) && c < 128) [m appendString:@"\\"]; [m appendFormat:@"%C", c]; }
    return m;
}
NSDictionary *OR6Chat6LockedTranscript(NSDictionary *c) {
    NSMutableString *md = [NSMutableString string]; NSUInteger messages = 0, images = 0, files = 0, unsupported = 0; NSMutableArray *sources = [NSMutableArray array]; NSMutableSet *seen = [NSMutableSet set];
    for (NSDictionary *m in [c[@"messages"] isKindOfClass:NSArray.class] ? c[@"messages"] : @[]) {
        if (![m isKindOfClass:NSDictionary.class] || ![@[@"user", @"assistant"] containsObject:m[@"role"] ?: @""]) continue;
        NSString *text = [m[@"text"] isKindOfClass:NSString.class] ? m[@"text"] : @"";
        NSArray *parts = [m[@"parts"] isKindOfClass:NSArray.class] ? m[@"parts"] : @[];
        NSDictionary *assets = OR6Chat8MessageAssets(parts);
        NSMutableArray *lines = [NSMutableArray array];
        if ([assets[@"images"] count]) { images += [assets[@"images"] count]; [lines addObject:[NSString stringWithFormat:([assets[@"images"] count] == 1 ? OR6L(@"Image — not shown in a locked chat; it stays in the chat.") : OR6L(@"%lu images — not shown in a locked chat; they stay in the chat.")), (unsigned long)[assets[@"images"] count]]]; }
        for (NSDictionary *f in assets[@"files"]) { files++; NSString *size = OR6Chat6Bytes(f[@"bytes"]); [lines addObject:[NSString stringWithFormat:OR6L(@"File «%@»%@ — it stays in the chat."), Escape(Str(f[@"name"], 240) ?: OR6L(@"File")), size ? [@" · " stringByAppendingString:size] : @""]]; }
        NSUInteger other = 0;
        for (NSDictionary *p in parts) {
            if (![p isKindOfClass:NSDictionary.class]) continue;
            NSDictionary *d = [p[@"data"] isKindOfClass:NSDictionary.class] ? p[@"data"] : p;
            if ([p[@"kind"] isEqual:@"unsupported"]) other++;
            else if ([p[@"kind"] isEqual:@"asset"] && !Str(d[@"asset_pointer"], 4096) && !OR6Chat8FileID(d[@"id"])) other++;
            else if ([p[@"kind"] isEqual:@"citation"] && sources.count < 64) {
                NSString *url = Str(d[@"url"], 2048); NSURL *u = url ? [NSURL URLWithString:url] : nil; NSString *s = u.scheme.lowercaseString;
                if (u.host.length && ([s isEqual:@"http"] || [s isEqual:@"https"]) && ![seen containsObject:url]) { [seen addObject:url]; NSString *t = Str(d[@"title"], 100000) ?: u.host; [sources addObject:@{@"title": [t substringToIndex:MIN(t.length, (NSUInteger)300)], @"url": url, @"host": u.host}]; }
            }
        }
        if (other) { unsupported += other; [lines addObject:(other == 1 ? OR6L(@"A part of this message that ChatGPT X cannot show — it stays in the chat.") : [NSString stringWithFormat:OR6L(@"%lu parts of this message that ChatGPT X cannot show — they stay in the chat."), (unsigned long)other])]; }
        BOOL empty = ![[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] length];
        if (empty && !lines.count) continue; // nothing at all (system scaffolding with an empty body)
        messages++;
        [md appendFormat:@"### %@\n\n", [m[@"role"] isEqual:@"user"] ? OR6L(@"Question") : @"ChatGPT"];
        if (!empty) [md appendFormat:@"%@\n\n", text];
        for (NSString *l in lines) [md appendFormat:@"_%@_\n\n", l];
    }
    return @{@"markdown": md, @"messages": @(messages), @"images": @(images), @"files": @(files), @"unsupported": @(unsupported), @"sources": sources};
}

#pragma mark - Report

NSArray *OR6Chat6ReportChildren(NSDictionary *reasons, NSString *parent) {
    NSMutableArray *a = [NSMutableArray array];
    for (NSDictionary *r in [reasons[@"items"] isKindOfClass:NSArray.class] ? reasons[@"items"] : @[]) {
        if (![r isKindOfClass:NSDictionary.class] || !Str(r[@"id"], 128) || !Str(r[@"label"], 1024)) continue;
        id p = [r[@"parentId"] isKindOfClass:NSString.class] ? r[@"parentId"] : nil;
        if ((parent == nil && p == nil) || (parent && [p isEqual:parent])) [a addObject:r];
    }
    return a;
}
static BOOL FieldValid(NSString *type, NSString *v) {
    if ([type isEqual:@"int"]) { NSScanner *s = [NSScanner scannerWithString:v]; long long n; return [s scanLongLong:&n] && s.isAtEnd; }
    if ([type isEqual:@"email"]) { NSRange at = [v rangeOfString:@"@"]; return at.location != NSNotFound && at.location > 0 && [v rangeOfString:@"." options:0 range:NSMakeRange(at.location, v.length - at.location)].location != NSNotFound && [v rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location == NSNotFound; }
    if ([type isEqual:@"url"]) { NSURL *u = [NSURL URLWithString:v]; NSString *s = u.scheme.lowercaseString; return u.host.length && ([s isEqual:@"https"] || [s isEqual:@"http"]); }
    if ([type isEqual:@"single_line_text"]) return [v rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet].location == NSNotFound;
    return YES;
}
NSDictionary *OR6Chat6ReportRequest(NSString *cid, NSDictionary *reasons, NSDictionary *reason, NSString *details, NSDictionary *values, NSString **problem) {
    NSString *catalog = Str(reasons[@"catalogId"], 36), *rid = Str(reason[@"id"], 128);
    if (!Str(cid, 36) || !catalog || !rid || ![reason[@"canSubmit"] isEqual:@YES]) { if (problem) *problem = OR6L(@"Choose a reason first."); return nil; }
    BOOL known = NO; for (NSDictionary *r in reasons[@"items"]) if ([r isKindOfClass:NSDictionary.class] && [r[@"id"] isEqual:rid]) known = YES;
    if (!known) { if (problem) *problem = OR6L(@"Choose a reason first."); return nil; }
    NSString *d = [details isKindOfClass:NSString.class] ? [details stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : @"";
    if (d.length > 4000) { if (problem) *problem = OR6L(@"The text is too long."); return nil; }
    NSMutableArray *fields = [NSMutableArray array];
    for (NSDictionary *f in [reason[@"additionalFields"] isKindOfClass:NSArray.class] ? reason[@"additionalFields"] : @[]) {
        if (![f isKindOfClass:NSDictionary.class] || !Str(f[@"id"], 128)) continue;
        NSString *v = [values[f[@"id"]] isKindOfClass:NSString.class] ? [values[f[@"id"]] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : @"";
        if (!v.length) { if ([f[@"required"] isEqual:@YES]) { if (problem) *problem = [NSString stringWithFormat:OR6L(@"Fill in «%@»."), Str(f[@"placeholder"], 1024) ?: f[@"id"]]; return nil; } continue; }
        if (v.length > 4000 || !FieldValid(f[@"type"], v)) { if (problem) *problem = [NSString stringWithFormat:OR6L(@"Check «%@»."), Str(f[@"placeholder"], 1024) ?: f[@"id"]]; return nil; }
        [fields addObject:@{@"id": f[@"id"], @"value": v}];
    }
    return @{@"conversationId": cid, @"catalogId": catalog, @"reasonId": rid, @"details": d, @"additionalFields": fields, @"consentToSendConversation": @YES};
}

#pragma mark - Task schedule

static NSString *const Days[] = {@"MO", @"TU", @"WE", @"TH", @"FR", @"SA", @"SU"};
NSString *OR6Chat6TaskSchedule(NSString *freq, NSDate *date, NSArray *weekdays, NSTimeZone *tz) {
    if (![date isKindOfClass:NSDate.class] || ![tz isKindOfClass:NSTimeZone.class]) return nil;
    NSCalendar *cal = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease]; cal.timeZone = tz;
    NSDateComponents *c = [cal components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSWeekdayCalendarUnit fromDate:date];
    NSString *start = [NSString stringWithFormat:@"DTSTART:%04ld%02ld%02ldT%02ld%02ld00", (long)c.year, (long)c.month, (long)c.day, (long)c.hour, (long)c.minute];
    NSString *time = [NSString stringWithFormat:@"BYHOUR=%ld;BYMINUTE=%ld;BYSECOND=0", (long)c.hour, (long)c.minute];
    NSString *rule = nil;
    if ([freq isEqual:@"once"]) return [NSString stringWithFormat:@"BEGIN:VEVENT\n%@\nEND:VEVENT", start];
    if ([freq isEqual:@"daily"]) rule = [@"FREQ=DAILY;" stringByAppendingString:time];
    else if ([freq isEqual:@"weekdays"]) rule = [@"FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR;" stringByAppendingString:time];
    else if ([freq isEqual:@"weekly"]) {
        NSMutableArray *d = [NSMutableArray array];
        for (NSNumber *n in [weekdays isKindOfClass:NSArray.class] ? [weekdays sortedArrayUsingSelector:@selector(compare:)] : @[]) { if (![n isKindOfClass:NSNumber.class] || n.intValue < 1 || n.intValue > 7 || [d containsObject:Days[n.intValue - 1]]) continue; [d addObject:Days[n.intValue - 1]]; }
        if (!d.count) [d addObject:Days[(c.weekday + 5) % 7]]; // NSCalendar: 1 = Sunday
        rule = [NSString stringWithFormat:@"FREQ=WEEKLY;BYDAY=%@;%@", [d componentsJoinedByString:@","], time];
    } else if ([freq isEqual:@"monthly"]) rule = [NSString stringWithFormat:@"FREQ=MONTHLY;BYMONTHDAY=%ld;%@", (long)c.day, time];
    if (!rule) return nil;
    return [NSString stringWithFormat:@"BEGIN:VEVENT\n%@\nRRULE:%@\nEND:VEVENT", start, rule];
}
NSDictionary *OR6Chat6TaskScheduleParse(NSString *s, NSTimeZone *tz) {
    if (!Str(s, 4096) || ![s hasPrefix:@"BEGIN:VEVENT\n"] || ![s hasSuffix:@"\nEND:VEVENT"]) return nil;
    NSString *start = nil, *rule = nil;
    for (NSString *l in [s componentsSeparatedByString:@"\n"]) {
        if ([l isEqual:@"BEGIN:VEVENT"] || [l isEqual:@"END:VEVENT"]) continue;
        if ([l hasPrefix:@"DTSTART:"] && !start) start = [l substringFromIndex:8];
        else if ([l hasPrefix:@"RRULE:"] && !rule) rule = [l substringFromIndex:6];
        else return nil; // another property: not this editor's schedule
    }
    NSMutableDictionary *out = [NSMutableDictionary dictionary]; NSInteger hour = -1, minute = -1;
    if (start) {
        if (start.length != 15 || [start characterAtIndex:8] != 'T') return nil;
        NSDateFormatter *f = [[[NSDateFormatter alloc] init] autorelease]; f.locale = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease]; f.timeZone = tz ?: [NSTimeZone localTimeZone]; f.dateFormat = @"yyyyMMdd'T'HHmmss";
        NSDate *d = [f dateFromString:start]; if (!d) return nil; out[@"date"] = d;
        hour = [[start substringWithRange:NSMakeRange(9, 2)] integerValue]; minute = [[start substringWithRange:NSMakeRange(11, 2)] integerValue];
    }
    if (!rule) { if (!start) return nil; out[@"frequency"] = @"once"; out[@"hour"] = @(hour); out[@"minute"] = @(minute); return out; }
    NSMutableDictionary *r = [NSMutableDictionary dictionary];
    for (NSString *kv in [rule componentsSeparatedByString:@";"]) { NSArray *p = [kv componentsSeparatedByString:@"="]; if (p.count != 2 || r[p[0]]) return nil; r[p[0]] = p[1]; }
    for (NSString *k in r) if (![@[@"FREQ", @"BYDAY", @"BYHOUR", @"BYMINUTE", @"BYSECOND", @"BYMONTHDAY"] containsObject:k]) return nil; // INTERVAL, COUNT, UNTIL…: shown read-only
    if (r[@"BYHOUR"]) hour = [r[@"BYHOUR"] integerValue]; if (r[@"BYMINUTE"]) minute = [r[@"BYMINUTE"] integerValue];
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59 || [r[@"BYHOUR"] rangeOfString:@","].location != NSNotFound || [r[@"BYMINUTE"] rangeOfString:@","].location != NSNotFound) return nil;
    out[@"hour"] = @(hour); out[@"minute"] = @(minute);
    NSString *freq = r[@"FREQ"];
    if ([freq isEqual:@"DAILY"] && !r[@"BYDAY"] && !r[@"BYMONTHDAY"]) out[@"frequency"] = @"daily";
    else if ([freq isEqual:@"WEEKLY"] && !r[@"BYMONTHDAY"]) {
        NSMutableArray *w = [NSMutableArray array];
        for (NSString *d in [r[@"BYDAY"] ?: @"" componentsSeparatedByString:@","]) { NSUInteger i = 0; for (; i < 7; i++) if ([Days[i] isEqual:d]) break; if (i == 7) return nil; [w addObject:@(i + 1)]; }
        BOOL weekdays = [w isEqual:@[@1, @2, @3, @4, @5]];
        out[@"frequency"] = weekdays ? @"weekdays" : @"weekly"; out[@"weekdays"] = w;
    } else if ([freq isEqual:@"MONTHLY"] && r[@"BYMONTHDAY"] && !r[@"BYDAY"]) { NSInteger d = [r[@"BYMONTHDAY"] integerValue]; if (d < 1 || d > 31) return nil; out[@"frequency"] = @"monthly"; out[@"monthDay"] = @(d); }
    else return nil;
    return out;
}
NSString *OR6Chat6TaskScheduleText(NSDictionary *p) {
    NSString *f = p[@"frequency"]; if (![f isKindOfClass:NSString.class]) return nil;
    NSString *time = [NSString stringWithFormat:@"%02d:%02d", [p[@"hour"] intValue], [p[@"minute"] intValue]];
    if ([f isEqual:@"once"]) {
        NSDateFormatter *o = [[[NSDateFormatter alloc] init] autorelease]; o.dateStyle = NSDateFormatterMediumStyle; o.timeStyle = NSDateFormatterShortStyle;
        return p[@"date"] ? [NSString stringWithFormat:OR6L(@"Once, %@"), [o stringFromDate:p[@"date"]]] : nil;
    }
    if ([f isEqual:@"daily"]) return [NSString stringWithFormat:OR6L(@"Every day at %@"), time];
    if ([f isEqual:@"weekdays"]) return [NSString stringWithFormat:OR6L(@"On weekdays at %@"), time];
    if ([f isEqual:@"monthly"]) return [NSString stringWithFormat:OR6L(@"Every month on day %d at %@"), [p[@"monthDay"] intValue], time];
    if ([f isEqual:@"weekly"]) {
        NSDateFormatter *o = [[[NSDateFormatter alloc] init] autorelease]; NSArray *names = o.shortStandaloneWeekdaySymbols; NSMutableArray *d = [NSMutableArray array]; // Sunday first
        for (NSNumber *n in p[@"weekdays"]) if (n.intValue >= 1 && n.intValue <= 7 && names.count == 7) [d addObject:names[(NSUInteger)(n.intValue % 7)]];
        return [NSString stringWithFormat:OR6L(@"Every week on %@ at %@"), [d componentsJoinedByString:@", "], time];
    }
    return nil;
}
NSDictionary *OR6Chat6TaskDraft(NSString *title, NSString *prompt, NSString *schedule, NSString *tz, NSString *timing, NSDictionary *existing, NSString **problem) {
    NSCharacterSet *ws = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    NSString *t = [title isKindOfClass:NSString.class] ? [title stringByTrimmingCharactersInSet:ws] : @"", *p = [prompt isKindOfClass:NSString.class] ? [prompt stringByTrimmingCharactersInSet:ws] : @"";
    if (!t.length || t.length > 1000) { if (problem) *problem = t.length ? OR6L(@"The name is too long.") : OR6L(@"Enter a name."); return nil; }
    if (!p.length || p.length > 16000) { if (problem) *problem = p.length ? OR6L(@"The request is too long.") : OR6L(@"Enter what ChatGPT should do."); return nil; }
    if (!Str(schedule, 4096) || !Str(tz, 128) || ![NSTimeZone timeZoneWithName:tz]) { if (problem) *problem = OR6L(@"Choose when the task runs."); return nil; }
    NSString *mode = Str(timing, 64) ?: @"exact_schedule";
    if (![@[@"exact_schedule", @"flexible_schedule", @"condition_watch"] containsObject:mode]) mode = @"exact_schedule";
    NSDictionary *e = [existing isKindOfClass:NSDictionary.class] ? existing : @{};
    id (^keep)(NSString *, NSUInteger) = ^id(NSString *k, NSUInteger max) { return Str(e[k], max) ?: (id)NSNull.null; };
    id thread = [@[@"new_chat", @"existing_chat"] containsObject:e[@"threadMode"] ?: @""] ? e[@"threadMode"] : (id)NSNull.null;
    return @{@"title": t, @"prompt": p, @"schedule": schedule, @"timezone": tz, @"modelId": keep(@"modelId", 128), @"thinkingEffort": keep(@"thinkingEffort", 64), @"emoji": keep(@"emoji", 64),
             @"emailEnabled": [e[@"emailEnabled"] isEqual:@YES] ? @YES : @NO, @"notificationsEnabled": [e[@"notificationsEnabled"] isEqual:@YES] ? @YES : @NO, @"timingMode": mode, @"threadMode": thread};
}

#pragma mark - Mentions, sizes

NSArray *OR6Chat6MentionRanges(NSString *text, NSArray *inserted) {
    NSMutableArray *out = [NSMutableArray array]; if (![text isKindOfClass:NSString.class]) return out;
    for (NSDictionary *m in [inserted isKindOfClass:NSArray.class] ? inserted : @[]) {
        if (![m isKindOfClass:NSDictionary.class] || !Str(m[@"id"], 256) || !Str(m[@"name"], 240) || ![m[@"location"] isKindOfClass:NSNumber.class] || out.count >= 16) continue;
        NSString *token = [@"@" stringByAppendingString:m[@"name"]]; NSUInteger at = [m[@"location"] unsignedIntegerValue];
        if (at + token.length > text.length || at + token.length > 16000 || ![[text substringWithRange:NSMakeRange(at, token.length)] isEqual:token]) continue;
        BOOL overlap = NO; for (NSDictionary *o in out) if (at < [o[@"endIndex"] unsignedIntegerValue] && at + token.length > [o[@"startIndex"] unsignedIntegerValue]) overlap = YES;
        if (!overlap) [out addObject:@{@"id": m[@"id"], @"startIndex": @(at), @"endIndex": @(at + token.length)}];
    }
    [out sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) { return [a[@"startIndex"] compare:b[@"startIndex"]]; }];
    return out;
}
NSString *OR6Chat6Bytes(id b) { return [b isKindOfClass:NSNumber.class] && [b longLongValue] > 0 ? OR6Chat8Bytes([b unsignedLongLongValue]) : nil; }

#pragma mark - Dates (ISO-8601 with an explicit zone; SDK 6 safe)

static BOOL Digits(NSString *s, NSUInteger at, NSUInteger n, NSInteger *out) {
    if (at + n > s.length) return NO; NSInteger v = 0;
    for (NSUInteger i = at; i < at + n; i++) { unichar c = [s characterAtIndex:i]; if (c < '0' || c > '9') return NO; v = v * 10 + (c - '0'); }
    if (out) *out = v; return YES;
}
NSDate *OR6Chat6ParseDate(id v) {
    if ([v isKindOfClass:NSNumber.class]) { double d = [v doubleValue]; if (d <= 0 || !isfinite(d)) return nil; return [NSDate dateWithTimeIntervalSince1970:d > 1e11 ? d / 1000 : d]; }
    NSString *s = [v isKindOfClass:NSString.class] ? v : nil; if (s.length < 20 || s.length > 40) return nil;
    NSInteger y, mo, d, h, mi, se;
    if (!Digits(s, 0, 4, &y) || [s characterAtIndex:4] != '-' || !Digits(s, 5, 2, &mo) || [s characterAtIndex:7] != '-' || !Digits(s, 8, 2, &d) || [s characterAtIndex:10] != 'T'
        || !Digits(s, 11, 2, &h) || [s characterAtIndex:13] != ':' || !Digits(s, 14, 2, &mi) || [s characterAtIndex:16] != ':' || !Digits(s, 17, 2, &se)) return nil;
    if (mo < 1 || mo > 12 || d < 1 || d > 31 || h > 23 || mi > 59 || se > 60) return nil;
    NSUInteger at = 19; double fraction = 0;
    if (at < s.length && [s characterAtIndex:at] == '.') {
        NSUInteger start = ++at; double scale = 0.1;
        while (at < s.length && [s characterAtIndex:at] >= '0' && [s characterAtIndex:at] <= '9') { fraction += ([s characterAtIndex:at] - '0') * scale; scale /= 10; at++; }
        if (at == start || at - start > 9) return nil;
    }
    if (at >= s.length) return nil; // no zone: refused, never assumed UTC
    NSInteger offset = 0; unichar z = [s characterAtIndex:at];
    if (z == 'Z') { if (at + 1 != s.length) return nil; }
    else if (z == '+' || z == '-') {
        NSInteger oh, om; NSUInteger rest = s.length - at - 1;
        if (rest == 5 && [s characterAtIndex:at + 3] == ':' && Digits(s, at + 1, 2, &oh) && Digits(s, at + 4, 2, &om)) {}
        else if (rest == 4 && Digits(s, at + 1, 2, &oh) && Digits(s, at + 3, 2, &om)) {}
        else return nil;
        if (oh > 14 || om > 59 || (oh == 14 && om)) return nil;
        offset = (oh * 3600 + om * 60) * (z == '-' ? -1 : 1);
    } else return nil;
    NSCalendar *cal = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease]; cal.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    NSDateComponents *c = [[[NSDateComponents alloc] init] autorelease]; c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi; c.second = se;
    NSDate *utc = [cal dateFromComponents:c]; if (!utc) return nil;
    NSDateComponents *back = [cal components:NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit fromDate:utc];
    if (back.year != y || back.month != mo || back.day != d) return nil; // 2026-02-30 and the like
    return [utc dateByAddingTimeInterval:fraction - offset];
}

#pragma mark - Model selection → the chat's catalog

static OR6Chat8Catalog *gChatCatalog;
void OR6Chat6SetChatCatalog(OR6Chat8Catalog *c) { if (c == gChatCatalog) return; [gChatCatalog release]; gChatCatalog = [c retain]; }
OR6Chat8Catalog *OR6Chat6ChatCatalog(void) { return gChatCatalog; }
BOOL OR6Chat6ApplySelection(OR6Chat8Catalog *catalog, NSDictionary *sel) {
    NSString *model = Str(sel[@"modelId"], 128); if (!catalog.loaded || !model) return NO;
    NSDictionary *mode = [catalog modeForModel:model]; if (!mode) return NO;
    NSString *effort = Str(sel[@"thinkingEffort"], 64); BOOL offered = NO;
    for (NSDictionary *e in [mode[@"efforts"] isKindOfClass:NSArray.class] ? mode[@"efforts"] : @[]) if ([e[@"id"] isEqual:effort]) offered = YES;
    return [catalog selectModel:model effort:offered ? effort : nil];
}

#pragma mark - PIN reset route, first-party pages

NSString *OR6Chat6PINResetRoute(BOOL nativeHost, BOOL resetCallable) { return nativeHost && resetCallable ? @"native" : @"web"; }
NSURL *OR6Chat6PINSettingsURL(void) { return [NSURL URLWithString:@"https://chatgpt.com/settings/security?view=account-pin"]; }
NSURL *OR6Chat6GPTPageURL(NSString *g) {
    if (!Str(g, 128) || ![g hasPrefix:@"g-"] || g.length < 4) return nil;
    NSCharacterSet *bad = [[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"] invertedSet];
    return [g rangeOfCharacterFromSet:bad].location == NSNotFound ? [NSURL URLWithString:[@"https://chatgpt.com/g/" stringByAppendingString:g]] : nil;
}

#pragma mark - Auto preference observation

@interface OR6Chat6AutoPreference () { OR6APICore *_core; id<OR6APITask> _task; NSDictionary *_cached; NSDate *_at; NSUInteger _generation, _epoch, _reads; NSString *_lastIssue; BOOL _stopped, _busy; NSTimeInterval _lifetime; NSMutableArray *_waiting; }
@end
@implementation OR6Chat6AutoPreference
@synthesize lifetime = _lifetime, lastIssue = _lastIssue, stopped = _stopped, busy = _busy, reads = _reads;
+ (OR6Chat6AutoPreference *)forCore:(OR6APICore *)core {
    // The app has one active Core. Retain only its observation; a replaced Core and
    // its old waiters must not remain in a process-wide collection forever.
    static OR6Chat6AutoPreference *active;
    if (active && active->_core == core) return active;
    [active invalidate]; [active release]; active = nil;
    if (!core) return nil;
    active = [OR6Chat6AutoPreference new]; active->_core = [core retain]; active->_lifetime = 300; active->_waiting = [NSMutableArray new]; active->_generation = OR6Chat7Generation(core);
    return active;
}
- (void)syncGeneration {
    NSUInteger g = OR6Chat7Generation(_core); if (g == _generation) return;
    [self invalidate]; _generation = g; _stopped = NO; [_lastIssue release]; _lastIssue = nil;
}
- (BOOL)request:(void (^)(NSDictionary *))apply {
    [self syncGeneration];
    if (_cached && _at && -[_at timeIntervalSinceNow] < _lifetime) { if (apply) apply(_cached); return YES; }
    if (_stopped || !OR6Chat7Callable(_core, @"modelControls.autoPreference.get")) return NO;
    if (apply) [_waiting addObject:[[apply copy] autorelease]];
    if (_busy) return YES;
    _busy = YES; _reads++; NSUInteger epoch = ++_epoch, generation = _generation;
    id<OR6APITask> task = [_core perform:@"modelControls.autoPreference.get" parameters:@{@"temporary": @NO} event:nil completion:^(NSDictionary *r, NSError *e) {
        if (epoch != _epoch || generation != OR6Chat7Generation(_core)) return; // late or another owner's context
        _busy = NO; [(id)_task release]; _task = nil; NSArray *waiting = [[_waiting copy] autorelease]; [_waiting removeAllObjects];
        if (e || ![r isKindOfClass:NSDictionary.class]) {
            NSString *code = [e.userInfo[@"code"] isKindOfClass:NSString.class] ? e.userInfo[@"code"] : @"invalid_response";
            [_lastIssue release]; _lastIssue = [code copy];
            if (OR6Chat8StopSignal(code) || [@[@"not_authenticated", @"login_required", @"session_recovery", @"stale_context"] containsObject:code]) _stopped = YES; // no further automatic read in this context
            return;
        }
        [_lastIssue release]; _lastIssue = nil; [_cached release]; _cached = [r copy]; [_at release]; _at = [[NSDate date] retain];
        for (void (^b)(NSDictionary *) in waiting) b(_cached);
    }];
    if (_busy && epoch == _epoch) _task = [(id)task retain];
    return YES;
}
- (void)invalidate {
    _epoch++; _busy = NO; [_waiting removeAllObjects];
    id<OR6APITask> task = _task; _task = nil;
    [_cached release]; _cached = nil; [_at release]; _at = nil;
    [task cancel]; [(id)task release]; // the epoch discards even a synchronous cancellation reply
    // A preference write cannot reset a service stop for this Core generation.
}
- (void)dealloc { [self invalidate]; [_waiting release]; [_lastIssue release]; [_core release]; [super dealloc]; }
- (NSDictionary *)diagnostics { return @{@"lastIssue": _lastIssue ?: @"", @"stopped": @(_stopped), @"busy": @(_busy), @"reads": @(_reads), @"cached": @(_cached != nil)}; }
@end
