#import <Foundation/Foundation.h>
BOOL OR6API9UUID(id value);
NSDictionary *OR6API9WAVInfo(NSData *data,NSError **error);
NSURLRequest *OR6API9TranscriptionRequest(NSData *data,NSString *boundary,NSError **error);
NSURLRequest *OR6API9StopRequest(NSString *conversation,NSString *conduitToken,NSError **error);
// Build semantic DTOs from already rendered content. UIKit focus/activation is
// an explicit UI adapter responsibility; no clipboard, media or URL side effect.
NSArray *OR6API9AccessibleContent(NSDictionary *presentation,NSError **error);
NSDictionary *OR6API9AccessibleControl(NSString *identifier,NSString *label,NSString *hint,NSString *action,BOOL enabled,BOOL selected,NSError **error);
