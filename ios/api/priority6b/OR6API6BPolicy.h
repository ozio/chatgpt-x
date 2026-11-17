#import "../OR6APICore.h"
NSDictionary *OR6API6BRegistry(NSDictionary *base,NSDictionary *extension,NSError **error);
BOOL OR6API6BCommand(NSString *operation);
BOOL OR6API6BMutation(NSString *operation);
BOOL OR6API6BID(id value);
// Opaque link IDs may contain a colon; encode them as one URL path component.
BOOL OR6API6BLinkID(id value);
NSString *OR6API6BUUID(void);
NSURLRequest *OR6API6BRequest(NSString *operation,NSDictionary *parameters,NSError **error);
BOOL OR6API6BAllowedRequest(NSURLRequest *request);
NSDictionary *OR6API6BProject(NSString *operation,id raw,NSDictionary *parameters,NSError **error);
NSDictionary *OR6API6BPlan(NSString *operation,NSDictionary *parameters,NSDictionary *admission,NSDictionary *conversation,NSError **error);
NSArray *OR6API6BLinks(id raw,NSError **error);
BOOL OR6API6BEditableLink(NSDictionary *link,NSDictionary *identity);
