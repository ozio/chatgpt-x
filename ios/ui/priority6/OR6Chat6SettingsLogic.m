#import "OR6Chat6SettingsLogic.h"
#import "../../localization/OR6Localization.h"

static NSString *Str(id v, NSUInteger max) { return [v isKindOfClass:NSString.class] && [v length] && [v length] <= max ? v : nil; }
static NSDictionary *Dict(id v) { return [v isKindOfClass:NSDictionary.class] ? v : nil; }
static NSArray *Arr(id v) { return [v isKindOfClass:NSArray.class] ? v : nil; }

#pragma mark - Apps

NSDictionary *OR6Chat6AppsCatalogParameters(NSString *query) {
    NSString *q = [query isKindOfClass:NSString.class] ? [query stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : @"";
    return q.length <= 240 ? @{@"query": q} : nil;
}
NSArray *OR6Chat6AppActions(NSDictionary *p) {
    if (!Str(Dict(p)[@"id"], 256)) return @[];
    BOOL installed = [p[@"installed"] isEqual:@YES], enabled = [p[@"enabled"] isEqual:@YES], local = [p[@"requiresLocalExecutor"] isEqual:@YES];
    BOOL open = [p[@"status"] isEqual:@"ENABLED"] && ![p[@"installationPolicy"] isEqual:@"NOT_AVAILABLE"];
    NSMutableArray *a = [NSMutableArray array];
    if (!installed && open && !local) [a addObject:@"install"];
    if (installed && !enabled && open) [a addObject:@"enable"];
    if (installed && enabled) [a addObject:@"disable"];
    if (installed && ![p[@"installationPolicy"] isEqual:@"INSTALLED_BY_DEFAULT"]) [a addObject:@"remove"];
    return a;
}
NSDictionary *OR6Chat6AppMutation(NSString *action, NSDictionary *plugin) {
    NSString *op = @{@"install": @"connectors.install", @"enable": @"connectors.enable", @"disable": @"connectors.disable", @"remove": @"connectors.remove"}[action ?: @""];
    if (!op || ![OR6Chat6AppActions(plugin) containsObject:action]) return nil;
    NSString *pid = plugin[@"id"];
    return @{@"operation": op, @"parameters": @{@"pluginId": pid, @"confirm": @YES}, @"intent": [NSString stringWithFormat:@"%@:%@", op, pid]};
}
NSString *OR6Chat6ServiceLabel(id v) {
    NSString *s = Str(v, 128); if (!s) return nil;
    NSDictionary *known = @{@"ENABLED": OR6L(@"Available"), @"DISABLED": OR6L(@"Turned off"), @"DISABLED_BY_ADMIN": OR6L(@"Turned off by your admin"),
                            @"AVAILABLE": OR6L(@"Can be installed"), @"NOT_AVAILABLE": OR6L(@"Not available for this account"), @"INSTALLED_BY_DEFAULT": OR6L(@"Installed by default"),
                            @"REAUTH_REQUIRED": OR6L(@"Sign in to the app again"), @"CONNECTED": OR6L(@"Connected"), @"ACTIVE": OR6L(@"Active")};
    if (known[s]) return known[s];
    NSString *words = [[s stringByReplacingOccurrencesOfString:@"_" withString:@" "] lowercaseString];
    return words.length ? [[[words substringToIndex:1] uppercaseString] stringByAppendingString:[words substringFromIndex:1]] : nil;
}
NSArray *OR6Chat6DefaultPolicies(void) { return @[@"always_ask", @"ask_before_writes", @"review_important_actions"]; }
NSArray *OR6Chat6LinkPolicies(void) { return @[@"always_ask", @"ask_before_writes", @"review_important_actions", @"full_access", NSNull.null]; }
NSString *OR6Chat6PolicyLabel(id p) {
    if (!p || p == NSNull.null) return OR6L(@"Use default");
    if ([p isEqual:@"always_ask"]) return OR6L(@"Always ask");
    if ([p isEqual:@"ask_before_writes"]) return OR6L(@"Ask before changes");
    if ([p isEqual:@"review_important_actions"]) return OR6L(@"Review important actions");
    if ([p isEqual:@"full_access"]) return OR6L(@"Full access");
    return nil;
}
NSDictionary *OR6Chat6DefaultPolicyParameters(id p) { return p && [OR6Chat6DefaultPolicies() containsObject:p] ? @{@"policy": p} : nil; }
NSDictionary *OR6Chat6LinkPolicyParameters(NSString *linkId, id p) {
    id policy = p ?: NSNull.null;
    return Str(linkId, 256) && [OR6Chat6LinkPolicies() containsObject:policy] ? @{@"linkId": linkId, @"policy": policy} : nil;
}
NSDictionary *OR6Chat6DisconnectParameters(NSString *linkId) { return Str(linkId, 256) ? @{@"linkId": linkId, @"confirm": @YES} : nil; }

#pragma mark - Receipts

NSString *OR6Chat6ReceiptOutcome(NSDictionary *r) {
    if (!Dict(r)) return @"unconfirmed";
    id state = r[@"state"], confirmed = r[@"confirmed"];
    if (!state && !confirmed) return @"result";
    if ([state isEqual:@"rejected"]) return @"rejected";
    if ([state isEqual:@"completed"] && [confirmed isEqual:@YES]) return @"confirmed";
    return @"unconfirmed"; // uncertain, or completed but not read back: unknown, never resent
}

#pragma mark - Voice

static NSArray *Modes(void) { return @[@"standard", @"advanced", @"wingman"]; }
NSString *OR6Chat6VoiceModeName(id m) {
    if ([m isEqual:@"standard"]) return OR6L(@"Standard");
    if ([m isEqual:@"advanced"]) return OR6L(@"Advanced");
    if ([m isEqual:@"wingman"]) return OR6L(@"Wingman");
    return nil;
}
NSDictionary *OR6Chat6VoiceCatalogParameters(NSDictionary *s) {
    id mode = Dict(s)[@"mode"]; NSString *language = Str(s[@"language"], 32);
    return mode && language && [Modes() containsObject:mode] ? @{@"mode": mode, @"language": language} : nil;
}
static NSDictionary *Voice(NSDictionary *catalog, NSString *voiceId) {
    if (!Str(Dict(catalog)[@"catalogId"], 36) || !Str(voiceId, 128)) return nil;
    for (NSDictionary *v in Arr(catalog[@"items"])) if ([Dict(v)[@"id"] isEqual:voiceId]) return v;
    return nil;
}
NSDictionary *OR6Chat6VoiceSelectParameters(NSDictionary *catalog, NSString *voiceId) {
    return Voice(catalog, voiceId) ? @{@"catalogId": catalog[@"catalogId"], @"voiceId": voiceId} : nil;
}
NSDictionary *OR6Chat6VoicePreviewParameters(NSDictionary *catalog, NSString *voiceId) {
    NSDictionary *v = Voice(catalog, voiceId);
    return [v[@"previewAvailable"] isEqual:@YES] ? @{@"operationId": OR6Chat7OperationID(), @"catalogId": catalog[@"catalogId"], @"voiceId": voiceId} : nil;
}
NSDictionary *OR6Chat6VoiceModeParameters(id mode, NSDictionary *s) {
    NSString *language = Str(Dict(s)[@"language"], 32);
    return mode && language && [Modes() containsObject:mode] ? @{@"mode": mode, @"language": language} : nil;
}
NSDictionary *OR6Chat6VoiceLanguageParameters(id language, NSDictionary *languages) {
    if (!Str(language, 32)) return nil;
    for (NSDictionary *l in Arr(Dict(languages)[@"items"])) if ([Dict(l)[@"id"] isEqual:language]) return @{@"language": language};
    return nil;
}
NSString *OR6Chat6VoiceLanguageName(NSString *identifier, NSLocale *locale) {
    if (!Str(identifier, 32)) return nil;
    if ([identifier isEqual:@"auto"]) return OR6L(@"Automatic");
    NSString *name = [(locale ?: [NSLocale currentLocale]) displayNameForKey:NSLocaleIdentifier value:identifier];
    if (!name.length) return identifier;
    return [[[name substringToIndex:1] uppercaseStringWithLocale:locale] stringByAppendingString:[name substringFromIndex:1]];
}
NSArray *OR6Chat6VoiceLanguages(NSDictionary *languages, NSLocale *locale) {
    NSMutableArray *out = [NSMutableArray array]; NSDictionary *automatic = nil; NSMutableSet *seen = [NSMutableSet set];
    for (NSDictionary *l in Arr(Dict(languages)[@"items"])) {
        NSString *i = Str(Dict(l)[@"id"], 32); if (!i || [seen containsObject:i]) continue; [seen addObject:i];
        NSDictionary *row = @{@"id": i, @"title": OR6Chat6VoiceLanguageName(i, locale)};
        if ([i isEqual:@"auto"]) automatic = row; else [out addObject:row];
    }
    [out sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) { return [a[@"title"] compare:b[@"title"] options:NSCaseInsensitiveSearch range:NSMakeRange(0, [a[@"title"] length]) locale:locale]; }];
    if (automatic) [out insertObject:automatic atIndex:0];
    return out;
}
NSString *OR6Chat6PlainMarkdown(NSString *md) {
    if (![md isKindOfClass:NSString.class]) return @"";
    NSMutableString *s = [[md mutableCopy] autorelease];
    NSArray *rules = @[@[@"\\[([^\\]]*)\\]\\([^)]*\\)", @"$1"], @[@"^[ \\t]{0,3}#{1,6}[ \\t]*", @""], @[@"^[ \\t]*[-*+][ \\t]+", @"• "], @[@"(\\*\\*|__|~~|`|\\*)", @""]];
    for (NSArray *r in rules) {
        NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:r[0] options:NSRegularExpressionAnchorsMatchLines error:NULL];
        [re replaceMatchesInString:s options:0 range:NSMakeRange(0, s.length) withTemplate:r[1]];
    }
    return [s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}
