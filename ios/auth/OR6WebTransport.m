#import "OR6WebTransport.h"
#import "OR6WebCookies.h"
#import "ORLHTTP.h"
#import <dispatch/dispatch.h>
#include <mach/mach_time.h>
#include <mbedtls/platform_time.h>
mbedtls_ms_time_t mbedtls_ms_time(void){mach_timebase_info_data_t t;mach_timebase_info(&t);return(int64_t)((double)mach_absolute_time()*t.numer/t.denom/1000000.0);}
@interface OR6WebNetworkTask:NSObject<OR6WebTask>{BOOL _cancelled;}
- (BOOL)cancelled;
@end
@implementation OR6WebNetworkTask
- (void)cancel{@synchronized(self){_cancelled=YES;}}
- (BOOL)cancelled{@synchronized(self){return _cancelled;}}
@end
static BOOL Text(id value){return [value isKindOfClass:NSString.class]&&[value length]>0&&[value length]<=512;}
// Account profile from /me for this iPhone's account screen: single-line, bounded, never logged.
static NSString *ProfileText(id v){
    if(![v isKindOfClass:NSString.class])return nil;
    NSString *s=[[[v componentsSeparatedByCharactersInSet:[NSCharacterSet controlCharacterSet]]componentsJoinedByString:@" "]stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    return s.length&&s.length<=256?s:nil;
}
static NSDictionary *Profile(NSDictionary *body){
    NSMutableDictionary *p=[NSMutableDictionary dictionary];NSString *name=ProfileText(body[@"name"]),*email=ProfileText(body[@"email"]);
    if(name)p[@"name"]=name;if(email&&[email rangeOfString:@"@"].location!=NSNotFound)p[@"email"]=email;return p;
}
static NSDictionary *Failure(NSInteger status,NSString *issue){return @{@"status":@(status),@"issue":issue};}
static NSString *Issue(NSInteger status){return status==401?@"invalid_session":status==403?@"access_denied":status==429?@"rate_limited":status>=500?@"server_unavailable":@"bad_response";}
@implementation OR6WebTransport
- (id)initWithRoots:(NSString *)roots clock:(NSTimeInterval (^)(void))clock{if((self=[super init])){_roots=[roots copy];_clock=[clock copy];}return self;}
- (NSMutableURLRequest *)request:(NSString *)path {
    NSMutableURLRequest *r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:[@"https://chatgpt.com"stringByAppendingString:path]]cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:25];
    r.HTTPMethod=@"GET";[r setValue:@"application/json"forHTTPHeaderField:@"Accept"];[r setValue:@"LegacyClient/0.2 (iOS 6)"forHTTPHeaderField:@"User-Agent"];return r;
}
- (NSDictionary *)send:(NSURLRequest *)request task:(OR6WebNetworkTask *)task {
    return ORLHTTPPerform(request,_roots,[NSSet setWithObject:@"chatgpt.com"],^BOOL{return task.cancelled;},NULL);
}
- (NSDictionary *)body:(NSDictionary *)response {
    if(![response[@"certificateVerified"]isEqual:@YES])return nil;
    NSData *data=response[@"data"];if(![data isKindOfClass:NSData.class]||data.length>8*1024*1024)return nil;
    id body=[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];return [body isKindOfClass:NSDictionary.class]?body:nil;
}
- (id<OR6WebTask>)validate:(NSString *)token owner:(NSString *)owner completion:(OR6WebReply)completion {
    OR6WebNetworkTask *task=[[[OR6WebNetworkTask alloc]init]autorelease];
    if(![OR6WebSession validAccessToken:token]){completion(Failure(0,@"invalid_session"));return task;}
    NSString *expected=[[owner copy]autorelease];NSMutableURLRequest *request=[self request:@"/backend-api/me"];
    [request setValue:[@"Bearer "stringByAppendingString:token]forHTTPHeaderField:@"Authorization"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{NSAutoreleasePool *pool=[NSAutoreleasePool new];
        NSDictionary *response=[self send:request task:task];NSInteger status=[response[@"status"]integerValue];NSDictionary *result=Failure(status,response?Issue(status):@"network_unavailable");
        NSDictionary *body=[self body:response];
        if(status==200&&Text(body[@"id"]))result=expected&&![expected isEqual:body[@"id"]]?Failure(status,@"owner_changed"):@{@"status":@200,@"issue":@"",@"owner":body[@"id"],@"profile":Profile(body)};
        if(task.cancelled)result=Failure(0,@"cancelled");
        dispatch_async(dispatch_get_main_queue(),^{completion(result);});[pool drain];
    });return task;
}
- (id<OR6WebTask>)fetch:(NSArray *)cookies completion:(OR6WebReply)completion {
    OR6WebNetworkTask *task=[[[OR6WebNetworkTask alloc]init]autorelease];
    if(![OR6WebCookies validRecords:cookies]){completion(Failure(0,@"bad_response"));return task;}
    NSData *data=[NSJSONSerialization dataWithJSONObject:cookies options:0 error:NULL];NSArray *snapshot=[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    NSString *header=[OR6WebCookies header:snapshot now:_clock()];
    if(!header.length){completion(Failure(0,@"no_session"));return task;}
    NSMutableURLRequest *request=[self request:@"/api/auth/session"];[request setValue:header forHTTPHeaderField:@"Cookie"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{NSAutoreleasePool *pool=[NSAutoreleasePool new];
        NSDictionary *response=[self send:request task:task];NSInteger status=[response[@"status"]integerValue];NSDictionary *result=Failure(status,response?Issue(status):@"network_unavailable");
        NSDictionary *body=[self body:response];
        if(status==200&&body){
            if(!body.count||(!body[@"accessToken"]&&!body[@"user"]))result=Failure(status,@"no_session");
            else if([body[@"user"]isKindOfClass:NSDictionary.class]&&[OR6WebSession validAccessToken:body[@"accessToken"]]){
                NSArray *next=[OR6WebCookies merging:snapshot setCookies:response[@"setCookies"]?:@[] now:_clock()];
                if([OR6WebSession tokenExpiry:body[@"accessToken"]]<=_clock()+15)result=Failure(status,@"expired_result");
                else if(next)result=@{@"status":@200,@"issue":@"",@"accessToken":body[@"accessToken"],@"cookies":next};
            }
        }else if(status==401)result=Failure(status,@"no_session");
        if(task.cancelled)result=Failure(0,@"cancelled");
        // The response includes sensitive data, cookies and preparedRequest.
        // It stays in memory and never enters diagnostics/files/logs.
        dispatch_async(dispatch_get_main_queue(),^{completion(result);});[pool drain];
    });return task;
}
- (void)dealloc{[_roots release];[_clock release];[super dealloc];}
@end
