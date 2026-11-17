// RCVoiceViewController — turn-based voice conversation (app.css .vscreen, stage 8):
// deep green radial backdrop, the glossy jade orb (breathes while thinking, pulses
// while speaking, dims when muted, turns amber while reconnecting), state and hint
// lines, an optional transcript, and round buttons Микрофон / Звук / Завершить.
// Turn-based: the caller records, sends, plays; this screen only shows and reports taps.
#import <UIKit/UIKit.h>

typedef enum {
    RCVoiceListening = 0, // «Слушаю» — tap the orb to finish the phrase
    RCVoiceSending,       // «Отправляю…»
    RCVoiceThinking,      // «Думаю…»
    RCVoiceSpeaking,      // «Говорю» — tap the orb to interrupt (when interruptAvailable)
    RCVoiceReconnecting,  // amber orb: «Плохая связь», the last phrase is kept and sent once
    RCVoiceError          // dim orb, caller's text: e.g. limit reached / unavailable
} RCVoiceState;

@class RCVoiceViewController;
@protocol RCVoiceViewControllerDelegate <NSObject>
- (void)voiceDidTapOrb:(RCVoiceViewController *)voice;
- (void)voiceDidEnd:(RCVoiceViewController *)voice; // «Завершить»: the caller dismisses
@optional
- (void)voice:(RCVoiceViewController *)voice didChangeMuted:(BOOL)muted;
- (void)voice:(RCVoiceViewController *)voice didChangeSoundOff:(BOOL)soundOff;
- (void)voiceDidTapSettings:(RCVoiceViewController *)voice;
@end

@interface RCVoiceViewController : UIViewController
@property (nonatomic, assign) RCVoiceState state;
@property (nonatomic, assign) BOOL muted;                 // mic off (listening shows «Микрофон выключен»)
@property (nonatomic, assign) BOOL soundOff;
@property (nonatomic, assign) BOOL showsMuteControls;     // Микрофон / Звук buttons (voice.mute)
@property (nonatomic, assign) BOOL interruptAvailable;    // hint while speaking
@property (nonatomic, assign) BOOL showsTranscriptToggle; // «Текст» bar button (voice.transcript)
@property (nonatomic, assign) BOOL transcriptShown;
@property (nonatomic, assign) BOOL showsSettings;         // sliders glyph at top right
@property (nonatomic, copy) NSString *stateText, *hintText; // override the default lines (nil: defaults)
@property (nonatomic, copy) NSString *noticeText;         // box instead of the transcript (limit reached)
@property (nonatomic, assign) id<RCVoiceViewControllerDelegate> delegate;
- (void)appendTranscriptLine:(NSString *)text speaker:(NSString *)speaker; // «Вы», «ChatGPT»
- (void)clearTranscript;
@end
