#import "RCDrawerController.h"
#import "RCTheme.h"
#import "RCGlyph.h"

static UIColor *RCDrawerInk(void) { return RCHex(0xe6f2ec); }
static UIColor *RCDrawerDim(CGFloat a) { return RCHexA(0xe6f2ec, a); }

@implementation RCDrawerItem
@synthesize title = _title, glyph = _glyph, count = _count, dotColor = _dotColor, style = _style, current = _current, busy = _busy, userInfo = _userInfo, actionsAvailable = _actionsAvailable, accessibilityIdentifier = _accessibilityIdentifier;
+ (id)itemWithTitle:(NSString *)title glyph:(NSString *)glyph style:(RCDrawerRowStyle)style {
    RCDrawerItem *i = [[[self alloc] init] autorelease];
    i.title = title; i.glyph = glyph; i.style = style;
    return i;
}
- (void)dealloc { [_title release]; [_glyph release]; [_count release]; [_dotColor release]; [_userInfo release]; [_accessibilityIdentifier release]; [super dealloc]; }
@end

@implementation RCDrawerSection
@synthesize title = _title, items = _items, emptyText = _emptyText;
+ (id)sectionWithTitle:(NSString *)title items:(NSArray *)items {
    RCDrawerSection *s = [[[self alloc] init] autorelease];
    s.title = title; s.items = items;
    return s;
}
- (void)dealloc { [_title release]; [_items release]; [_emptyText release]; [super dealloc]; }
@end

#pragma mark - Row backgrounds

typedef enum { RCRowBgNormal, RCRowBgPressed, RCRowBgCurrent } RCRowBg;

@interface RCDrawerRowBackground : UIView { @public RCRowBg _kind; }
@end
@implementation RCDrawerRowBackground
- (id)initWithKind:(RCRowBg)k { if ((self = [super initWithFrame:CGRectMake(0, 0, 270, 44)])) { _kind = k; self.opaque = NO; self.backgroundColor = [UIColor clearColor]; self.contentMode = UIViewContentModeRedraw; } return self; }
- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    if (_kind == RCRowBgPressed) RCDrawVerticalGradient(ctx, b, [NSArray arrayWithObjects:RCHex(0x3a8a63), RCHex(0x1d6a45), nil], nil);
    if (_kind == RCRowBgCurrent) {
        CGContextSetFillColorWithColor(ctx, RCHexA(0, .25).CGColor); CGContextFillRect(ctx, b);
        RCDrawVerticalGradient(ctx, CGRectMake(0, 0, b.size.width, 4), [NSArray arrayWithObjects:RCHexA(0, .35), RCHexA(0, 0), nil], nil);
    }
    CGContextSetFillColorWithColor(ctx, RCHexA(0xffffff, _kind == RCRowBgPressed ? .2 : .07).CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, b.size.width, 1));
    CGContextSetFillColorWithColor(ctx, RCHexA(0, .35).CGColor);
    CGContextFillRect(ctx, CGRectMake(0, b.size.height - 1, b.size.width, 1));
}
@end

@interface RCDrawerCell : UITableViewCell { @public UILabel *_count; UIImageView *_glyph; UIView *_dot; UIActivityIndicatorView *_spin; RCDrawerItem *_item; }
@end
@implementation RCDrawerCell
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:rid])) {
        self.backgroundView = [[[RCDrawerRowBackground alloc] initWithKind:RCRowBgNormal] autorelease];
        self.selectedBackgroundView = [[[RCDrawerRowBackground alloc] initWithKind:RCRowBgPressed] autorelease];
        self.textLabel.backgroundColor = [UIColor clearColor];
        self.textLabel.textColor = RCDrawerInk();
        self.textLabel.highlightedTextColor = [UIColor whiteColor];
        self.textLabel.shadowColor = RCHexA(0, .6);
        self.textLabel.shadowOffset = CGSizeMake(0, -1);
        _glyph = [[UIImageView alloc] initWithFrame:CGRectZero];
        _glyph.alpha = .85;
        [self.contentView addSubview:_glyph];
        _count = [[UILabel alloc] initWithFrame:CGRectZero];
        _count.backgroundColor = [UIColor clearColor];
        _count.font = [UIFont systemFontOfSize:12];
        _count.textColor = RCDrawerDim(.55);
        _count.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_count];
        _dot = [[UIView alloc] initWithFrame:CGRectMake(20, 16, 12, 12)];
        [self.contentView addSubview:_dot];
        _spin = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        [self.contentView addSubview:_spin];
    }
    return self;
}
- (void)dealloc { [_count release]; [_glyph release]; [_dot release]; [_spin release]; [_item release]; [super dealloc]; }

