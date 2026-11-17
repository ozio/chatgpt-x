#import "OR6API7AllComposition.h"
#import "../OR6APIWebAdapter.h"
#import "../priority7/OR6API7Policy.h"
#import "../priority7/OR6API7Provider.h"
#import "../priority7b/OR6API7BProvider.h"
#import "../priority7c/OR6API7CProvider.h"
#import "../priority7d/OR6API7DPolicy.h"
#import "../priority7d/OR6API7DProvider.h"
#import "../priority7e/OR6API7EPolicy.h"
#import "../priority7e/OR6API7EProvider.h"
#import "../priority7f/OR6API7FPolicy.h"
#import "../priority7f/OR6API7FProvider.h"
#import "../priority7f/OR6API7FNetwork.h"
#import "../priority7b/OR6API7BPolicy.h"
#import "../priority7c/OR6API7CNetwork.h"
#import "../priority7d/OR6API7DNetwork.h"
#import "../priority7e/OR6API7ENetwork.h"
#import "../priority7h/OR6API7HStreaming.h"
#import "../priority8/OR6API8Provider.h"
#include <sys/stat.h>
#include <errno.h>
#include <unistd.h>

NSString*const OR6API7TierLocal=@"local",*const OR6API7TierRead=@"candidate_read",*const OR6API7TierHandoff=@"handoff",*const OR6API7TierVerified=@"live_verified",*const OR6API7TierDenied=@"denied",*const OR6API7TierUserAction=@"user_action";
static NSArray*Modules(void){return @[@"7",@"7b",@"7c",@"7d",@"7e",@"7f",@"7g"];}
static NSSet*Handoffs(void){return[NSSet setWithArray:@[@"security.reauthenticate",@"security.passwordChange",@"security.emailChange",@"security.mfaSetup",@"security.recovery",@"privacy.openCenter",@"privacy.requestsHelp",@"safety.ageVerify",@"subscription.openPlans"]];}
BOOL OR6API7AllWrite(NSString*op){
 if(![op isKindOfClass:NSString.class])return NO;
 return OR6API7Mutation(op)||OR6API7BMutation(op)||OR6API7DMutation(op)||OR6API7EMutation(op)||OR6API7FMutation(op)||[@[@"library.attach",@"library.detach",@"projects.newDraft",@"dictation.streaming"]containsObject:op];
}
static NSDictionary*Fail(NSError**error){if(error)*error=OR6APIError(@"invalid_request",@"none");return nil;}
static BOOL Evidence(id e){
 if(![e isKindOfClass:NSDictionary.class]||[e count]!=3)return NO;
 for(NSString*k in @[@"date",@"reference",@"scope"])if(![e[k]isKindOfClass:NSString.class]||![e[k]length]||[e[k]length]>512)return NO;
 return YES;
}
// Source-backed explicit user actions. Per-provider fresh revision/catalog,
// owner/project, ready-file and durable operation guards still decide each call.
// No entry here proves live acceptance. Memory/text-training writes require the
// fresh personal-policy preflight; file-add requires fresh upload binding.
static NSSet*UserActions(void){return[NSSet setWithArray:@[@"chat.continue",@"compose.clarifications.respond",@"tools.actionApproval.respond",@"tools.deepResearch",@"tools.deepResearch.cancel",@"projects.newDraft",@"projects.send",@"instructions.update",@"profile.update",@"personality.update",@"traits.update",@"library.attach",@"library.detach",@"projects.moveConversation",@"projects.memoryUpdate",@"projects.filesRemove",@"projects.filesAdd",@"safety.sensitiveContent.set",@"tools.dataAnalysis",@"memory.setEnabled",@"memory.setHistory",@"privacy.training.setText"]];}
static NSString*Tier(id entry,NSString*op,BOOL local,NSError**error){
 if(![entry isKindOfClass:NSDictionary.class])return nil;NSString*t=entry[@"tier"];
 NSSet*keys=[NSSet setWithArray:[entry allKeys]],*allowed=[NSSet setWithArray:@[@"module",@"tier",@"reason",@"evidence",@"source",@"requiresUserAction",@"requiresConfirmation"]];if(![keys isSubsetOfSet:allowed])return nil;
 if([t isEqual:OR6API7TierLocal])return local?t:nil;
 if(local)return nil; // a local operation never becomes a service capability
 if([t isEqual:OR6API7TierDenied])return t;
 if([t isEqual:OR6API7TierVerified])return Evidence(entry[@"evidence"])?t:nil;
 if([t isEqual:OR6API7TierUserAction]){NSString*module=entry[@"module"];return[UserActions()containsObject:op]&&OR6API7AllWrite(op)&&[entry[@"requiresUserAction"]isEqual:@YES]&&[entry[@"requiresConfirmation"]isEqual:@YES]&&[entry[@"source"]isEqual:[NSString stringWithFormat:@"support/priority%@/contracts.json",module]]?t:nil;}
 if(OR6API7AllWrite(op))return nil; // remaining writes require live evidence
 if([t isEqual:OR6API7TierHandoff])return[Handoffs()containsObject:op]?t:nil;
 if([t isEqual:OR6API7TierRead])return[Handoffs()containsObject:op]?nil:t;
 (void)error;return nil;
}
NSDictionary*OR6API7AllAdmission(NSDictionary*m,NSDictionary*x,NSError**error){
 if(![m isKindOfClass:NSDictionary.class]||![m[@"schema"]isEqual:@1]||![m[@"operations"]isKindOfClass:NSDictionary.class]||![m[@"streaming"]isKindOfClass:NSDictionary.class]||![x isKindOfClass:NSDictionary.class])return Fail(error);
 NSMutableDictionary*tiers=[NSMutableDictionary dictionary],*granted=[NSMutableDictionary dictionary];NSMutableSet*all=[NSMutableSet set];
 for(NSString*k in Modules()){
  NSArray*ops=[x[k]isKindOfClass:NSDictionary.class]?x[k][@"operations"]:nil;if(![ops isKindOfClass:NSArray.class])return Fail(error);
  NSMutableSet*caps=[NSMutableSet set];
  for(NSDictionary*o in ops){NSString*op=[o isKindOfClass:NSDictionary.class]?o[@"id"]:nil;if(![op isKindOfClass:NSString.class]||[all containsObject:op])return Fail(error);[all addObject:op];
   BOOL local=[k isEqual:@"7g"]||[op isEqual:@"content.copyCode"];id entry=m[@"operations"][op];
   if(entry&&![entry[@"module"]?:k isEqual:k])return Fail(error);
   NSString*t=Tier(entry,op,local,error);if(!t)return Fail(error);tiers[op]=t;
   if([t isEqual:OR6API7TierRead]||[t isEqual:OR6API7TierHandoff]||[t isEqual:OR6API7TierVerified]||[t isEqual:OR6API7TierUserAction])[caps addObject:op];}
  granted[k]=caps;
 }
 if(![[NSSet setWithArray:[m[@"operations"]allKeys]]isEqualToSet:all])return Fail(error); // exactly the registered inventory
 if([m[@"streaming"]count]!=1)return Fail(error);NSString*s=Tier(m[@"streaming"][@"dictation.streaming"],@"dictation.streaming",NO,error);if(!s)return Fail(error);
 tiers[@"dictation.streaming"]=s;
 return @{@"operations":tiers,@"granted":granted,@"streaming":@([s isEqual:OR6API7TierVerified])};
}
static BOOL PrivateDirectory(NSString*path){
 if(mkdir(path.fileSystemRepresentation,0700)&&errno!=EEXIST)return NO;struct stat st;
 return !lstat(path.fileSystemRepresentation,&st)&&S_ISDIR(st.st_mode)&&st.st_uid==geteuid()&&!(st.st_mode&0077);
}

