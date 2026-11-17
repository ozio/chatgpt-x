#import "../OR6APICore.h"
NSDictionary *OR6API7CRegistry(NSDictionary *base,NSDictionary *extension,NSError **error);
BOOL OR6API7CCommand(NSString *operation);
BOOL OR6API7CLibraryID(id value);
BOOL OR6API7CHandle(id value);
NSDictionary *OR6API7CItem(id value,BOOL node,NSString *expectedID,NSError **error);
NSDictionary *OR6API7CPage(id value,NSUInteger limit,NSError **error);
NSDictionary *OR6API7CAsset(NSDictionary *item,NSString *handle,NSError **error);
NSURLRequest *OR6API7CRequest(NSString *operation,NSDictionary *parameters,NSString *cursor,NSError **error);
BOOL OR6API7CAllowedRequest(NSURLRequest *request);