- (void)setItem:(RCDrawerItem *)item {
    [_item release]; _item = [item retain];
    RCDrawerRowStyle s = item.style;
    self.textLabel.text = item.title;
    self.textLabel.font = s == RCDrawerRowNav ? [UIFont boldSystemFontOfSize:16] : (s == RCDrawerRowMore ? [UIFont boldSystemFontOfSize:14] : [UIFont systemFontOfSize:15]);
    self.textLabel.textColor = s == RCDrawerRowMore ? RCDrawerDim(.7) : RCDrawerInk();
    self.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    CGFloat gs = s == RCDrawerRowChat ? 16 : 20;
    _glyph.image = item.glyph ? [RCGlyph imageNamed:item.glyph size:gs color:RCHex(0xcfe7da)] : nil;
    _glyph.hidden = item.glyph == nil;
    _count.text = item.count;
    _dot.hidden = !(s == RCDrawerRowSub && item.dotColor && !item.glyph);
    _dot.backgroundColor = item.dotColor;
    if (item.busy) [_spin startAnimating]; else [_spin stopAnimating];
    _spin.hidden = !item.busy;
    ((RCDrawerRowBackground *)self.backgroundView)->_kind = item.current ? RCRowBgCurrent : RCRowBgNormal;
    [self.backgroundView setNeedsDisplay];
    self.accessibilityLabel = item.count.length ? [NSString stringWithFormat:@"%@, %@", item.title, item.count] : item.title;
    self.accessibilityIdentifier = item.accessibilityIdentifier;
    self.accessibilityTraits = item.current ? (UIAccessibilityTraitButton | UIAccessibilityTraitSelected) : UIAccessibilityTraitButton;
    self.accessibilityHint = item.actionsAvailable ? RCL(@"Double-tap and hold for chat actions") : nil;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width, h = self.contentView.bounds.size.height;
    RCDrawerRowStyle s = _item.style;
    CGFloat left = 14;
    if (s == RCDrawerRowNav || s == RCDrawerRowSub) left = 46;
    if (s == RCDrawerRowChat && _item.glyph) left = 36;
    if (s == RCDrawerRowMore && _item.busy) left = 14 + 20 + 6;
    if (s == RCDrawerRowChat) _glyph.frame = CGRectMake(12, 14, 16, 16);
    else _glyph.frame = CGRectMake(13, 11, 20, 20);
    _spin.center = CGPointMake(14 + 10, h / 2);
    CGFloat cw = _count.text.length ? ceil([_count.text sizeWithFont:_count.font].width) + 8 : 0;
    _count.frame = CGRectMake(w - 12 - cw, 0, cw, h);
    self.textLabel.frame = CGRectMake(left, 0, w - left - 12 - cw, h);
}
@end

#pragma mark - Headers and footer

