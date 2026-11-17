#import "OR6Chat7Conversation.h"
#import "../../localization/OR6Localization.h"
#import "../../chat/OR6ChatUIState.h"
#import "../../chat/OR6ChatScreens.h"
#import "../priority8/OR6Chat8Screens.h"
#import "RCFormViewController.h"
#import "RCAnswerCardView.h"
#import "RCImagePartView.h"
#import "RCImageViewerController.h"
#import "RCTaskPartView.h"
#import "RCClarifyPartView.h"
#import "RCPlaybackView.h"
#import "RCMarkdownView.h"
#import "RCTheme.h"
#import "RCHUD.h"
#import "RCButton.h"
#import "RCUserMessageView.h"

static NSArray *(^gExportResolver)(NSString *);
void OR6Chat7SetExportResolver(NSArray *(^r)(NSString *)) { [gExportResolver release]; gExportResolver = [r copy]; }
BOOL OR6Chat7RouteURL(NSURL *u) { return [@[@"chatgpt", @"openai", @"com.openai.chat", @"codex"] containsObject:u.scheme.lowercaseString ?: @""]; }
// routes.resolve only (local parser), then in-app navigation; compose text goes into the field,
// never sent, and an existing draft is never replaced (the navigator decides).
BOOL OR6Chat7HandleRoute(OR6APICore *core, NSURL *url, id<OR6Chat7Navigator> nav, void (^home)(void)) {
    if (!OR6Chat7RouteURL(url) || !OR6Chat7On(core, @"routes.resolve") || url.absoluteString.length > 4096) return NO;
    [core perform:@"routes.resolve" parameters:@{@"url": url.absoluteString} event:nil completion:^(NSDictionary *r, NSError *e) {
        if (e) { [RCHUD showText:OR6L(@"This link is not supported by ChatGPT X.") kind:RCHUDTextOnly inView:UIApplication.sharedApplication.keyWindow seconds:1.8]; return; }
        NSString *d = r[@"destination"];
        if ([d isEqual:@"conversation"] && [r[@"conversationId"] isKindOfClass:NSString.class]) [nav chat7RouteToConversation:r[@"conversationId"]]; // keeps an unsent draft
        else if ([d isEqual:@"project"] && [r[@"projectId"] isKindOfClass:NSString.class]) [nav chat7OpenProject:r[@"projectId"]];
        else if ([d isEqual:@"compose"] && [r[@"text"] isKindOfClass:NSString.class]) [nav chat7ComposeText:r[@"text"]];
        else if ([d isEqual:@"home"] && home) home();
    }];
    return YES;
}

static NSDictionary *Tools(void) {
    return @{@"research": @[@"tools.deepResearch", OR6L(@"Deep research"), @"research", @(RCTileOrange), @(RCChipOrange)],
             @"analysis": @[@"tools.dataAnalysis", OR6L(@"Data analysis"), @"chart", @(RCTileGreen), @(RCChipGreen)],
             @"study": @[@"tools.study", OR6L(@"Study"), @"book", @(RCTilePurple), @(RCChipPurple)],
             @"image": @[@"images.create", OR6L(@"Create image"), @"images", @(RCTileBlue), @(RCChipBlue)]};
}
static NSDictionary *gToolTurns;
// iOS 6 has no public Base64 decoder; strict alphabet, padding only at the end (the API already validated the PNG).
static NSData *OR6Chat7Base64(NSString *s) {
    static const char *a = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"; NSData *in = [s dataUsingEncoding:NSASCIIStringEncoding];
    if (!in || in.length % 4) return nil; const unsigned char *b = in.bytes; NSMutableData *out = [NSMutableData dataWithCapacity:in.length / 4 * 3]; unsigned v = 0; int n = 0, pad = 0;
    for (NSUInteger i = 0; i < in.length; i++) { unsigned char c = b[i]; if (c == '=') { if (i + 2 < in.length) return nil; pad++; v <<= 6; } else { const char *f = strchr(a, c); if (!f || !c || pad) return nil; v = (v << 6) | (unsigned)(f - a); } if (++n == 4) { unsigned char t[3] = { (unsigned char)(v >> 16), (unsigned char)(v >> 8), (unsigned char)v }; [out appendBytes:t length:(NSUInteger)(3 - pad)]; v = 0; n = 0; } }
    return out;
} // assistant message ID → {operation, operationId} of this process (analysis results, research status)

#pragma mark - Stack page (kit part views on linen)

@interface OR6Chat7PartsPage : UIViewController { @public UIScrollView *_scroll; NSMutableArray *_views; }
- (void)setViews:(NSArray *)views;
@end
@implementation OR6Chat7PartsPage
- (void)loadView {
    UIView *v = [[[UIView alloc] initWithFrame:UIScreen.mainScreen.applicationFrame] autorelease]; v.backgroundColor = [RCTheme contentBackgroundColor];
    _scroll = [[UIScrollView alloc] initWithFrame:v.bounds]; _scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; [v addSubview:_scroll]; self.view = v;
    for (UIView *p in _views) [_scroll addSubview:p];
}
- (void)setViews:(NSArray *)views { for (UIView *p in _views) [p removeFromSuperview]; [_views release]; _views = [views mutableCopy]; if (self.isViewLoaded) for (UIView *p in _views) [_scroll addSubview:p]; [self.view setNeedsLayout]; }
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews]; CGFloat w = self.view.bounds.size.width - 20, y = 10;
    for (UIView *p in _views) { CGFloat h = [p respondsToSelector:@selector(heightForWidth:)] ? [(id)p heightForWidth:w] : p.frame.size.height; p.frame = CGRectMake(10, y, w, h); y += h + 10; }
    _scroll.contentSize = CGSizeMake(self.view.bounds.size.width, y);
}
- (void)partViewDidChangeHeight:(RCPartView *)p { (void)p; [self.view setNeedsLayout]; }
- (void)dealloc { [_scroll release]; [_views release]; [super dealloc]; }
@end

#pragma mark - Helper

@interface OR6Chat7Conversation () <OR6Chat8ModelDelegate, RCPlaybackViewDelegate, RCClarifyPartViewDelegate, RCFormDelegate, UIActionSheetDelegate, RCImageViewerControllerDelegate> {
    NSDictionary *_pendingViewer, *_viewerInfo; RCImageViewerController *_viewer;
    OR6APICore *_core; id<OR6Chat7ConversationHost> _host; NSString *_toolMode, *_projectId; NSDictionary *_project;
    // running generation (tool / continue / project / respond)
    NSString *_runOp, *_runId, *_runPrompt, *_runText, *_runPhase, *_runStatus, *_runIntent, *_runReconcile, *_runTitle; NSDictionary *_runResult; NSError *_runError; id<OR6APITask> _runTask; NSUInteger _runEpoch; BOOL _runContinue;
    NSDictionary *_sendMode; void (^_sendFinished)(NSString *, NSDictionary *);
    // images, playback, streaming, mail, pending
    NSMutableDictionary *_imageAssets, *_players; OR6Chat7Call *_playback, *_export, *_stream, *_aux; NSTimer *_poll; NSString *_playing, *_streamId; BOOL _streaming;
    NSDictionary *_pendingRow, *_pendingClarify, *_pendingApproval; OR6Chat7PartsPage *_page; NSString *_mailId; RCFormViewController *_mail; NSMutableDictionary *_mailIds;
    NSUInteger _life; OR6Chat7ImageExport *_images; OR6Chat7EditorBinding *_editor; OR6Chat7AssetGate *_gate; OR6Chat7ImagePreview *_preview; NSDictionary *_pendingExport; // _life: background/teardown/owner change drops every late callback
}
@end

@implementation OR6Chat7Conversation
@synthesize projectId = _projectId, project = _project, toolMode = _toolMode, streaming = _streaming, sendMode = _sendMode, sendFinished = _sendFinished;
- (id)initWithCore:(OR6APICore *)core host:(id<OR6Chat7ConversationHost>)host {
    if ((self = [super init])) {
        _core = [core retain]; _host = host; _imageAssets = [NSMutableDictionary new]; _players = [NSMutableDictionary new]; _mailIds = [NSMutableDictionary new];
        _playback = [[OR6Chat7Call alloc] initWithCore:core]; _export = [[OR6Chat7Call alloc] initWithCore:core]; _stream = [[OR6Chat7Call alloc] initWithCore:core]; _aux = [[OR6Chat7Call alloc] initWithCore:core];
        _playback.delegate = _export.delegate = _stream.delegate = _aux.delegate = self;
        _images = [[OR6Chat7ImageExport alloc] initWithCore:core]; _images.delegate = self; _gate = [[OR6Chat7AssetGate alloc] initWithCore:core];
        _preview = [[OR6Chat7ImagePreview alloc] initWithCore:core]; _preview.delegate = self;
    }
    return self;
}
- (UIView *)hud { if (_viewer.isViewLoaded && _viewer.view.window) return _viewer.view; UIViewController *p = [_host chat7Presenter]; return p.view.window ?: p.view; } // the lightbox covers the chat: feedback goes over the image
// Saving from the lightbox: a busy HUD over the image until Photos answers (exportFinished); elsewhere the short note.
- (void)exportStarted:(NSString *)text destination:(NSString *)dest {
    if ([dest isEqual:@"photos"] && _viewer.isViewLoaded && _viewer.view.window) [_viewer showHUDText:text kind:RCHUDBusy seconds:0];
    else [RCHUD showText:text kind:RCHUDTextOnly inView:[self hud] seconds:1.2];
}
- (void)say:(NSString *)t { [_viewer hideHUD]; /* a note ends any save in progress over the image */ [RCHUD showText:t kind:RCHUDTextOnly inView:[self hud] seconds:2]; UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, t); }
- (BOOL)realId:(NSString *)i { return [i isKindOfClass:NSString.class] && i.length && i.length <= 128 && ![i hasPrefix:@"local-"] && ![i hasPrefix:@"tool-"] && ![i isEqual:@"failed-send"]; }

#pragma mark Tools and project chat

