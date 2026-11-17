#import "OR6API6AllComposition.h"
#import "../priority6a/OR6API6AProvider.h"
#import "../priority6a/OR6API6ANetwork.h"
#import "../priority6b/OR6API6BProvider.h"
#import "../priority6b/OR6API6BNetwork.h"
#import "../priority6c/OR6API6CProvider.h"
#import "../priority6c/OR6API6CNetwork.h"
#import "../priority6d/OR6API6DProvider.h"
#import "../priority6d/OR6API6DNetwork.h"
#import "../priority6e/OR6API6EProvider.h"
#import "../priority6e/OR6API6ENetwork.h"
#import "../priority6f/OR6API6FProvider.h"
#import "../priority6f/OR6API6FNetwork.h"
#import "../priority6a/OR6API6APolicy.h"
#import "../priority6b/OR6API6BPolicy.h"
#import "../priority6c/OR6API6CPolicy.h"
#import "../priority6d/OR6API6DPolicy.h"
#import "../priority6e/OR6API6EPolicy.h"
#import "../priority6f/OR6API6FPolicy.h"
#import <dispatch/dispatch.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>
static NSArray *Modules(void){return @[@"6a",@"6b",@"6c",@"6d",@"6e",@"6f"];}
static id AdmissionFailure(NSError **error){if(error)*error=OR6APIError(@"invalid_request",@"none");return nil;}
static BOOL AdmissionText(id value){return[value isKindOfClass:NSString.class]&&[value length]&&[value length]<=2048;}
NSDictionary *OR6API6AllAdmission(NSDictionary *manifest,NSDictionary *extensions,NSError **error){
 if(![manifest isKindOfClass:NSDictionary.class]||![manifest[@"schema"]isEqual:@1]||![manifest[@"operations"]isKindOfClass:NSDictionary.class]||![extensions isKindOfClass:NSDictionary.class]||extensions.count!=6)return AdmissionFailure(error);
 NSDictionary *entries=manifest[@"operations"];NSMutableDictionary *tiers=[NSMutableDictionary dictionary],*granted=[NSMutableDictionary dictionary];
 NSSet *known=[NSSet setWithArray:@[@"local",@"candidate_read",@"handoff",@"user_action",@"live_verified",@"denied"]];
 NSSet *readEffects=[NSSet setWithArray:@[@"locked.pin.verify",@"voice.preview.start",@"research.exportPDF"]];
 for(NSString *module in Modules()){
  id extension=extensions[module];if(![extension isKindOfClass:NSDictionary.class])return AdmissionFailure(error);
  id operations=extension[@"operations"];if(![operations isKindOfClass:NSArray.class])return AdmissionFailure(error);
  NSMutableSet *caps=[NSMutableSet set];
  for(id raw in operations){
   NSDictionary *op=[raw isKindOfClass:NSDictionary.class]?raw:nil;NSString *identifier=op[@"id"];
   if(!AdmissionText(identifier)||tiers[identifier])return AdmissionFailure(error);
   id entry=entries[identifier];if(![entry isKindOfClass:NSDictionary.class])return AdmissionFailure(error);
   NSString *tier=entry[@"tier"];if(![tier isKindOfClass:NSString.class]||![known containsObject:tier]||![entry[@"module"]isEqual:module])return AdmissionFailure(error);
   NSDictionary *wire=[op[@"wire"]isKindOfClass:NSDictionary.class]?op[@"wire"]:@{};
   BOOL mutation=OR6API6AMutation(identifier)||OR6API6BMutation(identifier)||OR6API6CMutation(identifier)||OR6API6DMutation(identifier)||OR6API6EMutation(identifier)||OR6API6FMutation(identifier);
   BOOL local=[wire[@"status"]isEqual:@"local"]||[wire[@"method"]isEqual:@"LOCAL"];
   BOOL remote=mutation&&!local&&![readEffects containsObject:identifier];
   if(([tier isEqual:@"local"]&&!local)||([tier isEqual:@"candidate_read"]&&remote)||([tier isEqual:@"handoff"]&&![wire[@"method"]isEqual:@"BROWSER_HANDOFF"]))return AdmissionFailure(error);
   if([tier isEqual:@"user_action"]&&(!remote||![entry[@"requiresUserAction"]isEqual:@YES]||![entry[@"requiresConfirmation"]isEqual:@YES]||![entry[@"source"]isEqual:[NSString stringWithFormat:@"support/priority%@/contracts.json",module]]))return AdmissionFailure(error);
   if([tier isEqual:@"live_verified"]){id evidence=entry[@"evidence"];if(![evidence isKindOfClass:NSDictionary.class]||!AdmissionText(evidence[@"date"])||!AdmissionText(evidence[@"reference"])||!AdmissionText(evidence[@"scope"]))return AdmissionFailure(error);}
   tiers[identifier]=tier;if(![tier isEqual:@"denied"])[caps addObject:identifier];
  }
  granted[module]=[[caps copy]autorelease];
 }
 if(tiers.count!=entries.count)return AdmissionFailure(error);
 return @{@"tiers":[[tiers copy]autorelease],@"granted":[[granted copy]autorelease]};
}
static BOOL PrivateDirectory(NSString *path){
 if(!path.isAbsolutePath)return NO;
 if(mkdir(path.fileSystemRepresentation,0700)&&errno!=EEXIST)return NO;
 struct stat st;return !lstat(path.fileSystemRepresentation,&st)&&S_ISDIR(st.st_mode)&&st.st_uid==geteuid()&&!(st.st_mode&0077);
}
@interface OR6API6AllComposition(){NSDictionary *_registry,*_providers,*_networks;}
@end
@implementation OR6API6AllComposition
@synthesize registry=_registry;
- (id<OR6APIProvider>)provider{return _providers[@"6f"];}
- (id<OR6APIProvider>)providerForModule:(NSString*)module{return[module isKindOfClass:NSString.class]?_providers[module]:nil;}
- (id<OR6API7HTTP>)networkForModule:(NSString*)module{return[module isKindOfClass:NSString.class]?_networks[module]:nil;}
- (id)initWithBase:(NSDictionary*)base extensions:(NSDictionary*)x adapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots next:(id<OR6APIProvider>)next generation:(id<OR6API8Generation>)generation vault:(OR6Files*)vault inboxDirectory:(NSString*)inbox platform:(id<OR6API7GPlatform>)platform directory:(NSString*)directory capabilities:(NSDictionary*)capabilities transport:(id<OR6API7HTTP>)transport error:(NSError**)error{
 if(!(self=[super init]))return nil;
 NSDictionary *registry=OR6API6AllRegistry(base,x,error);
 if(!registry||!next||!generation||!vault||!inbox.isAbsolutePath||(!transport&&(!adapter||!roots.length))||(capabilities&&![capabilities isKindOfClass:NSDictionary.class])||!PrivateDirectory(directory)){
  if(error&&!*error)*error=OR6APIError(@"invalid_request",@"none");[self release];return nil;
 }
 for(NSString *key in capabilities)if(![Modules()containsObject:key]||![capabilities[key]isKindOfClass:NSSet.class]){if(error)*error=OR6APIError(@"invalid_request",@"none");[self release];return nil;}
 NSMutableDictionary *dirs=[NSMutableDictionary dictionary],*caps=[NSMutableDictionary dictionary];
 for(NSString *key in Modules()){
  NSString *path=[directory stringByAppendingPathComponent:key];
  if(!PrivateDirectory(path)){if(error)*error=OR6APIError(@"storage_failure",@"none");[self release];return nil;}
  dirs[key]=path;caps[key]=capabilities[key]?:[NSSet set];
 }
 NSMutableDictionary *networks=[NSMutableDictionary dictionary];
 NSArray *classes=@[OR6API6ANetwork.class,OR6API6BNetwork.class,OR6API6CNetwork.class,OR6API6DNetwork.class,OR6API6ENetwork.class,OR6API6FNetwork.class];
 NSUInteger n=0; for (NSString *key in Modules()) { id network=transport?:[[[[classes objectAtIndex:n++] alloc]initWithAdapter:adapter roots:roots]autorelease]; if (!network) { if(error)*error=OR6APIError(@"invalid_request",@"none"); [self release]; return nil; } networks[key]=network; }
 _networks=[networks copy];
 OR6API6AProvider *a=[[[OR6API6AProvider alloc]initWithNext:next HTTP:_networks[@"6a"]extension:x[@"6a"]journalDirectory:dirs[@"6a"]capabilities:caps[@"6a"]error:error]autorelease];
 OR6API6BProvider *b=a?[[[OR6API6BProvider alloc]initWithNext:a HTTP:_networks[@"6b"]generation:generation extension:x[@"6b"]journalDirectory:dirs[@"6b"]capabilities:caps[@"6b"]error:error]autorelease]:nil;
 OR6API6CProvider *c=b?[[[OR6API6CProvider alloc]initWithNext:b HTTP:_networks[@"6c"]extension:x[@"6c"]journalDirectory:dirs[@"6c"]capabilities:caps[@"6c"]error:error]autorelease]:nil;
 OR6API6DProvider *d=c?[[[OR6API6DProvider alloc]initWithNext:c HTTP:_networks[@"6d"]extension:x[@"6d"]journalDirectory:dirs[@"6d"]capabilities:caps[@"6d"]error:error]autorelease]:nil;
 OR6API6EProvider *e=d?[[[OR6API6EProvider alloc]initWithNext:d HTTP:_networks[@"6e"]extension:x[@"6e"]journalDirectory:dirs[@"6e"]capabilities:caps[@"6e"]error:error]autorelease]:nil;
 OR6API6FProvider *f=e?[[[OR6API6FProvider alloc]initWithNext:e HTTP:_networks[@"6f"]generation:generation extension:x[@"6f"]journalDirectory:dirs[@"6f"]vault:vault inboxDirectory:inbox platform:platform capabilities:caps[@"6f"]error:error]autorelease]:nil;
 if(!f){[e deactivate];[d deactivate];[c deactivate];[b deactivate];[a deactivate];if(error&&!*error)*error=OR6APIError(@"invalid_request",@"none");[self release];return nil;}
 _providers=[@{@"6a":a,@"6b":b,@"6c":c,@"6d":d,@"6e":e,@"6f":f}copy];_registry=[registry copy];return self;
}
- (void)deactivate{
 // The queued work owns the providers, not this composition. This is also safe
 // when dealloc is reached on a worker while a leaf has an active callback.
 NSDictionary *providers=[[_providers copy]autorelease];
 void(^cancel)(void)=^{for(NSString *key in [Modules()reverseObjectEnumerator]){id p=providers[key];if([p respondsToSelector:@selector(deactivate)])[p deactivate];}};
 if(NSThread.isMainThread)cancel();else dispatch_async(dispatch_get_main_queue(),cancel);
}
- (NSDictionary*)diagnostics{return @{@"modules":@(_providers.count),@"operations":@([_registry[@"operations"]count]),@"automaticAdmission":@NO,@"automaticIdentityBinding":@NO};}
- (void)dealloc{[self deactivate];[_providers release];[_registry release];[_networks release];[super dealloc];}
@end
