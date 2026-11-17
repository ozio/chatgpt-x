#import "RCDiffViewController.h"
#import "RCCodeBlockView.h"
#import "RCTheme.h"
#import "RCButton.h"

@implementation RCDiffComment
@synthesize lineIndex = _lineIndex, title = _title, text = _text, userInfo = _userInfo;
+ (id)commentAfterLine:(NSUInteger)lineIndex text:(NSString *)text { RCDiffComment *c = [[[self alloc] init] autorelease]; c.lineIndex = lineIndex; c.text = text; return c; }
- (void)dealloc { [_title release]; [_text release]; [_userInfo release]; [super dealloc]; }
@end

@implementation RCDiffHunk
@synthesize header = _header, oldStart = _oldStart, newStart = _newStart, lines = _lines, comments = _comments;
+ (id)hunkWithHeader:(NSString *)header oldStart:(NSInteger)oldStart newStart:(NSInteger)newStart lines:(NSArray *)lines {
    RCDiffHunk *h = [[[self alloc] init] autorelease]; h.header = header; h.oldStart = oldStart; h.newStart = newStart; h.lines = lines; return h;
}
- (void)dealloc { [_header release]; [_lines release]; [_comments release]; [super dealloc]; }
@end

typedef enum { RCDiffRowHunk = 0, RCDiffRowContext, RCDiffRowAdded, RCDiffRowRemoved, RCDiffRowNote } RCDiffRowKind;

@interface RCDiffRow : NSObject { @public RCDiffRowKind kind; NSInteger oldNo, newNo; NSString *text; RCDiffComment *comment; }
@end
@implementation RCDiffRow
- (void)dealloc { [text release]; [comment release]; [super dealloc]; }
@end

#define RC_DIFF_LINE 17
#define RC_DIFF_GUTTER 70

@interface RCDiffLineCell : UITableViewCell { @public UIView *_gutter; UILabel *_old, *_new, *_sign, *_code; }
@end
@implementation RCDiffLineCell
- (id)initWithReuseIdentifier:(NSString *)rid {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:rid])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        UIFont *mono = [RCCodeBlockView codeFont], *small = [mono fontWithSize:10];
        _gutter = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 56, RC_DIFF_LINE)]; [self.contentView addSubview:_gutter];
        _old = [[UILabel alloc] initWithFrame:CGRectMake(2, 0, 26, RC_DIFF_LINE)]; _new = [[UILabel alloc] initWithFrame:CGRectMake(30, 0, 26, RC_DIFF_LINE)];
        for (UILabel *l in [NSArray arrayWithObjects:_old, _new, nil]) { l.font = small; l.textAlignment = NSTextAlignmentRight; l.backgroundColor = [UIColor clearColor]; l.isAccessibilityElement = NO; [self.contentView addSubview:l]; }
        _sign = [[UILabel alloc] initWithFrame:CGRectMake(58, 0, 10, RC_DIFF_LINE)]; _sign.font = [UIFont boldSystemFontOfSize:12]; _sign.backgroundColor = [UIColor clearColor]; _sign.isAccessibilityElement = NO; [self.contentView addSubview:_sign];
        _code = [[UILabel alloc] initWithFrame:CGRectZero]; _code.font = mono; _code.numberOfLines = 0; _code.lineBreakMode = NSLineBreakByCharWrapping; _code.backgroundColor = [UIColor clearColor]; _code.isAccessibilityElement = NO; [self.contentView addSubview:_code];
        self.isAccessibilityElement = YES;
    }
    return self;
}
- (void)dealloc { [_gutter release]; [_old release]; [_new release]; [_sign release]; [_code release]; [super dealloc]; }
@end

@interface RCDiffNoteCell : UITableViewCell { @public UIImageView *_box; UILabel *_title, *_text; UIButton *_fix; RCDiffComment *_comment; }
@end
@implementation RCDiffNoteCell
- (void)dealloc { [_box release]; [_title release]; [_text release]; [_fix release]; [_comment release]; [super dealloc]; }
@end

#define RC_DIFF_NOTE_X 70

