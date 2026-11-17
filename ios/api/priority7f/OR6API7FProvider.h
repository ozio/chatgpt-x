#import "../priority7/OR6API7Network.h"
#import "../priority8/OR6API8Provider.h"
@interface OR6API7FProvider:NSObject<OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP generation:(id<OR6API8Generation>)generation extension:(NSDictionary*)extension journalDirectory:(NSString*)directory capabilities:(NSSet*)capabilities error:(NSError**)error;
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP generation:(id<OR6API8Generation>)generation extension:(NSDictionary*)extension journalDirectory:(NSString*)directory capabilities:(NSSet*)capabilities clock:(NSTimeInterval(^)(void))clock error:(NSError**)error;
- (void)deactivate;
- (NSDictionary*)diagnostics;
@end
