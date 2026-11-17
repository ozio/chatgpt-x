// Codex tier 1 (usefulness 9–10 inside Codex; design/uxui «Codex · уровень 1»).
//  • RCGalleryCodexPage — a task history built from kit parts: RCChangesStripView,
//    RCTimelineNoteView (reconnect capsule, «working»), RCTerminalPartView (running with
//    Stop, finished 0, failed 1, stopped, collapsed/expanded tail), RCFileChangesPartView,
//    RCApprovalPartView (pending, sending, allowed, denied, network target), a Codex
//    question (RCClarifyPartView) and the placeholder for a later-tier item.
//    Route chatgptxkit://page/Codex (open=3: diff, open=4: task list, open=5: device check).
//  • The task list and device check are RCFormViewController screens (rows with lamps).
//  • RCDiffViewController shows one file.
// Codex tiers are independent of the chat stages: everything here is tier 1.
#import "RCGalleryDemos.h"
#import "RCFileChangesPartView.h"
#import "RCTerminalPartView.h"
#import "RCApprovalPartView.h"
#import "RCTimelineNoteView.h"
#import "RCDiffViewController.h"
#import "RCFormViewController.h"
#import "RCClarifyPartView.h"
#import "RCPartPlaceholderView.h"
#import "RCTheme.h"

static NSArray *RCGalleryCodexChanges(void) {
    return [NSArray arrayWithObjects:
        [RCFileChange changeWithPath:@"src/auth/link.js" kind:RCFileChangeModified added:4 removed:2],
        [RCFileChange changeWithPath:@"src/auth/link.test.js" kind:RCFileChangeAdded added:5 removed:0],
        [RCFileChange changeWithPath:@"src/auth/legacy-token.js" kind:RCFileChangeDeleted added:0 removed:31], nil];
}

@interface RCGalleryCodexListPage : RCFormViewController <RCFormDelegate> { BOOL _check; NSUInteger _step; }
- (id)initWithDeviceCheck:(BOOL)check;
@end

@implementation RCGalleryCodexListPage
- (id)initWithDeviceCheck:(BOOL)check {
    if ((self = [super init])) { _check = check; self.delegate = self; self.title = check ? @"Codex" : RCL(@"Codex tasks"); [self bind]; }
    return self;
}
- (void)dealloc { [NSObject cancelPreviousPerformRequestsWithTarget:self]; self.delegate = nil; [super dealloc]; }
- (RCFormRow *)task:(NSString *)title project:(NSString *)project status:(NSString *)status lamp:(RCLampState)lamp counts:(NSString *)counts {
    RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:title];
    r.subtitle = [NSString stringWithFormat:@"%@ · %@", project, status]; r.showsLamp = YES; r.lamp = lamp; r.value = counts; r.disclosure = YES;
    r.identifier = @"chat.codex.task"; return r;
}
- (void)bind {
    if (_check) {
        self.headerText = RCL(@"Codex runs commands and changes files in your projects. Confirm once that this iPhone belongs to your account. The device key stays in the iPhone keychain.");
        NSArray *titles = [NSArray arrayWithObjects:RCL(@"Creating the device key"), RCL(@"Signing the account request"), RCL(@"The account confirmed this iPhone"), nil];
        NSMutableArray *rows = [NSMutableArray array];
        for (NSUInteger i = 0; i < titles.count; i++) {
            RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:[titles objectAtIndex:i]]; r.showsLamp = YES;
            r.lamp = i < _step ? RCLampOK : (i == _step && _step > 0 && _step < 3 ? RCLampBusy : RCLampOff); r.enabled = NO; [rows addObject:r];
        }
        RCFormRow *go = [RCFormRow rowWithKind:RCFormRowButton title:RCL(@"Check iPhone")]; go.enabled = _step == 0; go.identifier = @"chat.codex.check";
        RCFormSection *s = [RCFormSection sectionWithTitle:nil rows:rows];
        RCFormSection *b = [RCFormSection sectionWithTitle:nil rows:[NSArray arrayWithObject:go]];
        b.footer = RCL(@"If the check fails, Codex stays closed; ordinary chats keep working.");
        self.sections = [NSArray arrayWithObjects:s, b, nil];
        return;
    }
    self.headerText = nil;
    RCFormSection *wait = [RCFormSection sectionWithTitle:RCL(@"Waiting for you") rows:[NSArray arrayWithObjects:
        [self task:RCL(@"Fix sign-in by link") project:@"shop-web" status:RCL(@"Needs permission") lamp:RCLampInfo counts:@"+9 −2"],
        [self task:RCL(@"Add a dark theme to settings") project:@"shop-web" status:RCL(@"Needs your answer") lamp:RCLampInfo counts:nil], nil]];
    RCFormSection *run = [RCFormSection sectionWithTitle:RCL(@"Running") rows:[NSArray arrayWithObject:
        [self task:RCL(@"Update dependencies") project:@"shop-api" status:RCL(@"running") lamp:RCLampBusy counts:nil]]];
    RCFormSection *done = [RCFormSection sectionWithTitle:RCL(@"Done") rows:[NSArray arrayWithObjects:
        [self task:RCL(@"Speed up the CSS build") project:@"shop-web" status:RCL(@"2 h ago") lamp:RCLampOK counts:@"+14 −4"],
        [self task:RCL(@"Tests for the date parser") project:@"shop-api" status:RCL(@"stopped with an error") lamp:RCLampError counts:nil], nil]];
    done.footer = RCL(@"Codex works where your account started it. The iPhone shows progress and stops a task only where your decision is needed.");
    self.sections = [NSArray arrayWithObjects:wait, run, done, nil];
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    (void)f;
    if (_check) { _step = 1; [self bind]; [self performSelector:@selector(advance) withObject:nil afterDelay:.9]; return; }
    RCGalleryHUD(self.view, row.title);
}
- (void)advance { _step++; [self bind]; if (_step < 3) [self performSelector:@selector(advance) withObject:nil afterDelay:.9]; else RCGalleryHUD(self.view, RCL(@"iPhone confirmed")); }
@end

@interface RCGalleryCodexPage : RCGalleryPage <RCTerminalPartViewDelegate, RCFileChangesPartViewDelegate, RCApprovalPartViewDelegate, RCPartViewDelegate, RCClarifyPartViewDelegate> { RCTerminalPartView *_live; NSTimer *_timer; }
@end

@implementation RCGalleryCodexPage
- (id)init { if ((self = [super init])) self.title = @"Codex"; return self; }
// The timer retains its target: keep self alive while invalidating (it may hold the last reference).
- (void)stopTimer { [[self retain] autorelease]; [_timer invalidate]; [_timer release]; _timer = nil; }
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [self stopTimer]; }
- (void)dealloc { [NSObject cancelPreviousPerformRequestsWithTarget:self]; [self stopTimer]; _live.delegate = nil; [_live release]; [super dealloc]; }

- (RCTerminalPartView *)terminal:(NSString *)cmd lines:(NSArray *)lines state:(RCTerminalState)st exit:(NSInteger)ex {
    RCTerminalPartView *t = [[[RCTerminalPartView alloc] initWithFrame:CGRectZero] autorelease];
    t.command = cmd; t.outputLines = lines; t.state = st; t.exitCode = ex; t.duration = st == RCTerminalFinished ? 2.1 : -1; t.delegate = self; return t;
}
- (RCApprovalPartView *)approval:(RCApprovalState)st {
    RCApprovalPartView *a = [[[RCApprovalPartView alloc] initWithFrame:CGRectZero] autorelease];
    a.detail = RCL(@"Run the sign-in module tests · in ~/src/shop-web"); a.command = @"npm test -- src/auth"; a.state = st; a.approvalDelegate = self; a.delegate = self; return a;
}

