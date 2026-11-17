#import "../OR6APICore.h"
@class OR6API8Media;
@protocol OR6API8Generation <NSObject>
- (id<OR6APITask>)executeNativePlan:(NSDictionary*)plan context:(NSDictionary*)context event:(OR6APIEvent)event completion:(OR6APIReply)completion;
@end
@interface OR6API8Provider:NSObject<OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next generation:(id<OR6API8Generation>)generation media:(OR6API8Media*)media capabilities:(NSSet*)capabilities;
- (void)deactivate;
@end