- (void)addPlusItems:(NSMutableArray *)items actions:(NSMutableArray *)actions {
    NSDictionary *t = Tools(); BOOL temporary = [[_host chat7DraftRequest][@"temporary"] boolValue];
    for (NSString *k in @[@"research", @"analysis", @"study", @"image"]) {
        NSArray *d = t[k]; if (temporary || _projectId || !OR6Chat7On(_core, d[0])) continue;
        RCActivityItem *i = [RCActivityItem itemWithTitle:d[1] glyph:d[2] tile:(RCTileColor)[d[3] intValue]]; i.on = [_toolMode isEqual:k]; [items addObject:i]; [actions addObject:[@"tool:" stringByAppendingString:k]];
    }
    if (OR6Chat7LibraryAvailable(_core) && OR6Chat7On(_core, @"library.attach") && !temporary) { [items addObject:[RCActivityItem itemWithTitle:OR6L(@"From Library") glyph:@"library" tile:RCTileTeal]]; [actions addObject:@"library"]; }
}
- (void)renderChip {
    NSArray *d = _toolMode ? Tools()[_toolMode] : nil; RCComposerView *c = [_host chat7Composer];
    if (!d && _sendMode) d = @[_sendMode[@"operation"] ?: @"", _sendMode[@"title"] ?: @"", _sendMode[@"glyph"] ?: @"gpt", @(RCTileGray), _sendMode[@"chip"] ?: @(RCChipPurple)];
    [c setModeChipTitle:d[1] glyph:d[2] color:(RCChipColor)[d[4] intValue]];
    [_host chat7Render];
}
- (BOOL)handlePlusAction:(NSString *)a {
    if ([a hasPrefix:@"tool:"]) {
        NSString *k = [a substringFromIndex:5]; NSString *m = [_toolMode isEqual:k] ? nil : k;
        [_toolMode release]; _toolMode = [m copy]; if (m) { [_sendMode release]; _sendMode = nil; } [self renderChip];
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, m ? [NSString stringWithFormat:OR6L(@"%@ is on for the next message"), Tools()[m][1]] : OR6L(@"Tool mode is off"));
        return YES;
    }
    if ([a isEqual:@"library"]) { [[_host chat7Presenter].navigationController pushViewController:OR6Chat7CreateLibrary(_core, [_host chat7Navigator]) animated:YES]; return YES; }
    return NO;
}
- (void)refreshModeChip { if (_toolMode || _sendMode) [self renderChip]; }
- (void)clearToolMode { [_toolMode release]; _toolMode = nil; [_sendMode release]; _sendMode = nil; [self renderChip]; }
- (void)setSendMode:(NSDictionary *)m {
    if (m && (![m[@"operation"] isKindOfClass:NSString.class] || !OR6Chat7Callable(_core, m[@"operation"]))) m = nil;
    if (m == _sendMode || [m isEqual:_sendMode]) return;
    [_sendMode release]; _sendMode = [m copy]; if (m) { [_toolMode release]; _toolMode = nil; } [self renderChip];
}
- (BOOL)wantsSend { return (_toolMode != nil) || (_sendMode != nil) || (_projectId && ![_host chat7ConversationId]); }
- (BOOL)running { return _runTask != nil || [_runPhase isEqual:@"running"]; }
- (void)send {
    NSString *text = [_host chat7Composer].text ?: @""; NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!trimmed.length || text.length > 16000 || [self running] || ![_host chat7Idle]) return;
    NSDictionary *draft = [_host chat7DraftRequest]; NSString *cid = [_host chat7ConversationId];
    NSString *parent = cid ? [_host chat7LastMessageId] : draft[@"parentMessageId"];
    if (![parent isKindOfClass:NSString.class]) { [self say:OR6L(@"This chat is not ready yet. Wait until it is loaded.")]; return; }
    if (_sendMode && !_toolMode) {
        NSString *op = _sendMode[@"operation"]; NSDictionary *(^build)(NSString *) = _sendMode[@"build"];
        NSDictionary *extra = build ? build(text) : @{}; if (!extra || !OR6Chat7Callable(_core, op)) return; // the build block explained a refusal
        NSMutableDictionary *p = [NSMutableDictionary dictionaryWithDictionary:@{@"conversationId": cid ?: (id)NSNull.null, @"parentMessageId": parent, @"modelId": [_host chat7ModelId] ?: @"web-current", @"text": text}];
        [p addEntriesFromDictionary:extra];
        [self run:op parameters:p prompt:text intent:nil]; return;
    }
    if (_projectId && !cid) { [self startProjectChat:text parent:parent]; return; }
    NSString *op = Tools()[_toolMode][0]; if (!op || !OR6Chat7On(_core, op)) return;
    [self run:op parameters:@{@"conversationId": cid ?: (id)NSNull.null, @"parentMessageId": parent, @"modelId": [_host chat7ModelId] ?: @"web-current", @"text": text} prompt:text intent:nil];
}
// projects.newDraft (reads the project, binds the draft) → projects.send (real native generation).
- (void)startProjectChat:(NSString *)text parent:(NSString *)parent {
    if (!OR6Chat7On(_core, @"projects.newDraft") || !OR6Chat7On(_core, @"projects.send")) return;
    NSString *draft = OR6Chat7OperationID(), *model = [_host chat7ModelId] ?: @"web-current";
    [_runPhase release]; _runPhase = [@"running" copy]; [_runPrompt release]; _runPrompt = [text copy]; [_runText release]; _runText = nil; [_host chat7SetDraftText:@""]; [_host chat7Render];
    NSUInteger epoch = ++_runEpoch;
    [_core perform:@"projects.newDraft" parameters:@{@"projectId": _projectId, @"draftId": draft, @"modelId": model, @"parentMessageId": parent} event:nil completion:^(NSDictionary *r, NSError *e) {
        if (epoch != _runEpoch) return;
        if (e || !r) { [self failRun:e restore:YES]; return; }
        [self run:@"projects.send" parameters:@{@"projectId": _projectId, @"draftId": draft, @"modelId": model, @"parentMessageId": parent, @"text": text} prompt:text intent:nil];
    }];
}
- (void)run:(NSString *)op parameters:(NSDictionary *)p prompt:(NSString *)prompt intent:(NSString *)intent {
    if (OR6Chat7IsUnresolved(intent)) { [self say:OR6L(@"The previous attempt has an unknown result. It is not sent again; check the chat first.")]; return; }
    NSMutableDictionary *q = [[p mutableCopy] autorelease]; NSString *operationId = OR6Chat7OperationID(); q[@"operationId"] = operationId;
    [_runOp release]; _runOp = [op copy]; [_runId release]; _runId = [operationId copy]; [_runIntent release]; _runIntent = [intent copy];
    BOOL modeRun = _sendMode && [_sendMode[@"operation"] isEqual:op];
    [_runReconcile release]; _runReconcile = [(modeRun ? _sendMode[@"reconcile"] : [op isEqual:@"projects.send"] ? @"projects.reconcileChat" : @"tools.operation.reconcile") copy];
    [_runTitle release]; _runTitle = [(modeRun ? _sendMode[@"title"] : nil) copy];
    [_runPrompt release]; _runPrompt = [prompt copy]; [_runText release]; _runText = nil; [_runStatus release]; _runStatus = nil; [_runResult release]; _runResult = nil; [_runError release]; _runError = nil;
    [_runPhase release]; _runPhase = [@"running" copy]; _runContinue = [op isEqual:@"chat.continue"];
    if (prompt) [_host chat7SetDraftText:@""]; // the field clears like Send; a proven refusal puts it back
    NSUInteger epoch = ++_runEpoch; __block BOOL finished = NO;
    id<OR6APITask> t = [_core perform:op parameters:q event:^(NSDictionary *ev) {
        if (epoch != _runEpoch) return; NSDictionary *pl = [ev[@"payload"] isKindOfClass:NSDictionary.class] ? ev[@"payload"] : nil;
        if ([ev[@"name"] isEqual:@"message"] && [pl[@"text"] isKindOfClass:NSString.class]) { [_runText release]; _runText = [pl[@"text"] copy]; }
        else if ([ev[@"name"] isEqual:@"status"]) { [_runStatus release]; _runStatus = [OR6Chat8StatusTitle(pl[@"phase"]) copy]; }
        [_host chat7Render];
    } completion:^(NSDictionary *r, NSError *e) { finished = YES; if (epoch != _runEpoch) return; [_runTask release]; _runTask = nil; [self finishRun:r error:e]; }];
    if (!finished && epoch == _runEpoch) _runTask = [t retain];
    [_host chat7Render];
}
- (void)failRun:(NSError *)e restore:(BOOL)restore {
    [_runError release]; _runError = [e retain]; [_runPhase release]; _runPhase = [@"failed" copy];
    if (restore && _runPrompt.length && ![[_host chat7Composer].text length]) [_host chat7SetDraftText:_runPrompt]; // proven not sent: the text returns to the field
    [self say:e ? OR6Chat7ErrorText(e) : OR6L(@"The request was not sent.")];
    [_runPrompt release]; _runPrompt = nil; [_host chat7Render];
}
- (void)finishRun:(NSDictionary *)r error:(NSError *)e {
    NSString *state = r[@"state"];
    if (e) {
        BOOL none = [e.userInfo[@"dispatch"] isEqual:@"none"] && ![e.userInfo[@"code"] isEqual:@"cancelled"];
        if (none) { [self failRun:e restore:YES]; return; }
        OR6Chat7MarkUnresolved(_runIntent ?: _runId);
        [_runError release]; _runError = [e retain]; [_runPhase release]; _runPhase = [@"uncertain" copy];
        [self say:OR6L(@"The result is unknown. It is not sent again; tap Check.")]; [_host chat7Render]; return;
    }
    [_runResult release]; _runResult = [r copy];
    if (_sendMode && [_sendMode[@"operation"] isEqual:_runOp] && [state isEqual:@"completed"] && _sendFinished) _sendFinished(_runOp, r);
    if (r[@"assistantMessageId"] != nil && [r[@"assistantMessageId"] isKindOfClass:NSString.class] && ([_runOp isEqual:@"tools.dataAnalysis"] || [_runOp isEqual:@"tools.deepResearch"])) {
        NSMutableDictionary *m = [[gToolTurns mutableCopy] autorelease] ?: [NSMutableDictionary dictionary]; m[r[@"assistantMessageId"]] = @{@"operation": _runOp, @"operationId": _runId}; [gToolTurns release]; gToolTurns = [m copy];
    }
    [_runPhase release]; _runPhase = [([state isEqual:@"background"] ? @"background" : [state isEqual:@"uncertain"] ? @"uncertain" : [state isEqual:@"completed"] ? @"completed" : @"failed") copy];
    if ([state isEqual:@"completed"] || [r[@"state"] isEqual:@"completed"]) {
        if ([_runOp isEqual:@"images.create"] && ![r[@"images"] count]) [self say:OR6L(@"No image was created. The answer explains why.")];
        NSString *cid = r[@"conversationId"], *mine = [_host chat7ConversationId];
        [self clearRun];
        if (_toolMode || (_sendMode && ![_sendMode[@"sticky"] boolValue])) [self clearToolMode];
        if ([cid isKindOfClass:NSString.class] && ![cid isEqual:mine]) [_host chat7OpenConversation:cid]; else [_host chat7Reload];
        return;
    }
    if ([state isEqual:@"uncertain"]) OR6Chat7MarkUnresolved(_runIntent ?: _runId);
    [_host chat7Render];
}
- (void)clearRun { _runEpoch++; [_runTask cancel]; [_runTask release]; _runTask = nil; [_runPhase release]; _runPhase = nil; [_runPrompt release]; _runPrompt = nil; [_runText release]; _runText = nil; [_runStatus release]; _runStatus = nil; }
- (BOOL)stop {
    if (!_runTask) return NO;
    // A cancelled generation may already be running on the service: uncertain, never resent.
    _runEpoch++; [_runTask cancel]; [_runTask release]; _runTask = nil; OR6Chat7MarkUnresolved(_runIntent ?: _runId);
    [_runPhase release]; _runPhase = [@"uncertain" copy]; [_host chat7Render]; return YES;
}
- (NSArray *)rows {
    if (!_runPhase) return @[];
    NSMutableArray *rows = [NSMutableArray array];
    if (_runPrompt.length && !_runContinue) [rows addObject:@{@"kind": @"user", @"id": @"tool-user", @"text": _runPrompt, @"delivery": @([_runPhase isEqual:@"running"] ? RCDeliverySending : RCDeliverySent), @"meta": (_runOp ? _runTitle ?: Tools()[_toolMode ?: @""][1] ?: OR6L(@"Project chat") : @"")}];
    NSMutableDictionary *a = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"answer", @"kind", @"tool-answer", @"id", (_runText ?: @""), @"text", nil];
    if ([_runPhase isEqual:@"running"]) { a[@"state"] = @(_runText.length ? RCAnswerStreaming : RCAnswerThinking); if (_runStatus) a[@"reasoning"] = _runStatus; }
    else if ([_runPhase isEqual:@"background"]) { a[@"state"] = @(RCAnswerDone); a[@"tool7"] = @"background"; }
    else { a[@"state"] = @(RCAnswerCut); a[@"note"] = [_runPhase isEqual:@"uncertain"] ? OR6L(@"The result is unknown. It is not sent again.") : (_runError ? OR6Chat7ErrorText(_runError) : OR6L(@"The answer is incomplete")); }
    [rows addObject:a];
    return rows;
}

