#import <Foundation/Foundation.h>
extern NSString *const OR6APIErrorDomain;
// Fixed safe code + dispatch(none|possible|confirmed), never underlying errors.
NSError *OR6APIError(NSString *code, NSString *dispatch);
NSDictionary *OR6APIErrorDTO(NSError *error, NSString *operationId);
id OR6APIJSONSnapshot(id value, NSUInteger maximumBytes);
BOOL OR6APISchemaCheck(id value, NSDictionary *schema, NSDictionary *types);
