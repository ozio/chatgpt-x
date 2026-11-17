#import <Foundation/Foundation.h>
// A load lease belongs to one real public document and one WebView request.
// It never includes account credentials. End cancels late callbacks and leaves
// subsequent leases independent, including after background/context changes.
@interface OR6StockDocumentLoad:NSObject
- (NSMutableURLRequest*)request;
- (NSDictionary*)diagnostics;
- (void)cancel;
@end
@interface OR6StockDocumentProtocol:NSURLProtocol
+ (OR6StockDocumentLoad*)beginWithRoots:(NSString*)roots userAgent:(NSString*)agent;
@end