#pragma mark Answer rows: continue, images, audio, task card

- (BOOL)continueAvailable:(NSDictionary *)r last:(BOOL)last {
    return last && [r[@"state"] isEqual:@(RCAnswerCut)] && [self realId:r[@"id"]] && [_host chat7ConversationId] && ![self running] && OR6Chat7On(_core, @"chat.continue");
}
- (BOOL)continueRow:(NSDictionary *)r {
    NSString *cid = [_host chat7ConversationId]; if (![self realId:r[@"id"]] || !cid || [self running] || !OR6Chat7On(_core, @"chat.continue") || ![_host chat7Idle]) return NO;
    [self run:@"chat.continue" parameters:@{@"conversationId": cid, @"assistantMessageId": r[@"id"], @"modelId": [_host chat7ModelId] ?: @"web-current"} prompt:nil intent:[@"continue:" stringByAppendingString:r[@"id"]]];
    return YES;
}
- (BOOL)imagesAvailable { return OR6Chat7On(_core, @"images.export") && OR6Chat8Supports(_core, OR6Chat8FDownload) && [_host chat7ConversationId]; }
- (BOOL)wav:(NSDictionary *)f { NSString *m = [f[@"mediaType"] isKindOfClass:NSString.class] ? [f[@"mediaType"] lowercaseString] : @"", *n = [f[@"name"] isKindOfClass:NSString.class] ? [f[@"name"] lowercaseString] : @""; return [m isEqual:@"audio/wav"] || [m isEqual:@"audio/x-wav"] || [n hasSuffix:@".wav"]; }
- (void)configureAnswerRow:(NSDictionary *)r card:(id)card parts:(NSMutableArray *)parts isLast:(BOOL)last { [self configureAnswerRow:r card:card parts:parts isLast:last measuring:NO]; }
// Measuring builds throwaway kit views of the same size: a persistent player is never added to the
// measuring card (that would reparent it out of the live cell), and nothing is registered or cached.
- (void)configureAnswerRow:(NSDictionary *)r card:(id)card parts:(NSMutableArray *)parts isLast:(BOOL)last measuring:(BOOL)measuring {
    RCAnswerCardView *c = card;
    if ([self continueAvailable:r last:last]) c.continueAvailable = YES;
    if ([r[@"tool7"] isEqual:@"background"]) {
        RCTaskPartView *t = [[[RCTaskPartView alloc] initWithGlyph:@"research" tile:RCTileOrange] autorelease];
        t.title = OR6L(@"Deep research"); t.subtitle = OR6L(@"Running on the service. Check the status yourself; it is not polled automatically."); t.progress = -1;
        NSMutableArray *pills = [NSMutableArray array];
        if (OR6Chat7On(_core, @"tools.deepResearch.status")) { RCButton *b = [RCButton buttonWithStyle:RCButtonStylePillGo title:OR6L(@"Check status")]; [b addTarget:self action:@selector(researchStatus) forControlEvents:UIControlEventTouchUpInside]; [b sizeToFit]; b.accessibilityIdentifier = @"chat.research.status"; [pills addObject:b]; }
        if (OR6Chat7On(_core, @"tools.deepResearch.cancel")) { RCButton *b = [RCButton buttonWithStyle:RCButtonStylePillRed title:OR6L(@"Stop")]; [b addTarget:self action:@selector(researchStop) forControlEvents:UIControlEventTouchUpInside]; [b sizeToFit]; b.accessibilityIdentifier = @"chat.research.stop"; [pills addObject:b]; }
        t.footerButtons = pills; [parts addObject:t];
    }
    // Images: shown automatically (one download into the private vault, queued and started outside the
    // render, then a cached thumbnail); Save (Photos) / Send (system share) reuse that validated asset.
    if ([self imagesAvailable] && [self realId:r[@"id"]] && [r[@"images"] count]) {
        for (NSUInteger k = 0; k < parts.count; k++) if ([parts[k] isKindOfClass:NSClassFromString(@"RCPartPlaceholderView")] && [[parts[k] accessibilityLabel] rangeOfString:OR6L(@"Image")].location != NSNotFound) { [parts removeObjectAtIndex:k]; k--; }
        NSString *cid = [_host chat7ConversationId];
        for (NSDictionary *img in r[@"images"]) {
            RCImagePartView *v = [[[RCImagePartView alloc] initWithFrame:CGRectMake(0, 0, 280, 280)] autorelease]; v.actionsEnabled = NO; v.viewerAvailable = OR6Chat7Callable(_core, @"images.gallery.prepare"); v.accessibilityLabel = OR6L(@"Image");
            if (measuring) { [parts addObject:v]; continue; } // fixed height: no tag, target, asset entry or cache read
            NSString *file = [img[@"fileId"] isKindOfClass:NSString.class] ? img[@"fileId"] : @"";
            NSDictionary *info = @{@"fileId": file, @"messageId": r[@"id"], @"conversationId": cid, @"caption":r[@"imageCaption"] ?: r[@"text"] ?: OR6L(@"Image")};
            [self showPreviewIn:v file:file message:r[@"id"] conversation:cid];
            v.saveButton.accessibilityIdentifier = @"chat.image.save"; v.sendButton.accessibilityIdentifier = @"chat.image.share"; v.artButton.accessibilityIdentifier = @"chat.image.preview";
            [v.artButton addTarget:self action:@selector(imagePreview:) forControlEvents:UIControlEventTouchUpInside];
            v.artButton.tag = (NSInteger)[_imageAssets count] + 1000; _imageAssets[@(v.artButton.tag)] = info; [parts addObject:v];
        }
    }
    // Saved WAV answer files: local player (playback.*), one at a time.
    if (OR6Chat7On(_core, @"playback.start")) {
        NSArray *files = r[@"files"], *downloads = r[@"downloads"];
        for (NSUInteger k = 0; k < files.count && k < downloads.count; k++) {
            NSDictionary *d = downloads[k]; if (![d[@"state"] isEqual:@"saved"] || ![d[@"assetId"] isKindOfClass:NSString.class] || ![self wav:files[k]]) continue;
            RCPlaybackView *p = _players[d[@"assetId"]];
            if (measuring) { // a detached copy of what the live player shows (its height depends on state)
                RCPlaybackView *m = [[[RCPlaybackView alloc] initWithFrame:CGRectMake(0, 0, 280, 100)] autorelease];
                m.title = p ? p.title : files[k][@"name"]; m.rateAvailable = OR6Chat7On(_core, @"playback.rate");
                if (p) { m.state = p.state; m.position = p.position; m.duration = p.duration; m.rate = p.rate; m.failureText = p.failureText; m.busy = p.busy; }
                [parts addObject:m]; continue;
            }
            if (!p) { p = [[[RCPlaybackView alloc] initWithFrame:CGRectMake(0, 0, 280, 100)] autorelease]; p.title = files[k][@"name"]; p.delegate = self; p.rateAvailable = OR6Chat7On(_core, @"playback.rate"); p.accessibilityIdentifier = @"chat.playback"; _players[d[@"assetId"]] = p; }
            [parts addObject:p];
        }
    }
}
- (NSString *)assetForPlayer:(RCPlaybackView *)v { for (NSString *k in _players) if (_players[k] == v) return k; return nil; }

#pragma mark Image preview and export