NSArray *OR6Chat6VoiceNotices(NSDictionary *usage) {
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *kind in @[@"exceeded", @"warning"]) {
        NSDictionary *n = Dict(Dict(usage)[kind]); NSString *i = Str(n[@"id"], 36); if (!i) continue;
        NSMutableDictionary *row = [NSMutableDictionary dictionaryWithDictionary:@{@"kind": kind, @"id": i, @"title": Str(n[@"title"], 240) ?: @"", @"text": OR6Chat6PlainMarkdown(n[@"descriptionMarkdown"]),
                                                                                  @"hint": Str(n[@"hint"], 1000) ?: @"", @"switchToStandard": @([Arr(n[@"actions"]) containsObject:@"switch_to_standard"])}];
        if (Str(usage[@"resetsAfter"], 40)) row[@"resetsAfter"] = usage[@"resetsAfter"];
        [out addObject:row];
    }
    return out;
}
static NSString *Clock(id v) { int t = [v isKindOfClass:NSNumber.class] ? (int)([v doubleValue] + 0.5) : 0; if (t < 0) t = 0; return [NSString stringWithFormat:@"%d:%02d", t / 60, t % 60]; }
NSString *OR6Chat6PlaybackText(NSDictionary *p) {
    id state = Dict(p)[@"state"];
    if ([state isEqual:@"failed"]) return OR6L(@"The sample could not be played.");
    if (![state isEqual:@"playing"] && ![state isEqual:@"paused"]) return nil;
    return [NSString stringWithFormat:([state isEqual:@"playing"] ? OR6L(@"Playing · %@ of %@") : OR6L(@"Paused · %@ of %@")), Clock(p[@"position"]), Clock(p[@"duration"])];
}

