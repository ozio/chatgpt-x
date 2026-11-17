#import "OR6CodexProtocol.h"
// Private bounded account/workspace/connection/generation namespace. No credentials
// or prompt bodies. Atomic durable writes precede every potentially mutating send.
@interface OR6CodexStore:NSObject {
 NSString *_path;
 NSDictionary *_context;
 NSMutableDictionary *_records;
 BOOL _failed;
 int _lockFD;
}
- (id)initWithDirectory:(NSString*)directory context:(NSDictionary*)context error:(NSError**)error;
- (BOOL)record:(NSString*)identifier value:(NSDictionary*)value error:(NSError**)error;
- (NSDictionary*)record:(NSString*)identifier;
- (NSDictionary*)records;
- (void)close;
@end
