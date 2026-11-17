#import "OR6API6FNetwork.h"
#import "OR6API6FPolicy.h"
#import "../OR6APIWebAdapter.h"
#import "../OR6APIHTTP.h"
#import <dispatch/dispatch.h>
static NSDictionary*D(id v){return[v isKindOfClass:NSDictionary.class]?v:nil;}
static BOOL Context(id v){return D(v)&&[v[@"key"]isKindOfClass:NSString.class]&&[v[@"key"]length]&&[v[@"key"]length]<=256&&OR6APISchemaCheck(v[@"generation"],@{@"type":@"integer",@"minimum":@1,@"maximum":@2147483647},@{});}
static BOOL PublicAudioURL(NSURL*u){
 if(![u isKindOfClass:NSURL.class]||![u.scheme isEqual:@"https"]||!u.host.length||u.host.length>253||u.user||u.password||u.fragment||(u.port&&u.port.integerValue!=443)||u.absoluteString.length>8192||[u.absoluteString rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound)return NO;
 NSString*h=u.host.lowercaseString;if([h isEqual:@"localhost"]||[h hasSuffix:@".localhost"]||[h hasSuffix:@".local"]||[h hasSuffix:@".internal"]||[h hasSuffix:@".home.arpa"]||[h rangeOfString:@":"].location!=NSNotFound||[h rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789."]invertedSet]].location==NSNotFound)return NO;
 if([h rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789-."]invertedSet]].location!=NSNotFound)return NO;for(NSString*label in[h componentsSeparatedByString:@"."])if(!label.length||label.length>63||[label hasPrefix:@"-"]||[label hasSuffix:@"-"])return NO;return YES;
}
@interface OR6API6FNetworkTask:NSObject<OR6APITask>{BOOL _cancelled;}
- (BOOL)cancelled;
@end
@implementation OR6API6FNetworkTask
- (void)cancel{@synchronized(self){_cancelled=YES;}}
- (BOOL)cancelled{@synchronized(self){return _cancelled;}}
@end
@implementation OR6API6FNetwork
- (id)initWithAdapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots{if((self=[super init])){if(!adapter||![roots isKindOfClass:NSString.class]||!roots.length){[self release];return nil;}_adapter=[adapter retain];_roots=[roots copy];_previews=[NSMutableDictionary new];}return self;}
- (BOOL)bindPreviewURL:(NSURL*)URL token:(NSString*)token context:(NSDictionary*)ctx error:(NSError**)error{
 if(NSThread.isMainThread){NSTimeInterval now=NSProcessInfo.processInfo.systemUptime;for(NSString*key in [[_previews.allKeys copy]autorelease]){NSDictionary*b=_previews[key];NSTimeInterval age=now-[b[@"time"]doubleValue];if(age<0||age>300||[b[@"generation"]unsignedIntegerValue]!=_adapter.credentialGeneration||![b[@"context"]isEqual:ctx])[_previews removeObjectForKey:key];}}
 if(!NSThread.isMainThread||!Context(ctx)||!OR6API6FUUID(token)||!PublicAudioURL(URL)||![ctx[@"key"]isEqual:_adapter.contextKey]||_previews[token]||_previews.count>=32){if(error)*error=OR6APIError(@"invalid_request",@"none");return NO;}
 _previews[token]=@{@"url":URL.absoluteString,@"context":OR6APIJSONSnapshot(ctx,4096),@"generation":@(_adapter.credentialGeneration),@"time":@(NSProcessInfo.processInfo.systemUptime)};return YES;
}
- (void)clearPreviewBindings{if(!NSThread.isMainThread)return;[_previews removeAllObjects];}
- (id<OR6APITask>)request:(NSURLRequest*)request context:(NSDictionary*)ctx completion:(OR6APIReply)reply{
 OR6API6FNetworkTask*task=[[[OR6API6FNetworkTask alloc]init]autorelease];if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{reply(nil,OR6APIError(@"invalid_request",@"none"));});return task;}request=[[request copy]autorelease];ctx=OR6APIJSONSnapshot(ctx,4096);NSString*token=[request valueForHTTPHeaderField:@"X-OR6-Voice-Preview"];NSDictionary*bound=token?_previews[token]:nil;BOOL preview=token!=nil;
 if(!NSThread.isMainThread||!Context(ctx)){void(^fail)(void)=^{reply(nil,OR6APIError(@"invalid_request",@"none"));};if(NSThread.isMainThread)fail();else dispatch_async(dispatch_get_main_queue(),fail);return task;}
 if(preview){BOOL allowed=OR6API6FUUID(token)&&PublicAudioURL(request.URL)&&[bound[@"url"]isEqual:request.URL.absoluteString]&&[bound[@"context"]isEqual:ctx]&&[bound[@"generation"]unsignedIntegerValue]==_adapter.credentialGeneration&&NSProcessInfo.processInfo.systemUptime-[bound[@"time"]doubleValue]>=0&&NSProcessInfo.processInfo.systemUptime-[bound[@"time"]doubleValue]<=300&&[request.HTTPMethod isEqual:@"GET"]&&!request.HTTPBody&&!request.HTTPBodyStream&&[request.allHTTPHeaderFields isEqual:@{@"Accept":@"audio/*",@"X-OR6-Voice-Preview":token}];if(!allowed){reply(nil,OR6APIError(@"invalid_request",@"none"));return task;}[_previews removeObjectForKey:token];}
 else if(!OR6API6FAllowedRequest(request)){reply(nil,OR6APIError(@"invalid_request",@"none"));return task;}
 NSMutableURLRequest*r=[[request mutableCopy]autorelease];NSUInteger generation=_adapter.credentialGeneration;NSURLRequest*authorized=nil;
 if(preview){[r setValue:nil forHTTPHeaderField:@"X-OR6-Voice-Preview"];authorized=r;}
 else{[r setValue:@"https://chatgpt.com"forHTTPHeaderField:@"Origin"];[r setValue:@"https://chatgpt.com/"forHTTPHeaderField:@"Referer"];authorized=[_adapter authorizeChatRequest:r expectedKey:ctx[@"key"]];}
 if(!authorized||![ctx[@"key"]isEqual:_adapter.contextKey]){reply(nil,OR6APIError(@"not_authenticated",@"none"));return task;}
 BOOL pdf=[authorized.URL.path isEqual:@"/backend-api/export_doc/deep_research"],binary=pdf||preview;NSSet*hosts=[NSSet setWithObject:authorized.URL.host];
 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{NSAutoreleasePool*pool=[NSAutoreleasePool new];NSError*network=nil;
  NSDictionary*response=OR6APIHTTPPerform(authorized,_roots,hosts,@{@"connectTimeout":@15,@"idleTimeout":@25,@"overallTimeout":@45,@"collectBody":@YES,@"maxRequestBytes":@32768,@"maxDecodedBytes":@(binary?8*1024*1024:4*1024*1024)},^BOOL{return task.cancelled;},nil,nil,&network);
  id sentBytes=response[@"requestBytesSent"]?:network.userInfo[@"requestBytesSent"];NSString*sent=[sentBytes isKindOfClass:NSNumber.class]&&![sentBytes unsignedLongLongValue]?@"none":@"possible";NSInteger status=[response[@"status"]integerValue];NSError*problem=nil;NSDictionary*result=nil;
  if(!response)problem=OR6APIError(task.cancelled?@"cancelled":@"network_unavailable",sent);
  else if(![response[@"certificateVerified"]isEqual:@YES])problem=OR6APIError(@"tls",sent);
  else if(status<200||status>299)problem=OR6APIError(status==401?@"not_authenticated":status==403?@"service_challenge":status==404?@"not_found":status==409?@"conflict":status==429?@"rate_limited":@"upstream_error",sent);
  else if(binary){NSData*data=response[@"data"];id type=D(response[@"headers"])[@"content-type"]?:D(response[@"headers"])[@"Content-Type"];NSString*mime=[type isKindOfClass:NSString.class]?[[[type componentsSeparatedByString:@";"]objectAtIndex:0]lowercaseString]:@"";if(![data isKindOfClass:NSData.class]||!data.length||data.length>8*1024*1024||mime.length>128)problem=OR6APIError(@"unknown_wire_shape",sent);else result=@{@"status":@(status),@"data":[[data copy]autorelease],@"mediaType":mime};}
  else{NSData*data=response[@"data"];id json=data.length?[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]:NSNull.null;if((!data.length&&status!=204)||(data.length&&!D(json)&&![json isKindOfClass:NSArray.class]))problem=OR6APIError(@"unknown_wire_shape",sent);else result=@{@"status":@(status),@"json":json?:NSNull.null};}
  dispatch_async(dispatch_get_main_queue(),^{
   if(task.cancelled){reply(nil,OR6APIError(@"cancelled",sent));return;}if(generation!=_adapter.credentialGeneration||![ctx[@"key"]isEqual:_adapter.contextKey]){reply(nil,OR6APIError(@"stale_context",sent));return;}
   if(!problem&&!preview&&![_adapter acceptChatCookies:response[@"setCookies"]?:@[]expectedKey:ctx[@"key"]generation:generation]){reply(nil,OR6APIError(@"storage_failure",sent));return;}
   if(problem){reply(nil,problem);return;}
   NSDictionary*out=result;id json=result[@"json"];
   if([authorized.URL.path isEqual:@"/backend-api/me"]&&(!D(json)||![_adapter chatMatchesOwner:D(json)[@"id"]])){reply(nil,OR6APIError(@"owner_mismatch",@"none"));return;}
   if([authorized.URL.path isEqual:@"/backend-api/accounts/check/v4-2023-04-27"]){NSDictionary*root=D(json),*accounts=D(root[@"accounts"]);id ordering=root[@"account_ordering"];NSString*selected=[authorized valueForHTTPHeaderField:@"ChatGPT-Account-ID"];if(!selected.length&&[root[@"default_account_id"]isKindOfClass:NSString.class])selected=root[@"default_account_id"];NSDictionary*found=nil;
    if(accounts.count<=128&&[ordering isKindOfClass:NSArray.class]&&[ordering count]<=128)for(id key in ordering){if(![key isKindOfClass:NSString.class])continue;NSDictionary*entry=D(accounts[key]),*account=D(entry[@"account"]);if(selected.length?![key isEqual:selected]&&![account[@"account_id"]isEqual:selected]:![key isEqual:[ordering objectAtIndex:0]])continue;if(found){found=nil;break;}if([account[@"account_id"]isKindOfClass:NSString.class]&&[account[@"structure"]isKindOfClass:NSString.class]&&![entry[@"can_access_with_session"]isEqual:@NO]&&![account[@"is_deactivated"]isEqual:@YES])found=account;}
    NSString*plan=found[@"plan_type"];if(!found||![plan isKindOfClass:NSString.class]||!plan.length||plan.length>128){reply(nil,OR6APIError(@"owner_mismatch",@"none"));return;}
    // mNEt's source plan predicate, derived from the authenticated account.
    NSSet*known=[NSSet setWithArray:@[@"free",@"go",@"plus",@"pro",@"promax",@"prolite",@"free_workspace",@"team",@"self_serve_business_prolite",@"sci",@"rosalind_academic",@"business",@"self_serve_business_usage_based",@"enterprise_cbp_usage_based",@"enterprise_cbp_automation",@"enterprise_cbp_trial",@"enterprise_cbp_view_only",@"finserv",@"law",@"ent26",@"education",@"edu_plus",@"edu_pro",@"quorum",@"enterprise",@"hc",@"hc_consumption",@"deprecated_enterprise",@"edu",@"deprecated_edu",@"k12"]];BOOL paid=[known containsObject:plan]&&![@[@"free",@"go",@"free_workspace"]containsObject:plan];out=@{@"status":@(status),@"json":json,@"accountBinding":@{@"id":found[@"account_id"],@"personal":@([found[@"structure"]isEqual:@"personal"]),@"paidEligible":@(paid)}};
   }
   reply(out,nil);
  });[pool drain];
 });return task;
}
- (void)dealloc{[_adapter release];[_roots release];[_previews release];[super dealloc];}
@end
