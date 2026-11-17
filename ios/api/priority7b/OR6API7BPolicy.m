#import "OR6API7BPolicy.h"
#import <CommonCrypto/CommonDigest.h>

static id Fail(NSError **error,NSString *code) { if (error) *error=OR6APIError(code,@"none"); return nil; }
static BOOL Bool(id v) { return OR6APISchemaCheck(v,@{@"type":@"boolean"},@{}); }
static BOOL String(id v,NSUInteger maximum) { return [v isKindOfClass:NSString.class] && [v length]<=maximum; }
static BOOL Key(id v) {
    return String(v,64) && [v length] && [v rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"] invertedSet]].location==NSNotFound;
}
static NSString *Canonical(id v) {
    if ([v isKindOfClass:NSDictionary.class]) {
        NSMutableArray *rows=[NSMutableArray array];
        for (NSString *k in [[v allKeys] sortedArrayUsingSelector:@selector(compare:)]) [rows addObject:[NSString stringWithFormat:@"%@:%@",Canonical(k),Canonical(v[k])]];
        return [NSString stringWithFormat:@"{%@}",[rows componentsJoinedByString:@","]];
    }
    if ([v isKindOfClass:NSArray.class]) { NSMutableArray *a=[NSMutableArray array]; for (id item in v) [a addObject:Canonical(item)]; return [NSString stringWithFormat:@"[%@]",[a componentsJoinedByString:@","]]; }
    NSData *d=[NSJSONSerialization dataWithJSONObject:@[v] options:0 error:NULL]; NSString *s=[[[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] autorelease];
    return s.length>=2?[s substringWithRange:NSMakeRange(1,s.length-2)]:nil;
}
NSString *OR6API7BDigest(id value) {
    if (!OR6APIJSONSnapshot(value,1024*1024)) return nil;
    NSData *data=[Canonical(value) dataUsingEncoding:NSUTF8StringEncoding]; if (!data) return nil;
    unsigned char bytes[CC_SHA256_DIGEST_LENGTH]; CC_SHA256(data.bytes,(CC_LONG)data.length,bytes); NSMutableString *s=[NSMutableString string];
    for (NSUInteger i=0;i<sizeof(bytes);i++) [s appendFormat:@"%02x",bytes[i]]; return s;
}
BOOL OR6API7BMutation(NSString *op) { return [@[@"instructions.update",@"profile.update",@"personality.update",@"traits.update",@"memory.setEnabled",@"memory.setHistory"] containsObject:op]; }
BOOL OR6API7BCommand(NSString *op) { return OR6API7BMutation(op) || [@[@"personalization.get",@"personalities.list",@"traits.list",@"memory.get",@"settings.reconcile"] containsObject:op]; }
NSDictionary *OR6API7BRegistry(NSDictionary *base,NSDictionary *ext,NSError **error) {
    if (![base[@"schemaVersion"] isEqual:@1] || ![ext[@"schemaVersion"] isEqual:@1] || ![base[@"types"] isKindOfClass:NSDictionary.class] || ![ext[@"types"] isKindOfClass:NSDictionary.class] || ![base[@"operations"] isKindOfClass:NSArray.class] || ![ext[@"operations"] isKindOfClass:NSArray.class] || ![base[@"featureMap"] isKindOfClass:NSArray.class] || ![ext[@"featureMap"] isKindOfClass:NSArray.class]) return Fail(error,@"invalid_request");
    NSMutableDictionary *r=[[base mutableCopy] autorelease],*types=[[base[@"types"] mutableCopy] autorelease]; NSMutableArray *ops=[[base[@"operations"] mutableCopy] autorelease],*features=[[base[@"featureMap"] mutableCopy] autorelease]; NSMutableSet *ids=[NSMutableSet set];
    for (NSDictionary *op in ops) [ids addObject:op[@"id"]];
    for (NSString *k in ext[@"types"]) { if (types[k]) return Fail(error,@"conflict"); types[k]=ext[@"types"][k]; }
    for (NSDictionary *op in ext[@"operations"]) { if (!OR6API7BCommand(op[@"id"]) || [ids containsObject:op[@"id"]]) return Fail(error,@"conflict"); [ids addObject:op[@"id"]]; [ops addObject:op]; }
    [features addObjectsFromArray:ext[@"featureMap"]]; r[@"operations"]=ops;r[@"types"]=types;r[@"featureMap"]=features; return OR6APIJSONSnapshot(r,4*1024*1024);
}
static NSDictionary *WithRevision(NSMutableDictionary *v) { NSString *hash=OR6API7BDigest(v); if (!hash) return nil; v[@"revision"]=hash; return v; }
NSDictionary *OR6API7BPersonalization(id raw,NSError **error) {
    if (![raw isKindOfClass:NSDictionary.class]) return Fail(error,@"unknown_wire_shape");
    BOOL recognized=NO;for(NSString*k in @[@"enabled",@"traits_model_message",@"name_user_message",@"role_user_message",@"other_user_message",@"personality_type_selection",@"personality_traits"])if(raw[k])recognized=YES;
    if(!recognized)return Fail(error,@"unknown_wire_shape");
    NSDictionary *names=@{@"instructions":@"traits_model_message",@"nickname":@"name_user_message",@"occupation":@"role_user_message",@"about":@"other_user_message",@"personality":@"personality_type_selection"};
    NSMutableDictionary *out=[NSMutableDictionary dictionary];
    id enabled=raw[@"enabled"]?:NSNull.null; if (enabled!=NSNull.null && !Bool(enabled)) return Fail(error,@"unknown_wire_shape"); out[@"enabled"]=enabled;
    // The service returns an empty selection when no personality was chosen.
    // Keep that known empty state distinct from an absent/null observation;
    // writing a personality still requires a nonempty fresh catalogue key.
    for (NSString *k in names) { id v=raw[names[k]]?:NSNull.null; if (v!=NSNull.null && (!String(v,[k isEqual:@"personality"]?64:1500) || ([k isEqual:@"personality"] && [v length] && !Key(v)))) return Fail(error,@"unknown_wire_shape"); out[k]=v; }
    id traits=raw[@"personality_traits"]; out[@"traits"]=NSNull.null;
    if (traits && traits!=NSNull.null) {
        if (![traits isKindOfClass:NSDictionary.class] || [traits count]>32) return Fail(error,@"unknown_wire_shape"); NSMutableArray *items=[NSMutableArray array];
        for (NSString *k in [[traits allKeys] sortedArrayUsingSelector:@selector(compare:)]) { if (!Key(k) || ![@[@"less",@"default",@"more"] containsObject:traits[k]]) return Fail(error,@"unknown_wire_shape"); [items addObject:@{@"key":k,@"level":traits[k]}]; } out[@"traits"]=items;
    }
    return WithRevision(out);
}
NSDictionary *OR6API7BMemory(id raw,NSError **error) {
    if (![raw isKindOfClass:NSDictionary.class] || ![raw[@"settings"] isKindOfClass:NSDictionary.class]) return Fail(error,@"unknown_wire_shape"); NSDictionary *s=raw[@"settings"];
    for (NSString *k in @[@"m3m",@"sunshine",@"moonshine",@"memory_in_search"]) if (s[k] && s[k]!=NSNull.null && !Bool(s[k])) return Fail(error,@"unknown_wire_shape");
    id locks=s[@"amphora_locks"]; if (locks && ![locks isKindOfClass:NSDictionary.class]) return Fail(error,@"unknown_wire_shape");
    for (NSString *k in @[@"m3m",@"sunshine",@"moonshine",@"memory_in_search"]) if (locks[k] && !Bool(locks[k])) return Fail(error,@"unknown_wire_shape");
    BOOL unified=Bool(s[@"m3m"]),legacy=!unified && Bool(s[@"sunshine"]); NSString *main=unified?@"m3m":@"sunshine";
    NSMutableDictionary *out=[NSMutableDictionary dictionaryWithDictionary:@{@"mode":unified?@"unified":legacy?@"legacy":@"unavailable",@"enabled":unified||legacy?s[main]:(id)NSNull.null,@"history":legacy?(s[@"moonshine"]?:(id)NSNull.null):(id)NSNull.null,@"search":s[@"memory_in_search"]?:(id)NSNull.null,@"enabledLocked":@([locks[main] isEqual:@YES]),@"historyLocked":@([locks[@"moonshine"] isEqual:@YES]),@"searchLocked":@([locks[@"memory_in_search"] isEqual:@YES])}];
    return WithRevision(out);
}
NSDictionary *OR6API7BCatalog(id raw,BOOL traits,NSError **error) {
    id rows=traits && [raw isKindOfClass:NSDictionary.class]?raw[@"trait_types"]:raw;
    if (![rows isKindOfClass:NSArray.class] || [rows count]>(traits?32:64)) return Fail(error,@"unknown_wire_shape"); NSMutableArray *out=[NSMutableArray array]; NSMutableSet *seen=[NSMutableSet set];
    for (id row in rows) {
        if (![row isKindOfClass:NSDictionary.class] || !Key(row[@"key"]) || [seen containsObject:row[@"key"]] || (row[@"deprecated"] && !Bool(row[@"deprecated"]))) return Fail(error,@"unknown_wire_shape"); [seen addObject:row[@"key"]];
        if ([row[@"deprecated"] isEqual:@YES]) continue;
        if (!String(row[@"label"],256) || ![row[@"label"] length] || (row[@"description"] && !String(row[@"description"],2000))) return Fail(error,@"unknown_wire_shape");
        NSMutableDictionary *item=[NSMutableDictionary dictionaryWithDictionary:@{@"key":row[@"key"],@"label":row[@"label"]}];
        if (!traits) item[@"description"]=row[@"description"]?:@"";
        else {
            id levels=row[@"levels"]; if (![levels isKindOfClass:NSArray.class] || ![levels count] || [levels count]>3) return Fail(error,@"unknown_wire_shape"); NSMutableArray *ls=[NSMutableArray array]; NSMutableSet *keys=[NSMutableSet set];
            for (id level in levels) {
                if (![level isKindOfClass:NSDictionary.class] || ![@[@"less",@"default",@"more"] containsObject:level[@"key"]] || [keys containsObject:level[@"key"]] || !String(level[@"option_label"],256) || ![level[@"option_label"] length] || (level[@"description"] && !String(level[@"description"],2000))) return Fail(error,@"unknown_wire_shape");
                [keys addObject:level[@"key"]]; [ls addObject:@{@"key":level[@"key"],@"label":level[@"option_label"],@"description":level[@"description"]?:@""}];
            } item[@"levels"]=ls;
        } [out addObject:item];
    } return @{@"items":out};
}
NSURLRequest *OR6API7BRead(NSString *op) {
    NSString *path=@{@"personalization.get":@"user_system_messages",@"personalities.list":@"personality_types",@"traits.list":@"personality_trait_types",@"memory.get":@"settings/user"}[op];
    return path?[NSURLRequest requestWithURL:[NSURL URLWithString:[@"https://chatgpt.com/backend-api/" stringByAppendingString:path]]]:nil;
}
static BOOL WirePatch(id body) {
    if (![body isKindOfClass:NSDictionary.class] || ![body count] || [body count]>7) return NO;
    for (NSString *k in body) {
        id v=body[k];
        if ([k isEqual:@"enabled"]) { if (!Bool(v)) return NO; }
        else if ([@[@"traits_model_message",@"name_user_message",@"role_user_message",@"other_user_message"] containsObject:k]) { if (!String(v,1500)) return NO; }
        else if ([k isEqual:@"personality_type_selection"]) { if (!Key(v)) return NO; }
        else if ([k isEqual:@"personality_traits"]) { if (![v isKindOfClass:NSDictionary.class] || [v count]>32) return NO; for (NSString *key in v) if (!Key(key) || ![@[@"less",@"default",@"more"] containsObject:v[key]]) return NO; }
        else return NO;
    } return YES;
}
NSURLRequest *OR6API7BWrite(NSString *category,NSDictionary *step) {
    NSString *url=nil; NSData *body=nil;
    if ([category isEqual:@"personalization"] && WirePatch(step)) { url=@"https://chatgpt.com/backend-api/user_system_messages"; body=[NSJSONSerialization dataWithJSONObject:step options:0 error:NULL]; }
    else if ([category isEqual:@"memory"] && step.count==2 && [@[@"sunshine",@"m3m",@"moonshine",@"memory_in_search"] containsObject:step[@"feature"]] && Bool(step[@"value"])) url=[NSString stringWithFormat:@"https://chatgpt.com/backend-api/settings/account_user_setting?feature=%@&value=%@",step[@"feature"],[step[@"value"] boolValue]?@"true":@"false"];
    if (!url) return nil; NSMutableURLRequest *r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]]; r.HTTPMethod=@"PATCH";
    if (body) { r.HTTPBody=body; [r setValue:@"application/json" forHTTPHeaderField:@"Content-Type"]; } return r;
}
BOOL OR6API7BAllowedRequest(NSURLRequest *r) {
    NSURL *u=r.URL;
    if (![u.scheme isEqual:@"https"] || ![u.host isEqual:@"chatgpt.com"] || u.user || u.password || u.port || u.fragment || r.HTTPBodyStream || r.HTTPBody.length>32768) return NO;
    for (NSString *k in r.allHTTPHeaderFields) if (![k.lowercaseString isEqual:@"content-type"] || ![[r valueForHTTPHeaderField:k] isEqual:@"application/json"]) return NO;
    if ([r.HTTPMethod isEqual:@"GET"]) { if (u.query || r.HTTPBody.length) return NO; for (NSString *op in @[@"personalization.get",@"personalities.list",@"traits.list",@"memory.get"]) if ([u.absoluteString isEqual:OR6API7BRead(op).URL.absoluteString]) return YES; return NO; }
    if (![r.HTTPMethod isEqual:@"PATCH"]) return NO;
    if ([u.path isEqual:@"/backend-api/user_system_messages"] && !u.query) return r.HTTPBody.length && WirePatch([NSJSONSerialization JSONObjectWithData:r.HTTPBody options:0 error:NULL]);
    if (![u.path isEqual:@"/backend-api/settings/account_user_setting"] || r.HTTPBody.length) return NO;
    for (NSString *feature in @[@"sunshine",@"m3m",@"moonshine",@"memory_in_search"]) for (NSString *value in @[@"true",@"false"]) if ([u.query isEqual:[NSString stringWithFormat:@"feature=%@&value=%@",feature,value]]) return YES;
    return NO;
}
static NSDictionary *CatalogItem(NSDictionary *catalog,NSString *key) { for (NSDictionary *item in catalog[@"items"]) if ([item[@"key"] isEqual:key]) return item; return nil; }
NSDictionary *OR6API7BPlan(NSString *op,NSDictionary *p,NSDictionary *snapshot,NSDictionary *catalog,NSDictionary *policy,NSError **error) {
    if (!OR6API7BMutation(op) || ![p[@"expectedRevision"] isEqual:snapshot[@"revision"]]) return Fail(error,@"conflict");
    BOOL memory=[op hasPrefix:@"memory."]; NSMutableDictionary *desired=[NSMutableDictionary dictionary],*patch=[NSMutableDictionary dictionary]; NSMutableArray *steps=[NSMutableArray array];
    if (!memory) {
        if ([op isEqual:@"instructions.update"] || [op isEqual:@"profile.update"]) {
            NSDictionary *map=[op isEqual:@"instructions.update"]?@{@"text":@"traits_model_message",@"enabled":@"enabled"}:@{@"nickname":@"name_user_message",@"occupation":@"role_user_message",@"about":@"other_user_message"};
            id changes=p[@"changes"]; if (![changes isKindOfClass:NSDictionary.class] || ![changes count]) return Fail(error,@"invalid_request");
            for (NSString *k in changes) { if (!map[k] || ([k isEqual:@"enabled"]?!Bool(changes[k]):!String(changes[k],1500))) return Fail(error,@"invalid_request"); patch[map[k]]=changes[k]; desired[[k isEqual:@"text"]?@"instructions":k]=changes[k]; }
        } else if ([op isEqual:@"personality.update"]) {
            if (!CatalogItem(catalog,p[@"key"])) return Fail(error,@"invalid_request"); patch[@"personality_type_selection"]=p[@"key"]; patch[@"enabled"]=@YES; desired[@"personality"]=p[@"key"]; desired[@"enabled"]=@YES;
        } else {
            if (snapshot[@"traits"]==NSNull.null) return Fail(error,@"capability_unavailable"); NSMutableDictionary *traits=[NSMutableDictionary dictionary];
            for (NSDictionary *t in snapshot[@"traits"]) traits[t[@"key"]]=t[@"level"];
            NSMutableSet *seen=[NSMutableSet set]; if (![p[@"changes"] count] || [p[@"changes"] count]>32) return Fail(error,@"invalid_request");
            for (NSDictionary *t in p[@"changes"]) {
                NSDictionary *item=CatalogItem(catalog,t[@"key"]); BOOL level=NO; for (NSDictionary *l in item[@"levels"]) if ([l[@"key"] isEqual:t[@"level"]]) level=YES;
                if (!item || !level || [seen containsObject:t[@"key"]]) return Fail(error,@"invalid_request"); [seen addObject:t[@"key"]]; traits[t[@"key"]]=t[@"level"];
            }
            if (traits.count>32) return Fail(error,@"size_limit"); patch[@"personality_traits"]=traits; patch[@"enabled"]=@YES; NSMutableArray *out=[NSMutableArray array]; for (NSString *k in [[traits allKeys] sortedArrayUsingSelector:@selector(compare:)]) [out addObject:@{@"key":k,@"level":traits[k]}]; desired[@"traits"]=out; desired[@"enabled"]=@YES;
        }
        if (!WirePatch(patch)) return Fail(error,@"invalid_request"); [steps addObject:patch];
    } else {
        if (![policy[@"eligible"] isEqual:@YES] || [snapshot[@"mode"] isEqual:@"unavailable"]) return Fail(error,@"capability_unavailable");
        if (!Bool(p[@"enabled"])) return Fail(error,@"invalid_request"); BOOL enable=[p[@"enabled"] boolValue],legacy=[snapshot[@"mode"] isEqual:@"legacy"];
        if ([op isEqual:@"memory.setHistory"]) {
            if (!legacy || !Bool(snapshot[@"history"]) || ![snapshot[@"enabled"] isEqual:@YES] || ![policy[@"historyEligible"] isEqual:@YES]) return Fail(error,@"capability_unavailable");
            if ([snapshot[@"historyLocked"] isEqual:@YES]) return Fail(error,@"access_denied"); desired[@"history"]=@(enable);
            if (![snapshot[@"history"] isEqual:@(enable)]) [steps addObject:@{@"feature":@"moonshine",@"value":@(enable)}];
        } else {
            if (!Bool(p[@"allowRelatedChanges"])) return Fail(error,@"invalid_request");
            if ([snapshot[@"enabledLocked"] isEqual:@YES]) return Fail(error,@"access_denied"); desired[@"enabled"]=@(enable); desired[@"mode"]=snapshot[@"mode"];
            if (![snapshot[@"enabled"] isEqual:@(enable)]) [steps addObject:@{@"feature":legacy?@"sunshine":@"m3m",@"value":@(enable)}];
            if (legacy && Bool(snapshot[@"history"]) && ![snapshot[@"history"] isEqual:@(enable)]) {
                if (![policy[@"historyEligible"] isEqual:@YES]) return Fail(error,@"capability_unavailable"); if ([snapshot[@"historyLocked"] isEqual:@YES]) return Fail(error,@"access_denied");
                [steps addObject:@{@"feature":@"moonshine",@"value":@(enable)}]; desired[@"history"]=@(enable);
            }
            if (!enable && [snapshot[@"search"] isEqual:@YES]) { if ([snapshot[@"searchLocked"] isEqual:@YES]) return Fail(error,@"access_denied"); [steps addObject:@{@"feature":@"memory_in_search",@"value":@NO}]; desired[@"search"]=@NO; }
            NSUInteger main=(![snapshot[@"enabled"] isEqual:@(enable)])?1:0;
            if (steps.count>main && ![p[@"allowRelatedChanges"] isEqual:@YES]) return Fail(error,@"conflict");
        }
    }
    return @{@"category":memory?@"memory":@"personalization",@"desired":desired,@"steps":steps};
}
BOOL OR6API7BMatches(NSDictionary *plan,NSDictionary *snapshot) { if (![plan[@"desired"] count]) return NO; for (NSString *k in plan[@"desired"]) if (![plan[@"desired"][k] isEqual:snapshot[k]]) return NO; return YES; }
