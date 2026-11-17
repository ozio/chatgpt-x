#import "OR6ChatCodexRuntime.h"
extern NSString*const OR6ChatCodexModelChanged;
@interface OR6ChatCodexModel:NSObject{
 id<OR6ChatCodexBackend> _backend;NSMutableSet *_calls;NSMutableDictionary *_data;
 NSUInteger _epoch;NSString*_scopeID;NSError *_error;BOOL _stale,_uncertain;
}
- (id)initWithBackend:(id<OR6ChatCodexBackend>)backend;
@property(nonatomic,readonly)id<OR6ChatCodexBackend> backend;
@property(nonatomic,readonly)NSDictionary*data;
@property(nonatomic,readonly)NSError*error;
@property(nonatomic,readonly)BOOL busy,stale,uncertain;
- (id<OR6APITask>)call:(NSString*)operation parameters:(NSDictionary*)parameters slot:(NSString*)slot mutation:(BOOL)mutation completion:(OR6APIReply)completion;
- (void)cancel;
- (void)rebind;
- (BOOL)sameAccount;
@end
// Pure source-shaped projection; no UIKit or transport dependency.
NSArray*OR6ChatCodexHistoryRows(NSDictionary*snapshot,NSDictionary*status,NSDictionary*plans,NSString*thread);
NSDictionary*OR6ChatCodexInputResponse(NSDictionary*request,NSArray*selections);
NSArray*OR6ChatCodexOfferedDecisions(NSDictionary*request,BOOL allow);
