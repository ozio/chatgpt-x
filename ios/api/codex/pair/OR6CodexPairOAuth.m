#import "OR6CodexPairOAuth.h"
#import "../../../auth/OR6OAuthCrypto.h"
#include <math.h>
static BOOL Integer(id value,double low,double high){return [value isKindOfClass:NSNumber.class]&&CFGetTypeID((CFTypeRef)value)!=CFBooleanGetTypeID()&&isfinite([value doubleValue])&&[value doubleValue]==floor([value doubleValue])&&[value doubleValue]>=low&&[value doubleValue]<=high;}
static NSArray *Stages(void){return @[@"callback",@"token_exchange",@"token_validation"];}
static NSArray *Codes(void){return @[@"invalid_request",@"auth_cancelled",@"not_authenticated",@"service_challenge",@"rate_limited",@"not_found",@"upstream_error",@"network_unavailable",@"tls",@"invalid_response",@"unavailable",@"storage_failure"];}
static NSArray *OAuthCodes(void){return @[@"invalid_request",@"invalid_grant",@"invalid_client",@"unauthorized_client",@"unsupported_grant_type",@"invalid_scope",@"access_denied",@"server_error",@"temporarily_unavailable",@"interaction_required",@"login_required",@"consent_required",@"other"];}
static NSArray *Reasons(void){return @[@"invalid_callback",@"callback_expired",@"callback_used",@"state_mismatch",@"token_claims_mismatch"];}
NSDictionary *OR6CodexPairOAuthSafeDiagnostic(id value){
    if(!OR6CodexKeys(value,@[@"stage",@"code",@"at"],@[@"httpStatus",@"transportCode",@"oauthCode",@"responseType",@"reason"])||![Stages()containsObject:value[@"stage"]]||![Codes()containsObject:value[@"code"]]||!Integer(value[@"at"],1,1e12))return nil;
    if(value[@"httpStatus"]&&!Integer(value[@"httpStatus"],100,599))return nil;
    if(value[@"transportCode"]&&!Integer(value[@"transportCode"],1,12))return nil;
    if(value[@"oauthCode"]&&![OAuthCodes()containsObject:value[@"oauthCode"]])return nil;
    if(value[@"responseType"]&&![@[@"json",@"html",@"other"]containsObject:value[@"responseType"]])return nil;
    if(value[@"reason"]&&![Reasons()containsObject:value[@"reason"]])return nil;
    return OR6APIJSONSnapshot(value,2048);
}
NSError *OR6CodexPairOAuthFailure(NSString *code,BOOL possible,NSString *stage,NSDictionary *details){
    NSMutableDictionary *d=[NSMutableDictionary dictionaryWithDictionary:@{@"stage":[Stages()containsObject:stage]?stage:@"token_exchange",@"code":[Codes()containsObject:code]?code:@"unavailable",@"at":@((long long)[NSDate.date timeIntervalSince1970])}];
    if(Integer(details[@"httpStatus"],100,599))d[@"httpStatus"]=details[@"httpStatus"];
    if(Integer(details[@"transportCode"],1,12))d[@"transportCode"]=details[@"transportCode"];
    if(details[@"oauthCode"])d[@"oauthCode"]=[OAuthCodes()containsObject:details[@"oauthCode"]]?details[@"oauthCode"]:@"other";
    if([@[@"json",@"html",@"other"]containsObject:details[@"responseType"]])d[@"responseType"]=details[@"responseType"];
    if([Reasons()containsObject:details[@"reason"]])d[@"reason"]=details[@"reason"];
    NSError *base=OR6CodexError(d[@"code"],possible);NSMutableDictionary *info=[[base.userInfo mutableCopy]autorelease];info[@"oauthFailure"]=d;
    return [NSError errorWithDomain:base.domain code:base.code userInfo:info];
}
static NSString *Escape(NSString *s) {
    return (NSString *)[(id)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,(CFStringRef)s,NULL,CFSTR(":/?#[]@!$&'()*+,;=%"),kCFStringEncodingUTF8)autorelease];
}
@implementation OR6CodexPairOAuth
- (id)initWithWorkspace:(NSString *)workspace {
    if((self=[super init])) {
        if(!OR6CodexID(workspace)){[self release];return nil;}
        _workspace=[workspace copy];_created=[NSDate.date timeIntervalSince1970];
        _state=[[OR6OAuthCrypto base64urlStringForData:[OR6OAuthCrypto randomDataOfLength:32]]copy];
        _verifier=[[OR6OAuthCrypto base64urlStringForData:[OR6OAuthCrypto randomDataOfLength:32]]copy];
        if(!_state||!_verifier){[self release];return nil;}
    }return self;
}
- (NSURL *)URL {
    if(_consumed)return nil;
    NSDictionary *p=@{@"response_type":@"code",@"client_id":@"app_EMoamEEZ73f0CkXaXp7hrann",@"redirect_uri":@"http://localhost:1455/auth/callback",@"scope":@"codex.remote_control.enroll",@"code_challenge":[OR6OAuthCrypto pkceChallengeForVerifier:_verifier],@"code_challenge_method":@"S256",@"state":_state,@"originator":@"legacy_ios6",@"reauth":@"remote_control",@"max_age":@"0",@"codex_cli_simplified_flow":@"true",@"allowed_workspace_id":_workspace,@"current_workspace_id":_workspace};
    NSMutableArray *a=[NSMutableArray array];for(NSString *k in [[p allKeys]sortedArrayUsingSelector:@selector(compare:)])[a addObject:[NSString stringWithFormat:@"%@=%@",k,Escape(p[k])]];
    return [NSURL URLWithString:[@"https://auth.openai.com/oauth/authorize?"stringByAppendingString:[a componentsJoinedByString:@"&"]]];
}
- (NSDictionary *)consume:(NSURL *)URL error:(NSError **)error {
    NSString *reason=@"invalid_callback";
    if(_consumed){reason=@"callback_used";goto invalid;}
    if([NSDate.date timeIntervalSince1970]-_created>600){reason=@"callback_expired";goto invalid;}
    if(![[URL.scheme lowercaseString]isEqual:@"http"]||![URL.host isEqual:@"localhost"]||![URL.port isEqual:@1455]||![URL.path isEqual:@"/auth/callback"]||URL.user||URL.password||URL.fragment||!OR6CodexText(URL.query,8192,NO))goto invalid;
    NSMutableDictionary *p=[NSMutableDictionary dictionary];
    for(NSString *item in [URL.query componentsSeparatedByString:@"&"]) {
        NSArray *a=[item componentsSeparatedByString:@"="];if(a.count!=2)goto invalid;
        NSString *k=[a[0]stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding],*v=[[a[1]stringByReplacingOccurrencesOfString:@"+"withString:@" "]stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        if(!k||!v||p[k])goto invalid;p[k]=v;
    }
    if(![p[@"state"]isEqual:_state]){reason=@"state_mismatch";goto invalid;}
    _consumed=YES;
    if(p[@"error"]){if(error)*error=OR6CodexPairOAuthFailure(@"auth_cancelled",NO,@"callback",@{@"oauthCode":p[@"error"]});return nil;}
    if(!OR6CodexText(p[@"code"],4096,NO)||p[@"error_description"])goto invalid;
    return @{@"grant_type":@"authorization_code",@"client_id":@"app_EMoamEEZ73f0CkXaXp7hrann",@"redirect_uri":@"http://localhost:1455/auth/callback",@"code":p[@"code"],@"code_verifier":_verifier};
invalid:if(error)*error=OR6CodexPairOAuthFailure(@"invalid_request",NO,@"callback",@{@"reason":reason});return nil;
}
- (NSString *)description {return @"<OR6CodexPairOAuth private>";}
- (void)dealloc {[_state release];[_verifier release];[_workspace release];[super dealloc];}
@end
