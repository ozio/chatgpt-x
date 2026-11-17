#import "OR6Chat7ImagePreview.h"
#import <ImageIO/ImageIO.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>

static NSData *(^gPreviewResolver)(NSString *);
void OR6Chat7SetImagePreviewResolver(NSData *(^r)(NSString *)) { [gPreviewResolver release]; gPreviewResolver = [r copy]; }
NSData *OR6Chat7LoadedImageData(NSString *assetId) { return gPreviewResolver && [assetId isKindOfClass:NSString.class] ? gPreviewResolver(assetId) : nil; }
BOOL OR6Chat7ImagePreviewAvailable(void) { return gPreviewResolver != nil; }

CGImageRef OR6Chat7PreviewThumbnail(NSData *data, NSUInteger maxPixels) {
    if (![data isKindOfClass:NSData.class] || !data.length || data.length > 8 * 1024 * 1024 || maxPixels < 16 || maxPixels > 2048) return NULL;
    CGImageSourceRef src = CGImageSourceCreateWithData((CFDataRef)data, (CFDictionaryRef)@{(id)kCGImageSourceShouldCache: @NO});
    if (!src) return NULL;
    CGImageRef out = NULL; NSString *type = (NSString *)CGImageSourceGetType(src);
    if (CGImageSourceGetCount(src) == 1 && ([type isEqual:@"public.png"] || [type isEqual:@"public.jpeg"])) {
        NSDictionary *p = [(NSDictionary *)CGImageSourceCopyPropertiesAtIndex(src, 0, NULL) autorelease];
        double w = [p[(id)kCGImagePropertyPixelWidth] doubleValue], h = [p[(id)kCGImagePropertyPixelHeight] doubleValue];
        // Header bounds before any pixel is decoded: no full-size bitmap of an oversized image.
        if (w >= 1 && h >= 1 && w <= 8192 && h <= 8192 && w * h <= 24e6)
            out = CGImageSourceCreateThumbnailAtIndex(src, 0, (CFDictionaryRef)@{(id)kCGImageSourceCreateThumbnailFromImageAlways: @YES, (id)kCGImageSourceCreateThumbnailWithTransform: @YES,
                                                                                (id)kCGImageSourceThumbnailMaxPixelSize: @(maxPixels), (id)kCGImageSourceShouldCache: @NO});
        if (out && (CGImageGetWidth(out) > maxPixels || CGImageGetHeight(out) > maxPixels)) { CGImageRelease(out); out = NULL; }
    }
    CFRelease(src);
    return out;
}

CGImageRef OR6Chat7LocalThumbnail(NSString *identifier) {
 if(![identifier isKindOfClass:NSString.class]||!identifier.length||identifier.length>128||!gPreviewResolver)return NULL;
 return OR6Chat7PreviewThumbnail(gPreviewResolver(identifier),160);
}

#pragma mark - Per-Core store

// One store per Core instance (associated object): the cache lives as long as the app's Core
// and is dropped wholesale when the owner/credential generation changes.
@interface OR6Chat7PreviewStore : NSObject { @public NSUInteger generation, downloadStarts; // downloadStarts: every assets.download dispatched on this Core (kept across owner changes)
 NSMutableDictionary *assets, *images, *states; NSMutableArray *assetOrder, *imageOrder; NSMutableSet *inflight; }
