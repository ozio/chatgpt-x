#import "OR6API5AllComposition.h"
#import "../priority5a/OR6API5AProvider.h"
#import "../priority5a/OR6API5ANetwork.h"
#import "../priority5b/OR6API5BProvider.h"
#import "../priority5b/OR6API5BNetwork.h"
#import "../priority5c/OR6API5CProvider.h"
#import "../priority5c/OR6API5CNetwork.h"
#import "../priority5d/OR6API5DProvider.h"
#import "../priority5d/OR6API5DNetwork.h"
#import "../priority5e/OR6API5EProvider.h"
#import "../priority5e/OR6API5ENetwork.h"
#import <dispatch/dispatch.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>
static NSArray *Modules(void){return @[@"5a",@"5b",@"5c",@"5d",@"5e"];}
static BOOL PrivateDirectory(NSString *path){
 if(!path.isAbsolutePath)return NO;
 if(mkdir(path.fileSystemRepresentation,0700)&&errno!=EEXIST)return NO;
 struct stat st;return !lstat(path.fileSystemRepresentation,&st)&&S_ISDIR(st.st_mode)&&st.st_uid==geteuid()&&!(st.st_mode&0077);
}
@interface OR6API5AllComposition(){NSDictionary *_registry,*_providers;}
@end
@implementation OR6API5AllComposition
@synthesize registry=_registry;
- (id<OR6APIProvider>)provider{return _providers[@"5e"];}
- (id<OR6APIProvider>)providerForModule:(NSString*)module{return[module isKindOfClass:NSString.class]?_providers[module]:nil;}
- (id)initWithBase:(NSDictionary*)base extensions:(NSDictionary*)x adapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots next:(id<OR6APIProvider>)next directory:(NSString*)directory capabilities:(NSDictionary*)capabilities transport:(id<OR6API7HTTP>)transport contentHosts:(NSSet*)contentHosts error:(NSError**)error{
 return[self initWithBase:base extensions:x adapter:adapter roots:roots next:next directory:directory capabilities:capabilities transport:transport contentHosts:contentHosts workspaceTransport:nil error:error];
}
- (id)initWithBase:(NSDictionary*)base extensions:(NSDictionary*)x adapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots next:(id<OR6APIProvider>)next directory:(NSString*)directory capabilities:(NSDictionary*)capabilities transport:(id<OR6API7HTTP>)transport contentHosts:(NSSet*)contentHosts workspaceTransport:(id<OR6API7HTTP>)workspaceTransport error:(NSError**)error{
 if(!(self=[super init]))return nil;
 NSDictionary *registry=OR6API5AllRegistry(base,x,error);
 if(!registry||!next||(!transport&&(!adapter||!roots.length))||(capabilities&&![capabilities isKindOfClass:NSDictionary.class])||(contentHosts&&![contentHosts isKindOfClass:NSSet.class])||!PrivateDirectory(directory)){
  if(error&&!*error)*error=OR6APIError(@"invalid_request",@"none");[self release];return nil;
 }
 for(NSString *key in capabilities)if(![Modules()containsObject:key]||![capabilities[key]isKindOfClass:NSSet.class]){if(error)*error=OR6APIError(@"invalid_request",@"none");[self release];return nil;}
 NSMutableDictionary *dirs=[NSMutableDictionary dictionary],*caps=[NSMutableDictionary dictionary];
 for(NSString *key in Modules()){
  NSString *path=[directory stringByAppendingPathComponent:key];
  if(!PrivateDirectory(path)){if(error)*error=OR6APIError(@"storage_failure",@"none");[self release];return nil;}
  dirs[key]=path;caps[key]=capabilities[key]?:[NSSet set];
 }
 OR6API5AProvider *a=[[[OR6API5AProvider alloc]initWithNext:next HTTP:(transport?:[[[OR6API5ANetwork alloc]initWithAdapter:adapter roots:roots]autorelease])extension:x[@"5a"]journalDirectory:dirs[@"5a"]capabilities:caps[@"5a"]error:error]autorelease];
 OR6API5BProvider *b=a?[[[OR6API5BProvider alloc]initWithNext:a HTTP:(transport?:[[[OR6API5BNetwork alloc]initWithAdapter:adapter roots:roots contentHosts:(contentHosts?:[NSSet set])]autorelease])extension:x[@"5b"]journalDirectory:dirs[@"5b"]capabilities:caps[@"5b"]error:error]autorelease]:nil;
 OR6API5CProvider *c=b?[[[OR6API5CProvider alloc]initWithNext:b HTTP:(transport?:[[[OR6API5CNetwork alloc]initWithAdapter:adapter roots:roots]autorelease])extension:x[@"5c"]journalDirectory:dirs[@"5c"]capabilities:caps[@"5c"]error:error]autorelease]:nil;
 OR6API5DProvider *d=c?[[[OR6API5DProvider alloc]initWithNext:c HTTP:(workspaceTransport?:transport?:[[[OR6API5DNetwork alloc]initWithAdapter:adapter roots:roots]autorelease])extension:x[@"5d"]journalDirectory:dirs[@"5d"]capabilities:caps[@"5d"]error:error]autorelease]:nil;
 OR6API5EProvider *e=d?[[[OR6API5EProvider alloc]initWithNext:d HTTP:(transport?:[[[OR6API5ENetwork alloc]initWithAdapter:adapter roots:roots]autorelease])extension:x[@"5e"]journalDirectory:dirs[@"5e"]capabilities:caps[@"5e"]error:error]autorelease]:nil;
 if(!e){[d deactivate];[c deactivate];[b deactivate];[a deactivate];if(error&&!*error)*error=OR6APIError(@"invalid_request",@"none");[self release];return nil;}
 _providers=[@{@"5a":a,@"5b":b,@"5c":c,@"5d":d,@"5e":e}copy];_registry=[registry copy];return self;
}
- (void)deactivate{
 NSDictionary *providers=[[_providers copy]autorelease];
 void(^cancel)(void)=^{for(NSString *key in [Modules()reverseObjectEnumerator]){id p=providers[key];if([p respondsToSelector:@selector(deactivate)])[p deactivate];}};
 if(NSThread.isMainThread)cancel();else dispatch_async(dispatch_get_main_queue(),cancel);
}
- (NSDictionary*)diagnostics{return @{@"modules":@(_providers.count),@"operations":@([_registry[@"operations"]count]),@"automaticAdmission":@NO,@"automaticIdentityBinding":@NO};}
- (void)dealloc{[self deactivate];[_providers release];[_registry release];[super dealloc];}
@end
