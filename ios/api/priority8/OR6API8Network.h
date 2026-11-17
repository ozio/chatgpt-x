#import "../OR6APICore.h"
@class OR6APIWebAdapter;
@protocol OR6API8HTTP <NSObject>
// kind: json, process, content (private same-origin auth), or blob (signed PUT).
// Results/URLs/bytes stay inside providers; DTOs contain only opaque handles.
- (id<OR6APITask>)request:(NSURLRequest*)request kind:(NSString*)kind file:(NSString*)file
 context:(NSDictionary*)context completion:(OR6APIReply)completion;
@optional
// Called only for a destination from authenticated /files metadata, never a DTO.
- (BOOL)admitSignedUploadRequest:(NSURLRequest*)request file:(NSString*)file context:(NSDictionary*)context;
@end
@interface OR6API8Network:NSObject<OR6API8HTTP>{OR6APIWebAdapter*_adapter;NSString*_roots;NSSet*_storageHosts;NSDictionary*_diagnostics;NSMutableDictionary*_signedUploads;}
- (NSDictionary*)diagnostics;
- (id)initWithAdapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots storageHosts:(NSSet*)hosts;
@end
