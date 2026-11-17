#import "RCGalleryDemos.h"
#import "RCFileIcon.h"
#import "RCTheme.h"
#import "RCGlyph.h"
#import "RCLampView.h"
#import "RCButton.h"
#import "RCTitleView.h"
#import "RCBannerView.h"
#import "RCUserMessageView.h"
#import "RCAnswerCardView.h"
#import "RCPartPlaceholderView.h"
#import "RCComposerView.h"
#import "RCActivitySheet.h"
#import "RCRevealController.h"
#import "RCDrawerController.h"
#import "RCHUD.h"
#import "RCStage.h"
#import <QuartzCore/QuartzCore.h> // headers only (layer messages), no QuartzCore link

#pragma mark - Stage

// The stage lives in the kit (RCStage); the gallery keeps its own names for it.
NSString *const RCGalleryStageDidChangeNotification = @"RCStageDidChangeNotification";
int RCGalleryStage(void) { return RCStageCurrent(); }
void RCGallerySetStage(int stage) { RCStageSet(stage); }
BOOL RCGalleryOn(int usefulness) { return RCStageOn(usefulness); }

static UIBarButtonItem *RCGlyphItem(NSString *glyph, id target, SEL action) {
    UIBarButtonItem *i = [[[UIBarButtonItem alloc] initWithImage:[RCGlyph imageNamed:glyph size:20 color:[UIColor whiteColor]] style:UIBarButtonItemStyleBordered target:target action:action] autorelease];
    return i;
}

void RCGalleryHUD(UIView *anyView, NSString *text) {
    UIView *host = anyView.window ? anyView.window : anyView;
    [RCHUD showText:text kind:RCHUDDone inView:host seconds:0];
}

void RCGalleryAlert(NSString *title, NSString *message) {
    UIAlertView *a = [[[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
    [a show];
}

static UIImage *RCSampleArt(unsigned top, unsigned bottom) {
    NSString *key = [NSString stringWithFormat:@"art-%06x-%06x", top, bottom];
    return [RCTheme imageForKey:key size:CGSizeMake(52, 52) capInsets:UIEdgeInsetsZero drawing:^(CGContextRef ctx, CGRect r) {
        RCDrawVerticalGradient(ctx, r, [NSArray arrayWithObjects:RCHex(top), RCHex(bottom), nil], nil);
        CGContextSetFillColorWithColor(ctx, RCHexA(0xffffff, .5).CGColor);
        CGContextFillEllipseInRect(ctx, CGRectMake(32, 8, 10, 10));
    }];
}

#pragma mark - Page base

@interface RCGalleryPage () {
    UIScrollView *_scroll;
    NSMutableArray *_items; // [view, NSNumber height (-1 = dynamic)]
    CGFloat _y;
}
@end

@interface RCGalleryActivityPage (Items)
+ (NSArray *)stageItems;
@end

@implementation RCGalleryPage
@synthesize scrollView = _scroll;

- (id)init {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _items = [[NSMutableArray alloc] init];
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(settingsChanged) name:RCGalleryStageDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(settingsChanged) name:RCThemeTextSizeDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(settingsChanged) name:RCThemeAppearanceDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(keyboard:) name:UIKeyboardWillShowNotification object:nil];
        [nc addObserver:self selector:@selector(keyboard:) name:UIKeyboardWillHideNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_scroll release]; [_items release];
    [super dealloc];
}

- (void)loadView {
    UIView *v = [[[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame] autorelease];
    v.backgroundColor = [RCTheme contentBackgroundColor];
    _scroll = [[UIScrollView alloc] initWithFrame:v.bounds];
    _scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scroll.alwaysBounceVertical = YES;
    [v addSubview:_scroll];
    self.view = v;
}

- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self.navigationController setToolbarHidden:YES animated:animated]; [self rebuild]; }
- (void)settingsChanged { if (self.isViewLoaded) [self rebuild]; }
- (void)build {}

- (void)rebuild {
    self.view.backgroundColor = [RCTheme contentBackgroundColor];
    for (NSArray *it in _items) [[it objectAtIndex:0] removeFromSuperview];
    [_items removeAllObjects];
    [self build];
    [self relayout];
}

- (CGFloat)width { return self.view.bounds.size.width; }

- (void)relayout {
    CGFloat y = 4, w = [self width];
    for (NSArray *it in _items) {
        UIView *v = [it objectAtIndex:0];
        CGFloat h = [[it objectAtIndex:1] floatValue];
        CGFloat x = [[it objectAtIndex:2] floatValue];
        if (h < 0) h = [v respondsToSelector:@selector(heightForWidth:)] ? [(id)v heightForWidth:w - 2 * x] : v.frame.size.height;
        v.frame = CGRectMake(x, y, w - 2 * x, h);
        y += h;
    }
    _y = y;
    _scroll.contentSize = CGSizeMake(w, y + 24);
}

- (void)add:(UIView *)v height:(CGFloat)h inset:(CGFloat)x {
    [_scroll addSubview:v];
    [_items addObject:[NSArray arrayWithObjects:v, [NSNumber numberWithFloat:h], [NSNumber numberWithFloat:x], nil]];
}

- (void)addCaption:(NSString *)caption {
    UIView *wrap = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)] autorelease];
    UILabel *l = [[[UILabel alloc] initWithFrame:CGRectMake(20, 17, 280, 21)] autorelease];
    l.backgroundColor = [UIColor clearColor];
    l.font = [UIFont boldSystemFontOfSize:16];
    l.textColor = [RCTheme engravedTextColor];
    l.shadowColor = [RCTheme engravedShadowColor];
    l.shadowOffset = [RCTheme engravedShadowOffset];
    l.text = caption;
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [wrap addSubview:l];
    [self add:wrap height:44 inset:0];
}

- (void)addNote:(NSString *)note {
    UILabel *l = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
    l.backgroundColor = [UIColor clearColor];
    l.font = [UIFont systemFontOfSize:13];
    l.textColor = [RCTheme noteTextColor];
    l.shadowColor = [RCTheme engravedShadowColor];
    l.shadowOffset = [RCTheme engravedShadowOffset];
    l.numberOfLines = 0; l.lineBreakMode = NSLineBreakByWordWrapping;
    RCLabelSetText(l, note);
    CGFloat h = RCMeasureText(note, l.font, 280).height;
    [self add:l height:h + 8 inset:20];
}

- (void)addView:(UIView *)view { [self add:view height:-1 inset:0]; }
- (void)addView:(UIView *)view height:(CGFloat)height { [self add:view height:height inset:0]; }
- (void)addInsetView:(UIView *)view height:(CGFloat)height { [self add:view height:height inset:10]; }
- (void)addSpace:(CGFloat)space { [self add:[[[UIView alloc] init] autorelease] height:space inset:0]; }

- (void)keyboard:(NSNotification *)n {
    if (!self.isViewLoaded || !self.view.window) return;
    CGRect kb = [self.view convertRect:[[n.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue] fromView:nil];
    CGFloat overlap = [n.name isEqualToString:UIKeyboardWillShowNotification] ? MAX(0, CGRectGetMaxY(self.view.bounds) - kb.origin.y) : 0;
    UIEdgeInsets in = _scroll.contentInset;
    in.bottom = overlap;
    _scroll.contentInset = in;
    _scroll.scrollIndicatorInsets = in;
}
@end

#pragma mark - Theme

@implementation RCGalleryThemePage
- (UIView *)swatches {
    struct { unsigned c; const char *n; } s[] = {
        {0x1d2924, "ink"}, {0x6b7a72, "secondary"}, {0x4b5d55, "header"}, {0x1f8a57, "jade"},
        {0x1c7449, "link"}, {0xa26b00, "warning"}, {0xa3261a, "error"}, {0xc7d2cc, "card border"},
        {0x23935f, "navbar"}, {0x1f8656, "bar button"}, {0x2ea96a, "switch on"}, {0x1e4838, "drawer"}};
    int n = sizeof s / sizeof s[0];
    UIView *v = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 3 * 64)] autorelease];
    for (int i = 0; i < n; i++) {
        CGFloat x = 14 + (i % 4) * 74, y = (i / 4) * 64;
        UIView *sw = [[[UIView alloc] initWithFrame:CGRectMake(x + 15, y + 4, 40, 34)] autorelease];
        sw.backgroundColor = RCHex(s[i].c);
        sw.layer.cornerRadius = 6;
        sw.layer.borderWidth = 1;
        sw.layer.borderColor = RCHexA(0, .15).CGColor;
        [v addSubview:sw];
        UILabel *l = [[[UILabel alloc] initWithFrame:CGRectMake(x, y + 40, 70, 22)] autorelease];
        l.backgroundColor = [UIColor clearColor];
        l.font = [UIFont systemFontOfSize:9];
        l.textColor = [RCTheme engravedTextColor];
        l.textAlignment = NSTextAlignmentCenter;
        l.numberOfLines = 2;
        l.text = [NSString stringWithFormat:@"%s\n#%06x", s[i].n, s[i].c];
        [v addSubview:l];
    }
    return v;
}

