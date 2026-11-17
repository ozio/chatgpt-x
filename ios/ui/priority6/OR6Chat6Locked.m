// «Закрытые чаты» (prototype s-tools.js lockedScreen, stage 6): drawer → server status → PIN keypad →
// list of locked chats → read-only chat; Privacy → «Закрытые чаты» (PIN create / change / reset);
// chat «⋯» → «Закрыть чат…» (PIN, then locked.conversations.lock). Real server protection (API6A):
// PINs go from the keypad to the trusted host (6A binder) for exactly one operation ID and never
// through Core; the short server grant lives only in 6A memory and is dropped when the screen
// closes or the app goes to the background. Protected chats are shown read-only from
// locked.conversations.get with every message kept (non-text parts as explicit placeholders) and
// are never stored (no history cache, drafts, snapshots, PDF or share). A remote change runs only
// after the user's explicit confirmation, with one operation ID and the read-only locked.reconcile
// after an unknown result.
#import "OR6Chat6Base.h"
#import "RCPINViewController.h"
#import "RCReportViewController.h"
#import "RCSourcesSheet.h"
#import "RCGlyph.h"
#import "RCHUD.h"

static NSString *ResetText(NSString *reset) {
    return [reset isEqual:@"in_progress"] ? OR6L(@"The PIN is being reset: locked chats are being deleted. Check again later.")
         : [reset isEqual:@"failed"] ? OR6L(@"The last PIN reset did not finish. Locked chats may still exist.")
         : OR6L(@"The state of the PIN reset is unknown. Check again later.");
}

#pragma mark - Read-only locked chat (the viewer owns its actions: F5)

@interface OR6Chat6LockedChat : UIViewController <OR6Chat8ModelDelegate, RCReportViewControllerDelegate> {
    OR6APICore *_core; NSString *_projectId, *_conversationId, *_chatTitle; OR6Chat7Call *_read, *_memory;
    RCReportViewController *_report; RCFormViewController *_state; BOOL _started;
}
- (id)initWithCore:(OR6APICore *)core project:(NSString *)projectId conversation:(NSString *)conversationId title:(NSString *)title;
@property (nonatomic, copy) void (^unlocked)(void);
- (void)wipe;
@end