- (void)build {
    [self stopTimer];
    [self addCaption:RCL(@"Above the history")];
    RCChangesStripView *strip = [[[RCChangesStripView alloc] initWithFrame:CGRectZero] autorelease]; strip.fileCount = 3; strip.added = 9; strip.removed = 33;
    [strip addTarget:self action:@selector(openDiff) forControlEvents:UIControlEventTouchUpInside];
    [self addInsetView:strip height:38];
    [self addCaption:RCL(@"Commands")];
    [_live release]; _live = [[self terminal:@"npm outdated --long" lines:[NSArray arrayWithObjects:@"Package   Current  Wanted", @"fastify   4.26.1   4.26.2", nil] state:RCTerminalRunning exit:0] retain]; _live.stopAvailable = YES;
    [self addInsetView:_live height:-1]; [self addSpace:10];
    _timer = [[NSTimer scheduledTimerWithTimeInterval:1.2 target:self selector:@selector(tick) userInfo:nil repeats:YES] retain];
    RCTerminalPartView *ok = [self terminal:@"npm test -- src/auth" lines:[NSArray arrayWithObjects:@"PASS src/auth/link.test.js", RCL(@"  ✓ an expired link is refused (4 ms)"), @"Tests: 6 passed, 6 total", nil] state:RCTerminalFinished exit:0];
    [self addInsetView:ok height:-1]; [self addSpace:10];
    NSMutableArray *many = [NSMutableArray array]; for (int i = 1; i <= 14; i++) [many addObject:[NSString stringWithFormat:@"tests/test_dates.py::test_case_%02d %@", i, i == 9 ? @"FAILED" : @"PASSED"]];
    [many addObject:@"1 failed, 13 passed in 0.84s"];
    RCTerminalPartView *bad = [self terminal:@"pytest tests/test_dates.py -v" lines:many state:RCTerminalFinished exit:1];
    [self addInsetView:bad height:-1]; [self addSpace:10];
    [self addNote:RCL(@"Tap the output to show up to the last 200 lines.")];
    RCTerminalPartView *stopped = [self terminal:@"npm run build" lines:[NSArray arrayWithObject:@"building 41/148…"] state:RCTerminalFinished exit:130]; stopped.stopped = YES;
    [self addInsetView:stopped height:-1]; [self addSpace:10];
    [self addCaption:RCL(@"Changed files")];
    RCFileChangesPartView *files = [[[RCFileChangesPartView alloc] initWithFrame:CGRectZero] autorelease]; files.changes = RCGalleryCodexChanges(); files.changesDelegate = self; files.delegate = self;
    [self addInsetView:files height:-1]; [self addSpace:10];
    [self addCaption:RCL(@"Permission")];
    RCApprovalPartView *p = [self approval:RCApprovalPending]; [self addInsetView:p height:-1]; [self addSpace:10];
    RCApprovalPartView *net = [self approval:RCApprovalPending];
    net.title = RCL(@"Codex asks for network access"); net.target = @"registry.npmjs.org"; net.targetGlyph = @"globe"; net.targetTile = RCTileBlue;
    net.detail = RCL(@"Download the updated packages"); net.command = @"npm update fastify pg zod";
    [self addInsetView:net height:-1]; [self addSpace:10];
    [self addNote:RCL(@"Tier 1 shows network access as an ordinary permission; tier 2 adds «Only now» / «Always for the domain».")];
    RCApprovalPartView *sending = [self approval:RCApprovalPending]; sending.busy = YES; [self addInsetView:sending height:-1]; [self addSpace:10];
    RCApprovalPartView *allowed = [self approval:RCApprovalAllowed]; [self addInsetView:allowed height:-1]; [self addSpace:10];
    RCApprovalPartView *denied = [self approval:RCApprovalDenied]; [self addInsetView:denied height:-1]; [self addSpace:10];
    [self addCaption:RCL(@"Codex asks")];
    RCClarifyPartView *ask = [[[RCClarifyPartView alloc] initWithFrame:CGRectMake(0, 0, 300, 200)] autorelease];
    RCClarifyQuestion *q = [RCClarifyQuestion questionWithText:RCL(@"How should the dark theme turn on?") options:[NSArray arrayWithObjects:RCL(@"Like the system"), RCL(@"Only manually"), RCL(@"System + manual choice"), nil] multiple:NO];
    ask.questions = [NSArray arrayWithObject:q]; ask.delegate = self; [self addInsetView:ask height:-1]; [self addSpace:10];
    [self addCaption:RCL(@"History notes")];
    RCTimelineNoteView *gap = [[[RCTimelineNoteView alloc] initWithStyle:RCTimelineNoteCapsule] autorelease]; gap.lamp = RCLampOK; gap.text = RCL(@"Connection restored · events loaded: 3");
    [self addInsetView:gap height:-1]; [self addSpace:10];
    RCTimelineNoteView *work = [[[RCTimelineNoteView alloc] initWithStyle:RCTimelineNoteActivity] autorelease]; work.text = RCL(@"Codex is working…");
    [self addInsetView:work height:-1]; [self addSpace:10];
    RCPartPlaceholderView *ph = [[[RCPartPlaceholderView alloc] initWithGlyph:@"sliders" tile:RCTileGreen title:RCL(@"Work plan") text:RCL(@"This task item is not shown on iPhone yet — it is saved in the task.")] autorelease];
    [self addInsetView:ph height:-1]; [self addSpace:10];
    [self addCaption:RCL(@"Screens")];
    RCButton *list = [RCButton buttonWithStyle:RCButtonStyleLarge title:RCL(@"Task list")]; [list addTarget:self action:@selector(openList) forControlEvents:UIControlEventTouchUpInside]; [self addInsetView:list height:44];
    [self addSpace:10];
    RCButton *check = [RCButton buttonWithStyle:RCButtonStyleLarge title:RCL(@"Device check")]; [check addTarget:self action:@selector(openCheck) forControlEvents:UIControlEventTouchUpInside]; [self addInsetView:check height:44];
    [self addSpace:10];
    RCButton *diff = [RCButton buttonWithStyle:RCButtonStyleLarge title:RCL(@"Diff of one file")]; [diff addTarget:self action:@selector(openDiff) forControlEvents:UIControlEventTouchUpInside]; [self addInsetView:diff height:44];
    [self addSpace:20];
}

- (void)tick {
    if (!_live || _live.state != RCTerminalRunning) { [self stopTimer]; return; }
    NSArray *more = [NSArray arrayWithObjects:@"pg        8.11.3   8.11.5", @"zod       3.22.4   3.22.6", nil];
    if (_live.outputLines.count < 4) { _live.outputLines = [_live.outputLines arrayByAddingObject:[more objectAtIndex:_live.outputLines.count - 2]]; return; }
    _live.state = RCTerminalFinished; _live.exitCode = 0; _live.duration = 2.8;
}
- (void)terminalPartDidTapStop:(RCTerminalPartView *)t { [self stopTimer]; t.state = RCTerminalFinished; t.exitCode = 130; t.stopped = YES; t.duration = 1.2; }
- (void)terminalPartDidChangeHeight:(RCTerminalPartView *)t { (void)t; [self relayout]; }
- (void)partViewDidChangeHeight:(RCPartView *)p { (void)p; [self relayout]; }
- (void)fileChangesPart:(RCFileChangesPartView *)part didSelectChange:(RCFileChange *)c { (void)part; [self openDiffFor:c]; }
- (void)approvalPartDidAllow:(RCApprovalPartView *)a { a.busy = YES; [self performSelector:@selector(resolve:) withObject:a afterDelay:.8]; }
- (void)resolve:(RCApprovalPartView *)a { a.state = RCApprovalAllowed; }
- (void)approvalPartDidDeny:(RCApprovalPartView *)a { a.state = RCApprovalDenied; }
- (void)clarifyPart:(RCClarifyPartView *)part didFinishWithSelections:(NSArray *)s { (void)part; RCGalleryAlert(RCL(@"Answers"), [s description]); }

