#import "OR6API7AllCore.h"
#import "../priority7/OR6API7Policy.h"
#import "../priority7b/OR6API7BPolicy.h"
#import "../priority7c/OR6API7CPolicy.h"
#import "../priority7d/OR6API7DPolicy.h"
#import "../priority7e/OR6API7EPolicy.h"
#import "../priority7f/OR6API7FPolicy.h"
#import "../priority7g/OR6API7GProvider.h"
NSDictionary*OR6API7AllRegistry(NSDictionary*base,NSDictionary*x,NSError**error){
 if(![x isKindOfClass:NSDictionary.class]||x.count!=7){if(error)*error=OR6APIError(@"invalid_request",@"none");return nil;}
 for(NSString*k in @[@"7",@"7b",@"7c",@"7d",@"7e",@"7f",@"7g"])if(![x[k]isKindOfClass:NSDictionary.class]){if(error)*error=OR6APIError(@"invalid_request",@"none");return nil;}
 NSDictionary*r=OR6API7Registry(base,x[@"7"],error);if(r)r=OR6API7BRegistry(r,x[@"7b"],error);if(r)r=OR6API7CRegistry(r,x[@"7c"],error);if(r)r=OR6API7DRegistry(r,x[@"7d"],error);if(r)r=OR6API7ERegistry(r,x[@"7e"],error);if(r)r=OR6API7FRegistry(r,x[@"7f"],error);if(r)r=OR6API7GRegistry(r,x[@"7g"],error);return r;
}
@implementation OR6API7AllCore
- (id<OR6APITask>)perform:(NSString*)op parameters:(NSDictionary*)p event:(OR6APIEvent)event completion:(OR6APIReply)reply{
 return[super perform:op parameters:p event:event completion:^(NSDictionary*r,NSError*e){
  // Parent Core invalidation can finish before child cancellation. Every new
  // service-mutating provider has its own durable journal; do not claim unsent
  // at that earlier boundary. A local Photos request may already be submitted.
  BOOL mutation=OR6API7DMutation(op)||OR6API7EMutation(op)||OR6API7FMutation(op)||([op isEqual:@"images.export"]&&[p[@"destination"]isEqual:@"photos"]);
  if(mutation&&[@[@"cancelled",@"stale_context",@"invalid_response"]containsObject:e.userInfo[@"code"]]&&[e.userInfo[@"dispatch"]isEqual:@"none"])e=OR6APIError(e.userInfo[@"code"],@"possible");if(reply)reply(r,e);
 }];
}
@end
