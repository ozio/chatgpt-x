#import "OR6Selected20.h"
@implementation OR6Selected20Core
- (id<OR6APITask>)perform:(NSString*)op parameters:(NSDictionary*)p event:(OR6APIEvent)event completion:(OR6APIReply)reply{return[super perform:op parameters:p event:event completion:^(NSDictionary*r,NSError*e){if([@[@"skills.install",@"skills.remove"]containsObject:op]&&[@[@"cancelled",@"stale_context",@"invalid_response"]containsObject:e.userInfo[@"code"]]&&[e.userInfo[@"dispatch"]isEqual:@"none"])e=OR6APIError(e.userInfo[@"code"],@"possible");if(reply)reply(r,e);}];}
@end
