#import "RCGallery.h"
#import "RCGalleryDemos.h"
#import "RCTheme.h"
#import "RCGlyph.h"
#import "RCStage.h"

@interface RCGalleryViewController : UITableViewController {
@public
    NSArray *_sections;
@private
    UISegmentedControl *_stage, *_size, *_look;
    NSMutableArray *_engraved;
}
@end

@implementation RCGalleryViewController

- (id)init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        self.title = RCL(@"Components");
        NSArray *base = [NSArray arrayWithObjects:
                         [NSArray arrayWithObjects:RCL(@"Theme and buttons"), RCL(@"colors, linen, RCButton"), @"RCGalleryThemePage", nil],
                         [NSArray arrayWithObjects:RCL(@"System controls"), RCL(@"UIAppearance: bars, UISwitch, tables"), @"RCGalleryStockPage", nil],
                         [NSArray arrayWithObjects:RCL(@"Glyphs and tiles"), RCL(@"RCGlyph from the prototype"), @"RCGalleryGlyphPage", nil],
                         [NSArray arrayWithObjects:RCL(@"HUD and progress"), @"RCHUD, RCProgressView", @"RCGalleryHUDPage", nil], nil];
        NSArray *nav = [NSArray arrayWithObjects:
                        [NSArray arrayWithObjects:RCL(@"Title and lamp"), @"RCTitleView, RCLampView", @"RCGalleryTitlePage", nil],
                        [NSArray arrayWithObjects:RCL(@"Banners"), @"RCBannerView: warn, err", @"RCGalleryBannerPage", nil],
                        [NSArray arrayWithObjects:RCL(@"Side drawer"), @"RCRevealController + RCDrawerController", @"RCGalleryDrawerPage", nil], nil];
        NSArray *chat = [NSArray arrayWithObjects:
                         [NSArray arrayWithObjects:RCL(@"Empty chat"), @"RCEmptyChatView", @"RCGalleryEmptyPage", nil],
                         [NSArray arrayWithObjects:RCL(@"User messages"), RCL(@"RCUserMessageView: bubble, attachments, versions"), @"RCGalleryUserMessagePage", nil],
                         [NSArray arrayWithObjects:RCL(@"Answers"), @"RCAnswerCardView, RCActionBar", @"RCGalleryAnswerPage", nil],
                         [NSArray arrayWithObjects:RCL(@"Markdown and code"), @"RCMarkdownView, RCCodeBlockView", @"RCGalleryMarkdownPage", nil],
                         [NSArray arrayWithObjects:RCL(@"Answer parts"), RCL(@"image, chart, research, email…"), @"RCGalleryPartsPage", nil],
                         [NSArray arrayWithObjects:RCL(@"Composer"), @"RCComposerView, RCDictationView", @"RCGalleryComposerPage", nil],
                         [NSArray arrayWithObjects:RCL(@"“+” menu"), @"RCActivitySheet", @"RCGalleryActivityPage", nil],
                         [NSArray arrayWithObjects:RCL(@"Cancel, failure, attachments (API 8)"), RCL(@"RCDictationView, RCComposerView: new properties"), @"RCGalleryPriority8Page", nil],
                         [NSArray arrayWithObjects:RCL(@"Model choice"), RCL(@"RCChecklistViewController: family, mode, effort"), @"RCGalleryChecklistPage", nil],
                         [NSArray arrayWithObjects:RCL(@"Settings form (API 7)"), RCL(@"RCFormViewController: values, input, choice"), @"RCGalleryFormPage", nil],
                         [NSArray arrayWithObjects:RCL(@"Player, questions, link (API 7)"), RCL(@"RCPlaybackView, RCClarifyPartView, RCShareLinkSheet"), @"RCGalleryPriority7Page", nil],
                         [NSArray arrayWithObjects:RCL(@"Codex: task history"), RCL(@"terminal, files, permission, diff (Codex tier 1)"), @"RCGalleryCodexPage", nil],
                         [NSArray arrayWithObjects:RCL(@"Codex: tier 2"), RCL(@"plan, network, MCP, review, connections, model"), @"RCGalleryCodexTwoPage", nil],
                         [NSArray arrayWithObjects:RCL(@"Codex: tier 3"), RCL(@"goal, subagents, hooks, settings, files, archive"), @"RCGalleryCodexThreePage", nil], nil];
        NSArray *shells = [NSArray arrayWithObjects:
                           [NSArray arrayWithObjects:RCL(@"Small controls"), RCL(@"text size, segments, account, swipe"), @"RCGalleryControlsPage", nil],
                           [NSArray arrayWithObjects:RCL(@"Welcome and sign-in"), @"RCWelcomeViewController, RCWebFrameController", @"RCGalleryWelcomePage", nil],
                           [NSArray arrayWithObjects:RCL(@"“Select Text”"), @"RCSelectTextViewController", @"RCGallerySelectPage", nil],
                           [NSArray arrayWithObjects:RCL(@"Sources and share link"), @"RCSourcesSheet, RCShareLinkSheet", @"RCGallerySheetsPage", nil],
                           [NSArray arrayWithObjects:RCL(@"Voice"), RCL(@"RCVoiceViewController: orb"), @"RCGalleryVoicePage", nil],
                           [NSArray arrayWithObjects:RCL(@"Translate"), @"RCTranslateViewController", @"RCGalleryTranslatePage", nil],
                           [NSArray arrayWithObjects:RCL(@"Image viewer and scanner"), @"RCImageViewerController, RCScannerViewController", @"RCGalleryMediaPage", nil],
                           [NSArray arrayWithObjects:RCL(@"Grids"), RCL(@"RCGridViewController: images, GPTs, library"), @"RCGalleryGridsPage", nil],
                           [NSArray arrayWithObjects:RCL(@"Research report"), @"RCReportViewController", @"RCGalleryReportPage", nil],
                           [NSArray arrayWithObjects:RCL(@"Locked chats PIN"), @"RCPINViewController", @"RCGalleryPINPage", nil], nil];
        _sections = [[NSArray alloc] initWithObjects:
                     [NSArray arrayWithObjects:RCL(@"Foundation"), base, nil],
                     [NSArray arrayWithObjects:RCL(@"Navigation"), nav, nil],
                     [NSArray arrayWithObjects:RCL(@"Chat"), chat, nil],
                     [NSArray arrayWithObjects:RCL(@"Screens"), shells, nil], nil];
    }
    return self;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; [_sections release]; [_stage release]; [_size release]; [_look release]; [_engraved release]; [super dealloc]; }

