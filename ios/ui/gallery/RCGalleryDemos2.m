// Gallery pages for the second component batch: Markdown, rich parts, empty chat, HUD/progress.
#import "RCGalleryDemos.h"
#import "RCTheme.h"
#import "RCGlyph.h"
#import "RCButton.h"
#import "RCHUD.h"
#import "RCProgressView.h"
#import "RCAnswerCardView.h"
#import "RCMarkdownView.h"
#import "RCPartPlaceholderView.h"
#import "RCImagePartView.h"
#import "RCImageViewerController.h"
#import "RCChartPartView.h"
#import "RCTaskPartView.h"
#import "RCMailPartView.h"
#import "RCClarifyPartView.h"
#import "RCFilePartView.h"
#import "RCEmptyChatView.h"

static NSString *kMarkdownSample(void) {
    return RCL(@"## Saturday plan\nMorning — **Kremlin** and *Kul Sharif* Mosque, afternoon — Bauman Street. Details at [kazan.travel](https://kazan.travel).\n\n### What to bring\n- comfortable shoes\n- `power bank` 10,000 mAh\n- umbrella: rain is forecast\n\n1. Kremlin — 2 h\n2. Lunch in the Old Quarter\n3. Kazanka embankment\n\n> Mosque entry is free, but a headscarf is required.\n\n| Place | Time | Price |\n|---|---|---|\n| Kremlin | 2 h | 0 ₽ |\n| Chak-Chak Museum | 1 h | 500 ₽ |\n\n```python\n# trip budget\ncosts = [500, 1200, 800]\nprint(\"Total:\", sum(costs))\n```\nHave a nice trip!");
}

static RCAnswerCardView *RCCard(NSString *text) {
    RCAnswerCardView *c = [[[RCAnswerCardView alloc] initWithFrame:CGRectMake(0, 0, 320, 100)] autorelease];
    c.text = text;
    c.textMode = RCGalleryOn(9) ? RCAnswerTextMarkdown : RCAnswerTextPlain;
    c.copyCodeEnabled = RCGalleryOn(7);
    c.copyMenuEnabled = RCGalleryOn(9);
    return c;
}

#pragma mark - Markdown

@interface RCGalleryMarkdownPage () <RCCodeBlockViewDelegate, RCAnswerCardViewDelegate> { NSTimer *_stream; RCAnswerCardView *_streaming; NSUInteger _shown; }
@end

@implementation RCGalleryMarkdownPage
- (void)dealloc { [_stream invalidate]; [_streaming release]; [super dealloc]; }
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [_stream invalidate]; _stream = nil; }

- (void)build {
    BOOL rich = RCGalleryOn(9);
    [self addCaption:rich ? RCL(@"Markdown (stage 9+)") : RCL(@"Stage 10: plain text without markup")];
    RCAnswerCardView *c = RCCard(kMarkdownSample());
    c.codeDelegate = self;
    c.delegate = self; // links: tap a paragraph with a link
    [self addView:c];
    [self addNote:rich ? (RCGalleryOn(7) ? RCL(@"Headings, lists, quote, table, links, and code. “Copy” on code is stage 7.") : RCL(@"Headings, lists, quote, table, links, and code. “Copy” on code appears at stage 7."))
                       : RCL(@"At stage 10 Markdown is not rendered: formatting symbols are stripped and text reads as plain.")];
    // Escaped punctuation (as answers come back from history): plain characters outside code; code keeps "\\".
    [self addCaption:RCL(@"Escaped punctuation")];
    RCAnswerCardView *escaped = RCCard(@"Dessert (tiramisu)\\. Polite forms (desu\\, masu\\)\\. Stars \\*not italic\\*, path C:\\\\temp, code `a\\.b`.\n\n```python\nre.sub(r\"\\.\", \"\", s)\n```");
    escaped.codeDelegate = self; [self addView:escaped];
    [self addNote:RCL(@"Should read: (tiramisu). (desu, masu). *not italic*, C:\\temp; code keeps its backslash.")];
    [self addCaption:RCL(@"Stream with cursor")];
    [_streaming release];
    _streaming = [RCCard(@"") retain];
    _streaming.state = RCAnswerStreaming;
    _streaming.codeDelegate = self;
    [self addView:_streaming];
    _shown = 0;
    [_stream invalidate];
    _stream = [NSTimer scheduledTimerWithTimeInterval:.15 target:self selector:@selector(tick) userInfo:nil repeats:YES];
}

