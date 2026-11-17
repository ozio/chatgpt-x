#import "OR6CodexSession.h"
#import "OR6CodexPolicy8.h"
#import <mach/mach_time.h>
#import <dispatch/dispatch.h>
static double Clock(void){mach_timebase_info_data_t t;mach_timebase_info(&t);return(double)mach_absolute_time()*t.numer/t.denom/1e9;}
static NSString*WireKey(id v){if(OR6CodexID(v))return[@"s:"stringByAppendingString:v];if(OR6APISchemaCheck(v,@{@"type":@"integer",@"minimum":@(-9007199254740991LL),@"maximum":@9007199254740991LL},@{}))return[@"n:"stringByAppendingString:[v description]];return nil;}
static BOOL Mutates(NSString*m){return![@[@"initialize",@"thread/goal/get",@"configRequirements/read",@"model/list",@"collaborationMode/list",@"mcpServerStatus/list",@"mcpServer/resource/read",@"account/read",@"thread/list",@"thread/read",@"thread/turns/list",@"thread/items/list",@"thread/backgroundTerminals/list",@"fs/readDirectory",@"fs/getMetadata"]containsObject:m];}
@class OR6CodexCall;
@interface OR6CodexSession()
- (void)finish:(OR6CodexCall*)call result:(NSDictionary*)result error:(NSError*)error;
- (void)receive:(NSDictionary*)message epoch:(NSUInteger)epoch;
- (void)lost:(NSError*)error;
- (id<OR6APITask>)send:(NSString*)method params:(NSDictionary*)params operationID:(NSString*)identifier completion:(OR6APIReply)reply;
@end
@interface OR6CodexCall:NSObject<OR6APITask>{@public OR6CodexSession*owner;NSString*wire,*method,*operation;NSDictionary*params;OR6APIReply reply;BOOL done,mutating;NSUInteger transcriptRevision;NSTimer*timer;}
@end
@implementation OR6CodexCall
- (void)expire:(NSTimer*)unused{(void)unused;if(owner&&!done)[owner finish:self result:nil error:OR6CodexError(@"timeout",mutating)];}
- (void)cancel{if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self cancel];});return;}if(owner&&!done)[owner finish:self result:nil error:OR6CodexError(@"cancelled",mutating)];}
- (void)dealloc{[owner release];[wire release];[method release];[operation release];[params release];[reply release];[timer invalidate];[timer release];[super dealloc];}
@end
@implementation OR6CodexSession
+ (Class)protocolClass{return OR6CodexProtocol.class;}
- (BOOL)contextIsCurrent{return YES;}
- (void)verifyAdmission:(OR6APIReply)completion{
 [self send:@"account/read"params:@{@"refreshToken":@NO}operationID:nil completion:^(NSDictionary*account,NSError*admission){
  BOOL match=[account[@"account"]isKindOfClass:NSDictionary.class]&&[account[@"workspaceRouting"]isKindOfClass:NSDictionary.class]&&[account[@"account"][@"type"]isEqual:@"chatgpt"]&&OR6CodexText(account[@"account"][@"email"],256,NO)&&[[account[@"account"][@"email"]lowercaseString]isEqual:[_context[@"owner"]lowercaseString]]&&[account[@"workspaceRouting"][@"chatgptAccountId"]isEqual:_context[@"workspace"]];
  completion(match?account:nil,admission?:match?nil:OR6CodexError(@"owner_mismatch",NO));
 }];
}
- (id)initWithTransport:(id<OR6CodexTransport>)transport contracts:(NSDictionary*)contracts context:(NSDictionary*)ctx directory:(NSString*)directory error:(NSError**)error{
 if((self=[super init])){_protocol=[[[[self class]protocolClass]alloc]initWithContracts:contracts error:error];_store=[[OR6CodexStore alloc]initWithDirectory:directory context:ctx error:error];if(!_protocol||!_store||!transport){[self release];return nil;}_transport=[transport retain];_context=[OR6APIJSONSnapshot(ctx,8192)retain];_transcript=[OR6CodexTranscript new];_pending=[NSMutableDictionary new];_server=[NSMutableDictionary new];_seen=[NSMutableSet new];_models=[NSMutableDictionary new];_settings=[NSMutableDictionary new];_modes=[NSMutableSet new];_mcpServers=[NSMutableDictionary new];_state=[@"disconnected"copy];}return self;
}
- (void)state:(NSString*)s{[_state release];_state=[s copy];}
- (void)setEventHandler:(OR6APIEvent)e{if(!NSThread.isMainThread)return;[_event release];_event=[e copy];}
- (void)emit:(NSDictionary*)e{OR6APIEvent cb=[[_event copy]autorelease];if(cb)cb(e);}
- (void)connect:(OR6APIReply)cb{
 if(!NSThread.isMainThread||_deactivated||_closing||![_state isEqual:@"disconnected"]){if(cb)cb(nil,OR6CodexError(@"conflict",NO));return;}[self state:@"connecting"];NSUInteger epoch=++_epoch;[_seen removeAllObjects];[_server removeAllObjects];[_transcript invalidate];
 [_transport open:^(NSDictionary*m){if(epoch==_epoch)[self receive:m epoch:epoch];}closed:^(NSError*e){if(epoch==_epoch)[self lost:e?:OR6CodexError(@"network_unavailable",YES)];}ready:^(NSError*e){if(epoch!=_epoch){if(cb)cb(nil,OR6CodexError(@"stale_context",NO));return;}if(e){[self lost:e];if(cb)cb(nil,e);return;}[self send:@"initialize"params:@{@"clientInfo":@{@"name":@"legacy_ios6",@"title":@"iOS 6 client",@"version":@"1"},@"capabilities":@{@"experimentalApi":@YES,@"requestAttestation":@NO}}operationID:nil completion:^(NSDictionary*r,NSError*problem){if(problem){[self lost:problem];if(cb)cb(nil,problem);return;}NSError*failure=nil;if(![_transport send:@{@"method":@"initialized"}error:&failure]){[self lost:failure];if(cb)cb(nil,OR6CodexError(@"network_unavailable",YES));return;}[self state:@"verifying"];
 [self verifyAdmission:^(NSDictionary*account,NSError*admission){
  (void)account;if(admission||![self contextIsCurrent]){NSError*denied=admission?:OR6CodexError(@"stale_context",NO);[self lost:denied];if(cb)cb(nil,denied);return;}
  [self state:@"ready"];if(cb)cb(r,nil);
 }];}];}];
}
- (void)finish:(OR6CodexCall*)c result:(NSDictionary*)r error:(NSError*)e{
 if(c->done)return;[self retain];[c retain];c->done=YES;[c->timer invalidate];[c->timer release];c->timer=nil;
 if(c->operation){NSMutableDictionary*v=[[[_store record:c->operation]mutableCopy]autorelease];v[@"state"]=e?([e.userInfo[@"dispatch"]isEqual:@"none"]?@"rejected":@"uncertain"):@"confirmed";if([r[@"thread"]isKindOfClass:NSDictionary.class]&&OR6CodexID(r[@"thread"][@"id"]))v[@"threadId"]=r[@"thread"][@"id"];if([r[@"turn"]isKindOfClass:NSDictionary.class]&&OR6CodexID(r[@"turn"][@"id"]))v[@"turnId"]=r[@"turn"][@"id"];NSError*storage=nil;if(![_store record:c->operation value:v error:&storage]){e=OR6CodexError(@"storage_failure",YES);r=nil;}}
 OR6APIReply cb=[[c->reply copy]autorelease];[c->reply release];c->reply=nil;[_pending removeObjectForKey:c->wire];[_seen addObject:c->wire];[c->owner release];c->owner=nil;if(cb)cb(e?nil:r,e);[c release];[self release];
}
- (id<OR6APITask>)send:(NSString*)m params:(NSDictionary*)p operationID:(NSString*)identifier completion:(OR6APIReply)cb{
 BOOL mutating=Mutates(m);p=OR6APIJSONSnapshot(p,[@[@"turn/start",@"turn/steer"]containsObject:m]?262144:24576);if(!cb)return nil;
 if(!p||![_protocol validate:[m isEqual:@"configRequirements/read"]?(id)NSNull.null:p group:@"client"method:m direction:@"params"]||_pending.count>=16||_seen.count>=256||(mutating&&!OR6CodexID(identifier))){cb(nil,OR6CodexError(@"invalid_request",NO));return nil;}
 if(mutating&&[_store record:identifier]){cb(nil,OR6CodexError(@"duplicate_operation",NO));return nil;}
 if(mutating){NSMutableDictionary*v=[NSMutableDictionary dictionaryWithDictionary:@{@"method":m,@"state":@"possible"}];for(NSString*k in @[@"threadId",@"expectedTurnId",@"clientUserMessageId",@"path"])if(p[k])v[k]=p[k];NSError*e=nil;if(![_store record:identifier value:v error:&e]){cb(nil,e);return nil;}}
 OR6CodexCall*c=[[[OR6CodexCall alloc]init]autorelease];c->owner=[self retain];c->wire=[[NSString stringWithFormat:@"rc-%lu-%lu",(unsigned long)_epoch,(unsigned long)++_counter]copy];c->method=[m copy];c->params=[p retain];c->operation=mutating?[identifier copy]:nil;c->mutating=mutating;c->reply=[cb copy];c->transcriptRevision=[_transcript revision];_pending[c->wire]=c;
 c->timer=[[NSTimer scheduledTimerWithTimeInterval:60 target:c selector:@selector(expire:)userInfo:nil repeats:NO]retain];NSError*e=nil;NSMutableDictionary*message=[NSMutableDictionary dictionaryWithDictionary:@{@"id":c->wire,@"method":m,@"params":p}];if([m isEqual:@"configRequirements/read"])[message removeObjectForKey:@"params"];if(![_transport send:message error:&e]){[self finish:c result:nil error:OR6CodexError(@"network_unavailable",mutating)];return c;}
 return c;
}
- (id<OR6APITask>)request:(NSString*)m parameters:(NSDictionary*)p operationID:(NSString*)i completion:(OR6APIReply)cb{
 if(NSThread.isMainThread&&![self contextIsCurrent]){[self lost:OR6CodexError(@"stale_context",YES)];if(cb)cb(nil,OR6CodexError(@"stale_context",NO));return nil;}
 if(!NSThread.isMainThread||_deactivated||_closing||![_state isEqual:@"ready"]||[m isEqual:@"initialize"]){if(cb)cb(nil,OR6CodexError(@"unavailable",NO));return nil;}return[self send:m params:p operationID:i completion:cb];
}
- (void)receive:(NSDictionary*)raw epoch:(NSUInteger)epoch{
 if(epoch!=_epoch||_closing)return;if(![self contextIsCurrent]){[self lost:OR6CodexError(@"stale_context",YES)];return;}NSDictionary*m=OR6APIJSONSnapshot(raw,1024*1024);if(![m isKindOfClass:NSDictionary.class]){[self lost:OR6CodexError(@"unknown_wire_shape",YES)];return;}
 NSString*method=m[@"method"];id wire=m[@"id"];
 if(!method){OR6CodexCall*c=[wire isKindOfClass:NSString.class]?_pending[wire]:nil;if(!c){if([_seen containsObject:wire?:@""])return;[self lost:OR6CodexError(@"unknown_wire_shape",YES)];return;}if(!OR6CodexKeys(m,@[@"id"],@[@"result",@"error"])||((m[@"result"]!=nil)==(m[@"error"]!=nil))){[self lost:OR6CodexError(@"unknown_wire_shape",YES)];return;}if(m[@"error"]){if(!OR6CodexKeys(m[@"error"],@[@"code",@"message"],@[@"data"])||!OR6APISchemaCheck(m[@"error"][@"code"],@{@"type":@"integer"},@{})||!OR6CodexText(m[@"error"][@"message"],4096,YES)){[self lost:OR6CodexError(@"unknown_wire_shape",YES)];return;}NSString*code=[m[@"error"][@"code"]isEqual:@(-32001)]?@"rate_limited":@"upstream_error";[self finish:c result:nil error:OR6CodexError(code,YES)];if([code isEqual:@"rate_limited"])[self lost:OR6CodexError(code,YES)];return;}
 if(![_protocol validate:m[@"result"]group:@"client"method:c->method direction:@"result"]){[self finish:c result:nil error:OR6CodexError(@"schema_mismatch",c->mutating)];return;}
 NSDictionary*r=m[@"result"];if([c->method isEqual:@"review/start"]&&![r[@"reviewThreadId"]isEqual:c->params[@"threadId"]]){[self finish:c result:nil error:OR6CodexError(@"schema_mismatch",YES)];return;}if(([r[@"thread"]isKindOfClass:NSDictionary.class]&&!OR6CodexID(r[@"thread"][@"id"]))||([r[@"turn"]isKindOfClass:NSDictionary.class]&&!OR6CodexID(r[@"turn"][@"id"]))){[self finish:c result:nil error:OR6CodexError(@"schema_mismatch",c->mutating)];return;}if([r[@"data"]isKindOfClass:NSArray.class]&&c->params[@"limit"]&&[r[@"data"]count]>[c->params[@"limit"]unsignedIntegerValue]){[self finish:c result:nil error:OR6CodexError(@"size_limit",c->mutating)];return;}if(c->params[@"threadId"]&&r[@"thread"]&&![c->params[@"threadId"]isEqual:r[@"thread"][@"id"]]){[self lost:OR6CodexError(@"schema_mismatch",YES)];return;}if([c->method isEqual:@"model/list"]){for(NSDictionary*model in r[@"data"]){if(!OR6CodexID(model[@"model"])||(_models.count>=256&&!_models[model[@"model"]])){[self finish:c result:nil error:OR6CodexError(@"size_limit",NO)];return;}_models[model[@"model"]]=model;}}
 if([c->method isEqual:@"collaborationMode/list"]){[_modes removeAllObjects];for(NSDictionary*mode in r[@"data"])if([mode[@"mode"]isKindOfClass:NSString.class])[_modes addObject:mode[@"mode"]];}
 if([c->method isEqual:@"mcpServerStatus/list"]){NSString*thread=c->params[@"threadId"]?:@"*";if(!_mcpServers[thread]){if(_mcpServers.count>=64)[_mcpServers removeObjectForKey:_mcpServers.allKeys[0]];_mcpServers[thread]=[NSMutableSet set];}NSMutableSet*names=_mcpServers[thread];for(NSDictionary*server in r[@"data"]){if(!OR6CodexID(server[@"name"])||(names.count>=128&&![names containsObject:server[@"name"]])){[self finish:c result:nil error:OR6CodexError(@"size_limit",NO)];return;}[names addObject:server[@"name"]];}}

 BOOL okay=YES;if([c->method isEqual:@"thread/items/list"])okay=[_transcript mergeItems:r[@"data"]thread:c->params[@"threadId"]beforeRevision:c->transcriptRevision];if([c->method isEqual:@"thread/turns/list"])okay=[_transcript mergeTurns:r[@"data"]thread:c->params[@"threadId"]beforeRevision:c->transcriptRevision];[self finish:c result:okay?r:nil error:okay?nil:OR6CodexError(@"size_limit",NO)];return;}
 if(!OR6CodexText(method,128,NO)||!OR6CodexKeys(m,@[@"method",@"params"],wire?@[@"id"]:@[])){[self lost:OR6CodexError(@"unknown_wire_shape",YES)];return;}
 NSDictionary*p=m[@"params"];if(![p isKindOfClass:NSDictionary.class]){[self lost:OR6CodexError(@"unknown_wire_shape",YES)];return;}
 if([method hasPrefix:@"account/"]){[self lost:OR6CodexError(@"stale_context",YES)];return;}
 if(wire){NSString*k=WireKey(wire);if(!k){[self lost:OR6CodexError(@"unknown_wire_shape",YES)];return;}if([method isEqual:@"attestation/generate"]||[method hasPrefix:@"account/"]){[self lost:OR6CodexError(@"service_challenge",YES)];return;}
 if(![_protocol validate:p group:@"server"method:method direction:@"params"]){if([_protocol supports:@"server"method:method]){[self lost:OR6CodexError(@"schema_mismatch",YES)];return;}NSError*e=nil;[_transport send:@{@"id":wire,@"error":@{@"code":@(-32601),@"message":@"Unsupported client request"}}error:&e];return;}
 if([_seen containsObject:[@"server:"stringByAppendingString:k]])return;
 if(_server[k]){if(![_server[k][@"method"]isEqual:method]||![_server[k][@"params"]isEqual:p])[self lost:OR6CodexError(@"unknown_wire_shape",YES)];return;}
 if(_server.count>=32){[self lost:OR6CodexError(@"size_limit",YES)];return;}if([method isEqual:@"item/tool/requestUserInput"]){NSArray*q=p[@"questions"];NSMutableSet*ids=[NSMutableSet set];if(!q.count||q.count>8){[self lost:OR6CodexError(@"size_limit",YES)];return;}for(NSDictionary*x in q){if(!OR6CodexID(x[@"id"])||[ids containsObject:x[@"id"]]||!OR6CodexText(x[@"question"],4096,NO)){[self lost:OR6CodexError(@"schema_mismatch",YES)];return;}[ids addObject:x[@"id"]];}}
 NSString*token=NSProcessInfo.processInfo.globallyUniqueString;_server[k]=@{@"id":wire,@"method":method,@"params":p,@"token":token,@"deadline":@(Clock()+900),@"state":@"pending"};[self emit:@{@"kind":@"serverRequest",@"request":_server[k]}];return;}
 if(![_protocol validate:p group:@"notifications"method:method direction:nil]){if([_protocol supports:@"notifications"method:method])[self lost:OR6CodexError(@"schema_mismatch",YES)];return;}
 if([method isEqual:@"warning"]){[self lost:OR6CodexError(@"service_challenge",YES)];return;}
 if([method isEqual:@"error"]){[self lost:OR6CodexError(@"upstream_error",YES)];return;}
 if([method isEqual:@"serverRequest/resolved"]){NSString*k=WireKey(p[@"requestId"]);NSDictionary*r=k?_server[k]:nil;if(r&&[r[@"params"][@"threadId"]isEqual:p[@"threadId"]]){if(r[@"operationID"]){NSMutableDictionary*v=[[[_store record:r[@"operationID"]]mutableCopy]autorelease];v[@"state"]=@"confirmed";if(![_store record:r[@"operationID"]value:v error:NULL]){[self lost:OR6CodexError(@"storage_failure",YES)];return;}}[_seen addObject:[@"server:"stringByAppendingString:k]];[_server removeObjectForKey:k];}}
 if([method isEqual:@"turn/completed"]||[method isEqual:@"thread/closed"]||[method isEqual:@"thread/deleted"]){for(NSString*k in [[_server.allKeys copy]autorelease]){NSDictionary*r=_server[k];if([r[@"params"][@"threadId"]isEqual:p[@"threadId"]]&&(!p[@"turn"]||[r[@"params"][@"turnId"]isEqual:p[@"turn"][@"id"]])){[_seen addObject:[@"server:"stringByAppendingString:k]];[_server removeObjectForKey:k];}}}
 if([method isEqual:@"thread/settings/updated"]){if(_settings.count>=64&&!_settings[p[@"threadId"]])[_settings removeObjectForKey:_settings.allKeys[0]];_settings[p[@"threadId"]]=p[@"threadSettings"];}
 if(![_transcript consume:method parameters:p]){[self lost:OR6CodexError(@"size_limit",YES)];return;}[self emit:@{@"kind":@"notification",@"method":method,@"params":p}];
}
- (BOOL)answer:(NSString*)token response:(NSDictionary*)response operationID:(NSString*)identifier error:(NSError**)error{
 if(!NSThread.isMainThread||![_state isEqual:@"ready"]||!OR6CodexID(token)||!OR6CodexID(identifier))goto invalid;
 {NSString*key=nil;NSDictionary*r=nil;for(NSString*k in _server)if([_server[k][@"token"]isEqual:token]){key=k;r=_server[k];break;}
 if(!r||![r[@"state"]isEqual:@"pending"]||Clock()>[r[@"deadline"]doubleValue]){if(error)*error=OR6CodexError(@"expired",NO);return NO;}
 response=OR6APIJSONSnapshot(response,24576);if(!response||![_protocol validate:response group:@"server"method:r[@"method"]direction:@"result"])goto invalid;
 if([r[@"method"]isEqual:@"item/tool/requestUserInput"]){NSDictionary*answers=response[@"answers"];NSArray*questions=r[@"params"][@"questions"];if(answers.count!=questions.count)goto invalid;for(NSDictionary*q in questions){id a=answers[q[@"id"]][@"answers"];if(![a isKindOfClass:NSArray.class]||![a count]||[a count]>16)goto invalid;for(id text in a)if(!OR6CodexText(text,4096,NO))goto invalid;}}
 else if([r[@"method"]isEqual:@"mcpServer/elicitation/request"]){if(!OR6CodexElicitationResponse(r[@"params"],response))goto invalid;}
 else if([r[@"method"]isEqual:@"item/permissions/requestApproval"]){if(!OR6CodexPermissionSubset(r[@"params"][@"permissions"],response))goto invalid;}
 else {id decision=response[@"decision"];NSArray*allowed=r[@"params"][@"availableDecisions"];if(allowed&&allowed!=(id)NSNull.null){if(![allowed containsObject:decision])goto invalid;}else if(![@[@"accept",@"acceptForSession",@"decline",@"cancel"]containsObject:decision])goto invalid;}
 if([_store record:identifier]){if(error)*error=OR6CodexError(@"duplicate_operation",NO);return NO;}
 NSDictionary*v=@{@"method":r[@"method"],@"state":@"possible",@"threadId":r[@"params"][@"threadId"],@"turnId":r[@"params"][@"turnId"]?:NSNull.null};if(![_store record:identifier value:v error:error])return NO;
 NSMutableDictionary*next=[[r mutableCopy]autorelease];next[@"state"]=@"responseSent";next[@"operationID"]=identifier;_server[key]=next;
 if(![_transport send:@{@"id":r[@"id"],@"result":response}error:error]){[self lost:OR6CodexError(@"uncertain_outcome",YES)];return NO;}return YES;}
invalid:if(error)*error=OR6CodexError(@"invalid_request",NO);return NO;
}
- (void)lost:(NSError*)e{if(_closing)return;[self retain];_closing=YES;_epoch++;[self state:@"disconnected"];[_transport close];[_transcript invalidate];[_models removeAllObjects];[_modes removeAllObjects];[_settings removeAllObjects];[_mcpServers removeAllObjects];[_server removeAllObjects];NSArray*calls=[[_pending.allValues copy]autorelease];for(OR6CodexCall*c in calls)[self finish:c result:nil error:OR6CodexError(e.userInfo[@"code"]?:@"network_unavailable",c->mutating)];[self emit:@{@"kind":@"disconnected",@"code":e.userInfo[@"code"]?:@"network_unavailable"}];_closing=NO;[self release];}
- (void)disconnect{if(NSThread.isMainThread)[self lost:OR6CodexError(@"cancelled",YES)];}
- (void)deactivate{_deactivated=YES;[self disconnect];[_store close];[self setEventHandler:nil];[_transcript reset];}
- (BOOL)matchesContext:(NSDictionary*)c{return[_context isEqual:c];}
- (NSDictionary*)status{return@{@"state":_state,@"epoch":@(_epoch),@"features7":[_protocol features7],@"protocolVersion":@"0.163.0",@"pendingRequests":@(_pending.count),@"serverRequests":_server.allValues,@"secureSetup":@{@"route":@"app-server",@"mobileEnrollmentRequired":@NO,@"mobileEnrollmentSupported":@NO,@"hardwareSecureEnclave":@NO,@"osProtectedNonextractableVerified":@NO},@"features":[_protocol features],@"features8":[_protocol features8]};}
- (NSDictionary*)model:(NSString*)m{return OR6APIJSONSnapshot(_models[m],65536);}
- (BOOL)hasMode:(NSString*)m{return[_modes containsObject:m];}
- (BOOL)hasMCPServer:(NSString*)s thread:(NSString*)t{return[_mcpServers[t?:@"*"]containsObject:s];}
- (NSDictionary*)settings:(NSString*)t{return OR6APIJSONSnapshot(_settings[t],16384);}
- (NSDictionary*)journal{return[_store records];}
- (NSDictionary*)transcript:(NSString*)t{return[_transcript snapshot:t];}
- (void)dealloc{[_transport release];[_protocol release];[_store release];[_transcript release];[_context release];[_pending release];[_server release];[_seen release];[_event release];[_state release];[_models release];[_settings release];[_modes release];[_mcpServers release];[super dealloc];}
@end
