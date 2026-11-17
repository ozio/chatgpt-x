#import "OR6API7Core.h"
#import "OR6API7Policy.h"
@implementation OR6API7Core
- (id<OR6APITask>)perform:(NSString *)op parameters:(NSDictionary *)p event:(OR6APIEvent)event completion:(OR6APIReply)reply {
    // Core cancellation runs before child cancellation. The new provider owns
    // durable mutation identities; never report definitely-unsent on this path.
    return [super perform:op parameters:p event:event completion:^(NSDictionary *r, NSError *e) {
        if (OR6API7Mutation(op) && [@[@"cancelled", @"stale_context", @"invalid_response"] containsObject:e.userInfo[@"code"]]
            && [e.userInfo[@"dispatch"] isEqual:@"none"]) e = OR6APIError(e.userInfo[@"code"], @"possible");
        if (reply) reply(r, e);
    }];
}
@end
