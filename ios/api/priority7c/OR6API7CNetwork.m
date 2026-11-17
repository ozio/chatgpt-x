#import "OR6API7CNetwork.h"
#import "OR6API7CPolicy.h"
#ifdef OR6_CHAT_ACCEPTANCE
#import <CoreFoundation/CoreFoundation.h>
#include <sys/stat.h>
// Bounded development-only wire-shape evidence. Values/headers/credentials are
// never recorded, and an explicit private on-device marker is required.
static id CReadShape(id value, NSUInteger depth) {
    if (depth > 5) return @{@"type": @"depth_limit"};
    if (!value || value == NSNull.null) return @{@"type": @"null"};
    if ([value isKindOfClass:NSString.class]) {
        NSString *s = value;
        return @{@"type": @"string", @"length": @(s.length), @"slash": @([s rangeOfString:@"/"].location != NSNotFound),
                 @"libraryID": @(OR6API7CLibraryID(s)), @"encryptedNode": @([s hasPrefix:@"libfile_fde1_"] || [s hasPrefix:@"libfile_fde2_"] || [s hasPrefix:@"libfile_fde3_"])};
    }
    if ([value isKindOfClass:NSNumber.class]) return @{@"type": @"number", @"boolean": @(CFGetTypeID((CFTypeRef)value) == CFBooleanGetTypeID()), @"negative": @([value doubleValue] < 0)};
    if ([value isKindOfClass:NSArray.class]) { NSMutableArray *a = [NSMutableArray array]; for (id v in [value subarrayWithRange:NSMakeRange(0, MIN((NSUInteger)50, [value count]))]) [a addObject:CReadShape(v, depth + 1)]; return @{@"type": @"array", @"count": @([value count]), @"items": a}; }
    if ([value isKindOfClass:NSDictionary.class]) { NSMutableDictionary *d = [NSMutableDictionary dictionary]; NSArray *keys = [[value allKeys] sortedArrayUsingSelector:@selector(compare:)]; for (NSString *k in [keys subarrayWithRange:NSMakeRange(0, MIN((NSUInteger)80, keys.count))]) if (k.length <= 100) d[k] = CReadShape(value[k], depth + 1); return @{@"type": @"object", @"fields": d}; }
    return @{@"type": @"other"};
}
static void CTraceReadShape(NSURLRequest *request, NSInteger status, id json, NSError *error) {
    NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (!dirs.count) return;
    NSString *dir = [dirs objectAtIndex:0];
    if (![NSFileManager.defaultManager fileExistsAtPath:[dir stringByAppendingPathComponent:@"UI7ReadShapeCapture"]]) return;
    NSString *path = [dir stringByAppendingPathComponent:@"UI7ReadShapes.json"];
    NSData *old = [NSData dataWithContentsOfFile:path]; id prior = old ? [NSJSONSerialization JSONObjectWithData:old options:0 error:NULL] : nil;
    NSMutableArray *items = [prior isKindOfClass:NSArray.class] ? [[prior mutableCopy] autorelease] : [NSMutableArray array];
    if (items.count >= 8) return;
    NSString *kind = [request.URL.path isEqual:@"/backend-api/files/library"] ? @"library.list_or_search" : [request.URL.path hasSuffix:@"/node"] ? @"library.node" : [request.URL.path hasPrefix:@"/backend-api/conversations/"] ? @"conversation.files" : @"library.detail";
    [items addObject:@{@"routeKind": kind, @"status": @(status), @"error": error.userInfo[@"code"] ?: @"", @"shape": CReadShape(json, 0)}];
    NSData *data = [NSJSONSerialization dataWithJSONObject:items options:0 error:NULL];
    if (data.length <= 512 * 1024 && [data writeToFile:path atomically:YES]) chmod(path.fileSystemRepresentation,0600);
}
#endif
#import "../OR6APIWebAdapter.h"
#import "../OR6APIHTTP.h"
#import <dispatch/dispatch.h>

@interface OR6API7CNetworkTask : NSObject <OR6APITask> { BOOL _cancelled; }
- (BOOL)cancelled;
@end
@implementation OR6API7CNetworkTask
- (void)cancel { @synchronized(self) { _cancelled=YES; } }
- (BOOL)cancelled { @synchronized(self) { return _cancelled; } }
@end

@implementation OR6API7CNetwork
- (id)initWithAdapter:(OR6APIWebAdapter *)adapter roots:(NSString *)roots {
    if ((self=[super init])) {
        if (!adapter || !roots.length) { [self release]; return nil; }
        _adapter=[adapter retain]; _roots=[roots copy];
    }
    return self;
}
- (id<OR6APITask>)request:(NSURLRequest *)request context:(NSDictionary *)ctx completion:(OR6APIReply)reply {
    OR6API7CNetworkTask *task=[[[OR6API7CNetworkTask alloc] init] autorelease];
    if (!NSThread.isMainThread || !OR6API7CAllowedRequest(request)) { reply(nil,OR6APIError(@"invalid_request",@"none")); return task; }
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
            @{@"connectTimeout":@15,@"idleTimeout":@25,@"overallTimeout":@45,@"collectBody":@YES,@"maxRequestBytes":@32768,@"maxDecodedBytes":@(4*1024*1024)},
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
#ifdef OR6_CHAT_ACCEPTANCE
            CTraceReadShape(r,status,json,error);
#endif
            reply(error?nil:result,error);
        });
        [pool drain];
    });
    return task;
}
- (void)dealloc { [_adapter release]; [_roots release]; [super dealloc]; }
@end