@end
@implementation OR6Chat7PreviewStore
- (id)init { if ((self = [super init])) { assets = [NSMutableDictionary new]; images = [NSMutableDictionary new]; states = [NSMutableDictionary new]; assetOrder = [NSMutableArray new]; imageOrder = [NSMutableArray new]; inflight = [NSMutableSet new]; } return self; }
- (void)sync:(NSUInteger)gen { if (gen == generation) return; generation = gen; [assets removeAllObjects]; [images removeAllObjects]; [states removeAllObjects]; [assetOrder removeAllObjects]; [imageOrder removeAllObjects]; [inflight removeAllObjects]; }
- (void)forgetAsset:(NSArray *)k { [assets removeObjectForKey:k]; [assetOrder removeObject:k]; [images removeObjectForKey:k]; [imageOrder removeObject:k]; }
- (void)setAsset:(NSString *)a key:(NSArray *)k { if (!assets[k]) [assetOrder addObject:k]; assets[k] = a; while (assetOrder.count > 64) [self forgetAsset:assetOrder[0]]; } // a shown thumbnail always has its asset
// Thumbnails are at most 720 px: six of them stay in memory; an evicted one is decoded again
// from the cached asset (revalidated), never downloaded again.
- (void)setImage:(CGImageRef)cg key:(NSArray *)k { [imageOrder removeObject:k]; [imageOrder addObject:k]; images[k] = (id)cg; while (imageOrder.count > 6) { [images removeObjectForKey:imageOrder[0]]; [imageOrder removeObjectAtIndex:0]; } }
- (void)dealloc { [assets release]; [images release]; [states release]; [assetOrder release]; [imageOrder release]; [inflight release]; [super dealloc]; }
@end
static char gStoreKey;
static OR6Chat7PreviewStore *Store(OR6APICore *core, BOOL create) {
    OR6Chat7PreviewStore *s = core ? objc_getAssociatedObject(core, &gStoreKey) : nil;
    if (!s && create && core) { s = [[[OR6Chat7PreviewStore alloc] init] autorelease]; s->generation = OR6Chat7Generation(core); objc_setAssociatedObject(core, &gStoreKey, s, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    return s;
}

#pragma mark - Preview

// Automatic display: an image is started automatically at most kAutoLimit times per screen (thumbnail
// evictions), a part without a window is given kAutoGrace seconds to appear, and queued parts that are
// not on screen are probed again every kAutoPoll seconds (local geometry only, never a request).
static const NSUInteger kAutoLimit = 8; static const NSTimeInterval kAutoGrace = 2, kAutoPoll = .5;
@interface OR6Chat7ImagePreview () { OR6APICore *_core; OR6Chat7AssetGate *_gate; id<OR6APITask> _task; NSUInteger _life; NSArray *_loading; NSString *_refusal; NSError *_error; BOOL _downloading; NSUInteger _downloadStarts;
 NSMutableArray *_wanted; NSMutableDictionary *_autoStarts, *_retryAt; NSUInteger _autoTotal; BOOL _pumpScheduled, _pumpSoon; } // _wanted: @[key, probe, queued-at], oldest first
@end
@implementation OR6Chat7ImagePreview
@synthesize delegate = _delegate, refusal = _refusal, error = _error;
- (id)initWithCore:(OR6APICore *)core { if ((self = [super init])) { _core = [core retain]; _gate = [[OR6Chat7AssetGate alloc] initWithCore:core]; _wanted = [NSMutableArray new]; _autoStarts = [NSMutableDictionary new]; _retryAt = [NSMutableDictionary new]; } return self; }
- (BOOL)busy { return _loading != nil; }
static BOOL Part(NSString *s) { return [s isKindOfClass:NSString.class] && s.length && s.length <= 256; }
static NSArray *Key(NSString *f, NSString *m, NSString *c) { return f && m && c && Part(f) && Part(m) && Part(c) ? @[c, m, f] : nil; }
static NSString *Latch(NSArray *k) { return [NSString stringWithFormat:@"download:%@:%@", k[1], k[2]]; } // OR6Chat7ImageExport's key
- (OR6Chat7PreviewStore *)current { OR6Chat7PreviewStore *s = Store(_core, NO); return s && s->generation == OR6Chat7Generation(_core) ? s : nil; } // read-only view

- (NSUInteger)queued:(NSArray *)k { NSUInteger i = 0; for (NSArray *e in _wanted) { if ([e[0] isEqual:k]) return i; i++; } return NSNotFound; }
- (NSString *)stateForFile:(NSString *)f message:(NSString *)m conversation:(NSString *)c {
    NSArray *k = Key(f, m, c); if (!k) return @"unavailable";
    NSString *st = [self modelState:k];
    return [st isEqual:@"offer"] && [self queued:k] != NSNotFound ? @"loading" : st; // queued for the automatic start: shown as loading
}
- (NSString *)modelState:(NSArray *)k {
    OR6Chat7PreviewStore *s = [self current];
    if ([_loading isEqual:k] || (s && [s->inflight containsObject:k])) return @"loading";
    if (s && s->images[k]) return @"shown";
    if (OR6Chat7IsUnresolved(Latch(k))) return @"unknown";
    return (s ? s->states[k] : nil) ?: @"offer";
}
- (CGImageRef)imageForFile:(NSString *)f message:(NSString *)m conversation:(NSString *)c { NSArray *k = Key(f, m, c); OR6Chat7PreviewStore *s = [self current]; return k && s ? (CGImageRef)s->images[k] : NULL; }
- (NSString *)assetForFile:(NSString *)f message:(NSString *)m conversation:(NSString *)c { NSArray *k = Key(f, m, c); OR6Chat7PreviewStore *s = [self current]; return k && s ? s->assets[k] : nil; }

- (BOOL)refuse:(NSString *)why { [_refusal release]; _refusal = [why copy]; return NO; }
- (void)changed { [[self retain] autorelease]; [_delegate chat8ModelChanged:self]; }
- (void)end:(NSArray *)k state:(NSString *)state error:(NSError *)e {
    OR6Chat7PreviewStore *s = Store(_core, YES); [s->inflight removeObject:k];
    if (state) s->states[k] = state; else [s->states removeObjectForKey:k];
    [_error release]; _error = [e retain]; [_loading release]; _loading = nil; _downloading = NO; [_task release]; _task = nil;
    [self changed];
    if (_wanted.count) [self schedulePump:0]; // the next queued image, on a later turn
}

#pragma mark Automatic display

- (NSString *)autoShowFile:(NSString *)f message:(NSString *)m conversation:(NSString *)c visibility:(OR6Chat7PreviewVisibility)probe {
    NSArray *k = Key(f, m, c); if (!k || !_core || !gPreviewResolver || !probe) return @"unavailable";
    NSString *st = [self modelState:k];
    BOOL watch = [st isEqual:@"loading"] && ![_loading isEqual:k]; // another screen's download: re-rendered here when it settles
    if (![st isEqual:@"offer"] && !watch) return st; // shown, ours loading, failed, unknown, unavailable: never started automatically
    if (!watch) {
        OR6Chat7PreviewStore *s = [self current];
        if (!(s && s->assets[k]) && !OR6Chat8Supports(_core, OR6Chat8FDownload)) return @"unavailable"; // -showFile: would refuse
        if ([_autoStarts[k] unsignedIntegerValue] >= kAutoLimit) return @"offer"; // storm breaker: the tap stays
    }
    NSUInteger i = [self queued:k]; if (i != NSNotFound) [_wanted removeObjectAtIndex:i]; // a re-render replaces the probe
    [_wanted addObject:@[k, [[probe copy] autorelease], @(CFAbsoluteTimeGetCurrent())]];
    [self schedulePump:0]; // never inside the render that queued it
    return @"loading";
}
- (void)retryLater:(NSArray *)k { _retryAt[k] = @(CFAbsoluteTimeGetCurrent() + 1.5); } // still bounded by kAutoLimit
- (void)schedulePump:(NSTimeInterval)delay {
    if (_pumpScheduled) { if (delay > 0 || _pumpSoon) return; [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(pump) object:nil]; }
    _pumpScheduled = YES; _pumpSoon = delay <= 0;
    [self performSelector:@selector(pump) withObject:nil afterDelay:delay]; // default mode: waits while the user drags the list
}
// Drops settled and gone parts, starts at most one on-screen queued image (newest part first) when
// this screen is idle, and probes again later only while queued parts wait off screen.
- (void)pump {
    _pumpScheduled = NO; if (!_wanted.count) return;
    NSArray *snapshot = [[_wanted copy] autorelease]; CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    NSMutableArray *drop = [NSMutableArray array]; NSArray *next = nil; BOOL wait = NO, settled = NO;
    for (NSArray *e in snapshot.reverseObjectEnumerator) {
        NSArray *k = e[0]; NSString *st = [self modelState:k];
        if ([st isEqual:@"loading"]) { if ([_loading isEqual:k]) [drop addObject:e]; else wait = YES; continue; } // ours (a tap) reports itself
        if (![st isEqual:@"offer"]) { [drop addObject:e]; settled = YES; continue; } // settled elsewhere: re-render the part
        NSInteger v = ((OR6Chat7PreviewVisibility)e[1])();
        if (v < 0 && now - [e[2] doubleValue] > kAutoGrace) { [drop addObject:e]; continue; } // left its window: a later render queues it again
        if (v <= 0 || [_retryAt[k] doubleValue] > now) { wait = YES; continue; } // off screen, or a stale-context retry not due yet
        if (!next && !_loading && [_autoStarts[k] unsignedIntegerValue] < kAutoLimit) next = e;
    }
    for (NSArray *e in drop) [_wanted removeObjectIdenticalTo:e];
    if (next) {
        NSArray *k = next[0]; [_wanted removeObjectIdenticalTo:next];
        _autoStarts[k] = @([_autoStarts[k] unsignedIntegerValue] + 1); _autoTotal++;
        if (![self showFile:k[2] message:k[1] conversation:k[0]]) { _autoStarts[k] = @(kAutoLimit); settled = YES; } // refused: left to an explicit tap
    }
    if (settled) [self changed];
    if (wait && _wanted.count) [self schedulePump:kAutoPoll];
}

- (BOOL)showFile:(NSString *)f message:(NSString *)m conversation:(NSString *)c {
    [_refusal release]; _refusal = nil;
    NSArray *k = Key(f, m, c); if (!k || !_core || !gPreviewResolver) return [self refuse:@"invalid"];
    NSUInteger gen = OR6Chat7Generation(_core); OR6Chat7PreviewStore *s = Store(_core, YES); [s sync:gen];
    if (_loading || [s->inflight containsObject:k]) return [self refuse:@"busy"];
    if (s->images[k]) return YES; // already shown: nothing to do
    NSString *asset = s->assets[k];
    if (!asset && OR6Chat7IsUnresolved(Latch(k))) return [self refuse:@"unresolved"]; // an unknown download is never replayed
    if (!asset && !OR6Chat8Supports(_core, OR6Chat8FDownload)) return [self refuse:@"invalid"]; // the API8 download capability (as OR6Chat7ImageExport)
    NSUInteger life = ++_life; _loading = [k retain]; [s->inflight addObject:k]; [s->states removeObjectForKey:k];
    if (asset) { // cached vault asset: revalidated for this owner in the current context before its bytes are read
        if (![_gate revalidate:asset completion:^(NSDictionary *st, NSError *e) {
            (void)st; if (life != _life) return;
            if (gen != OR6Chat7Generation(_core)) { [self end:k state:@"failed" error:OR6APIError(@"stale_context", @"none")]; return; }
            if (e) { if ([@[@"not_found", @"unavailable", @"conflict"] containsObject:e.userInfo[@"code"] ?: @""]) [Store(_core, YES) forgetAsset:k]; [self end:k state:@"failed" error:e]; return; }
            [self resolve:asset key:k life:life generation:gen];
        }]) { [_loading release]; _loading = nil; [s->inflight removeObject:k]; return [self refuse:@"busy"]; }
        [self changed]; return YES;
    }
    __block BOOL finished = NO; _downloading = YES; [self changed];
    _downloadStarts++; s->downloadStarts++; // diagnostics: counts only real download dispatches, never renders or cache hits
    id<OR6APITask> t = [_core perform:@"assets.download" parameters:@{@"operationId": OR6Chat7OperationID(), @"conversationId": c, @"messageId": m, @"fileId": f} event:nil completion:^(NSDictionary *r, NSError *e) {
        finished = YES; if (life != _life) return; // invalidated: already latched, nothing applies
        _downloading = NO; [_task release]; _task = nil;
        if (gen != OR6Chat7Generation(_core)) { [self retryLater:k]; [self end:k state:nil error:OR6APIError(@"stale_context", @"possible")]; return; } // a read: fetched again in the new context
        if (e || ![r[@"assetId"] isKindOfClass:NSString.class]) {
            // The context moved under the request (e.g. the session rebinding at launch): offered again shortly, in the new context.
            if ([e.userInfo[@"code"] isEqual:@"stale_context"]) { [self retryLater:k]; [self end:k state:nil error:e]; return; }
            // A download is a read: an interrupted or possibly-sent one is Failed (a tap retries), never latched.
            [self end:k state:@"failed" error:e ?: OR6APIError(@"invalid_response", @"possible")]; return;
        }
        [Store(_core, YES) setAsset:r[@"assetId"] key:k]; // validated by the download in this context
        [self changed]; // the asset is usable now (Save/Share) while the thumbnail decodes
        [self resolve:r[@"assetId"] key:k life:life generation:gen];
    }];
    if (!finished && life == _life) _task = [t retain];
    return YES;
}
// Trusted bytes of the exact current binding → bounded thumbnail off the main thread → cache.
- (void)resolve:(NSString *)asset key:(NSArray *)k life:(NSUInteger)life generation:(NSUInteger)gen {
    NSData *data = gPreviewResolver ? gPreviewResolver(asset) : nil;
    if (![data isKindOfClass:NSData.class] || !data.length) { [self end:k state:@"unavailable" error:nil]; return; }
    [data retain]; [self retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        CGImageRef cg = OR6Chat7PreviewThumbnail(data, 720); [data release];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (life == _life && gen == OR6Chat7Generation(_core)) {
                if (cg) [Store(_core, YES) setImage:cg key:k];
                [self end:k state:cg ? nil : @"unavailable" error:nil];
            } else if (life == _life) [self end:k state:nil error:OR6APIError(@"stale_context", @"none")]; // another owner now: the picture is dropped
            if (cg) CGImageRelease(cg);
            [self release];
        });
    });
}
- (void)invalidate {
    _life++; [_gate invalidate];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(pump) object:nil]; _pumpScheduled = NO; [_wanted removeAllObjects]; // nothing starts automatically after background/teardown
    if (_loading) { OR6Chat7PreviewStore *s = Store(_core, NO); if (s) [s->inflight removeObject:_loading]; } // our own cancelled read: offered again on the next display
    [_task cancel]; [_task release]; _task = nil; [_loading release]; _loading = nil; _downloading = NO;
}
// Counts only (no IDs, paths or bytes): downloadStarts is this screen's, coreDownloadStarts survives screens and history reloads.
// Numbers only: 0 none; 1 stale_context, 2 network_unavailable, 3 timeout, 4 not_authenticated,
// 5 service_challenge, 6 rate_limited, 7 not_found, 8 upstream_error, 9 cancelled, 10 invalid_response; 99 other.
static NSUInteger ErrorIndex(NSError *e) {
    if (!e) return 0;
    NSUInteger i = [@[@"stale_context", @"network_unavailable", @"timeout", @"not_authenticated", @"service_challenge", @"rate_limited", @"not_found", @"upstream_error", @"cancelled", @"invalid_response"] indexOfObject:e.userInfo[@"code"] ?: @""];
    return i == NSNotFound ? 99 : i + 1;
}
- (NSDictionary *)diagnostics { OR6Chat7PreviewStore *s = [self current], *any = Store(_core, NO); return @{@"busy": @(_loading != nil), @"assets": @(s ? s->assets.count : 0), @"images": @(s ? s->images.count : 0), @"life": @(_life), @"downloadStarts": @(_downloadStarts), @"coreDownloadStarts": @(any ? any->downloadStarts : 0), @"autoQueued": @(_wanted.count), @"autoStarts": @(_autoTotal), @"lastError": @(ErrorIndex(_error))}; }
- (void)dealloc { _delegate = nil; [self invalidate]; [_gate release]; [_core release]; [_refusal release]; [_error release]; [_wanted release]; [_autoStarts release]; [_retryAt release]; [super dealloc]; }
@end
