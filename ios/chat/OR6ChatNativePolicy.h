#import <Foundation/Foundation.h>
BOOL OR6CNUUID(id value);
BOOL OR6CNSameUUID(id a,id b);
NSString *OR6CNHash(NSString *value);
NSDictionary *OR6CNHeaders(id value);
NSDictionary *OR6CNBody(NSString *text,NSString *user,NSString *parent,NSString *conversation,NSString *model);
NSString *OR6CNReadback(NSDictionary *conversation,NSString *cid,NSString *uid,NSString *aid,NSString *hash);
// Identity-bound recovery snapshot; may still be in progress.
NSDictionary *OR6CNRecoveryMessage(NSDictionary *conversation,NSString *cid,NSString *uid,NSString *aid,NSString *hash);
NSTimeInterval OR6CNRecoveryDelay(NSUInteger completedReads);

// Canonical visible final answer of a planned turn, bound to the original user/hash.
NSString *OR6CNPlanReadback(NSDictionary *conversation, NSString *conversationID, NSString *userID, NSString *textHash);
