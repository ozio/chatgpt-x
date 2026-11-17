#import "OR6CodexCloudInternal.h"
#import <CoreFoundation/CoreFoundation.h>
#include <math.h>
static BOOL Token(id value){return OR6CodexText(value,8192,NO)&&[value rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"]invertedSet]].location==NSNotFound;}
static BOOL Snapshot(NSDictionary*s){
 if(!OR6CodexKeys(s,@[@"context",@"userId",@"accessToken",@"expiresAt"],@[])||!OR6CodexKeys(s[@"context"],@[@"owner",@"workspace",@"connection",@"credentialGeneration"],@[]))return NO;
 NSDictionary*c=s[@"context"];for(NSString*k in @[@"owner",@"workspace"])if(!OR6CodexID(c[k]))return NO;
 return[c[@"connection"]isEqual:@"codex-cloud"]&&OR6APISchemaCheck(c[@"credentialGeneration"],@{@"type":@"integer",@"minimum":@1,@"maximum":@9007199254740991LL},@{})&&OR6CodexID(s[@"userId"])&&Token(s[@"accessToken"])&&OR6APISchemaCheck(s[@"expiresAt"],@{@"type":@"number"},@{})&&[s[@"expiresAt"]doubleValue]>[[NSDate date]timeIntervalSince1970];
}
@implementation OR6CodexCloudBinding
- (id)initWithSource:(OR6CodexCloudCredentialSource)source error:(NSError**)error{
 if(!(self=[super init]))return nil;NSDictionary*s=NSThread.isMainThread&&source?OR6APIJSONSnapshot(source(),16384):nil;
 if(!Snapshot(s)){if(error)*error=OR6CodexError(@"not_authenticated",NO);[self release];return nil;}_source=[source copy];_snapshot=[s retain];return self;
}
- (BOOL)current{
 if(!NSThread.isMainThread||_invalidated||!_source)return NO;
 NSDictionary*s=OR6APIJSONSnapshot(_source(),16384);if(!Snapshot(s)||![s isEqual:_snapshot]){[self invalidate];return NO;}return YES;
}
- (NSDictionary*)context{return _snapshot[@"context"];}
- (NSDictionary*)headers{if(![self current])return nil;return@{@"Authorization":[@"Bearer "stringByAppendingString:_snapshot[@"accessToken"]],@"ChatGPT-Account-Id":_snapshot[@"context"][@"workspace"],@"X-OpenAI-Product-Sku":@"codex",@"originator":@"legacy_ios6",@"User-Agent":@"LegacyClient/1 (iOS 6; Codex)"};}
- (NSDictionary*)socketHeaders{
 if(![self current])return nil;return@{@"ChatGPT-Account-Id":_snapshot[@"context"][@"workspace"],@"X-OpenAI-Product-Sku":@"codex",@"originator":@"legacy_ios6",@"User-Agent":@"LegacyClient/1 (iOS 6; Codex)",@"Sec-WebSocket-Protocol":[@"codex-app-server, codex-client.legacy_ios6, openai-bearer."stringByAppendingString:_snapshot[@"accessToken"]]};
}
- (void)invalidate{_invalidated=YES;[_source release];_source=nil;NSDictionary*c=[_snapshot[@"context"]retain];[_snapshot release];_snapshot=c?[@{@"context":c}retain]:nil;[c release];}
- (NSString*)description{return@"<OR6CodexCloudBinding private>";}
- (void)dealloc{[_source release];[_snapshot release];[super dealloc];}
@end

@implementation OR6CodexCloudProtocol
- (BOOL)validate:(id)v group:(NSString*)g method:(NSString*)m direction:(NSString*)dir{
 if([g isEqual:@"client"]&&[m isEqual:@"thread/start"]&&[dir isEqual:@"params"]){
  if(!OR6CodexKeys(v,@[@"environments",@"deferredEnvironment",@"pluginsMcp",@"config",@"historyMode"],@[])||![v[@"environments"]isKindOfClass:NSArray.class]||[v[@"environments"]count]!=1||!OR6APISchemaCheck(v[@"deferredEnvironment"],@{@"type":@"boolean",@"enum":@[@YES]},@{})||![v[@"pluginsMcp"]isEqual:@{@"productSku":@"codex"}]||![v[@"config"]isEqual:@{@"features.mcp_app_ui":@YES}]||![v[@"historyMode"]isEqual:@"paginated"])return NO;
  NSDictionary*e=v[@"environments"][0];return OR6CodexKeys(e,@[@"environmentConfigId"],@[@"cwd"])&&OR6CodexID(e[@"environmentConfigId"])&&(!e[@"cwd"]||OR6CodexPath(e[@"cwd"]));
 }
 return[super validate:v group:g method:m direction:dir];
}
@end
@implementation OR6CodexCloudSession
+ (Class)protocolClass{return OR6CodexCloudProtocol.class;}
- (id)initWithIO:(id<OR6CodexCloudIO>)wire binding:(OR6CodexCloudBinding*)b contracts:(NSDictionary*)c directory:(NSString*)d error:(NSError**)e{
 if((self=[super initWithTransport:wire contracts:c context:b.context directory:d error:e]))_binding=[b retain];return self;
}
- (BOOL)contextIsCurrent{return[_binding current];}
- (void)verifyAdmission:(OR6APIReply)cb{
 // A successful TLS/WSS initialize is channel admission. Account ownership is
 // supplied by the trusted existing ChatGPT session, not by cloud account/read
 // (the desktop intercepts that RPC locally). No invented ownership receipt.
 BOOL current=[_binding current];cb(current?@{@"source":@"trusted_chatgpt_session",@"serverOwnerReceipt":@NO}:nil,current?nil:OR6CodexError(@"stale_context",NO));
}
- (NSDictionary*)status{NSMutableDictionary*s=[[[super status]mutableCopy]autorelease];s[@"transportProfile"]=@"hosted-26.1106.51428";s[@"admission"]=@{@"source":@"trusted_chatgpt_session",@"serverOwnerReceipt":@NO};s[@"secureSetup"]=@{@"route":@"direct-cloud",@"mobileEnrollmentRequired":@NO,@"mobileEnrollmentSupported":@NO,@"hardwareSecureEnclave":@NO,@"osProtectedNonextractableVerified":@NO};return s;}
- (void)dealloc{[_binding release];[super dealloc];}
@end
