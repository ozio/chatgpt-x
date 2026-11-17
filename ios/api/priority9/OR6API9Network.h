#import "OR6API9Provider.h"
@class OR6APIWebAdapter;
// Uses the existing private session authorization and native HTTP primitive.
// Independent connections allow Stop while the main generation stream is open.
@interface OR6API9Network:NSObject<OR6API9HTTP>{OR6APIWebAdapter*_adapter;NSString*_roots;}
- (id)initWithAdapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots;
@end
