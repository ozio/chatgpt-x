#import "OR6ChatWebProvider.h"
#import "../api/OR6APIWire.h"
#import "../api/OR6APIOperations.h"
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>
#include <mach/mach_time.h>
#include <mach/mach.h>

@class OR6ChatWebTask;
@interface OR6ChatWebProvider(){
 id<OR6APIProvider> _next;UIView*_hostView;NSString*(^_contextKey)(void);BOOL(^_verifyOwner)(NSString*);
 UIWebView*_web;NSTimer*_timer;OR6APIDeltaDecoder*_decoder;OR6APIOperations*_records;
 NSDictionary*_parameters,*_context;NSString*_nonce,*_conversationID,*_userID,*_assistantID,*_persistedIdentity,*_phase,*_issue;
 OR6APIReply _reply;OR6APIEvent _event;OR6ChatWebTask*_task;id<OR6APITask>_readTask;
 NSDate*_started,*_progress;NSUInteger _generation,_sequence,_backendRequests,_activeBackendRequests,_sends,_readbacks;
 BOOL _installed,_approved,_clicked,_ended,_reconciling,_terminal,_streamingAnnounced;NSInteger _status,_loadError;
 NSDictionary*_pageState;NSMutableDictionary*_timings;
 NSTimer*_idleTimer;NSString*_pageContextKey,*_pageConversationID;
 BOOL _pageLoaded;NSUInteger _pageLoads,_pageReuses,_prepares,_evaluations;
 NSTimeInterval _pageBegan,_pageLoadMS,_operationBegan,_evaluationMS,_evaluationMaxMS;
}
- (void)cancelGeneration:(NSUInteger)generation;
@end
@interface OR6ChatWebTask:NSObject<OR6APITask>{@public OR6ChatWebProvider*owner;NSUInteger generation;}
@end
@implementation OR6ChatWebTask
- (void)cancel{[owner cancelGeneration:generation];}
@end
static BOOL UUID(id s){if(![s isKindOfClass:NSString.class]||[s length]!=36)return NO;NSRegularExpression*r=[NSRegularExpression regularExpressionWithPattern:@"^[a-fA-F0-9]{8}(-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}$"options:0 error:NULL];return[r numberOfMatchesInString:s options:0 range:NSMakeRange(0,[s length])]==1;}
static NSString*SHA(NSString*s){NSData*d=[s dataUsingEncoding:NSUTF8StringEncoding];unsigned char h[CC_SHA256_DIGEST_LENGTH];CC_SHA256(d.bytes,(CC_LONG)d.length,h);NSMutableString*out=[NSMutableString string];for(NSUInteger n=0;n<sizeof(h);n++)[out appendFormat:@"%02x",h[n]];return out;}
static NSString*Nonce(void){unsigned char bytes[16];if(SecRandomCopyBytes(kSecRandomDefault,sizeof(bytes),bytes))return nil;NSMutableString*s=[NSMutableString string];for(NSUInteger n=0;n<sizeof(bytes);n++)[s appendFormat:@"%02x",bytes[n]];return s;}
static NSTimeInterval Monotonic(void){static mach_timebase_info_data_t base;if(!base.denom)mach_timebase_info(&base);return(double)mach_absolute_time()*base.numer/base.denom/1e9;}
static BOOL SameTarget(NSString*key,NSString*other,NSString*cid,NSString*otherCID){return key.length&&[key isEqual:other]&&(cid==otherCID||[cid isEqual:otherCID]);}
static BOOL PageMatches(NSString*key,NSString*other,NSString*cid,NSString*href){
 if(!key.length||![key isEqual:other]||(cid&&!UUID(cid))||![href isKindOfClass:NSString.class])return NO;
 NSURL*u=[NSURL URLWithString:href];NSString*path=cid?[@"/c/"stringByAppendingString:cid]:@"/";
 return[u.scheme.lowercaseString isEqual:@"https"]&&[u.host.lowercaseString isEqual:@"chatgpt.com"]&&(!u.port||u.port.integerValue==443)&&!u.user&&!u.password&&!u.query&&!u.fragment&&[u.path isEqual:path];
}
static NSString*Literal(id value){NSData*d=[NSJSONSerialization dataWithJSONObject:@[value]options:0 error:NULL];return d?[[[NSString alloc]initWithData:d encoding:NSUTF8StringEncoding]autorelease]:nil;}
static NSData*Base64(id input){
 if(![input isKindOfClass:NSString.class]||![input length]||[input length]>21848||[input length]%4)return nil;
 NSData*encoded=[input dataUsingEncoding:NSASCIIStringEncoding];if(!encoded)return nil;const unsigned char*p=encoded.bytes;NSUInteger n=encoded.length;NSMutableData*out=[NSMutableData data];
 for(NSUInteger i=0;i<n;i+=4){unsigned value[4];for(NSUInteger k=0;k<4;k++){unsigned char c=p[i+k];if(c>='A'&&c<='Z')value[k]=c-'A';else if(c>='a'&&c<='z')value[k]=c-'a'+26;else if(c>='0'&&c<='9')value[k]=c-'0'+52;else if(c=='+')value[k]=62;else if(c=='/')value[k]=63;else if(c=='='&&i+4==n&&k>=2)value[k]=64;else return nil;}if(value[2]==64&&value[3]!=64)return nil;if((value[2]==64&&(value[1]&15))||(value[3]==64&&value[2]!=64&&(value[2]&3)))return nil;unsigned char b[3]={(unsigned char)((value[0]<<2)|(value[1]>>4)),(unsigned char)((value[1]<<4)|(value[2]>>2)),(unsigned char)((value[2]<<6)|value[3])};[out appendBytes:b length:value[2]==64?1:value[3]==64?2:3];}
 return out.length<=16384?out:nil;
}
static NSString*ReadbackAssistant(NSDictionary*conversation,NSDictionary*record){
 NSDictionary*m=record[@"metadata"];NSString*cid=m[@"conversationId"],*uid=m[@"userMessageId"],*aid=m[@"assistantMessageId"],*hash=record[@"request"][@"textSHA256"];
 if(!UUID(cid)||!UUID(uid)||(aid&&aid!=(id)NSNull.null&&!UUID(aid))||![conversation[@"id"]isEqual:cid]||![hash isKindOfClass:NSString.class]||hash.length!=64||![conversation[@"messages"]isKindOfClass:NSArray.class]||[conversation[@"messages"]count]>2048)return nil;
 BOOL userFound=NO;for(id value in conversation[@"messages"]){if(![value isKindOfClass:NSDictionary.class])return nil;NSDictionary*message=value;
  if([message[@"id"]isEqual:uid]&&[message[@"role"]isEqual:@"user"]&&[message[@"text"]isKindOfClass:NSString.class]&&[SHA(message[@"text"])isEqual:hash]){userFound=YES;continue;}
  if(!userFound)continue;if([message[@"role"]isEqual:@"user"])return nil;
  if([message[@"role"]isEqual:@"assistant"]&&[message[@"finished"]isEqual:@YES]&&UUID(message[@"id"])&&(!UUID(aid)||[message[@"id"]isEqual:aid]))return message[@"id"];
 }return nil;
}
@implementation OR6ChatWebProvider
- (id)initWithNext:(id<OR6APIProvider>)next hostView:(UIView*)view contextKey:(NSString*(^)(void))key verifyWebOwner:(BOOL(^)(NSString*))verify{
 if((self=[super init])){if(!next||!view||!key||!verify){[self release];return nil;}_next=[next retain];_hostView=view;_contextKey=[key copy];_verifyOwner=[verify copy];NSString*dir=[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES)[0]stringByAppendingPathComponent:@"ChatGPTXWebOps-v1"];_records=[[OR6APIOperations alloc]initWithDirectory:dir error:NULL];if(!_records){[self release];return nil;}[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(memoryWarning:)name:UIApplicationDidReceiveMemoryWarningNotification object:nil];}return self;
}
- (BOOL)current{return _reply&&!_terminal&&[_context[@"key"]isEqual:_contextKey()];}
- (NSString*)evaluate:(NSString*)body{
 if(!_web)return nil;NSString*script=[NSString stringWithFormat:@"(function(){if(window!==window.top||location.protocol!=='https:'||location.hostname!=='chatgpt.com'||(location.port&&location.port!=='443'))return '';var b=window.__OR6ChatBridge;if(!b)return '';return %@;})()",body];NSTimeInterval before=Monotonic();NSString*result=[_web stringByEvaluatingJavaScriptFromString:script];NSTimeInterval ms=(Monotonic()-before)*1000;_evaluationMS+=ms;_evaluationMaxMS=MAX(_evaluationMaxMS,ms);_evaluations++;return result;
}
- (NSDictionary*)receipt:(NSString*)state persisted:(BOOL)persisted{return @{ @"operationId":_parameters[@"operationId"],@"state":state,@"conversationId":_conversationID?:(id)NSNull.null,@"userMessageId":_userID?:(id)NSNull.null,@"assistantMessageId":_assistantID?:(id)NSNull.null,@"persisted":@(persisted)};}
- (void)emitState:(NSString*)state{if(_event&&[self current])_event(@{@"name":@"state",@"payload":[self receipt:state persisted:NO]});}
- (BOOL)persistUncertain{
 if(!_parameters)return NO;NSString*identity=[NSString stringWithFormat:@"%@|%@|%@",_conversationID?:@"",_userID?:@"",_assistantID?:@""];if([identity isEqual:_persistedIdentity])return YES;
 if(![_records finish:_parameters[@"operationId"]scope:_context[@"key"]state:@"uncertain"metadata:[self receipt:@"uncertain"persisted:NO]error:NULL])return NO;[_persistedIdentity release];_persistedIdentity=[identity copy];return YES;
}
- (void)mark:(NSString*)name{if(_timings&&!_timings[name])_timings[name]=@((Monotonic()-_operationBegan)*1000);}
- (void)stopPolling{[_timer invalidate];[_timer release];_timer=nil;}
- (void)releasePage{
 [self stopPolling];[_idleTimer invalidate];[_idleTimer release];_idleTimer=nil;
 if(_web){[self evaluate:@"b.detach()"];_web.delegate=nil;[_web stopLoading];[_web removeFromSuperview];[_web release];_web=nil;}
 [_pageContextKey release];_pageContextKey=nil;[_pageConversationID release];_pageConversationID=nil;_pageLoaded=NO;_pageBegan=0;_pageLoadMS=0;_installed=NO;
}
- (void)idleExpired:(NSTimer*)timer{(void)timer;if(!_reply)[self releasePage];}
- (void)scheduleIdle{[_idleTimer invalidate];[_idleTimer release];_idleTimer=[[NSTimer scheduledTimerWithTimeInterval:180 target:self selector:@selector(idleExpired:)userInfo:nil repeats:NO]retain];}
- (void)memoryWarning:(NSNotification*)note{(void)note;if(!_reply)[self releasePage];}
- (NSString*)pageURL{return _web?[_web stringByEvaluatingJavaScriptFromString:@"window===window.top?location.href:''"]:nil;}
- (BOOL)targetIsCurrent:(NSString*)identifier key:(NSString*)key{
 return _web&&SameTarget(key,_pageContextKey,identifier,_pageConversationID)&&(!_pageLoaded||PageMatches(key,_pageContextKey,identifier,[self pageURL]));
}
- (void)loadPage:(NSString*)identifier key:(NSString*)key{
 [self releasePage];_pageContextKey=[key copy];_pageConversationID=[identifier copy];_pageBegan=Monotonic();_pageLoads++;
 _web=[[UIWebView alloc]initWithFrame:_hostView.bounds];_web.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;_web.delegate=self;_web.userInteractionEnabled=NO;_web.accessibilityElementsHidden=YES;[_hostView insertSubview:_web atIndex:0];
 NSString*path=identifier?[@"/c/"stringByAppendingString:identifier]:@"/";
 [_web loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[@"https://chatgpt.com"stringByAppendingString:path]]cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:60]];
}
- (void)prepareConversation:(NSString*)identifier{
 if(!NSThread.isMainThread||_reply||(identifier&&!UUID(identifier)))return;NSString*key=_contextKey();if(!key.length)return;_prepares++;
 if(![self targetIsCurrent:identifier key:key])[self loadPage:identifier key:key];if(_web&&!_reply)[self scheduleIdle];
}
- (void)parkPage{
 [self stopPolling];if(!_web)return;if(_installed){if(![[self evaluate:@"b.park()"]isEqual:@"parked"]){[self releasePage];return;}_installed=NO;}
 // The ordinary website has its own successful response to finish rendering.
 // Keep only this document, with no observer, payload or credentials in native UI.
 [_pageConversationID release];_pageConversationID=[_conversationID copy];[self scheduleIdle];
}
- (void)installObserver{
 if(_installed||!_web||!_pageLoaded||![self current])return;
 NSString*source=[NSString stringWithContentsOfFile:[[NSBundle mainBundle]pathForResource:@"chat-web"ofType:@"js"]encoding:NSUTF8StringEncoding error:NULL];if(!source){[self finish:nil error:OR6APIError(@"unavailable",@"none")];return;}
 NSString*installed=[_web stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@((%@)[0])",source,Literal(_nonce)]];if(![installed isEqual:@"installed"]){[self finish:nil error:OR6APIError(@"capability_unavailable",@"none")];return;}_installed=YES;_timings[@"documentLoadMs"]=@(_pageLoadMS);[self mark:@"bridgeInstalledMs"];
 NSDictionary*config=@{@"text":_parameters[@"text"],@"conversationId":_conversationID?:(id)NSNull.null,@"parentMessageId":_parameters[@"parentMessageId"]};NSString*started=[self evaluate:[NSString stringWithFormat:@"b.begin((%@)[0])",Literal(config)]];if(![started isEqual:@"started"])[self finish:nil error:OR6APIError(@"invalid_response",@"none")];
}
- (void)finish:(NSDictionary*)result error:(NSError*)error{
 if(!_reply||_terminal)return;_terminal=YES;OR6APIReply reply=[[_reply copy]autorelease];[_reply release];_reply=nil;[_event release];_event=nil;
 [_phase release];_phase=[(error?@"failed":result[@"state"]?:@"uncertain")copy];[_issue release];_issue=[(error?OR6APIError(error.userInfo[@"code"],@"none").userInfo[@"code"]:@"")copy];
 if(error){if(_clicked)[self persistUncertain];else[_records finish:_parameters[@"operationId"]scope:_context[@"key"]state:@"rejected"metadata:@{}error:NULL];}
 _task->owner=nil;[_task release];_task=nil;[_readTask cancel];[_readTask release];_readTask=nil;if(!error&&[result[@"persisted"]boolValue])[self parkPage];else[self releasePage];[self mark:@"finishedMs"];[_decoder release];_decoder=nil;
 [_parameters release];_parameters=nil;[_context release];_context=nil;[_nonce release];_nonce=nil;[_started release];_started=nil;[_progress release];_progress=nil;[_conversationID release];_conversationID=nil;[_userID release];_userID=nil;[_assistantID release];_assistantID=nil;[_persistedIdentity release];_persistedIdentity=nil;
 reply(result,error);
}
- (void)cancelGeneration:(NSUInteger)generation{if(generation==_generation&&_reply)[self finish:nil error:OR6APIError(@"cancelled",_clicked?@"possible":@"none")];}
- (void)deactivate{if(_reply)[self finish:nil error:OR6APIError(@"cancelled",_clicked?@"possible":@"none")];else[self releasePage];}
- (BOOL)readbackMatches:(NSDictionary*)conversation record:(NSDictionary*)record{
 NSString*aid=ReadbackAssistant(conversation,record);if(!aid)return NO;if(!_assistantID)_assistantID=[aid copy];return YES;
}
- (void)readback:(NSDictionary*)record completion:(OR6APIReply)completion{
 NSString*cid=record[@"metadata"][@"conversationId"];if(!UUID(cid)){completion([self receipt:@"uncertain"persisted:NO],nil);return;}
 NSUInteger generation=_generation;_readbacks++;id<OR6APITask>task=[_next execute:@"history.get"parameters:@{@"conversationId":cid}context:_context event:nil completion:^(NSDictionary*conversation,NSError*error){
  if(generation!=_generation||!_reply||_terminal)return;
  if(![self current]){completion(nil,OR6APIError(@"stale_context",@"possible"));return;}
  if(error){completion(nil,OR6APIError(error.userInfo[@"code"],@"possible"));return;}
  if(![self readbackMatches:conversation record:record]){completion([self receipt:@"uncertain"persisted:NO],nil);return;}
  NSDictionary*saved=[self receipt:@"completed"persisted:YES];NSError*storage=nil;
  if(![_records finish:_parameters[@"operationId"]scope:_context[@"key"]state:@"completed"metadata:saved error:&storage]){completion(nil,OR6APIError(@"storage_failure",@"possible"));return;}completion(saved,nil);
 }];if(_reply&&!_terminal&&generation==_generation)_readTask=[task retain];
}
- (void)reconcileActive{
 if(_reconciling)return;_reconciling=YES;[_phase release];_phase=[@"reconciling"copy];if(![self persistUncertain]){[self finish:nil error:OR6APIError(@"storage_failure",@"possible")];return;}[self mark:@"streamCompleteMs"];[self parkPage];[self emitState:@"reconciling"];NSError*error=nil;NSDictionary*r=[_records record:_parameters[@"operationId"]scope:_context[@"key"]error:&error];if(error||!r){[self finish:nil error:OR6APIError(@"storage_failure",@"possible")];return;}
 [self readback:r completion:^(NSDictionary*result,NSError*failure){[self finish:result error:failure];}];
}
- (void)wireEvents:(NSArray*)events{
 for(NSDictionary*e in events){NSString*t=e[@"type"];if([t isEqual:@"identity"]){if(_conversationID&&![_conversationID isEqual:e[@"conversationId"]]){[self finish:nil error:OR6APIError(@"invalid_response",@"possible")];return;}if(!_conversationID)_conversationID=[e[@"conversationId"]copy];}
  else if([t isEqual:@"messageSnapshot"]&&[e[@"message"][@"role"]isEqual:@"assistant"]){NSDictionary*m=e[@"message"];[_assistantID release];_assistantID=[m[@"id"]copy];if(![self persistUncertain]){[self finish:nil error:OR6APIError(@"storage_failure",@"possible")];return;}if(_event)_event(@{@"name":@"message",@"payload":@{@"operationId":_parameters[@"operationId"],@"sequence":@(++_sequence),@"conversationId":e[@"conversationId"],@"messageId":m[@"id"],@"text":m[@"text"],@"finished":m[@"finished"]}});}
  else if([t isEqual:@"status"]&&_event)_event(@{@"name":@"status",@"payload":@{@"operationId":_parameters[@"operationId"],@"phase":@"writing",@"label":@"",@"sequence":@(++_sequence)}});
  if(![self current])return;
 }if(![self persistUncertain])[self finish:nil error:OR6APIError(@"storage_failure",@"possible")];
}
- (void)tick:(NSTimer*)timer{
 (void)timer;if(![self current]){if(_reply)[self finish:nil error:OR6APIError(@"stale_context",_clicked?@"possible":@"none")];return;}
 NSTimeInterval elapsed=-_started.timeIntervalSinceNow,idle=-_progress.timeIntervalSinceNow;
 if(elapsed>300||(!_clicked&&elapsed>150)||(_clicked&&idle>60)){[self finish:nil error:OR6APIError(@"timeout",_clicked?@"possible":@"none")];return;}
 if(!_installed){[self installObserver];return;}NSString*raw=[self evaluate:@"b.take()"];
 NSDictionary*s=raw.length&&raw.length<524288?OR6APIJSONSnapshot([NSJSONSerialization JSONObjectWithData:[raw dataUsingEncoding:NSUTF8StringEncoding]options:0 error:NULL],524288):nil;
 if(![s isKindOfClass:NSDictionary.class]||![s[@"nonce"]isEqual:_nonce]){[self finish:nil error:OR6APIError(@"invalid_response",_clicked?@"possible":@"none")];return;}
 _status=[s[@"status"]integerValue];NSUInteger observed=[s[@"backendRequests"]unsignedIntegerValue];if(observed<_activeBackendRequests||observed>10000){[self finish:nil error:OR6APIError(@"invalid_response",_clicked?@"possible":@"none")];return;}_backendRequests+=observed-_activeBackendRequests;_activeBackendRequests=observed;
 NSMutableDictionary*page=[NSMutableDictionary dictionary];for(NSString*k in @[@"navigationDOMMs",@"navigationLoadMs",@"resourceCount",@"resourceTransferBytes",@"bridgeAgeMs",@"composerCount",@"composerLength",@"typingMatches",@"sendCandidates",@"sendEnabled",@"globalSubmitCandidates",@"documentVisible",@"documentFocused",@"selectionInside"]){if([s[k]isKindOfClass:NSNumber.class])page[k]=s[k];}[_pageState release];_pageState=[page copy];
 if([s[@"userMessageId"]isKindOfClass:NSString.class]){if(!UUID(s[@"userMessageId"])||(_userID&&![_userID isEqual:s[@"userMessageId"]])){[self finish:nil error:OR6APIError(@"invalid_response",@"possible")];return;}if(!_userID){[self mark:@"requestObservedMs"];_userID=[s[@"userMessageId"]copy];[_progress release];_progress=[NSDate new];if(![self persistUncertain]){[self finish:nil error:OR6APIError(@"storage_failure",@"possible")];return;}}}
 NSArray*frames=s[@"frames"];if(![frames isKindOfClass:NSArray.class]||frames.count>4){[self finish:nil error:OR6APIError(@"invalid_response",_clicked?@"possible":@"none")];return;}
 for(id encoded in frames){NSData*bytes=Base64(encoded);NSError*parse=nil;NSArray*events=bytes?[_decoder feed:bytes final:NO error:&parse]:nil;if(!events){[self finish:nil error:OR6APIError(@"unknown_wire_shape",@"possible")];return;}[_progress release];_progress=[NSDate new];[self wireEvents:events];if(![self current])return;}
 if([s[@"issue"]isKindOfClass:NSString.class]&&[s[@"issue"]length]){[self finish:nil error:OR6APIError(s[@"issue"],_clicked?@"possible":@"none")];return;}
 NSString*phase=s[@"phase"];if([phase isEqual:@"owner_ready"])[self mark:@"ownerReadyMs"];if([phase isEqual:@"streaming"])[self mark:@"responseMs"];
 if([@[@"idle",@"authorizing",@"owner_ready",@"typing",@"dispatching",@"streaming",@"failed"]containsObject:phase?:@""]){[_phase release];_phase=[phase copy];}
 if([phase isEqual:@"owner_ready"]&&!_approved){if(!_verifyOwner(s[@"owner"])){[self finish:nil error:OR6APIError(@"owner_mismatch",@"none")];return;}if([s[@"composerConflict"]boolValue]){[self finish:nil error:OR6APIError(@"conflict",@"none")];return;}if([s[@"composerReady"]boolValue]){NSString*result=[self evaluate:@"b.approve()"];if(![result isEqual:@"typed"]){[self finish:nil error:OR6APIError(@"invalid_response",@"none")];return;}_approved=YES;[self mark:@"typedMs"];}}
 else if([phase isEqual:@"typing"]&&[s[@"ready"]boolValue]&&!_clicked){_clicked=YES;if(![self persistUncertain]){_clicked=NO;[self finish:nil error:OR6APIError(@"storage_failure",@"none")];return;}[self mark:@"sendClickedMs"];_sends++;[self emitState:@"dispatching"];if(![self current])return;NSString*result=[self evaluate:@"b.click()"];if(![result isEqual:@"clicked"]){[self finish:nil error:OR6APIError(@"uncertain_outcome",@"possible")];return;}[_progress release];_progress=[NSDate new];}
 if([phase isEqual:@"streaming"]&&frames.count&&!_streamingAnnounced){_streamingAnnounced=YES;[self emitState:@"streaming"];}
 if([s[@"streamEnded"]boolValue]&&!_ended){_ended=YES;NSError*parse=nil;NSArray*events=[_decoder feed:[NSData data]final:YES error:&parse];if(!events||!_decoder.done||!_decoder.complete||!_userID||!_assistantID||!_conversationID){[self finish:nil error:OR6APIError(@"uncertain_outcome",@"possible")];return;}[self wireEvents:events];if([self current])[self reconcileActive];}
}
- (id<OR6APITask>)execute:(NSString*)op parameters:(NSDictionary*)p context:(NSDictionary*)ctx event:(OR6APIEvent)event completion:(OR6APIReply)reply{
 if(!NSThread.isMainThread){reply(nil,OR6APIError(@"invalid_request",@"none"));return nil;}
 if(![op isEqual:@"messages.send"]&&![op isEqual:@"messages.reconcile"])return[_next execute:op parameters:p context:ctx event:event completion:reply];
 OR6ChatWebTask*task=[[[OR6ChatWebTask alloc]init]autorelease];if(_reply){reply(nil,OR6APIError(@"conflict",@"none"));return task;}
 NSString*key=_contextKey();if(!key||![ctx[@"key"]isEqual:key]){reply(nil,OR6APIError(@"not_authenticated",@"none"));return task;}
 BOOL send=[op isEqual:@"messages.send"];if(send&&(![p[@"modelId"]isEqual:@"web-current"]||[p[@"temporary"]boolValue]||[p[@"attachments"]count]||![p[@"text"]length]||[p[@"text"]length]>16000||!UUID(p[@"parentMessageId"])||(p[@"conversationId"]&&!UUID(p[@"conversationId"])))){reply(nil,OR6APIError(@"capability_unavailable",@"none"));return task;}
 NSError*storage=nil;NSDictionary*record=nil;
 if(send){if(![_records reserve:p[@"operationId"]command:@"web.send"request:@{@"textSHA256":SHA(p[@"text"])}scope:key error:&storage]){reply(nil,storage);return task;}}
 else {record=[_records record:p[@"operationId"]scope:key error:&storage];if(storage||!record){reply(nil,storage?:OR6APIError(@"not_found",@"none"));return task;}if([record[@"state"]isEqual:@"completed"]){reply(record[@"result"],nil);return task;}if([record[@"state"]isEqual:@"rejected"]){reply(@{@"operationId":p[@"operationId"],@"state":@"rejected",@"conversationId":NSNull.null,@"userMessageId":NSNull.null,@"assistantMessageId":NSNull.null,@"persisted":@NO},nil);return task;}}
 _generation++;task->generation=_generation;task->owner=self;_task=[task retain];_reply=[reply copy];_event=[event copy];_parameters=[p copy];_context=[ctx copy];_terminal=NO;_clicked=!send;_installed=_approved=_ended=_reconciling=_streamingAnnounced=NO;_sequence=0;_activeBackendRequests=0;_status=0;_loadError=0;[_pageState release];_pageState=nil;[_phase release];_phase=[(send?@"loading":@"reconciling")copy];[_issue release];_issue=nil;
 if(!send){NSDictionary*m=record[@"metadata"];if(UUID(m[@"conversationId"]))_conversationID=[m[@"conversationId"]copy];if(UUID(m[@"userMessageId"]))_userID=[m[@"userMessageId"]copy];if(UUID(m[@"assistantMessageId"]))_assistantID=[m[@"assistantMessageId"]copy];[self readback:record completion:^(NSDictionary*r,NSError*e){[self finish:r error:e];}];return task;}
 if(p[@"conversationId"])_conversationID=[p[@"conversationId"]copy];_nonce=[Nonce()copy];if(!_nonce){[self finish:nil error:OR6APIError(@"unavailable",@"none")];return task;}
 _started=[NSDate new];_progress=[NSDate new];_operationBegan=Monotonic();_decoder=[OR6APIDeltaDecoder new];[_timings release];_timings=[NSMutableDictionary new];_evaluations=0;_evaluationMS=_evaluationMaxMS=0;
 BOOL reused=[self targetIsCurrent:_conversationID key:key];_timings[@"preparedBeforeSend"]=@(reused);_timings[@"documentLoadedAtSend"]=@(reused&&_pageLoaded);
 if(reused){_pageReuses++;_timings[@"pageAgeAtSendMs"]=@((Monotonic()-_pageBegan)*1000);[_idleTimer invalidate];[_idleTimer release];_idleTimer=nil;}else[self loadPage:_conversationID key:key];
 if(_reply){_timer=[[NSTimer scheduledTimerWithTimeInterval:.15 target:self selector:@selector(tick:)userInfo:nil repeats:YES]retain];[self installObserver];}return task;
}
- (BOOL)webView:(UIWebView*)web shouldStartLoadWithRequest:(NSURLRequest*)request navigationType:(UIWebViewNavigationType)type{
 (void)web;(void)type;NSURL*u=request.URL;BOOL main=!request.mainDocumentURL||[u isEqual:request.mainDocumentURL];if(!main)return[u.scheme.lowercaseString isEqual:@"https"]||[u.scheme isEqual:@"about"]||[u.scheme isEqual:@"data"]||[u.scheme isEqual:@"blob"];
 BOOL origin=[u.scheme.lowercaseString isEqual:@"https"]&&[u.host.lowercaseString isEqual:@"chatgpt.com"]&&(!u.port||u.port.integerValue==443)&&!u.user&&!u.password&&!u.fragment;
 BOOL route=[u.path isEqual:@"/"]||([u.path hasPrefix:@"/c/"]&&UUID([u.path substringFromIndex:3]));
 if(!origin||!route){if(_reply)[self finish:nil error:OR6APIError(@"not_authenticated",_clicked?@"possible":@"none")];else[self releasePage];return NO;}return YES;
}
- (void)webViewDidFinishLoad:(UIWebView*)web{
 if(web!=_web||web.loading)return;_pageLoaded=YES;_pageLoadMS=(Monotonic()-_pageBegan)*1000;if(_reply){[self mark:@"pageLoadedMs"];[self installObserver];}
}
- (void)webView:(UIWebView*)web didFailLoadWithError:(NSError*)error{if(web==_web&&error.code!=NSURLErrorCancelled){_loadError=error.code;if(_reply)[self finish:nil error:OR6APIError(@"network_unavailable",_clicked?@"possible":@"none")];else[self releasePage];}}
- (NSDictionary*)diagnostics{mach_task_basic_info_data_t memory;mach_msg_type_number_t count=MACH_TASK_BASIC_INFO_COUNT;kern_return_t k=task_info(mach_task_self(),MACH_TASK_BASIC_INFO,(task_info_t)&memory,&count);return @{@"rssBytes":k==KERN_SUCCESS?@(memory.resident_size):(id)NSNull.null,@"pageLoads":@(_pageLoads),@"pageReuses":@(_pageReuses),@"prepares":@(_prepares),@"pageLoaded":@(_pageLoaded),@"pageLoadMs":@(_pageLoadMS),@"timings":_timings?:@{},@"jsEvaluations":@(_evaluations),@"jsEvaluationMs":@(_evaluationMS),@"jsEvaluationMaxMs":@(_evaluationMaxMS),@"active":@(_reply!=nil),@"webViewPresent":@(_web!=nil),@"phase":_phase?:@"idle",@"issue":_issue?:@"",@"sendsAttempted":@(_sends),@"readbacks":@(_readbacks),@"backendRequestsObserved":@(_backendRequests),@"status":@(_status),@"loadErrorCode":@(_loadError),@"page":_pageState?:@{},@"requiresMacBridge":@NO,@"credentialsExposed":@NO};}
- (void)dealloc{[NSNotificationCenter.defaultCenter removeObserver:self];[self deactivate];[_timings release];[_next release];[_contextKey release];[_verifyOwner release];[_records release];[_phase release];[_issue release];[_pageState release];[super dealloc];}
@end
