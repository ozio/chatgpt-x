#import "OR6API9Core.h"
@implementation OR6API9Core
- (id<OR6APITask>)perform:(NSString*)op parameters:(NSDictionary*)p event:(OR6APIEvent)event completion:(OR6APIReply)reply{
 BOOL remote=[op isEqual:@"messages.stop"]||[op isEqual:@"dictation.retry"];
 return[super perform:op parameters:p event:event completion:^(NSDictionary*r,NSError*e){
  if(remote&&[@[@"cancelled",@"stale_context"]containsObject:e.userInfo[@"code"]]&&[e.userInfo[@"dispatch"]isEqual:@"none"])e=OR6APIError(e.userInfo[@"code"],@"possible");if(reply)reply(r,e);
 }];
}
@end
