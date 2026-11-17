#import "OR6CodexProvider.h"
@interface OR6CodexOperation:NSObject<OR6APITask>{@public id<OR6APITask> task;OR6APIReply reply;void(^cancelAction)(void);BOOL done;NSUInteger serial;NSString *scopeKey;}
- (void)finish:(NSDictionary*)result error:(NSError*)error;
@end

@interface OR6CodexProvider(Extras)
- (BOOL)handles8:(NSString*)operation;
- (id<OR6APITask>)execute8:(NSString*)operation parameters:(NSDictionary*)parameters completion:(OR6APIReply)completion;
@end

@interface OR6CodexProvider(Seven)
- (BOOL)handles7:(NSString*)operation;
- (id<OR6APITask>)execute7:(NSString*)operation parameters:(NSDictionary*)parameters completion:(OR6APIReply)completion;
@end
