// API 8/10 additions to the composer and dictation row (docs/ui-kit.md, «API 8/10
// kit additions»): Отмена while recognising (cancelsRecognition), the caller's
// failure note (failureText), tray item taps (composerView:didTapAttachmentAtIndex:)
// with the item's VoiceOver status (RCComposerAttachment.detail).
// Route: chatgptxkit://page/Priority8 (stage 8+; earlier stages show the note only).
#import "RCGalleryDemos.h"
#import "RCComposerView.h"
#import "RCTheme.h"

@interface RCGalleryPriority8Page : RCGalleryPage <RCComposerViewDelegate> { NSMutableArray *_composers; }
@end

@implementation RCGalleryPriority8Page
- (void)dealloc { for (RCComposerView *c in _composers) c.delegate = nil; [_composers release]; [super dealloc]; }

- (RCComposerView *)composer {
    RCComposerView *c = [[[RCComposerView alloc] initWithFrame:CGRectMake(0, 0, 320, 46)] autorelease];
    c.showsPlus = YES; c.showsMic = YES; c.stopAvailable = YES; c.delegate = self;
    if (!_composers) _composers = [[NSMutableArray alloc] init];
    [_composers addObject:c];
    return c;
}

- (void)build {
    for (RCComposerView *c in _composers) c.delegate = nil;
    [_composers removeAllObjects];
    if (!RCGalleryOn(8)) { [self addNote:RCL(@"These states appear from stage 8 (dictation cancel/retry, attachments).")]; [self addSpace:20]; return; }

    [self addCaption:RCL(@"Recognizing… with “Cancel” (cancelsRecognition)")];
    RCComposerView *recognising = [self composer];
    recognising.dictating = YES; recognising.dictationView.cancelAvailable = YES; recognising.dictationView.cancelsRecognition = YES;
    recognising.dictationView.state = RCDictationRecognising;
    [recognising.dictationView.cancelButton addTarget:self action:@selector(cancelTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self addView:recognising];
    [self addNote:RCL(@"“Cancel” stops the app's recognition and deletes the recording; “Done” is hidden until the result.")];

    [self addCaption:RCL(@"Failure with the caller's explanation (failureText)")];
    RCComposerView *unknown = [self composer];
    unknown.dictating = YES; unknown.dictationView.cancelAvailable = YES; unknown.dictationView.state = RCDictationFailed;
    unknown.dictationView.failureText = RCL(@"The result is unknown. It is not retried, so the recording is not uploaded twice.");
    unknown.dictationView.doneButton.enabled = NO;
    [self addView:unknown];
    RCComposerView *plain = [self composer];
    plain.dictating = YES; plain.dictationView.cancelAvailable = YES; plain.dictationView.state = RCDictationFailed;
    [self addView:plain];
    [self addNote:RCL(@"Without failureText: the kit's standard line and an active “Retry”.")];

    [self addCaption:RCL(@"Tapping an attachment (didTapAttachmentAtIndex, detail)")];
    RCComposerView *tray = [self composer];
    RCComposerAttachment *ready = [RCComposerAttachment attachmentWithTitle:RCL(@"Report.pdf") glyph:@"file" image:nil];
    ready.detail = RCL(@"Ready to send · 820 KB");
    RCComposerAttachment *uploading = [RCComposerAttachment attachmentWithTitle:RCL(@"Photo.jpg") glyph:@"photo" image:nil];
    uploading.progress = .4; uploading.detail = RCL(@"Uploading · 40%");
    RCComposerAttachment *unknownUpload = [RCComposerAttachment attachmentWithTitle:RCL(@"Scan.png") glyph:@"photo" image:nil];
    unknownUpload.failed = YES; unknownUpload.detail = RCL(@"The upload result is unknown. It is not retried automatically.");
    tray.attachments = [NSArray arrayWithObjects:ready, uploading, unknownUpload, nil];
    tray.trayNote = RCL(@"Tap a file for its status, retry or replace. ✕ removes the file from the message.");
    tray.text = RCL(@"What is in these files?");
    [self addView:tray];
    [self addSpace:20];
}

- (void)cancelTapped:(UIButton *)b { RCGalleryHUD(b, RCL(@"Recognition cancelled, recording deleted")); }
- (void)composerView:(RCComposerView *)view didTapAttachmentAtIndex:(NSUInteger)index {
    RCComposerAttachment *a = index < view.attachments.count ? [view.attachments objectAtIndex:index] : nil;
    RCGalleryAlert(a.title ? a.title : @"", a.detail ? a.detail : @"");
}
- (void)composerView:(RCComposerView *)view didRemoveAttachmentAtIndex:(NSUInteger)index {
    NSMutableArray *a = [[view.attachments mutableCopy] autorelease];
    if (index < a.count) [a removeObjectAtIndex:index];
    view.attachments = a;
}
- (void)composerView:(RCComposerView *)view didChangeHeight:(CGFloat)height { (void)view; (void)height; if (self.isViewLoaded) [self relayout]; }
@end

// RCChecklistViewController (model picker: family / mode / thinking effort). Taps
// simulate the app: the list turns busy, then the check moves. Route:
// chatgptxkit://page/Checklist (stage 8+); open=3 holds the busy state, open=4 shows a
// flat one-section list without headers.
#import "RCChecklistViewController.h"

@interface RCGalleryChecklistPage : RCChecklistViewController <RCChecklistDelegate> { NSUInteger _family, _mode, _effort; BOOL _isDefault, _flat; }
@end

@implementation RCGalleryChecklistPage
- (id)init {
    if ((self = [super init])) {
        self.delegate = self; _isDefault = YES; _effort = 0;
        self.busyAccessibilityLabel = RCL(@"Choosing…");
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stageChanged:) name:RCGalleryStageDidChangeNotification object:nil];
        [self bind];
    }
    return self;
}
- (void)dealloc { [NSObject cancelPreviousPerformRequestsWithTarget:self]; [[NSNotificationCenter defaultCenter] removeObserver:self]; self.delegate = nil; [super dealloc]; }
- (void)stageChanged:(NSNotification *)n { (void)n; [self bind]; }
- (NSArray *)families { return [NSArray arrayWithObjects:RCL(@"Family A"), RCL(@"Family B"), nil]; }
- (NSArray *)modes { return [NSArray arrayWithObjects:RCL(@"Instant"), RCL(@"Thinking"), RCL(@"Pro"), nil]; }
- (NSArray *)efforts { return [NSArray arrayWithObjects:RCL(@"Medium"), RCL(@"High"), RCL(@"Extra High"), nil]; }
- (RCChecklistSection *)section:(NSString *)title titles:(NSArray *)titles checked:(NSInteger)checked {
    NSMutableArray *rows = [NSMutableArray array];
    for (NSUInteger i = 0; i < titles.count; i++) [rows addObject:[RCChecklistRow rowWithTitle:[titles objectAtIndex:i] detail:nil checked:(NSInteger)i == checked]];
    return [RCChecklistSection sectionWithTitle:title rows:rows];
}
- (void)bind {
    if (!RCGalleryOn(8)) {
        self.sections = [NSArray array];
        self.footerText = RCL(@"Model choice appears from stage 8.");
        return;
    }
    self.footerText = RCL(@"“Default” uses the account’s default model and the service’s default thinking effort.");
    if (_flat) { self.sections = [NSArray arrayWithObject:[self section:nil titles:[self families] checked:(NSInteger)_family]]; return; }
    NSMutableArray *s = [NSMutableArray array];
    NSString *def = [NSString stringWithFormat:@"%@ · %@", [[self families] objectAtIndex:0], [[self modes] objectAtIndex:0]];
    [s addObject:[RCChecklistSection sectionWithTitle:nil rows:[NSArray arrayWithObject:[RCChecklistRow rowWithTitle:RCL(@"Default") detail:def checked:_isDefault]]]];
    [s addObject:[self section:RCL(@"Model family") titles:[self families] checked:_isDefault ? -1 : (NSInteger)_family]];
    [s addObject:[self section:RCL(@"Mode") titles:[self modes] checked:_isDefault ? -1 : (NSInteger)_mode]];
    if (!_isDefault && _mode == 1) {
        RCChecklistSection *e = [self section:RCL(@"Thinking effort") titles:[[NSArray arrayWithObject:RCL(@"Default")] arrayByAddingObjectsFromArray:[self efforts]] checked:(NSInteger)_effort];
        [(RCChecklistRow *)[e.rows objectAtIndex:0] setDetail:[[self efforts] objectAtIndex:0]];
        [s addObject:e];
    }
    self.sections = s;
}
- (void)checklist:(RCChecklistViewController *)list didSelectRow:(NSUInteger)row inSection:(NSUInteger)section {
    (void)list;
    if (_flat) { _family = row; [self bind]; return; }
    if (section == 0) _isDefault = YES;
    else if (section == 1) { _isDefault = NO; _family = row; }
    else if (section == 2) { _isDefault = NO; if (row != _mode) _effort = 0; _mode = row; } // another mode: effort back to its default
    else _effort = row;
    self.busy = YES; // the app's models.select runs; the check moves when it is confirmed
    [self performSelector:@selector(applied) withObject:nil afterDelay:.8];
}
- (void)applied { self.busy = NO; [self bind]; }
- (void)openVariant:(NSNumber *)variant {
    if ([variant intValue] == 3) { _isDefault = NO; _mode = 1; _effort = 2; [self bind]; self.busy = YES; }
    else if ([variant intValue] == 4) { _flat = YES; [self bind]; }
}
@end
