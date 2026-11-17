#import "../OR6APICore.h"
NSArray *OR6API6BBranch(id raw,NSString *conversation,NSError **error);
NSString *OR6API6BMessageText(NSDictionary *message);
NSDictionary *OR6API6BWorkModels(id raw,NSString *selected,NSError **error);
NSDictionary *OR6API6BHandoff(id raw,NSString *conversation,NSError **error);
NSString *OR6API6BHandoffResultID(NSString *handoff);
NSDictionary *OR6API6BHandoffMessage(NSDictionary *binding,BOOL accept,NSError **error);