- (void)tick {
    NSArray *lines = [kMarkdownSample() componentsSeparatedByString:@"\n"];
    NSUInteger n = MIN(lines.count, 6);
    if (_shown >= n * 6 + 12) _shown = 0;
    _shown++;
    NSUInteger full = MIN(_shown / 6, n);
    NSString *t = [[lines subarrayWithRange:NSMakeRange(0, full)] componentsJoinedByString:@"\n"];
    if (full < n) {
        NSString *next = [lines objectAtIndex:full];
        NSUInteger part = next.length * (_shown % 6) / 6;
        t = [t stringByAppendingFormat:@"%@%@", (full ? @"\n" : @""), [next substringToIndex:part]];
    }
    CGFloat before = [_streaming heightForWidth:320];
    _streaming.text = t;
    if ([_streaming heightForWidth:320] != before) [self relayout];
}

- (void)codeBlockViewDidCopy:(RCCodeBlockView *)view { RCGalleryHUD(self.view, RCL(@"Code copied")); }
- (void)answerCard:(RCAnswerCardView *)card didSelectLinkURL:(NSURL *)url title:(NSString *)title { RCGalleryAlert(title, url.absoluteString); }
@end

#pragma mark - Rich parts

@interface RCGalleryPartsPage () <RCClarifyPartViewDelegate> {
    NSTimer *_timer; RCImagePartView *_making, *_offer; RCTaskPartView *_research; RCFilePartView *_file; int _tick;
}
@end

@implementation RCGalleryPartsPage
- (void)dealloc { [NSObject cancelPreviousPerformRequestsWithTarget:self]; [_timer invalidate]; [_making release]; [_offer release]; [_research release]; [_file release]; [super dealloc]; }
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [_timer invalidate]; _timer = nil; [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(previewLoaded) object:nil]; }

- (void)addPart:(UIView *)part caption:(NSString *)caption text:(NSString *)text {
    [self addCaption:caption];
    RCAnswerCardView *c = RCCard(text);
    if ([part isKindOfClass:[RCPartView class]]) ((RCPartView *)part).delegate = (id)self;
    c.partViews = [NSArray arrayWithObject:part];
    [self addView:c];
}

- (UIView *)placeholder:(NSString *)glyph tile:(RCTileColor)tile title:(NSString *)title {
    return [[[RCPartPlaceholderView alloc] initWithGlyph:glyph tile:tile title:title text:nil] autorelease];
}

