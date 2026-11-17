#import "OR6CodexPrivateState.h"
#include <sys/stat.h>
#include <sys/file.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
static BOOL Private(NSString*p,BOOL dir){struct stat s;return!lstat(p.fileSystemRepresentation,&s)&&(dir?S_ISDIR(s.st_mode):S_ISREG(s.st_mode))&&s.st_uid==getuid()&&!(s.st_mode&077);}
@implementation OR6CodexPrivateState
- (id)initWithDirectory:(NSString*)dir context:(NSDictionary*)ctx name:(NSString*)name error:(NSError**)error{
 if(!(self=[super init]))return nil;_lockFD=-1;
 if(!OR6CodexPath(dir)||!OR6CodexText(name,40,NO)||[name rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789-"]invertedSet]].location!=NSNotFound||!OR6CodexKeys(ctx,@[@"owner",@"workspace",@"credentialGeneration"],@[])||!OR6CodexID(ctx[@"owner"])||!OR6CodexID(ctx[@"workspace"])||!OR6APISchemaCheck(ctx[@"credentialGeneration"],@{@"type":@"integer",@"minimum":@1,@"maximum":@9007199254740991LL},@{}))goto fail;
 {char root[PATH_MAX];if([dir hasPrefix:@"/var/"]&&realpath("/var",root)&&!strcmp(root,"/private/var"))dir=[@"/private"stringByAppendingString:dir];}
 {NSString*part=@"/";for(NSString*p in dir.pathComponents){if([p isEqual:@"/"])continue;part=[part stringByAppendingPathComponent:p];struct stat s;if(lstat(part.fileSystemRepresentation,&s)||!S_ISDIR(s.st_mode))goto fail;}}
 if(!Private(dir,YES))goto fail;
 _context=[OR6APIJSONSnapshot(ctx,8192)retain];{NSMutableString*k=[NSMutableString string];for(NSString*p in @[@"owner",@"workspace",@"credentialGeneration"]){NSString*v=[ctx[p]description];[k appendFormat:@"%lu:%@",(unsigned long)v.length,v];}_path=[[dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@.json",name,OR6CodexDigest(k)]]copy];}
 {NSString*lock=[_path stringByAppendingString:@".lock"];_lockFD=open(lock.fileSystemRepresentation,O_RDWR|O_CREAT|O_NOFOLLOW,0600);if(_lockFD<0||!Private(lock,NO)||flock(_lockFD,LOCK_EX|LOCK_NB))goto fail;}
 {struct stat s;if(!lstat(_path.fileSystemRepresentation,&s)){if(!Private(_path,NO)||s.st_size>65536)goto fail;NSDictionary*d=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:_path]options:0 error:NULL];if(!OR6CodexKeys(d,@[@"context",@"value"],@[])||![d[@"context"]isEqual:ctx]||![d[@"value"]isKindOfClass:NSDictionary.class])goto fail;_value=[OR6APIJSONSnapshot(d[@"value"],65536)retain];if(!_value)goto fail;}else if(errno!=ENOENT)goto fail;else _value=[@{}retain];}return self;
fail:if(error)*error=OR6CodexError(@"storage_failure",NO);[self release];return nil;
}
- (NSDictionary*)value{return OR6APIJSONSnapshot(_value,65536);}
- (BOOL)save:(NSDictionary*)value error:(NSError**)error{
 value=OR6APIJSONSnapshot(value,60000);if(_failed||![value isKindOfClass:NSDictionary.class])goto fail;
 {NSData*d=[NSJSONSerialization dataWithJSONObject:@{@"context":_context,@"value":value}options:0 error:NULL];if(!d||d.length>65536)goto fail;NSString*tmp=[_path stringByAppendingFormat:@".%@",NSProcessInfo.processInfo.globallyUniqueString];int fd=open(tmp.fileSystemRepresentation,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600);if(fd<0)goto fail;NSUInteger left=d.length;const char*p=d.bytes;BOOL good=YES;while(left){ssize_t n=write(fd,p,left);if(n<0&&errno==EINTR)continue;if(n<=0){good=NO;break;}p+=n;left-=(NSUInteger)n;}if(fsync(fd))good=NO;if(close(fd))good=NO;if(good&&rename(tmp.fileSystemRepresentation,_path.fileSystemRepresentation))good=NO;if(!good){unlink(tmp.fileSystemRepresentation);goto fail;}[_value release];_value=[value retain];int parent=open(_path.stringByDeletingLastPathComponent.fileSystemRepresentation,O_RDONLY);if(parent<0)goto fail;good=!fsync(parent);close(parent);if(!good)goto fail;}return YES;
fail:_failed=YES;if(error)*error=OR6CodexError(@"storage_failure",NO);return NO;
}
- (void)close{_failed=YES;if(_lockFD>=0){flock(_lockFD,LOCK_UN);close(_lockFD);_lockFD=-1;}}
- (void)dealloc{[self close];[_path release];[_context release];[_value release];[super dealloc];}
@end
