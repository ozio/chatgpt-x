#import "OR6API7GProvider.h"
// Uses public iOS6 AVAudioPlayer and Photos write API. No application views.
// Background read aloud: the app declares UIBackgroundModes audio. While the
// host holds playback (only around its own app-background teardown), -suspend
// cancels photo saves but keeps a playing or paused player; any other suspend
// stops it. The playing player publishes lock-screen Now Playing details and
// answers headset/lock-screen play/pause through OR6API7GRemoteControlNotification.
extern NSString *const OR6API7GRemoteControlNotification;     // userInfo @"subtype": NSNumber (UIEventSubtype), posted by the app delegate
extern NSString *const OR6API7GPlaybackDidChangeNotification; // the device changed playback state on its own (remote control)
@interface OR6API7GDevice:NSObject<OR6API7GPlatform>
- (void)setHoldsPlayback:(BOOL)hold;
- (BOOL)holdsPlayback; // hold requested and a player is playing or paused
@end
