#import "OR6CodexPair.h"
#import "OR6CodexPairOAuth.h"
#import "../OR6CodexOperation.h"
#import "../../OR6APIHTTP.h"
#import <Security/Security.h>
#import <dispatch/dispatch.h>
static NSString *Escape(NSString *s) {
    return (NSString *)[(id)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,(CFStringRef)s,NULL,CFSTR(":/?#[]@!$&'()*+,;=%"),kCFStringEncodingUTF8)autorelease];
}
@interface OR6CodexPairStop:NSObject {@public BOOL stopped;}
@end
@implementation OR6CodexPairStop
@end
@implementation OR6CodexPairHTTP
- (id)initWithRoots:(NSString *)roots {
    if((self=[super init])){_roots=[roots copy];_calls=[NSMutableSet new];}return self;
}
- (id<OR6APITask>)request:(NSString *)endpoint parameters:(NSDictionary *)raw headers:(NSDictionary *)headers completion:(OR6APIReply)cb {
    if(!cb)return nil;
    NSDictionary *paths=@{@"enroll.start":@"/codex/remote/control/client/enroll/start",@"enroll.finish":@"/codex/remote/control/client/enroll/finish",@"refresh.start":@"/codex/remote/control/client/refresh/start",@"refresh.finish":@"/codex/remote/control/client/refresh/finish",@"pair":@"/codex/remote/control/client/pair"};
    NSDictionary *p=OR6APIJSONSnapshot(raw,49152);BOOL oauth=[endpoint isEqual:@"oauth"],list=[endpoint isEqual:@"environments"];
    NSString *path=paths[endpoint],*origin=oauth?@"https://auth.openai.com":@"https://chatgpt.com",*method=list?@"GET":@"POST";
    if(oauth)path=@"/oauth/token";
    else if(list&&OR6CodexKeys(p,@[@"clientId"],@[@"cursor"])&&OR6CodexID(p[@"clientId"])&&(!p[@"cursor"]||OR6CodexText(p[@"cursor"],2048,NO)))path=[NSString stringWithFormat:@"/codex/remote/control/clients/%@/environments?limit=100%@",Escape(p[@"clientId"]),p[@"cursor"]?[@"&cursor="stringByAppendingString:Escape(p[@"cursor"])]:@""];
    if(!NSThread.isMainThread||_stopped||!p||!path||_calls.count||(!oauth&&(!OR6CodexText(headers[@"Authorization"],32768,NO)||!OR6CodexID(headers[@"ChatGPT-Account-Id"])))){cb(nil,OR6CodexError(@"invalid_request",NO));return nil;}
    NSURL *URL=[NSURL URLWithString:[origin stringByAppendingString:oauth?path:[@"/backend-api"stringByAppendingString:path]]];
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:URL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:35];request.HTTPMethod=method;
    if(!oauth)for(NSString *key in @[@"Authorization",@"ChatGPT-Account-Id"])[request setValue:headers[key]forHTTPHeaderField:key];
    [request setValue:@"legacy_ios6"forHTTPHeaderField:@"originator"];
    [request setValue:@"LegacyClient/1 (iOS 6; Codex)"forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"application/json"forHTTPHeaderField:@"Accept"];
    if(!list){
        [request setValue:oauth?@"application/x-www-form-urlencoded":@"application/json"forHTTPHeaderField:@"Content-Type"];
        if(oauth){NSMutableArray *a=[NSMutableArray array];for(NSString *k in [[p allKeys]sortedArrayUsingSelector:@selector(compare:)]){if(![p[k]isKindOfClass:NSString.class]){cb(nil,OR6CodexError(@"invalid_request",NO));return nil;}[a addObject:[NSString stringWithFormat:@"%@=%@",Escape(k),Escape(p[k])]];}request.HTTPBody=[[a componentsJoinedByString:@"&"]dataUsingEncoding:NSUTF8StringEncoding];}
        else request.HTTPBody=[NSJSONSerialization dataWithJSONObject:p options:0 error:NULL];
    }
    OR6CodexOperation *c=[[[OR6CodexOperation alloc]init]autorelease];[_calls addObject:c];NSUInteger epoch=_epoch;
    c->reply=[^(NSDictionary *r,NSError *e){[_calls removeObject:c];cb(r,e);}copy];
    OR6CodexPairStop *stop=[[[OR6CodexPairStop alloc]init]autorelease];c->cancelAction=[^{@synchronized(stop){stop->stopped=YES;}}copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{NSAutoreleasePool *pool=[NSAutoreleasePool new];NSError *error=nil;NSDictionary *value=nil;
        NSDictionary *r=OR6APIHTTPPerform(request,_roots,[NSSet setWithObject:URL.host],@{@"connectTimeout":@10,@"idleTimeout":@15,@"overallTimeout":@35,@"maxEncodedBytes":@262144,@"maxDecodedBytes":@262144,@"maxRequestBytes":@65536},^BOOL{@synchronized(stop){return stop->stopped;}},nil,nil,&error);
        NSInteger status=[r[@"status"]integerValue];
        NSError *transport=error;
        NSString *type=[r[@"headers"][@"content-type"]isKindOfClass:NSString.class]?r[@"headers"][@"content-type"]:@"";
        NSString *mime=[[type.lowercaseString componentsSeparatedByString:@";"][0]stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        NSData *data=[r[@"data"]isKindOfClass:NSData.class]?r[@"data"]:nil;
        id decoded=data&&data.length<=262144?[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]:nil;
        NSDictionary *json=[decoded isKindOfClass:NSDictionary.class]?decoded:nil;
        if(!r)error=OR6CodexError(@"network_unavailable",!list);
        else if(![r[@"certificateVerified"]isEqual:@YES])error=OR6CodexError(@"tls",!list);
        else if(status<200||status>=300)error=OR6CodexError(status==401?@"not_authenticated":status==403?@"service_challenge":status==429?@"rate_limited":status==404?@"not_found":status==400||status==422?@"invalid_request":@"upstream_error",status>=500&&!list);
        else {
            if(![mime isEqual:@"application/json"]||!json)error=OR6CodexError(@"invalid_response",!list);
            else value=OR6APIJSONSnapshot(json,262144);
        }
        if(oauth&&error){
            NSMutableDictionary *details=[NSMutableDictionary dictionary];
            if(r){details[@"httpStatus"]=@(status);details[@"responseType"]=[mime isEqual:@"application/json"]?@"json":[mime isEqual:@"text/html"]?@"html":@"other";}
            if([transport.domain isEqual:OR6APIHTTPErrorDomain])details[@"transportCode"]=@(transport.code);
            if(json[@"error"])details[@"oauthCode"]=json[@"error"];
            NSString *code=error.userInfo[@"code"]?:@"network_unavailable";
            if(!r&&[transport.domain isEqual:OR6APIHTTPErrorDomain]&&(transport.code==OR6APIHTTPTLSFailure||transport.code==OR6APIHTTPCertificateFailure))code=@"tls";
            BOOL possible=[error.userInfo[@"dispatch"]isEqual:@"possible"];
            // DNS/TCP/TLS failures before any HTTP byte cannot consume a code.
            id sent=transport.userInfo[@"requestBytesSent"];
            if(!r&&[transport.domain isEqual:OR6APIHTTPErrorDomain]&&[sent isKindOfClass:NSNumber.class]&&CFGetTypeID((CFTypeRef)sent)!=CFBooleanGetTypeID()&&[sent doubleValue]==0)possible=NO;
            error=OR6CodexPairOAuthFailure(code,possible,@"token_exchange",details);
        }
        [value retain];[error retain];dispatch_async(dispatch_get_main_queue(),^{if(!c->done)[c finish:epoch==_epoch?value:nil error:epoch==_epoch?error:OR6CodexError(@"stale_context",NO)];[value release];[error release];});[pool drain];
    });return c;
}
- (void)invalidate {_stopped=YES;_epoch++;for(OR6CodexOperation *c in [[_calls.allObjects copy]autorelease])[c cancel];}
- (void)dealloc {[self invalidate];[_roots release];[_calls release];[super dealloc];}
@end
@implementation OR6CodexPairKeychain
- (id)initWithService:(NSString *)service {if((self=[super init]))_service=[service copy];return self;}
- (NSMutableDictionary *)query {return [NSMutableDictionary dictionaryWithDictionary:@{(id)kSecClass:(id)kSecClassGenericPassword,(id)kSecAttrService:_service,(id)kSecAttrAccount:@"relay-software-p256-v1"}];}
- (NSDictionary *)load:(NSError **)error {
    NSMutableDictionary *q=[self query];q[(id)kSecReturnData]=@YES;CFTypeRef data=NULL;OSStatus code=SecItemCopyMatching((CFDictionaryRef)q,&data);
    if(code==errSecItemNotFound)return @{};
    if(code||!data){if(data)CFRelease(data);if(error)*error=OR6CodexError(@"storage_failure",NO);return nil;}
    id v=[NSJSONSerialization JSONObjectWithData:(NSData *)data options:0 error:NULL];NSDictionary *safe=[v isKindOfClass:NSDictionary.class]?OR6APIJSONSnapshot(v,60000):nil;CFRelease(data);
    if(!safe&&error)*error=OR6CodexError(@"storage_failure",NO);return safe;
}
- (BOOL)save:(NSDictionary *)value error:(NSError **)error {
    NSData *d=[NSJSONSerialization dataWithJSONObject:value options:0 error:NULL];if(!d||d.length>60000){if(error)*error=OR6CodexError(@"storage_failure",NO);return NO;}
    NSMutableDictionary *q=[self query];NSDictionary *attrs=@{(id)kSecValueData:d,(id)kSecAttrAccessible:(id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly};
    OSStatus code=SecItemUpdate((CFDictionaryRef)q,(CFDictionaryRef)attrs);if(code==errSecItemNotFound){[q addEntriesFromDictionary:attrs];code=SecItemAdd((CFDictionaryRef)q,NULL);}
    if(code&&error)*error=OR6CodexError(@"storage_failure",NO);return !code;
}
- (NSString *)description {return @"<OR6CodexPairKeychain private>";}
- (void)dealloc {[_service release];[super dealloc];}
@end
