// RCTranslateViewController — «Перевод» (prototype S.translate, stage 8; languages
// and sharing stage 7): a jade toolbar with the language pair (pills + swap, or a
// fixed «Определить → English»), the source box with «Перевести», the result card
// (spinner while busy, then text, «Копировать» / «Поделиться»), and the note that
// translations are not kept in the chat history. The caller translates.
#import <UIKit/UIKit.h>

@class RCTranslateViewController;
@protocol RCTranslateViewControllerDelegate <NSObject>
- (void)translate:(RCTranslateViewController *)controller translateText:(NSString *)text;
@optional
- (void)translateDidTapSourceLanguage:(RCTranslateViewController *)controller; // caller shows a picker
- (void)translateDidTapTargetLanguage:(RCTranslateViewController *)controller;
- (void)translateDidSwapLanguages:(RCTranslateViewController *)controller;    // after the swap
- (void)translate:(RCTranslateViewController *)controller copyResult:(NSString *)text; // default: pasteboard + HUD
- (void)translate:(RCTranslateViewController *)controller shareResult:(NSString *)text;
@end

@interface RCTranslateViewController : UIViewController <UITextViewDelegate>
@property (nonatomic, copy) NSString *sourceLanguage, *targetLanguage; // «Определить», «English»
@property (nonatomic, assign) BOOL languagesEditable;  // pills + swap (stage 7); NO: fixed pair with →
@property (nonatomic, copy) NSString *sourceText;
@property (nonatomic, copy) NSString *detectedText;    // «Определён: русский» under the source
@property (nonatomic, copy) NSString *resultText;      // nil hides the result card (unless busy)
@property (nonatomic, assign) BOOL busy;               // spinner in the result card
@property (nonatomic, copy) NSString *errorText;       // red line in the result card
@property (nonatomic, assign) BOOL shareAvailable;     // «Копировать» / «Поделиться» (stage 7)
@property (nonatomic, assign) id<RCTranslateViewControllerDelegate> delegate;
@end
