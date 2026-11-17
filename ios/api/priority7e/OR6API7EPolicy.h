#import "../OR6APICore.h"
NSDictionary *OR6API7ERegistry(NSDictionary *base,NSDictionary *extension,NSError **error);
BOOL OR6API7ECommand(NSString *operation);
BOOL OR6API7EMutation(NSString *operation);
NSDictionary *OR6API7ESettings(id raw,NSError **error);
NSURLRequest *OR6API7EPlansRequest(NSString *countryCode);
NSDictionary *OR6API7EPlans(id raw,NSString *countryCode,NSError **error);
NSDictionary *OR6API7ECenter(NSDictionary *settings,NSDictionary *age);
NSDictionary *OR6API7EAge(id raw,NSError **error);
NSDictionary *OR6API7ESecurity(id raw,NSError **error);
NSDictionary *OR6API7EHandoff(NSString *operation,NSDictionary *parameters,NSError **error);
NSURLRequest *OR6API7ERead(NSString *operation);
NSURLRequest *OR6API7EWrite(NSDictionary *step);
BOOL OR6API7EAllowedRequest(NSURLRequest *request);
NSDictionary *OR6API7EPlan(NSString *operation,NSDictionary *parameters,NSDictionary *snapshot,NSError **error);
BOOL OR6API7EMatches(NSDictionary *plan,NSDictionary *snapshot);
