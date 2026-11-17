// RCMarkdownText — Foundation-only text helpers of RCMarkdownView (host-testable).
// Backslash escapes: "\" before ASCII punctuation (!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~) shows the
// character itself and never starts emphasis, code or a link. Inside `inline code` and ``` fences
// a backslash stays literal (code and copyCode/source text are never changed).
#import <Foundation/Foundation.h>
#ifdef __cplusplus
extern "C" {
#endif
BOOL RCMarkdownIsRule(NSString *line); // a standalone thematic separator, outside fences
BOOL RCMarkdownEscapable(unichar c);                                   // ASCII punctuation
NSRange RCMarkdownFindUnescaped(NSString *s, NSString *token, NSRange range); // token not preceded by an odd run of '\'
NSString *RCMarkdownUnescape(NSString *s);                             // "\." → "." (text outside code only)
NSString *RCMarkdownPlainText(NSString *markdown);                     // +[RCMarkdownView plainTextFromMarkdown:]
NSString *RCMarkdownReadableText(NSString *markdown);                  // +[RCMarkdownView readableTextFromMarkdown:]
#ifdef __cplusplus
}
#endif
