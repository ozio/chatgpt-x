#import "RCGridViewController.h"
#import "RCFileIcon.h"
#import "RCTheme.h"
#import "RCSegmentedControl.h"

@implementation RCGridItem
@synthesize title = _title, subtitle = _subtitle, detail = _detail, image = _image, glyph = _glyph, tile = _tile, fileIcon = _fileIcon, value = _value, showsDisclosure = _showsDisclosure, userInfo = _userInfo;
+ (id)itemWithTitle:(NSString *)title subtitle:(NSString *)subtitle glyph:(NSString *)glyph tile:(RCTileColor)tile {
    RCGridItem *i = [[[self alloc] init] autorelease];
    i.title = title; i.subtitle = subtitle; i.glyph = glyph; i.tile = tile;
    return i;
}
+ (id)itemWithImage:(UIImage *)image title:(NSString *)title { RCGridItem *i = [[[self alloc] init] autorelease]; i.image = image; i.title = title; return i; }
- (void)dealloc { [_title release]; [_subtitle release]; [_detail release]; [_image release]; [_glyph release]; [_value release]; [_userInfo release]; [super dealloc]; }
@end

@implementation RCGridSection
@synthesize title = _title, footer = _footer, items = _items;
+ (id)sectionWithTitle:(NSString *)title items:(NSArray *)items { RCGridSection *s = [[[self alloc] init] autorelease]; s.title = title; s.items = items; return s; }
- (void)dealloc { [_title release]; [_footer release]; [_items release]; [super dealloc]; }
@end

static const CGFloat RCGridCellSide = 100, RCGridGap = 4;

// One row of up to three thumbnails (.grid .gi).
@interface RCGridRowCell : UITableViewCell { @public NSArray *items; id target; }
@end
@implementation RCGridRowCell
- (id)initWithStyle:(UITableViewCellStyle)s reuseIdentifier:(NSString *)r {
    if ((self = [super initWithStyle:s reuseIdentifier:r])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundView = [[[UIView alloc] init] autorelease];
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}
- (void)dealloc { [items release]; [super dealloc]; }
- (void)configure:(NSArray *)row tags:(NSInteger)firstTag {
    [items release]; items = [row retain];
    for (UIView *v in [[self.contentView.subviews copy] autorelease]) [v removeFromSuperview];
    for (NSUInteger i = 0; i < row.count; i++) {
        RCGridItem *it = [row objectAtIndex:i];
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.tag = firstTag + (NSInteger)i;
        b.frame = CGRectMake(i * (RCGridCellSide + RCGridGap), 0, RCGridCellSide, RCGridCellSide);
        [b setBackgroundImage:[RCGridRowCell thumbFor:it] forState:UIControlStateNormal];
        b.adjustsImageWhenHighlighted = YES;
        b.isAccessibilityElement = YES;
        b.accessibilityLabel = it.title.length ? it.title : RCL(@"Image");
        b.accessibilityTraits = UIAccessibilityTraitButton | (it.image ? UIAccessibilityTraitImage : 0);
        [b addTarget:target action:@selector(thumbTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:b];
    }
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat total = 3 * RCGridCellSide + 2 * RCGridGap, x0 = round((self.bounds.size.width - total) / 2);
    NSInteger i = 0;
    for (UIView *b in self.contentView.subviews) { b.frame = CGRectMake(x0 + i * (RCGridCellSide + RCGridGap), 0, RCGridCellSide, RCGridCellSide); i++; }
    self.contentView.frame = self.bounds;
}
+ (UIImage *)thumbFor:(RCGridItem *)it {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(RCGridCellSide, RCGridCellSide), YES, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect r = CGRectMake(0, 0, RCGridCellSide, RCGridCellSide);
    [[RCTheme contentBackgroundColor] setFill];
    CGContextFillRect(ctx, r);
    CGPathRef p = RCCreateRoundedRectPath(CGRectInset(r, 1, 1), 4);
    CGContextSaveGState(ctx);
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1), 2, RCHexA(0, .3).CGColor);
    CGContextAddPath(ctx, p); CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor); CGContextFillPath(ctx);
    CGContextRestoreGState(ctx);
    CGContextAddPath(ctx, p); CGContextClip(ctx);
    if (it.image && !it.fileIcon) {
        CGSize s = it.image.size; CGFloat k = MAX(RCGridCellSide / MAX(1, s.width), RCGridCellSide / MAX(1, s.height));
        [it.image drawInRect:CGRectMake((RCGridCellSide - s.width * k) / 2, (RCGridCellSide - s.height * k) / 2, s.width * k, s.height * k)];
    } else {
        // a file: tile + name (library grid)
        if (it.fileIcon) [[RCFileIcon iconForFileName:it.title glyph:it.glyph photo:it.image size:CGSizeMake(44, 48) failed:NO] drawAtPoint:CGPointMake(28, 14)];
        else [[RCGlyph tileNamed:(it.glyph ? it.glyph : @"file") color:it.tile size:40] drawAtPoint:CGPointMake(30, 18)];
        [RCHex(0x4b5d55) set];
        [(it.title ? it.title : @"") drawInRect:CGRectMake(4, 66, RCGridCellSide - 8, 14) withFont:[UIFont systemFontOfSize:10] lineBreakMode:NSLineBreakByTruncatingTail alignment:NSTextAlignmentCenter];
    }
    CGPathRelease(p);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}
