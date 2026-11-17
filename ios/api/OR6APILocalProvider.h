#import "OR6APICore.h"
// Local deterministic projections. No network/pasteboard/camera/microphone/UI.
// The UI performs explicit system interaction from the returned safe DTO.
@interface OR6APILocalProvider:NSObject<OR6APIProvider>{
 id<OR6APIProvider> _next;
 NSMutableDictionary *_drafts;
 NSDictionary *_models;NSString *_selected,*_scope;
}
- (id)initWithNext:(id<OR6APIProvider>)next;
- (void)installModels:(NSArray *)models;
@end
