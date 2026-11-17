#import "../OR6APICore.h"
// Private account/workspace scoped persistence. Never accepts caller paths.
@interface OR6API5CStore:NSObject
- (id)initWithDirectory:(NSString*)directory error:(NSError**)error;
- (NSDictionary*)readScope:(NSString*)scope error:(NSError**)error;
- (BOOL)write:(NSDictionary*)value scope:(NSString*)scope error:(NSError**)error;
@end
