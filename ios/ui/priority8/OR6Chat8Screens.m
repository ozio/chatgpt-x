#import "OR6Chat8Screens.h"
#import "../priority7/OR6Chat7ImagePreview.h"
#import "../../chat/OR6ChatScreens.h"
#import "../../chat/OR6ChatUIState.h"
#import "../../localization/OR6Localization.h"
#import "../priority9/OR6Chat9Content.h"
#import "RCComposerView.h"
#import "RCTheme.h"
#import "RCHUD.h"
#import "RCChecklistViewController.h"

#pragma mark - Sheets

// The choice is delivered once, AFTER the sheet is gone (-didDismissWithButtonIndex:). On iOS 6
// a modal presented from -clickedButtonAtIndex: starts while the sheet's own temporary window
// is still key; on the iPhone the presented sheet was lost with that window (an empty jade bar
// over the window's hidden web view). Every delegate stays alive until its own sheet is
// dismissed (UIActionSheet does not retain it), so a second sheet never frees the first one's.
// A sheet dismissed by the system (background) reports its cancel index: no choice.
static NSMutableSet *gOR6Chat8Sheets;
@interface OR6Chat8SheetActions : NSObject <UIActionSheetDelegate> { @public void (^chosen)(NSInteger, NSString *); NSInteger first; BOOL delivered; }
@end
@implementation OR6Chat8SheetActions
- (void)actionSheet:(UIActionSheet *)s didDismissWithButtonIndex:(NSInteger)i {
    if (delivered) return; // exactly once
    delivered = YES; [[self retain] autorelease]; [gOR6Chat8Sheets removeObject:self];
    void (^c)(NSInteger, NSString *) = [[chosen copy] autorelease]; [chosen release]; chosen = nil;
    NSInteger index = (i == s.cancelButtonIndex || i < 0 || i >= s.numberOfButtons) ? -1 : (i == s.destructiveButtonIndex ? -2 : i - first);
    NSString *title = index != -1 ? [s buttonTitleAtIndex:i] : nil;
    s.delegate = nil;
    if (c) c(index, title);
}
- (void)dealloc { [chosen release]; [super dealloc]; }
@end

void OR6Chat8ShowSheet(UIView *view, NSString *title, NSArray *buttons, NSString *destructive, void (^chosen)(NSInteger, NSString *)) {
    if (!view) return;
    if (!gOR6Chat8Sheets) gOR6Chat8Sheets = [NSMutableSet new];
    OR6Chat8SheetActions *current = [[[OR6Chat8SheetActions alloc] init] autorelease];
    current->chosen = [chosen copy];
    [gOR6Chat8Sheets addObject:current]; // kept until its sheet is dismissed
    UIActionSheet *s = [[[UIActionSheet alloc] initWithTitle:title delegate:current cancelButtonTitle:nil destructiveButtonTitle:destructive otherButtonTitles:nil] autorelease];
    current->first = destructive ? 1 : 0;
    for (NSString *b in buttons) [s addButtonWithTitle:b];
    s.cancelButtonIndex = [s addButtonWithTitle:OR6L(@"Cancel")];
    [s showInView:view];
}

void OR6Chat8ChooseSignIn(UIView *view, BOOL email, BOOL google, void (^choose)(NSString *)) {
    NSMutableArray *buttons = [NSMutableArray array], *providers = [NSMutableArray array];
    if (email) { [buttons addObject:OR6L(@"E-mail and password")]; [providers addObject:@"email"]; }
    if (google) { [buttons addObject:OR6L(@"Continue with Google")]; [providers addObject:@"google"]; }
    void (^c)(NSString *) = [[choose copy] autorelease];
    OR6Chat8ShowSheet(view, OR6L(@"The password and a code from your authenticator app are entered only on the service page."), buttons, nil, ^(NSInteger i, NSString *t) {
        (void)t; if (i >= 0 && (NSUInteger)i < providers.count && c) c(providers[(NSUInteger)i]);
    });
}

#pragma mark - Attachments

