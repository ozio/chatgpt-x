// RCClarifyPartView — clarifying questions before an answer (app.css .clarify):
// "1 из 2" counter, single/multi-choice options with a jade check, own answer
// field, Пропустить / Далее → Ответить. Answered cards dim and lock.
#import "RCPartView.h"
#import "RCButton.h"

@interface RCClarifyQuestion : NSObject
+ (id)questionWithText:(NSString *)text options:(NSArray *)options multiple:(BOOL)multiple;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSArray *options;
@property (nonatomic, assign) BOOL multiple;
@property (nonatomic, assign) BOOL requiresAnswer; // hides Skip and requires a choice or nonempty own answer; default NO
@property (nonatomic, assign) BOOL ownAnswerHidden; // no «Свой вариант» field for this question (API: allowFreeText NO)
@end

@class RCClarifyPartView;
@protocol RCClarifyPartViewDelegate <RCPartViewDelegate>
@optional
// One line per question: "Вопрос ответ, ответ" (or "без разницы"), ready to send.
- (void)clarifyPart:(RCClarifyPartView *)part didFinishWithAnswer:(NSString *)answer;
// Structured answers, one per question in order: {"options": [NSNumber option indexes],
// "text": own answer or ""}. Called before -didFinishWithAnswer: when implemented.
- (void)clarifyPart:(RCClarifyPartView *)part didFinishWithSelections:(NSArray *)selections;
@end

@interface RCClarifyPartView : RCPartView <UITextFieldDelegate>
@property (nonatomic, copy) NSArray *questions; // RCClarifyQuestion
@property (nonatomic, readonly) NSUInteger currentIndex;
@property (nonatomic, readonly) BOOL answered;
@end
