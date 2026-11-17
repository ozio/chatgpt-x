#import "OR6CodexProtocol.h"
// A bounded working set, not an unbounded copy of a remote rollout. Page cursors
// are owned by the caller; reconnect replaces snapshots before accepting deltas.
@interface OR6CodexTranscript:NSObject {
 NSMutableDictionary *_items,*_turns,*_diffs,*_plans;
 NSMutableArray *_order;
 NSMutableSet *_complete,*_hydrated;
 NSMutableDictionary *_gaps;
 NSUInteger _revision;
}
- (NSUInteger)revision;
- (void)invalidate;
- (void)reset;
- (BOOL)consume:(NSString*)method parameters:(NSDictionary*)parameters;
- (BOOL)mergeItems:(NSArray*)items thread:(NSString*)thread beforeRevision:(NSUInteger)revision;
- (BOOL)mergeTurns:(NSArray*)turns thread:(NSString*)thread beforeRevision:(NSUInteger)revision;
- (NSDictionary*)snapshot:(NSString*)thread;
@end