// The cached thumbnail (current owner/generation) at once, else the honest state. An offer-state
// image is only queued here with a probe of this part (no request inside the render): the preview
// model starts one on-screen image per later run-loop turn and its change re-renders the row.
// Failed, unknown and unavailable images are never started automatically.
- (void)showPreviewIn:(RCImagePartView *)v file:(NSString *)file message:(NSString *)msg conversation:(NSString *)cid {
    if (!OR6Chat7ImagePreviewAvailable()) { v.previewState = RCImagePreviewUnavailable; return; }
    CGImageRef cg = [_preview imageForFile:file message:msg conversation:cid];
    if (cg) { v.image = [UIImage imageWithCGImage:cg scale:2 orientation:UIImageOrientationUp]; v.previewState = RCImagePreviewShown; return; }
    // Gone once the part leaves its window (cell reuse, card rebuilt, screen closed); on screen when it
    // intersects the window. The block keeps the part only while the image is queued.
    NSString *s = [_preview autoShowFile:file message:msg conversation:cid visibility:^NSInteger{
        UIWindow *w = v.window; if (!w) return -1;
        return !v.hidden && CGRectIntersectsRect([v convertRect:v.bounds toView:nil], w.bounds) ? 1 : 0;
    }];
    v.previewState = [s isEqual:@"loading"] ? RCImagePreviewLoading : [s isEqual:@"failed"] ? RCImagePreviewFailed : [s isEqual:@"unknown"] ? RCImagePreviewUnknown : [s isEqual:@"unavailable"] ? RCImagePreviewUnavailable : RCImagePreviewOffer;
}
// The host puts this into the row: a preview change (loading, shown, failed, evicted) changes exactly
// the rows whose images it shows, so the host's row diff reconfigures only those (their height is
// fixed). Pure reads like -showPreviewIn:: no request, no cache change; nil without live image parts.
- (NSString *)imagePreviewRevisionForRow:(NSDictionary *)r {
    if (![r[@"images"] count] || ![self realId:r[@"id"]] || ![self imagesAvailable]) return nil;
    if (!OR6Chat7ImagePreviewAvailable()) return @"unavailable";
    NSString *cid = [_host chat7ConversationId]; NSMutableString *s = [NSMutableString string];
    for (NSDictionary *img in r[@"images"]) { NSString *file = [img[@"fileId"] isKindOfClass:NSString.class] ? img[@"fileId"] : @""; [s appendString:[_preview imageForFile:file message:r[@"id"] conversation:cid] ? @"shown" : [_preview stateForFile:file message:r[@"id"] conversation:cid]]; [s appendString:@"|"]; }
    return s;
}
// The tapped card's own binding, and only while this screen still shows that conversation.
- (NSDictionary *)imageInfo:(UIButton *)b { NSDictionary *info = _imageAssets[@(b.tag)]; return _host && info && [info[@"conversationId"] isEqual:[_host chat7ConversationId]] ? info : nil; }
- (void)showViewerForInfo:(NSDictionary *)info {
    if (_viewer || !_host || ![info[@"conversationId"] isEqual:[_host chat7ConversationId]]) return;
    NSString *asset = [_preview assetForFile:info[@"fileId"] message:info[@"messageId"] conversation:info[@"conversationId"]];
    CGImageRef cg = [_preview imageForFile:info[@"fileId"] message:info[@"messageId"] conversation:info[@"conversationId"]];
    if (!asset || !cg || !OR6Chat7Callable(_core, @"images.gallery.prepare")) return;
    UIImage *image = [UIImage imageWithCGImage:cg scale:1 orientation:UIImageOrientationUp]; NSUInteger life = _life, gen = OR6Chat7Generation(_core);
    [_core perform:@"images.gallery.prepare" parameters:@{@"assetId":asset} event:nil completion:^(NSDictionary *r, NSError *e) {
        if (life != _life || gen != OR6Chat7Generation(_core) || !_host || _viewer) return;
        if (e || ![r[@"available"] isEqual:@YES]) { [self say:e ? OR6Chat7ErrorText(e) : OR6L(@"The image is no longer available.")]; return; }
        [_viewerInfo release]; _viewerInfo = [info copy];
        _viewer = [[RCImageViewerController alloc] initWithImage:image caption:[info[@"caption"] length] ? info[@"caption"] : OR6L(@"Image")]; _viewer.delegate = self;
        _viewer.saveAvailable = _viewer.shareAvailable = OR6Chat7Callable(_core, @"images.export"); _viewer.editAvailable = NO;
        _viewer.view.accessibilityIdentifier = @"chat.images.gallery";
        UINavigationController *nav = [[[UINavigationController alloc] initWithRootViewController:_viewer] autorelease];
        [[_host chat7Presenter] presentViewController:nav animated:YES completion:nil];
    }];
}
- (void)imagePreview:(UIButton *)b {
    NSDictionary *info = [self imageInfo:b]; if (!info || _viewer) return;
    [_pendingViewer release]; _pendingViewer = [info copy];
    if ([_preview showFile:info[@"fileId"] message:info[@"messageId"] conversation:info[@"conversationId"]]) {
        if (_pendingViewer && !_preview.busy) [self previewChanged]; [_host chat7Render]; return;
    }
    [_pendingViewer release]; _pendingViewer = nil;
    [self say:[_preview.refusal isEqual:@"unresolved"] ? OR6L(@"The image download has an unknown result. It is not repeated.") : OR6L(@"Wait until the image is ready.")];
}
- (void)imageViewerDidTapSave:(RCImageViewerController *)v { if (v == _viewer) [self imageExportInfo:_viewerInfo destination:@"photos"]; }
- (void)imageViewerDidTapShare:(RCImageViewerController *)v { if (v == _viewer) [self imageExportInfo:_viewerInfo destination:@"share"]; }
- (void)imageViewerDidFinish:(RCImageViewerController *)v {
    if (v != _viewer) return; v.delegate = nil; [[_host chat7Presenter] dismissViewControllerAnimated:YES completion:nil];
    [_viewer release]; _viewer = nil; [_viewerInfo release]; _viewerInfo = nil;
}
- (void)imageExport:(UIButton *)b destination:(NSString *)dest { [self imageExportInfo:[self imageInfo:b] destination:dest]; }
- (BOOL)canExportImagesForRow:(NSDictionary *)r {
    return [self imagesAvailable] && [self realId:r[@"id"]] && [r[@"images"] count] > 0;
}
- (void)exportImagesForRow:(NSDictionary *)r destination:(NSString *)destination {
    if (![self canExportImagesForRow:r] || ![@[@"photos", @"share"] containsObject:destination]) return;
    NSString *cid = [_host chat7ConversationId]; NSMutableArray *images = [NSMutableArray array], *titles = [NSMutableArray array];
    for (NSDictionary *image in r[@"images"]) if ([image[@"fileId"] isKindOfClass:NSString.class] && [image[@"fileId"] length]) {
        [images addObject:@{@"fileId":image[@"fileId"], @"messageId":r[@"id"], @"conversationId":cid}];
        [titles addObject:[NSString stringWithFormat:OR6L(@"Image %lu"), (unsigned long)images.count]];
    }
    if (images.count == 1) { [self imageExportInfo:images[0] destination:destination]; return; }
    if (!images.count) return;
    NSUInteger life = _life, generation = OR6Chat7Generation(_core);
    OR6Chat8ShowSheet([self hud], OR6L(@"Choose image"), titles, nil, ^(NSInteger index, NSString *title) {
        (void)title; if (life != _life || generation != OR6Chat7Generation(_core) || index < 0 || (NSUInteger)index >= images.count) return;
        [self imageExportInfo:images[(NSUInteger)index] destination:destination];
    });
}
- (void)imageExportInfo:(NSDictionary *)info destination:(NSString *)dest {
    NSString *cid = info[@"conversationId"]; if (!info || ![cid isEqual:[_host chat7ConversationId]]) return;
    // The validated preview asset: no second download (exportAsset revalidates it first).
    NSString *asset = [_preview assetForFile:info[@"fileId"] message:info[@"messageId"] conversation:cid];
    if (asset) { if ([_images exportAsset:asset key:info[@"fileId"] destination:dest]) { [self exportStarted:([dest isEqual:@"photos"] ? OR6L(@"Saving to Photos…") : OR6L(@"Preparing…")) destination:dest]; return; } }
    else if (OR6Chat7ImagePreviewAvailable() && !_images.busy && !_pendingExport) {
        // Not on this iPhone yet: the one download of the preview, then this export of its asset.
        _pendingExport = [@{@"info": info, @"destination": dest} copy]; // before the call: a synchronous reply already finds it
        if ([_preview showFile:info[@"fileId"] message:info[@"messageId"] conversation:cid]) {
            if (_pendingExport && !_preview.busy) [self previewChanged]; // nothing left to wait for
            else if (_pendingExport) [self exportStarted:OR6L(@"Downloading the image to this iPhone…") destination:dest];
            [_host chat7Render]; return;
        }
        [_pendingExport release]; _pendingExport = nil;
        NSString *why = _preview.refusal;
        [self say:[why isEqual:@"busy"] ? OR6L(@"Wait until the image is ready.") : [why isEqual:@"unresolved"] ? OR6L(@"The image download has an unknown result. It is not repeated.") : OR6L(@"The image could not be prepared for sharing.")]; return;
    }
    else if (_pendingExport) { [self say:OR6L(@"Wait until the image is ready.")]; return; }
    else if ([_images exportFile:info[@"fileId"] message:info[@"messageId"] conversation:cid destination:dest]) {
        [self exportStarted:(_images.busy && [_images.phase isEqual:@"downloading"] ? OR6L(@"Downloading the image to this iPhone…") : [dest isEqual:@"photos"] ? OR6L(@"Saving to Photos…") : OR6L(@"Preparing…")) destination:dest];
        return;
    }
    NSString *why = _images.refusal;
    [self say:[why isEqual:@"busy"] ? OR6L(@"Wait until the image is ready.") : [why isEqual:@"unresolved"] ? ([dest isEqual:@"photos"] ? OR6L(@"The photo may already be saved. It is not saved again; check Photos.") : OR6L(@"The image download has an unknown result. It is not repeated.")) : OR6L(@"The image could not be prepared for sharing.")];
}
- (void)imageSave:(UIButton *)b { [self imageExport:b destination:@"photos"]; }
- (void)imageShare:(UIButton *)b { [self imageExport:b destination:@"share"]; }
// The preview's download finished: a Save/Send that waited for it exports the validated asset
// once; a failed or unknown download is reported, never repeated.
- (void)previewChanged {
    if (_pendingViewer && !_preview.busy) {
        NSDictionary *info = [[_pendingViewer retain] autorelease]; [_pendingViewer release]; _pendingViewer = nil;
        if ([_preview imageForFile:info[@"fileId"] message:info[@"messageId"] conversation:info[@"conversationId"]]) [self showViewerForInfo:info];
        else if (_preview.error) [self say:OR6Chat7ErrorText(_preview.error)];
    }
    NSDictionary *pending = [[_pendingExport retain] autorelease], *info = pending[@"info"];
    if (pending) {
        NSString *asset = [_preview assetForFile:info[@"fileId"] message:info[@"messageId"] conversation:info[@"conversationId"]];
        if (asset || !_preview.busy) { [_pendingExport release]; _pendingExport = nil; }
        if (asset && [info[@"conversationId"] isEqual:[_host chat7ConversationId]]) {
            if (![_images exportAsset:asset key:info[@"fileId"] destination:pending[@"destination"]]) [self say:[_images.refusal isEqual:@"unresolved"] ? OR6L(@"The photo may already be saved. It is not saved again; check Photos.") : OR6L(@"The image could not be prepared for sharing.")];
        } else if (!asset && !_preview.busy) [self say:[[_preview stateForFile:info[@"fileId"] message:info[@"messageId"] conversation:info[@"conversationId"]] isEqual:@"unknown"] ? OR6L(@"The image download has an unknown result. It is not repeated.") : _preview.error ? OR6Chat7ErrorText(_preview.error) : OR6L(@"The image could not be prepared for sharing.")];
    }
    [_host chat7Render];
}
- (void)exportFinished {
    NSString *p = _images.phase;
    if (_images.busy || [p isEqual:@"idle"]) return;
    if ([p isEqual:@"saved"] && _viewer.isViewLoaded && _viewer.view.window) { [_viewer finishHUDWithText:OR6L(@"Saved to Photos.")]; return; }
    [_viewer hideHUD];
    if ([p isEqual:@"shared"]) { // one-use token → validated vault URLs → the system sheet (completed stays false)
        NSArray *urls = gExportResolver && _images.token ? gExportResolver(_images.token) : nil;
        if (!urls.count) { [self say:OR6L(@"The image could not be prepared for sharing.")]; return; }
        [(_viewer ?: [_host chat7Presenter]) presentViewController:[[[UIActivityViewController alloc] initWithActivityItems:urls applicationActivities:nil] autorelease] animated:YES completion:nil]; return;
    }
    if ([p isEqual:@"saved"]) { [RCHUD showText:OR6L(@"Saved to Photos.") kind:RCHUDDone inView:[self hud] seconds:0]; return; }
    if ([p isEqual:@"uncertain"]) { [self say:OR6L(@"The photo may already be saved. It is not saved again; check Photos.")]; return; }
    [self say:_images.error ? OR6Chat7ErrorText(_images.error) : OR6L(@"Photos did not confirm the save.")];
}

