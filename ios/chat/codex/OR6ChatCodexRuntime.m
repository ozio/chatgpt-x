#import "OR6ChatCodexRuntime.h"
#import "OR6ChatCodexAccount.h"
#import "OR6ChatCodexKeys.h"
#import "../../api/codex/OR6CodexConnections.h"
#import "../../api/codex/OR6CodexSSH.h"
#import "../../api/codex/OR6CodexOperation.h"
#import "../../api/codex/OR6CodexPolicy8.h"
#import "../../api/codex/pair/OR6CodexPairOAuth.h"
#import <dispatch/dispatch.h>
#include <sys/stat.h>
NSString*const OR6ChatCodexChanged=@"OR6ChatCodexChanged";
static void Use(OR6CodexOperation*c,id<OR6APITask>(^start)(void)){if(c->done)return;NSUInteger serial=++c->serial;id<OR6APITask>t=start();if(!c->done&&serial==c->serial){[c->task release];c->task=[t retain];}}
@implementation OR6ChatCodexRuntime
- (id)initWithAdapter:(OR6APIWebAdapter*)a contracts:(NSDictionary*)c directory:(NSString*)d{if((self=[super init])){_adapter=[a retain];_contracts=[OR6APIJSONSnapshot(c,4*1024*1024)retain];_directory=[d copy];_calls=[NSMutableSet new];_suspended=YES;}return self;}
- (NSUInteger)epoch{return _epoch;}
- (NSString*)scopeID{return _credentialService;}
- (BOOL)available{return!_suspended&&_context!=nil;}
- (void)changed{[NSNotificationCenter.defaultCenter postNotificationName:OR6ChatCodexChanged object:self];}
- (void)reset{
 [_relay deactivate];[_relay release];_relay=nil;[_pair invalidate];[_pair release];_pair=nil;
 _epoch++;for(OR6CodexOperation*c in[[_calls.allObjects copy]autorelease])[c cancel];[_connections deactivate];[_connections release];_connections=nil;[_cloud deactivate];[_cloud release];_cloud=nil;[_environment release];_environment=nil;[_context release];_context=nil;[_selection release];_selection=nil;[_probe release];_probe=nil;[_probeToken release];_probeToken=nil;[_credentialService release];_credentialService=nil;
}
- (void)updateIdentity{
 NSDictionary*c=[_adapter codexAccountContext];if(!_suspended&&[_context isEqual:c])return;[self reset];_suspended=NO;if(!c||!_contracts){[self changed];return;}
 if(![[NSFileManager defaultManager]fileExistsAtPath:_directory])[[NSFileManager defaultManager]createDirectoryAtPath:_directory withIntermediateDirectories:NO attributes:@{NSFilePosixPermissions:@0700}error:NULL];
 struct stat st;if(lstat(_directory.fileSystemRepresentation,&st)||!S_ISDIR(st.st_mode)||st.st_uid!=getuid()||(st.st_mode&077)){[self changed];return;}
 _context=[c retain];_credentialService=[[@"io.ozio.chatgptx.chat.codex."stringByAppendingString:OR6CodexDigest([NSString stringWithFormat:@"%@\n%@",c[@"owner"],c[@"workspace"]])]copy];
 NSMutableDictionary*connectionContext=[[c mutableCopy]autorelease];[connectionContext removeObjectForKey:@"connection"];NSMutableDictionary*storage=[[connectionContext mutableCopy]autorelease];storage[@"credentialGeneration"]=@1;NSError*error=nil;
 // The profile namespace survives token rotation; each selected API receives
 // the exact live generation and versioned connection context from the factory.
 OR6APIWebAdapter*adapter=_adapter;NSDictionary*bound=_context,*contracts=_contracts;NSString*service=_credentialService,*directory=_directory;
 _connections=[[OR6CodexConnections alloc]initWithDirectory:_directory accountContext:connectionContext storageContext:storage factory:^OR6CodexAPI*(NSDictionary*p,NSDictionary*ctx,NSError**e){
  if(![bound isEqual:[adapter codexAccountContext]]){if(e)*e=OR6CodexError(@"stale_context",NO);return nil;}NSDictionary*key=OR6ChatCodexLoadKey(service,e);if(!key)return nil;
  OR6CodexSSH*t=[[[OR6CodexSSH alloc]initWithHost:p[@"host"]port:[p[@"port"]unsignedIntegerValue]username:p[@"username"]hostKeySHA256:p[@"hostKeySHA256"]credentials:key error:e]autorelease];if(!t)return nil;
  return[[[OR6CodexAPI alloc]initWithTransport:t contracts:contracts context:ctx privateDirectory:directory error:e]autorelease];
 }error:&error];if(!_connections){[_context release];_context=nil;}
 if(_context)_pair=[_adapter newCodexPairWithContracts:_contracts directory:_directory error:NULL];
 [_lastOAuthError release];_lastOAuthError=[OR6CodexPairOAuthSafeDiagnostic([_pair status][@"lastOAuthError"])copy];[_oauthErrorContext release];_oauthErrorContext=[_context copy];[self changed];
}
- (void)suspend{_suspended=YES;[self reset];[self changed];}
- (id<OR6APITask>)perform:(NSString*)op parameters:(NSDictionary*)raw event:(OR6APIEvent)event completion:(OR6APIReply)cb{
 if(!cb)return nil;if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{cb(nil,OR6CodexError(@"invalid_request",NO));});return nil;}
 if(!self.available||![_context isEqual:[_adapter codexAccountContext]]){[self suspend];cb(nil,OR6CodexError(@"stale_context",NO));return nil;}
 NSDictionary*p=OR6APIJSONSnapshot(raw,[op isEqual:@"codex.attachments.prepare"]?2*1024*1024:65536);if(!p||_calls.count>=16){cb(nil,OR6CodexError(@"invalid_request",NO));return nil;}__block NSUInteger epoch=_epoch;
 OR6CodexOperation*c=[[[OR6CodexOperation alloc]init]autorelease];[_calls addObject:c];c->reply=[^(NSDictionary*r,NSError*e){[_calls removeObject:c];if(!e&&[op isEqual:@"codex.cloud.environments.select"]){[_environment release];_environment=[r copy];}if(epoch!=_epoch||![_context isEqual:[_adapter codexAccountContext]]){e=OR6CodexError(@"stale_context",NO);if(_context)[self suspend];}if([@[@"rate_limited",@"service_challenge",@"not_authenticated"]containsObject:e.userInfo[@"code"]]){[self suspend];}cb(e?nil:OR6APIJSONSnapshot(r?:@{},2*1024*1024),e);if([@[@"ui.connections.select",@"ui.cloud.select",@"ui.connections.remove",@"codex.session.disconnect"]containsObject:op])[self changed];}copy];OR6APIReply finish=^(NSDictionary*r,NSError*e){[c finish:r error:e];};
 if([op isEqual:@"ui.environment.get"]){if(p.count)goto invalid;finish(_environment?:@{},nil);return c;}
 if([op isEqual:@"ui.connections.list"]){if(p.count)goto invalid;NSMutableArray *profiles=[NSMutableArray arrayWithArray:[_connections list]?:@[]];for(NSDictionary *host in [_pair status][@"data"]){NSString *identifier=[@"relay:"stringByAppendingString:host[@"env_id"]];[profiles addObject:@{@"id":identifier,@"name":host[@"name"],@"type":@"relay",@"selected":@([_selection isEqual:identifier]),@"state":_relay&&[_selection isEqual:identifier]?@"selected":@"unknown"}];}finish(@{@"data":profiles,@"selected":_selection?:NSNull.null,@"cloud":@(_cloud!=nil),@"pairAvailable":@(_pair!=nil)},nil);return c;}
 if([op isEqual:@"ui.connections.select"]&&[p[@"id"]isKindOfClass:NSString.class]&&[p[@"id"]hasPrefix:@"relay:"]){if(!OR6CodexKeys(p,@[@"id"],@[]))goto invalid;NSError *error=nil;OR6CodexAPI *api=[_pair newAPIForEnvironment:[p[@"id"]substringFromIndex:6]error:&error];if(!api){finish(nil,error?:OR6CodexError(@"unavailable",NO));return c;}[_relay deactivate];[_relay release];_relay=api;[_cloud deactivate];[_cloud release];_cloud=nil;[_connections performActive:@"codex.session.disconnect"parameters:@{}event:nil completion:^(NSDictionary *r,NSError *e){(void)r;(void)e;}];[_selection release];_selection=[p[@"id"]copy];_epoch++;epoch=_epoch;finish(@{},nil);return c;}
 if([op isEqual:@"ui.connections.remove"]&&[p[@"id"]isKindOfClass:NSString.class]&&[p[@"id"]hasPrefix:@"relay:"]){if(!OR6CodexKeys(p,@[@"id"],@[]))goto invalid;Use(c,^id<OR6APITask>{return [_pair perform:@"codex.pair.forget-host"parameters:@{@"environmentId":[p[@"id"]substringFromIndex:6]}completion:^(NSDictionary *r,NSError *e){if(!e&&[_selection isEqual:p[@"id"]]){[_relay deactivate];[_relay release];_relay=nil;[_selection release];_selection=nil;_epoch++;epoch=_epoch;}finish(r,e);}];});return c;}
 if([op hasPrefix:@"codex.pair."]){if(!_pair){finish(nil,OR6CodexError(@"capability_unavailable",NO));return c;}Use(c,^id<OR6APITask>{return [_pair perform:op parameters:p completion:^(NSDictionary *r,NSError *e){if(c->done)return;if(!e&&_relay&&[@[@"codex.pair.refresh",@"codex.pair.forget-local"]containsObject:op]){[_relay deactivate];[_relay release];_relay=nil;[_selection release];_selection=nil;_epoch++;epoch=_epoch;}
  if(epoch==_epoch&&[_context isEqual:[_adapter codexAccountContext]]){[_lastOAuthError release];_lastOAuthError=[OR6CodexPairOAuthSafeDiagnostic([_pair status][@"lastOAuthError"])copy];[_oauthErrorContext release];_oauthErrorContext=[_context copy];}
  finish(r,e);if(!e)[self changed];}];});return c;}
 if([op isEqual:@"ui.connections.select"]){[_relay deactivate];[_relay release];_relay=nil;if(!OR6CodexKeys(p,@[@"id"],@[]))goto invalid;NSError*e=nil;BOOL okay=[_connections select:p[@"id"]error:&e];[_cloud deactivate];[_cloud release];_cloud=nil;[_selection release];_selection=okay?[p[@"id"]copy]:nil;_epoch++;epoch=_epoch;finish(okay?@{}:nil,e);return c;}
 if([op isEqual:@"ui.cloud.select"]){[_relay deactivate];[_relay release];_relay=nil;if(p.count)goto invalid;[_connections performActive:@"codex.session.disconnect"parameters:@{}event:nil completion:^(NSDictionary*r,NSError*e){(void)r;(void)e;}];[_cloud deactivate];[_cloud release];NSError*e=nil;_cloud=[_adapter newCodexCloudWithContracts:_contracts directory:_directory error:&e];[_selection release];_selection=_cloud?[@"codex-cloud"copy]:nil;_epoch++;epoch=_epoch;finish(_cloud?@{}:nil,e);return c;}
 if([op isEqual:@"ui.connections.remove"]){if(!OR6CodexKeys(p,@[@"id"],@[]))goto invalid;NSError*e=nil;BOOL okay=[_connections remove:p[@"id"]error:&e];if(okay&&[_selection isEqual:p[@"id"]]){[_selection release];_selection=nil;_epoch++;epoch=_epoch;}finish(okay?@{}:nil,e);return c;}
 if([op isEqual:@"ui.ssh.key"]){if(p.count)goto invalid;NSError*e=nil;NSDictionary*key=OR6ChatCodexLoadKey(_credentialService,&e);if(key||e){finish(key?@{@"publicKey":key[@"publicKey"]}:nil,e);return c;}
  NSString*service=[[_credentialService copy]autorelease];dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{NSAutoreleasePool*pool=[NSAutoreleasePool new];NSError*error=nil;NSDictionary*k=[OR6ChatCodexGenerateKey(&error)retain];[error retain];dispatch_async(dispatch_get_main_queue(),^{if(!c->done){if(epoch!=_epoch||![_context isEqual:[_adapter codexAccountContext]])finish(nil,OR6CodexError(@"stale_context",NO));else{NSError*save=nil;if(k&&OR6ChatCodexSaveKey(service,k,&save))finish(@{@"publicKey":k[@"publicKey"]},nil);else finish(nil,save?:error?:OR6CodexError(@"storage_failure",NO));}}[k release];[error release];});[pool drain];});return c;
 }
 if([op isEqual:@"ui.ssh.probe"]){if(!OR6CodexKeys(p,@[@"host",@"port",@"username",@"name"],@[])||!OR6CodexID(p[@"username"])||!OR6CodexText(p[@"name"],128,NO)||!OR6APISchemaCheck(p[@"port"],@{@"type":@"integer",@"minimum":@1,@"maximum":@65535},@{}))goto invalid;NSError*e=nil;if(!OR6ChatCodexLoadKey(_credentialService,&e)){finish(nil,e?:OR6CodexError(@"not_found",NO));return c;}
  Use(c,^id<OR6APITask>{return[OR6CodexSSH probeHost:p[@"host"]port:[p[@"port"]unsignedIntegerValue]completion:^(NSDictionary*r,NSError*error){if(c->done)return;if(error||epoch!=_epoch){finish(nil,error?:OR6CodexError(@"stale_context",NO));return;}[_probe release];NSMutableDictionary*pr=[[p mutableCopy]autorelease];pr[@"hostKeySHA256"]=r[@"hostKeySHA256"];_probe=[pr copy];[_probeToken release];_probeToken=[NSProcessInfo.processInfo.globallyUniqueString copy];finish(@{@"probeToken":_probeToken,@"fingerprint":OR6ChatCodexFingerprint(r[@"hostKeySHA256"]),@"host":p[@"host"],@"port":p[@"port"]},nil);}];});return c;
 }
 if([op isEqual:@"ui.ssh.save"]){if(!OR6CodexKeys(p,@[@"probeToken"],@[])||![_probeToken isEqual:p[@"probeToken"]]||!_probe)goto invalid;NSString*identifier=NSProcessInfo.processInfo.globallyUniqueString;NSDictionary*profile=@{@"id":identifier,@"name":_probe[@"name"],@"type":@"ssh",@"host":_probe[@"host"],@"port":_probe[@"port"],@"username":_probe[@"username"],@"hostKeySHA256":_probe[@"hostKeySHA256"],@"credentialRef":@"ssh-rsa-v1"};NSError*e=nil;BOOL okay=[_connections upsert:profile error:&e];[_probe release];_probe=nil;[_probeToken release];_probeToken=nil;finish(okay?@{@"id":identifier}:nil,e);return c;}
 if([op hasPrefix:@"ui."])goto invalid;
 Use(c,^id<OR6APITask>{OR6APIEvent receive=^(NSDictionary*n){if(epoch==_epoch&&[_context isEqual:[_adapter codexAccountContext]]){if(event)event(n);[NSNotificationCenter.defaultCenter postNotificationName:OR6ChatCodexChanged object:self userInfo:@{@"event":n}];}};return _cloud?[_cloud perform:op parameters:p event:receive completion:finish]:_relay?[_relay perform:op parameters:p event:receive completion:finish]:[_connections performActive:op parameters:p event:receive completion:finish];});return c;
invalid:finish(nil,OR6CodexError(@"invalid_request",NO));return c;
}
- (NSDictionary*)diagnostics{return@{@"available":@(self.available),@"epoch":@(_epoch),@"active":@(_calls.count),@"selected":@(_selection!=nil),@"cloud":@(_cloud!=nil),@"pairing":@(_pair!=nil),@"relay":@(_relay!=nil),@"credentialValuesExported":@NO,@"lastOAuthError":[_oauthErrorContext isEqual:[_adapter codexAccountContext]]?(_lastOAuthError?:@{}):@{}};}
- (void)dealloc{[self suspend];[_lastOAuthError release];[_oauthErrorContext release];[_adapter release];[_contracts release];[_directory release];[_calls release];[super dealloc];}
@end
