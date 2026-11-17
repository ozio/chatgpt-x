// RCShareLinkSheet — «Поделиться ссылкой» (prototype S.shareChat, stage 7): what a
// shared link means, a preview card of the conversation, the «Показывать моё имя»
// switch, and the link button through its states: «Создать ссылку» → «Создаю
// ссылку…» → the link with «Скопировать ссылку» / «Отправить…», or a failure note with
// «Повторить». The caller creates the link; nothing is sent from here.
// Before «Создать ссылку» the caller may read the chat first: Preparing («Проверяю чат…»,
// spinner, busy lamp, nothing tappable but «Готово») → Idle, or PreparationFailed (error lamp,
// «Проверить снова» only when preparationRetryAvailable; a retry asks the caller to READ again,
// never to create). Identifiers: chat.share.primary / .send / .open / .revoke / .status.
#import <UIKit/UIKit.h>

typedef enum { RCShareLinkIdle = 0, RCShareLinkCreating, RCShareLinkCreated, RCShareLinkFailed, RCShareLinkPreparing, RCShareLinkPreparationFailed } RCShareLinkState;

@class RCShareLinkSheet;
@protocol RCShareLinkSheetDelegate <NSObject>
- (void)shareLinkSheet:(RCShareLinkSheet *)sheet createLinkIncludingName:(BOOL)includeName;
@optional
- (void)shareLinkSheet:(RCShareLinkSheet *)sheet copyLink:(NSString *)link; // default: pasteboard + HUD
- (void)shareLinkSheet:(RCShareLinkSheet *)sheet shareLink:(NSString *)link;
- (void)shareLinkSheetDidFinish:(RCShareLinkSheet *)sheet;                 // without it: dismiss
- (void)shareLinkSheet:(RCShareLinkSheet *)sheet openLink:(NSString *)link;  // «Открыть снимок» (openAvailable)
- (void)shareLinkSheet:(RCShareLinkSheet *)sheet revokeLink:(NSString *)link; // «Удалить ссылку» (revokeAvailable); caller confirms
- (void)shareLinkSheetRetryPreparation:(RCShareLinkSheet *)sheet;           // «Проверить снова» (preparationRetryAvailable): a read only
@end

@interface RCShareLinkSheet : UIViewController
@property (nonatomic, copy) NSString *chatTitle, *chatMeta, *excerpt; // preview card
@property (nonatomic, assign) BOOL includeName;        // switch value
@property (nonatomic, assign) BOOL showsNameSwitch;    // default YES
@property (nonatomic, assign) RCShareLinkState state;
@property (nonatomic, copy) NSString *link;            // Created
@property (nonatomic, copy) NSString *failureText;     // Failed / PreparationFailed (nil: the kit's honest default)
@property (nonatomic, assign) BOOL preparationRetryAvailable; // PreparationFailed: «Проверить снова»
@property (nonatomic, assign) BOOL openAvailable;      // Created: read-only snapshot of the link (stage 7)
@property (nonatomic, assign) BOOL revokeAvailable;    // Created: red «Удалить ссылку»
@property (nonatomic, assign) id<RCShareLinkSheetDelegate> delegate;
+ (UINavigationController *)navigationControllerWithSheet:(RCShareLinkSheet *)sheet;
@end