@end

@interface RCGridViewController () {
    UITableView *_table;
    UIView *_header;
    UISearchBar *_search;
    RCSegmentedControl *_segments;
    UIView *_emptyView;
    NSMutableArray *_flat; // grid: every item, for button tags
}
@end

@implementation RCGridViewController
@synthesize style = _style, showsGrid = _showsGrid, sections = _sections, searchPlaceholder = _searchPlaceholder, segmentTitles = _segmentTitles,
    selectedSegment = _selectedSegment, emptyTitle = _emptyTitle, emptyText = _emptyText, emptyGlyph = _emptyGlyph, delegate = _delegate, tableView = _table;

- (id)initWithStyle:(RCGridStyle)style title:(NSString *)title {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _style = style;
        _showsGrid = style == RCGridStyleImages;
        _flat = [[NSMutableArray alloc] init];
        self.title = title;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeChanged) name:RCThemeAppearanceDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _table.delegate = nil; _table.dataSource = nil; _search.delegate = nil;
    [_table release]; [_header release]; [_search release]; [_segments release]; [_emptyView release]; [_flat release];
    [_sections release]; [_searchPlaceholder release]; [_segmentTitles release]; [_emptyTitle release]; [_emptyText release]; [_emptyGlyph release];
    [super dealloc];
}

- (void)loadView {
    _table = [[UITableView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame style:UITableViewStyleGrouped];
    _table.dataSource = self; _table.delegate = self;
    _table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view = _table;
    [self themeChanged];
    [self rebuildHeader];
}

- (void)themeChanged { if (_table) { [RCTheme styleGroupedTableView:_table]; [self reloadData]; } }

- (void)rebuildHeader {
    if (!_table) return;
    CGFloat w = _table.bounds.size.width, y = 0;
    [_header release];
    _header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 0)];
    if (_searchPlaceholder) {
        if (!_search) { _search = [[UISearchBar alloc] initWithFrame:CGRectZero]; _search.delegate = self; }
        _search.placeholder = _searchPlaceholder;
        _search.frame = CGRectMake(0, 0, w, 44);
        _search.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [_header addSubview:_search];
        y = 44;
    }
    if (_segmentTitles.count) {
        if (!_segments) { _segments = [[RCSegmentedControl alloc] initWithItems:_segmentTitles style:RCSegmentedLight]; [_segments addTarget:self action:@selector(segmentChanged) forControlEvents:UIControlEventValueChanged]; }
        _segments.items = _segmentTitles;
        _segments.selectedSegmentIndex = _selectedSegment;
        _segments.frame = CGRectMake(9, y + 12, w - 18, 31);
        _segments.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [_header addSubview:_segments];
        y += 12 + 31;
    }
    _header.frame = CGRectMake(0, 0, w, y + (y ? 0 : 1));
    _table.tableHeaderView = _header;
}

- (NSUInteger)itemCount { NSUInteger n = 0; for (RCGridSection *s in _sections) n += s.items.count; return n; }