#pragma mark Playback (local, audio focus)

- (void)playback:(NSString *)op params:(NSDictionary *)p { if (![_playback perform:op parameters:p]) [self say:OR6L(@"Playback is not available.")]; }
- (void)playbackViewDidTapPlay:(RCPlaybackView *)v {
    NSString *asset = [self assetForPlayer:v]; if (!asset) return;
    if (_streaming || ![_host chat7Idle]) { [self say:OR6L(@"Finish dictation before listening.")]; return; }
    if ([_playing isEqual:asset] && v.state == RCPlaybackPaused) [self playback:@"playback.resume" params:@{}];
    else {
        // The saved file is revalidated for this owner first (G rebinds it after a deactivate); a late reply is dropped.
        NSUInteger life = _life; [_playing release]; _playing = [asset copy];
        if (![_gate revalidate:asset completion:^(NSDictionary *s, NSError *e) { (void)s; if (life != _life || !_host) return; if (e) { v.state = RCPlaybackFailed; v.failureText = OR6Chat7ErrorText(e); return; } [self playback:@"playback.start" params:@{@"assetId": asset}]; }]) [self say:OR6L(@"Playback is not available.")];
    }
}
- (void)playbackViewDidTapPause:(RCPlaybackView *)v { (void)v; [self playback:@"playback.pause" params:@{}]; }
- (void)playbackViewDidTapStop:(RCPlaybackView *)v { (void)v; [self playback:@"playback.stop" params:@{}]; }
- (void)playbackViewDidTapRetry:(RCPlaybackView *)v { (void)v; [self playback:@"playback.retry" params:@{}]; }
- (void)playbackView:(RCPlaybackView *)v didChooseRate:(double)rate { (void)v; [self playback:@"playback.rate" params:@{@"rate": @(rate)}]; }
- (void)applyPlayback:(NSDictionary *)s {
    RCPlaybackView *v = _players[_playing ?: @""]; if (!v || ![s isKindOfClass:NSDictionary.class]) return;
    if (![s[@"assetId"] isEqual:_playing]) { v.state = RCPlaybackStopped; [_poll invalidate]; [_poll release]; _poll = nil; return; }
    NSString *st = s[@"state"]; v.state = [st isEqual:@"playing"] ? RCPlaybackPlaying : [st isEqual:@"paused"] ? RCPlaybackPaused : [st isEqual:@"stopped"] ? RCPlaybackStopped : [st isEqual:@"failed"] ? RCPlaybackFailed : RCPlaybackIdle;
    v.position = [s[@"position"] doubleValue]; v.duration = [s[@"duration"] doubleValue]; v.rate = [s[@"rate"] doubleValue] ?: 1;
    BOOL playing = v.state == RCPlaybackPlaying;
    if (playing && !_poll) _poll = [[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(pollPlayback) userInfo:nil repeats:YES] retain];
    else if (!playing) { [_poll invalidate]; [_poll release]; _poll = nil; }
}
- (void)pollPlayback { if (!_playback.busy) [_playback perform:@"playback.status" parameters:@{}]; } // local player state, no network
- (void)stopPlayback { [_poll invalidate]; [_poll release]; _poll = nil; if (_playing && OR6Chat7Callable(_core, @"playback.stop")) [_playback perform:@"playback.stop" parameters:@{}]; RCPlaybackView *v = _players[_playing ?: @""]; if (v) v.state = RCPlaybackStopped; [_playing release]; _playing = nil; }

#pragma mark Model callbacks

- (void)chat8ModelChanged:(id)m {
    if (!_host) return;
    if (m == _playback && !_playback.busy) { if (_playback.error) { RCPlaybackView *v = _players[_playing ?: @""]; v.state = RCPlaybackFailed; v.failureText = OR6Chat7ErrorText(_playback.error); } else [self applyPlayback:_playback.result]; }
    if (m == _images) [self exportFinished];
    if (m == _preview) [self previewChanged];
    if (m == _stream) [self streamChanged];
    if (m == _aux && !_aux.busy) [self auxFinished];
}

#pragma mark More menu: email, pending questions/approvals, analysis results, research

