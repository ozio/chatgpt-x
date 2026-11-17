// Automatic preview of a generated answer image (stage 7). Foundation/ImageIO only (no UIKit).
// Render never requests anything itself: -autoShowFile:… (the conversation's live, non-measuring
// row configuration) only queues an offer-state image with a visibility probe and returns the state
// to show (queued = loading). A later run-loop turn starts at most one queued image that is on
// screen now, through the same -showFile:… path as a tap; the next one starts when it settles.
// Gone parts leave the queue; an image is auto-started at most a few times per screen (an evicted
// thumbnail is re-decoded from its cached asset, never downloaded again); failed, unknown and
// unavailable images are never started automatically (a tap on Failed retries).
// The validated asset ID and a bounded ImageIO thumbnail are cached per Core (owner/credential
// generation): a repeated render or an in-session history reload uses the cache; a cached asset
// is revalidated (assets.status, current Core context) before its bytes are read again.
// The bytes come only from the trusted in-process resolver (the composition's exact current
// binding); no path or bytes travel through Core JSON.
// Unknown or cancelled downloads latch "download:<message>:<file>" (shared with
// OR6Chat7ImageExport) and are never replayed. -invalidate (background, owner change, teardown)
// cancels the request and drops every late reply and decode.
// state: offer | loading (also queued) | shown | failed (tap retries) | unknown | unavailable
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "OR6Chat7Models.h"

// Automatic display probe of one rendered image part: < 0 gone (the part left its window),
// 0 not on screen now, > 0 on screen. Runs on the main thread only while the image is queued.
typedef NSInteger (^OR6Chat7PreviewVisibility)(void);

#ifdef __cplusplus
extern "C" {
#endif
// Trusted composition host only (coordinator): exact current asset binding → bounded PNG/JPEG
// bytes, or nil. nil clears it (teardown).
void OR6Chat7SetImagePreviewResolver(NSData *(^resolver)(NSString *assetId));
BOOL OR6Chat7ImagePreviewAvailable(void);
// Trusted app-only bytes for a currently bound vault image; never a Core DTO.
NSData *OR6Chat7LoadedImageData(NSString *assetId);
// Pure local cache read; caller owns the bounded image. Never downloads.
CGImageRef OR6Chat7LocalThumbnail(NSString *identifier) CF_RETURNS_RETAINED;
// Bounded decode: PNG/JPEG only, at most 8 MB and 24 Mpx in, longest side <= maxPixels out.
CGImageRef OR6Chat7PreviewThumbnail(NSData *data, NSUInteger maxPixels) CF_RETURNS_RETAINED;
#ifdef __cplusplus
}
#endif

@interface OR6Chat7ImagePreview : NSObject
- (id)initWithCore:(OR6APICore *)core;
@property (nonatomic, assign) id<OR6Chat8ModelDelegate> delegate;
@property (nonatomic, readonly) BOOL busy;
@property (nonatomic, readonly) NSString *refusal; // busy | unresolved | invalid
@property (nonatomic, readonly) NSError *error;
// Pure reads (render and measuring): no request, no cache change.
- (NSString *)stateForFile:(NSString *)fileId message:(NSString *)messageId conversation:(NSString *)conversationId;
- (CGImageRef)imageForFile:(NSString *)fileId message:(NSString *)messageId conversation:(NSString *)conversationId;
- (NSString *)assetForFile:(NSString *)fileId message:(NSString *)messageId conversation:(NSString *)conversationId;
// Live render of one image part: queues an offer-state image (no request now) and returns the state
// the part shows. The same image again only replaces its probe; nothing is queued for failed/unknown.
- (NSString *)autoShowFile:(NSString *)fileId message:(NSString *)messageId conversation:(NSString *)conversationId visibility:(OR6Chat7PreviewVisibility)visibility;
// Explicit tap (and the automatic start): shown → nothing; cached asset → assets.status + resolver
// + decode; else one download.
- (BOOL)showFile:(NSString *)fileId message:(NSString *)messageId conversation:(NSString *)conversationId;
- (void)invalidate; // also empties the automatic queue
- (NSDictionary *)diagnostics;
@end
