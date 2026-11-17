#import "OR6CodexStore.h"
#import <CommonCrypto/CommonDigest.h>
#include <sys/stat.h>
#include <sys/file.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
static BOOL Private(NSString*p,BOOL directory){struct stat st;return lstat(p.fileSystemRepresentation,&st)==0&&(directory?S_ISDIR(st.st_mode):S_ISREG(st.st_mode))&&st.st_uid==getuid()&&(st.st_mode&077)==0;}
@implementation OR6CodexStore
- (id)initWithDirectory:(NSString*)d context:(NSDictionary*)c error:(NSError**)error{
 if(!(self=[super init]))return nil;_lockFD=-1;
 if(!OR6CodexPath(d)||!OR6CodexKeys(c,@[@"owner",@"workspace",@"connection",@"credentialGeneration"],@[])||!OR6CodexID(c[@"owner"])||!OR6CodexID(c[@"workspace"])||!OR6CodexID(c[@"connection"])||!OR6APISchemaCheck(c[@"credentialGeneration"],@{@"type":@"integer",@"minimum":@1},@{}))goto fail;
 // iOS normally returns /var/mobile/... for its own container. Canonicalize
 // only the known root-owned system /var alias, never an arbitrary symlink.
 {char root[PATH_MAX];if([d hasPrefix:@"/var/"]&&realpath("/var",root)&&!strcmp(root,"/private/var"))d=[@"/private"stringByAppendingString:d];}
 // The caller supplies an existing private parent; never follow a symlink in
 // any ancestor and never chmod a shared directory as an incidental effect.
 {NSString*part=@"/";for(NSString*x in[d pathComponents]){if([x isEqual:@"/"])continue;part=[part stringByAppendingPathComponent:x];struct stat st;if(lstat(part.fileSystemRepresentation,&st)||!S_ISDIR(st.st_mode))goto fail;}}
 if(!Private(d,YES))goto fail;
 {NSMutableString*key=[NSMutableString string];for(NSString*k in @[@"owner",@"workspace",@"connection",@"credentialGeneration"]){NSString*v=[c[k]description];[key appendFormat:@"%lu:%@",(unsigned long)v.length,v];}NSData*bytes=[key dataUsingEncoding:NSUTF8StringEncoding];unsigned char hash[CC_SHA256_DIGEST_LENGTH];CC_SHA256(bytes.bytes,(CC_LONG)bytes.length,hash);NSMutableString*hex=[NSMutableString string];for(NSUInteger i=0;i<sizeof(hash);i++)[hex appendFormat:@"%02x",hash[i]];_path=[[d stringByAppendingPathComponent:[hex stringByAppendingString:@".json"]]copy];}
 {NSString*lock=[_path stringByAppendingString:@".lock"];_lockFD=open(lock.fileSystemRepresentation,O_RDWR|O_CREAT|O_NOFOLLOW,0600);if(_lockFD<0||!Private(lock,NO)||flock(_lockFD,LOCK_EX|LOCK_NB))goto fail;}
 _context=[OR6APIJSONSnapshot(c,8192)retain];_records=[NSMutableDictionary new];
 {struct stat st;if(lstat(_path.fileSystemRepresentation,&st)==0){if(!Private(_path,NO)||st.st_size>1024*1024)goto fail;NSData*raw=[NSData dataWithContentsOfFile:_path];NSDictionary*v=raw?[NSJSONSerialization JSONObjectWithData:raw options:0 error:NULL]:nil;if(!OR6CodexKeys(v,@[@"context",@"records"],@[])||![v[@"context"]isEqual:c]||![v[@"records"]isKindOfClass:NSDictionary.class]||[v[@"records"]count]>512)goto fail;for(NSString*k in v[@"records"]){NSDictionary*r=v[@"records"][k];if(!OR6CodexID(k)||!OR6CodexKeys(r,@[@"method",@"state"],@[@"threadId",@"turnId",@"expectedTurnId",@"clientUserMessageId",@"path"])||!OR6CodexText(r[@"method"],128,NO)||![@[@"possible",@"confirmed",@"rejected",@"uncertain"]containsObject:r[@"state"]])goto fail;}[_records addEntriesFromDictionary:v[@"records"]];}else if(errno!=ENOENT)goto fail;}
 return self;
fail:if(error)*error=OR6CodexError(@"storage_failure",NO);[self release];return nil;
}
- (BOOL)record:(NSString*)identifier value:(NSDictionary*)value error:(NSError**)error{
 value=OR6APIJSONSnapshot(value,16384);if(_failed||!OR6CodexID(identifier)||!value||(!_records[identifier]&&_records.count>=512)){if(error)*error=OR6CodexError(@"storage_failure",NO);return NO;}
 NSMutableDictionary*next=[[_records mutableCopy]autorelease];next[identifier]=value;NSData*data=[NSJSONSerialization dataWithJSONObject:@{@"context":_context,@"records":next}options:0 error:NULL];if(!data||data.length>1024*1024)goto fail;
 {NSString*tmp=[_path stringByAppendingFormat:@".%@",NSProcessInfo.processInfo.globallyUniqueString];int fd=open(tmp.fileSystemRepresentation,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600);if(fd<0)goto fail;const char*p=data.bytes;NSUInteger left=data.length;BOOL okay=YES;while(left){ssize_t n=write(fd,p,left);if(n<0&&errno==EINTR)continue;if(n<=0){okay=NO;break;}p+=n;left-=(NSUInteger)n;}if(fsync(fd))okay=NO;if(close(fd))okay=NO;if(okay&&rename(tmp.fileSystemRepresentation,_path.fileSystemRepresentation))okay=NO;if(!okay){unlink(tmp.fileSystemRepresentation);goto fail;}[_records setDictionary:next];int parent=open([_path stringByDeletingLastPathComponent].fileSystemRepresentation,O_RDONLY);if(parent<0)goto fail;okay=fsync(parent)==0;close(parent);if(!okay)goto fail;}
 [_records setDictionary:next];return YES;
fail:_failed=YES;if(error)*error=OR6CodexError(@"storage_failure",NO);return NO;
}
- (NSDictionary*)record:(NSString*)i{return OR6APIJSONSnapshot(_records[i],16384);}
- (NSDictionary*)records{return OR6APIJSONSnapshot(_records,1024*1024);}
- (void)close{_failed=YES;if(_lockFD>=0){flock(_lockFD,LOCK_UN);close(_lockFD);_lockFD=-1;}}
- (void)dealloc{[self close];[_path release];[_context release];[_records release];[super dealloc];}
@end
