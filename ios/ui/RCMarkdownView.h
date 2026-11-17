// RCMarkdownView — answer body as native views (app.css .md): paragraphs with
// bold/italic/inline code/links, ## and ### headings, bullet and numbered lists,
// quotes, thematic rules, tables and fenced code (RCCodeBlockView). Text size follows RCTheme;
// colours follow the appearance. Stage 10 shows +plainTextFromMarkdown: instead.
#import <UIKit/UIKit.h>
#import "RCCodeBlockView.h"
@class RCMarkdownView;
@protocol RCMarkdownViewDelegate <NSObject>
@optional
// A link was tapped. A tap on a paragraph/list item/cell with one link selects it;
// with several, the view first asks which one (action sheet). Validate the URL
// before opening it; the view only accepts http, https and mailto.
- (void)markdownView:(RCMarkdownView *)view didSelectLinkURL:(NSURL *)url title:(NSString *)title;
@end

@interface RCMarkdownView : UIView
@property (nonatomic, copy) NSString *markdown;
@property (nonatomic, copy) NSSet *citationURLs; // source links use compact site labels
@property (nonatomic, assign) BOOL copyCodeEnabled;   // "Копировать" in code headers (stage 7)
@property (nonatomic, assign) BOOL showsCursor;       // streaming: ▌ after the last text
@property (nonatomic, assign) BOOL cursorOn;          // blink phase (cheap: recolours one label)
@property (nonatomic, assign) id<RCCodeBlockViewDelegate> codeDelegate;
@property (nonatomic, assign) id<RCMarkdownViewDelegate> linkDelegate; // nil: links are styled only
@property (nonatomic, readonly) NSArray *links; // NSDictionary {title, url} in reading order
- (CGFloat)heightForWidth:(CGFloat)width;
- (void)reload; // re-render after text size or appearance changes
// Markers removed, as the prototype's stage-10 renderer (S.plain).
+ (NSString *)plainTextFromMarkdown:(NSString *)markdown;
// Readable text for Copy: no Markdown markers, code kept verbatim, links as
// "title (url)", list bullets "•", table cells separated by tabs.
+ (NSString *)readableTextFromMarkdown:(NSString *)markdown;
@end
