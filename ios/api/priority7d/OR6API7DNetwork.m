#import "OR6API7DNetwork.h"
#import "OR6API7DPolicy.h"
#import "../OR6APIWebAdapter.h"
#import "../OR6APIHTTP.h"
#import <dispatch/dispatch.h>

@interface OR6API7DNetworkTask : NSObject <OR6APITask> { BOOL _cancelled; }
- (BOOL)cancelled;
@end
@implementation OR6API7DNetworkTask
- (void)cancel { @synchronized(self) { _cancelled=YES; } }
- (BOOL)cancelled { @synchronized(self) { return _cancelled; } }
@end

@implementation OR6API7DNetwork
- (id)initWithAdapter:(OR6APIWebAdapter *)adapter roots:(NSString *)roots {
    if ((self=[super init])) {
        if (!adapter || !roots.length) { [self release]; return nil; }
        _adapter=[adapter retain]; _roots=[roots copy];
    }
    return self;
}
- (id<OR6APITask>)request:(NSURLRequest *)request context:(NSDictionary *)ctx completion:(OR6APIReply)reply {
    OR6API7DNetworkTask *task=[[[OR6API7DNetworkTask alloc] init] autorelease];
    if (!NSThread.isMainThread || !OR6API7DAllowedRequest(request)) { reply(nil,OR6APIError(@"invalid_request",@"none")); return task; }
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
            @{@"connectTimeout":@15,@"idleTimeout":@25,@"overallTimeout":@45,@"collectBody":@YES,@"maxRequestBytes":@65536,@"maxDecodedBytes":@(4*1024*1024)},
            ^BOOL { return task.cancelled; },nil,nil,&network);
        id bytes=response[@"requestBytesSent"]?:network.userInfo[@"requestBytesSent"];
        NSString *sent=[bytes isKindOfClass:NSNumber.class] && ![bytes unsignedLongLongValue]?@"none":@"possible";
        NSInteger status=[response[@"status"] integerValue]; NSError *error=nil; id json=nil;
        if (!response) error=OR6APIError(task.cancelled?@"cancelled":@"network_unavailable",sent);
        else if (![response[@"certificateVerified"] boolValue]) error=OR6APIError(@"tls",sent);
        else if ((status<200 || status>299) && status!=404) error=OR6APIError(status==401?@"not_authenticated":status==403?@"service_challenge":status==429?@"rate_limited":@"upstream_error",sent);
        else {
            NSData *data=response[@"data"];
            if (data.length) json=[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            if (data.length && ![json isKindOfClass:NSDictionary.class] && ![json isKindOfClass:NSArray.class]) error=OR6APIError(@"unknown_wire_shape",sent);
            if (!data.length && status!=204) error=OR6APIError(@"unknown_wire_shape",sent);
        }
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
- (void)dealloc { [_adapter release]; [_roots release]; [super dealloc]; }
@end
