#import "../OR6APICore.h"
// Private adapter internals. No credential-bearing request crosses this boundary.
NSString *OR6API7HBase64(NSData *data);
NSString *OR6API7HAccept(NSString *key);
BOOL OR6API7HHandshake(NSData *header,NSString *key,NSError **error);
NSData *OR6API7HFrame(NSUInteger opcode,NSData *payload,NSData *mask,NSError **error);
NSData *OR6API7HRandomFrame(NSUInteger opcode,NSData *payload,NSError **error);
@interface OR6API7HFrames:NSObject{NSMutableData *_buffer,*_fragment;NSUInteger _fragmentOpcode,_count;BOOL _closed;}
- (NSArray *)append:(NSData *)bytes error:(NSError **)error;
@end
@interface OR6API7HSession:NSObject{NSMutableArray *_order;NSMutableDictionary *_utterances;NSDictionary *_last;NSString *_sessionID;long long _sequence;NSUInteger _count;BOOL _started,_closed;}
- (NSDictionary *)consume:(NSDictionary *)message closing:(BOOL)closing error:(NSError **)error;
- (NSString *)text:(BOOL)includePartial error:(NSError **)error;
- (BOOL)started;
- (BOOL)closed;
@end
