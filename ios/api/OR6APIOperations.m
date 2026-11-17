#import "OR6APIOperations.h"
#import "OR6APISchema.h"
#import <CommonCrypto/CommonDigest.h>
#include <sys/stat.h>
#include <sys/file.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
static NSString*Hash(NSString*s){NSData*d=[s dataUsingEncoding:NSUTF8StringEncoding];unsigned char h[CC_SHA256_DIGEST_LENGTH];CC_SHA256(d.bytes,(CC_LONG)d.length,h);NSMutableString*r=[NSMutableString string];for(NSUInteger i=0;i<sizeof(h);i++)[r appendFormat:@"%02x",h[i]];return r;}
static BOOL Text(id s){return[s isKindOfClass:NSString.class]&&[s length]>0&&[s length]<=256;}
static BOOL Fail(NSError**e,NSString*c){if(e)*e=OR6APIError(c,@"none");return NO;}
@implementation OR6APIOperations
- (id)initWithDirectory:(NSString*)dir error:(NSError**)error{
 if(!(self=[super init]))return nil;_lockfd=-1;
 if(!Text(dir)||![dir isAbsolutePath]){Fail(error,@"storage_failure");[self release];return nil;}
 _directory=[dir copy];NSFileManager*m=NSFileManager.defaultManager;struct stat st;
 if(lstat(dir.fileSystemRepresentation,&st)!=0){if(errno!=ENOENT||![m createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700}error:NULL]){Fail(error,@"storage_failure");[self release];return nil;}}
 if(lstat(dir.fileSystemRepresentation,&st)!=0||!S_ISDIR(st.st_mode)||(st.st_mode&0077)){Fail(error,@"storage_failure");[self release];return nil;}
 _lockfd=open([dir stringByAppendingPathComponent:@".lock"].fileSystemRepresentation,O_RDWR|O_CREAT|O_NOFOLLOW,0600);
 if(_lockfd<0||fstat(_lockfd,&st)||!S_ISREG(st.st_mode)||st.st_nlink!=1){Fail(error,@"storage_failure");[self release];return nil;}
 return self;
}
- (NSString*)path:(NSString*)identifier scope:(NSString*)scope{return[_directory stringByAppendingPathComponent:[Hash([NSString stringWithFormat:@"%@\n%@",scope,identifier])stringByAppendingString:@".json"]];}
- (NSDictionary*)record:(NSString*)identifier scope:(NSString*)scope error:(NSError**)error{
 if(!Text(identifier)||!Text(scope)){Fail(error,@"invalid_request");return nil;}
 NSString*p=[self path:identifier scope:scope];int fd=open(p.fileSystemRepresentation,O_RDONLY|O_NOFOLLOW|O_NONBLOCK);
 if(fd<0){if(errno!=ENOENT)Fail(error,@"storage_failure");return nil;}struct stat st;NSMutableData*d=[NSMutableData data];BOOL ok=fstat(fd,&st)==0&&S_ISREG(st.st_mode)&&st.st_nlink==1&&st.st_size>0&&st.st_size<=1024*1024;
 while(ok){char b[8192];ssize_t n=read(fd,b,sizeof(b));if(n<0&&errno==EINTR)continue;if(n<0||(n>0&&d.length+(NSUInteger)n>1024*1024)){ok=NO;break;}if(n==0)break;[d appendBytes:b length:(NSUInteger)n];}close(fd);
 if(!ok||d.length!=(NSUInteger)st.st_size){Fail(error,@"storage_failure");return nil;}
 id r=[NSJSONSerialization JSONObjectWithData:d options:0 error:NULL];
 if(![r isKindOfClass:NSDictionary.class]||![r[@"schema"]isEqual:@1]||![r[@"operationId"]isEqual:identifier]||![r[@"scopeHash"]isEqual:Hash(scope)]||![@[@"dispatching",@"completed",@"rejected",@"cancelled",@"uncertain"]containsObject:r[@"state"]]){Fail(error,@"storage_failure");return nil;}
 return r;
}
- (BOOL)write:(NSDictionary*)r path:(NSString*)path error:(NSError**)error{
 NSData*d=[NSJSONSerialization dataWithJSONObject:r options:0 error:NULL];if(!d||d.length>1024*1024)return Fail(error,@"storage_failure");
 NSArray*files=[NSFileManager.defaultManager contentsOfDirectoryAtPath:_directory error:NULL];if(!files||files.count>8192)return Fail(error,@"storage_failure");
 unsigned long long total=0;for(NSString*f in files)if([f hasSuffix:@".json"]){struct stat st;if(lstat([_directory stringByAppendingPathComponent:f].fileSystemRepresentation,&st)||!S_ISREG(st.st_mode)||st.st_size<0)return Fail(error,@"storage_failure");total+=(unsigned long long)st.st_size;if(total>32*1024*1024)return Fail(error,@"storage_failure");}
 NSString*tmp=[_directory stringByAppendingPathComponent:[@".write-"stringByAppendingString:NSProcessInfo.processInfo.globallyUniqueString]];int fd=open(tmp.fileSystemRepresentation,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600);if(fd<0)return Fail(error,@"storage_failure");
 const char*b=d.bytes;NSUInteger n=0;BOOL ok=YES;while(n<d.length){ssize_t k=write(fd,b+n,d.length-n);if(k<0&&errno==EINTR)continue;if(k<=0){ok=NO;break;}n+=(NSUInteger)k;}if(ok&&fsync(fd))ok=NO;if(close(fd))ok=NO;
 if(ok&&rename(tmp.fileSystemRepresentation,path.fileSystemRepresentation))ok=NO;if(!ok){unlink(tmp.fileSystemRepresentation);return Fail(error,@"storage_failure");}
 int directory=open(_directory.fileSystemRepresentation,O_RDONLY|O_NOFOLLOW);if(directory<0)return Fail(error,@"storage_failure");ok=fsync(directory)==0;close(directory);return ok?YES:Fail(error,@"storage_failure");
}
- (BOOL)reserve:(NSString*)identifier command:(NSString*)cmd request:(NSDictionary*)req scope:(NSString*)scope error:(NSError**)error{
 @synchronized(self){if(flock(_lockfd,LOCK_EX))return Fail(error,@"storage_failure");@try{if(!Text(identifier)||!Text(cmd)||!Text(scope)||!OR6APIJSONSnapshot(req,512*1024))return Fail(error,@"invalid_request");NSError*e=nil;NSDictionary*old=[self record:identifier scope:scope error:&e];if(e){if(error)*error=e;return NO;}if(old)return Fail(error,@"duplicate_operation");
 NSDictionary*r=@{@"schema":@1,@"operationId":identifier,@"scopeHash":Hash(scope),@"command":cmd,@"request":req,@"state":@"dispatching",@"metadata":@{}};return[self write:r path:[self path:identifier scope:scope]error:error];}@finally{flock(_lockfd,LOCK_UN);}}
}
- (BOOL)finish:(NSString*)identifier scope:(NSString*)scope state:(NSString*)state metadata:(NSDictionary*)metadata error:(NSError**)error{
 @synchronized(self){if(flock(_lockfd,LOCK_EX))return Fail(error,@"storage_failure");@try{if(![@[@"completed",@"rejected",@"cancelled",@"uncertain"]containsObject:state])return Fail(error,@"invalid_operation_state");NSDictionary*r=[self record:identifier scope:scope error:error];if(!r)return Fail(error,@"storage_failure");if(![r[@"state"]isEqual:@"dispatching"]&&![r[@"state"]isEqual:@"uncertain"])return Fail(error,@"invalid_operation_state");
 NSMutableDictionary*next=[[r mutableCopy]autorelease];next[@"state"]=state;NSMutableDictionary*safe=[NSMutableDictionary dictionary];for(NSString*k in @[@"conversationId",@"userMessageId",@"assistantMessageId",@"persisted"]){id v=metadata[k];if(v)safe[k]=v;}next[@"metadata"]=safe;
 if([state isEqual:@"completed"]){id result=OR6APIJSONSnapshot(metadata,512*1024);if(!result)return Fail(error,@"storage_failure");next[@"result"]=result;}
 // Completed metadata is enough for duplicate rejection/reconciliation; no
 // credentials ever enter request, and successful text drafts needn't persist.
 if([state isEqual:@"completed"])[next removeObjectForKey:@"request"];
 return[self write:next path:[self path:identifier scope:scope]error:error];}@finally{flock(_lockfd,LOCK_UN);}}
}
- (void)dealloc{if(_lockfd>=0)close(_lockfd);[_directory release];[super dealloc];}
@end