@implementation OR6Chat6LockedChat
@synthesize unlocked = _unlocked;
- (id)initWithCore:(OR6APICore *)core project:(NSString *)p conversation:(NSString *)c title:(NSString *)t {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _core = [core retain]; _projectId = [p copy]; _conversationId = [c copy]; _chatTitle = [t copy]; self.title = OR6L(@"Locked chat");
        _read = [[OR6Chat7Call alloc] initWithCore:core]; _read.delegate = self; _memory = [[OR6Chat7Call alloc] initWithCore:core]; _memory.delegate = self;
    }
    return self;
}
- (void)loadView {
    UIView *v = [[[UIView alloc] initWithFrame:UIScreen.mainScreen.applicationFrame] autorelease]; v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; self.view = v;
    _state = [[RCFormViewController alloc] init]; _state.tableView.accessibilityIdentifier = @"chat.locked.chat"; [self embed:_state];
}
- (void)embed:(UIViewController *)c {
    for (UIViewController *o in [[self.childViewControllers copy] autorelease]) { [o willMoveToParentViewController:nil]; [o.view removeFromSuperview]; [o removeFromParentViewController]; }
    [self addChildViewController:c]; c.view.frame = self.view.bounds; c.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; [self.view addSubview:c.view]; [c didMoveToParentViewController:self];
}
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; if (!_started) { _started = YES; [self load]; } }
- (void)load { [_read perform:@"locked.conversations.get" parameters:@{@"projectId": _projectId, @"conversationId": _conversationId}]; [self renderState]; }
- (void)renderState {
    NSMutableArray *rows = [NSMutableArray array];
    if (_read.busy || (!_read.error && !_read.result)) [rows addObject:[RCFormRow rowWithKind:RCFormRowNote title:OR6L(@"Loading…")]];
    else if (_read.error) {
        [rows addObject:[RCFormRow rowWithKind:RCFormRowNote title:OR6Chat7ErrorText(_read.error)]];
        if (OR6Chat7Retryable(_read.error)) { RCFormRow *r = [RCFormRow rowWithKind:RCFormRowButton title:OR6L(@"Read again")]; r.identifier = @"chat.locked.chat.retry"; r.userInfo = @"retry"; [rows addObject:r]; _state.delegate = (id)self; }
    } else [rows addObject:[RCFormRow rowWithKind:RCFormRowNote title:OR6L(@"This chat arrived in an unknown format.")]];
    _state.sections = @[[RCFormSection sectionWithTitle:nil rows:rows]];
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row { (void)f; if ([row.userInfo isEqual:@"retry"]) [self load]; }
- (void)showConversation:(NSDictionary *)c {
    NSDictionary *t = OR6Chat6LockedTranscript(c); NSUInteger n = [t[@"messages"] unsignedIntegerValue];
    NSString *md = [t[@"markdown"] length] ? t[@"markdown"] : [NSString stringWithFormat:@"_%@_", OR6L(@"This chat has no messages.")];
    if (!_report) { _report = [[RCReportViewController alloc] initWithTitle:OR6Chat6Text(c[@"title"], _chatTitle) markdown:md]; _report.delegate = self; }
    else { _report.reportTitle = OR6Chat6Text(c[@"title"], _chatTitle); _report.markdown = md; }
    _report.savePDFAvailable = NO; _report.shareAvailable = NO; // protected content is never exported or shared from here
    NSMutableArray *sources = [NSMutableArray array];
    for (NSDictionary *s in t[@"sources"]) { NSURL *u = [NSURL URLWithString:s[@"url"]]; if (u) [sources addObject:[RCSourceItem sourceWithTitle:s[@"title"] host:s[@"host"] URL:u]]; }
    _report.sources = sources;
    [self renderMeta:n];
    [self embed:_report];
    if (OR6Chat6On(_core, @"locked.conversations.unlock")) {
        UIBarButtonItem *b = [[[UIBarButtonItem alloc] initWithImage:[RCGlyph imageNamed:@"more" size:20 color:[UIColor whiteColor]] style:UIBarButtonItemStyleBordered target:self action:@selector(actions)] autorelease];
        b.accessibilityLabel = OR6L(@"Chat actions"); self.navigationItem.rightBarButtonItem = b; // target: this viewer, alive as long as its bar
    }
    if (OR6Chat6On(_core, @"locked.memory") && !_memory.result && !_memory.busy) [_memory perform:@"locked.memory" parameters:@{@"projectId": _projectId, @"conversationId": _conversationId}];
}
- (void)renderMeta:(NSUInteger)n {
    NSString *meta = [NSString stringWithFormat:OR6L(@"Locked chat · read only · %lu messages"), (unsigned long)n];
    NSDictionary *m = _memory.result;
    if (!_memory.error && [m[@"locked"] isEqual:@YES] && [m[@"newMessagesContributeToMemory"] isEqual:@NO] && [m[@"projectId"] isEqual:_projectId])
        meta = [meta stringByAppendingFormat:@" · %@", OR6L(@"not added to memory")];
    _report.meta = meta;
}
- (void)chat8ModelChanged:(id)m {
    if (!self.navigationController && !self.parentViewController) return;
    if (m == _read && !_read.busy) {
        NSDictionary *c = _read.result;
        if (!_read.error && [c[@"id"] isEqual:_conversationId] && [c[@"messages"] isKindOfClass:NSArray.class]) [self showConversation:c];
        else { if (_read.error && [_read.error.userInfo[@"code"] isEqual:@"access_denied"]) { [self.navigationController popViewControllerAnimated:YES]; return; } [self embed:_state]; [self renderState]; }
        return;
    }
    if (m == _memory && !_memory.busy && _report) [self renderMeta:[OR6Chat6LockedTranscript(_read.result)[@"messages"] unsignedIntegerValue]];
}
- (void)report:(RCReportViewController *)r didSelectSource:(RCSourceItem *)s { (void)r; NSString *sch = s.URL.scheme.lowercaseString; if ([sch isEqual:@"https"] || [sch isEqual:@"http"]) [UIApplication.sharedApplication openURL:s.URL]; }
- (void)actions {
    if (!OR6Chat6On(_core, @"locked.conversations.unlock")) return;
    void (^done)(void) = [[_unlocked copy] autorelease]; UINavigationController *nc = self.navigationController; NSString *cid = _conversationId, *pid = _projectId; OR6APICore *core = _core; UIViewController *me = self;
    OR6Chat8ShowSheet(self.view.window ?: self.view, OR6L(@"Remove protection? The chat returns to the chat list and search, and follows your usual memory settings again."), @[OR6L(@"Remove protection")], nil, ^(NSInteger n, NSString *t) {
        (void)t; if (n != 0) return;
        OR6Chat7RunWrite(nc.view.window, core, @"locked.conversations.unlock", @{@"projectId": pid, @"conversationId": cid}, [@"locked.conversations.unlock:" stringByAppendingString:cid], @"locked.reconcile", OR6L(@"The chat is back in the list."),
                         ^(NSDictionary *r) { (void)r; if (done) done(); if (nc.topViewController == me) [nc popViewControllerAnimated:YES]; });
    });
}
- (void)wipe { [_read cancel]; [_read reset]; [_memory cancel]; [_memory reset]; _report.markdown = @""; _report.sources = @[]; } // protected text leaves memory with the screen
- (void)dealloc {
    _read.delegate = nil; _memory.delegate = nil; [_read cancel]; [_memory cancel]; _report.delegate = nil; _state.delegate = nil;
    [_read release]; [_memory release]; [_report release]; [_state release]; [_core release]; [_projectId release]; [_conversationId release]; [_chatTitle release]; [_unlocked release]; [super dealloc];
}
@end

#pragma mark - PIN flow (status → keypad → grant) shared by the list, lock and settings

typedef enum { OR6LockedPurposeList = 0, OR6LockedPurposeLock, OR6LockedPurposeSettings } OR6LockedPurpose;

@interface OR6Chat6LockedScreen : UIViewController <RCPINViewControllerDelegate, RCFormDelegate, OR6Chat8ModelDelegate> {
    OR6APICore *_core; id<OR6Chat7Navigator> _nav; OR6LockedPurpose _purpose; NSString *_target, *_targetTitle;
    OR6Chat7Call *_status, *_verify; OR6Chat7Write *_pinWrite; OR6Chat6Pager *_list;
    RCFormViewController *_form; RCPINViewController *_pin; UIViewController *_shown;
    NSString *_phase, *_projectId, *_currentPIN, *_resetAuthorization, *_notice; BOOL _started, _wrongPIN, _lockDone; NSUInteger _life;
}
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav purpose:(OR6LockedPurpose)purpose target:(NSString *)conversationId title:(NSString *)title;
@end

@implementation OR6Chat6LockedScreen
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav purpose:(OR6LockedPurpose)purpose target:(NSString *)cid title:(NSString *)title {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _core = [core retain]; _nav = nav; _purpose = purpose; _target = [cid copy]; _targetTitle = [title copy];
        self.title = purpose == OR6LockedPurposeLock ? OR6L(@"Lock chat") : OR6L(@"Locked chats");
        _status = [[OR6Chat7Call alloc] initWithCore:core]; _status.delegate = self;
        _verify = [[OR6Chat7Call alloc] initWithCore:core]; _verify.delegate = self;
        _phase = [@"status" retain];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(background:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(foreground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    }
    return self;
}
- (void)foreground:(NSNotification *)n { (void)n; if (!_started && self.view.window) { _started = YES; [self readStatus]; } } // the status read again after the background wiped the grant
- (void)loadView {
    UIView *v = [[[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame] autorelease];
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; self.view = v;
    _form = [[RCFormViewController alloc] init]; _form.delegate = self; _form.tableView.accessibilityIdentifier = _purpose == OR6LockedPurposeSettings ? @"chat.locked_settings.table" : @"chat.locked.table";
    [self show:_form];
}
- (void)show:(UIViewController *)c {
    if (_shown == c) return;
    if (_shown) { [_shown willMoveToParentViewController:nil]; [_shown.view removeFromSuperview]; [_shown removeFromParentViewController]; }
    _shown = c; [self addChildViewController:c]; c.view.frame = self.view.bounds;
    c.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:c.view]; [c didMoveToParentViewController:self];
}
- (void)viewWillAppear:(BOOL)a { [super viewWillAppear:a]; if (!_started) { _started = YES; [self readStatus]; } [self render]; }
- (void)setPhase:(NSString *)p { [_phase release]; _phase = [p copy]; }
- (void)setNotice:(NSString *)n { [_notice release]; _notice = [n copy]; }
- (UIView *)hud { return self.view.window ?: self.view; }

#pragma mark Server status

- (void)readStatus { [self setPhase:@"status"]; [self show:_form]; [_status perform:@"locked.status" parameters:@{}]; [self render]; }
- (NSDictionary *)statusResult { return [_status.result isKindOfClass:NSDictionary.class] ? _status.result : nil; }
- (void)statusArrived {
    NSDictionary *s = [self statusResult]; if (!s) { [self render]; return; }
    BOOL hasPIN = [s[@"hasPIN"] isEqual:@YES]; NSString *reset = OR6Chat6Text(s[@"resetStatus"], nil);
    NSUInteger wait = [s[@"retryAfterSeconds"] isKindOfClass:NSNumber.class] ? [s[@"retryAfterSeconds"] unsignedIntegerValue] : 0;
    if (_purpose == OR6LockedPurposeSettings || reset || !hasPIN) { [self setPhase:@"info"]; [self show:_form]; [self render]; return; }
    [self setPhase:@"pin"]; [self showPIN:RCPINModeUnlock title:nil];
    if (wait) [_pin lockForSeconds:wait]; // the server's lockout, never a counted guess (privacy.locked_retry_limits)
    else if (_wrongPIN) [_pin showError:OR6L(@"Wrong PIN")];
    _wrongPIN = NO;
}
- (void)showPIN:(RCPINMode)mode title:(NSString *)title {
    if (!_pin || _pin.mode != mode) { _pin.delegate = nil; [_pin release]; _pin = [[RCPINViewController alloc] initWithMode:mode]; _pin.delegate = self; _pin.showsCancel = NO; }
    _pin.titleText = title;
    _pin.message = [_phase isEqual:@"change-current"] ? OR6L(@"Enter your current PIN.") : [_phase isEqual:@"change-new"] ? OR6L(@"Choose a new PIN.")
                 : _purpose == OR6LockedPurposeLock ? [NSString stringWithFormat:OR6L(@"Enter your PIN to lock «%@»."), OR6Chat6Text(_targetTitle, OR6L(@"this chat"))]
                 : mode == RCPINModeUnlock ? OR6L(@"Locked chats are hidden from the chat list and search.") : nil;
    [_pin reset]; [self show:_pin];
}

#pragma mark Keypad → trusted host → one operation

- (BOOL)bind:(NSDictionary *)secrets op:(NSString *)op error:(NSError **)e {
    id<OR6Chat6TrustedHost> host = OR6Chat6TrustedHostNow();
    if (!host) { if (e) *e = OR6APIError(@"capability_unverified", @"none"); return NO; }
    return [host chat6BindLockedSecrets:secrets operationId:op error:e];
}
- (BOOL)pinController:(RCPINViewController *)c checkPIN:(NSString *)pin {
    if ([_phase isEqual:@"change-current"]) { // kept in memory only until the new PIN is chosen
        [_currentPIN release]; _currentPIN = [pin copy]; [self setPhase:@"change-new"]; [self showPIN:RCPINModeSet title:nil]; return YES;
    }
    NSString *op = OR6Chat7OperationID(); NSError *e = nil;
    if (![self bind:@{@"pin": pin} op:op error:&e]) { [c showError:OR6Chat7ErrorText(e)]; return YES; }
    c.checking = YES;
    if (![_verify perform:@"locked.pin.verify" parameters:@{@"operationId": op}]) [c showError:OR6L(@"This function is not available in this build.")];
    return YES; // the service answers; -verifyArrived ends «Проверка…»
}
- (void)pinController:(RCPINViewController *)c didSetPIN:(NSString *)pin {
    BOOL change = [_phase isEqual:@"change-new"]; NSString *op = OR6Chat7OperationID(); NSError *e = nil;
    NSString *write = change ? @"locked.pin.change" : @"locked.pin.create";
    if (OR6Chat7IsUnresolved([write stringByAppendingString:@":account"]) || [_pinWrite.phase isEqual:@"uncertain"]) { // never bind or send again while an earlier attempt is unknown
        [_currentPIN release]; _currentPIN = nil; [self setNotice:OR6L(@"An earlier attempt has an unknown result. It is not sent again; check it first.")]; [self show:_form]; [self setPhase:@"info"]; [self render]; return;
    }
    NSDictionary *secrets = change ? @{@"current_pin": _currentPIN ?: @"", @"new_pin": pin} : @{@"pin": pin, @"pin_confirmation": pin};
    [_currentPIN release]; _currentPIN = nil; // the host holds it for this one operation now
    if (![self bind:secrets op:op error:&e]) { [c showError:OR6Chat7ErrorText(e)]; return; }
    c.checking = YES;
    if (!_pinWrite) { _pinWrite = [[OR6Chat7Write alloc] initWithCore:_core reconcile:@"locked.reconcile"]; _pinWrite.delegate = self; }
    // The secrets are bound to exactly this operation ID, so the write runs with it (6A journals it, sends once, never replays).
    if (![_pinWrite perform:write parameters:@{} intent:[write stringByAppendingString:@":account"] operationId:op]) { c.checking = NO; [self pinWriteEnded]; }
}
- (void)pinWriteEnded {
    NSString *p = _pinWrite.phase; if ([p isEqual:@"running"] || [p isEqual:@"reconciling"]) return;
    _pin.checking = NO; BOOL change = [_pinWrite.operation isEqual:@"locked.pin.change"];
    if ([p isEqual:@"done"] && [_pinWrite.receipt[@"operationId"] isEqual:_pinWrite.operationId] && _pinWrite.receipt[@"completed"]) { // a read-only reconcile answered
        [self setNotice:[_pinWrite.receipt[@"completed"] isEqual:@YES] ? (change ? OR6L(@"The PIN was changed.") : OR6L(@"The PIN was created.")) : OR6L(@"The result is still unknown. Nothing was sent again.")]; [self readStatus]; return;
    }
    if ([p isEqual:@"done"]) {
        OR6Chat6Say([self hud], change ? OR6L(@"The PIN was changed.") : OR6L(@"The PIN was created."));
        NSDictionary *st = [_pinWrite.receipt[@"status"] isKindOfClass:NSDictionary.class] ? _pinWrite.receipt[@"status"] : nil;
        if (!change && [_pinWrite.receipt[@"accessGranted"] isEqual:@YES] && OR6Chat6Text(st[@"projectId"], nil) && _purpose != OR6LockedPurposeSettings) { [self granted:st[@"projectId"]]; return; }
    } else if ([p isEqual:@"uncertain"]) [self setNotice:OR6L(@"The result is unknown. It is not sent again; the PIN state below is read from the service.")]; // «Check» (locked.reconcile) is offered below
    else [self setNotice:_pinWrite.error ? OR6Chat7ErrorText(_pinWrite.error) : OR6L(@"The PIN was not changed.")];
    [self readStatus]; // whatever happened, the server status says whether a PIN exists now (read-only)
}
- (void)verifyArrived {
    if (_verify.busy) return;
    if (!_verify.error && [_verify.result[@"accessGranted"] isEqual:@YES]) {
        NSDictionary *st = [_verify.result[@"status"] isKindOfClass:NSDictionary.class] ? _verify.result[@"status"] : nil;
        NSString *project = OR6Chat6Text(st[@"projectId"], OR6Chat6Text([self statusResult][@"projectId"], nil));
        if (!project) { [_pin showError:OR6L(@"This action is not possible in the current state.")]; return; }
        _pin.checking = NO; [self granted:project]; return;
    }
    NSString *code = _verify.error.userInfo[@"code"];
    if ([code isEqual:@"access_denied"] || [code isEqual:@"rate_limited"] || (!_verify.error && [_verify.result[@"accessGranted"] isEqual:@NO])) { _wrongPIN = ![code isEqual:@"rate_limited"]; [_status perform:@"locked.status" parameters:@{}]; return; }
    [_pin showError:_verify.error ? OR6Chat7ErrorText(_verify.error) : OR6L(@"This action is not possible in the current state.")];
}
- (void)granted:(NSString *)project {
    if (!project) return;
    [_projectId release]; _projectId = [project copy];
    if (_purpose == OR6LockedPurposeLock) { [self setPhase:@"lock"]; [self show:_form]; [self render]; [self confirmLock]; return; }
    [self setPhase:@"list"]; [self show:_form];
    _list.delegate = nil; [_list release]; _list = [[OR6Chat6Pager alloc] initWithCore:_core operation:@"locked.conversations.list" parameters:@{@"projectId": project, @"limit": @20} tokenKey:@"cursor" nextKey:@"nextCursor" idKey:@"id"];
    _list.delegate = self; [_list reload]; [self render];
}

#pragma mark Lock a regular chat (locked.conversations.lock)

- (void)confirmLock {
    if (!_projectId || !_target || _lockDone) return;
    NSString *pid = [[_projectId copy] autorelease], *cid = [[_target copy] autorelease]; id<OR6Chat7Navigator> nav = _nav; UINavigationController *nc = self.navigationController;
    OR6Chat8ShowSheet([self hud], [NSString stringWithFormat:OR6L(@"Lock «%@»? It moves to Locked chats, is hidden from the chat list and search, and new messages in it are not added to memory."), OR6Chat6Text(_targetTitle, OR6L(@"this chat"))],
                      @[OR6L(@"Lock chat")], nil, ^(NSInteger n, NSString *t) {
        (void)t; if (n != 0) { [self render]; return; }
        OR6Chat7RunWrite(nc.view.window, _core, @"locked.conversations.lock", @{@"projectId": pid, @"conversationId": cid}, [@"locked.conversations.lock:" stringByAppendingString:cid], @"locked.reconcile", OR6L(@"The chat is locked."), ^(NSDictionary *r) {
            (void)r; _lockDone = YES; [nav chat7Conversation:cid changed:@"locked"]; NSUInteger at = [nc.viewControllers indexOfObject:self]; if (at != NSNotFound && at > 0) [nc popToViewController:nc.viewControllers[at - 1] animated:YES];
        });
    });
}

#pragma mark PIN reset (challenge → first-party reauthentication → reset)

- (BOOL)resetAvailable { id<OR6Chat6TrustedHost> h = OR6Chat6TrustedHostNow(); return [OR6Chat6PINResetRoute([h respondsToSelector:@selector(chat6BeginPINReset:completion:)], OR6Chat6AllOn(_core, @[@"locked.pin.resetChallenge", @"locked.pin.reset"])) isEqual:@"native"]; }
// No proven native reauthentication: the real first-party account PIN page; nothing is sent from the app (completed:false).
- (void)openResetPage {
    OR6Chat8ShowSheet([self hud], OR6L(@"Reset the PIN on the ChatGPT website? There you confirm with your password, and every locked chat is deleted. ChatGPT X sends nothing and cannot see the result until you check again."), @[OR6L(@"Open in Safari")], nil, ^(NSInteger n, NSString *t) {
        (void)t; if (n != 0) return;
        if ([UIApplication.sharedApplication openURL:OR6Chat6PINSettingsURL()]) { [self setNotice:OR6L(@"Continue in Safari. Nothing was reset in ChatGPT X; tap Check again when you return.")]; [self render]; }
    });
}
- (void)startReset {
    OR6Chat8ShowSheet([self hud], OR6L(@"Reset the PIN? All locked chats are deleted for good. You confirm it on the ChatGPT website with your account password first."), @[], OR6L(@"Delete locked chats and reset"), ^(NSInteger n, NSString *t) {
        (void)t; if (n != -2) return;
        OR6Chat7RunWrite([self hud], _core, @"locked.pin.resetChallenge", @{}, @"locked.pin.resetChallenge:account", @"locked.reconcile", OR6L(@"Confirm on the website."), ^(NSDictionary *auth) {
            if (!OR6Chat7ConversationUUID(auth[@"authorizationId"]) || ![auth[@"completed"] isEqual:@NO]) { [self setNotice:OR6L(@"This action is not possible in the current state.")]; [self render]; return; }
            id<OR6Chat6TrustedHost> h = OR6Chat6TrustedHostNow(); NSString *authorization = auth[@"authorizationId"];
            BOOL opened = [h respondsToSelector:@selector(chat6BeginPINReset:completion:)] && [h chat6BeginPINReset:auth completion:^(BOOL accepted, NSError *e) {
                if (!accepted) { [self setNotice:e ? OR6Chat7ErrorText(e) : OR6L(@"The confirmation on the website was not completed. Nothing was reset.")]; [self render]; return; }
                [_resetAuthorization release]; _resetAuthorization = [authorization copy];
                if (!self.view.window) { [_resetAuthorization release]; _resetAuthorization = nil; return; } // the screen is gone: nothing destructive runs unseen
                OR6Chat8ShowSheet([self hud], OR6L(@"Your sign-in is confirmed. Delete every locked chat and reset the PIN now?"), @[], OR6L(@"Delete locked chats and reset"), ^(NSInteger k, NSString *x) {
                    (void)x; if (k == -2 && self.view.window) [self finishReset]; else { [_resetAuthorization release]; _resetAuthorization = nil; [self setNotice:OR6L(@"Nothing was reset.")]; [self render]; }
                });
            }];
            if (!opened) { [self setNotice:OR6L(@"The website could not be opened. Nothing was reset.")]; [self render]; }
        });
    });
}
- (void)finishReset {
    if (!_resetAuthorization) return; NSString *a = [[_resetAuthorization retain] autorelease]; [_resetAuthorization release]; _resetAuthorization = nil;
    OR6Chat7RunWrite([self hud], _core, @"locked.pin.reset", @{@"authorizationId": a, @"confirmDeleteLockedChats": @YES}, [@"locked.pin.reset:" stringByAppendingString:a], @"locked.reconcile", OR6L(@"The PIN reset has started."), ^(NSDictionary *r) {
        NSString *reset = OR6Chat6Text(r[@"resetStatus"], nil); [self setNotice:reset ? ResetText(reset) : OR6L(@"The PIN was reset. Locked chats were deleted.")]; [self readStatus];
    });
}

#pragma mark Rendering

- (void)chat8ModelChanged:(id)m {
    if (m == _status && !_status.busy && [_phase isEqual:@"pin"] && _status.error) { [_pin showError:OR6Chat7ErrorText(_status.error)]; return; }
    if (m == _status && !_status.busy && !_status.error) { [self statusArrived]; return; }
    if (m == _verify) { [self verifyArrived]; return; }
    if (m == _pinWrite) { [self pinWriteEnded]; return; }
    if (m == _list && !_list.busy && _list.error && [_list.error.userInfo[@"code"] isEqual:@"access_denied"]) { [self forget]; [self readStatus]; return; } // the grant expired: PIN again
    [self render];
}
- (RCFormRow *)note:(NSString *)t { return [RCFormRow rowWithKind:RCFormRowNote title:t]; }
- (RCFormRow *)button:(NSString *)t info:(id)i identifier:(NSString *)ident { RCFormRow *r = [RCFormRow rowWithKind:RCFormRowButton title:t]; r.userInfo = i; r.identifier = ident; return r; }
- (void)render {
    if (![self isViewLoaded]) return;
    NSMutableArray *sections = [NSMutableArray array];
    if (_notice) [sections addObject:[RCFormSection sectionWithTitle:nil rows:@[[self note:_notice]]]];
    if ([_phase isEqual:@"status"] || [_phase isEqual:@"pin"] || [_phase isEqual:@"lock"]) {
        NSMutableArray *rows = [NSMutableArray array];
        if ([_phase isEqual:@"lock"]) [rows addObject:[self note:_lockDone ? OR6L(@"The chat is locked.") : OR6L(@"Confirm to lock the chat.")]];
        else if (_status.busy || !_status.error) [rows addObject:[self note:OR6L(@"Loading…")]];
        else { [rows addObject:[self note:OR6Chat7ErrorText(_status.error)]]; if (OR6Chat7Retryable(_status.error)) [rows addObject:[self button:OR6L(@"Read again") info:@"status" identifier:@"chat.locked.retry"]]; }
        if ([_phase isEqual:@"lock"] && !_lockDone) [rows addObject:[self button:OR6L(@"Lock chat") info:@"lock" identifier:@"chat.lock.confirm"]];
        [sections addObject:[RCFormSection sectionWithTitle:nil rows:rows]];
    } else if ([_phase isEqual:@"info"]) {
        NSDictionary *s = [self statusResult]; NSString *reset = OR6Chat6Text(s[@"resetStatus"], nil); BOOL hasPIN = [s[@"hasPIN"] isEqual:@YES];
        NSMutableArray *rows = [NSMutableArray array];
        if (_purpose == OR6LockedPurposeSettings) {
            [rows addObject:[RCFormRow rowWithKind:RCFormRowValue title:OR6L(@"PIN")]]; ((RCFormRow *)rows.lastObject).value = hasPIN ? OR6L(@"Set") : OR6L(@"Not set"); ((RCFormRow *)rows.lastObject).identifier = @"chat.locked_settings.pin"; ((RCFormRow *)rows.lastObject).enabled = NO;
            NSUInteger wait = [s[@"retryAfterSeconds"] unsignedIntegerValue];
            if (wait) [rows addObject:[self note:[NSString stringWithFormat:OR6L(@"Too many wrong PINs. The service allows a new try in %lu min."), (unsigned long)((wait + 59) / 60)]]];
        }
        if (reset) [rows addObject:[self note:ResetText(reset)]];
        else if (!hasPIN && _purpose != OR6LockedPurposeSettings) [rows addObject:[self note:(_purpose == OR6LockedPurposeLock ? OR6L(@"Create a PIN first. Locked chats open only with it.") : OR6L(@"No locked chats. Locked chats are not set up for this account."))]];
        if (!reset && !hasPIN && OR6Chat6On(_core, @"locked.pin.create")) [rows addObject:[self button:OR6L(@"Create a PIN") info:@"create" identifier:@"chat.locked.create"]];
        if (!reset && hasPIN && _purpose == OR6LockedPurposeSettings && OR6Chat6On(_core, @"locked.pin.change")) [rows addObject:[self button:OR6L(@"Change PIN") info:@"change" identifier:@"chat.locked_settings.change"]];
        if (reset) [rows addObject:[self button:OR6L(@"Check again") info:@"status" identifier:@"chat.locked.recheck"]];
        if ([_pinWrite.phase isEqual:@"uncertain"] && OR6Chat6On(_core, @"locked.reconcile")) [rows addObject:[self button:OR6L(@"Check the PIN change") info:@"pin-check" identifier:@"chat.locked.pin_check"]];
        RCFormSection *main = [RCFormSection sectionWithTitle:nil rows:rows];
        if (_purpose == OR6LockedPurposeSettings) main.footer = OR6L(@"A 4-digit PIN protects locked chats on the service. ChatGPT X never stores it.");
        [sections addObject:main];
        if (_purpose == OR6LockedPurposeSettings && hasPIN && !reset) {
            if ([self resetAvailable]) { RCFormRow *r = [self button:OR6L(@"Forgot PIN…") info:@"reset" identifier:@"chat.locked_settings.reset"]; r.destructive = YES; RCFormSection *x = [RCFormSection sectionWithTitle:nil rows:@[r]]; x.footer = OR6L(@"Resetting the PIN deletes every locked chat."); [sections addObject:x]; }
            else { RCFormRow *r = [self button:OR6L(@"Forgot PIN… (on the website)") info:@"reset-web" identifier:@"chat.locked_settings.reset_web"]; RCFormSection *x = [RCFormSection sectionWithTitle:nil rows:@[r, [self button:OR6L(@"Check again") info:@"status" identifier:@"chat.locked_settings.recheck"]]]; x.footer = OR6L(@"A forgotten PIN is reset on the ChatGPT website. It deletes every locked chat."); [sections addObject:x]; }
        }
    } else {
        NSMutableArray *rows = [NSMutableArray array];
        for (NSDictionary *i in _list.items) {
            RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:OR6Chat6Text(i[@"title"], OR6L(@"Untitled"))];
            r.glyph = @"lock"; r.tile = RCTileGraphite; r.disclosure = YES; r.userInfo = i; r.identifier = @"chat.locked.row"; [rows addObject:r];
        }
        if (_list.busy) [rows addObject:[self note:OR6L(@"Loading…")]];
        else if (_list.error) { [rows addObject:[self note:OR6Chat7ErrorText(_list.error)]]; if (_list.retryAvailable) [rows addObject:[self button:OR6L(@"Read again") info:@"retry-list" identifier:@"chat.locked.list.retry"]]; }
        else if (_list.hasMore) [rows addObject:[self button:OR6L(@"Show more") info:@"more" identifier:@"chat.locked.more"]];
        else if (!_list.items.count) [rows addObject:[self note:OR6L(@"No locked chats.")]];
        RCFormSection *s = [RCFormSection sectionWithTitle:nil rows:rows];
        if (_list.items.count) s.footer = OR6L(@"While a chat is locked, ChatGPT does not add to memory from it. A chat unlocked again follows your usual settings.");
        [sections addObject:s];
    }
    _form.sections = sections;
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    (void)f; id i = row.userInfo;
    if ([i isEqual:@"status"]) { [self setNotice:nil]; [self readStatus]; return; }
    if ([i isEqual:@"create"]) { [self setNotice:nil]; [self setPhase:@"create"]; [self showPIN:RCPINModeSet title:nil]; return; }
    if ([i isEqual:@"change"]) { [self setNotice:nil]; [self setPhase:@"change-current"]; [self showPIN:RCPINModeUnlock title:nil]; return; }
    if ([i isEqual:@"reset"]) { [self setNotice:nil]; [self startReset]; return; }
    if ([i isEqual:@"reset-web"]) { [self openResetPage]; return; }
    if ([i isEqual:@"pin-check"]) { if ([_pinWrite reconcile]) [self setNotice:OR6L(@"Checking…")]; [self render]; return; }
    if ([i isEqual:@"lock"]) { [self confirmLock]; return; }
    if ([i isEqual:@"more"]) { [_list loadMore]; [self render]; return; }
    if ([i isEqual:@"retry-list"]) { [_list retry]; [self render]; return; }
    if (![i isKindOfClass:NSDictionary.class] || !_projectId) return;
    OR6Chat6LockedChat *c = [[[OR6Chat6LockedChat alloc] initWithCore:_core project:_projectId conversation:i[@"id"] title:OR6Chat6Text(i[@"title"], OR6L(@"Untitled"))] autorelease];
    NSString *cid = i[@"id"]; id<OR6Chat7Navigator> nav = _nav; OR6Chat6Pager *list = _list;
    c.unlocked = ^{ [list removeItemWithId:cid]; [nav chat7Conversation:cid changed:@"unarchived"]; };
    [self.navigationController pushViewController:c animated:YES];
}

#pragma mark Lifecycle: the grant and protected content never outlive the screen

- (void)forget {
    _life++; [_status cancel]; [_verify cancel]; [_list cancel]; _list.delegate = nil; [_list release]; _list = nil; [_projectId release]; _projectId = nil;
    if ([_pinWrite.phase isEqual:@"running"] || [_pinWrite.phase isEqual:@"reconciling"]) { _pinWrite.delegate = nil; [_pinWrite autorelease]; _pinWrite = nil; } // its late reply must not reopen the list (an interrupted write stays latched, never resent)
    _pin.checking = NO;
    [_currentPIN release]; _currentPIN = nil; [_resetAuthorization release]; _resetAuthorization = nil;
    for (UIViewController *v in self.navigationController.viewControllers) if ([v isKindOfClass:OR6Chat6LockedChat.class]) [(OR6Chat6LockedChat *)v wipe];
    [OR6Chat6TrustedHostNow() chat6ClearLockedAccess];
}
- (void)background:(NSNotification *)n {
    (void)n; if (!self.navigationController) return;
    // Hide protected titles and text before iOS takes the app-switcher snapshot.
    [self forget];
    if ([self.navigationController.viewControllers containsObject:self]) [self.navigationController popToViewController:self animated:NO];
    _started = NO; [self setPhase:@"status"]; [self show:_form]; [self render];
}
- (void)viewDidAppear:(BOOL)a { [super viewDidAppear:a]; if (!_started) { _started = YES; [self readStatus]; } }
- (void)didMoveToParentViewController:(UIViewController *)p { [super didMoveToParentViewController:p]; if (!p) [self forget]; }
- (void)viewWillDisappear:(BOOL)a { [super viewWillDisappear:a]; if (self.isMovingFromParentViewController) [self forget]; }
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self]; [self forget];
    _status.delegate = nil; _verify.delegate = nil; _pinWrite.delegate = nil; _pin.delegate = nil; _form.delegate = nil;
    [_status release]; [_verify release]; [_pinWrite release]; [_pin release]; [_form release];
    [_core release]; [_phase release]; [_target release]; [_targetTitle release]; [_notice release]; [super dealloc];
}
@end

