#import <Foundation/Foundation.h>
@class OR6Files;
@interface OR6API6FAssets:NSObject
- (id)initWithDirectory:(NSString*)directory vault:(OR6Files*)vault inbox:(NSString*)inbox error:(NSError**)error;
- (NSDictionary*)storePreview:(NSData*)bytes mediaType:(NSString*)mediaType context:(NSDictionary*)context error:(NSError**)error;
- (NSURL*)previewURL:(NSString*)assetId context:(NSDictionary*)context error:(NSError**)error;
- (BOOL)removePreview:(NSString*)assetId context:(NSDictionary*)context error:(NSError**)error;
// Trusted caller must supply only its current-scope private journal candidate.
// This verifies the real vault descriptor/payload; it does not authorize public IDs.
- (NSDictionary*)pdfAsset:(NSString*)assetId context:(NSDictionary*)context error:(NSError**)error;
- (NSDictionary*)storePDF:(NSData*)bytes context:(NSDictionary*)context error:(NSError**)error;
- (NSArray*)takeExportURLs:(NSString*)token context:(NSDictionary*)context;
- (NSDictionary*)stageScanPages:(NSArray*)pages context:(NSDictionary*)context error:(NSError**)error;
- (NSDictionary*)scanStatus:(NSString*)draftId context:(NSDictionary*)context error:(NSError**)error;
- (NSArray*)takeScanPages:(NSString*)draftId context:(NSDictionary*)context error:(NSError**)error;
- (BOOL)discardScan:(NSString*)draftId context:(NSDictionary*)context error:(NSError**)error;
- (NSNumber*)autoPreference:(NSDictionary*)context error:(NSError**)error;
- (BOOL)setAutoPreference:(BOOL)value context:(NSDictionary*)context error:(NSError**)error;
- (void)deactivate;
@end
