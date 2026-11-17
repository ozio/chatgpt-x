#import "OR6RealtimeNetwork.h"
#import "../OR6APIWebAdapter.h"
#import "../OR6APIHTTP.h"
#import <dispatch/dispatch.h>
static BOOL Text(id v,NSUInteger max){return[v isKindOfClass:NSString.class]&&[v length]&&[v length]<=max&&[v rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location==NSNotFound;}
static BOOL UUID(id v){return Text(v,36)&&[[NSRegularExpression regularExpressionWithPattern:@"^[a-fA-F0-9]{8}(-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}$"options:0 error:NULL]numberOfMatchesInString:v options:0 range:NSMakeRange(0,[v length])]==1;}
BOOL OR6RealtimeSessionValid(NSDictionary*s){
 if(![s isKindOfClass:NSDictionary.class])return NO;
 NSSet*required=[NSSet setWithArray:@[@"parent_message_id",@"requested_default_model",@"voice",@"voice_session_id",@"voice_status_request_id",@"timezone_offset_min",@"timezone",@"user_locale",@"voice_mode",@"model_slug",@"model_slug_advanced",@"client_tools",@"history_and_training_disabled",@"conversation_mode",@"chat_mode",@"backend_model",@"enable_message_streaming",@"deprecate_celsius"]];NSMutableSet*allowed=[[required mutableCopy]autorelease];[allowed addObjectsFromArray:@[@"conversation_id",@"language_code",@"thinking_effort",@"backend_thinking_effort"]];
 if(![required isSubsetOfSet:[NSSet setWithArray:s.allKeys]]||![[NSSet setWithArray:s.allKeys]isSubsetOfSet:allowed])return NO;
 if(!UUID(s[@"parent_message_id"])||!UUID(s[@"voice_session_id"])||![s[@"voice_status_request_id"]isEqual:s[@"voice_session_id"]]||(s[@"conversation_id"]&&!UUID(s[@"conversation_id"])))return NO;
 if(![s[@"voice_mode"]isEqual:@"wingman"]||![s[@"chat_mode"]isEqual:@"chat"]||![s[@"conversation_mode"]isEqual:@{@"kind":@"primary_assistant"}]||![s[@"client_tools"]isEqual:@[]]||![s[@"history_and_training_disabled"]isEqual:@NO]||![s[@"enable_message_streaming"]isEqual:@YES]||![s[@"deprecate_celsius"]isEqual:@YES])return NO;
 for(NSString*k in @[@"requested_default_model",@"model_slug",@"model_slug_advanced"])if(![s[k]isEqual:@""])return NO;
 for(NSString*k in @[@"voice",@"backend_model",@"timezone",@"user_locale"])if(!Text(s[k],128))return NO;
 for(NSString*k in @[@"language_code",@"thinking_effort",@"backend_thinking_effort"])if(s[k]&&!Text(s[k],64))return NO;
 return OR6APISchemaCheck(s[@"timezone_offset_min"],@{@"type":@"integer",@"minimum":@(-840),@"maximum":@840},@{});
}
@interface OR6RealtimeRequest:NSObject<OR6APITask>{BOOL _cancelled;}
- (BOOL)cancelled;
@end
@implementation OR6RealtimeRequest
- (void)cancel{@synchronized(self){_cancelled=YES;}}
- (BOOL)cancelled{@synchronized(self){return _cancelled;}}
@end
id<OR6APITask> OR6RealtimeConnect(OR6APIWebAdapter*adapter,NSString*roots,NSDictionary*ctx,NSDictionary*session,NSString*offer,OR6APIReply reply){
 OR6RealtimeRequest*task=[[[OR6RealtimeRequest alloc]init]autorelease];
 if(!NSThread.isMainThread||!OR6RealtimeSessionValid(session)||![offer isKindOfClass:NSString.class]||offer.length>8191||![offer hasPrefix:@"v=0\r\n"]||!roots.length||![ctx[@"key"]isEqual:adapter.contextKey]){reply(nil,OR6APIError(@"invalid_request",@"none"));return task;}
 NSString*boundary=[@"OR6Voice-"stringByAppendingString:session[@"voice_session_id"]];NSData*json=[NSJSONSerialization dataWithJSONObject:session options:0 error:NULL];NSString*metadata=[[[NSString alloc]initWithData:json encoding:NSUTF8StringEncoding]autorelease];
 if(!metadata||[offer rangeOfString:boundary].location!=NSNotFound||[metadata rangeOfString:boundary].location!=NSNotFound){reply(nil,OR6APIError(@"invalid_request",@"none"));return task;}
 NSString*body=[NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"sdp\"\r\n\r\n%@\r\n--%@\r\nContent-Disposition: form-data; name=\"session\"\r\n\r\n%@\r\n--%@--\r\n",boundary,offer,boundary,metadata,boundary];
 NSMutableURLRequest*r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://chatgpt.com/realtime/wm?dcid=0"]];r.HTTPMethod=@"POST";r.HTTPBody=[body dataUsingEncoding:NSUTF8StringEncoding];[r setValue:[@"multipart/form-data; boundary="stringByAppendingString:boundary]forHTTPHeaderField:@"Content-Type"];[r setValue:@"text/plain, application/json"forHTTPHeaderField:@"Accept"];[r setValue:@"identity"forHTTPHeaderField:@"Accept-Encoding"];[r setValue:@"https://chatgpt.com"forHTTPHeaderField:@"Origin"];[r setValue:@"https://chatgpt.com/"forHTTPHeaderField:@"Referer"];[r setValue:@"LegacyClient/0.3 (iOS 6)"forHTTPHeaderField:@"User-Agent"];
 NSUInteger generation=adapter.credentialGeneration;NSURLRequest*authorized=[adapter authorizeRealtimeRequest:r expectedKey:ctx[@"key"]];
 if(!authorized){reply(nil,OR6APIError(@"not_authenticated",@"none"));return task;}
 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{NSAutoreleasePool*pool=[NSAutoreleasePool new];NSError*network=nil;NSDictionary*response=OR6APIHTTPPerform(authorized,roots,[NSSet setWithObject:@"chatgpt.com"],@{@"connectTimeout":@10,@"idleTimeout":@15,@"overallTimeout":@25,@"collectBody":@YES,@"maxRequestBytes":@16384,@"maxDecodedBytes":@32768},^BOOL{return task.cancelled;},nil,nil,&network);
  NSInteger status=[response[@"status"]integerValue];NSError*problem=nil;NSString*answer=nil;
  if(!response)problem=OR6APIError(task.cancelled?@"cancelled":@"network_unavailable",@"possible");
  else if(![response[@"certificateVerified"]isEqual:@YES])problem=OR6APIError(@"tls",@"possible");
  else if(status<200||status>299)problem=OR6APIError(status==401?@"not_authenticated":status==403?@"service_challenge":status==429?@"rate_limited":@"upstream_error",@"confirmed");
  else{NSData*d=response[@"data"];answer=[[[NSString alloc]initWithData:d encoding:NSUTF8StringEncoding]autorelease];if([answer hasPrefix:@"{"]){id j=[NSJSONSerialization JSONObjectWithData:d options:0 error:NULL];id transport=[j isKindOfClass:NSDictionary.class]?j[@"transport"]:nil;answer=[transport isKindOfClass:NSDictionary.class]?transport[@"sdp"]:nil;}if(![answer isKindOfClass:NSString.class]||![answer hasPrefix:@"v=0\r\n"]||answer.length>8191)problem=OR6APIError(@"unknown_wire_shape",@"confirmed");}
  dispatch_async(dispatch_get_main_queue(),^{if(task.cancelled){reply(nil,OR6APIError(@"cancelled",@"possible"));return;}if(generation!=adapter.credentialGeneration||![ctx[@"key"]isEqual:adapter.contextKey]){reply(nil,OR6APIError(@"stale_context",@"possible"));return;}NSError*final=problem;if(!final&&![adapter acceptChatCookies:response[@"setCookies"]?:@[]expectedKey:ctx[@"key"]generation:generation])final=OR6APIError(@"storage_failure",@"confirmed");reply(final?nil:@{@"sdp":answer,@"status":@(status)},final);});[pool drain];
 });return task;
}
