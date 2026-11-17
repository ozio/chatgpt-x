#import "OR6API7BCore.h"
#import "OR6API7BPolicy.h"
@implementation OR6API7BCore
- (id<OR6APITask>)perform:(NSString *)op parameters:(NSDictionary *)p event:(OR6APIEvent)event completion:(OR6APIReply)reply {
    return [super perform:op parameters:p event:event completion:^(NSDictionary *r,NSError *e) {
        if (OR6API7BMutation(op) && [@[@"cancelled",@"stale_context",@"invalid_response"] containsObject:e.userInfo[@"code"]] && [e.userInfo[@"dispatch"] isEqual:@"none"]) e=OR6APIError(e.userInfo[@"code"],@"possible");
        if (reply) reply(r,e);
    }];
}
@end
