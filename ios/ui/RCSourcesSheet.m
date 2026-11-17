#import "RCSourcesSheet.h"
#import "RCTheme.h"

NSString *RCSourcesCountTitle(NSUInteger n) {
    NSUInteger m10 = n % 10, m100 = n % 100;
    NSString *w = (m10 == 1 && m100 != 11) ? RCL(@"source") : (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) ? [RCL(@"sources (2–4)") stringByReplacingOccurrencesOfString:@" (2–4)" withString:@""] : RCL(@"sources");
    return [NSString stringWithFormat:@"%d %@", (int)n, w];
}

@implementation RCSourceItem
@synthesize title = _title, host = _host, URL = _URL, icon = _icon;
+ (id)sourceWithTitle:(NSString *)title host:(NSString *)host URL:(NSURL *)url {
    RCSourceItem *s = [[[self alloc] init] autorelease];
    s.title = title; s.URL = url; s.host = host.length ? host : url.host;
    return s;
}
- (void)dealloc { [_title release]; [_host release]; [_URL release]; [_icon release]; [super dealloc]; }
@end

static const unsigned RCSourceTileColors[6][2] = {{0x8fb8e6, 0x2d6fb8}, {0x7fdcab, 0x1e9656}, {0xf5b46a, 0xd06a10}, {0xc6a1e6, 0x7a45b0}, {0xa9b6af, 0x5f6f67}, {0x79d3d6, 0x15868a}};

@implementation RCSourceRowView {
    UILabel *_num, *_title, *_host;
    UIImageView *_tile;
}
@synthesize source = _source, number = _number, followsAppearance = _follows;

+ (UIImage *)tileForSource:(RCSourceItem *)s {
    NSString *host = s.host ? s.host : @"";
    if ([host hasPrefix:@"www."]) host = [host substringFromIndex:4];
    NSString *initial = host.length ? [[host substringWithRange:[host rangeOfComposedCharacterSequenceAtIndex:0]] uppercaseString] : @"•";
    UIImage *icon = s.icon;
    NSUInteger hash = 0; for (NSUInteger i = 0; i < host.length; i++) hash = hash * 31 + [host characterAtIndex:i];
    const unsigned *c = RCSourceTileColors[hash % 6];
    NSString *key = icon ? nil : [NSString stringWithFormat:@"src-tile-%@-%u", initial, (unsigned)(hash % 6)];
    void (^draw)(CGContextRef, CGRect) = ^(CGContextRef ctx, CGRect r) {
        CGPathRef p = RCCreateRoundedRectPath(CGRectInset(r, .5, .5), 6);
        CGContextSaveGState(ctx); CGContextAddPath(ctx, p); CGContextClip(ctx);
        if (icon) { CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor); CGContextFillRect(ctx, r); [icon drawInRect:CGRectInset(r, 4, 4)]; }
        else {
            RCDrawVerticalGradient(ctx, r, [NSArray arrayWithObjects:RCHex(c[0]), RCHex(c[1]), nil], nil);
            CGContextSetFillColorWithColor(ctx, RCHexA(0xffffff, .25).CGColor); CGContextFillRect(ctx, CGRectMake(0, 0, r.size.width, r.size.height / 2));
            UIFont *f = [UIFont boldSystemFontOfSize:15]; CGSize ts = [initial sizeWithFont:f];
            CGContextSetShadowWithColor(ctx, CGSizeMake(0, -1), 0, RCHexA(0, .3).CGColor);
            [[UIColor whiteColor] set];
            [initial drawAtPoint:CGPointMake(round((r.size.width - ts.width) / 2), round((r.size.height - ts.height) / 2)) withFont:f];
        }
        CGContextRestoreGState(ctx);
        CGContextAddPath(ctx, p); CGContextSetStrokeColorWithColor(ctx, RCHexA(0, .2).CGColor); CGContextStrokePath(ctx);
        CGPathRelease(p);
    };
    if (key) return [RCTheme imageForKey:key size:CGSizeMake(29, 29) capInsets:UIEdgeInsetsZero drawing:draw];
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(29, 29), NO, 0);
    draw(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, 29, 29));
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

static UILabel *RCSrcLabel(UIFont *f) { UILabel *l = [[UILabel alloc] initWithFrame:CGRectZero]; l.backgroundColor = [UIColor clearColor]; l.font = f; return l; }

- (id)initWithSource:(RCSourceItem *)source number:(NSUInteger)number {
    if ((self = [super initWithFrame:CGRectMake(0, 0, 300, 52)])) {
        self.backgroundColor = [UIColor clearColor];
        _tile = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 29, 29)];
        _num = RCSrcLabel([UIFont systemFontOfSize:15]);
        _title = RCSrcLabel([UIFont boldSystemFontOfSize:15]);
        _host = RCSrcLabel([UIFont systemFontOfSize:13]);
        _num.textColor = RCHex(0x6b7a72);
        _host.lineBreakMode = NSLineBreakByTruncatingMiddle;
        for (UIView *v in [NSArray arrayWithObjects:_tile, _num, _title, _host, nil]) { v.userInteractionEnabled = NO; [self addSubview:v]; }
        self.isAccessibilityElement = YES;
        self.accessibilityTraits = UIAccessibilityTraitLink;
        _number = number;
        _follows = YES;
        self.source = source;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh) name:RCThemeAppearanceDidChangeNotification object:nil];
    }
    return self;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; [_tile release]; [_num release]; [_title release]; [_host release]; [_source release]; [super dealloc]; }

