#import "OR6API7EPolicy.h"
#import "../priority7b/OR6API7BPolicy.h"
static id Fail(NSError **error,NSString *code){if(error)*error=OR6APIError(code,@"none");return nil;}
static BOOL Bool(id v){return OR6APISchemaCheck(v,@{@"type":@"boolean"},@{});}
static BOOL Text(id v,NSUInteger n){return [v isKindOfClass:NSString.class]&&[v length]>0&&[v length]<=n;}
NSDictionary *OR6API7ERegistry(NSDictionary *base,NSDictionary *ext,NSError **error) {
    if (![base[@"schemaVersion"] isEqual:@1] || ![ext[@"schemaVersion"] isEqual:@1] || ![base[@"types"] isKindOfClass:NSDictionary.class] || ![ext[@"types"] isKindOfClass:NSDictionary.class] || ![base[@"operations"] isKindOfClass:NSArray.class] || ![ext[@"operations"] isKindOfClass:NSArray.class] || ![base[@"featureMap"] isKindOfClass:NSArray.class] || ![ext[@"featureMap"] isKindOfClass:NSArray.class]) return Fail(error,@"invalid_request");
    NSMutableDictionary *r=[[base mutableCopy] autorelease],*types=[[base[@"types"] mutableCopy] autorelease]; NSMutableArray *ops=[[base[@"operations"] mutableCopy] autorelease],*features=[[base[@"featureMap"] mutableCopy] autorelease]; NSMutableSet *ids=[NSMutableSet set];
    for (NSDictionary *op in ops) [ids addObject:op[@"id"]];
    for (NSString *k in ext[@"types"]) { if (types[k]) return Fail(error,@"conflict"); types[k]=ext[@"types"][k]; }
    for (NSDictionary *op in ext[@"operations"]) { if (!OR6API7ECommand(op[@"id"]) || [ids containsObject:op[@"id"]]) return Fail(error,@"conflict"); [ids addObject:op[@"id"]]; [ops addObject:op]; }
    [features addObjectsFromArray:ext[@"featureMap"]]; r[@"operations"]=ops;r[@"types"]=types;r[@"featureMap"]=features; return OR6APIJSONSnapshot(r,4*1024*1024);
}