- (void)build {
    [self addCaption:RCL(@"Palette")];
    [self addView:[self swatches] height:3 * 64];
    [self addCaption:RCL(@"44 pt buttons (RCButton)")];
    struct { RCButtonStyle s; NSString *t; } large[] = {
        {RCButtonStyleLarge, RCL(@"Log in with browser")}, {RCButtonStyleLargeGreen, RCL(@"Continue")},
        {RCButtonStyleLargeRed, RCL(@"Delete all chats")}, {RCButtonStyleLargeDark, RCL(@"Log in")}};
    for (int i = 0; i < 4; i++) {
        [self addInsetView:[RCButton buttonWithStyle:large[i].s title:large[i].t] height:44];
        [self addSpace:10];
    }
    RCButton *dis = [RCButton buttonWithStyle:RCButtonStyleLargeGreen title:RCL(@"Disabled (alpha .5)")];
    dis.enabled = NO;
    [self addInsetView:dis height:44];
    [self addCaption:RCL(@"Pills (App Store 2012)")];
    UIView *row = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 30)] autorelease];
    CGFloat x = 20;
    struct { RCButtonStyle s; NSString *t; } pills[] = {{RCButtonStylePill, RCL(@"Copy")}, {RCButtonStylePillGo, RCL(@"Log in")}, {RCButtonStylePillRed, RCL(@"Delete")}};
    for (int i = 0; i < 3; i++) {
        RCButton *p = [RCButton buttonWithStyle:pills[i].s title:pills[i].t];
        p.frame = CGRectMake(x, 2, p.frame.size.width, 26);
        [row addSubview:p];
        x += p.frame.size.width + 8;
    }
    [self addView:row height:30];
    [self addCaption:RCL(@"Materials")];
    UIView *mat = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 90)] autorelease];
    UIView *dark = [[[UIView alloc] initWithFrame:CGRectMake(160, 0, 150, 90)] autorelease];
    dark.backgroundColor = [RCTheme linenDarkColor];
    dark.layer.cornerRadius = 8; dark.clipsToBounds = YES;
    [mat addSubview:dark];
    UIImageView *icon57 = [[[UIImageView alloc] initWithImage:[RCTheme appIconImage:57]] autorelease];
    icon57.frame = CGRectMake(20, 10, 57, 57);
    icon57.layer.cornerRadius = 10; icon57.clipsToBounds = YES;
    [mat addSubview:icon57];
    UIImageView *icon29 = [[[UIImageView alloc] initWithImage:[RCTheme appIconImage:29]] autorelease];
    icon29.frame = CGRectMake(92, 24, 29, 29);
    icon29.layer.cornerRadius = 6; icon29.clipsToBounds = YES;
    [mat addSubview:icon29];
    UILabel *dl = [[[UILabel alloc] initWithFrame:CGRectInset(dark.bounds, 10, 10)] autorelease];
    dl.backgroundColor = [UIColor clearColor]; dl.numberOfLines = 0;
    dl.font = [UIFont boldSystemFontOfSize:13]; dl.textColor = RCHex(0xe6f2ec);
    dl.shadowColor = RCHexA(0, .6); dl.shadowOffset = CGSizeMake(0, -1);
    dl.text = RCL(@"Dark drawer linen");
    [dark addSubview:dl];
    [self addView:mat height:90];
    [self addNote:RCL(@"Page background: light linen (rc-linen-light.png). Without the PNG, components fall back to a solid color.")];
    [self addCaption:RCL(@"Mark without a tile (RCBrandMark)")];
    UIView *marks = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 96)] autorelease];
    UIView *darkMarks = [[[UIView alloc] initWithFrame:CGRectMake(240, 0, 72, 96)] autorelease];
    darkMarks.backgroundColor = [RCTheme linenDarkColor];
    darkMarks.layer.cornerRadius = 8; darkMarks.clipsToBounds = YES;
    [marks addSubview:darkMarks];
    struct { RCBrandMark m; BOOL grey; CGFloat x; NSString *t; } ms[] = {
        {RCBrandMarkDebossed, NO, 8, RCL(@"Debossed")}, {RCBrandMarkDebossed, YES, 82, RCL(@"Temporary")},
        {RCBrandMarkEmbossedEmerald, NO, 160, RCL(@"Emerald")}, {RCBrandMarkEmbossedWhite, NO, 244, RCL(@"White")}};
    for (int i = 0; i < 4; i++) {
        UIImageView *m = [[[UIImageView alloc] initWithImage:[RCTheme brandMarkImage:ms[i].m size:64 grey:ms[i].grey]] autorelease];
        m.frame = CGRectMake(ms[i].x, 4, 64, 64);
        m.accessibilityLabel = ms[i].t;
        m.isAccessibilityElement = YES;
        [marks addSubview:m];
        UILabel *l = [[[UILabel alloc] initWithFrame:CGRectMake(ms[i].x - 6, 72, 76, 16)] autorelease];
        l.backgroundColor = [UIColor clearColor]; l.textAlignment = NSTextAlignmentCenter;
        l.font = [UIFont boldSystemFontOfSize:11];
        BOOL onDark = ms[i].m == RCBrandMarkEmbossedWhite;
        l.textColor = onDark ? RCHex(0xe6f2ec) : [RCTheme engravedTextColor];
        l.shadowColor = onDark ? RCHexA(0, .6) : [RCTheme engravedShadowColor];
        l.shadowOffset = onDark ? CGSizeMake(0, -1) : [RCTheme engravedShadowOffset];
        l.text = ms[i].t;
        l.isAccessibilityElement = NO;
        [marks addSubview:l];
    }
    [self addView:marks height:96];
    [self addNote:RCL(@"Debossed mark: the empty chat (light or dark artwork by appearance, grey for a temporary chat). White embossed: welcome and launch on the dark linen; emerald: light backgrounds. The tile (icon) only in small headers.")];
}
@end

#pragma mark - Stock controls (UIAppearance)

@interface RCGalleryStockPage () <UIActionSheetDelegate>
@end

@implementation RCGalleryStockPage
- (id)init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped]))
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appearanceChanged) name:RCThemeAppearanceDidChangeNotification object:nil];
    return self;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; [super dealloc]; }
- (void)appearanceChanged { if (self.isViewLoaded) { [RCTheme styleGroupedTableView:self.tableView]; [self.tableView reloadData]; } }

