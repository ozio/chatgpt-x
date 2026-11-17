#import "OR6API7ECore.h"
#import "OR6API7EPolicy.h"
@implementation OR6API7ECore
- (id<OR6APITask>)perform:(NSString *)op parameters:(NSDictionary *)p event:(OR6APIEvent)event completion:(OR6APIReply)reply {
 return [super perform:op parameters:p event:event completion:^(NSDictionary *r,NSError *e){
  if(OR6API7EMutation(op)&&[@[@"cancelled",@"stale_context",@"invalid_response"]containsObject:e.userInfo[@"code"]]&&[e.userInfo[@"dispatch"]isEqual:@"none"])e=OR6APIError(e.userInfo[@"code"],@"possible");
  if(reply)reply(r,e);
 }];
}
@end
