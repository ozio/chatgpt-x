#import "OR6WebCookies.h"
#include <math.h>
static NSString *Domain(NSString *d){if(![d isKindOfClass:NSString.class])return nil;d=d.lowercaseString;while([d hasPrefix:@"."])d=[d substringFromIndex:1];return d;}
static BOOL Value(id v,NSUInteger limit){return [v isKindOfClass:NSString.class]&&[v length]<=limit&&[v rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location==NSNotFound;}
static BOOL Text(id v,NSUInteger limit){return Value(v,limit)&&[v length]>0;}
static BOOL SessionName(NSString *name){return [name rangeOfString:@"session-token"].location!=NSNotFound;}
static NSDictionary *Record(NSHTTPCookie *c){
    if(![Domain(c.domain)isEqual:@"chatgpt.com"]||!Text(c.name,512)||!Value(c.value,16384)||!Text(c.path,1024)||![c.path hasPrefix:@"/"])return nil;
    if([c.name rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"()<>@,;:\\\"/[]?={} \t"]].location!=NSNotFound)return nil;
    if(([c.name hasPrefix:@"__Secure-"]||[c.name hasPrefix:@"__Host-"])&&!c.isSecure)return nil;
    NSMutableDictionary *r=[NSMutableDictionary dictionaryWithDictionary:@{@"name":c.name,@"value":c.value,@"domain":c.domain,@"path":c.path,@"secure":@(c.isSecure),@"httpOnly":@(c.isHTTPOnly)}];
    if(c.expiresDate)r[@"expiresAt"]=@([c.expiresDate timeIntervalSince1970]);return r;
}
static NSHTTPCookie *Cookie(NSDictionary *r){
    NSMutableDictionary *p=[NSMutableDictionary dictionaryWithDictionary:@{NSHTTPCookieName:r[@"name"],NSHTTPCookieValue:r[@"value"],NSHTTPCookieDomain:r[@"domain"],NSHTTPCookiePath:r[@"path"]}];
    if([r[@"secure"]boolValue])p[NSHTTPCookieSecure]=@"TRUE";if([r[@"httpOnly"]boolValue])p[@"HttpOnly"]=@"TRUE";
    if(r[@"expiresAt"])p[NSHTTPCookieExpires]=[NSDate dateWithTimeIntervalSince1970:[r[@"expiresAt"]doubleValue]];
    return [NSHTTPCookie cookieWithProperties:p];
}
static BOOL Same(NSDictionary *a,NSDictionary *b){return [a[@"name"]isEqual:b[@"name"]]&&[Domain(a[@"domain"])isEqual:Domain(b[@"domain"])]&&[a[@"path"]isEqual:b[@"path"]];}
@implementation OR6WebCookies
+ (BOOL)validRecords:(id)records {
    if(![records isKindOfClass:NSArray.class]||[records count]>96)return NO;
    NSUInteger bytes=0;NSMutableArray *seen=[NSMutableArray array];
    for(id r in records){
        if(![r isKindOfClass:NSDictionary.class])return NO;
        NSSet *keys=[NSSet setWithArray:[r allKeys]];NSMutableSet *expected=[NSMutableSet setWithArray:@[@"name",@"value",@"domain",@"path",@"secure",@"httpOnly"]];if(r[@"expiresAt"])[expected addObject:@"expiresAt"];
        if(![keys isEqual:expected]||!Text(r[@"name"],512)||!Value(r[@"value"],16384)||!Text(r[@"domain"],1024)||!Text(r[@"path"],1024)||
           ![r[@"secure"]isKindOfClass:NSNumber.class]||![r[@"httpOnly"]isKindOfClass:NSNumber.class]||
           ![@[@0,@1]containsObject:r[@"secure"]]||![@[@0,@1]containsObject:r[@"httpOnly"]])return NO;
        if(r[@"expiresAt"]&&(![r[@"expiresAt"]isKindOfClass:NSNumber.class]||!isfinite([r[@"expiresAt"]doubleValue])))return NO;
        NSHTTPCookie *c=Cookie(r);NSDictionary *roundtrip=c?Record(c):nil;if(!roundtrip)return NO;
        for(NSDictionary *old in seen)if(Same(old,r))return NO;[seen addObject:r];
        NSData *data=[NSJSONSerialization dataWithJSONObject:r options:0 error:NULL];if(!data)return NO;bytes+=data.length;if(bytes>65536)return NO;
    }return YES;
}
+ (NSArray *)snapshot:(NSHTTPCookieStorage *)jar now:(NSTimeInterval)now {
    NSMutableArray *out=[NSMutableArray array];
    for(NSHTTPCookie *c in [jar cookiesForURL:[NSURL URLWithString:@"https://chatgpt.com/api/auth/session"]]){
        NSDictionary *r=Record(c);if(r&&(!c.expiresDate||[c.expiresDate timeIntervalSince1970]>now))[out addObject:r];
    }return [self validRecords:out]?out:@[];
}
+ (NSString *)header:(NSArray *)records now:(NSTimeInterval)now {
    if(![self validRecords:records])return nil;NSMutableArray *cookies=[NSMutableArray array];
    NSString *path=@"/api/auth/session";
    for(NSDictionary *r in records){if(r[@"expiresAt"]&&[r[@"expiresAt"]doubleValue]<=now)continue;
        NSString *p=r[@"path"];if(![path isEqual:p]&&!([path hasPrefix:p]&&([p hasSuffix:@"/"]||[path characterAtIndex:p.length]=='/')))continue;
        NSHTTPCookie *c=Cookie(r);if(c)[cookies addObject:c];
    }return [NSHTTPCookie requestHeaderFieldsWithCookies:cookies][@"Cookie"]?:@"";
}
+ (NSArray *)merging:(NSArray *)records setCookies:(NSArray *)headers now:(NSTimeInterval)now {
    if(![self validRecords:records]||![headers isKindOfClass:NSArray.class]||headers.count>96)return nil;
    NSMutableArray *out=[NSMutableArray array];for(NSDictionary *r in records)if(!r[@"expiresAt"]||[r[@"expiresAt"]doubleValue]>now)[out addObject:r];
    for(id text in headers){if(![text isKindOfClass:NSString.class]||[text length]>32768)return nil;
        for(NSHTTPCookie *c in [NSHTTPCookie cookiesWithResponseHeaderFields:@{@"Set-Cookie":text}forURL:[NSURL URLWithString:@"https://chatgpt.com/api/auth/session"]]){
            NSDictionary *r=Record(c);if(!r)continue;
            for(NSInteger i=(NSInteger)out.count-1;i>=0;i--)if(Same(out[(NSUInteger)i],r))[out removeObjectAtIndex:(NSUInteger)i];
            if(!c.expiresDate||[c.expiresDate timeIntervalSince1970]>now)[out addObject:r];
        }
    }return [self validRecords:out]?out:nil;
}
+ (NSDictionary *)metadata:(NSArray *)records {
    BOOL session=NO,persistent=NO;for(NSDictionary *r in records){session|=SessionName(r[@"name"]);persistent|=r[@"expiresAt"]!=nil;}
    return @{@"cookieCount":@(records.count),@"sessionCookiePresent":@(session),@"persistentCookiePresent":@(persistent)};
}
+ (BOOL)hasSession:(NSArray *)records now:(NSTimeInterval)now {
    if(![self validRecords:records])return NO;
    for(NSDictionary *r in records)if(SessionName(r[@"name"])&&[r[@"value"]length]&&[self header:@[r]now:now].length)return YES;
    return NO;
}
+ (void)clearJar:(NSHTTPCookieStorage *)jar {for(NSHTTPCookie *c in [[jar.cookies copy]autorelease]){NSString *d=Domain(c.domain);if([d isEqual:@"chatgpt.com"]||[d hasSuffix:@".chatgpt.com"]||[d isEqual:@"openai.com"]||[d hasSuffix:@".openai.com"])[jar deleteCookie:c];}}
+ (void)install:(NSArray *)records jar:(NSHTTPCookieStorage *)jar now:(NSTimeInterval)now {
    if(![self validRecords:records])return;
    // Replace only our exact ChatGPT host cookies. No provider/Safari jar access.
    for(NSHTTPCookie *c in [[jar.cookies copy]autorelease])if([Domain(c.domain)isEqual:@"chatgpt.com"])[jar deleteCookie:c];
    for(NSDictionary *r in records)if(!r[@"expiresAt"]||[r[@"expiresAt"]doubleValue]>now){NSHTTPCookie *c=Cookie(r);if(c)[jar setCookie:c];}
}
@end