- (void)viewDidLoad {
    [super viewDidLoad];
    [RCTheme styleGroupedTableView:self.tableView];
    self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:
        [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:nil action:nil] autorelease],
        RCGlyphItem(@"compose", nil, nil), nil];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.toolbarItems = [NSArray arrayWithObjects:
        RCGlyphItem(@"share", nil, nil),
        [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease],
        [[[UIBarButtonItem alloc] initWithTitle:RCL(@"Translate") style:UIBarButtonItemStyleBordered target:nil action:nil] autorelease],
        [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease],
        RCGlyphItem(@"trash", nil, nil), nil];
    [self.navigationController setToolbarHidden:NO animated:animated];
}
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [self.navigationController setToolbarHidden:YES animated:animated]; }

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 4; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return s == 0 ? 2 : (s == 1 ? 4 : 3); }
- (UIView *)tableView:(UITableView *)tv viewForHeaderInSection:(NSInteger)s {
    NSArray *t = [NSArray arrayWithObjects:@"UISwitch", RCL(@"Cells and selection"), @"UISegmentedControl · UIProgressView · UISlider", RCL(@"System sheets and alerts"), nil];
    return [RCTheme groupedHeaderViewWithTitle:[t objectAtIndex:(NSUInteger)s] width:tv.bounds.size.width];
}
- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)s { return 44; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil] autorelease];
    NSInteger s = ip.section, r = ip.row;
    if (s == 0) {
        c.textLabel.text = r == 0 ? RCL(@"Temporary chat") : RCL(@"Read answers aloud");
        if (r == 0) c.imageView.image = [RCGlyph imageNamed:@"ghost" size:20 color:[RCTheme engravedTextColor]];
        UISwitch *sw = [[[UISwitch alloc] init] autorelease];
        sw.on = r == 0;
        c.accessoryView = sw;
        c.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (s == 1) {
        NSArray *t = [NSArray arrayWithObjects:RCL(@"Model"), RCL(@"Text size"), RCL(@"Medium"), RCL(@"Log out"), nil];
        c.textLabel.text = [t objectAtIndex:(NSUInteger)r];
        if (r == 0) { c.detailTextLabel.text = @"GPT-5"; c.accessoryType = UITableViewCellAccessoryDisclosureIndicator; }
        if (r == 1) { c.detailTextLabel.text = @"M"; c.accessoryType = UITableViewCellAccessoryDisclosureIndicator; }
        if (r == 2) { c.accessoryView = [RCTheme checkmarkAccessoryView]; c.accessibilityTraits |= UIAccessibilityTraitSelected; }
        if (r == 3) { c.textLabel.textAlignment = NSTextAlignmentCenter; }
    } else if (s == 2) {
        c.selectionStyle = UITableViewCellSelectionStyleNone;
        if (r == 0) {
            UISegmentedControl *seg = [[[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:RCL(@"Light"), RCL(@"Dark"), RCL(@"Auto"), nil]] autorelease];
            seg.segmentedControlStyle = UISegmentedControlStyleBar;
            seg.selectedSegmentIndex = 0;
            seg.frame = CGRectMake(10, 7, 280, 30);
            seg.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            [c.contentView addSubview:seg];
        } else if (r == 1) {
            UIProgressView *p = [[[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar] autorelease];
            p.frame = CGRectMake(14, 18, 270, 9);
            p.progress = .6;
            [c.contentView addSubview:p];
        } else {
            UISlider *sl = [[[UISlider alloc] initWithFrame:CGRectMake(14, 7, 270, 30)] autorelease];
            sl.value = .5;
            [c.contentView addSubview:sl];
        }
    } else {
        NSArray *t = [NSArray arrayWithObjects:@"UIAlertView", @"UIActionSheet", @"UIActivityIndicatorView", nil];
        c.textLabel.text = [t objectAtIndex:(NSUInteger)r];
        if (r == 2) {
            UIActivityIndicatorView *ai = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray] autorelease];
            [ai startAnimating];
            c.accessoryView = ai;
        }
    }
    [RCTheme styleGroupedCell:c position:[RCTheme positionForRow:r count:[self tableView:tv numberOfRowsInSection:s]]];
    if (s == 1 && r == 3) c.textLabel.textColor = RCHex(0xc42515);
    return c;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section != 3) return;
    if (ip.row == 0) {
        UIAlertView *a = [[[UIAlertView alloc] initWithTitle:RCL(@"Replace attachment?") message:RCL(@"You can attach up to 4 files to a message. Replace the last one?") delegate:nil cancelButtonTitle:RCL(@"Cancel") otherButtonTitles:RCL(@"Replace"), nil] autorelease];
        [a show];
    } else if (ip.row == 1) {
        UIActionSheet *s = [[[UIActionSheet alloc] initWithTitle:RCL(@"Chat “Trip plan”") delegate:self cancelButtonTitle:RCL(@"Cancel") destructiveButtonTitle:RCL(@"Delete chat") otherButtonTitles:RCL(@"Pin"), RCL(@"Rename"), RCL(@"Archive"), nil] autorelease];
        [s showFromToolbar:self.navigationController.toolbar];
    }
}
- (void)actionSheet:(UIActionSheet *)s clickedButtonAtIndex:(NSInteger)i {}
@end

#pragma mark - Title and lamp

@interface RCGalleryTitlePage () <UIActionSheetDelegate> {
    NSTimer *_timer;
    RCTitleView *_preparing;
    int _left;
}
@end

@implementation RCGalleryTitlePage
- (void)dealloc { [_timer invalidate]; [_preparing release]; [super dealloc]; }
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [_timer invalidate]; _timer = nil; }

- (UIView *)lampRow:(CGFloat)d {
    UIView *row = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)] autorelease];
    RCLampState states[] = {RCLampOK, RCLampBusy, RCLampWarn, RCLampError, RCLampInfo, RCLampOff};
    for (int i = 0; i < 6; i++) {
        RCLampView *l = [[[RCLampView alloc] initWithDiameter:d] autorelease];
        l.state = states[i];
        l.center = CGPointMake(35 + i * 50, 12);
        [row addSubview:l];
        UILabel *t = [[[UILabel alloc] initWithFrame:CGRectMake(10 + i * 50, 22, 50, 14)] autorelease];
        t.backgroundColor = [UIColor clearColor];
        t.font = [UIFont boldSystemFontOfSize:10];
        t.textColor = [RCTheme metaTextColor];
        t.textAlignment = NSTextAlignmentCenter;
        t.text = [NSString stringWithFormat:@"%@ %g", [RCLampView nameForState:states[i]], d];
        [row addSubview:t];
    }
    return row;
}

- (UINavigationBar *)barWithTitle:(RCTitleView *)tv variant:(RCBarVariant)variant {
    UINavigationBar *bar = [[[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)] autorelease];
    if (variant != RCBarVariantJade) [RCTheme styleNavigationBar:bar variant:variant];
    UINavigationItem *item = [[[UINavigationItem alloc] initWithTitle:@""] autorelease];
    tv.variant = variant;
    item.titleView = tv;
    item.leftBarButtonItem = RCGlyphItem(@"menu", nil, nil);
    item.rightBarButtonItem = RCGlyphItem(@"compose", nil, nil);
    if (variant != RCBarVariantJade) {
        item.leftBarButtonItem.tintColor = [RCTheme barButtonTintForVariant:variant];
        item.rightBarButtonItem.tintColor = [RCTheme barButtonTintForVariant:variant];
    }
    [bar pushNavigationItem:item animated:NO];
    return bar;
}

- (RCTitleView *)title:(NSString *)t sub:(NSString *)s lamp:(RCLampState)l showsLamp:(BOOL)sl caret:(BOOL)c {
    RCTitleView *tv = [[[RCTitleView alloc] initWithFrame:CGRectMake(0, 0, 200, 44)] autorelease];
    tv.animatesSubtitleAppearance = YES;
    [tv setTitle:t subtitle:s lamp:l showsLamp:sl caret:c];
    return tv;
}

- (void)build {
    [self addCaption:@"RCLampView: 9 / 8 / 7 pt"];
    [self addView:[self lampRow:9] height:44];
    [self addView:[self lampRow:8] height:44];
    [self addView:[self lampRow:7] height:44];
    BOOL model = RCGalleryOn(8);
    [self addCaption:model ? RCL(@"Ready: model picker (stage 8+)") : RCL(@"Ready (stages 10–9)")];
    RCTitleView *ready = model ? [self title:RCL(@"New chat") sub:@"GPT-5" lamp:RCLampOK showsLamp:NO caret:YES]
                               : [self title:RCL(@"New chat") sub:RCL(@"Ready to send") lamp:RCLampOK showsLamp:YES caret:NO];
    if (model) [ready addTarget:self action:@selector(pickModel) forControlEvents:UIControlEventTouchUpInside];
    [self addView:[self barWithTitle:ready variant:RCBarVariantJade] height:44];
    [self addCaption:RCL(@"Preparing to send (live countdown)")];
    [_preparing release];
    _preparing = [[self title:RCL(@"New chat") sub:@"" lamp:RCLampBusy showsLamp:YES caret:NO] retain];
    _left = 42;
    [self tick];
    [_timer invalidate];
    _timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    [self addView:[self barWithTitle:_preparing variant:RCBarVariantJade] height:44];
    [self addCaption:RCL(@"No network")];
    [self addView:[self barWithTitle:[self title:RCL(@"Trip plan") sub:RCL(@"No network") lamp:RCLampError showsLamp:YES caret:NO] variant:RCBarVariantJade] height:44];
    [self addCaption:RCL(@"Single line and read-only")];
    [self addView:[self barWithTitle:[self title:RCL(@"Account") sub:nil lamp:RCLampOff showsLamp:NO caret:NO] variant:RCBarVariantJade] height:44];
    [self addSpace:8];
    [self addView:[self barWithTitle:[self title:RCL(@"Borscht recipe") sub:RCL(@"Shared conversation · read-only") lamp:RCLampOff showsLamp:NO caret:NO] variant:RCBarVariantJade] height:44];
    if (RCGalleryOn(8)) {
        [self addCaption:RCL(@"Temporary chat: graphite (stage 8+)")];
        [self addView:[self barWithTitle:[self title:RCL(@"Temporary chat") sub:@"GPT-5" lamp:RCLampOK showsLamp:NO caret:YES] variant:RCBarVariantTemporary] height:44];
    }
    [self addCaption:RCL(@"Dark variant")];
    [self addView:[self barWithTitle:[self title:RCL(@"Image") sub:nil lamp:RCLampOff showsLamp:NO caret:NO] variant:RCBarVariantDark] height:44];
    [self addNote:RCL(@"Tapping the title with ▾ opens the model picker. iOS 6 takes the status bar tint from the navigation bar.")];
}

