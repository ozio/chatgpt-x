#import "OR6ChatStockPreparation.h"
#import "OR6StockDocumentProtocol.h"
#import "../OR6ChatNativePolicy.h"
#import <CommonCrypto/CommonDigest.h>
#include <mach/mach_time.h>
static double Clock(void){mach_timebase_info_data_t t;mach_timebase_info(&t);return(double)mach_absolute_time()*t.numer/t.denom/1e9;}
static NSString*Literal(id v){NSData*d=v?[NSJSONSerialization dataWithJSONObject:@[v]options:0 error:NULL]:nil;return d?[[[NSString alloc]initWithData:d encoding:NSUTF8StringEncoding]autorelease]:nil;}
static NSString*Hash(NSData*d){if(!d)return nil;unsigned char h[CC_SHA256_DIGEST_LENGTH];CC_SHA256(d.bytes,(CC_LONG)d.length,h);NSMutableString*s=[NSMutableString string];for(NSUInteger i=0;i<sizeof(h);i++)[s appendFormat:@"%02x",h[i]];return s;}
@implementation OR6ChatStockPreparation{
 UIView*_host;NSString*_roots,*_UA,*_issue,*_nonce,*_held;UIWebView*_web;OR6ChatPreparationState*_state;OR6StockDocumentLoad*_load;
 NSDictionary*_context,*_manifest,*_bootstrap,*_transport;NSTimer*_timer;BOOL _installed,_installing;NSUInteger _pageLoads,_navigations;double _began,_loadMS;
}
- (NSString*)resourceDirectory{return[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"StockPreparation"];}
- (id)initWithHostView:(UIView*)host roots:(NSString*)roots{if((self=[super init])){_host=host;_roots=[roots copy];_state=[OR6ChatPreparationState new];if(!host||!roots.length){[self release];return nil;}NSString*p=[[self resourceDirectory]stringByAppendingPathComponent:@"Manifest.json"];_manifest=[[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:p]?:[NSData data]options:0 error:NULL]retain];}return self;}
- (NSString*)script:(NSString*)name{NSString*p=[[self resourceDirectory]stringByAppendingPathComponent:name];NSData*d=[NSData dataWithContentsOfFile:p];NSString*h=_manifest[@"files"][name];if(![h isKindOfClass:NSString.class]||![Hash(d)isEqual:h])return nil;return[[[NSString alloc]initWithData:d encoding:NSUTF8StringEncoding]autorelease];}
- (NSString*)evaluate:(NSString*)source{if(!source.length)return nil;return[_web stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"(function(){try{return (%@);}catch(e){return 'script_failed';}})()",source]];}
- (void)clearAttempt{if(_nonce&&_installed)[_web stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"window.__OR6MinimalSentinel.cancel((%@)[0])",Literal(_nonce)]];[_state cancel];[_nonce release];_nonce=nil;}
- (void)releasePage{[_timer invalidate];[_timer release];_timer=nil;[self clearAttempt];[_held release];_held=nil;[_load cancel];[_load release];_load=nil;_web.delegate=nil;[_web stopLoading];[_web removeFromSuperview];[_web release];_web=nil;[_UA release];_UA=nil;_installed=_installing=NO;}
- (void)deactivate{[self releasePage];[_context release];_context=nil;[_issue release];_issue=nil;}
- (void)fail:(NSString*)code{[_issue release];_issue=[code copy];[self releasePage];}
- (void)park{[_timer invalidate];[_timer release];_timer=[[NSTimer scheduledTimerWithTimeInterval:180 target:self selector:@selector(idleExpired:)userInfo:nil repeats:NO]retain];}
- (void)idleExpired:(NSTimer*)t{(void)t;if(!_nonce&&!_held)[self releasePage];}
- (void)prepareForContext:(NSDictionary*)context{
 if(!NSThread.isMainThread)return;if(![_state matchesContext:context]){[self deactivate];if(![_state bindContext:context])return;_context=[@{@"key":context[@"key"],@"generation":context[@"generation"]}copy];}else if(!_context)_context=[context copy];
 if(_web||_issue)return;if(![_manifest isKindOfClass:NSDictionary.class]||![Hash([NSData dataWithContentsOfFile:_roots])isEqual:_manifest[@"rootsSHA256"]]){[self fail:@"capability_unavailable"];return;}
 _began=Clock();_pageLoads++;_navigations=0;_web=[[UIWebView alloc]initWithFrame:_host.bounds];_web.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;_web.userInteractionEnabled=NO;_web.accessibilityElementsHidden=YES;_web.delegate=self;[_host insertSubview:_web atIndex:0];
 _UA=[[_web stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"]copy];_load=[[OR6StockDocumentProtocol beginWithRoots:_roots userAgent:_UA]retain];if(!_load){[self fail:@"capability_unavailable"];return;}
 [_web loadRequest:[_load request]];_timer=[[NSTimer scheduledTimerWithTimeInterval:.04 target:self selector:@selector(bootstrapTick:)userInfo:nil repeats:YES]retain];
}
- (BOOL)isReadyForContext:(NSDictionary*)context{return _installed&&[_state matchesContext:context]&&[_context isEqual:context];}
- (BOOL)reserveAttempt:(NSString*)nonce context:(NSDictionary*)context{if(!NSThread.isMainThread||!OR6CNUUID(nonce)||(_held&&[_state matchesContext:context]&&![_held isEqual:nonce]))return NO;[self prepareForContext:context];if(_issue||![_state matchesContext:context])return NO;[_held release];_held=[nonce copy];if(_installed){[_timer invalidate];[_timer release];_timer=nil;}return YES;}
- (NSString*)userAgentForContext:(NSDictionary*)context{return[self isReadyForContext:context]?_UA:nil;}
- (BOOL)beginAttempt:(NSString*)nonce context:(NSDictionary*)context{if(!NSThread.isMainThread||(_held&&![_held isEqual:nonce])||![self isReadyForContext:context]||![_state beginAttempt:nonce context:context now:Clock()])return NO;[_timer invalidate];[_timer release];_timer=nil;[_nonce release];_nonce=[nonce copy];NSString*r=[_web stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"window.__OR6MinimalSentinel.begin((%@)[0])",Literal(nonce)]];if(![r isEqual:@"started"]){[self clearAttempt];return NO;}return YES;}
- (NSDictionary*)pollAttempt:(NSString*)nonce context:(NSDictionary*)context{if(!NSThread.isMainThread||![_nonce isEqual:nonce]||![self isReadyForContext:context])return @{@"phase":@"failed",@"issue":@"stale_context"};NSString*raw=[_web stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"window.__OR6MinimalSentinel.take((%@)[0])",Literal(nonce)]];id value=raw.length&&raw.length<200000?[NSJSONSerialization JSONObjectWithData:[raw dataUsingEncoding:NSUTF8StringEncoding]options:0 error:NULL]:nil;return[_state consume:value attempt:nonce context:context now:Clock()];}
- (BOOL)supplyRequirements:(NSDictionary*)requirements attempt:(NSString*)nonce context:(NSDictionary*)context{if(!NSThread.isMainThread||![_nonce isEqual:nonce]||![self isReadyForContext:context]||![_state maySupply:requirements attempt:nonce context:context now:Clock()])return NO;NSString*r=[_web stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"window.__OR6MinimalSentinel.supply((%@)[0],(%@)[0])",Literal(nonce),Literal(requirements)]];if(![r isEqual:@"accepted"]){[self clearAttempt];return NO;}[_state didSupply];return YES;}
- (void)endAttempt:(NSString*)nonce context:(NSDictionary*)context reuseDocument:(BOOL)reuse{if(![_state matchesContext:context]||(_nonce&&![_nonce isEqual:nonce])||(_held&&![_held isEqual:nonce]))return;[self clearAttempt];[_held release];_held=nil;if(reuse&&_installed)[self park];else[self releasePage];}
- (void)webViewDidFinishLoad:(UIWebView*)web{
 if(web!=_web||web.loading||_installed||_installing)return;_loadMS=(Clock()-_began)*1000;[_transport release];_transport=[[_load diagnostics]retain];[_load cancel];[_load release];_load=nil;
 NSString*docSource=[self script:@"DocumentCheck.js"];NSString*raw=docSource?[_web stringByEvaluatingJavaScriptFromString:docSource]:nil;NSDictionary*d=raw?[NSJSONSerialization JSONObjectWithData:[raw dataUsingEncoding:NSUTF8StringEncoding]options:0 error:NULL]:nil;
 for(NSString*k in @[@"topLevel",@"hrefExact",@"documentURLExact",@"protocolHttps",@"hostExact",@"portDefault",@"pathExact",@"searchEmpty",@"hashEmpty",@"domainExact",@"originExact",@"readyComplete",@"bodyPresent",@"bodyMarker",@"bodySinglePre",@"doctypeAbsent",@"userAgentPresent"])if(![d[k]isEqual:@YES]){[self fail:@"capability_unavailable"];return;}
 if(![d[@"scriptElements"]isEqual:@0]||![_transport[@"certificateVerified"]isEqual:@YES]||![_transport[@"status"]isEqual:@200]){[self fail:@"service_challenge"];return;}
 NSString*mime=[self script:@"DocumentMIME.js"];NSString*result=mime?[self evaluate:[NSString stringWithFormat:@"(%@)(window,(%@)[0])",mime,Literal(_transport)]]:nil;if(![@[@"installed",@"already_installed",@"native"]containsObject:result]){[self fail:@"capability_unavailable"];return;}
 for(NSString*name in @[@"StockCompatibility.js",@"SentinelCore.js",@"compat-fixtures.js"]){NSString*source=[self script:name];if(!source){[self fail:@"capability_unavailable"];return;}[_web stringByEvaluatingJavaScriptFromString:source];}
 if(![[_web stringByEvaluatingJavaScriptFromString:@"window.__OR6CompatFixtures?window.__OR6CompatFixtures.start():'missing'"]isEqual:@"started"]){[self fail:@"capability_unavailable"];return;}_installing=YES;
}
- (void)bootstrapTick:(NSTimer*)timer{
 (void)timer;if(!_web)return;if(Clock()-_began>45){[self fail:@"network_unavailable"];return;}if(!_installing)return;
 NSString*raw=[_web stringByEvaluatingJavaScriptFromString:@"window.__OR6CompatFixtures.take()"];NSDictionary*d=raw?[NSJSONSerialization JSONObjectWithData:[raw dataUsingEncoding:NSUTF8StringEncoding]options:0 error:NULL]:nil;if(![d[@"phase"]isEqual:@"complete"])return;
 if(![d[@"checks"]isEqual:@66]||![d[@"failures"]isEqual:@0]||![d[@"coreReady"]isEqual:@YES]||![d[@"asyncSettled"]isEqual:@YES]){[self fail:@"capability_unavailable"];return;}
 NSString*crypto=[self script:@"LegacyCrypto.js"],*bridge=[self script:@"SentinelBridge.js"];NSString*r=crypto?[self evaluate:[NSString stringWithFormat:@"(%@)(window)",crypto]]:nil;NSDictionary*c=r?[NSJSONSerialization JSONObjectWithData:[r dataUsingEncoding:NSUTF8StringEncoding]options:0 error:NULL]:nil;
 if(![c[@"installed"]isEqual:@YES]||![c[@"nativeEntropy"]isEqual:@YES]||![c[@"sourceHonest"]isEqual:@YES]||!bridge.length||![[_web stringByEvaluatingJavaScriptFromString:bridge]isEqual:@"installed"]){[self fail:@"capability_unavailable"];return;}
 [_bootstrap release];_bootstrap=[@{@"fixtureChecks":d[@"checks"],@"fixtureFailures":d[@"failures"],@"cryptoMethodReplaced":c[@"methodReplaced"],@"nativeEntropy":c[@"nativeEntropy"],@"sourceHonest":c[@"sourceHonest"]}copy];_installed=YES;_installing=NO;[_timer invalidate];[_timer release];_timer=nil;if(!_held)[self park];
}
- (BOOL)webView:(UIWebView*)web shouldStartLoadWithRequest:(NSURLRequest*)request navigationType:(UIWebViewNavigationType)t{(void)t;if(web!=_web)return NO;BOOL allowed=_navigations==0&&!_installed&&!_installing&&[request.URL.absoluteString isEqual:@"https://chatgpt.com/robots.txt"]&&[request.HTTPMethod isEqual:@"GET"];if(!allowed){[self fail:@"service_challenge"];return NO;}_navigations++;return YES;}
- (void)webView:(UIWebView*)web didFailLoadWithError:(NSError*)error{if(web==_web&&error.code!=NSURLErrorCancelled){NSDictionary*d=[_load diagnostics];[self fail:[d[@"serviceStop"]isEqual:@YES]?@"service_challenge":@"network_unavailable"];}}
- (NSDictionary*)diagnostics{return @{@"implementation":@"stock-document",@"webViewPresent":@(_web!=nil),@"pageLoaded":@(_installed),@"pageLoads":@(_pageLoads),@"pageLoadMs":@(_loadMS),@"bootstrap":_bootstrap?:@{},@"documentTransport":_transport?:@{},@"issue":_issue?:@""};}
- (void)dealloc{[self deactivate];[_roots release];[_state release];[_manifest release];[_bootstrap release];[_transport release];[super dealloc];}
@end