- (void)openDiff { [self openDiffFor:[RCGalleryCodexChanges() objectAtIndex:0]]; }
- (void)openDiffFor:(RCFileChange *)c {
    RCDiffViewController *d = [[[RCDiffViewController alloc] init] autorelease];
    d.title = c.fileName; d.change = c;
    d.hunks = [NSArray arrayWithObjects:
        [RCDiffHunk hunkWithHeader:@"function verifyLink(token)" oldStart:12 newStart:12 lines:[NSArray arrayWithObjects:
            @" export function verifyLink(token) {", @"-  const data = jwt.decode(token);", @"-  if (data.exp < Date.now()) return null;",
            @"+  const data = jwt.verify(token, SECRET, {", @"+    algorithms: [\"HS256\"],", @"+    clockTolerance: 30", @"+  });",
            @"   return findUser(data.sub);", @" }", nil]],
        [RCDiffHunk hunkWithHeader:@"module.exports" oldStart:58 newStart:61 lines:[NSArray arrayWithObjects:@" module.exports = {", @"-  verifyLink", @"+  verifyLink,", @"+  SECRET_TTL", @" };", nil]], nil];
    [self.navigationController pushViewController:d animated:YES];
}
- (void)openList { [self.navigationController pushViewController:[[[RCGalleryCodexListPage alloc] initWithDeviceCheck:NO] autorelease] animated:YES]; }
- (void)openCheck { [self.navigationController pushViewController:[[[RCGalleryCodexListPage alloc] initWithDeviceCheck:YES] autorelease] animated:YES]; }
- (void)openVariant:(NSNumber *)n { int v = [n intValue]; if (v == 3) [self openDiff]; else if (v == 4) [self openList]; else if (v == 5) [self openCheck]; }
@end

// Codex tier 2 (usefulness 8 inside Codex; design/uxui «Codex · уровень 2»).
//  • RCGalleryCodexTwoPage — plan (proposed, sending, running, finished), network access
//    with «Разрешить…» → «Только сейчас / Всегда для домена», an MCP tool call
//    (RCTaskPartView), the yellow review strip; screens: diff with review notes and
//    «Исправить», connections and «Добавить компьютер…», SSH, model and where to run.
//    Route chatgptxkit://page/CodexTwo (open=3 review diff, 4 connections, 5 SSH, 6 model, 7 where).
//  • Connections, SSH and model are kit forms/checklists (RCFormViewController,
//    RCChecklistViewController); pairing choices and the host key use stock sheets/alerts.
#import "RCPlanPartView.h"
#import "RCTaskPartView.h"
#import "RCChecklistViewController.h"

@interface RCGalleryCodexFormPage : RCFormViewController <RCFormDelegate, UIActionSheetDelegate, UIAlertViewDelegate> { BOOL _ssh; }
- (id)initSSH:(BOOL)ssh;
@end
@implementation RCGalleryCodexFormPage
- (id)initSSH:(BOOL)ssh {
    if ((self = [super init])) {
        _ssh = ssh; self.delegate = self; self.title = ssh ? @"SSH" : RCL(@"Connections");
        if (ssh) self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:RCL(@"Connect") style:UIBarButtonItemStyleDone target:self action:@selector(connect)] autorelease];
        [self bind];
    }
    return self;
}
- (void)dealloc { self.delegate = nil; [super dealloc]; }
- (RCFormRow *)host:(NSString *)name via:(NSString *)via lamp:(RCLampState)lamp glyph:(NSString *)glyph tile:(RCTileColor)tile value:(NSString *)value {
    RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:name]; r.subtitle = via; r.showsLamp = lamp != RCLampOff; r.lamp = lamp; r.glyph = glyph; r.tile = tile; r.value = value; r.disclosure = YES; r.identifier = @"chat.codex.connection"; return r;
}
- (void)bind {
    if (_ssh) {
        RCFormRow *h = [RCFormRow rowWithKind:RCFormRowText title:RCL(@"Host")]; h.placeholder = RCL(@"Host: 192.168.1.30"); h.identifier = @"chat.codex.ssh.host";
        RCFormRow *p = [RCFormRow rowWithKind:RCFormRowText title:RCL(@"Port")]; p.placeholder = RCL(@"Port: 22"); p.identifier = @"chat.codex.ssh.port";
        RCFormRow *u = [RCFormRow rowWithKind:RCFormRowText title:RCL(@"Login")]; u.placeholder = RCL(@"Login: alex"); u.identifier = @"chat.codex.ssh.user";
        RCFormRow *k = [RCFormRow rowWithKind:RCFormRowNote title:@"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK7q…x2Lw chatgptx@iphone"];
        RCFormRow *c = [RCFormRow rowWithKind:RCFormRowButton title:RCL(@"Copy public key")]; c.identifier = @"chat.codex.ssh.copy";
        RCFormSection *s1 = [RCFormSection sectionWithTitle:RCL(@"Computer") rows:[NSArray arrayWithObjects:h, p, u, nil]];
        RCFormSection *s2 = [RCFormSection sectionWithTitle:RCL(@"iPhone key") rows:[NSArray arrayWithObjects:k, c, nil]];
        s2.footer = RCL(@"Add the public key to ~/.ssh/authorized_keys on the computer. The private key never leaves this iPhone.");
        self.sections = [NSArray arrayWithObjects:s1, s2, nil];
        return;
    }
    RCFormRow *add = [RCFormRow rowWithKind:RCFormRowButton title:RCL(@"Add a computer…")]; add.identifier = @"chat.codex.connection.add";
    RCFormSection *pcs = [RCFormSection sectionWithTitle:RCL(@"Computers") rows:[NSArray arrayWithObjects:
        [self host:@"MacBook Pro" via:RCL(@"Connected · SSH · 192.168.1.20") lamp:RCLampOK glyph:@"devices" tile:RCTileDark value:RCL(@"in use")],
        [self host:RCL(@"Office iMac") via:RCL(@"Offline · seen yesterday at 19:40") lamp:RCLampOff glyph:@"devices" tile:RCTileGray value:nil], add, nil]];
    RCFormSection *cloud = [RCFormSection sectionWithTitle:RCL(@"Cloud") rows:[NSArray arrayWithObjects:
        [self host:@"shop-web" via:@"github.com/acme/shop-web" lamp:RCLampOff glyph:@"cloud" tile:RCTileBlue value:nil],
        [self host:@"shop-api" via:@"github.com/acme/shop-api" lamp:RCLampOff glyph:@"cloud" tile:RCTileBlue value:nil], nil]];
    cloud.footer = RCL(@"A cloud environment clones the repository and runs the task without your computer.");
    self.sections = [NSArray arrayWithObjects:pcs, cloud, nil];
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    (void)f;
    if ([row.identifier isEqualToString:@"chat.codex.connection.add"]) {
        UIActionSheet *s = [[[UIActionSheet alloc] initWithTitle:RCL(@"How to connect the computer? Codex must be open on it.") delegate:self cancelButtonTitle:RCL(@"Cancel") destructiveButtonTitle:nil otherButtonTitles:RCL(@"Scan QR code"), RCL(@"Enter code"), RCL(@"Manually over SSH"), nil] autorelease];
        [s showInView:self.view]; return;
    }
    if ([row.identifier isEqualToString:@"chat.codex.ssh.copy"]) { RCGalleryHUD(self.view, RCL(@"Copied")); return; }
    RCGalleryHUD(self.view, row.title);
}
- (void)actionSheet:(UIActionSheet *)s clickedButtonAtIndex:(NSInteger)i {
    if (i == s.cancelButtonIndex) return;
    if (i == 1) { UIAlertView *a = [[[UIAlertView alloc] initWithTitle:RCL(@"Pairing code") message:RCL(@"The code is shown in Codex on the computer: Settings › Mobile device.") delegate:nil cancelButtonTitle:RCL(@"Cancel") otherButtonTitles:RCL(@"Connect"), nil] autorelease]; a.alertViewStyle = UIAlertViewStylePlainTextInput; [a show]; }
    else if (i == 2) [self.navigationController pushViewController:[[[RCGalleryCodexFormPage alloc] initSSH:YES] autorelease] animated:YES];
    else RCGalleryHUD(self.view, RCL(@"Scan QR code"));
}
- (void)connect {
    [self endEditing];
    UIAlertView *a = [[[UIAlertView alloc] initWithTitle:RCL(@"Unknown server key") message:[NSString stringWithFormat:@"%@\n\nED25519 SHA256:9f2c…a71e", RCL(@"First connection to this computer. Compare the fingerprint with ssh-keygen -lf on the computer.")] delegate:self cancelButtonTitle:RCL(@"Cancel") otherButtonTitles:RCL(@"Trust"), nil] autorelease];
    [a show];
}
- (void)alertView:(UIAlertView *)a clickedButtonAtIndex:(NSInteger)i { if (i != a.cancelButtonIndex) { self.busy = YES; [self performSelector:@selector(connected) withObject:nil afterDelay:1.2]; } }
- (void)connected { self.busy = NO; RCGalleryHUD(self.view, RCL(@"Connected")); }
@end

