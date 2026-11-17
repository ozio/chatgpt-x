#import "../OR6APICore.h"
NSDictionary *OR6API6DRegistry(NSDictionary *base, NSDictionary *extension, NSError **error);
BOOL OR6API6DCommand(NSString *operation);
BOOL OR6API6DMutation(NSString *operation);
NSDictionary *OR6API6DTask(id raw, NSError **error);
NSDictionary *OR6API6DTasks(id raw, NSError **error);
NSDictionary *OR6API6DMemory(id raw, NSError **error);
NSDictionary *OR6API6DMemories(id raw, NSString *query, NSError **error);
NSDictionary *OR6API6DCapacity(id raw, NSError **error);
NSDictionary *OR6API6DAdvanced(id rawSettings, id rawContext, NSError **error);
NSDictionary *OR6API6DLocation(id raw, NSError **error);
BOOL OR6API6DIdentifier(id value);
NSDictionary *OR6API6DManagement(id raw,NSError **error);
NSDictionary *OR6API6DCitations(id raw,NSDictionary *parameters,NSDictionary *identity,NSError **error);
NSDictionary *OR6API6DTaskBody(NSDictionary *raw,NSDictionary *draft,BOOL create,NSError **error);
NSURLRequest *OR6API6DRequest(NSString *operation,NSDictionary *parameters,id body,NSDictionary *privateHeaders,NSString *cursor,NSError **error);
BOOL OR6API6DAllowedRequest(NSURLRequest *request);
