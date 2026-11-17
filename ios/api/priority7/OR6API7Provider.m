#import "OR6API7Provider.h"
#import "OR6API7Policy.h"
#import "../OR6APIOperations.h"
#import "../OR6APIWire.h"
#import <dispatch/dispatch.h>

@class OR6API7Call;
@interface OR6API7Provider () {
    id<OR6APIProvider> _next;
    id<OR6API7HTTP> _HTTP;
    OR6APIOperations *_journal;
    NSDictionary *_extension, *_operations;
    NSSet *_capabilities;
    NSMutableSet *_calls;
    NSString *_scope;
    NSUInteger _epoch, _requests;
}
- (void)cancel:(OR6API7Call *)call;
@end
@interface OR6API7Call : NSObject <OR6APITask> {
@public
    OR6API7Provider *owner;
    NSString *command;
    NSDictionary *parameters, *context;
    OR6APIReply reply;
    id<OR6APITask> child;
    BOOL terminal, dispatched, reserved;
}
@end
@implementation OR6API7Call
- (void)cancel {
    if (!NSThread.isMainThread) { dispatch_async(dispatch_get_main_queue(), ^{ [self cancel]; }); return; }
    if (!terminal) [owner cancel:self];
}
- (void)dealloc { [command release]; [parameters release]; [context release]; [reply release]; [child release]; [super dealloc]; }
@end

