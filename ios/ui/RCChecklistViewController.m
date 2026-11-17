#import "RCChecklistViewController.h"
#import "RCTheme.h"

@implementation RCChecklistRow
@synthesize title = _title, detail = _detail, checked = _checked, identifier = _identifier;
+ (RCChecklistRow *)rowWithTitle:(NSString *)title detail:(NSString *)detail checked:(BOOL)checked {
    RCChecklistRow *r = [[[self alloc] init] autorelease];
    r.title = title; r.detail = detail; r.checked = checked;
    return r;
}
- (void)dealloc { [_title release]; [_detail release]; [_identifier release]; [super dealloc]; }
@end

@implementation RCChecklistSection
@synthesize title = _title, rows = _rows;
+ (RCChecklistSection *)sectionWithTitle:(NSString *)title rows:(NSArray *)rows {
    RCChecklistSection *s = [[[self alloc] init] autorelease];
    s.title = title; s.rows = rows;
    return s;
}
- (void)dealloc { [_title release]; [_rows release]; [super dealloc]; }
@end

// Metrics follow the text size: rows bold body + 1 pt (17 pt at the default step, the
// iOS 6 grouped cell), second line and footer body − 2 pt (14 pt at the default step).
static UIFont *RCChecklistTitleFont(void) { return [UIFont boldSystemFontOfSize:[RCTheme bodyFont].pointSize + 1]; }
static UIFont *RCChecklistDetailFont(void) { return [UIFont systemFontOfSize:[RCTheme bodyFont].pointSize - 2]; }
static const CGFloat kRCChecklistFooterInset = 20, kRCChecklistFooterTop = 6, kRCChecklistFooterBottom = 10;

@interface RCChecklistViewController () { NSArray *_sections; NSString *_footerText, *_busyLabel; BOOL _busy; id<RCChecklistDelegate> _delegate; UIBarButtonItem *_savedItem; }
@end

@implementation RCChecklistViewController
@synthesize delegate = _delegate, sections = _sections, footerText = _footerText, busy = _busy, busyAccessibilityLabel = _busyLabel;

- (id)init { return [self initWithStyle:UITableViewStyleGrouped]; }
- (id)initWithStyle:(UITableViewStyle)style {
    (void)style;
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) { _sections = [[NSArray alloc] init]; }
    return self;
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _delegate = nil; [_sections release]; [_footerText release]; [_busyLabel release]; [_savedItem release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [RCTheme styleGroupedTableView:self.tableView];
    NSNotificationCenter *n = [NSNotificationCenter defaultCenter];
    [n addObserver:self selector:@selector(looksChanged:) name:RCThemeAppearanceDidChangeNotification object:nil];
    [n addObserver:self selector:@selector(looksChanged:) name:RCThemeTextSizeDidChangeNotification object:nil];
    [self renderBusy];
}
- (void)looksChanged:(NSNotification *)n { (void)n; if (!self.isViewLoaded) return; [RCTheme styleGroupedTableView:self.tableView]; [self.tableView reloadData]; }

- (void)setSections:(NSArray *)sections {
    NSArray *s = [(sections ? sections : [NSArray array]) copy];
    [_sections release]; _sections = s;
    if (self.isViewLoaded) [self.tableView reloadData];
}
- (void)setFooterText:(NSString *)text {
    NSString *t = [text copy];
    [_footerText release]; _footerText = t;
    if (self.isViewLoaded) [self.tableView reloadData];
}
- (void)setBusyAccessibilityLabel:(NSString *)label {
    NSString *l = [label copy];
    [_busyLabel release]; _busyLabel = l;
    if (self.isViewLoaded) [self renderBusy];
}
- (void)setBusy:(BOOL)busy {
    if (busy == _busy) return;
    _busy = busy;
    if (self.isViewLoaded) { [self renderBusy]; [self.tableView reloadData]; }
}
- (void)renderBusy {
    self.tableView.userInteractionEnabled = !_busy;
    if (!_busy) {
        if ([self.navigationItem.rightBarButtonItem.customView isKindOfClass:[UIActivityIndicatorView class]]) self.navigationItem.rightBarButtonItem = _savedItem;
        [_savedItem release]; _savedItem = nil;
        return;
    }
    if (![self.navigationItem.rightBarButtonItem.customView isKindOfClass:[UIActivityIndicatorView class]]) {
        [_savedItem release]; _savedItem = [self.navigationItem.rightBarButtonItem retain];
    }
    UIActivityIndicatorView *spin = (UIActivityIndicatorView *)self.navigationItem.rightBarButtonItem.customView;
    if (![spin isKindOfClass:[UIActivityIndicatorView class]]) {
        spin = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite] autorelease];
        [spin startAnimating];
        self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithCustomView:spin] autorelease];
    }
    spin.accessibilityLabel = _busyLabel.length ? _busyLabel : RCL(@"Please wait…");
}