@interface RCDrawerHeader : UIView { @public UILabel *_label; }
@end
@implementation RCDrawerHeader
- (id)initWithTitle:(NSString *)title {
    if ((self = [super initWithFrame:CGRectMake(0, 0, 270, 24)])) {
        self.contentMode = UIViewContentModeRedraw;
        self.backgroundColor = [UIColor clearColor];
        _label = [[UILabel alloc] initWithFrame:CGRectMake(14, 0, 242, 24)];
        _label.backgroundColor = [UIColor clearColor];
        NSDictionary *a = [NSDictionary dictionaryWithObjectsAndKeys:[UIFont boldSystemFontOfSize:11], NSFontAttributeName, RCDrawerDim(.65), NSForegroundColorAttributeName, [NSNumber numberWithFloat:1], NSKernAttributeName, nil];
        _label.attributedText = [[[NSAttributedString alloc] initWithString:[title uppercaseString] attributes:a] autorelease];
        _label.shadowColor = RCHexA(0, .6);
        _label.shadowOffset = CGSizeMake(0, -1);
        [self addSubview:_label];
        self.isAccessibilityElement = YES;
        self.accessibilityLabel = title;
        self.accessibilityTraits = UIAccessibilityTraitHeader;
    }
    return self;
}
- (void)dealloc { [_label release]; [super dealloc]; }
- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    CGContextSetFillColorWithColor(ctx, [RCTheme linenDarkColor].CGColor); CGContextFillRect(ctx, b);
    RCDrawVerticalGradient(ctx, b, [NSArray arrayWithObjects:RCHexA(0, .18), RCHexA(0, .32), nil], nil);
    CGContextSetFillColorWithColor(ctx, RCHexA(0xffffff, .06).CGColor); CGContextFillRect(ctx, CGRectMake(0, 0, b.size.width, 1));
    CGContextSetFillColorWithColor(ctx, RCHexA(0, .45).CGColor); CGContextFillRect(ctx, CGRectMake(0, b.size.height - 1, b.size.width, 1));
}
@end

@interface RCDrawerFooter : UIControl { @public UILabel *_avatar, *_name, *_email; UIImageView *_gear; }
@end
@implementation RCDrawerFooter
+ (UIImage *)avatarImage {
    return [RCTheme imageForKey:@"drawer-avatar" size:CGSizeMake(34, 35) capInsets:UIEdgeInsetsZero drawing:^(CGContextRef ctx, CGRect r) {
        CGRect c = CGRectMake(1, 1, 32, 32);
        CGContextSaveGState(ctx);
        CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1), 2, RCHexA(0, .5).CGColor);
        CGContextSetFillColorWithColor(ctx, RCHex(0x2b9a62).CGColor); CGContextFillEllipseInRect(ctx, c);
        CGContextRestoreGState(ctx);
        CGContextAddEllipseInRect(ctx, c); CGContextClip(ctx);
        RCDrawVerticalGradient(ctx, c, [NSArray arrayWithObjects:RCHex(0x8bd6ae), RCHex(0x2b9a62), nil], nil);
        CGContextSetFillColorWithColor(ctx, RCHexA(0xffffff, .4).CGColor); CGContextFillRect(ctx, CGRectMake(0, 2, 34, 1));
        (void)r;
    }];
}
- (id)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.contentMode = UIViewContentModeRedraw;
        UIImageView *av = [[[UIImageView alloc] initWithImage:[RCDrawerFooter avatarImage]] autorelease];
        av.frame = CGRectMake(11, 8, 34, 35);
        [self addSubview:av];
        _avatar = [[UILabel alloc] initWithFrame:CGRectMake(12, 9, 32, 32)];
        _avatar.font = [UIFont boldSystemFontOfSize:13];
        _avatar.textAlignment = NSTextAlignmentCenter;
        _name = [[UILabel alloc] initWithFrame:CGRectMake(56, 8, f.size.width - 56 - 38, 19)];
        _name.font = [UIFont boldSystemFontOfSize:15];
        _name.shadowColor = [UIColor blackColor]; _name.shadowOffset = CGSizeMake(0, -1);
        _email = [[UILabel alloc] initWithFrame:CGRectMake(56, 27, f.size.width - 56 - 38, 15)];
        _email.font = [UIFont systemFontOfSize:12];
        for (UILabel *l in [NSArray arrayWithObjects:_avatar, _name, _email, nil]) { l.backgroundColor = [UIColor clearColor]; l.textColor = RCDrawerInk(); l.userInteractionEnabled = NO; [self addSubview:l]; }
        _avatar.textColor = [UIColor whiteColor];
        _email.textColor = RCDrawerDim(.6);
        _gear = [[UIImageView alloc] initWithImage:[RCGlyph imageNamed:@"gear" size:20 color:RCHex(0xcfe7da)]];
        _gear.frame = CGRectMake(f.size.width - 12 - 20, 15, 20, 20);
        _gear.alpha = .75;
        [self addSubview:_gear];
        self.isAccessibilityElement = YES;
        self.accessibilityTraits = UIAccessibilityTraitButton;
    }
    return self;
}
- (void)dealloc { [_avatar release]; [_name release]; [_email release]; [_gear release]; [super dealloc]; }
- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    NSArray *c = self.highlighted ? [NSArray arrayWithObjects:RCHex(0x3a8a63), RCHex(0x1d6a45), nil] : [NSArray arrayWithObjects:RCHex(0x2c5143), RCHex(0x183a2d), nil];
    RCDrawVerticalGradient(ctx, b, c, nil);
    CGContextSetFillColorWithColor(ctx, RCHex(0x0a2219).CGColor); CGContextFillRect(ctx, CGRectMake(0, 0, b.size.width, 1));
    CGContextSetFillColorWithColor(ctx, RCHexA(0xffffff, .12).CGColor); CGContextFillRect(ctx, CGRectMake(0, 1, b.size.width, 1));
}
@end