@interface RCGalleryCodexChecklistPage : RCChecklistViewController <RCChecklistDelegate> { BOOL _where; NSUInteger _sel[3]; }
- (id)initWhere:(BOOL)where;
@end
@implementation RCGalleryCodexChecklistPage
- (id)initWhere:(BOOL)where { if ((self = [super init])) { _where = where; _sel[1] = 1; self.delegate = self; self.title = where ? RCL(@"Where to run") : RCL(@"Model"); [self bind]; } return self; }
- (void)dealloc { self.delegate = nil; [super dealloc]; }
- (RCChecklistRow *)row:(NSString *)t detail:(NSString *)d section:(NSUInteger)s index:(NSUInteger)i { return [RCChecklistRow rowWithTitle:t detail:d checked:_sel[s] == i]; }
- (void)bind {
    if (_where) {
        self.sections = [NSArray arrayWithObjects:
            [RCChecklistSection sectionWithTitle:RCL(@"Computers") rows:[NSArray arrayWithObjects:[self row:@"MacBook Pro" detail:RCL(@"Connected · SSH") section:0 index:0], [self row:RCL(@"Office iMac") detail:RCL(@"Offline") section:0 index:1], nil]],
            [RCChecklistSection sectionWithTitle:RCL(@"Cloud") rows:[NSArray arrayWithObjects:[self row:@"shop-web" detail:@"github.com/acme/shop-web" section:0 index:2], [self row:@"shop-api" detail:@"github.com/acme/shop-api" section:0 index:3], nil]], nil];
        self.footerText = RCL(@"An offline computer continues its tasks when it comes back.");
        return;
    }
    self.sections = [NSArray arrayWithObjects:
        [RCChecklistSection sectionWithTitle:RCL(@"Model") rows:[NSArray arrayWithObjects:[self row:@"GPT-5.5-Codex" detail:RCL(@"For code, default") section:0 index:0], [self row:@"GPT-5.5" detail:RCL(@"General, for analysis and text") section:0 index:1], [self row:@"GPT-5.5 mini" detail:RCL(@"Fast and economical") section:0 index:2], nil]],
        [RCChecklistSection sectionWithTitle:RCL(@"Reasoning depth") rows:[NSArray arrayWithObjects:[self row:RCL(@"Low") detail:nil section:1 index:0], [self row:RCL(@"Medium") detail:nil section:1 index:1], [self row:RCL(@"High") detail:nil section:1 index:2], nil]],
        [RCChecklistSection sectionWithTitle:RCL(@"Speed") rows:[NSArray arrayWithObjects:[self row:RCL(@"Standard") detail:nil section:2 index:0], [self row:RCL(@"Fast") detail:RCL(@"Answers sooner, uses the limit faster") section:2 index:1], nil]], nil];
    self.footerText = RCL(@"The list comes from the account; models it does not offer are not shown.");
}
- (void)checklist:(RCChecklistViewController *)c didSelectRow:(NSUInteger)row inSection:(NSUInteger)section {
    (void)c;
    if (_where) { _sel[0] = section * 2 + row; } else _sel[section] = row;
    [self bind];
}
@end