UIImage *OR6Chat8LocalThumbnail(NSString *identifier) {
 CGImageRef cg=OR6Chat7LocalThumbnail(identifier);if(!cg)return nil;
 UIImage*image=[UIImage imageWithCGImage:cg];CGImageRelease(cg);return image;
}
NSArray *OR6Chat8TrayAttachments(NSArray *items) {
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *i in items) {
        BOOL image = [i[@"image"] boolValue];
        NSString *name = [i[@"name"] length] ? i[@"name"] : (image ? OR6L(@"Image") : OR6L(@"File"));
        RCComposerAttachment *a = [RCComposerAttachment attachmentWithTitle:name glyph:(image ? @"photo" : @"file") image:(image?OR6Chat8LocalThumbnail(i[@"assetId"]):nil)];
        NSString *phase = i[@"phase"];
        a.progress = [@[@"acquiring", @"uploading", @"processing", @"attaching"] containsObject:phase] ? MAX(0.02, MIN(0.98, [i[@"progress"] doubleValue])) : 1;
        a.failed = [@[@"failed", @"uncertain", @"expired", @"unavailable"] containsObject:phase] || ([phase isEqual:@"ready"] && ![i[@"attached"] boolValue]);
        a.detail = OR6Chat8AttachmentStatus(i);
        [out addObject:a];
    }
    return out;
}

NSString *OR6Chat8AttachmentStatus(NSDictionary *i) {
    NSString *phase = i[@"phase"], *size = [i[@"bytes"] unsignedLongLongValue] ? OR6Chat8Bytes([i[@"bytes"] unsignedLongLongValue]) : nil;
    if ([phase isEqual:@"acquiring"]) return OR6L(@"Choosing the file…");
    if ([phase isEqual:@"uploading"]) return [NSString stringWithFormat:OR6L(@"Uploading · %lu%%"), (unsigned long)MIN(99.0, [i[@"progress"] doubleValue] * 100)];
    if ([phase isEqual:@"processing"]) return OR6L(@"The service is processing the file…");
    if ([phase isEqual:@"attaching"]) return OR6L(@"Adding to the message…");
    if ([phase isEqual:@"failed"]) return [NSString stringWithFormat:OR6L(@"Not uploaded: %@"), OR6ChatErrorText(OR6APIError(i[@"issue"] ?: @"unknown", @"none"))];
    if ([phase isEqual:@"uncertain"]) return OR6L(@"The upload result is unknown. It is not repeated automatically: remove the file or replace it with a new copy.");
    if ([phase isEqual:@"expired"]) return OR6L(@"The uploaded file has expired. Replace it with a new copy.");
    if ([phase isEqual:@"unavailable"]) return OR6L(@"The file is no longer available on this iPhone or on the service.");
    if ([phase isEqual:@"ready"] && ![i[@"attached"] boolValue]) return OR6L(@"Uploaded but not added to the message.");
    return size ? [NSString stringWithFormat:OR6L(@"Ready to send · %@"), size] : OR6L(@"Ready to send");
}

NSArray *OR6Chat8BubbleAttachments(NSDictionary *row) {
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *a in row[@"attachments"]) [out addObject:[RCComposerAttachment attachmentWithTitle:([a[@"name"] length] ? a[@"name"] : ([a[@"image"] boolValue] ? OR6L(@"Image") : OR6L(@"File"))) glyph:([a[@"image"] boolValue] ? @"photo" : @"file") image:([a[@"image"]boolValue]?OR6Chat8LocalThumbnail(a[@"assetId"]):nil)]];
    if (out.count) return out;
    for (NSDictionary *i in row[@"images"]) [out addObject:[RCComposerAttachment attachmentWithTitle:OR6L(@"Image") glyph:@"photo" image:OR6Chat8LocalThumbnail(i[@"fileId"])]];
    for (NSDictionary *f in row[@"files"]) [out addObject:[RCComposerAttachment attachmentWithTitle:([f[@"name"] length] ? f[@"name"] : OR6L(@"File")) glyph:@"file" image:nil]];
    return out;
}

