#import "../OR6APICore.h"
NSDictionary *OR6API6ARegistry(NSDictionary *base,NSDictionary *extension,NSError **error);
BOOL OR6API6ACommand(NSString *operation);
BOOL OR6API6AMutation(NSString *operation);
BOOL OR6API6APIN(id value);
NSDictionary *OR6API6AStatus(id raw,NSError **error);
NSDictionary *OR6API6ADecode(NSString *operation,id raw,NSDictionary *parameters,NSError **error);
NSURLRequest *OR6API6ARequest(NSString *operation,NSDictionary *parameters,NSDictionary *secrets);
BOOL OR6API6AAllowedRequest(NSURLRequest *request);
NSString *OR6API6AWireErrorCode(id raw);
