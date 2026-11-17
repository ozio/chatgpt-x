// RCCodeBlockView — fenced code in an answer (app.css .code): dark green panel,
// uppercase language header with optional "Копировать" (stage 7), monospaced body
// that scrolls sideways, light keyword/string/comment highlighting.
#import <UIKit/UIKit.h>

@class RCCodeBlockView;
@protocol RCCodeBlockViewDelegate <NSObject>
@optional
- (void)codeBlockViewDidCopy:(RCCodeBlockView *)view; // text is already on the pasteboard
// «Копировать» tapped. Return NO to copy yourself (e.g. the app's content.copyCode); the kit
// then leaves the pasteboard alone and does not call -codeBlockViewDidCopy:.
- (BOOL)codeBlockViewShouldCopy:(RCCodeBlockView *)view;
@end

@interface RCCodeBlockView : UIView
- (id)initWithCode:(NSString *)code language:(NSString *)language;
@property (nonatomic, readonly) NSString *code;
@property (nonatomic, assign) BOOL copyEnabled;
// Zero-based position among the non-empty fenced blocks of the Markdown it came from
// (set by RCMarkdownView); -1 for an empty block or a block made outside Markdown.
@property (nonatomic, assign) NSInteger blockIndex;
@property (nonatomic, assign) id<RCCodeBlockViewDelegate> delegate;
- (CGFloat)heightForWidth:(CGFloat)width;
+ (UIFont *)codeFont; // Menlo when present, Courier on iOS 6
@end
