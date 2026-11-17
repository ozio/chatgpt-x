// Read-aloud mini player below the navigation bar. Graphite glass strip in the
// iOS 6 media-control idiom: convex round play/pause knob, title with a live
// level meter, elapsed/total time, progress groove, dark speed and Close
// capsules. Slides down from under the bar when presented and back up when
// dismissed. No audio or I/O: delegates own playback.
// Loading/playing/paused/stopped/failed, light/dark, text sizes and VoiceOver.
#import <UIKit/UIKit.h>
#import "RCPlaybackView.h"
@class RCReadAloudBar;
@protocol RCReadAloudBarDelegate <NSObject>
- (void)readAloudBarDidTapPlay:(RCReadAloudBar *)bar;
- (void)readAloudBarDidTapPause:(RCReadAloudBar *)bar;
- (void)readAloudBarDidTapRetry:(RCReadAloudBar *)bar;
- (void)readAloudBarDidClose:(RCReadAloudBar *)bar;
- (void)readAloudBar:(RCReadAloudBar *)bar didChooseRate:(double)rate;
@optional
// The full strip height changed (text size, failure text wrapping). Not sent
// for elapsed-time ticks.
- (void)readAloudBarDidChangeHeight:(RCReadAloudBar *)bar;
@end
@interface RCReadAloudBar : UIView
@property(nonatomic, assign) id<RCReadAloudBarDelegate> delegate;
@property(nonatomic, assign) RCPlaybackState state;
@property(nonatomic, assign) BOOL busy, rateAvailable;
@property(nonatomic, assign) NSTimeInterval position, duration;
@property(nonatomic, assign) double rate;
@property(nonatomic, copy) NSString *failureText;
@property(nonatomic, readonly) UIButton *playButton, *speedButton, *closeButton;
// Presentation (default YES). A host gives the bar
// `presented ? heightForWidth: : 0` and, to slide content with it, lays out
// inside an animation of +presentationDuration and then calls -layoutIfNeeded
// on the bar. The strip slides down from its top edge when presented and up
// behind it when dismissed; a dismissed bar is hidden from VoiceOver and touch.
@property(nonatomic, readonly, getter=isPresented) BOOL presented;
- (void)setPresented:(BOOL)presented animated:(BOOL)animated;
+ (NSTimeInterval)presentationDuration;
// Full strip height (independent of presentation).
- (CGFloat)heightForWidth:(CGFloat)width;
@end
