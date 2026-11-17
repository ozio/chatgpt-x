#import "OR6API6AllCore.h"
#import "../priority6a/OR6API6APolicy.h"
#import "../priority6b/OR6API6BPolicy.h"
#import "../priority6c/OR6API6CPolicy.h"
#import "../priority6d/OR6API6DPolicy.h"
#import "../priority6e/OR6API6EPolicy.h"
#import "../priority6f/OR6API6FPolicy.h"
#import <dispatch/dispatch.h>
NSDictionary *OR6API6AllRegistry(NSDictionary *base,NSDictionary *x,NSError **error){
 if(![x isKindOfClass:NSDictionary.class]||x.count!=6){if(error)*error=OR6APIError(@"invalid_request",@"none");return nil;}
 for(NSString *k in @[@"6a",@"6b",@"6c",@"6d",@"6e",@"6f"])if(![x[k]isKindOfClass:NSDictionary.class]){if(error)*error=OR6APIError(@"invalid_request",@"none");return nil;}
 NSDictionary *r=OR6API6ARegistry(base,x[@"6a"],error);
 if(r)r=OR6API6BRegistry(r,x[@"6b"],error);
 if(r)r=OR6API6CRegistry(r,x[@"6c"],error);
 if(r)r=OR6API6DRegistry(r,x[@"6d"],error);
 if(r)r=OR6API6ERegistry(r,x[@"6e"],error);
 if(r)r=OR6API6FRegistry(r,x[@"6f"],error);
 return r;
}
@implementation OR6API6AllCore
- (id<OR6APITask>)perform:(NSString*)op parameters:(NSDictionary*)p event:(OR6APIEvent)event completion:(OR6APIReply)reply{
 if(!NSThread.isMainThread){if(reply)dispatch_async(dispatch_get_main_queue(),^{reply(nil,OR6APIError(@"invalid_request",@"none"));});return nil;}
 if(![op isKindOfClass:NSString.class]||![p isKindOfClass:NSDictionary.class]){if(reply)reply(nil,OR6APIError(@"invalid_request",@"none"));return nil;}
 NSString *command=[[op copy]autorelease];NSDictionary *request=OR6APIJSONSnapshot(p,512*1024);
 BOOL mutation=OR6API6AMutation(command)||OR6API6BMutation(command)||OR6API6CMutation(command)||OR6API6DMutation(command)||OR6API6EMutation(command)||OR6API6FMutation(command);
 return [super perform:command parameters:request event:event completion:^(NSDictionary *r,NSError *e){
  // Core invalidation can complete before cancellation reaches a child journal.
  // Preserve uncertainty until that provider's explicit reconciliation decides.
  if(mutation&&[@[@"cancelled",@"stale_context",@"invalid_response"]containsObject:e.userInfo[@"code"]]&&[e.userInfo[@"dispatch"]isEqual:@"none"])e=OR6APIError(e.userInfo[@"code"],@"possible");
  if(reply)reply(r,e);
 }];
}
@end