- (void)refresh {
    _title.textColor = _follows ? [RCTheme answerTextColor] : [RCTheme inkColor];
    _host.textColor = _follows ? [RCTheme answerSecondaryColor] : [RCTheme secondaryInkColor];
    _tile.image = [RCSourceRowView tileForSource:_source];
    _num.text = _number ? [NSString stringWithFormat:@"%d", (int)_number] : nil;
    RCLabelSetText(_title, _source.title.length ? _source.title : _source.host);
    _host.text = _source.host;
    self.accessibilityLabel = [NSString stringWithFormat:@"%@%@, %@", _number ? [NSString stringWithFormat:@"%d. ", (int)_number] : @"", _title.text ? _title.text : @"", _source.host ? _source.host : @""];
    self.accessibilityHint = RCL(@"Opens the link");
    [self setNeedsLayout];
}
- (void)setSource:(RCSourceItem *)s { [_source release]; _source = [s retain]; [self refresh]; }
- (void)setNumber:(NSUInteger)n { _number = n; [self refresh]; }
- (void)setFollowsAppearance:(BOOL)f { _follows = f; [self refresh]; }

- (CGFloat)textX { return _number ? 62 : 40; }
- (CGFloat)heightForWidth:(CGFloat)width {
    CGFloat th = RCMeasureText(_title.text, _title.font, width - [self textX]).height;
    return MAX(44, 6 + MIN(th, 38) + 17 + 6);
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width, x = [self textX];
    _num.frame = CGRectMake(0, 6, 20, 19);
    _tile.frame = CGRectMake(_number ? 22 : 0, round((self.bounds.size.height - 29) / 2), 29, 29);
    CGFloat th = MIN(RCMeasureText(_title.text, _title.font, w - x).height, 38);
    _title.frame = CGRectMake(x, 6, w - x, th);
    _host.frame = CGRectMake(x, 6 + th, w - x, 17);
}
- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; self.alpha = h ? .6 : 1; }
@end

@interface RCSourcesSheet () { NSMutableArray *_rows; }
@end

@implementation RCSourcesSheet
@synthesize sources = _sources, footer = _footer, delegate = _delegate;

+ (UINavigationController *)navigationControllerWithSources:(NSArray *)sources delegate:(id<RCSourcesSheetDelegate>)delegate {
    RCSourcesSheet *s = [[[self alloc] initWithSources:sources] autorelease];
    s.delegate = delegate;
    UINavigationController *nav = [[[UINavigationController alloc] initWithRootViewController:s] autorelease];
    [RCTheme styleNavigationBar:nav.navigationBar variant:RCBarVariantJade];
    return nav;
}

- (id)initWithSources:(NSArray *)sources {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        _sources = [sources copy];
        _footer = nil;
        _rows = [[NSMutableArray alloc] init];
        self.title = RCL(@"Sources");
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeChanged) name:RCThemeAppearanceDidChangeNotification object:nil];
    }
    return self;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; [_sources release]; [_footer release]; [_rows release]; [super dealloc]; }

- (void)themeChanged { [RCTheme styleGroupedTableView:self.tableView]; [self.tableView reloadData]; }

- (void)viewDidLoad {
    [super viewDidLoad];
    [RCTheme styleGroupedTableView:self.tableView];
    [self buildRows];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:RCL(@"Done") style:UIBarButtonItemStyleDone target:self action:@selector(done)] autorelease];
}

- (void)buildRows {
    [_rows removeAllObjects];
    for (NSUInteger i = 0; i < _sources.count; i++) { RCSourceRowView *r = [[[RCSourceRowView alloc] initWithSource:[_sources objectAtIndex:i] number:i + 1] autorelease]; r.followsAppearance = NO; [_rows addObject:r]; }
    [self.tableView reloadData];
}
- (void)setSources:(NSArray *)s { [_sources release]; _sources = [s copy]; [self buildRows]; }

- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return 1; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return (NSInteger)_rows.count; }
- (UIView *)tableView:(UITableView *)t viewForHeaderInSection:(NSInteger)s { return [RCTheme groupedHeaderViewWithTitle:RCSourcesCountTitle(_sources.count) width:t.bounds.size.width]; }
- (CGFloat)tableView:(UITableView *)t heightForHeaderInSection:(NSInteger)s { return 44; }
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s { return _footer; }
- (CGFloat)tableView:(UITableView *)t heightForRowAtIndexPath:(NSIndexPath *)ip {
    return [(RCSourceRowView *)[_rows objectAtIndex:(NSUInteger)ip.row] heightForWidth:t.bounds.size.width - 20 - 24] + 6;
}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil] autorelease];
    [RCTheme styleGroupedCell:c position:[RCTheme positionForRow:ip.row count:(NSInteger)_rows.count]];
    RCSourceRowView *row = [_rows objectAtIndex:(NSUInteger)ip.row];
    [row removeFromSuperview];
    row.userInteractionEnabled = NO;
    row.frame = CGRectMake(12, 3, c.contentView.bounds.size.width - 24, [self tableView:t heightForRowAtIndexPath:ip] - 6);
    row.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [c.contentView addSubview:row];
    c.isAccessibilityElement = YES;
    c.accessibilityLabel = row.accessibilityLabel;
    c.accessibilityHint = row.accessibilityHint;
    c.accessibilityTraits = UIAccessibilityTraitLink;
    return c;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    [_delegate sourcesSheet:self didSelectSource:[_sources objectAtIndex:(NSUInteger)ip.row]];
}

- (void)done {
    if ([_delegate respondsToSelector:@selector(sourcesSheetDidFinish:)]) [_delegate sourcesSheetDidFinish:self];
    else [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}
@end
