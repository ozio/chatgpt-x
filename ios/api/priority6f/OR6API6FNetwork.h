#import "../priority7/OR6API7Network.h"
@class OR6APIWebAdapter;
// Preview authority is derived only from a freshly authenticated voice catalogue.
// The opaque token is removed before GET; preview requests carry no credentials.
@protocol OR6API6FPreviewHTTP<OR6API7HTTP>
- (BOOL)bindPreviewURL:(NSURL*)URL token:(NSString*)token context:(NSDictionary*)context error:(NSError**)error;
- (void)clearPreviewBindings;
@end
@interface OR6API6FNetwork:NSObject<OR6API6FPreviewHTTP>{OR6APIWebAdapter*_adapter;NSString*_roots;NSMutableDictionary*_previews;}
- (id)initWithAdapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots;
@end
