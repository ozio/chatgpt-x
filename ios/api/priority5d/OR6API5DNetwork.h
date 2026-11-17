#import "OR6API5DProvider.h"
@class OR6APIWebAdapter;
@interface OR6API5DNetwork:NSObject<OR6API7HTTP,OR6API5DWorkspace>{OR6APIWebAdapter*_adapter;NSString*_roots;}
// Override only in the trusted native host. Runs on main immediately before
// persisting a proven exchange; no user callback is interposed before commit.
- (BOOL)canCommitWorkspace:(NSDictionary*)workspace context:(NSDictionary*)context;
- (id)initWithAdapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots;
@end
