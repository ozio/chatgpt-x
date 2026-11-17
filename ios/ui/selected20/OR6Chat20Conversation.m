#import "OR6Chat20Conversation.h"
#import "../priority6/OR6Chat6Base.h"
#import "RCPlaybackView.h"
#import "RCAnswerCardView.h"
#import "RCHUD.h"
@interface OR6Chat20Conversation () <OR6Chat8ModelDelegate, RCReadAloudBarDelegate> {
    RCReadAloudBar *_bar; OR6APICore *_core; id<OR6Chat7ConversationHost> _host; OR6Chat7Call *_call;
    NSString *_message, *_asset; NSDictionary *_audio; NSError *_failure; NSTimer *_timer; NSUInteger _life; BOOL _resync;
}
@end
// Read aloud failures with their own advice: a too-long answer is not retried (it would fail again).
static NSString *OR6Chat20ReadAloudErrorText(NSError *e) {
    NSString *code = e.userInfo[@"code"];
    if ([code isEqual:@"size_limit"]) return OR6L(@"This answer is too long to read aloud (over 3 minutes).");
    if ([code isEqual:@"timeout"]) return OR6L(@"The voice took too long to prepare. Try again later.");
    return OR6Chat7ErrorText(e);
}
static BOOL gPlaybackHold;
void OR6Chat20SetPlaybackHold(BOOL hold) { gPlaybackHold = hold; }
// Posted by the playback device after a lock-screen/headset play or pause (OR6API7GPlaybackDidChangeNotification).
static NSString *const kPlaybackChanged = @"OR6API7GPlaybackDidChangeNotification";
@implementation OR6Chat20Conversation
- (id)initWithCore:(OR6APICore *)core host:(id<OR6Chat7ConversationHost>)host {
    if ((self = [super init])) { _core = [core retain]; _host = host; _call = [[OR6Chat7Call alloc] initWithCore:core]; _call.delegate = self; _bar = [[RCReadAloudBar alloc] initWithFrame:CGRectZero]; _bar.delegate = self; [_bar setPresented:NO animated:NO];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(playbackChanged:) name:kPlaybackChanged object:nil]; } return self;
}
- (void)say:(NSString *)text { UIViewController *p = [_host chat7Presenter]; OR6Chat6Say(p.view.window ?: p.view, text); }
- (void)addPlusItems:(NSMutableArray *)items actions:(NSMutableArray *)actions {
    for (NSArray *entry in @[@[@"suggestions", @"compose.suggestions", OR6L(@"Conversation starters"), @"compose", @(RCTileGreen)],
                            @[@"autocomplete", @"compose.autocomplete.get", OR6L(@"Complete my draft"), @"compose", @(RCTileTeal)],
                            @[@"prediction", @"compose.workPrediction.get", OR6L(@"Suggested next request"), @"bag", @(RCTilePurple)],
                            @[@"skills", @"skills.list", OR6L(@"Skills"), @"book", @(RCTileOrange)]]) {
        if (!OR6Chat7Callable(_core, entry[1])) continue;
        NSString *text = [_host chat7Composer].text;
        if ([entry[0] isEqual:@"autocomplete"] && (!text.length || text.length > 512)) continue;
        if ([entry[0] isEqual:@"prediction"] && ![_host chat7ConversationId]) continue;
        [items addObject:[RCActivityItem itemWithTitle:entry[2] glyph:entry[3] tile:(RCTileColor)[entry[4] integerValue]]];
        [actions addObject:[@"twenty:" stringByAppendingString:entry[0]]];
    }
}
- (BOOL)handlePlusAction:(NSString *)action {
    if (![action hasPrefix:@"twenty:"]) return NO;
    if (![_host chat7Idle]) return YES;
    UIViewController *c = OR6Chat20ComposeScreen(_core, [action substringFromIndex:7], _host);
    if (c) [[_host chat7Presenter].navigationController pushViewController:c animated:YES]; return YES;
}
- (BOOL)isSpeakingRow:(NSDictionary *)r { return [r[@"id"] isEqual:_message] && [_audio[@"state"] isEqual:@"playing"]; }
- (BOOL)canReadRow:(NSDictionary *)r {
    return OR6Chat7Callable(_core, @"audio.readAloud") && [_host chat7ConversationId] &&
           [r[@"id"] isKindOfClass:NSString.class] && ![r[@"id"] hasPrefix:@"local-"] && ![r[@"id"] hasPrefix:@"tool-"] &&
           [r[@"text"] length] && [r[@"state"] integerValue] == RCAnswerDone;
}
- (void)copyMarkdownRow:(NSDictionary *)r {
    if (![r[@"text"] isKindOfClass:NSString.class] || !OR6Chat7Callable(_core, @"chat.copyMarkdown")) return;
    NSUInteger life = _life, gen = OR6Chat7Generation(_core);
    [_core perform:@"chat.copyMarkdown" parameters:@{@"markdown":r[@"text"]} event:nil completion:^(NSDictionary *v, NSError *e) {
        if (!_host || life != _life || gen != OR6Chat7Generation(_core)) return;
        if (e) [self say:OR6Chat7ErrorText(e)]; else if ([v[@"markdown"] isKindOfClass:NSString.class]) { UIPasteboard.generalPasteboard.string = v[@"markdown"]; [self say:OR6L(@"Copied")]; }
    }];
}
- (BOOL)performMore:(NSString *)title row:(NSDictionary *)r {
    if (![title isEqual:OR6L(@"Read aloud")]) return NO;
    if (![self canReadRow:r] || ![_host chat7Idle] || _call.busy) return YES;
    if ([r[@"id"] isEqual:_message] && _asset && !_failure) {
        NSString *state = _audio[@"state"];
        NSString *op = [state isEqual:@"playing"] ? @"playback.pause" : [state isEqual:@"paused"] ? @"playback.resume" : @"playback.start";
        [_call perform:op parameters:[op isEqual:@"playback.start"] ? @{@"assetId":_asset} : @{}]; return YES;
    }
    if ([r[@"id"] isEqual:_message] && [_failure.userInfo[@"code"] isEqual:@"size_limit"]) { [self say:OR6Chat20ReadAloudErrorText(_failure)]; return YES; } // same answer, same limit: no new request
    [self stopPlayback]; [_message release]; _message = [r[@"id"] copy]; [_asset release]; _asset = nil; [_audio release]; _audio = nil; [_failure release]; _failure = nil;
    [_call perform:@"audio.readAloud" parameters:@{@"conversationId":[_host chat7ConversationId], @"messageId":_message}]; [_host chat7Render]; return YES;
}
- (void)chat8ModelChanged:(id)m {
    (void)m; if (!_host || (_call.busy && [_call.operation isEqual:@"playback.status"])) return;
    if (!_call.busy && _call.error && [_call.operation isEqual:@"playback.status"] && _asset) { [_host chat7Render]; return; } // passive read (e.g. before the session is bound again): keep the last state, retry on the next tick
    if (!_call.busy) {
        if ([_call.operation isEqual:@"playback.status"]) _resync = NO;
        [_failure release]; _failure = [_call.error retain];
        if (!_call.error) {
            NSDictionary *r = _call.result, *s = [r[@"playback"] isKindOfClass:NSDictionary.class] ? r[@"playback"] : r;
            if ([_call.operation isEqual:@"audio.readAloud"] && [r[@"assetId"] isKindOfClass:NSString.class]) { [_asset release]; _asset = [r[@"assetId"] copy]; }
            if (_asset && ![s[@"assetId"] isEqual:_asset]) { NSMutableDictionary *stopped = [[_audio mutableCopy] autorelease] ?: [NSMutableDictionary dictionary]; stopped[@"state"] = @"stopped"; [_audio release]; _audio = [stopped copy]; }
            else { [_audio release]; _audio = [s copy]; }
        }
        [_timer invalidate]; [_timer release]; _timer = nil;
        if ([_audio[@"state"] isEqual:@"playing"] && !_failure) _timer = [[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(tick) userInfo:nil repeats:YES] retain];
    }
    [_host chat7Render];
}
- (void)tick { if (!_call.busy) [_call perform:@"playback.status" parameters:@{}]; }
- (void)startStatusTimer { if (!_timer) _timer = [[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(tick) userInfo:nil repeats:YES] retain]; }
- (void)playbackChanged:(NSNotification *)n { (void)n; if (!_asset || !_host) return; _resync = YES; [self startStatusTimer]; [self tick]; }
- (NSString *)answerRevisionForRow:(NSDictionary *)r {
    return [r[@"id"] isEqual:_message] ? [NSString stringWithFormat:@"%@|%@|%@|%d", _audio ?: @{}, _failure.userInfo[@"code"] ?: @"", _asset ?: @"", _call.busy] : nil;
}
- (RCReadAloudBar *)readAloudBar {
    [_bar setPresented:_message != nil animated:YES]; // the host slides its content with it
    if (_resync && _asset && !_timer) [self startStatusTimer]; // back from the background: read the player state again
    NSString *s = _audio[@"state"]; _bar.state = _failure ? RCPlaybackFailed : [s isEqual:@"playing"] ? RCPlaybackPlaying : [s isEqual:@"paused"] ? RCPlaybackPaused : [s isEqual:@"stopped"] ? RCPlaybackStopped : RCPlaybackIdle;
    _bar.position = [_audio[@"position"] doubleValue]; _bar.duration = [_audio[@"duration"] doubleValue]; _bar.rate = [_audio[@"rate"] doubleValue] ?: 1;
    _bar.failureText = _failure ? OR6Chat20ReadAloudErrorText(_failure) : nil; _bar.busy = _call.busy; _bar.rateAvailable = OR6Chat7Callable(_core, @"playback.rate"); return _bar;
}
- (void)play:(NSString *)op parameters:(NSDictionary *)p { if (!_call.busy && [_host chat7Idle]) [_call perform:op parameters:p]; }
- (void)readAloudBarDidTapPlay:(RCReadAloudBar *)v { (void)v; [self play:[_audio[@"state"] isEqual:@"paused"] ? @"playback.resume" : @"playback.start" parameters:[_audio[@"state"] isEqual:@"paused"] ? @{} : @{@"assetId":_asset ?: @""}]; }
- (void)readAloudBarDidTapPause:(RCReadAloudBar *)v { (void)v; [self play:@"playback.pause" parameters:@{}]; }
- (void)readAloudBarDidClose:(RCReadAloudBar *)v { (void)v; [self prepareForBackground]; [_host chat7Render]; }
- (void)readAloudBarDidTapRetry:(RCReadAloudBar *)v { (void)v; if (_asset) [self play:@"playback.retry" parameters:@{}]; else if (_message && [_host chat7ConversationId] && [_host chat7Idle]) {
        if (OR6Chat8StopSignal(_failure.userInfo[@"code"]) || [_failure.userInfo[@"code"] isEqual:@"size_limit"]) { [self say:OR6Chat20ReadAloudErrorText(_failure)]; return; }
        [_failure release]; _failure=nil; [_call perform:@"audio.readAloud" parameters:@{@"conversationId":[_host chat7ConversationId],@"messageId":_message}];
    } }
