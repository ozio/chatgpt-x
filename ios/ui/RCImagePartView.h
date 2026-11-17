// RCImagePartView — generated image in an answer (app.css .imgcard): 230 pt art,
// "Создаю изображение…" with progress while making, Save/Send pills when done
// (stage 7). artButton opens the viewer (stage 6).
// previewState (stage 7): an image that stays on the account until the user asks for it.
// Offer "Нажмите, чтобы показать" (art is the button) → Loading (barber pole) → Shown (the
// real picture; the art is no longer a button) or Failed (tap retries), Unknown (the
// download result is not known; nothing is repeated), Unavailable (no preview here).
// The app owns the download; the view only reports artButton taps.
#import "RCPartView.h"
#import "RCButton.h"
#import "RCProgressView.h"

typedef enum {
    RCImagePreviewNone = 0,     // plain art/placeholder; artButton = viewer (stage 6)
    RCImagePreviewOffer,        // placeholder + "Нажмите, чтобы показать"
    RCImagePreviewLoading,      // "Загружаю изображение…", indeterminate bar, art not tappable
    RCImagePreviewShown,        // the downloaded picture, optional viewer tap
    RCImagePreviewFailed,       // "Не удалось показать изображение", tap retries
    RCImagePreviewUnknown,      // "Результат загрузки неизвестен", not tappable
    RCImagePreviewUnavailable   // "Предпросмотр недоступен", not tappable
} RCImagePreviewState;

@interface RCImagePartView : RCPartView
@property (nonatomic, retain) UIImage *image;          // nil: neutral placeholder art
@property (nonatomic, assign) BOOL making;
@property (nonatomic, assign) CGFloat progress;
@property (nonatomic, assign) BOOL viewerAvailable;    // Shown art opens the existing viewer when the app supplies a target
@property (nonatomic, assign) BOOL actionsEnabled;     // Сохранить / Отправить
@property (nonatomic, assign) RCImagePreviewState previewState; // ignored while making
@property (nonatomic, readonly) RCButton *saveButton, *sendButton;
@property (nonatomic, readonly) UIButton *artButton;
@end
