// RCFilePartView — file produced in an answer (app.css .filecard): tile, name,
// size/status line, and one pill: Скачать (go) → progress → Открыть в…;
// expired files are dashed with Загрузить (stage 8) or plain "Недоступен".
#import "RCPartView.h"
#import "RCButton.h"

typedef enum { RCFileReady = 0, RCFileDownloading, RCFileSaved, RCFileExpired, RCFileUnavailable } RCFileState;

@interface RCFilePartView : RCPartView
@property (nonatomic, copy) NSString *fileName, *detail; // detail: "820 КБ", "Нет сети — загрузка прервана"…
@property (nonatomic, retain) UIImage *thumbnail; // local, already validated by the app
@property (nonatomic, assign) RCFileState state;
@property (nonatomic, assign) CGFloat progress;           // RCFileDownloading
@property (nonatomic, readonly) RCButton *actionButton;
@end
