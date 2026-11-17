#import "../OR6APICore.h"
@class OR6APIWebAdapter;
@protocol OR6API7HTTP <NSObject>
- (id<OR6APITask>)request:(NSURLRequest *)request context:(NSDictionary *)context completion:(OR6APIReply)completion;
@end
// Private transport; authorized requests and raw JSON never become UI DTOs.
@interface OR6API7Network : NSObject <OR6API7HTTP> {
    OR6APIWebAdapter *_adapter;
    NSString *_roots;
}
- (id)initWithAdapter:(OR6APIWebAdapter *)adapter roots:(NSString *)roots;
@end
