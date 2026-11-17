#import "../priority7g/OR6API7GProvider.h"
#import "../OR6APIWebAdapter.h"
#import "OR6API7HCapture.h"
@interface OR6API7HStreaming:NSObject<OR6API7GStreaming>
// Nil capture selects concrete iOS6 AudioQueue capture. Host refuses hardware.
// Nil capabilities is the closed default. Trusted admission: dictation.streaming.
- (id)initWithAdapter:(OR6APIWebAdapter *)adapter roots:(NSString *)roots capture:(id<OR6API7HPCM>)capture capabilities:(NSSet *)capabilities error:(NSError **)error;
// Trusted host supplies the exact Core owner/workspace key and generation.
- (BOOL)bindContext:(NSDictionary *)context;
- (NSDictionary *)diagnostics;
@end
