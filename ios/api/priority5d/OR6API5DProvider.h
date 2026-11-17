#import "../priority7/OR6API7Network.h"
@protocol OR6API5DWorkspace <NSObject>
// Native-only. The target is selected from a freshly observed server catalog.
// Raw token/cookies never cross the OR6API7HTTP/public result boundary.
- (id<OR6APITask>)selectWorkspace:(NSDictionary *)workspace context:(NSDictionary *)context completion:(OR6APIReply)completion;
@end
@interface OR6API5DProvider:NSObject<OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP extension:(NSDictionary *)extension journalDirectory:(NSString *)directory capabilities:(NSSet *)capabilities error:(NSError **)error;
- (BOOL)bindIdentity:(NSDictionary *)identity context:(NSDictionary *)context;
- (BOOL)bindPolicy:(NSDictionary *)policy context:(NSDictionary *)context;
- (void)deactivate;
- (NSDictionary *)diagnostics;
@end
