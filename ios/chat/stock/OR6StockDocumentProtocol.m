#import "OR6StockDocumentProtocol.h"
#import "../../api/OR6APIHTTP.h"
#import <CoreFoundation/CoreFoundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <dispatch/dispatch.h>
static NSString*const Target=@"https://chatgpt.com/robots.txt",*const Tag=@"X-ChatGPTX-Document-Load";
static OR6StockDocumentLoad*Active;static BOOL Registered;
static NSNumber*Flag(BOOL b){return b?(id)kCFBooleanTrue:(id)kCFBooleanFalse;}
static BOOL Exact(NSURL*u){return[u.absoluteString isEqual:Target]&&![u port]&&!u.user&&!u.password&&!u.query&&!u.fragment;}
@interface OR6StockDocumentLoad(){@public NSString*roots,*agent,*token;NSMutableDictionary*facts;BOOL cancelled;NSUInteger started,dispatched,blocked;}
@end
@implementation OR6StockDocumentLoad
- (NSMutableURLRequest*)request{NSMutableURLRequest*r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:Target]cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:45];[r setValue:token forHTTPHeaderField:Tag];return r;}
- (NSDictionary*)diagnostics{@synchronized(self){NSMutableDictionary*d=[NSMutableDictionary dictionaryWithDictionary:facts];[d addEntriesFromDictionary:@{@"redirectsFollowed":@0,@"loadsStarted":@(started),@"networkRequestsDispatched":@(dispatched),@"blockedRequests":@(blocked),@"certificateVerificationRequired":Flag(YES),@"hostnameVerificationRequired":Flag(YES),@"cookiesForwarded":Flag(NO),@"authorizationForwarded":Flag(NO),@"responseCookiesInstalled":Flag(NO),@"htmlStringLoaded":Flag(NO),@"baseURLUsed":Flag(NO)}];return[[d copy]autorelease];}}
- (void)cancel{@synchronized(OR6StockDocumentProtocol.class){@synchronized(self){cancelled=YES;}if(Active==self){[Active release];Active=nil;}}}
- (void)dealloc{[roots release];[agent release];[token release];[facts release];[super dealloc];}
@end
@interface OR6StockDocumentProtocol(){OR6StockDocumentLoad*_lease;BOOL _cancelled;CFRunLoopRef _origin;}
- (BOOL)cancelled;
- (void)worker;
- (void)deliver:(NSDictionary*)response error:(NSError*)error;
@end
@implementation OR6StockDocumentProtocol
+ (OR6StockDocumentLoad*)beginWithRoots:(NSString*)roots userAgent:(NSString*)agent{
 if(!NSThread.isMainThread||!roots.length||!agent.length||agent.length>2048||[agent rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound)return nil;
 NSDictionary*a=[NSFileManager.defaultManager attributesOfItemAtPath:roots error:NULL];if(![a[NSFileType]isEqual:NSFileTypeRegular]||![a[NSFileSize]unsignedLongLongValue]||[a[NSFileSize]unsignedLongLongValue]>2*1024*1024)return nil;
 @synchronized(self){if(Active)return nil;OR6StockDocumentLoad*l=[OR6StockDocumentLoad new];l->roots=[roots copy];l->agent=[agent copy];l->token=[[[NSUUID UUID]UUIDString]copy];l->facts=[NSMutableDictionary new];if(!Registered)Registered=[NSURLProtocol registerClass:self];if(!Registered){[l release];return nil;}Active=[l retain];return[l autorelease];}
}
+ (BOOL)canInitWithRequest:(NSURLRequest*)request{
 // Consume marked requests even after a lease ended: fail closed rather than
 // falling through to a different loader. Unmarked WebViews are unaffected.
 return Exact(request.URL)&&[request valueForHTTPHeaderField:Tag].length>0;
}
+ (NSURLRequest*)canonicalRequestForRequest:(NSURLRequest*)r{return r;}
- (BOOL)cancelled{@synchronized(self){if(_cancelled)return YES;}@synchronized(_lease){return _lease?_lease->cancelled:NO;}}
- (void)startLoading{
 _origin=CFRunLoopGetCurrent();CFRetain(_origin);BOOL allowed=NO;
 @synchronized(OR6StockDocumentProtocol.class){if(Active&&[[self.request valueForHTTPHeaderField:Tag]isEqual:Active->token])_lease=[Active retain];}
 if(_lease){@synchronized(_lease){_lease->started++;allowed=!_lease->cancelled&&_lease->started==1&&Exact(self.request.URL)&&[self.request.HTTPMethod isEqual:@"GET"]&&!self.request.HTTPBody&&!self.request.HTTPBodyStream;if(!allowed)_lease->blocked++;}}
 if(!allowed){[self deliver:nil error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadURL userInfo:nil]];return;}
 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{NSAutoreleasePool*p=[NSAutoreleasePool new];[self worker];[p drain];});
}
- (void)stopLoading{@synchronized(self){_cancelled=YES;}}
- (void)worker{
 if(self.cancelled)return;NSMutableURLRequest*r=[NSMutableURLRequest requestWithURL:self.request.URL cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:35];r.HTTPMethod=@"GET";[r setValue:_lease->agent forHTTPHeaderField:@"User-Agent"];
 for(NSString*k in @[@"Accept",@"Accept-Language"]){NSString*v=[self.request valueForHTTPHeaderField:k];if(v.length&&v.length<=2048&&[v rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location==NSNotFound)[r setValue:v forHTTPHeaderField:k];}
 @synchronized(_lease){_lease->dispatched++;_lease->facts[@"nativeUserAgentForwarded"]=Flag([[r valueForHTTPHeaderField:@"User-Agent"]isEqual:_lease->agent]);}
 NSError*error=nil;NSDictionary*response=OR6APIHTTPPerform(r,_lease->roots,[NSSet setWithObject:@"chatgpt.com"],@{@"connectTimeout":@12,@"idleTimeout":@10,@"overallTimeout":@35,@"maxRequestBytes":@8192,@"maxEncodedBytes":@131072,@"maxDecodedBytes":@131072,@"collectBody":@YES,@"acceptEncoding":@"identity"},^BOOL{return self.cancelled;},nil,nil,&error);
 NSHTTPURLResponse*http=nil;NSData*body=response[@"data"];BOOL verified=[response[@"certificateVerified"]isEqual:@YES];NSInteger status=[response[@"status"]integerValue];
 if(response){NSMutableDictionary*headers=[[response[@"headers"]mutableCopy]autorelease];for(NSString*k in [[headers.allKeys copy]autorelease])if([@[@"set-cookie",@"set-cookie2"]containsObject:k.lowercaseString])[headers removeObjectForKey:k];http=[[[NSHTTPURLResponse alloc]initWithURL:self.request.URL statusCode:status HTTPVersion:@"HTTP/1.1"headerFields:headers]autorelease];}
 BOOL plain=[http.MIMEType.lowercaseString isEqual:@"text/plain"],valid=[body isKindOfClass:NSData.class]&&body.length&&body.length<=131072;
 @synchronized(_lease){NSMutableDictionary*f=_lease->facts;f[@"status"]=response?@(status):(id)NSNull.null;f[@"certificateVerified"]=Flag(verified);f[@"mimeTextPlain"]=Flag(plain);f[@"responseMIME"]=plain?@"text/plain":@"other";f[@"serviceStop"]=Flag(status==401||status==403||status==429);f[@"bodyBytes"]=valid?@(body.length):@0;NSString*tls=response[@"tlsVersion"];f[@"tlsVersion"]=[@[@"TLSv1.2",@"TLSv1.3"]containsObject:tls?:@""]?tls:(id)NSNull.null;}
 if(!response||!verified||status!=200||!plain||!valid){NSInteger code=NSURLErrorBadServerResponse;if((response&&!verified)||error.code==OR6APIHTTPCertificateFailure)code=NSURLErrorServerCertificateUntrusted;else if(error.code==OR6APIHTTPTLSFailure)code=NSURLErrorSecureConnectionFailed;else if(error.code==OR6APIHTTPConnectTimeout||error.code==OR6APIHTTPIdleTimeout||error.code==OR6APIHTTPOverallTimeout)code=NSURLErrorTimedOut;[self deliver:nil error:[NSError errorWithDomain:NSURLErrorDomain code:code userInfo:nil]];return;}
 [self deliver:@{@"http":http,@"body":body}error:nil];
}
- (void)deliver:(NSDictionary*)response error:(NSError*)error{
 if(!_origin)return;CFRunLoopPerformBlock(_origin,kCFRunLoopCommonModes,^{if(self.cancelled)return;if(error){[self.client URLProtocol:self didFailWithError:error];return;}[self.client URLProtocol:self didReceiveResponse:response[@"http"]cacheStoragePolicy:NSURLCacheStorageNotAllowed];if(self.cancelled)return;[self.client URLProtocol:self didLoadData:response[@"body"]];if(self.cancelled)return;[self.client URLProtocolDidFinishLoading:self];});CFRunLoopWakeUp(_origin);
}
- (void)dealloc{[_lease release];if(_origin)CFRelease(_origin);[super dealloc];}
@end