NSDictionary *OR6API7EAge(id raw,NSError **error){
 if(![raw isKindOfClass:NSDictionary.class]||!Text(raw[@"age_status"],128)||!Bool(raw[@"has_verified_age_or_dob"])||(raw[@"show_age_verification_setting"]&&!Bool(raw[@"show_age_verification_setting"])))return Fail(error,@"unknown_wire_shape");
 NSString *status=raw[@"age_status"];BOOL teen=[status isEqual:@"under_18"],adult=[status isEqual:@"over_18"];
 return @{@"ageGroup":teen?@"teen":adult?@"adult":@"unsure",@"hasVerifiedAgeOrDOB":raw[@"has_verified_age_or_dob"],@"canVerifyAge":@((BOOL)(!adult&&(!teen||![raw[@"has_verified_age_or_dob"]boolValue]))),@"showVerificationSetting":raw[@"show_age_verification_setting"]?:NSNull.null};
}
BOOL OR6API7EMutation(NSString *op){return [@[@"privacy.training.setText",@"privacy.training.setMedia",@"safety.sensitiveContent.set"]containsObject:op];}
BOOL OR6API7ECommand(NSString *op){return OR6API7EMutation(op)||[@[@"privacy.get",@"privacy.reconcile",@"safety.ageStatus",@"security.policy",@"security.reauthenticate",@"security.passwordChange",@"security.emailChange",@"security.mfaSetup",@"security.recovery",@"privacy.center",@"privacy.openCenter",@"subscription.openPlans",@"privacy.requestsHelp",@"safety.ageVerify",@"subscription.plans"]containsObject:op];}
static NSDictionary *SettingsMap(void){return @{@"trainingText":@"training_allowed",@"trainingAudio":@"voice_training_allowed",@"trainingVideo":@"video_training_allowed",@"sensitiveContent":@"3VyEPC5dTP_model_instructions_enabled"};}
NSDictionary *OR6API7ESettings(id raw,NSError **error){
 if(![raw isKindOfClass:NSDictionary.class]||![raw[@"settings"]isKindOfClass:NSDictionary.class])return Fail(error,@"unknown_wire_shape");
 NSDictionary*s=raw[@"settings"],*locks=s[@"amphora_locks"];if(locks&&![locks isKindOfClass:NSDictionary.class])return Fail(error,@"unknown_wire_shape");NSMutableDictionary*out=[NSMutableDictionary dictionary];
 for(NSString*k in SettingsMap()){
  NSString*wire=SettingsMap()[k];id v=s[wire],l=locks[wire];if((v&&v!=NSNull.null&&!Bool(v))||(l&&!Bool(l)))return Fail(error,@"unknown_wire_shape");out[k]=v?:NSNull.null;out[[k stringByAppendingString:@"Locked"]]=@([l isEqual:@YES]);
 }
 out[@"revision"]=OR6API7BDigest(out);return out;
}
NSDictionary *OR6API7ESecurity(id raw,NSError **error){
 if(![raw isKindOfClass:NSDictionary.class]||![raw[@"mfa"]isKindOfClass:NSDictionary.class]||![raw[@"protection"]isKindOfClass:NSDictionary.class]||!Bool(raw[@"mfa"][@"mfa_enabled_v2"])||!Bool(raw[@"protection"][@"advanced_protection_mode_enabled"]))return Fail(error,@"unknown_wire_shape");
 return @{@"mfaEnabled":raw[@"mfa"][@"mfa_enabled_v2"],@"advancedSecurity":raw[@"protection"][@"advanced_protection_mode_enabled"],@"mfaManagementAllowed":@((BOOL)![raw[@"protection"][@"advanced_protection_mode_enabled"]boolValue])};
}
NSDictionary *OR6API7EHandoff(NSString *op,NSDictionary *p,NSError **error){
 if(p.count)return Fail(error,@"invalid_request");NSDictionary*map=@{@"security.reauthenticate":@[@"/settings/security",@"reauthentication"],@"security.passwordChange":@[@"/settings/security",@"password_change"],@"security.emailChange":@[@"/settings/account",@"email_change"],@"security.mfaSetup":@[@"/settings/security",@"mfa_setup"],@"security.recovery":@[@"/auth/login",@"mfa_recovery"],@"privacy.openCenter":@[@"/privacy-center",@"privacy_center"],@"privacy.requestsHelp":@[@"https://privacy.openai.com/",@"privacy_request"],@"safety.ageVerify":@[@"/settings/age",@"age_verification"],@"subscription.openPlans":@[@"/plans",@"compare_plans"]};NSArray*v=map[op];if(!v)return Fail(error,@"invalid_request");NSString*url=[v[0]hasPrefix:@"/"]?[@"https://chatgpt.com"stringByAppendingString:v[0]]:v[0];return @{@"action":@"open_browser",@"purpose":v[1],@"url":url,@"completed":@NO,@"requiresExistingAccount":@YES};
}
NSURLRequest *OR6API7ERead(NSString *op){NSString*path=@{@"privacy.get":@"settings/user",@"safety.ageStatus":@"settings/is_adult",@"security.policy":@"accounts/mfa_info",@"security.protection":@"accounts/security_settings/info"}[op];return path?[NSURLRequest requestWithURL:[NSURL URLWithString:[@"https://chatgpt.com/backend-api/"stringByAppendingString:path]]]:nil;}
NSURLRequest *OR6API7EWrite(NSDictionary *step){if(step.count!=2||![[SettingsMap()allValues]containsObject:step[@"feature"]]||!Bool(step[@"value"]))return nil;NSMutableURLRequest*r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://chatgpt.com/backend-api/settings/account_user_setting?feature=%@&value=%@",step[@"feature"],[step[@"value"]boolValue]?@"true":@"false"]]];r.HTTPMethod=@"PATCH";return r;}
BOOL OR6API7EAllowedRequest(NSURLRequest *r){
 NSURL*u=r.URL;if(![u.scheme isEqual:@"https"]||![u.host isEqual:@"chatgpt.com"]||u.user||u.password||u.port||u.fragment||r.HTTPBodyStream||r.HTTPBody.length||r.allHTTPHeaderFields.count)return NO;
 if([r.HTTPMethod isEqual:@"GET"]){if([u.path hasPrefix:@"/backend-api/checkout_pricing_config/configs/"]){NSString*country=[u.path lastPathComponent];return [u.absoluteString isEqual:OR6API7EPlansRequest(country).URL.absoluteString];}for(NSString*op in @[@"privacy.get",@"safety.ageStatus",@"security.policy",@"security.protection"])if([u.absoluteString isEqual:OR6API7ERead(op).URL.absoluteString])return YES;return NO;}
 if(![r.HTTPMethod isEqual:@"PATCH"]||![u.path isEqual:@"/backend-api/settings/account_user_setting"])return NO;
 for(NSString*k in SettingsMap())for(NSNumber*b in @[@YES,@NO])if([u.absoluteString isEqual:OR6API7EWrite(@{@"feature":SettingsMap()[k],@"value":b}).URL.absoluteString])return YES;return NO;
}
NSDictionary *OR6API7EPlan(NSString *op,NSDictionary *p,NSDictionary *snapshot,NSError **error){
 if(!OR6API7EMutation(op)||![p[@"expectedRevision"]isEqual:snapshot[@"revision"]])return Fail(error,@"conflict");NSMutableDictionary*desired=[NSMutableDictionary dictionary];NSMutableArray*steps=[NSMutableArray array];
 if([op isEqual:@"privacy.training.setMedia"]){if(!Bool(p[@"audio"])||!Bool(p[@"video"]))return Fail(error,@"invalid_request");if(([p[@"audio"]boolValue]||[p[@"video"]boolValue])&&![snapshot[@"trainingText"]isEqual:@YES])return Fail(error,@"capability_unavailable");desired[@"trainingAudio"]=p[@"audio"];desired[@"trainingVideo"]=p[@"video"];}
 else{if(!Bool(p[@"enabled"]))return Fail(error,@"invalid_request");desired[[op isEqual:@"privacy.training.setText"]?@"trainingText":@"sensitiveContent"]=p[@"enabled"];}
 for(NSString*k in [[desired allKeys]sortedArrayUsingSelector:@selector(compare:)]){if(!Bool(snapshot[k]))return Fail(error,@"capability_unavailable");if([snapshot[[k stringByAppendingString:@"Locked"]]isEqual:@YES])return Fail(error,@"access_denied");if(![snapshot[k]isEqual:desired[k]])[steps addObject:@{@"feature":SettingsMap()[k],@"value":desired[k]}];}
 return @{@"category":@"privacy",@"desired":desired,@"steps":steps};
}
BOOL OR6API7EMatches(NSDictionary *plan,NSDictionary *snapshot){if(![plan[@"desired"]count])return NO;for(NSString*k in plan[@"desired"])if(![plan[@"desired"][k]isEqual:snapshot[k]])return NO;return YES;}

NSDictionary *OR6API7ECenter(NSDictionary *settings,NSDictionary *age){return @{@"settings":settings,@"age":age,@"resources":@[@{@"kind":@"privacy_request",@"url":@"https://privacy.openai.com/"},@{@"kind":@"privacy_policy",@"url":@"https://openai.com/policies/privacy-policy/"},@{@"kind":@"manage_privacy",@"url":@"https://chatgpt.com/privacy-center"}]};}
static BOOL Code(id v,NSUInteger n){return [v isKindOfClass:NSString.class]&&[v length]==n&&[v rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ"]invertedSet]].location==NSNotFound;}
NSURLRequest *OR6API7EPlansRequest(NSString *country){return Code(country,2)?[NSURLRequest requestWithURL:[NSURL URLWithString:[@"https://chatgpt.com/backend-api/checkout_pricing_config/configs/"stringByAppendingString:country]]]:nil;}
NSDictionary *OR6API7EPlans(id raw,NSString *country,NSError **error){
 if(!Code(country,2)||![raw isKindOfClass:NSDictionary.class]||![raw[@"currency_config"]isKindOfClass:NSDictionary.class])return Fail(error,@"unknown_wire_shape");NSDictionary*config=raw[@"currency_config"];id currency=config[@"symbol_code"],exponent=config[@"minor_unit_exponent"]?:NSNull.null;
 if(!Code(currency,3)||(exponent!=NSNull.null&&!OR6APISchemaCheck(exponent,@{@"type":@"integer",@"minimum":@0,@"maximum":@6},@{})))return Fail(error,@"unknown_wire_shape");NSMutableArray*items=[NSMutableArray array];
 for(NSString*k in @[@"free",@"go",@"plus",@"prolite",@"pro",@"promax",@"business",@"business_prolite"]){id plan=config[k];if(!plan||plan==NSNull.null)continue;if(![plan isKindOfClass:NSDictionary.class])return Fail(error,@"unknown_wire_shape");NSMutableDictionary*item=[NSMutableDictionary dictionaryWithObject:k forKey:@"plan"];
  for(NSString*period in @[@"month",@"year"]){id row=plan[period],amount=NSNull.null;if(row&&row!=NSNull.null){if(![row isKindOfClass:NSDictionary.class])return Fail(error,@"unknown_wire_shape");amount=row[@"amount"]?:NSNull.null;if(amount!=NSNull.null&&!OR6APISchemaCheck(amount,@{@"type":@"number",@"minimum":@0,@"maximum":@1000000000000},@{}))return Fail(error,@"unknown_wire_shape");}item[[period isEqual:@"month"]?@"monthlyAmount":@"yearlyAmount"]=amount;}[items addObject:item];
 }
 return @{@"countryCode":country,@"currencyCode":currency,@"minorUnitExponent":exponent,@"items":items,@"eligibilityVerified":@NO,@"browserURL":@"https://chatgpt.com/plans"};
}
