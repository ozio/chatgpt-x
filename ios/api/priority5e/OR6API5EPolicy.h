#import "../OR6APICore.h"
BOOL OR6API5EUUID(id value);
BOOL OR6API5EID(id value);
BOOL OR6API5ECommand(NSString*operation);
BOOL OR6API5EMutation(NSString*operation);
NSDictionary*OR6API5ERegistry(NSDictionary*base,NSDictionary*extension,NSError**error);
NSURLRequest*OR6API5ERequest(NSString*operation,NSDictionary*parameters,NSError**error);
BOOL OR6API5EAllowedRequest(NSURLRequest*request);
NSDictionary*OR6API5EProject(NSString*operation,id raw,NSDictionary*parameters,NSError**error);
NSString*OR6API5ERole(id role);
NSString*OR6API5EValidateSchedule(id value,BOOL quiet);
NSDictionary*OR6API5EHours(NSDictionary*settings,BOOL quiet,id memberId);
BOOL OR6API5ELocked(NSDictionary*settings,NSArray*features);
BOOL OR6API5EIdentifier(NSString*value,NSString*kind);
NSDictionary*OR6API5EQuietStatus(NSDictionary*schedule,NSDate*instant,NSTimeZone*timeZone);