- (void)reloadData {
    if (!_table) return;
    [_flat removeAllObjects];
    for (RCGridSection *s in _sections) [_flat addObjectsFromArray:s.items];
    BOOL empty = [self itemCount] == 0 && (_emptyTitle.length || _emptyText.length);
    [_emptyView removeFromSuperview]; [_emptyView release]; _emptyView = nil;
    if (empty) {
        _emptyView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, _table.bounds.size.width, 200)];
        CGFloat y = 40;
        if (_emptyGlyph) { UIImageView *t = [[[UIImageView alloc] initWithImage:[RCGlyph tileNamed:_emptyGlyph color:RCTileGray size:57]] autorelease]; t.frame = CGRectMake(round((_emptyView.bounds.size.width - 57) / 2), y, 57, 57); [_emptyView addSubview:t]; y += 70; }
        for (int i = 0; i < 2; i++) {
            NSString *txt = i ? _emptyText : _emptyTitle;
            if (!txt.length) continue;
            UILabel *l = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
            l.backgroundColor = [UIColor clearColor];
            l.font = i ? [UIFont systemFontOfSize:14] : [UIFont boldSystemFontOfSize:17];
            l.textColor = i ? [RCTheme noteTextColor] : [RCTheme engravedTextColor];
            l.shadowColor = [RCTheme engravedShadowColor]; l.shadowOffset = [RCTheme engravedShadowOffset];
            l.textAlignment = NSTextAlignmentCenter;
            RCLabelSetText(l, txt);
            CGFloat h = RCMeasureText(txt, l.font, _emptyView.bounds.size.width - 60).height;
            l.frame = CGRectMake(30, y, _emptyView.bounds.size.width - 60, h);
            [_emptyView addSubview:l];
            y += h + 6;
        }
        _emptyView.frame = CGRectMake(0, 0, _table.bounds.size.width, y + 20);
        _emptyView.isAccessibilityElement = YES;
        _emptyView.accessibilityLabel = [NSString stringWithFormat:@"%@. %@", _emptyTitle ? _emptyTitle : @"", _emptyText ? _emptyText : @""];
    }
    _table.tableFooterView = _emptyView;
    [_table reloadData];
}

- (void)setSections:(NSArray *)s { [_sections release]; _sections = [s copy]; [self reloadData]; }
- (void)setShowsGrid:(BOOL)g { _showsGrid = g; [self reloadData]; }
- (void)setSearchPlaceholder:(NSString *)p { [_searchPlaceholder release]; _searchPlaceholder = [p copy]; [self rebuildHeader]; }
- (void)setSegmentTitles:(NSArray *)t { [_segmentTitles release]; _segmentTitles = [t copy]; [self rebuildHeader]; }
- (void)setSelectedSegment:(NSInteger)i { _selectedSegment = i; _segments.selectedSegmentIndex = i; }
- (void)setEmptyTitle:(NSString *)t { [_emptyTitle release]; _emptyTitle = [t copy]; [self reloadData]; }
- (void)setEmptyText:(NSString *)t { [_emptyText release]; _emptyText = [t copy]; [self reloadData]; }
- (void)setEmptyGlyph:(NSString *)t { [_emptyGlyph release]; _emptyGlyph = [t copy]; [self reloadData]; }

- (void)segmentChanged { _selectedSegment = _segments.selectedSegmentIndex; if ([_delegate respondsToSelector:@selector(grid:didSelectSegment:)]) [_delegate grid:self didSelectSegment:_selectedSegment]; }
- (void)searchBar:(UISearchBar *)bar textDidChange:(NSString *)text { if ([_delegate respondsToSelector:@selector(grid:searchTextDidChange:)]) [_delegate grid:self searchTextDidChange:text]; }
- (void)searchBarSearchButtonClicked:(UISearchBar *)bar { [bar resignFirstResponder]; if ([_delegate respondsToSelector:@selector(grid:searchDidSubmit:)]) [_delegate grid:self searchDidSubmit:bar.text ?: @""]; }
- (void)scrollViewWillBeginDragging:(UIScrollView *)s { [_search resignFirstResponder]; }

#pragma mark - Table

