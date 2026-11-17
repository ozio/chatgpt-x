#import "../OR6CodexAPI.h"
#import "OR6CodexPairCrypto.h"

// Trusted native account source, never UI parameters. Required keys:
// context (the four Codex context keys), accountUserId, accessToken, expiresAt.
typedef NSDictionary *(^OR6CodexPairCredentials)(void);
@protocol OR6CodexPairVault <NSObject>
- (NSDictionary *)load:(NSError **)error;
- (BOOL)save:(NSDictionary *)value error:(NSError **)error;
@end
// Only injected by native composition or offline fixtures. Production fixes
// origins and endpoint names; caller-controlled origins/headers are impossible.
@protocol OR6CodexPairIO <NSObject>
- (id<OR6APITask>)request:(NSString *)endpoint parameters:(NSDictionary *)parameters
    headers:(NSDictionary *)headers completion:(OR6APIReply)completion;
- (void)invalidate;
@end
@interface OR6CodexPairHTTP : NSObject<OR6CodexPairIO> {
    NSString *_roots; NSMutableSet *_calls; NSUInteger _epoch; BOOL _stopped;
}
- (id)initWithRoots:(NSString *)roots;
@end
@interface OR6CodexPairKeychain : NSObject<OR6CodexPairVault> { NSString *_service; }
- (id)initWithService:(NSString *)service;
@end

@interface OR6CodexPair : NSObject {
    OR6CodexPairCredentials _source; NSDictionary *_snapshot;
    id<OR6CodexPairIO> _IO; id<OR6CodexPairVault> _vault;
    NSMutableDictionary *_record; NSMutableSet *_calls;
    NSString *_roots; NSDictionary *_contracts; NSString *_directory;
    id _authorization; NSString *_stepUp; NSTimeInterval _stepUpAt;
    BOOL _stopped; NSUInteger _epoch;
}
- (id)initWithCredentials:(OR6CodexPairCredentials)source IO:(id<OR6CodexPairIO>)IO
    vault:(id<OR6CodexPairVault>)vault roots:(NSString *)roots contracts:(NSDictionary *)contracts
    directory:(NSString *)directory error:(NSError **)error;
- (id<OR6APITask>)perform:(NSString *)operation parameters:(NSDictionary *)parameters completion:(OR6APIReply)completion;
- (BOOL)current;
- (NSDictionary *)status;
- (OR6CodexAPI *)newAPIForEnvironment:(NSString *)environment error:(NSError **)error;
- (void)invalidate;
@end
