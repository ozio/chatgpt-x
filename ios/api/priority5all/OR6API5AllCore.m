#import "OR6API5AllCore.h"
#import "../priority5a/OR6API5APolicy.h"
#import "../priority5b/OR6API5BPolicy.h"
#import "../priority5c/OR6API5CPolicy.h"
#import "../priority5d/OR6API5DPolicy.h"
#import "../priority5e/OR6API5EPolicy.h"
#import "../priority6a/OR6API6APolicy.h"
#import "../priority6b/OR6API6BPolicy.h"
#import "../priority6c/OR6API6CPolicy.h"
#import "../priority6d/OR6API6DPolicy.h"
#import "../priority6e/OR6API6EPolicy.h"
#import "../priority6f/OR6API6FPolicy.h"
#import "../priority7/OR6API7Policy.h"
#import "../priority7b/OR6API7BPolicy.h"
#import "../priority7d/OR6API7DPolicy.h"
#import "../priority7e/OR6API7EPolicy.h"
#import "../priority7f/OR6API7FPolicy.h"
#import <dispatch/dispatch.h>
NSDictionary *OR6API5AllRegistry(NSDictionary *base,NSDictionary *x,NSError **error){
 if(![x isKindOfClass:NSDictionary.class]||x.count!=5){if(error)*error=OR6APIError(@"invalid_request",@"none");return nil;}
 for(NSString *k in @[@"5a",@"5b",@"5c",@"5d",@"5e"])if(![x[k]isKindOfClass:NSDictionary.class]){if(error)*error=OR6APIError(@"invalid_request",@"none");return nil;}
 NSDictionary *r=OR6API5ARegistry(base,x[@"5a"],error);
 if(r)r=OR6API5BRegistry(r,x[@"5b"],error);
 if(r)r=OR6API5CRegistry(r,x[@"5c"],error);
 if(r)r=OR6API5DRegistry(r,x[@"5d"],error);
 if(r)r=OR6API5ERegistry(r,x[@"5e"],error);
 return r;
}
static BOOL EarlierMutation(NSString*op,NSDictionary*p){
 return OR6API6AMutation(op)||OR6API6BMutation(op)||OR6API6CMutation(op)||OR6API6DMutation(op)||OR6API6EMutation(op)||OR6API6FMutation(op)||OR6API7Mutation(op)||OR6API7BMutation(op)||OR6API7DMutation(op)||OR6API7EMutation(op)||OR6API7FMutation(op)||([op isEqual:@"images.export"]&&[p[@"destination"]isEqual:@"photos"])||[@[@"messages.send",@"messages.edit",@"messages.regenerate",@"messages.retry",@"assets.upload",@"dictation.transcribe",@"messages.stop",@"dictation.retry",@"translation.translate",@"search.web",@"assets.download"]containsObject:op];
}
@implementation OR6API5AllCore
- (id<OR6APITask>)perform:(NSString*)op parameters:(NSDictionary*)p event:(OR6APIEvent)event completion:(OR6APIReply)reply{
 if(!NSThread.isMainThread){if(reply)dispatch_async(dispatch_get_main_queue(),^{reply(nil,OR6APIError(@"invalid_request",@"none"));});return nil;}
 if(![op isKindOfClass:NSString.class]||![p isKindOfClass:NSDictionary.class]){if(reply)reply(nil,OR6APIError(@"invalid_request",@"none"));return nil;}
 [[self retain]autorelease];NSUInteger generation=_generation;
 NSString *command=[[op copy]autorelease];NSDictionary *request=OR6APIJSONSnapshot(p,512*1024);
 BOOL mutation=OR6API5AMutation(command)||OR6API5BMutation(command)||OR6API5CMutation(command)||OR6API5DMutation(command)||OR6API5EMutation(command);
 BOOL finalMutation=mutation||EarlierMutation(command,request);
 return [super perform:command parameters:request event:event completion:^(NSDictionary *r,NSError *e){
  if(generation!=_generation){r=nil;e=OR6APIError(@"stale_context",finalMutation||[e.userInfo[@"dispatch"]isEqual:@"possible"]?@"possible":@"none");}
  // Core invalidation can complete before cancellation reaches a child journal.
  // Preserve uncertainty until that provider's explicit reconciliation decides.
  if(mutation&&[@[@"cancelled",@"stale_context",@"invalid_response"]containsObject:e.userInfo[@"code"]]&&[e.userInfo[@"dispatch"]isEqual:@"none"])e=OR6APIError(e.userInfo[@"code"],@"possible");
  if(reply)reply(r,e);
 }];
}
@end