@interface RCGalleryCodexTwoPage : RCGalleryPage <RCPlanPartViewDelegate, RCApprovalPartViewDelegate, RCPartViewDelegate, UIActionSheetDelegate, RCDiffViewControllerDelegate> { RCApprovalPartView *_net; }
@end
@implementation RCGalleryCodexTwoPage
- (id)init { if ((self = [super init])) self.title = RCL(@"Codex, tier 2"); return self; }
- (void)dealloc { [NSObject cancelPreviousPerformRequestsWithTarget:self]; [_net release]; [super dealloc]; }
- (NSArray *)steps:(NSUInteger)done {
    NSArray *t = [NSArray arrayWithObjects:RCL(@"Find where the code does this"), RCL(@"Make the change and update the tests"), RCL(@"Run the tests and show the diff"), nil];
    NSMutableArray *a = [NSMutableArray array]; for (NSUInteger i = 0; i < t.count; i++) [a addObject:[RCPlanStep stepWithText:[t objectAtIndex:i] done:i < done]]; return a;
}
- (RCPlanPartView *)plan:(RCPlanState)st done:(NSUInteger)d busy:(BOOL)b {
    RCPlanPartView *p = [[[RCPlanPartView alloc] initWithFrame:CGRectZero] autorelease]; p.steps = [self steps:d]; p.state = st; p.busy = b; p.planDelegate = self; p.delegate = self; return p;
}
- (void)build {
    [self addCaption:RCL(@"Plan")];
    RCPlanPartView *p = [self plan:RCPlanProposed done:0 busy:NO]; [self addInsetView:p height:-1]; [self addSpace:10];
    RCPlanPartView *pb = [self plan:RCPlanProposed done:0 busy:YES]; [self addInsetView:pb height:-1]; [self addSpace:10];
    RCPlanPartView *pr = [self plan:RCPlanAccepted done:1 busy:NO]; [self addInsetView:pr height:-1]; [self addSpace:10];
    RCPlanPartView *pf = [self plan:RCPlanFinished done:3 busy:NO]; [self addInsetView:pf height:-1]; [self addSpace:10];
    [self addNote:RCL(@"Tier 1 shows a plan as a placeholder saved in the task.")];
    [self addCaption:RCL(@"Network access")];
    [_net release]; _net = [[RCApprovalPartView alloc] initWithFrame:CGRectZero];
    _net.title = RCL(@"Codex asks for network access"); _net.target = @"registry.npmjs.org"; _net.targetGlyph = @"globe"; _net.targetTile = RCTileBlue;
    _net.detail = RCL(@"Download the updated packages"); _net.command = @"npm update fastify pg zod"; _net.allowTitle = RCL(@"Allow…"); _net.approvalDelegate = self; _net.delegate = self;
    [self addInsetView:_net height:-1]; [self addSpace:10];
    RCApprovalPartView *always = [[[RCApprovalPartView alloc] initWithFrame:CGRectZero] autorelease];
    always.target = @"registry.npmjs.org"; always.targetGlyph = @"globe"; always.targetTile = RCTileBlue; always.detail = RCL(@"Download the updated packages");
    always.state = RCApprovalAllowed; always.resolvedText = RCL(@"Always allowed for registry.npmjs.org");
    [self addInsetView:always height:-1]; [self addSpace:10];
    [self addCaption:RCL(@"External tool (MCP)")];
    RCTaskPartView *mcp = [[[RCTaskPartView alloc] initWithGlyph:@"apps" tile:RCTilePurple] autorelease];
    mcp.title = @"github · create_issue"; mcp.subtitle = RCL(@"title: «Reset the CSS cache when browserslist changes»");
    mcp.rows = [NSArray arrayWithObject:[RCTaskRow stepWithText:RCL(@"Created issue #212") lamp:RCLampOK]];
    [self addInsetView:mcp height:-1]; [self addSpace:10];
    RCTaskPartView *mcpRun = [[[RCTaskPartView alloc] initWithGlyph:@"apps" tile:RCTilePurple] autorelease];
    mcpRun.title = @"linear · search_issues"; mcpRun.subtitle = RCL(@"query: «css build»");
    mcpRun.rows = [NSArray arrayWithObject:[RCTaskRow stepWithText:RCL(@"Running…") lamp:RCLampBusy]];
    [self addInsetView:mcpRun height:-1]; [self addSpace:10];
    [self addNote:RCL(@"A tool's access request uses the ordinary permission card with the server tile.")];
    [self addCaption:RCL(@"Review")];
    RCChangesStripView *rv = [[[RCChangesStripView alloc] initWithFrame:CGRectZero] autorelease]; rv.review = YES; rv.reviewCount = 1;
    [rv addTarget:self action:@selector(openReview) forControlEvents:UIControlEventTouchUpInside]; [self addInsetView:rv height:38]; [self addSpace:10];
    [self addCaption:RCL(@"Screens")];
    NSArray *b = [NSArray arrayWithObjects:RCL(@"Diff with review notes"), RCL(@"Connections"), @"SSH", RCL(@"Model"), RCL(@"Where to run"), nil];
    for (NSUInteger i = 0; i < b.count; i++) { RCButton *x = [RCButton buttonWithStyle:RCButtonStyleLarge title:[b objectAtIndex:i]]; x.tag = (NSInteger)i + 3; [x addTarget:self action:@selector(tapScreen:) forControlEvents:UIControlEventTouchUpInside]; [self addInsetView:x height:44]; [self addSpace:10]; }
    [self addSpace:10];
}
- (void)tapScreen:(UIButton *)b { [self openVariant:[NSNumber numberWithInt:(int)b.tag]]; }
- (void)partViewDidChangeHeight:(RCPartView *)p { (void)p; [self relayout]; }
- (void)planPartDidAccept:(RCPlanPartView *)p { p.busy = YES; [self performSelector:@selector(accepted:) withObject:p afterDelay:.8]; }
- (void)accepted:(RCPlanPartView *)p { p.state = RCPlanAccepted; NSArray *s = p.steps; [(RCPlanStep *)[s objectAtIndex:0] setDone:YES]; p.steps = s; }
- (void)planPartDidAskToEdit:(RCPlanPartView *)p { (void)p; RCGalleryHUD(self.view, RCL(@"Plan: write what to change")); }
- (void)approvalPartDidAllow:(RCApprovalPartView *)a {
    (void)a;
    UIActionSheet *s = [[[UIActionSheet alloc] initWithTitle:RCL(@"Access to registry.npmjs.org for this task") delegate:self cancelButtonTitle:RCL(@"Cancel") destructiveButtonTitle:nil otherButtonTitles:RCL(@"Only now"), RCL(@"Always for registry.npmjs.org"), nil] autorelease];
    [s showInView:self.view];
}
- (void)actionSheet:(UIActionSheet *)s clickedButtonAtIndex:(NSInteger)i {
    if (i == s.cancelButtonIndex) return;
    _net.busy = YES; _net.resolvedText = i == 1 ? RCL(@"Always allowed for registry.npmjs.org") : nil;
    [self performSelector:@selector(netAllowed) withObject:nil afterDelay:.8];
}
- (void)netAllowed { _net.state = RCApprovalAllowed; }
- (void)approvalPartDidDeny:(RCApprovalPartView *)a { a.state = RCApprovalDenied; }
- (void)openReview {
    RCDiffViewController *d = [[[RCDiffViewController alloc] init] autorelease];
    RCFileChange *c = [RCFileChange changeWithPath:@"build/css.js" kind:RCFileChangeModified added:6 removed:3]; d.title = c.fileName; d.change = c; d.fixAvailable = YES; d.delegate = self;
    RCDiffHunk *h = [RCDiffHunk hunkWithHeader:@"async function buildCss()" oldStart:30 newStart:30 lines:[NSArray arrayWithObjects:
        @" async function buildCss() {", @"-  const files = await glob(\"src/**/*.css\");", @"-  for (const f of files) await compile(f);",
        @"+  const files = await glob(\"src/**/*.css\");", @"+  const stale = files.filter(cache.changed);", @"+  await Promise.all(stale.map(compile));", @"+  cache.save();", @" }", nil]];
    h.comments = [NSArray arrayWithObject:[RCDiffComment commentAfterLine:5 text:RCL(@"The cache is not reset when browserslist changes: after a browser update the CSS stays old.")]];
    d.hunks = [NSArray arrayWithObject:h];
    [self.navigationController pushViewController:d animated:YES];
}
- (void)diffController:(RCDiffViewController *)d didTapFixComment:(RCDiffComment *)c { (void)c; RCGalleryHUD(d.view, RCL(@"Sent to the task")); }
- (void)openVariant:(NSNumber *)n {
    int v = [n intValue];
    if (v == 3) [self openReview];
    else if (v == 4) [self.navigationController pushViewController:[[[RCGalleryCodexFormPage alloc] initSSH:NO] autorelease] animated:YES];
    else if (v == 5) [self.navigationController pushViewController:[[[RCGalleryCodexFormPage alloc] initSSH:YES] autorelease] animated:YES];
    else if (v == 6) [self.navigationController pushViewController:[[[RCGalleryCodexChecklistPage alloc] initWhere:NO] autorelease] animated:YES];
    else if (v == 7) [self.navigationController pushViewController:[[[RCGalleryCodexChecklistPage alloc] initWhere:YES] autorelease] animated:YES];
}
@end