- (void)tick {
    if (_left <= 0) {
        BOOL model = RCGalleryOn(8);
        [_preparing setTitle:RCL(@"New chat") subtitle:(model ? @"GPT-5" : RCL(@"Ready to send")) lamp:RCLampOK showsLamp:!model caret:model];
        if (_left < -2) _left = 43;
    } else {
        [_preparing setTitle:RCL(@"New chat") subtitle:[NSString stringWithFormat:RCL(@"Preparing to send… %d s"), _left] lamp:RCLampBusy showsLamp:YES caret:NO];
    }
    _left--;
}

- (void)pickModel {
    UIActionSheet *s = [[[UIActionSheet alloc] initWithTitle:RCL(@"Model") delegate:self cancelButtonTitle:RCL(@"Cancel") destructiveButtonTitle:nil otherButtonTitles:@"GPT-5", @"GPT-5 Thinking", @"GPT-4o", nil] autorelease];
    [s showInView:self.view];
}
- (void)actionSheet:(UIActionSheet *)s clickedButtonAtIndex:(NSInteger)i {}
@end

#pragma mark - Banners

@implementation RCGalleryBannerPage
- (void)build {
    [self addCaption:RCL(@"warn: session expired")];
    [self addView:[[[RCBannerView alloc] initWithKind:RCBannerBusy text:RCL(@"Thinking") actionTitle:RCL(@"Retry")] autorelease]];
    RCBannerView *b1 = [[[RCBannerView alloc] initWithKind:RCBannerWarning text:RCL(@"Session expired. Your draft and chats are safe.") actionTitle:RCL(@"Log in")] autorelease];
    [b1.actionButton addTarget:self action:@selector(signIn) forControlEvents:UIControlEventTouchUpInside];
    [self addView:b1];
    [self addCaption:RCL(@"err: no network")];
    [self addView:[[[RCBannerView alloc] initWithKind:RCBannerError text:RCL(@"No internet connection. Your draft is saved.") actionTitle:nil] autorelease]];
    [self addCaption:RCL(@"Long text")];
    [self addView:[[[RCBannerView alloc] initWithKind:RCBannerWarning text:RCL(@"The service rate-limited requests. Sending will resume automatically in 2 minutes; your draft is saved.") actionTitle:nil] autorelease]];
    [self addSpace:10];
    [self addView:[[[RCBannerView alloc] initWithKind:RCBannerError text:RCL(@"Could not refresh chat history.") actionTitle:RCL(@"Retry")] autorelease]];
}
- (void)signIn { RCGalleryAlert(RCL(@"Log in"), RCL(@"In the app, this opens the service sign-in page. The showcase never contacts the network.")); }
@end

#pragma mark - User messages

@interface RCGalleryUserMessagePage () <RCUserMessageViewDelegate, UIActionSheetDelegate>
@end

@implementation RCGalleryUserMessagePage
- (RCUserMessageView *)message:(NSString *)text delivery:(RCDeliveryState)d meta:(NSString *)meta tint:(RCBubbleTint)tint {
    RCUserMessageView *m = [[[RCUserMessageView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)] autorelease];
    m.text = text; m.delivery = d; m.metaText = meta; m.tint = tint;
    m.copyMenuEnabled = RCGalleryOn(9);
    m.editMenuEnabled = RCGalleryOn(8);
    m.delegate = self;
    return m;
}

- (void)build {
    BOOL retry = RCGalleryOn(9);
    [self addCaption:RCL(@"Sent")];
    [self addView:[self message:RCL(@"Hi! How are you?") delivery:RCDeliverySent meta:nil tint:RCBubbleGreen]];
    [self addView:[self message:RCL(@"Please make a weekend trip plan for Kazan: what to see, where to eat, and how to get from the airport.") delivery:RCDeliverySent meta:nil tint:RCBubbleGreen]];
    if (RCGalleryOn(8)) {
        [self addCaption:RCL(@"Temporary chat (stage 8+)")];
        [self addView:[self message:RCL(@"This won’t be saved in history.") delivery:RCDeliverySent meta:nil tint:RCBubbleGraphite]];
    }
    if (RCGalleryOn(8)) {
        [self addCaption:RCL(@"Attachments and versions (stage 8+)")];
        RCUserMessageView *att = [self message:RCL(@"What is in these photos?") delivery:RCDeliverySent meta:nil tint:RCBubbleGreen];
        att.attachments = [NSArray arrayWithObjects:[RCComposerAttachment attachmentWithTitle:RCL(@"Photo.jpg") glyph:nil image:RCSampleArt(0x9cbfae, 0x24453a)],
                           [RCComposerAttachment attachmentWithTitle:RCL(@"Quarterly report.pdf") glyph:@"file" image:nil], nil];
        [self addView:att];
        RCUserMessageView *only = [self message:nil delivery:RCDeliverySent meta:nil tint:RCBubbleGreen];
        only.attachments = [NSArray arrayWithObject:[RCComposerAttachment attachmentWithTitle:RCL(@"Recording 0:07") glyph:@"voice" image:nil]];
        [self addView:only];
        RCUserMessageView *ver = [self message:RCL(@"Translate to English, but keep it short") delivery:RCDeliverySent meta:nil tint:RCBubbleGreen];
        ver.pagerCount = 2; ver.pagerIndex = 1;
        [self addView:ver];
    }
    [self addCaption:RCL(@"Delivery: honest states")];
    [self addView:[self message:RCL(@"Will send as soon as connected") delivery:RCDeliveryQueued meta:RCL(@"Waiting for connection — will be sent once") tint:RCBubbleGreen]];
    [self addView:[self message:RCL(@"How much does the Moon weigh?") delivery:RCDeliverySending meta:RCL(@"Sending…") tint:RCBubbleGreen]];
    [self addView:[self message:RCL(@"Translate to English") delivery:RCDeliveryFailed meta:(retry ? RCL(@"Not sent · tap “!”") : RCL(@"Not sent · text returned to the input field")) tint:RCBubbleGreen]];
    [self addView:[self message:RCL(@"Remind me about the meeting") delivery:RCDeliveryUncertain meta:(retry ? RCL(@"Delivery not confirmed · tap “?”") : RCL(@"Delivery not confirmed")) tint:RCBubbleGreen]];
    [self addView:[self message:RCL(@"Tell a long story") delivery:RCDeliveryStopped meta:RCL(@"Answer stopped") tint:RCBubbleGreen]];
    [self addNote:retry ? RCL(@"Hold a bubble: “Copy” (stage 9+), “Edit” (stage 8+). “!” means retry is safe; “?” means connection dropped after tap, check history only.") : RCL(@"Stage 10: hold menu and retry are not present yet; unsent text returns to the input field.")];
}

- (void)userMessageViewDidTapBadge:(RCUserMessageView *)view {
    if (!RCGalleryOn(9)) return;
    UIActionSheet *s;
    if (view.delivery == RCDeliveryUncertain)
        s = [[[UIActionSheet alloc] initWithTitle:RCL(@"Connection dropped after sending. The message may have arrived.") delegate:self cancelButtonTitle:RCL(@"Cancel") destructiveButtonTitle:nil otherButtonTitles:RCL(@"Check in history"), nil] autorelease];
    else
        s = [[[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:RCL(@"Cancel") destructiveButtonTitle:RCL(@"Delete") otherButtonTitles:RCL(@"Send again"), nil] autorelease];
    [s showInView:self.view];
}
- (void)userMessageViewDidRequestEdit:(RCUserMessageView *)view { RCGalleryAlert(RCL(@"Edit"), view.text); }
- (void)userMessageViewDidTapPager:(RCUserMessageView *)view {
    view.pagerIndex = (view.pagerIndex + 1) % view.pagerCount;
    view.text = view.pagerIndex == 0 ? RCL(@"Translate to English") : RCL(@"Translate to English, but keep it short");
    [self relayout];
}
- (void)actionSheet:(UIActionSheet *)s clickedButtonAtIndex:(NSInteger)i {}
@end

#pragma mark - Answers

static NSString *kAnswerText(void) { return RCL(@"Kazan in a weekend: on Saturday — the Kremlin, Kul Sharif Mosque, and Bauman Street, and the Kazanka embankment in the evening. On Sunday — the Old Tatar Quarter and the Chak-Chak Museum.\n\nFrom the airport, the Aeroexpress is most convenient: about 25 minutes to the station."); }

@interface RCGalleryAnswerPage () <RCAnswerCardViewDelegate, RCCodeBlockViewDelegate> {
    NSTimer *_stream;
    RCAnswerCardView *_streaming;
    NSUInteger _shown;
}
@end

@implementation RCGalleryAnswerPage
- (void)dealloc { [_stream invalidate]; [_streaming release]; [super dealloc]; }
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [_stream invalidate]; _stream = nil; }

