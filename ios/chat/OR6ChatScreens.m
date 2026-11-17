#import "../localization/OR6Localization.h"
#import "OR6ChatScreens.h"
#import "OR6ChatFavicons.h"
#import "RCTheme.h"
#import "RCRevealController.h"
#import "RCSelectTextViewController.h"
#import "RCSourcesSheet.h"
#import "RCTextSizeSlider.h"
#import "RCAnswerCardView.h"
#import "RCHUD.h"
#import "RCComposerView.h"
#import "../ui/priority9/OR6Chat9Content.h"
#import "../ui/priority8/OR6Chat8Models.h"
#import "../ui/priority8/OR6Chat8Screens.h"
#import "../ui/priority6/OR6Chat6Screens.h"
#import "../ui/priority6/OR6Chat6Settings.h"

static NSString *const OR6TextSizeKey = @"RCTextSize", *const OR6AppearanceKey = @"RCAppearance";

void OR6ChatApplySavedLook(void) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    id size = [d objectForKey:OR6TextSizeKey], look = [d objectForKey:OR6AppearanceKey];
    if ([size isKindOfClass:[NSNumber class]]) [RCTheme setTextSize:(RCTextSize)MAX(0, MIN(4, [size intValue]))];
    if ([look isKindOfClass:[NSNumber class]]) [RCTheme setAppearance:[look intValue] == 1 ? RCAppearanceDark : RCAppearanceLight];
}
void OR6ChatSetAppearance(BOOL dark) {
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:dark ? 1 : 0] forKey:OR6AppearanceKey];
    [RCTheme setAppearance:dark ? RCAppearanceDark : RCAppearanceLight];
}
void OR6ChatSetTextSize(int size) {
    size = MAX(0, MIN(4, size));
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:size] forKey:OR6TextSizeKey];
    [RCTheme setTextSize:(RCTextSize)size];
}
NSString *OR6TextSizeName(int size) {
    NSArray *n = [NSArray arrayWithObjects:OR6L(@"Smaller"), OR6L(@"Small"), OR6L(@"Normal"), OR6L(@"Large"), OR6L(@"Larger"), nil];
    return [n objectAtIndex:(NSUInteger)MAX(0, MIN(4, size))];
}

void OR6ChatToggleDrawer(UIViewController *controller) {
    RCRevealController *reveal = controller.rc_revealController;
    if (!reveal && controller.navigationController) reveal = controller.navigationController.rc_revealController;
    [reveal toggleDrawer:nil];
}

// «Выделить» (stage 9): the kit's selection screen. Copy (selection or all)
// goes through the app's content.copy, then UIPasteboard, as before.
@interface OR6ChatSelectController : RCSelectTextViewController <RCSelectTextViewControllerDelegate> { OR6APICore *_core; NSString *_messageId; }
@end
@implementation OR6ChatSelectController
- (id)initWithCore:(OR6APICore *)core messageId:(NSString *)identifier text:(NSString *)text {
    if ((self = [super initWithText:text])) { _core = [core retain]; _messageId = [identifier copy]; self.delegate = self; self.showsDoneButton = NO; }
    return self;
}
- (void)viewDidLoad { [super viewDidLoad]; self.textView.accessibilityIdentifier = @"chat.message.selection"; }
- (void)selectTextController:(RCSelectTextViewController *)c copyText:(NSString *)text {
    NSDictionary *p = OR6Chat9CopyParameters(_messageId ? _messageId : @"message", text ? text : @"");
    if (!p) return;
    UIView *host = self.view.window;
    [_core perform:@"content.copy" parameters:p event:nil completion:^(NSDictionary *r, NSError *e) {
        if (e) return;
        [UIPasteboard generalPasteboard].string = [r objectForKey:@"text"];
        [RCHUD showText:OR6L(@"Copied") kind:RCHUDDone inView:host seconds:0];
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, OR6L(@"Copied"));
    }];
}
- (void)dealloc { self.delegate = nil; [_core release]; [_messageId release]; [super dealloc]; }
@end

UIViewController *OR6ChatCreateSelectController(OR6APICore *core, NSDictionary *message, NSString *readableText) {
    if (![message isKindOfClass:[NSDictionary class]]) return nil;
    NSString *text = readableText.length ? readableText : ([[message objectForKey:@"text"] isKindOfClass:[NSString class]] ? [message objectForKey:@"text"] : @"");
    OR6ChatSelectController *c = [[[OR6ChatSelectController alloc] initWithCore:core messageId:[message objectForKey:@"id"] text:text] autorelease];
    c.title = OR6L(@"Select in text");
    return c;
}