// Codex tier 3 (usefulness 1–7 inside Codex; design/uxui «Codex · уровень 3»).
//  • RCGalleryCodexThreePage — goal and budget (RCGoalStripView), subagents
//    (RCTaskPartView), hooks (RCTimelineNoteView Meta), a chart in the result
//    (RCChartPartView), rating (RCRatingRowView), task menu (rename / fork / files /
//    archive), worktree choice; screens: Codex settings (profile + RCStatsRowView,
//    permissions, answer style, lock with RCPINViewController, report), task list with
//    «Архив» segment and swipe «В архив», project files and a file, computer snapshot
//    (RCImageViewerController), cloud machine choice.
//    Route chatgptxkit://page/CodexThree (open=3 settings, 4 tasks, 5 files, 6 screen,
//    7 lock, 8 permissions, 9 machine).
#import "RCGoalStripView.h"
#import "RCRatingRowView.h"
#import "RCStatsRowView.h"
#import "RCAccountHeaderView.h"
#import "RCChartPartView.h"
#import "RCPINViewController.h"
#import "RCImageViewerController.h"
#import "RCSegmentedControl.h"
#import "RCSwipeToDelete.h"

@interface RCGalleryCodexSettingsPage : RCFormViewController <RCFormDelegate, RCPINViewControllerDelegate> { BOOL _lock; }
@end
@implementation RCGalleryCodexSettingsPage
- (id)init { if ((self = [super init])) { self.delegate = self; self.title = RCL(@"Settings"); [self bind]; } return self; }
- (void)dealloc { self.delegate = nil; [super dealloc]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    UIView *h = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 10)] autorelease];
    RCAccountHeaderView *acc = [[[RCAccountHeaderView alloc] initWithFrame:CGRectZero] autorelease]; acc.name = RCL(@"Alexey Smirnov"); acc.email = @"alexey@example.com";
    CGFloat ah = [acc heightForWidth:320]; acc.frame = CGRectMake(0, 0, 320, ah); [h addSubview:acc];
    RCStatsRowView *st = [[[RCStatsRowView alloc] initWithFrame:CGRectMake(0, ah, 320, 46)] autorelease];
    st.items = [NSArray arrayWithObjects:[RCStatItem itemWithValue:@"14" caption:RCL(@"tasks this week") tint:RCStatPlain], [RCStatItem itemWithValue:@"+2318" caption:RCL(@"lines added") tint:RCStatAdded], [RCStatItem itemWithValue:@"−611" caption:RCL(@"lines removed") tint:RCStatRemoved], nil];
    [h addSubview:st]; h.frame = CGRectMake(0, 0, 320, ah + 46);
    self.tableView.tableHeaderView = h;
}
- (void)bind {
    RCFormRow *pol = [RCFormRow rowWithKind:RCFormRowValue title:RCL(@"Permissions")]; pol.value = RCL(@"In the project"); pol.glyph = @"shield"; pol.tile = RCTileGreen; pol.disclosure = YES; pol.identifier = @"chat.codex.policy";
    RCFormRow *sty = [RCFormRow rowWithKind:RCFormRowValue title:RCL(@"Answer style")]; sty.value = RCL(@"Ordinary"); sty.glyph = @"text"; sty.tile = RCTileGray; sty.disclosure = YES; sty.identifier = @"chat.codex.style";
    RCFormRow *lock = [RCFormRow rowWithKind:RCFormRowSwitch title:RCL(@"Passcode lock")]; lock.on = _lock; lock.identifier = @"chat.codex.lock";
    RCFormRow *rep = [RCFormRow rowWithKind:RCFormRowButton title:RCL(@"Report a problem")]; rep.identifier = @"chat.codex.report";
    RCFormSection *w = [RCFormSection sectionWithTitle:RCL(@"Work") rows:[NSArray arrayWithObjects:pol, sty, nil]];
    RCFormSection *l = [RCFormSection sectionWithTitle:nil rows:[NSArray arrayWithObject:lock]]; l.footer = RCL(@"The passcode is asked when you open Codex. It does not lock ordinary chats.");
    RCFormSection *r = [RCFormSection sectionWithTitle:nil rows:[NSArray arrayWithObject:rep]]; r.footer = RCL(@"The report includes the task ID. Project code and files are not sent.");
    self.sections = [NSArray arrayWithObjects:w, l, r, nil];
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    (void)f;
    if ([row.identifier isEqualToString:@"chat.codex.policy"]) [self.navigationController pushViewController:[[[NSClassFromString(@"RCGalleryCodexPolicyPage") alloc] init] autorelease] animated:YES];
    else RCGalleryHUD(self.view, row.title);
}
- (void)form:(RCFormViewController *)f didToggleRow:(RCFormRow *)row {
    (void)f;
    if (!row.on) { _lock = NO; [self bind]; return; }
    RCPINViewController *pin = [[[RCPINViewController alloc] initWithMode:RCPINModeSet] autorelease]; pin.title = @"Codex"; pin.message = RCL(@"Codex passcode"); pin.delegate = self;
    [self presentViewController:[[[UINavigationController alloc] initWithRootViewController:pin] autorelease] animated:YES completion:nil];
}
- (BOOL)pinController:(RCPINViewController *)c checkPIN:(NSString *)p { (void)c; (void)p; return YES; }
- (void)pinController:(RCPINViewController *)c didSetPIN:(NSString *)p { (void)p; _lock = YES; [self bind]; [c dismissViewControllerAnimated:YES completion:nil]; }
- (void)pinControllerDidCancel:(RCPINViewController *)c { [self bind]; [c dismissViewControllerAnimated:YES completion:nil]; }
@end

@interface RCGalleryCodexPolicyPage : RCChecklistViewController <RCChecklistDelegate> { NSUInteger _sel; }
@end
@implementation RCGalleryCodexPolicyPage
- (id)init { if ((self = [super init])) { _sel = 1; self.delegate = self; self.title = RCL(@"Permissions"); [self bind]; } return self; }
- (void)dealloc { self.delegate = nil; [super dealloc]; }
- (void)bind {
    NSArray *t = [NSArray arrayWithObjects:RCL(@"Always ask"), RCL(@"Free inside the project"), RCL(@"Full access"), nil];
    NSArray *d = [NSArray arrayWithObjects:RCL(@"Before every command"), RCL(@"Network and outside — ask"), RCL(@"Only on a separate machine"), nil];
    self.footerText = [[NSArray arrayWithObjects:RCL(@"Codex asks before every command and change."), RCL(@"Reading, edits and commands in the project folder go without questions. Network and anything outside the project ask first."), RCL(@"Codex never asks. Use only on a separate machine."), nil] objectAtIndex:_sel];
    NSMutableArray *rows = [NSMutableArray array]; for (NSUInteger i = 0; i < t.count; i++) [rows addObject:[RCChecklistRow rowWithTitle:[t objectAtIndex:i] detail:[d objectAtIndex:i] checked:i == _sel]];
    self.sections = [NSArray arrayWithObject:[RCChecklistSection sectionWithTitle:RCL(@"Commands") rows:rows]];
}
- (void)checklist:(RCChecklistViewController *)c didSelectRow:(NSUInteger)row inSection:(NSUInteger)s { (void)c; (void)s; _sel = row; [self bind]; }
@end