- (RCChecklistSection *)sectionAt:(NSInteger)s { return (s >= 0 && (NSUInteger)s < _sections.count) ? [_sections objectAtIndex:(NSUInteger)s] : nil; }
- (RCChecklistRow *)rowAt:(NSIndexPath *)p {
    NSArray *rows = [self sectionAt:p.section].rows;
    return (p.row >= 0 && (NSUInteger)p.row < rows.count) ? [rows objectAtIndex:(NSUInteger)p.row] : nil;
}
- (BOOL)isLastSection:(NSInteger)s { return (NSUInteger)s + 1 == _sections.count; }

- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { (void)t; return (NSInteger)_sections.count; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { (void)t; return (NSInteger)[self sectionAt:s].rows.count; }

- (UIView *)tableView:(UITableView *)t viewForHeaderInSection:(NSInteger)s {
    NSString *title = [self sectionAt:s].title;
    if (!title.length) return nil;
    UIView *v = [RCTheme groupedHeaderViewWithTitle:title width:(t.bounds.size.width ? t.bounds.size.width : 320)];
    for (UIView *l in v.subviews) l.accessibilityTraits = UIAccessibilityTraitHeader;
    return v;
}
- (CGFloat)tableView:(UITableView *)t heightForHeaderInSection:(NSInteger)s { (void)t; return [self sectionAt:s].title.length ? 44 : 10; }

- (UIFont *)footerFont { return RCChecklistDetailFont(); }
- (CGFloat)footerTextHeight:(UITableView *)t {
    return RCMeasureText(_footerText, [self footerFont], (t.bounds.size.width ? t.bounds.size.width : 320) - 2 * kRCChecklistFooterInset).height;
}
- (UIView *)tableView:(UITableView *)t viewForFooterInSection:(NSInteger)s {
    if (![self isLastSection:s] || !_footerText.length) return nil;
    CGFloat w = t.bounds.size.width ? t.bounds.size.width : 320, h = [self footerTextHeight:t];
    UIView *v = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h + kRCChecklistFooterTop + kRCChecklistFooterBottom)] autorelease];
    UILabel *l = [[[UILabel alloc] initWithFrame:CGRectMake(kRCChecklistFooterInset, kRCChecklistFooterTop, w - 2 * kRCChecklistFooterInset, h)] autorelease];
    l.backgroundColor = [UIColor clearColor]; l.font = [self footerFont]; l.numberOfLines = 0; l.textAlignment = NSTextAlignmentCenter;
    l.textColor = [RCTheme noteTextColor]; l.shadowColor = [RCTheme engravedShadowColor]; l.shadowOffset = [RCTheme engravedShadowOffset];
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    RCLabelSetText(l, _footerText);
    [v addSubview:l];
    return v;
}
- (CGFloat)tableView:(UITableView *)t heightForFooterInSection:(NSInteger)s {
    if (![self isLastSection:s] || !_footerText.length) return 1;
    return [self footerTextHeight:t] + kRCChecklistFooterTop + kRCChecklistFooterBottom;
}

- (CGFloat)tableView:(UITableView *)t heightForRowAtIndexPath:(NSIndexPath *)p {
    (void)t;
    CGFloat h = RCChecklistTitleFont().lineHeight + 20;
    if ([self rowAt:p].detail.length) h += RCChecklistDetailFont().lineHeight + 1;
    return MAX(44, ceil(h));
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p {
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:@"RCChecklistRow"];
    if (!c) c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"RCChecklistRow"] autorelease];
    RCChecklistRow *row = [self rowAt:p];
    [RCTheme styleGroupedCell:c position:[RCTheme positionForRow:p.row count:(NSInteger)[self sectionAt:p.section].rows.count]];
    c.textLabel.font = RCChecklistTitleFont(); c.textLabel.lineBreakMode = NSLineBreakByTruncatingTail; c.textLabel.backgroundColor = [UIColor clearColor];
    c.detailTextLabel.font = RCChecklistDetailFont(); c.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingTail; c.detailTextLabel.backgroundColor = [UIColor clearColor];
    c.textLabel.text = row.title;
    c.detailTextLabel.text = row.detail.length ? row.detail : nil;
    c.accessoryView = row.checked ? [RCTheme checkmarkAccessoryView] : nil;
    c.isAccessibilityElement = YES;
    c.accessibilityLabel = row.title;
    c.accessibilityValue = row.detail.length ? row.detail : nil;
    c.accessibilityTraits = UIAccessibilityTraitButton | (row.checked ? UIAccessibilityTraitSelected : 0) | (_busy ? UIAccessibilityTraitNotEnabled : 0);
    c.accessibilityIdentifier = row.identifier;
    return c;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p {
    [t deselectRowAtIndexPath:p animated:YES];
    if (_busy || ![self rowAt:p]) return;
    NSUInteger section = (NSUInteger)p.section, row = (NSUInteger)p.row;
    id<RCChecklistDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(checklist:shouldSelectRow:inSection:)] && ![d checklist:self shouldSelectRow:row inSection:section]) return;
    [d checklist:self didSelectRow:row inSection:section];
}
@end
