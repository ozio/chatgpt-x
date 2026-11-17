#import "OR6CodexPair.h"
#import "OR6CodexPairOAuth.h"
#import "OR6CodexPairRelay.h"
#import "../OR6CodexOperation.h"
#import "../OR6CodexPolicy8.h"
#import "../../../auth/OR6OAuthCrypto.h"
#include <math.h>
static NSString *const Software=@"software_exportable";
static NSTimeInterval Now(void){return [NSDate.date timeIntervalSince1970];}
static BOOL Snapshot(NSDictionary *s) {
    if(!OR6CodexKeys(s,@[@"context",@"accountUserId",@"accessToken",@"expiresAt"],@[])||!OR6CodexKeys(s[@"context"],@[@"owner",@"workspace",@"connection",@"credentialGeneration"],@[]))return NO;
    NSDictionary *c=s[@"context"];for(NSString *k in @[@"owner",@"workspace"])if(!OR6CodexID(c[k]))return NO;
    return OR6CodexID(s[@"accountUserId"])&&OR6CodexText(s[@"accessToken"],16384,NO)&&[s[@"accessToken"]rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location==NSNotFound&&OR6APISchemaCheck(c[@"credentialGeneration"],@{@"type":@"integer",@"minimum":@1},@{})&&OR6APISchemaCheck(s[@"expiresAt"],@{@"type":@"number"},@{})&&[s[@"expiresAt"]doubleValue]>Now()+15;
}
static void Use(OR6CodexOperation *c,id<OR6APITask>(^start)(void)) {
    if(c->done)return;NSUInteger serial=++c->serial;id<OR6APITask> t=start();
    if(!c->done&&serial==c->serial){[c->task release];c->task=[t retain];}
}
static NSNumber *Expiry(id string) {
    if(!OR6CodexText(string,40,NO))return nil;
    NSDateFormatter *f=[[[NSDateFormatter alloc]init]autorelease];f.locale=[[[NSLocale alloc]initWithLocaleIdentifier:@"en_US_POSIX"]autorelease];f.timeZone=[NSTimeZone timeZoneForSecondsFromGMT:0];
    for(NSString *format in @[@"yyyy-MM-dd'T'HH:mm:ss'Z'",@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"]){f.dateFormat=format;NSDate *d=[f dateFromString:string];if(d)return @((long long)floor(d.timeIntervalSince1970));}return nil;
}
@interface OR6CodexPair ()
- (BOOL)save:(NSError **)error;
- (void)enroll:(BOOL)refresh call:(OR6CodexOperation *)call;
- (void)claim:(NSString *)code operation:(NSString *)identifier call:(OR6CodexOperation *)call;
- (void)request:(NSString *)endpoint parameters:(NSDictionary *)parameters call:(OR6CodexOperation *)call done:(OR6APIReply)done;
@end
@implementation OR6CodexPair
- (id)initWithCredentials:(OR6CodexPairCredentials)source IO:(id<OR6CodexPairIO>)IO vault:(id<OR6CodexPairVault>)vault roots:(NSString *)roots contracts:(NSDictionary *)contracts directory:(NSString *)directory error:(NSError **)error {
    if(!(self=[super init]))return nil;
    NSDictionary *s=NSThread.isMainThread&&source?OR6APIJSONSnapshot(source(),32768):nil;
    if(!Snapshot(s)||!IO||!vault||!contracts||!OR6CodexPath(directory)||!OR6CodexPath(roots)){if(error)*error=OR6CodexError(@"not_authenticated",NO);[self release];return nil;}
    _source=[source copy];_snapshot=[s retain];_IO=[IO retain];_vault=[vault retain];_roots=[roots copy];_contracts=[contracts retain];_directory=[directory copy];_calls=[NSMutableSet new];
    NSDictionary *saved=[vault load:error];if(!saved){[self release];return nil;}
    NSString *owner=s[@"context"][@"owner"],*workspace=s[@"context"][@"workspace"],*user=s[@"accountUserId"];
    if(!owner||!workspace||!user){if(error)*error=OR6CodexError(@"not_authenticated",NO);[self release];return nil;}
    NSDictionary *scope=@{@"owner":owner,@"workspace":workspace,@"accountUserId":user};
    if(saved.count) {
        if(![saved[@"scope"]isEqual:scope]||![saved[@"schema"]isEqual:@1]||!OR6CodexKeys(saved,@[@"schema",@"scope",@"phase",@"environments"],@[@"scalar",@"identity",@"clientId",@"grant",@"lastClaim",@"issue",@"forgotten",@"lastSetup",@"lastOAuthError"])||![@[@"not_enrolled",@"enrolled",@"paired",@"enroll_start_pending",@"enroll_finish_pending",@"refresh_start_pending",@"refresh_finish_pending",@"claim_pending",@"uncertain",@"rejected"]containsObject:saved[@"phase"]]||![saved[@"environments"]isKindOfClass:NSArray.class]||[saved[@"environments"]count]>16)goto corrupt;
        if(saved[@"lastOAuthError"]&&!OR6CodexPairOAuthSafeDiagnostic(saved[@"lastOAuthError"]))goto corrupt;
        if(saved[@"lastSetup"]&&(!OR6CodexKeys(saved[@"lastSetup"],@[@"operationID",@"refresh"],@[])||!OR6CodexID(saved[@"lastSetup"][@"operationID"])||!OR6APISchemaCheck(saved[@"lastSetup"][@"refresh"],@{@"type":@"boolean"},@{})))goto corrupt;
        if(saved[@"forgotten"]){if(![saved[@"forgotten"]isKindOfClass:NSArray.class]||[saved[@"forgotten"]count]>16)goto corrupt;for(id item in saved[@"forgotten"])if(!OR6CodexID(item))goto corrupt;}
        if(saved[@"scalar"]){NSData *key=OR6CodexPairDecode64(saved[@"scalar"]);if(key.length!=32||![OR6CodexPairBase64(OR6CodexPairSPKI(key))isEqual:saved[@"identity"][@"publicKeySpkiDerBase64"]]||![saved[@"identity"][@"protectionClass"]isEqual:Software]||!OR6CodexPairIdentityHash(saved[@"identity"]))goto corrupt;}
        else if(saved[@"identity"]||saved[@"clientId"]||saved[@"grant"])goto corrupt;
        if(saved[@"clientId"]&&!OR6CodexID(saved[@"clientId"]))goto corrupt;
        if(saved[@"grant"]&&(!OR6CodexKeys(saved[@"grant"],@[@"token",@"expiry",@"scopes"],@[])||!OR6CodexText(saved[@"grant"][@"token"],16384,NO)||![saved[@"grant"][@"scopes"]isEqual:@[@"remote_control_controller_websocket"]]||!OR6APISchemaCheck(saved[@"grant"][@"expiry"],@{@"type":@"integer",@"minimum":@1},@{})))goto corrupt;
        for(id e in saved[@"environments"])if(![e isKindOfClass:NSDictionary.class]||!OR6CodexID(e[@"env_id"])||!OR6CodexText(e[@"name"],256,NO))goto corrupt;
        _record=[saved mutableCopy];
        if([saved[@"phase"]hasSuffix:@"_pending"]){_record[@"phase"]=@"uncertain";if(![self save:error]){[self release];return nil;}}
    }else _record=[@{@"schema":@1,@"scope":scope,@"phase":@"not_enrolled",@"environments":@[]}mutableCopy];
    return self;
corrupt:if(error)*error=OR6CodexError(@"storage_failure",NO);[self release];return nil;
}
- (BOOL)current {
    if(!NSThread.isMainThread||_stopped||!_source)return NO;
    NSDictionary *s=OR6APIJSONSnapshot(_source(),32768);return Snapshot(s)&&[s isEqual:_snapshot];
}
- (BOOL)save:(NSError **)error {
    if(![self current]||![_vault save:_record error:error]){if(error&&!*error)*error=OR6CodexError(@"stale_context",NO);return NO;}return YES;
}
- (NSDictionary *)status {
    BOOL valid=[self current];
    return @{@"available":@(valid),@"state":valid?(_record[@"phase"]?:@"not_enrolled"):@"unavailable",@"busy":@(_calls.count>0),@"enrolled":@(valid&&_record[@"grant"]!=nil),@"hasClient":@(valid&&_record[@"clientId"]!=nil),@"tokenCurrent":@(valid&&[_record[@"grant"][@"expiry"]doubleValue]>Now()+15),@"keyProtectionClass":Software,@"hardwareSecureEnclave":@NO,@"osProtectedNonextractable":@NO,@"serviceAdmissionVerified":@(valid&&_record[@"grant"]!=nil),@"claimUncertain":@(_record[@"lastClaim"]&&![_record[@"lastClaim"][@"confirmed"]boolValue]),@"authorizationReady":@(_stepUp&&Now()-_stepUpAt<300),@"data":valid?(_record[@"environments"]?:@[]):@[],@"issue":_record[@"issue"]?:@"",@"lastOAuthError":OR6CodexPairOAuthSafeDiagnostic(_record[@"lastOAuthError"])?:@{}};
}
- (NSDictionary *)headers {
    if(![self current])return nil;
    return @{@"Authorization":[@"Bearer "stringByAppendingString:_snapshot[@"accessToken"]],@"ChatGPT-Account-Id":_snapshot[@"context"][@"workspace"]};
}
- (void)request:(NSString *)endpoint parameters:(NSDictionary *)p call:(OR6CodexOperation *)c done:(OR6APIReply)done {
    if(![self current]){[c finish:nil error:OR6CodexError(@"stale_context",NO)];return;}
    Use(c,^id<OR6APITask>{return [_IO request:endpoint parameters:p headers:[self headers]completion:^(NSDictionary *r,NSError *e){
        if(c->done)return;if(![self current]){[c finish:nil error:OR6CodexError(@"stale_context",NO)];return;}done(r,e);
    }];});
}
- (id<OR6APITask>)perform:(NSString *)op parameters:(NSDictionary *)raw completion:(OR6APIReply)cb {
    if(!cb)return nil;
    NSDictionary *p=OR6APIJSONSnapshot(raw,16384);
    if(![self current]){cb(nil,OR6CodexError(@"stale_context",NO));return nil;}
    if(!p){cb(nil,OR6CodexError(@"invalid_request",NO));return nil;}
    if([@[@"codex.pair.capability",@"codex.pair.status"]containsObject:op]){cb(p.count?nil:[self status],p.count?OR6CodexError(@"invalid_request",NO):nil);return nil;}
    if(_calls.count){cb(nil,OR6CodexError(@"conflict",NO));return nil;}
    OR6CodexOperation *c=[[[OR6CodexOperation alloc]init]autorelease];[_calls addObject:c];NSUInteger epoch=_epoch;
    BOOL mutation=[@[@"codex.pair.enroll",@"codex.pair.refresh",@"codex.pair.claim",@"codex.pair.callback"]containsObject:op];
    c->reply=[^(NSDictionary *r,NSError *e){[_calls removeObject:c];if(epoch!=_epoch||![self current]){r=nil;e=OR6CodexError(@"stale_context",NO);}else if(e&&mutation){BOOL possible=[e.userInfo[@"dispatch"]isEqual:@"possible"];if([_record[@"phase"]hasSuffix:@"_pending"]){_record[@"phase"]=possible?@"uncertain":@"rejected";}_record[@"issue"]=e.userInfo[@"code"]?:@"unavailable";
        if([op isEqual:@"codex.pair.callback"]){NSDictionary *diagnostic=OR6CodexPairOAuthSafeDiagnostic(e.userInfo[@"oauthFailure"]);if(diagnostic)_record[@"lastOAuthError"]=diagnostic;}
        NSError *storage=nil;if(![self save:&storage])e=storage;}
        if([@[@"not_authenticated",@"service_challenge",@"rate_limited"]containsObject:e.userInfo[@"code"]]){_stopped=YES;[_IO invalidate];}
        cb(r,e);
    }copy];
    if([op isEqual:@"codex.pair.authorize"]) {
        if(p.count)goto invalid;[_authorization release];_authorization=[[OR6CodexPairOAuth alloc]initWithWorkspace:_snapshot[@"context"][@"workspace"]];
        NSURL *URL=[_authorization URL];[c finish:URL?@{@"url":URL.absoluteString}:nil error:URL?nil:OR6CodexError(@"unavailable",NO)];return c;
    }
    if([op isEqual:@"codex.pair.callback"]) {
        if(!OR6CodexKeys(p,@[@"url"],@[])||!OR6CodexText(p[@"url"],8192,NO)||!_authorization)goto invalid;
        NSError *e=nil;NSDictionary *exchange=[_authorization consume:[NSURL URLWithString:p[@"url"]]error:&e];
        if(!exchange){[c finish:nil error:e];return c;}
        [self request:@"oauth"parameters:exchange call:c done:^(NSDictionary *r,NSError *error){
            if(error){[c finish:nil error:error];return;}
            NSString *token=r[@"access_token"];
            if(!OR6CodexPairStepUp(token,_snapshot[@"accountUserId"],Now())){[c finish:nil error:OR6CodexPairOAuthFailure(@"not_authenticated",NO,@"token_validation",@{@"reason":@"token_claims_mismatch"})];return;}
            [_record removeObjectForKey:@"lastOAuthError"];[_record removeObjectForKey:@"issue"];NSError *storage=nil;if(![self save:&storage]){[c finish:nil error:storage];return;}
            [_stepUp release];_stepUp=[token copy];_stepUpAt=Now();[_authorization release];_authorization=nil;
            [c finish:@{@"authorized":@YES}error:nil];
        }];return c;
    }
    if([op isEqual:@"codex.pair.cancel-authorization"]) {
        if(p.count)goto invalid;[_authorization release];_authorization=nil;[_stepUp release];_stepUp=nil;[c finish:@{}error:nil];return c;
    }
    if([op isEqual:@"codex.pair.enroll"]||[op isEqual:@"codex.pair.refresh"]) {
        if(!OR6CodexKeys(p,@[@"operationID"],@[])||!OR6CodexID(p[@"operationID"]))goto invalid;
        BOOL refresh=[op isEqual:@"codex.pair.refresh"];
        if([_record[@"lastSetup"][@"operationID"]isEqual:p[@"operationID"]]){[c finish:nil error:OR6CodexError(@"duplicate_operation",NO)];return c;}
        if(refresh&&(!_record[@"clientId"]||!_record[@"identity"])){[c finish:nil error:OR6CodexError(@"not_found",NO)];return c;}
        if(!refresh&&(_record[@"clientId"]||[_record[@"phase"]isEqual:@"uncertain"])) { [c finish:nil error:OR6CodexError(@"uncertain_outcome",NO)];return c; }
        if(!refresh&&!OR6CodexPairStepUp(_stepUp,_snapshot[@"accountUserId"],Now())){[c finish:nil error:OR6CodexError(@"login_required",NO)];return c;}
        _record[@"lastSetup"]=@{@"operationID":p[@"operationID"],@"refresh":@(refresh)};[self enroll:refresh call:c];return c;
    }
    if([op isEqual:@"codex.pair.claim"]) {
        if(!OR6CodexKeys(p,@[@"code",@"operationID"],@[])||!OR6CodexID(p[@"operationID"])||!OR6CodexPairCode(p[@"code"]))goto invalid;
        if(!_record[@"grant"]||[_record[@"phase"]isEqual:@"uncertain"]||[_record[@"phase"]hasSuffix:@"_pending"]){[c finish:nil error:OR6CodexError(@"uncertain_outcome",NO)];return c;}
        if(_record[@"lastClaim"]&&![_record[@"lastClaim"][@"confirmed"]boolValue]&&[_record[@"lastClaim"][@"codeSHA256"]isEqual:OR6CodexDigest(OR6CodexPairCode(p[@"code"]))]){[c finish:nil error:OR6CodexError(@"uncertain_outcome",NO)];return c;}
        if([_record[@"lastClaim"][@"operationID"]isEqual:p[@"operationID"]]){[c finish:nil error:OR6CodexError(@"duplicate_operation",NO)];return c;}
        [self claim:OR6CodexPairCode(p[@"code"])operation:p[@"operationID"]call:c];return c;
    }
    if([op isEqual:@"codex.pair.environments"]) {
        if(!OR6CodexKeys(p,@[],@[@"cursor"])||!_record[@"clientId"]||(p[@"cursor"]&&!OR6CodexText(p[@"cursor"],2048,NO)))goto invalid;
        NSMutableDictionary *query=[NSMutableDictionary dictionaryWithObject:_record[@"clientId"]forKey:@"clientId"];if(p[@"cursor"])query[@"cursor"]=p[@"cursor"];
        [self request:@"environments"parameters:query call:c done:^(NSDictionary *r,NSError *e){
            if(e){[c finish:nil error:e];return;}
            if(![r[@"items"]isKindOfClass:NSArray.class]||[r[@"items"]count]>100||(r[@"cursor"]&&r[@"cursor"]!=NSNull.null&&!OR6CodexText(r[@"cursor"],2048,NO))){[c finish:nil error:OR6CodexError(@"schema_mismatch",NO)];return;}
            NSMutableArray *a=p[@"cursor"]?[[(_record[@"environments"]?:@[])mutableCopy]autorelease]:[NSMutableArray array];for(id item in r[@"items"]){
                if(![item isKindOfClass:NSDictionary.class]||!OR6CodexID(item[@"env_id"])){[c finish:nil error:OR6CodexError(@"schema_mismatch",NO)];return;}
                NSString *name=OR6CodexText(item[@"display_name"],256,NO)?item[@"display_name"]:OR6CodexText(item[@"name"],256,NO)?item[@"name"]:item[@"env_id"];
                BOOL duplicate=NO;for(NSDictionary *host in a)if([host[@"env_id"]isEqual:item[@"env_id"]])duplicate=YES;
                if(!duplicate&&a.count<16&&![_record[@"forgotten"]containsObject:item[@"env_id"]])[a addObject:@{@"env_id":item[@"env_id"],@"name":name}];
            }
            _record[@"environments"]=a;NSError *storage=nil;if(![self save:&storage]){[c finish:nil error:storage];return;}
            [c finish:@{@"data":a,@"nextCursor":r[@"cursor"]?:NSNull.null,@"previousClaimConfirmed":@NO}error:nil];
        }];return c;
    }
    if([op isEqual:@"codex.pair.forget-host"]) {
        if(!OR6CodexKeys(p,@[@"environmentId"],@[])||!OR6CodexID(p[@"environmentId"]))goto invalid;
        NSMutableArray *a=[NSMutableArray array];BOOL found=NO;for(NSDictionary *host in _record[@"environments"]){if([host[@"env_id"]isEqual:p[@"environmentId"]])found=YES;else[a addObject:host];}
        if(!found){[c finish:nil error:OR6CodexError(@"not_found",NO)];return c;}
        NSMutableArray *forgotten=[[(_record[@"forgotten"]?:@[])mutableCopy]autorelease];if(![forgotten containsObject:p[@"environmentId"]])[forgotten addObject:p[@"environmentId"]];if(forgotten.count>16)[forgotten removeObjectAtIndex:0];_record[@"environments"]=a;_record[@"forgotten"]=forgotten;
        NSError *e=nil;BOOL saved=[self save:&e];[c finish:saved?@{@"serverRevoked":@NO}:nil error:e];return c;
    }
    if([op isEqual:@"codex.pair.forget-local"]) {
        if(!OR6CodexKeys(p,@[@"confirmed"],@[])||!OR6APISchemaCheck(p[@"confirmed"],@{@"type":@"boolean",@"enum":@[@YES]},@{}))goto invalid;
        [_authorization release];_authorization=nil;[_stepUp release];_stepUp=nil;NSDictionary *scope=[[_record[@"scope"]retain]autorelease];[_record removeAllObjects];[_record addEntriesFromDictionary:@{@"schema":@1,@"scope":scope,@"phase":@"not_enrolled",@"environments":@[]}];
        NSError *e=nil;BOOL saved=[self save:&e];[c finish:saved?@{@"serverRevoked":@NO}:nil error:e];return c;
    }
invalid:[c finish:nil error:[op isEqual:@"codex.pair.callback"]?OR6CodexPairOAuthFailure(@"invalid_request",NO,@"callback",@{@"reason":@"invalid_callback"}):OR6CodexError(@"invalid_request",NO)];return c;
}
- (void)enroll:(BOOL)refresh call:(OR6CodexOperation *)c {
    if(!refresh&&!_record[@"scalar"]) {
        NSData *scalar=[OR6OAuthCrypto generateP256PrivateKey],*SPKI=OR6CodexPairSPKI(scalar);
        if(!SPKI){[c finish:nil error:OR6CodexError(@"unavailable",NO)];return;}
        _record[@"scalar"]=OR6CodexPairBase64(scalar);
        _record[@"identity"]=@{@"algorithm":@"ecdsa_p256_sha256",@"keyId":NSProcessInfo.processInfo.globallyUniqueString,@"protectionClass":Software,@"publicKeySpkiDerBase64":OR6CodexPairBase64(SPKI)};
    }
    _record[@"phase"]=refresh?@"refresh_start_pending":@"enroll_start_pending";NSError *storage=nil;
    if(![self save:&storage]){[c finish:nil error:storage];return;}
    NSString *step=refresh?@"refresh.start":@"enroll.start";
    [self request:step parameters:refresh?@{@"client_id":_record[@"clientId"]}:@{}call:c done:^(NSDictionary *start,NSError *e){
        if(e){[c finish:nil error:e];return;}
        if(![start[@"account_user_id"]isEqual:_snapshot[@"accountUserId"]]||!OR6CodexID(start[@"client_id"])||(refresh&&![start[@"client_id"]isEqual:_record[@"clientId"]])){[c finish:nil error:OR6CodexError(@"schema_mismatch",YES)];return;}
        _record[@"clientId"]=start[@"client_id"];
        NSDictionary *challenge=start[@"device_key_challenge"],*payload=OR6CodexPairEnrollmentPayload(challenge,_record[@"identity"],_snapshot[@"accountUserId"],_record[@"clientId"],refresh,Now());
        if(!payload){[c finish:nil error:OR6CodexError(@"schema_mismatch",YES)];return;}
        NSDictionary *signatureParts=OR6CodexPairSign(OR6CodexPairDecode64(_record[@"scalar"]),_record[@"identity"][@"keyId"],payload);
        if(!signatureParts){[c finish:nil error:OR6CodexError(@"unavailable",YES)];return;}
        NSDictionary *proof=@{@"challenge_token":challenge[@"challenge_token"],@"key_id":signatureParts[@"keyId"],@"signature_der_base64":signatureParts[@"signatureDerBase64"],@"signed_payload_base64":signatureParts[@"signedPayloadBase64"],@"algorithm":signatureParts[@"algorithm"]};
        NSMutableDictionary *body=[NSMutableDictionary dictionaryWithDictionary:@{@"client_id":_record[@"clientId"],@"device_key_proof":proof}];
        if(!refresh){
            if(!OR6CodexPairStepUp(_stepUp,_snapshot[@"accountUserId"],Now())){[c finish:nil error:OR6CodexError(@"login_required",YES)];return;}
            NSDictionary *i=_record[@"identity"];
            body[@"step_up_token"]=_stepUp;body[@"device_identity"]=@{@"key_id":i[@"keyId"],@"algorithm":i[@"algorithm"],@"protection_class":i[@"protectionClass"],@"public_key_spki_der_base64":i[@"publicKeySpkiDerBase64"]};
        }
        _record[@"phase"]=refresh?@"refresh_finish_pending":@"enroll_finish_pending";NSError *failed=nil;
        if(![self save:&failed]){[c finish:nil error:failed];return;}
        [self request:refresh?@"refresh.finish":@"enroll.finish"parameters:body call:c done:^(NSDictionary *r,NSError *problem){
            [_stepUp release];_stepUp=nil;if(problem){[c finish:nil error:problem];return;}
            NSNumber *expiry=Expiry(r[@"expires_at"]);
            if(![r[@"client_id"]isEqual:_record[@"clientId"]]||![r[@"account_user_id"]isEqual:_snapshot[@"accountUserId"]]||!OR6CodexText(r[@"remote_control_token"],16384,NO)||[r[@"remote_control_token"]rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound||!expiry||expiry.doubleValue<=Now()+15||![r[@"scopes"]isEqual:@[@"remote_control_controller_websocket"]]){[c finish:nil error:OR6CodexError(@"schema_mismatch",YES)];return;}
            _record[@"grant"]=@{@"token":r[@"remote_control_token"],@"expiry":expiry,@"scopes":r[@"scopes"]};_record[@"phase"]=[_record[@"environments"]count]?@"paired":@"enrolled";[_record removeObjectForKey:@"issue"];
            NSError *save=nil;if(![self save:&save]){[c finish:nil error:save];return;}[c finish:[self status]error:nil];
        }];
    }];
}
- (void)claim:(NSString *)code operation:(NSString *)identifier call:(OR6CodexOperation *)c {
    if([_record[@"grant"][@"expiry"]doubleValue]<=Now()+15){[c finish:nil error:OR6CodexError(@"expired",NO)];return;}
    _record[@"lastClaim"]=@{@"operationID":identifier,@"codeSHA256":OR6CodexDigest(code),@"confirmed":@NO};_record[@"phase"]=@"claim_pending";
    NSError *storage=nil;if(![self save:&storage]){[c finish:nil error:storage];return;}
    [self request:@"pair"parameters:@{@"pairing_code":code,@"client_id":_record[@"clientId"]}call:c done:^(NSDictionary *r,NSError *e){
        if(e){[c finish:nil error:e];return;}
        if(![r[@"client_id"]isEqual:_record[@"clientId"]]||!OR6CodexID(r[@"server_id"])||!OR6CodexID(r[@"environment_id"])){[c finish:nil error:OR6CodexError(@"schema_mismatch",YES)];return;}
        NSDictionary *host=@{@"env_id":r[@"environment_id"],@"name":r[@"environment_id"],@"server_id":r[@"server_id"]};
        if([_record[@"forgotten"]containsObject:host[@"env_id"]]){NSMutableArray *forgotten=[[_record[@"forgotten"]mutableCopy]autorelease];[forgotten removeObject:host[@"env_id"]];_record[@"forgotten"]=forgotten;}
        NSMutableArray *a=[[(_record[@"environments"]?:@[])mutableCopy]autorelease];for(NSInteger index=(NSInteger)a.count-1;index>=0;index--)if([a[(NSUInteger)index][@"env_id"]isEqual:host[@"env_id"]])[a removeObjectAtIndex:(NSUInteger)index];
        if(a.count>=16)[a removeObjectAtIndex:0];[a addObject:host];_record[@"environments"]=a;
        _record[@"lastClaim"]=@{@"operationID":identifier,@"codeSHA256":OR6CodexDigest(code),@"confirmed":@YES};_record[@"phase"]=@"paired";[_record removeObjectForKey:@"issue"];
        NSError *save=nil;if(![self save:&save]){[c finish:nil error:save];return;}[c finish:@{@"environment":host,@"confirmed":@YES}error:nil];
    }];
}
- (OR6CodexAPI *)newAPIForEnvironment:(NSString *)environment error:(NSError **)error {
    BOOL known=NO;for(NSDictionary *e in _record[@"environments"])if([e[@"env_id"]isEqual:environment])known=YES;
    if(![self current]||!known||!_record[@"grant"]||[_record[@"grant"][@"expiry"]doubleValue]<=Now()+15){if(error)*error=OR6CodexError(@"expired",NO);return nil;}
    // The grant's client is injected only by this trusted factory.
    NSMutableDictionary *grant=[[(_record[@"grant"])mutableCopy]autorelease];grant[@"clientId"]=_record[@"clientId"];
    OR6CodexPairRelay *transport=[[[OR6CodexPairRelay alloc]initWithSource:_source snapshot:_snapshot grant:grant identity:_record[@"identity"]scalar:OR6CodexPairDecode64(_record[@"scalar"])environment:environment roots:_roots]autorelease];
    NSMutableDictionary *context=[[_snapshot[@"context"]mutableCopy]autorelease];context[@"connection"]=[@"codex-relay:"stringByAppendingString:environment];
    return [[OR6CodexAPI alloc]initWithTransport:transport contracts:_contracts context:context privateDirectory:_directory error:error];
}
- (void)invalidate {
    _stopped=YES;_epoch++;for(OR6CodexOperation *c in [[_calls.allObjects copy]autorelease])[c cancel];[_IO invalidate];[_stepUp release];_stepUp=nil;[_authorization release];_authorization=nil;
}
- (NSString *)description {return @"<OR6CodexPair private>";}
- (void)dealloc {[self invalidate];[_source release];[_snapshot release];[_IO release];[_vault release];[_record release];[_calls release];[_roots release];[_contracts release];[_directory release];[super dealloc];}
@end
