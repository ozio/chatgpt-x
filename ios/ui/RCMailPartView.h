// RCMailPartView — editable e-mail draft in an answer (app.css .mailcard):
// Кому / Копия / Тема fields, body, footer with Скопировать and (stage 6) Отправить….
#import "RCPartView.h"
#import "RCButton.h"

@interface RCMailPartView : RCPartView <UITextFieldDelegate>
@property (nonatomic, copy) NSString *to, *cc, *subject, *body;
@property (nonatomic, assign) BOOL sendEnabled;
@property (nonatomic, readonly) RCButton *clipboardButton, *sendButton; // Скопировать, Отправить…
@end
