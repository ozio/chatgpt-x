#import <Foundation/Foundation.h>

@protocol OR6WebStore <NSObject>
- (NSDictionary *)load:(NSInteger *)status;
- (BOOL)save:(NSDictionary *)record status:(NSInteger *)status;
- (NSDictionary *)legacy:(NSInteger *)status;
- (BOOL)clearLegacy:(NSInteger *)status;
@end
@protocol OR6WebCookieJar <NSObject>
- (NSArray *)snapshot;
- (void)install:(NSArray *)records;
- (void)clear;
@end
@protocol OR6WebTask <NSObject>
- (void)cancel;
@end
typedef void (^OR6WebReply)(NSDictionary *result);
@protocol OR6WebProvider <NSObject>
- (id<OR6WebTask>)validate:(NSString *)token owner:(NSString *)owner completion:(OR6WebReply)completion;
- (id<OR6WebTask>)fetch:(NSArray *)cookies completion:(OR6WebReply)completion;
@end
@class OR6WebSession;
@protocol OR6WebSessionDelegate <NSObject>
- (void)webSessionChanged:(OR6WebSession *)session;
@end
// Main-thread coordinator. Replies carry private data only inside this process.
// Diagnostics/delegate events never contain record/cookie/token/owner values.
@interface OR6WebSession:NSObject {
    id<OR6WebStore> _store;id<OR6WebProvider> _provider;id<OR6WebCookieJar> _jar;id<OR6WebTask> _task;
    id<OR6WebSessionDelegate> _delegate;NSTimeInterval (^_clock)(void),(^_validationClock)(void);
    NSDictionary *_record,*_prior;NSString *_phase,*_issue;
    NSUInteger _generation,_request,_revision,_restores,_renewals,_joins;NSInteger _storageStatus,_webStatus,_nativeStatus;
    NSTimeInterval _nextAutomatic,_cooldownUntil;
    NSTimeInterval _ownerValidatedAt,_ownerValidatedWall;
    NSUInteger _ownerValidatedGeneration;
    BOOL _ownerValidated;
    BOOL _busy,_authenticated,_priorAuthenticated,_migrating,_bearerChanged,_expiryAdvanced,_cleanupPending,_legacyPresent,_loginAttempt;
}
@property(nonatomic,assign)id<OR6WebSessionDelegate> delegate;
@property(nonatomic,readonly)NSString *phase;
@property(nonatomic,readonly)NSString *issue;
@property(nonatomic,readonly)BOOL authenticated;
@property(nonatomic,readonly)BOOL hasStoredSession;
@property(nonatomic,readonly)BOOL renewable;
@property(nonatomic,readonly)NSUInteger generation;
// Account profile from /me (fallback: the bearer's e-mail claim) for this iPhone's own
// account screen: {name?, email?}, nil when signed out. Never in diagnostics or receipts.
@property(nonatomic,readonly)NSDictionary *profile;
// Account and user ids from the validated bearer. Nil when they are absent.
// The token itself never leaves the session, and this dictionary is not logged.
- (NSDictionary *)serviceAccount;
- (id)initWithStore:(id<OR6WebStore>)store provider:(id<OR6WebProvider>)provider jar:(id<OR6WebCookieJar>)jar clock:(NSTimeInterval (^)(void))clock;
// Separate monotonic clock makes validation freshness independent of wall-clock edits.
- (id)initWithStore:(id<OR6WebStore>)store provider:(id<OR6WebProvider>)provider jar:(id<OR6WebCookieJar>)jar clock:(NSTimeInterval (^)(void))clock validationClock:(NSTimeInterval (^)(void))validationClock;
// Private native composition only: -1 means a new authenticated /me is required.
// Successful checks live in memory for <60 seconds, never in the stored record.
- (NSTimeInterval)recentOwnerValidationAge;
- (BOOL)recordOwnerValidation:(NSString *)owner generation:(NSUInteger)generation;
+ (BOOL)validAccessToken:(id)token;
+ (NSTimeInterval)tokenExpiry:(NSString *)token;
+ (BOOL)validRecord:(id)record;
- (void)restore;
- (void)renew;
- (void)activate;
- (NSTimeInterval)secondsUntilRenewal;
- (NSUInteger)beginSignIn;
- (BOOL)acceptWebCredential:(NSDictionary *)credential generation:(NSUInteger)generation;
- (void)cancelSignIn;
- (BOOL)signOut;
- (NSDictionary *)diagnostics;
@end
