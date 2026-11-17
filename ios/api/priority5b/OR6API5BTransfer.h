#import "../OR6APICore.h"
@class OR6APIWebAdapter;
@protocol OR6API5BHTTP <NSObject>
// kind: json, process, content (private same-origin auth), or blob (signed PUT).
// Results/URLs/bytes stay inside providers; DTOs contain only opaque handles.
- (id<OR6APITask>)request:(NSURLRequest*)request kind:(NSString*)kind file:(NSString*)file
 context:(NSDictionary*)context completion:(OR6APIReply)completion;
@end
@interface OR6API5BTransfer:NSObject<OR6API5BHTTP>{OR6APIWebAdapter*_adapter;NSString*_roots;NSSet*_storageHosts;}
- (id)initWithAdapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots storageHosts:(NSSet*)hosts;
@end