#pragma mark - Models

NSString *OR6Chat6LaneName(id lane) {
    NSDictionary *n = @{@"auto": OR6L(@"Auto"), @"instant": OR6L(@"Instant"), @"thinking": OR6L(@"Thinking"), @"thinking_mini": OR6L(@"Thinking mini"), @"pro": OR6L(@"Pro")};
    return [lane isKindOfClass:NSString.class] ? n[lane] : nil;
}
NSArray *OR6Chat6ModelFamilies(NSDictionary *catalog) {
    NSMutableArray *order = [NSMutableArray array]; NSMutableDictionary *byId = [NSMutableDictionary dictionary];
    for (NSDictionary *m in Arr(Dict(catalog)[@"items"])) {
        NSString *f = Str(Dict(m)[@"familyId"], 128); if (!f || !Str(m[@"id"], 128) || !OR6Chat6LaneName(m[@"lane"])) continue;
        NSMutableDictionary *fam = byId[f];
        if (!fam) { fam = [NSMutableDictionary dictionaryWithDictionary:@{@"familyId": f, @"title": Str(m[@"familyTitle"], 240) ?: f, @"versions": [NSMutableArray array]}]; byId[f] = fam; [order addObject:fam]; }
        [fam[@"versions"] addObject:m];
    }
    return order;
}
static NSArray *Efforts(NSDictionary *m) { NSMutableArray *a = [NSMutableArray array]; for (NSDictionary *e in Arr(m[@"efforts"])) if (Str(Dict(e)[@"id"], 32)) [a addObject:e[@"id"]]; return a; }
NSDictionary *OR6Chat6ModelSelectParameters(NSDictionary *m, id effort) {
    id e = effort ?: NSNull.null;
    if (!Str(Dict(m)[@"familyId"], 128) || !OR6Chat6LaneName(m[@"lane"]) || (e != NSNull.null && ![Efforts(m) containsObject:e])) return nil;
    return @{@"versionId": m[@"familyId"], @"lane": m[@"lane"], @"thinkingEffort": e, @"temporary": @NO};
}
NSDictionary *OR6Chat6AutoPreferenceParameters(BOOL prefersAuto) { return @{@"prefersAuto": @(prefersAuto), @"temporary": @NO}; }
NSString *OR6Chat6SelectionText(NSDictionary *s, NSDictionary *catalog) {
    if (!Str(Dict(s)[@"modelId"], 128)) return nil;
    NSDictionary *model = nil;
    for (NSDictionary *m in Arr(Dict(catalog)[@"items"])) if ([Dict(m)[@"id"] isEqual:s[@"modelId"]] && [m[@"lane"] isEqual:s[@"lane"]]) model = m;
    if (!model) for (NSDictionary *m in Arr(Dict(catalog)[@"items"])) if ([Dict(m)[@"id"] isEqual:s[@"modelId"]]) model = m;
    NSMutableArray *parts = [NSMutableArray arrayWithObject:Str(model[@"title"], 240) ?: OR6L(@"Model")];
    if (OR6Chat6LaneName(s[@"lane"]) && ![parts[0] isEqual:OR6Chat6LaneName(s[@"lane"])]) [parts addObject:OR6Chat6LaneName(s[@"lane"])];
    for (NSDictionary *e in Arr(model[@"efforts"])) if ([Dict(e)[@"id"] isEqual:s[@"thinkingEffort"]] && Str(e[@"title"], 240)) [parts addObject:e[@"title"]];
    return [parts componentsJoinedByString:@" · "];
}

