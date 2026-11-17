#import "OR6Selected20.h"
#import "../OR6APIWebAdapter.h"
#import "../OR6APIHTTP.h"
#import "../priority5a/OR6API5APolicy.h"
#import "../priority4b/OR6API4BPolicy.h"
#import "../priority7/OR6API7Policy.h"
#import <dispatch/dispatch.h>
static BOOL SafeID(NSString *s){return OR6API4BIdentifier(s);}
BOOL OR6Selected20AllowedRequest(NSURLRequest *r){
 for(NSString*header in r.allHTTPHeaderFields){NSString*key=header.lowercaseString;if(![@[@"chatgpt-account-id",@"content-type"]containsObject:key])return NO;if([key isEqual:@"content-type"]&&![[r valueForHTTPHeaderField:header]isEqual:@"application/json"])return NO;}
 NSURL *candidate=r.URL;NSMutableURLRequest *bare=[[r mutableCopy]autorelease];[bare setValue:nil forHTTPHeaderField:@"ChatGPT-Account-Id"];
 if(([candidate.path isEqual:@"/backend-api/prompt_library/"]||[candidate.path isEqual:@"/backend-api/prompt_library"])&&OR6API5AAllowedRequest(bare))return YES;
 if(([candidate.path isEqual:@"/backend-api/conversation/experimental/generate_autocompletions"]||[candidate.path hasPrefix:@"/backend-api/hazelnuts"])&&OR6API4BAllowedRequest(r))return YES;
 if([candidate.path isEqual:@"/backend-api/codex-app-server/prediction"]){if(![candidate.scheme isEqual:@"https"]||![candidate.host isEqual:@"chatgpt.com"]||candidate.port||candidate.user||candidate.password||candidate.fragment||candidate.query||r.HTTPBodyStream||r.HTTPBody.length>8192||![r.HTTPMethod isEqual:@"POST"])return NO;id body=r.HTTPBody?[NSJSONSerialization JSONObjectWithData:r.HTTPBody options:0 error:NULL]:nil;if(![body isKindOfClass:NSDictionary.class]||([body count]!=2&&[body count]!=3)||!OR6API7UUID(body[@"conversationId"])||![@[@"live",@"catch_up"]containsObject:body[@"generationTrigger"]])return NO;for(NSString*k in body)if(![@[@"conversationId",@"expectedMessageId",@"generationTrigger"]containsObject:k])return NO;return !body[@"expectedMessageId"]||OR6API7UUID(body[@"expectedMessageId"]);}

 NSURL *u=r.URL;if(![u.scheme isEqual:@"https"]||![u.host isEqual:@"chatgpt.com"]||u.port||u.user||u.password||u.fragment||r.HTTPBodyStream||r.HTTPBody||![r.HTTPMethod isEqual:@"GET"]||u.absoluteString.length>8192)return NO;
 NSMutableDictionary *q=[NSMutableDictionary dictionary];for(NSString *s in [u.query componentsSeparatedByString:@"&"]){NSArray *p=[s componentsSeparatedByString:@"="];if(p.count!=2||q[p[0]])return NO;NSString *v=[p[1]stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];if(!v)return NO;q[p[0]]=v;}
 if([u.path isEqual:@"/backend-api/settings/user"])return !u.query;
 if([u.path isEqual:@"/backend-api/estuary/content"])return u.query.length>0&&u.query.length<=8192;
 if([u.path isEqual:@"/backend-api/synthesize"])return q.count==3&&OR6API7UUID(q[@"conversation_id"])&&OR6API7UUID(q[@"message_id"])&&[q[@"format"]isEqual:@"mp3"];
 if([u.path isEqual:@"/backend-api/wham/tasks/list"])return(q.count==2||q.count==3)&&[q[@"limit"]isEqual:@"20"]&&[q[@"task_filter"]isEqual:@"current"]&&(!q[@"cursor"]||([q[@"cursor"]length]&&[q[@"cursor"]length]<=4096));
 if([u.path isEqual:@"/backend-api/wham/environments"])return !u.query;
 NSArray *p=[u.path componentsSeparatedByString:@"/"];if(p.count==7&&[p[1]isEqual:@"backend-api"]&&[p[2]isEqual:@"files"]&&[p[3]isEqual:@"library"]&&[p[4]isEqual:@"files"]&&SafeID(p[5])&&[p[6]isEqual:@"content_url"]&&!u.query)return YES;
 return !u.query&&((p.count==5&&[p[1]isEqual:@"backend-api"]&&[p[2]isEqual:@"wham"]&&[p[3]isEqual:@"tasks"]&&SafeID(p[4]))||(p.count==6&&[p[1]isEqual:@"backend-api"]&&[p[2]isEqual:@"wham"]&&[p[3]isEqual:@"environments"]&&SafeID(p[4])&&[p[5]isEqual:@"with-creator-and-machine"]));
}
@interface OR6S20NetworkTask:NSObject<OR6APITask>{BOOL _cancelled;}
- (BOOL)cancelled;
@end
@implementation OR6S20NetworkTask
- (void)cancel{@synchronized(self){_cancelled=YES;}}
- (BOOL)cancelled{@synchronized(self){return _cancelled;}}
@end
@interface OR6Selected20Network(){OR6APIWebAdapter *_adapter;NSString *_roots;NSDictionary *_lastFailure;NSUInteger _failures;}
@end
@implementation OR6Selected20Network
- (id)initWithAdapter:(OR6APIWebAdapter *)adapter roots:(NSString *)roots{if((self=[super init])){_adapter=[adapter retain];_roots=[roots copy];}return self;}
- (BOOL)current:(NSDictionary *)ctx generation:(NSUInteger)g task:(OR6S20NetworkTask *)task{return !task.cancelled&&g==_adapter.credentialGeneration&&[ctx[@"key"]isEqual:_adapter.contextKey]&&[_adapter chatMatchesOwner:ctx[@"userId"]]&&g==_adapter.credentialGeneration&&!task.cancelled;}
- (id<OR6APITask>)request:(NSURLRequest *)request context:(NSDictionary *)context completion:(OR6APIReply)reply{
 OR6S20NetworkTask *task=[[[OR6S20NetworkTask alloc]init]autorelease];NSDictionary *ctx=OR6APIJSONSnapshot(context,8192);NSURLRequest *r=[[request copy]autorelease];
 if(!NSThread.isMainThread||!OR6Selected20AllowedRequest(r)||![ctx[@"userId"]isKindOfClass:NSString.class]||![ctx[@"accountId"]isKindOfClass:NSString.class]||![[r valueForHTTPHeaderField:@"ChatGPT-Account-Id"]isEqual:ctx[@"accountId"]]){void(^done)(void)=^{reply(nil,OR6APIError(@"invalid_request",@"none"));};if(NSThread.isMainThread)done();else dispatch_async(dispatch_get_main_queue(),done);return task;}
 NSUInteger g=_adapter.credentialGeneration;if(![self current:ctx generation:g task:task]){reply(nil,OR6APIError(@"stale_context",@"none"));return task;}
 NSMutableURLRequest *q=[[r mutableCopy]autorelease];BOOL audio=[r.URL.path isEqual:@"/backend-api/synthesize"]||[r.URL.path isEqual:@"/backend-api/estuary/content"];[q setValue:audio?([r.URL.path isEqual:@"/backend-api/synthesize"]?@"audio/mpeg":@"image/png,image/jpeg"):@"application/json" forHTTPHeaderField:@"Accept"];[q setValue:@"https://chatgpt.com" forHTTPHeaderField:@"Origin"];[q setValue:@"https://chatgpt.com/" forHTTPHeaderField:@"Referer"];NSURLRequest *auth=[_adapter authorizeChatRequest:q expectedKey:ctx[@"key"]];if(!auth){reply(nil,OR6APIError(@"not_authenticated",@"none"));return task;}auth=[[auth copy]autorelease];
 // Speech is synthesized before the first byte: a long answer can take well over the 25s idle bound of JSON reads.
 BOOL speech=[r.URL.path isEqual:@"/backend-api/synthesize"];
 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{NSAutoreleasePool *pool=[NSAutoreleasePool new];NSError *e=nil;NSDictionary *v=OR6APIHTTPPerform(auth,_roots,[NSSet setWithObject:@"chatgpt.com"],@{@"connectTimeout":@15,@"idleTimeout":@(speech?90:25),@"overallTimeout":@(speech?240:60),@"collectBody":@YES,@"maxRequestBytes":@32768,@"maxDecodedBytes":@(audio?8*1024*1024:4*1024*1024)},^BOOL{return task.cancelled;},nil,nil,&e);NSInteger status=[v[@"status"]integerValue];NSError *error=nil;id json=nil;NSData *bytes=nil;
 NSDictionary *failure=nil;NSString *cause=nil;if(!v){NSString *named=e.localizedDescription;cause=[@[@"connect_timeout",@"idle_timeout",@"overall_timeout",@"dns_failure",@"tls_failure",@"certificate_failure",@"invalid_response",@"size_limit",@"io_failure",@"consumer_stopped",@"cancelled"]containsObject:named]?named:@"io_failure";NSString *code=task.cancelled?@"cancelled":[@[@"connect_timeout",@"idle_timeout",@"overall_timeout"]containsObject:cause]?@"timeout":[cause isEqual:@"size_limit"]?@"size_limit":[@[@"tls_failure",@"certificate_failure"]containsObject:cause]?@"tls":@"network_unavailable";error=OR6APIError(code,@"none");}else if(![v[@"certificateVerified"]isEqual:@YES])error=OR6APIError(@"tls",@"none");else if(status<200||status>299)error=OR6APIError(status==401?@"not_authenticated":status==403?@"service_challenge":status==429?@"rate_limited":status==404?@"not_found":@"upstream_error",@"none");else{NSData *data=v[@"data"];if(audio){if([data isKindOfClass:NSData.class]&&data.length&&data.length<=8*1024*1024)bytes=[[data copy]autorelease];else error=OR6APIError(@"unsupported_media",@"none");}else if([r.HTTPMethod isEqual:@"POST"]&&[r.URL.path hasPrefix:@"/backend-api/hazelnuts/"]&&[r.URL.path hasSuffix:@"/status"]){json=NSNull.null;}else{json=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]:nil;if(![json isKindOfClass:NSDictionary.class]&&![json isKindOfClass:NSArray.class])error=OR6APIError(@"unknown_wire_shape",@"none");}}
 NSDictionary *result=audio?@{@"status":@(status),@"data":bytes?:[NSData data]}:@{@"status":@(status),@"json":json?:NSNull.null};NSArray *cookies=OR6APIJSONSnapshot(@{@"cookies":v[@"setCookies"]?:@[]},128*1024)[@"cookies"];
 if(cause)failure=@{@"path":r.URL.path?:@"",@"cause":cause,@"responseBytesRead":e.userInfo[@"responseBytesRead"]?:@0,@"responseFraming":e.userInfo[@"responseFraming"]?:@"unobserved",@"at":@((long long)[[NSDate date] timeIntervalSince1970])};
 dispatch_async(dispatch_get_main_queue(),^{if(failure){_failures++;[_lastFailure release];_lastFailure=[failure copy];}if(![self current:ctx generation:g task:task]){reply(nil,OR6APIError(task.cancelled?@"cancelled":@"stale_context",@"none"));return;}if(!error&&(!cookies||![_adapter acceptChatCookies:cookies expectedKey:ctx[@"key"]generation:g])){reply(nil,OR6APIError(@"storage_failure",@"none"));return;}if(![self current:ctx generation:g task:task]){reply(nil,OR6APIError(task.cancelled?@"cancelled":@"stale_context",@"none"));return;}reply(error?nil:result,error);});[pool drain];});return task;
}
- (NSDictionary *)diagnostics{return @{@"transportFailures":@(_failures),@"lastTransportFailure":_lastFailure?:(id)NSNull.null};}
- (void)dealloc{[_adapter release];[_roots release];[_lastFailure release];[super dealloc];}
@end