#pragma mark - Controller

@interface RCDrawerController () {
    UISearchBar *_search;
    UITableView *_table;
    RCDrawerFooter *_footer;
    NSArray *_sections;
    NSString *_searchPlaceholder, *_accountName, *_accountEmail, *_accountInitials;
}
@end

@implementation RCDrawerController
@synthesize showsSearch = _showsSearch, delegate = _delegate, tableView = _table;

- (id)init {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _showsSearch = YES;
        _searchPlaceholder = [RCL(@"Search chats") copy];
    }
    return self;
}

- (void)dealloc {
    _search.delegate = nil; _table.delegate = nil; _table.dataSource = nil;
    [_search release]; [_table release]; [_footer release];
    [_sections release]; [_searchPlaceholder release]; [_accountName release]; [_accountEmail release]; [_accountInitials release];
    [super dealloc];
}

- (void)loadView {
    UIView *v = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 270, 460)] autorelease];
    v.backgroundColor = [RCTheme linenDarkColor];
    self.view = v;
    _search = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 270, 44)];
    _search.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _search.delegate = self;
    [RCTheme styleDarkSearchBar:_search];
    [v addSubview:_search];
    _table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _table.backgroundColor = [UIColor clearColor];
    _table.backgroundView = nil;
    _table.separatorStyle = UITableViewCellSeparatorStyleNone;
    _table.rowHeight = 44;
    _table.dataSource = self;
    _table.delegate = self;
    _table.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    _table.scrollsToTop = NO;
    [v addSubview:_table];
    UILongPressGestureRecognizer *press = [[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(pressed:)] autorelease];
    [_table addGestureRecognizer:press];
    _footer = [[RCDrawerFooter alloc] initWithFrame:CGRectMake(0, 0, 270, 50)];
    _footer.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    [_footer addTarget:self action:@selector(tapAccount) forControlEvents:UIControlEventTouchUpInside];
    [v addSubview:_footer];
    [self applyAccount];
    [self applySearch];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    CGFloat h = self.view.bounds.size.height, top = _showsSearch ? 44 : 0;
    _table.frame = CGRectMake(0, top, 270, h - top - 50);
    _footer.frame = CGRectMake(0, h - 50, 270, 50);
}

- (NSArray *)sections { return _sections; }
- (void)setSections:(NSArray *)s { [_sections release]; _sections = [s copy]; [_table reloadData]; }
- (void)setShowsSearch:(BOOL)v { _showsSearch = v; [self applySearch]; [self.view setNeedsLayout]; }
- (NSString *)searchPlaceholder { return _searchPlaceholder; }
- (void)setSearchPlaceholder:(NSString *)p { [_searchPlaceholder release]; _searchPlaceholder = [p copy]; [self applySearch]; }
- (void)applySearch { _search.hidden = !_showsSearch; _search.placeholder = _searchPlaceholder; }