RCFilePartView *OR6Chat8FilePart(NSDictionary *file, NSDictionary *download) {
    RCFilePartView *v = [[[RCFilePartView alloc] initWithFrame:CGRectZero] autorelease];
    NSString *state = download[@"state"];v.thumbnail=OR6Chat8LocalThumbnail(download[@"assetId"]?:file[@"fileId"]);
    unsigned long long bytes = [download[@"bytes"] unsignedLongLongValue] ?: [file[@"bytes"] unsignedLongLongValue];
    v.fileName = [download[@"name"] length] ? download[@"name"] : ([file[@"name"] length] ? file[@"name"] : OR6L(@"File"));
    if ([state isEqual:@"downloading"]) { v.state = RCFileDownloading; v.progress = [download[@"progress"] floatValue]; v.detail = OR6L(@"Downloading…"); }
    else if ([state isEqual:@"saved"]) { v.detail = [NSString stringWithFormat:OR6L(@"%@ · on this iPhone"), OR6Chat8Bytes(bytes)]; v.state = RCFileSaved; v.actionButton.hidden = YES; } // no file URL leaves the vault: nothing to "Open in…"
    else if ([state isEqual:@"unavailable"]) { v.state = RCFileUnavailable; }
    // Unknown outcome or a service stop signal: no second request, the reason is shown.
    else if ([state isEqual:@"uncertain"]) { v.state = RCFileReady; v.detail = OR6L(@"The download result is unknown. It is not repeated."); v.actionButton.hidden = YES; }
    else if ([state isEqual:@"blocked"]) { v.state = RCFileReady; v.detail = OR6ChatErrorText(OR6APIError(download[@"issue"] ?: @"service_challenge", @"none")); v.actionButton.hidden = YES; }
    else { v.state = RCFileReady; v.detail = [state isEqual:@"failed"] ? [NSString stringWithFormat:OR6L(@"Not downloaded: %@"), OR6ChatErrorText(OR6APIError(download[@"issue"] ?: @"unknown", @"none"))] : (bytes ? OR6Chat8Bytes(bytes) : nil); }
    v.isAccessibilityElement = NO;
    v.actionButton.accessibilityLabel = [NSString stringWithFormat:OR6L(@"Download %@"), v.fileName];
    v.actionButton.accessibilityIdentifier = @"chat.file.download";
    return v;
}

#pragma mark - Models

// «Модель» on the kit's RCChecklistViewController: Default, Model family, Mode and Thinking
// effort sections. This class only binds catalog data and callbacks; every tap is one
// models.select of an exact (model, effort) pair and the catalog's notification moves the checks.
static id O8First(NSArray *a) { return a.count ? a[0] : nil; } // -firstObject is not public before iOS 7
// The effort kept when the mode changes: only one the new mode really offers.
static NSString *O8KeptEffort(OR6Chat8Catalog *c, NSDictionary *mode) { return [[mode[@"efforts"] valueForKey:@"id"] containsObject:c.chosenEffort] ? c.chosenEffort : nil; }
static RCChecklistRow *O8Row(NSString *title, NSString *detail, BOOL on, NSString *identifier) {
    RCChecklistRow *r = [RCChecklistRow rowWithTitle:title detail:detail checked:on]; r.identifier = identifier; return r;
}

@interface OR6Chat8ModelPickerController : RCChecklistViewController <RCChecklistDelegate> { OR6Chat8Catalog *_catalog; BOOL (^_allow)(void); NSArray *_actions; NSString *_family; }
- (id)initWithCatalog:(OR6Chat8Catalog *)catalog allow:(BOOL (^)(void))allow;
@end
@implementation OR6Chat8ModelPickerController
- (id)initWithCatalog:(OR6Chat8Catalog *)catalog allow:(BOOL (^)(void))allow {
    if ((self = [super init])) {
        _catalog = [catalog retain]; _allow = [allow copy]; self.delegate = self; self.title = OR6L(@"Model");
        self.footerText = OR6L(@"“Default” uses the account’s default model and the service’s default thinking effort.");
        self.busyAccessibilityLabel = OR6L(@"Choosing the model…");
        NSString *shown = catalog.chosenModelId ?: catalog.catalogDefaultModelId;
        _family = [([catalog familyForModel:shown] ?: O8First(catalog.families))[@"id"] copy];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(catalogChanged:) name:OR6Chat8CatalogDidChangeNotification object:catalog];
        [self bind];
    }
    return self;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; self.delegate = nil; [_catalog release]; [_allow release]; [_actions release]; [_family release]; [super dealloc]; }
