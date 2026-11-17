#import "../OR6APICore.h"
BOOL OR6API5CUUID(id value);
BOOL OR6API5CID(id value);
BOOL OR6API5CCommand(NSString*operation);
BOOL OR6API5CMutation(NSString*operation);
NSDictionary*OR6API5CRegistry(NSDictionary*base,NSDictionary*extension,NSError**error);
NSURLRequest*OR6API5CRequest(NSString*operation,NSDictionary*parameters,NSError**error);
BOOL OR6API5CAllowedRequest(NSURLRequest*request);
NSDictionary*OR6API5CProject(NSString*operation,id raw,NSDictionary*parameters,NSError**error);
