#import "../OR6APICore.h"
NSDictionary *OR6API5BRegistry(NSDictionary *base,NSDictionary *extension,NSError **error);
BOOL OR6API5BCommand(NSString *operation);
BOOL OR6API5BMutation(NSString *operation);
BOOL OR6API5BIdentifier(id value);
BOOL OR6API5BUUID(id value);
BOOL OR6API5BSource(id descriptor);
BOOL OR6API5BFile(id descriptor);
NSURLRequest *OR6API5BRequest(NSString *operation,NSDictionary *parameters,NSDictionary *body,NSDictionary *identity,NSError **error);
BOOL OR6API5BAllowedRequest(NSURLRequest *request);
NSDictionary *OR6API5BDecode(NSString *operation,id raw,NSDictionary *parameters,NSDictionary *identity,NSError **error);
NSDictionary *OR6API5BProcessing(NSData *bytes,NSString *file,BOOL final,NSError **error);
NSString *OR6API5BDigest(id value);
