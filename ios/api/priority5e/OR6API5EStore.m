#import "OR6API5EStore.h"
#import <CommonCrypto/CommonDigest.h>
#include <sys/stat.h>
#include <sys/file.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
static BOOL Failure(NSError**error){if(error)*error=OR6APIError(@"storage_failure",@"none");return NO;}
static NSString*Hash(NSString*s){NSData*d=[s dataUsingEncoding:NSUTF8StringEncoding];unsigned char h[CC_SHA256_DIGEST_LENGTH];CC_SHA256(d.bytes,(CC_LONG)d.length,h);NSMutableString*out=[NSMutableString string];for(NSUInteger i=0;i<sizeof h;i++)[out appendFormat:@"%02x",h[i]];return out;}
@interface OR6API5EStore(){NSString*_directory;int _lock;}
@end
@implementation OR6API5EStore
- (id)initWithDirectory:(NSString*)dir error:(NSError**)error{
 if(!(self=[super init]))return nil;_lock=-1;struct stat st;
 if(![dir isKindOfClass:NSString.class]||!dir.isAbsolutePath||dir.length>2048){Failure(error);[self release];return nil;}
 if(lstat(dir.fileSystemRepresentation,&st)&&!(errno==ENOENT&&[NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700}error:NULL])){Failure(error);[self release];return nil;}
 if(lstat(dir.fileSystemRepresentation,&st)||!S_ISDIR(st.st_mode)||(st.st_mode&0077)){Failure(error);[self release];return nil;}
 _directory=[dir copy];_lock=open([dir stringByAppendingPathComponent:@".lock"].fileSystemRepresentation,O_RDWR|O_CREAT|O_NOFOLLOW,0600);
 if(_lock<0||fstat(_lock,&st)||!S_ISREG(st.st_mode)||st.st_nlink!=1||(st.st_mode&0077)){Failure(error);[self release];return nil;}return self;
}
- (NSString*)path:(NSString*)scope{return[_directory stringByAppendingPathComponent:[Hash(scope)stringByAppendingString:@".json"]];}
- (NSDictionary*)readScope:(NSString*)scope error:(NSError**)error{
 if(![scope isKindOfClass:NSString.class]||!scope.length||scope.length>256){Failure(error);return nil;}
 int fd=open([self path:scope].fileSystemRepresentation,O_RDONLY|O_NOFOLLOW|O_NONBLOCK);if(fd<0){if(errno==ENOENT)return @{};Failure(error);return nil;}
 struct stat st;BOOL ok=!fstat(fd,&st)&&S_ISREG(st.st_mode)&&st.st_nlink==1&&!(st.st_mode&0077)&&st.st_size>0&&st.st_size<=1024*1024;NSMutableData*d=[NSMutableData data];
 while(ok){char bytes[8192];ssize_t n=read(fd,bytes,sizeof bytes);if(n<0&&errno==EINTR)continue;if(n<0||(n>0&&d.length+(NSUInteger)n>1024*1024)){ok=NO;break;}if(!n)break;[d appendBytes:bytes length:(NSUInteger)n];}close(fd);
 id root=ok&&d.length==(NSUInteger)st.st_size?[NSJSONSerialization JSONObjectWithData:d options:0 error:NULL]:nil;
 if(![root isKindOfClass:NSDictionary.class]||![root[@"version"]isEqual:@1]||![root[@"scope"]isEqual:Hash(scope)]||![root[@"value"]isKindOfClass:NSDictionary.class]){Failure(error);return nil;}return OR6APIJSONSnapshot(root[@"value"],1024*1024);
}
- (BOOL)write:(NSDictionary*)value scope:(NSString*)scope error:(NSError**)error{
 if(![scope isKindOfClass:NSString.class]||!scope.length||scope.length>256||![value isKindOfClass:NSDictionary.class]||!OR6APIJSONSnapshot(value,900*1024))return Failure(error);
 if(flock(_lock,LOCK_EX))return Failure(error);@try{
 NSArray*files=[NSFileManager.defaultManager contentsOfDirectoryAtPath:_directory error:NULL];if(!files||files.count>256)return Failure(error);unsigned long long total=0;
 for(NSString*f in files)if([f hasSuffix:@".json"]){struct stat st;if(lstat([_directory stringByAppendingPathComponent:f].fileSystemRepresentation,&st)||!S_ISREG(st.st_mode)||st.st_nlink!=1||st.st_size<0)return Failure(error);total+=(unsigned long long)st.st_size;if(total>16*1024*1024)return Failure(error);}
 NSData*d=[NSJSONSerialization dataWithJSONObject:@{@"version":@1,@"scope":Hash(scope),@"value":value}options:0 error:NULL];if(!d||d.length>1024*1024)return Failure(error);
 NSString*tmp=[_directory stringByAppendingPathComponent:[@".write-"stringByAppendingString:NSProcessInfo.processInfo.globallyUniqueString]];int fd=open(tmp.fileSystemRepresentation,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600);if(fd<0)return Failure(error);BOOL ok=YES;NSUInteger sent=0;
 while(sent<d.length){ssize_t n=write(fd,(const char*)d.bytes+sent,d.length-sent);if(n<0&&errno==EINTR)continue;if(n<=0){ok=NO;break;}sent+=(NSUInteger)n;}if(ok&&fsync(fd))ok=NO;if(close(fd))ok=NO;
 if(ok&&rename(tmp.fileSystemRepresentation,[self path:scope].fileSystemRepresentation))ok=NO;if(!ok){unlink(tmp.fileSystemRepresentation);return Failure(error);}int directory=open(_directory.fileSystemRepresentation,O_RDONLY|O_NOFOLLOW);if(directory<0)return Failure(error);ok=!fsync(directory);close(directory);return ok?YES:Failure(error);
 }@finally{flock(_lock,LOCK_UN);}
}
- (void)dealloc{if(_lock>=0)close(_lock);[_directory release];[super dealloc];}
@end
