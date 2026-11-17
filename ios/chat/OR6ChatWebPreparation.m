#import "OR6ChatWebPreparation.h"
#import "OR6ChatNativePolicy.h"
#include <mach/mach_time.h>
static double Clock(void){mach_timebase_info_data_t t;mach_timebase_info(&t);return(double)mach_absolute_time()*t.numer/t.denom/1e9;}
static NSString*Literal(id v){if(!v)return nil;NSData*d=[NSJSONSerialization dataWithJSONObject:@[v]options:0 error:NULL];return d?[[[NSString alloc]initWithData:d encoding:NSUTF8StringEncoding]autorelease]:nil;}
@implementation OR6ChatWebPreparation{
 UIView*_host;UIWebView*_web;OR6ChatPreparationState*_state;NSDictionary*_context,*_bootstrap;
 NSString*_nonce,*_heldNonce,*_UA,*_issue;NSTimer*_idleTimer;BOOL _installed;NSUInteger _pageLoads;double _pageBegan,_pageLoadMS;
}
- (id)initWithHostView:(UIView*)host{if((self=[super init])){_host=host;_state=[OR6ChatPreparationState new];if(!host){[self release];return nil;}}return self;}
- (void)clearAttempt{
 if(_installed&&_nonce)[_web stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"window.__OR6MinimalSentinel.cancel((%@)[0])",Literal(_nonce)]];
 [_state cancel];[_nonce release];_nonce=nil;
}
- (void)releasePage{
 [_idleTimer invalidate];[_idleTimer release];_idleTimer=nil;[self clearAttempt];[_heldNonce release];_heldNonce=nil;_web.delegate=nil;[_web stopLoading];[_web removeFromSuperview];[_web release];_web=nil;_installed=NO;[_UA release];_UA=nil;
}
- (void)deactivate{[self releasePage];[_context release];_context=nil;[_issue release];_issue=nil;}
- (void)idleExpired:(NSTimer*)timer{(void)timer;if(!_nonce&&!_heldNonce)[self releasePage];}
- (void)park{[_idleTimer invalidate];[_idleTimer release];_idleTimer=[[NSTimer scheduledTimerWithTimeInterval:180 target:self selector:@selector(idleExpired:)userInfo:nil repeats:NO]retain];}
- (void)fail:(NSString*)issue{[_issue release];_issue=[issue copy];[self releasePage];}
- (void)prepareForContext:(NSDictionary*)context{
 if(!NSThread.isMainThread)return;
 if(![_state matchesContext:context]){[self deactivate];if(![_state bindContext:context])return;_context=[@{@"key":context[@"key"],@"generation":context[@"generation"]}copy];}
 else if(!_context)_context=[@{@"key":context[@"key"],@"generation":context[@"generation"]}copy];
 if(_web||_issue)return;_pageBegan=Clock();_pageLoads++;
 _web=[[UIWebView alloc]initWithFrame:_host.bounds];_web.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;_web.userInteractionEnabled=NO;_web.accessibilityElementsHidden=YES;_web.delegate=self;[_host insertSubview:_web atIndex:0];
 [_web loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://chatgpt.com/robots.txt"]cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:45]];
}
- (BOOL)isReadyForContext:(NSDictionary*)context{return _installed&&[_state matchesContext:context]&&[_context isEqual:context];}
- (BOOL)reserveAttempt:(NSString*)nonce context:(NSDictionary*)context{
 if(!NSThread.isMainThread||!OR6CNUUID(nonce)||(_heldNonce&&[_state matchesContext:context]&&![_heldNonce isEqual:nonce]))return NO;
 [self prepareForContext:context];if(![_state matchesContext:context]||_issue)return NO;
 [_heldNonce release];_heldNonce=[nonce copy];[_idleTimer invalidate];[_idleTimer release];_idleTimer=nil;return YES;
}
- (NSString*)userAgentForContext:(NSDictionary*)context{return[self isReadyForContext:context]?_UA:nil;}
- (BOOL)beginAttempt:(NSString*)nonce context:(NSDictionary*)context{
 if(!NSThread.isMainThread||(_heldNonce&&![_heldNonce isEqual:nonce])||![self isReadyForContext:context]||![_state beginAttempt:nonce context:context now:Clock()])return NO;
 [_idleTimer invalidate];[_idleTimer release];_idleTimer=nil;[_nonce release];_nonce=[nonce copy];
 NSString*r=[_web stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"window.__OR6MinimalSentinel.begin((%@)[0])",Literal(nonce)]];
 if(![r isEqual:@"started"]){[self clearAttempt];return NO;}return YES;
}
- (NSDictionary*)pollAttempt:(NSString*)nonce context:(NSDictionary*)context{
 if(!NSThread.isMainThread||![_nonce isEqual:nonce]||![self isReadyForContext:context])return @{@"phase":@"failed",@"issue":@"stale_context"};
 NSString*raw=[_web stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"window.__OR6MinimalSentinel.take((%@)[0])",Literal(nonce)]];
 id s=raw.length&&raw.length<200000?[NSJSONSerialization JSONObjectWithData:[raw dataUsingEncoding:NSUTF8StringEncoding]options:0 error:NULL]:nil;
 return[_state consume:s attempt:nonce context:context now:Clock()];
}
- (BOOL)supplyRequirements:(NSDictionary*)requirements attempt:(NSString*)nonce context:(NSDictionary*)context{
 if(!NSThread.isMainThread||![_nonce isEqual:nonce]||![self isReadyForContext:context]||![_state maySupply:requirements attempt:nonce context:context now:Clock()])return NO;
 NSString*r=[_web stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"window.__OR6MinimalSentinel.supply((%@)[0],(%@)[0])",Literal(nonce),Literal(requirements)]];
 if(![r isEqual:@"accepted"]){[self clearAttempt];return NO;}[_state didSupply];return YES;
}
- (void)endAttempt:(NSString*)nonce context:(NSDictionary*)context reuseDocument:(BOOL)reuse{
 if(![_state matchesContext:context]||(_nonce&&![nonce isEqual:_nonce])||(_heldNonce&&![nonce isEqual:_heldNonce]))return;[self clearAttempt];[_heldNonce release];_heldNonce=nil;if(reuse&&_installed)[self park];else[self releasePage];
}
- (void)webViewDidFinishLoad:(UIWebView*)web{
 if(web!=_web||web.loading||_installed)return;_pageLoadMS=(Clock()-_pageBegan)*1000;
 NSString*diagnostic=[web stringByEvaluatingJavaScriptFromString:@"JSON.stringify({top:window===window.top,url:location.href==='https://chatgpt.com/robots.txt',plain:document.contentType==='text/plain',body:!!document.body,agent:!!document.body&&document.body.textContent.indexOf('User-agent')>=0,promise:typeof Promise==='function',encoder:typeof TextEncoder==='function'})"];
 NSData*d=[diagnostic dataUsingEncoding:NSUTF8StringEncoding];id parsed=d.length<2048?[NSJSONSerialization JSONObjectWithData:d?:[NSData data]options:0 error:NULL]:nil;
 NSMutableDictionary*diag=[NSMutableDictionary dictionaryWithDictionary:[parsed isKindOfClass:NSDictionary.class]?parsed:@{}];
 NSString*guard=[web stringByEvaluatingJavaScriptFromString:@"String(window===window.top&&location.href==='https://chatgpt.com/robots.txt'&&document.contentType==='text/plain'&&document.body&&document.body.textContent.includes('User-agent'))"];
 NSString*source=[NSString stringWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"MinimalSentinelCore"ofType:@"js"]encoding:NSUTF8StringEncoding error:NULL];NSString*bridge=[NSString stringWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"sentinel-bridge"ofType:@"js"]encoding:NSUTF8StringEncoding error:NULL];
 diag[@"sourcePresent"]=@(source.length>0);diag[@"bridgePresent"]=@(bridge.length>0);[_bootstrap release];_bootstrap=[diag copy];
 if(![guard isEqual:@"true"]||!source||!bridge){[self fail:@"capability_unavailable"];return;}
 [web stringByEvaluatingJavaScriptFromString:source];NSString*installed=[web stringByEvaluatingJavaScriptFromString:bridge];NSString*ua=[web stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
 diag[@"installed"]=[@[@"installed",@"wrong_document",@"engine_unavailable"]containsObject:installed]?installed:@"script_failed";diag[@"userAgentPresent"]=@(ua.length>0);[_bootstrap release];_bootstrap=[diag copy];
 if(![installed isEqual:@"installed"]||!ua.length||ua.length>1024||[ua rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound){[self fail:@"capability_unavailable"];return;}
 _installed=YES;[_UA release];_UA=[ua copy];if(!_nonce&&!_heldNonce)[self park];
}
- (BOOL)webView:(UIWebView*)web shouldStartLoadWithRequest:(NSURLRequest*)r navigationType:(UIWebViewNavigationType)t{
 (void)t;if(web!=_web)return NO;NSURL*u=r.URL;BOOL main=!r.mainDocumentURL||[u isEqual:r.mainDocumentURL];BOOL okay=[u.scheme isEqual:@"https"]&&[u.host isEqual:@"chatgpt.com"]&&(!u.port||u.port.integerValue==443)&&!u.user&&!u.password&&!u.query&&!u.fragment;
 BOOL route=main?[u.path isEqual:@"/robots.txt"]:([u.path hasPrefix:@"/sentinel/"]||[u.path hasPrefix:@"/backend-api/sentinel/"]);if(!okay||!route){[self fail:@"service_challenge"];return NO;}return YES;
}
- (void)webView:(UIWebView*)web didFailLoadWithError:(NSError*)e{if(web==_web&&e.code!=NSURLErrorCancelled)[self fail:@"network_unavailable"];}
- (NSDictionary*)diagnostics{return @{@"implementation":@"webport-document",@"bootstrap":_bootstrap?:@{},@"webViewPresent":@(_web!=nil),@"pageLoaded":@(_installed),@"pageLoads":@(_pageLoads),@"pageLoadMs":@(_pageLoadMS),@"issue":_issue?:@""};}
- (void)dealloc{[self deactivate];[_state release];[_bootstrap release];[super dealloc];}
@end
