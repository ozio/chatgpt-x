#import "OR6API8Provider.h"
#import "OR6API8Policy.h"
#import "OR6API8Media.h"
#import <dispatch/dispatch.h>
@class OR6API8Provider;
@interface O8Call:NSObject<OR6APITask>{@public OR6API8Provider*owner;NSString*op;NSDictionary*p,*context,*message;OR6APIReply reply;OR6APIEvent event;id<OR6APITask>child;BOOL terminal,dispatched;}
@end
@interface OR6API8Provider(){id<OR6APIProvider>_next;id<OR6API8Generation>_generation;OR6API8Media*_media;NSSet*_capabilities;NSMutableSet*_calls;NSMutableDictionary*_status,*_models;NSString*_scope,*_selected;NSUInteger _epoch;}
- (void)finish:(O8Call*)call result:(NSDictionary*)result error:(NSError*)error;
@end
@implementation O8Call
- (void)cancel{if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self cancel];});return;}[owner finish:self result:nil error:OR6APIError(@"cancelled",dispatched?@"possible":@"none")];}
- (void)dealloc{[op release];[p release];[context release];[message release];[reply release];[event release];[child release];[super dealloc];}
@end
static BOOL Emits8(NSString*op){return[op isEqual:@"messages.send"]||[op isEqual:@"messages.edit"]||[op isEqual:@"messages.regenerate"]||[op isEqual:@"messages.retry"];}
@implementation OR6API8Provider
- (id)initWithNext:(id<OR6APIProvider>)next generation:(id<OR6API8Generation>)generation media:(OR6API8Media*)media capabilities:(NSSet*)caps {
 if((self=[super init])){NSSet*known=[NSSet setWithArray:@[@"temporary",@"edit",@"regenerate",@"model",@"attachments",@"search",@"translate"]];if(!next||![caps isKindOfClass:NSSet.class]||![caps isSubsetOfSet:known]||(caps.count&&!generation)){[self release];return nil;}_next=[next retain];_generation=[generation retain];_media=[media retain];_capabilities=[caps copy];_calls=[NSMutableSet new];_status=[NSMutableDictionary new];_models=[NSMutableDictionary new];}return self;
}
- (BOOL)current:(O8Call*)c{return !c->terminal&&[c->context[@"key"]isEqual:_scope]&&[c->context[@"generation"]unsignedIntegerValue]==_epoch;}
- (void)status:(O8Call*)c phase:(NSString*)phase label:(NSString*)label {
 if(!c->p[@"operationId"])return;NSDictionary*old=_status[c->p[@"operationId"]];if(_status.count>=64&&!old)[_status removeObjectForKey:_status.allKeys[0]];
 NSDictionary*s=@{@"operationId":c->p[@"operationId"],@"phase":phase,@"label":label?:@"",@"sequence":@([old[@"sequence"]unsignedIntegerValue]+1)};_status[c->p[@"operationId"]]=s;
 // Tool operations have no status event in their public schema; polling still
 // sees the same truthful lifecycle, without invented reasoning text.
 if(c->event&&Emits8(c->op)){OR6APIEvent cb=[[c->event copy]autorelease];cb(@{@"name":@"status",@"payload":s});}
}
- (void)status:(O8Call*)c phase:(NSString*)phase{[self status:c phase:phase label:nil];}
- (void)finish:(O8Call*)c result:(NSDictionary*)r error:(NSError*)e {
 if(c->terminal)return;[c retain];BOOL current=[self current:c];c->terminal=YES;
 if(!current){r=nil;e=OR6APIError(@"stale_context",c->dispatched?@"possible":@"none");}
 if(current&&c->p[@"operationId"]&&([c->op hasPrefix:@"messages."]||[@[@"search.web",@"translation.translate"]containsObject:c->op]))[self status:c phase:e?([e.userInfo[@"code"]isEqual:@"cancelled"]?@"interrupted":@"failed"):([r[@"persisted"]isEqual:@NO]&&![r[@"state"]isEqual:@"completed"]?@"unknown":@"complete")];
 id<OR6APITask>task=[[c->child retain]autorelease];[c->child release];c->child=nil;if(e)[task cancel];
 OR6APIReply cb=[[c->reply copy]autorelease];[c->reply release];c->reply=nil;[c->event release];c->event=nil;c->owner=nil;[_calls removeObject:c];if(cb)cb(r,e);[c release];
}
- (void)adopt:(id<OR6APITask>)task call:(O8Call*)c{if(c->terminal)[task cancel];else if(task)c->child=[task retain];else[self finish:c result:nil error:OR6APIError(@"unavailable",@"none")];}
- (void)deactivate{for(O8Call*c in [[_calls.allObjects copy]autorelease])[c cancel];}
- (void)didValidate:(NSString*)op result:(NSDictionary*)r context:(NSDictionary*)ctx {
 if([ctx[@"key"]isEqual:_scope]){
  if([op isEqual:@"models.list"]){[_models removeAllObjects];for(NSDictionary*m in r[@"items"])_models[m[@"id"]]=m;[_selected release];_selected=([r[@"selectedModelId"]isKindOfClass:NSString.class]&&_models[r[@"selectedModelId"]])?[r[@"selectedModelId"]copy]:nil;}
  if([op isEqual:@"models.select"]){[_selected release];_selected=[r[@"modelId"]copy];}
 }
 if([_next respondsToSelector:@selector(didValidate:result:context:)])[_next didValidate:op result:r context:ctx];
}
- (void)releaseCompletedDraft:(NSString*)d context:(NSDictionary*)ctx{if([_next respondsToSelector:@selector(releaseCompletedDraft:context:)])[_next releaseCompletedDraft:d context:ctx];}
- (void)receive:(NSDictionary*)e call:(O8Call*)c {
 if(![self current:c])return;
 if([e[@"name"]isEqual:@"status"]){NSString*phase=e[@"payload"][@"phase"];if([@[@"thinking",@"searching",@"writing"]containsObject:phase])[self status:c phase:phase label:e[@"payload"][@"label"]];return;}
 if([e[@"name"]isEqual:@"message"]){c->dispatched=YES;if([e[@"payload"][@"text"]length])[self status:c phase:@"writing"];}
 else if([e[@"name"]isEqual:@"state"]){NSString*s=e[@"payload"][@"state"];if([@[@"dispatching",@"streaming",@"reconciling"]containsObject:s])c->dispatched=YES;}
 if(c->event&&Emits8(c->op)){OR6APIEvent cb=[[c->event copy]autorelease];cb(e);}
}
- (void)readyPlan:(O8Call*)c conversation:(NSDictionary*)conversation {
 if(![self current:c])return;NSString*model=c->p[@"modelId"];
 if(!model||[model isEqual:@"web-current"])model=_selected;
 if(!model||!_models[model]){[self finish:c result:nil error:OR6APIError(@"capability_unverified",@"none")];return;}
 id effort=c->p[@"thinkingEffort"];BOOL validEffort=!effort||effort==NSNull.null;
 for(NSDictionary*e in _models[model][@"efforts"])if([e[@"id"]isEqual:effort])validEffort=YES;
 if(!validEffort){[self finish:c result:nil error:OR6APIError(@"capability_unverified",@"none")];return;}
 NSError*error=nil;NSArray*attachments=@[];
 if([c->p[@"attachments"]count])attachments=[_media attachments:c->p[@"attachments"]draft:c->p[@"draftId"]context:c->context error:&error];
 NSDictionary*plan=attachments?OR6API8Plan(c->op,c->p,conversation,model,attachments,&error):nil;
 if(!plan){[self finish:c result:nil error:error?:OR6APIError(@"invalid_request",@"none")];return;}
 if([plan[@"body"][@"messages"]count]){NSDictionary*last=[plan[@"body"][@"messages"]lastObject];if(([last[@"metadata"][@"attachments"]count]||[last[@"content"][@"content_type"]isEqual:@"multimodal_text"])&&![_capabilities containsObject:@"attachments"]){[self finish:c result:nil error:OR6APIError(@"capability_unverified",@"none")];return;}}
 [self status:c phase:@"preparing"];if(![self current:c])return;c->dispatched=YES;
 id<OR6APITask>task=[_generation executeNativePlan:plan context:c->context event:^(NSDictionary*e){[self receive:e call:c];}completion:^(NSDictionary*result,NSError*e){
  if(![self current:c])return;if(e){[self finish:c result:nil error:e];return;}
  NSDictionary*receipt=result[@"receipt"],*message=result[@"assistant"];
  if(![result[@"streamComplete"]boolValue]||![receipt[@"operationId"]isEqual:c->p[@"operationId"]]){[self finish:c result:nil error:OR6APIError(@"uncertain_outcome",@"possible")];return;}
  if([c->op isEqual:@"translation.translate"]){NSString*text=message[@"text"];if(![text isKindOfClass:NSString.class]||text.length>16000){[self finish:c result:nil error:OR6APIError(@"invalid_response",@"possible")];return;}[self finish:c result:@{@"operationId":c->p[@"operationId"],@"text":text,@"targetLanguage":c->p[@"targetLanguage"]}error:nil];}
  else if([c->op isEqual:@"search.web"]){NSError*problem=nil;NSArray*sources=OR6API8Sources(message,&problem);if(!sources||![message[@"text"]isKindOfClass:NSString.class]){[self finish:c result:nil error:OR6APIError(problem.userInfo[@"code"]?:@"invalid_response",@"possible")];return;}[self finish:c result:@{@"operationId":c->p[@"operationId"],@"text":message[@"text"],@"sources":sources}error:nil];}
  else[self finish:c result:receipt error:nil];
 }];[self adopt:task call:c];
}
- (void)plan:(O8Call*)c conversation:(NSDictionary*)conversation {
 if(![_media needsRemotePreparation:c->p[@"attachments"]]){[self readyPlan:c conversation:conversation];return;}
 id<OR6APITask>task=[_media prepareRemoteAssets:c->p[@"attachments"]draft:c->p[@"draftId"]context:c->context completion:^(NSDictionary*r,NSError*e){
  if(![self current:c])return;[c->child release];c->child=nil;
  if(e||![r[@"ready"]isEqual:@YES])[self finish:c result:nil error:e?:OR6APIError(@"invalid_response",@"none")];else[self readyPlan:c conversation:conversation];
 }];if(c->terminal)[task cancel];else if(!c->child)[self adopt:task call:c];
}
- (void)generation:(O8Call*)c {
 BOOL needsConversation=[@[@"messages.edit",@"messages.regenerate"]containsObject:c->op]||([c->op isEqual:@"search.web"]&&[c->p[@"conversationId"]isKindOfClass:NSString.class]);
 if(!needsConversation){[self plan:c conversation:nil];return;}
 id<OR6APITask>task=[_next execute:@"history.get"parameters:@{@"conversationId":c->p[@"conversationId"]}context:c->context event:nil completion:^(NSDictionary*r,NSError*e){
  if(![self current:c])return;[c->child release];c->child=nil;if(e)[self finish:c result:nil error:e];else[self plan:c conversation:r];
 }];if(!c->terminal&&!c->child)[self adopt:task call:c];
}
- (id<OR6APITask>)execute:(NSString*)op parameters:(NSDictionary*)p context:(NSDictionary*)ctx event:(OR6APIEvent)event completion:(OR6APIReply)reply {
 if(!NSThread.isMainThread){reply(nil,OR6APIError(@"invalid_request",@"none"));return nil;}
 if(![_scope isEqual:ctx[@"key"]]||_epoch!=[ctx[@"generation"]unsignedIntegerValue]){[self deactivate];BOOL ownerChanged=![_scope isEqual:ctx[@"key"]];if(ownerChanged){[_status removeAllObjects];[_models removeAllObjects];[_selected release];_selected=nil;}[_scope release];_scope=[ctx[@"key"]copy];_epoch=[ctx[@"generation"]unsignedIntegerValue];}
 O8Call*c=[[[O8Call alloc]init]autorelease];c->owner=self;c->op=[op copy];c->p=[p copy];c->context=[ctx copy];c->event=[event copy];c->reply=[reply copy];[_calls addObject:c];
 if([op isEqual:@"generation.status"]){NSDictionary*s=_status[p[@"operationId"]];[self finish:c result:s error:s?nil:OR6APIError(@"not_found",@"none")];return c;}
 NSString*cap=[@{@"messages.edit":@"edit",@"messages.regenerate":@"regenerate",@"search.web":@"search",@"translation.translate":@"translate"}objectForKey:op];
 BOOL planned=cap!=nil;
 if([op isEqual:@"messages.send"]){if([p[@"temporary"]boolValue])cap=@"temporary";else if([p[@"attachments"]count])cap=@"attachments";else if(![p[@"modelId"]isEqual:@"web-current"]||(p[@"thinkingEffort"]&&p[@"thinkingEffort"]!=NSNull.null))cap=@"model";planned=cap!=nil;}
 if(planned){
  NSMutableArray*required=[NSMutableArray arrayWithObject:cap];if([p[@"temporary"]boolValue])[required addObject:@"temporary"];if([p[@"attachments"]count])[required addObject:@"attachments"];
  if(![[NSSet setWithArray:required]isSubsetOfSet:_capabilities]){[self finish:c result:nil error:OR6APIError(@"capability_unverified",@"none")];return c;}
  if(!_models.count){id<OR6APITask>task=[_next execute:@"models.list"parameters:@{}context:ctx event:nil completion:^(NSDictionary*r,NSError*e){if(![self current:c])return;[c->child release];c->child=nil;if(e)[self finish:c result:nil error:e];else{[self didValidate:@"models.list"result:r context:ctx];[self generation:c];}}];if(!c->terminal&&!c->child)[self adopt:task call:c];}
  else[self generation:c];return c;
 }
 if([op isEqual:@"auth.logout"]){for(O8Call*other in [[_calls.allObjects copy]autorelease])if(other!=c)[other cancel];[_models removeAllObjects];[_status removeAllObjects];[_selected release];_selected=nil;}
 id<OR6APITask>task=[_next execute:op parameters:p context:ctx event:^(NSDictionary*e){[self receive:e call:c];}completion:^(NSDictionary*r,NSError*e){[self finish:c result:r error:e];}];[self adopt:task call:c];return c;
}
- (void)dealloc{[self deactivate];[_next release];[_generation release];[_media release];[_capabilities release];[_calls release];[_status release];[_models release];[_scope release];[_selected release];[super dealloc];}
@end