@interface RCDiffViewController () { RCFileChange *_change; NSArray *_hunks; NSMutableArray *_rows; CGFloat _charW; CGFloat _width; }
@end

@implementation RCDiffViewController
@synthesize change = _change, hunks = _hunks, fixAvailable = _fixAvailable, delegate = _delegate;

- (id)init {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        _rows = [[NSMutableArray alloc] init];
        _charW = [@"0000000000" sizeWithFont:[RCCodeBlockView codeFont]].width / 10.0;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appearance) name:RCThemeAppearanceDidChangeNotification object:nil];
    }
    return self;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; [_change release]; [_hunks release]; [_rows release]; [super dealloc]; }

- (void)setHunks:(NSArray *)hunks {
    if (hunks == _hunks) return;
    [_hunks release]; _hunks = [hunks copy];
    [_rows removeAllObjects];
    for (RCDiffHunk *h in _hunks) {
        RCDiffRow *hr = [[[RCDiffRow alloc] init] autorelease]; hr->kind = RCDiffRowHunk; hr->text = [[@"@@ " stringByAppendingString:h.header ? h.header : @""] copy]; [_rows addObject:hr];
        NSInteger o = h.oldStart, n = h.newStart;
        NSUInteger li = 0;
        for (NSString *l in h.lines) {
            RCDiffRow *r = [[[RCDiffRow alloc] init] autorelease];
            unichar c = l.length ? [l characterAtIndex:0] : ' ';
            r->kind = c == '+' ? RCDiffRowAdded : (c == '-' ? RCDiffRowRemoved : RCDiffRowContext);
            r->oldNo = r->kind == RCDiffRowAdded ? 0 : o++;
            r->newNo = r->kind == RCDiffRowRemoved ? 0 : n++;
            r->text = [(l.length ? [l substringFromIndex:1] : @"") copy];
            [_rows addObject:r];
            for (RCDiffComment *c in h.comments) if (c.lineIndex == li) { RCDiffRow *nr = [[[RCDiffRow alloc] init] autorelease]; nr->kind = RCDiffRowNote; nr->comment = [c retain]; [_rows addObject:nr]; }
            li++;
        }
    }
    if (self.isViewLoaded) [self.tableView reloadData];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self appearance];
}
- (void)appearance {
    if (!self.isViewLoaded) return;
    self.tableView.backgroundColor = [RCTheme isDark] ? RCHex(0x141d19) : [UIColor whiteColor];
    self.tableView.tableHeaderView = [self headerView];
    [self.tableView reloadData];
}

- (UIView *)headerView {
    BOOL dark = [RCTheme isDark];
    CGFloat w = self.tableView.bounds.size.width ? self.tableView.bounds.size.width : 320;
    UIView *v = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 36)] autorelease];
    UIImageView *bg = [[[UIImageView alloc] initWithFrame:v.bounds] autorelease]; bg.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    bg.image = [RCTheme imageForKey:(dark ? @"cx-dfh-d" : @"cx-dfh") size:CGSizeMake(4, 36) capInsets:UIEdgeInsetsMake(1, 1, 2, 1) drawing:^(CGContextRef ctx, CGRect r) {
        RCDrawVerticalGradient(ctx, CGRectMake(0, 0, r.size.width, 35), [NSArray arrayWithObjects:RCHex(dark ? 0x26352e : 0xf7faf8), RCHex(dark ? 0x1d2a24 : 0xe3eae6), nil], nil);
        CGContextSetFillColorWithColor(ctx, RCHex(dark ? 0x2c3d35 : 0xc7d2cc).CGColor); CGContextFillRect(ctx, CGRectMake(0, 35, r.size.width, 1));
    }];
    [v addSubview:bg];
    if (_change) {
        UIImageView *badge = [[[UIImageView alloc] initWithImage:RCFileChangeBadge(_change.kind)] autorelease]; badge.frame = CGRectMake(10, 9, 17, 18); [v addSubview:badge];
        UILabel *counts = [[[UILabel alloc] initWithFrame:CGRectMake(w - 100, 0, 90, 35)] autorelease]; counts.backgroundColor = [UIColor clearColor]; counts.textAlignment = NSTextAlignmentRight; counts.attributedText = RCChangeCountsText(_change.added, _change.removed, 12); counts.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin; [v addSubview:counts];
        UILabel *path = [[[UILabel alloc] initWithFrame:CGRectMake(34, 0, w - 34 - 104, 35)] autorelease]; path.backgroundColor = [UIColor clearColor]; path.font = [UIFont boldSystemFontOfSize:13]; path.textColor = RCHex(dark ? 0xcfe0d7 : 0x33453d); path.lineBreakMode = NSLineBreakByTruncatingHead; path.text = _change.path; path.autoresizingMask = UIViewAutoresizingFlexibleWidth; [v addSubview:path];
        v.isAccessibilityElement = YES; v.accessibilityTraits = UIAccessibilityTraitHeader;
        v.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", RCFileChangeKindName(_change.kind), _change.path];
        v.accessibilityValue = RCChangeCountsAccessibilityText(_change.added, _change.removed);
    }
    return v;
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { (void)tv; (void)s; return (NSInteger)_rows.count; }