#define RC_ACCOUNT(Get, Set, ivar) - (NSString *)Get { return ivar; } - (void)Set:(NSString *)v { [ivar release]; ivar = [v copy]; [self applyAccount]; }
RC_ACCOUNT(accountName, setAccountName, _accountName)
RC_ACCOUNT(accountEmail, setAccountEmail, _accountEmail)
RC_ACCOUNT(accountInitials, setAccountInitials, _accountInitials)
#undef RC_ACCOUNT

- (void)applyAccount {
    _footer->_avatar.text = _accountInitials;
    _footer->_name.text = _accountName;
    _footer->_email.text = _accountEmail;
    _footer.accessibilityLabel = [NSString stringWithFormat:RCL(@"Account and settings, %@"), _accountName ? _accountName : @""];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return (NSInteger)_sections.count; }
- (RCDrawerSection *)sectionAt:(NSInteger)i { return [_sections objectAtIndex:(NSUInteger)i]; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    RCDrawerSection *sec = [self sectionAt:s];
    return sec.items.count ? (NSInteger)sec.items.count : (sec.emptyText.length ? 1 : 0);
}
- (CGFloat)tableView:(UITableView *)tv heightForHeaderInSection:(NSInteger)s { return [self sectionAt:s].title.length ? 24 : 0; }
- (UIView *)tableView:(UITableView *)tv viewForHeaderInSection:(NSInteger)s {
    NSString *t = [self sectionAt:s].title;
    return t.length ? [[[RCDrawerHeader alloc] initWithTitle:t] autorelease] : nil;
}
- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip {
    RCDrawerSection *sec = [self sectionAt:ip.section];
    if (!sec.items.count) return 50;
    return 44;
}
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    RCDrawerSection *sec = [self sectionAt:ip.section];
    if (!sec.items.count) {
        UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"empty"];
        if (!c) {
            c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"empty"] autorelease];
            c.selectionStyle = UITableViewCellSelectionStyleNone;
            c.backgroundView = [[[UIView alloc] init] autorelease];
            c.textLabel.font = [UIFont systemFontOfSize:14];
            c.textLabel.textColor = RCDrawerDim(.6);
            c.textLabel.backgroundColor = [UIColor clearColor];
            c.textLabel.shadowColor = RCHexA(0, .5); c.textLabel.shadowOffset = CGSizeMake(0, -1);
            c.textLabel.numberOfLines = 0;
            c.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
        }
        c.textLabel.text = sec.emptyText;
        return c;
    }
    RCDrawerCell *c = (RCDrawerCell *)[tv dequeueReusableCellWithIdentifier:@"row"];
    if (!c) c = [[[RCDrawerCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"row"] autorelease];
    [c setItem:[sec.items objectAtIndex:(NSUInteger)ip.row]];
    return c;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    RCDrawerSection *sec = [self sectionAt:ip.section];
    if (!sec.items.count) return;
    if ([_delegate respondsToSelector:@selector(drawer:didSelectItem:)]) [_delegate drawer:self didSelectItem:[sec.items objectAtIndex:(NSUInteger)ip.row]];
}

- (void)pressed:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    NSIndexPath *ip = [_table indexPathForRowAtPoint:[g locationInView:_table]];
    RCDrawerSection *sec = ip ? [self sectionAt:ip.section] : nil;
    if ((NSUInteger)ip.row >= sec.items.count) return;
    RCDrawerItem *item = [sec.items objectAtIndex:(NSUInteger)ip.row];
    if (item.actionsAvailable && [_delegate respondsToSelector:@selector(drawer:didLongPressItem:)]) [_delegate drawer:self didLongPressItem:item];
}

#pragma mark - Search and account

- (void)searchBar:(UISearchBar *)bar textDidChange:(NSString *)text {
    if ([_delegate respondsToSelector:@selector(drawer:searchTextDidChange:)]) [_delegate drawer:self searchTextDidChange:text];
}
- (void)searchBarSearchButtonClicked:(UISearchBar *)bar { [bar resignFirstResponder]; }
- (void)tapAccount { if ([_delegate respondsToSelector:@selector(drawerDidTapAccount:)]) [_delegate drawerDidTapAccount:self]; }
@end
