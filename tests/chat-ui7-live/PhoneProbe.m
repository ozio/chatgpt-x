// Acceptance-build only. Real production Core/providers/transport; fixed synthetic prompts,
// durable budgets, one owned test chat, no account settings and no credential export.
#import "Policy.h"
#import "../../ios/chat/OR6ChatCoordinator.h"
#import "../../ios/api/OR6APICore.h"
#import "../../ios/api/OR6APIWebAdapter.h"
#import "../../ios/api/priority7/OR6API7Network.h"
#import "../../ios/api/priority7/OR6API7Policy.h"
#import "../../ios/api/priority7f/OR6API7FPolicy.h"
#import "../../ios/chat/OR6ChatNativePolicy.h"
#include <sys/stat.h>
#import "../../ios/chat/OR6ChatNativeProvider.h"
#import "../../ios/OR6Files.h"
#import <ImageIO/ImageIO.h>
#import "../../ios/api/OR6APIWire.h"
#import "../../ios/api/priority7f/OR6API7FAnalysis.h"
@class Live7;
@interface LiveHTTP:NSObject<OR6API7HTTP>{@public id<OR6API7HTTP>next;Live7*owner;}
@end
@interface Live7:NSObject{
 @public OR6ChatCoordinator*host;OR6APICore*core;id seven,f;id old7,oldF;NSSet*caps7,*capsF;NSDictionary*context;
 NSMutableDictionary*state;NSString*path;id<OR6APITask>task;BOOL busy,stopped,closed;NSUInteger serial;
}
- (void)save;
- (BOOL)current;
- (void)restore;
- (void)perform:(NSString*)op parameters:(NSDictionary*)p completion:(OR6APIReply)reply;
- (NSDictionary*)status;
- (NSDictionary*)step:(NSString*)name;
@end
static Live7*live;
static NSString*UUID(void){return OR6API7FUUID();}
static id Shape(id v,NSUInteger d){if(d>4)return @"depth";if(!v||v==NSNull.null)return NSNull.null;if([v isKindOfClass:NSString.class])return @{@"stringLength":@([v length])};if([v isKindOfClass:NSNumber.class])return v;if([v isKindOfClass:NSArray.class]){NSMutableArray*a=[NSMutableArray array];for(id x in [v subarrayWithRange:NSMakeRange(0,MIN((NSUInteger)8,[v count]))])[a addObject:Shape(x,d+1)];return @{@"count":@([v count]),@"sample":a};}if([v isKindOfClass:NSDictionary.class]){NSMutableDictionary*a=[NSMutableDictionary dictionary];for(NSString*k in v)if(k.length<100&&a.count<60)a[k]=Shape(v[k],d+1);return a;}return @"unknown";}
@implementation LiveHTTP
- (id<OR6APITask>)request:(NSURLRequest*)r context:(NSDictionary*)ctx completion:(OR6APIReply)reply{
 NSMutableArray*trace=owner->state[@"http"];if(![owner current]||owner->stopped||trace.count>=48||!OR6Live7Allowed(r,owner->state[@"conversationId"],owner->state[@"shareId"])) {reply(nil,OR6APIError(@"live_probe_refused",@"none"));return nil;}
 NSMutableDictionary*entry=[NSMutableDictionary dictionaryWithDictionary:@{@"method":r.HTTPMethod,@"path":r.URL.path,@"dispatched":@YES}];[trace addObject:entry];[owner save];
 return[next request:r context:ctx completion:^(NSDictionary*v,NSError*e){entry[@"status"]=v[@"status"]?:@0;entry[@"shape"]=Shape(v[@"json"],0);entry[@"code"]=e.userInfo[@"code"]?:@"";
 if([r.URL.path isEqual:@"/backend-api/share/v2/create"]&&OR6API7UUID(v[@"json"][@"share_id"]))owner->state[@"shareId"]=v[@"json"][@"share_id"];
 if([@[@"service_challenge",@"not_authenticated",@"rate_limited",@"auth_failed"]containsObject:e.userInfo[@"code"]]){owner->stopped=YES;owner->state[@"stopCode"]=e.userInfo[@"code"];}
 [owner save];reply(v,e);}];
}
- (void)dealloc{[next release];[super dealloc];}
@end
@implementation Live7
- (BOOL)current{return !closed&&[[core valueForKey:@"context"]isEqual:context];}
- (void)save{if(!state||!path)return;NSData*d=[NSJSONSerialization dataWithJSONObject:state options:0 error:NULL];if(d.length<1024*1024&&[d writeToFile:path atomically:YES])chmod(path.fileSystemRepresentation,0600);}
- (void)restore{if(closed)return;closed=YES;if(caps7)[seven setValue:caps7 forKey:@"capabilities"];if(capsF)[f setValue:capsF forKey:@"capabilities"];if(old7)[seven setValue:old7 forKey:@"HTTP"];if(oldF)[f setValue:oldF forKey:@"HTTP"];[state setObject:@YES forKey:@"capabilitiesRestored"];[self save];}
- (void)background:(NSNotification*)n{(void)n;if(busy){stopped=YES;state[@"stopCode"]=@"background_during_operation";}[task cancel];[self restore];}
- (NSDictionary*)status{return @{@"ok":@YES,@"live7":@YES,@"busy":@(busy),@"stopped":@(stopped),@"closed":@(closed),@"state":state?:@{}};}
- (void)perform:(NSString*)op parameters:(NSDictionary*)p completion:(OR6APIReply)reply{
 state[@"activeOperation"]=op;state[@"activeParameters"]=p;[self save];NSUInteger epoch=++serial;__block BOOL done=NO;
 id<OR6APITask>t=[core perform:op parameters:p event:^(NSDictionary*event){state[@"eventCount"]=@([state[@"eventCount"]unsignedIntegerValue]+1);state[@"lastEventType"]=event[@"type"]?:@"";}completion:^(NSDictionary*r,NSError*e){done=YES;if(epoch!=serial)return;[task release];task=nil;
 if(![self current]){stopped=YES;state[@"stopCode"]=@"context_changed";}
 if([@[@"service_challenge",@"not_authenticated",@"rate_limited",@"auth_failed"]containsObject:e.userInfo[@"code"]]){stopped=YES;state[@"stopCode"]=e.userInfo[@"code"];}
 state[@"lastOperation"]=op;state[@"lastParameters"]=p;state[@"lastResult"]=r?:@{};state[@"lastError"]=e?@{@"code":e.userInfo[@"code"]?:@"unknown",@"dispatch":e.userInfo[@"dispatch"]?:@"none"}:@{};[self save];reply(r,e);}];
 if(!done){[task release];task=[t retain];}
}
- (void)readOwned:(OR6APIReply)reply{
 if(!OR6API7UUID(state[@"conversationId"])||![state[@"marker"]isKindOfClass:NSString.class]){reply(nil,OR6APIError(@"ownership_not_proven",@"none"));return;}
 [self perform:@"history.get" parameters:@{@"conversationId":state[@"conversationId"]}completion:^(NSDictionary*r,NSError*e){
 BOOL found=NO;for(NSDictionary*m in r[@"messages"])if([m[@"role"]isEqual:@"user"]&&[m[@"text"]rangeOfString:state[@"marker"]].location!=NSNotFound)found=YES;
 if(!e&&found){state[@"currentNode"]=r[@"currentNode"]?:@"";state[@"history"]=r;state[@"enrolled"]=@YES;state[@"originalTitle"]=state[@"originalTitle"]?:r[@"title"]?:@"";[self save];reply(r,nil);}else reply(nil,e?:OR6APIError(@"ownership_not_proven",@"none"));}];
}
- (BOOL)removeOwnedSeedRecovery:(NSDictionary*)receipt{
 OR6ChatNativeProvider*web=[host valueForKey:@"web"];NSDictionary*s=[web recoverySnapshotForConversation:state[@"conversationId"]];
 if(!s){state[@"seedRecoveryAbsent"]=@YES;return YES;}
 if(!OR6Live7OwnRecovery(s,state[@"conversationId"],receipt[@"userMessageId"],context[@"key"],state[@"marker"]))return NO;
 NSString*directory=[[web valueForKey:@"recovery"]valueForKey:@"directory"];
 if(!directory.length)return NO;NSString*name=[NSString stringWithFormat:@"%@-%@.json",OR6CNHash(context[@"key"]),[s[@"operationId"]lowercaseString]];
 BOOL removed=[NSFileManager.defaultManager removeItemAtPath:[directory stringByAppendingPathComponent:name]error:NULL];
 if(removed)state[@"seedRecoveryRemoved"]=@YES;return removed;
}
- (void)finish:(NSString*)name result:(NSDictionary*)r error:(NSError*)e{
 busy=NO;NSMutableDictionary*entry=state[@"steps"][name];entry[@"completed"]=@(!e);entry[@"result"]=r?:@{};entry[@"error"]=e?@{@"code":e.userInfo[@"code"]?:@"unknown",@"dispatch":e.userInfo[@"dispatch"]?:@"none"}:@{};
 NSUInteger writes=0;NSArray*http=state[@"http"];for(NSUInteger i=[state[@"httpBeforeStep"]unsignedIntegerValue];i<http.count;i++)if(![http[i][@"method"]isEqual:@"GET"])writes++;
 NSUInteger after=[[(OR6ChatNativeProvider*)[host valueForKey:@"web"]diagnostics][@"sendsAttempted"]unsignedIntegerValue];entry[@"nativeSendsBefore"]=state[@"sendsBeforeStep"]?:@0;entry[@"nativeSendsAfter"]=@(after);entry[@"HTTPWriteAttempts"]=@(writes);
 if(OR6Live7NeedsReconcile(state[@"lastOperation"],[e.userInfo[@"dispatch"]isEqual:@"possible"],[state[@"sendsBeforeStep"]unsignedIntegerValue],after,writes)){state[@"uncertain"]=@YES;state[@"uncertainOperation"]=state[@"lastOperation"]?:@"";state[@"uncertainParameters"]=state[@"lastParameters"]?:@{};}
 [self save];
}
- (NSDictionary*)step:(NSString*)name{
 if(![self current]||busy||stopped||[core.diagnostics[@"activeCount"]unsignedIntegerValue])return @{@"ok":@NO,@"error":@"probe_busy_closed_or_stopped"};
 NSNumber*limit=OR6Live7Limits()[name];NSMutableDictionary*counts=state[@"counts"];NSUInteger n=[counts[name]unsignedIntegerValue];if(!limit||n>=limit.unsignedIntegerValue)return @{@"ok":@NO,@"error":@"attempt_budget"};
 BOOL reconcile=[name isEqual:@"reconcile"],seed=[name isEqual:@"seed"];
 BOOL afterImage=[name isEqual:@"research"]&&[state[@"uncertainOperation"]isEqual:@"images.create"]&&[state[@"steps"][@"streamStatus"][@"result"][@"status"]isEqual:@"COMPLETE"];if(([state[@"uncertain"]boolValue]&&!reconcile&&!afterImage&&![@[@"readback",@"catalog",@"ownDiagnostics",@"streamStatus",@"continue",@"delete",@"verifyDeleted"]containsObject:name])||(!seed&&![state[@"enrolled"]boolValue]))return @{@"ok":@NO,@"error":@"ownership_or_uncertain"};
 counts[name]=@(n+1);state[@"sendsBeforeStep"]=[(OR6ChatNativeProvider*)[host valueForKey:@"web"]diagnostics][@"sendsAttempted"]?:@0;state[@"httpBeforeStep"]=@([state[@"http"]count]);NSString*operation=UUID();state[@"steps"][name]=[NSMutableDictionary dictionaryWithDictionary:@{@"operationId":operation,@"dispatched":@YES}];busy=YES;[self save];
 OR6APIReply end=^(NSDictionary*r,NSError*e){[self finish:name result:r error:e];};
 if(seed){NSString*d=UUID(),*parent=UUID();NSDictionary*p=@{@"draftId":d,@"parentMessageId":parent,@"modelId":@"web-current",@"temporary":@NO};
  [self perform:@"messages.newDraft" parameters:p completion:^(NSDictionary*r,NSError*e){if(e){end(nil,e);return;}(void)r;
   NSDictionary*send=@{@"operationId":operation,@"draftId":d,@"parentMessageId":parent,@"modelId":@"web-current",@"temporary":@NO,@"text":[state[@"marker"]stringByAppendingString:@". This is a temporary software acceptance test. Reply only OK."],@"attachments":@[]};
   [self perform:@"messages.send" parameters:send completion:^(NSDictionary*v,NSError*x){NSString*cid=v[@"conversationId"];if(OR6API7UUID(cid))state[@"conversationId"]=cid;
    if(x||![v[@"persisted"]isEqual:@YES]||![v[@"state"]isEqual:@"completed"]||!OR6API7UUID(cid)){end(v,x?:OR6APIError(@"uncertain_outcome",@"possible"));return;}
    [self readOwned:^(NSDictionary*h,NSError*z){(void)h;if(!z&&![self removeOwnedSeedRecovery:v]){stopped=YES;state[@"stopCode"]=@"owned_recovery_cleanup_failed";z=OR6APIError(@"storage_failure",@"none");}end(v,z);}];}];}];return[self status];
 }
 NSString*cid=state[@"conversationId"],*sid=state[@"shareId"],*node=state[@"currentNode"];NSString*op=nil;NSDictionary*p=nil;
 if([name isEqual:@"readback"]){[self readOwned:end];return[self status];}
 if([name isEqual:@"streamStatus"]||[name isEqual:@"ownDiagnostics"]){
  BOOL status=[name isEqual:@"streamStatus"];NSURLRequest*q=status?OR6API7FRequest(@"tools.deepResearch.status",@{@"conversationId":cid},NULL):OR6API7Request(@"conversations.readback",@{@"conversationId":cid},NULL);
  id<OR6APITask>child=[[(status?f:seven)valueForKey:@"HTTP"]request:q context:context completion:^(NSDictionary*v,NSError*e){
   if(e){end(nil,e);return;}NSDictionary*raw=v[@"json"];
   if(status){end(@{@"httpStatus":v[@"status"]?:@0,@"status":raw[@"status"]?:NSNull.null},nil);return;}
   if(![raw[@"conversation_id"]isEqual:cid]||![raw[@"mapping"]isKindOfClass:NSDictionary.class]){end(nil,OR6APIError(@"owner_mismatch",@"none"));return;}
   NSMutableArray*messages=[NSMutableArray array];for(NSString*k in raw[@"mapping"]){NSDictionary*n=raw[@"mapping"][k],*m=n[@"message"];if(![m isKindOfClass:NSDictionary.class])continue;
    NSMutableDictionary*safe=[NSMutableDictionary dictionary];for(NSString*field in @[@"id",@"channel",@"status",@"recipient",@"end_turn"])if(m[field])safe[field]=m[field];safe[@"author"]=m[@"author"]?:@{};safe[@"type"]=m[@"content"][@"content_type"]?:NSNull.null;
    id hints=m[@"metadata"][@"system_hints"];if(hints)safe[@"system_hints"]=hints;safe[@"hidden"]=m[@"metadata"][@"is_visually_hidden_from_conversation"]?:@NO;[messages addObject:safe];
   }end(@{@"currentNode":raw[@"current_node"]?:NSNull.null,@"study":raw[@"is_study_mode"]?:NSNull.null,@"messages":messages},nil);
  }];if(busy){[task release];task=[child retain];}return[self status];
 }
 if([name isEqual:@"catalog"]){
  NSURLRequest*q=OR6API7FRequest(@"analysis.models",@{},NULL);
  id<OR6APITask>child=[[f valueForKey:@"HTTP"]request:q context:context completion:^(NSDictionary*v,NSError*e){
   if(e){end(nil,e);return;}NSDictionary*raw=v[@"json"];NSData*data=[NSJSONSerialization dataWithJSONObject:raw options:0 error:NULL];NSDictionary*picker=OR6APIWireModels(data,NULL);NSMutableArray*models=[NSMutableArray array];
   for(NSDictionary*m in raw[@"models"]){if(![m isKindOfClass:NSDictionary.class])continue;NSMutableDictionary*safe=[NSMutableDictionary dictionary];for(NSString*k in @[@"slug",@"enabled_tools",@"is_work_mode_model"])if(m[k])safe[k]=m[k];id attachments=m[@"product_features"][@"attachments"][@"type"];if(attachments)safe[@"attachmentType"]=attachments;[models addObject:safe];}
   end(@{@"defaultModel":raw[@"default_model_slug"]?:NSNull.null,@"picker":picker?:@{},@"models":models},nil);
  }];if(busy){[task release];task=[child retain];}return[self status];
 }

 if([name isEqual:@"rename"]||[name isEqual:@"renameBack"]){op=@"conversations.rename";p=@{@"operationId":operation,@"conversationId":cid,@"title":[name isEqual:@"rename"]?[state[@"marker"]stringByAppendingString:@" renamed"]:state[@"originalTitle"]};}
 else if([@[@"pin",@"unpin"]containsObject:name]){op=@"conversations.pin";p=@{@"operationId":operation,@"conversationId":cid,@"pinned":@([name isEqual:@"pin"])};}
 else if([@[@"archive",@"unarchive",@"delete"]containsObject:name]){op=[@"conversations."stringByAppendingString:name];p=@{@"operationId":operation,@"conversationId":cid};}
 else if([name isEqual:@"share"]){op=@"shares.create";p=@{@"operationId":operation,@"conversationId":cid,@"currentNode":node,@"publish":@YES};}
 else if([@[@"shareGet",@"shareGetAfterFix",@"shareGone"]containsObject:name]&&OR6API7UUID(sid)){op=@"shares.get";p=@{@"shareId":sid};}
 else if([name isEqual:@"revoke"]&&OR6API7UUID(sid)){op=@"chat.sharedLink.delete";p=@{@"operationId":operation,@"shareId":sid};}
 else if([name isEqual:@"pins"]){op=@"pins.list";p=@{};}
 else if([name isEqual:@"archives"]){op=@"archives.list";p=@{@"offset":@0,@"limit":@50};}
 else if([name isEqual:@"verifyDeleted"]){op=@"history.get";p=@{@"conversationId":cid};}
 else if(reconcile){if([state[@"uncertain"]boolValue]){NSDictionary*last=state[@"uncertainParameters"];op=[state[@"uncertainOperation"]hasPrefix:@"conversations."]||[state[@"uncertainOperation"]isEqual:@"shares.create"]?@"conversations.reconcile":@"tools.operation.reconcile";if(last[@"operationId"])p=@{@"operationId":last[@"operationId"]};}else{op=@"conversations.reconcile";NSString*target=state[@"steps"][@"unarchive"][@"operationId"];if(target)p=@{@"operationId":target};}}
 else if([@[@"analysis",@"study",@"image",@"research"]containsObject:name]){
  NSDictionary*ops=@{@"analysis":@"tools.dataAnalysis",@"study":@"tools.study",@"image":@"images.create",@"research":@"tools.deepResearch"};
  NSDictionary*prompts=@{@"analysis":@"Acceptance test: use Python to compute sum(i*i for i in range(1,101)). Return the number and the executed Python code. Do not browse or create files.",@"study":@"Acceptance test in Study mode: teach me how to solve 2*x+3=7. Ask me exactly one short guiding question and wait for my answer.",@"image":@"Acceptance test: generate one simple image of a plain emerald green circle on a white background. No text, no people. One image only.",@"research":@"Acceptance test: briefly research why the Moon has phases, using at most two primary NASA sources. Keep it short; no downloads or external actions."};op=ops[name];p=@{@"operationId":operation,@"conversationId":cid,@"parentMessageId":node,@"modelId":@"web-current",@"text":prompts[name]};
 }
 else if([name isEqual:@"imageDownload"]){NSDictionary*image=state[@"steps"][@"image"][@"result"];NSArray*images=image[@"images"];if(images.count&&OR6API7UUID(image[@"assistantMessageId"])){op=@"assets.download";p=@{@"operationId":operation,@"conversationId":cid,@"messageId":image[@"assistantMessageId"],@"fileId":images[0][@"fileId"]};}}
 else if([name isEqual:@"imageCleanup"]){NSString*asset=state[@"downloadedImage"][@"id"];OR6Files*vault=[[host valueForKey:@"media8"]valueForKey:@"vault"];NSError*e=nil;BOOL removed=asset&&[vault removeAssetID:asset error:&e];if(removed)state[@"localImageRemoved"]=@YES;end(removed?@{@"removed":@YES}:nil,removed?nil:OR6APIError(@"storage_failure",@"none"));return[self status];}
 else if([name isEqual:@"analysisResult"]){op=@"tools.dataAnalysis.result";p=@{@"operationId":state[@"steps"][@"analysis"][@"operationId"]?:@"",@"conversationId":cid};}
 else if([name isEqual:@"researchStatus"]||[name isEqual:@"researchCancel"]){op=[name isEqual:@"researchStatus"]?@"tools.deepResearch.status":@"tools.deepResearch.cancel";NSString*research=state[@"steps"][@"research"][@"operationId"];if(research)p=[name isEqual:@"researchStatus"]?@{@"operationId":research}:@{@"operationId":operation,@"taskOperationId":research};}
 else if([name isEqual:@"continue"]){for(NSDictionary*m in [state[@"history"][@"messages"]reverseObjectEnumerator])if([m[@"role"]isEqual:@"assistant"]&&[m[@"finished"]isEqual:@NO]&&[m[@"status"]isEqual:@"finished_partial_completion"]){op=@"chat.continue";p=@{@"operationId":operation,@"conversationId":cid,@"assistantMessageId":m[@"id"],@"modelId":@"web-current"};break;}}
 if(!op||!p){end(nil,OR6APIError(@"eligible_state_missing",@"none"));return[self status];}
 [self perform:op parameters:p completion:^(NSDictionary*r,NSError*e){
  if(!e&&[name isEqual:@"share"]&&OR6API7UUID(r[@"share"][@"id"]))state[@"shareId"]=r[@"share"][@"id"];
  if(!e&&[name isEqual:@"imageDownload"]){OR6Files*vault=[[host valueForKey:@"media8"]valueForKey:@"vault"];NSDictionary*asset=[vault assetForID:r[@"assetId"]error:NULL];NSURL*url=[vault URLForAssetID:r[@"assetId"]error:NULL];CGImageSourceRef source=url?CGImageSourceCreateWithURL((CFURLRef)url,NULL):NULL;NSDictionary*props=source?[(NSDictionary*)CGImageSourceCopyPropertiesAtIndex(source,0,NULL)autorelease]:nil;if(source)CFRelease(source);if(asset&&props){NSMutableDictionary*proof=[[asset mutableCopy]autorelease];proof[@"width"]=props[(NSString*)kCGImagePropertyPixelWidth]?:@0;proof[@"height"]=props[(NSString*)kCGImagePropertyPixelHeight]?:@0;state[@"downloadedImage"]=proof;}else e=OR6APIError(@"unsupported_media",@"none");}
  if(!e&&[name isEqual:@"revoke"])state[@"shareRevoked"]=@YES;
  if(!e&&[name isEqual:@"delete"])state[@"deleteAcknowledged"]=@YES;
  if([name isEqual:@"verifyDeleted"]&&[e.userInfo[@"code"]isEqual:@"not_found"])state[@"deleted"]=@YES;
  if(!e&&reconcile&&OR6Live7Reconciled(r,state[@"uncertainParameters"][@"operationId"])){
   state[@"uncertain"]=@NO;if([state[@"uncertainOperation"]isEqual:@"chat.sharedLink.delete"])state[@"shareRevoked"]=@YES;
  }
  end(r,e);
 }];return[self status];
}
- (void)dealloc{[NSNotificationCenter.defaultCenter removeObserver:self];[self restore];[task cancel];[task release];[host release];[core release];[seven release];[f release];[old7 release];[oldF release];[caps7 release];[capsF release];[context release];[state release];[path release];[super dealloc];}
@end
NSDictionary*OR6ChatLive7(OR6ChatCoordinator*coordinator,NSDictionary*command){
 NSString*action=command[@"action"];
 if([action isEqual:@"live7_status"])return live?[live status]:@{@"ok":@NO,@"error":@"probe_closed"};
 if([action isEqual:@"live7_begin"]){
  if(live)return @{@"ok":@NO,@"error":@"probe_exists"};OR6APICore*c=[coordinator valueForKey:@"core"];if([c.diagnostics[@"activeCount"]unsignedIntegerValue])return @{@"ok":@NO,@"error":@"core_active"};
  NSString*run=command[@"runId"];if(!OR6API7UUID(run))return @{@"ok":@NO,@"error":@"invalid_run"};NSString*path=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES)[0]stringByAppendingPathComponent:@"ChatServerAcceptance.json"];
  BOOL resume=[command[@"resume"]isEqual:@YES];NSMutableDictionary*saved=nil;
  if([NSFileManager.defaultManager fileExistsAtPath:path]){
   NSData*data=[NSData dataWithContentsOfFile:path];if(resume&&data.length<1024*1024)saved=[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:NULL];
   if(![saved isKindOfClass:NSMutableDictionary.class]||!OR6Live7ResumeValid(saved,run))return @{@"ok":@NO,@"error":@"inspect_existing_checkpoint"};
  }else if(resume)return @{@"ok":@NO,@"error":@"checkpoint_missing"};
  Live7*l=[Live7 new];l->host=[coordinator retain];l->core=[c retain];l->context=[[c valueForKey:@"context"]copy];id composition=[coordinator valueForKey:@"api7"];l->seven=[[composition valueForKey:@"seven"]retain];l->f=[[composition valueForKey:@"f"]retain];l->path=[path copy];
  if(!l->seven||!l->f||!l->context[@"key"]){[l release];return @{@"ok":@NO,@"error":@"native_composition_missing"};}
  l->caps7=[[l->seven valueForKey:@"capabilities"]copy];l->capsF=[[l->f valueForKey:@"capabilities"]copy];l->old7=[[l->seven valueForKey:@"HTTP"]retain];l->oldF=[[l->f valueForKey:@"HTTP"]retain];
  NSMutableSet*a=[[l->caps7 mutableCopy]autorelease];[a addObjectsFromArray:@[@"conversations.rename",@"conversations.archive",@"conversations.unarchive",@"conversations.pin",@"conversations.delete",@"shares.create"]];[l->seven setValue:a forKey:@"capabilities"];
  a=[[l->capsF mutableCopy]autorelease];[a addObjectsFromArray:@[@"chat.sharedLink.delete",@"tools.dataAnalysis",@"tools.study",@"images.create",@"tools.deepResearch",@"tools.deepResearch.cancel",@"chat.continue"]];[l->f setValue:a forKey:@"capabilities"];
  l->state=[[NSMutableDictionary alloc]initWithDictionary:@{@"runId":run,@"marker":[@"ChatGPT X API7 acceptance "stringByAppendingString:run],@"counts":[NSMutableDictionary dictionary],@"steps":[NSMutableDictionary dictionary],@"http":[NSMutableArray array],@"enrolled":@NO,@"uncertain":@NO}];
  if(saved){[l->state release];l->state=[saved retain];[l->state removeObjectForKey:@"capabilitiesRestored"];l->state[@"enrolled"]=@NO;
   NSDictionary*reconciled=saved[@"steps"][@"reconcile"];
   if([saved[@"uncertain"]boolValue]&&![reconciled[@"error"]count]&&OR6Live7Reconciled(reconciled[@"result"],saved[@"uncertainParameters"][@"operationId"])){
    l->state[@"uncertain"]=@NO;l->state[@"recoveredReconciliation"]=@YES;
    if([saved[@"uncertainOperation"]isEqual:@"chat.sharedLink.delete"])l->state[@"shareRevoked"]=@YES;
   }
   NSString*old=saved[@"uncertainOperation"];if([saved[@"uncertain"]boolValue]&&!OR6Live7Mutation(old)){l->state[@"uncertain"]=@NO;l->state[@"readOnlyClassificationCorrected"]=@YES;}
  }
  for(id provider in @[l->seven,l->f]){LiveHTTP*h=[[[LiveHTTP alloc]init]autorelease];h->owner=l;h->next=[[provider valueForKey:@"HTTP"]retain];[provider setValue:h forKey:@"HTTP"];}
  l->state[@"runtimeRecoveryDirectory"]=[[[coordinator valueForKey:@"web"]valueForKey:@"recovery"]valueForKey:@"directory"]?:@"";
  [NSNotificationCenter.defaultCenter addObserver:l selector:@selector(background:)name:UIApplicationWillResignActiveNotification object:nil];live=l;[l save];if(saved){l->busy=YES;[l readOwned:^(NSDictionary*r,NSError*e){(void)r;l->busy=NO;if(e){l->stopped=YES;l->state[@"stopCode"]=e.userInfo[@"code"]?:@"resume_owner_unproven";}else l->state[@"resumedAfterOwnershipRead"]=@YES;[l save];}];}return[l status];
 }
 if(!live)return @{@"ok":@NO,@"error":@"probe_closed"};
 if([action isEqual:@"live7_step"]&&[command[@"step"]isKindOfClass:NSString.class])return[live step:command[@"step"]];
 if([action isEqual:@"live7_end"]){if(live->busy)return @{@"ok":@NO,@"error":@"probe_busy"};[live restore];NSDictionary*r=[[live status]retain];[live release];live=nil;return[r autorelease];}
 return @{@"ok":@NO,@"error":@"unknown_action"};
}
