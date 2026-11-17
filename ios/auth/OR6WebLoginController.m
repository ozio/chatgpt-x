#import "../localization/OR6Localization.h"
#import "OR6WebLoginController.h"
#import "OR6AuthEngine.h"
#import <Security/Security.h>

static NSString *Nonce(void){
    unsigned char b[16];if(SecRandomCopyBytes(kSecRandomDefault,sizeof(b),b)!=errSecSuccess)return nil;
    NSMutableString *s=[NSMutableString string];for(unsigned i=0;i<sizeof(b);i++)[s appendFormat:@"%02x",b[i]];memset(b,0,sizeof(b));return s;
}
// iOS 6.1.4: a multi-line UILabel given plain text can drop the word at a line
// break; the attributed string with the same font lays out correctly.
static void OR6LoginSetMessage(UILabel *label,NSString *text){
    NSMutableParagraphStyle *ps=[[[NSMutableParagraphStyle alloc]init]autorelease];ps.alignment=label.textAlignment;ps.lineBreakMode=NSLineBreakByWordWrapping;
    label.attributedText=[[[NSAttributedString alloc]initWithString:text?:@"" attributes:@{NSFontAttributeName:label.font,NSForegroundColorAttributeName:label.textColor?:[UIColor blackColor],NSParagraphStyleAttributeName:ps}]autorelease];
}
@implementation OR6WebLoginController
@synthesize delegate=_delegate;
- (id)initWithSession:(OR6WebSession *)session generation:(NSUInteger)generation {
    if((self=[super init])){_session=[session retain];_generation=generation;_nonce=[Nonce()copy];self.title=OR6L(@"ChatGPT login");}return self;
}
- (void)loadView {
    self.view=[[[UIView alloc]initWithFrame:[UIScreen mainScreen].applicationFrame]autorelease];self.view.backgroundColor=[UIColor whiteColor];
    _web=[[UIWebView alloc]initWithFrame:self.view.bounds];_web.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;_web.delegate=self;[self.view addSubview:_web];
    _cover=[[UIView alloc]initWithFrame:self.view.bounds];_cover.autoresizingMask=_web.autoresizingMask;_cover.backgroundColor=[UIColor whiteColor];[self.view addSubview:_cover];
    _spinner=[[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];_spinner.center=CGPointMake(160,130);[_cover addSubview:_spinner];[_spinner startAnimating];
    _message=[[UILabel alloc]initWithFrame:CGRectMake(20,155,280,90)];_message.textAlignment=NSTextAlignmentCenter;_message.numberOfLines=4;_message.font=[UIFont systemFontOfSize:16];OR6LoginSetMessage(_message,OR6L(@"Opening the secure login page…"));[_cover addSubview:_message];
    _retry=[[UIButton buttonWithType:UIButtonTypeRoundedRect]retain];_retry.frame=CGRectMake(65,260,190,42);[_retry setTitle:OR6L(@"Retry")forState:UIControlStateNormal];[_retry addTarget:self action:@selector(retry)forControlEvents:UIControlEventTouchUpInside];_retry.hidden=YES;[_cover addSubview:_retry];
    self.navigationItem.leftBarButtonItem=[[[UIBarButtonItem alloc]initWithTitle:OR6L(@"Cancel")style:UIBarButtonItemStylePlain target:self action:@selector(cancel)]autorelease];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    if(![OR6AuthEngine()[@"modernWebKit"]boolValue]){[self showError:OR6L(@"Login requires Web Port to be enabled. Restart ChatGPT X after enabling it.")];return;}
    if(!_nonce){[self showError:OR6L(@"Could not start login. Try again.")];return;}
    _timer=[[NSTimer scheduledTimerWithTimeInterval:.5 target:self selector:@selector(tick:)userInfo:nil repeats:YES]retain];[self loadLogin];
}
- (void)loadLogin {
    _submitted=NO;_completionRequested=NO;_onChatGPT=NO;_cover.hidden=NO;_retry.hidden=YES;[_spinner startAnimating];OR6LoginSetMessage(_message,OR6L(@"Opening the login page…"));
    [_lastAttempt release];_lastAttempt=nil;[_probeStarted release];_probeStarted=nil;
    [_web loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://chatgpt.com/auth/login"]cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:60]];
}
- (void)showError:(NSString *)message {_cover.hidden=NO;OR6LoginSetMessage(_message,message);_retry.hidden=NO;[_spinner stopAnimating];}
- (void)retry {
    if(_stopped)return;
    _generation=[_session beginSignIn];[_nonce release];_nonce=[Nonce()copy];
    if(!_nonce){[self showError:OR6L(@"Could not start login.")];return;}[self loadLogin];
}
- (void)cancel {[_delegate loginControllerCancelled:self];}
- (NSString *)literalNonce {
    NSData *data=[NSJSONSerialization dataWithJSONObject:@[_nonce]options:0 error:NULL];return [[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]autorelease];
}
- (void)tick:(NSTimer *)timer {
    (void)timer;if(_stopped||_submitted||!_onChatGPT||!_completionRequested||![_session.phase isEqual:@"signing_in"])return;
    NSString *origin=[_web stringByEvaluatingJavaScriptFromString:@"(function(){return window===window.top&&location.protocol==='https:'&&location.hostname==='chatgpt.com'&&(!location.port||location.port==='443')?'own':'other';})()"];
    if(![origin isEqual:@"own"])return;
    NSString *literal=[self literalNonce];
    NSString *read=[NSString stringWithFormat:@"(function(n){if(window!==window.top||location.protocol!=='https:'||location.hostname!=='chatgpt.com'||(location.port&&location.port!=='443'))return '';var r=window.__OR6NativeAuth;return r&&r.nonce===n?JSON.stringify(r):'';})((%@)[0])",literal];
    NSString *raw=[_web stringByEvaluatingJavaScriptFromString:read];
    id result=raw.length&&raw.length<=32768?[NSJSONSerialization JSONObjectWithData:[raw dataUsingEncoding:NSUTF8StringEncoding]options:0 error:NULL]:nil;
    if([result isKindOfClass:NSDictionary.class]&&[result[@"nonce"]isEqual:_nonce]){
        _webStatus=[result[@"status"]isKindOfClass:NSNumber.class]?[result[@"status"]integerValue]:0;
        if([result[@"state"]isEqual:@"available"]){
            NSDictionary *credential=result[@"credential"];[_web stringByEvaluatingJavaScriptFromString:@"window.__OR6NativeAuth=null;"];
            _cover.hidden=NO;_retry.hidden=YES;[_spinner startAnimating];OR6LoginSetMessage(_message,OR6L(@"Saving login…"));_submitted=YES;
            if(![_session acceptWebCredential:credential generation:_generation])[self showError:OR6L(@"Could not verify the session. Log in again.")];return;
        }
        if(![result[@"state"]isEqual:@"pending"]){[self showError:OR6L(@"Could not retrieve the session. Check your connection and log in again.")];return;}
    }
    if(_lastAttempt){if(_probeStarted&&-_probeStarted.timeIntervalSinceNow>20)[self showError:OR6L(@"The service did not respond. Check your connection and log in again.")];return;}
    NSString *source=[NSString stringWithContentsOfFile:[[NSBundle mainBundle]pathForResource:@"web-session-probe"ofType:@"js"]encoding:NSUTF8StringEncoding error:NULL];
    if(!source){[self showError:OR6L(@"Could not open login.")];return;}
    NSString *started=[_web stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"%@( (%@)[0] )",source,literal]];
    if([started isEqual:@"started"]){_lastAttempt=[NSDate new];_probeStarted=[NSDate new];}
}
- (void)sessionChanged {
    if([_session.phase isEqual:@"recovery"]||[_session.phase isEqual:@"reauthentication_required"]){
        NSString *issue=_session.issue;
        [self showError:[issue hasPrefix:@"storage_"]?OR6L(@"Could not save your login on this iPhone. Try again."):[issue isEqual:@"invalid_session"]?OR6L(@"The session failed validation. Log in again."):OR6L(@"Could not verify login. Check your connection and try again.")];
    }
}
- (BOOL)webView:(UIWebView *)web shouldStartLoadWithRequest:(NSURLRequest *)r navigationType:(UIWebViewNavigationType)type {
    (void)web;(void)type;NSURL *u=r.URL;NSString *scheme=u.scheme.lowercaseString;
    if(![@[@"https",@"about",@"data",@"blob"]containsObject:scheme])return NO;
    BOOL main=!r.mainDocumentURL||[u isEqual:r.mainDocumentURL];
    NSString *h=u.host.lowercaseString;BOOL chat=[h isEqual:@"chatgpt.com"];
    if([h isEqual:@"accounts.google.com"])_googleSeen=YES;
    if(main){_documentCount++;_onChatGPT=chat;if([_delegate respondsToSelector:@selector(loginController:didNavigateToURL:loading:)])[_delegate loginController:self didNavigateToURL:u loading:YES];}
    BOOL completing=chat&&([u.path isEqual:@"/"]||[u.path hasPrefix:@"/c/"]||[u.path hasPrefix:@"/api/auth/callback"]||[u.path hasPrefix:@"/auth/callback"]);
    if(completing){_completionRequested=YES;_cover.hidden=NO;_retry.hidden=YES;[_spinner startAnimating];OR6LoginSetMessage(_message,OR6L(@"Finishing login…"));}
    else if(main && !chat)_cover.hidden=YES;
    return YES;
}
- (void)webViewDidFinishLoad:(UIWebView *)web {
    if(_stopped||web.loading)return;
    if([_delegate respondsToSelector:@selector(loginController:didNavigateToURL:loading:)])[_delegate loginController:self didNavigateToURL:web.request.URL loading:NO];
    NSString *state=[web stringByEvaluatingJavaScriptFromString:@"(function(){if(location.protocol!=='https:')return 'other';if(location.hostname!=='chatgpt.com')return 'provider';return location.pathname==='/auth/login'?'login':'chat';})()"];
    _onChatGPT=[@[@"login",@"chat"]containsObject:state];
    if([state isEqual:@"provider"]||[state isEqual:@"login"])_cover.hidden=YES;
    else if([state isEqual:@"chat"]){_completionRequested=YES;_cover.hidden=NO;OR6LoginSetMessage(_message,OR6L(@"Finishing login…"));}
}
- (void)webView:(UIWebView *)web didFailLoadWithError:(NSError *)error {(void)web;if(!_stopped&&[_delegate respondsToSelector:@selector(loginController:didNavigateToURL:loading:)])[_delegate loginController:self didNavigateToURL:web.request.URL loading:NO];if(error.code!=NSURLErrorCancelled&&!_stopped)[self showError:OR6L(@"The login page could not load. Check your connection and try again.")];}
- (NSDictionary *)diagnostics {return @{@"googleNavigationSeen":@(_googleSeen),@"webSessionStatus":@(_webStatus),@"webCredentialSubmitted":@(_submitted),@"documents":@(_documentCount)};}
- (void)stop {if(_onChatGPT)[_web stringByEvaluatingJavaScriptFromString:@"(function(){if(window===window.top&&location.protocol==='https:'&&location.hostname==='chatgpt.com'&&window.__OR6SessionAbort)window.__OR6SessionAbort.abort();})()"];_stopped=YES;[_timer invalidate];_web.delegate=nil;[_web stopLoading];if(_onChatGPT)[_web stringByEvaluatingJavaScriptFromString:@"if(location.protocol==='https:'&&location.hostname==='chatgpt.com')window.__OR6NativeAuth=null;"];}
- (void)dealloc {[self stop];[_timer release];[_web release];[_cover release];[_message release];[_retry release];[_spinner release];[_nonce release];[_probeStarted release];[_lastAttempt release];[_session release];[super dealloc];}
@end
