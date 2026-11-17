#import <Foundation/Foundation.h>
// Worker primitive. Request authorization stays in the private session adapter.
// Wire events are delivered synchronously for bounded UI backpressure.
NSDictionary *OR6ChatNativeHTTP(NSURLRequest *request,NSString *roots,BOOL stream,
 BOOL(^cancelled)(void),BOOL(^events)(NSArray *events));