- (CGFloat)codeWidth { CGFloat w = self.tableView.bounds.size.width ? self.tableView.bounds.size.width : 320; return w - RC_DIFF_GUTTER - 6; }
- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip {
    (void)tv;
    RCDiffRow *r = [_rows objectAtIndex:(NSUInteger)ip.row];
    if (r->kind == RCDiffRowHunk) return 24;
    if (r->kind == RCDiffRowNote) return [self noteHeight:r->comment];
    NSUInteger perLine = MAX(1, (NSUInteger)floor([self codeWidth] / _charW));
    NSUInteger lines = MAX(1, (r->text.length + perLine - 1) / perLine);
    return RC_DIFF_LINE * lines;
}

static NSString *RCNo(NSInteger n) { return n > 0 ? [NSString stringWithFormat:@"%ld", (long)n] : @""; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    BOOL dark = [RCTheme isDark];
    RCDiffRow *r = [_rows objectAtIndex:(NSUInteger)ip.row];
    if (r->kind == RCDiffRowHunk) {
        UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"h"];
        if (!c) {
            c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"h"] autorelease];
            c.selectionStyle = UITableViewCellSelectionStyleNone;
            UIImageView *bg = [[[UIImageView alloc] initWithImage:[RCTheme imageForKey:@"cx-hunk" size:CGSizeMake(4, 24) capInsets:UIEdgeInsetsMake(1, 1, 1, 1) drawing:^(CGContextRef ctx, CGRect rr) {
                RCDrawVerticalGradient(ctx, rr, [NSArray arrayWithObjects:RCHex(0x8fa39a), RCHex(0x6b7f76), nil], nil);
                CGContextSetFillColorWithColor(ctx, RCHex(0x5d7068).CGColor); CGContextFillRect(ctx, CGRectMake(0, 0, rr.size.width, 1)); CGContextFillRect(ctx, CGRectMake(0, rr.size.height - 1, rr.size.width, 1));
            }]] autorelease];
            c.backgroundView = bg;
            c.textLabel.font = [[RCCodeBlockView codeFont] fontWithSize:11]; c.textLabel.textColor = [UIColor whiteColor];
            c.textLabel.shadowColor = RCHexA(0x000000, .35); c.textLabel.shadowOffset = CGSizeMake(0, -1); c.textLabel.backgroundColor = [UIColor clearColor];
            c.accessibilityTraits = UIAccessibilityTraitHeader;
        }
        c.textLabel.text = r->text; c.accessibilityLabel = r->text;
        return c;
    }
    if (r->kind == RCDiffRowNote) return [self noteCell:tv row:r];
    RCDiffLineCell *c = (RCDiffLineCell *)[tv dequeueReusableCellWithIdentifier:@"l"];
    if (!c) c = [[[RCDiffLineCell alloc] initWithReuseIdentifier:@"l"] autorelease];
    unsigned bg = r->kind == RCDiffRowAdded ? (dark ? 0x173326 : 0xe3f6e8) : (r->kind == RCDiffRowRemoved ? (dark ? 0x3a1d1a : 0xfde9e6) : (dark ? 0x141d19 : 0xffffff));
    unsigned gutter = r->kind == RCDiffRowAdded ? (dark ? 0x1c3b2d : 0xd2efdb) : (r->kind == RCDiffRowRemoved ? (dark ? 0x44221e : 0xf8d8d3) : bg);
    c.contentView.backgroundColor = RCHex(bg); c.backgroundColor = RCHex(bg);
    c->_gutter.backgroundColor = RCHex(gutter); c->_old.backgroundColor = c->_new.backgroundColor = [UIColor clearColor];
    c->_old.textColor = c->_new.textColor = RCHex(dark ? 0x6b7f76 : 0x9aa8a1);
    c->_old.text = RCNo(r->oldNo); c->_new.text = RCNo(r->newNo);
    c->_sign.text = r->kind == RCDiffRowAdded ? @"+" : (r->kind == RCDiffRowRemoved ? @"−" : @"");
    c->_sign.textColor = r->kind == RCDiffRowAdded ? RCHex(dark ? 0x6fd49a : 0x1f8a4c) : RCHex(dark ? 0xff8c7f : 0xc42515);
    c->_code.textColor = RCHex(dark ? 0xe3ece7 : 0x1d2924);
    c->_code.text = r->text.length ? r->text : @" ";
    CGFloat h = [self tableView:tv heightForRowAtIndexPath:ip];
    c->_gutter.frame = CGRectMake(0, 0, 56, h); c->_old.frame = CGRectMake(0, 0, 26, RC_DIFF_LINE); c->_new.frame = CGRectMake(28, 0, 26, RC_DIFF_LINE); c->_sign.frame = CGRectMake(58, 0, 10, RC_DIFF_LINE);
    c->_old.textAlignment = c->_new.textAlignment = NSTextAlignmentRight;
    c->_code.frame = CGRectMake(RC_DIFF_GUTTER, 0, [self codeWidth], h);
    c.accessibilityLabel = [NSString stringWithFormat:@"%@%@", r->kind == RCDiffRowAdded ? [RCL(@"Added") stringByAppendingString:@": "] : (r->kind == RCDiffRowRemoved ? [RCL(@"Deleted") stringByAppendingString:@": "] : @""), r->text];
    c.accessibilityValue = r->newNo ? [NSString stringWithFormat:RCL(@"line %ld"), (long)r->newNo] : (r->oldNo ? [NSString stringWithFormat:RCL(@"line %ld"), (long)r->oldNo] : nil);
    return c;
}

