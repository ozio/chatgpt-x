#import "OR6WebStore.h"
#import "OR6WebCookies.h"
#import <Security/Security.h>
@implementation OR6WebKeychain
- (id)initWithBundle:(NSString *)bundle{if((self=[super init])){_service=[[bundle stringByAppendingString:@".web-session.v3"]copy];_legacyService=[[bundle stringByAppendingString:@".account-session.v1"]copy];}return self;}
- (NSDictionary *)query:(BOOL)legacy{return @{(id)kSecClass:(id)kSecClassGenericPassword,(id)kSecAttrService:legacy?_legacyService:_service,(id)kSecAttrAccount:legacy?@"chatgpt-web-session":@"web-session-aggregate-v3"};}
- (NSDictionary *)read:(BOOL)legacy status:(NSInteger *)status {
    NSMutableDictionary *q=[[[self query:legacy]mutableCopy]autorelease];q[(id)kSecReturnData]=@YES;q[(id)kSecMatchLimit]=(id)kSecMatchLimitOne;
    CFTypeRef raw=NULL;OSStatus s=SecItemCopyMatching((CFDictionaryRef)q,&raw);if(s==errSecItemNotFound){*status=0;return nil;}
    *status=s;if(s||!raw){if(!s)*status=errSecDecode;if(raw)CFRelease(raw);return nil;}
    id value=CFGetTypeID(raw)==CFDataGetTypeID()&&[(NSData *)raw length]<=98304?[NSJSONSerialization JSONObjectWithData:(NSData *)raw options:0 error:NULL]:nil;CFRelease(raw);
    if(![value isKindOfClass:NSDictionary.class]||(!legacy&&![OR6WebSession validRecord:value])){*status=errSecDecode;return nil;}return value;
}
- (NSDictionary *)load:(NSInteger *)status{return [self read:NO status:status];}
- (NSDictionary *)legacy:(NSInteger *)status{return [self read:YES status:status];}
- (BOOL)save:(NSDictionary *)record status:(NSInteger *)status {
    if(![OR6WebSession validRecord:record]){*status=errSecParam;return NO;}
    NSData *data=[NSJSONSerialization dataWithJSONObject:record options:0 error:NULL];if(!data||data.length>98304){*status=errSecParam;return NO;}
    NSDictionary *attrs=@{(id)kSecValueData:data,(id)kSecAttrAccessible:(id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly};
    OSStatus s=SecItemUpdate((CFDictionaryRef)[self query:NO],(CFDictionaryRef)attrs);
    if(s==errSecItemNotFound){NSMutableDictionary *q=[[[self query:NO]mutableCopy]autorelease];[q addEntriesFromDictionary:attrs];s=SecItemAdd((CFDictionaryRef)q,NULL);}
    *status=s;return s==errSecSuccess;
}
- (BOOL)clearLegacy:(NSInteger *)status{OSStatus s=SecItemDelete((CFDictionaryRef)[self query:YES]);if(s==errSecItemNotFound)s=errSecSuccess;*status=s;return s==errSecSuccess;}
- (void)dealloc{[_service release];[_legacyService release];[super dealloc];}
@end
@implementation OR6WebSystemJar
- (NSArray *)snapshot{return [OR6WebCookies snapshot:[NSHTTPCookieStorage sharedHTTPCookieStorage]now:[[NSDate date]timeIntervalSince1970]];}
- (void)install:(NSArray *)records{[OR6WebCookies install:records jar:[NSHTTPCookieStorage sharedHTTPCookieStorage]now:[[NSDate date]timeIntervalSince1970]];}
- (void)clear{[OR6WebCookies clearJar:[NSHTTPCookieStorage sharedHTTPCookieStorage]];}
@end
