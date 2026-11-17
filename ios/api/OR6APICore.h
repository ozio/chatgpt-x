#import <Foundation/Foundation.h>
#import "OR6APISchema.h"
@protocol OR6APITask <NSObject>
- (void)cancel;
@end
typedef void (^OR6APIEvent)(NSDictionary *event);
typedef void (^OR6APIReply)(NSDictionary *result,NSError *error);
@protocol OR6APIProvider <NSObject>
// Main-thread API. Provider replies/events on main too, bounded/backpressured.
// Context is opaque owner+workspace namespace and generation, never credentials.
- (id<OR6APITask>)execute:(NSString *)operation parameters:(NSDictionary *)parameters
 context:(NSDictionary *)context event:(OR6APIEvent)event completion:(OR6APIReply)completion;
@optional
- (void)didValidate:(NSString *)operation result:(NSDictionary *)result context:(NSDictionary *)context;
- (void)releaseCompletedDraft:(NSString *)draftId context:(NSDictionary *)context;
@end
@class OR6APIOperations;
@interface OR6APICore:NSObject {
 NSDictionary *_registry,*_operations,*_context;
 id<OR6APIProvider> _provider;
 NSMutableSet *_active;
 OR6APIOperations *_journal;
 NSUInteger _generation;
}
- (id)initWithRegistry:(NSDictionary *)registry provider:(id<OR6APIProvider>)provider
 journalDirectory:(NSString *)directory error:(NSError **)error;
// Invalidates all old callbacks, then changes cache/journal namespace. The key
// must be supplied by the trusted session adapter, not an editable UI user ID.
- (void)setContextKey:(NSString *)key;
- (id<OR6APITask>)perform:(NSString *)operation parameters:(NSDictionary *)parameters
 event:(OR6APIEvent)event completion:(OR6APIReply)completion;
- (void)cancelAll;
- (NSDictionary *)diagnostics;
@end
