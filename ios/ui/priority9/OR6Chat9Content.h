#import <Foundation/Foundation.h>
// Pure adapters over the existing renderer; no WebView or executable HTML.
NSArray *OR6Chat9ContentRows(NSArray *messages);
NSString *OR6Chat9ReadableText(NSString *source,BOOL markdown);
NSDictionary *OR6Chat9CopyParameters(NSString *messageId,NSString *text);
@interface OR6Chat9ContentCache:NSObject{NSMutableDictionary *_messages;NSUInteger _parses;}
- (NSArray *)rowsForMessages:(NSArray *)messages;
- (NSUInteger)parseCount;
@end
