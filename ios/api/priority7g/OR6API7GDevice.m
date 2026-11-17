#import "OR6API7GDevice.h"
#import <TargetConditionals.h>
#import <dispatch/dispatch.h>
#if TARGET_OS_IPHONE || defined(OR6_API7G_DEVICE_TESTING)
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#ifndef OR6_API7G_DEVICE_TESTING
#import <MediaPlayer/MediaPlayer.h>
#endif
@interface OR6API7GDevice(GPhotos)
- (void)photoCompleted:(id)photo;
@end
@interface GPhoto:NSObject<OR6APITask>{@public OR6API7GDevice*owner;NSArray*URLs;NSUInteger index,saved;BOOL terminal,cancelled;OR6APIReply reply;}
- (void)next;
@end
@implementation GPhoto
- (void)cancel{cancelled=YES;}
- (void)finish:(NSError*)e{if(terminal)return;terminal=YES;OR6APIReply cb=[[reply copy]autorelease];[reply release];reply=nil;[[self retain]autorelease];OR6API7GDevice*device=[[owner retain]autorelease];[owner release];owner=nil;[device photoCompleted:self];if(cb)cb(e?nil:@{@"saved":@(saved),@"completed":@((BOOL)(saved==URLs.count))},e);}
- (void)next{if(cancelled){[self finish:OR6APIError(@"cancelled",saved?@"possible":@"none")];return;}if(index==URLs.count){[self finish:nil];return;}UIImage*image=[UIImage imageWithContentsOfFile:[URLs[index]path]];if(!image){[self finish:OR6APIError(@"unsupported_media",saved?@"possible":@"none")];return;}index++;UIImageWriteToSavedPhotosAlbum(image,self,@selector(image:didFinishSavingWithError:contextInfo:),NULL);}
- (void)image:(UIImage*)image didFinishSavingWithError:(NSError*)error contextInfo:(void*)context{(void)image;(void)context;if(error)[self finish:OR6APIError(@"permission_denied",@"possible")];else{saved++;[self next];}}
- (void)dealloc{[owner release];[URLs release];[reply release];[super dealloc];}
@end
NSString *const OR6API7GRemoteControlNotification=@"OR6API7GRemoteControlNotification";
NSString *const OR6API7GPlaybackDidChangeNotification=@"OR6API7GPlaybackDidChangeNotification";
@interface OR6API7GDevice()<AVAudioPlayerDelegate>{AVAudioPlayer*_player;NSURL*_URL;NSString*_asset,*_state;float _rate;NSMutableSet*_photos;BOOL _hold,_remote;}
@end
@implementation OR6API7GDevice
- (id)init{if((self=[super init])){_state=[@"idle"copy];_rate=1;_photos=[NSMutableSet new];[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(remoteControl:)name:OR6API7GRemoteControlNotification object:nil];}return self;}
- (void)state:(NSString*)s{[_state release];_state=[s copy];[self publishNowPlaying];}
- (void)setHoldsPlayback:(BOOL)hold{_hold=hold;}
- (BOOL)holdsPlayback{return _hold&&_player&&([_state isEqual:@"playing"]||[_state isEqual:@"paused"]);}
// Lock screen / Control Center: title, elapsed and rate while a player exists; remote events only then.
- (void)publishNowPlaying{
#ifndef OR6_API7G_DEVICE_TESTING
 MPNowPlayingInfoCenter*center=[MPNowPlayingInfoCenter defaultCenter];UIApplication*app=UIApplication.sharedApplication;
 if(!_player||[_state isEqual:@"idle"]){[center setNowPlayingInfo:nil];if(_remote){[app endReceivingRemoteControlEvents];_remote=NO;}return;}
 if(!_remote){[app beginReceivingRemoteControlEvents];_remote=YES;}
 NSBundle*b=NSBundle.mainBundle;NSString*title=[b localizedStringForKey:@"Reading aloud"value:@"Reading aloud"table:@"Kit"],*appName=[b objectForInfoDictionaryKey:@"CFBundleDisplayName"]?:@"ChatGPT X";
 [center setNowPlayingInfo:@{MPMediaItemPropertyTitle:title,MPMediaItemPropertyArtist:appName,MPMediaItemPropertyPlaybackDuration:@(_player.duration),MPNowPlayingInfoPropertyElapsedPlaybackTime:@(_player.currentTime),MPNowPlayingInfoPropertyPlaybackRate:@([_state isEqual:@"playing"]?_rate:0)}];
#endif
}
- (void)remoteControl:(NSNotification*)n{
 if(!_player||!NSThread.isMainThread)return;NSInteger t=[n.userInfo[@"subtype"]integerValue];BOOL playing=[_state isEqual:@"playing"];NSString*action=nil;
#ifndef OR6_API7G_DEVICE_TESTING
 if(t==UIEventSubtypeRemoteControlTogglePlayPause)action=playing?@"pause":@"resume";else if(t==UIEventSubtypeRemoteControlPlay&&!playing)action=@"resume";else if(t==UIEventSubtypeRemoteControlPause&&playing)action=@"pause";
#else
 action=t==1?(playing?@"pause":@"resume"):nil;
#endif
 if(!action||![self playback:action assetURL:nil assetId:_asset rate:nil error:NULL])return;
 [NSNotificationCenter.defaultCenter postNotificationName:OR6API7GPlaybackDidChangeNotification object:self];
}
- (NSDictionary*)snapshot{return@{@"assetId":_asset?:(id)NSNull.null,@"state":_state,@"position":@(MAX(0,MIN(180,_player.currentTime))),@"duration":@(MAX(0,MIN(180,_player.duration))),@"rate":@(_rate)};}
- (NSDictionary*)playback:(NSString*)action assetURL:(NSURL*)url assetId:(NSString*)asset rate:(NSNumber*)rate error:(NSError**)error{
 if(!NSThread.isMainThread){if(error)*error=OR6APIError(@"invalid_request",@"none");return nil;}if([action isEqual:@"start"]){if(!url.isFileURL){if(error)*error=OR6APIError(@"invalid_request",@"none");return nil;}[self resetAudio];AVAudioSession*session=AVAudioSession.sharedInstance;if(![session setCategory:AVAudioSessionCategoryPlayback error:NULL]||![session setActive:YES error:NULL]){if(error)*error=OR6APIError(@"unavailable",@"none");return nil;}_player=[[AVAudioPlayer alloc]initWithContentsOfURL:url error:NULL];if(!_player||_player.duration<=0||_player.duration>180){[self resetAudio];if(error)*error=OR6APIError(@"unsupported_media",@"none");return nil;}[_URL release];_URL=[url retain];[_asset release];_asset=[asset copy];_player.delegate=self;_player.enableRate=YES;_player.rate=_rate;if(![_player prepareToPlay]||![_player play]){[self state:@"failed"];if(error)*error=OR6APIError(@"unavailable",@"none");return nil;}[self state:@"playing"];
 }else if([action isEqual:@"status"]){}else if(!_player){if(error)*error=OR6APIError(@"invalid_operation_state",@"none");return nil;}else if([action isEqual:@"pause"]){if(![_state isEqual:@"playing"]){if(error)*error=OR6APIError(@"invalid_operation_state",@"none");return nil;}[_player pause];[self state:@"paused"];}else if([action isEqual:@"resume"]||[action isEqual:@"retry"]){if([action isEqual:@"retry"])_player.currentTime=0;if(![_player play]){[self state:@"failed"];if(error)*error=OR6APIError(@"unavailable",@"none");return nil;}[self state:@"playing"];}else if([action isEqual:@"rate"]){if(![@[@0.5,@1,@1.5,@2]containsObject:rate]){if(error)*error=OR6APIError(@"invalid_request",@"none");return nil;}_rate=rate.floatValue;_player.rate=_rate;[self publishNowPlaying];}else if([action isEqual:@"stop"]){[_player stop];[self state:@"stopped"];}else{if(error)*error=OR6APIError(@"invalid_request",@"none");return nil;}return[self snapshot];
}
- (id<OR6APITask>)saveImages:(NSArray*)URLs completion:(OR6APIReply)completion{if(!NSThread.isMainThread||!URLs.count||URLs.count>4){completion(nil,OR6APIError(@"invalid_request",@"none"));return nil;}GPhoto*t=[[[GPhoto alloc]init]autorelease];t->owner=[self retain];t->URLs=[URLs copy];t->reply=[completion copy];[_photos addObject:t];[t next];return t;}
- (void)photoCompleted:(id)photo{[_photos removeObject:photo];}
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer*)player successfully:(BOOL)flag{if(player==_player)[self state:flag?@"stopped":@"failed"];}
- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer*)player error:(NSError*)error{(void)error;if(player==_player)[self state:@"failed"];}
- (void)resetAudio{_player.delegate=nil;[_player stop];[_player release];_player=nil;[_URL release];_URL=nil;[_asset release];_asset=nil;_rate=1;[self state:@"idle"];[AVAudioSession.sharedInstance setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:NULL];}
- (void)suspend{for(GPhoto*photo in [[_photos.allObjects copy]autorelease])[photo cancel];if(![self holdsPlayback])[self resetAudio];}
- (void)dealloc{[NSNotificationCenter.defaultCenter removeObserver:self];_hold=NO;[self suspend];[_URL release];[_asset release];[_state release];[_photos release];[super dealloc];}
@end
#else
NSString *const OR6API7GRemoteControlNotification=@"OR6API7GRemoteControlNotification";
NSString *const OR6API7GPlaybackDidChangeNotification=@"OR6API7GPlaybackDidChangeNotification";
@implementation OR6API7GDevice
- (NSDictionary*)playback:(NSString*)action assetURL:(NSURL*)URL assetId:(NSString*)asset rate:(NSNumber*)rate error:(NSError**)error{(void)action;(void)URL;(void)asset;(void)rate;if(error)*error=OR6APIError(@"capability_unavailable",@"none");return nil;}
- (id<OR6APITask>)saveImages:(NSArray*)URLs completion:(OR6APIReply)completion{(void)URLs;completion(nil,OR6APIError(@"capability_unavailable",@"none"));return nil;}
- (void)suspend{}
- (void)setHoldsPlayback:(BOOL)hold{(void)hold;}
- (BOOL)holdsPlayback{return NO;}
@end
#endif