- (UILabel *)engraved:(NSString *)text frame:(CGRect)f {
    UILabel *l = [[[UILabel alloc] initWithFrame:f] autorelease];
    l.backgroundColor = [UIColor clearColor];
    l.font = [UIFont boldSystemFontOfSize:14];
    l.text = text;
    if (!_engraved) _engraved = [[NSMutableArray alloc] init];
    [_engraved addObject:l];
    [self styleEngraved:l];
    return l;
}

- (void)styleEngraved:(UILabel *)l {
    l.textColor = [RCTheme engravedTextColor];
    l.shadowColor = [RCTheme engravedShadowColor];
    l.shadowOffset = [RCTheme engravedShadowOffset];
}

- (void)appearanceChanged {
    if (!self.isViewLoaded) return;
    [RCTheme styleGroupedTableView:self.tableView];
    for (UILabel *l in _engraved) [self styleEngraved:l];
    _look.selectedSegmentIndex = [RCTheme appearance];
    [self.tableView reloadData];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [RCTheme styleGroupedTableView:self.tableView];
    UIView *h = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 112)] autorelease];
    [h addSubview:[self engraved:RCL(@"Stage (feature usefulness)") frame:CGRectMake(20, 10, 280, 18)]];
    _stage = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"10", @"9", @"8", @"7", @"6", nil]];
    _stage.segmentedControlStyle = UISegmentedControlStyleBar;
    _stage.frame = CGRectMake(10, 30, 300, 30);
    _stage.selectedSegmentIndex = 10 - RCGalleryStage();
    [_stage addTarget:self action:@selector(stageChanged) forControlEvents:UIControlEventValueChanged];
    [h addSubview:_stage];
    [h addSubview:[self engraved:RCL(@"Answer text size") frame:CGRectMake(20, 64, 280, 18)]];
    _size = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"XS", @"S", @"M", @"L", @"XL", nil]];
    _size.segmentedControlStyle = UISegmentedControlStyleBar;
    _size.frame = CGRectMake(10, 84, 300, 30);
    _size.selectedSegmentIndex = [RCTheme textSize];
    [_size addTarget:self action:@selector(sizeChanged) forControlEvents:UIControlEventValueChanged];
    [h addSubview:_size];
    [h addSubview:[self engraved:RCL(@"Appearance (stage 7+)") frame:CGRectMake(20, 118, 280, 18)]];
    _look = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:RCL(@"Light"), RCL(@"Dark"), nil]];
    _look.segmentedControlStyle = UISegmentedControlStyleBar;
    _look.frame = CGRectMake(10, 138, 300, 30);
    _look.selectedSegmentIndex = [RCTheme appearance];
    [_look addTarget:self action:@selector(lookChanged) forControlEvents:UIControlEventValueChanged];
    [h addSubview:_look];
    h.frame = CGRectMake(0, 0, 320, 176);
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appearanceChanged) name:RCThemeAppearanceDidChangeNotification object:nil];
    self.tableView.tableHeaderView = h;
    UIView *f = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 70)] autorelease];
    UILabel *note = [self engraved:RCL(@"Offline showcase: no network, account or session. Build: OR6_UI_GALLERY=1.") frame:CGRectMake(20, 8, 280, 54)];
    note.font = [UIFont systemFontOfSize:13];
    note.numberOfLines = 0; note.lineBreakMode = NSLineBreakByWordWrapping;
    note.textAlignment = NSTextAlignmentCenter;
    [f addSubview:note];
    self.tableView.tableFooterView = f;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:YES animated:animated];
    _stage.selectedSegmentIndex = 10 - RCGalleryStage();
    _size.selectedSegmentIndex = [RCTheme textSize];
    _look.selectedSegmentIndex = [RCTheme appearance];
}

