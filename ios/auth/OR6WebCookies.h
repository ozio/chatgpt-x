#import <Foundation/Foundation.h>
// Only this application's exact chatgpt.com jar. Records contain secrets and
// must remain in app memory/Keychain; diagnostics expose only fixed metadata.
@interface OR6WebCookies : NSObject
+ (NSArray *)snapshot:(NSHTTPCookieStorage *)jar now:(NSTimeInterval)now;
+ (BOOL)validRecords:(id)records;
+ (NSString *)header:(NSArray *)records now:(NSTimeInterval)now;
+ (NSArray *)merging:(NSArray *)records setCookies:(NSArray *)headers now:(NSTimeInterval)now;
+ (NSDictionary *)metadata:(NSArray *)records;
+ (BOOL)hasSession:(NSArray *)records now:(NSTimeInterval)now;
+ (void)clearJar:(NSHTTPCookieStorage *)jar;
+ (void)install:(NSArray *)records jar:(NSHTTPCookieStorage *)jar now:(NSTimeInterval)now;
@end
