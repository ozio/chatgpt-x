#import "OR6Chat6AccountLogic.h"
#import "../../localization/OR6Localization.h"

NSString *const OR6Chat6DeleteConfirmationWord = @"DELETE";

static NSString *Str(id v, NSUInteger max) { return [v isKindOfClass:NSString.class] && [v length] && [v length] <= max ? v : nil; }
static NSNumber *Count(id v) { return [v isKindOfClass:NSNumber.class] && strcmp([v objCType], @encode(BOOL)) != 0 && [v longLongValue] >= 0 ? v : nil; }
static NSString *Trim(NSString *s) { return [s isKindOfClass:NSString.class] ? [s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : nil; }

#pragma mark - Memories and settings

NSDictionary *OR6Chat6MemoryDeleteRequest(NSDictionary *m) {
    if (![m isKindOfClass:NSDictionary.class]) return nil;
    NSString *rev = Str(m[@"revision"], 64), *ident = Str(m[@"id"], 128);
    return rev && ident ? @{@"expectedRevision": rev, @"memoryId": ident, @"confirmed": @YES} : nil;
}
BOOL OR6Chat6MemoryIsPriority(NSDictionary *m) { return [m isKindOfClass:NSDictionary.class] && [m[@"status"] isEqual:@"warm"]; }
NSDictionary *OR6Chat6MemoryPrioritizeRequest(NSDictionary *m) {
    if (![m isKindOfClass:NSDictionary.class] || OR6Chat6MemoryIsPriority(m)) return nil;
    NSString *rev = Str(m[@"revision"], 64), *ident = Str(m[@"id"], 128);
    return rev && ident ? @{@"expectedRevision": rev, @"memoryId": ident} : nil;
}
NSDictionary *OR6Chat6MemoryDeleteAllRequest(NSDictionary *list) {
    if (![list isKindOfClass:NSDictionary.class] || ![list[@"items"] isKindOfClass:NSArray.class] || ![list[@"items"] count]) return nil;
    if ([list[@"query"] isKindOfClass:NSString.class] && [list[@"query"] length]) return nil; // a search result is not the whole list
    NSString *rev = Str(list[@"revision"], 64);
    return rev ? @{@"expectedRevision": rev, @"confirmed": @YES} : nil;
}
NSDictionary *OR6Chat6SettingRequest(NSDictionary *state, BOOL enabled) {
    NSString *rev = [state isKindOfClass:NSDictionary.class] ? Str(state[@"revision"], 64) : nil;
    return rev ? @{@"expectedRevision": rev, @"enabled": @(enabled)} : nil;
}
NSString *OR6Chat6MemorySearchQuery(NSString *typed) {
    NSString *q = Trim(typed);
    if (!q.length) return nil;
    if (q.length > 1000) q = Trim([q substringToIndex:[q rangeOfComposedCharacterSequenceAtIndex:1000].location]);
    return q.length ? q : nil;
}
NSArray *OR6Chat6MemoryFilter(NSArray *items, NSString *query) {
    NSString *q = OR6Chat6MemorySearchQuery(query); NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *m in [items isKindOfClass:NSArray.class] ? items : @[]) {
        if (![m isKindOfClass:NSDictionary.class] || ![m[@"content"] isKindOfClass:NSString.class]) continue;
        if (!q || [m[@"content"] rangeOfString:q options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location != NSNotFound) [out addObject:m];
    }
    return out;
}
static NSString *Grouped(NSNumber *n) {
    NSNumberFormatter *f = [[[NSNumberFormatter alloc] init] autorelease]; f.numberStyle = NSNumberFormatterDecimalStyle;
    return [f stringFromNumber:n];
}
NSString *OR6Chat6MemoryCapacityText(NSDictionary *c) {
    if (![c isKindOfClass:NSDictionary.class]) return nil;
    NSNumber *pct = Count(c[@"percentUsed"]), *used = Count(c[@"usedTokens"]), *max = Count(c[@"maxTokens"]);
    if (pct && pct.intValue <= 100) return [NSString stringWithFormat:OR6L(@"Memory is %d%% full"), pct.intValue];
    if (used && max && max.longLongValue > 0) return [NSString stringWithFormat:OR6L(@"%@ of %@ tokens used"), Grouped(used), Grouped(max)];
    return nil;
}
BOOL OR6Chat6MemoryAlmostFull(NSDictionary *c) {
    if (![c isKindOfClass:NSDictionary.class]) return NO;
    NSNumber *pct = Count(c[@"percentUsed"]), *used = Count(c[@"usedTokens"]), *max = Count(c[@"maxTokens"]);
    if (pct) return pct.intValue >= 80;
    return used && max && max.longLongValue > 0 && used.doubleValue >= 0.8 * max.doubleValue;
}

#pragma mark - Account requests

BOOL OR6Chat6DeleteConfirmationValid(NSString *typed) { return [Trim(typed) isEqualToString:OR6Chat6DeleteConfirmationWord]; }
NSDictionary *OR6Chat6DeleteAccountRequest(NSString *typed) {
    return OR6Chat6DeleteConfirmationValid(typed) ? @{@"confirmed": @YES, @"confirmation": OR6Chat6DeleteConfirmationWord} : nil;
}
NSDictionary *OR6Chat6ExportRequest(void) { return @{@"confirmed": @YES}; }

NSString *OR6Chat6AccountActionText(id a) {
    if ([a isEqual:@"reauthenticate"]) return OR6L(@"The service asks you to sign in again first. Sign in on the web, then make the request again.");
    if ([a isEqual:@"verify_phone"]) return OR6L(@"The service asks you to verify your phone number first. Continue on the web.");
    if ([a isEqual:@"add_email"]) return OR6L(@"Your account needs an e-mail address first. Continue on the web.");
    if ([a isEqual:@"wait_for_export"]) return OR6L(@"An export is already being prepared. Wait for its e-mail before you request another one.");
    if ([a isEqual:@"contact_organization"]) return OR6L(@"Your organization manages this account. Ask its administrator.");
    if ([a isEqual:@"transfer_workspace_ownership"]) return OR6L(@"You own a workspace. Transfer its ownership on the web before you delete the account.");
    return nil;
}
NSString *OR6Chat6AccountReceiptText(NSDictionary *r, NSString *command) {
    if (![r isKindOfClass:NSDictionary.class]) return nil;
    BOOL del = [command isEqual:@"privacy.deleteAccount"];
    NSString *action = OR6Chat6AccountActionText(r[@"actionRequired"]), *state = r[@"state"];
    if (action) return action;
    if ([state isEqual:@"rejected"]) return OR6L(@"The service did not accept the request.");
    if ([state isEqual:@"verified"] && [r[@"verified"] isEqual:@YES])
        return del ? OR6L(@"Your account is deleted. ChatGPT X will sign out.") : OR6L(@"The service confirmed your export request. The download link will arrive by e-mail.");
    if (([state isEqual:@"acknowledged"] || [state isEqual:@"verified"]) && [r[@"serverAcknowledged"] isEqual:@YES])
        return del ? OR6L(@"The service accepted the request to delete your account. ChatGPT X will sign out.")
                   : ([r[@"delivery"] isEqual:@"email"] ? OR6L(@"The service accepted your export request. The download link will arrive by e-mail when the export is ready.")
                                                         : OR6L(@"The service accepted your export request."));
    return OR6L(@"The result of the request is not known yet.");
}
NSString *OR6Chat6AccountStatusText(NSDictionary *s) {
    if (![s isKindOfClass:NSDictionary.class] || ![s[@"state"] isKindOfClass:NSString.class]) return nil;
    NSDictionary *r = [s[@"receipt"] isKindOfClass:NSDictionary.class] ? s[@"receipt"] : nil; NSString *state = s[@"state"];
    if ([state isEqual:@"completed"]) return r ? OR6Chat6AccountReceiptText(r, s[@"command"]) : OR6L(@"The service finished the request.");
    if ([state isEqual:@"rejected"]) return OR6Chat6AccountActionText(r[@"actionRequired"]) ?: OR6L(@"The service did not accept the request.");
    if ([state isEqual:@"reserved"]) return OR6L(@"The request was started, but its result is not known yet.");
    if ([state isEqual:@"uncertain"]) return OR6L(@"The result of the request is not known yet.");
    return nil;
}
BOOL OR6Chat6AccountStatusSettled(NSDictionary *s, NSString *operationId) {
    return [s isKindOfClass:NSDictionary.class] && operationId && [s[@"operationId"] isEqual:operationId] && ([s[@"state"] isEqual:@"completed"] || [s[@"state"] isEqual:@"rejected"]);
}

#pragma mark - Sessions

NSString *OR6Chat6SessionRefusal(NSDictionary *d) {
    if (![d isKindOfClass:NSDictionary.class] || !Str(d[@"targetId"], 36)) return @"invalid";
    if ([d[@"isCurrent"] isEqual:@YES]) return @"current";
    if (![d[@"kind"] isEqual:@"session"] && ![d[@"kind"] isEqual:@"signed_out_trusted"]) return @"unavailable";
    if (![d[@"canRevoke"] isEqual:@YES]) return @"not_allowed";
    return nil;
}
BOOL OR6Chat6SessionCatalogFresh(NSDate *readAt, NSDate *now) {
    if (![readAt isKindOfClass:NSDate.class] || ![now isKindOfClass:NSDate.class]) return NO;
    NSTimeInterval age = [now timeIntervalSinceDate:readAt];
    return age >= 0 && age < 270; // the service expires the IDs after 300 s; keep a margin for the confirmation
}
NSDictionary *OR6Chat6SessionRevokeRequest(NSDictionary *sessions, NSDictionary *d, NSDate *readAt, NSDate *now) {
    NSString *catalog = [sessions isKindOfClass:NSDictionary.class] ? Str(sessions[@"catalogId"], 36) : nil;
    if (!catalog || OR6Chat6SessionRefusal(d) || !OR6Chat6SessionCatalogFresh(readAt, now)) return nil;
    BOOL listed = NO; for (id i in [sessions[@"items"] isKindOfClass:NSArray.class] ? sessions[@"items"] : @[]) if ([i isKindOfClass:NSDictionary.class] && [i[@"targetId"] isEqual:d[@"targetId"]]) listed = YES;
    return listed ? @{@"catalogId": catalog, @"targetId": d[@"targetId"], @"confirm": @YES} : nil;
}
NSDictionary *OR6Chat6SessionRevokeAllRequest(void) { return @{@"confirmRevokeAllSessions": @YES}; }
NSString *OR6Chat6SessionKindText(NSDictionary *d) {
    if (![d isKindOfClass:NSDictionary.class]) return nil;
    if ([d[@"kind"] isEqual:@"signed_out_trusted"]) return OR6L(@"Signed out · trusted device");
    if ([d[@"kind"] isEqual:@"unavailable"]) return OR6L(@"Details unavailable");
    return nil;
}
