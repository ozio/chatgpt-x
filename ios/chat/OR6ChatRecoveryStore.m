#import "OR6ChatRecoveryStore.h"
#import "OR6ChatNativePolicy.h"
#import <TargetConditionals.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <math.h>
static BOOL Bool(id n){return[n isKindOfClass:NSNumber.class]&&(CFGetTypeID((CFTypeRef)n)==CFBooleanGetTypeID());}
static BOOL UUIDOrNull(id n){return n==NSNull.null||OR6CNUUID(n);}
static NSDictionary*Safe(id s){
 if(![s isKindOfClass:NSDictionary.class]||![s[@"schema"]isEqual:@1]||![s[@"scope"]isKindOfClass:NSString.class]||![s[@"scope"]length]||[s[@"scope"]length]>128||!OR6CNUUID(s[@"operationId"])||!UUIDOrNull(s[@"conversationId"])||!OR6CNUUID(s[@"userMessageId"])||!UUIDOrNull(s[@"assistantMessageId"])||![s[@"text"]isKindOfClass:NSString.class]||[s[@"text"]length]>262144||!Bool(s[@"finished"])||!Bool(s[@"completed"])||!Bool(s[@"autoResume"])||![s[@"updatedAt"]isKindOfClass:NSNumber.class]||!isfinite([s[@"updatedAt"]doubleValue])||[s[@"updatedAt"]doubleValue]<=0)return nil;
 NSDictionary*p=s[@"request"];if(![p isKindOfClass:NSDictionary.class]||![p[@"operationId"]isEqual:s[@"operationId"]]||!OR6CNUUID(p[@"draftId"])||!OR6CNUUID(p[@"parentMessageId"])||![p[@"modelId"]isEqual:@"web-current"]||![p[@"text"]isKindOfClass:NSString.class]||![p[@"text"]length]||[p[@"text"]length]>16000||![p[@"temporary"]isEqual:@NO]||![p[@"attachments"]isKindOfClass:NSArray.class]||[p[@"attachments"]count]||(p[@"conversationId"]&&!OR6CNUUID(p[@"conversationId"])))return nil;
 if(p[@"conversationId"]&&!OR6CNSameUUID(p[@"conversationId"],s[@"conversationId"]))return nil;
 if([s[@"completed"]boolValue]&&(![s[@"finished"]boolValue]||!OR6CNUUID(s[@"conversationId"])||!OR6CNUUID(s[@"assistantMessageId"])))return nil;
 // Rebuild from known fields, so extra values (including credentials) cannot persist.
 NSMutableDictionary*q=[NSMutableDictionary dictionary];for(NSString*k in @[@"operationId",@"draftId",@"parentMessageId",@"modelId",@"text",@"temporary",@"attachments",@"conversationId"])if(p[k])q[k]=p[k];
 NSMutableDictionary*r=[NSMutableDictionary dictionary];for(NSString*k in @[@"schema",@"scope",@"operationId",@"conversationId",@"userMessageId",@"assistantMessageId",@"text",@"finished",@"completed",@"autoResume",@"updatedAt"])r[k]=s[k];r[@"request"]=q;return r;
}
@implementation OR6ChatRecoveryStore
- (BOOL)directoryOK{struct stat st;return lstat(_directory.fileSystemRepresentation,&st)==0&&S_ISDIR(st.st_mode)&&!(st.st_mode&0077);}
- (id)initWithDirectory:(NSString*)dir{
 if((self=[super init])){_directory=[dir copy];NSDictionary*attrs=@{NSFilePosixPermissions:@0700};
  if(!dir.length||(![NSFileManager.defaultManager fileExistsAtPath:dir]&&![NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:attrs error:NULL])||![self directoryOK]){[self release];return nil;}}
 return self;
}
- (NSString*)path:(NSString*)operation scope:(NSString*)scope{return[_directory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@.json",OR6CNHash(scope),operation.lowercaseString]];}
- (NSDictionary*)read:(NSString*)path{
 if(![self directoryOK])return nil;int fd=open(path.fileSystemRepresentation,O_RDONLY|O_NOFOLLOW);if(fd<0)return nil;struct stat st;BOOL ok=fstat(fd,&st)==0&&S_ISREG(st.st_mode)&&st.st_nlink==1&&!(st.st_mode&0077)&&st.st_size>0&&st.st_size<=2*1024*1024;NSMutableData*d=ok?[NSMutableData dataWithLength:(NSUInteger)st.st_size]:nil;NSUInteger at=0;while(ok&&at<d.length){ssize_t n=read(fd,(char*)d.mutableBytes+at,d.length-at);if(n<=0)ok=NO;else at+=(NSUInteger)n;}close(fd);return ok?Safe([NSJSONSerialization JSONObjectWithData:d options:0 error:NULL]):nil;
}
- (BOOL)save:(NSDictionary*)snapshot{
 NSDictionary*s=Safe(snapshot);if(!s||![self directoryOK])return NO;NSData*d=[NSJSONSerialization dataWithJSONObject:s options:0 error:NULL];if(!d||d.length>2*1024*1024)return NO;
 NSString*prefix=[OR6CNHash(s[@"scope"])stringByAppendingString:@"-"];NSMutableArray*completed=[NSMutableArray array];NSUInteger pending=0;
 for(NSString*f in [NSFileManager.defaultManager contentsOfDirectoryAtPath:_directory error:NULL]){if(![f hasPrefix:prefix]||![f hasSuffix:@".json"])continue;NSDictionary*old=[self read:[_directory stringByAppendingPathComponent:f]];if(!old)continue;if([old[@"completed"]boolValue])[completed addObject:old];else pending++;}
 NSString*path=[self path:s[@"operationId"]scope:s[@"scope"]];if(pending>=32&&![self snapshotForOperation:s[@"operationId"]scope:s[@"scope"]])return NO;
 NSString*tmp=[path stringByAppendingFormat:@".%@.tmp",NSProcessInfo.processInfo.globallyUniqueString];int fd=open(tmp.fileSystemRepresentation,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600);if(fd<0)return NO;
 BOOL ok=YES;NSUInteger at=0;while(ok&&at<d.length){ssize_t n=write(fd,(const char*)d.bytes+at,d.length-at);if(n<=0)ok=NO;else at+=(NSUInteger)n;}
#if TARGET_OS_IPHONE
 if(ok)ok=[NSFileManager.defaultManager setAttributes:@{NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication}ofItemAtPath:tmp error:NULL];
#endif
 if(ok)ok=fsync(fd)==0;if(close(fd)!=0)ok=NO;if(ok)ok=rename(tmp.fileSystemRepresentation,path.fileSystemRepresentation)==0;if(!ok)unlink(tmp.fileSystemRepresentation);
 if(ok){int dirfd=open(_directory.fileSystemRepresentation,O_RDONLY|O_NOFOLLOW);if(dirfd>=0){ok=fsync(dirfd)==0;close(dirfd);}}
 if(ok&&[s[@"completed"]boolValue]){[completed sortUsingComparator:^NSComparisonResult(NSDictionary*a,NSDictionary*b){return[b[@"updatedAt"]compare:a[@"updatedAt"]];}];NSUInteger keep=0;for(NSDictionary*old in completed){if(OR6CNSameUUID(old[@"operationId"],s[@"operationId"]))continue;if(++keep>=10)unlink([self path:old[@"operationId"]scope:s[@"scope"]].fileSystemRepresentation);}}
 return ok;
}
- (NSDictionary*)snapshotForOperation:(NSString*)operation scope:(NSString*)scope{
 if(!OR6CNUUID(operation)||!scope.length)return nil;NSDictionary*s=[self read:[self path:operation scope:scope]];return[s[@"scope"]isEqual:scope]&&OR6CNSameUUID(s[@"operationId"],operation)?s:nil;
}
- (NSDictionary*)latestForScope:(NSString*)scope conversation:(NSString*)identifier{
 if(!scope.length||(identifier&&!OR6CNUUID(identifier))||![self directoryOK])return nil;NSString*prefix=[OR6CNHash(scope)stringByAppendingString:@"-"];NSDictionary*latest=nil;
 for(NSString*f in [NSFileManager.defaultManager contentsOfDirectoryAtPath:_directory error:NULL]){if(![f hasPrefix:prefix]||![f hasSuffix:@".json"]||f.length!=prefix.length+41)continue;NSDictionary*s=[self read:[_directory stringByAppendingPathComponent:f]];if(![s[@"scope"]isEqual:scope]||(identifier&&!OR6CNSameUUID(s[@"conversationId"],identifier)))continue;if(!latest||[s[@"updatedAt"]doubleValue]>[latest[@"updatedAt"]doubleValue])latest=s;}
 return latest;
}
- (BOOL)clearScope:(NSString*)scope{
 if(!scope.length||![self directoryOK])return NO;BOOL ok=YES;NSString*prefix=[OR6CNHash(scope)stringByAppendingString:@"-"];for(NSString*f in [NSFileManager.defaultManager contentsOfDirectoryAtPath:_directory error:NULL])if([f hasPrefix:prefix]&&[f hasSuffix:@".json"])if(unlink([_directory stringByAppendingPathComponent:f].fileSystemRepresentation)!=0)ok=NO;return ok;
}
- (void)dealloc{[_directory release];[super dealloc];}
@end