- (void)viewDidLoad { [super viewDidLoad]; self.tableView.accessibilityIdentifier = @"chat.models"; }
- (NSDictionary *)shownFamily { for (NSDictionary *f in _catalog.families) if ([f[@"id"] isEqual:_family]) return f; return O8First(_catalog.families); }
// Sections and, in parallel, one action block per row.
- (void)bind {
    OR6Chat8Catalog *c = _catalog; NSString *chosen = c.chosenModelId; NSDictionary *mode = [c modeForModel:chosen];
    if (chosen) { NSString *f = [[c familyForModel:chosen][@"id"] copy]; [_family release]; _family = f; }
    NSDictionary *family = [self shownFamily];
    NSMutableArray *sections = [NSMutableArray array], *actions = [NSMutableArray array];
    void (^add)(NSString *, NSArray *, NSArray *) = ^(NSString *title, NSArray *rows, NSArray *blocks) { [sections addObject:[RCChecklistSection sectionWithTitle:title rows:rows]]; [actions addObject:blocks]; };
    if ([c canUseDefault]) {
        NSString *def = c.catalogDefaultModelId ? [c titleForModel:c.catalogDefaultModelId effort:nil] : nil;
        add(nil, @[O8Row(OR6L(@"Default"), def, !chosen, @"chat.models.default")], @[[[^{ [c useDefault]; } copy] autorelease]]);
    }
    NSMutableArray *rows = [NSMutableArray array], *blocks = [NSMutableArray array];
    for (NSDictionary *f in c.families) {
        [rows addObject:O8Row(f[@"title"], nil, chosen && [[c familyForModel:chosen][@"id"] isEqual:f[@"id"]], @"chat.models.family")];
        [blocks addObject:[[^{
            // Switching the family keeps the mode (and an effort the new mode still offers) when the family has it.
            NSString *current = [c modeForModel:c.chosenModelId ?: c.catalogDefaultModelId][@"id"]; NSDictionary *target = nil;
            for (NSDictionary *m in f[@"modes"]) if ([m[@"id"] isEqual:current]) target = m;
            for (NSDictionary *m in f[@"modes"]) if (!target && [m[@"modelId"] isEqual:c.catalogDefaultModelId]) target = m;
            if (!target) target = O8First(f[@"modes"]);
            NSString *effort = O8KeptEffort(c, target);
            if ([target[@"modelId"] isEqual:c.chosenModelId] && (effort == c.chosenEffort || [effort isEqual:c.chosenEffort])) return;
            [c selectModel:target[@"modelId"] effort:effort];
        } copy] autorelease]];
    }
    if (rows.count) add(c.structured ? OR6L(@"Model family") : nil, rows, blocks); // flat legacy models: no family heading
    NSArray *modes = family[@"modes"]; BOOL titled = NO;
    for (NSDictionary *m in modes) if ([m[@"title"] length]) titled = YES;
    if (titled) {
        rows = [NSMutableArray array]; blocks = [NSMutableArray array];
        for (NSDictionary *m in modes) {
            [rows addObject:O8Row(m[@"title"], nil, [m[@"modelId"] isEqual:chosen], @"chat.models.mode")];
            [blocks addObject:[[^{ if (![m[@"modelId"] isEqual:c.chosenModelId]) [c selectModel:m[@"modelId"] effort:O8KeptEffort(c, m)]; } copy] autorelease]];
        }
        add(OR6L(@"Mode"), rows, blocks);
    }
    NSArray *efforts = mode[@"efforts"];
    if (chosen && efforts.count) {
        NSString *defaultTitle = nil; for (NSDictionary *e in efforts) if ([e[@"id"] isEqual:mode[@"defaultEffort"]]) defaultTitle = e[@"title"];
        rows = [NSMutableArray arrayWithObject:O8Row(OR6L(@"Default"), defaultTitle, !c.chosenEffort, @"chat.models.effort")];
        blocks = [NSMutableArray arrayWithObject:[[^{ if (c.chosenEffort) [c selectModel:chosen effort:nil]; } copy] autorelease]];
        for (NSDictionary *e in efforts) {
            [rows addObject:O8Row(e[@"title"], nil, [e[@"id"] isEqual:c.chosenEffort], @"chat.models.effort")];
            [blocks addObject:[[^{ if (![e[@"id"] isEqual:c.chosenEffort]) [c selectModel:chosen effort:e[@"id"]]; } copy] autorelease]];
        }
        add(OR6L(@"Thinking effort"), rows, blocks);
    }
    NSArray *a = [actions copy]; [_actions release]; _actions = a;
    self.sections = sections; self.busy = c.busy;
}
- (void)catalogChanged:(NSNotification *)n {
    (void)n; [self bind];
    if (_catalog.busy || !_catalog.issue || !self.isViewLoaded || !self.view.window) return;
    NSString *text = [_catalog.issue isEqual:@"default_unknown"] ? OR6L(@"The service did not name its default model, so the chosen model stays.") : OR6ChatErrorText(OR6APIError(_catalog.issue, @"none"));
    [RCHUD showText:text kind:RCHUDTextOnly inView:self.view.window seconds:1.8];
}
- (BOOL)checklist:(RCChecklistViewController *)list shouldSelectRow:(NSUInteger)row inSection:(NSUInteger)section {
    (void)list; (void)row; (void)section; return !_catalog.busy && (!_allow || _allow());
}
- (void)checklist:(RCChecklistViewController *)list didSelectRow:(NSUInteger)row inSection:(NSUInteger)section {
    (void)list; NSArray *blocks = section < _actions.count ? _actions[section] : nil;
    void (^action)(void) = row < blocks.count ? [[blocks[row] retain] autorelease] : nil;
    if (action) action();
}
@end

