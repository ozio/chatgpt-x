#import "OR6WebSession.h"
@interface OR6WebTransport:NSObject<OR6WebProvider>{NSString *_roots;NSTimeInterval (^_clock)(void);}
- (id)initWithRoots:(NSString *)roots clock:(NSTimeInterval (^)(void))clock;
@end
