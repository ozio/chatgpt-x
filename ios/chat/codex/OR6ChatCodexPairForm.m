#import "OR6ChatCodexPairUI.h"
#import "../../ui/RCFormViewController.h"
#import "../../ui/RCHUD.h"
#import "../../ui/RCTheme.h"
#import "../../ui/priority8/OR6Chat8Screens.h"
#import "../../localization/OR6Localization.h"
@interface OR6CodexPairForm:RCFormViewController<RCFormDelegate>{
    OR6ChatCodexModel *_model;NSString *_code;BOOL _scanOnAppear,_chain;
}
- (id)initBackend:(id<OR6ChatCodexBackend>)backend code:(NSString *)code scan:(BOOL)scan;
- (void)render;
- (void)readStatus;
- (void)claim;
@end
@implementation OR6CodexPairForm
- (id)initBackend:(id<OR6ChatCodexBackend>)backend code:(NSString *)code scan:(BOOL)scan{
    if((self=[super init])){_model=[[OR6ChatCodexModel alloc]initWithBackend:backend];_code=[code copy];_scanOnAppear=scan;self.delegate=self;self.title=OR6L(@"Pair a computer");[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(changed:)name:OR6ChatCodexModelChanged object:_model];}return self;
}
- (void)viewDidLoad{[super viewDidLoad];self.tableView.accessibilityIdentifier=@"chat.codex.pair.form";}
- (void)viewWillAppear:(BOOL)a{[super viewWillAppear:a];if(_model.stale&&[_model sameAccount])[_model rebind];[self readStatus];}
- (void)viewDidAppear:(BOOL)a{[super viewDidAppear:a];if(_scanOnAppear){_scanOnAppear=NO;[self scan];}}
- (void)viewWillDisappear:(BOOL)a{[super viewWillDisappear:a];if(self.isMovingFromParentViewController)[_model cancel];}
- (void)changed:(NSNotification *)n{(void)n;if(_model.stale&&![_model sameAccount]){[_code release];_code=nil;}_chain=_model.stale?NO:_chain;[self render];}
- (void)readStatus{[_model call:@"codex.pair.status"parameters:@{}slot:@"status"mutation:NO completion:nil];[self render];}
- (RCFormRow *)note:(NSString *)text{return [RCFormRow rowWithKind:RCFormRowNote title:text];}
- (RCFormRow *)button:(NSString *)title action:(NSString *)action{
    RCFormRow *r=[RCFormRow rowWithKind:RCFormRowButton title:title];r.userInfo=action;r.identifier=[@"chat.codex.pair."stringByAppendingString:action];return r;
}
- (void)render{
    if(!self.isViewLoaded)return;self.busy=_model.busy||_chain;NSDictionary *status=_model.data[@"status"];
    NSMutableArray *rows=[NSMutableArray array];if(_model.error)[rows addObject:[self note:OR6ChatCodexError(_model.error)]];
    if([status[@"lastOAuthError"]count]&&!_model.error.userInfo[@"oauthFailure"])[rows addObject:[self note:OR6ChatCodexPairAuthorizationFailureText(status[@"lastOAuthError"])]];
    if(_model.stale){self.sections=@[[RCFormSection sectionWithTitle:nil rows:rows]];return;}
    [rows addObject:[self note:OR6L(@"Pairing on this legacy iPhone is experimental. The service may reject this device. You can also connect over SSH.")]];
    [rows addObject:[self note:OR6L(@"On your computer, open ChatGPT Settings → Connections → Control this Mac or PC → Add. Scan the QR code or enter its connection code.")]];
    RCFormRow *field=[RCFormRow rowWithKind:RCFormRowText title:OR6L(@"Connection code")];field.text=_code?:@"";field.placeholder=OR6L(@"Connection code");field.maxLength=2048;field.identifier=@"chat.codex.pair.code";field.userInfo=@"code";[rows addObject:field];
    [rows addObject:[self button:RCL(@"Scan QR code")action:@"scan"]];
    if([status[@"claimUncertain"]boolValue]||_model.uncertain)[rows addObject:[self note:OR6L(@"The previous pairing result is unconfirmed. Read connected computers before trying another code. The same code will not be sent again.")]];
    [rows addObject:[self button:OR6L(@"Connect")action:@"connect"]];
    NSMutableArray *recovery=[NSMutableArray array];if([status[@"hasClient"]boolValue]||[status[@"enrolled"]boolValue]){
        [recovery addObject:[self button:OR6L(@"Read connected computers")action:@"read"]];
        [recovery addObject:[self button:OR6L(@"Refresh connection authorization")action:@"refresh"]];
    }
    for(NSDictionary *host in _model.data[@"hosts"][@"data"]){RCFormRow *r=[RCFormRow rowWithKind:RCFormRowNote title:host[@"name"]];[recovery addObject:r];}
    id cursor=_model.data[@"hosts"][@"nextCursor"];if(cursor&&cursor!=NSNull.null)[recovery addObject:[self button:OR6L(@"Show more")action:@"more"]];
    if(![status[@"state"]isEqual:@"not_enrolled"])[recovery addObject:[self button:OR6L(@"Forget local setup…")action:@"forget"]];
    self.sections=@[[RCFormSection sectionWithTitle:OR6L(@"Connection")rows:rows],[RCFormSection sectionWithTitle:OR6L(@"Recovery")rows:recovery]];
}
- (void)form:(RCFormViewController *)f didChangeTextOfRow:(RCFormRow *)row{(void)f;if([row.userInfo isEqual:@"code"]){[_code release];_code=[row.text copy];}}
- (void)scan{
    if(_model.busy||_model.stale||_chain)return;[self endEditing];
    UIViewController *scanner=OR6ChatCodexPairScanner(^(NSString *code){if(_model.stale||!code)return;[_code release];_code=[code copy];[self render];});[self presentViewController:scanner animated:YES completion:nil];
}
- (void)connect{
    [self endEditing];if(_chain||_model.busy||_model.stale)return;
    NSString *code=OR6ChatCodexPairQRPayload(_code);if(!code){[RCHUD showText:OR6L(@"Check the connection code.")kind:RCHUDTextOnly inView:self.view seconds:2];return;}
    [_code release];_code=[code copy];NSDictionary *status=_model.data[@"status"];
    if([status[@"tokenCurrent"]boolValue]){[self claim];return;}
    if([status[@"hasClient"]boolValue]){[RCHUD showText:OR6L(@"Refresh connection authorization, then connect again.")kind:RCHUDTextOnly inView:self.view seconds:3];return;}
    _chain=YES;[self render];
    [_model call:@"codex.pair.authorize"parameters:@{}slot:nil mutation:NO completion:^(NSDictionary *r,NSError *e){
        if(e){_chain=NO;[self render];return;}
        UIViewController *auth=OR6ChatCodexPairAuthorization(_model.backend,[NSURL URLWithString:r[@"url"]],^(BOOL authorized){
            if(!authorized||_model.stale){_chain=NO;[self render];return;}
            [_model call:@"codex.pair.enroll"parameters:@{}slot:@"setup"mutation:YES completion:^(NSDictionary *setup,NSError *failed){(void)setup;
                if(failed){_chain=NO;[self readStatus];return;}[self claim];
            }];
        });
        if(auth)[self presentViewController:auth animated:YES completion:nil];else{_chain=NO;[self render];}
    }];
}
- (void)claim{
    if(_model.stale)return;_chain=YES;[self render];
    [_model call:@"codex.pair.claim"parameters:@{@"code":_code?:@""}slot:@"paired"mutation:YES completion:^(NSDictionary *r,NSError *e){
        _chain=NO;if(e){[self readStatus];return;}
        if(![r[@"confirmed"]boolValue]){[self readStatus];return;}
        [_code release];_code=nil;[RCHUD showText:OR6L(@"Computer paired")kind:RCHUDDone inView:self.view.window seconds:2];[self.navigationController popViewControllerAnimated:YES];
    }];
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row{
    (void)f;if(_model.busy||_chain||_model.stale)return;NSString *action=row.userInfo;
    if([action isEqual:@"scan"])[self scan];else if([action isEqual:@"connect"])[self connect];
    else if([action isEqual:@"refresh"]){[_model call:@"codex.pair.refresh"parameters:@{}slot:@"setup"mutation:YES completion:^(NSDictionary *r,NSError *e){(void)r;(void)e;[self readStatus];}];}
    else if([action isEqual:@"read"]||[action isEqual:@"more"]){NSMutableDictionary *p=[NSMutableDictionary dictionary];id cursor=_model.data[@"hosts"][@"nextCursor"];if([action isEqual:@"more"]&&cursor&&cursor!=NSNull.null)p[@"cursor"]=cursor;[_model call:@"codex.pair.environments"parameters:p slot:@"hosts"mutation:NO completion:^(NSDictionary *r,NSError *e){(void)r;(void)e;[self readStatus];}];}
    else if([action isEqual:@"forget"]){OR6ChatCodexAlert(OR6L(@"Forget local setup?"),OR6L(@"This removes the saved setup from this iPhone. Existing server pairings are not revoked."),OR6L(@"Forget"),NO,^(NSString *text){(void)text;[_model call:@"codex.pair.forget-local"parameters:@{@"confirmed":@YES}slot:nil mutation:NO completion:^(NSDictionary *r,NSError *e){(void)r;(void)e;[_model rebind];[self readStatus];}];});}
}
- (void)dealloc{[NSNotificationCenter.defaultCenter removeObserver:self];self.delegate=nil;[_model cancel];[_model release];[_code release];[super dealloc];}
@end
UIViewController *OR6ChatCodexPairScreen(id<OR6ChatCodexBackend>backend,NSString *code,BOOL scan){return [[[OR6CodexPairForm alloc]initBackend:backend code:code scan:scan]autorelease];}
