#import "../OR6APICore.h"
// Trusted native injection boundary. PCM is signed little-endian16, mono16kHz.
// consumer may run off-main; finished is delivered on main. stop drains capture,
// cancel discards capture immediately. No implementation may synthesize speech.
@protocol OR6API7HPCM <NSObject>
- (BOOL)startPCM:(BOOL(^)(NSData *PCM))consumer finished:(void(^)(NSError *error))finished error:(NSError **)error;
- (void)stop;
- (void)cancel;
@end
@interface OR6API7HAudioQueueCapture:NSObject<OR6API7HPCM>
@end
