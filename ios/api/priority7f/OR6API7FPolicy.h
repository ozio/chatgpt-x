#import "../OR6APICore.h"
NSDictionary *OR6API7FRegistry(NSDictionary *base,NSDictionary *extension,NSError **error);
BOOL OR6API7FCommand(NSString *operation);
BOOL OR6API7FMutation(NSString *operation);
NSString *OR6API7FUUID(void);
NSDictionary *OR6API7FPlan(NSString *operation,NSDictionary *parameters,NSDictionary *conversation,NSString *model,NSString *hint,NSDictionary *challenge,NSError **error);
NSDictionary *OR6API7FPending(NSString *operation,NSDictionary *raw,NSString *conversation,NSString *message,NSError **error);
NSURLRequest *OR6API7FRequest(NSString *operation,NSDictionary *parameters,NSError **error);
BOOL OR6API7FAllowedRequest(NSURLRequest *request);
NSDictionary *OR6API7FResult(NSDictionary *receipt,NSDictionary *assistant,NSError **error);
NSDictionary *OR6API7FImageResult(id raw,NSDictionary *binding,NSString *operationId,NSError **error);
// Authoritative active-branch history only: startup prose/stream COMPLETE never prove a research report.
NSDictionary *OR6API7FResearchResult(NSDictionary *conversation,NSDictionary *binding,NSString *operationId,NSError **error);