#pragma mark - Sign-in handoffs

NSArray *OR6Chat6SignInHandoffCandidates(void) {
    return @[@{@"key": @"phone", @"title": OR6L(@"Phone number"), @"operation": @"account.auth.phone"},
             @{@"key": @"email_code", @"title": OR6L(@"E-mail code"), @"operation": @"account.auth.emailCode"},
             @{@"key": @"password_reset", @"title": OR6L(@"Forgot password"), @"operation": @"account.auth.passwordReset"},
             @{@"key": @"signup", @"title": OR6L(@"Create an account"), @"operation": @"account.auth.signup"},
             @{@"key": @"mfa_push", @"title": OR6L(@"Approve on another device"), @"operation": @"account.auth.mfaPush"},
             @{@"key": @"recovery_code", @"title": OR6L(@"Use a recovery code"), @"operation": @"account.auth.recoveryCode"}];
}
NSURL *OR6Chat6SignInHandoffURL(NSDictionary *h) {
    id completed = Dict(h)[@"completed"];
    if (![completed isKindOfClass:NSNumber.class] || [completed boolValue] || !Str(h[@"url"], 2048)) return nil;
    NSURL *u = [NSURL URLWithString:h[@"url"]];
    if (![u.scheme.lowercaseString isEqual:@"https"] || ![u.host.lowercaseString isEqual:@"chatgpt.com"] || u.user || u.password || u.port) return nil;
    return u;
}