- (RCAnswerCardView *)card:(RCAnswerState)state text:(NSString *)text {
    RCAnswerCardView *c = [[[RCAnswerCardView alloc] initWithFrame:CGRectMake(0, 0, 320, 100)] autorelease];
    c.text = text;
    c.state = state;
    c.delegate = self;
    c.copyMenuEnabled = RCGalleryOn(9);
    c.selectMenuEnabled = RCGalleryOn(9);
    c.textMode = RCGalleryOn(9) ? RCAnswerTextMarkdown : RCAnswerTextPlain;
    c.copyCodeEnabled = RCGalleryOn(7);
    c.codeDelegate = self;
    c.showsReasoning = RCGalleryOn(8);
    NSUInteger actions = 0;
    if (RCGalleryOn(8)) actions |= RCAnswerActionCopy | RCAnswerActionRegenerate;
    if (RCGalleryOn(7)) actions |= RCAnswerActionSpeak | RCAnswerActionShare;
    if (RCGalleryOn(6)) actions |= RCAnswerActionMore;
    c.actionBar.actions = actions;
    return c;
}

- (void)build {
    [self addCaption:RCL(@"Completed answer")];
    RCAnswerCardView *done = [self card:RCAnswerDone text:kAnswerText()];
    if (RCGalleryOn(8)) {
        done.reasoningTitle = RCL(@"Thought for 4 s · searched the web");
        done.reasoningSteps = [NSArray arrayWithObjects:RCL(@"Searching for sights in Kazan"), RCL(@"Checking travel time from the airport"), RCL(@"Putting together a two-day plan"), nil];
        done.actionBar.sourcesCount = 3;
        done.actionBar.pagerCount = 2;
    }
    [self addView:done];
    [self addCaption:RCGalleryOn(8) ? RCL(@"Thinking: reasoning steps (stage 8+)") : RCL(@"Waiting for answer: dots")];
    RCAnswerCardView *thinking = [self card:RCAnswerThinking text:nil];
    if (RCGalleryOn(8)) {
        thinking.reasoningTitle = RCL(@"Thinking");
        thinking.reasoningSteps = [NSArray arrayWithObjects:RCL(@"Analyzing the question"), RCL(@"Searching the web"), nil];
    }
    [self addView:thinking];
    [self addCaption:RCL(@"Writing (stream, blinking cursor)")];
    [_streaming release];
    _streaming = [[self card:RCAnswerStreaming text:@""] retain];
    _shown = 0;
    [self addView:_streaming];
    [_stream invalidate];
    _stream = [NSTimer scheduledTimerWithTimeInterval:.12 target:self selector:@selector(streamTick) userInfo:nil repeats:YES];
    [self addCaption:RCL(@"Interrupted answer")];
    RCAnswerCardView *cut = [self card:RCAnswerCut text:RCL(@"Here are the first steps: install Python 3, then create a virtual environment and")];
    cut.continueAvailable = RCGalleryOn(7);
    [self addView:cut];
    [self addCaption:RCL(@"Part not shown at this stage")];
    RCAnswerCardView *part = [self card:RCAnswerDone text:RCL(@"Here is the monthly sales chart:")];
    part.partViews = [NSArray arrayWithObject:[[[RCPartPlaceholderView alloc] initWithGlyph:@"chart" tile:RCTileTeal title:RCL(@"Chart") text:nil] autorelease]];
    [self addView:part];
    [self addNote:RCL(@"Hold a card: “Copy | Select Text” (stage 9+). Action bar: copy and regenerate (8), speak and share (7), “More” (6).")];
}

- (void)streamTick {
    NSArray *words = [kAnswerText() componentsSeparatedByString:@" "];
    if (_shown >= words.count + 12) _shown = 0;
    _shown++;
    NSUInteger n = MIN(_shown, words.count);
    NSString *t = [[words subarrayWithRange:NSMakeRange(0, n)] componentsJoinedByString:@" "];
    CGFloat before = [_streaming heightForWidth:320];
    _streaming.text = t;
    if ([_streaming heightForWidth:320] != before) [self relayout];
}

- (void)answerCardDidToggleReasoning:(RCAnswerCardView *)card { [self relayout]; }
- (void)codeBlockViewDidCopy:(RCCodeBlockView *)view { RCGalleryHUD(self.view, RCL(@"Code copied")); }
- (void)answerCardDidTapContinue:(RCAnswerCardView *)card { card.text = kAnswerText(); card.state = RCAnswerDone; [self relayout]; }
- (void)answerCardDidRequestSelect:(RCAnswerCardView *)card { RCGalleryAlert(RCL(@"Select Text"), RCL(@"Opens the answer text selection screen.")); }
- (void)answerCard:(RCAnswerCardView *)card didSelectAction:(RCAnswerAction)action {
    switch (action) {
        case RCAnswerActionPager: card.actionBar.pagerIndex = (card.actionBar.pagerIndex + 1) % card.actionBar.pagerCount; break;
        case RCAnswerActionSpeak: card.actionBar.speaking = !card.actionBar.speaking; break;
        case RCAnswerActionCopy: [UIPasteboard generalPasteboard].string = card.text; RCGalleryHUD(self.view, RCL(@"Copied")); break;
        case RCAnswerActionSources: RCGalleryAlert(RCL(@"Sources"), @"kazan.travel, wikipedia.org, aeroexpress.ru"); break;
        default: RCGalleryAlert(RCL(@"Action"), [NSString stringWithFormat:@"%lu", (unsigned long)action]); break;
    }
}
@end

#pragma mark - Composer

@interface RCGalleryComposerPage () <RCComposerViewDelegate, RCActivitySheetDelegate> {
    NSMutableArray *_composers;
    NSTimer *_dictTimer;
    RCComposerView *_dictating;
    NSTimeInterval _dictElapsed;
}
@end

@implementation RCGalleryComposerPage
- (void)dealloc { [_dictTimer invalidate]; [_composers release]; [super dealloc]; }
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [_dictTimer invalidate]; _dictTimer = nil; }

- (RCComposerView *)composer {
    RCComposerView *c = [[[RCComposerView alloc] initWithFrame:CGRectMake(0, 0, 320, 46)] autorelease];
    c.showsPlus = RCGalleryOn(8);
    c.showsMic = RCGalleryOn(9);
    c.stopAvailable = RCGalleryOn(9);
    c.voiceAvailable = RCGalleryOn(8);
    c.expandAvailable = RCGalleryOn(7);
    c.delegate = self;
    if (!_composers) _composers = [[NSMutableArray alloc] init];
    [_composers addObject:c];
    return c;
}