UIViewController *OR6Chat8CreateModelPicker(OR6Chat8Catalog *catalog, BOOL (^allow)(void)) {
    return [[[OR6Chat8ModelPickerController alloc] initWithCatalog:catalog allow:allow] autorelease];
}

#pragma mark - Translation

NSArray *OR6Chat8Languages(void) {
    return @[@{@"name": @"English", @"title": OR6L(@"English")}, @{@"name": @"Russian", @"title": OR6L(@"Russian")},
             @{@"name": @"Ukrainian", @"title": OR6L(@"Ukrainian")}, @{@"name": @"German", @"title": OR6L(@"German")},
             @{@"name": @"French", @"title": OR6L(@"French")}, @{@"name": @"Spanish", @"title": OR6L(@"Spanish")},
             @{@"name": @"Italian", @"title": OR6L(@"Italian")}, @{@"name": @"Portuguese", @"title": OR6L(@"Portuguese")},
             @{@"name": @"Turkish", @"title": OR6L(@"Turkish")}, @{@"name": @"Chinese", @"title": OR6L(@"Chinese")},
             @{@"name": @"Japanese", @"title": OR6L(@"Japanese")}, @{@"name": @"Korean", @"title": OR6L(@"Korean")}];
}
NSString *OR6Chat8DefaultTargetLanguage(void) {
    NSString *first = [[NSBundle mainBundle] preferredLocalizations].count ? [[NSBundle mainBundle] preferredLocalizations][0] : @"en";
    return [first hasPrefix:@"ru"] ? @"Russian" : @"English";
}
static NSString *OR6Chat8LanguageTitle(NSString *name) { for (NSDictionary *l in OR6Chat8Languages()) if ([l[@"name"] isEqual:name]) return l[@"title"]; return name; }

