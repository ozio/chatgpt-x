// RCDictationView — dictation row that replaces the composer row (app.css .rec):
// pulsing red dot, 0:00 timer, live wave (or streamed words, stage 7), Отмена
// (stage 8) and Готово; then "Распознаю…" and, on failure, a red note with
// Отмена / Повторить (stage 8). Times and audio come from the caller.
#import <UIKit/UIKit.h>
#import "RCButton.h"

typedef enum { RCDictationRecording = 0, RCDictationRecognising, RCDictationFailed } RCDictationState;

@interface RCDictationView : UIView
@property (nonatomic, assign) RCDictationState state;
@property (nonatomic, assign) NSTimeInterval elapsed;     // shown as m:ss
@property (nonatomic, copy) NSString *liveText;           // non-nil: streamed words instead of the wave
@property (nonatomic, assign) BOOL cancelAvailable;
@property (nonatomic, assign) BOOL cancelsRecognition;  // Отмена stays during «Распознаю…» (stage 8: cancel aborts the caller's recognition)
@property (nonatomic, copy) NSString *failureText;        // failed note; nil: «Не распознано. Запись сохранена.»
@property (nonatomic, readonly) RCButton *cancelButton, *doneButton; // done reads "Повторить" when failed
- (void)setLevel:(CGFloat)level;                           // 0…1 input level → wave (random if never called)
@end
