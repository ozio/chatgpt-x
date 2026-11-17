// RCPlaybackView — local audio playback controls as an answer-part box (app.css
// .filecard look): speaker tile, file name, «0:12 / 1:30», jade progress, Play/Pause
// and Stop pills, speed segments 0,5× · 1× · 1,5× · 2× (stage 7). States: idle,
// playing, paused, stopped, failed (red note + «Повторить»). The caller owns the
// player and reports its real state; the view never pretends to play.
#import "RCPartView.h"
#import "RCButton.h"
typedef enum { RCPlaybackIdle = 0, RCPlaybackPlaying, RCPlaybackPaused, RCPlaybackStopped, RCPlaybackFailed } RCPlaybackState;
@class RCPlaybackView;
@protocol RCPlaybackViewDelegate <RCPartViewDelegate>
@optional
- (void)playbackViewDidTapPlay:(RCPlaybackView *)view;   // idle/paused/stopped: start or resume (caller decides)
- (void)playbackViewDidTapPause:(RCPlaybackView *)view;
- (void)playbackViewDidTapStop:(RCPlaybackView *)view;
- (void)playbackViewDidTapRetry:(RCPlaybackView *)view;
- (void)playbackView:(RCPlaybackView *)view didChooseRate:(double)rate; // 0.5, 1, 1.5 or 2
@end
@interface RCPlaybackView : RCPartView
@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign) RCPlaybackState state;
@property (nonatomic, assign) NSTimeInterval position, duration;
@property (nonatomic, assign) double rate;            // shown checked segment
@property (nonatomic, assign) BOOL rateAvailable;      // speed segments (default YES)
@property (nonatomic, copy) NSString *failureText;     // failed note; nil: «Не удалось воспроизвести.»
@property (nonatomic, assign) BOOL busy;               // a request runs: pills not enabled
@property (nonatomic, readonly) RCButton *playButton, *stopButton;
+ (NSString *)timeText:(NSTimeInterval)seconds;        // m:ss
@end