#import "../priority7/OR6Chat7Models.h"
// Stage 7 (API7 G, local): system language catalogue (translation.languages), the chosen pair
// (translation.configure / swapLanguages, ISO codes; the API8 request still takes English names),
// and copy/share payloads (translation.copy / translation.share).
static NSString *OR6Chat8EnglishLanguageName(NSString *code) { return [[[[NSLocale alloc] initWithLocaleIdentifier:@"en"] autorelease] displayNameForKey:NSLocaleLanguageCode value:code]; }
@interface OR6Chat8TranslateController () <RCTranslateViewControllerDelegate, OR6Chat8ModelDelegate> { OR6APICore *_core; OR6Chat8Translation *_translation; NSString *_source, *_target; NSArray *_catalog; NSDictionary *_titles; }
@end
@implementation OR6Chat8TranslateController
@synthesize translation = _translation;
- (id)initWithCore:(OR6APICore *)core text:(NSString *)text {
    if ((self = [super init])) {
        _core = [core retain]; _translation = [[OR6Chat8Translation alloc] initWithCore:core]; _translation.delegate = self;
        _target = [OR6Chat8DefaultTargetLanguage() copy];
        self.delegate = self; self.sourceText = text ?: @"";
        self.languagesEditable = YES; self.shareAvailable = YES;
        self.title = OR6L(@"Translation");
        [self renderLanguages];
    }
    return self;
}
- (NSString *)titleFor:(NSString *)name { return _titles[name] ?: OR6Chat8LanguageTitle(name); }
- (void)renderLanguages { self.sourceLanguage = _source ? [self titleFor:_source] : OR6L(@"Detect language"); self.targetLanguage = [self titleFor:_target]; }
- (BOOL)usesCatalog { return OR6Chat7On(_core, @"translation.languages") && OR6Chat7On(_core, @"translation.configure"); }
// translation.configure / swapLanguages result {sourceLanguage: code|auto, targetLanguage: code} → the pair shown and sent.
- (void)applyPair:(NSDictionary *)r {
    NSString *src = r[@"sourceLanguage"], *dst = r[@"targetLanguage"]; NSString *dstName = [dst isKindOfClass:NSString.class] ? OR6Chat8EnglishLanguageName(dst) : nil;
    if (!dstName) return;
    NSMutableDictionary *t = [[_titles mutableCopy] autorelease] ?: [NSMutableDictionary dictionary];
    for (NSDictionary *l in _catalog) { NSString *n = OR6Chat8EnglishLanguageName(l[@"code"]); if (n && ([l[@"code"] isEqual:src] || [l[@"code"] isEqual:dst])) t[n] = l[@"name"]; }
    [_titles release]; _titles = [t copy];
    [_source release]; _source = [src isEqual:@"auto"] ? nil : [OR6Chat8EnglishLanguageName(src) copy]; [_target release]; _target = [dstName copy];
    [self renderLanguages];
}
- (NSString *)codeFor:(NSString *)name { for (NSDictionary *l in _catalog) if ([OR6Chat8EnglishLanguageName(l[@"code"]) isEqual:name]) return l[@"code"]; return nil; }
- (void)viewDidLoad { [super viewDidLoad]; self.view.accessibilityIdentifier = @"chat.translate"; }
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.isMovingFromParentViewController || self.isBeingDismissed || self.navigationController.isBeingDismissed) [_translation cancel];
}
- (void)translate:(RCTranslateViewController *)c translateText:(NSString *)text {
    (void)c; self.sourceText = text;
    if ([_translation translate:text from:_source to:_target] || _translation.busy) return;
    NSString *why = _translation.refusal;
    self.errorText = [why isEqual:@"not_repeated"] ? OR6L(@"This exact translation may already have run, so it is not sent again. Change the text or the language.")
        : [why isEqual:@"restricted"] ? OR6ChatErrorText(OR6APIError(@"service_challenge", @"none")) : OR6L(@"Enter up to 16,000 characters to translate.");
}
- (void)chat8ModelChanged:(id)model {
    (void)model;
    self.busy = _translation.busy;
    self.resultText = _translation.result;
    if (_translation.busy || _translation.result) self.errorText = nil;
    else if ([_translation.issue isEqual:@"cancelled"]) self.errorText = OR6L(@"The translation was interrupted. It is not repeated automatically.");
    else if (_translation.issue) self.errorText = [OR6ChatErrorText(OR6APIError(_translation.issue, _translation.uncertain ? @"possible" : @"none")) stringByAppendingString:_translation.uncertain ? OR6L(@" It is not repeated automatically.") : @""];
    if (_translation.result) UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, OR6L(@"Translation ready"));
}
- (void)chooseLanguage:(BOOL)source {
    if ([self usesCatalog]) { [self chooseFromCatalog:source]; return; }
    NSArray *langs = OR6Chat8Languages(); NSMutableArray *titles = [NSMutableArray array]; NSUInteger selected = 0, n = 0;
    if (source) { [titles addObject:OR6L(@"Detect language")]; n = 1; }
    for (NSDictionary *l in langs) { [titles addObject:l[@"title"]]; if ([l[@"name"] isEqual:source ? _source : _target]) selected = n; n++; }
    OR6ChatChoiceController *c = [[[OR6ChatChoiceController alloc] initWithTitle:(source ? OR6L(@"Source language") : OR6L(@"Target language")) options:titles selected:selected footer:nil choose:^(NSUInteger i) {
        NSString *name = source && i == 0 ? nil : langs[i - (source ? 1 : 0)][@"name"];
        if (source) { [_source release]; _source = [name copy]; } else if (name) { [_target release]; _target = [name copy]; }
        [self renderLanguages];
    }] autorelease];
    [self.navigationController pushViewController:c animated:YES];
}
- (void)chooseFromCatalog:(BOOL)source {
    if (!_catalog) {
        [_core perform:@"translation.languages" parameters:@{} event:nil completion:^(NSDictionary *r, NSError *e) {
            if (e || ![r[@"items"] isKindOfClass:NSArray.class] || ![r[@"items"] count]) { [RCHUD showText:e ? OR6Chat7ErrorText(e) : OR6L(@"No languages available.") kind:RCHUDTextOnly inView:self.view.window seconds:1.6]; return; }
            [_catalog release]; _catalog = [r[@"items"] copy]; if (self.view.window) [self chooseFromCatalog:source];
        }];
        return;
    }
    NSMutableArray *titles = [NSMutableArray array]; NSUInteger selected = 0, n = 0; NSString *current = source ? [self codeFor:_source] : [self codeFor:_target];
    if (source) { [titles addObject:OR6L(@"Detect language")]; n = 1; }
    for (NSDictionary *l in _catalog) { [titles addObject:l[@"name"]]; if ([l[@"code"] isEqual:current]) selected = n; n++; }
    NSArray *catalog = [[_catalog retain] autorelease];
    OR6ChatChoiceController *c = [[[OR6ChatChoiceController alloc] initWithTitle:(source ? OR6L(@"Source language") : OR6L(@"Target language")) options:titles selected:selected footer:nil choose:^(NSUInteger i) {
        NSString *code = source && i == 0 ? @"auto" : catalog[i - (source ? 1 : 0)][@"code"];
        NSString *src = source ? code : ([self codeFor:_source] ?: @"auto"), *dst = source ? ([self codeFor:_target] ?: @"en") : code;
        [_core perform:@"translation.configure" parameters:@{@"sourceLanguage": src, @"targetLanguage": dst} event:nil completion:^(NSDictionary *r, NSError *e) {
            if (e) [RCHUD showText:OR6Chat7ErrorText(e) kind:RCHUDTextOnly inView:self.view.window seconds:1.6]; else [self applyPair:r]; }];
    }] autorelease];
    [self.navigationController pushViewController:c animated:YES];
}
- (void)translateDidTapSourceLanguage:(RCTranslateViewController *)c { (void)c; [self chooseLanguage:YES]; }
- (void)translateDidTapTargetLanguage:(RCTranslateViewController *)c { (void)c; [self chooseLanguage:NO]; }
- (void)translateDidSwapLanguages:(RCTranslateViewController *)c {
    (void)c;
    if (!_source) { [self renderLanguages]; return; } // «Определить» cannot become a target
    if ([self usesCatalog] && OR6Chat7On(_core, @"translation.swapLanguages") && [self codeFor:_source] && [self codeFor:_target]) {
        // The pair must exist in the local store first (configure), then swap returns the new pair.
        [_core perform:@"translation.configure" parameters:@{@"sourceLanguage": [self codeFor:_source], @"targetLanguage": [self codeFor:_target]} event:nil completion:^(NSDictionary *r, NSError *e) { (void)r;
            if (e) { [self renderLanguages]; return; }
            [_core perform:@"translation.swapLanguages" parameters:@{} event:nil completion:^(NSDictionary *x, NSError *f) { if (!f) [self applyPair:x]; else [self renderLanguages]; }]; }];
        return;
    }
    NSString *s = [[_source retain] autorelease]; [_source release]; _source = [_target copy]; [_target release]; _target = [s copy];
    [self renderLanguages];
}
- (void)translate:(RCTranslateViewController *)c copyResult:(NSString *)text {
    (void)c; UIView *host = self.view.window;
    if (OR6Chat7On(_core, @"translation.copy") && text.length) { // G: the exact Unicode text; the pasteboard write stays this explicit UIKit action
        [_core perform:@"translation.copy" parameters:@{@"text": text} event:nil completion:^(NSDictionary *r, NSError *e) { if (e || ![r[@"text"] isKindOfClass:NSString.class]) return; [UIPasteboard generalPasteboard].string = r[@"text"]; [RCHUD showText:OR6L(@"Copied") kind:RCHUDDone inView:host seconds:0]; }];
        return;
    }
    NSDictionary *p = OR6Chat9CopyParameters(@"translation", text ?: @""); if (!p) return;
    [_core perform:@"content.copy" parameters:p event:nil completion:^(NSDictionary *r, NSError *e) {
        if (e) return; [UIPasteboard generalPasteboard].string = r[@"text"];
        [RCHUD showText:OR6L(@"Copied") kind:RCHUDDone inView:host seconds:0];
    }];
}
- (void)translate:(RCTranslateViewController *)c shareResult:(NSString *)text {
    (void)c; if (!text.length) return;
    if (OR6Chat7On(_core, @"translation.share")) { // G prepares the text/plain payload; the system sheet is the real handoff
        [_core perform:@"translation.share" parameters:@{@"text": text} event:nil completion:^(NSDictionary *r, NSError *e) { if (e || ![r[@"text"] isKindOfClass:NSString.class] || !self.view.window) return;
            [self presentViewController:[[[UIActivityViewController alloc] initWithActivityItems:@[r[@"text"]] applicationActivities:nil] autorelease] animated:YES completion:nil]; }];
        return;
    }
    [self presentViewController:[[[UIActivityViewController alloc] initWithActivityItems:@[text] applicationActivities:nil] autorelease] animated:YES completion:nil];
}
- (void)dealloc { self.delegate = nil; _translation.delegate = nil; [_translation cancel]; [_translation release]; [_core release]; [_source release]; [_target release]; [_catalog release]; [_titles release]; [super dealloc]; }
@end

