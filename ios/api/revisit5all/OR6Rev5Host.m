#import "OR6Rev5Host.h"
#import <dispatch/dispatch.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
static BOOL Text(id s,NSUInteger max){return[s isKindOfClass:NSString.class]&&[s length]&&[s length]<=max&&[s rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location==NSNotFound;}
static NSDictionary *D(id v){return[v isKindOfClass:NSDictionary.class]?v:nil;}
// Validate descriptor type/owner/permissions/size BEFORE bounded reads. A FIFO,
// dangling symlink, unreadable file or growing file cannot block or allocate unboundedly.
static NSData *ReadMap(NSString *path){int fd=open(path.fileSystemRepresentation,O_RDONLY|O_NOFOLLOW|O_NONBLOCK);if(fd<0)return nil;struct stat st;BOOL ok=!fstat(fd,&st)&&S_ISREG(st.st_mode)&&st.st_uid==geteuid()&&!(st.st_mode&0077)&&st.st_size>0&&st.st_size<=65536;NSMutableData*out=ok?[NSMutableData data]:nil;unsigned char buffer[4096];while(ok){ssize_t n=read(fd,buffer,sizeof(buffer));if(n<0&&errno==EINTR)continue;if(n<0){ok=NO;break;}if(!n)break;if(out.length+(NSUInteger)n>65536){ok=NO;break;}[out appendBytes:buffer length:(NSUInteger)n];}close(fd);return ok?out:nil;}
// The initial legacy owner/account witness MUST be crash-durable before an
// exchange may persist a different native token. Atomic rename alone is insufficient.
static BOOL WriteMap(NSData *bytes,NSString *path){if(!bytes.length||bytes.length>65536)return NO;NSString*temp=[[path stringByDeletingLastPathComponent]stringByAppendingPathComponent:[@".legacy-"stringByAppendingString:NSProcessInfo.processInfo.globallyUniqueString]];int fd=open(temp.fileSystemRepresentation,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600);if(fd<0)return NO;BOOL ok=YES;NSUInteger offset=0;while(offset<bytes.length){ssize_t n=write(fd,(const unsigned char*)bytes.bytes+offset,bytes.length-offset);if(n<0&&errno==EINTR)continue;if(n<=0){ok=NO;break;}offset+=(NSUInteger)n;}if(ok)ok=fsync(fd)==0;if(close(fd))ok=NO;if(ok)ok=rename(temp.fileSystemRepresentation,path.fileSystemRepresentation)==0;if(ok){int dir=open(path.stringByDeletingLastPathComponent.fileSystemRepresentation,O_RDONLY|O_NOFOLLOW);struct stat st;ok=dir>=0&&!fstat(dir,&st)&&S_ISDIR(st.st_mode)&&st.st_uid==geteuid()&&!(st.st_mode&0077)&&fsync(dir)==0;if(dir>=0&&close(dir))ok=NO;}if(!ok)unlink(temp.fileSystemRepresentation);return ok;}
@interface OR6WebSession(OR6Rev5ExistingClaims)
+ (NSDictionary*)tokenPayload:(NSString*)token;
@end
@interface OR6WebSession(OR6Rev5PrivateClaims)
- (NSString*)rev5MessagingIdentity;
@end
@implementation OR6WebSession(OR6Rev5PrivateClaims)
- (NSString*)rev5MessagingIdentity{
 if(!NSThread.isMainThread||!self.authenticated||![self serviceAccount])return nil;
 NSDictionary *auth=D([self.class tokenPayload:_record[@"accessToken"]][@"https://api.openai.com/auth"]);
 id value=auth[@"chatgpt_account_user_id"]?:auth[@"account_user_id"];
 return Text(value,128)?[[value copy]autorelease]:nil;
}
@end
@interface OR6APIWebAdapter(OR6Rev5PrivateScope)
- (BOOL)rev5AdoptAccount:(NSString*)account legacy:(BOOL)legacy identity:(NSDictionary*)identity;
@end
@implementation OR6APIWebAdapter(OR6Rev5PrivateScope)
- (BOOL)rev5AdoptAccount:(NSString*)account legacy:(BOOL)legacy identity:(NSDictionary*)identity{
 if(!NSThread.isMainThread||!Text(account,128)||![[_session serviceAccount]isEqual:identity]||![identity[@"accountId"]isEqual:account]||![self chatMatchesOwner:identity[@"userId"]])return NO;
 NSString *desired=legacy?nil:account;if((_workspace==desired)||[_workspace isEqual:desired])return YES;
 [_workspace release];_workspace=[desired copy];return YES;
}
@end
@interface OR6Rev5Host(){OR6APIWebAdapter *_adapter;OR6WebSession *_session;NSString *_path;NSMutableDictionary *_legacy;NSDictionary *_synchronizedIdentity;NSString *_scopeKey;BOOL _transitioning,_poisoned;}
@end
@implementation OR6Rev5Host
- (id)initWithAdapter:(OR6APIWebAdapter*)adapter session:(OR6WebSession*)session directory:(NSString*)directory error:(NSError**)error{
 if(!(self=[super init]))return nil;
 struct stat st;BOOL ok=directory.isAbsolutePath&&(!mkdir(directory.fileSystemRepresentation,0700)||errno==EEXIST)&&!lstat(directory.fileSystemRepresentation,&st)&&S_ISDIR(st.st_mode)&&st.st_uid==geteuid()&&!(st.st_mode&0077);
 if(!adapter||!session||!ok){if(error)*error=OR6APIError(@"storage_failure",@"none");[self release];return nil;}
 _adapter=[adapter retain];_session=[session retain];_path=[[directory stringByAppendingPathComponent:@"legacy-accounts.json"]copy];_legacy=[NSMutableDictionary new];
 struct stat file;int exists=lstat(_path.fileSystemRepresentation,&file);if(!exists){NSData *bytes=ReadMap(_path);NSDictionary *raw=bytes?D([NSJSONSerialization JSONObjectWithData:bytes options:0 error:NULL]):nil,*items=D(raw[@"accounts"]);ok=raw.count==2&&[raw[@"schema"]isEqual:@1]&&items&&items.count>=1&&items.count<=128;for(id user in items)if(!Text(user,256)||!Text(items[user],128))ok=NO;if(!ok){if(error)*error=OR6APIError(@"storage_failure",@"none");[self release];return nil;}[_legacy addEntriesFromDictionary:items];}else if(errno!=ENOENT){if(error)*error=OR6APIError(@"storage_failure",@"none");[self release];return nil;}
 return self;
}
- (NSDictionary*)identity{return OR6APIJSONSnapshot([_session serviceAccount],4096);}
- (BOOL)synchronizeAccountScope:(NSError**)error{
 if(error)*error=nil;if(!NSThread.isMainThread){if(error)*error=OR6APIError(@"invalid_request",@"none");return NO;}NSDictionary *i=self.identity;if(_poisoned){if(error)*error=OR6APIError(@"storage_failure",@"none");return NO;}if(_transitioning||!i||![_adapter chatMatchesOwner:i[@"userId"]]){if(error)*error=OR6APIError(@"not_authenticated",@"none");return NO;}
 NSString *legacy=_legacy[i[@"userId"]];if(!legacy&&!_legacy.count){if(_legacy.count>=128){if(error)*error=OR6APIError(@"storage_failure",@"none");return NO;}NSMutableDictionary *next=[[_legacy mutableCopy]autorelease];next[i[@"userId"]]=i[@"accountId"];NSData *bytes=[NSJSONSerialization dataWithJSONObject:@{@"schema":@1,@"accounts":next}options:0 error:NULL];[_legacy setDictionary:next];_transitioning=YES;BOOL written=WriteMap(bytes,_path);_transitioning=NO;if(!written){_poisoned=YES;if(error)*error=OR6APIError(@"storage_failure",@"none");return NO;}legacy=_legacy[i[@"userId"]];}
 if(![_adapter rev5AdoptAccount:i[@"accountId"]legacy:[legacy isEqual:i[@"accountId"]]identity:i]){if(error)*error=OR6APIError(@"stale_context",@"none");return NO;}[_synchronizedIdentity release];_synchronizedIdentity=[i copy];[_scopeKey release];_scopeKey=[_adapter.contextKey copy];return YES;
}
- (NSDictionary*)liveContext{NSDictionary*i=self.identity;NSString*k=_adapter.contextKey;BOOL valid=i?(!_poisoned&&[i isEqual:_synchronizedIdentity]&&[k isEqual:_scopeKey]):(k==nil);return@{@"key":k?:@"anonymous",@"accountId":i[@"accountId"]?:NSNull.null,@"userId":i[@"userId"]?:NSNull.null,@"valid":@(valid)};}
- (NSString*)messagingIdentity{return[_session rev5MessagingIdentity];}
- (NSDictionary*)diagnostics{return@{@"legacyOwners":@(_legacy.count),@"recoveryRequired":@(_poisoned),@"credentialsExposed":@NO};}
- (void)dealloc{[_adapter release];[_session release];[_path release];[_legacy release];[_synchronizedIdentity release];[_scopeKey release];[super dealloc];}
@end
@interface OR6Rev5AccountAdapter(){OR6APIWebAdapter *_base;}
@end
@implementation OR6Rev5AccountAdapter
- (id)initWithBase:(OR6APIWebAdapter*)base session:(OR6WebSession*)session roots:(NSString*)roots{if((self=[super initWithSession:session roots:roots workspace:nil permittedReads:[NSSet set]])){if(!base){[self release];return nil;}_base=[base retain];}return self;}
- (NSString*)contextKey{return _base.contextKey;}
- (NSUInteger)credentialGeneration{return _base.credentialGeneration;}
- (BOOL)chatMatchesOwner:(NSString*)owner{return[_base chatMatchesOwner:owner];}
- (NSURLRequest*)authorizeChatRequest:(NSURLRequest*)request expectedKey:(NSString*)key{
 NSDictionary *i=[_session serviceAccount];NSString *given=[request valueForHTTPHeaderField:@"ChatGPT-Account-ID"];
 if(!NSThread.isMainThread||!i||![_base chatMatchesOwner:i[@"userId"]]||![key isEqual:_base.contextKey]||(given&&![given isEqual:i[@"accountId"]]))return nil;
 NSMutableURLRequest *r=[[request mutableCopy]autorelease];[r setValue:i[@"accountId"]forHTTPHeaderField:@"ChatGPT-Account-ID"];NSURLRequest *authorized=[_base authorizeChatRequest:r expectedKey:key];return[[authorized valueForHTTPHeaderField:@"ChatGPT-Account-ID"]isEqual:i[@"accountId"]]?authorized:nil;
}
- (BOOL)acceptChatCookies:(NSArray*)headers expectedKey:(NSString*)key generation:(NSUInteger)generation{return[_base acceptChatCookies:headers expectedKey:key generation:generation];}
- (NSTimeInterval)recentChatOwnerValidationAgeForKey:(NSString*)key generation:(NSUInteger)generation{return[_base recentChatOwnerValidationAgeForKey:key generation:generation];}
- (BOOL)recordChatOwnerValidation:(NSString*)owner expectedKey:(NSString*)key generation:(NSUInteger)generation{return[_base recordChatOwnerValidation:owner expectedKey:key generation:generation];}
- (void)dealloc{[_base release];[super dealloc];}
@end
@interface OR6Rev5WorkspaceNetwork(){OR6Rev5Host *_host;BOOL(^_allowed)(void);void(^_changed)(void);}
@end
@implementation OR6Rev5WorkspaceNetwork
- (id)initWithAdapter:(OR6APIWebAdapter*)adapter roots:(NSString*)roots host:(OR6Rev5Host*)host{if((self=[super initWithAdapter:adapter roots:roots])){if(!host){[self release];return nil;}_host=[host retain];}return self;}
- (void)setContextChanged:(void(^)(void))changed{[_changed release];_changed=[changed copy];}
- (BOOL)canCommitWorkspace:(NSDictionary*)workspace context:(NSDictionary*)ctx{(void)workspace;NSDictionary*live=_host.liveContext;return _allowed&&_allowed()&&[live[@"valid"]isEqual:@YES]&&[live[@"key"]isEqual:ctx[@"key"]]&&[live[@"accountId"]isEqual:ctx[@"accountId"]]&&[live[@"userId"]isEqual:ctx[@"userId"]];}
- (void)setWorkspaceAllowed:(BOOL(^)(void))allowed{[_allowed release];_allowed=[allowed copy];}
- (id<OR6APITask>)selectWorkspace:(NSDictionary*)workspace context:(NSDictionary*)ctx completion:(OR6APIReply)reply{
 NSDictionary *target=OR6APIJSONSnapshot(workspace,4096),*original=OR6APIJSONSnapshot(ctx,4096);NSUInteger generation=_adapter.credentialGeneration;
 if(!_allowed||!_allowed()){if(reply)reply(nil,OR6APIError(@"conflict",@"none"));return nil;}
 NSError *preflight=nil;if(![_host synchronizeAccountScope:&preflight]||![original[@"key"]isEqual:_adapter.contextKey]){if(reply)reply(nil,preflight?:OR6APIError(@"stale_context",@"none"));return nil;}
 return[super selectWorkspace:target context:original completion:^(NSDictionary *result,NSError *error){
  if(!error){NSDictionary *identity=_host.identity;NSError *problem=nil;
   if(![result[@"selected"]isEqual:@YES]||![identity[@"accountId"]isEqual:target[@"id"]]||![identity[@"userId"]isEqual:original[@"userId"]]||_adapter.credentialGeneration!=generation+1||![_host synchronizeAccountScope:&problem]||![_adapter recordChatOwnerValidation:identity[@"userId"]expectedKey:_adapter.contextKey generation:_adapter.credentialGeneration]){result=nil;error=problem?:OR6APIError(@"stale_context",@"possible");}
  }
  BOOL transitioned=_adapter.credentialGeneration!=generation;void(^changed)(void)=transitioned?[[_changed copy]autorelease]:nil;
  if(reply)reply(result,error);if(changed)dispatch_async(dispatch_get_main_queue(),changed);
 }];
}
- (void)dealloc{[_host release];[_allowed release];[_changed release];[super dealloc];}
@end
