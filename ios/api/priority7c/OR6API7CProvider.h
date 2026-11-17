#import "OR6API7CNetwork.h"
#import "../priority8/OR6API8Media.h"
@interface OR6API7CProvider:NSObject<OR6APIProvider,OR6API8RemoteAssets>
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP media:(OR6API8Media*)media
 extension:(NSDictionary*)extension capabilities:(NSSet*)capabilities clock:(NSTimeInterval(^)(void))clock error:(NSError**)error;
- (void)deactivate;
- (NSDictionary*)diagnostics;
@end
