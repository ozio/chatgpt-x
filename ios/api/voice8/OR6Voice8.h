#import "../OR6APICore.h"
// Approved turn-based adaptation: record → transcribe → ordinary chat → read aloud.
// This does not admit the research realtime/LiveKit transport. Children run through
// the same Core, so send/transcribe journals and existing account guards apply.
NSDictionary *OR6Voice8Registry(NSDictionary *base);
@interface OR6Voice8Provider : NSObject <OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next;
@property(nonatomic,assign) OR6APICore *core; // host clears before Core teardown
- (void)pause;       // interruption/background: stops devices, never auto-resumes
- (void)deactivate;  // owner/credential change: destroys all session information
- (NSDictionary *)diagnostics;
@end
