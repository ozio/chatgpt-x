#import "OR6Rev5LocalVideo.h"
#import <AVFoundation/AVFoundation.h>
#import <math.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
static id Fail(NSError **error){if(error)*error=OR6APIError(@"unsupported_media",@"none");return nil;}
static BOOL File(NSURL*u){if(![u isKindOfClass:NSURL.class]||!u.isFileURL||!u.path.isAbsolutePath)return NO;struct stat st;return !lstat(u.path.fileSystemRepresentation,&st)&&S_ISREG(st.st_mode)&&st.st_uid==geteuid()&&st.st_size>0&&st.st_size<=8*1024*1024;}
void OR6Rev5LocalReleaseMovieCopy(NSURL *URL){if(![URL isKindOfClass:NSURL.class]||!URL.isFileURL||![URL.lastPathComponent isEqual:@"video.mov"])return;NSString*directory=URL.path.stringByDeletingLastPathComponent,*parent=directory.stringByDeletingLastPathComponent;if(![parent.stringByStandardizingPath isEqual:NSTemporaryDirectory().stringByStandardizingPath]||![directory.lastPathComponent hasPrefix:@"Rev5VideoDecode-"])return;struct stat st;if(lstat(directory.fileSystemRepresentation,&st)||!S_ISDIR(st.st_mode)||st.st_uid!=geteuid()||(st.st_mode&0077))return;unlink(URL.path.fileSystemRepresentation);rmdir(directory.fileSystemRepresentation);}
NSURL *OR6Rev5LocalMovieCopy(NSURL *u,NSError **error){
 if(!File(u))return Fail(error);int input=open(u.path.fileSystemRepresentation,O_RDONLY|O_NOFOLLOW|O_NONBLOCK);struct stat st;if(input<0)return Fail(error);BOOL valid=!fstat(input,&st)&&S_ISREG(st.st_mode)&&st.st_uid==geteuid()&&st.st_size>0&&st.st_size<=8*1024*1024;if(!valid){close(input);return Fail(error);}
 CFUUIDRef uuid=CFUUIDCreate(NULL);NSString*name=[@"Rev5VideoDecode-"stringByAppendingString:[(NSString*)CFUUIDCreateString(NULL,uuid)autorelease]];CFRelease(uuid);NSString*directory=[NSTemporaryDirectory()stringByAppendingPathComponent:name];if(mkdir(directory.fileSystemRepresentation,0700)){close(input);return Fail(error);}NSURL*output=[NSURL fileURLWithPath:[directory stringByAppendingPathComponent:@"video.mov"]];int fd=open(output.path.fileSystemRepresentation,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600);if(fd<0){close(input);rmdir(directory.fileSystemRepresentation);return Fail(error);}unsigned long long total=0;BOOL ok=YES;for(;;){unsigned char bytes[32768];ssize_t n=read(input,bytes,sizeof(bytes));if(n<0&&errno==EINTR)continue;if(n<0||(n>0&&total+(unsigned long long)n>8*1024*1024)){ok=NO;break;}if(n==0)break;total+=(unsigned long long)n;ssize_t at=0;while(at<n){ssize_t sent=write(fd,bytes+at,(size_t)(n-at));if(sent<0&&errno==EINTR)continue;if(sent<=0){ok=NO;break;}at+=sent;}if(!ok)break;}if(close(input))ok=NO;if(close(fd))ok=NO;if(!total||total!=(unsigned long long)st.st_size)ok=NO;if(!ok){OR6Rev5LocalReleaseMovieCopy(output);return Fail(error);}return output;
}
NSDictionary *OR6Rev5LocalInspectVideo(NSURL *u,NSError **error){
 if(!File(u))return Fail(error);NSURL*copy=OR6Rev5LocalMovieCopy(u,error);if(!copy)return nil;NSDictionary*result=nil;
 @try{AVURLAsset*a=[[[AVURLAsset alloc]initWithURL:copy options:@{AVURLAssetReferenceRestrictionsKey:@(AVAssetReferenceRestrictionForbidAll)}]autorelease];NSArray*t=[a tracksWithMediaType:AVMediaTypeVideo];NSTimeInterval duration=CMTimeGetSeconds(a.duration);if(!a.hasProtectedContent&&a.playable&&t.count&&t.count<=4&&isfinite(duration)&&duration>=0.01&&duration<=600){CGSize size=[(AVAssetTrack*)t[0]naturalSize];double w=fabs(size.width),h=fabs(size.height);if(isfinite(w)&&isfinite(h)&&w>=1&&h>=1&&w<=1920&&h<=1920&&w*h<=2073600)result=@{@"duration":@(duration),@"width":@((NSUInteger)w),@"height":@((NSUInteger)h)};}}
 @catch(NSException*exception){(void)exception;}
 @finally{OR6Rev5LocalReleaseMovieCopy(copy);}
 return result?:Fail(error);
}