- (RCGridSection *)sectionAt:(NSInteger)i { return [_sections objectAtIndex:(NSUInteger)i]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return (NSInteger)_sections.count; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {
    NSUInteger n = [self sectionAt:s].items.count;
    return (NSInteger)(_showsGrid ? (n + 2) / 3 : n);
}
- (CGFloat)tableView:(UITableView *)t heightForRowAtIndexPath:(NSIndexPath *)ip {
    if (_showsGrid) return RCGridCellSide + RCGridGap;
    RCGridItem *it = [[self sectionAt:ip.section].items objectAtIndex:(NSUInteger)ip.row];
    if (_style == RCGridStyleGPT) {
        CGFloat h = 10 + 20 + RCMeasureText(it.subtitle, [UIFont systemFontOfSize:13], t.bounds.size.width - 20 - 62 - 30).height + (it.detail.length ? 16 : 0) + 10;
        return MAX(64, h);
    }
    return it.subtitle.length ? 54 : 44;
}
- (UIView *)tableView:(UITableView *)t viewForHeaderInSection:(NSInteger)s {
    NSString *title = [self sectionAt:s].title;
    return title.length ? [RCTheme groupedHeaderViewWithTitle:title width:t.bounds.size.width] : nil;
}
- (CGFloat)tableView:(UITableView *)t heightForHeaderInSection:(NSInteger)s { return [self sectionAt:s].title.length ? 44 : (s == 0 ? 10 : 6); }
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s { return [self sectionAt:s].footer; }

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    RCGridSection *sec = [self sectionAt:ip.section];
    if (_showsGrid) {
        RCGridRowCell *c = (RCGridRowCell *)[t dequeueReusableCellWithIdentifier:@"grid"];
        if (!c) c = [[[RCGridRowCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"grid"] autorelease];
        c->target = self;
        NSUInteger from = (NSUInteger)ip.row * 3, n = MIN((NSUInteger)3, sec.items.count - from);
        NSArray *row = [sec.items subarrayWithRange:NSMakeRange(from, n)];
        [c configure:row tags:(NSInteger)[_flat indexOfObjectIdenticalTo:[row objectAtIndex:0]]];
        return c;
    }
    RCGridItem *it = [sec.items objectAtIndex:(NSUInteger)ip.row];
    NSString *rid = _style == RCGridStyleGPT ? @"gpt" : @"row";
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:rid];
    if (!c) c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:rid] autorelease];
    [RCTheme styleGroupedCell:c position:[RCTheme positionForRow:ip.row count:(NSInteger)sec.items.count]];
    c.textLabel.text = it.title;
    c.textLabel.font = [UIFont boldSystemFontOfSize:_style == RCGridStyleGPT ? 16 : 15];
    c.detailTextLabel.font = [UIFont systemFontOfSize:13];
    c.detailTextLabel.textColor = [RCTheme secondaryInkColor];
    NSString *sub = it.subtitle;
    if (it.detail.length) sub = sub.length ? [NSString stringWithFormat:@"%@\n%@", sub, it.detail] : it.detail;
    c.detailTextLabel.numberOfLines = _style == RCGridStyleGPT ? 0 : 1;
    if (_style == RCGridStyleGPT) RCLabelSetText(c.detailTextLabel, sub); else { c.detailTextLabel.attributedText = nil; c.detailTextLabel.text = sub; }
    CGFloat side = _style == RCGridStyleGPT ? 40 : 29;
    if (it.image && !it.fileIcon) {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0);
        CGPathRef p = RCCreateRoundedRectPath(CGRectMake(0, 0, side, side), 5);
        CGContextAddPath(UIGraphicsGetCurrentContext(), p); CGContextClip(UIGraphicsGetCurrentContext()); CGPathRelease(p);
        CGSize s = it.image.size; CGFloat k = MAX(side / MAX(1, s.width), side / MAX(1, s.height));
        [it.image drawInRect:CGRectMake((side - s.width * k) / 2, (side - s.height * k) / 2, s.width * k, s.height * k)];
        c.imageView.image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    } else if (it.fileIcon) c.imageView.image = [RCFileIcon iconForFileName:it.title glyph:it.glyph photo:it.image size:CGSizeMake(side, side) failed:NO];
    else c.imageView.image = it.glyph ? [RCGlyph tileNamed:it.glyph color:it.tile size:side] : nil;
    c.accessoryType = it.showsDisclosure || _style == RCGridStyleGPT ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    if (it.value.length) {
        UILabel *v = [[[UILabel alloc] initWithFrame:CGRectMake(0, 0, 60, 20)] autorelease];
        v.backgroundColor = [UIColor clearColor]; v.font = [UIFont systemFontOfSize:15]; v.textColor = RCHex(0x3c6f57); v.textAlignment = NSTextAlignmentRight; v.text = it.value;
        c.accessoryView = v;
    } else c.accessoryView = nil;
    c.accessibilityLabel = [NSString stringWithFormat:@"%@%@", it.title ? it.title : @"", sub.length ? [@", " stringByAppendingString:sub] : @""];
    return c;
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    if (_showsGrid) return;
    RCGridItem *it = [[self sectionAt:ip.section].items objectAtIndex:(NSUInteger)ip.row];
    if ([_delegate respondsToSelector:@selector(grid:didSelectItem:)]) [_delegate grid:self didSelectItem:it];
}

- (void)thumbTapped:(UIButton *)b {
    if (b.tag < 0 || b.tag >= (NSInteger)_flat.count) return;
    if ([_delegate respondsToSelector:@selector(grid:didSelectItem:)]) [_delegate grid:self didSelectItem:[_flat objectAtIndex:(NSUInteger)b.tag]];
}
@end