- (void)readAloudBar:(RCReadAloudBar *)v didChooseRate:(double)rate { (void)v; [self play:@"playback.rate" parameters:@{@"rate":@(rate)}]; }
- (void)readAloudBarDidChangeHeight:(RCReadAloudBar *)v { (void)v; [[_host chat7Presenter].view setNeedsLayout]; }
- (void)stopPlayback {
    [_timer invalidate]; [_timer release]; _timer = nil;
    if (_asset && OR6Chat7Callable(_core, @"playback.stop")) [_core perform:@"playback.stop" parameters:@{} event:nil completion:nil];
    if (_audio) { NSMutableDictionary *s = [[_audio mutableCopy] autorelease]; s[@"state"] = @"stopped"; [_audio release]; _audio = [s copy]; }
}
- (void)prepareForBackground {
    NSString *s = _audio[@"state"];
    if (gPlaybackHold && _message && _asset && !_failure && ([s isEqual:@"playing"] || [s isEqual:@"paused"])) {
        _life++; [_call cancel]; [_timer invalidate]; [_timer release]; _timer = nil; _resync = YES; return; // keeps playing in the background
    }
    _resync = NO; _life++; [_call cancel]; [self stopPlayback]; [_message release]; _message = nil; [_asset release]; _asset = nil; [_audio release]; _audio = nil; [_failure release]; _failure = nil; }
- (void)detach { [NSNotificationCenter.defaultCenter removeObserver:self name:kPlaybackChanged object:nil]; BOOL hold = gPlaybackHold; gPlaybackHold = NO; [self prepareForBackground]; gPlaybackHold = hold; _bar.delegate = nil; _call.delegate = nil; _host = nil; }
- (void)dealloc { [self detach]; [_bar release]; [_call release]; [_core release]; [_message release]; [_asset release]; [_audio release]; [_failure release]; [super dealloc]; }
@end
