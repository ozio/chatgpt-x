#import "../OR6APICore.h"
@class OR6Files,OR6API8Media;
NSDictionary *OR6Rev5ASRRegistry(NSDictionary *base,NSError **error);
NSDictionary *OR6Rev5ASROperations(void);
NSDictionary *OR6Rev5ASRTiers(void);
BOOL OR6Rev5ASRMutation(NSString *operation);
// Offline recorded WAV/AAC-M4A only, en-US, <=30s/8MiB. No URL/path authority,
// microphone capture, remote fallback, automatic model downloads or Siri parity.
@interface OR6Rev5ASRProvider:NSObject<OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next registry:(NSDictionary *)registry vault:(OR6Files *)vault media:(OR6API8Media *)media modelsDirectory:(NSString *)directory error:(NSError **)error;
- (BOOL)bindIdentity:(NSDictionary *)identity context:(NSDictionary *)context;
// Native host only: descriptors from current-owner Core-validated acquisition,
// download/upload, or audio.recording.attach. Caller asset IDs confer no ownership.
- (BOOL)bindAssets:(NSArray *)assets context:(NSDictionary *)context;
- (void)deactivate;
- (NSDictionary *)diagnostics;
@end
