#import "OR6ChatCodexAccount.h"
#import "../../api/codex/OR6CodexPolicy8.h"
@interface OR6WebSession(CodexAccount)
- (NSDictionary*)codexPrivateSnapshot;
- (NSDictionary*)codexPairPrivateSnapshot;
@end
@implementation OR6WebSession(CodexAccount)
- (NSDictionary*)codexPrivateSnapshot{
 if(!NSThread.isMainThread||!_authenticated||_busy||!_ownerValidated||_ownerValidatedGeneration!=_generation||![_record[@"state"]isEqual:@"active"]||[_record[@"expiresAt"]doubleValue]<=_clock()+15)return nil;
 NSDictionary*identity=[self serviceAccount];if(!identity||!OR6CodexID(_record[@"owner"]))return nil;
 return@{@"context":@{@"owner":_record[@"owner"],@"workspace":identity[@"accountId"],@"connection":@"codex-cloud",@"credentialGeneration":@(MAX((NSUInteger)1,_generation))},@"userId":identity[@"userId"],@"accessToken":_record[@"accessToken"],@"expiresAt":_record[@"expiresAt"]};
}
- (NSDictionary*)codexPairPrivateSnapshot {
 NSDictionary *s=[self codexPrivateSnapshot];if(!s)return nil;
 NSDictionary *payload=OR6CodexPairClaims(_record[@"accessToken"]);id auth=payload[@"https://api.openai.com/auth"];
 if(![auth isKindOfClass:NSDictionary.class])return nil;
 NSString *user=auth[@"chatgpt_account_user_id"]?:auth[@"account_user_id"];
 if(!OR6CodexID(user))return nil;
 return @{@"context":s[@"context"],@"accountUserId":user,@"accessToken":s[@"accessToken"],@"expiresAt":s[@"expiresAt"]};
}
@end
@implementation OR6APIWebAdapter(CodexAccount)
- (NSDictionary*)codexAccountContext{return[_session codexPrivateSnapshot][@"context"];}
- (OR6CodexCloud*)newCodexCloudWithContracts:(NSDictionary*)c directory:(NSString*)d error:(NSError**)e{OR6WebSession*s=_session;return[[OR6CodexCloud alloc]initWithCredentials:^NSDictionary*{return[s codexPrivateSnapshot];}roots:_roots contracts:c privateDirectory:d error:e];}
- (OR6CodexPair*)newCodexPairWithContracts:(NSDictionary*)c directory:(NSString*)d error:(NSError**)e {
 OR6WebSession *session=_session;NSDictionary *s=[session codexPairPrivateSnapshot];
 if(!s){if(e)*e=OR6CodexError(@"not_authenticated",NO);return nil;}
 NSString *service=[@"io.ozio.chatgptx.chat.codex.relay."stringByAppendingString:OR6CodexDigest([NSString stringWithFormat:@"%lu:%@%lu:%@%lu:%@",(unsigned long)[s[@"context"][@"owner"]length],s[@"context"][@"owner"],(unsigned long)[s[@"context"][@"workspace"]length],s[@"context"][@"workspace"],(unsigned long)[s[@"accountUserId"]length],s[@"accountUserId"]])];
 OR6CodexPairHTTP *IO=[[[OR6CodexPairHTTP alloc]initWithRoots:_roots]autorelease];OR6CodexPairKeychain *vault=[[[OR6CodexPairKeychain alloc]initWithService:service]autorelease];
 return [[OR6CodexPair alloc]initWithCredentials:^NSDictionary *{return [session codexPairPrivateSnapshot];}IO:IO vault:vault roots:_roots contracts:c directory:d error:e];
}
@end
