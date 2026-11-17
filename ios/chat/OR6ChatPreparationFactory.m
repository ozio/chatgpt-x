#import "OR6ChatPreparationFactory.h"
#import "OR6ChatWebPreparation.h"
#import "stock/OR6ChatStockPreparation.h"
#import "../auth/OR6AuthEngine.h"
id<OR6ChatPreparation> OR6ChatCreatePreparation(UIView*host,NSString*roots){
 NSDictionary*engine=OR6AuthEngine();BOOL injected=[engine[@"modernWebKit"]boolValue]||[engine[@"modernJSC"]boolValue]||[engine[@"secureBridge"]boolValue];
 return injected?(id)[[[OR6ChatWebPreparation alloc]initWithHostView:host]autorelease]:(id)[[[OR6ChatStockPreparation alloc]initWithHostView:host roots:roots]autorelease];
}
