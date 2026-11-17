#import "../OR6APICore.h"
NSDictionary *OR6API6ERegistry(NSDictionary *base,NSDictionary *extension,NSError **error);
BOOL OR6API6ECommand(NSString *operation);
BOOL OR6API6EMutation(NSString *operation);
NSDictionary *OR6API6EHandoff(NSString *operation);
// Private server records contain revocation identifiers; never return them through Core.
NSArray *OR6API6ERecords(id raw,NSError **error);
NSDictionary *OR6API6EPublicDevice(NSDictionary *record,NSString *targetId);
NSString *OR6API6EFingerprint(NSString *scope,NSString *kind,NSString *identifier);
NSURLRequest *OR6API6ERequest(NSString *operation,NSDictionary *privateParameters,NSString *accountId);
BOOL OR6API6EAllowedRequest(NSURLRequest *request);
BOOL OR6API6EAcknowledged(NSDictionary *response);
