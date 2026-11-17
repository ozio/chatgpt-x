#import "OR6CodexPolicy8.h"
// Bounded private metadata, separate from operation receipts. One writer for
// each account/workspace namespace; credentials never enter this file.
@interface OR6CodexPrivateState:NSObject {
 NSString *_path;
 NSDictionary *_context,*_value;
 int _lockFD;
 BOOL _failed;
}
- (id)initWithDirectory:(NSString*)directory context:(NSDictionary*)context name:(NSString*)name error:(NSError**)error;
- (NSDictionary*)value;
- (BOOL)save:(NSDictionary*)value error:(NSError**)error;
- (void)close;
@end
