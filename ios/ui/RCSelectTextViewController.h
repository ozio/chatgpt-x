// RCSelectTextViewController — «Выделение» (prototype selectText, stage 9): the
// answer or message as read-only selectable text on a card (current text size and
// appearance), a note how to select, and a bottom toolbar «Выделить всё» /
// «Копировать». Copy takes the selection, or the whole text when nothing is selected.
// The system callout's Copy is routed the same way. With a delegate the caller
// performs the copy (e.g. through its content.copy core path); without one the
// controller writes UIPasteboard itself and shows a «Скопировано» HUD.
#import <UIKit/UIKit.h>

@class RCSelectTextViewController;
@protocol RCSelectTextViewControllerDelegate <NSObject>
@optional
// The caller copies `text` (the selected substring or the whole text) and gives feedback.
- (void)selectTextController:(RCSelectTextViewController *)controller copyText:(NSString *)text;
// «Готово» (only when showsDoneButton). Without this the controller dismisses itself.
- (void)selectTextControllerDidFinish:(RCSelectTextViewController *)controller;
@end

@interface RCSelectTextViewController : UIViewController
- (id)initWithText:(NSString *)text;
@property (nonatomic, copy) NSString *text;              // plain text (no Markdown markers)
@property (nonatomic, copy) NSString *hint;              // note under the card; nil hides it
@property (nonatomic, assign) BOOL showsDoneButton;      // «Готово» on the right (modal use), default YES
@property (nonatomic, assign) id<RCSelectTextViewControllerDelegate> delegate;
@property (nonatomic, readonly) UITextView *textView;
@property (nonatomic, readonly) NSString *textToCopy;    // selection, or all text when nothing is selected
- (void)selectAll;
- (void)copySelection;                                   // same as the toolbar button
// Convenience: a jade navigation controller around the controller, ready for -presentViewController:.
+ (UINavigationController *)navigationControllerWithText:(NSString *)text delegate:(id<RCSelectTextViewControllerDelegate>)delegate;
@end
