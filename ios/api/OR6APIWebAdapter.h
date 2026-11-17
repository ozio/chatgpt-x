#import "OR6APICore.h"
#import "../auth/OR6WebSession.h"
// Private composition adapter; UI receives OR6APICore only. No token getter.
@interface OR6APIWebAdapter:NSObject<OR6APIProvider>{
 OR6WebSession *_session;NSString *_roots,*_workspace;
 NSSet *_permittedReads;
 NSMutableDictionary *_searchCursors;
 NSUInteger _contextEpoch;
}
- (id)initWithSession:(OR6WebSession *)session roots:(NSString *)roots workspace:(NSString *)workspace permittedReads:(NSSet *)operations;
- (NSString *)contextKey;
// Internal composition boundary. Never expose these requests to UI/JavaScript.
- (NSUInteger)credentialGeneration;
- (NSURLRequest *)authorizeChatRequest:(NSURLRequest *)request expectedKey:(NSString *)key;
- (NSURLRequest *)authorizeRealtimeRequest:(NSURLRequest *)request expectedKey:(NSString *)key;
- (BOOL)acceptChatCookies:(NSArray *)headers expectedKey:(NSString *)key generation:(NSUInteger)generation;
- (BOOL)chatMatchesOwner:(NSString *)owner;
- (NSTimeInterval)recentChatOwnerValidationAgeForKey:(NSString *)key generation:(NSUInteger)generation;
- (BOOL)recordChatOwnerValidation:(NSString *)owner expectedKey:(NSString *)key generation:(NSUInteger)generation;
@end