#pragma mark - Inbox (Open In files)

#import "../../api/priority8/OR6API8Interactions.h"
#import "RCGlyph.h"

// «Файлы»: the iOS 6 Open In / Inbox list for the "document" source of
// assets.acquire, on the kit's grouped table. The API8 picker finds this class by
// name (OR6API8InboxScreenClassName) and validates the chosen name itself.
@interface OR6Chat8InboxController : UITableViewController <OR6API8InboxScreen> { NSArray *_files; void (^_chosen)(NSString *); }
@end
@implementation OR6Chat8InboxController
+ (UIViewController *)inboxScreenWithFiles:(NSArray *)files chosen:(void (^)(NSString *))chosen {
    OR6Chat8InboxController *c = [[[self alloc] initWithStyle:UITableViewStyleGrouped] autorelease];
    c->_files = [files copy]; c->_chosen = [chosen copy];
    return c;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; [_files release]; [_chosen release]; [super dealloc]; }
- (NSString *)note {
    return _files.count ? OR6L(@"Files you opened in ChatGPT X from other apps (“Open in…”). Choosing one only adds it to the message; nothing is sent.")
                        : OR6L(@"No files yet. In Mail, Safari or another app, tap “Open in…” and choose ChatGPT X. The file then appears here.");
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = OR6L(@"Files");
    self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:OR6L(@"Cancel") style:UIBarButtonItemStyleBordered target:self action:@selector(cancel)] autorelease];
    self.tableView.accessibilityIdentifier = @"chat.inbox";
    [RCTheme styleGroupedTableView:self.tableView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(looks:) name:RCThemeAppearanceDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(looks:) name:RCThemeTextSizeDidChangeNotification object:nil];
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [RCTheme styleNavigationBar:self.navigationController.navigationBar variant:RCBarVariantJade]; }
- (void)looks:(NSNotification *)n { (void)n; [RCTheme styleGroupedTableView:self.tableView]; [self.tableView reloadData]; }
- (void)cancel { void (^c)(NSString *) = [[_chosen copy] autorelease]; if (c) c(nil); }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { (void)t; (void)s; return (NSInteger)_files.count; }
- (UIView *)tableView:(UITableView *)t viewForFooterInSection:(NSInteger)s {
    (void)s; NSString *text = [self note]; UIFont *font = [UIFont systemFontOfSize:14];
    CGFloat w = t.bounds.size.width ?: 320, h = RCMeasureText(text, font, w - 40).height;
    UIView *v = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h + (_files.count ? 16 : 40))] autorelease];
    UILabel *l = [[[UILabel alloc] initWithFrame:CGRectMake(20, _files.count ? 6 : 30, w - 40, h)] autorelease];
    l.backgroundColor = [UIColor clearColor]; l.font = font; l.numberOfLines = 0; l.textAlignment = NSTextAlignmentCenter;
    l.textColor = [RCTheme noteTextColor]; l.shadowColor = [RCTheme engravedShadowColor]; l.shadowOffset = [RCTheme engravedShadowOffset];
    RCLabelSetText(l, text); l.accessibilityIdentifier = _files.count ? @"chat.inbox.note" : @"chat.inbox.empty";
    [v addSubview:l]; return v;
}
- (CGFloat)tableView:(UITableView *)t heightForFooterInSection:(NSInteger)s { (void)s; return RCMeasureText([self note], [UIFont systemFontOfSize:14], (t.bounds.size.width ?: 320) - 40).height + (_files.count ? 16 : 40); }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p {
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:@"file"];
    if (!c) c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"file"] autorelease];
    [RCTheme styleGroupedCell:c position:[RCTheme positionForRow:p.row count:(NSInteger)_files.count]];
    NSDictionary *f = _files[(NSUInteger)p.row];
    c.imageView.image = [RCGlyph tileNamed:@"file" color:RCTileGray size:29];
    c.textLabel.text = f[@"name"]; c.textLabel.textColor = [RCTheme inkColor]; c.textLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    c.detailTextLabel.text = OR6Chat8Bytes([f[@"bytes"] unsignedLongLongValue]);
    c.accessibilityLabel = f[@"name"]; c.accessibilityValue = c.detailTextLabel.text; c.accessibilityHint = OR6L(@"Adds the file to the message. Nothing is sent.");
    c.accessibilityTraits = UIAccessibilityTraitButton; c.accessibilityIdentifier = @"chat.inbox.file";
    return c;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p {
    [t deselectRowAtIndexPath:p animated:YES];
    void (^c)(NSString *) = [[_chosen copy] autorelease]; if (c) c(_files[(NSUInteger)p.row][@"name"]);
}
@end
