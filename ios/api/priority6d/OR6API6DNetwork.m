#import "OR6API6DNetwork.h"
#import "OR6API6DPolicy.h"
#import "../OR6APIWebAdapter.h"
#import "../OR6APIHTTP.h"
#import <dispatch/dispatch.h>

// Private concrete session boundary; never exposes WebSession or credentials.
@interface OR6APIWebAdapter(OR6API6DPrivateLogout)
- (BOOL)or6dSignOutForKey:(NSString*)key generation:(NSUInteger)generation user:(NSString*)user;
@end
@implementation OR6APIWebAdapter(OR6API6DPrivateLogout)
- (BOOL)or6dSignOutForKey:(NSString*)key generation:(NSUInteger)generation user:(NSString*)user{if(!NSThread.isMainThread||generation!=self.credentialGeneration||![key isEqual:self.contextKey]||![self chatMatchesOwner:user])return NO;return[_session signOut];}
@end
@interface OR6API6DNetworkTask : NSObject <OR6APITask> { BOOL _cancelled,_terminal; }
- (BOOL)cancelled;
- (BOOL)complete;
@end
@implementation OR6API6DNetworkTask
- (void)cancel { @synchronized(self) { if(!_terminal)_cancelled=YES; } }
- (BOOL)cancelled { @synchronized(self) { return _cancelled; } }
- (BOOL)complete { @synchronized(self) { _terminal=YES;return!_cancelled; } }
@end

