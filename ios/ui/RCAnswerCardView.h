// RCAnswerCardView — an assistant answer (app.css .msg.asst .card): white card
// with the app-icon header, optional expandable reasoning row, body text,
// part views (e.g. RCPartPlaceholderView), cut-off note or "Продолжить ответ",
// and an RCActionBar. Long press: system Copy (+ "Выделить" when enabled).
#import <UIKit/UIKit.h>
#import "RCActionBar.h"
#import "RCMarkdownView.h"

typedef enum {
    RCAnswerDone = 0,   // finished: action bar, long-press menu
    RCAnswerThinking,   // reasoning running (busy lamp) or waiting dots
    RCAnswerStreaming,  // text arriving, blinking cursor
    RCAnswerCut         // interrupted: note, or Continue pill when available
} RCAnswerState;

typedef enum {
    RCAnswerTextRaw = 0,  // text shown as is (default)
    RCAnswerTextPlain,    // stage 10: Markdown markers removed
    RCAnswerTextMarkdown  // stage 9+: RCMarkdownView (lists, code, tables…)
} RCAnswerTextMode;

@class RCAnswerCardView;
@protocol RCAnswerCardViewDelegate <NSObject>
@optional
- (void)answerCard:(RCAnswerCardView *)card didSelectAction:(RCAnswerAction)action;
- (void)answerCardDidToggleReasoning:(RCAnswerCardView *)card; // height changed: relayout
- (void)answerCardDidTapContinue:(RCAnswerCardView *)card;
- (void)answerCardDidRequestSelect:(RCAnswerCardView *)card;
// Long-press Copy. Implement to route the copy yourself (e.g. through the app's
// content.copy); otherwise the card puts -readableText on the pasteboard.
- (void)answerCardDidRequestCopy:(RCAnswerCardView *)card;
// A link in the Markdown body was tapped (stage 9+). Validate before opening.
- (void)answerCard:(RCAnswerCardView *)card didSelectLinkURL:(NSURL *)url title:(NSString *)title;
@end

@interface RCAnswerCardView : UIView
@property (nonatomic, assign) RCAnswerState state;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, assign) RCAnswerTextMode textMode;
@property (nonatomic, assign) BOOL copyCodeEnabled;      // "Копировать" on code blocks (stage 7)
@property (nonatomic, assign) id<RCCodeBlockViewDelegate> codeDelegate;
@property (nonatomic, copy) NSString *assistantName;    // "ChatGPT"
@property (nonatomic, assign) BOOL showsReasoning;      // stage 8+: reasoning status row
@property (nonatomic, copy) NSString *reasoningTitle;   // "Думаю" / "Думал 4 с · искал в интернете"
@property (nonatomic, copy) NSArray *reasoningSteps;    // NSString list, shown when expanded
@property (nonatomic, assign) BOOL reasoningExpanded;
@property (nonatomic, copy) NSArray *partViews;         // views with -heightForWidth: or sizeThatFits:
@property (nonatomic, assign) BOOL continueAvailable;   // Cut: pill instead of the note
@property (nonatomic, copy) NSString *cutNoteText;      // "Ответ не завершён"
@property (nonatomic, assign) BOOL copyMenuEnabled;     // long-press callout (stage 9+), default YES
@property (nonatomic, assign) BOOL selectMenuEnabled;   // adds "Выделить"
@property (nonatomic, copy) NSSet *citationURLs;
@property (nonatomic, readonly) RCActionBar *actionBar; // configure actions/sources/pager on it
@property (nonatomic, assign) id<RCAnswerCardViewDelegate> delegate;
// What Copy copies: the answer without Markdown markers (code kept verbatim,
// links as "title (url)"); the raw text in RCAnswerTextRaw mode.
- (NSString *)readableText;
- (CGFloat)heightForWidth:(CGFloat)width; // full row incl. 12 pt gap below
@end