static id JSON(NSDictionary *v) { return v[@"json"]==NSNull.null ? nil : v[@"json"]; }
static BOOL Success(NSDictionary *v) {
    id raw=JSON(v); NSInteger status=[v[@"status"] integerValue];
    if (status==204) return !raw;
    return status==200 && [raw isKindOfClass:NSDictionary.class] && !raw[@"error"] &&
        OR6APISchemaCheck(raw[@"success"],@{@"type":@"boolean",@"enum":@[@YES]},@{});
}
static NSDictionary *Receipt(NSString *op, NSDictionary *p, BOOL acknowledged, BOOL verified, NSDictionary *share) {
    NSString *action=[op isEqual:@"shares.create"]?@"share":[op componentsSeparatedByString:@"."].lastObject;
    return @{@"operationId":p[@"operationId"], @"conversationId":p[@"conversationId"], @"action":action,
        @"serverAcknowledged":@(acknowledged), @"verified":@(verified), @"title":p[@"title"]?:(id)NSNull.null,
        @"archived":[op isEqual:@"conversations.archive"]?@YES:[op isEqual:@"conversations.unarchive"]?@NO:(id)NSNull.null,
        @"pinned":p[@"pinned"]?:(id)NSNull.null, @"deleteRequested":@([op isEqual:@"conversations.delete"]), @"share":share?:(id)NSNull.null};
}
static NSDictionary *Summary(id raw, BOOL archiveRequired) {
    if (![raw isKindOfClass:NSDictionary.class] || !OR6API7UUID(raw[@"id"]) ||
        ![raw[@"title"] isKindOfClass:NSString.class] || [raw[@"title"] length]>2000 ||
        !OR6APISchemaCheck(raw[@"is_archived"],@{@"type":@"boolean"},@{}) ||
        (archiveRequired && ![raw[@"is_archived"] isEqual:@YES]) ||
        (raw[@"is_starred"] && !OR6APISchemaCheck(raw[@"is_starred"],@{@"type":@"boolean"},@{}))) return nil;
    return @{@"id":[raw[@"id"] lowercaseString], @"title":raw[@"title"], @"archived":raw[@"is_archived"], @"pinned":raw[@"is_starred"]?:@NO};
}
@implementation OR6API7Provider
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP extension:(NSDictionary *)ext journalDirectory:(NSString *)directory capabilities:(NSSet *)caps error:(NSError **)error {
    if (!(self=[super init])) return nil;
    if (!next || !HTTP || ![caps isKindOfClass:NSSet.class] || ![ext[@"operations"] isKindOfClass:NSArray.class]) {
        if (error) *error=OR6APIError(@"invalid_request",@"none"); [self release]; return nil;
    }
    _extension=[OR6APIJSONSnapshot(ext,1024*1024) retain];
    if (!_extension) { if (error) *error=OR6APIError(@"invalid_request",@"none"); [self release]; return nil; }
    NSMutableDictionary *ops=[NSMutableDictionary dictionary];
    for (NSDictionary *op in _extension[@"operations"]) { if (!OR6API7Command(op[@"id"]) || ops[op[@"id"]]) { if (error) *error=OR6APIError(@"invalid_request",@"none"); [self release]; return nil; } ops[op[@"id"]]=op; }
    _next=[next retain]; _HTTP=[HTTP retain]; _operations=[ops copy];
    _capabilities=[caps copy]; _calls=[NSMutableSet new]; _journal=[[OR6APIOperations alloc] initWithDirectory:directory error:error];
    if (!_extension || !_journal) { [self release]; return nil; } return self;
}
- (BOOL)current:(OR6API7Call *)c { return !c->terminal && [c->context[@"key"] isEqual:_scope] && [c->context[@"generation"] unsignedIntegerValue]==_epoch; }
- (void)finish:(OR6API7Call *)c result:(NSDictionary *)result error:(NSError *)error {
    if (c->terminal) return;
    [c retain]; c->terminal=YES;
    if (c->reserved) {
        NSString *state=error?([error.userInfo[@"dispatch"] isEqual:@"none"]?@"rejected":@"uncertain"):@"completed";
        if (![_journal finish:c->parameters[@"operationId"] scope:c->context[@"key"] state:state metadata:result?:@{} error:NULL]) { result=nil; error=OR6APIError(@"storage_failure",@"possible"); }
    }
    OR6APIReply callback=[[c->reply copy] autorelease]; [c->reply release]; c->reply=nil;
    id<OR6APITask> task=[[c->child retain] autorelease]; [c->child release]; c->child=nil;
    [_calls removeObject:c]; if (error) [task cancel]; if (callback) callback(result,error); [c release];
}
- (void)cancel:(OR6API7Call *)c { if (!c->terminal) [self finish:c result:nil error:OR6APIError(@"cancelled",c->dispatched?@"possible":@"none")]; }
- (void)deactivate { for (OR6API7Call *c in [[_calls.allObjects copy] autorelease]) [self cancel:c]; }
- (void)send:(NSURLRequest *)request call:(OR6API7Call *)c completion:(OR6APIReply)completion {
    if (!request) { [self finish:c result:nil error:OR6APIError(@"invalid_request",@"none")]; return; }
    _requests++; c->dispatched=YES;
    id<OR6APITask> task=[_HTTP request:request context:c->context completion:^(NSDictionary *r,NSError *e) {
        if (![self current:c]) return;
        if (e) [self finish:c result:nil error:OR6APIError(e.userInfo[@"code"],e.userInfo[@"dispatch"])];
        else if (![r isKindOfClass:NSDictionary.class] || !OR6APISchemaCheck(r[@"status"],@{@"type":@"integer",@"minimum":@100,@"maximum":@599},@{}) || !OR6APIJSONSnapshot(r,4*1024*1024)) [self finish:c result:nil error:OR6APIError(@"unknown_wire_shape",@"possible")];
        else completion(r,nil);
    }];
    if (c->terminal) [task cancel];
    else if (task) { [c->child release]; c->child=[task retain]; }
    else [self finish:c result:nil error:OR6APIError(@"uncertain_outcome",@"possible")];
}
- (void)read:(OR6API7Call *)c {
    [self send:OR6API7Request(c->command,c->parameters,NULL) call:c completion:^(NSDictionary *v,NSError *unused) {
        (void)unused; id raw=JSON(v); NSDictionary *result=nil; NSError *error=nil;
        if ([v[@"status"] integerValue]==404) error=OR6APIError(@"not_found",@"none");
        else if ([v[@"status"] integerValue]!=200) error=OR6APIError(@"upstream_error",@"none");
        else if ([c->command isEqual:@"shares.get"]) {
            if (![raw isKindOfClass:NSDictionary.class] || !OR6API7UUID(raw[@"conversation_id"]) || (raw[@"share_id"] && ![raw[@"share_id"] isEqual:c->parameters[@"shareId"]])) error=OR6APIError(@"unknown_wire_shape",@"none");
            else {
                NSDictionary *conversation=OR6API7SharedConversation(raw,c->parameters[@"shareId"],&error);
                if (conversation) result=@{@"shareId":c->parameters[@"shareId"],@"conversation":conversation,@"readOnly":@YES};
            }
        } else {
            BOOL archive=[c->command isEqual:@"archives.list"]; id rows=archive?([raw isKindOfClass:NSDictionary.class]?raw[@"items"]:nil):raw;
            NSUInteger max=archive?[c->parameters[@"limit"] unsignedIntegerValue]:100;
            if (![rows isKindOfClass:NSArray.class] || [rows count]>max) error=OR6APIError(@"unknown_wire_shape",@"none");
            else {
                NSMutableArray *items=[NSMutableArray array]; NSMutableSet *seen=[NSMutableSet set];
                for (id row in rows) {
                    if (!archive && (![row isKindOfClass:NSDictionary.class] || ![row[@"item_type"] isEqual:@"conversation"])) { error=OR6APIError(@"unknown_wire_shape",@"none"); break; }
                    NSDictionary *item=Summary(archive?row:row[@"item"],archive);
                    if (!item || [seen containsObject:item[@"id"]]) { error=OR6APIError(@"unknown_wire_shape",@"none"); break; }
                    [seen addObject:item[@"id"]]; if (!archive) { NSMutableDictionary *p=[[item mutableCopy] autorelease]; p[@"pinned"]=@YES; item=p; } [items addObject:item];
                }
                if (!error && archive) {
                    NSUInteger offset=[c->parameters[@"offset"] unsignedIntegerValue], next=offset+items.count;
                    BOOL valid=OR6APISchemaCheck(raw[@"total"],@{@"type":@"integer",@"minimum":@0,@"maximum":@1000000},@{}) &&
                        [raw[@"offset"] isEqual:c->parameters[@"offset"]] && [raw[@"limit"] isEqual:c->parameters[@"limit"]] &&
                        (!items.count || [raw[@"total"] unsignedIntegerValue]>=next) &&
                        (items.count || [raw[@"total"] unsignedIntegerValue]<=offset) && (next<=10000 || next>=[raw[@"total"] unsignedIntegerValue]);
                    if (!valid) error=OR6APIError(@"unknown_wire_shape",@"none");
                    else result=@{@"items":items,@"nextOffset":next<[raw[@"total"] unsignedIntegerValue]?@(next):(id)NSNull.null};
                } else if (!error) result=@{@"items":items};
            }
        }
        [self finish:c result:result error:error?:result?nil:OR6APIError(@"unknown_wire_shape",@"none")];
    }];
}
- (void)reconcile:(OR6API7Call *)c {
    NSError *error=nil; NSDictionary *record=[_journal record:c->parameters[@"operationId"] scope:_scope error:&error];
    NSString *op=record[@"command"]; NSDictionary *p=record[@"request"], *old=record[@"result"];
    if (!record || !OR6API7Mutation(op) || [record[@"state"] isEqual:@"rejected"]) { [self finish:c result:nil error:error?:OR6APIError(@"invalid_operation_state",@"none")]; return; }
    BOOL share=[op isEqual:@"shares.create"]; NSString *sid=old[@"share"]==NSNull.null?nil:old[@"share"][@"id"];
    if (share && !sid) { [self finish:c result:nil error:OR6APIError(@"uncertain_outcome",@"possible")]; return; }
    NSString *cid=p[@"conversationId"]?:old[@"conversationId"];
    NSURLRequest *request=OR6API7Request(share?@"shares.get":@"conversations.readback", share?@{@"shareId":sid}:@{@"conversationId":cid},NULL);
    [self send:request call:c completion:^(NSDictionary *v,NSError *unused) {
        (void)unused; id raw=JSON(v); BOOL verified=NO;
        NSString *action=old[@"action"]?:[op componentsSeparatedByString:@"."].lastObject;
        if (share) verified=[v[@"status"] integerValue]==200 && [raw isKindOfClass:NSDictionary.class] &&
            [raw[@"current_node"] isEqual:old[@"share"][@"currentNode"]] && [raw[@"share_id"] isEqual:sid];
        else if ([action isEqual:@"delete"]) {
            // A generic 404 can hide lack of access. Only an explicit deletion
            // response qualifies; absence from a history page never does.
            verified=[v[@"status"] integerValue]==404 && [raw isKindOfClass:NSDictionary.class] && [raw[@"error_code"] isEqual:@"conversation_deleted"];
        } else if ([v[@"status"] integerValue]==200 && [raw isKindOfClass:NSDictionary.class] && [raw[@"conversation_id"] isEqual:cid]) {
            if ([action isEqual:@"rename"]) verified=[raw[@"title"] isEqual:p[@"title"]?:old[@"title"]];
            else if ([action isEqual:@"pin"]) verified=OR6APISchemaCheck(raw[@"is_starred"],@{@"type":@"boolean"},@{}) && [raw[@"is_starred"] isEqual:p[@"pinned"]?:old[@"pinned"]];
            else verified=OR6APISchemaCheck(raw[@"is_archived"],@{@"type":@"boolean"},@{}) && [raw[@"is_archived"] isEqual:old?old[@"archived"]:@([action isEqual:@"archive"])];
        }
        if (!verified) { [self finish:c result:nil error:OR6APIError(@"uncertain_outcome",@"possible")]; return; }
        NSMutableDictionary *receipt=[[old?:Receipt(op,p,NO,YES,nil) mutableCopy] autorelease]; receipt[@"verified"]=@YES;
        if (![record[@"state"] isEqual:@"completed"] && ![_journal finish:c->parameters[@"operationId"] scope:c->context[@"key"] state:@"completed" metadata:receipt error:NULL]) { [self finish:c result:nil error:OR6APIError(@"storage_failure",@"possible")]; return; }
        [self finish:c result:receipt error:nil];
    }];
}
- (id<OR6APITask>)execute:(NSString *)op parameters:(NSDictionary *)p context:(NSDictionary *)ctx event:(OR6APIEvent)event completion:(OR6APIReply)reply {
    if (!OR6API7Command(op)) { if ([op isEqual:@"auth.logout"]) [self deactivate]; return [_next execute:op parameters:p context:ctx event:event completion:reply]; }
    if (!NSThread.isMainThread || ![ctx[@"key"] isKindOfClass:NSString.class] || ![ctx[@"key"] length] || [ctx[@"key"] length]>256 ||
        !OR6APISchemaCheck(ctx[@"generation"],@{@"type":@"integer",@"minimum":@1},@{}) ||
        !OR6APISchemaCheck(p,_operations[op][@"requestSchema"],_extension[@"types"])) { reply(nil,OR6APIError(@"invalid_request",@"none")); return nil; }
    if (![_scope isEqual:ctx[@"key"]] || _epoch!=[ctx[@"generation"] unsignedIntegerValue]) { [self deactivate]; [_scope release]; _scope=[ctx[@"key"] copy]; _epoch=[ctx[@"generation"] unsignedIntegerValue]; }
    if (_calls.count>=8) { reply(nil,OR6APIError(@"unavailable",@"none")); return nil; }
    NSMutableDictionary *canonical=[[OR6APIJSONSnapshot(p,512*1024) mutableCopy] autorelease];
    for (NSString *k in @[@"operationId",@"conversationId",@"shareId",@"currentNode"]) if (canonical[k]) {
        if (!OR6API7UUID(canonical[k])) { reply(nil,OR6APIError(@"invalid_request",@"none")); return nil; }
        canonical[k]=[canonical[k] lowercaseString];
    }
    // Keep operation identity exact: Core also validates it in the response.
    if (p[@"operationId"] && ![p[@"operationId"] isEqual:canonical[@"operationId"]]) { reply(nil,OR6APIError(@"invalid_request",@"none")); return nil; }
    p=canonical;
    OR6API7Call *c=[[[OR6API7Call alloc] init] autorelease]; c->owner=self; c->command=[op copy]; c->parameters=[p retain]; c->context=[ctx copy]; c->reply=[reply copy]; [_calls addObject:c];
    if ([op isEqual:@"content.copyCode"]) { NSError *error=nil; NSDictionary *v=OR6API7Code(p,&error); [self finish:c result:v error:error]; return c; }
    if (![_capabilities containsObject:op]) { [self finish:c result:nil error:OR6APIError(@"capability_unverified",@"none")]; return c; }
    if ([op isEqual:@"conversations.reconcile"]) { [self reconcile:c]; return c; }
    if (!OR6API7Mutation(op)) { [self read:c]; return c; }
    NSError *error=nil; NSURLRequest *request=OR6API7Request(op,p,&error);
    if (!request || ![_journal reserve:p[@"operationId"] command:op request:p scope:_scope error:&error]) { [self finish:c result:nil error:error]; return c; }
    c->reserved=YES;
    if (![_journal finish:p[@"operationId"] scope:_scope state:@"uncertain" metadata:@{} error:&error]) { [self finish:c result:nil error:error]; return c; }
    [self send:request call:c completion:^(NSDictionary *v,NSError *unused) {
        (void)unused; NSDictionary *share=nil;
        if ([op isEqual:@"shares.create"]) {
            NSError *e=nil; share=[v[@"status"] integerValue]==200?OR6API7Share(JSON(v),nil,&e):nil;
            if (!share || ![share[@"currentNode"] isEqual:[p[@"currentNode"] lowercaseString]]) { [self finish:c result:nil error:OR6APIError(e.userInfo[@"code"]?:@"unknown_wire_shape",@"possible")]; return; }
        } else if (!([op isEqual:@"conversations.delete"] && [v[@"status"]integerValue]>=200 && [v[@"status"]integerValue]<=299 && !JSON(v)) && !Success(v)) { [self finish:c result:nil error:OR6APIError(@"unknown_wire_shape",@"possible")]; return; }
        [self finish:c result:Receipt(op,p,YES,NO,share) error:nil];
    }];
    return c;
}
- (void)didValidate:(NSString *)op result:(NSDictionary *)r context:(NSDictionary *)ctx { if ([_next respondsToSelector:_cmd]) [_next didValidate:op result:r context:ctx]; }
- (void)releaseCompletedDraft:(NSString *)draft context:(NSDictionary *)ctx { if ([_next respondsToSelector:_cmd]) [_next releaseCompletedDraft:draft context:ctx]; }
- (NSDictionary *)diagnostics { return @{@"activeCount":@(_calls.count), @"requests":@(_requests), @"automaticReplay":@NO, @"credentialsExposed":@NO}; }
- (void)dealloc { [self deactivate]; [_next release]; [_HTTP release]; [_journal release]; [_extension release]; [_operations release]; [_capabilities release]; [_calls release]; [_scope release]; [super dealloc]; }
@end
