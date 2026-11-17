#import "OR6API7Network.h"
@interface OR6API7Provider : NSObject <OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP extension:(NSDictionary *)extension
 journalDirectory:(NSString *)directory capabilities:(NSSet *)capabilities error:(NSError **)error;
- (void)deactivate;
- (NSDictionary *)diagnostics;
@end