// Top of the chain: keeps the streaming adapter bound to the exact Core context
// and deactivates every API7 layer on logout before the session provider sees it.
// The outer personal-policy wrapper is the only production B/E policy issuer.
@interface OR6API7AllObserver:NSObject<OR6APIProvider>{@public id<OR6APIProvider>_next;OR6API7HStreaming*_streaming;NSDictionary*_context;OR6API7AllComposition*_owner;/* weak: the composition owns the observer */NSUInteger _rebinds;}
@end
@interface OR6API7AllComposition(){NSDictionary*_registry,*_tiers;OR6API7AllObserver*_observer;OR6API7Provider*_seven;OR6API7BProvider*_b;OR6API7CProvider*_c;OR6API7DProvider*_d;OR6API7EProvider*_e;OR6API7FProvider*_f;OR6API7GProvider*_g;OR6API7HStreaming*_h;NSUInteger _deactivations;NSString*_preferencesPath;BOOL _memoryPolicyBound,_trainingPolicyBound;}
@end
@implementation OR6API7AllObserver
- (id<OR6APITask>)execute:(NSString*)op parameters:(NSDictionary*)p context:(NSDictionary*)ctx event:(OR6APIEvent)event completion:(OR6APIReply)reply{
 if(![_context isEqual:ctx]){[_context release];_context=[ctx copy];_rebinds++;[_streaming bindContext:ctx];}
 if([op isEqual:@"auth.logout"])[_owner deactivate];
 return[_next execute:op parameters:p context:ctx event:event completion:reply];
}
- (void)didValidate:(NSString*)op result:(NSDictionary*)r context:(NSDictionary*)ctx{if([_next respondsToSelector:_cmd])[_next didValidate:op result:r context:ctx];}
- (void)releaseCompletedDraft:(NSString*)d context:(NSDictionary*)ctx{if([_next respondsToSelector:_cmd])[_next releaseCompletedDraft:d context:ctx];}
- (void)dealloc{[_next release];[_streaming release];[_context release];[super dealloc];}
@end

