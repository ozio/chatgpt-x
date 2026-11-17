#import "OR6WebSession.h"
@interface OR6WebKeychain:NSObject<OR6WebStore>{NSString *_service,*_legacyService;}
- (id)initWithBundle:(NSString *)bundle;
@end
@interface OR6WebSystemJar:NSObject<OR6WebCookieJar>
@end
