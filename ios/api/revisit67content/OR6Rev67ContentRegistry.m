#import "OR6Rev67Content.h"
#import "../OR6APISchema.h"
#include "OR6Rev67ContentContracts.inc"
BOOL OR6Rev67ContentMutation(NSString *op){return [op isKindOfClass:NSString.class]&&[OR6Rev67ContentTiers()[op]isEqual:@"user_action"];}
NSDictionary *OR6Rev67ContentRegistry(NSDictionary *base,NSError **error){
 if(![base[@"operations"]isKindOfClass:NSArray.class]||![base[@"types"]isKindOfClass:NSDictionary.class]){if(error)*error=OR6APIError(@"invalid_request",@"none");return nil;}
 NSMutableDictionary*r=[[base mutableCopy]autorelease];NSMutableArray*ops=[[base[@"operations"]mutableCopy]autorelease],*map=[NSMutableArray array];NSMutableSet*ids=[NSMutableSet set];for(NSDictionary*o in ops){if(![o[@"id"]isKindOfClass:NSString.class]||[ids containsObject:o[@"id"]]){if(error)*error=OR6APIError(@"conflict",@"none");return nil;}[ids addObject:o[@"id"]];}
 NSDictionary*x=Extension();NSMutableSet*features=[NSMutableSet set];for(NSDictionary*f in x[@"featureMap"])[features addObject:f[@"featureId"]];for(NSDictionary*f in base[@"featureMap"])if(![features containsObject:f[@"featureId"]])[map addObject:f];[map addObjectsFromArray:x[@"featureMap"]];
 for(NSDictionary*o in x[@"operations"]){if([ids containsObject:o[@"id"]]){if(error)*error=OR6APIError(@"conflict",@"none");return nil;}[ops addObject:o];[ids addObject:o[@"id"]];}r[@"operations"]=ops;r[@"featureMap"]=map;return OR6APIJSONSnapshot(r,4*1024*1024);
}
