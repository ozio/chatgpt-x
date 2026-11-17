#import <Foundation/Foundation.h>

extern NSString * const ORLHTTPErrorDomain;

typedef NS_ENUM(NSInteger, ORLHTTPErrorCode) {
    ORLHTTPInvalidRequest = 1,
    ORLHTTPCancelled = 2,
    ORLHTTPTimeout = 3,
    ORLHTTPDNSFailure = 4,
    ORLHTTPConnectFailure = 5,
    ORLHTTPTLSFailure = 6,
    ORLHTTPCertificateFailure = 7,
    ORLHTTPInvalidResponse = 8,
    ORLHTTPSizeLimit = 9,
    ORLHTTPBodyStreamFailure = 10,
    ORLHTTPIOFailure = 11,
    ORLHTTPUnsupportedEncoding = 12
};

/*
 * Synchronous, single-attempt direct HTTPS. Call on a worker thread.
 * cancelled must be a quick flag-only check, never a network/reentrant call.
 *
 * Mutable request/CA/allowlist/cancel inputs are snapshotted at entry.
 * Only an exact allowed host, HTTPS and absent/443 port are accepted. The
 * supplied app-scoped CA file is required. No redirect is followed, credential
 * is created, cookie is stored, response is cached or POST is retried here.
 * The caller owns normal cookie/origin/redirect policy.
 *
 * The pinned library has no threading support. Calls are serialized internally,
 * including cancellation/deadline checks while waiting. timeoutInterval is
 * clamped to 1..45 seconds and covers body preparation, waiting, DNS and I/O.
 *
 * Returns status, headers, setCookies (separate original Set-Cookie values),
 * data, url, tlsVersion, cipher, certificateVerified and preparedRequest.
 * headers omit hop-by-hop/Set-Cookie fields; dechunk/gzip are already decoded.
 * preparedRequest retains a bounded NSData body for an explicit 307/308 redirect
 * instead of rereading an exhausted HTTPBodyStream. It is sensitive RAM data:
 * do not log/serialize this dictionary, its headers, cookies, data or request.
 * Bodies are bounded to 1 MiB request / 8 MiB encoded and decoded response;
 * headers and chunk metadata each have a 64 KiB cumulative bound.
 * Errors contain only stable generic codes, never a URL/query/header/body.
 */
NSDictionary *ORLHTTPPerform(NSURLRequest *request,
                             NSString *CAFile,
                             NSSet *allowedHosts,
                             BOOL (^cancelled)(void),
                             NSError **error);

#if defined(ORL_HTTP_TESTING)
/* Offline fixture interfaces. Not exported by a normal app build. */
NSDictionary *ORLHTTPParseForTesting(NSArray *fragments, NSString *method, NSError **error);
NSData *ORLHTTPRequestForTesting(NSURLRequest *request, NSError **error);
#endif
