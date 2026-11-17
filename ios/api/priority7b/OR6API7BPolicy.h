#import "../OR6APICore.h"
NSDictionary *OR6API7BRegistry(NSDictionary *base, NSDictionary *extension, NSError **error);
BOOL OR6API7BMutation(NSString *operation);
BOOL OR6API7BCommand(NSString *operation);
NSString *OR6API7BDigest(id value);
NSDictionary *OR6API7BPersonalization(id raw, NSError **error);
NSDictionary *OR6API7BMemory(id raw, NSError **error);
NSDictionary *OR6API7BCatalog(id raw, BOOL traits, NSError **error);
NSURLRequest *OR6API7BRead(NSString *operation);
NSURLRequest *OR6API7BWrite(NSString *category, NSDictionary *step);
BOOL OR6API7BAllowedRequest(NSURLRequest *request);
// Plan contains private immutable wire target and bounded ordered steps.
NSDictionary *OR6API7BPlan(NSString *operation, NSDictionary *parameters, NSDictionary *snapshot, NSDictionary *catalog, NSDictionary *memoryPolicy, NSError **error);
BOOL OR6API7BMatches(NSDictionary *plan, NSDictionary *snapshot);