@implementation OR6API7AllComposition
@synthesize registry=_registry,tiers=_tiers,preferencesPath=_preferencesPath;
- (id<OR6APIProvider>)provider{return _observer;}
- (id)initWithBase:(NSDictionary*)base extensions:(NSDictionary*)x admission:(NSDictionary*)manifest adapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots next:(id<OR6APIProvider>)next media:(OR6API8Media*)media generation:(id<OR6API8Generation>)generation vault:(OR6Files*)vault directory:(NSString*)directory platform:(id<OR6API7GPlatform>)platform capture:(id<OR6API7HPCM>)capture error:(NSError**)error{
 return[self initWithBase:base extensions:x admission:manifest adapter:adapter roots:roots next:next media:media generation:generation vault:vault directory:directory platform:platform capture:capture transport:nil error:error];
}
- (id)initWithBase:(NSDictionary*)base extensions:(NSDictionary*)x admission:(NSDictionary*)manifest adapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots next:(id<OR6APIProvider>)next media:(OR6API8Media*)media generation:(id<OR6API8Generation>)generation vault:(OR6Files*)vault directory:(NSString*)directory platform:(id<OR6API7GPlatform>)platform capture:(id<OR6API7HPCM>)capture transport:(id<OR6API7HTTP>)transport error:(NSError**)error{
 if(!(self=[super init]))return nil;
 NSDictionary*admission=OR6API7AllAdmission(manifest,x,error);
 NSDictionary*registry=admission?OR6API7AllRegistry(base,x,error):nil;
 BOOL dirs=directory.isAbsolutePath&&PrivateDirectory(directory);NSString*(^dir)(NSString*)=^NSString*(NSString*n){NSString*p=[directory stringByAppendingPathComponent:n];return PrivateDirectory(p)?p:nil;};
 NSString*j7=dirs?dir(@"Mutations-7"):nil,*jb=dirs?dir(@"Mutations-7B"):nil,*jd=dirs?dir(@"Mutations-7D"):nil,*je=dirs?dir(@"Mutations-7E"):nil,*jf=dirs?dir(@"Mutations-7F"):nil,*jg=dirs?dir(@"Interaction-7G"):nil;
 if(!registry||!adapter||!roots||!next||!media||!generation||!vault||!j7||!jb||!jd||!je||!jf||!jg){if(error&&!*error)*error=OR6APIError(@"invalid_request",@"none");[self release];return nil;}
 NSDictionary*g=admission[@"granted"];
 _seven=[[OR6API7Provider alloc]initWithNext:next HTTP:(transport?:(id<OR6API7HTTP>)[[[OR6API7Network alloc]initWithAdapter:adapter roots:roots]autorelease])extension:x[@"7"]journalDirectory:j7 capabilities:g[@"7"]error:error];
 _b=_seven?[[OR6API7BProvider alloc]initWithNext:_seven HTTP:(transport?:(id<OR6API7HTTP>)[[[OR6API7BNetwork alloc]initWithAdapter:adapter roots:roots]autorelease])extension:x[@"7b"]journalDirectory:jb capabilities:g[@"7b"]error:error]:nil;
 // Library resolver on the exact Media instance API8 sends with.
 _c=_b?[[OR6API7CProvider alloc]initWithNext:_b HTTP:(transport?:(id<OR6API7HTTP>)[[[OR6API7CNetwork alloc]initWithAdapter:adapter roots:roots]autorelease])media:media extension:x[@"7c"]capabilities:g[@"7c"]clock:nil error:error]:nil;
 _f=_c?[[OR6API7FProvider alloc]initWithNext:_c HTTP:(transport?:(id<OR6API7HTTP>)[[[OR6API7FNetwork alloc]initWithAdapter:adapter roots:roots]autorelease])generation:generation extension:x[@"7f"]journalDirectory:jf capabilities:g[@"7f"]error:error]:nil;
 _d=_f?[[OR6API7DProvider alloc]initWithNext:_f HTTP:(transport?:(id<OR6API7HTTP>)[[[OR6API7DNetwork alloc]initWithAdapter:adapter roots:roots]autorelease])extension:x[@"7d"]journalDirectory:jd capabilities:g[@"7d"]error:error]:nil;
 if(_d&&![_d bindGeneration:generation]){[_d release];_d=nil;}
 _e=_d?[[OR6API7EProvider alloc]initWithNext:_d HTTP:(transport?:(id<OR6API7HTTP>)[[[OR6API7ENetwork alloc]initWithAdapter:adapter roots:roots]autorelease])extension:x[@"7e"]journalDirectory:je capabilities:g[@"7e"]error:error]:nil;
 // Streaming dictation: closed unless dictation.streaming is live_verified; the adapter
 // also requires bindContext: before any microphone or network use.
 _h=_e?[[OR6API7HStreaming alloc]initWithAdapter:adapter roots:roots capture:capture capabilities:[admission[@"streaming"]boolValue]?[NSSet setWithObject:@"dictation.streaming"]:[NSSet set]error:error]:nil;
 _g=_h?[[OR6API7GProvider alloc]initWithNext:_e extension:x[@"7g"]directory:jg vault:vault platform:platform streaming:_h error:error]:nil;
 if(!_g){if(error&&!*error)*error=OR6APIError(@"invalid_request",@"none");[self release];return nil;}
 _observer=[[OR6API7AllObserver alloc]init];_observer->_next=[_g retain];_observer->_streaming=[_h retain];_observer->_owner=self;
 _registry=[registry copy];_tiers=[admission[@"operations"]copy];_preferencesPath=[[jg stringByAppendingPathComponent:@"preferences.json"]copy];
 return self;
}
- (NSArray*)exportURLsForToken:(NSString*)token{return _observer->_context?[_g takeExportURLs:token context:_observer->_context]:nil;}
- (NSData*)imagePreviewDataForAsset:(NSString*)assetId{return _observer->_context?[_g imagePreviewDataForAsset:assetId context:_observer->_context]:nil;}
- (BOOL)bindMemoryPolicy:(NSDictionary*)policy context:(NSDictionary*)context{BOOL ok=[_b bindMemoryPolicy:policy context:context];if(ok)_memoryPolicyBound=[policy[@"eligible"]isEqual:@YES];return ok;}
- (BOOL)bindPrivacyPolicy:(NSDictionary*)policy context:(NSDictionary*)context{BOOL ok=[_e bindPrivacyPolicy:policy context:context];if(ok)_trainingPolicyBound=[policy[@"trainingPermitted"]isEqual:@YES];return ok;}
- (BOOL)bindProjectUploadedFiles:(NSArray*)files context:(NSDictionary*)context{return[_d bindUploadedFiles:files context:context];}
- (BOOL)bindProjectIdentity:(NSDictionary*)identity context:(NSDictionary*)context{return[_d bindIdentity:identity context:context];}
- (void)deactivate{_deactivations++;_memoryPolicyBound=NO;_trainingPolicyBound=NO;[_g deactivate];[_e deactivate];[_d deactivate];[_f deactivate];[_c deactivate];[_b deactivate];[_seven deactivate];[_h cancel];}
- (NSDictionary*)diagnostics{
 NSUInteger granted=0;for(NSString*t in _tiers.allValues)if(![t isEqual:OR6API7TierDenied])granted++;
 return @{@"operations":@(_tiers.count),@"granted":@(granted),@"verified":@([[_tiers allKeysForObject:OR6API7TierVerified]count]),@"denied":@([[_tiers allKeysForObject:OR6API7TierDenied]count]),@"streaming":_tiers[@"dictation.streaming"]?:@"",@"deactivations":@(_deactivations),@"contextRebinds":@(_observer?_observer->_rebinds:0),
  @"memoryPolicyBound":@(_memoryPolicyBound),@"trainingPolicyBound":@(_trainingPolicyBound),@"projectIdentityBound":[_d diagnostics][@"identityBound"]?:@NO,@"g":_g.diagnostics?:@{},@"f":_f.diagnostics?:@{}};
}
- (void)dealloc{if(_observer)_observer->_owner=nil;[self deactivate];[_observer release];[_g release];[_h release];[_e release];[_d release];[_f release];[_c release];[_b release];[_seven release];[_registry release];[_tiers release];[_preferencesPath release];[super dealloc];}
@end
