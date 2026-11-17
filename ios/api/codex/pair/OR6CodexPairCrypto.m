#import "OR6CodexPairCrypto.h"
#import "../../../auth/OR6OAuthCrypto.h"
#include <math.h>

static BOOL Text(id v, NSUInteger max) {
    return OR6CodexText(v,max,NO) && [v rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location==NSNotFound;
}
static BOOL Integer(id v) {
    return OR6APISchemaCheck(v,@{@"type":@"integer",@"minimum":@1,@"maximum":@9007199254740991LL},@{});
}
static NSString *JSON(id v, NSUInteger depth) {
    if(depth>16)return nil;
    if([v isKindOfClass:NSDictionary.class]) {
        if([v count]>64)return nil;
        for(id k in v)if(![k isKindOfClass:NSString.class]||[k length]>256)return nil;
        NSMutableArray *parts=[NSMutableArray array];
        for(NSString *k in [[v allKeys]sortedArrayUsingSelector:@selector(compare:)]) {
            NSString *key=JSON(k,depth+1),*value=JSON(v[k],depth+1);
            if(!key||!value)return nil;
            [parts addObject:[NSString stringWithFormat:@"%@:%@",key,value]];
        }
        return [NSString stringWithFormat:@"{%@}",[parts componentsJoinedByString:@","]];
    }
    if([v isKindOfClass:NSArray.class]) {
        if([v count]>64)return nil;NSMutableArray *a=[NSMutableArray array];
        for(id x in v){NSString *s=JSON(x,depth+1);if(!s)return nil;[a addObject:s];}
        return [NSString stringWithFormat:@"[%@]",[a componentsJoinedByString:@","]];
    }
    if(![v isKindOfClass:NSString.class]&&!Integer(v))return nil;
    if([v isKindOfClass:NSString.class]&&[v length]>32768)return nil;
    NSData *d=[NSJSONSerialization dataWithJSONObject:@[v]options:0 error:NULL];
    NSString *s=[[[NSString alloc]initWithData:d encoding:NSUTF8StringEncoding]autorelease];
    if(s.length<2)return nil;
    return [[s substringWithRange:NSMakeRange(1,s.length-2)]stringByReplacingOccurrencesOfString:@"\\/"withString:@"/"];
}
NSData *OR6CodexPairCanonical(id value) { return [JSON(value,0)dataUsingEncoding:NSUTF8StringEncoding]; }
NSString *OR6CodexPairBase64(NSData *d) {
    if(![d isKindOfClass:NSData.class])return nil;
    NSString *s=[[OR6OAuthCrypto base64urlStringForData:d]stringByReplacingOccurrencesOfString:@"-"withString:@"+"];
    s=[s stringByReplacingOccurrencesOfString:@"_"withString:@"/"];
    while(s.length%4)s=[s stringByAppendingString:@"="];return s;
}
NSData *OR6CodexPairDecode64(NSString *s) {
    if(!OR6CodexText(s,131072,YES)||s.length%4)return nil;
    NSString *n=[s stringByReplacingOccurrencesOfString:@"+"withString:@"-"];
    n=[n stringByReplacingOccurrencesOfString:@"/"withString:@"_"];
    while([n hasSuffix:@"="])n=[n substringToIndex:n.length-1];
    NSData *d=[OR6OAuthCrypto dataForBase64urlString:n];
    return [OR6CodexPairBase64(d)isEqual:s]?d:nil;
}
NSDictionary *OR6CodexPairClaims(NSString *s) {
    if(!Text(s,32768))return nil;NSArray *a=[s componentsSeparatedByString:@"."];
    if(a.count!=3)return nil;
    NSData *d=[OR6OAuthCrypto dataForBase64urlString:a[1]];
    id v=d?[NSJSONSerialization JSONObjectWithData:d options:0 error:NULL]:nil;
    return [v isKindOfClass:NSDictionary.class]?OR6APIJSONSnapshot(v,16384):nil;
}
NSData *OR6CodexPairSPKI(NSData *scalar) {
    NSDictionary *j=[OR6OAuthCrypto publicJWKForPrivateKey:scalar];
    NSData *x=[OR6OAuthCrypto dataForBase64urlString:j[@"x"]],*y=[OR6OAuthCrypto dataForBase64urlString:j[@"y"]];
    if(x.length!=32||y.length!=32)return nil;
    const unsigned char prefix[]={0x30,0x59,0x30,0x13,0x06,0x07,0x2a,0x86,0x48,0xce,0x3d,0x02,0x01,0x06,0x08,0x2a,0x86,0x48,0xce,0x3d,0x03,0x01,0x07,0x03,0x42,0,4};
    NSMutableData *d=[NSMutableData dataWithBytes:prefix length:sizeof(prefix)];[d appendData:x];[d appendData:y];return d;
}
NSData *OR6CodexPairDER(NSData *raw) {
    if(raw.length!=64)return nil;const unsigned char *p=raw.bytes;NSMutableData *body=[NSMutableData data];
    for(NSUInteger offset=0;offset<64;offset+=32) {
        NSUInteger start=offset;while(start<offset+31&&!p[start])start++;
        BOOL zero=p[start]&0x80;unsigned char header[]={2,(unsigned char)(offset+32-start+(zero?1:0))},z=0;
        [body appendBytes:header length:2];if(zero)[body appendBytes:&z length:1];[body appendBytes:p+start length:offset+32-start];
    }
    unsigned char header[]={0x30,(unsigned char)body.length};NSMutableData *d=[NSMutableData dataWithBytes:header length:2];[d appendData:body];return d;
}
NSDictionary *OR6CodexPairSign(NSData *scalar, NSString *keyID, NSDictionary *p) {
    if(!Text(keyID,256)||![p isKindOfClass:NSDictionary.class])return nil;
    NSData *bytes=OR6CodexPairCanonical(@{@"domain":@"codex-device-key-sign-payload/v1",@"payload":p});
    NSData *der=bytes?OR6CodexPairDER([OR6OAuthCrypto ES256SignatureForData:bytes privateKey:scalar]):nil;
    if(!der)return nil;
    return @{@"keyId":keyID,@"algorithm":@"ecdsa_p256_sha256",@"signatureDerBase64":OR6CodexPairBase64(der),@"signedPayloadBase64":OR6CodexPairBase64(bytes)};
}
NSString *OR6CodexPairIdentityHash(NSDictionary *i) {
    if(!OR6CodexKeys(i,@[@"algorithm",@"keyId",@"protectionClass",@"publicKeySpkiDerBase64"],@[]))return nil;
    if(![i[@"algorithm"]isEqual:@"ecdsa_p256_sha256"]||!Text(i[@"keyId"],256)||!Text(i[@"protectionClass"],128)||OR6CodexPairDecode64(i[@"publicKeySpkiDerBase64"]).length!=91)return nil;
    return [OR6OAuthCrypto base64urlStringForData:[OR6OAuthCrypto sha256:OR6CodexPairCanonical(i)]];
}
BOOL OR6CodexPairStepUp(NSString *token,NSString *user,NSTimeInterval now) {
    NSDictionary *p=OR6CodexPairClaims(token),*a=p[@"https://api.openai.com/auth"];
    if(![a isKindOfClass:NSDictionary.class]||![(a[@"chatgpt_account_user_id"]?:a[@"account_user_id"])isEqual:user])return NO;
    NSMutableSet *scopes=[NSMutableSet set];id scope=p[@"scope"],scp=p[@"scp"];
    if(scope){if(![scope isKindOfClass:NSString.class])return NO;for(NSString *s in [scope componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet])if(s.length)[scopes addObject:s];}
    if(scp){if(![scp isKindOfClass:NSArray.class]||[scp count]>8)return NO;for(id s in scp){if(!Text(s,128))return NO;[scopes addObject:s];}}
    if(![scopes isEqual:[NSSet setWithObject:@"codex.remote_control.enroll"]]||!Integer(p[@"iat"])||!Integer(p[@"pwd_auth_time"]))return NO;
    NSTimeInterval issued=[p[@"iat"]doubleValue],password=[p[@"pwd_auth_time"]doubleValue]/1000;
    if(!isfinite(now)||issued>now+5||now-issued>300||password>now+5||now-password>300)return NO;
    return !p[@"exp"]||(Integer(p[@"exp"])&&[p[@"exp"]doubleValue]>now);
}
NSDictionary *OR6CodexPairEnrollmentPayload(NSDictionary *c,NSDictionary *identity,NSString *user,NSString *client,BOOL refresh,NSTimeInterval now) {
    if(![c isKindOfClass:NSDictionary.class])return nil;
    NSString *hash=OR6CodexPairIdentityHash(identity),*path=refresh?@"/backend-api/codex/remote/control/client/refresh/finish":@"/backend-api/codex/remote/control/client/enroll/finish";
    if(!hash||!Text(user,256)||!Text(client,256)||![c[@"account_user_id"]isEqual:user]||![c[@"client_id"]isEqual:client]||![c[@"purpose"]isEqual:@"remote_control_client_enrollment"]||![c[@"audience"]isEqual:@"remote_control_client_enrollment"]||![c[@"target_origin"]isEqual:@"https://chatgpt.com"]||![c[@"target_path"]isEqual:path]||!Integer(c[@"challenge_expires_at"])||[c[@"challenge_expires_at"]doubleValue]<=now||[c[@"challenge_expires_at"]doubleValue]>now+600||!Text(c[@"challenge_id"],256)||!Text(c[@"challenge_token"],16384))return nil;
    NSData *nonce=[OR6OAuthCrypto dataForBase64urlString:c[@"nonce"]];
    if(nonce.length<32||nonce.length>128||(refresh&&!c[@"device_identity_hash"])||(c[@"device_identity_hash"]&&![c[@"device_identity_hash"]isEqual:hash]))return nil;
    return @{@"accountUserId":user,@"clientId":client,@"audience":@"remote_control_client_enrollment",@"type":@"remoteControlClientEnrollment",@"challengeExpiresAt":c[@"challenge_expires_at"],@"challengeId":c[@"challenge_id"],@"deviceIdentitySha256Base64url":hash,@"nonce":c[@"nonce"],@"targetOrigin":@"https://chatgpt.com",@"targetPath":path};
}
NSDictionary *OR6CodexPairConnectionPayload(NSDictionary *c,NSString *user,NSString *client,NSString *token,NSNumber *expiry,NSTimeInterval now) {
    if(![c isKindOfClass:NSDictionary.class])return nil;
    NSString *hash=[OR6OAuthCrypto base64urlStringForData:[OR6OAuthCrypto sha256:[token dataUsingEncoding:NSUTF8StringEncoding]]];
    NSData *nonce=[OR6OAuthCrypto dataForBase64urlString:c[@"nonce"]];
    if(!Text(token,16384)||![c[@"accountUserId"]isEqual:user]||![c[@"clientId"]isEqual:client]||![c[@"audience"]isEqual:@"remote_control_client_websocket"]||![c[@"targetOrigin"]isEqual:@"https://chatgpt.com"]||![c[@"targetPath"]isEqual:@"/backend-api/codex/remote/control/client"]||![c[@"tokenSha256Base64url"]isEqual:hash]||![c[@"tokenExpiresAt"]isEqual:expiry]||!Integer(expiry)||expiry.doubleValue<=now||![c[@"scopes"]isEqual:@[@"remote_control_controller_websocket"]]||!Text(c[@"sessionId"],256)||nonce.length<32||nonce.length>128)return nil;
    return @{@"accountUserId":user,@"clientId":client,@"audience":@"remote_control_client_websocket",@"type":@"remoteControlClientConnection",@"nonce":c[@"nonce"],@"scopes":c[@"scopes"],@"sessionId":c[@"sessionId"],@"targetOrigin":c[@"targetOrigin"],@"targetPath":c[@"targetPath"],@"tokenExpiresAt":expiry,@"tokenSha256Base64url":hash};
}
NSString *OR6CodexPairCode(NSString *s) {
    if(!OR6CodexText(s,4096,NO))return nil;
    s=[s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if(s.length<6||s.length>2048||[s rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"]invertedSet]].location!=NSNotFound)return nil;
    return s;
}