@interface RCGalleryCodexTasksPage : RCFormViewController <RCFormDelegate, RCSwipeToDeleteDelegate> { RCSwipeToDelete *_swipe; RCSegmentedControl *_seg; NSMutableArray *_archived; }
@end
@implementation RCGalleryCodexTasksPage
- (id)init { if ((self = [super init])) { self.delegate = self; self.title = RCL(@"Codex tasks"); _archived = [[NSMutableArray alloc] initWithObjects:RCL(@"Rename the auth module"), nil]; } return self; }
- (void)dealloc { [_swipe detach]; [_swipe release]; [_seg release]; [_archived release]; self.delegate = nil; [super dealloc]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    _seg = [[RCSegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:RCL(@"Active"), RCL(@"Done"), RCL(@"Archive (tab)"), nil] style:RCSegmentedLight];
    _seg.selectedSegmentIndex = 1; [_seg addTarget:self action:@selector(bind) forControlEvents:UIControlEventValueChanged];
    UIView *h = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 50)] autorelease]; _seg.frame = CGRectMake(9, 12, 302, 30); [h addSubview:_seg]; self.tableView.tableHeaderView = h;
    _swipe = [[RCSwipeToDelete alloc] initWithTableView:self.tableView]; _swipe.title = RCL(@"Archive (action)"); _swipe.delegate = self;
    [self bind];
}
- (void)bind {
    if (!_seg) return;
    NSMutableArray *rows = [NSMutableArray array];
    NSArray *src = _seg.selectedSegmentIndex == 2 ? _archived : (_seg.selectedSegmentIndex == 1 ? [NSArray arrayWithObjects:RCL(@"Speed up the CSS build"), RCL(@"Tests for the date parser"), nil] : [NSArray arrayWithObject:RCL(@"Update dependencies")]);
    for (NSString *t in src) { RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:t]; r.subtitle = @"shop-web"; r.showsLamp = YES; r.lamp = _seg.selectedSegmentIndex == 0 ? RCLampBusy : RCLampOK; r.disclosure = YES; [rows addObject:r]; }
    RCFormSection *s = [RCFormSection sectionWithTitle:nil rows:rows];
    s.footer = _seg.selectedSegmentIndex == 2 ? RCL(@"Archived tasks keep their history; «Restore» in the task menu.") : RCL(@"Swipe a task left to archive it; hold it for the menu.");
    [_swipe hideAnimated:NO];
    self.sections = [NSArray arrayWithObject:s];
}
- (void)swipeToDelete:(RCSwipeToDelete *)s deleteRowAtIndexPath:(NSIndexPath *)ip {
    (void)s; RCFormRow *r = [[[self.sections objectAtIndex:0] rows] objectAtIndex:(NSUInteger)ip.row];
    [_archived addObject:r.title]; RCGalleryHUD(self.view, RCL(@"Archived")); [self bind];
}
- (BOOL)swipeToDelete:(RCSwipeToDelete *)s canDeleteRowAtIndexPath:(NSIndexPath *)ip { (void)s; (void)ip; return _seg.selectedSegmentIndex != 2; }
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row { (void)f; RCGalleryHUD(self.view, row.title); }
@end

@interface RCGalleryCodexFilesPage : RCFormViewController <RCFormDelegate> { NSString *_dir; }
- (id)initWithDirectory:(NSString *)dir;
@end
@implementation RCGalleryCodexFilesPage
- (id)initWithDirectory:(NSString *)dir {
    if ((self = [super init])) {
        _dir = [dir copy]; self.delegate = self; self.title = dir.length ? [dir lastPathComponent] : @"shop-web";
        NSDictionary *tree = [NSDictionary dictionaryWithObjectsAndKeys:[NSArray arrayWithObjects:@"src/", @"build/", @"package.json", @"README.md", nil], @"", [NSArray arrayWithObjects:@"auth/", @"routes/", @"index.js", nil], @"src", [NSArray arrayWithObjects:@"link.js", @"link.test.js", nil], @"src/auth", [NSArray arrayWithObjects:@"css.js", @"cache.js", nil], @"build", nil];
        NSMutableArray *rows = [NSMutableArray array];
        for (NSString *n in [tree objectForKey:_dir] ? [tree objectForKey:_dir] : [NSArray arrayWithObject:@"index.js"]) {
            BOOL d = [n hasSuffix:@"/"];
            RCFormRow *r = [RCFormRow rowWithKind:RCFormRowValue title:d ? [n substringToIndex:n.length - 1] : n]; r.glyph = d ? @"folder" : @"file"; r.tile = d ? RCTileBlue : RCTileGray; r.disclosure = YES; r.userInfo = [NSNumber numberWithBool:d]; [rows addObject:r];
        }
        self.sections = [NSArray arrayWithObject:[RCFormSection sectionWithTitle:[@"~/src/shop-web/" stringByAppendingString:_dir] rows:rows]];
    }
    return self;
}
- (void)dealloc { [_dir release]; self.delegate = nil; [super dealloc]; }
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    (void)f;
    NSString *p = _dir.length ? [_dir stringByAppendingPathComponent:row.title] : row.title;
    if ([row.userInfo boolValue]) { [self.navigationController pushViewController:[[[RCGalleryCodexFilesPage alloc] initWithDirectory:p] autorelease] animated:YES]; return; }
    RCGalleryPage *v = [[[NSClassFromString(@"RCGalleryCodexFileViewPage") alloc] init] autorelease]; v.title = row.title;
    [self.navigationController pushViewController:v animated:YES];
}
@end

@interface RCGalleryCodexFileViewPage : RCGalleryPage @end
@implementation RCGalleryCodexFileViewPage
- (void)build {
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:RCL(@"Mention") style:UIBarButtonItemStyleBordered target:self action:@selector(mention)] autorelease];
    RCCodeBlockView *c = [[[RCCodeBlockView alloc] initWithCode:@"export function verifyLink(token) {\n  const data = jwt.verify(token, SECRET, {\n    algorithms: [\"HS256\"],\n    clockTolerance: 30\n  });\n  return findUser(data.sub);\n}" language:@"javascript"] autorelease];
    c.copyEnabled = YES; [self addSpace:8]; [self addInsetView:c height:[c heightForWidth:300]];
    [self addNote:RCL(@"«Mention» adds the file to the task's next message.")];
}
- (void)mention { RCGalleryHUD(self.view, RCL(@"File mentioned")); }
@end

