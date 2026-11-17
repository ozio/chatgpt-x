#import "../priority7/OR6API7Network.h"
#import "OR6API5BTransfer.h"
@interface OR6API5BNetwork:NSObject<OR6API7HTTP,OR6API5BHTTP>{OR6APIWebAdapter*_adapter;NSString*_roots;NSSet*_contentHosts;OR6API5BTransfer*_transfer;}
- (id)initWithAdapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots;
// Optional explicit trusted host set for private signed note-content URLs.
// These hosts receive neither Authorization nor session cookies.
- (id)initWithAdapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots contentHosts:(NSSet*)hosts;
@end
