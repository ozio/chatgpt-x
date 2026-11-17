// Small screens and adapters shared by the ChatGPT X controllers. They put the
// UI kit's screens (ios/ui) in front of the app's existing Core contract.
#import <UIKit/UIKit.h>
#import "../api/OR6APICore.h"
#import "OR6ChatRootController.h"

#ifdef __cplusplus
extern "C" {
#endif
// ☰: open or close the reveal drawer that contains `controller`.
void OR6ChatToggleDrawer(UIViewController *controller);
// «Выделить»: readable text with native selection; Copy goes through content.copy/content.select.
UIViewController *OR6ChatCreateSelectController(OR6APICore *core, NSDictionary *message, NSString *readableText);
// Saved look (text size, appearance): applied at launch, stored on change.
void OR6ChatApplySavedLook(void);
void OR6ChatSetAppearance(BOOL dark);
void OR6ChatSetTextSize(int size);       // RCTextSize 0…4
NSString *OR6TextSizeName(int size);     // "Обычный"…
// «Размер текста» (stage 8). With a Core the step goes through content.scale and
// the returned scale sets the kit text size (accessibility.large_text).
UIViewController *OR6ChatCreateTextSizeController(void);
UIViewController *OR6ChatCreateTextSizeControllerWithCore(OR6APICore *core);
// «Войти»: e-mail/password or Google (auth.begin through the host) when the host and
// Core offer them (stage 8); otherwise the host's ordinary -chatSignIn.
void OR6ChatSignIn(id<OR6ChatUIHost> host, OR6APICore *core, UIView *view);
// «Источники»: the answer's citations; `open` receives the chosen {title,url,host}.
void OR6ChatPresentSources(UIViewController *host, NSArray *sources, void (^open)(NSDictionary *source));
#ifdef __cplusplus
}
#endif

// Grouped checklist (appearance, stage): `choose` runs on a tap, the check moves.
@interface OR6ChatChoiceController : UITableViewController
- (id)initWithTitle:(NSString *)title options:(NSArray *)options selected:(NSUInteger)selected footer:(NSString *)footer choose:(void (^)(NSUInteger index))choose;
@end

// Full-screen composer editor (stage 7): Отмена / Готово; completion(nil) on cancel.
@interface OR6ChatTextEditorController : UIViewController
- (id)initWithTitle:(NSString *)title text:(NSString *)text completion:(void (^)(NSString *text))completion;
@property (nonatomic, assign) NSRange selection; // UTF-16 range; applied when shown, kept after Done/Cancel (stage 7: composer.editor.*)
@end