// «Источники» (stage 8): the kit's sources sheet; a row goes to `open` after the sheet closes.
@interface OR6ChatSourcesActions : NSObject <RCSourcesSheetDelegate> { @public void (^open)(NSDictionary *); NSArray *sources; RCSourcesSheet *_sheet; }
@end
@implementation OR6ChatSourcesActions
- (void)sourcesSheet:(RCSourcesSheet *)sheet didSelectSource:(RCSourceItem *)source {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    NSDictionary *chosen = nil;
    for (NSDictionary *d in sources) if ([[d objectForKey:@"url"] isEqual:source.URL.absoluteString]) { chosen = d; break; }
    void (^o)(NSDictionary *) = [[open copy] autorelease];
    [sheet dismissViewControllerAnimated:YES completion:^{ if (o && chosen) o(chosen); }];
}
- (void)sourcesSheetDidFinish:(RCSourcesSheet *)sender { [NSNotificationCenter.defaultCenter removeObserver:self]; [sender dismissViewControllerAnimated:YES completion:nil]; }
- (void)iconsLoaded:(NSNotification *)note { NSMutableArray *items=[NSMutableArray array]; for(NSDictionary *d in sources){ RCSourceItem *s=[RCSourceItem sourceWithTitle:d[@"title"] host:d[@"host"] URL:[NSURL URLWithString:d[@"url"]]];s.icon=OR6ChatFavicon(d[@"url"],NO);[items addObject:s]; } _sheet.sources=items; [_sheet.tableView reloadData]; }
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; [_sheet release]; [open release]; [sources release]; [super dealloc]; }
@end

void OR6ChatPresentSources(UIViewController *host, NSArray *sources, void (^open)(NSDictionary *source)) {
    if (!sources.count) return;
    static OR6ChatSourcesActions *current; // the sheet does not retain its delegate
    [current release];
    current = [[OR6ChatSourcesActions alloc] init];
    current->open = [open copy];
    current->sources = [sources copy];
    NSMutableArray *items = [NSMutableArray array];
    for (NSDictionary *d in sources) { RCSourceItem *s=[RCSourceItem sourceWithTitle:d[@"title"] host:d[@"host"] URL:[NSURL URLWithString:d[@"url"]]];s.icon=OR6ChatFavicon(d[@"url"],YES);[items addObject:s]; }
    UINavigationController *nav = [RCSourcesSheet navigationControllerWithSources:items delegate:current];
    current->_sheet=[(RCSourcesSheet *)nav.topViewController retain];
    [NSNotificationCenter.defaultCenter addObserver:current selector:@selector(iconsLoaded:) name:OR6ChatFaviconDidLoadNotification object:nil];
    [host presentViewController:nav animated:YES completion:nil];
}

// «Размер текста» (stage 8): the kit slider over a live sample answer.
@interface OR6ChatTextSizeController : UIViewController { RCTextSizeSlider *_slider; RCAnswerCardView *_sample; @public OR6APICore *_core; }
@end
@implementation OR6ChatTextSizeController
- (void)loadView {
    UIView *v = [[[UIView alloc] initWithFrame:UIScreen.mainScreen.applicationFrame] autorelease];
    v.backgroundColor = [RCTheme contentBackgroundColor];
    _sample = [[RCAnswerCardView alloc] initWithFrame:CGRectZero];
    _sample.textMode = RCAnswerTextMarkdown;
    _sample.copyMenuEnabled = NO;
    _sample.text = OR6L(@"This is how answers look. **Bold**, lists and code follow the same size.");
    [v addSubview:_sample];
    _slider = [[RCTextSizeSlider alloc] initWithFrame:CGRectZero];
    _slider.showsStepName = YES;
    _slider.value = [RCTheme textSize];
    _slider.accessibilityIdentifier = @"chat.settings.text_size.slider";
    [_slider addTarget:self action:@selector(changed) forControlEvents:UIControlEventValueChanged];
    [v addSubview:_slider];
    self.view = v;
    self.title = OR6L(@"Text size");
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width, y = 16;
    CGFloat sh = [_slider heightForWidth:w - 40];
    _slider.frame = CGRectMake(20, y, w - 40, sh); y += sh + 18;
    CGFloat ch = [_sample heightForWidth:w];
    _sample.frame = CGRectMake(0, y, w, ch);
}
- (void)changed {
    int size = (int)_slider.value;
    if (!_core || !OR6Chat8Supports(_core, OR6Chat8FLargeText)) { OR6ChatSetTextSize(size); [self.view setNeedsLayout]; return; }
    // content.scale validates the scale DTO (0.75…3); the kit size follows the returned value.
    [_core perform:@"content.scale" parameters:@{@"scale": @(OR6Chat8ScaleForTextSize(size))} event:nil completion:^(NSDictionary *r, NSError *e) {
        if (e || ![r[@"scale"] isKindOfClass:[NSNumber class]]) { _slider.value = [RCTheme textSize]; return; }
        OR6ChatSetTextSize(OR6Chat8TextSizeForScale([r[@"scale"] doubleValue]));
        [self.view setNeedsLayout];
    }];
}
- (void)dealloc { [_slider release]; [_sample release]; [_core release]; [super dealloc]; }
@end