@interface RCGalleryCodexThreePage : RCGalleryPage <RCRatingRowViewDelegate, UIActionSheetDelegate, UIAlertViewDelegate, RCPartViewDelegate> { RCRatingRowView *_rate; }
@end
@implementation RCGalleryCodexThreePage
- (id)init { if ((self = [super init])) self.title = RCL(@"Codex, tier 3"); return self; }
- (void)dealloc { _rate.delegate = nil; [_rate release]; [super dealloc]; }
- (RCGoalStripView *)goal:(CGFloat)used { RCGoalStripView *g = [[[RCGoalStripView alloc] initWithFrame:CGRectZero] autorelease]; g.goal = RCL(@"CSS build faster than 2 s"); g.budgetUsed = used; return g; }
- (RCTimelineNoteView *)hook:(NSString *)t lamp:(RCLampState)l { RCTimelineNoteView *h = [[[RCTimelineNoteView alloc] initWithStyle:RCTimelineNoteMeta] autorelease]; h.lamp = l; h.text = t; return h; }
- (void)build {
    [self addCaption:RCL(@"Goal and budget")];
    [self addInsetView:[self goal:.35] height:-1]; [self addSpace:8];
    [self addInsetView:[self goal:.92] height:-1]; [self addSpace:8];
    [self addInsetView:[self goal:1] height:-1]; [self addSpace:6];
    [self addCaption:RCL(@"Subagents")];
    RCTaskPartView *sub = [[[RCTaskPartView alloc] initWithGlyph:@"person" tile:RCTileTeal] autorelease]; sub.title = RCL(@"Subagents · 3"); sub.subtitle = RCL(@"Working on parts of the task");
    sub.rows = [NSArray arrayWithObjects:[RCTaskRow stepWithText:RCL(@"Build timing — 9.1 s → 1.6 s") lamp:RCLampOK], [RCTaskRow stepWithText:RCL(@"CSS comparison — identical") lamp:RCLampOK], [RCTaskRow stepWithText:RCL(@"Browser check — running") lamp:RCLampBusy], nil];
    [self addInsetView:sub height:-1]; [self addSpace:6];
    [self addCaption:RCL(@"Hooks")];
    [self addInsetView:[self hook:RCL(@"hook pre-run · working copy check · passed · 0.4 s") lamp:RCLampOK] height:-1];
    [self addInsetView:[self hook:RCL(@"hook post-run · linter · stopped the task: 2 flake8 errors · 1.2 s") lamp:RCLampError] height:-1]; [self addSpace:6];
    [self addCaption:RCL(@"Result with a chart")];
    RCChartPartView *ch = [[[RCChartPartView alloc] initWithFrame:CGRectZero] autorelease]; ch.title = RCL(@"Build time, s");
    ch.values = [NSArray arrayWithObjects:[NSArray arrayWithObjects:RCL(@"before"), [NSNumber numberWithDouble:9.1], nil], [NSArray arrayWithObjects:RCL(@"after"), [NSNumber numberWithDouble:1.6], nil], nil];
    ch.delegate = self; [self addInsetView:ch height:-1]; [self addSpace:6];
    [self addCaption:RCL(@"Rating")];
    [_rate release]; _rate = [[RCRatingRowView alloc] initWithFrame:CGRectZero]; _rate.delegate = self; [self addInsetView:_rate height:36];
    [self addCaption:RCL(@"Task actions")];
    NSArray *b = [NSArray arrayWithObjects:RCL(@"Task menu"), RCL(@"Branch for a new task"), RCL(@"Codex settings"), RCL(@"Tasks and archive"), RCL(@"Project files"), RCL(@"Computer screen"), RCL(@"Codex passcode"), RCL(@"Cloud machine"), nil];
    int tags[] = {1, 2, 3, 4, 5, 6, 7, 9};
    for (NSUInteger i = 0; i < b.count; i++) { RCButton *x = [RCButton buttonWithStyle:RCButtonStyleLarge title:[b objectAtIndex:i]]; x.tag = tags[i]; [x addTarget:self action:@selector(tap:) forControlEvents:UIControlEventTouchUpInside]; [self addInsetView:x height:44]; [self addSpace:10]; }
    [self addNote:RCL(@"Attachments and dictation use the chat's «+» sheet and RCDictationView in the task composer.")];
    [self addSpace:10];
}
- (void)partViewDidChangeHeight:(RCPartView *)p { (void)p; [self relayout]; }
- (void)ratingRow:(RCRatingRowView *)row didRate:(NSInteger)r { row.rating = r; RCGalleryHUD(self.view, r > 0 ? RCL(@"Thanks") : RCL(@"Report a problem")); }
- (void)tap:(UIButton *)b {
    if (b.tag == 1) { UIActionSheet *s = [[[UIActionSheet alloc] initWithTitle:RCL(@"Speed up the CSS build") delegate:self cancelButtonTitle:RCL(@"Cancel") destructiveButtonTitle:nil otherButtonTitles:RCL(@"Rename"), RCL(@"Fork"), RCL(@"Project files"), RCL(@"Archive (action)"), nil] autorelease]; s.tag = 1; [s showInView:self.view]; return; }
    if (b.tag == 2) { UIActionSheet *s = [[[UIActionSheet alloc] initWithTitle:RCL(@"Where to make the changes") delegate:self cancelButtonTitle:RCL(@"Cancel") destructiveButtonTitle:nil otherButtonTitles:RCL(@"New branch in a separate worktree"), RCL(@"Current branch main"), nil] autorelease]; s.tag = 2; [s showInView:self.view]; return; }
    [self openVariant:[NSNumber numberWithInt:(int)b.tag]];
}
- (void)actionSheet:(UIActionSheet *)s clickedButtonAtIndex:(NSInteger)i {
    if (i == s.cancelButtonIndex) return;
    if (s.tag == 1 && i == 0) { UIAlertView *a = [[[UIAlertView alloc] initWithTitle:RCL(@"Task name") message:nil delegate:self cancelButtonTitle:RCL(@"Cancel") otherButtonTitles:RCL(@"Save"), nil] autorelease]; a.alertViewStyle = UIAlertViewStylePlainTextInput; [a textFieldAtIndex:0].text = RCL(@"Speed up the CSS build"); [a show]; return; }
    if (s.tag == 1 && i == 2) { [self openVariant:[NSNumber numberWithInt:5]]; return; }
    RCGalleryHUD(self.view, [s buttonTitleAtIndex:i]);
}
- (void)alertView:(UIAlertView *)a clickedButtonAtIndex:(NSInteger)i { if (i != a.cancelButtonIndex) RCGalleryHUD(self.view, RCL(@"Renamed")); }
- (UIImage *)screenImage {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(480, 300), YES, 1);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    RCDrawVerticalGradient(ctx, CGRectMake(0, 0, 480, 300), [NSArray arrayWithObjects:RCHex(0x4c7fa8), RCHex(0x9cc0d8), nil], nil);
    CGContextSetFillColorWithColor(ctx, RCHexA(0xffffff, .75).CGColor); CGContextFillRect(ctx, CGRectMake(0, 0, 480, 16));
    CGContextSetFillColorWithColor(ctx, RCHex(0x1b2b24).CGColor); CGContextFillRect(ctx, CGRectMake(40, 50, 380, 200));
    CGContextSetFillColorWithColor(ctx, RCHex(0x9fe0a9).CGColor);
    [@"$ codex resume\n> Speed up the CSS build\n  npm run css  1.6s" drawInRect:CGRectMake(52, 62, 360, 180) withFont:[UIFont fontWithName:@"Courier" size:14]];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return img;
}
- (void)openVariant:(NSNumber *)n {
    int v = [n intValue]; UIViewController *vc = nil;
    if (v == 3) vc = [[[RCGalleryCodexSettingsPage alloc] init] autorelease];
    else if (v == 4) vc = [[[RCGalleryCodexTasksPage alloc] init] autorelease];
    else if (v == 5) vc = [[[RCGalleryCodexFilesPage alloc] initWithDirectory:@""] autorelease];
    else if (v == 8) vc = [[[RCGalleryCodexPolicyPage alloc] init] autorelease];
    else if (v == 9) { RCChecklistViewController *c = [[[RCChecklistViewController alloc] init] autorelease]; c.title = RCL(@"Computer");
        c.sections = [NSArray arrayWithObject:[RCChecklistSection sectionWithTitle:@"shop-web" rows:[NSArray arrayWithObjects:[RCChecklistRow rowWithTitle:RCL(@"Standard") detail:RCL(@"4 cores") checked:YES], [RCChecklistRow rowWithTitle:RCL(@"Large") detail:RCL(@"16 cores") checked:NO], nil]]]; vc = c; }
    else if (v == 6) { [self presentViewController:[RCImageViewerController navigationControllerWithImage:[self screenImage] caption:RCL(@"MacBook Pro · snapshot") delegate:nil] animated:YES completion:nil]; return; }
    else if (v == 7) { RCPINViewController *p = [[[RCPINViewController alloc] initWithMode:RCPINModeUnlock] autorelease]; p.titleText = RCL(@"Codex passcode"); p.title = @"Codex"; [self presentViewController:[[[UINavigationController alloc] initWithRootViewController:p] autorelease] animated:YES completion:nil]; return; }
    if (vc) [self.navigationController pushViewController:vc animated:YES];
}
@end
