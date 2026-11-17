#import "OR6ChatCodexPairUI.h"
#import "../../ui/RCWebFrameController.h"
#import "../../ui/RCTheme.h"
#import "../../ui/priority8/OR6Chat8Screens.h"
#import "../../ui/RCHUD.h"
#import "../../localization/OR6Localization.h"
#import "../../api/codex/pair/OR6CodexPairOAuth.h"
NSString *OR6ChatCodexPairAuthorizationFailureText(NSDictionary *raw){
    NSDictionary *d=OR6CodexPairOAuthSafeDiagnostic(raw);
    if(!d)return OR6L(@"Codex authorization could not finish. Close verification and start connecting again.");
    NSString *stage=[d[@"stage"]isEqual:@"callback"]?OR6L(@"OAuth callback"):[d[@"stage"]isEqual:@"token_validation"]?OR6L(@"OAuth token validation"):OR6L(@"OAuth token exchange");
    NSMutableArray *parts=[NSMutableArray arrayWithObject:d[@"code"]];
    if(d[@"httpStatus"])[parts addObject:[NSString stringWithFormat:@"HTTP %@",d[@"httpStatus"]]];
    if(d[@"transportCode"]){NSArray *names=@[@"invalid_request",@"cancelled",@"connect_timeout",@"idle_timeout",@"overall_timeout",@"dns_failure",@"tls_failure",@"certificate_failure",@"invalid_response",@"size_limit",@"io_failure",@"consumer_stopped"];[parts addObject:names[[d[@"transportCode"]unsignedIntegerValue]-1]];}
    for(NSString *key in @[@"oauthCode",@"responseType",@"reason"])if(d[key])[parts addObject:d[key]];
    return [NSString stringWithFormat:OR6L(@"Codex authorization failed. %@: %@. Close verification and start connecting again. No request was repeated."),stage,[parts componentsJoinedByString:@", "]];
}
@interface OR6CodexAuthorization:RCWebFrameController<UIWebViewDelegate,RCWebFrameControllerDelegate>{
    UIWebView *_web;NSURL *_URL;OR6ChatCodexModel *_model;void(^_done)(BOOL);BOOL _closed,_exchanging;
}
- (id)initWithBackend:(id<OR6ChatCodexBackend>)backend URL:(NSURL *)URL done:(void(^)(BOOL))done;
- (void)finish:(BOOL)authorized;
- (void)consumeCallback:(NSURL *)URL;
@end
@implementation OR6CodexAuthorization
- (id)initWithBackend:(id<OR6ChatCodexBackend>)backend URL:(NSURL *)URL done:(void(^)(BOOL))done{
    UIWebView *web=[[[UIWebView alloc]initWithFrame:CGRectZero]autorelease];
    if((self=[super initWithContentView:web title:OR6L(@"Authorize connection")])){_web=[web retain];_web.delegate=self;_URL=[URL copy];_model=[[OR6ChatCodexModel alloc]initWithBackend:backend];_done=[done copy];self.delegate=self;[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(changed:)name:OR6ChatCodexModelChanged object:_model];}return self;
}
- (void)viewDidLoad{[super viewDidLoad];self.view.accessibilityIdentifier=@"chat.codex.pair.authorization";self.host=_URL.host;self.secure=YES;self.progress=0;self.navigationItem.rightBarButtonItem=[[[UIBarButtonItem alloc]initWithTitle:OR6L(@"More")style:UIBarButtonItemStylePlain target:self action:@selector(more)]autorelease];[_web loadRequest:[NSURLRequest requestWithURL:_URL]];}
- (BOOL)webView:(UIWebView *)web shouldStartLoadWithRequest:(NSURLRequest *)r navigationType:(UIWebViewNavigationType)type{
    (void)web;(void)type;if(_closed||_model.stale)return NO;NSURL *u=r.URL;BOOL main=!r.mainDocumentURL||[u isEqual:r.mainDocumentURL];
    if(main&&[u.scheme isEqual:@"http"]&&[u.host isEqual:@"localhost"]&&[u.port isEqual:@1455]&&[u.path isEqual:@"/auth/callback"]){
        [self consumeCallback:u];return NO;
    }
    if(![@[@"https",@"about",@"data",@"blob"]containsObject:u.scheme.lowercaseString])return NO;
    if(main){self.host=u.host;self.secure=[u.scheme.lowercaseString isEqual:@"https"];self.progress=.2;}return YES;
}
- (void)consumeCallback:(NSURL *)u{
    if(_closed||_exchanging||_model.stale)return;_exchanging=YES;[_web stopLoading];self.progress=.8;
    [_model call:@"codex.pair.callback"parameters:@{@"url":u.absoluteString?:@""}slot:nil mutation:NO completion:^(NSDictionary *result,NSError *e){
        if(!e&&[result[@"authorized"]boolValue])[self finish:YES];else{self.progress=-1;self.navigationItem.rightBarButtonItem=nil;[self showErrorText:OR6ChatCodexPairAuthorizationFailureText(e.userInfo[@"oauthFailure"])actionTitle:nil];}
    }];
}
- (void)more{
    if(_closed||_exchanging||_model.stale)return;
    OR6Chat8ShowSheet(self.view,OR6L(@"Verification on a computer"),@[OR6L(@"Copy verification link"),OR6L(@"Paste verification callback…")],nil,^(NSInteger index,NSString *title){
        (void)title;if(index==0){UIPasteboard.generalPasteboard.string=_URL.absoluteString;[RCHUD showText:OR6L(@"Open the link on your computer. After verification, copy the full localhost callback URL and paste it here within ten minutes.")kind:RCHUDTextOnly inView:self.view seconds:6];}
        else if(index==1)OR6ChatCodexAlert(OR6L(@"Verification callback"),OR6L(@"Paste the full localhost callback URL shown after verification on your computer. It is used only for this pending request."),OR6L(@"Continue"),YES,^(NSString *text){if(!_closed&&!_model.stale)[self consumeCallback:[NSURL URLWithString:[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]]];});
    });
}
- (void)webViewDidFinishLoad:(UIWebView *)web{if(!_closed&&!web.loading)self.progress=1;}
- (void)webView:(UIWebView *)web didFailLoadWithError:(NSError *)e{(void)web;if(!_closed&&e.code!=NSURLErrorCancelled)[self showErrorText:OR6L(@"Verification could not finish on this iPhone. Your chat session is unchanged.")actionTitle:nil];}
- (void)changed:(NSNotification *)n{(void)n;if(_model.stale)[self finish:NO];}
- (void)finish:(BOOL)authorized{
    if(_closed)return;_closed=YES;[_web stopLoading];_web.delegate=nil;
    if(!authorized)[_model call:@"codex.pair.cancel-authorization"parameters:@{}slot:nil mutation:NO completion:nil];
    void(^done)(BOOL)=[[_done copy]autorelease];[_done release];_done=nil;
    [self dismissViewControllerAnimated:YES completion:^{if(done)done(authorized);}];
}
- (void)webFrameDidCancel:(RCWebFrameController *)frame{(void)frame;[self finish:NO];}
- (void)dealloc{[NSNotificationCenter.defaultCenter removeObserver:self];self.delegate=nil;_web.delegate=nil;[_web stopLoading];[_model cancel];[_model release];[_web release];[_URL release];[_done release];[super dealloc];}
@end
UIViewController *OR6ChatCodexPairAuthorization(id<OR6ChatCodexBackend>backend,NSURL *URL,void(^done)(BOOL)){
    if(![URL.scheme isEqual:@"https"]||![URL.host isEqual:@"auth.openai.com"]||![URL.path isEqual:@"/oauth/authorize"]||URL.user||URL.password||URL.port||URL.fragment)return nil;
    UIViewController *c=[[[OR6CodexAuthorization alloc]initWithBackend:backend URL:URL done:done]autorelease];UINavigationController *nav=[[[UINavigationController alloc]initWithRootViewController:c]autorelease];[RCTheme styleNavigationBar:nav.navigationBar variant:RCBarVariantJade];return nav;
}