- (NSArray *)moreTitlesForRow:(NSDictionary *)r isLast:(BOOL)last {
    NSMutableArray *t = [NSMutableArray array];
    if ([r[@"id"] isEqual:@"tool-answer"]) { if ([_runPhase isEqual:@"uncertain"] && _runReconcile && OR6Chat7Callable(_core, _runReconcile)) [t addObject:OR6L(@"Check result")]; return t; }
    if ([self canExportImagesForRow:r]) [t addObject:OR6L(@"Save image to Photos")];
    if (OR6Chat7AllOn(_core, @[@"emailDraft.set", @"emailDraft.prepare"]) && [r[@"text"] length]) [t addObject:OR6L(@"Create e-mail from answer…")];
    BOOL real = [self realId:r[@"id"]] && [_host chat7ConversationId];
    if (last && ([self realId:r[@"pendingMessageId"]] || real) && (([r[@"pendingQuestions"] isEqual:@YES] && OR6Chat7On(_core, @"compose.clarifications.get")) || ([r[@"pendingAction"] isEqual:@YES] && OR6Chat7On(_core, @"tools.actionApproval.get")))) [t addObject:OR6L(@"Questions and actions")];
    NSDictionary *turn = real ? gToolTurns[r[@"id"]] : nil;
    if ([turn[@"operation"] isEqual:@"tools.dataAnalysis"] && OR6Chat7On(_core, @"tools.dataAnalysis.result")) [t addObject:OR6L(@"Analysis results")];
    if ([turn[@"operation"] isEqual:@"tools.deepResearch"] && OR6Chat7On(_core, @"tools.deepResearch.status")) [t addObject:OR6L(@"Research status")];
    return t;
}
- (BOOL)performMore:(NSString *)title row:(NSDictionary *)r {
    if ([title isEqual:OR6L(@"Save image to Photos")]) { [self exportImagesForRow:r destination:@"photos"]; return YES; }
    if ([title isEqual:OR6L(@"Check result")]) { [self reconcileRun]; return YES; }
    if ([title isEqual:OR6L(@"Create e-mail from answer…")]) { [self openMail:r]; return YES; }
    if ([title isEqual:OR6L(@"Questions and actions")]) { [self openPending:r]; return YES; }
    if ([title isEqual:OR6L(@"Analysis results")]) { [_aux perform:@"tools.dataAnalysis.result" parameters:@{@"operationId": gToolTurns[r[@"id"]][@"operationId"]}]; return YES; }
    if ([title isEqual:OR6L(@"Research status")]) { [_aux perform:@"tools.deepResearch.status" parameters:@{@"operationId": gToolTurns[r[@"id"]][@"operationId"]}]; return YES; }
    return NO;
}
- (BOOL)runUncertain { return [_runPhase isEqual:@"uncertain"] && _runId && _runReconcile && OR6Chat7Callable(_core, _runReconcile); }
- (void)reconcileRun { if (_runId && _runReconcile) [_aux perform:_runReconcile parameters:@{@"operationId": _runId}]; }
- (void)researchStatus { NSString *op = _runId; if (op) [_aux perform:@"tools.deepResearch.status" parameters:@{@"operationId": op}]; }
- (void)researchStop {
    UIActionSheet *s = [[[UIActionSheet alloc] initWithTitle:OR6L(@"Ask the service to stop this research? Work already done may stay.") delegate:self cancelButtonTitle:OR6L(@"Cancel") destructiveButtonTitle:OR6L(@"Stop research") otherButtonTitles:nil] autorelease];
    s.tag = 71; [s showInView:[self hud]];
}
- (void)actionSheet:(UIActionSheet *)s clickedButtonAtIndex:(NSInteger)i {
    if (s.tag == 71 && i == s.destructiveButtonIndex && _runId) {
        NSString *key = [@"research-stop:" stringByAppendingString:_runId];
        if (OR6Chat7IsUnresolved(key)) { [self say:OR6L(@"The stop request has an unknown result. It is not sent again.")]; return; }
        NSUInteger life = _life;
        [_core perform:@"tools.deepResearch.cancel" parameters:@{@"operationId": OR6Chat7OperationID(), @"taskOperationId": _runId} event:nil completion:^(NSDictionary *r, NSError *e) {
            if (e && ![e.userInfo[@"dispatch"] isEqual:@"none"]) OR6Chat7MarkUnresolved(key);
            if (life != _life || !_host) return;
            if (e) { [self say:OR6Chat7ErrorText(e)]; return; }
            [self say:[r[@"stopRequested"] isEqual:@YES] ? OR6L(@"The service accepted the stop request. It may take a moment to stop.") : OR6L(@"The research has already finished.")];
        }];
    } else if (s.tag == 72 && i == s.destructiveButtonIndex) [self respondApproval:@"allow"];
}
- (void)auxFinished {
    NSString *op = _aux.operation; NSDictionary *r = _aux.result;
    if (_aux.error) { [self say:OR6Chat7ErrorText(_aux.error)]; return; }
    if ([op isEqual:@"tools.operation.reconcile"] || [op isEqual:@"projects.reconcileChat"] || [op isEqual:_runReconcile]) {
        // API6B/6F mutation receipts say confirmed + resourceId (the conversation); API7 says conversationId.
        BOOL found = [r[@"state"] isEqual:@"completed"] && (r[@"confirmed"] == nil || [r[@"confirmed"] isEqual:@YES]);
        if (found) { NSString *cid = [r[@"conversationId"] isKindOfClass:NSString.class] ? r[@"conversationId"] : r[@"resourceId"]; [self clearRun]; if ([cid isKindOfClass:NSString.class] && ![cid isEqual:[_host chat7ConversationId]]) [_host chat7OpenConversation:cid]; else [_host chat7Reload]; [self say:OR6L(@"The answer was found in the chat.")]; }
        else [self say:OR6L(@"The result is still unknown. Nothing was sent again.")];
        return;
    }
    if ([op isEqual:@"tools.deepResearch.status"]) {
        NSString *s = [r[@"status"] isEqual:@"complete"] ? OR6L(@"Research finished. Open the chat to read the report.") : [r[@"status"] isEqual:@"running"] ? [NSString stringWithFormat:OR6L(@"Still running. You can check again in %@ s."), r[@"nextPollAfterSeconds"]] : [r[@"status"] isEqual:@"failed"] ? OR6L(@"The research failed on the service.") : OR6L(@"The status is not available.");
        [self say:s]; if ([r[@"status"] isEqual:@"complete"]) { NSString *cid = [[_runResult[@"conversationId"] retain] autorelease]; [self clearRun]; if ([cid isKindOfClass:NSString.class] && ![cid isEqual:[_host chat7ConversationId]]) [_host chat7OpenConversation:cid]; else [_host chat7Reload]; } return;
    }
    if ([op isEqual:@"tools.dataAnalysis.result"]) { [self showAnalysis:r]; return; }
    if ([op isEqual:@"compose.clarifications.get"]) { [_pendingClarify release]; _pendingClarify = [r copy]; [self pendingStep]; return; }
    if ([op isEqual:@"tools.actionApproval.get"]) { [_pendingApproval release]; _pendingApproval = [r copy]; [self showPending]; return; }
}

#pragma mark Analysis results (visible executions only; no hidden reasoning)

- (void)showAnalysis:(NSDictionary *)r {
    NSMutableArray *views = [NSMutableArray array];
    RCTaskPartView *head = [[[RCTaskPartView alloc] initWithGlyph:@"chart" tile:RCTileGreen] autorelease]; head.title = OR6L(@"Analysis results"); head.progress = -1;
    head.subtitle = ![r[@"observed"] boolValue] ? OR6L(@"No calculation was observed in this answer. The answer text is all there is.") : [NSString stringWithFormat:OR6L(@"%lu runs · %@"), (unsigned long)[r[@"executions"] count], r[@"state"]];
    [views addObject:head];
    NSUInteger n = 0;
    for (NSDictionary *x in r[@"executions"]) {
        n++; RCCodeBlockView *code = [[[RCCodeBlockView alloc] initWithCode:x[@"code"] ?: @"" language:@"python"] autorelease]; code.copyEnabled = YES; [views addObject:code];
        NSMutableArray *rows = [NSMutableArray array];
        for (NSDictionary *o in x[@"output"]) [rows addObject:[RCTaskRow paramWithKey:o[@"kind"] value:o[@"text"]]];
        RCTaskPartView *out = [[[RCTaskPartView alloc] initWithGlyph:@"text" tile:([x[@"status"] isEqual:@"error"] ? RCTileRed : RCTileGray)] autorelease];
        out.title = [NSString stringWithFormat:OR6L(@"Run %lu"), (unsigned long)n]; out.subtitle = x[@"status"]; out.rows = rows; out.progress = -1; [views addObject:out];
        for (NSDictionary *v in x[@"visualizations"]) {
            RCImagePartView *img = [[[RCImagePartView alloc] initWithFrame:CGRectMake(0, 0, 280, 280)] autorelease]; img.actionsEnabled = NO;
            NSData *png = [v[@"available"] boolValue] && [v[@"data"] isKindOfClass:NSString.class] ? OR6Chat7Base64(v[@"data"]) : nil;
            img.image = png ? [UIImage imageWithData:png] : nil; img.accessibilityLabel = [v[@"title"] isKindOfClass:NSString.class] ? v[@"title"] : OR6L(@"Chart");
            [views addObject:img];
            if (!img.image) { RCTaskPartView *note = [[[RCTaskPartView alloc] initWithGlyph:@"chart" tile:RCTileGray] autorelease]; note.title = img.accessibilityLabel; note.subtitle = OR6L(@"Only the chart's description is available; the picture is not shown here."); note.progress = -1; [views addObject:note]; }
        }
    }
    OR6Chat7PartsPage *page = [[[OR6Chat7PartsPage alloc] init] autorelease]; page.title = OR6L(@"Analysis results"); [page setViews:views];
    [[_host chat7Presenter].navigationController pushViewController:page animated:YES];
}

#pragma mark Pending clarifications and action approvals

