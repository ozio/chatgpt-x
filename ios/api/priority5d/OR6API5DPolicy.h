#import "../OR6APICore.h"
NSDictionary *OR6API5DRegistry(NSDictionary *base,NSDictionary *extension,NSError **error);
BOOL OR6API5DCommand(NSString *operation);
BOOL OR6API5DMutation(NSString *operation);
BOOL OR6API5DText(id value,NSUInteger limit);
NSDictionary *OR6API5DHandoff(NSString *operation);
NSURLRequest *OR6API5DRequest(NSString *operation,NSDictionary *parameters,NSString *account);
BOOL OR6API5DAllowedRequest(NSURLRequest *request);
NSDictionary *OR6API5DDecode(NSString *operation,id raw,NSError **error);
