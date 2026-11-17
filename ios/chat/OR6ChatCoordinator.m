#import "../api/voice-realtime/OR6Realtime.h"
#import "../api/revisit5local/OR6Rev5Local.h"
#import "../api/revisit5asr/OR6Rev5ASR.h"
#import "../api/revisit5local/OR6Rev5LocalDevice.h"
#import "../api/revisit5content/OR6Rev5Content.h"
#import "../api/revisit5system/OR6Rev5System.h"
#import "../api/revisit5all/OR6Rev5All.h"
#import "../api/revisit5all/OR6Rev5Host.h"
#import "../api/priority5a/OR6API5AProvider.h"
#import "../api/priority5b/OR6API5BProvider.h"
#import "../api/priority5d/OR6API5DProvider.h"
#import "../api/priority5e/OR6API5EProvider.h"
#import "codex/OR6ChatCodexPairPayload.h"
#import "codex/OR6ChatCodexScreens.h"
#import "../api/selected20/OR6Selected20.h"
#import "../api/revisit67all/OR6Rev67All.h"
#import "../api/revisit67all/OR6Rev67PersonalPolicy.h"
#import "../api/revisit67local/OR6Rev67Local.h"
#import "../api/revisit67local/OR6Rev67LocalDevice.h"
#import "../api/revisit67content/OR6Rev67Content.h"
#import "../api/revisit67account/OR6Rev67Account.h"
#import "OR6ChatPreparationFactory.h"
#import "OR6ChatCoordinator.h"
#import "OR6ChatNativeProvider.h"
#import "../api/OR6APIWebAdapter.h"
#import "../api/OR6APILocalProvider.h"
#import "../api/priority8/OR6API8Core.h"
#import "../api/priority8/OR6API8Policy.h"
#import "../api/priority8/OR6API8Provider.h"
#import "../api/priority8/OR6API8Media.h"
#import "../api/priority8/OR6API8Network.h"
#import "../api/priority8/OR6API8Interactions.h"
#import "../api/priority8/OR6API8Binding.h"
#import "../OR6Files.h"
#import "../api/priority9/OR6API9Policy.h"
#import "../api/priority9/OR6API9Provider.h"
#import "../api/priority9/OR6API9Network.h"
#import "../api/priority9/OR6API9AudioRecorder.h"
#import "../api/priority7all/OR6API7AllComposition.h"
#import "../api/priority7g/OR6API7GDevice.h"
#import "../api/priority6all/OR6API6AllComposition.h"
#import "../api/priority6a/OR6API6AProvider.h"
#import "../api/priority6c/OR6API6CProvider.h"
#import "../api/priority6c/OR6API6CNetwork.h"
#import "../api/priority6d/OR6API6DProvider.h"
#import "../api/priority6d/OR6API6DNetwork.h"
#import "../api/priority6e/OR6API6EProvider.h"
#import "../api/priority6f/OR6API6FProvider.h"
#import "../api/priority6f/OR6API6FNetwork.h"
#import "../api/priority6f/OR6API6FPolicy.h"
#import "../ui/priority7/OR6Chat7Conversation.h"
#import "../ui/selected20/OR6Chat20Conversation.h"
#import "../ui/priority6/OR6Chat6Screens.h"
#import "../auth/OR6WebStore.h"
#import "../auth/OR6WebTransport.h"
#import "../auth/OR6AuthEngine.h"
#import "../localization/OR6Localization.h"
#import "RCTheme.h"
#import "RCWebFrameController.h"
#import <dispatch/dispatch.h>
#include <unistd.h>
@interface OR6ChatCoordinator()<RCWebFrameControllerDelegate,OR6Chat6TrustedHost>
@end
@interface OR6ChatCoordinator(Interaction)
- (id<OR6APITask>)presentProvider:(NSString*)provider generation:(NSUInteger)generation completion:(void(^)(NSString*))completion;
- (void)closeLogin:(NSString*)state;
- (void)requestSync;
- (void)observeReceipt;
- (void)receiptTick:(NSTimer*)timer;
- (void)invalidateProviders;
- (id<OR6APIProvider>)api5ObserverWithNext:(id<OR6APIProvider>)next vault:(OR6Files*)vault;
@end
@interface OR6ChatAuthHost:NSObject<OR6APIInteractionHost>{@public OR6ChatCoordinator*owner;}
@end
@implementation OR6ChatAuthHost
- (id<OR6APITask>)presentProvider:(NSString*)provider session:(OR6WebSession*)s generation:(NSUInteger)gen completion:(void(^)(NSString*))completion{(void)s;return[owner presentProvider:provider generation:gen completion:completion];}
@end
@interface OR6ChatLoginTask:NSObject<OR6APITask>{@public OR6ChatCoordinator*owner;}
@end
@implementation OR6ChatLoginTask
- (void)cancel{[owner closeLogin:@"cancelled"];}
@end
// The one-shot API67 location adapter retains no precise-location cache.
// This real empty-cache adapter has no back-reference to the coordinator/Core,
// avoiding a provider → cache → host retain cycle under MRC.
@interface OR6Chat6EmptyLocationCache:NSObject<OR6API6DLocationCache>{NSDictionary*_context;}
- (id)initWithContext:(NSDictionary*)context;
@end
@implementation OR6Chat6EmptyLocationCache
- (id)initWithContext:(NSDictionary*)context{if((self=[super init]))_context=[OR6APIJSONSnapshot(context,4096)retain];return self;}
- (BOOL)clearPreciseLocationForContext:(NSDictionary*)ctx error:(NSError**)error{BOOL current=NSThread.isMainThread&&[_context isEqual:ctx];if(!current&&error)*error=OR6APIError(@"stale_context",@"none");return current;}
- (void)dealloc{[_context release];[super dealloc];}
@end
@implementation OR6ChatCoordinator
@synthesize root=_root;
- (id)initWithWindow:(UIWindow*)window error:(NSError**)error{
 if(!(self=[super init]))return nil;_active=YES;
 NSString*roots=[NSBundle.mainBundle pathForResource:@"roots"ofType:@"pem"];NSString*registryPath=[NSBundle.mainBundle pathForResource:@"contracts"ofType:@"json"];NSData*data=[NSData dataWithContentsOfFile:registryPath];NSDictionary*registry=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]:nil;
 NSTimeInterval(^clock)(void)=^{return[[NSDate date]timeIntervalSince1970];};OR6WebKeychain*store=[[[OR6WebKeychain alloc]initWithBundle:NSBundle.mainBundle.bundleIdentifier]autorelease];OR6WebTransport*transport=[[[OR6WebTransport alloc]initWithRoots:roots clock:clock]autorelease];OR6WebSystemJar*jar=[[[OR6WebSystemJar alloc]init]autorelease];_session=[[OR6WebSession alloc]initWithStore:store provider:transport jar:jar clock:clock];
 _reads=[[OR6APIWebAdapter alloc]initWithSession:_session roots:roots workspace:nil permittedReads:[NSSet setWithArray:@[@"history.list",@"history.get",@"history.search",@"models.list"]]];
 // Keep the genuine minimal Sentinel document in a laid-out hierarchy.
 // The opaque native navigation controller covers it completely.
 _webHost=[[UIView alloc]initWithFrame:CGRectMake(0,0,320,480)];_webHost.userInteractionEnabled=NO;[window insertSubview:_webHost atIndex:0];
 _web=[[OR6ChatNativeProvider alloc]initWithAdapter:_reads preparation:OR6ChatCreatePreparation(_webHost,roots) roots:roots recoveryDirectory:[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES)[0]stringByAppendingPathComponent:@"ChatGPTXRecovery-v1"]];
 [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(transportChanged:)name:@"OR6ChatTransportChanged"object:_web];
 [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(transportChanged:)name:@"OR6ChatUIChanged"object:nil];
 OR6ChatAuthHost*host=[[[OR6ChatAuthHost alloc]init]autorelease];host->owner=self;_authHost=[host retain];_auth=[[OR6APISessionProvider alloc]initWithSession:_session host:host next:_web];_auth.observer=self;OR6APILocalProvider*local=[[[OR6APILocalProvider alloc]initWithNext:_auth]autorelease];NSString*library=NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES)[0];NSString*journal=[library stringByAppendingPathComponent:@"ChatGPTXOperations-v1"];
 OR6API9Network*network=[[[OR6API9Network alloc]initWithAdapter:_reads roots:roots]autorelease];OR6API9AudioRecorder*recorder=[[[OR6API9AudioRecorder alloc]initWithDirectory:[library stringByAppendingPathComponent:@"ChatGPTXDictation-v1"]error:error]autorelease];
 NSString*pending=recorder.snapshot[@"recordingId"];if(OR6API9UUID(pending))[NSUserDefaults.standardUserDefaults setObject:pending forKey:@"ChatGPTXUI9RecordingID"];else[NSUserDefaults.standardUserDefaults removeObjectForKey:@"ChatGPTXUI9RecordingID"];
 // Preserve the installed session, native recovery and UI9 journals. Only the
 // provider layers grow: no second delegate/coordinator and no journal replay.
 NSString*documents=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES)[0];NSString*inbox=[documents stringByAppendingPathComponent:@"Inbox"];
 OR6Files*vault=[[[OR6Files alloc]initWithDirectory:[documents stringByAppendingPathComponent:@"MediaFiles-v1"]inbox:inbox error:error]autorelease];
 OR6API8Picker*picker=[[[OR6API8Picker alloc]initWithPresenter:nil inbox:inbox]autorelease];
 // Estuary same-origin uploads work without admitting arbitrary signed hosts.
 OR6API8Network*files=[[[OR6API8Network alloc]initWithAdapter:_reads roots:roots storageHosts:[NSSet set]]autorelease];
 _media8=[[OR6API8Media alloc]initWithNext:local vault:vault inbox:inbox HTTP:files picker:picker journal:[library stringByAppendingPathComponent:@"ChatGPTXAPI8Media-v1"]capabilities:[NSSet setWithArray:@[@"upload",@"download"]]error:error];
 _priority8=[[OR6API8Provider alloc]initWithNext:_media8 generation:(id<OR6API8Generation>)_web media:_media8 capabilities:[NSSet setWithArray:@[@"temporary",@"edit",@"regenerate",@"model",@"attachments",@"search",@"translate"]]];
 _priority9=[[OR6API9Provider alloc]initWithNext:_priority8 HTTP:network recorder:recorder coreJournalDirectory:journal controlJournalDirectory:[library stringByAppendingPathComponent:@"ChatGPTXControls-v1"]capabilities:[NSSet setWithArray:@[@"stop",@"transcribe"]]error:error];
 if(!vault||!picker||!files||!_media8||!_priority8||!network||!recorder||!_priority9){[self release];return nil;}
 // API7: the complete inventory outside the unchanged 9→8→Media chain, same Core journal
 // directory. Capabilities follow the bundled admission tiers (default-denied); a missing
 // or invalid manifest keeps the previous API8 Core instead of failing the app.
 _api7=[self newAPI7CompositionBase:OR6API8Registry(registry)roots:roots media:_media8 vault:vault library:library];
 _api6=_api7?[self newAPI6CompositionLibrary:library vault:vault inbox:inbox roots:roots]:nil;
 // API6 sits on API7 with exact bundled tiers; source-backed actions require explicit UI intent.
 if(_api6){
  NSDictionary*(^extension)(NSString*)=^NSDictionary*(NSString*name){NSString*p=[NSBundle.mainBundle pathForResource:name ofType:@"json"];NSData*d=p?[NSData dataWithContentsOfFile:p]:nil;return d?[NSJSONSerialization JSONObjectWithData:d options:0 error:NULL]:nil;};
  NSError*fiveError=nil;NSMutableDictionary*fiveExtensions=[NSMutableDictionary dictionary];for(NSString*k in @[@"5a",@"5b",@"5c",@"5d",@"5e"]){NSDictionary*x=extension([@"contracts-"stringByAppendingString:k]);if(x)fiveExtensions[k]=x;}
  _rev5Host=[[OR6Rev5Host alloc]initWithAdapter:_reads session:_session directory:[library stringByAppendingPathComponent:@"ChatGPTXAPI5Host-v1"]error:&fiveError];
  if(_rev5Host)_api5Adapter=[[OR6Rev5AccountAdapter alloc]initWithBase:_reads session:_session roots:roots];
  OR6Rev5WorkspaceNetwork*workspace=_rev5Host?[[[OR6Rev5WorkspaceNetwork alloc]initWithAdapter:_reads roots:roots host:_rev5Host]autorelease]:nil;
  _rev5Workspace=[workspace retain];
  if(_api5Adapter&&fiveExtensions.count==5)_api5=[[OR6API5AllComposition alloc]initWithBase:_api6.registry extensions:fiveExtensions adapter:_api5Adapter roots:roots next:_api6.provider directory:[library stringByAppendingPathComponent:@"ChatGPTXAPI5-v1"]capabilities:OR6Rev5LegacyCapabilities(fiveExtensions)transport:nil contentHosts:[NSSet set]workspaceTransport:workspace error:&fiveError];
  if(_api5)_api5Tiers=[OR6Rev5LegacyTiers(fiveExtensions)copy];
  NSDictionary*fiveBase=_api5?_api5.registry:_api6.registry;
  NSError*selectedError=nil;NSDictionary*selectedRegistry=OR6Selected20Registry(fiveBase,extension(@"contracts-5a"),extension(@"contracts-4b"),&selectedError);
  if(selectedRegistry){OR6Selected20Network*n=[[[OR6Selected20Network alloc]initWithAdapter:_reads roots:roots]autorelease];id<OR6API7GPlatform>d=_playbackDevice;_selected20=[[OR6Selected20Provider alloc]initWithNext:(_api5?_api5.provider:_api6.provider) HTTP:n registry:selectedRegistry vault:vault inboxDirectory:inbox journalDirectory:[library stringByAppendingPathComponent:@"ChatGPTXSelected20-v1"] platform:d];
   if(_selected20){
    NSError*revisionError=nil;NSDictionary*revisionRegistry=OR6Rev67AllRegistry(selectedRegistry,&revisionError);
    if(revisionRegistry){
     OR6Rev67ContentNetwork*contentNetwork=[[[OR6Rev67ContentNetwork alloc]initWithAdapter:_reads roots:roots]autorelease];
     _rev67Content=[[OR6Rev67ContentProvider alloc]initWithNext:_selected20 HTTP:contentNetwork registry:revisionRegistry media:_media8 generation:(id<OR6API8Generation>)_web vault:vault inboxDirectory:inbox journalDirectory:[library stringByAppendingPathComponent:@"ChatGPTXAPI67-v1"]error:&revisionError];
     OR6Rev67AccountNetwork*accountNetwork=[[[OR6Rev67AccountNetwork alloc]initWithAdapter:_reads roots:roots]autorelease];
     if(_rev67Content)_rev67Account=[[OR6Rev67AccountProvider alloc]initWithNext:_rev67Content HTTP:accountNetwork registry:revisionRegistry];
     OR6Rev67LocalDevice*localDevice=[[[OR6Rev67LocalDevice alloc]init]autorelease];
     if(_rev67Account)_rev67Local=[[OR6Rev67LocalProvider alloc]initWithNext:_rev67Account registry:revisionRegistry vault:vault inboxDirectory:inbox recorder:recorder playback:d platform:localDevice];
     [_rev67Local setMedia:_media8];
     OR6API7AllComposition*policyComposition=_api7;
     OR6Rev67AccountNetwork*policyNetwork=[[[OR6Rev67AccountNetwork alloc]initWithAdapter:_reads roots:roots]autorelease];
     if(_rev67Local)_rev67Personal=[[OR6Rev67PersonalPolicy alloc]initWithNext:_rev67Local HTTP:policyNetwork registry:revisionRegistry memoryBinder:^BOOL(NSDictionary*policy,NSDictionary*ctx){return[policyComposition bindMemoryPolicy:policy context:ctx];}privacyBinder:^BOOL(NSDictionary*policy,NSDictionary*ctx){return[policyComposition bindPrivacyPolicy:policy context:ctx];}];
     OR6Rev67AllObserver*observer=_rev67Personal?[[[OR6Rev67AllObserver alloc]initWithNext:_rev67Personal local:_rev67Local media:_media8 vault:vault]autorelease]:nil;
     OR6API7AllComposition*projectComposition=_api7;[observer setProjectUploadBinder:^BOOL(NSArray*files,NSDictionary*ctx){return[projectComposition bindProjectUploadedFiles:files context:ctx];}];
     id<OR6APIProvider>fiveProvider=observer;
     if(observer&&_api5){OR6Rev67AccountNetwork*familyNetwork=[[[OR6Rev67AccountNetwork alloc]initWithAdapter:_reads roots:roots]autorelease];_rev5Family=[[OR6Rev5FamilyPolicy alloc]initWithNext:observer HTTP:familyNetwork registry:revisionRegistry family:(OR6API5EProvider*)[_api5 providerForModule:@"5e"]];
      NSDictionary*allFive=OR6Rev5AllRegistry(revisionRegistry,&revisionError);
      if(allFive&&_rev5Family){OR6Rev5ContentNetwork*contentHTTP=[[[OR6Rev5ContentNetwork alloc]initWithAdapter:_reads roots:roots]autorelease];_rev5Content=[[OR6Rev5ContentProvider alloc]initWithNext:_rev5Family HTTP:contentHTTP registry:allFive vault:vault media:_media8 inboxDirectory:inbox playback:d journalDirectory:[library stringByAppendingPathComponent:@"ChatGPTXAPI5Content-v1"]error:&revisionError];
       OR6Rev5SystemNetwork*systemHTTP=[[[OR6Rev5SystemNetwork alloc]initWithAdapter:_reads roots:roots]autorelease];if(_rev5Content)_rev5System=[[OR6Rev5SystemProvider alloc]initWithNext:_rev5Content HTTP:systemHTTP registry:allFive journalDirectory:[library stringByAppendingPathComponent:@"ChatGPTXAPI5System-v1"]error:&revisionError];
       _rev5Device=[[OR6Rev5LocalDevice alloc]init];if(_rev5System)_rev5Local=[[OR6Rev5LocalProvider alloc]initWithNext:_rev5System registry:allFive vault:vault media:_media8 inboxDirectory:inbox platform:_rev5Device recorder:recorder playback:d journalDirectory:[library stringByAppendingPathComponent:@"ChatGPTXAPI5Local-v1"]error:&revisionError];
       if(_rev5Local)_rev5ASR=[[OR6Rev5ASRProvider alloc]initWithNext:_rev5Local registry:allFive vault:vault media:_media8 modelsDirectory:[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Rev5ASRModel"]error:&revisionError];
       if(_rev5ASR)revisionRegistry=allFive;}
      fiveProvider=_rev5ASR?[self api5ObserverWithNext:_rev5ASR vault:vault]:nil;}
     if(fiveProvider){_voice8=[[OR6RealtimeProvider alloc]initWithNext:fiveProvider adapter:_reads roots:roots];_core=[[(_api5?OR6Rev5AllCore.class:OR6Rev67AllCore.class)alloc]initWithRegistry:OR6RealtimeRegistry(revisionRegistry) provider:_voice8 journalDirectory:journal error:&revisionError];_voice8.core=_core;}
    }
    if(!_core){[_rev5ASR release];_rev5ASR=nil;[_rev5Device setPresenter:nil];[_rev5Local release];_rev5Local=nil;[_rev5Content release];_rev5Content=nil;[_rev5System release];_rev5System=nil;[_rev5Device release];_rev5Device=nil;[_rev5Family release];_rev5Family=nil;[_rev67Personal release];_rev67Personal=nil;[_rev67Local release];_rev67Local=nil;[_rev67Account release];_rev67Account=nil;[_rev67Content release];_rev67Content=nil;
     _core=[[(_api5?OR6Rev5AllCore.class:OR6Selected20Core.class)alloc]initWithRegistry:selectedRegistry provider:(_api5?[self api5ObserverWithNext:_selected20 vault:vault]:(id<OR6APIProvider>)_selected20) journalDirectory:journal error:error];}
   }}
  if(!_core&&_api5)_core=[[OR6Rev5AllCore alloc]initWithRegistry:_api5.registry provider:[self api5ObserverWithNext:_api5.provider vault:vault] journalDirectory:journal error:error];
 if(!_core)_core=[[OR6API6AllCore alloc]initWithRegistry:_api6.registry provider:_api6.provider journalDirectory:journal error:error];
 }
 if(!_core&&_api7)_core=[[OR6API7AllCore alloc]initWithRegistry:_api7.registry provider:_api7.provider journalDirectory:journal error:error];
 if(!_core)_core=[[OR6API8Core alloc]initWithRegistry:OR6API8Registry(registry)provider:_priority9 journalDirectory:journal error:error];
 // One tier table for the API7 and API6 screens; API6 tiers only when its Core is the one in use.
 {NSMutableDictionary*tiers=[NSMutableDictionary dictionaryWithDictionary:_api7?_api7.tiers:@{}];if(_api6&&[_core isKindOfClass:OR6API6AllCore.class])[tiers addEntriesFromDictionary:_api6Tiers];if(_api5)[tiers addEntriesFromDictionary:_api5Tiers];if(_rev5Local)[tiers addEntriesFromDictionary:OR6Rev5AllTiers()];if(_selected20&&[_core isKindOfClass:OR6Selected20Core.class])[tiers addEntriesFromDictionary:OR6Selected20Tiers()];if(_rev67Local&&[_core isKindOfClass:OR6Rev67AllCore.class])[tiers addEntriesFromDictionary:OR6Rev67AllTiers()];OR6Chat7SetTiers(_api7?tiers:nil);}OR6Chat7SetPolicies([NSSet set]); // API-only per-action personal policy is private; no cached UI eligibility.
 // Trusted host only: the one-use share token of images.export becomes validated vault URLs for the system sheet.
 OR6API7AllComposition*composition=_api7;OR6Chat7SetExportResolver(composition?^NSArray*(NSString*token){return[composition exportURLsForToken:token];}:nil);
 // Trusted host only: an asset of the exact current binding → bounded PNG/JPEG bytes for the in-app preview (never through Core JSON).
 OR6API8Media*previewMedia=_media8;__block OR6APICore*previewCore=_core;OR6APIWebAdapter*previewReads=_reads;
 NSData*(^priorPreview)(NSString*)=composition?^NSData*(NSString*assetId){NSData*d=[composition imagePreviewDataForAsset:assetId];if(d)return d;NSString*key=previewReads.contextKey;return key?[previewMedia imagePreviewDataForAsset:assetId context:@{@"key":key,@"generation":previewCore.diagnostics[@"generation"]}]:nil;}:nil;
 [_selected20 setImagePreviewResolver:priorPreview];[_rev67Content setImagePreviewResolver:priorPreview];OR6Selected20Provider*selectedPreview=_selected20;
 OR6Chat7SetImagePreviewResolver(composition?^NSData*(NSString*assetId){NSData*d=[selectedPreview imagePreviewDataForAsset:assetId];return d?:priorPreview(assetId);}:nil);
 if([_core isKindOfClass:OR6Rev5AllCore.class]){OR6Rev5Host*liveHost=_rev5Host;[(OR6Rev5AllCore*)_core setLiveContextSource:^NSDictionary*{return liveHost.liveContext;}];}
 if(!_core||!_auth||!_reads||!_web){[self release];return nil;}
 __block OR6ChatCoordinator*owner=self;_binding8=[[OR6API8Binding alloc]initWithCore:_core adapter:_reads session:_session invalidate:^{[owner invalidateProviders];}changed:nil];
 if(!_binding8){if(error)*error=OR6APIError(@"invalid_request",@"none");[self release];return nil;}
 [_web setReadContextSource:^NSDictionary*{NSString*k=owner->_reads.contextKey;return k?@{@"key":k,@"generation":owner->_core.diagnostics[@"generation"]}:nil;}];
 OR6Chat6SetTrustedHost(_api6&&[_core isKindOfClass:OR6API6AllCore.class]?self:nil);
 [self bindAPI6];
 // First API7 launch: the app's explicitly stored appearance (not a registered default) seeds the new
 // preference store once; the startup look itself is unchanged (OR6ChatApplySavedLook).
 if(_api7)OR6Chat7MigrateAppearance(_core,_api7.preferencesPath,[[NSUserDefaults.standardUserDefaults persistentDomainForName:NSBundle.mainBundle.bundleIdentifier]objectForKey:@"RCAppearance"]); // after the binding set the Core context
 NSString*codexPath=[NSBundle.mainBundle pathForResource:@"codex-contracts"ofType:@"json"];NSDictionary*codexContracts=codexPath?[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:codexPath]options:0 error:NULL]:nil;_codex=[[OR6ChatCodexRuntime alloc]initWithAdapter:_reads contracts:codexContracts directory:[library stringByAppendingPathComponent:@"ChatGPTXCodex-v1"]];[_codex updateIdentity];
 _root=[[OR6ChatRootController alloc]initWithCore:_core host:self];[picker setPresenter:_root];[_rev67Content setMailPresenter:_root];[_rev5Device setPresenter:_root];return self;
}
- (id<OR6APIProvider>)api5ObserverWithNext:(id<OR6APIProvider>)next vault:(OR6Files*)vault{
 [_rev5Observer setWorkspaceChanged:nil];[_rev5Observer setWorkspaceAllowed:nil];[_rev5Observer release];_rev5Observer=nil;
 if(!next||!_rev5Host)return nil;
 _rev5Observer=[[OR6Rev5Observer alloc]initWithNext:next adapter:_reads host:_rev5Host];
 __block OR6ChatCoordinator*owner=self;[_rev5Observer setWorkspaceChanged:^{[owner requestSync];}];[_rev5Workspace setContextChanged:^{[owner requestSync];}];
 BOOL(^allowed)(void)=^BOOL{if(!owner->_root||!owner->_active)return NO;NSDictionary*u=owner->_root.diagnostics[@"conversation"];return[u isKindOfClass:NSDictionary.class]&&u[@"draftLength"]&&![u[@"draftLength"]unsignedIntegerValue]&&![u[@"attachments"]unsignedIntegerValue]&&![u[@"sending"]boolValue]&&![u[@"uncertain"]boolValue]&&![u[@"files8"][@"items"]unsignedIntegerValue]&&[owner->_core.diagnostics[@"activeCount"]unsignedIntegerValue]<=1;};
 [_rev5Observer setWorkspaceAllowed:allowed];[_rev5Workspace setWorkspaceAllowed:allowed];
 OR6Rev5LocalProvider*local=_rev5Local;OR6Rev5ASRProvider*asr=_rev5ASR;[_rev5Observer setAudioWillStart:^{[local stopVideo];}];
 [_rev5Observer setAssetDidValidate:^(NSString*op,NSDictionary*r,NSDictionary*ctx){NSString*identifier=[@[@"assets.acquire",@"assets.upload",@"assets.download"]containsObject:op]&&[r[@"assetId"]isKindOfClass:NSString.class]?r[@"assetId"]:[op isEqual:@"media.audioRecording.attach"]&&[r[@"asset"]isKindOfClass:NSDictionary.class]?r[@"asset"][@"id"]:nil;if(identifier){NSDictionary*asset=[vault assetForID:identifier error:NULL];if(asset){[local bindAssets:@[asset]context:ctx];[asr bindAssets:@[asset]context:ctx];}}}];
 return _rev5Observer;
}
- (OR6API7AllComposition*)newAPI7CompositionBase:(NSDictionary*)base roots:(NSString*)roots media:(OR6API8Media*)media vault:(OR6Files*)vault library:(NSString*)library{
 NSDictionary*(^load)(NSString*)=^NSDictionary*(NSString*name){NSString*path=[NSBundle.mainBundle pathForResource:name ofType:@"json"];NSData*d=path?[NSData dataWithContentsOfFile:path]:nil;id v=d?[NSJSONSerialization JSONObjectWithData:d options:0 error:NULL]:nil;return[v isKindOfClass:NSDictionary.class]?v:nil;};
 NSMutableDictionary*x=[NSMutableDictionary dictionary];for(NSString*k in @[@"7",@"7b",@"7c",@"7d",@"7e",@"7f",@"7g"]){NSDictionary*e=load([@"contracts-"stringByAppendingString:k]);if(!e){[_api7Issue release];_api7Issue=@"extension_missing";return nil;}x[k]=e;}
 NSDictionary*admission=load(@"priority7-admission");if(!admission||!base){[_api7Issue release];_api7Issue=@"admission_missing";return nil;}
 NSError*e=nil;OR6API7GDevice*device=[[[OR6API7GDevice alloc]init]autorelease];[_playbackDevice release];_playbackDevice=[device retain];
 OR6API7AllComposition*c=[[OR6API7AllComposition alloc]initWithBase:base extensions:x admission:admission adapter:_reads roots:roots next:_priority9 media:media generation:(id<OR6API8Generation>)_web vault:vault directory:[library stringByAppendingPathComponent:@"ChatGPTXAPI7-v1"]platform:device capture:nil error:&e];
 if(!c){[_api7Issue release];_api7Issue=[(e.userInfo[@"code"]?:@"composition_failed")copy];}return c;
}
- (NSDictionary*)api6Context{NSString*key=_reads.contextKey;if(!key.length)key=@"anonymous";id g=_core.diagnostics[@"generation"];return@{@"key":key,@"generation":[g isKindOfClass:NSNumber.class]?g:@1};}
- (void)bindAPI6{
 if(!_api6)return;NSDictionary*ident=[_session serviceAccount];if(!ident)return;NSDictionary*ctx=[self api6Context];[_media8 bindContext:ctx];
 OR6API6AProvider*a=(id)[_api6 providerForModule:@"6a"];OR6API6EProvider*e=(id)[_api6 providerForModule:@"6e"];
 OR6API6CProvider*c=(id)[_api6 providerForModule:@"6c"];OR6API6DProvider*d=(id)[_api6 providerForModule:@"6d"];
 [a bindIdentity:ident context:ctx];[e bindIdentity:ident context:ctx];
 [_selected20 bindIdentity:ident context:ctx];[_rev67Local bindIdentity:ident context:ctx];[_rev67Content bindIdentity:ident context:ctx];[_rev67Account bindIdentity:ident context:ctx];[_rev67Personal bindIdentity:ident context:ctx];[_rev5Family bindIdentity:ident context:ctx];[_rev5Local bindIdentity:ident context:ctx];[_rev5Content bindIdentity:ident context:ctx];[_rev5System bindIdentity:ident context:ctx];[_rev5ASR bindIdentity:ident context:ctx];
 [(OR6API5AProvider*)[_api5 providerForModule:@"5a"]bindIdentity:ident context:ctx];[(OR6API5DProvider*)[_api5 providerForModule:@"5d"]bindIdentity:ident context:ctx];
 [(OR6API5BProvider*)[_api5 providerForModule:@"5b"]bindIdentity:@{@"userId":ident[@"userId"],@"accountId":ident[@"accountId"],@"workspaceId":NSNull.null}context:ctx];
 NSDictionary*ws=@{@"userId":ident[@"userId"],@"workspaceId":NSNull.null};
 [_api7 bindProjectIdentity:ws context:ctx];[c bindIdentity:ws context:ctx];[d bindIdentity:ws context:ctx];
}
- (OR6API6AllComposition*)newAPI6CompositionLibrary:(NSString*)library vault:(OR6Files*)vault inbox:(NSString*)inbox roots:(NSString*)roots{
 NSDictionary*(^load)(NSString*)=^NSDictionary*(NSString*name){NSString*path=[NSBundle.mainBundle pathForResource:name ofType:@"json"];NSData*d=path?[NSData dataWithContentsOfFile:path]:nil;id v=d?[NSJSONSerialization JSONObjectWithData:d options:0 error:NULL]:nil;return[v isKindOfClass:NSDictionary.class]?v:nil;};
 NSMutableDictionary*x=[NSMutableDictionary dictionary];for(NSString*k in @[@"6a",@"6b",@"6c",@"6d",@"6e",@"6f"]){NSDictionary*e=load([@"contracts-"stringByAppendingString:k]);if(!e){[_api6Issue release];_api6Issue=@"extension_missing";return nil;}x[k]=e;}
 // Exact coverage and tier validation; user_action is source-backed explicit UI
 // intent, never a fabricated live_verified observation.
 NSError*admissionError=nil;NSDictionary*admitted=OR6API6AllAdmission(load(@"priority6-admission"),x,&admissionError);
 if(!admitted){[_api6Issue release];_api6Issue=@"admission_invalid";return nil;}
 NSDictionary*caps=admitted[@"granted"];[_api6Tiers release];_api6Tiers=[admitted[@"tiers"]copy];
 NSError*e=nil;OR6API7GDevice*device=[[[OR6API7GDevice alloc]init]autorelease];
 OR6API6AllComposition*c=[[OR6API6AllComposition alloc]initWithBase:_api7.registry extensions:x adapter:_reads roots:roots next:_api7.provider generation:(id<OR6API8Generation>)_web vault:vault inboxDirectory:inbox platform:device directory:[library stringByAppendingPathComponent:@"ChatGPTXAPI6-v1"]capabilities:caps transport:nil error:&e];
 if(!c){[_api6Issue release];_api6Issue=[(e.userInfo[@"code"]?:@"composition_failed")copy];}return c;
}
// Trusted host for the stage-6 screens: PIN secrets go straight to 6A, never through Core.
- (BOOL)chat6BindLockedSecrets:(NSDictionary*)secrets operationId:(NSString*)operationId error:(NSError**)error{
 OR6API6AProvider*a=(id)[_api6 providerForModule:@"6a"];if(!a){if(error)*error=OR6APIError(@"capability_unverified",@"none");return NO;}
 return[a bindPINSecrets:secrets operationId:operationId context:[self api6Context]error:error];
}
- (void)chat6ClearLockedAccess{[(OR6API6AProvider*)[_api6 providerForModule:@"6a"]clearLockedAccess];}
- (BOOL)chat6PolicyBound:(NSString*)policy {
 if(!NSThread.isMainThread||!_session.authenticated||!_api6)return NO;
 if([policy isEqual:@"autoContext"])return[(OR6API6CProvider*)[_api6 providerForModule:@"6c"]hasAutoContextPolicyForContext:[self api6Context]];
 NSDictionary*operations=@{@"webSearch":@"preferences.setAutoWebSearch",@"imageCreation":@"preferences.setImageCreation",@"location":@"privacy.locationControls.update",@"automaticMemoryManagement":@"memories.management.update"};NSString*op=operations[policy];
 if(!op||[[(OR6API6DProvider*)[_api6 providerForModule:@"6d"]diagnostics][@"activeCount"]unsignedIntegerValue])return NO;
 return[self chat6PrepareOperation:op error:NULL];
}
- (BOOL)chat6BindAccountAuthorizationForOperation:(NSString*)identifier command:(NSString*)command error:(NSError**)error {
 BOOL valid=NSThread.isMainThread&&OR6API6FUUID(identifier)&&[@[@"privacy.exportData",@"privacy.deleteAccount"]containsObject:command];
 // The native generator only prepares send purpose. Account export/deactivate
 // require their own real purpose-bound Sentinel authorization; never reuse send
 // material or claim a recent password check from an ordinary bearer restore.
 if(error)*error=OR6APIError(valid?@"login_required":@"invalid_request",@"none");return NO;
}
// Called only from an explicit user-confirmed settings action. Source booleans
// were observed privately by the actual authenticated networks; editable Core
// parameters can never grant policy. Providers still reread locks/revisions.
- (BOOL)chat6PrepareOperation:(NSString*)operation error:(NSError**)error {
 if(!NSThread.isMainThread||!_session.authenticated||!_api6){if(error)*error=OR6APIError(@"not_authenticated",@"none");return NO;}
 [self bindAPI6]; NSDictionary*ctx=[self api6Context];
 NSDictionary*keys=@{@"preferences.setAutoWebSearch":@"webSearch",@"preferences.setImageCreation":@"imageCreation",@"privacy.locationControls.update":@"location",@"memories.management.update":@"automaticMemoryManagement"};
 NSString*key=keys[operation]; if(key){
  OR6API6DNetwork*n=(id)[_api6 networkForModule:@"6d"];NSDictionary*policy=[n isKindOfClass:OR6API6DNetwork.class]?[n trustedPreferencesPolicyForContext:ctx]:nil;
  OR6API6DProvider*d=(id)[_api6 providerForModule:@"6d"];
  id<OR6API6DLocationCache>cache=[[[OR6Chat6EmptyLocationCache alloc]initWithContext:ctx]autorelease];
  if(![policy[key]isEqual:@YES]||![d bindPreferencesPolicy:policy context:ctx]||([operation isEqual:@"privacy.locationControls.update"]&&![d bindLocationCache:cache context:ctx])){if(error)*error=OR6APIError(@"capability_unverified",@"none");return NO;}
 }
 if([operation isEqual:@"library.autoContext.update"]){if(error)*error=OR6APIError(@"capability_unverified",@"none");return NO;} // asynchronous owner/structure proof below
 return YES;
}
- (id<OR6APITask>)chat6PrepareOperation:(NSString*)operation completion:(void(^)(NSError*))completion {
 NSError*error=nil;if(![operation isEqual:@"library.autoContext.update"]){[self chat6PrepareOperation:operation error:&error];if(completion)completion(error);return nil;}
 if(!NSThread.isMainThread||!_session.authenticated||!_api6){if(completion)completion(OR6APIError(@"not_authenticated",@"none"));return nil;}
 [self bindAPI6];NSDictionary*ctx=[self api6Context],*ident=[_session serviceAccount];OR6API6CNetwork*c=(id)[_api6 networkForModule:@"6c"];
 NSDictionary*policy=[c isKindOfClass:OR6API6CNetwork.class]?[c trustedAutoContextPolicyForContext:ctx]:nil;
 if(![policy[@"regionEligible"]isEqual:@YES]||!ident){if(completion)completion(OR6APIError(@"capability_unverified",@"none"));return nil;}
 NSURLRequest*request=OR6API6FRequest(@"account.raw",@{},&error);if(!request){if(completion)completion(error);return nil;}
 return[[_api6 networkForModule:@"6f"]request:request context:ctx completion:^(NSDictionary*r,NSError*e){
  if(e){if(completion)completion(e);return;}
  if(![[self api6Context]isEqual:ctx]||!_session.authenticated||![[_session serviceAccount]isEqual:ident]){if(completion)completion(OR6APIError(@"stale_context",@"none"));return;}
  NSDictionary*b=[r[@"accountBinding"]isKindOfClass:NSDictionary.class]?r[@"accountBinding"]:nil;
  // The current composition is personal-workspace only. An organization needs
  // its separately observed source permission; never infer it from absence.
  BOOL eligible=[b[@"id"]isEqual:ident[@"accountId"]]&&[b[@"personal"]isEqual:@YES];
  BOOL bound=[(OR6API6CProvider*)[_api6 providerForModule:@"6c"]bindAutoContextPolicy:@{@"eligible":@(eligible)}context:ctx];
  if(completion)completion(eligible&&bound?nil:OR6APIError(@"permission_denied",@"none"));
 }];
}
- (NSArray*)chat6TakeExportURLs:(NSString*)token {return[(OR6API6FProvider*)[_api6 providerForModule:@"6f"]takeExportURLs:token context:[self api6Context]];}
- (NSDictionary*)api6RuntimeDiagnostics {
 NSMutableDictionary*d=[NSMutableDictionary dictionaryWithObject:@([_session serviceAccount]!=nil)forKey:@"identityAvailable"];
 if(_api6)for(NSString*k in @[@"6a",@"6b",@"6c",@"6d",@"6e",@"6f"]){id p=[_api6 providerForModule:k];if([p respondsToSelector:@selector(diagnostics)]){NSDictionary*v=[p diagnostics];if([v isKindOfClass:NSDictionary.class])d[k]=v;}}
 return d; // provider diagnostics contain counts/flags only, no identity or credential values
}
- (NSDictionary*)summary{
 NSDictionary*d=_session.diagnostics;BOOL busy=[d[@"busy"]boolValue]||[_session.phase isEqual:@"signing_in"];NSString*state=busy?@"validating":_session.authenticated?@"authenticated":[_session.phase isEqual:@"signed_out"]?@"signed_out":[_session.phase isEqual:@"reauthentication_required"]?@"login_required":@"recovery_required";
 return @{@"state":state,@"authenticated":@(_session.authenticated),@"revision":d[@"revision"],@"renewable":@(_session.renewable),@"expiresAt":NSNull.null,@"cleanupPending":d[@"legacyCleanupPending"]};
}
- (BOOL)chatCodexAvailable{return _codex.available;}
- (UIViewController*)chatCodexController{[_codex updateIdentity];return _codex.available?OR6ChatCodexHome(_codex):nil;}
- (void)invalidateProviders{if(_active){[_voice8 deactivate];[NSNotificationCenter.defaultCenter postNotificationName:@"OR6Voice8OwnerChanged"object:self];}else[_voice8 pause];if(_active)[_rev67Local deactivate];else[_rev67Local suspend];[_rev67Content deactivate];[_rev67Account deactivate];[_rev67Personal deactivate];[_rev5Family deactivate];if(_active)[_rev5Local deactivate];else[_rev5Local suspend];if(_active)[_rev5Content deactivate];else[_rev5Content suspend];[_rev5System deactivate];[_rev5ASR deactivate];[_api5 deactivate];[_codex suspend];[_selected20 deactivate];[_root invalidateAPI7Context];[_api6 deactivate];[_api7 deactivate];[_priority9 deactivate];[_priority8 deactivate];[_media8 deactivate];[_web deactivate];}
- (void)requestSync{
 // Binding updates context only after the current auth completion has returned.
 // Queue UI work after that update so history/recovery sees the new generation.
 if(_session.authenticated&&_rev5Host&&![_rev5Host synchronizeAccountScope:NULL]){[self invalidateProviders];return;}
 [_binding8 apiSessionDidChange];if(_syncPending)return;_syncPending=YES;
 dispatch_async(dispatch_get_main_queue(),^{_syncPending=NO;[self sync];});
}
- (void)sync{[self bindAPI6];if(_active)[_codex updateIdentity];
 [_root applyAccountProfile:_session.profile];[_root applySessionSummary:[self summary]];if(_active&&_session.authenticated&&![_session.diagnostics[@"busy"]boolValue])[_web prepareConversation:nil];if(_pendingConversation&&_session.authenticated&&![_session.diagnostics[@"busy"]boolValue]){NSString*identifier=[[_pendingConversation copy]autorelease];[_pendingConversation release];_pendingConversation=nil;[_root openConversationIdentifier:identifier];_recoveryChecked=YES;}if(_active&&_session.authenticated&&![_session.diagnostics[@"busy"]boolValue]&&!_recoveryChecked){_recoveryChecked=YES;NSDictionary*s=[_web recoverySnapshotForConversation:nil];if(s)[_root restoreRecoverySnapshot:s];}[self schedule];[self writeReceipt];
 // Interaction status is a local SessionProvider read, never an account poll.
 // Apply after the session summary so cancelled/failed sign-in can offer retry.
 if(_interactionId)[_core perform:@"auth.status"parameters:@{@"interactionId":_interactionId}event:nil completion:^(NSDictionary*r,NSError*e){if(!e)[_root applySignInInteraction:r];}];
}
- (void)transportChanged:(NSNotification*)notification{(void)notification;[self writeReceipt];}
- (BOOL)openRouteURL:(NSURL*)url{return _root?[_root openRouteURL:url]:NO;}
- (BOOL)openConversationIdentifier:(NSString*)identifier{if(![identifier isKindOfClass:NSString.class]||identifier.length!=36||[[NSRegularExpression regularExpressionWithPattern:@"^[a-fA-F0-9]{8}(-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}$"options:0 error:NULL]numberOfMatchesInString:identifier options:0 range:NSMakeRange(0,identifier.length)]!=1)return NO;if(_session.authenticated&&![_session.diagnostics[@"busy"]boolValue])return[_root openConversationIdentifier:identifier];[_pendingConversation release];_pendingConversation=[identifier copy];return YES;}
- (void)runAuth:(NSString*)op{
 [_core perform:op parameters:@{}event:nil completion:^(NSDictionary*r,NSError*e){(void)r;if(e)[_root showSessionError:e];[self requestSync];}];
}
- (void)start{if(_started)return;_started=YES;[self observeReceipt];_restores++;[self runAuth:@"auth.restore"];}
- (void)chatPrepareConversation:(NSString*)identifier{if(_active&&_session.authenticated&&![_session.diagnostics[@"busy"]boolValue])[_web prepareConversation:identifier];}
- (void)chatRestore{if(_login)return;_restores++;[self runAuth:@"auth.restore"];}
- (void)chatRenew{if(_login)return;_renews++;[self runAuth:@"auth.renew"];}
- (void)chatSignOut{if(_login)return;[_pendingConversation release];_pendingConversation=nil;[_interactionId release];_interactionId=nil;[_web clearRecoveryForCurrentAccount];_recoveryChecked=YES;[self runAuth:@"auth.logout"];if(!_session.authenticated)[NSUserDefaults.standardUserDefaults removeObjectForKey:@"ChatGPTXUI9RecordingID"];}
- (NSDictionary*)chatRecoveryForConversation:(NSString*)identifier{return _session.authenticated&&![_session.diagnostics[@"busy"]boolValue]?[_web recoverySnapshotForConversation:identifier]:nil;}
- (void)chatSignIn{[self chatSignInWithProvider:@"google"];}
- (void)chatSignInWithProvider:(NSString*)provider{if(_login)return;if(![@[@"google",@"email"]containsObject:provider]||![OR6AuthEngine()[@"webPortAvailable"]boolValue]){[_root showSessionError:OR6APIError(@"capability_unavailable",@"none")];return;}[_core perform:@"auth.begin"parameters:@{@"provider":provider}event:nil completion:^(NSDictionary*r,NSError*e){[_interactionId release];_interactionId=[r[@"interactionId"]copy];if(e)[_root showSessionError:e];[self requestSync];}];}
- (id<OR6APITask>)presentProvider:(NSString*)provider generation:(NSUInteger)generation completion:(void(^)(NSString*))completion{
 if(![@[@"google",@"email"]containsObject:provider]||_login||_root.presentedViewController)return nil;
 [_loginCompletion release];_loginCompletion=[completion copy];_login=[[OR6WebLoginController alloc]initWithSession:_session generation:generation];_login.delegate=self;
 // The service page inside the kit's frame: jade bar with Cancel, the real host with a lock, load progress.
 RCWebFrameController*frame=[[[RCWebFrameController alloc]initWithContentView:_login.view title:OR6L(@"ChatGPT login")]autorelease];frame.delegate=self;frame.host=@"chatgpt.com";frame.secure=YES;[frame setProgress:.08 animated:NO];
 [frame addChildViewController:_login];[_login didMoveToParentViewController:frame];
 UINavigationController*nav=[[[UINavigationController alloc]initWithRootViewController:frame]autorelease];[RCTheme styleNavigationBar:nav.navigationBar variant:RCBarVariantJade];[_root presentViewController:nav animated:YES completion:nil];OR6ChatLoginTask*task=[[[OR6ChatLoginTask alloc]init]autorelease];task->owner=self;return task;
}
- (void)closeLogin:(NSString*)state{
 if(!_login||_closing)return;_closing=YES;OR6WebLoginController*old=[_login retain];_login.delegate=nil;[_login stop];[_login release];_login=nil;void(^completion)(NSString*)=[[_loginCompletion copy]autorelease];[_loginCompletion release];_loginCompletion=nil;
 [_root dismissViewControllerAnimated:NO completion:^{[old release];_closing=NO;[self requestSync];}];if(completion)completion(state);
}
- (void)webFrameDidCancel:(RCWebFrameController*)frame{(void)frame;[self loginControllerCancelled:_login];}
- (void)loginController:(OR6WebLoginController*)controller didNavigateToURL:(NSURL*)url loading:(BOOL)loading{
 if(controller!=_login)return;RCWebFrameController*frame=(id)controller.parentViewController;if(![frame isKindOfClass:RCWebFrameController.class])return;
 if(url.host.length){frame.host=url.host.lowercaseString;frame.secure=[url.scheme.lowercaseString isEqual:@"https"];}
 if(loading)[frame setProgress:MAX(.15,MIN(.85,frame.progress+.25))animated:YES];else[frame setProgress:1 animated:YES];
}
- (void)loginControllerCancelled:(OR6WebLoginController*)controller{if(controller!=_login)return;if(_interactionId){[_core perform:@"auth.cancel"parameters:@{@"interactionId":_interactionId}event:nil completion:^(NSDictionary*r,NSError*e){(void)r;if(e)[_root showSessionError:e];[self requestSync];}];}else{[_session cancelSignIn];[self closeLogin:@"cancelled"];}}
- (void)apiSessionDidChange{_changes++;[_login sessionChanged];if(_login&&_session.authenticated&&![_session.diagnostics[@"busy"]boolValue])[self closeLogin:@"complete"];[self requestSync];}
- (void)schedule{[_renewTimer invalidate];[_renewTimer release];_renewTimer=nil;NSTimeInterval seconds=[_session secondsUntilRenewal];if(_active&&!_login&&seconds>=0)_renewTimer=[[NSTimer scheduledTimerWithTimeInterval:MAX(1,seconds)target:self selector:@selector(renewTimer:)userInfo:nil repeats:NO]retain];}
- (void)renewTimer:(NSTimer*)timer{(void)timer;[_session activate];[self requestSync];}
- (void)activate{if(!_active)_recoveryChecked=NO;_active=YES;[self observeReceipt];if(_started)[_session activate];[self requestSync];}
// Resign active: a playing/paused read-aloud survives this teardown (UIBackgroundModes audio). The hold covers
// only this call; logout, session invalidation, conversation changes and dealloc still stop it.
- (void)deactivate{[_voice8 pause];_active=NO;[_receiptTimer invalidate];[_receiptTimer release];_receiptTimer=nil;[_renewTimer invalidate];[_renewTimer release];_renewTimer=nil;BOOL hold=_root!=nil;[(OR6API7GDevice*)_playbackDevice setHoldsPlayback:hold];OR6Chat20SetPlaybackHold(hold);[_root prepareForBackground];[self invalidateProviders];OR6Chat20SetPlaybackHold(NO);[(OR6API7GDevice*)_playbackDevice setHoldsPlayback:NO];[self writeReceipt];}
// UI6 auxiliary reads and form calls need not emit transport notifications.
// Sample only local diagnostics while foreground; no account polling. Write only
// changed snapshots, so an idle screen causes no repeated flash writes.
- (void)observeReceipt{if(!_active||!_started||_receiptTimer)return;_receiptTimer=[[NSTimer timerWithTimeInterval:1 target:self selector:@selector(receiptTick:)userInfo:nil repeats:YES]retain];[[NSRunLoop mainRunLoop]addTimer:_receiptTimer forMode:NSRunLoopCommonModes];}
- (void)receiptTick:(NSTimer*)timer{(void)timer;[self writeReceipt];}
- (void)writeReceipt{if(!_root)return;NSDictionary*r=@{@"schema":@1,@"bundleID":@"io.ozio.chatgptx",@"pid":@((int)getpid()),@"session":[self summary],@"sessionDiagnostics":_session.diagnostics,@"engine":OR6AuthEngine(),@"core":_core.diagnostics,@"priority9":_priority9.diagnostics,@"priority7":_api7?_api7.diagnostics:@{@"issue":_api7Issue?:@"absent"},@"priority6":_api6?_api6.diagnostics:@{@"issue":_api6Issue?:@"absent"},@"priority6Runtime":[self api6RuntimeDiagnostics],@"priority5":_api5.diagnostics?:@{},@"api5Host":_rev5Host.diagnostics?:@{},@"api5FamilyPolicy":_rev5Family.diagnostics?:@{},@"revisit5":@{@"asr":_rev5ASR.diagnostics?:@{},@"local":_rev5Local.diagnostics?:@{},@"content":_rev5Content.diagnostics?:@{},@"system":_rev5System.diagnostics?:@{}},@"selected20":_selected20.diagnostics?:@{},@"voiceRealtime":_voice8.diagnostics?:@{},@"revisit67":@{@"local":_rev67Local.diagnostics?:@{},@"content":_rev67Content.diagnostics?:@{},@"account":_rev67Account.diagnostics?:@{},@"personalPolicy":_rev67Personal.diagnostics?:@{}},@"codex":_codex.diagnostics?:@{},@"codexQR":OR6ChatCodexPairQRDiagnostics(),@"ui":_root.diagnostics,@"web":_web.diagnostics,@"restores":@(_restores),@"renews":@(_renews),@"changes":@(_changes),@"requiresMacBridge":@NO,@"credentialValuesExported":@NO};if([_receiptSnapshot isEqual:r])return;NSString*dir=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES)[0];NSData*encoded=[NSJSONSerialization dataWithJSONObject:r options:0 error:NULL];if(encoded&&[encoded writeToFile:[dir stringByAppendingPathComponent:@"ChatUIState.json"]atomically:YES]){[_receiptSnapshot release];_receiptSnapshot=[[NSJSONSerialization JSONObjectWithData:encoded options:0 error:NULL]retain];}}
- (void)dealloc{[_voice8 deactivate];_voice8.core=nil;[_voice8 release];_voice8=nil;[_rev5Observer setWorkspaceChanged:nil];[_rev5Observer setWorkspaceAllowed:nil];[_rev5Workspace setWorkspaceAllowed:nil];[_rev5Workspace setContextChanged:nil];[_rev5Device setPresenter:nil];[_rev67Content setMailPresenter:nil];[_rev67Local deactivate];OR6Chat6SetTrustedHost(nil);OR6Chat7SetExportResolver(nil);OR6Chat7SetImagePreviewResolver(nil);[NSNotificationCenter.defaultCenter removeObserver:self];if(_authHost)((OR6ChatAuthHost*)_authHost)->owner=nil;_auth.observer=nil;[_binding8 stop];[self deactivate];[_login stop];[_login release];[_loginCompletion release];[_interactionId release];[_binding8 release];[_root release];[_codex release];[_core release];[_selected20 release];[_rev5ASR release];[_rev5Local release];[_rev5Device release];[_rev5Content release];[_rev5System release];[_api5 release];[_api5Tiers release];[_api5Adapter release];[_rev5Observer release];[_rev5Workspace release];[_rev5Host release];[_rev5Family release];[_rev67Local release];[_rev67Content release];[_rev67Account release];[_rev67Personal release];[_playbackDevice release];[_api6 release];[_api6Issue release];[_api6Tiers release];[_api7 release];[_api7Issue release];[_priority9 release];[_priority8 release];[_media8 release];[_auth release];[_web release];[_reads release];[_session release];[_webHost removeFromSuperview];[_webHost release];[_authHost release];[_pendingConversation release];[_receiptSnapshot release];[super dealloc];}
@end
