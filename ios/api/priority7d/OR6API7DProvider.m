#import "OR6API7DProvider.h"
#import "OR6API7DPolicy.h"
#import "../priority7/OR6API7Policy.h"
#import "../priority8/OR6API8Policy.h"
#import "../OR6APIOperations.h"
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>
@class DCall;
@interface OR6API7DProvider(){
 id<OR6APIProvider>_next;id<OR6API7HTTP>_HTTP;id<OR6API8Generation>_generation;
 OR6APIOperations*_journal;NSDictionary*_extension,*_operations,*_identity,*_identityContext;
 NSSet*_caps;NSMutableSet*_calls;NSMutableDictionary*_pages,*_drafts,*_uploads;NSString*_scope;NSUInteger _epoch,_requests,_writes;
 BOOL _mutating;
}
- (void)cancel:(DCall*)call;
@end
@interface DCall:NSObject<OR6APITask>{@public OR6API7DProvider*owner;NSString*op;NSDictionary*p,*ctx,*plan;OR6APIReply reply;id<OR6APITask>child;NSUInteger serial;BOOL terminal,mutation,reserved,possible;}
@end
@implementation DCall
- (void)cancel{if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self cancel];});return;}if(!terminal)[owner cancel:self];}
- (void)dealloc{[op release];[p release];[ctx release];[plan release];[reply release];[child release];[super dealloc];}
@end
static NSString*ID(void){CFUUIDRef u=CFUUIDCreate(NULL);NSString*s=[(NSString*)CFUUIDCreateString(NULL,u)autorelease];CFRelease(u);return s.lowercaseString;}
static BOOL Context(id c){return[c isKindOfClass:NSDictionary.class]&&[c[@"key"]isKindOfClass:NSString.class]&&[c[@"key"]length]&&[c[@"key"]length]<=256&&OR6APISchemaCheck(c[@"generation"],@{@"type":@"integer",@"minimum":@1},@{});}
static BOOL ValidPlan(id p,NSString*command){
 if(![p isKindOfClass:NSDictionary.class]||(!OR6API7DProjectID(p[@"projectId"])&&(![command isEqual:@"projects.moveConversation"]||p[@"projectId"]!=NSNull.null)))return NO;NSString*kind=p[@"kind"],*expected=@{@"projects.send":@"chat",@"projects.moveConversation":@"move",@"projects.memoryUpdate":@"memory",@"projects.filesAdd":@"files-add",@"projects.filesRemove":@"files-remove"}[command];
 if(!expected||![kind isEqual:expected])return NO;if([kind isEqual:@"memory"])return[p count]==2;
 if([kind isEqual:@"chat"])return[p count]==3&&[p[@"draftId"]isKindOfClass:NSString.class]&&[p[@"draftId"]length]&&[p[@"draftId"]length]<=128;
 if([kind isEqual:@"move"])return[p count]==3&&OR6API7UUID(p[@"conversationId"]);
 NSArray*ids=p[@"fileIds"];if([p count]!=3||![ids isKindOfClass:NSArray.class]||!ids.count||ids.count>4||[[NSSet setWithArray:ids]count]!=ids.count)return NO;for(id f in ids)if(!OR6API8RemoteID(f))return NO;return![kind isEqual:@"files-remove"]||ids.count==1;
}
@implementation OR6API7DProvider
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP extension:(NSDictionary*)ext journalDirectory:(NSString*)dir capabilities:(NSSet*)caps error:(NSError**)error{
 if(!(self=[super init]))return nil;_extension=[OR6APIJSONSnapshot(ext,1024*1024)retain];NSMutableDictionary*ops=[NSMutableDictionary dictionary];
 if(!next||!HTTP||![caps isKindOfClass:NSSet.class]||![_extension[@"operations"]isKindOfClass:NSArray.class]){if(error)*error=OR6APIError(@"invalid_request",@"none");[self release];return nil;}
 for(NSDictionary*o in _extension[@"operations"]){if(!OR6API7DCommand(o[@"id"])||ops[o[@"id"]]){if(error)*error=OR6APIError(@"invalid_request",@"none");[self release];return nil;}ops[o[@"id"]]=o;}
 if(![caps isSubsetOfSet:[NSSet setWithArray:ops.allKeys]]){if(error)*error=OR6APIError(@"invalid_request",@"none");[self release];return nil;}
 _next=[next retain];_HTTP=[HTTP retain];_operations=[ops copy];_caps=[caps copy];_calls=[NSMutableSet new];_pages=[NSMutableDictionary new];_drafts=[NSMutableDictionary new];_uploads=[NSMutableDictionary new];_journal=[[OR6APIOperations alloc]initWithDirectory:dir error:error];if(!_journal){[self release];return nil;}return self;
}
- (BOOL)bindGeneration:(id<OR6API8Generation>)g{if(!NSThread.isMainThread||!g||_calls.count||_drafts.count)return NO;[_generation release];_generation=[g retain];return YES;}
- (BOOL)bindIdentity:(NSDictionary*)i context:(NSDictionary*)ctx{
 NSDictionary*s=@{@"type":@"object",@"properties":@{@"userId":@{@"type":@"string",@"minLength":@1,@"maxLength":@256},@"workspaceId":@{@"type":@[@"string",@"null"],@"maxLength":@256}},@"required":@[@"userId",@"workspaceId"],@"additionalProperties":@NO};
 if(!NSThread.isMainThread||!Context(ctx)||!OR6APISchemaCheck(i,s,@{}))return NO;
 if(![_identity isEqual:i]||![_identityContext isEqual:ctx]){for(DCall*c in [[_calls.allObjects copy]autorelease])[self cancel:c];[_drafts removeAllObjects];[_pages removeAllObjects];[_uploads removeAllObjects];}
 [_identity release];_identity=[OR6APIJSONSnapshot(i,4096)retain];[_identityContext release];_identityContext=[OR6APIJSONSnapshot(ctx,4096)retain];return YES;
}
- (BOOL)bindUploadedFiles:(NSArray*)files context:(NSDictionary*)ctx{
 NSDictionary*schema=_operations[@"projects.filesAdd"][@"requestSchema"][@"properties"][@"files"];
 if(!NSThread.isMainThread||_mutating||![_identityContext isEqual:ctx]||!OR6APISchemaCheck(files,schema,_extension[@"types"]))return NO;
 NSMutableSet*ids=[NSMutableSet set];for(NSDictionary*f in files){if(!OR6API8RemoteID(f[@"fileId"])||[ids containsObject:f[@"fileId"]]||(_uploads[f[@"fileId"]]&&![_uploads[f[@"fileId"]][@"file"]isEqual:f]))return NO;[ids addObject:f[@"fileId"]];}
 NSUInteger additional=0;for(NSString*identifier in ids)if(!_uploads[identifier])additional++;if(_uploads.count+additional>128)return NO;
 for(NSDictionary*f in files)_uploads[f[@"fileId"]]=@{@"file":OR6APIJSONSnapshot(@{@"record":f},4096)[@"record"],@"context":_identityContext};return YES;
}
- (BOOL)current:(DCall*)c{return!c->terminal&&[_scope isEqual:c->ctx[@"key"]]&&_epoch==[c->ctx[@"generation"]unsignedIntegerValue];}
- (void)finish:(DCall*)c result:(NSDictionary*)r error:(NSError*)e{
 if(c->terminal)return;[c retain];c->terminal=YES;
 if(c->reserved){if(e&&c->possible&&![e.userInfo[@"dispatch"]isEqual:@"none"])e=OR6APIError(e.userInfo[@"code"],@"possible");NSString*state=e?([e.userInfo[@"dispatch"]isEqual:@"none"]?@"rejected":@"uncertain"):@"completed";
  if(![_journal finish:c->p[@"operationId"]scope:c->ctx[@"key"]state:state metadata:r?@{@"plan":c->plan,@"receipt":r}:@{} error:NULL]){r=nil;e=OR6APIError(@"storage_failure",@"possible");}}
 if(c->mutation)_mutating=NO;OR6APIReply cb=[[c->reply copy]autorelease];[c->reply release];c->reply=nil;id<OR6APITask>child=[[c->child retain]autorelease];[c->child release];c->child=nil;[_calls removeObject:c];if(e)[child cancel];c->owner=nil;if(cb)cb(r,e);[c release];
}
- (void)cancel:(DCall*)c{[self finish:c result:nil error:OR6APIError(@"cancelled",c->possible?@"possible":@"none")];}
- (void)deactivate{for(DCall*c in [[_calls.allObjects copy]autorelease])[self cancel:c];[_pages removeAllObjects];[_drafts removeAllObjects];[_uploads removeAllObjects];[_identity release];_identity=nil;[_identityContext release];_identityContext=nil;}
- (void)adopt:(id<OR6APITask>)t serial:(NSUInteger)s call:(DCall*)c{if(c->terminal||s!=c->serial)[t cancel];else if(t){[c->child release];c->child=[t retain];}else[self finish:c result:nil error:OR6APIError(@"unavailable",c->possible?@"possible":@"none")];}
- (void)request:(NSURLRequest*)r write:(BOOL)write call:(DCall*)c completion:(OR6APIReply)completion{
 if(!r||!OR6API7DAllowedRequest(r)){[self finish:c result:nil error:OR6APIError(@"invalid_request",@"none")];return;}NSUInteger serial=++c->serial;_requests++;if(write){_writes++;c->possible=YES;}__block BOOL delivered=NO;
 id<OR6APITask>task=[_HTTP request:r context:c->ctx completion:^(NSDictionary*v,NSError*e){
  if(delivered||![self current:c]||serial!=c->serial)return;delivered=YES;
  if(e){[self finish:c result:nil error:OR6APIError(e.userInfo[@"code"],c->possible?(!write?@"possible":e.userInfo[@"dispatch"]):@"none")];return;}
  if(![v isKindOfClass:NSDictionary.class]||!OR6APIJSONSnapshot(v,4*1024*1024)||!OR6APISchemaCheck(v[@"status"],@{@"type":@"integer",@"minimum":@100,@"maximum":@599},@{})){[self finish:c result:nil error:OR6APIError(@"unknown_wire_shape",c->possible?@"possible":@"none")];return;}
  NSInteger status=[v[@"status"]integerValue];if(status<200||status>299){[self finish:c result:nil error:OR6APIError(status==404?@"not_found":@"upstream_error",c->possible?@"possible":@"none")];return;}completion(v,nil);
 }];[self adopt:task serial:serial call:c];
}
- (void)project:(NSString*)project call:(DCall*)c completion:(OR6APIReply)completion{
 [self request:OR6API7DRequest(@"projects.get",@{@"projectId":project},nil,nil,NULL)write:NO call:c completion:^(NSDictionary*v,NSError*unused){(void)unused;NSError*e=nil;NSDictionary*r=OR6API7DProject(v[@"json"],project,&e);if(!r){[self finish:c result:nil error:e];return;}
  NSMutableDictionary*p=[[r mutableCopy]autorelease];BOOL eligible=[_identityContext isEqual:c->ctx]&&[r[@"author"]isEqual:_identity[@"userId"]]&&[r[@"workspace"]isEqual:_identity[@"workspaceId"]]&&[r[@"shared"]isEqual:@NO];p[@"canWrite"]=@(eligible);completion(p,nil);
 }];
}
- (NSDictionary*)publicProject:(NSDictionary*)p{NSMutableDictionary*r=[NSMutableDictionary dictionary];for(NSString*k in @[@"projectId",@"name",@"memoryScope",@"shared",@"canWrite",@"fileCount"])r[k]=p[k];return r;}
- (BOOL)writable:(NSDictionary*)project call:(DCall*)c{if(![project[@"canWrite"]isEqual:@YES]){[self finish:c result:nil error:OR6APIError(@"permission_denied",@"none")];return NO;}return YES;}
- (void)conversation:(NSString*)identifier call:(DCall*)c completion:(OR6APIReply)completion{
 [self request:OR6API7DRequest(@"conversation.get",@{@"conversationId":identifier},nil,nil,NULL)write:NO call:c completion:^(NSDictionary*v,NSError*unused){(void)unused;NSError*e=nil;NSDictionary*r=OR6API7DConversation(v[@"json"],identifier,&e);if(!r)[self finish:c result:nil error:e];else if(![_identityContext isEqual:c->ctx]||![r[@"owner"]isEqual:_identity[@"userId"]])[self finish:c result:nil error:OR6APIError(@"owner_mismatch",@"none")];else completion(r,nil);}];
}
- (BOOL)reserve:(NSDictionary*)plan call:(DCall*)c{
 c->plan=[OR6APIJSONSnapshot(plan,512*1024)retain];NSError*e=nil;if(!c->plan||![_journal reserve:c->p[@"operationId"]command:c->op request:@{@"plan":c->plan}scope:c->ctx[@"key"]error:&e]){[self finish:c result:nil error:e?:OR6APIError(@"invalid_request",@"none")];return NO;}c->reserved=YES;
 if(![_journal finish:c->p[@"operationId"]scope:c->ctx[@"key"]state:@"uncertain"metadata:@{}error:&e]){[self finish:c result:nil error:e];return NO;}return YES;
}
- (NSDictionary*)receipt:(DCall*)c acknowledged:(BOOL)a{return@{@"operationId":c->p[@"operationId"],@"projectId":c->plan[@"projectId"],@"kind":c->plan[@"kind"],@"serverAcknowledged":@(a),@"verified":@YES};}
- (BOOL)matches:(NSDictionary*)plan project:(NSDictionary*)p{
 if(![p[@"projectId"]isEqual:plan[@"projectId"]])return NO;if([plan[@"kind"]isEqual:@"memory"])return[p[@"memoryScope"]isEqual:@"project-only"];
 NSSet*actual=[NSSet setWithArray:[p[@"files"]valueForKey:@"fileId"]];for(NSString*f in plan[@"fileIds"]){BOOL exists=[actual containsObject:f];if([plan[@"kind"]isEqual:@"files-remove"]?exists:!exists)return NO;}return YES;
}
- (void)verify:(DCall*)c acknowledged:(BOOL)ack{
 if([c->plan[@"kind"]isEqual:@"move"]){[self conversation:c->plan[@"conversationId"]call:c completion:^(NSDictionary*v,NSError*unused){(void)unused;if(![v[@"projectId"]isEqual:c->plan[@"projectId"]])[self finish:c result:nil error:OR6APIError(@"uncertain_outcome",@"possible")];else[self finish:c result:[self receipt:c acknowledged:ack]error:nil];}];}
 else[self project:c->plan[@"projectId"]call:c completion:^(NSDictionary*p,NSError*unused){(void)unused;if(![self matches:c->plan project:p])[self finish:c result:nil error:OR6APIError(@"uncertain_outcome",@"possible")];else[self finish:c result:[self receipt:c acknowledged:ack]error:nil];}];
}
- (void)mutateProject:(NSDictionary*)project call:(DCall*)c{
 if(![self writable:project call:c])return;NSString*kind=[c->op isEqual:@"projects.memoryUpdate"]?@"memory":[c->op isEqual:@"projects.filesAdd"]?@"files-add":@"files-remove";NSMutableDictionary*plan=[NSMutableDictionary dictionaryWithDictionary:@{@"kind":kind,@"projectId":c->p[@"projectId"]}];id body=nil;
 if([kind isEqual:@"memory"]){NSMutableDictionary*w=[[project[@"wire"]mutableCopy]autorelease];w[@"memory_scope"]=@"project_v2";body=w;}
 else{NSMutableSet*existing=[NSMutableSet setWithArray:[project[@"files"]valueForKey:@"fileId"]];NSMutableArray*ids=[NSMutableArray array];
  if([kind isEqual:@"files-add"]){NSMutableSet*names=[NSMutableSet setWithArray:[project[@"files"]valueForKey:@"name"]];NSMutableArray*files=[NSMutableArray array];for(NSDictionary*f in c->p[@"files"]){if([existing containsObject:f[@"fileId"]]||[names containsObject:f[@"name"]]||[ids containsObject:f[@"fileId"]]){[self finish:c result:nil error:OR6APIError(@"conflict",@"none")];return;}NSDictionary*bound=_uploads[f[@"fileId"]];if(![bound[@"context"]isEqual:c->ctx]||![bound[@"file"]isEqual:f]){[self finish:c result:nil error:OR6APIError(@"owner_mismatch",@"none")];return;}[names addObject:f[@"name"]];[ids addObject:f[@"fileId"]];NSMutableDictionary*wire=[NSMutableDictionary dictionaryWithDictionary:@{@"file_id":f[@"fileId"],@"name":f[@"name"],@"type":f[@"mediaType"],@"size":f[@"bytes"],@"last_modified":f[@"lastModified"],@"location":@"fs"}];if(f[@"libraryFileId"]!=NSNull.null)wire[@"library_file_id"]=f[@"libraryFileId"];[files addObject:wire];}body=@{@"files":files};}
  else{if(![existing containsObject:c->p[@"fileId"]]){[self finish:c result:nil error:OR6APIError(@"not_found",@"none")];return;}[ids addObject:c->p[@"fileId"]];}plan[@"fileIds"]=ids;
 }
 if(![self reserve:plan call:c])return;if([kind isEqual:@"memory"]&&[project[@"memoryScope"]isEqual:@"project-only"]){[self finish:c result:[self receipt:c acknowledged:NO]error:nil];return;}
 [self request:OR6API7DRequest(c->op,c->p,body,nil,NULL)write:YES call:c completion:^(NSDictionary*v,NSError*unused){(void)unused;id j=v[@"json"];BOOL valid=[j isKindOfClass:NSDictionary.class]&&!j[@"error"]&&![j[@"success"]isEqual:@NO];if([c->op isEqual:@"projects.filesRemove"]&&[v[@"status"]isEqual:@204]&&j==NSNull.null)valid=YES;if(!valid){[self finish:c result:nil error:OR6APIError(@"uncertain_outcome",@"possible")];return;}[self verify:c acknowledged:YES];}];
}
- (void)move:(NSDictionary*)project call:(DCall*)c{
 if(c->p[@"projectId"]!=NSNull.null&&![self writable:project call:c])return;[self conversation:c->p[@"conversationId"]call:c completion:^(NSDictionary*old,NSError*unused){(void)unused;
  void(^ready)(void)=^{NSDictionary*plan=@{@"kind":@"move",@"projectId":c->p[@"projectId"],@"conversationId":c->p[@"conversationId"]};if(![self reserve:plan call:c])return;if([old[@"projectId"]isEqual:c->p[@"projectId"]]){[self finish:c result:[self receipt:c acknowledged:NO]error:nil];return;}
   [self request:OR6API7DRequest(c->op,c->p,nil,nil,NULL)write:YES call:c completion:^(NSDictionary*v,NSError*ignored){(void)ignored;id j=v[@"json"];if(!([v[@"status"]isEqual:@204]&&j==NSNull.null)&&(![j isKindOfClass:NSDictionary.class]||j[@"error"]||[j[@"success"]isEqual:@NO]))[self finish:c result:nil error:OR6APIError(@"uncertain_outcome",@"possible")];else[self verify:c acknowledged:YES];}];
  };
  if(old[@"projectId"]!=NSNull.null&&![old[@"projectId"]isEqual:c->p[@"projectId"]])[self project:old[@"projectId"]call:c completion:^(NSDictionary*source,NSError*ignored){(void)ignored;if([self writable:source call:c])ready();}];else ready();
 }];
}
- (NSDictionary*)binding:(DCall*)c{NSMutableDictionary*b=[[c->p mutableCopy]autorelease];[b removeObjectForKey:@"pageToken"];b[@"operation"]=c->op;return b;}
- (void)page:(DCall*)c{
 id token=c->p[@"pageToken"];NSDictionary*previous=token==NSNull.null?nil:_pages[token],*binding=[self binding:c];if(token!=NSNull.null&&(!previous||![previous[@"binding"]isEqual:binding])){[self finish:c result:nil error:OR6APIError(@"invalid_request",@"none")];return;}
 void(^deliver)(NSArray*,id)=^(NSArray*items,id cursor){NSUInteger limit=[c->p[@"limit"]unsignedIntegerValue];id next=NSNull.null;
  if(cursor!=NSNull.null){if(_pages.count>=128||[previous[@"seen"]count]>=128||[previous[@"seen"]containsObject:cursor]){[self finish:c result:nil error:OR6APIError(@"size_limit",@"none")];return;}NSMutableArray*seen=[NSMutableArray arrayWithArray:previous[@"seen"]?:@[]];[seen addObject:cursor];next=ID();_pages[next]=@{@"binding":binding,@"cursor":cursor,@"seen":seen};}
  if(items.count>limit){[self finish:c result:nil error:OR6APIError(@"unknown_wire_shape",@"none")];return;}[self finish:c result:@{@"projectId":c->p[@"projectId"],@"items":items,@"nextPageToken":next}error:nil];
 };
 if([c->op isEqual:@"projects.filesList"]){
  void(^slice)(NSArray*,NSUInteger)=^(NSArray*files,NSUInteger offset){NSUInteger limit=[c->p[@"limit"]unsignedIntegerValue];if(offset>files.count){[self finish:c result:nil error:OR6APIError(@"invalid_request",@"none")];return;}NSUInteger n=MIN(limit,files.count-offset);id next=NSNull.null;
   if(offset+n<files.count){if(_pages.count>=128){[self finish:c result:nil error:OR6APIError(@"size_limit",@"none")];return;}next=ID();_pages[next]=@{@"binding":binding,@"files":files,@"offset":@(offset+n)};}
   [self finish:c result:@{@"projectId":c->p[@"projectId"],@"items":[files subarrayWithRange:NSMakeRange(offset,n)],@"nextPageToken":next}error:nil];};
  if(previous)slice(previous[@"files"],[previous[@"offset"]unsignedIntegerValue]);else[self project:c->p[@"projectId"]call:c completion:^(NSDictionary*p,NSError*unused){(void)unused;slice(p[@"files"],0);}];return;
 }
 [self request:OR6API7DRequest(c->op,c->p,nil,previous[@"cursor"],NULL)write:NO call:c completion:^(NSDictionary*v,NSError*unused){(void)unused;id j=v[@"json"];if(![j isKindOfClass:NSDictionary.class]){[self finish:c result:nil error:OR6APIError(@"unknown_wire_shape",@"none")];return;}id cursor=j[@"cursor"]?:NSNull.null;NSArray*raw=j[@"items"];if(![raw isKindOfClass:NSArray.class]||raw.count>[c->p[@"limit"]unsignedIntegerValue]||(cursor!=NSNull.null&&(![cursor isKindOfClass:NSString.class]||![cursor length]||[cursor length]>1024))||(!raw.count&&cursor!=NSNull.null)){[self finish:c result:nil error:OR6APIError(@"unknown_wire_shape",@"none")];return;}
  NSMutableArray*out=[NSMutableArray array];NSMutableSet*ids=[NSMutableSet set];for(id x in raw){if(![x isKindOfClass:NSDictionary.class]||!OR6API7UUID(x[@"id"])||![x[@"title"]isKindOfClass:NSString.class]||[x[@"title"]length]>2000||![x[@"gizmo_id"]isEqual:c->p[@"projectId"]]||[ids containsObject:x[@"id"]]){[self finish:c result:nil error:OR6APIError(@"unknown_wire_shape",@"none")];return;}[ids addObject:x[@"id"]];[out addObject:@{@"conversationId":x[@"id"],@"title":x[@"title"]}];}deliver(out,cursor);
 }];
}
- (void)newDraft:(NSDictionary*)project call:(DCall*)c{
 if(![self writable:project call:c])return;if(_drafts.count>=32||_drafts[c->p[@"draftId"]]){[self finish:c result:nil error:OR6APIError(@"conflict",@"none")];return;}
 NSUInteger serial=++c->serial;__block BOOL delivered=NO;id<OR6APITask>t=[_next execute:@"messages.newDraft"parameters:@{@"draftId":c->p[@"draftId"],@"modelId":c->p[@"modelId"],@"parentMessageId":c->p[@"parentMessageId"],@"temporary":@NO}context:c->ctx event:nil completion:^(NSDictionary*r,NSError*e){if(delivered||![self current:c]||serial!=c->serial)return;delivered=YES;if(!e){if(![r[@"draftId"]isEqual:c->p[@"draftId"]]||![r[@"temporary"]isEqual:@NO]||r[@"conversationId"]!=NSNull.null){[self finish:c result:nil error:OR6APIError(@"invalid_response",@"none")];return;}_drafts[c->p[@"draftId"]]=@{@"request":c->p,@"context":c->ctx};}[self finish:c result:r error:e];}];[self adopt:t serial:serial call:c];
}
- (void)send:(NSDictionary*)project call:(DCall*)c{
 if(![self writable:project call:c])return;NSDictionary*binding=_drafts[c->p[@"draftId"]],*d=binding[@"request"];
 if(!_generation||![binding[@"context"]isEqual:c->ctx]||![d[@"projectId"]isEqual:c->p[@"projectId"]]||![d[@"parentMessageId"]isEqual:c->p[@"parentMessageId"]]||![d[@"modelId"]isEqual:c->p[@"modelId"]]){[self finish:c result:nil error:OR6APIError(@"invalid_operation_state",@"none")];return;}
 NSUInteger serial=++c->serial;__block BOOL catalogDelivered=NO;id<OR6APITask>t=[_next execute:@"models.list"parameters:@{}context:c->ctx event:nil completion:^(NSDictionary*r,NSError*e){
  if(catalogDelivered||![self current:c]||serial!=c->serial)return;catalogDelivered=YES;if(e){[self finish:c result:nil error:e];return;}NSString*model=c->p[@"modelId"];if([model isEqual:@"web-current"])model=r[@"selectedModelId"];BOOL found=NO;for(NSDictionary*m in r[@"items"])if([m[@"id"]isEqual:model])found=YES;if(!found){[self finish:c result:nil error:OR6APIError(@"capability_unverified",@"none")];return;}
  NSMutableDictionary*p=[[c->p mutableCopy]autorelease];[p removeObjectForKey:@"projectId"];p[@"temporary"]=@NO;p[@"attachments"]=@[];NSError*error=nil;NSDictionary*base=OR6API8Plan(@"messages.send",p,nil,model,@[],&error);if(!base){[self finish:c result:nil error:error];return;}
  NSMutableDictionary*plan=[[base mutableCopy]autorelease],*body=[[base[@"body"]mutableCopy]autorelease];body[@"gizmo_id"]=c->p[@"projectId"];body[@"conversation_mode"]=@{@"kind":@"gizmo_interaction",@"gizmo_id":c->p[@"projectId"]};plan[@"body"]=body;
  if(![self reserve:@{@"kind":@"chat",@"projectId":c->p[@"projectId"],@"draftId":c->p[@"draftId"]}call:c])return;c->possible=YES;NSUInteger serial=++c->serial;
  __block BOOL delivered=NO;id<OR6APITask>task=[_generation executeNativePlan:plan context:c->ctx event:nil completion:^(NSDictionary*v,NSError*e){if(delivered||![self current:c]||serial!=c->serial)return;delivered=YES;NSDictionary*receipt=v[@"receipt"];if(!e&&(![v[@"streamComplete"]isEqual:@YES]||![receipt[@"operationId"]isEqual:c->p[@"operationId"]]||![receipt[@"persisted"]isEqual:@YES]||![receipt[@"state"]isEqual:@"completed"]||!OR6API7UUID(receipt[@"conversationId"])))e=OR6APIError(@"uncertain_outcome",@"possible");if(e){[self finish:c result:nil error:e];return;}
   [self conversation:receipt[@"conversationId"]call:c completion:^(NSDictionary*conversation,NSError*unused){(void)unused;if(![conversation[@"projectId"]isEqual:c->p[@"projectId"]]){[self finish:c result:nil error:OR6APIError(@"uncertain_outcome",@"possible")];return;}[self releaseCompletedDraft:c->p[@"draftId"]context:c->ctx];[self finish:c result:receipt error:nil];}];
  }];[self adopt:task serial:serial call:c];
 }];[self adopt:t serial:serial call:c];
}
- (void)reconcile:(DCall*)c{
 for(DCall*x in _calls)if(x!=c&&x->mutation&&[x->p[@"operationId"]isEqual:c->p[@"operationId"]]){[self finish:c result:nil error:OR6APIError(@"conflict",@"none")];return;}
 NSError*error=nil;NSDictionary*record=[_journal record:c->p[@"operationId"]scope:c->ctx[@"key"]error:&error],*plan=record[@"request"][@"plan"]?:record[@"result"][@"plan"];
 BOOL chat=[c->op isEqual:@"projects.reconcileChat"];if(!record||!ValidPlan(plan,record[@"command"])||[record[@"state"]isEqual:@"rejected"]||chat!=[plan[@"kind"]isEqual:@"chat"]){[self finish:c result:nil error:error?:OR6APIError(@"invalid_operation_state",@"none")];return;}
 if([record[@"state"]isEqual:@"completed"]){[self finish:c result:record[@"result"][@"receipt"]error:nil];return;}c->plan=[plan retain];
 OR6APIReply done=^(NSDictionary*r,NSError*e){if(![self current:c])return;if(!e&&![_journal finish:c->p[@"operationId"]scope:c->ctx[@"key"]state:@"completed"metadata:@{@"plan":plan,@"receipt":r}error:NULL])e=OR6APIError(@"storage_failure",@"possible");if(!e&&chat)[self releaseCompletedDraft:plan[@"draftId"]context:c->ctx];[self finish:c result:e?nil:r error:e];};
 if(chat){NSUInteger serial=++c->serial;__block BOOL delivered=NO;id<OR6APITask>t=[_next execute:@"messages.reconcile"parameters:c->p context:c->ctx event:nil completion:^(NSDictionary*r,NSError*e){if(delivered||![self current:c]||serial!=c->serial)return;delivered=YES;if(!e&&(![r[@"operationId"]isEqual:c->p[@"operationId"]]||![r[@"persisted"]isEqual:@YES]||![r[@"state"]isEqual:@"completed"]||!OR6API7UUID(r[@"conversationId"])))e=OR6APIError(@"uncertain_outcome",@"possible");if(e){done(nil,e);return;}[self conversation:r[@"conversationId"]call:c completion:^(NSDictionary*conversation,NSError*unused){(void)unused;BOOL matches=[conversation[@"projectId"]isEqual:plan[@"projectId"]];done(matches?r:nil,matches?nil:OR6APIError(@"uncertain_outcome",@"possible"));}];}];[self adopt:t serial:serial call:c];}
 else if([plan[@"kind"]isEqual:@"move"])[self conversation:plan[@"conversationId"]call:c completion:^(NSDictionary*v,NSError*unused){(void)unused;done([v[@"projectId"]isEqual:plan[@"projectId"]]?[self receipt:c acknowledged:NO]:nil,[v[@"projectId"]isEqual:plan[@"projectId"]]?nil:OR6APIError(@"uncertain_outcome",@"possible"));}];
 else[self project:plan[@"projectId"]call:c completion:^(NSDictionary*p,NSError*unused){(void)unused;BOOL ok=[self matches:plan project:p];done(ok?[self receipt:c acknowledged:NO]:nil,ok?nil:OR6APIError(@"uncertain_outcome",@"possible"));}];
}
- (id<OR6APITask>)execute:(NSString*)op parameters:(NSDictionary*)p context:(NSDictionary*)ctx event:(OR6APIEvent)event completion:(OR6APIReply)reply{
 if(!NSThread.isMainThread||!Context(ctx)){reply(nil,OR6APIError(@"invalid_request",@"none"));return nil;}
 if(![_scope isEqual:ctx[@"key"]]||_epoch!=[ctx[@"generation"]unsignedIntegerValue]){NSDictionary*i=[_identityContext isEqual:ctx]?[[_identity retain]autorelease]:nil,*uploads=i?[[_uploads copy]autorelease]:nil;[self deactivate];if(i){_identity=[i retain];_identityContext=[ctx copy];[_uploads addEntriesFromDictionary:uploads];}[_scope release];_scope=[ctx[@"key"]copy];_epoch=[ctx[@"generation"]unsignedIntegerValue];}
 if(!OR6API7DCommand(op)){if([op isEqual:@"auth.logout"])[self deactivate];return[_next execute:op parameters:p context:ctx event:event completion:reply];}
 if(!OR6APISchemaCheck(p,_operations[op][@"requestSchema"],_extension[@"types"])||!OR6APIJSONSnapshot(p,512*1024)||(p[@"projectId"]&&!OR6API7DProjectID(p[@"projectId"])&&(![op isEqual:@"projects.moveConversation"]||p[@"projectId"]!=NSNull.null))||(p[@"parentMessageId"]&&!OR6API7UUID(p[@"parentMessageId"]))||(p[@"operationId"]&&(!OR6API7UUID(p[@"operationId"])||![p[@"operationId"]isEqual:[p[@"operationId"]lowercaseString]]))){reply(nil,OR6APIError(@"invalid_request",@"none"));return nil;}
 if(![_caps containsObject:op]){reply(nil,OR6APIError(@"capability_unverified",@"none"));return nil;}BOOL mutation=OR6API7DMutation(op);if(_calls.count>=8||(mutation&&_mutating)){reply(nil,OR6APIError(@"conflict",@"none"));return nil;}
 if(mutation){NSError*e=nil;NSDictionary*old=[_journal record:p[@"operationId"]scope:ctx[@"key"]error:&e];if(old||e){reply(nil,e?:OR6APIError(@"duplicate_operation",@"none"));return nil;}}
 DCall*c=[[[DCall alloc]init]autorelease];c->owner=self;c->op=[op copy];c->p=[OR6APIJSONSnapshot(p,512*1024)retain];c->ctx=[OR6APIJSONSnapshot(ctx,4096)retain];c->reply=[reply copy];c->mutation=mutation;[_calls addObject:c];if(mutation)_mutating=YES;
 if([@[@"projects.reconcile",@"projects.reconcileChat"]containsObject:op])[self reconcile:c];else if([@[@"projects.conversations",@"projects.filesList"]containsObject:op])[self page:c];else if([op isEqual:@"projects.moveConversation"]&&p[@"projectId"]==NSNull.null)[self move:nil call:c];else[self project:p[@"projectId"]call:c completion:^(NSDictionary*project,NSError*unused){(void)unused;if([op isEqual:@"projects.newDraft"])[self newDraft:project call:c];else if([op isEqual:@"projects.send"])[self send:project call:c];else if([op isEqual:@"projects.moveConversation"])[self move:project call:c];else if(mutation)[self mutateProject:project call:c];else[self finish:c result:[self publicProject:project]error:nil];}];return c;
}
- (void)didValidate:(NSString*)o result:(NSDictionary*)r context:(NSDictionary*)ctx{if([_next respondsToSelector:_cmd])[_next didValidate:o result:r context:ctx];}
- (void)releaseCompletedDraft:(NSString*)d context:(NSDictionary*)ctx{if([_drafts[d][@"context"]isEqual:ctx])[_drafts removeObjectForKey:d];if([_next respondsToSelector:_cmd])[_next releaseCompletedDraft:d context:ctx];}
- (NSDictionary*)diagnostics{return@{@"activeCount":@(_calls.count),@"identityBound":_identityContext?@YES:@NO,@"pageTokens":@(_pages.count),@"drafts":@(_drafts.count),@"uploadedFiles":@(_uploads.count),@"requests":@(_requests),@"writeAttempts":@(_writes),@"automaticReplay":@NO,@"credentialsExposed":@NO};}
- (void)dealloc{[self deactivate];[_next release];[_HTTP release];[_generation release];[_journal release];[_extension release];[_operations release];[_caps release];[_calls release];[_pages release];[_drafts release];[_uploads release];[_scope release];[super dealloc];}
@end
