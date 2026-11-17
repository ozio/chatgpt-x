#import "../OR6APICore.h"
NSDictionary *OR6API5ARegistry(NSDictionary *base,NSDictionary *extension,NSError **error);
BOOL OR6API5ACommand(NSString *operation);
BOOL OR6API5AMutation(NSString *operation);
NSURLRequest *OR6API5ARequest(NSString *operation,NSDictionary *parameters);
BOOL OR6API5AAllowedRequest(NSURLRequest *request);
NSDictionary *OR6API5ADecode(NSString *operation,id raw,NSDictionary *parameters,NSError **error);
// Private native GG invitation parser; never place this dictionary in a Core DTO.
NSDictionary *OR6API5AInvitation(NSString *URL);
