#import <UIKit/UIKit.h>
#import "OR6ChatCodexModel.h"
UIViewController*OR6ChatCodexHome(id<OR6ChatCodexBackend>backend);
UIViewController*OR6ChatCodexForm(id<OR6ChatCodexBackend>backend,NSString*page,NSDictionary*parameters,void(^done)(NSDictionary*result));
UIViewController*OR6ChatCodexTask(id<OR6ChatCodexBackend>backend,NSString*thread,NSString*title);
void OR6ChatCodexAlert(NSString*title,NSString*message,NSString*action,BOOL input,void(^done)(NSString*text));
NSString*OR6ChatCodexError(NSError*error);

UIViewController*OR6ChatCodexReadOnlyTask(id<OR6ChatCodexBackend>backend,NSString*parent,NSString*thread,NSString*title);