- (void)build {
    [_composers removeAllObjects];
    [self addCaption:RCL(@"Empty field")];
    [self addView:[self composer]];
    [self addNote:RCGalleryOn(8) ? RCL(@"Empty field + voice: the voice conversation button replaces “Send”.") : RCL(@"Without voice, “Send” is simply disabled when the field is empty.")];
    [self addCaption:RCL(@"Preparing to send: lamp on “Send”")];
    RCComposerView *prep = [self composer];
    prep.text = RCL(@"How much does the Moon weigh?");
    prep.preparing = YES;
    [self addView:prep];
    [self addCaption:RCGalleryOn(9) ? RCL(@"Streaming answer: “Stop” (stage 9+)") : RCL(@"Streaming answer: send disabled")];
    RCComposerView *st = [self composer];
    st.streaming = YES;
    [self addView:st];
    [self addCaption:RCL(@"Multi-line text")];
    RCComposerView *tall = [self composer];
    tall.text = RCL(@"Make a trip plan:\n— Saturday: Kremlin, Kul Sharif\n— Sunday: Old Quarter\n— how to get from the airport");
    [self addView:tall];
    if (RCGalleryOn(8)) {
        [self addCaption:RCL(@"Mode, attachments, limit (stage 8+)")];
        RCComposerView *rich = [self composer];
        [rich setModeChipTitle:RCL(@"Search") glyph:@"globe" color:RCChipBlue];
        RCComposerAttachment *a1 = [RCComposerAttachment attachmentWithTitle:RCL(@"Photo.jpg") glyph:nil image:RCSampleArt(0x9cbfae, 0x24453a)];
        RCComposerAttachment *a2 = [RCComposerAttachment attachmentWithTitle:RCL(@"Report.pdf") glyph:@"file" image:nil];
        a2.progress = .5;
        RCComposerAttachment *a3 = [RCComposerAttachment attachmentWithTitle:RCL(@"Recording 0:07") glyph:@"voice" image:nil];
        a3.failed = YES;
        rich.attachments = [NSArray arrayWithObjects:a1, a2, a3, nil];
        rich.trayNote = RCL(@"Today’s upload limit is reached — resets at 18:40. You can send text without the attachment.");
        rich.text = RCL(@"What is in the photo?");
        [self addView:rich];
    }
    if (RCGalleryOn(9)) {
        [self addCaption:RCL(@"Dictation (stage 9+)")];
        RCComposerView *d1 = [self composer];
        d1.dictating = YES; d1.dictationView.elapsed = 4; d1.dictationView.cancelAvailable = RCGalleryOn(8);
        [self wireDictation:d1];
        [self addView:d1];
        if (RCGalleryOn(7)) {
            RCComposerView *d2 = [self composer];
            d2.dictating = YES; d2.dictationView.elapsed = 2; d2.dictationView.liveText = RCL(@"Tell me how to make syrniki…"); d2.dictationView.cancelAvailable = YES;
            [self wireDictation:d2];
            [self addView:d2];
        }
        RCComposerView *d3 = [self composer];
        d3.dictating = YES; d3.dictationView.state = RCDictationRecognising;
        [self addView:d3];
        if (RCGalleryOn(8)) {
            RCComposerView *d4 = [self composer];
            d4.dictating = YES; d4.dictationView.state = RCDictationFailed; d4.dictationView.cancelAvailable = YES;
            [self wireDictation:d4];
            [self addView:d4];
        }
        [self addNote:RCL(@"The microphone in any field above starts a live simulation: recording → “Recognizing…” → text in the field.")];
    }
    [self addNote:RCL(@"The field grows up to 118 pt; “⤢” appears on a tall field from stage 7. All fields are interactive: “+”, microphone, send.")];
    [self addSpace:20];
}

- (void)composerView:(RCComposerView *)view didChangeHeight:(CGFloat)height { if (self.isViewLoaded) [self relayout]; }
- (void)composerViewDidTapSend:(RCComposerView *)view { view.text = @""; view.attachments = nil; [view setModeChipTitle:nil glyph:nil color:RCChipBlue]; view.trayNote = nil; }
- (void)composerViewDidTapStop:(RCComposerView *)view { view.streaming = NO; }
- (void)composerViewDidTapVoice:(RCComposerView *)view { RCGalleryAlert(RCL(@"Turn-by-turn voice"), RCL(@"Record → answer → read aloud.")); }
- (void)wireDictation:(RCComposerView *)c {
    [c.dictationView.cancelButton addTarget:self action:@selector(dictationCancel:) forControlEvents:UIControlEventTouchUpInside];
    [c.dictationView.doneButton addTarget:self action:@selector(dictationDone:) forControlEvents:UIControlEventTouchUpInside];
}
- (RCComposerView *)composerFor:(UIView *)v { while (v && ![v isKindOfClass:[RCComposerView class]]) v = v.superview; return (RCComposerView *)v; }
- (void)composerViewDidTapMic:(RCComposerView *)view {
    view.dictating = YES;
    view.dictationView.state = RCDictationRecording;
    view.dictationView.cancelAvailable = RCGalleryOn(8);
    view.dictationView.liveText = nil;
    [self wireDictation:view];
    _dictating = view; _dictElapsed = 0;
    [_dictTimer invalidate];
    _dictTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(dictTick) userInfo:nil repeats:YES];
}
- (void)dictTick { _dictElapsed += 1; if (_dictating.dictating && _dictating.dictationView.state == RCDictationRecording) _dictating.dictationView.elapsed = _dictElapsed; }
- (void)dictationCancel:(UIButton *)b { RCComposerView *c = [self composerFor:b]; c.dictating = NO; if (c == _dictating) { [_dictTimer invalidate]; _dictTimer = nil; } }
- (void)dictationDone:(UIButton *)b {
    RCComposerView *c = [self composerFor:b];
    c.dictationView.state = RCDictationRecognising;
    [self performSelector:@selector(dictationFinish:) withObject:c afterDelay:1.1];
}
- (void)dictationFinish:(RCComposerView *)c {
    c.dictating = NO;
    c.text = [c.text.length ? [c.text stringByAppendingString:@" "] : @"" stringByAppendingString:RCL(@"Tell me how to make flourless syrniki")];
    if (c == _dictating) { [_dictTimer invalidate]; _dictTimer = nil; }
}
- (void)composerViewDidTapExpand:(RCComposerView *)view { RCGalleryAlert(RCL(@"Full-screen editor"), nil); }
- (void)composerViewDidClearMode:(RCComposerView *)view { [view setModeChipTitle:nil glyph:nil color:RCChipBlue]; }
- (void)composerView:(RCComposerView *)view didRemoveAttachmentAtIndex:(NSUInteger)index {
    NSMutableArray *a = [[view.attachments mutableCopy] autorelease];
    if (index < a.count) [a removeObjectAtIndex:index];
    view.attachments = a;
    if (!a.count) view.trayNote = nil;
}
- (void)composerViewDidTapPlus:(RCComposerView *)view {
    [view resignFirstResponder];
    RCActivitySheet *s = [[[RCActivitySheet alloc] initWithTitle:nil items:[RCGalleryActivityPage stageItems]] autorelease];
    s.delegate = self;
    [s showInView:self.view.window];
}
- (void)activitySheet:(RCActivitySheet *)sheet didSelectItemAtIndex:(NSUInteger)index {}
@end

#pragma mark - Activity sheet

@interface RCGalleryActivityPage () <RCActivitySheetDelegate> { UILabel *_result; }
@end

@implementation RCGalleryActivityPage
+ (NSArray *)stageItems {
    NSMutableArray *it = [NSMutableArray array];
    struct { NSString *t; const char *g; RCTileColor c; int u; BOOL on; } spec[] = {
        {RCL(@"Camera"), "camera", RCTileGraphite, 8, NO}, {RCL(@"Photos"), "photo", RCTileOrange, 8, NO}, {RCL(@"File"), "file", RCTileBlue, 8, NO},
        {RCL(@"From library"), "library", RCTileTeal, 7, NO}, {RCL(@"Web search"), "globe", RCTileBlue, 8, YES},
        {RCL(@"Create image"), "photo", RCTilePurple, 7, NO}, {RCL(@"Deep research"), "research", RCTileOrange, 7, NO},
        {RCL(@"Study"), "book", RCTileGreen, 7, NO}, {RCL(@"Scan"), "scan", RCTileGray, 6, NO}, {RCL(@"Audio"), "voice", RCTileRed, 6, NO},
        {RCL(@"Work"), "bag", RCTileDark, 6, NO}};
    for (unsigned i = 0; i < sizeof spec / sizeof spec[0]; i++) {
        if (!RCGalleryOn(spec[i].u)) continue;
        RCActivityItem *a = [RCActivityItem itemWithTitle:spec[i].t glyph:[NSString stringWithUTF8String:spec[i].g] tile:spec[i].c];
        a.on = spec[i].on;
        [it addObject:a];
    }
    return it;
}

- (void)dealloc { [_result release]; [super dealloc]; }

- (void)build {
    if (!RCGalleryOn(8)) {
        [self addCaption:RCL(@"Stages 10–9")];
        [self addNote:RCL(@"“+” appears from stage 8 (camera, photos, files, web search). At stages 10–9 there is nothing to the left of the input field.")];
        return;
    }
    [self addCaption:RCL(@"“+” menu for the current stage")];
    RCButton *open = [RCButton buttonWithStyle:RCButtonStyleLargeGreen title:RCL(@"Open “+”")];
    [open addTarget:self action:@selector(openPlain) forControlEvents:UIControlEventTouchUpInside];
    [self addInsetView:open height:44];
    [self addSpace:10];
    RCButton *titled = [RCButton buttonWithStyle:RCButtonStyleLarge title:RCL(@"With title")];
    [titled addTarget:self action:@selector(openTitled) forControlEvents:UIControlEventTouchUpInside];
    [self addInsetView:titled height:44];
    [self addSpace:6];
    [_result release];
    _result = [[UILabel alloc] initWithFrame:CGRectZero];
    _result.backgroundColor = [UIColor clearColor];
    _result.font = [UIFont boldSystemFontOfSize:14];
    _result.textColor = [RCTheme engravedTextColor];
    _result.textAlignment = NSTextAlignmentCenter;
    _result.text = RCL(@"Nothing selected");
    [self addView:_result height:30];
    [self addNote:RCL(@"The active mode (here “Web search”) is marked with a glowing white ring. Tapping the dim background or “Cancel” closes the menu.")];
}