UIViewController *OR6ChatCreateTextSizeController(void) { return [[[OR6ChatTextSizeController alloc] init] autorelease]; }
UIViewController *OR6ChatCreateTextSizeControllerWithCore(OR6APICore *core) { OR6ChatTextSizeController *c = [[[OR6ChatTextSizeController alloc] init] autorelease]; c->_core = [core retain]; return c; }

void OR6ChatSignIn(id<OR6ChatUIHost> host, OR6APICore *core, UIView *view) {
    // Every sign-in method (e-mail and password, Google, Apple, phone, codes, password reset,
    // sign-up) is offered by the same ChatGPT page, so the app opens it directly.
    (void)core; (void)view;
    [host chatSignIn];
}

#pragma mark - Choice

@interface OR6ChatChoiceController () { NSArray *_options; NSUInteger _selected; NSString *_footer; void (^_choose)(NSUInteger); }
@end
@implementation OR6ChatChoiceController
- (id)initWithTitle:(NSString *)title options:(NSArray *)options selected:(NSUInteger)selected footer:(NSString *)footer choose:(void (^)(NSUInteger))choose {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) { self.title = title; _options = [options copy]; _selected = selected; _footer = [footer copy]; _choose = [choose copy]; }
    return self;
}
- (void)viewDidLoad { [super viewDidLoad]; [RCTheme styleGroupedTableView:self.tableView]; self.tableView.accessibilityIdentifier = @"chat.settings.choice"; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { (void)t; (void)s; return (NSInteger)_options.count; }
- (UIView *)tableView:(UITableView *)t viewForFooterInSection:(NSInteger)s {
    (void)s;
    if (!_footer.length) return nil;
    CGFloat w = t.bounds.size.width, h = RCMeasureText(_footer, [UIFont systemFontOfSize:14], w - 40).height;
    UIView *v = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h + 16)] autorelease];
    UILabel *l = [[[UILabel alloc] initWithFrame:CGRectMake(20, 6, w - 40, h)] autorelease];
    l.backgroundColor = [UIColor clearColor]; l.font = [UIFont systemFontOfSize:14]; l.numberOfLines = 0; l.textAlignment = NSTextAlignmentCenter;
    l.textColor = [RCTheme noteTextColor]; l.shadowColor = [RCTheme engravedShadowColor]; l.shadowOffset = [RCTheme engravedShadowOffset];
    RCLabelSetText(l, _footer);
    [v addSubview:l];
    return v;
}
- (CGFloat)tableView:(UITableView *)t heightForFooterInSection:(NSInteger)s { (void)s; return _footer.length ? RCMeasureText(_footer, [UIFont systemFontOfSize:14], t.bounds.size.width - 40).height + 16 : 1; }
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p {
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:@"choice"];
    if (!c) c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"choice"] autorelease];
    [RCTheme styleGroupedCell:c position:[RCTheme positionForRow:p.row count:(NSInteger)_options.count]];
    c.textLabel.text = [_options objectAtIndex:(NSUInteger)p.row];
    BOOL on = (NSUInteger)p.row == _selected;
    c.accessoryView = on ? [RCTheme checkmarkAccessoryView] : nil;
    c.accessibilityTraits = UIAccessibilityTraitButton | (on ? UIAccessibilityTraitSelected : 0);
    return c;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p {
    [t deselectRowAtIndexPath:p animated:YES];
    _selected = (NSUInteger)p.row;
    if (_choose) _choose(_selected);
    [RCTheme styleGroupedTableView:t];
    [t reloadData];
}
- (void)dealloc { [_options release]; [_footer release]; [_choose release]; [super dealloc]; }
@end

#pragma mark - Editor

