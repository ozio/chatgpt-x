#import "OR6CodexCloud.h"
// Shared private authority. No network or credential storage; no descriptions
// containing tokens. Expiry and the entire trusted snapshot are rechecked.
@interface OR6CodexCloudBinding:NSObject {
 OR6CodexCloudCredentialSource _source;
 NSDictionary *_snapshot;
 BOOL _invalidated;
}
- (id)initWithSource:(OR6CodexCloudCredentialSource)source error:(NSError**)error;
- (BOOL)current;
- (NSDictionary*)context;
- (NSDictionary*)headers;
- (NSDictionary*)socketHeaders;
- (void)invalidate;
@end

@interface OR6CodexCloudWire:OR6CodexWSS<OR6CodexCloudIO> {
 OR6CodexCloudBinding *_binding;
 NSMutableSet *_reads;
 NSUInteger _readEpoch,_HTTPWorkers;
 BOOL _halted;
}
- (id)initWithBinding:(OR6CodexCloudBinding*)binding roots:(NSString*)roots error:(NSError**)error;
@end

@interface OR6CodexCloudProtocol:OR6CodexProtocol
@end
@interface OR6CodexCloudSession:OR6CodexSession {
 OR6CodexCloudBinding *_binding;
}
- (id)initWithIO:(id<OR6CodexCloudIO>)wire binding:(OR6CodexCloudBinding*)binding contracts:(NSDictionary*)contracts directory:(NSString*)directory error:(NSError**)error;
@end
