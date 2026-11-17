// API 7/10 kit additions (docs/ui-kit.md, «API 7/10 kit additions»), stage 7+.
//  • RCGalleryFormPage — RCFormViewController: value (+ lamp, second line, disclosure, busy),
//    switch, text, long text, note, check, button and destructive button; busy state;
//    route chatgptxkit://page/Form (open=3: busy, open=4: read-only state with notes).
//  • RCGalleryPriority7Page — RCPlaybackView states, RCClarifyPartView structured answers
//    (own answer hidden per question), RCShareLinkSheet with «Открыть снимок» / «Удалить ссылку»,
//    RCCodeBlockView with blockIndex and app-side copy, RCDrawerController long press;
//    route chatgptxkit://page/Priority7.
#import "RCGalleryDemos.h"
#import "RCFormViewController.h"
#import "RCPlaybackView.h"
#import "RCReadAloudBar.h"
#import "RCClarifyPartView.h"
#import "RCShareLinkSheet.h"
#import "RCCodeBlockView.h"
#import "RCDrawerController.h"
#import "RCTheme.h"

@interface RCGalleryFormPage : RCFormViewController <RCFormDelegate> { BOOL _readOnly; }
@end
@implementation RCGalleryFormPage
- (id)init {
    if ((self = [super init])) { self.delegate = self; self.title = RCL(@"Form"); [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(bind) name:RCGalleryStageDidChangeNotification object:nil]; [self bind]; }
    return self;
}
- (void)dealloc { [NSObject cancelPreviousPerformRequestsWithTarget:self]; [[NSNotificationCenter defaultCenter] removeObserver:self]; self.delegate = nil; [super dealloc]; }
- (void)bind {
    if (!RCGalleryOn(7)) { self.headerText = RCL(@"API 7 settings screens appear from stage 7."); self.sections = [NSArray array]; return; }
    self.headerText = _readOnly ? RCL(@"Read only: the service values and where to change them.") : nil;
    RCFormRow *v = [RCFormRow rowWithKind:RCFormRowValue title:RCL(@"Saved memory")]; v.value = RCL(@"On"); v.showsLamp = YES; v.lamp = RCLampOK;
    RCFormRow *two = [RCFormRow rowWithKind:RCFormRowValue title:RCL(@"Plus")]; two.value = RCL(@"3000 JPY"); two.subtitle = RCL(@"Month: 3000 JPY · year: 30000 JPY");
    RCFormRow *dis = [RCFormRow rowWithKind:RCFormRowValue title:RCL(@"Privacy center")]; dis.value = RCL(@"Safari"); dis.disclosure = YES; dis.glyph = @"shield"; dis.tile = RCTileBlue;
    RCFormRow *busy = [RCFormRow rowWithKind:RCFormRowValue title:RCL(@"Checking the file…")]; busy.busy = YES;
    RCFormRow *sw = [RCFormRow rowWithKind:RCFormRowSwitch title:RCL(@"Use personalization")]; sw.on = YES; sw.subtitle = RCL(@"Instructions apply to new chats."); sw.enabled = !_readOnly;
    RCFormRow *text = [RCFormRow rowWithKind:RCFormRowText title:RCL(@"Occupation")]; text.text = RCL(@"Engineer"); text.maxLength = 1500; text.enabled = !_readOnly;
    RCFormRow *longText = [RCFormRow rowWithKind:RCFormRowLongText title:RCL(@"Instructions")]; longText.text = [NSString stringWithFormat:@"%@\n%@", RCL(@"Answer in Russian."), RCL(@"Short and to the point.")]; longText.enabled = !_readOnly;
    RCFormRow *note = [RCFormRow rowWithKind:RCFormRowNote title:RCL(@"Shown for reference. You can change this in the web version.")];
    RCFormRow *c1 = [RCFormRow rowWithKind:RCFormRowCheck title:RCL(@"Light")]; c1.checked = YES; RCFormRow *c2 = [RCFormRow rowWithKind:RCFormRowCheck title:RCL(@"Dark")];
    RCFormRow *b = [RCFormRow rowWithKind:RCFormRowButton title:RCL(@"Save instructions")]; b.enabled = !_readOnly;
    RCFormRow *red = [RCFormRow rowWithKind:RCFormRowButton title:RCL(@"Clear temporary files")]; red.destructive = YES;
    RCFormSection *s1 = [RCFormSection sectionWithTitle:RCL(@"Values") rows:[NSArray arrayWithObjects:v, two, dis, busy, nil]];
    RCFormSection *s2 = [RCFormSection sectionWithTitle:RCL(@"Input") rows:(_readOnly ? [NSArray arrayWithObjects:sw, note, nil] : [NSArray arrayWithObjects:sw, text, longText, b, nil])]; s2.footer = RCL(@"Up to 1,500 characters. The service may have its own limits.");
    RCFormSection *s3 = [RCFormSection sectionWithTitle:RCL(@"Choice") rows:[NSArray arrayWithObjects:c1, c2, nil]];
    self.sections = [NSArray arrayWithObjects:s1, s2, s3, [RCFormSection sectionWithTitle:nil rows:[NSArray arrayWithObject:red]], nil];
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    (void)f;
    if (row.kind == RCFormRowCheck) { for (RCFormSection *s in self.sections) for (RCFormRow *r in s.rows) if (r.kind == RCFormRowCheck) r.checked = r == row; self.busy = YES; [self performSelector:@selector(done) withObject:nil afterDelay:.6]; return; }
    RCGalleryHUD(self.view, row.title);
}
- (void)done { self.busy = NO; self.sections = self.sections; }
- (void)form:(RCFormViewController *)f didToggleRow:(RCFormRow *)row { (void)f; RCGalleryHUD(self.view, row.on ? RCL(@"On") : RCL(@"Off")); }
- (void)openVariant:(NSNumber *)n { if ([n intValue] == 3) self.busy = YES; else if ([n intValue] == 4) { _readOnly = YES; [self bind]; } }
@end

