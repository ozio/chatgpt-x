#import "OR6API8Interactions.h"
#import "../../auth/OR6WebLoginController.h"
#import <dispatch/dispatch.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <math.h>
@interface I8Task:NSObject<OR6APITask>{@public void(^stop)(void);BOOL ended;}
@end
@implementation I8Task
- (void)cancel{if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self cancel];});return;}if(ended)return;ended=YES;void(^cb)(void)=[[stop copy]autorelease];[stop release];stop=nil;if(cb)cb();}
- (void)dealloc{[stop release];[super dealloc];}
@end
@interface OR6API8AuthHost()<OR6WebLoginControllerDelegate>{UIViewController*_presenter;OR6WebLoginController*_login;UINavigationController*_navigation;OR6WebSession*_session;void(^_completion)(NSString*);I8Task*_task;}
@end
@implementation OR6API8AuthHost
- (id)initWithPresenter:(UIViewController*)p{if((self=[super init]))_presenter=p;return self;}
- (void)finish:(NSString*)state {
 if(!_completion)return;void(^cb)(NSString*)=[[_completion copy]autorelease];[_completion release];_completion=nil;_task->ended=YES;[_task->stop release];_task->stop=nil;[_task release];_task=nil;
 [_login stop];_login.delegate=nil;if(_presenter.presentedViewController==_navigation)[_presenter dismissViewControllerAnimated:YES completion:nil];[_login release];_login=nil;[_navigation release];_navigation=nil;[_session release];_session=nil;cb(state);
}
- (id<OR6APITask>)presentProvider:(NSString*)provider session:(OR6WebSession*)session generation:(NSUInteger)generation completion:(void(^)(NSString*))completion {
 if(!NSThread.isMainThread||_completion||_presenter.presentedViewController||![@[@"email",@"google"]containsObject:provider])return nil;
 _session=[session retain];_completion=[completion copy];_login=[[OR6WebLoginController alloc]initWithSession:session generation:generation];_login.delegate=self;_navigation=[[UINavigationController alloc]initWithRootViewController:_login];_task=[I8Task new];_task->stop=[^{[self finish:@"cancelled"];}copy];[_presenter presentViewController:_navigation animated:YES completion:nil];return[[_task retain]autorelease];
}
- (void)sessionChanged{[_login sessionChanged];if(_session.authenticated)[self finish:@"complete"];else if([_session.phase isEqual:@"reauthentication_required"]||[_session.phase isEqual:@"signed_out"])[self finish:@"failed"];}
- (void)loginControllerCancelled:(OR6WebLoginController*)controller{if(controller==_login)[self finish:@"cancelled"];}
- (void)dealloc{[self finish:@"cancelled"];[super dealloc];}
@end
@interface OR6API8Picker()<UIImagePickerControllerDelegate,UINavigationControllerDelegate>{UIViewController*_presenter,*_modal;NSString*_inbox;NSMutableSet*_staged;void(^_completion)(NSURL*,NSError*);I8Task*_task;}
@end
@implementation OR6API8Picker
- (id)initWithPresenter:(UIViewController*)p inbox:(NSString*)inbox{if((self=[super init])){_presenter=p;_inbox=[inbox copy];_staged=[NSMutableSet new];}return self;}
- (void)setPresenter:(UIViewController*)presenter{if(NSThread.isMainThread&&!_completion)_presenter=presenter;}
- (void)finish:(NSURL*)url error:(NSError*)error {
 if(!_completion)return;void(^cb)(NSURL*,NSError*)=[[_completion copy]autorelease];[_completion release];_completion=nil;_task->ended=YES;[_task->stop release];_task->stop=nil;[_task release];_task=nil;
 if([_modal isKindOfClass:UIImagePickerController.class])((UIImagePickerController*)_modal).delegate=nil;
 if(_presenter.presentedViewController==_modal)[_presenter dismissViewControllerAnimated:YES completion:nil];[_modal release];_modal=nil;cb(url,error);
}
- (id<OR6APITask>)acquire:(NSString*)source selection:(NSString*)selection completion:(void(^)(NSURL*,NSError*))completion {
 (void)selection;if(!NSThread.isMainThread||!_presenter||_completion||_presenter.presentedViewController)return nil;
 _completion=[completion copy];_task=[I8Task new];_task->stop=[^{[self finish:nil error:OR6APIError(@"cancelled",@"none")];}copy];
 if([source isEqual:@"document"]){
  // iOS 6 has Open In/Inbox, not UIDocumentPicker. Show only app Inbox files.
  Class screen=NSClassFromString(OR6API8InboxScreenClassName);
  if(![screen conformsToProtocol:@protocol(OR6API8InboxScreen)]){[self finish:nil error:OR6APIError(@"capability_unavailable",@"none")];return[[[I8Task alloc]init]autorelease];}
  NSMutableArray*files=[NSMutableArray array],*names=[NSMutableArray array];for(NSString*n in [[NSFileManager.defaultManager contentsOfDirectoryAtPath:_inbox error:NULL]sortedArrayUsingSelector:@selector(compare:)]){struct stat st;NSString*path=[_inbox stringByAppendingPathComponent:n];if(!lstat(path.fileSystemRepresentation,&st)&&S_ISREG(st.st_mode)&&st.st_nlink==1&&st.st_size>0&&st.st_size<=8*1024*1024&&![n hasPrefix:@"."]&&[n rangeOfString:@"/"].location==NSNotFound){[files addObject:@{@"name":n,@"bytes":@((unsigned long long)st.st_size)}];[names addObject:n];}if(files.count>=256)break;}
  NSArray*listed=[[names copy]autorelease];
  UIViewController*list=[(Class<OR6API8InboxScreen>)screen inboxScreenWithFiles:files chosen:^(NSString*n){if(n&&![listed containsObject:n])return;[self finish:n?[NSURL fileURLWithPath:[_inbox stringByAppendingPathComponent:n]]:nil error:n?nil:OR6APIError(@"cancelled",@"none")];}];
  if(!list){[self finish:nil error:OR6APIError(@"capability_unavailable",@"none")];return[[[I8Task alloc]init]autorelease];}
  _modal=[[UINavigationController alloc]initWithRootViewController:list];
 }else{
  UIImagePickerControllerSourceType kind=[source isEqual:@"camera"]?UIImagePickerControllerSourceTypeCamera:UIImagePickerControllerSourceTypePhotoLibrary;
  if(![@[@"camera",@"photo_library"]containsObject:source]||![UIImagePickerController isSourceTypeAvailable:kind]){[self finish:nil error:OR6APIError(@"capability_unavailable",@"none")];return[[[I8Task alloc]init]autorelease];}
  UIImagePickerController*p=[[[UIImagePickerController alloc]init]autorelease];p.sourceType=kind;p.mediaTypes=@[@"public.image"];p.delegate=self;_modal=[p retain];
 }
 [_presenter presentViewController:_modal animated:YES completion:nil];return[[_task retain]autorelease];
}
- (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary*)info {
 if(picker!=_modal)return;UIImage*image=info[UIImagePickerControllerOriginalImage];if(![image isKindOfClass:UIImage.class]){[self finish:nil error:OR6APIError(@"unsupported_media",@"none")];return;}
 CGFloat w=image.size.width,h=image.size.height;CGFloat scale=MIN(1,2048/MAX(w,h));if(!isfinite(w)||!isfinite(h)||w<=0||h<=0){[self finish:nil error:OR6APIError(@"unsupported_media",@"none")];return;}
 UIGraphicsBeginImageContextWithOptions(CGSizeMake(MAX(1,w*scale),MAX(1,h*scale)),YES,1);[image drawInRect:CGRectMake(0,0,MAX(1,w*scale),MAX(1,h*scale))];UIImage*converted=UIGraphicsGetImageFromCurrentImageContext();NSData*bytes=converted?UIImageJPEGRepresentation(converted,.85):nil;UIGraphicsEndImageContext();
 if(!bytes.length||bytes.length>8*1024*1024){[self finish:nil error:OR6APIError(@"size_limit",@"none")];return;}
 NSString*path=[_inbox stringByAppendingPathComponent:[[NSProcessInfo.processInfo.globallyUniqueString stringByReplacingOccurrencesOfString:@"/"withString:@"-"]stringByAppendingString:@".jpg"]];int fd=open(path.fileSystemRepresentation,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600);BOOL okay=fd>=0;NSUInteger at=0;while(okay&&at<bytes.length){ssize_t n=write(fd,(const unsigned char*)bytes.bytes+at,bytes.length-at);if(n<0&&errno==EINTR)continue;if(n<=0)okay=NO;else at+=(NSUInteger)n;}if(okay&&fsync(fd))okay=NO;if(fd>=0&&close(fd))okay=NO;
 if(!okay){if(fd>=0)unlink(path.fileSystemRepresentation);[self finish:nil error:OR6APIError(@"storage_failure",@"none")];return;}[_staged addObject:path];[self finish:[NSURL fileURLWithPath:path]error:nil];
}
- (void)releaseSelectionURL:(NSURL*)url{NSString*path=url.path;if(![_staged containsObject:path])return;struct stat st;if(!lstat(path.fileSystemRepresentation,&st)&&S_ISREG(st.st_mode)&&st.st_nlink==1&&unlink(path.fileSystemRepresentation)==0)[_staged removeObject:path];}
- (void)imagePickerControllerDidCancel:(UIImagePickerController*)picker{if(picker==_modal)[self finish:nil error:OR6APIError(@"cancelled",@"none")];}
- (void)dealloc{[self finish:nil error:OR6APIError(@"cancelled",@"none")];for(NSString*path in [[_staged.allObjects copy]autorelease])[self releaseSelectionURL:[NSURL fileURLWithPath:path]];[_staged release];[_inbox release];[super dealloc];}
@end
