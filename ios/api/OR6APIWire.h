#import <Foundation/Foundation.h>

extern NSString *const OR6APIWireErrorDomain;
// Private account data stays in returned DTOs in process, never in NSError text.
NSDictionary *OR6APIWireHistory(NSData *data, NSUInteger offset, NSUInteger limit, NSError **error);
NSDictionary *OR6APIWireConversation(NSData *data, NSString *expectedID, NSError **error);
NSDictionary *OR6APIWireModels(NSData *data, NSError **error);
NSDictionary *OR6APIWireSearch(NSData *data, NSString *previousCursor, NSError **error);

// Consumes ORIGINAL vendor SSE, unlike OR6Events' normalized bridge events.
// feed returns bounded events: identity/messageSnapshot/status/complete/done.
// complete is an observed upstream completion marker; EOF/DONE alone isn't proof
// of persistence. Caller separately reconciles server IDs with a read.
@interface OR6APIDeltaDecoder : NSObject {
    NSMutableData *_pending;
    NSMutableDictionary *_state;
    NSString *_path,*_operation;
    id _context;
    BOOL _encodingSeen,_done,_complete,_failed;
    NSUInteger _bytes,_events;
    NSUInteger _deltaFrames,_analysisFrames,_hiddenAssistantFrames,_visibleAssistantFrames;
    NSUInteger _blocks;
    NSMutableDictionary *_frameInfo;
    NSDictionary *_failureInfo;
    NSArray *_failureEvents;
    NSString *_failureIssue;
}
- (NSArray *)feed:(NSData *)bytes final:(BOOL)final error:(NSError **)error;
// Counts only; no message IDs/text/metadata or server-provided strings.
- (NSDictionary *)diagnostics;
// Failure metadata is fixed enums/counts/optional hashes of protocol tags only.
// NSError remains generic. Account DTOs stay exclusively in the event channel.
- (NSString *)failureIssue;
- (NSArray *)takeFailureEvents;
@property(nonatomic,readonly) BOOL done;
@property(nonatomic,readonly) BOOL complete;
@end
