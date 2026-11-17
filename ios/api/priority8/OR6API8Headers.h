#import <Foundation/Foundation.h>
// iOS 6 setAllHTTPHeaderFields merges rather than replacing existing fields.
// Remove every old field explicitly before changing the upload protocol.
static inline void OR6API8ReplaceHeaders(NSMutableURLRequest *request, NSDictionary *fields) {
 NSArray *keys=[[request.allHTTPHeaderFields allKeys]copy];
 for(NSString *key in keys)[request setValue:nil forHTTPHeaderField:key];
 [keys release];
 for(NSString *key in fields)[request setValue:fields[key]forHTTPHeaderField:key];
}