- (CGFloat)noteTextWidth { return (self.tableView.bounds.size.width ? self.tableView.bounds.size.width : 320) - RC_DIFF_NOTE_X - 8 - 20; }
- (CGFloat)noteHeight:(RCDiffComment *)c {
    CGFloat th = ceil(RCMeasureText(c.text, [UIFont systemFontOfSize:13], [self noteTextWidth]).height);
    return 4 + 8 + 16 + th + (_fixAvailable ? 8 + 32 : 0) + 8 + 6;
}
- (UITableViewCell *)noteCell:(UITableView *)tv row:(RCDiffRow *)r {
    BOOL dark = [RCTheme isDark];
    RCDiffNoteCell *c = (RCDiffNoteCell *)[tv dequeueReusableCellWithIdentifier:@"n"];
    if (!c) {
        c = [[[RCDiffNoteCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"n"] autorelease];
        c.selectionStyle = UITableViewCellSelectionStyleNone;
        c->_box = [[UIImageView alloc] initWithFrame:CGRectZero]; [c.contentView addSubview:c->_box];
        c->_title = [[UILabel alloc] initWithFrame:CGRectZero]; c->_title.backgroundColor = [UIColor clearColor]; c->_title.font = [UIFont boldSystemFontOfSize:12]; [c.contentView addSubview:c->_title];
        c->_text = [[UILabel alloc] initWithFrame:CGRectZero]; c->_text.backgroundColor = [UIColor clearColor]; c->_text.font = [UIFont systemFontOfSize:13]; c->_text.numberOfLines = 0; c->_text.lineBreakMode = NSLineBreakByWordWrapping; [c.contentView addSubview:c->_text];
        c->_fix = [[RCButton buttonWithStyle:RCButtonStylePill title:RCL(@"Fix")] retain];
        c->_fix.accessibilityHint = RCL(@"Asks Codex to fix this comment in the task");
        [c->_fix addTarget:self action:@selector(tapFix:) forControlEvents:UIControlEventTouchUpInside]; [c.contentView addSubview:c->_fix];
        c.isAccessibilityElement = NO;
    }
    [c->_comment release]; c->_comment = [r->comment retain];
    unsigned bg = dark ? 0x141d19 : 0xffffff;
    c.backgroundColor = c.contentView.backgroundColor = RCHex(bg);
    c->_box.image = [RCTheme imageForKey:(dark ? @"cx-note-d" : @"cx-note") size:CGSizeMake(16, 16) capInsets:UIEdgeInsetsMake(7, 7, 7, 7) drawing:^(CGContextRef ctx, CGRect rr) {
        CGRect b = CGRectInset(rr, .5, .5); CGPathRef p = RCCreateRoundedRectPath(b, 6);
        CGContextSaveGState(ctx); CGContextAddPath(ctx, p); CGContextClip(ctx);
        RCDrawVerticalGradient(ctx, b, [NSArray arrayWithObjects:RCHex(dark ? 0x4a4020 : 0xfff8d8), RCHex(dark ? 0x3a3218 : 0xfbeaa8), nil], nil);
        CGContextRestoreGState(ctx); CGContextAddPath(ctx, p); CGContextSetStrokeColorWithColor(ctx, RCHex(dark ? 0x7a6420 : 0xd8b54a).CGColor); CGContextSetLineWidth(ctx, 1); CGContextStrokePath(ctx); CGPathRelease(p);
    }];
    UIColor *ink = RCHex(dark ? 0xf3e3a8 : 0x4a3500);
    c->_title.textColor = ink; c->_text.textColor = ink;
    c->_title.text = r->comment.title.length ? r->comment.title : RCL(@"Codex · review");
    RCLabelSetText(c->_text, RCDisplayText(r->comment.text));
    CGFloat w = tv.bounds.size.width ? tv.bounds.size.width : 320, tw = [self noteTextWidth], th = ceil(RCMeasureText(r->comment.text, c->_text.font, tw).height);
    CGFloat h = [self noteHeight:r->comment];
    c->_box.frame = CGRectMake(RC_DIFF_NOTE_X, 4, w - RC_DIFF_NOTE_X - 8, h - 10);
    c->_title.frame = CGRectMake(RC_DIFF_NOTE_X + 10, 12, tw, 16);
    c->_text.frame = CGRectMake(RC_DIFF_NOTE_X + 10, 28, tw, th);
    c->_fix.hidden = !_fixAvailable;
    CGFloat fw = MAX(90, [RCL(@"Fix") sizeWithFont:c->_fix.titleLabel.font].width + 28);
    c->_fix.frame = CGRectMake(RC_DIFF_NOTE_X + 10, 28 + th + 8, fw, 26);
    c->_title.isAccessibilityElement = NO;
    c->_text.accessibilityLabel = [NSString stringWithFormat:@"%@: %@", c->_title.text, r->comment.text];
    return c;
}
- (void)tapFix:(UIButton *)b {
    UIView *v = b; while (v && ![v isKindOfClass:[RCDiffNoteCell class]]) v = v.superview;
    RCDiffComment *cm = v ? ((RCDiffNoteCell *)v)->_comment : nil;
    if (cm && [_delegate respondsToSelector:@selector(diffController:didTapFixComment:)]) [_delegate diffController:self didTapFixComment:cm];
}
- (void)setFixAvailable:(BOOL)f { _fixAvailable = f; if (self.isViewLoaded) [self.tableView reloadData]; }

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.tableView.bounds.size.width != _width) { _width = self.tableView.bounds.size.width; self.tableView.tableHeaderView = [self headerView]; [self.tableView reloadData]; }
}
- (void)setChange:(RCFileChange *)c { if (c == _change) return; [_change release]; _change = [c retain]; if (self.isViewLoaded) self.tableView.tableHeaderView = [self headerView]; }
@end
