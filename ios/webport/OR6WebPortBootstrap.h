#import <Foundation/Foundation.h>
// Call once on the main thread before UIApplicationMain / any WebView.
// A failed or partially initialized engine is never retried in this process.
BOOL OR6WebPortBootstrap(BOOL requireBundled);
NSDictionary *OR6WebPortDiagnostics(void);
NSDictionary *OR6WebPortResourceAudit(void);
