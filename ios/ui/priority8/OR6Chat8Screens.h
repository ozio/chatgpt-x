// UIKit glue for the API 8/10 functions, built only from the ChatGPT X kit
// (RCTranslateViewController, RCComposerAttachment, RCFilePartView, stock
// action sheets) and the app's OR6ChatChoiceController / kit-styled grouped tables. No network here: every
// action goes through the Foundation models in OR6Chat8Models.
#import <UIKit/UIKit.h>
#import "OR6Chat8Models.h"
#import "RCTranslateViewController.h"
#import "RCFilePartView.h"

#ifdef __cplusplus
extern "C" {
#endif
// Stock action sheet with a block; buttons: index 0… in order, cancel → -1.
void OR6Chat8ShowSheet(UIView *view, NSString *title, NSArray *buttons, NSString *destructive, void (^chosen)(NSInteger index, NSString *title));
// «Войти»: e-mail and password or Google on the ordinary service page (MFA is entered there).
void OR6Chat8ChooseSignIn(UIView *view, BOOL email, BOOL google, void (^choose)(NSString *provider));
// Draft tray items (OR6Chat8Attachments.items) → RCComposerAttachment.
NSArray *OR6Chat8TrayAttachments(NSArray *items);
UIImage *OR6Chat8LocalThumbnail(NSString *identifier);
// Honest one-line status of a tray item for its action sheet.
NSString *OR6Chat8AttachmentStatus(NSDictionary *item);
// Sent-bubble attachments (row "attachments"/"files"/"images") → RCComposerAttachment.
NSArray *OR6Chat8BubbleAttachments(NSDictionary *row);
// RCFilePartView for an answer file and its download state.
RCFilePartView *OR6Chat8FilePart(NSDictionary *file, NSDictionary *download);
// «Модель»: «По умолчанию», then the catalog's versions, the shown version's modes and the
// chosen mode's thinking efforts (each a models.select). `allow` runs before every change
// (NO: refused, e.g. while a safe Retry keeps the reserved draft's options).
UIViewController *OR6Chat8CreateModelPicker(OR6Chat8Catalog *catalog, BOOL (^allow)(void));
// Languages sent as targetLanguage (English names) with their display names.
NSArray *OR6Chat8Languages(void);           // [{name, title}]
NSString *OR6Chat8DefaultTargetLanguage(void); // the UI language (Russian or English)
#ifdef __cplusplus
}
#endif

// «Перевод» on the kit screen with translation.translate. Source: «Определить»
// (null sourceLanguage) or a language at stage 7; the result is not kept in a chat.
@interface OR6Chat8TranslateController : RCTranslateViewController
- (id)initWithCore:(OR6APICore *)core text:(NSString *)text;
@property (nonatomic, readonly) OR6Chat8Translation *translation;
@end
