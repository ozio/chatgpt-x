#import "OR6ChatCodexModel.h"
#import "../../api/codex/OR6CodexOperation.h"
NSString*const OR6ChatCodexModelChanged=@"OR6ChatCodexModelChanged";
@implementation OR6ChatCodexModel
- (id)initWithBackend:(id<OR6ChatCodexBackend>)b{if((self=[super init])){_backend=[b retain];_epoch=b.epoch;_scopeID=[b.scopeID copy];_calls=[NSMutableSet new];_data=[NSMutableDictionary new];[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(backendChanged:)name:OR6ChatCodexChanged object:b];}return self;}
- (id<OR6ChatCodexBackend>)backend{return _backend;}
- (NSDictionary*)data{return OR6APIJSONSnapshot(_data,6*1024*1024);}
- (NSError*)error{return _error;}
- (BOOL)busy{return _calls.count>0;}
- (BOOL)stale{return _stale;}
- (BOOL)uncertain{return _uncertain;}
- (void)changed{[NSNotificationCenter.defaultCenter postNotificationName:OR6ChatCodexModelChanged object:self];}
- (void)backendChanged:(NSNotification*)n{(void)n;if(_epoch!=_backend.epoch||!_backend.available){_stale=YES;[_data removeAllObjects];[self cancel];[_error release];_error=[OR6CodexError(@"stale_context",NO)retain];}[self changed];}
- (BOOL)sameAccount{return[_scopeID isEqual:_backend.scopeID];}
- (void)rebind{[_scopeID release];_scopeID=[_backend.scopeID copy];[self cancel];_epoch=_backend.epoch;_stale=!_backend.available;_uncertain=NO;[_data removeAllObjects];[_error release];_error=nil;[self changed];}
- (id<OR6APITask>)call:(NSString*)op parameters:(NSDictionary*)raw slot:(NSString*)slot mutation:(BOOL)mutation completion:(OR6APIReply)completion{
 if(_stale||_epoch!=_backend.epoch||!_backend.available){if(completion)completion(nil,OR6CodexError(@"stale_context",NO));return nil;}
 NSMutableDictionary*p=[[OR6APIJSONSnapshot(raw,[op isEqual:@"codex.attachments.prepare"]?2*1024*1024:65536)mutableCopy]autorelease];if(!p){if(completion)completion(nil,OR6CodexError(@"invalid_request",NO));return nil;}if(mutation&&!p[@"operationID"])p[@"operationID"]=NSProcessInfo.processInfo.globallyUniqueString;
 OR6CodexOperation*c=[[[OR6CodexOperation alloc]init]autorelease];[_calls addObject:c];BOOL local=[@[@"codex.home.get",@"codex.transcript.snapshot",@"codex.plan.snapshot",@"codex.settings.get",@"codex.secure-setup.status",@"codex.recovery.journal",@"codex.pair.status",@"codex.pair.capability"]containsObject:op];NSUInteger epoch=_epoch;c->reply=[^(NSDictionary*r,NSError*e){[_calls removeObject:c];BOOL selection=[@[@"ui.connections.select",@"ui.cloud.select",@"ui.connections.remove",@"codex.pair.refresh",@"codex.pair.forget-local"]containsObject:op];if(selection&&!e){_epoch=_backend.epoch;[_data removeAllObjects];_stale=NO;}else if(epoch!=_backend.epoch||_stale){if(![@[@"rate_limited",@"service_challenge",@"not_authenticated"]containsObject:e.userInfo[@"code"]])e=OR6CodexError(@"stale_context",NO);r=nil;}if(e||!local){[_error release];_error=[e retain];}if(!e&&[op isEqual:@"codex.transcript.recover"]){_uncertain=NO;[_error release];_error=nil;}if(e&&mutation&&[e.userInfo[@"dispatch"]isEqual:@"possible"])_uncertain=YES;if(r&&slot)_data[slot]=OR6APIJSONSnapshot(r,6*1024*1024)?:@{};if(completion)completion(r,e);[self changed];}copy];if(!local){[_error release];_error=nil;}
 NSUInteger serial=++c->serial;id<OR6APITask>task=[_backend perform:op parameters:p event:nil completion:^(NSDictionary*r,NSError*e){[c finish:r error:e];}];if(!c->done&&serial==c->serial)c->task=[task retain];[self changed];return c;
}
- (void)cancel{for(OR6CodexOperation*c in[[_calls.allObjects copy]autorelease])[c cancel];}
- (void)dealloc{[NSNotificationCenter.defaultCenter removeObserver:self];[self cancel];[_scopeID release];[_backend release];[_calls release];[_data release];[_error release];[super dealloc];}
@end
static NSString*Text(id x){return[x isKindOfClass:NSString.class]?x:@"";}
NSArray*OR6ChatCodexHistoryRows(NSDictionary*s,NSDictionary*status,NSDictionary*plans,NSString*thread){
 NSMutableArray*rows=[NSMutableArray array];for(NSDictionary*r in s[@"items"]){NSDictionary*i=r[@"item"];NSString*t=i[@"type"],*kind=@"placeholder",*text=Text(i[@"text"]);
  if([t isEqual:@"userMessage"]){kind=@"user";NSMutableArray*a=[NSMutableArray array];for(NSDictionary*c in i[@"content"])if([c[@"type"]isEqual:@"text"])[a addObject:Text(c[@"text"])];text=[a componentsJoinedByString:@"\n"];}
  else if([t isEqual:@"agentMessage"])kind=@"agent";
  else if([t isEqual:@"commandExecution"])kind=@"command";
  else if([t isEqual:@"fileChange"])kind=@"files";
  else if([t isEqual:@"plan"])kind=@"plan";
  else if([t isEqual:@"mcpToolCall"])kind=@"mcp";
  else if([t isEqual:@"enteredReviewMode"]||[t isEqual:@"exitedReviewMode"]){kind=@"agent";text=Text(i[@"review"]);}
  else if([t isEqual:@"reasoning"]){kind=@"agent";NSMutableArray*a=[NSMutableArray array];for(id x in i[@"summary"])if([x isKindOfClass:NSString.class])[a addObject:x];text=[a componentsJoinedByString:@"\n"];}
  NSMutableDictionary*row=[NSMutableDictionary dictionaryWithDictionary:@{@"kind":kind,@"item":i,@"text":text,@"turnId":r[@"turnId"]?:@"",@"itemId":i[@"id"]?:@""}];
  if([kind isEqual:@"plan"])for(NSDictionary*p in plans[@"data"])if([p[@"item"][@"id"]isEqual:i[@"id"]]&&p[@"planToken"])row[@"planToken"]=p[@"planToken"];[rows addObject:row];
 }
 for(NSDictionary*r in status[@"serverRequests"]){if(![r[@"params"][@"threadId"]isEqual:thread])continue;NSString*m=r[@"method"],*kind=[m isEqual:@"item/tool/requestUserInput"]?@"input":[m isEqual:@"mcpServer/elicitation/request"]?@"form":@"approval";[rows addObject:@{@"kind":kind,@"request":r,@"itemId":r[@"token"]}];}
 return OR6APIJSONSnapshot(rows,6*1024*1024)?:@[];
}
NSDictionary*OR6ChatCodexInputResponse(NSDictionary*r,NSArray*selections){NSArray*q=r[@"params"][@"questions"];if(![selections isKindOfClass:NSArray.class]||q.count!=selections.count)return nil;NSMutableDictionary*answers=[NSMutableDictionary dictionary];for(NSUInteger i=0;i<q.count;i++){NSDictionary*x=q[i],*selected=selections[i];NSMutableArray*a=[NSMutableArray array];for(NSNumber*n in selected[@"options"]){if(!OR6APISchemaCheck(n,@{@"type":@"integer",@"minimum":@0},@{})||[n unsignedIntegerValue]>=[x[@"options"]count])return nil;[a addObject:Text(x[@"options"][[n unsignedIntegerValue]][@"label"])];}NSString*text=Text(selected[@"text"]);if(text.length)[a addObject:text];if(!a.count)return nil;answers[x[@"id"]]=@{@"answers":a};}return@{@"answers":answers};}
NSArray*OR6ChatCodexOfferedDecisions(NSDictionary*r,BOOL allow){NSArray*offered=r[@"params"][@"availableDecisions"];if(![offered isKindOfClass:NSArray.class])offered=@[@"accept",@"decline",@"cancel"];NSMutableArray*out=[NSMutableArray array];for(id d in offered){BOOL positive=[@[@"accept",@"acceptForSession"]containsObject:d],negative=[@[@"decline",@"cancel"]containsObject:d];if([d isKindOfClass:NSDictionary.class]){if(d[@"acceptWithExecpolicyAmendment"])positive=YES;NSDictionary*n=d[@"applyNetworkPolicyAmendment"][@"network_policy_amendment"];if(n){positive=[n[@"action"]isEqual:@"allow"];negative=[n[@"action"]isEqual:@"deny"];}}if(allow?positive:negative)[out addObject:d];}return out;}