- (void)openPending:(NSDictionary *)r {
    [_pendingRow release]; _pendingRow = [r copy]; [_pendingClarify release]; _pendingClarify = nil; [_pendingApproval release]; _pendingApproval = nil;
    NSDictionary *p = @{@"conversationId": [_host chat7ConversationId], @"messageId": r[@"pendingMessageId"] ?: r[@"id"]};
    if ([r[@"pendingQuestions"] isEqual:@YES] && OR6Chat7On(_core, @"compose.clarifications.get")) [_aux perform:@"compose.clarifications.get" parameters:p];
    else [self pendingStep];
}
- (void)pendingStep { // then the approval read (sequential, one Core call at a time)
    if ([_pendingRow[@"pendingAction"] isEqual:@YES] && OR6Chat7On(_core, @"tools.actionApproval.get") && _pendingRow) [_aux perform:@"tools.actionApproval.get" parameters:@{@"conversationId": [_host chat7ConversationId], @"messageId": _pendingRow[@"pendingMessageId"] ?: _pendingRow[@"id"]}];
    else [self showPending];
}
- (void)showPending {
    NSMutableArray *views = [NSMutableArray array]; NSArray *qs = _pendingClarify[@"questions"]; NSDictionary *ap = _pendingApproval;
    BOOL answer = OR6Chat7On(_core, @"compose.clarifications.respond") && [_pendingClarify[@"challengeId"] isKindOfClass:NSString.class];
    if (qs.count && answer) {
        RCClarifyPartView *c = [[[RCClarifyPartView alloc] initWithFrame:CGRectMake(0, 0, 300, 200)] autorelease]; NSMutableArray *qq = [NSMutableArray array];
        for (NSDictionary *q in qs) { NSMutableArray *o = [NSMutableArray array]; for (NSDictionary *x in q[@"options"]) [o addObject:x[@"label"]]; RCClarifyQuestion *cq = [RCClarifyQuestion questionWithText:q[@"question"] options:o multiple:[q[@"multiple"] boolValue]]; cq.requiresAnswer = ![q[@"allowSkip"] boolValue]; cq.ownAnswerHidden = ![q[@"allowFreeText"] boolValue]; [qq addObject:cq]; }
        c.questions = qq; c.delegate = (id)self; [views addObject:c];
    } else if (qs.count) {
        for (NSDictionary *q in qs) { RCTaskPartView *t = [[[RCTaskPartView alloc] initWithGlyph:@"text" tile:RCTileBlue] autorelease]; t.title = q[@"question"]; t.progress = -1; NSMutableArray *rows = [NSMutableArray array];
            for (NSDictionary *x in q[@"options"]) [rows addObject:[RCTaskRow stepWithText:x[@"label"] lamp:RCLampOff]]; t.rows = rows; t.subtitle = OR6L(@"Answering from ChatGPT X is not enabled yet; answer in the web version."); [views addObject:t]; }
    }
    if ([ap[@"challengeId"] isKindOfClass:NSString.class] || [ap[@"title"] length]) {
        RCTaskPartView *t = [[[RCTaskPartView alloc] initWithGlyph:@"shield" tile:RCTilePurple] autorelease]; t.title = ap[@"title"]; t.subtitle = ap[@"description"]; t.progress = -1;
        t.rows = @[[RCTaskRow paramWithKey:OR6L(@"Recipient") value:ap[@"recipient"] ?: @""]];
        if (OR6Chat7On(_core, @"tools.actionApproval.respond") && [ap[@"challengeId"] isKindOfClass:NSString.class]) {
            NSMutableArray *pills = [NSMutableArray array];
            if ([ap[@"canAllow"] boolValue]) { RCButton *b = [RCButton buttonWithStyle:RCButtonStylePillGo title:OR6L(@"Allow")]; [b addTarget:self action:@selector(approvalAllow) forControlEvents:UIControlEventTouchUpInside]; [b sizeToFit]; b.accessibilityIdentifier = @"chat.approval.allow"; [pills addObject:b]; }
            if ([ap[@"canDeny"] boolValue]) { RCButton *b = [RCButton buttonWithStyle:RCButtonStylePillRed title:OR6L(@"Deny")]; [b addTarget:self action:@selector(approvalDeny) forControlEvents:UIControlEventTouchUpInside]; [b sizeToFit]; b.accessibilityIdentifier = @"chat.approval.deny"; [pills addObject:b]; }
            t.footerButtons = pills;
        } else t.subtitle = [NSString stringWithFormat:@"%@ %@", ap[@"description"] ?: @"", OR6L(@"Answering from ChatGPT X is not enabled yet; answer in the web version.")];
        [views addObject:t];
    }
    if (!views.count) { [self say:OR6L(@"This answer does not wait for questions or actions.")]; return; }
    [_page release]; _page = [[OR6Chat7PartsPage alloc] init]; _page.title = OR6L(@"Questions and actions"); [_page setViews:views];
    for (UIView *v in views) if ([v isKindOfClass:RCPartView.class] && ![v isKindOfClass:RCClarifyPartView.class]) ((RCPartView *)v).delegate = (id)_page;
    [[_host chat7Presenter].navigationController pushViewController:_page animated:YES];
}
- (void)clarifyPart:(RCClarifyPartView *)part didFinishWithSelections:(NSArray *)sel {
    (void)part; NSArray *qs = _pendingClarify[@"questions"]; NSMutableArray *answers = [NSMutableArray array];
    for (NSUInteger i = 0; i < qs.count && i < sel.count; i++) {
        NSArray *idx = sel[i][@"options"]; NSArray *opts = qs[i][@"options"]; NSString *own = sel[i][@"text"];
        NSMutableArray *labels = [NSMutableArray array]; for (NSNumber *n in idx) if (n.unsignedIntegerValue < opts.count && labels.count < ([qs[i][@"multiple"] boolValue] ? 20u : 1u)) [labels addObject:opts[n.unsignedIntegerValue][@"label"]];
        [answers addObject:@{@"questionId": qs[i][@"id"], @"selectedOptions": labels, @"freeText": own.length ? own : (id)NSNull.null}];
    }
    [self.class popPage:_page]; NSString *ch = _pendingClarify[@"challengeId"];
    [self run:@"compose.clarifications.respond" parameters:@{@"challengeId": ch, @"answers": answers} prompt:nil intent:[@"clarify:" stringByAppendingString:ch]];
}
- (void)partViewDidChangeHeight:(RCPartView *)p { (void)p; [_page.view setNeedsLayout]; }
+ (void)popPage:(UIViewController *)page { UINavigationController *n = page.navigationController; if (n.topViewController == page) [n popViewControllerAnimated:YES]; }
- (void)approvalAllow {
    UIActionSheet *s = [[[UIActionSheet alloc] initWithTitle:[NSString stringWithFormat:OR6L(@"Allow this action once? %@"), _pendingApproval[@"title"] ?: @""] delegate:self cancelButtonTitle:OR6L(@"Cancel") destructiveButtonTitle:OR6L(@"Allow once") otherButtonTitles:nil] autorelease];
    s.tag = 72; [s showInView:[self hud]];
}
- (void)approvalDeny { [self respondApproval:@"deny"]; }
- (void)respondApproval:(NSString *)action {
    NSString *ch = _pendingApproval[@"challengeId"]; if (![ch isKindOfClass:NSString.class]) return; [self.class popPage:_page];
    [self run:@"tools.actionApproval.respond" parameters:@{@"challengeId": ch, @"action": action} prompt:nil intent:[@"approval:" stringByAppendingString:ch]];
}

#pragma mark E-mail draft (local; Mail opens the prepared mailto, nothing is sent here)

- (void)openMail:(NSDictionary *)r {
    NSString *mid = r[@"id"] ?: @"answer"; NSString *draftId = _mailIds[mid]; BOOL existing = draftId != nil;
    if (!draftId) { draftId = OR6Chat7OperationID(); _mailIds[mid] = draftId; }
    [_mailId release]; _mailId = [draftId copy];
    [_mail release]; _mail = [[RCFormViewController alloc] init]; _mail.title = OR6L(@"E-mail"); _mail.delegate = self;
    [self renderMail:@{@"to": @[], @"cc": @[], @"bcc": @[], @"subject": @"", @"body": [RCMarkdownView readableTextFromMarkdown:r[@"text"] ?: @""]}];
    [[_host chat7Presenter].navigationController pushViewController:_mail animated:YES];
    if (existing && OR6Chat7On(_core, @"emailDraft.get")) [_core perform:@"emailDraft.get" parameters:@{@"id": draftId} event:nil completion:^(NSDictionary *d, NSError *e) { if (!e && [d[@"id"] isEqual:_mailId]) [self renderMail:d]; }];
}
- (RCFormRow *)mailField:(NSString *)key title:(NSString *)t text:(NSString *)v long:(BOOL)l { RCFormRow *r = [RCFormRow rowWithKind:(l ? RCFormRowLongText : RCFormRowText) title:t]; r.text = v; r.placeholder = t; r.userInfo = key; r.identifier = [@"chat.mail." stringByAppendingString:key]; r.maxLength = l ? 32000 : 1000; return r; }
- (void)renderMail:(NSDictionary *)d {
    NSString *(^join)(id) = ^NSString *(id a) { return [a isKindOfClass:NSArray.class] ? [a componentsJoinedByString:@", "] : @""; };
    RCFormSection *h = [RCFormSection sectionWithTitle:nil rows:@[[self mailField:@"to" title:OR6L(@"To") text:join(d[@"to"]) long:NO], [self mailField:@"cc" title:OR6L(@"Cc") text:join(d[@"cc"]) long:NO], [self mailField:@"bcc" title:OR6L(@"Bcc") text:join(d[@"bcc"]) long:NO], [self mailField:@"subject" title:OR6L(@"Subject") text:d[@"subject"] long:NO]]];
    RCFormSection *b = [RCFormSection sectionWithTitle:OR6L(@"Text") rows:@[[self mailField:@"body" title:OR6L(@"Text") text:d[@"body"] long:YES]]];
    RCFormRow *open = [RCFormRow rowWithKind:RCFormRowButton title:OR6L(@"Open in Mail")]; open.userInfo = @"open"; open.identifier = @"chat.mail.open";
    RCFormSection *a = [RCFormSection sectionWithTitle:nil rows:@[open]]; a.footer = OR6L(@"ChatGPT X only prepares the letter. Mail opens it; you check and send it there.");
    _mail.sections = @[h, b, a];
}
- (NSDictionary *)mailDraft {
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithObjectsAndKeys:_mailId, @"id", @"", @"sender", nil];
    NSArray *(^split)(NSString *) = ^NSArray *(NSString *s) { NSMutableArray *a = [NSMutableArray array]; for (NSString *x in [s ?: @"" componentsSeparatedByString:@","]) { NSString *t = [x stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]; if (t.length) [a addObject:t]; } return a; };
    for (RCFormSection *s in _mail.sections) for (RCFormRow *r in s.rows) { NSString *k = r.userInfo; if (![k isKindOfClass:NSString.class]) continue;
        if ([@[@"to", @"cc", @"bcc"] containsObject:k]) d[k] = split(r.text); else if ([@[@"subject", @"body"] containsObject:k]) d[k] = r.text ?: @""; }
    return d;
}
- (void)form:(RCFormViewController *)f didSelectRow:(RCFormRow *)row {
    if (f != _mail || ![row.userInfo isEqual:@"open"]) return; [f endEditing];
    NSString *mid = [[_mailId copy] autorelease];
    NSUInteger life = _life;
    [_core perform:@"emailDraft.set" parameters:[self mailDraft] event:nil completion:^(NSDictionary *d, NSError *e) {
        if (life != _life || !_host) return;
        if (e) { [self say:OR6Chat7ErrorText(e)]; return; } (void)d;
        [_core perform:@"emailDraft.prepare" parameters:@{@"id": mid} event:nil completion:^(NSDictionary *r, NSError *x) {
            if (life != _life || !_host) return; // no Mail handoff after background/teardown
            NSURL *u = [r[@"url"] isKindOfClass:NSString.class] ? [NSURL URLWithString:r[@"url"]] : nil;
            if (x || ![u.scheme.lowercaseString isEqual:@"mailto"] || ![r[@"sent"] isEqual:@NO]) { [self say:x ? OR6Chat7ErrorText(x) : OR6L(@"The letter could not be prepared.")]; return; }
            if (![UIApplication.sharedApplication canOpenURL:u] || ![UIApplication.sharedApplication openURL:u]) { [self say:OR6L(@"Mail is not set up on this iPhone.")]; return; }
            [self say:OR6L(@"Mail opened with the letter. It is sent only from Mail.")];
        }];
    }];
}
- (void)form:(RCFormViewController *)f didChangeTextOfRow:(RCFormRow *)row { (void)f; (void)row; }

#pragma mark Code copy, links, full-screen editor

