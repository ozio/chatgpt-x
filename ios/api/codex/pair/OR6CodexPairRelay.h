#import "OR6CodexPair.h"
#import "../OR6CodexTransport.h"
@interface OR6CodexPairCodec : NSObject {
    NSString *_client,*_environment,*_stream,*_cursor; uint64_t _outSequence,_lastSequence; BOOL _hasSequence;
    NSMutableData *_assembly; NSDictionary *_segment; NSUInteger _nextSegment;
}
- (id)initClient:(NSString *)client environment:(NSString *)environment;
- (NSArray *)outgoing:(NSDictionary *)RPC error:(NSError **)error;
// [] is a duplicate or incomplete segment; nil is an invalid frame or gap.
- (NSDictionary *)heartbeat;
- (NSArray *)incoming:(NSDictionary *)envelope error:(NSError **)error;
@end
@interface OR6CodexPairRelay : OR6CodexWSS {
    OR6CodexPairCredentials _source; NSDictionary *_snapshot,*_grant,*_identity;
    NSData *_scalar; OR6CodexPairCodec *_codec;
    BOOL _proofSent,_relayReady; void(^_relayOpened)(NSError *); void(^_relayClosed)(NSError *);
}
- (id)initWithSource:(OR6CodexPairCredentials)source snapshot:(NSDictionary *)snapshot
    grant:(NSDictionary *)grant identity:(NSDictionary *)identity scalar:(NSData *)scalar
    environment:(NSString *)environment roots:(NSString *)roots;
@end
