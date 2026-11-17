#import "OR6WebRootController.h"
#import "OR6AuthEngine.h"
#include <mach-o/dyld.h>
#include <unistd.h>
NSDictionary *OR6AuthEngine(void){
    BOOL j=NO,w=NO,t=NO,i=NO;
    for(uint32_t n=0;n<_dyld_image_count();n++){const char *p=_dyld_get_image_name(n);if(!p)continue;
        if(strstr(p,"/var/wkd/")&&strstr(p,"JavaScriptCore.framework"))j=YES;
        if(strstr(p,"/var/wkd/")&&strstr(p,"WebKitLegacy.framework"))w=YES;
        if(strstr(p,"/STBridge.dylib"))t=YES;if(strstr(p,"/WK26.dylib"))i=YES;
    }return @{@"modernJSC":@(j),@"modernWebKit":@(w),@"secureBridge":@(t),@"webPortAvailable":@(i||(j&&w))};
}
static NSUInteger WebCount(UIView *v){if([v isKindOfClass:UIWebView.class])return 1;NSUInteger n=0;for(UIView *c in v.subviews)n+=WebCount(c);return n;}
static NSString *IssueText(NSString *issue){
    if([issue isEqual:@"session_expired"]||[issue isEqual:@"invalid_session"])return @"Срок входа истёк. Войдите снова.";
    if([issue isEqual:@"logout_cleanup"])return @"Вход отключён. Нажмите «Выйти» ещё раз, чтобы завершить очистку.";
    if([issue hasPrefix:@"storage_"])return @"Не удалось сохранить изменения на iPhone. Повторите попытку.";
    if([issue isEqual:@"owner_changed"])return @"Сервис вернул другой аккаунт. Войдите снова.";
    if([issue isEqual:@"rate_limited"]||[issue isEqual:@"access_denied"])return @"Сервис временно ограничил доступ. Попробуйте позже.";
    return @"Сессия сохранена. Проверьте соединение и повторите попытку.";
}
@implementation OR6WebRootController
- (id)initWithSession:(OR6WebSession *)session{if((self=[super init])){_session=[session retain];_session.delegate=self;_active=YES;self.title=@"ChatGPT X";}return self;}
- (UILabel *)label:(CGRect)frame size:(CGFloat)size{UILabel *l=[[[UILabel alloc]initWithFrame:frame]autorelease];l.backgroundColor=[UIColor clearColor];l.textAlignment=NSTextAlignmentCenter;l.numberOfLines=0;l.font=[UIFont systemFontOfSize:size];[self.view addSubview:l];return l;}
- (UIButton *)button:(NSString *)title y:(CGFloat)y action:(SEL)action{UIButton *b=[UIButton buttonWithType:UIButtonTypeRoundedRect];b.frame=CGRectMake(35,y,250,44);[b setTitle:title forState:UIControlStateNormal];[b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:b];return b;}
- (void)loadView {
    self.view=[[[UIView alloc]initWithFrame:[UIScreen mainScreen].applicationFrame]autorelease];self.view.backgroundColor=[UIColor colorWithRed:.96 green:.96 blue:.97 alpha:1];
    _heading=[[self label:CGRectMake(20,40,280,60)size:25]retain];_heading.font=[UIFont boldSystemFontOfSize:25];_heading.accessibilityIdentifier=@"websession.heading";
    _message=[[self label:CGRectMake(25,110,270,100)size:16]retain];_message.accessibilityIdentifier=@"websession.message";
    _signIn=[[self button:@"Войти"y:225 action:@selector(signIn)]retain];_signIn.accessibilityIdentifier=@"websession.sign_in";
    _renew=[[self button:@"Обновить сессию"y:225 action:@selector(renew)]retain];_renew.accessibilityIdentifier=@"websession.renew";
    _retry=[[self button:@"Повторить"y:225 action:@selector(retry)]retain];_retry.accessibilityIdentifier=@"websession.retry";
    _signOut=[[self button:@"Выйти из ChatGPT X"y:280 action:@selector(signOut)]retain];_signOut.accessibilityIdentifier=@"websession.sign_out";
    _requirements=[[self label:CGRectMake(20,350,280,65)size:13]retain];_requirements.textColor=[UIColor darkGrayColor];
    _spinner=[[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];_spinner.center=CGPointMake(160,335);_spinner.hidesWhenStopped=YES;[self.view addSubview:_spinner];[self render];
}
- (void)render {
    if(!self.isViewLoaded)return;BOOL auth=_session.authenticated;NSString *p=_session.phase;
    BOOL busy=[@[@"restoring",@"signing_in",@"validating",@"refreshing"]containsObject:p];BOOL recovery=[p isEqual:@"recovery"];
    BOOL engine=[OR6AuthEngine()[@"webPortAvailable"]boolValue];
    _heading.text=auth?@"Вы вошли в ChatGPT":busy?@"Проверяем вход…":recovery?@"Не удалось подключиться":@"Войдите в ChatGPT";
    _message.text=busy?([p isEqual:@"refreshing"]?@"Обновляем сессию…":@"Восстанавливаем подключение…"):auth?(_session.renewable?@"Сессия сохранена и обновляется на этом iPhone.":@"Сессия сохранена. Позже может потребоваться повторный вход."):_session.issue.length?IssueText(_session.issue):@"Войдите в свой аккаунт ChatGPT. После входа вы вернётесь в приложение.";
    _signIn.hidden=auth||busy;_signIn.enabled=engine;_signIn.frame=CGRectMake(35,recovery?280:225,250,44);
    [_signIn setTitle:recovery?@"Войти заново":@"Войти"forState:UIControlStateNormal];
    _renew.hidden=!auth||busy;_renew.enabled=_session.renewable;
    _retry.hidden=!recovery;_retry.enabled=!busy;
    _signOut.hidden=!_session.hasStoredSession&&!recovery;_signOut.enabled=!_login;_signOut.frame=CGRectMake(35,recovery?335:280,250,44);
    _requirements.frame=CGRectMake(20,recovery?395:350,280,65);_requirements.hidden=auth||busy||engine;_requirements.text=@"Для входа включите Web Port для ChatGPT X и перезапустите приложение.";
    if(busy)[_spinner startAnimating];else[_spinner stopAnimating];
}
- (void)start{if(_started)return;_started=YES;[_session restore];}
- (void)reschedule {
    [_renewalTimer invalidate];[_renewalTimer release];_renewalTimer=nil;
    NSTimeInterval delay=[_session secondsUntilRenewal];if(_active&&delay>=0&&!_login)_renewalTimer=[[NSTimer scheduledTimerWithTimeInterval:MAX(1,delay)target:self selector:@selector(timer:)userInfo:nil repeats:NO]retain];
}
- (void)timer:(NSTimer *)timer{(void)timer;[_session activate];[self reschedule];[self writeReceipt];}
- (void)activate{_active=YES;[_session activate];[self reschedule];[self writeReceipt];}
- (void)deactivate{_active=NO;[_renewalTimer invalidate];[_renewalTimer release];_renewalTimer=nil;}
- (void)renew{[_session renew];}
- (void)retry{if(!_login)[_session restore];}
- (void)signIn{
    if(_login||![OR6AuthEngine()[@"webPortAvailable"]boolValue])return;
    NSUInteger generation=[_session beginSignIn];_login=[[OR6WebLoginController alloc]initWithSession:_session generation:generation];_login.delegate=self;
    UINavigationController *nav=[[[UINavigationController alloc]initWithRootViewController:_login]autorelease];[self.navigationController presentViewController:nav animated:YES completion:^{[self writeReceipt];}];
}
- (void)dismissLogin{
    if(!_login)return;[_lastLogin release];_lastLogin=[[_login diagnostics]copy];[_login stop];_login.delegate=nil;
    [self.navigationController dismissViewControllerAnimated:NO completion:^{[_login release];_login=nil;[self render];[self reschedule];[self writeReceipt];}];
}
- (void)loginControllerCancelled:(OR6WebLoginController *)controller{if(controller!=_login)return;_cancellations++;[_session cancelSignIn];[self dismissLogin];}
- (void)signOut{if(_login)return;if([_session signOut])_signOuts++;[self writeReceipt];}
- (void)webSessionChanged:(OR6WebSession *)session{(void)session;_events++;[_login sessionChanged];[self render];[self reschedule];if(_session.authenticated&&_login)[self dismissLogin];else[self writeReceipt];}
- (void)writeReceipt {
    UIWindow *window=[(id)[UIApplication sharedApplication].delegate window];
    NSDictionary *r=@{@"schema":@3,@"bundleID":@"io.ozio.chatgptx",@"pid":@((int)getpid()),@"session":[_session diagnostics],@"engine":OR6AuthEngine(),
        @"nativeScreen":_session.authenticated?@"authenticated":@"welcome",@"webModalPresented":@(self.navigationController.presentedViewController!=nil),@"webViewsInWindow":@(window?WebCount(window):0),
        @"login":_login?[_login diagnostics]:(_lastLogin?:@{}),@"events":@(_events),@"signOuts":@(_signOuts),@"cancellations":@(_cancellations),@"requiresMacBridge":@NO,@"credentialsExportedToHost":@NO,@"credentialObservation":@NO};
    NSString *dir=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES)[0];[[NSJSONSerialization dataWithJSONObject:r options:0 error:NULL]writeToFile:[dir stringByAppendingPathComponent:@"WebSessionState.json"]atomically:YES];
}
- (void)viewDidAppear:(BOOL)animated{[super viewDidAppear:animated];[self writeReceipt];}
- (void)dealloc{[self deactivate];[_login stop];_session.delegate=nil;[_session release];[_login release];[_lastLogin release];[_heading release];[_message release];[_requirements release];[_signIn release];[_signOut release];[_retry release];[_renew release];[_spinner release];[super dealloc];}
@end
