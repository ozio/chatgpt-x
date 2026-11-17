#import <Foundation/Foundation.h>

/* Foundation-only, deliberately small Markdown renderer. No HTML is interpreted.
 * Every row has a bounded amount of text; the caller can recycle native cells.
 * Styles are UTF-16 ranges into text. Link/image actions are separate rows. */
NSArray *OR6ContentBlocks(NSString *source);
NSArray *OR6PlainContentBlocks(NSString *source);
NSString *OR6ContentSafeURL(NSString *value, BOOL image);
NSData *OR6ContentDecodeBase64(NSString *value, NSUInteger maximumBytes);
// Vendor citation markers → numbered Markdown links to validated source rows.
// Incomplete markers are held back during streaming; unresolved locators are never printed.
NSString *OR6ContentResolveCitations(NSString *source, NSArray *sources);
// Layout markup of "visual" answers (<row>, <box>, <Entity/>, <AsyncImage/>) → plain Markdown.
NSString *OR6ContentFlattenVisualMarkup(NSString *source);