- (void)build {
    BOOL s7 = RCGalleryOn(7), s8 = RCGalleryOn(8), s6 = RCGalleryOn(6);
    [_timer invalidate]; _timer = nil; _tick = 0;
    [_making release]; _making = nil; [_offer release]; _offer = nil; [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(previewLoaded) object:nil]; [_research release]; _research = nil; [_file release]; _file = nil;

    // image: stage 7 (save/share 7, viewer 6)
    if (s7) {
        RCImagePartView *img = [[[RCImagePartView alloc] init] autorelease];
        img.actionsEnabled = YES;
        [img.saveButton addTarget:self action:@selector(saved) forControlEvents:UIControlEventTouchUpInside];
        [self addPart:img caption:RCL(@"Image (stage 7)") text:RCL(@"Here is the image based on your description:")];
        _making = [[RCImagePartView alloc] init];
        _making.making = YES;
        [self addPart:_making caption:RCL(@"Creating") text:nil];
        // Tap-to-show preview (stage 7): the app downloads only after a tap; the view shows its state.
        _offer = [[RCImagePartView alloc] init];
        _offer.actionsEnabled = YES; _offer.previewState = RCImagePreviewOffer;
        [_offer.artButton addTarget:self action:@selector(previewTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self addPart:_offer caption:RCL(@"Preview: tap → download → shown") text:RCL(@"Image from chat history:")];
        RCImagePreviewState states[] = { RCImagePreviewShown, RCImagePreviewFailed, RCImagePreviewUnknown, RCImagePreviewUnavailable };
        NSString *captions[] = { RCL(@"Shown (real image)"), RCL(@"Failed — tap retries"), RCL(@"Result unknown — no retry"), RCL(@"Preview unavailable") };
        for (int i = 0; i < 4; i++) {
            RCImagePartView *p = [[[RCImagePartView alloc] init] autorelease];
            p.actionsEnabled = YES; p.previewState = states[i];
            if (states[i] == RCImagePreviewShown) { p.image = [RCTheme appIconImage:57]; p.viewerAvailable = RCGalleryOn(6); [p.artButton addTarget:self action:@selector(openShownImage:) forControlEvents:UIControlEventTouchUpInside]; }
            if (states[i] == RCImagePreviewFailed) [p.artButton addTarget:self action:@selector(previewTapped:) forControlEvents:UIControlEventTouchUpInside];
            [self addPart:p caption:captions[i] text:nil];
        }
    } else [self addPart:[self placeholder:@"photo" tile:RCTilePurple title:RCL(@"Image")] caption:RCL(@"Image → placeholder before stage 7") text:RCL(@"Here is the image:")];

    // chart: stage 7
    if (s7) {
        RCChartPartView *ch = [[[RCChartPartView alloc] init] autorelease];
        ch.title = RCL(@"Revenue, M RUB");
        ch.values = [NSArray arrayWithObjects:[NSArray arrayWithObjects:RCL(@"Jan"), [NSNumber numberWithFloat:1.2], nil], [NSArray arrayWithObjects:RCL(@"Feb"), [NSNumber numberWithFloat:1.5], nil], [NSArray arrayWithObjects:RCL(@"Mar"), [NSNumber numberWithFloat:1.9], nil], nil];
        ch.code = RCL(@"import matplotlib.pyplot as plt\nplt.bar([\"Jan\",\"Feb\",\"Mar\"], [1.2, 1.5, 1.9])\nplt.title(\"Revenue, M RUB\")");
        ch.codeCopyEnabled = YES;
        [self addPart:ch caption:RCL(@"Chart (stage 7)") text:RCL(@"Sales are growing for the third month in a row:")];
    } else [self addPart:[self placeholder:@"chart" tile:RCTileTeal title:RCL(@"Chart")] caption:RCL(@"Chart → placeholder before stage 7") text:nil];

    // research: stage 7, export 6
    if (s7) {
        _research = [[RCTaskPartView alloc] initWithGlyph:@"research" tile:RCTileOrange];
        _research.title = RCL(@"Electric bike market in Russia");
        [self addPart:_research caption:RCL(@"Research in progress (stage 7)") text:nil];
        RCTaskPartView *done = [[[RCTaskPartView alloc] initWithGlyph:@"research" tile:RCTileOrange] autorelease];
        done.title = RCL(@"Electric bike market in Russia");
        done.subtitle = RCL(@"Done · 4 min · 33 sources · 8 pp.");
        done.rows = [NSArray arrayWithObjects:[RCTaskRow stepWithText:RCL(@"Created research plan") lamp:RCLampOK], [RCTaskRow stepWithText:RCL(@"Found 33 sources") lamp:RCLampOK],
                     [RCTaskRow stepWithText:RCL(@"Compared data and verified dates") lamp:RCLampOK], [RCTaskRow stepWithText:RCL(@"Writing report") lamp:RCLampOK], nil];
        NSMutableArray *b = [NSMutableArray arrayWithObject:[RCButton buttonWithStyle:RCButtonStylePillGo title:RCL(@"Open report")]];
        if (s6) [b addObject:[RCButton buttonWithStyle:RCButtonStylePill title:RCL(@"Save PDF")]];
        done.footerButtons = b;
        [self addPart:done caption:s6 ? RCL(@"Done (PDF — stage 6)") : RCL(@"Done") text:nil];
        [self researchStep];
    } else [self addPart:[self placeholder:@"research" tile:RCTileOrange title:RCL(@"Research report")] caption:RCL(@"Research → placeholder before stage 7") text:nil];

    // approval: stage 7
    if (s7) {
        RCTaskPartView *ap = [[[RCTaskPartView alloc] initWithGlyph:@"apps" tile:RCTilePurple] autorelease];
        ap.title = RCL(@"“Calendar” wants to create an event");
        ap.subtitle = RCL(@"Nothing will happen without your permission");
        ap.rows = [NSArray arrayWithObjects:[RCTaskRow paramWithKey:RCL(@"What") value:RCL(@"Meeting with Anna")], [RCTaskRow paramWithKey:RCL(@"When") value:RCL(@"Fri, Nov 14, 15:00")], [RCTaskRow paramWithKey:RCL(@"Where") value:RCL(@"Cafe “Skazka”")], nil];
        RCButton *allow = [RCButton buttonWithStyle:RCButtonStylePillGo title:RCL(@"Allow")], *deny = [RCButton buttonWithStyle:RCButtonStylePill title:RCL(@"Deny")];
        [allow addTarget:self action:@selector(approve:) forControlEvents:UIControlEventTouchUpInside];
        [deny addTarget:self action:@selector(deny:) forControlEvents:UIControlEventTouchUpInside];
        ap.footerButtons = [NSArray arrayWithObjects:allow, deny, nil];
        [self addPart:ap caption:RCL(@"App action (stage 7)") text:nil];
    } else [self addPart:[self placeholder:@"apps" tile:RCTilePurple title:RCL(@"App action")] caption:RCL(@"Action → placeholder before stage 7") text:nil];

    // mail: stage 7, send 6
    if (s7) {
        RCMailPartView *m = [[[RCMailPartView alloc] init] autorelease];
        m.to = @"landlord@example.com"; m.subject = RCL(@"Faucet repair");
        m.body = RCL(@"Hello!\n\nThe kitchen faucet is leaking. When would be a good time to send a plumber?\n\nThanks, Anna");
        m.sendEnabled = s6;
        [self addPart:m caption:s6 ? RCL(@"Email draft (send — stage 6)") : RCL(@"Email draft (stage 7)") text:RCL(@"Here is the draft:")];
    } else [self addPart:[self placeholder:@"mail" tile:RCTileBlue title:RCL(@"Email draft")] caption:RCL(@"Email → placeholder before stage 7") text:nil];

    // clarify: stage 7
    if (s7) {
        RCClarifyPartView *q = [[[RCClarifyPartView alloc] init] autorelease];
        q.questions = [NSArray arrayWithObjects:[RCClarifyQuestion questionWithText:RCL(@"For what budget?") options:[NSArray arrayWithObjects:RCL(@"Under 50K RUB"), RCL(@"50–100K RUB"), RCL(@"No limit"), nil] multiple:NO],
                       [RCClarifyQuestion questionWithText:RCL(@"What matters more?") options:[NSArray arrayWithObjects:RCL(@"Range"), RCL(@"Weight"), RCL(@"Price"), nil] multiple:YES], nil];
        [self addPart:q caption:RCL(@"Clarifying questions (stage 7)") text:RCL(@"To pick a bike, let me clarify:")];
    } else [self addPart:[self placeholder:@"sliders" tile:RCTileGreen title:RCL(@"Clarifying questions")] caption:RCL(@"Questions → placeholder before stage 7") text:nil];

    // file: stage 8 (expiry 8)
    if (s8) {
        _file = [[RCFilePartView alloc] init];
        _file.fileName = RCL(@"Trip budget.xlsx"); _file.detail = RCL(@"820 KB");
        [_file.actionButton addTarget:self action:@selector(fileTap) forControlEvents:UIControlEventTouchUpInside];
        [self addPart:_file caption:RCL(@"File (stage 8): Download → progress → Open") text:nil];
        RCFilePartView *ex = [[[RCFilePartView alloc] init] autorelease];
        ex.fileName = RCL(@"Old report.pdf"); ex.state = RCFileExpired;
        [self addPart:ex caption:RCL(@"Expired") text:nil];
    } else [self addPart:[self placeholder:@"file" tile:RCTileBlue title:RCL(@"File")] caption:RCL(@"File → placeholder before stage 8") text:nil];

    _timer = [NSTimer scheduledTimerWithTimeInterval:.7 target:self selector:@selector(animate) userInfo:nil repeats:YES];
    [self addNote:RCL(@"Parts not available at the current stage are shown with a “saved in conversation” placeholder. Dark card colors are a kit extension.")];
}

- (void)researchStep {
    NSArray *steps = [NSArray arrayWithObjects:RCL(@"Created research plan"), RCL(@"Found %d sources"), RCL(@"Compared data and verified dates"), RCL(@"Writing report"), nil];
    int shown = 1 + (_tick / 3) % 4;
    NSMutableArray *rows = [NSMutableArray array];
    for (int i = 0; i < shown; i++)
        [rows addObject:[RCTaskRow stepWithText:[NSString stringWithFormat:[steps objectAtIndex:i], 11 * shown] lamp:(i < shown - 1 ? RCLampOK : RCLampBusy)]];
    _research.subtitle = RCL(@"Research in progress — you can close the app, the report will appear in this chat");
    _research.progress = shown / 4.0;
    _research.rows = rows;
}

- (void)animate {
    _tick++;
    CGFloat p = (_tick % 8) / 7.0;
    [_making setProgress:p];
    if (_research && _tick % 3 == 0) { CGFloat before = [_research heightForWidth:276]; [self researchStep]; if ([_research heightForWidth:276] != before) [self relayout]; }
    if (_file.state == RCFileDownloading) {
        _file.progress = MIN(1, _file.progress + .25);
        if (_file.progress >= 1) { _file.state = RCFileSaved; [self relayout]; }
    }
}

- (void)partViewDidChangeHeight:(RCPartView *)part { [self relayout]; }
- (void)clarifyPart:(RCClarifyPartView *)part didFinishWithAnswer:(NSString *)answer { RCGalleryAlert(RCL(@"Answer will be sent as a message"), answer); }
- (void)saved { RCGalleryHUD(self.view, RCL(@"Saved to Photos")); }
- (void)previewTapped:(UIButton *)b { if (b != _offer.artButton || _offer.previewState != RCImagePreviewOffer) { RCGalleryHUD(self.view, RCL(@"The app would retry the download")); return; } _offer.previewState = RCImagePreviewLoading; [self performSelector:@selector(previewLoaded) withObject:nil afterDelay:1.5]; }
- (void)openShownImage:(UIButton *)sender { (void)sender; [self presentViewController:[RCImageViewerController navigationControllerWithImage:[RCTheme appIconImage:57] caption:RCL(@"Image") delegate:nil] animated:YES completion:nil]; }
- (void)previewLoaded { _offer.image = [RCTheme appIconImage:57]; _offer.previewState = RCImagePreviewShown; }
// Footer buttons are removed on the next run-loop turn, never inside their own action.
- (void)settle:(RCTaskPartView *)t { t.footerButtons = nil; [self relayout]; }
- (void)approve:(UIButton *)b { RCTaskPartView *t = (RCTaskPartView *)b.superview; t.subtitle = RCL(@"Allowed — event created"); [self performSelector:@selector(settle:) withObject:t afterDelay:0]; RCGalleryHUD(self.view, RCL(@"Event created")); }
- (void)deny:(UIButton *)b { RCTaskPartView *t = (RCTaskPartView *)b.superview; t.subtitle = RCL(@"Denied — nothing changed"); [self performSelector:@selector(settle:) withObject:t afterDelay:0]; }
- (void)fileTap {
    if (_file.state == RCFileReady) { _file.progress = 0; _file.state = RCFileDownloading; [self relayout]; }
    else if (_file.state == RCFileSaved) RCGalleryAlert(RCL(@"Open in…"), RCL(@"System “Open in” menu with iPhone apps."));
}
@end

#pragma mark - Empty chat

@interface RCGalleryEmptyPage () { RCEmptyChatView *_live; }
@end

@implementation RCGalleryEmptyPage
- (void)dealloc { [_live release]; [super dealloc]; }

- (void)build {
    [self addCaption:RCGalleryOn(8) ? RCL(@"New chat (toggle — stage 8)") : RCL(@"New chat")];
    [_live release];
    _live = [[RCEmptyChatView alloc] initWithFrame:CGRectZero];
    _live.showsTemporaryToggle = RCGalleryOn(8);
    [_live.temporarySwitch addTarget:self action:@selector(toggled) forControlEvents:UIControlEventValueChanged];
    [self addView:_live];
    [self addCaption:RCL(@"In project")];
    RCEmptyChatView *p = [[[RCEmptyChatView alloc] initWithFrame:CGRectZero] autorelease];
    p.message = RCL(@"New chat in project “Vacation”. Its files and instructions are included.");
    [self addView:p];
}

- (void)toggled {
    BOOL t = _live.temporarySwitch.on;
    _live.temporary = t;
    _live.title = t ? RCL(@"Temporary chat") : RCL(@"What can I help with?");
    _live.message = t ? RCL(@"This chat won’t be saved to history or memory. A copy may be kept on servers for up to 30 days.") : RCL(@"Ask anything. The answer appears as it is written.");
    [self relayout];
}
@end

#pragma mark - HUD and progress

@interface RCGalleryHUDPage () { RCProgressView *_live; NSTimer *_timer; }
@end

@implementation RCGalleryHUDPage
- (void)dealloc { [_timer invalidate]; [_live release]; [super dealloc]; }
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [_timer invalidate]; _timer = nil; }

