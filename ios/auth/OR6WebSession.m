#import "OR6WebSession.h"
#import "OR6WebCookies.h"
#import <CoreFoundation/CoreFoundation.h>
#include <mbedtls/base64.h>
#include <math.h>
#include <mach/mach_time.h>
static NSTimeInterval ValidationClock(void){mach_timebase_info_data_t t;mach_timebase_info(&t);return(double)mach_absolute_time()*t.numer/t.denom/1e9;}
static BOOL Text(id v,NSUInteger limit){return [v isKindOfClass:NSString.class]&&[v length]>0&&[v length]<=limit&&[v rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location==NSNotFound;}
static BOOL Number(id v){return [v isKindOfClass:NSNumber.class]&&CFGetTypeID((CFTypeRef)v)!=CFBooleanGetTypeID()&&isfinite([v doubleValue]);}
static id Snapshot(id value){NSData *data=value?[NSJSONSerialization dataWithJSONObject:value options:0 error:NULL]:nil;return data&&data.length<=98304?[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]:nil;}
static id Flag(BOOL b){return b?(id)kCFBooleanTrue:(id)kCFBooleanFalse;}
@interface OR6WebSession ()
- (void)validateCandidate:(NSDictionary *)candidate expectedOwner:(NSString *)owner generation:(NSUInteger)generation;
- (void)fetchCandidate:(NSDictionary *)candidate generation:(NSUInteger)generation;
@end
@implementation OR6WebSession
@synthesize delegate=_delegate,phase=_phase,issue=_issue,authenticated=_authenticated,generation=_generation;
- (id)initWithStore:(id<OR6WebStore>)store provider:(id<OR6WebProvider>)provider jar:(id<OR6WebCookieJar>)jar clock:(NSTimeInterval (^)(void))clock {
    return[self initWithStore:store provider:provider jar:jar clock:clock validationClock:^{return ValidationClock();}];
}
- (id)initWithStore:(id<OR6WebStore>)store provider:(id<OR6WebProvider>)provider jar:(id<OR6WebCookieJar>)jar clock:(NSTimeInterval (^)(void))clock validationClock:(NSTimeInterval (^)(void))validationClock {
    if((self=[super init])){_store=[store retain];_provider=[provider retain];_jar=[jar retain];_clock=[clock copy];_validationClock=[validationClock copy];_phase=[@"signed_out"copy];_issue=[@""copy];}return self;
}
- (BOOL)recordOwnerValidation:(NSString *)owner generation:(NSUInteger)generation {
    if(!NSThread.isMainThread||generation!=_generation)return NO;
    _ownerValidated=NO;
    if(!_authenticated||_busy||![_record[@"state"]isEqual:@"active"]||![owner isKindOfClass:NSString.class]||![owner isEqual:_record[@"owner"]]||[_record[@"expiresAt"]doubleValue]<=_clock()+15)return NO;
    _ownerValidatedAt=_validationClock();_ownerValidatedWall=_clock();_ownerValidatedGeneration=_generation;
    _ownerValidated=isfinite(_ownerValidatedAt)&&isfinite(_ownerValidatedWall);return _ownerValidated;
}
- (NSTimeInterval)recentOwnerValidationAge {
    if(!NSThread.isMainThread||!_ownerValidated||_ownerValidatedGeneration!=_generation||!_authenticated||_busy||![_record[@"state"]isEqual:@"active"]||[_record[@"expiresAt"]doubleValue]<=_clock()+15)return -1;
    NSTimeInterval age=_validationClock()-_ownerValidatedAt,wallAge=_clock()-_ownerValidatedWall;
    // The wall bound also expires the check across suspend on old mach clocks.
    // Reads and cookie commits never slide either deadline.
    if(!isfinite(age)||!isfinite(wallAge)||age<0||wallAge<0||age>=60||wallAge>=60){_ownerValidated=NO;return -1;}
    return MAX(age,wallAge);
}
+ (BOOL)validAccessToken:(id)token {
    if(!Text(token,16384))return NO;
    return [token rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~+/="]invertedSet]].location==NSNotFound;
}
+ (NSTimeInterval)tokenExpiry:(NSString *)token {
    id exp=[self tokenPayload:token][@"exp"];return Number(exp)&&[exp doubleValue]>0?[exp doubleValue]:0;
}
// JWT payload of a bearer (no signature check: only local display/expiry fields are read).
+ (NSDictionary *)tokenPayload:(NSString *)token {
    if(![self validAccessToken:token])return nil;NSArray *parts=[token componentsSeparatedByString:@"."];if(parts.count!=3)return nil;
    NSString *part=parts[1];if(part.length%4==1)return nil;
    if([part rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"]invertedSet]].location!=NSNotFound)return nil;
    NSMutableString *s=[[[part stringByReplacingOccurrencesOfString:@"-"withString:@"+"]stringByReplacingOccurrencesOfString:@"_"withString:@"/"]mutableCopy];while(s.length%4)[s appendString:@"="];
    NSData *in=[s dataUsingEncoding:NSASCIIStringEncoding];[s release];size_t length=0;
    if(mbedtls_base64_decode(NULL,0,&length,in.bytes,in.length)!=MBEDTLS_ERR_BASE64_BUFFER_TOO_SMALL||length>16384)return nil;
    NSMutableData *out=[NSMutableData dataWithLength:length];if(mbedtls_base64_decode(out.mutableBytes,length,&length,in.bytes,in.length))return nil;out.length=length;
    id j=[NSJSONSerialization JSONObjectWithData:out options:0 error:NULL];return [j isKindOfClass:NSDictionary.class]?j:nil;
}
// Optional account profile kept with the active record: only {name?, email?}, each ≤256, one line.
static BOOL ValidProfile(id p){
    if(![p isKindOfClass:NSDictionary.class]||[p count]>2)return NO;
    for(NSString *k in p)if(![@[@"name",@"email"]containsObject:k]||!Text(p[k],256))return NO;return YES;
}
- (NSDictionary *)profileFrom:(NSDictionary *)validated owner:(NSString *)owner token:(NSString *)token {
    NSMutableDictionary *p=[NSMutableDictionary dictionary];
    // Same account: keep what /me said before when this check carried nothing new.
    if([_record[@"owner"]isEqual:owner]&&ValidProfile(_record[@"profile"]))[p addEntriesFromDictionary:_record[@"profile"]];
    if(ValidProfile(validated))[p addEntriesFromDictionary:validated];
    if(!p[@"email"]){id claims=[self.class tokenPayload:token][@"https://api.openai.com/profile"];id email=[claims isKindOfClass:NSDictionary.class]?claims[@"email"]:nil;if(Text(email,256)&&[email rangeOfString:@"@"].location!=NSNotFound)p[@"email"]=email;}
    return p.count?p:nil;
}
- (NSDictionary *)profile{return _record&&![_record[@"state"]isEqual:@"signed_out"]&&ValidProfile(_record[@"profile"])?_record[@"profile"]:nil;}
- (NSDictionary *)serviceAccount{
    if(!_authenticated||![_record[@"state"]isEqual:@"active"])return nil;
    id claims=[self.class tokenPayload:_record[@"accessToken"]][@"https://api.openai.com/auth"];
    NSDictionary *auth=[claims isKindOfClass:NSDictionary.class]?claims:nil;
    id account=auth[@"chatgpt_account_id"]?:auth[@"account_id"],user=auth[@"chatgpt_user_id"]?:auth[@"user_id"];
    if(!Text(account,128)||!Text(user,256))return nil;
    return @{@"accountId":account,@"userId":user};
}
+ (BOOL)validRecord:(id)r {
    if(![r isKindOfClass:NSDictionary.class]||!Number(r[@"schema"])||[r[@"schema"]integerValue]!=3||![r[@"kind"]isEqual:@"web"]||!Number(r[@"revision"])||[r[@"revision"]doubleValue]<0||[r[@"revision"]doubleValue]>2147483646||floor([r[@"revision"]doubleValue])!=[r[@"revision"]doubleValue])return NO;
    NSArray *keys;
    if([r[@"state"]isEqual:@"signed_out"]){keys=@[@"schema",@"kind",@"state",@"revision",@"legacyCleanupPending"];if(![r[@"legacyCleanupPending"]isKindOfClass:NSNumber.class]||![@[@0,@1]containsObject:r[@"legacyCleanupPending"]])return NO;}
    else{
        if(![@[@"active",@"reauthentication_required"]containsObject:r[@"state"]]||![self validAccessToken:r[@"accessToken"]]||!Number(r[@"expiresAt"])||[r[@"expiresAt"]doubleValue]<=0||!Text(r[@"owner"],512)||![OR6WebCookies validRecords:r[@"cookies"]])return NO;
        if([self tokenExpiry:r[@"accessToken"]]!=[r[@"expiresAt"]doubleValue])return NO;
        keys=@[@"schema",@"kind",@"state",@"revision",@"accessToken",@"expiresAt",@"owner",@"cookies"];
        if(r[@"profile"]){if(!ValidProfile(r[@"profile"]))return NO;keys=[keys arrayByAddingObject:@"profile"];}
    }return [[NSSet setWithArray:[r allKeys]]isEqual:[NSSet setWithArray:keys]];
}
- (BOOL)hasStoredSession{return _legacyPresent||(_record&&(![_record[@"state"]isEqual:@"signed_out"]||_cleanupPending));}
- (BOOL)renewable{return [OR6WebCookies hasSession:_record[@"cookies"]?:@[] now:_clock()];}
- (void)changed:(NSString *)phase issue:(NSString *)issue {
    [_phase release];_phase=[phase copy];[_issue release];_issue=[issue copy];[_delegate webSessionChanged:self];
}
- (void)invalidate {
    _ownerValidated=NO;_generation++;_request++;[_task cancel];[_task release];_task=nil;_busy=NO;
}
- (BOOL)current:(NSUInteger)generation request:(NSUInteger)request{return generation==_generation&&request==_request&&_busy;}
- (void)adopt:(id<OR6WebTask>)task generation:(NSUInteger)generation request:(NSUInteger)request {
    // Providers are allowed to complete synchronously. Never overwrite a
    // later validation task with the just-returned session-fetch task.
    if([self current:generation request:request]){[_task release];_task=[task retain];}else[task cancel];
}
- (NSString *)safeIssue:(id)value {
    NSArray *allowed=@[@"network_unavailable",@"access_denied",@"rate_limited",@"server_unavailable",@"bad_response",@"invalid_session",@"no_session",@"expired_result",@"owner_changed",@"cancelled"];
    return [allowed containsObject:value]?value:@"network_unavailable";
}
- (void)failure:(NSString *)issue {
    _busy=NO;_authenticated=NO;[_task release];_task=nil;_migrating=NO;
    [self changed:@"recovery"issue:[self safeIssue:issue]];
}
- (BOOL)persist:(NSDictionary *)record {
    if(![self.class validRecord:record]){_storageStatus=-50;return NO;}if(![_store save:record status:&_storageStatus])return NO;
    for(NSString *key in @[@"state",@"accessToken",@"expiresAt",@"owner"])if(![record[key]isEqual:_record[key]]){_ownerValidated=NO;break;}
    [_record release];_record=[Snapshot(record)retain];_revision=[record[@"revision"]unsignedIntegerValue];return YES;
}
- (void)reauthenticate {
    _busy=NO;_authenticated=NO;[_task release];_task=nil;
    NSMutableDictionary *record;
    if(_record&&![_record[@"state"]isEqual:@"signed_out"]){record=[[_record mutableCopy]autorelease];record[@"state"]=@"reauthentication_required";record[@"revision"]=@(_revision+1);}
    else{record=[NSMutableDictionary dictionaryWithDictionary:@{@"schema":@3,@"kind":@"web",@"state":@"signed_out",@"revision":@(_revision+1),@"legacyCleanupPending":Flag(_migrating)}];_cleanupPending=_migrating;}
    _migrating=NO;
    if(![self persist:record]){[self changed:@"recovery"issue:@"storage_write"];return;}
    [self changed:@"reauthentication_required"issue:@"session_expired"];
}
- (void)acceptValidated:(NSDictionary *)candidate owner:(NSString *)owner profile:(NSDictionary *)validated {
    NSTimeInterval now=_clock(),expiry=[candidate[@"expiresAt"]doubleValue];
    if(!Text(owner,512)||expiry<=now+15||![OR6WebCookies validRecords:candidate[@"cookies"]]){if(_loginAttempt)[self failure:@"invalid_session"];else[self reauthenticate];return;}
    BOOL hadPrevious=_record&&[_record[@"state"]isEqual:@"active"];
    _bearerChanged=hadPrevious&&![_record[@"accessToken"]isEqual:candidate[@"accessToken"]];
    _expiryAdvanced=hadPrevious&&expiry>[_record[@"expiresAt"]doubleValue];
    NSMutableDictionary *record=[NSMutableDictionary dictionaryWithDictionary:@{@"schema":@3,@"kind":@"web",@"state":@"active",@"revision":@(_revision+1),@"owner":owner,
        @"accessToken":candidate[@"accessToken"],@"expiresAt":@(expiry),@"cookies":candidate[@"cookies"]}];
    NSDictionary *profile=[self profileFrom:validated owner:owner token:candidate[@"accessToken"]];if(profile)record[@"profile"]=profile;
    if(![self persist:record]){_busy=NO;_authenticated=NO;[_task release];_task=nil;[self changed:@"recovery"issue:@"storage_write"];return;}
    [_jar install:_record[@"cookies"]];_busy=NO;_authenticated=YES;_migrating=NO;_cleanupPending=NO;_loginAttempt=NO;
    [self recordOwnerValidation:owner generation:_generation];
    [_prior release];_prior=nil;
    [_task release];_task=nil;
    // An unchanged early session response is not a renewal. Check again at
    // actual expiry, rather than spinning on the same near-expiry token.
    _nextAutomatic=!self.renewable||expiry-now<=60?expiry:expiry-60;
    [self changed:@"authenticated"issue:@""];
}
- (void)validateCandidate:(NSDictionary *)candidate expectedOwner:(NSString *)owner generation:(NSUInteger)generation {
    NSDictionary *snapshot=Snapshot(candidate);NSString *expected=[[owner copy]autorelease];NSUInteger request=++_request;
    id<OR6WebTask> task=[_provider validate:snapshot[@"accessToken"]owner:expected completion:^(NSDictionary *r){
        if(![self current:generation request:request])return;
        _nativeStatus=[r[@"status"]isKindOfClass:NSNumber.class]?[r[@"status"]integerValue]:0;
        if(_nativeStatus==200&&[r[@"issue"]isEqual:@""]&&Text(r[@"owner"],512)){
            if(expected&&![expected isEqual:r[@"owner"]]){[self failure:@"owner_changed"];return;}
            [self acceptValidated:snapshot owner:r[@"owner"]profile:r[@"profile"]];
        }else if(_nativeStatus==401){
            // Only a restored old bearer may take this single recovery branch.
            // A newly fetched/login bearer is never retried automatically.
            if(_loginAttempt)[self failure:@"invalid_session"];
            else if([_phase isEqual:@"restoring"]&&[snapshot[@"cookies"]count]){[self changed:@"refreshing"issue:@""];[self fetchCandidate:snapshot generation:generation];}
            else [self reauthenticate];
        }else[self failure:[self safeIssue:r[@"issue"]]];
    }];[self adopt:task generation:generation request:request];
}
- (void)fetchCandidate:(NSDictionary *)candidate generation:(NSUInteger)generation {
    NSDictionary *previous=Snapshot(candidate);_renewals++;_cooldownUntil=_clock()+30;NSUInteger request=++_request;
    id<OR6WebTask> task=[_provider fetch:previous[@"cookies"]completion:^(NSDictionary *r){
        if(![self current:generation request:request])return;
        _webStatus=[r[@"status"]isKindOfClass:NSNumber.class]?[r[@"status"]integerValue]:0;
        if([r[@"issue"]isEqual:@"no_session"]||[r[@"issue"]isEqual:@"expired_result"]){[self reauthenticate];return;}
        if(_webStatus!=200||![r[@"issue"]isEqual:@""]||![self.class validAccessToken:r[@"accessToken"]]||![OR6WebCookies validRecords:r[@"cookies"]]){[self failure:[self safeIssue:r[@"issue"]]];return;}
        NSTimeInterval expiry=[self.class tokenExpiry:r[@"accessToken"]];if(expiry<=_clock()+15){[self reauthenticate];return;}
        NSDictionary *next=@{@"accessToken":r[@"accessToken"],@"expiresAt":@(expiry),@"cookies":r[@"cookies"]};
        [self changed:@"validating"issue:@""];[self validateCandidate:next expectedOwner:Text(previous[@"owner"],512)?previous[@"owner"]:nil generation:generation];
    }];[self adopt:task generation:generation request:request];
}
- (void)restore {
    if(_busy){_joins++;return;}[self invalidate];_restores++;_authenticated=NO;_migrating=NO;_storageStatus=0;_nativeStatus=0;_webStatus=0;
    NSDictionary *saved=[_store load:&_storageStatus];
    if(_storageStatus){[self changed:@"recovery"issue:@"storage_read"];return;}
    if(saved&&![self.class validRecord:saved]){[self changed:@"recovery"issue:@"storage_invalid"];return;}
    [_record release];_record=[Snapshot(saved)retain];_revision=[saved[@"revision"]unsignedIntegerValue];
    if([saved[@"state"]isEqual:@"signed_out"]){_cleanupPending=[saved[@"legacyCleanupPending"]boolValue];[_jar clear];[self changed:@"signed_out"issue:_cleanupPending?@"logout_cleanup":@""];return;}
    if([saved[@"state"]isEqual:@"reauthentication_required"]){[self changed:@"reauthentication_required"issue:@"session_expired"];return;}
    NSDictionary *candidate=saved;
    if(!candidate){
        NSDictionary *legacy=[_store legacy:&_storageStatus];if(_storageStatus){[self changed:@"recovery"issue:@"storage_read"];return;}_legacyPresent=legacy!=nil;
        if(!legacy){[self changed:@"signed_out"issue:@""];return;}
        if(![self.class validAccessToken:legacy[@"accessToken"]]){[self changed:@"recovery"issue:@"storage_invalid"];return;}
        candidate=@{@"accessToken":legacy[@"accessToken"],@"expiresAt":@([self.class tokenExpiry:legacy[@"accessToken"]]),@"cookies":[_jar snapshot]};_migrating=YES;
    }
    _busy=YES;[self changed:@"restoring"issue:@""];
    if([candidate[@"expiresAt"]doubleValue]<=_clock()+15){
        if([candidate[@"cookies"]count]){[self changed:@"refreshing"issue:@""];[self fetchCandidate:candidate generation:_generation];}
        else[self reauthenticate];
    }else[self validateCandidate:candidate expectedOwner:saved[@"owner"]generation:_generation];
}
- (void)renew {
    if(_busy){_joins++;return;}if(!_record||![_record[@"state"]isEqual:@"active"]){[self restore];return;}
    if(_clock()<_cooldownUntil&&[_record[@"expiresAt"]doubleValue]>_clock())return;
    if(!self.renewable){[self reauthenticate];return;}
    [self invalidate];_busy=YES;_webStatus=0;_nativeStatus=0;_bearerChanged=NO;_expiryAdvanced=NO;
    if([_record[@"expiresAt"]doubleValue]<=_clock())_authenticated=NO;
    [self changed:@"refreshing"issue:@""];[self fetchCandidate:_record generation:_generation];
}
- (void)activate {if(_authenticated&&!_busy&&_clock()>=_nextAutomatic)[self renew];}
- (NSTimeInterval)secondsUntilRenewal{
    if(!_authenticated||_busy)return -1;
    NSTimeInterval due=_nextAutomatic;if(_cooldownUntil>due)due=MIN(_cooldownUntil,[_record[@"expiresAt"]doubleValue]);
    return MAX(0,due-_clock());
}
- (NSUInteger)beginSignIn {
    NSDictionary *prior=Snapshot(_loginAttempt?_prior:_record);BOOL authenticated=_loginAttempt?_priorAuthenticated:_authenticated;
    [self invalidate];[_prior release];_prior=[prior retain];_priorAuthenticated=authenticated;_authenticated=NO;_migrating=NO;_loginAttempt=YES;
    [self changed:@"signing_in"issue:@""];return _generation;
}
- (BOOL)acceptWebCredential:(NSDictionary *)credential generation:(NSUInteger)generation {
    if(generation!=_generation||![_phase isEqual:@"signing_in"]||![self.class validAccessToken:credential[@"accessToken"]])return NO;
    NSTimeInterval expiry=[self.class tokenExpiry:credential[@"accessToken"]];if(expiry<=_clock()+15){[self changed:@"recovery"issue:@"invalid_session"];return NO;}
    NSDictionary *candidate=@{@"accessToken":credential[@"accessToken"],@"expiresAt":@(expiry),@"cookies":[_jar snapshot]};
    _busy=YES;[self changed:@"validating"issue:@""];[self validateCandidate:candidate expectedOwner:nil generation:generation];return YES;
}
- (void)cancelSignIn {
    if(!_loginAttempt)return;_loginAttempt=NO;
    [self invalidate];[_record release];_record=[Snapshot(_prior)retain];_authenticated=_priorAuthenticated&&[_record[@"expiresAt"]doubleValue]>_clock();
    [_prior release];_prior=nil;[self changed:_authenticated?@"authenticated":@"signed_out"issue:@""];
}
- (BOOL)signOut {
    [self invalidate];_authenticated=NO;_loginAttempt=NO;[_prior release];_prior=nil;_priorAuthenticated=NO;
    // Persist the migration barrier before removing legacy/cookie state. A late
    // response or crash can never restore credentials behind successful logout.
    NSDictionary *tombstone=@{@"schema":@3,@"kind":@"web",@"state":@"signed_out",@"revision":@(_revision+1),@"legacyCleanupPending":@YES};
    if(![self persist:tombstone]){[self changed:@"recovery"issue:@"storage_write"];return NO;}
    _cleanupPending=YES;[_jar clear];
    if(![_store clearLegacy:&_storageStatus]){[self changed:@"signed_out"issue:@"logout_cleanup"];return NO;}
    NSDictionary *clean=@{@"schema":@3,@"kind":@"web",@"state":@"signed_out",@"revision":@(_revision+1),@"legacyCleanupPending":@NO};
    if(![self persist:clean]){[self changed:@"signed_out"issue:@"logout_cleanup"];return NO;}
    _cleanupPending=NO;_migrating=NO;_legacyPresent=NO;[self changed:@"signed_out"issue:@""];return YES;
}
- (NSDictionary *)diagnostics {
    NSDictionary *cookies=[OR6WebCookies metadata:_record[@"cookies"]?:@[]];
    return @{@"schema":@3,@"kind":@"web",@"phase":_phase,@"issue":_issue,@"generation":@(_generation),@"revision":@(_revision),
        @"storageStatus":@(_storageStatus),@"authenticated":Flag(_authenticated),@"storedSession":Flag(self.hasStoredSession),@"renewable":Flag(self.renewable),
        @"busy":Flag(_busy),@"migrationPending":Flag(_migrating),@"legacyCleanupPending":Flag(_cleanupPending),@"cookies":cookies,
        @"nativeHTTPStatus":@(_nativeStatus),@"webHTTPStatus":@(_webStatus),@"restoreCount":@(_restores),@"sessionReadCount":@(_renewals),@"singleFlightJoins":@(_joins),
        @"bearerChanged":Flag(_bearerChanged),@"expiryAdvanced":Flag(_expiryAdvanced),@"automaticScheduled":Flag([self secondsUntilRenewal]>=0),@"nativeGrant":@NO};
}
- (void)dealloc{[_task cancel];[_task release];[_store release];[_provider release];[_jar release];[_clock release];[_validationClock release];[_record release];[_prior release];[_phase release];[_issue release];[super dealloc];}
@end