- (void)show:(NSString *)title {
    RCActivitySheet *s = [[[RCActivitySheet alloc] initWithTitle:title items:[RCGalleryActivityPage stageItems]] autorelease];
    s.delegate = self;
    [s showInView:self.view.window];
}
- (void)openPlain { [self show:nil]; }
- (void)openTitled { [self show:RCL(@"Add to message")]; }
- (void)activitySheet:(RCActivitySheet *)sheet didSelectItemAtIndex:(NSUInteger)index {
    _result.text = [NSString stringWithFormat:RCL(@"Selected: %@"), [[sheet.items objectAtIndex:index] title]];
}
- (void)activitySheetDidCancel:(RCActivitySheet *)sheet { _result.text = RCL(@"Cancel"); }
@end

#pragma mark - Drawer + a screen assembled from the kit

@interface RCGalleryMiniChat : UIViewController <RCComposerViewDelegate> {
    UIScrollView *_list;
    RCComposerView *_composer;
    RCTitleView *_titleView;
}
@end

@implementation RCGalleryMiniChat
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; _composer.delegate = nil; [_list release]; [_composer release]; [_titleView release]; [super dealloc]; }

- (void)loadView {
    UIView *v = [[[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame] autorelease];
    v.backgroundColor = [RCTheme contentBackgroundColor];
    self.view = v;
    _list = [[UIScrollView alloc] initWithFrame:v.bounds];
    _list.alwaysBounceVertical = YES;
    [v addSubview:_list];
    _composer = [[RCComposerView alloc] initWithFrame:CGRectMake(0, 0, 320, 46)];
    _composer.showsPlus = RCGalleryOn(8); _composer.showsMic = RCGalleryOn(9); _composer.stopAvailable = RCGalleryOn(9);
    _composer.voiceAvailable = RCGalleryOn(8); _composer.expandAvailable = RCGalleryOn(7);
    _composer.delegate = self;
    [v addSubview:_composer];
    CGFloat y = 10;
    RCUserMessageView *u = [[[RCUserMessageView alloc] initWithFrame:CGRectZero] autorelease];
    u.text = RCL(@"Make a weekend trip plan for Kazan");
    u.frame = CGRectMake(0, y, 320, [u heightForWidth:320]);
    [_list addSubview:u];
    y += u.frame.size.height;
    RCAnswerCardView *a = [[[RCAnswerCardView alloc] initWithFrame:CGRectZero] autorelease];
    a.text = kAnswerText();
    if (RCGalleryOn(8)) a.actionBar.actions = RCAnswerActionCopy | RCAnswerActionRegenerate | (RCGalleryOn(7) ? RCAnswerActionSpeak | RCAnswerActionShare : 0);
    a.frame = CGRectMake(0, y, 320, [a heightForWidth:320]);
    [_list addSubview:a];
    _list.contentSize = CGSizeMake(320, y + a.frame.size.height + 10);
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboard:) name:UIKeyboardWillChangeFrameNotification object:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _titleView = [[RCTitleView alloc] initWithFrame:CGRectMake(0, 0, 200, 44)];
    BOOL model = RCGalleryOn(8);
    [_titleView setTitle:RCL(@"Trip plan") subtitle:(model ? @"GPT-5" : RCL(@"Ready to send")) lamp:RCLampOK showsLamp:!model caret:model];
    self.navigationItem.titleView = _titleView;
    self.navigationItem.leftBarButtonItem = RCGlyphItem(@"menu", self, @selector(menu));
    self.navigationItem.rightBarButtonItem = RCGlyphItem(@"compose", nil, nil);
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    [self layoutComposer:self.view.bounds.size.height];
}
- (void)layoutComposer:(CGFloat)bottom {
    CGFloat h = [_composer heightForWidth:320];
    _composer.frame = CGRectMake(0, bottom - h, 320, h);
    _list.frame = CGRectMake(0, 0, 320, bottom - h);
}
- (void)keyboard:(NSNotification *)n {
    CGRect kb = [self.view convertRect:[[n.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue] fromView:nil];
    CGFloat bottom = MIN(self.view.bounds.size.height, kb.origin.y);
    [UIView animateWithDuration:[[n.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue] animations:^{ [self layoutComposer:bottom]; }];
}
- (void)composerView:(RCComposerView *)view didChangeHeight:(CGFloat)height { [self layoutComposer:CGRectGetMaxY(_composer.frame)]; }
- (void)composerViewDidTapSend:(RCComposerView *)view { view.text = @""; [view resignFirstResponder]; }
- (void)menu { [self.rc_revealController toggleDrawer:nil]; }
@end

@interface RCGalleryDrawerPage () <RCDrawerControllerDelegate> { RCRevealController *_reveal; NSArray *_all; }
@end

@implementation RCGalleryDrawerPage
- (void)dealloc { [_reveal release]; [_all release]; [super dealloc]; }

- (void)build {
    [self addCaption:RCL(@"Screen assembled from components")];
    RCButton *open = [RCButton buttonWithStyle:RCButtonStyleLargeGreen title:RCL(@"Open chat with drawer")];
    [open addTarget:self action:@selector(open) forControlEvents:UIControlEventTouchUpInside];
    [self addInsetView:open height:44];
    [self addNote:RCL(@"☰ or swiping the navbar right opens the drawer; tapping or swiping the screen back closes it. “Close showcase” or the account row at the bottom returns here.")];
    [self addNote:RCGalleryOn(8) ? RCL(@"Stage 8 adds search; stage 7 adds projects and library; stage 6 adds images, GPTs, tasks, locked chats, and “Search everywhere”.") : RCL(@"Stages 10–9: “New chat” and history by date, without search.")];
}

- (NSArray *)sectionsFiltered:(NSString *)q {
    NSMutableArray *sections = [NSMutableArray array];
    for (RCDrawerSection *s in _all) {
        if (!q.length) { [sections addObject:s]; continue; }
        NSMutableArray *items = [NSMutableArray array];
        for (RCDrawerItem *i in s.items) if (i.style == RCDrawerRowChat && [i.title rangeOfString:q options:NSCaseInsensitiveSearch].location != NSNotFound) [items addObject:i];
        if (items.count) [sections addObject:[RCDrawerSection sectionWithTitle:s.title items:items]];
    }
    if (q.length && !sections.count) {
        RCDrawerSection *e = [RCDrawerSection sectionWithTitle:RCL(@"Results") items:nil];
        e.emptyText = RCL(@"Nothing found");
        [sections addObject:e];
    }
    return sections;
}

- (NSArray *)stageSections {
    NSMutableArray *nav = [NSMutableArray array];
    RCDrawerItem *newChat = [RCDrawerItem itemWithTitle:RCL(@"New chat") glyph:@"compose" style:RCDrawerRowNav];
    newChat.current = YES;
    [nav addObject:newChat];
    if (RCGalleryOn(8)) [nav addObject:[RCDrawerItem itemWithTitle:RCL(@"Translate") glyph:@"translate" style:RCDrawerRowNav]];
    if (RCGalleryOn(7)) [nav addObject:[RCDrawerItem itemWithTitle:RCL(@"Library") glyph:@"library" style:RCDrawerRowNav]];
    if (RCGalleryOn(6)) {
        [nav addObject:[RCDrawerItem itemWithTitle:RCL(@"Images") glyph:@"images" style:RCDrawerRowNav]];
        [nav addObject:[RCDrawerItem itemWithTitle:@"GPT" glyph:@"gpt" style:RCDrawerRowNav]];
        RCDrawerItem *tasks = [RCDrawerItem itemWithTitle:RCL(@"Tasks") glyph:@"clock" style:RCDrawerRowNav];
        tasks.count = @"2";
        [nav addObject:tasks];
        [nav addObject:[RCDrawerItem itemWithTitle:RCL(@"Locked chats") glyph:@"lock" style:RCDrawerRowNav]];
    }
    NSMutableArray *sections = [NSMutableArray arrayWithObject:[RCDrawerSection sectionWithTitle:nil items:nav]];
    if (RCGalleryOn(7)) {
        NSMutableArray *pr = [NSMutableArray array];
        if (RCGalleryOn(6)) [pr addObject:[RCDrawerItem itemWithTitle:RCL(@"New project") glyph:@"plus" style:RCDrawerRowSub]];
        RCDrawerItem *p1 = [RCDrawerItem itemWithTitle:RCL(@"Vacation") glyph:nil style:RCDrawerRowSub];
        p1.dotColor = RCHex(0xf3b95f); p1.count = @"3";
        RCDrawerItem *p2 = [RCDrawerItem itemWithTitle:RCL(@"Work") glyph:nil style:RCDrawerRowSub];
        p2.dotColor = RCHex(0x6ea9ef); p2.count = @"5";
        [pr addObject:p1]; [pr addObject:p2];
        [sections addObject:[RCDrawerSection sectionWithTitle:RCL(@"Projects") items:pr]];
    }
    RCDrawerItem *pinned = [RCDrawerItem itemWithTitle:RCL(@"Trip plan to Kazan") glyph:(RCGalleryOn(7) ? @"pin" : nil) style:RCDrawerRowChat];
    [sections addObject:[RCDrawerSection sectionWithTitle:RCL(@"Today") items:[NSArray arrayWithObjects:pinned,
        [RCDrawerItem itemWithTitle:RCL(@"Borscht recipe") glyph:nil style:RCDrawerRowChat],
        [RCDrawerItem itemWithTitle:RCL(@"Python: reading CSV") glyph:nil style:RCDrawerRowChat], nil]]];
    [sections addObject:[RCDrawerSection sectionWithTitle:RCL(@"Yesterday") items:[NSArray arrayWithObjects:
        [RCDrawerItem itemWithTitle:RCL(@"Email to landlord") glyph:nil style:RCDrawerRowChat],
        [RCDrawerItem itemWithTitle:RCL(@"How much does the Moon weigh") glyph:nil style:RCDrawerRowChat],
        [RCDrawerItem itemWithTitle:RCL(@"Show more") glyph:nil style:RCDrawerRowMore], nil]]];
    [sections addObject:[RCDrawerSection sectionWithTitle:RCL(@"Showcase") items:[NSArray arrayWithObject:[RCDrawerItem itemWithTitle:RCL(@"Close showcase") glyph:@"collapse" style:RCDrawerRowNav]]]];
    return sections;
}

- (void)open {
    [_all release];
    _all = [[self stageSections] retain];
    RCDrawerController *drawer = [[[RCDrawerController alloc] init] autorelease];
    drawer.showsSearch = RCGalleryOn(8);
    drawer.searchPlaceholder = RCGalleryOn(6) ? RCL(@"Search everywhere") : RCL(@"Search chats");
    drawer.accountName = RCL(@"Anna Smirnova");
    drawer.accountEmail = @"anna@example.com";
    drawer.accountInitials = RCL(@"AS");
    drawer.sections = _all;
    drawer.delegate = self;
    UINavigationController *front = [[[UINavigationController alloc] initWithRootViewController:[[[RCGalleryMiniChat alloc] init] autorelease]] autorelease];
    [_reveal release];
    _reveal = [[RCRevealController alloc] initWithFrontViewController:front drawerViewController:drawer];
    _reveal.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    [self presentViewController:_reveal animated:YES completion:nil];
}

- (void)openWithDrawer {
    [self open];
    [_reveal performSelector:@selector(toggleDrawer:) withObject:nil afterDelay:.8];
}

- (void)drawer:(RCDrawerController *)drawer didSelectItem:(RCDrawerItem *)item {
    if ([item.title isEqualToString:RCL(@"Close showcase")]) { [self dismissViewControllerAnimated:YES completion:nil]; return; }
    if (item.style == RCDrawerRowMore) { item.busy = !item.busy; [drawer.tableView reloadData]; return; }
    for (RCDrawerSection *s in _all) for (RCDrawerItem *i in s.items) i.current = i == item;
    [drawer.tableView reloadData];
    [_reveal setDrawerOpen:NO animated:YES];
}
- (void)drawer:(RCDrawerController *)drawer searchTextDidChange:(NSString *)text { drawer.sections = [self sectionsFiltered:text]; }
- (void)drawerDidTapAccount:(RCDrawerController *)drawer { [self dismissViewControllerAnimated:YES completion:nil]; }
@end

#pragma mark - Glyphs

@implementation RCGalleryGlyphPage
- (void)build {
    NSArray *names = [RCGlyph allGlyphNames];
    [self addCaption:[NSString stringWithFormat:RCL(@"Glyphs (%lu, from icons.js)"), (unsigned long)names.count]];
    NSUInteger perRow = 5, rows = (names.count + perRow - 1) / perRow;
    UIView *grid = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, rows * 58)] autorelease];
    for (NSUInteger i = 0; i < names.count; i++) {
        CGFloat x = 10 + (i % perRow) * 60, y = (i / perRow) * 58;
        UIImageView *iv = [[[UIImageView alloc] initWithImage:[RCGlyph imageNamed:[names objectAtIndex:i] size:24 color:[RCTheme answerTextColor]]] autorelease];
        iv.frame = CGRectMake(x + 18, y + 6, 24, 24);
        [grid addSubview:iv];
        UILabel *l = [[[UILabel alloc] initWithFrame:CGRectMake(x, y + 34, 60, 14)] autorelease];
        l.backgroundColor = [UIColor clearColor];
        l.font = [UIFont systemFontOfSize:9];
        l.textColor = [RCTheme metaTextColor];
        l.textAlignment = NSTextAlignmentCenter;
        l.adjustsFontSizeToFitWidth = YES;
        l.text = [names objectAtIndex:i];
        [grid addSubview:l];
    }
    [self addView:grid height:rows * 58];
    [self addCaption:RCL(@"40 pt tiles")];
    const char *tn[] = {"green", "blue", "orange", "red", "purple", "gray", "teal", "pink", "graphite", "yellow", "dark"};
    const char *tg[] = {"compose", "globe", "research", "voice", "photo", "scan", "library", "star", "camera", "bell", "bag"};
    UIView *tiles = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 3 * 64)] autorelease];
    for (int i = 0; i <= RCTileDark; i++) {
        CGFloat x = 14 + (i % 5) * 60, y = (i / 5) * 64;
        UIImageView *iv = [[[UIImageView alloc] initWithImage:[RCGlyph tileNamed:[NSString stringWithUTF8String:tg[i]] color:(RCTileColor)i size:40]] autorelease];
        iv.frame = CGRectMake(x + 10, y + 4, 40, 42);
        [tiles addSubview:iv];
        UILabel *l = [[[UILabel alloc] initWithFrame:CGRectMake(x, y + 48, 60, 14)] autorelease];
        l.backgroundColor = [UIColor clearColor];
        l.font = [UIFont systemFontOfSize:9];
        l.textColor = [RCTheme metaTextColor];
        l.textAlignment = NSTextAlignmentCenter;
        l.text = [NSString stringWithUTF8String:tn[i]];
        [tiles addSubview:l];
    }
    [self addView:tiles height:3 * 64];
    [self addCaption:RCL(@"File icons (RCFileIcon): a concrete file, not the attach action")];
    const char *fn[] = {"Report.pdf", "Letter.docx", "Budget.xlsx", "Pitch.key", "Notes.txt", "main.py", "Backup.zip", "Memo.m4a", "Clip.mov", "README", "Photo.jpg"};
    UIView *files = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 4 * 76)] autorelease];
    for (int i = 0; i < 13; i++) {
        CGFloat x = 14 + (i % 4) * 74, y = (i / 4) * 76;
        UIImage *img = i < 11 ? [RCFileIcon iconForFileName:[NSString stringWithUTF8String:fn[i]] glyph:nil photo:nil size:CGSizeMake(54, 54) failed:NO]
                              : [RCFileIcon iconForFileName:RCL(@"Photo.jpg") glyph:nil photo:RCSampleArt(0x9cbfae, 0x24453a) size:CGSizeMake(54, 54) failed:(i == 12)];
        UIImageView *iv = [[[UIImageView alloc] initWithImage:img] autorelease];
        iv.frame = CGRectMake(x + 6, y + 2, 54, 54);
        [files addSubview:iv];
        UILabel *l = [[[UILabel alloc] initWithFrame:CGRectMake(x, y + 58, 66, 14)] autorelease];
        l.backgroundColor = [UIColor clearColor];
        l.font = [UIFont systemFontOfSize:9];
        l.textColor = [RCTheme metaTextColor];
        l.textAlignment = NSTextAlignmentCenter;
        l.text = i < 11 ? [NSString stringWithUTF8String:fn[i]] : RCL(@"failed");
        [files addSubview:l];
    }
    [self addView:files height:4 * 76];
}
@end
