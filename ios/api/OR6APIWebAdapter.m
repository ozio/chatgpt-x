#import "OR6APIWebAdapter.h"
#import "OR6APIHTTP.h"
#import "OR6APIWire.h"
#import "../auth/OR6WebCookies.h"
#import <CommonCrypto/CommonDigest.h>
#import <dispatch/dispatch.h>
static BOOL UUID(NSString*s){if(![s isKindOfClass:NSString.class]||s.length!=36)return NO;return[[NSRegularExpression regularExpressionWithPattern:@"^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$"options:0 error:NULL]numberOfMatchesInString:s options:0 range:NSMakeRange(0,s.length)]==1;}
// This category stays within the private adapter. It never returns raw tokens.
@interface OR6WebSession(OR6APIPrivate)
- (NSString*)apiKey:(NSString*)workspace;
- (NSURLRequest*)apiAuthorize:(NSURLRequest*)request workspace:(NSString*)workspace expectedKey:(NSString*)key;
- (NSURLRequest*)apiAuthorize:(NSURLRequest*)request workspace:(NSString*)workspace expectedKey:(NSString*)key realtime:(BOOL)realtime;
- (BOOL)apiAcceptCookies:(NSArray*)headers workspace:(NSString*)workspace expectedKey:(NSString*)key generation:(NSUInteger)generation;
- (BOOL)apiMatchesOwner:(NSString*)owner;
@end
@interface OR6WebSession(OR6APIPrivatePersistence)
- (BOOL)persist:(NSDictionary*)record;
@end
@implementation OR6WebSession(OR6APIPrivate)
- (NSString*)apiKey:(NSString*)workspace{
 if(!_authenticated||_busy||![_record[@"state"]isEqual:@"active"]||[_record[@"expiresAt"]doubleValue]<=_clock()+15)return nil;
 NSString*s=[NSString stringWithFormat:@"%lu:%@|%lu:%@",(unsigned long)[_record[@"owner"]length],_record[@"owner"],(unsigned long)(workspace?:@"unresolved_default").length,workspace?:@"unresolved_default"];NSData*d=[s dataUsingEncoding:NSUTF8StringEncoding];unsigned char hash[CC_SHA256_DIGEST_LENGTH];CC_SHA256(d.bytes,(CC_LONG)d.length,hash);NSMutableString*r=[NSMutableString string];for(NSUInteger i=0;i<sizeof(hash);i++)[r appendFormat:@"%02x",hash[i]];return r;
}
- (NSURLRequest*)apiAuthorize:(NSURLRequest*)r workspace:(NSString*)workspace expectedKey:(NSString*)key{return[self apiAuthorize:r workspace:workspace expectedKey:key realtime:NO];}
- (NSURLRequest*)apiAuthorize:(NSURLRequest*)r workspace:(NSString*)workspace expectedKey:(NSString*)key realtime:(BOOL)realtime{
 NSString*path=r.URL.path,*discovery=@"/public-api/gizmos/discovery";BOOL discoveryPath=[path isEqual:discovery];
 if([path hasPrefix:[discovery stringByAppendingString:@"/"]]){NSString*cut=[path substringFromIndex:discovery.length+1];discoveryPath=cut.length>0&&cut.length<=128&&[cut rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"]invertedSet]].location==NSNotFound;}
 BOOL realtimePath=realtime&&[path isEqual:@"/realtime/wm"]&&[r.URL.query isEqual:@"dcid=0"]&&[r.HTTPMethod isEqual:@"POST"]&&r.HTTPBody.length>0&&r.HTTPBody.length<=16384&&!r.HTTPBodyStream&&[[r valueForHTTPHeaderField:@"Content-Type"]hasPrefix:@"multipart/form-data; boundary=OR6Voice-"];
 if(realtime&&!realtimePath)return nil;
 BOOL publicDiscovery=discoveryPath&&[r.HTTPMethod isEqual:@"GET"]&&!r.HTTPBody&&!r.HTTPBodyStream&&[[r valueForHTTPHeaderField:@"X-OpenAI-Attach-Auth"]isEqual:@"1"];
 if(!NSThread.isMainThread||![key isEqual:[self apiKey:workspace]]||![r.URL.scheme.lowercaseString isEqual:@"https"]||![r.URL.host.lowercaseString isEqual:@"chatgpt.com"]||r.URL.user||r.URL.password||r.URL.fragment||(r.URL.port&&r.URL.port.integerValue!=443)||(![path hasPrefix:@"/backend-api/"]&&!publicDiscovery&&!realtimePath))return nil;
 // Feature adapters validate exact method/path/body before this private
 // authorization boundary. Their admitted account mutations use PATCH/DELETE.
 if(![@[@"GET",@"POST",@"PATCH",@"DELETE"]containsObject:r.HTTPMethod])return nil;
 NSMutableURLRequest*next=[[r mutableCopy]autorelease];[next setValue:[@"Bearer "stringByAppendingString:_record[@"accessToken"]]forHTTPHeaderField:@"Authorization"];
 if(realtime){NSString*account=workspace?:[self serviceAccount][@"accountId"];if(!UUID(account))return nil;[next setValue:account forHTTPHeaderField:@"ChatGPT-Account-Id"];}else if(workspace.length)[next setValue:workspace forHTTPHeaderField:@"ChatGPT-Account-Id"];
 NSArray*cookies=[_jar snapshot];if(![OR6WebCookies hasSession:cookies now:_clock()])cookies=_record[@"cookies"];
 NSString*header=[OR6WebCookies header:cookies now:_clock()];if(header.length)[next setValue:header forHTTPHeaderField:@"Cookie"];
 for(NSDictionary*c in cookies)if([c[@"name"]isEqual:@"oai-did"]&&UUID(c[@"value"]))[next setValue:c[@"value"]forHTTPHeaderField:@"OAI-Device-Id"];
 return[[next copy]autorelease];
}
- (BOOL)apiMatchesOwner:(NSString*)owner{return NSThread.isMainThread&&_authenticated&&!_busy&&[owner isKindOfClass:NSString.class]&&[owner isEqual:_record[@"owner"]]&&[_record[@"expiresAt"]doubleValue]>_clock()+15;}
- (BOOL)apiAcceptCookies:(NSArray*)headers workspace:(NSString*)workspace expectedKey:(NSString*)key generation:(NSUInteger)generation{
 if(!NSThread.isMainThread||generation!=_generation||![key isEqual:[self apiKey:workspace]])return NO;
 if(!headers.count)return YES;NSArray*base=[_jar snapshot];if(![OR6WebCookies hasSession:base now:_clock()])base=_record[@"cookies"];
 NSArray*updated=[OR6WebCookies merging:base setCookies:headers now:_clock()];if(!updated||![OR6WebCookies validRecords:updated])return NO;
 if(![updated isEqual:_record[@"cookies"]]){NSMutableDictionary*r=[[_record mutableCopy]autorelease];r[@"cookies"]=updated;r[@"revision"]=@(_revision+1);if(![self persist:r])return NO;}
 [_jar install:updated];return YES;
}
@end
@interface OR6APIReadTask:NSObject<OR6APITask>{BOOL _cancelled;}
- (BOOL)cancelled;
@end
@implementation OR6APIReadTask
- (void)cancel{@synchronized(self){_cancelled=YES;}}
- (BOOL)cancelled{@synchronized(self){return _cancelled;}}
@end
static NSString*Issue(NSInteger status){return status==401?@"not_authenticated":status==403?@"service_challenge":status==429?@"rate_limited":@"upstream_error";}

@implementation OR6APIWebAdapter
- (id)initWithSession:(OR6WebSession*)session roots:(NSString*)roots workspace:(NSString*)workspace permittedReads:(NSSet*)ops{
 if((self=[super init])){NSSet*allowed=[NSSet setWithArray:@[@"history.list",@"history.get",@"history.search",@"models.list"]];if(!session||![roots isKindOfClass:NSString.class]||(workspace&&(![workspace isKindOfClass:NSString.class]||!workspace.length||workspace.length>128||[workspace rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound))||![ops isSubsetOfSet:allowed]){[self release];return nil;}_session=[session retain];_roots=[roots copy];_workspace=[workspace copy];_permittedReads=[ops copy];_searchCursors=[NSMutableDictionary new];}return self;
}
- (NSString*)contextKey{return[_session apiKey:_workspace];}
- (NSUInteger)credentialGeneration{return _session.generation;}
- (NSURLRequest*)authorizeChatRequest:(NSURLRequest*)r expectedKey:(NSString*)key{return[_session apiAuthorize:r workspace:_workspace expectedKey:key];}
- (NSURLRequest*)authorizeRealtimeRequest:(NSURLRequest*)r expectedKey:(NSString*)key{return[_session apiAuthorize:r workspace:_workspace expectedKey:key realtime:YES];}
- (BOOL)acceptChatCookies:(NSArray*)h expectedKey:(NSString*)key generation:(NSUInteger)generation{return[_session apiAcceptCookies:h workspace:_workspace expectedKey:key generation:generation];}
- (BOOL)chatMatchesOwner:(NSString*)owner{return[_session apiMatchesOwner:owner];}
- (NSTimeInterval)recentChatOwnerValidationAgeForKey:(NSString*)key generation:(NSUInteger)generation{
 if(!NSThread.isMainThread||generation!=_session.generation||![key isEqual:self.contextKey])return -1;return[_session recentOwnerValidationAge];
}
- (BOOL)recordChatOwnerValidation:(NSString*)owner expectedKey:(NSString*)key generation:(NSUInteger)generation{
 if(!NSThread.isMainThread||generation!=_session.generation||![key isEqual:self.contextKey])return NO;return[_session recordOwnerValidation:owner generation:generation];
}
- (id<OR6APITask>)execute:(NSString*)operation parameters:(NSDictionary*)p context:(NSDictionary*)ctx event:(OR6APIEvent)event completion:(OR6APIReply)completion{
 (void)event;OR6APIReadTask*task=[[[OR6APIReadTask alloc]init]autorelease];
 NSUInteger epoch=[ctx[@"generation"]unsignedIntegerValue];if(epoch!=_contextEpoch){_contextEpoch=epoch;[_searchCursors removeAllObjects];}
 if(![_permittedReads containsObject:operation]){completion(nil,OR6APIError(@"capability_unverified",@"none"));return task;}
 NSString*path=nil;NSUInteger offset=0,limit=[p[@"limit"]unsignedIntegerValue];NSData*body=nil;
 if([operation isEqual:@"history.list"]){id token=p[@"pageToken"];if(token!=NSNull.null){if(![token isKindOfClass:NSString.class]||![token hasPrefix:@"offset:"]){completion(nil,OR6APIError(@"invalid_request",@"none"));return task;}NSString*number=[token substringFromIndex:7];if(!number.length||number.length>8||[number rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789"]invertedSet]].location!=NSNotFound){completion(nil,OR6APIError(@"invalid_request",@"none"));return task;}offset=(NSUInteger)number.longLongValue;if(offset>10000){completion(nil,OR6APIError(@"invalid_request",@"none"));return task;}}path=[NSString stringWithFormat:@"/backend-api/conversations?offset=%lu&limit=%lu&order=updated",(unsigned long)offset,(unsigned long)limit];}
 else if([operation isEqual:@"history.get"]){if(!UUID(p[@"conversationId"])){completion(nil,OR6APIError(@"invalid_request",@"none"));return task;}path=[@"/backend-api/conversation/"stringByAppendingString:p[@"conversationId"]];}
 else if([operation isEqual:@"history.search"]){path=@"/backend-api/global/search";id cursor=p[@"pageToken"];body=[NSJSONSerialization dataWithJSONObject:@{@"query":p[@"query"],@"limit":@(MAX(10,limit)),@"cursor":cursor}options:0 error:NULL];}
 else if([operation isEqual:@"models.list"])path=@"/backend-api/models?iim=false&include_icons=false&is_gizmo=false";
 if(!path){completion(nil,OR6APIError(@"capability_unverified",@"none"));return task;}
 NSMutableURLRequest*r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:[@"https://chatgpt.com"stringByAppendingString:path]]cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:40];r.HTTPMethod=body?@"POST":@"GET";r.HTTPBody=body;[r setValue:@"application/json"forHTTPHeaderField:@"Accept"];[r setValue:@"identity"forHTTPHeaderField:@"Accept-Encoding"];[r setValue:@"LegacyClient/0.3 (iOS 6)"forHTTPHeaderField:@"User-Agent"];if(body)[r setValue:@"application/json"forHTTPHeaderField:@"Content-Type"];
 NSURLRequest*request=[_session apiAuthorize:r workspace:_workspace expectedKey:ctx[@"key"]];NSUInteger generation=_session.generation;
 if(!request){completion(nil,OR6APIError(@"not_authenticated",@"none"));return task;}
 NSString*scope=[NSString stringWithFormat:@"%@:%@",ctx[@"key"],p[@"query"]?:@""];
 if([operation isEqual:@"history.search"]){if(p[@"pageToken"]==NSNull.null){if(_searchCursors.count>=8)[_searchCursors removeAllObjects];_searchCursors[scope]=[NSMutableSet set];}else if(![_searchCursors[scope]containsObject:p[@"pageToken"]]){completion(nil,OR6APIError(@"invalid_request",@"none"));return task;}}
 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{NSAutoreleasePool*pool=[NSAutoreleasePool new];NSError*network=nil;
  NSDictionary*response=OR6APIHTTPPerform(request,_roots,[NSSet setWithObject:@"chatgpt.com"],@{@"connectTimeout":@15,@"idleTimeout":@20,@"overallTimeout":@40,@"collectBody":@YES},^BOOL{return task.cancelled;},nil,nil,&network);
  NSInteger status=[response[@"status"]integerValue];NSError*error=nil;NSDictionary*value=nil;
  if(!response){error=OR6APIError(task.cancelled?@"cancelled":@"network_unavailable",[network.userInfo[@"requestBytesSent"]unsignedLongLongValue]?@"possible":@"none");}
  else if(status!=200)error=OR6APIError(status==404&&[operation isEqual:@"history.get"]?@"not_found":Issue(status),@"confirmed");
  else{NSData*data=response[@"data"];NSError*wire=nil;if([operation isEqual:@"history.list"])value=OR6APIWireHistory(data,offset,limit,&wire);else if([operation isEqual:@"history.get"])value=OR6APIWireConversation(data,p[@"conversationId"],&wire);else if([operation isEqual:@"history.search"])value=OR6APIWireSearch(data,p[@"pageToken"]==NSNull.null?nil:p[@"pageToken"],&wire);else{NSDictionary*models=OR6APIWireModels(data,&wire);if(models){id raw=[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];id selected=NSNull.null;for(NSDictionary*m in models[@"items"])if([m[@"id"]isEqual:raw[@"default_model_slug"]])selected=m[@"id"];value=@{@"items":models[@"items"],@"selectedModelId":selected};}}if(!value)error=OR6APIError(@"unknown_wire_shape",@"confirmed");}
  NSDictionary*snapshot=OR6APIJSONSnapshot(value,8*1024*1024);
  dispatch_async(dispatch_get_main_queue(),^{
   if(task.cancelled){completion(nil,OR6APIError(@"cancelled",@"possible"));return;}
   if(_contextEpoch!=epoch||_session.generation!=generation||![ctx[@"key"]isEqual:self.contextKey]){completion(nil,OR6APIError(@"stale_context",@"possible"));return;}
   if(!error&&![self acceptChatCookies:response[@"setCookies"]?:@[] expectedKey:ctx[@"key"] generation:generation]){completion(nil,OR6APIError(@"storage_failure",@"confirmed"));return;}
   if(!error&&[operation isEqual:@"history.search"]){id next=snapshot[@"nextToken"];NSMutableSet*seen=_searchCursors[scope];if(next!=NSNull.null){if(!seen||seen.count>=256||[seen containsObject:next]){completion(nil,OR6APIError(@"invalid_response",@"confirmed"));return;}[seen addObject:next];}}
   completion(snapshot,error);
  });[pool drain];
 });return task;
}
- (void)dealloc{[_session release];[_roots release];[_workspace release];[_permittedReads release];[_searchCursors release];[super dealloc];}
@end
