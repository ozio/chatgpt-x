#import "OR6API6ANetwork.h"
#import "OR6API6APolicy.h"
#import "../OR6APIWebAdapter.h"
#import "../OR6APIHTTP.h"
#import <dispatch/dispatch.h>
#import "../../OR6Content.h"

@interface OR6API6ANetworkTask : NSObject <OR6APITask> { BOOL _cancelled; }
- (BOOL)cancelled;
@end
@implementation OR6API6ANetworkTask
- (void)cancel { @synchronized(self) { _cancelled=YES; } }
- (BOOL)cancelled { @synchronized(self) { return _cancelled; } }
@end

@implementation OR6API6ANetwork
- (id)initWithAdapter:(OR6APIWebAdapter *)adapter roots:(NSString *)roots {
    if ((self=[super init])) {
        if (!adapter || !roots.length) { [self release]; return nil; }
        _adapter=[adapter retain]; _roots=[roots copy];
    }
    return self;
}
- (id<OR6APITask>)request:(NSURLRequest *)request context:(NSDictionary *)ctx completion:(OR6APIReply)reply {
    OR6API6ANetworkTask *task=[[[OR6API6ANetworkTask alloc] init] autorelease];
    if(!NSThread.isMainThread){if(reply)dispatch_async(dispatch_get_main_queue(),^{reply(nil,OR6APIError(@"invalid_request",@"none"));});return task;}
    ctx=OR6APIJSONSnapshot(ctx,4096);
    if (!NSThread.isMainThread || !OR6API6AAllowedRequest(request) || ![ctx[@"key"]isKindOfClass:NSString.class] || ![ctx[@"key"]length] || [ctx[@"key"]length]>256 || !OR6APISchemaCheck(ctx[@"generation"],@{@"type":@"integer",@"minimum":@1},@{})) { reply(nil,OR6APIError(@"invalid_request",@"none")); return task; }
    NSMutableURLRequest *r=[[request mutableCopy] autorelease];
    [r setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [r setValue:@"https://chatgpt.com" forHTTPHeaderField:@"Origin"];
    [r setValue:@"https://chatgpt.com/" forHTTPHeaderField:@"Referer"];
    if(r.HTTPBody.length)[r setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSUInteger generation=_adapter.credentialGeneration;
    NSURLRequest *authorized=[_adapter authorizeChatRequest:r expectedKey:ctx[@"key"]];
    if (!authorized) { reply(nil,OR6APIError(@"not_authenticated",@"none")); return task; }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^{
        NSAutoreleasePool *pool=[NSAutoreleasePool new]; NSError *network=nil;
        NSDictionary *response=OR6APIHTTPPerform(authorized,_roots,[NSSet setWithObject:@"chatgpt.com"],
            @{@"connectTimeout":@15,@"idleTimeout":@25,@"overallTimeout":@45,@"collectBody":@YES,@"maxRequestBytes":@32768,@"maxDecodedBytes":@(4*1024*1024)},
            ^BOOL { return task.cancelled; },nil,nil,&network);
        id bytes=response[@"requestBytesSent"]?:network.userInfo[@"requestBytesSent"];
        NSString *sent=[bytes isKindOfClass:NSNumber.class] && ![bytes unsignedLongLongValue]?@"none":@"possible";
        NSInteger status=[response[@"status"] integerValue]; NSError *error=nil; id json=nil;
        if (!response) error=OR6APIError(task.cancelled?@"cancelled":@"network_unavailable",sent);
        else if (![response[@"certificateVerified"] boolValue]) error=OR6APIError(@"tls",sent);
        else if ((status<200 || status>299) && ![@[@400,@403,@404,@409,@423,@429] containsObject:@(status)]) error=OR6APIError(status==401?@"not_authenticated":status==403?@"service_challenge":status==429?@"rate_limited":@"upstream_error",sent);
        else {
            NSData *data=response[@"data"];
            if (data.length) json=[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            if (data.length && ![json isKindOfClass:NSDictionary.class] && ![json isKindOfClass:NSArray.class]) error=OR6APIError(@"unknown_wire_shape",sent);
            if (!data.length && status!=204 && status!=200) error=OR6APIError(@"unknown_wire_shape",sent);
        }
        if(error&&status==403)error=OR6APIError(@"service_challenge",sent);if(error&&status==429)error=OR6APIError(@"rate_limited",sent);
        NSDictionary *result=@{@"status":@(status), @"json":json?:(id)NSNull.null};
        dispatch_async(dispatch_get_main_queue(), ^{
            if (task.cancelled) { reply(nil,OR6APIError(@"cancelled",sent)); return; }
            if (generation!=_adapter.credentialGeneration || ![ctx[@"key"] isEqual:_adapter.contextKey]) { reply(nil,OR6APIError(@"stale_context",sent)); return; }
            if (!error && ![_adapter acceptChatCookies:response[@"setCookies"]?:@[] expectedKey:ctx[@"key"] generation:generation]) { reply(nil,OR6APIError(@"storage_failure",sent)); return; }
            reply(error?nil:result,error);
        });
        [pool drain];
    });
    return task;
}
- (BOOL)validatePasswordReauthenticationForAccount:(NSString*)account user:(NSString*)user context:(NSDictionary*)ctx issuedAt:(NSTimeInterval)issuedAt {
 if(!NSThread.isMainThread||![account isKindOfClass:NSString.class]||![user isKindOfClass:NSString.class]||![_adapter chatMatchesOwner:user]||![ctx[@"key"]isEqual:_adapter.contextKey])return NO;
 NSURLRequest*r=[_adapter authorizeChatRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://chatgpt.com/backend-api/locked_chats/status"]] expectedKey:ctx[@"key"]];
 if(![[r valueForHTTPHeaderField:@"ChatGPT-Account-Id"]isEqual:account])return NO;NSString*auth=[r valueForHTTPHeaderField:@"Authorization"];if(![auth hasPrefix:@"Bearer "]||auth.length>32768)return NO;NSArray*parts=[[auth substringFromIndex:7]componentsSeparatedByString:@"."];if(parts.count!=3)return NO;NSString*part=[parts[1]stringByReplacingOccurrencesOfString:@"-" withString:@"+"];part=[part stringByReplacingOccurrencesOfString:@"_" withString:@"/"];while(part.length%4)part=[part stringByAppendingString:@"="];NSData*d=OR6ContentDecodeBase64(part,16384);id claims=d?[NSJSONSerialization JSONObjectWithData:d options:0 error:NULL]:nil;id time=[claims isKindOfClass:NSDictionary.class]?claims[@"pwd_auth_time"]:nil;NSTimeInterval now=[NSDate timeIntervalSinceReferenceDate]+978307200;
 return OR6APISchemaCheck(time,@{@"type":@"number",@"minimum":@0},@{})&&[time doubleValue]>=issuedAt-1&&[time doubleValue]<=now+30&&now-issuedAt>=0&&now-issuedAt<=600;
}
- (void)dealloc { [_adapter release]; [_roots release]; [super dealloc]; }
@end