UIViewController *OR6Chat6CreateLocked(OR6APICore *core, id<OR6Chat7Navigator> nav) { return [[[OR6Chat6LockedScreen alloc] initWithCore:core navigator:nav purpose:OR6LockedPurposeList target:nil title:nil] autorelease]; }
UIViewController *OR6Chat6CreateLockedSettings(OR6APICore *core) { return OR6Chat6On(core, @"locked.status") ? [[[OR6Chat6LockedScreen alloc] initWithCore:core navigator:nil purpose:OR6LockedPurposeSettings target:nil title:nil] autorelease] : nil; }
UIViewController *OR6Chat6CreateLockConversation(OR6APICore *core, NSString *cid, NSString *title, id<OR6Chat7Navigator> nav) {
    if (!OR6Chat7ConversationUUID(cid) || !OR6Chat6AllOn(core, @[@"locked.status", @"locked.pin.verify", @"locked.conversations.lock"])) return nil;
    return [[[OR6Chat6LockedScreen alloc] initWithCore:core navigator:nav purpose:OR6LockedPurposeLock target:cid title:title] autorelease];
}
NSArray *OR6Chat6LockedPrivacyEntries(OR6APICore *core) {
    return OR6Chat6On(core, @"locked.status") // the web PIN reset is always offered, native writes when granted
        ? @[@{@"key": @"locked_settings", @"title": OR6L(@"Locked chats"), @"identifier": @"chat.privacy.locked"}] : @[];
}