@interface OR6ChatTextEditorController () <UITextViewDelegate> { NSString *_text, *_edited; void (^_completion)(NSString *); UITextView *_tv; CGFloat _keyboard; NSRange _selection; }
@end

// iOS 6.1.4 (physical QA80/QA81): this attributed (WebKit) text view reads an empty last paragraph back
// with one extra "\n" (Select All + Backspace read "\n"; one Return at the end of a 167-character draft
// read ORIGINAL+"\n\n"), and an assigned "\n" only ends a paragraph. The editor keeps the intended text:
// the original, then every edit UIKit reports applied to it; Done returns it through the kit's
// RCTextViewIntendedText (RCComposerView.h), and a draft whose last paragraph is empty opens with
// RCTextViewStoredText. Nothing is trimmed or normalised. (tests/chat-keyboard/editor.m)

@implementation OR6ChatTextEditorController
- (NSRange)selection {
    if (!_tv) return _selection;
    NSUInteger n = [RCTextViewIntendedText(_tv.text, _edited) length]; NSRange r = _tv.selectedRange; // never past the intended text
    if (r.location == NSNotFound || r.location > n) return NSMakeRange(n, 0);
    if (NSMaxRange(r) > n) r.length = n - r.location;
    return r;
}
- (void)setSelection:(NSRange)r { _selection = r; if (_tv && r.location != NSNotFound && NSMaxRange(r) <= _tv.text.length) _tv.selectedRange = r; }
- (id)initWithTitle:(NSString *)title text:(NSString *)text completion:(void (^)(NSString *))completion {
    if ((self = [super init])) {
        self.title = title;
        _text = [text copy];
        _completion = [completion copy]; _selection = NSMakeRange(text.length, 0);
        _edited = [(text ? text : @"") copy]; // intended text: the original until UIKit reports an edit
    }
    return self;
}
- (void)loadView {
    UIView *v = [[[UIView alloc] initWithFrame:UIScreen.mainScreen.applicationFrame] autorelease];
    v.backgroundColor = [UIColor whiteColor];
    _tv = [[UITextView alloc] initWithFrame:v.bounds];
    _tv.font = RCTextViewFont([UIFont systemFontOfSize:17]);
    _tv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    // iOS 6 -setText: turns line breaks into spaces; the attributed setter keeps them.
    // An empty draft takes the plain setter: no line breaks to keep, and no attributed empty paragraph.
    if (_text.length) _tv.attributedText = [[[NSAttributedString alloc] initWithString:RCTextViewStoredText(_text) attributes:RCTextViewAttributes(_tv.font, [RCTheme inkColor])] autorelease];
    else { _tv.text = @""; _tv.textColor = [RCTheme inkColor]; }
    _tv.delegate = self;
    _tv.accessibilityIdentifier = @"chat.composer.expanded";
    [v addSubview:_tv];
    self.view = v;
    self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:OR6L(@"Cancel") style:UIBarButtonItemStyleBordered target:self action:@selector(cancel)] autorelease];
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:OR6L(@"Done") style:UIBarButtonItemStyleDone target:self action:@selector(done)] autorelease];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboard:) name:UIKeyboardWillChangeFrameNotification object:nil];
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [RCTheme styleNavigationBar:self.navigationController.navigationBar variant:RCBarVariantJade]; }
- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; [_tv becomeFirstResponder]; if (_selection.location != NSNotFound && NSMaxRange(_selection) <= _tv.text.length) _tv.selectedRange = _selection; }
- (void)keyboard:(NSNotification *)n {
    NSValue *v = [n.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey];
    if (!v) return;
    CGRect overlap = CGRectIntersection(self.view.bounds, [self.view convertRect:v.CGRectValue fromView:nil]);
    _keyboard = CGRectIsNull(overlap) ? 0 : overlap.size.height;
    _tv.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - _keyboard);
}
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    NSString *edited = RCTextViewEditedText(textView.text, _edited, range, text);
    [_edited release]; _edited = [edited copy];
    return YES;
}
- (void)finish:(NSString *)text {
    void (^c)(NSString *) = [[_completion copy] autorelease];
    [_completion release]; _completion = nil;
    _selection = self.selection; [_tv resignFirstResponder];
    [self dismissViewControllerAnimated:YES completion:nil];
    if (c) c(text);
}
- (void)cancel { [self finish:nil]; }
- (void)done { [self finish:RCTextViewIntendedText(_tv.text, _edited)]; }
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; _tv.delegate = nil; [_text release]; [_edited release]; [_completion release]; [_tv release]; [super dealloc]; }
@end
