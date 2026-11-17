#import "OR6ChatFavicons.h"
#import "../api/OR6APIHTTP.h"
#import <ImageIO/ImageIO.h>
#import "RCSourcesSheet.h"

NSString *const OR6ChatFaviconDidLoadNotification = @"OR6ChatFaviconDidLoad";
static NSCache *icons;
static NSMutableSet *attempted;
static NSOperationQueue *queue;
static NSString *directory;
static BOOL backgrounded;
static NSLock *lifecycleLock;
static BOOL Backgrounded(void) { [lifecycleLock lock]; BOOL value=backgrounded; [lifecycleLock unlock]; return value; }

@interface OR6ChatFaviconLifecycle : NSObject
@end
@implementation OR6ChatFaviconLifecycle
- (void)background { [lifecycleLock lock]; backgrounded = YES; [lifecycleLock unlock]; }
- (void)active { [lifecycleLock lock]; backgrounded = NO; [lifecycleLock unlock]; }
@end

static NSString *Host(NSString *raw) {
    NSURL *url = [NSURL URLWithString:raw]; NSString *host = url.host.lowercaseString;
    if (![@[@"https", @"http"] containsObject:url.scheme.lowercaseString] || host.length > 253 || host.length < 3 || [host rangeOfString:@"."].location == NSNotFound) return nil;
    if ([host rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789.-"] invertedSet]].location != NSNotFound) return nil;
    return host;
}
static void Setup(void) {
    if (icons) return;
    lifecycleLock = [NSLock new]; icons = [NSCache new]; icons.countLimit = 64;
    attempted = [NSMutableSet new]; queue = [NSOperationQueue new]; queue.maxConcurrentOperationCount = 1;
    directory = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES)[0] stringByAppendingPathComponent:@"SourceFavicons-v1"] copy];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    static OR6ChatFaviconLifecycle *life; life = [OR6ChatFaviconLifecycle new];
    [NSNotificationCenter.defaultCenter addObserver:life selector:@selector(background) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:life selector:@selector(active) name:UIApplicationDidBecomeActiveNotification object:nil];
}
static UIImage *Decode(NSData *data) {
    if (!data.length || data.length > 65536) return nil;
    CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)data,NULL); if (!source) return nil;
    NSDictionary *props = (NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source,0,NULL);
    NSUInteger w = [props[(id)kCGImagePropertyPixelWidth] unsignedIntegerValue], h = [props[(id)kCGImagePropertyPixelHeight] unsignedIntegerValue];
    CGImageRef image = NULL;
    if (w && h && w <= 512 && h <= 512) image = CGImageSourceCreateThumbnailAtIndex(source,0,(CFDictionaryRef)@{(id)kCGImageSourceCreateThumbnailFromImageAlways:@YES,(id)kCGImageSourceThumbnailMaxPixelSize:@32});
    UIImage *result = image ? [UIImage imageWithCGImage:image] : nil;
    if (image) CGImageRelease(image); [props release]; CFRelease(source); return result;
}
UIImage *OR6ChatFavicon(NSString *raw, BOOL load) {
    NSCAssert(NSThread.isMainThread,@"Favicon UI cache is main-thread owned");
    NSString *host = Host(raw); if (!host) return nil; Setup();
    UIImage *icon = [icons objectForKey:host]; if (icon) return icon;
    NSString *path = [directory stringByAppendingPathComponent:[host stringByAppendingString:@".png"]];
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
    if ([attrs[NSFileModificationDate] timeIntervalSinceNow] > -7*86400) {
        icon = Decode([NSData dataWithContentsOfFile:path]); if (icon) { [icons setObject:icon forKey:host]; return icon; }
    }
    if ([host hasSuffix:@".invalid"] || [host hasSuffix:@".example"]) return nil;
    if (!load || Backgrounded() || [attempted containsObject:host] || attempted.count >= 64) return nil;
    [attempted addObject:host];
    // Same public favicon service used by ChatGPT's citations. Only the site's
    // origin is sent; never its path/query, referrer, cookies or account headers.
    NSString *origin = [@"https://" stringByAppendingString:host];
    NSString *escaped = [(NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,(CFStringRef)origin,NULL,CFSTR(":/?&=+#"),kCFStringEncodingUTF8) autorelease];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://t0.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON&fallback_opts=TYPE,SIZE,URL&url=%@&size=32&drop_404_icon=true",escaped]];
    [queue addOperationWithBlock:^{ @autoreleasepool {
        if (Backgrounded()) return;
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:8];
        request.HTTPShouldHandleCookies = NO; [request setValue:@"image/png,image/*" forHTTPHeaderField:@"Accept"];
        NSDictionary *r = OR6APIHTTPPerform(request,[[NSBundle mainBundle] pathForResource:@"roots" ofType:@"pem"],[NSSet setWithObject:@"t0.gstatic.com"],@{@"connectTimeout":@4,@"idleTimeout":@4,@"overallTimeout":@8,@"maxEncodedBytes":@65536,@"maxDecodedBytes":@65536},^BOOL{return Backgrounded();},^BOOL(NSInteger status,NSDictionary *headers){ return status==200; },nil,NULL);
        UIImage *image = [r[@"status"] integerValue]==200 && [r[@"certificateVerified"] boolValue] ? Decode(r[@"data"]) : nil;
        if (!image) return;
        dispatch_async(dispatch_get_main_queue(),^{
            [icons setObject:image forKey:host];
            NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:NULL];
            if (files.count >= 64) { NSString *oldest = nil; NSDate *date = nil; for (NSString *f in files) { NSString *p = [directory stringByAppendingPathComponent:f]; NSDate *d = [[[NSFileManager defaultManager] attributesOfItemAtPath:p error:NULL] objectForKey:NSFileModificationDate]; if (!date || [d compare:date]==NSOrderedAscending) { oldest=p; date=d; } } if (oldest) [[NSFileManager defaultManager] removeItemAtPath:oldest error:NULL]; }
            [UIImagePNGRepresentation(image) writeToFile:path atomically:YES];
            [NSNotificationCenter.defaultCenter postNotificationName:OR6ChatFaviconDidLoadNotification object:host];
        });
    }}];
    return nil;
}
NSArray *OR6ChatSourceIcons(NSArray *sources, BOOL load) {
    NSMutableArray *out = [NSMutableArray array]; NSMutableSet *hosts = [NSMutableSet set];
    for (NSDictionary *source in sources) {
        NSString *host = Host(source[@"url"]); if (!host || [hosts containsObject:host]) continue; [hosts addObject:host];
        UIImage *icon = OR6ChatFavicon(source[@"url"],load);
        if (!icon) { RCSourceItem *item = [RCSourceItem sourceWithTitle:source[@"title"] host:host URL:nil]; icon = [RCSourceRowView tileForSource:item]; }
        if (icon) [out addObject:icon]; if (out.count == 3) break;
    }
    return out;
}
