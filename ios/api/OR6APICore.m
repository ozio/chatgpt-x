#import "OR6APICore.h"
#import "OR6APIOperations.h"
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>

@interface OR6APIInvocation:NSObject<OR6APITask>{
@public id<OR6APITask> child;BOOL terminal;NSUInteger eventCount;
 void(^cancelBlock)(void);
}
- (void)setChild:(id<OR6APITask>)task;
- (void)clear;
@end
@implementation OR6APIInvocation
- (void)setChild:(id<OR6APITask>)task{if(terminal){[task cancel];return;}child=[task retain];}
- (void)cancel{if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self cancel];});return;}if(!terminal&&cancelBlock){void(^b)(void)=[[cancelBlock copy]autorelease];b();}}
- (void)clear{[child release];child=nil;[cancelBlock release];cancelBlock=nil;}
- (void)dealloc{[self clear];[super dealloc];}
@end
static BOOL Text(id s){return[s isKindOfClass:NSString.class]&&[s length]>0&&[s length]<=256;}
static NSSet*Mutations(void){return[NSSet setWithArray:@[@"messages.send",@"messages.edit",@"messages.regenerate",@"messages.retry",@"assets.upload",@"dictation.transcribe"]];}
// A completed temporary exchange is delivered but deliberately absent from
// history. Recover that distinction for explicit retry/reconcile too.
static BOOL EphemeralOperation(OR6APIOperations*journal,NSString*identifier,NSString*scope){
 NSMutableSet*seen=[NSMutableSet set];for(NSUInteger n=0;n<32&&identifier;n++){if([seen containsObject:identifier])return NO;[seen addObject:identifier];NSDictionary*r=[journal record:identifier scope:scope error:NULL];NSString*cmd=r[@"command"];
  if([@[@"messages.send",@"messages.retry"]containsObject:cmd]&&[r[@"state"]isEqual:@"completed"]&&[r[@"result"][@"state"]isEqual:@"completed"]&&[r[@"result"][@"persisted"]isEqual:@NO])return YES;
  if([cmd isEqual:@"messages.send"])return[r[@"request"][@"temporary"]isEqual:@YES];if(![cmd isEqual:@"messages.retry"])return NO;identifier=r[@"request"][@"previousOperationId"];
 }return NO;
}
@implementation OR6APICore
- (id)initWithRegistry:(NSDictionary*)registry provider:(id<OR6APIProvider>)provider journalDirectory:(NSString*)dir error:(NSError**)error{
 if(!(self=[super init]))return nil;_registry=[OR6APIJSONSnapshot(registry,4*1024*1024)retain];
 if(![_registry[@"schemaVersion"]isEqual:@1]||![_registry[@"operations"]isKindOfClass:NSArray.class]||![_registry[@"types"]isKindOfClass:NSDictionary.class]||!provider){if(error)*error=OR6APIError(@"invalid_request",@"none");[self release];return nil;}
 NSMutableDictionary*ops=[NSMutableDictionary dictionary];
 for(NSDictionary*op in _registry[@"operations"]){
  if(![op isKindOfClass:NSDictionary.class]||!Text(op[@"id"])||ops[op[@"id"]]||![op[@"requestSchema"]isKindOfClass:NSDictionary.class]||![op[@"responseSchema"]isKindOfClass:NSDictionary.class]||![op[@"events"]isKindOfClass:NSArray.class]){if(error)*error=OR6APIError(@"invalid_request",@"none");[self release];return nil;}
  ops[op[@"id"]]=op;
 }
 _operations=[ops copy];_provider=[provider retain];_journal=[[OR6APIOperations alloc]initWithDirectory:dir error:error];if(!_journal){[self release];return nil;}_active=[NSMutableSet new];_generation=1;_context=[@{@"key":@"anonymous",@"generation":@1}retain];return self;
}
- (void)setContextKey:(NSString*)key{
 if(!NSThread.isMainThread)return;if(key&&!Text(key))return;[self cancelAll];[_context release];_context=[@{@"key":key?:@"anonymous",@"generation":@(_generation)}retain];
}
- (id<OR6APITask>)perform:(NSString*)name parameters:(NSDictionary*)parameters event:(OR6APIEvent)event completion:(OR6APIReply)reply{
 if(!NSThread.isMainThread){if(reply)reply(nil,OR6APIError(@"invalid_request",@"none"));return nil;}
 NSDictionary*op=Text(name)?_operations[name]:nil;NSDictionary*request=OR6APIJSONSnapshot(parameters,512*1024);
 if(!op||![request isKindOfClass:NSDictionary.class]||!OR6APISchemaCheck(request,op[@"requestSchema"],_registry[@"types"])){if(reply)reply(nil,OR6APIError(@"invalid_request",@"none"));return nil;}
 if(_active.count>=8){if(reply)reply(nil,OR6APIError(@"unavailable",@"none"));return nil;}
 NSString*scope=_context[@"key"],*identifier=request[@"operationId"];BOOL ephemeral=([name isEqual:@"messages.send"]&&[request[@"temporary"]isEqual:@YES])||([name isEqual:@"messages.retry"]&&EphemeralOperation(_journal,request[@"previousOperationId"],scope))||([name isEqual:@"messages.reconcile"]&&EphemeralOperation(_journal,identifier,scope));BOOL mutation=[Mutations()containsObject:name]&&Text(identifier);NSError*storage=nil;
 if([name isEqual:@"messages.retry"]){NSDictionary*prior=[_journal record:request[@"previousOperationId"]scope:scope error:&storage];if(storage||![prior[@"state"]isEqual:@"rejected"]){if(reply)reply(nil,OR6APIError(@"invalid_operation_state",@"none"));return nil;}}
 if([name isEqual:@"messages.reconcile"]){NSDictionary*prior=[_journal record:identifier scope:scope error:&storage];if(storage||!prior){if(reply)reply(nil,OR6APIError(@"invalid_operation_state",@"none"));return nil;}}
 if(mutation&&![_journal reserve:identifier command:name request:request scope:scope error:&storage]){if(reply)reply(nil,storage);return nil;}
 OR6APIInvocation*call=[[[OR6APIInvocation alloc]init]autorelease];[_active addObject:call];NSUInteger generation=_generation;NSDictionary*context=[[_context copy]autorelease];
 OR6APIReply finish=^(NSDictionary*result,NSError*error){
  if(call->terminal)return;call->terminal=YES;
  NSDictionary*safe=error?nil:OR6APIJSONSnapshot(result,8*1024*1024);NSError*problem=error?OR6APIError(error.userInfo[@"code"],error.userInfo[@"dispatch"]):nil;
  if(generation!=_generation){safe=nil;problem=OR6APIError(@"stale_context",mutation?@"possible":@"none");}
  if(!problem&&(![safe isKindOfClass:NSDictionary.class]||!OR6APISchemaCheck(safe,op[@"responseSchema"],_registry[@"types"]))){safe=nil;problem=OR6APIError(@"invalid_response",mutation?@"possible":@"none");}
  if(!problem&&Text(identifier)&&safe[@"operationId"]&&![safe[@"operationId"]isEqual:identifier]){safe=nil;problem=OR6APIError(@"invalid_response",mutation?@"possible":@"none");}
  if(!problem&&safe[@"persisted"]&&([safe[@"persisted"]boolValue]!=[safe[@"state"]isEqual:@"completed"])&&!(ephemeral&&[safe[@"persisted"]isEqual:@NO]&&[safe[@"state"]isEqual:@"completed"])){safe=nil;problem=OR6APIError(@"invalid_response",mutation?@"possible":@"none");}
  if(!problem&&[_provider respondsToSelector:@selector(didValidate:result:context:)]){[_provider didValidate:name result:safe context:context];}
  if(mutation){BOOL message=[name hasPrefix:@"messages."];NSString*state=problem?([problem.userInfo[@"dispatch"]isEqual:@"none"]?@"rejected":@"uncertain"):(!message||[safe[@"persisted"]isEqual:@YES]||(ephemeral&&[safe[@"state"]isEqual:@"completed"])?@"completed":@"uncertain");NSError*j=nil;if(![_journal finish:identifier scope:scope state:state metadata:safe?:@{} error:&j]){safe=nil;problem=OR6APIError(@"storage_failure",@"possible");}}
  NSString*completedDraft=(!problem&&([safe[@"persisted"]isEqual:@YES]||(ephemeral&&[safe[@"state"]isEqual:@"completed"])))?request[@"draftId"]:nil;
  if(!problem&&[name isEqual:@"messages.reconcile"]&&([safe[@"persisted"]isEqual:@YES]||(ephemeral&&[safe[@"state"]isEqual:@"completed"]))){NSError*j=nil;NSDictionary*old=[_journal record:identifier scope:scope error:&j];completedDraft=old[@"request"][@"draftId"];if(![old[@"state"]isEqual:@"completed"]&&![_journal finish:identifier scope:scope state:@"completed"metadata:safe error:&j]){safe=nil;problem=OR6APIError(@"storage_failure",@"possible");}}
  if(!problem&&completedDraft&&[_provider respondsToSelector:@selector(releaseCompletedDraft:context:)])[_provider releaseCompletedDraft:completedDraft context:context];
  id<OR6APITask>child=[[call->child retain]autorelease];[call clear];[_active removeObject:call];if(problem)[child cancel];if(reply)reply(safe,problem);
 };
 call->cancelBlock=[^{finish(nil,OR6APIError(@"cancelled",mutation?@"possible":@"none"));}copy];
 OR6APIEvent receive=^(NSDictionary*e){
  if(call->terminal||generation!=_generation)return;NSDictionary*safe=OR6APIJSONSnapshot(e,1024*1024);NSString*type=safe[@"name"];NSDictionary*schema=nil;
  for(NSDictionary*spec in op[@"events"])if([spec[@"name"]isEqual:type])schema=spec[@"schema"];
  if(++call->eventCount>16384||safe.count!=2||!schema||!safe[@"payload"]||!OR6APISchemaCheck(safe[@"payload"],schema,_registry[@"types"])){finish(nil,OR6APIError(@"invalid_response",mutation?@"possible":@"none"));return;}if(event)event(safe);
 };
 @try{id<OR6APITask>task=[_provider execute:name parameters:request context:context event:receive completion:finish];[call setChild:task];if(!task&&!call->terminal)finish(nil,OR6APIError(@"unavailable",@"none"));}
 @catch(NSException*e){(void)e;finish(nil,OR6APIError(@"invalid_response",mutation?@"possible":@"none"));}
 return call;
}
- (void)cancelAll{if(!NSThread.isMainThread)return;_generation++;NSArray*calls=[[_active allObjects]retain];for(OR6APIInvocation*c in calls)[c cancel];[calls release];}
- (NSDictionary*)diagnostics{return @{@"schema":@1,@"operationCount":@(_operations.count),@"activeCount":@(_active.count),@"generation":@(_generation),@"credentialsExposed":(id)kCFBooleanFalse,@"requiresMac":(id)kCFBooleanFalse};}
- (void)dealloc{[self cancelAll];[_registry release];[_operations release];[_context release];[_provider release];[_active release];[_journal release];[super dealloc];}
@end
