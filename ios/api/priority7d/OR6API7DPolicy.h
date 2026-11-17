#import "../OR6APICore.h"
NSDictionary *OR6API7DRegistry(NSDictionary *base,NSDictionary *extension,NSError **error);
BOOL OR6API7DCommand(NSString *operation);
BOOL OR6API7DMutation(NSString *operation);
BOOL OR6API7DProjectID(id value);
NSDictionary *OR6API7DProject(id raw,NSString *expected,NSError **error);
NSArray *OR6API7DFiles(id raw,NSError **error);
NSDictionary *OR6API7DConversation(id raw,NSString *expected,NSError **error);
NSURLRequest *OR6API7DRequest(NSString *operation,NSDictionary *parameters,id body,NSString *cursor,NSError **error);
BOOL OR6API7DAllowedRequest(NSURLRequest *request);
