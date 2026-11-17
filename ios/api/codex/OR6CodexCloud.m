#import "OR6CodexCloudInternal.h"
#import "OR6CodexOperation.h"
#import <dispatch/dispatch.h>
static void Use(OR6CodexOperation*c,id<OR6APITask>(^start)(void)){if(c->done)return;NSUInteger serial=++c->serial;id<OR6APITask>t=start();if(!c->done&&serial==c->serial){[c->task release];c->task=[t retain];}}
static NSString*Esc(NSString*s){return(NSString*)[(id)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,(CFStringRef)s,NULL,CFSTR(":/?#[]@!$&'()*+,;=%"),kCFStringEncodingUTF8)autorelease];}
// Account for UTF-8 and JSON escaping before creating any remote thread. The
// placeholders bound the generated wire ID and any valid returned thread ID.
static BOOL FitsFirstTurn(NSString*text,NSString*identifier){
 NSString*thread=[@""stringByPaddingToLength:256 withString:@"漢"startingAtIndex:0],*wire=[@""stringByPaddingToLength:64 withString:@"r"startingAtIndex:0];
 NSDictionary*params=@{@"threadId":thread,@"input":@[@{@"type":@"text",@"text":text,@"text_elements":@[]}],@"clientUserMessageId":identifier};
 return OR6APIJSONSnapshot(@{@"id":wire,@"method":@"turn/start",@"params":params},24576)!=nil;
}
static BOOL Stop(NSError*e){return[@[@"not_authenticated",@"service_challenge",@"rate_limited"]containsObject:e.userInfo[@"code"]];}
@interface OR6CodexCloud()
- (id)initWithBinding:(OR6CodexCloudBinding*)binding IO:(id<OR6CodexCloudIO>)IO contracts:(NSDictionary*)contracts directory:(NSString*)directory error:(NSError**)error;
- (void)clearCatalog;
@end
@implementation OR6CodexCloud
- (id)initWithCredentials:(OR6CodexCloudCredentialSource)source roots:(NSString*)roots contracts:(NSDictionary*)contracts privateDirectory:(NSString*)directory error:(NSError**)error{
 OR6CodexCloudBinding*b=[[[OR6CodexCloudBinding alloc]initWithSource:source error:error]autorelease];if(!b){[self release];return nil;}OR6CodexCloudWire*w=[[[OR6CodexCloudWire alloc]initWithBinding:b roots:roots error:error]autorelease];return[self initWithBinding:b IO:w contracts:contracts directory:directory error:error];
}
- (id)initWithIO:(id<OR6CodexCloudIO>)IO credentials:(OR6CodexCloudCredentialSource)source contracts:(NSDictionary*)contracts privateDirectory:(NSString*)directory error:(NSError**)error{
 OR6CodexCloudBinding*b=[[[OR6CodexCloudBinding alloc]initWithSource:source error:error]autorelease];return[self initWithBinding:b IO:IO contracts:contracts directory:directory error:error];
}
- (id)initWithBinding:(OR6CodexCloudBinding*)b IO:(id<OR6CodexCloudIO>)IO contracts:(NSDictionary*)contracts directory:(NSString*)directory error:(NSError**)error{
 if(!(self=[super init]))return nil;if(!NSThread.isMainThread||!b||!IO){if(error)*error=OR6CodexError(@"invalid_request",NO);[self release];return nil;}
 _binding=[b retain];_wire=[IO retain];_session=[[OR6CodexCloudSession alloc]initWithIO:IO binding:b contracts:contracts directory:directory error:error];if(!_session){[self release];return nil;}
 _provider=[[OR6CodexProvider alloc]initWithSession:_session context:b.context];_catalog=[NSMutableDictionary new];_cursors=[NSMutableDictionary new];_selections=[NSMutableDictionary new];_active=[NSMutableSet new];[self clearCatalog];return self;
}
- (void)clearCatalog{[_catalog removeAllObjects];[_cursors removeAllObjects];[_selections removeAllObjects];[_catalogRevision release];_catalogRevision=[NSProcessInfo.processInfo.globallyUniqueString copy];}
- (BOOL)matchesContext:(NSDictionary*)c{return[[_binding context]isEqual:c];}
- (id<OR6APITask>)perform:(NSString*)op parameters:(NSDictionary*)raw event:(OR6APIEvent)event completion:(OR6APIReply)cb{
 if(!cb)return nil;if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{cb(nil,OR6CodexError(@"invalid_request",NO));});return nil;}
 if(_deactivated||![_binding current]){[self deactivate];cb(nil,OR6CodexError(@"stale_context",NO));return nil;}
 NSDictionary*p=OR6APIJSONSnapshot(raw,65536);if(!p||!OR6CodexText(op,128,NO)||_active.count>=16){cb(nil,OR6CodexError(@"invalid_request",NO));return nil;}
 if(![op hasPrefix:@"codex.cloud."]){
  // Workspace filesystem operations and cwd-based creation belong to the host
  // route. Cloud starts only through a catalogue-bound selection token.
  if([op isEqual:@"codex.tasks.create"]||([op isEqual:@"codex.session.connect"]&&p.count)){cb(nil,OR6CodexError(@"invalid_request",NO));return nil;}
  return[_provider execute:op parameters:p context:[_binding context]event:event completion:^(NSDictionary*r,NSError*e){if(Stop(e)||![_binding current])[self deactivate];cb(r,e);}];
 }
 OR6CodexOperation*c=[[[OR6CodexOperation alloc]init]autorelease];[_active addObject:c];c->reply=[^(NSDictionary*r,NSError*e){[_active removeObject:c];if(_catalogCall==c){_catalogBusy=NO;_catalogCall=nil;}if(Stop(e)||![_binding current])[self deactivate];cb(r,e);}copy];OR6APIReply finish=^(NSDictionary*r,NSError*e){NSDictionary*s=r?OR6APIJSONSnapshot(r,1048576):nil;[c finish:s error:e?:r&&!s?OR6CodexError(@"size_limit",NO):nil];};
 if([op isEqual:@"codex.cloud.capability"]){if(p.count)goto invalid;finish(@{@"available":@YES,@"implemented":@YES,@"UIReady":@YES,@"UIConnected":@NO,@"profile":@"hosted-26.1106.51428",@"accountAdmission":@"unobserved",@"mobileEnrollmentRequired":@NO,@"catalogueMaximum":@256,@"requestMaximumBytes":@24576,@"messageMaximumBytes":@1048576},nil);return c;}
 if([op isEqual:@"codex.cloud.environments.list"]){
  if(!OR6CodexKeys(p,@[@"scope"],@[@"cursor"])||![@[@"user",@"workspace"]containsObject:p[@"scope"]])goto invalid;
  if(_catalogBusy){finish(nil,OR6CodexError(@"conflict",NO));return c;}
  if(p[@"cursor"]&&!OR6CodexID(p[@"cursor"]))goto invalid;
  NSDictionary*cursor=p[@"cursor"]?_cursors[p[@"cursor"]]:nil;
  if(p[@"cursor"]&&(!OR6CodexID(p[@"cursor"])||![cursor[@"scope"]isEqual:p[@"scope"]]||![cursor[@"revision"]isEqual:_catalogRevision])){finish(nil,OR6CodexError(@"stale_context",NO));return c;}
  // A fresh first page invalidates that scope's selection and cursor tokens.
  // Other scope pages remain independent; no unbounded automatic page loop.
  if(!cursor){for(NSString*k in[[_catalog.allKeys copy]autorelease])if([_catalog[k][@"scope"]isEqual:p[@"scope"]])[_catalog removeObjectForKey:k];for(NSString*k in[[_selections.allKeys copy]autorelease])if([_selections[k][@"scope"]isEqual:p[@"scope"]])[_selections removeObjectForKey:k];for(NSString*k in[[_cursors.allKeys copy]autorelease])if([_cursors[k][@"scope"]isEqual:p[@"scope"]])[_cursors removeObjectForKey:k];}
  _catalogBusy=YES;_catalogCall=c;NSString*revision=[[_catalogRevision copy]autorelease];NSString*path=[NSString stringWithFormat:@"/v1/environment-configs?scope=%@&limit=100&omitDraft=true%@",p[@"scope"],cursor?[@"&cursor="stringByAppendingString:Esc(cursor[@"wire"])]:@""];
  Use(c,^id<OR6APITask>{return[_wire readPath:path completion:^(NSDictionary*r,NSError*e){
   if(c->done)return;if(![_binding current]||![revision isEqual:_catalogRevision]){finish(nil,OR6CodexError(@"stale_context",NO));return;}if(e){finish(nil,e);return;}
   if(!OR6CodexKeys(r,@[@"data",@"next_cursor"],@[])||![r[@"data"]isKindOfClass:NSArray.class]||[r[@"data"]count]>100||(r[@"next_cursor"]&&r[@"next_cursor"]!=NSNull.null&&!OR6CodexText(r[@"next_cursor"],4096,NO))){finish(nil,OR6CodexError(@"schema_mismatch",NO));return;}
   NSMutableArray*data=[NSMutableArray array];NSMutableDictionary*added=[NSMutableDictionary dictionary];NSMutableSet*ids=[NSMutableSet set];
   for(NSDictionary*x in r[@"data"]){
    if(![x isKindOfClass:NSDictionary.class]||!OR6CodexID(x[@"id"])||!OR6CodexText(x[@"name"],512,NO)||[ids containsObject:x[@"id"]]||!OR6CodexID(x[@"version_id"])||(x[@"version_revision"]&&x[@"version_revision"]!=NSNull.null&&!OR6APISchemaCheck(x[@"version_revision"],@{@"type":@"integer",@"minimum":@1},@{}))){finish(nil,OR6CodexError(@"schema_mismatch",NO));return;}[ids addObject:x[@"id"]];
    NSMutableDictionary*row=[NSMutableDictionary dictionaryWithDictionary:@{@"id":x[@"id"],@"name":x[@"name"],@"scope":p[@"scope"]}];
    if(x[@"version_id"]&&x[@"version_id"]!=NSNull.null)row[@"versionId"]=x[@"version_id"];if(x[@"version_revision"]&&x[@"version_revision"]!=NSNull.null)row[@"versionRevision"]=x[@"version_revision"];
    // Only display metadata crosses into results. Config secrets, provider
    // payloads, arbitrary response properties and prompts are never cached.
    if(OR6CodexText(x[@"description"],1024,YES))row[@"description"]=x[@"description"];
    NSString*key=[p[@"scope"]stringByAppendingFormat:@":%@",x[@"id"]];added[key]=row;[data addObject:row];
   }
   if(_catalog.count+added.count>256||_cursors.count>=16){finish(nil,OR6CodexError(@"size_limit",NO));return;}
   NSMutableDictionary*bounded=[[_catalog mutableCopy]autorelease];[bounded addEntriesFromDictionary:added];if(!OR6APIJSONSnapshot(bounded,524288)){finish(nil,OR6CodexError(@"size_limit",NO));return;}
   [_catalog addEntriesFromDictionary:added];if(p[@"cursor"])[_cursors removeObjectForKey:p[@"cursor"]];id next=NSNull.null;
   if(r[@"next_cursor"]&&r[@"next_cursor"]!=NSNull.null){next=NSProcessInfo.processInfo.globallyUniqueString;_cursors[next]=@{@"scope":p[@"scope"],@"wire":r[@"next_cursor"],@"revision":revision};}
   finish(@{@"data":data,@"nextCursor":next,@"scope":p[@"scope"]},nil);
  }];});return c;
 }
 if([op isEqual:@"codex.cloud.environments.select"]){
  if(!OR6CodexKeys(p,@[@"scope",@"id"],@[@"cwd"])||!OR6CodexID(p[@"id"])||![@[@"user",@"workspace"]containsObject:p[@"scope"]]||(p[@"cwd"]&&!OR6CodexPath(p[@"cwd"])))goto invalid;
  if(_catalogBusy){finish(nil,OR6CodexError(@"conflict",NO));return c;}NSDictionary*row=_catalog[[p[@"scope"]stringByAppendingFormat:@":%@",p[@"id"]]];if(!row){finish(nil,OR6CodexError(@"not_found",NO));return c;}if(_selections.count>=32){finish(nil,OR6CodexError(@"size_limit",NO));return c;}
  NSString*token=NSProcessInfo.processInfo.globallyUniqueString;NSMutableDictionary*s=[[row mutableCopy]autorelease];s[@"revision"]=_catalogRevision;if(p[@"cwd"])s[@"cwd"]=p[@"cwd"];_selections[token]=s;finish(@{@"selectionToken":token,@"environment":row,@"versionPinned":@NO},nil);return c;
 }
 if([op isEqual:@"codex.cloud.tasks.create"]){
  if(!OR6CodexKeys(p,@[@"selectionToken",@"text",@"operationID"],@[])||!OR6CodexID(p[@"selectionToken"])||!OR6CodexText(p[@"text"],16000,NO)||!OR6CodexID(p[@"operationID"])||[p[@"operationID"]length]>200||!FitsFirstTurn(p[@"text"],p[@"operationID"]))goto invalid;
  NSDictionary*s=_selections[p[@"selectionToken"]];if(!s||![s[@"revision"]isEqual:_catalogRevision]||_catalogBusy){finish(nil,OR6CodexError(@"stale_context",NO));return c;}
  NSString*identifier=p[@"operationID"];NSMutableDictionary*environment=[NSMutableDictionary dictionaryWithObject:s[@"id"]forKey:@"environmentConfigId"];if(s[@"cwd"])environment[@"cwd"]=s[@"cwd"];
  NSDictionary*params=@{@"environments":@[environment],@"deferredEnvironment":@YES,@"pluginsMcp":@{@"productSku":@"codex"},@"config":@{@"features.mcp_app_ui":@YES},@"historyMode":@"paginated"};
  Use(c,^id<OR6APITask>{return[_session request:@"thread/start"parameters:params operationID:[identifier stringByAppendingString:@".thread"]completion:^(NSDictionary*started,NSError*e){
   if(c->done)return;if(e){finish(nil,e);return;}NSString*thread=started[@"thread"][@"id"];
   // Read the created durable ID before starting the first user turn. A failed
   // read leaves its receipt in the journal; neither step is silently replayed.
   Use(c,^id<OR6APITask>{return[_session request:@"thread/read"parameters:@{@"threadId":thread,@"includeTurns":@NO}operationID:nil completion:^(NSDictionary*readback,NSError*failure){
    if(c->done)return;if(failure){finish(nil,failure);return;}
    Use(c,^id<OR6APITask>{return[_session request:@"turn/start"parameters:@{@"threadId":thread,@"input":@[@{@"type":@"text",@"text":p[@"text"],@"text_elements":@[]}],@"clientUserMessageId":identifier}operationID:[identifier stringByAppendingString:@".turn"]completion:^(NSDictionary*turn,NSError*problem){
     if(c->done)return;if(problem){finish(nil,problem);return;}finish(@{@"thread":readback[@"thread"],@"turn":turn[@"turn"],@"environmentConfigId":s[@"id"],@"versionPinned":@NO,@"state":@"accepted",@"environmentProvisioning":@"deferred"},nil);
    }];});
   }];});
  }];});return c;
 }
invalid:finish(nil,OR6CodexError(@"invalid_request",NO));return c;
}
- (void)deactivate{if(!NSThread.isMainThread||_deactivated)return;_deactivated=YES;[_binding invalidate];for(OR6CodexOperation*c in[[_active.allObjects copy]autorelease])[c cancel];[_provider deactivate];[self clearCatalog];[_wire close];}
- (void)dealloc{[self deactivate];[_provider release];[_session release];[_binding release];[_wire release];[_catalog release];[_cursors release];[_selections release];[_active release];[_catalogRevision release];[super dealloc];}
@end