#pragma mark - Settings write

static NSMutableDictionary *gPendingWrites; // intent → {operationId, reconcile}: unresolved writes of this session
static void Remember(NSString *intent, NSString *oid, NSString *reconcile) {
    if (!intent || !oid || !reconcile) return;
    if (!gPendingWrites) gPendingWrites = [NSMutableDictionary new];
    gPendingWrites[intent] = @{@"operationId": oid, @"reconcile": reconcile};
}
static void Forget(NSString *intent) { if (!intent) return; [gPendingWrites removeObjectForKey:intent]; OR6Chat7ForgetUnresolvedKey(intent); }

@interface OR6Chat6SettingsWrite () {
    OR6APICore *_core; NSString *_reconcile; OR6Chat7Write *_write; id<OR6APITask> _task; NSUInteger _epoch;
}
@end
@implementation OR6Chat6SettingsWrite
@synthesize delegate = _delegate, outcome = _outcome, operation = _operation, intent = _intent, operationId = _operationId, receipt = _receipt, error = _error;
- (id)initWithCore:(OR6APICore *)core reconcile:(NSString *)reconcile {
    if ((self = [super init])) { _core = [core retain]; _reconcile = [reconcile copy]; _outcome = [@"idle" copy]; }
    return self;
}
- (void)set:(NSString *)o { [_outcome release]; _outcome = [o copy]; [[self retain] autorelease]; [_delegate chat8ModelChanged:self]; }
- (BOOL)open { return [_outcome isEqual:@"running"] || [_outcome isEqual:@"checking"]; }
- (void)classify:(NSDictionary *)r {
    [_receipt release]; _receipt = [r copy];
    NSString *o = OR6Chat6ReceiptOutcome(r);
    if ([o isEqual:@"confirmed"] || [o isEqual:@"result"]) { Forget(_intent); [self set:@"confirmed"]; return; }
    if ([o isEqual:@"rejected"]) { Forget(_intent); [self set:@"rejected"]; return; }
    OR6Chat7MarkUnresolved(_intent); Remember(_intent, _operationId, _reconcile); [self set:@"unconfirmed"];
}
- (void)chat8ModelChanged:(id)m {
    if (m != _write) return;
    NSString *p = _write.phase;
    if (!_operationId && _write.operationId) _operationId = [_write.operationId copy];
    [_error release]; _error = [_write.error retain];
    if ([p isEqual:@"running"]) { Remember(_intent, _operationId, _reconcile); [self set:@"running"]; }
    else if ([p isEqual:@"reconciling"]) [self set:@"checking"];
    else if ([p isEqual:@"done"]) [self classify:_write.receipt];
    else if ([p isEqual:@"uncertain"]) { Remember(_intent, _operationId, _reconcile); [self set:@"uncertain"]; }
    else if ([p isEqual:@"failed"]) { [gPendingWrites removeObjectForKey:_intent ?: @""]; [self set:@"failed"]; }
    else if ([p isEqual:@"blocked"]) [self set:@"blocked"];
}
- (BOOL)perform:(NSString *)op parameters:(NSDictionary *)p intent:(NSString *)intent {
    if ([self open] || [_outcome isEqual:@"unconfirmed"] || [_outcome isEqual:@"uncertain"] || !intent.length) return NO;
    _write.delegate = nil; [_write release];
    _write = [[OR6Chat7Write alloc] initWithCore:_core reconcile:_reconcile]; _write.delegate = self;
    [_operation release]; _operation = [op copy]; [_intent release]; _intent = [intent copy];
    [_operationId release]; _operationId = nil; [_receipt release]; _receipt = nil; [_error release]; _error = nil;
    if ([_write perform:op parameters:p intent:intent]) return YES;
    _write.delegate = nil; [_write release]; _write = nil;
    return NO;
}
- (BOOL)check {
    if (!([_outcome isEqual:@"unconfirmed"] || [_outcome isEqual:@"uncertain"])) return NO;
    return _write ? [_write reconcile] : [self checkIntent:_intent]; // without a write: an earlier one checked by its intent
}
- (BOOL)checkIntent:(NSString *)intent {
    NSDictionary *pending = intent ? gPendingWrites[intent] : nil;
    if ([self open] || !pending || !OR6Chat7IsUnresolved(intent) || !OR6Chat7Callable(_core, pending[@"reconcile"])) return NO;
    _write.delegate = nil; [_write release]; _write = nil;
    [_intent release]; _intent = [intent copy]; [_operationId release]; _operationId = [pending[@"operationId"] copy];
    [_reconcile release]; _reconcile = [pending[@"reconcile"] copy];
    NSUInteger epoch = ++_epoch; __block BOOL finished = NO;
    [self set:@"checking"];
    id<OR6APITask> t = [_core perform:_reconcile parameters:@{@"operationId": _operationId} event:nil completion:^(NSDictionary *r, NSError *e) {
        finished = YES; if (epoch != _epoch) return;
        [_task release]; _task = nil;
        if (e) { [_error release]; _error = [e retain]; [self set:@"uncertain"]; return; } // still unknown: the latch stays
        [self classify:r];
    }];
    if (!finished && epoch == _epoch) _task = [t retain];
    return YES;
}
- (void)cancel {
    _epoch++; [_task cancel]; [_task release]; _task = nil;
    if (_write) [_write cancel]; else if ([_outcome isEqual:@"checking"]) [self set:@"uncertain"];
}
- (void)dealloc {
    _epoch++; [_task cancel]; [_task release]; _write.delegate = nil; [_write release];
    [_core release]; [_reconcile release]; [_outcome release]; [_operation release]; [_intent release]; [_operationId release]; [_receipt release]; [_error release];
    [super dealloc];
}
@end

NSDictionary *OR6Chat6ConnectionsParameters(void) { return @{@"pageToken": NSNull.null, @"includeConnections": @YES}; }
NSArray *OR6Chat6Connections(NSDictionary *page) {
    NSMutableArray *out = [NSMutableArray array]; NSMutableSet *seen = [NSMutableSet set];
    id list = [page isKindOfClass:NSDictionary.class] ? page[@"connections"] : nil;
    for (NSDictionary *c in [list isKindOfClass:NSArray.class] ? list : @[]) {
        if (![c isKindOfClass:NSDictionary.class]) continue;
        id i = c[@"id"], k = c[@"connectorId"], a = c[@"authStatus"];
        if (![i isKindOfClass:NSString.class] || ![i length] || [i length] > 256 || ![k isKindOfClass:NSString.class] || ![k length] || [k length] > 256 || [seen containsObject:i]) continue;
        [seen addObject:i];
        [out addObject:@{@"id": i, @"connectorId": k, @"name":Str(c[@"name"],240) ?: @"", @"authStatus": [a isKindOfClass:NSString.class] ? a : @"", @"privacyControl": c[@"privacyControl"] ?: NSNull.null}];
        if (out.count >= 128) break;
    }
    return out;
}
