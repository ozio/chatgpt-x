#import "OR6API8Core.h"
#import "../OR6APIOperations.h"
@implementation OR6API8Core
- (id<OR6APITask>)perform:(NSString*)op parameters:(NSDictionary*)p event:(OR6APIEvent)event completion:(OR6APIReply)reply {
 if([op isEqual:@"assets.processing.resume"]){NSDictionary*ctx=[[_context copy]autorelease];if(NSThread.isMainThread&&OR6APISchemaCheck(p,_operations[op][@"requestSchema"],_registry[@"types"])){NSDictionary*original=[_journal record:p[@"operationId"]scope:ctx[@"key"]error:NULL];if(![original[@"command"]isEqual:@"assets.upload"]||![original[@"request"][@"assetId"]isEqual:p[@"assetId"]]){if(reply)reply(nil,OR6APIError(@"invalid_operation_state",@"none"));return nil;}}return[super perform:op parameters:p event:event completion:^(NSDictionary*r,NSError*e){if([@[@"cancelled",@"stale_context",@"invalid_response"]containsObject:e.userInfo[@"code"]]&&[e.userInfo[@"dispatch"]isEqual:@"none"])e=OR6APIError(e.userInfo[@"code"],@"possible");if(!e){NSDictionary*original=[_journal record:p[@"operationId"]scope:ctx[@"key"]error:NULL];if(![original[@"command"]isEqual:@"assets.upload"]||![original[@"request"][@"assetId"]isEqual:p[@"assetId"]]||![_journal finish:p[@"operationId"]scope:ctx[@"key"]state:@"completed"metadata:r error:NULL]){r=nil;e=OR6APIError(@"storage_failure",@"possible");}}if(reply)reply(r,e);}];}
 BOOL extra=[@[@"translation.translate",@"search.web",@"assets.download"]containsObject:op];
 if(!extra||!NSThread.isMainThread||!OR6APISchemaCheck(p,_operations[op][@"requestSchema"],_registry[@"types"]))return[super perform:op parameters:p event:event completion:reply];
 NSDictionary*ctx=[[_context copy]autorelease];NSError*error=nil;
 if(![_journal reserve:p[@"operationId"]command:op request:p scope:ctx[@"key"]error:&error]){if(reply)reply(nil,error);return nil;}
 return[super perform:op parameters:p event:event completion:^(NSDictionary*r,NSError*e){
  if([@[@"cancelled",@"stale_context"]containsObject:e.userInfo[@"code"]]&&[e.userInfo[@"dispatch"]isEqual:@"none"])e=OR6APIError(e.userInfo[@"code"],@"possible");
  NSString*state=e?([e.userInfo[@"dispatch"]isEqual:@"none"]?@"rejected":@"uncertain"):@"completed";
  if(![_journal finish:p[@"operationId"]scope:ctx[@"key"]state:state metadata:r?:@{} error:NULL]){r=nil;e=OR6APIError(@"storage_failure",@"possible");}if(reply)reply(r,e);
 }];
}
@end
