#import "../OR6APICore.h"
BOOL OR6API6FCommand(NSString *operation);
BOOL OR6API6FMutation(NSString *operation);
BOOL OR6API6FUUID(id value);
NSString *OR6API6FNewUUID(void);
BOOL OR6API6FID(id value);
NSArray *OR6API6FLanguages(void);
NSURLRequest *OR6API6FRequest(NSString *operation,NSDictionary *parameters,NSError **error);
BOOL OR6API6FAllowedRequest(NSURLRequest *request);
NSDictionary *OR6API6FProject(NSString *operation,id raw,NSDictionary *parameters,NSError **error);
NSDictionary *OR6API6FRegistry(NSDictionary *base,NSDictionary *extension,NSError **error);
