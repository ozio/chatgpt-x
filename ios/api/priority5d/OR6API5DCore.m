#import "OR6API5DCore.h"
#import "OR6API5DPolicy.h"
#import <dispatch/dispatch.h>
@implementation OR6API5DCore
- (id<OR6APITask>)perform:(NSString *)op parameters:(NSDictionary *)p event:(OR6APIEvent)event completion:(OR6APIReply)reply {
 if(!NSThread.isMainThread){if(reply)dispatch_async(dispatch_get_main_queue(),^{reply(nil,OR6APIError(@"invalid_request",@"none"));});return nil;}
 return [super perform:op parameters:p event:event completion:^(NSDictionary *r,NSError *e){
  if(OR6API5DMutation(op)&&[@[@"cancelled",@"stale_context",@"invalid_response"]containsObject:e.userInfo[@"code"]]&&[e.userInfo[@"dispatch"]isEqual:@"none"])e=OR6APIError(e.userInfo[@"code"],@"possible");
  if(reply)reply(r,e);
 }];
}
@end