- (void)lookChanged { [RCTheme setAppearance:(RCAppearance)_look.selectedSegmentIndex]; }
- (void)stageChanged { RCGallerySetStage(10 - (int)_stage.selectedSegmentIndex); }
- (void)sizeChanged { [RCTheme setTextSize:(RCTextSize)_size.selectedSegmentIndex]; }

- (NSArray *)rowsIn:(NSInteger)s { return [[_sections objectAtIndex:(NSUInteger)s] objectAtIndex:1]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return (NSInteger)_sections.count; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return (NSInteger)[self rowsIn:s].count; }
- (UIView *)tableView:(UITableView *)tv viewForHeaderInSection:(NSInteger)s {
    return [RCTheme groupedHeaderViewWithTitle:[[_sections objectAtIndex:(NSUInteger)s] objectAtIndex:0] width:tv.bounds.size.width];
}
- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)s { return 44; }
- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip { return 52; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"g"];
    if (!c) {
        c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"g"] autorelease];
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    NSArray *row = [[self rowsIn:ip.section] objectAtIndex:(NSUInteger)ip.row];
    c.textLabel.text = [row objectAtIndex:0];
    c.detailTextLabel.text = [row objectAtIndex:1];
    [RCTheme styleGroupedCell:c position:[RCTheme positionForRow:ip.row count:[self tableView:tv numberOfRowsInSection:ip.section]]];
    c.detailTextLabel.textColor = [RCTheme secondaryInkColor];
    return c;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    NSArray *row = [[self rowsIn:ip.section] objectAtIndex:(NSUInteger)ip.row];
    Class cls = NSClassFromString([row objectAtIndex:2]);
    UIViewController *vc = [[[cls alloc] init] autorelease];
    vc.title = [row objectAtIndex:0];
    [self.navigationController pushViewController:vc animated:YES];
}
@end

