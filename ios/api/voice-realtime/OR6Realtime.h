#import "../OR6APICore.h"
@class OR6APIWebAdapter;
NSDictionary *OR6RealtimeRegistry(NSDictionary *base);
@interface OR6RealtimeProvider:NSObject<OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next adapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots;
@property(nonatomic,assign)OR6APICore *core;
- (void)pause;
- (void)deactivate;
- (NSDictionary*)diagnostics;
@end
