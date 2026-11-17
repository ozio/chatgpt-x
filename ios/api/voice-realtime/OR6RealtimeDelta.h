#import <Foundation/Foundation.h>
// Current official IwWE v1 delta encoding. Bounded native state, no arbitrary keys.
@interface OR6RealtimeDelta:NSObject
- (NSDictionary*)apply:(NSDictionary*)delta;
- (void)clear;
@end
