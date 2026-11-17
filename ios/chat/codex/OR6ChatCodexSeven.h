#import "OR6ChatCodexScreens.h"
BOOL OR6ChatCodexSevenAvailable(NSDictionary *status);
NSString *OR6ChatCodexGoalTitle(id status);
UIViewController *OR6ChatCodexSevenPage(id<OR6ChatCodexBackend>backend,NSString *page,NSDictionary *parameters,void(^done)(NSDictionary*));
