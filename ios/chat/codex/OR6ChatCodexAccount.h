#import "../../api/OR6APIWebAdapter.h"
#import "../../api/codex/OR6CodexCloud.h"
#import "../../api/codex/pair/OR6CodexPair.h"
// Native composition only. No bearer getter; UIKit receives the runtime facade.
@interface OR6APIWebAdapter(CodexAccount)
- (NSDictionary*)codexAccountContext;
- (OR6CodexCloud*)newCodexCloudWithContracts:(NSDictionary*)contracts directory:(NSString*)directory error:(NSError**)error;
- (OR6CodexPair*)newCodexPairWithContracts:(NSDictionary*)contracts directory:(NSString*)directory error:(NSError**)error;
@end