@interface RCGalleryPriority7Page : RCGalleryPage <RCReadAloudBarDelegate, RCPlaybackViewDelegate, RCClarifyPartViewDelegate, RCShareLinkSheetDelegate, RCCodeBlockViewDelegate, RCDrawerControllerDelegate> { RCPlaybackView *_live; RCReadAloudBar *_mini; NSTimer *_timer; }
@end
@implementation RCGalleryPriority7Page
- (void)dealloc { [NSObject cancelPreviousPerformRequestsWithTarget:self]; [_timer invalidate]; _live.delegate = nil; [_live release]; _mini.delegate=nil; [_mini release]; [super dealloc]; }
- (void)readAloudBarDidTapPlay:(RCReadAloudBar *)bar { bar.state=RCPlaybackPlaying; }
- (void)readAloudBarDidTapPause:(RCReadAloudBar *)bar { bar.state=RCPlaybackPaused; }
- (void)readAloudBarDidTapRetry:(RCReadAloudBar *)bar { bar.state=RCPlaybackPlaying; }
// Close slides the strip up behind its top edge; the gallery brings it back to show the slide-in.
- (void)readAloudBarDidClose:(RCReadAloudBar *)bar { [bar setPresented:NO animated:YES]; [self performSelector:@selector(representReadAloudBar:) withObject:bar afterDelay:1.2]; }
- (void)representReadAloudBar:(RCReadAloudBar *)bar { [bar setPresented:YES animated:YES]; }
- (void)readAloudBar:(RCReadAloudBar *)bar didChooseRate:(double)rate { bar.rate=rate; }
- (void)readAloudBarDidChangeHeight:(RCReadAloudBar *)bar { (void)bar; [self relayout]; }
- (RCPlaybackView *)player:(RCPlaybackState)state position:(NSTimeInterval)p {
    RCPlaybackView *v = [[[RCPlaybackView alloc] initWithFrame:CGRectMake(0, 0, 300, 120)] autorelease]; v.title = RCL(@"Note.wav"); v.state = state; v.position = p; v.duration = 90; v.delegate = self; return v;
}
- (void)build {
    [_timer invalidate]; _timer = nil;
    if (!RCGalleryOn(7)) { [self addNote:RCL(@"These elements appear from stage 7.")]; [self addSpace:20]; return; }
    [self addCaption:RCL(@"Read aloud mini player")];
    [_mini release]; _mini=[[RCReadAloudBar alloc]initWithFrame:CGRectZero]; _mini.state=RCPlaybackPlaying; _mini.position=12; _mini.duration=90; _mini.delegate=self; [self addView:_mini]; [self addSpace:10];
    RCReadAloudBar *miniPaused=[[[RCReadAloudBar alloc]initWithFrame:CGRectZero]autorelease]; miniPaused.state=RCPlaybackPaused; miniPaused.position=31; miniPaused.duration=90; miniPaused.rate=1.5; miniPaused.delegate=self; [self addView:miniPaused]; [self addSpace:10];
    RCReadAloudBar *miniLoading=[[[RCReadAloudBar alloc]initWithFrame:CGRectZero]autorelease]; miniLoading.busy=YES; miniLoading.delegate=self; [self addView:miniLoading]; [self addSpace:10];
    RCReadAloudBar *miniFailed=[[[RCReadAloudBar alloc]initWithFrame:CGRectZero]autorelease]; miniFailed.state=RCPlaybackFailed; miniFailed.delegate=self; [self addView:miniFailed];
    [self addCaption:RCL(@"Playback (RCPlaybackView)")];
    [_live release]; _live = [[self player:RCPlaybackIdle position:0] retain]; [self addInsetView:_live height:[_live heightForWidth:300]];
    RCPlaybackView *paused = [self player:RCPlaybackPaused position:31]; paused.rate = 1.5; [self addInsetView:paused height:[paused heightForWidth:300]];
    RCPlaybackView *failed = [self player:RCPlaybackFailed position:0]; failed.failureText = RCL(@"The file is no longer on this iPhone."); [self addInsetView:failed height:[failed heightForWidth:300]];
    [self addNote:RCL(@"The app reports the state: the view never pretends to play.")];
    [self addCaption:RCL(@"Clarifying questions: per-question answers")];
    RCClarifyPartView *c = [[[RCClarifyPartView alloc] initWithFrame:CGRectMake(0, 0, 300, 200)] autorelease];
    RCClarifyQuestion *q1 = [RCClarifyQuestion questionWithText:RCL(@"Who is the text for?") options:[NSArray arrayWithObjects:RCL(@"For me"), RCL(@"For colleagues"), nil] multiple:NO]; q1.requiresAnswer = YES;
    RCClarifyQuestion *q2 = [RCClarifyQuestion questionWithText:RCL(@"How long?") options:[NSArray arrayWithObjects:RCL(@"Short"), RCL(@"In detail"), nil] multiple:NO]; q2.ownAnswerHidden = YES;
    c.questions = [NSArray arrayWithObjects:q1, q2, nil]; c.delegate = self; [self addInsetView:c height:[c heightForWidth:300]];
    [self addNote:RCL(@"The second question takes no own answer (allowFreeText NO).")];
    [self addCaption:RCL(@"Code: the app copies it (blockIndex)")];
    RCCodeBlockView *code = [[[RCCodeBlockView alloc] initWithCode:@"print(\"hello\")" language:@"python"] autorelease]; code.copyEnabled = YES; code.blockIndex = 0; code.delegate = self;
    [self addInsetView:code height:[code heightForWidth:300]];
    [self addCaption:RCL(@"Link and chat actions")];
    RCButton *share = [RCButton buttonWithStyle:RCButtonStyleLarge title:RCL(@"Link created: open, delete")]; [share addTarget:self action:@selector(showShare) forControlEvents:UIControlEventTouchUpInside]; [self addInsetView:share height:44];
    RCButton *drawer = [RCButton buttonWithStyle:RCButtonStyleLarge title:RCL(@"Drawer: press and hold a row")]; [drawer addTarget:self action:@selector(showDrawer) forControlEvents:UIControlEventTouchUpInside]; [self addInsetView:drawer height:44];
    [self addSpace:20];
}
- (void)playbackViewDidTapPlay:(RCPlaybackView *)v { v.state = RCPlaybackPlaying; if (v == _live && !_timer) _timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(tick) userInfo:nil repeats:YES]; }
- (void)tick { _live.position = MIN(_live.duration, _live.position + _live.rate); if (_live.position >= _live.duration) { _live.state = RCPlaybackStopped; [_timer invalidate]; _timer = nil; } }
- (void)playbackViewDidTapPause:(RCPlaybackView *)v { v.state = RCPlaybackPaused; if (v == _live) { [_timer invalidate]; _timer = nil; } }
- (void)playbackViewDidTapStop:(RCPlaybackView *)v { v.state = RCPlaybackStopped; v.position = 0; if (v == _live) { [_timer invalidate]; _timer = nil; } }
- (void)playbackViewDidTapRetry:(RCPlaybackView *)v { v.state = RCPlaybackIdle; v.failureText = nil; }
- (void)playbackView:(RCPlaybackView *)v didChooseRate:(double)rate { v.rate = rate; }
- (void)partViewDidChangeHeight:(RCPartView *)p { (void)p; [self relayout]; }
- (void)clarifyPart:(RCClarifyPartView *)part didFinishWithSelections:(NSArray *)s { (void)part; RCGalleryAlert(RCL(@"Answers"), [s description]); }
- (BOOL)codeBlockViewShouldCopy:(RCCodeBlockView *)v { RCGalleryHUD(self.view, [NSString stringWithFormat:RCL(@"Block %ld is copied by the app"), (long)v.blockIndex]); return NO; }
- (void)showShare {
    RCShareLinkSheet *s = [[[RCShareLinkSheet alloc] init] autorelease]; s.chatTitle = RCL(@"Conversation"); s.showsNameSwitch = NO; s.delegate = self;
    s.state = RCShareLinkCreated; s.link = @"https://chatgpt.com/share/00000000-0000-4000-8000-000000000000"; s.openAvailable = YES; s.revokeAvailable = YES;
    [self presentViewController:[RCShareLinkSheet navigationControllerWithSheet:s] animated:YES completion:nil];
}
- (void)shareLinkSheet:(RCShareLinkSheet *)s createLinkIncludingName:(BOOL)n { (void)n; s.state = RCShareLinkCreated; }
- (void)shareLinkSheet:(RCShareLinkSheet *)s openLink:(NSString *)l { (void)l; RCGalleryHUD(s.view, RCL(@"Open snapshot")); }
- (void)shareLinkSheet:(RCShareLinkSheet *)s revokeLink:(NSString *)l { (void)l; s.revokeAvailable = NO; s.openAvailable = NO; RCGalleryHUD(s.view, RCL(@"Link deleted")); }
- (void)showDrawer {
    RCDrawerController *d = [[[RCDrawerController alloc] init] autorelease]; d.delegate = self; d.accountName = RCL(@"Account");
    RCDrawerItem *pinned = [RCDrawerItem itemWithTitle:RCL(@"Pinned chat") glyph:@"pin" style:RCDrawerRowChat]; pinned.actionsAvailable = YES;
    RCDrawerItem *chat = [RCDrawerItem itemWithTitle:RCL(@"Ordinary chat") glyph:nil style:RCDrawerRowChat]; chat.actionsAvailable = YES;
    d.sections = [NSArray arrayWithObjects:[RCDrawerSection sectionWithTitle:RCL(@"Pinned") items:[NSArray arrayWithObject:pinned]], [RCDrawerSection sectionWithTitle:RCL(@"Today") items:[NSArray arrayWithObject:chat]], nil];
    [self.navigationController pushViewController:d animated:YES];
}
- (void)drawer:(RCDrawerController *)d didLongPressItem:(RCDrawerItem *)item { (void)d; RCGalleryAlert(item.title, RCL(@"Rename · Pin · Archive · Delete")); }
- (void)openVariant:(NSNumber *)n { if ([n intValue] == 3) [self showShare]; else if ([n intValue] == 4) [self showDrawer]; }
@end