- (UIView *)bar:(RCProgressTint)tint progress:(CGFloat)p indeterminate:(BOOL)ind height:(CGFloat)h {
    UIView *wrap = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, h + 14)] autorelease];
    RCProgressView *v = [[[RCProgressView alloc] initWithFrame:CGRectMake(20, 4, 280, h)] autorelease];
    v.tint = tint; v.progress = p; v.indeterminate = ind;
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [wrap addSubview:v];
    return wrap;
}

- (void)build {
    [self addCaption:@"RCHUD"];
    struct { NSString *t; SEL s; } b[] = {{RCL(@"“Copied”"), @selector(hudDone)}, {RCL(@"Busy → done"), @selector(hudBusy)}, {RCL(@"Text only"), @selector(hudText)}};
    for (int i = 0; i < 3; i++) {
        RCButton *btn = [RCButton buttonWithStyle:(i == 0 ? RCButtonStyleLargeGreen : RCButtonStyleLarge) title:b[i].t];
        [btn addTarget:self action:b[i].s forControlEvents:UIControlEventTouchUpInside];
        [self addInsetView:btn height:44];
        [self addSpace:10];
    }
    [self addCaption:@"RCProgressView"];
    [self addView:[self bar:RCProgressGreen progress:.3 indeterminate:NO height:9] height:23];
    [self addView:[self bar:RCProgressAmber progress:.7 indeterminate:NO height:9] height:23];
    [self addView:[self bar:RCProgressGreen progress:0 indeterminate:YES height:9] height:23];
    UIView *w = [self bar:RCProgressGreen progress:0 indeterminate:NO height:9];
    [_live release]; _live = [[w.subviews lastObject] retain];
    [self addView:w height:23];
    [self addView:[self bar:RCProgressGreen progress:.5 indeterminate:NO height:6] height:20];
    [self addNote:RCL(@"Green and amber, barber-pole for indeterminate, live bar fills in 3 s. 6 pt is the size in the attachment tray.")];
    [_timer invalidate];
    _timer = [NSTimer scheduledTimerWithTimeInterval:.35 target:self selector:@selector(tick) userInfo:nil repeats:YES];
}

- (void)tick { [_live setProgress:(_live.progress >= 1 ? 0 : _live.progress + .12) animated:_live.progress < 1]; }
- (void)open { [self hudBusy]; } // route open=1: capture a HUD without touch
- (void)hudDone { [RCHUD showText:RCL(@"Copied") kind:RCHUDDone inView:self.view.window seconds:0]; }
- (void)hudText { [RCHUD showText:RCL(@"Voice unavailable offline") kind:RCHUDTextOnly inView:self.view.window seconds:1.6]; }
- (void)hudBusy {
    RCHUD *h = [RCHUD showText:RCL(@"Saving…") kind:RCHUDBusy inView:self.view.window seconds:0];
    [h performSelector:@selector(finishWithText:) withObject:RCL(@"PDF saved") afterDelay:1.5];
}
@end
