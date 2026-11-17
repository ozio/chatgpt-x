#import <Foundation/Foundation.h>

extern NSString *const OR6APIHTTPErrorDomain;
typedef NS_ENUM(NSInteger,OR6APIHTTPError) {
    OR6APIHTTPInvalidRequest=1, OR6APIHTTPCancelled, OR6APIHTTPConnectTimeout,
    OR6APIHTTPIdleTimeout, OR6APIHTTPOverallTimeout, OR6APIHTTPDNSFailure,
    OR6APIHTTPTLSFailure, OR6APIHTTPCertificateFailure, OR6APIHTTPInvalidResponse,
    OR6APIHTTPSizeLimit, OR6APIHTTPIOFailure, OR6APIHTTPConsumerStopped
};
typedef BOOL (^OR6APIHTTPHeaders)(NSInteger status,NSDictionary *headers);
typedef BOOL (^OR6APIHTTPBytes)(NSData *bytes);

// Synchronous worker-thread primitive. Per-connection TLS/DRBG contexts with a
// verified thread-safe pinned app-bundled MbedTLS build; no whole-stream lock.
// exact HTTPS host allowlist/443, CA required, no implicit cookies, redirects,
// credential acquisition, caching or retries. Callbacks occur on the worker.
// options: connectTimeout/idleTimeout/overallTimeout (seconds), maxRequestBytes,
// maxEncodedBytes/maxDecodedBytes, collectBody BOOL (default YES). All bounded.
// acceptEncoding: "gzip" (default) or "identity"; this owns the wire header.
// timings are monotonic milliseconds from primitive entry; absent phases did not finish.
// responseContentEncoding preserves the validated wire encoding before decompression.
// traceReadTiming BOOL (default NO) adds a bounded payload-free streamTiming trace:
// [kind(0=TLS read,1=body consumer),startMs,endMs,byteCount,socketWaitMs,readPollTimeouts].
// Times use timingOriginMonotonic; a TLS read span includes readiness waits and
// TLS processing. socketWaitMs is time spent inside select, not server CPU time.
// At most128 rows; truncated traces cannot prove coverage of a later interval.
// headers block precedes bytes; NO stops consumption, never retries. A cancelled
// connection is NOT a server Stop. Simultaneous control request is independent.
// Return ONLY status/headers/setCookies/data(if collectBody), certificateVerified,
// TLS metadata and dispatch/byte counters; NEVER request/header/body echo.
// Errors contain fixed generic codes only, no URL/query/headers/payloads.
NSDictionary *OR6APIHTTPPerform(NSURLRequest *request, NSString *CAFile,
    NSSet *allowedHosts, NSDictionary *options, BOOL (^cancelled)(void),
    OR6APIHTTPHeaders onHeaders, OR6APIHTTPBytes onBytes, NSError **error);

// Private protocol-adapter primitive for an explicit WebSocket upgrade. The
// pump owns RFC6455 validation and framing. Same verified TLS/host/CA path as
// HTTPS. Read returns -2 when no bytes are ready, 0 on TLS close, -1 on error.
// All callbacks run on the one worker; no concurrent TLS context access.
typedef NSInteger (^OR6APIHTTPDuplexRead)(unsigned char *bytes,NSUInteger capacity,NSError **error);
typedef BOOL (^OR6APIHTTPDuplexWrite)(NSData *bytes,NSError **error);
typedef BOOL (^OR6APIHTTPDuplexPump)(OR6APIHTTPDuplexRead read,OR6APIHTTPDuplexWrite write,NSError **error);
NSDictionary *OR6APIHTTPDuplex(NSURLRequest *request,NSString *CAFile,NSSet *allowedHosts,
    BOOL (^cancelled)(void),OR6APIHTTPDuplexPump pump,NSError **error);