- (BOOL)shouldKitCopyCode:(RCCodeBlockView *)v row:(NSDictionary *)r {
    if (!OR6Chat7On(_core, @"content.copyCode") || v.blockIndex < 0 || ![r[@"id"] isKindOfClass:NSString.class] || [r[@"id"] length] > 128 || ![r[@"text"] length]) return YES;
    NSString *code = v.code; UIView *hud = [self hud];
    [_core perform:@"content.copyCode" parameters:@{@"messageId": r[@"id"], @"markdown": r[@"text"], @"codeBlockIndex": @(v.blockIndex)} event:nil completion:^(NSDictionary *x, NSError *e) {
        NSString *t = [x[@"text"] isKindOfClass:NSString.class] ? x[@"text"] : nil;
        NSString *(^norm)(NSString *) = ^NSString *(NSString *s) { return [[s stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"] stringByTrimmingCharactersInSet:NSCharacterSet.newlineCharacterSet]; };
        // The API counts blocks itself: if it names a different block, copy what the user tapped.
        [UIPasteboard generalPasteboard].string = (!e && t && [norm(t) isEqual:norm(code)]) ? t : code;
        [RCHUD showText:OR6L(@"Code block copied.") kind:RCHUDDone inView:hud seconds:0];
    }];
    return NO;
}
- (BOOL)handleLink:(NSURL *)url {
    NSString *share = OR6Chat7ShareIdFromURL(url);
    if (share && OR6Chat7SharedViewAvailable(_core)) { [[_host chat7Presenter].navigationController pushViewController:OR6Chat7CreateSharedView(_core, share) animated:YES]; return YES; }
    if (OR6Chat7RouteURL(url)) { id<OR6Chat7Navigator> nav = [_host chat7Navigator]; return OR6Chat7HandleRoute(_core, url, nav, ^{ [nav chat7ShowHome]; }); } // home: back to this chat, draft kept
    return NO;
}
- (BOOL)openEditorFromText:(NSString *)text {
    // The chat's own draft identity, reserved or not: composer.editor.* is local state keyed by it (7G), so
    // editing never needs messages.newDraft (a network model check) first. messages.newDraft reserves the same ID.
    NSString *draft = [_host chat7DraftRequest][@"draftId"];
    if (![draft isKindOfClass:NSString.class] || !OR6Chat7AllOn(_core, @[@"composer.editor.set", @"composer.editor.get"])) return NO;
    RCComposerView *c = [_host chat7Composer]; NSRange sel = c.textView.selectedRange; NSString *t = text ?: @"";
    if (sel.location == NSNotFound || NSMaxRange(sel) > t.length) sel = NSMakeRange(t.length, 0);
    [_editor invalidate]; [_editor release];
    _editor = [[OR6Chat7EditorBinding alloc] initWithCore:_core draftId:draft conversationId:[_host chat7ConversationId] text:t selection:sel];
    OR6Chat7EditorBinding *binding = _editor; // retained by the block: the completion checks this exact binding
    __block OR6ChatTextEditorController *editor = nil;
    editor = [[[OR6ChatTextEditorController alloc] initWithTitle:OR6L(@"Message") text:t completion:^(NSString *done) {
        // A different draft, chat or owner by now (or background/teardown), or the field's text changed while
        // the editor was open: nothing is applied or stored.
        if (!_host || binding != _editor) return;
        if (![([_host chat7Composer].text ?: @"") isEqualToString:t]) { [binding invalidate]; return; }
        if (![binding finishText:(done ?: t) selection:editor.selection currentDraft:[_host chat7DraftRequest][@"draftId"] currentConversation:[_host chat7ConversationId]]) return;
        if (done) { NSRange r = editor.selection; [_host chat7SetDraftText:done]; if (NSMaxRange(r) <= [_host chat7Composer].textView.text.length) [_host chat7Composer].textView.selectedRange = r; }
    }] autorelease];
    editor.selection = sel;
    [binding openRestoring:^(NSRange r) { editor.selection = r; }];
    [[_host chat7Presenter] presentViewController:[[[UINavigationController alloc] initWithRootViewController:editor] autorelease] animated:YES completion:nil];
    return YES;
}

#pragma mark Streaming dictation (only when dictation.streaming is live_verified)

- (BOOL)streamingAvailable { return [OR6Chat7Tier(@"dictation.streaming") isEqual:@"live_verified"] && OR6Chat7On(_core, @"dictation.stream.start"); }
- (void)startStreaming {
    if (_streaming || ![self streamingAvailable]) return;
    [self stopPlayback]; // one audio owner: the player stops before the microphone opens
    [_streamId release]; _streamId = [OR6Chat7OperationID() copy]; _streaming = YES;
    RCComposerView *c = [_host chat7Composer]; c.dictating = YES; c.dictationView.state = RCDictationRecording; c.dictationView.liveText = @""; c.dictationView.cancelAvailable = YES;
    if (![_stream perform:@"dictation.stream.start" parameters:@{@"recordingId": _streamId, @"language": NSNull.null, @"visible": @YES}]) { _streaming = NO; c.dictating = NO; }
    [_host chat7Render];
}
- (void)stopStreaming { NSUInteger life = _life; if (_streaming && _streamId) [_core perform:@"dictation.stream.stop" parameters:@{@"recordingId": _streamId} event:nil completion:^(NSDictionary *r, NSError *e) { (void)r; if (e && life == _life && _host) [self say:OR6Chat7ErrorText(e)]; }]; [_host chat7Composer].dictationView.state = RCDictationRecognising; }
- (void)cancelStreaming {
    if (!_streaming) return; NSString *rid = [[_streamId copy] autorelease]; _streaming = NO; [_stream cancel];
    if (rid) [_core perform:@"dictation.stream.cancel" parameters:@{@"recordingId": rid} event:nil completion:^(NSDictionary *r, NSError *e) { (void)r; (void)e; }];
    [_host chat7Composer].dictating = NO; [_host chat7Render];
}
- (void)streamChanged {
    NSDictionary *t = [_stream.lastEvent[@"payload"] isKindOfClass:NSDictionary.class] ? _stream.lastEvent[@"payload"] : nil; RCComposerView *c = [_host chat7Composer];
    if (_stream.busy) { if (t && [t[@"recordingId"] isEqual:_streamId]) c.dictationView.liveText = t[@"visible"] ? t[@"text"] : nil; return; }
    if (!_streaming) return; _streaming = NO;
    NSDictionary *f = _stream.result; NSString *text = [f[@"text"] isKindOfClass:NSString.class] ? f[@"text"] : nil;
    if (!_stream.error && [f[@"state"] isEqual:@"completed"] && [f[@"final"] isEqual:@YES] && text.length) {
        NSString *cur = c.text ?: @""; NSRange r = c.textView.selectedRange; if (r.location == NSNotFound || NSMaxRange(r) > cur.length) r = NSMakeRange(cur.length, 0);
        c.dictating = NO; [_host chat7SetDraftText:[cur stringByReplacingCharactersInRange:r withString:text]];
        [self say:OR6L(@"Text inserted into the message field. Send it from the chat when you are ready.")];
    } else {
        c.dictationView.state = RCDictationFailed; c.dictationView.failureText = _stream.error ? OR6Chat7ErrorText(_stream.error) : OR6L(@"Nothing was recognised. No text was inserted.");
        c.dictationView.doneButton.enabled = NO;
    }
    [_host chat7Render];
}

#pragma mark Lifecycle

- (void)prepareForBackground {
    // Background cancels local and remote work: a running generation becomes uncertain,
    // streaming stops, polling ends, and the composition's G suspend DISCARDS the player (resetAudio):
    // every playing or paused part shows Stopped and the next Play is a new validated playback.start.
    // Every late callback of the old life is dropped (images, editor, Mail, research stop).
    _life++;
    [_pendingViewer release]; _pendingViewer = nil;
    if (_viewer) { _viewer.delegate = nil; [[_host chat7Presenter] dismissViewControllerAnimated:NO completion:nil]; [_viewer release]; _viewer = nil; }
    [_viewerInfo release]; _viewerInfo = nil;
    [_images invalidate]; [_preview invalidate]; [_editor invalidate]; [_gate invalidate]; // a delayed download/export/preview, status or editor completion of the old life is dropped
    [_pendingExport release]; _pendingExport = nil; // a waiting Save/Send never starts after background
    [self stop]; [self cancelStreaming]; [_poll invalidate]; [_poll release]; _poll = nil;
    [_export cancel]; [_aux cancel]; [_playback cancel];
    for (RCPlaybackView *v in _players.allValues) if (v.state == RCPlaybackPlaying || v.state == RCPlaybackPaused) v.state = RCPlaybackStopped;
    [_playing release]; _playing = nil; // no resume against a discarded player
}
- (void)detach { [self prepareForBackground]; _runEpoch++; _host = nil; [_sendFinished release]; _sendFinished = nil; _images.delegate = nil; _preview.delegate = nil; for (OR6Chat7Call *c in @[_playback, _export, _stream, _aux]) c.delegate = nil; }
- (NSUInteger)playersInWindow { NSUInteger n = 0; for (RCPlaybackView *v in _players.allValues) if (v.window) n++; return n; }
- (NSDictionary *)diagnostics { return @{@"toolMode": _toolMode ?: @"", @"sendMode": _sendMode[@"operation"] ?: @"", @"run": _runPhase ?: @"", @"runOperation": _runOp ?: @"", @"streaming": @(_streaming), @"players": @(_players.count), @"playersInWindow": @([self playersInWindow]), @"project": @(_projectId != nil), @"imagePreview": [_preview diagnostics] ?: @{}}; }
- (void)dealloc {
    _runEpoch++; _life++; [_pendingViewer release]; [_viewerInfo release]; _viewer.delegate=nil; [_viewer release]; _images.delegate = nil; [_images invalidate]; [_images release]; _preview.delegate = nil; [_preview invalidate]; [_preview release]; [_pendingExport release]; [_editor invalidate]; [_editor release]; [_gate invalidate]; [_gate release]; [_runTask cancel]; [_runTask release]; [_poll invalidate]; [_poll release];
    for (OR6Chat7Call *c in @[_playback, _export, _stream, _aux]) { c.delegate = nil; [c cancel]; }
    for (RCPlaybackView *v in _players.allValues) v.delegate = nil;
    [_playback release]; [_export release]; [_stream release]; [_aux release]; [_core release]; [_toolMode release]; [_projectId release]; [_project release];
    [_runOp release]; [_runId release]; [_runPrompt release]; [_runText release]; [_runPhase release]; [_runStatus release]; [_runIntent release]; [_runResult release]; [_runError release];
    [_runReconcile release]; [_runTitle release]; [_sendMode release]; [_sendFinished release];
    [_imageAssets release]; [_players release]; [_playing release]; [_streamId release]; [_pendingRow release]; [_pendingClarify release]; [_pendingApproval release]; [_page release]; [_mailId release]; [_mail release]; [_mailIds release];
    [super dealloc];
}
@end
