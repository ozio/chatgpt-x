#import "../OR6APICore.h"
// Extension registry is loaded by the trusted host, never from the network.
NSDictionary *OR6API7Registry(NSDictionary *base, NSDictionary *extension, NSError **error);
BOOL OR6API7UUID(id value);
BOOL OR6API7Mutation(NSString *operation);
BOOL OR6API7Command(NSString *operation);
NSURLRequest *OR6API7Request(NSString *operation, NSDictionary *parameters, NSError **error);
BOOL OR6API7AllowedRequest(NSURLRequest *request);
NSDictionary *OR6API7Share(id value, NSString *expectedID, NSError **error);
NSDictionary *OR6API7Code(NSDictionary *parameters, NSError **error);

// Public snapshots may omit the sole empty root parent; owned wire graphs remain strict.
NSDictionary *OR6API7SharedConversation(id value,NSString *shareId,NSError **error);
