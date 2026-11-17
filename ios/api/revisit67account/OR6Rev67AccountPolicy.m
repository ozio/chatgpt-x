#import "OR6Rev67Account.h"
#import <CoreFoundation/CoreFoundation.h>
static id Fail(NSError **e,NSString *code){if(e)*e=OR6APIError(code,@"none");return nil;}
static BOOL Text(id v,NSUInteger n){return[v isKindOfClass:NSString.class]&&[v length]&&[v length]<=n&&[v rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location==NSNotFound;}
static BOOL Bool(id v){return OR6APISchemaCheck(v,@{@"type":@"boolean"},@{});}
static NSDictionary *D(id v){return[v isKindOfClass:NSDictionary.class]?v:nil;}
static NSString *Escape(NSString *v){return[(NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,(CFStringRef)v,NULL,CFSTR("!*'();:@&=+$,/?%#[]"),kCFStringEncodingUTF8)autorelease];}
NSDictionary *OR6Rev67AccountTiers(void){return @{@"subscription6.status":@"candidate_read",@"subscription6.manage":@"handoff",@"subscription6.billingRecovery":@"handoff",@"subscription6.purchase":@"handoff"};}
NSURLRequest *OR6Rev67AccountRequest(NSString *route,NSDictionary *identity){
 if(!Text(identity[@"accountId"],128)||!Text(identity[@"userId"],256))return nil;
 NSString *path=[route isEqual:@"account"]?@"/accounts/check/v4-2023-04-27":[route isEqual:@"subscription"]?[@"/subscriptions?account_id="stringByAppendingString:Escape(identity[@"accountId"])]:nil;
 if(!path)return nil;NSMutableURLRequest *r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:[@"https://chatgpt.com/backend-api"stringByAppendingString:path]]];[r setValue:identity[@"accountId"]forHTTPHeaderField:@"ChatGPT-Account-ID"];return[[r copy]autorelease];
}
BOOL OR6Rev67AccountAllowedRequest(NSURLRequest *r){
 if(![r isKindOfClass:NSURLRequest.class]||![r.HTTPMethod isEqual:@"GET"]||r.HTTPBodyStream||r.HTTPBody.length||r.allHTTPHeaderFields.count!=1)return NO;
 NSString *account=[r valueForHTTPHeaderField:@"ChatGPT-Account-ID"];if(!Text(account,128))return NO;
 NSDictionary *identity=@{@"accountId":account,@"userId":@"guard"};
 for(NSString *route in @[@"account",@"subscription"])if([r.URL.absoluteString isEqual:OR6Rev67AccountRequest(route,identity).URL.absoluteString])return YES;return NO;
}
NSDictionary *OR6Rev67AccountDecodeAccount(id raw,NSString *accountId,NSError **error){
 if(!Text(accountId,128))return Fail(error,@"invalid_request");
 NSDictionary *root=D(raw),*accounts=D(root[@"accounts"]),*entry=D(accounts[accountId]),*account=D(entry[@"account"]),*ent=D(entry[@"entitlement"]),*last=D(entry[@"last_active_subscription"]);
 if(!accounts||accounts.count>100||!entry||!account||!ent||![account[@"account_id"]isEqual:accountId]||![@[@"personal",@"workspace"]containsObject:account[@"structure"]]||!Text(account[@"plan_type"],128)||!Bool(ent[@"has_active_subscription"])||(ent[@"is_active_subscription_gratis"]&&!Bool(ent[@"is_active_subscription_gratis"]))||(entry[@"can_access_with_session"]&&!Bool(entry[@"can_access_with_session"]))||[entry[@"can_access_with_session"]isEqual:@NO]||(account[@"is_deactivated"]&&!Bool(account[@"is_deactivated"]))||[account[@"is_deactivated"]isEqual:@YES])return Fail(error,@"unknown_wire_shape");
 if(!last&&([ent[@"has_active_subscription"]isEqual:@YES]||(entry[@"last_active_subscription"]&&entry[@"last_active_subscription"]!=NSNull.null)))return Fail(error,@"unknown_wire_shape");
 id origin=last[@"purchase_origin_platform"]?:NSNull.null;if(origin!=NSNull.null&&!Text(origin,128))return Fail(error,@"unknown_wire_shape");id role=account[@"account_user_role"]?:NSNull.null;if(role!=NSNull.null&&!Text(role,128))return Fail(error,@"unknown_wire_shape");
 return @{@"accountId":accountId,@"structure":account[@"structure"],@"plan":account[@"plan_type"],@"origin":origin,@"role":role,@"active":ent[@"has_active_subscription"],@"gratis":ent[@"is_active_subscription_gratis"]?:@NO};
}
NSDictionary *OR6Rev67AccountDecodeSubscription(id raw,NSError **error){
 NSDictionary *d=D(raw);if(!d||!Text(d[@"plan_type"],128)||!Bool(d[@"is_processor_stripe"])||!Bool(d[@"is_delinquent"]))return Fail(error,@"unknown_wire_shape");
 id grace=d[@"grace_period_end_timestamp"]?:NSNull.null;if(grace!=NSNull.null){if(!Text(grace,64))return Fail(error,@"unknown_wire_shape");NSDateFormatter *f=[[[NSDateFormatter alloc]init]autorelease];f.locale=[[[NSLocale alloc]initWithLocaleIdentifier:@"en_US_POSIX"]autorelease];f.dateFormat=@"yyyy-MM-dd'T'HH:mm:ssZZZZZ";NSDate *date=[f dateFromString:grace];if(!date){f.dateFormat=@"yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ";date=[f dateFromString:grace];}if(!date)return Fail(error,@"unknown_wire_shape");}
 return @{@"plan":d[@"plan_type"],@"stripe":d[@"is_processor_stripe"],@"delinquent":d[@"is_delinquent"],@"gracePeriodEnd":grace};
}
NSDictionary *OR6Rev67AccountHandoff(NSString *operation,NSDictionary *a,NSDictionary *subscription,NSError **error){
 if(!OR6Rev67AccountTiers()[operation]||!D(a)||!Text(a[@"accountId"],128)||![a[@"structure"]isEqual:@"personal"]||![@[@"free",@"go",@"plus",@"prolite",@"pro",@"promax"]containsObject:a[@"plan"]]||!Bool(a[@"active"])||!Bool(a[@"gratis"]))return Fail(error,@"capability_unavailable");
 NSString *origin=a[@"origin"],*url=nil,*platform=nil,*purpose=nil;BOOL active=[a[@"active"]isEqual:@YES],gratis=[a[@"gratis"]isEqual:@YES];
 BOOL web=[@[@"chatgpt_web",@"chatgpt_mobile_ios_web_view"]containsObject:origin];
 NSString *management=[@"https://chatgpt.com/account/subscription?account_id="stringByAppendingString:Escape(a[@"accountId"])];
 if([operation isEqual:@"subscription6.purchase"]){
  if(gratis||(active&&!web))return Fail(error,@"capability_unavailable");
  // The existing offer UI owns plan/region/eligibility and the eventual checkout. No SKU is invented.
  if(!active&&(origin==nil||[origin isEqual:NSNull.null]||web||[origin isEqual:@"chatgpt_no_payment_trial"])){url=@"https://chatgpt.com/plans";platform=@"web";purpose=@"review_purchase_offer";}
  else if(active&&web){url=management;platform=@"web";purpose=@"review_plan_change";}
 }else if([operation isEqual:@"subscription6.manage"]){
  if(!active||gratis)return Fail(error,@"capability_unavailable");purpose=@"manage_or_cancel";
  if(web){url=management;platform=@"web";}
  else if([@[@"chatgpt_mobile_ios",@"sora_mobile_ios"]containsObject:origin]){url=@"https://help.openai.com/en/articles/7905690-how-to-cancel-your-apple-subscription-for-chatgpt-in-the-chatgpt-ios-app";platform=@"apple";}
  else if([origin isEqual:@"chatgpt_mobile_android"]){url=@"https://help.openai.com/en/articles/8258076-how-to-cancel-a-subscription-in-the-chatgpt-android-app";platform=@"android";}
 }else if([operation isEqual:@"subscription6.billingRecovery"]){
  if(!web||!D(subscription)||![subscription[@"stripe"]isEqual:@YES]||![subscription[@"delinquent"]isEqual:@YES]||![subscription[@"plan"]isEqual:a[@"plan"]]||gratis)return Fail(error,@"capability_unavailable");
  url=management;platform=@"web";purpose=@"review_payment_recovery";
 }
 if(!url)return Fail(error,@"capability_unavailable");
 return @{@"action":@"open_browser",@"purpose":purpose,@"url":url,@"platform":platform,@"accountId":a[@"accountId"],@"completed":@NO,@"requiresExistingAccount":@YES,@"eligibilityVerified":@NO,@"chargesSubmitted":@NO};
}