UIViewController *RCGalleryCreateRootController(void) {
    [RCTheme applyAppearance];
    RCStageRegisterDefault(8);
    RCGalleryViewController *root = [[[RCGalleryViewController alloc] init] autorelease];
    return [[[UINavigationController alloc] initWithRootViewController:root] autorelease];
}

BOOL RCGalleryOpenURL(UIViewController *root, NSURL *url) {
    if (![root isKindOfClass:[UINavigationController class]] || ![url.host isEqualToString:@"page"]) return NO;
    NSString *name = url.path.lastPathComponent;
    NSCharacterSet *bad = [[NSCharacterSet letterCharacterSet] invertedSet];
    if (!name.length || name.length > 24 || [name rangeOfCharacterFromSet:bad].location != NSNotFound) return NO;
    Class cls = NSClassFromString([NSString stringWithFormat:@"RCGallery%@Page", name]);
    if (!cls) return NO;
    int open = 0;
    CGFloat scrollY = 0;
    for (NSString *pair in [url.query componentsSeparatedByString:@"&"]) {
        NSArray *kv = [pair componentsSeparatedByString:@"="];
        if (kv.count != 2) continue;
        int v = [[kv objectAtIndex:1] intValue];
        if ([[kv objectAtIndex:0] isEqualToString:@"stage"]) RCGallerySetStage(v);
        else if ([[kv objectAtIndex:0] isEqualToString:@"size"]) [RCTheme setTextSize:(RCTextSize)MAX(0, MIN(4, v))];
        else if ([[kv objectAtIndex:0] isEqualToString:@"open"]) open = v;
        else if ([[kv objectAtIndex:0] isEqualToString:@"y"]) scrollY = MAX(0, v);
        else if ([[kv objectAtIndex:0] isEqualToString:@"dark"]) [RCTheme setAppearance:(v == 1 ? RCAppearanceDark : RCAppearanceLight)];
    }
    UINavigationController *nav = (UINavigationController *)root;
    [nav dismissViewControllerAnimated:NO completion:nil];
    for (UIView *v in [[nav.view.window.subviews copy] autorelease]) if ([v isKindOfClass:NSClassFromString(@"RCActivitySheet")]) [v removeFromSuperview];
    [nav popToRootViewControllerAnimated:NO];
    [nav.topViewController.view setNeedsLayout];
    UIViewController *vc = [[[cls alloc] init] autorelease];
    vc.title = name;
    RCGalleryViewController *list = [nav.viewControllers objectAtIndex:0];
    if ([list isKindOfClass:[RCGalleryViewController class]])
        for (NSArray *section in list->_sections) for (NSArray *row in [section objectAtIndex:1])
            if ([[row objectAtIndex:2] isEqualToString:NSStringFromClass(cls)]) vc.title = [row objectAtIndex:0];
    [nav pushViewController:vc animated:NO];
    if (scrollY > 0 && [vc isKindOfClass:[RCGalleryPage class]]) {
        RCGalleryPage *page = (RCGalleryPage *)vc;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIScrollView *sv = page.scrollView;
            [sv setContentOffset:CGPointMake(0, MIN(scrollY, MAX(0, sv.contentSize.height - sv.bounds.size.height))) animated:NO];
        });
    }
    SEL action = NSSelectorFromString(open == 2 ? @"openWithDrawer" : ([cls isSubclassOfClass:NSClassFromString(@"RCGalleryActivityPage")] ? @"openPlain" : @"open"));
    if (open >= 3 && [vc respondsToSelector:@selector(openVariant:)]) [vc performSelector:@selector(openVariant:) withObject:[NSNumber numberWithInt:open] afterDelay:.6]; // shell pages: open=3…9 variants
    else if (open && [vc respondsToSelector:action]) [vc performSelector:action withObject:nil afterDelay:.6];
    return YES;
}
