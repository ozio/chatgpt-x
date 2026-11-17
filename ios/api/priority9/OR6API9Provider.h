#import "../OR6APICore.h"
// Private runtime boundary. Unsigned requests and audio bytes never enter DTOs.
@protocol OR6API9HTTP <NSObject>
- (id<OR6APITask>)performRequest:(NSURLRequest*)request context:(NSDictionary*)context completion:(void(^)(NSDictionary*response,NSError*error))completion;
@end
@protocol OR6API9Recorder <NSObject>
- (BOOL)start:(NSString*)recording maxDurationMS:(NSUInteger)maximum error:(NSError**)error;
- (void)stop;
- (void)cancel;
- (void)suspend;
- (NSDictionary*)snapshot; // no URL: state, recordingId, durationMS, bytes, assetId
- (NSData*)recordingData:(NSString*)identifier error:(NSError**)error;
@end
// Put OUTSIDE the existing local/session/native-send provider chain. Pass the
// SAME directory to this provider and Core for immutable no-dispatch retry.
// Optional HTTP capabilities default to empty: explicit candidate enabling is
// separate from native service admission and never enables a remote fallback.
@interface OR6API9Provider:NSObject<OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API9HTTP>)HTTP recorder:(id<OR6API9Recorder>)recorder coreJournalDirectory:(NSString*)directory controlJournalDirectory:(NSString*)controls capabilities:(NSSet*)capabilities error:(NSError**)error;
// Trusted in-process send host only, if the actual generation supplied one.
- (BOOL)bindConduitToken:(NSString*)token operation:(NSString*)operation context:(NSDictionary*)context;
- (void)deactivate;
- (NSDictionary*)diagnostics;
@end