@implementation OR6API6DNetwork
- (void)observePolicy:(id)raw path:(NSString *)path context:(NSDictionary *)ctx generation:(NSUInteger)generation {
    if (![raw isKindOfClass:NSDictionary.class]) return;
    NSMutableDictionary *policy=[NSMutableDictionary dictionary];
    if ([path isEqual:@"/backend-api/user_system_messages"]) {
        id tools=raw[@"disabled_tools"]; BOOL valid=[tools isKindOfClass:NSArray.class] && [tools count]<=64;
        if (valid) for (id value in tools) if (![value isKindOfClass:NSString.class] || ![value length] || [value length]>128) valid=NO;
        if (valid) policy[@"webSearch"]=@YES;
    } else if ([path isEqual:@"/backend-api/settings/user"]) {
        id s=raw[@"settings"]; if (![s isKindOfClass:NSDictionary.class]) return;
        id locks=s[@"amphora_locks"]; if (locks && locks!=NSNull.null && ![locks isKindOfClass:NSDictionary.class]) return;
        NSDictionary *map=@{@"image_gen_enabled":@"imageCreation",@"precise_location_allowed":@"location",@"golden_hour":@"automaticMemoryManagement"};
        for (NSString *key in map) {
            id value=s[key], locked=[locks isKindOfClass:NSDictionary.class]?locks[key]:nil;
            BOOL known=OR6APISchemaCheck(value,@{@"type":@"boolean"},@{}) && (!locked || OR6APISchemaCheck(locked,@{@"type":@"boolean"},@{}));
            if (known) policy[map[key]]=@(![locked isEqual:@YES]);
        }
        id restricted=s[@"precise_location_restricted_reason"];
        if (restricted && restricted!=NSNull.null && (![restricted isKindOfClass:NSString.class] || [restricted length])) policy[@"location"]=@NO;
    }
    if (!policy.count) return;
    if (![_policyContext isEqual:ctx] || _policyCredentialGeneration!=generation) {
        [_observedPolicy release]; _observedPolicy=[NSMutableDictionary new];
        [_policyContext release]; _policyContext=[OR6APIJSONSnapshot(ctx,4096) retain];
    }
    _policyCredentialGeneration=generation; _policyAt=NSProcessInfo.processInfo.systemUptime;
    for (NSString *key in policy) _observedPolicy[key]=@{@"allowed":policy[key],@"at":@(_policyAt)};
}
- (NSDictionary *)trustedPreferencesPolicyForContext:(NSDictionary *)ctx {
    NSTimeInterval age=NSProcessInfo.processInfo.systemUptime-_policyAt;
    if (!NSThread.isMainThread || ![_policyContext isEqual:ctx] || _policyCredentialGeneration!=_adapter.credentialGeneration || ![ctx[@"key"]isEqual:_adapter.contextKey] || age<0 || age>300) return nil;
    NSMutableDictionary *out=[NSMutableDictionary dictionary];
    for (NSString *key in _observedPolicy) { NSDictionary *observation=_observedPolicy[key]; NSTimeInterval fieldAge=NSProcessInfo.processInfo.systemUptime-[observation[@"at"]doubleValue]; if (fieldAge>=0 && fieldAge<=300) out[key]=observation[@"allowed"]; }
    return OR6APIJSONSnapshot(out,4096);
}
- (id)initWithAdapter:(OR6APIWebAdapter *)adapter roots:(NSString *)roots {
    if ((self=[super init])) {
        if (!adapter || !roots.length) { [self release]; return nil; }
        _adapter=[adapter retain]; _roots=[roots copy];
    }
    return self;
}
- (id<OR6APITask>)request:(NSURLRequest *)request context:(NSDictionary *)ctx completion:(OR6APIReply)reply {
    OR6API6DNetworkTask *task=[[[OR6API6DNetworkTask alloc] init] autorelease];
    if(!NSThread.isMainThread){if(reply)dispatch_async(dispatch_get_main_queue(),^{reply(nil,OR6APIError(@"invalid_request",@"none"));});return task;}ctx=OR6APIJSONSnapshot(ctx,4096);
    BOOL account=[@[@"/backend-api/accounts/data_export",@"/backend-api/accounts/deactivate"]containsObject:request.URL.path],logout=[request.URL.path isEqual:@"/backend-api/accounts/deactivate"],ownerBound=account||[request.URL.path hasPrefix:@"/backend-api/conversation/"];
    if (!OR6API6DAllowedRequest(request) || ![ctx[@"key"]isKindOfClass:NSString.class] || ![ctx[@"key"]length] || [ctx[@"key"]length]>256 || !OR6APISchemaCheck(ctx[@"generation"],@{@"type":@"integer",@"minimum":@1},@{})) { reply(nil,OR6APIError(@"invalid_request",@"none")); return task; }
    if(ownerBound&&(![ctx[@"userId"]isKindOfClass:NSString.class]||![_adapter chatMatchesOwner:ctx[@"userId"]])){reply(nil,OR6APIError(@"owner_mismatch",@"none"));return task;}
    NSMutableURLRequest *r=[[request mutableCopy] autorelease];
    [r setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [r setValue:@"https://chatgpt.com" forHTTPHeaderField:@"Origin"];
    [r setValue:@"https://chatgpt.com/" forHTTPHeaderField:@"Referer"];
    NSUInteger generation=_adapter.credentialGeneration;
    NSURLRequest *authorized=[_adapter authorizeChatRequest:r expectedKey:ctx[@"key"]];
    if (!authorized) { reply(nil,OR6APIError(@"not_authenticated",@"none")); return task; }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
        NSAutoreleasePool *pool=[NSAutoreleasePool new]; NSError *network=nil;
        NSDictionary *response=OR6APIHTTPPerform(authorized,_roots,[NSSet setWithObject:@"chatgpt.com"],
            @{@"connectTimeout":@15,@"idleTimeout":@25,@"overallTimeout":@45,@"collectBody":@YES,@"maxRequestBytes":@(128*1024),@"maxDecodedBytes":@(4*1024*1024)},
            ^BOOL { return task.cancelled; },nil,nil,&network);
        id bytes=response[@"requestBytesSent"]?:network.userInfo[@"requestBytesSent"];
        NSString *sent=[bytes isKindOfClass:NSNumber.class] && ![bytes unsignedLongLongValue]?@"none":@"possible";
        NSInteger status=[response[@"status"] integerValue]; NSError *error=nil; id json=nil;
        if (!response) error=OR6APIError(task.cancelled?@"cancelled":@"network_unavailable",sent);
        else if (![response[@"certificateVerified"] boolValue]) error=OR6APIError(@"tls",sent);
        else if ((status<200 || status>299) && status!=404&&status!=410&&!(account&&(status==400||status==401||status==403||status==409))) error=OR6APIError(status==401?@"not_authenticated":status==403?@"service_challenge":status==429?@"rate_limited":@"upstream_error",sent);
        else {
            NSData *data=response[@"data"];
            if (data.length) json=[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            if (data.length && ![json isKindOfClass:NSDictionary.class] && ![json isKindOfClass:NSArray.class]) error=OR6APIError(@"unknown_wire_shape",sent);
            if (!data.length && [r.HTTPMethod isEqual:@"GET"] && status!=404&&status!=410) error=OR6APIError(@"unknown_wire_shape",sent);
        }
        NSDictionary *result=@{@"status":@(status), @"json":json?:(id)NSNull.null};
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![task complete]) { reply(nil,OR6APIError(@"cancelled",sent)); return; }
            if (generation!=_adapter.credentialGeneration || ![ctx[@"key"] isEqual:_adapter.contextKey]||(ownerBound&&![_adapter chatMatchesOwner:ctx[@"userId"]])) { reply(nil,OR6APIError(@"stale_context",sent)); return; }
            if (!error && ![_adapter acceptChatCookies:response[@"setCookies"]?:@[] expectedKey:ctx[@"key"] generation:generation]) { reply(nil,OR6APIError(@"storage_failure",sent)); return; }
            if (!error && status>=200 && status<=299) [self observePolicy:json path:r.URL.path context:ctx generation:generation];
            reply(error?nil:result,error);
            // Any public/peer completion may install a replacement login. Recheck
            // the captured concrete credential generation, key and owner here.
            BOOL acknowledged=status>=200&&status<=299&&(json==nil||([json isKindOfClass:NSDictionary.class]&&!json[@"error"]&&!json[@"error_code"]&&![json[@"success"]isEqual:@NO]));
            if(!error&&logout&&acknowledged&&!task.cancelled)[_adapter or6dSignOutForKey:ctx[@"key"]generation:generation user:ctx[@"userId"]];
        });
        [pool drain];
    });
    return task;
}
- (void)dealloc { [_adapter release]; [_roots release]; [_policyContext release]; [_observedPolicy release]; [super dealloc]; }
@end
