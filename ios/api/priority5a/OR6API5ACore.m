#import "OR6API5ACore.h"
#import "OR6API5APolicy.h"
#import <dispatch/dispatch.h>
@implementation OR6API5ACore
- (id<OR6APITask>)perform:(NSString *)operation parameters:(NSDictionary *)parameters event:(OR6APIEvent)event completion:(OR6APIReply)reply {
 NSString*op=[[operation copy]autorelease];
 if(!NSThread.isMainThread){if(reply)dispatch_async(dispatch_get_main_queue(),^{reply(nil,OR6APIError(@"invalid_request",@"none"));});return nil;}
 [[self retain]autorelease];NSUInteger generation=[self.diagnostics[@"generation"]unsignedIntegerValue];
 return [super perform:op parameters:parameters event:event completion:^(NSDictionary *r,NSError *e){
  if(generation!=[self.diagnostics[@"generation"]unsignedIntegerValue]){r=nil;e=OR6APIError(@"stale_context",OR6API5AMutation(op)?@"possible":@"none");}
  if(OR6API5AMutation(op)&&[@[@"cancelled",@"stale_context",@"invalid_response"]containsObject:e.userInfo[@"code"]]&&[e.userInfo[@"dispatch"]isEqual:@"none"])e=OR6APIError(e.userInfo[@"code"],@"possible");
  if(reply)reply(r,e);
 }];
}
@end
