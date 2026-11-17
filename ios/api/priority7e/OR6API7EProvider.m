#import "OR6API7EProvider.h"
#import "OR6API7EPolicy.h"
#import "../priority7/OR6API7Policy.h"
#import "../OR6APIOperations.h"
#import <dispatch/dispatch.h>

@class ECall;
@interface OR6API7EProvider () {
    id<OR6APIProvider> _next;
    id<OR6API7HTTP> _HTTP;
    OR6APIOperations *_journal;
    NSDictionary *_extension,*_operations,*_policy,*_policyContext;
    NSSet *_capabilities;
    NSMutableSet *_calls;
    NSString *_scope;
    NSUInteger _epoch,_requests,_writes;
    BOOL _mutating;
}
- (void)cancel:(ECall *)call;
@end
@interface ECall : NSObject <OR6APITask> {
@public OR6API7EProvider *owner;
    NSString *command;
    NSDictionary *parameters,*context,*plan;
    OR6APIReply reply;
    id<OR6APITask> child;
    NSUInteger serial,completedSteps;
    BOOL terminal,writePossible,reserved,mutation;
}
@end
@implementation ECall
- (void)cancel { if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(),^{[self cancel];}); return; } if (!terminal) [owner cancel:self]; }
- (void)dealloc { [command release];[parameters release];[context release];[plan release];[reply release];[child release];[super dealloc]; }
@end
static NSDictionary *Receipt(ECall *c,BOOL acknowledged,BOOL verified) {
    return @{@"operationId":c->parameters[@"operationId"],@"category":c->plan[@"category"],@"serverAcknowledged":@(acknowledged),@"verified":@(verified),@"completedSteps":@(c->completedSteps)};
}
static BOOL Context(id ctx) { return [ctx isKindOfClass:NSDictionary.class] && [ctx[@"key"] isKindOfClass:NSString.class] && [ctx[@"key"] length] && [ctx[@"key"] length]<=256 && OR6APISchemaCheck(ctx[@"generation"],@{@"type":@"integer",@"minimum":@1},@{}); }
@implementation OR6API7EProvider
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP extension:(NSDictionary *)ext journalDirectory:(NSString *)dir capabilities:(NSSet *)caps error:(NSError **)error {
    if (!(self=[super init])) return nil;
    _extension=[OR6APIJSONSnapshot(ext,1024*1024) retain];
    if (!next || !HTTP || ![caps isKindOfClass:NSSet.class] || ![_extension[@"operations"] isKindOfClass:NSArray.class]) { if(error)*error=OR6APIError(@"invalid_request",@"none");[self release];return nil; }
    NSMutableDictionary *ops=[NSMutableDictionary dictionary];
    for (NSDictionary *op in _extension[@"operations"]) { if (!OR6API7ECommand(op[@"id"]) || ops[op[@"id"]]) { if(error)*error=OR6APIError(@"invalid_request",@"none");[self release];return nil; } ops[op[@"id"]]=op; }
    _operations=[ops copy];_next=[next retain];_HTTP=[HTTP retain];_capabilities=[caps copy];_calls=[NSMutableSet new];_journal=[[OR6APIOperations alloc] initWithDirectory:dir error:error];
    if (!_journal) { [self release]; return nil; } return self;
}
- (BOOL)bindPrivacyPolicy:(NSDictionary *)p context:(NSDictionary *)ctx {
 if(!NSThread.isMainThread||!Context(ctx)||!OR6APISchemaCheck(p,@{@"type":@"object",@"properties":@{@"trainingPermitted":@{@"type":@"boolean"}},@"required":@[@"trainingPermitted"],@"additionalProperties":@NO},@{}))return NO;
 [_policy release];_policy=[OR6APIJSONSnapshot(p,4096)retain];[_policyContext release];_policyContext=[OR6APIJSONSnapshot(ctx,4096)retain];
 for(ECall*c in [[_calls.allObjects copy]autorelease])if(c->mutation&&[c->command hasPrefix:@"privacy.training."]&&(![p[@"trainingPermitted"]isEqual:@YES]||![c->context isEqual:ctx]))[self cancel:c];return YES;
}
- (BOOL)current:(ECall *)c { return !c->terminal && [_scope isEqual:c->context[@"key"]] && _epoch==[c->context[@"generation"] unsignedIntegerValue]; }
- (void)finish:(ECall *)c result:(NSDictionary *)r error:(NSError *)e {
    if (c->terminal) return; [c retain];c->terminal=YES;
    if (c->reserved) {
        // A later unsent step cannot make an earlier acknowledged write unsent.
        if (e && c->completedSteps) e=OR6APIError(e.userInfo[@"code"],@"possible");
        NSString *state=e?([e.userInfo[@"dispatch"] isEqual:@"none"]?@"rejected":@"uncertain"):@"completed";
        NSDictionary *saved=r?@{@"receipt":r,@"plan":c->plan}:@{};
        if (![_journal finish:c->parameters[@"operationId"] scope:c->context[@"key"] state:state metadata:saved error:NULL]) {r=nil;e=OR6APIError(@"storage_failure",@"possible");}
    }
    if(c->mutation)_mutating=NO;
    OR6APIReply callback=[[c->reply copy] autorelease];[c->reply release];c->reply=nil;id<OR6APITask> task=[[c->child retain] autorelease];[c->child release];c->child=nil;[_calls removeObject:c];if(e)[task cancel];if(callback)callback(r,e);[c release];
}
- (void)cancel:(ECall *)c { if (!c->terminal) [self finish:c result:nil error:OR6APIError(@"cancelled",c->writePossible?@"possible":@"none")]; }
- (void)cancelCalls { for (ECall *c in [[_calls.allObjects copy] autorelease]) [self cancel:c]; }
- (void)deactivate { [self cancelCalls];[_policy release];_policy=nil;[_policyContext release];_policyContext=nil; }
- (void)request:(NSURLRequest *)request write:(BOOL)write call:(ECall *)c completion:(OR6APIReply)completion {
    if (!request || !OR6API7EAllowedRequest(request)) { [self finish:c result:nil error:OR6APIError(@"invalid_request",@"none")];return; }
    NSUInteger serial=++c->serial;_requests++;if(write){_writes++;c->writePossible=YES;}
    __block BOOL delivered=NO;
    id<OR6APITask> task=[_HTTP request:request context:c->context completion:^(NSDictionary *v,NSError *e) {
        if (delivered || ![self current:c] || serial!=c->serial) return;delivered=YES;
        if (e) { [self finish:c result:nil error:OR6APIError(e.userInfo[@"code"],c->completedSteps?@"possible":e.userInfo[@"dispatch"])];return; }
        if (![v isKindOfClass:NSDictionary.class] || !OR6APISchemaCheck(v[@"status"],@{@"type":@"integer",@"minimum":@100,@"maximum":@599},@{}) || !OR6APIJSONSnapshot(v,4*1024*1024)) { [self finish:c result:nil error:OR6APIError(@"unknown_wire_shape",write?@"possible":@"none")];return; }
        completion(v,nil);
    }];
    if (c->terminal || serial!=c->serial) [task cancel];
    else if (task) { [c->child release];c->child=[task retain]; }
    else [self finish:c result:nil error:OR6APIError(@"unavailable",write?@"possible":@"none")];
}
- (void)load:(NSString *)op call:(ECall *)c completion:(OR6APIReply)completion {
    if([op isEqual:@"privacy.center"]){[self load:@"privacy.get"call:c completion:^(NSDictionary*settings,NSError*unused){(void)unused;[self load:@"safety.ageStatus"call:c completion:^(NSDictionary*age,NSError*ignored){(void)ignored;completion(OR6API7ECenter(settings,age),nil);}];}];return;}
    if([op isEqual:@"security.policy"]){
     [self request:OR6API7ERead(op) write:NO call:c completion:^(NSDictionary*v,NSError*unused){(void)unused;if([v[@"status"]integerValue]!=200){[self finish:c result:nil error:OR6APIError(@"upstream_error",@"none")];return;}id mfa=v[@"json"];
      [self request:OR6API7ERead(@"security.protection") write:NO call:c completion:^(NSDictionary*w,NSError*ignored){(void)ignored;NSError*e=nil;NSDictionary*r=[w[@"status"]integerValue]==200?OR6API7ESecurity(@{@"mfa":mfa?:NSNull.null,@"protection":w[@"json"]?:NSNull.null},&e):nil;if(!r)[self finish:c result:nil error:e?:OR6APIError(@"upstream_error",@"none")];else completion(r,nil);}];
     }];return;
    }
    [self request:[op isEqual:@"subscription.plans"]?OR6API7EPlansRequest(c->parameters[@"countryCode"]):OR6API7ERead(op) write:NO call:c completion:^(NSDictionary *v,NSError *unused) {
        (void)unused;NSInteger status=[v[@"status"] integerValue];if(status!=200){[self finish:c result:nil error:OR6APIError(status==404?@"not_found":@"upstream_error",@"none")];return;}
        NSError *error=nil;id raw=v[@"json"];NSDictionary *r=[op isEqual:@"subscription.plans"]?OR6API7EPlans(raw,c->parameters[@"countryCode"],&error):[op isEqual:@"safety.ageStatus"]?OR6API7EAge(raw,&error):[op isEqual:@"security.policy"]?OR6API7ESecurity(raw,&error):OR6API7ESettings(raw,&error);
        if (!r) [self finish:c result:nil error:error?:OR6APIError(@"unknown_wire_shape",@"none")]; else completion(r,nil);
    }];
}
- (void)writeStep:(NSUInteger)index call:(ECall *)c {
    if (![self current:c]) return;
    NSArray *steps=c->plan[@"steps"];
    if (index==steps.count) { [self finish:c result:Receipt(c,steps.count>0,steps.count==0) error:nil];return; }
    if([c->command hasPrefix:@"privacy.training."]&&(![_policyContext isEqual:c->context]||![_policy[@"trainingPermitted"]isEqual:@YES])){[self finish:c result:nil error:OR6APIError(@"capability_unavailable",c->writePossible?@"possible":@"none")];return;}
    [self request:OR6API7EWrite(steps[index]) write:YES call:c completion:^(NSDictionary *v,NSError *unused) {
        (void)unused;NSInteger status=[v[@"status"] integerValue];id raw=v[@"json"];BOOL empty=raw==NSNull.null;
        BOOL ack=(status==204 && empty) || (status==200 && [raw isKindOfClass:NSDictionary.class] && !raw[@"error"] && ![raw[@"success"] isEqual:@NO]);
        if (!ack) { [self finish:c result:nil error:OR6APIError(@"uncertain_outcome",@"possible")];return; }
        c->completedSteps++;[self writeStep:index+1 call:c];
    }];
}
- (void)prepare:(ECall *)c snapshot:(NSDictionary *)snapshot {
    if([c->command hasPrefix:@"privacy.training."]&&(![_policyContext isEqual:c->context]||![_policy[@"trainingPermitted"]isEqual:@YES])){[self finish:c result:nil error:OR6APIError(@"capability_unavailable",@"none")];return;}
    NSError *error=nil;NSDictionary *plan=OR6API7EPlan(c->command,c->parameters,snapshot,&error);
    if (!plan) { [self finish:c result:nil error:error];return; }
    c->plan=[plan retain];
    NSDictionary *request=@{@"parameters":c->parameters,@"plan":plan};
    if (![_journal reserve:c->parameters[@"operationId"] command:c->command request:request scope:c->context[@"key"] error:&error]) { [self finish:c result:nil error:error];return; }
    c->reserved=YES;
    if (![_journal finish:c->parameters[@"operationId"] scope:c->context[@"key"] state:@"uncertain" metadata:@{} error:&error]) { [self finish:c result:nil error:error];return; }
    [self writeStep:0 call:c];
}
- (void)mutate:(ECall *)c {
 [self load:@"privacy.get" call:c completion:^(NSDictionary *snapshot,NSError *unused){(void)unused;[self prepare:c snapshot:snapshot];}];
}
- (void)reconcile:(ECall *)c {
    for(ECall *active in _calls)if(active!=c&&active->mutation&&[active->parameters[@"operationId"] isEqual:c->parameters[@"operationId"]]){[self finish:c result:nil error:OR6APIError(@"conflict",@"none")];return;}
    NSError *error=nil;NSDictionary *record=[_journal record:c->parameters[@"operationId"] scope:c->context[@"key"] error:&error];
    if (!record || !OR6API7EMutation(record[@"command"]) || [record[@"state"] isEqual:@"rejected"]) { [self finish:c result:nil error:error?:OR6APIError(@"invalid_operation_state",@"none")];return; }
    NSDictionary *plan=record[@"request"][@"plan"]?:record[@"result"][@"plan"],*old=record[@"result"][@"receipt"];
    if (![plan[@"category"] isEqual:@"privacy"] || ![plan[@"desired"] isKindOfClass:NSDictionary.class] || ![plan[@"steps"] isKindOfClass:NSArray.class] || [plan[@"steps"] count]>2) { [self finish:c result:nil error:OR6APIError(@"storage_failure",@"none")];return; }
    c->plan=[plan retain];c->completedSteps=[old[@"completedSteps"] unsignedIntegerValue];
    [self load:@"privacy.get" call:c completion:^(NSDictionary *snapshot,NSError *unused) {
        (void)unused;if(!OR6API7EMatches(plan,snapshot)){[self finish:c result:nil error:OR6APIError(@"uncertain_outcome",@"possible")];return;}
        NSDictionary *receipt=Receipt(c,[old[@"serverAcknowledged"] isEqual:@YES],YES);
        if(![record[@"state"] isEqual:@"completed"]&&![_journal finish:c->parameters[@"operationId"] scope:c->context[@"key"] state:@"completed" metadata:@{@"plan":plan,@"receipt":receipt} error:NULL]){[self finish:c result:nil error:OR6APIError(@"storage_failure",@"possible")];return;}
        [self finish:c result:receipt error:nil];
    }];
}
- (id<OR6APITask>)execute:(NSString *)op parameters:(NSDictionary *)p context:(NSDictionary *)ctx event:(OR6APIEvent)event completion:(OR6APIReply)reply {
    if(!OR6API7ECommand(op)){if([op isEqual:@"auth.logout"])[self deactivate];return[_next execute:op parameters:p context:ctx event:event completion:reply];}
    if(!NSThread.isMainThread||!Context(ctx)||!OR6APISchemaCheck(p,_operations[op][@"requestSchema"],_extension[@"types"])||(p[@"operationId"]&&(!OR6API7UUID(p[@"operationId"])||![p[@"operationId"] isEqual:[p[@"operationId"] lowercaseString]]))){reply(nil,OR6APIError(@"invalid_request",@"none"));return nil;}
    if(![_scope isEqual:ctx[@"key"]]||_epoch!=[ctx[@"generation"] unsignedIntegerValue]){[self cancelCalls];[_scope release];_scope=[ctx[@"key"] copy];_epoch=[ctx[@"generation"] unsignedIntegerValue];if(![_policyContext isEqual:ctx]){[_policy release];_policy=nil;[_policyContext release];_policyContext=nil;}}
    if(![_capabilities containsObject:op]){reply(nil,OR6APIError(@"capability_unverified",@"none"));return nil;}
    BOOL mutation=OR6API7EMutation(op);
    if(_calls.count>=8||(mutation&&_mutating)){reply(nil,OR6APIError(@"conflict",@"none"));return nil;}
    if(mutation){NSError*error=nil;NSDictionary*old=[_journal record:p[@"operationId"] scope:_scope error:&error];if(old||error){reply(nil,error?:OR6APIError(@"duplicate_operation",@"none"));return nil;}}
    ECall*c=[[[ECall alloc]init]autorelease];c->owner=self;c->command=[op copy];c->parameters=[OR6APIJSONSnapshot(p,512*1024)retain];c->context=[OR6APIJSONSnapshot(ctx,4096)retain];c->reply=[reply copy];c->mutation=mutation;[_calls addObject:c];
    if(mutation){_mutating=YES;[self mutate:c];}else if([op isEqual:@"privacy.reconcile"])[self reconcile:c];else if(OR6API7ERead(op)||[op isEqual:@"privacy.center"]||[op isEqual:@"subscription.plans"])[self load:op call:c completion:^(NSDictionary*r,NSError*e){[self finish:c result:r error:e];}];else{NSError*e=nil;NSDictionary*r=OR6API7EHandoff(op,p,&e);[self finish:c result:r error:e];};return c;
}
- (void)didValidate:(NSString *)op result:(NSDictionary *)r context:(NSDictionary *)ctx {if([_next respondsToSelector:_cmd])[_next didValidate:op result:r context:ctx];}
- (void)releaseCompletedDraft:(NSString *)draft context:(NSDictionary *)ctx {if([_next respondsToSelector:_cmd])[_next releaseCompletedDraft:draft context:ctx];}
- (NSDictionary *)diagnostics {return @{@"activeCount":@(_calls.count),@"requests":@(_requests),@"writeAttempts":@(_writes),@"automaticReplay":@NO,@"credentialsExposed":@NO};}
- (void)dealloc {[self deactivate];[_next release];[_HTTP release];[_journal release];[_extension release];[_operations release];[_capabilities release];[_calls release];[_scope release];[super dealloc];}
@end
