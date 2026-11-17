#import "../OR6APICore.h"
NSDictionary *OR6API4BRegistry(NSDictionary *base,NSDictionary *extension,NSError **error);
BOOL OR6API4BCommand(NSString *operation);
BOOL OR6API4BMutation(NSString *operation);
BOOL OR6API4BIdentifier(id value);
BOOL OR6API4BUUID(id value);
NSString *OR6API4BDigest(id value);
NSURLRequest *OR6API4BRequest(NSString *operation,NSDictionary *parameters,NSDictionary *identity);
BOOL OR6API4BAllowedRequest(NSURLRequest *request);
NSDictionary *OR6API4BSkill(id raw,NSDictionary *policy,NSError **error);
NSDictionary *OR6API4BAutomation(id raw,NSError **error);
