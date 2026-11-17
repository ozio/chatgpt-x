#import "../OR6APICore.h"
NSDictionary *OR6API6CRegistry(NSDictionary *base,NSDictionary *extension,NSError **error);
BOOL OR6API6CCommand(NSString *operation);
BOOL OR6API6CMutation(NSString *operation);
BOOL OR6API6CNativeID(id value);
BOOL OR6API6CProjectID(id value);
BOOL OR6API6CExternalID(id value,NSString *provider);
NSDictionary *OR6API6CProject(id raw,NSString *expected,NSDictionary *identity,NSError **error);
NSDictionary *OR6API6CNode(id raw,NSString *expected,BOOL fileResponse,NSError **error);
NSArray *OR6API6CNodes(id raw,BOOL fileResponse,NSError **error);
NSDictionary *OR6API6CCapabilities(id raw,NSError **error);
NSDictionary *OR6API6CFavorite(id raw,NSString *target,NSError **error);
NSDictionary *OR6API6CAutoContext(id raw,NSError **error);
NSURLRequest *OR6API6CRequest(NSString *operation,NSDictionary *parameters,id body,NSString *cursor,NSError **error);
BOOL OR6API6CAllowedRequest(NSURLRequest *request);

NSDictionary*OR6API6CEntityDescriptor(id raw,NSError**error);
NSString*OR6API6CEntityKey(NSDictionary*target);
NSDictionary*OR6API6CEntityStatus(id raw,NSDictionary*descriptor,NSString*reference,NSError**error);
NSString*OR6API6CFavoriteKind(NSDictionary*raw);

NSArray*OR6API6CResponses(id raw,NSError**error);
