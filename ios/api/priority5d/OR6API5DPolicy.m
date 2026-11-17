#import "OR6API5DPolicy.h"
#import "../priority7/OR6API7Policy.h"
static id Fail(NSError**e,NSString*c){if(e)*e=OR6APIError(c,@"none");return nil;}
static NSDictionary*D(id v){return[v isKindOfClass:NSDictionary.class]?v:nil;}
BOOL OR6API5DText(id v,NSUInteger n){return[v isKindOfClass:NSString.class]&&[v length]&&[v length]<=n&&[v rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location==NSNotFound;}
static BOOL B(id v){return OR6APISchemaCheck(v,@{@"type":@"boolean"},@{});}
NSDictionary *OR6API5DRegistry(NSDictionary *base,NSDictionary *ext,NSError **error) {
    if (![base[@"schemaVersion"] isEqual:@1] || ![ext[@"schemaVersion"] isEqual:@1] || ![base[@"types"] isKindOfClass:NSDictionary.class] || ![ext[@"types"] isKindOfClass:NSDictionary.class] || ![base[@"operations"] isKindOfClass:NSArray.class] || ![ext[@"operations"] isKindOfClass:NSArray.class] || ![base[@"featureMap"] isKindOfClass:NSArray.class] || ![ext[@"featureMap"] isKindOfClass:NSArray.class]) return Fail(error,@"invalid_request");
    NSMutableDictionary *r=[[base mutableCopy] autorelease],*types=[[base[@"types"] mutableCopy] autorelease]; NSMutableArray *ops=[[base[@"operations"] mutableCopy] autorelease],*features=[[base[@"featureMap"] mutableCopy] autorelease]; NSMutableSet *ids=[NSMutableSet set];
    for (NSDictionary *op in ops) [ids addObject:op[@"id"]];
    for (NSString *k in ext[@"types"]) { if (types[k]) return Fail(error,@"conflict"); types[k]=ext[@"types"][k]; }
    for (NSDictionary *op in ext[@"operations"]) { if (!OR6API5DCommand(op[@"id"]) || [ids containsObject:op[@"id"]]) return Fail(error,@"conflict"); [ids addObject:op[@"id"]]; [ops addObject:op]; }
    [features addObjectsFromArray:ext[@"featureMap"]]; r[@"operations"]=ops;r[@"types"]=types;r[@"featureMap"]=features; return OR6APIJSONSnapshot(r,4*1024*1024);
}
BOOL OR6API5DMutation(NSString*o){return[@[@"workspaces.select",@"workspaces.createPersonal",@"ads.personalization.set",@"ads.data.delete"]containsObject:o];}
BOOL OR6API5DCommand(NSString*o){return OR6API5DMutation(o)||[@[@"security.sms.get",@"security.sms.open",@"security.advanced.get",@"security.advanced.open",@"security.history.list",@"security.recommendations.get",@"workspaces.list",@"workspaces.reconcile",@"ads.settings.get",@"ads.history.list",@"ads.topics.list",@"account5.operationStatus",@"ads.reconcile"]containsObject:o];}
NSDictionary *OR6API5DHandoff(NSString*o){NSString*p=[o isEqual:@"security.sms.open"]?@"sms_mfa":[o isEqual:@"security.advanced.open"]?@"advanced_security":nil;return p?@{@"action":@"open_browser",@"purpose":p,@"url":@"https://chatgpt.com/settings/security",@"requiresUserSelection":@YES,@"completed":@NO,@"flowStarted":@NO,@"sensitiveInputInBrowser":@YES}:nil;}
static NSString*Q(id v){if(!OR6API5DText(v,2048))return nil;NSData*d=[v dataUsingEncoding:NSUTF8StringEncoding];NSMutableString*s=[NSMutableString string];const unsigned char*b=d.bytes;for(NSUInteger i=0;i<d.length;i++){unsigned char c=b[i];if((c>='a'&&c<='z')||(c>='A'&&c<='Z')||(c>='0'&&c<='9')||c=='-'||c=='_'||c=='.'||c=='~')[s appendFormat:@"%c",c];else[s appendFormat:@"%%%02X",c];}return s;}
NSURLRequest *OR6API5DRequest(NSString*o,NSDictionary*p,NSString*account){
 if(!D(p)||!OR6API5DText(account,128))return nil;NSString*path=nil,*method=@"GET";
 if([o isEqual:@"security.sms.get"])path=@"/accounts/mfa_info";
 else if([o isEqual:@"security.advanced.get"])path=@"/accounts/security_settings/info";
 else if([o isEqual:@"security.recommendations.get"])path=@"/accounts/security/recommendations";
 else if([o isEqual:@"security.history.list"]){path=@"/accounts/user_events?limit=20";if(p[@"serverCursor"]){if(!Q(p[@"serverCursor"]))return nil;path=[path stringByAppendingFormat:@"&cursor=%@",Q(p[@"serverCursor"])];}}
 else if([o isEqual:@"workspaces.list"])path=@"/accounts/check/v4-2023-04-27";
 else if([o isEqual:@"workspaces.createPersonal"]){path=@"/accounts/personal";method=@"POST";}
 else if([o isEqual:@"ads.settings.get"])path=@"/settings/user";
 else if([o isEqual:@"ads.personalization.set"]){if(!B(p[@"enabled"]))return nil;method=@"PATCH";path=[@"/settings/account_user_setting?feature=bazaar_personalization_enabled&value="stringByAppendingString:[p[@"enabled"]boolValue]?@"true":@"false"];}
 else if([o isEqual:@"ads.history.list"]||[o isEqual:@"ads.topics.list"]){path=[o isEqual:@"ads.history.list"]?@"/bazaar/history":@"/bazaar/preferences";if(p[@"serverCursor"]){if(!Q(p[@"serverCursor"]))return nil;path=[path stringByAppendingFormat:@"?cursor=%@",Q(p[@"serverCursor"])];}}
 else if([o isEqual:@"ads.data.delete"]){path=@"/bazaar/profile";method=@"DELETE";}
 if(!path)return nil;NSMutableURLRequest*r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:[@"https://chatgpt.com/backend-api"stringByAppendingString:path]]];r.HTTPMethod=method;[r setValue:account forHTTPHeaderField:@"ChatGPT-Account-ID"];return r;
}
BOOL OR6API5DAllowedRequest(NSURLRequest*r){
 if(![r isKindOfClass:NSURLRequest.class]||![r.URL.scheme isEqual:@"https"]||![r.URL.host isEqual:@"chatgpt.com"]||r.URL.user||r.URL.password||r.URL.fragment||r.URL.port||r.HTTPBody||r.HTTPBodyStream||[r valueForHTTPHeaderField:@"Authorization"]||[r valueForHTTPHeaderField:@"Cookie"])return NO;
 NSString*a=[r valueForHTTPHeaderField:@"ChatGPT-Account-ID"];if(!OR6API5DText(a,128))return NO;
 for(NSString*k in r.allHTTPHeaderFields)if(![k.lowercaseString isEqual:@"chatgpt-account-id"])return NO;
 NSArray*reads=@[@"/backend-api/accounts/mfa_info",@"/backend-api/accounts/security_settings/info",@"/backend-api/accounts/security/recommendations",@"/backend-api/accounts/check/v4-2023-04-27",@"/backend-api/settings/user"];
 if([r.HTTPMethod isEqual:@"GET"]&&[reads containsObject:r.URL.path])return!r.URL.query;
 if([r.HTTPMethod isEqual:@"DELETE"]&&[r.URL.path isEqual:@"/backend-api/bazaar/profile"])return!r.URL.query;
 if([r.HTTPMethod isEqual:@"POST"]&&[r.URL.path isEqual:@"/backend-api/accounts/personal"])return!r.URL.query;
 if([r.HTTPMethod isEqual:@"PATCH"]&&[r.URL.path isEqual:@"/backend-api/settings/account_user_setting"])return[@[@"feature=bazaar_personalization_enabled&value=true",@"feature=bazaar_personalization_enabled&value=false"]containsObject:r.URL.query];
 NSString*q=r.URL.query;
 if(![r.HTTPMethod isEqual:@"GET"])return NO;
 if([r.URL.path isEqual:@"/backend-api/accounts/user_events"]){if([q isEqual:@"limit=20"])return YES;if(![q hasPrefix:@"limit=20&cursor="])return NO;q=[q substringFromIndex:16];}
 else if([@[@"/backend-api/bazaar/history",@"/backend-api/bazaar/preferences"]containsObject:r.URL.path]){if(!q)return YES;if(![q hasPrefix:@"cursor="])return NO;q=[q substringFromIndex:7];}
 else return NO;
 NSString*v=[q stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];return Q(v)&&[Q(v)isEqual:q];
}
NSDictionary *OR6API5DDecode(NSString*o,id raw,NSError**error){
 NSDictionary*d=D(raw);if(!d)return Fail(error,@"unknown_wire_shape");
 if([o isEqual:@"ads.settings.get"]){NSDictionary*s=D(d[@"settings"]),*f=D(d[@"flags"]);if(!s||!f||(s[@"bazaar_personalization_enabled"]&&!B(s[@"bazaar_personalization_enabled"]))||(f[@"bazaar_personalization_unavailable"]&&!B(f[@"bazaar_personalization_unavailable"])))return Fail(error,@"unknown_wire_shape");return@{@"personalizationEnabled":@((BOOL)![s[@"bazaar_personalization_enabled"]isEqual:@NO]),@"personalizationUnavailable":@([f[@"bazaar_personalization_unavailable"]isEqual:@YES])};}
 if([o isEqual:@"security.advanced.get"]){if(!B(d[@"advanced_protection_mode_enabled"])||!B(d[@"aas_eligible"]))return Fail(error,@"unknown_wire_shape");return@{@"advancedProtectionEnabled":d[@"advanced_protection_mode_enabled"],@"eligible":d[@"aas_eligible"]};}
 if([o isEqual:@"security.sms.get"]){id a=D(d[@"factors"])[@"sms"];if(!B(d[@"mfa_enabled_v2"])||!B(d[@"show_sms"])||![a isKindOfClass:NSArray.class]||[a count]>32)return Fail(error,@"unknown_wire_shape");return@{@"enabled":d[@"mfa_enabled_v2"],@"available":d[@"show_sms"],@"enrolledCount":@([a count])};}
 NSMutableArray*out=[NSMutableArray array];id rows=nil,next=nil;
 if([o isEqual:@"security.recommendations.get"]){rows=d[@"recommendations"];if(![rows isKindOfClass:NSArray.class]||[rows count]>3)return Fail(error,@"unknown_wire_shape");for(id r in rows){if(!OR6API5DText(D(r)[@"id"],128))return Fail(error,@"unknown_wire_shape");[out addObject:@{@"id":r[@"id"]}];}return@{@"items":out};}
 if([o isEqual:@"workspaces.list"]){NSDictionary*accounts=D(d[@"accounts"]);if(!accounts||accounts.count>100)return Fail(error,@"unknown_wire_shape");for(NSString*k in [[accounts allKeys]sortedArrayUsingSelector:@selector(compare:)]){NSDictionary*entry=D(accounts[k]),*a=D(entry[@"account"]);if(!a||(a[@"account_residency_region"]&&!OR6API5DText(a[@"account_residency_region"],128))||(a[@"is_fedramp_compliant_workspace"]&&!B(a[@"is_fedramp_compliant_workspace"]))||!OR6API5DText(a[@"account_id"],128)||![a[@"account_id"]isEqual:k]||!OR6API5DText(a[@"structure"],64)||(a[@"name"]&&a[@"name"]!=NSNull.null&&!OR6API5DText(a[@"name"],256))||(entry[@"can_access_with_session"]&&!B(entry[@"can_access_with_session"]))||(a[@"is_deactivated"]&&!B(a[@"is_deactivated"])))return Fail(error,@"unknown_wire_shape");[out addObject:@{@"id":k,@"name":a[@"name"]?:NSNull.null,@"structure":a[@"structure"],@"accessible":@((BOOL)![entry[@"can_access_with_session"]isEqual:@NO]),@"deactivated":@([a[@"is_deactivated"]isEqual:@YES]),@"residencyRegion":a[@"account_residency_region"]?:@"no_constraint",@"isFedramp":@([a[@"is_fedramp_compliant_workspace"]isEqual:@YES])}];}return@{@"items":out};}
 BOOL security=[o isEqual:@"security.history.list"],history=[o isEqual:@"ads.history.list"],topics=[o isEqual:@"ads.topics.list"];
 if(!security&&!history&&!topics)return Fail(error,@"invalid_request");rows=d[security?@"events":history?@"history":@"preferences"];next=d[security?@"next_cursor":@"cursor"]?:NSNull.null;
 if(![rows isKindOfClass:NSArray.class]||[rows count]>(security?20:100)||(next!=NSNull.null&&!OR6API5DText(next,2048)))return Fail(error,@"unknown_wire_shape");NSMutableSet*seen=[NSMutableSet set];
 for(id row in rows){NSDictionary*r=D(row);if(!r)return Fail(error,@"unknown_wire_shape");if(security){if(!OR6API5DText(r[@"id"],256)||[seen containsObject:r[@"id"]]||!OR6API5DText(r[@"event_type"],128)||!OR6APISchemaCheck(r[@"timestamp_second"],@{@"type":@"integer",@"minimum":@0,@"maximum":@253402300799},@{})||!OR6API5DText(r[@"device_description"],512)||(r[@"location_description"]&&r[@"location_description"]!=NSNull.null&&!OR6API5DText(r[@"location_description"],512)))return Fail(error,@"unknown_wire_shape");[seen addObject:r[@"id"]];[out addObject:@{@"id":r[@"id"],@"type":r[@"event_type"],@"timestampSeconds":r[@"timestamp_second"],@"device":r[@"device_description"],@"location":r[@"location_description"]?:NSNull.null}];}
 else if(topics){if(!OR6API5DText(r[@"content"],2048))return Fail(error,@"unknown_wire_shape");[out addObject:@{@"content":r[@"content"]}];}
 else{NSDictionary*a=D(r[@"ad_data"]),*b=D(a[@"advertiser_brand"]);if(!OR6API5DText(b[@"name"],512)||!OR6API5DText(a[@"title"],2048)||!OR6API5DText(r[@"occurred_at"],128)||!OR6API5DText(r[@"action"],128))return Fail(error,@"unknown_wire_shape");[out addObject:@{@"brand":b[@"name"],@"title":a[@"title"],@"occurredAt":r[@"occurred_at"],@"action":r[@"action"]}];}}
 return@{@"items":out,@"serverCursor":next};
}
