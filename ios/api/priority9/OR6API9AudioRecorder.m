#import "OR6API9AudioRecorder.h"
#import "OR6API9Policy.h"
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
@implementation OR6API9AudioRecorder
- (id)initWithDirectory:(NSString*)directory error:(NSError**)error{if((self=[super init])){_directory=[directory copy];_audio=[[OR6Audio alloc]initWithDirectory:directory allowedPlaybackDirectories:@[]error:error];if(!_audio){[self release];return nil;}}return self;}
- (void)clearLimit{[_limit invalidate];[_limit release];_limit=nil;}
- (BOOL)start:(NSString*)identifier maxDurationMS:(NSUInteger)maximum error:(NSError**)error{
 if(!NSThread.isMainThread||!OR6API9UUID(identifier)||!maximum||maximum>60000){if(error)*error=OR6APIError(@"invalid_request",@"none");return NO;}if(![_audio startRecording:identifier.lowercaseString error:error])return NO;
 [_externalID release];_externalID=[identifier copy];[self clearLimit];_limit=[[NSTimer timerWithTimeInterval:(double)maximum/1000 target:self selector:@selector(expired:)userInfo:nil repeats:NO]retain];[NSRunLoop.mainRunLoop addTimer:_limit forMode:NSRunLoopCommonModes];return YES;
}
- (void)expired:(NSTimer*)timer{(void)timer;[self stop];}
- (void)stop{[self clearLimit];[_audio stopRecording];}
- (void)cancel{[self clearLimit];[_audio cancelRecording];if(![_audio.snapshot[@"pending"]boolValue]){[_externalID release];_externalID=nil;}}
- (void)suspend{[self clearLimit];[_audio suspend];}
- (NSDictionary*)snapshot{
 NSDictionary*s=_audio.snapshot;BOOL active=[s[@"state"]isEqual:@"recording"],ready=[@[@"recorded",@"interrupted"]containsObject:s[@"state"]]&&s[@"recording"]!=nil;NSDictionary*m=s[@"recording"];
 return @{@"state":active?@"recording":ready?@"stopped":[s[@"pending"]boolValue]?@"failed":@"idle",@"recordingId":_externalID?:s[@"recordingID"]?:(id)NSNull.null,@"assetId":ready?(_externalID?:s[@"recordingID"]):(id)NSNull.null,@"durationMS":ready?@(MIN(60000,(NSUInteger)([m[@"frames"]unsignedLongLongValue]*1000/16000))):@0,@"bytes":ready?m[@"bytes"]:@0};
}
- (NSData*)recordingData:(NSString*)identifier error:(NSError**)error{
 NSDictionary*s=self.snapshot;if(!OR6API9UUID(identifier)||![s[@"recordingId"]isKindOfClass:NSString.class]||[identifier caseInsensitiveCompare:s[@"recordingId"]]!=NSOrderedSame||![s[@"state"]isEqual:@"stopped"]){if(error)*error=OR6APIError(@"invalid_operation_state",@"none");return nil;}
 NSString*path=[_directory stringByAppendingPathComponent:[identifier.lowercaseString stringByAppendingString:@".wav"]];int fd=open(path.fileSystemRepresentation,O_RDONLY|O_NOFOLLOW|O_NONBLOCK);struct stat before,after;BOOL okay=fd>=0&&fstat(fd,&before)==0&&S_ISREG(before.st_mode)&&before.st_nlink==1&&before.st_size>=44&&before.st_size<=8*1024*1024;NSMutableData*d=[NSMutableData data];
 while(okay){unsigned char bytes[8192];ssize_t n=read(fd,bytes,sizeof(bytes));if(n<0&&errno==EINTR)continue;if(n<0||(n>0&&d.length+(NSUInteger)n>(NSUInteger)before.st_size)){okay=NO;break;}if(!n)break;[d appendBytes:bytes length:(NSUInteger)n];}
 okay=okay&&fstat(fd,&after)==0&&before.st_dev==after.st_dev&&before.st_ino==after.st_ino&&before.st_size==after.st_size&&before.st_mtimespec.tv_sec==after.st_mtimespec.tv_sec&&before.st_mtimespec.tv_nsec==after.st_mtimespec.tv_nsec&&d.length==(NSUInteger)before.st_size;if(fd>=0)close(fd);
 if(!okay||!OR6API9WAVInfo(d,error)){if(error&&!*error)*error=OR6APIError(@"unsupported_media",@"none");return nil;}return[[d copy]autorelease];
}
- (void)dealloc{[self suspend];[_audio release];[_directory release];[_externalID release];[super dealloc];}
@end
