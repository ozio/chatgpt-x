#import "RCFileChangesPartView.h"
#import "RCTheme.h"
#import "RCGlyph.h"

@implementation RCFileChange
@synthesize path = _path, kind = _kind, added = _added, removed = _removed, userInfo = _userInfo;
+ (id)changeWithPath:(NSString *)path kind:(RCFileChangeKind)kind added:(NSInteger)added removed:(NSInteger)removed {
    RCFileChange *c = [[[self alloc] init] autorelease]; c.path = path; c.kind = kind; c.added = added; c.removed = removed; return c;
}
- (void)dealloc { [_path release]; [_userInfo release]; [super dealloc]; }
- (NSString *)fileName { return [_path lastPathComponent]; }
- (NSString *)directory { NSRange r = [_path rangeOfString:@"/" options:NSBackwardsSearch]; return r.location == NSNotFound ? @"" : [_path substringToIndex:r.location + 1]; }
@end

static UIFont *RCCountsFont(CGFloat size) {
    UIFont *f = [UIFont fontWithName:@"Menlo-Bold" size:size];
    return f ? f : [UIFont fontWithName:@"Courier-Bold" size:size + 1];
}

NSAttributedString *RCChangeCountsText(NSInteger added, NSInteger removed, CGFloat fontSize) {
    BOOL dark = [RCTheme isDark];
    UIFont *f = RCCountsFont(fontSize);
    NSMutableAttributedString *s = [[[NSMutableAttributedString alloc] init] autorelease];
    [s appendAttributedString:[[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"+%ld", (long)added] attributes:
        [NSDictionary dictionaryWithObjectsAndKeys:f, NSFontAttributeName, RCHex(dark ? 0x6fd49a : 0x1f8a4c), NSForegroundColorAttributeName, nil]] autorelease]];
    [s appendAttributedString:[[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" −%ld", (long)removed] attributes:
        [NSDictionary dictionaryWithObjectsAndKeys:f, NSFontAttributeName, RCHex(dark ? 0xff8c7f : 0xc42515), NSForegroundColorAttributeName, nil]] autorelease]];
    return s;
}

NSString *RCChangeCountsAccessibilityText(NSInteger added, NSInteger removed) {
    return [NSString stringWithFormat:RCL(@"lines added: %ld, removed: %ld"), (long)added, (long)removed];
}

NSString *RCFileChangeKindName(RCFileChangeKind kind) {
    return kind == RCFileChangeAdded ? RCL(@"Added") : (kind == RCFileChangeDeleted ? RCL(@"Deleted") : RCL(@"Modified"));
}

UIImage *RCFileChangeBadge(RCFileChangeKind kind) {
    return [RCTheme imageForKey:[NSString stringWithFormat:@"cx-badge-%d", (int)kind] size:CGSizeMake(17, 18) capInsets:UIEdgeInsetsZero drawing:^(CGContextRef ctx, CGRect r) {
        unsigned top = kind == RCFileChangeAdded ? 0x7fdcab : (kind == RCFileChangeDeleted ? 0xff8c7f : 0xffc874);
        unsigned bottom = kind == RCFileChangeAdded ? 0x1e9656 : (kind == RCFileChangeDeleted ? 0xc9200f : 0xe07a0c);
        CGRect box = CGRectMake(0, 0, 17, 17);
        CGPathRef p = RCCreateRoundedRectPath(box, 4);
        CGContextSaveGState(ctx); CGContextAddPath(ctx, p); CGContextClip(ctx);
        RCDrawVerticalGradient(ctx, box, [NSArray arrayWithObjects:RCHex(top), RCHex(bottom), nil], nil);
        CGContextSetFillColorWithColor(ctx, RCHexA(0xffffff, .4).CGColor); CGContextFillRect(ctx, CGRectMake(0, 0, 17, 1));
        CGContextRestoreGState(ctx); CGPathRelease(p);
        NSString *letter = kind == RCFileChangeAdded ? @"A" : (kind == RCFileChangeDeleted ? @"D" : @"M");
        UIFont *f = [UIFont boldSystemFontOfSize:11];
        CGContextSetFillColorWithColor(ctx, RCHexA(0x000000, .35).CGColor);
        [letter drawInRect:CGRectMake(0, 1, 17, 14) withFont:f lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentCenter];
        CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
        [letter drawInRect:CGRectMake(0, 2, 17, 14) withFont:f lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentCenter];
        (void)r;
    }];
}

static NSAttributedString *RCPathText(RCFileChange *c) {
    BOOL dark = [RCTheme isDark];
    NSMutableAttributedString *s = [[[NSMutableAttributedString alloc] initWithString:c.directory attributes:
        [NSDictionary dictionaryWithObjectsAndKeys:[UIFont systemFontOfSize:13], NSFontAttributeName, RCHex(dark ? 0x8fa39a : 0x7c8c84), NSForegroundColorAttributeName, nil]] autorelease];
    [s appendAttributedString:[[[NSAttributedString alloc] initWithString:c.fileName attributes:
        [NSDictionary dictionaryWithObjectsAndKeys:[UIFont boldSystemFontOfSize:14], NSFontAttributeName, RCHex(dark ? 0xe3ece7 : 0x1d2924), NSForegroundColorAttributeName, nil]] autorelease]];
    return s;
}

static UIImage *RCRowHighlight(void) {
    return [RCTheme imageForKey:([RCTheme isDark] ? @"cx-row-hl-d" : @"cx-row-hl") size:CGSizeMake(4, 4) capInsets:UIEdgeInsetsMake(1, 1, 1, 1) drawing:^(CGContextRef ctx, CGRect r) {
        CGContextSetFillColorWithColor(ctx, RCHex([RCTheme isDark] ? 0x24342c : 0xe2f1e9).CGColor); CGContextFillRect(ctx, r);
    }];
}

#define RC_FC_HEAD 30
#define RC_FC_ROW 35

@interface RCFileChangesPartView () { NSArray *_changes; UILabel *_head, *_total; NSMutableArray *_rows; }
@end

@implementation RCFileChangesPartView
@synthesize changesDelegate = _changesDelegate;

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.plainFill = YES; self.fillTop = 0xffffff;
        _head = [[self labelWithRole:RCPartTextTitle font:[UIFont boldSystemFontOfSize:13]] retain];
        _head.isAccessibilityElement = YES; _head.accessibilityTraits = UIAccessibilityTraitHeader;
        _total = [[UILabel alloc] initWithFrame:CGRectZero]; _total.backgroundColor = [UIColor clearColor]; _total.textAlignment = NSTextAlignmentRight;
        [self addSubview:_total];
        _rows = [[NSMutableArray alloc] init];
    }
    return self;
}
- (void)dealloc { [_changes release]; [_head release]; [_total release]; [_rows release]; [super dealloc]; }

- (NSArray *)changes { return _changes; }
- (void)setChanges:(NSArray *)changes {
    if (changes == _changes || [changes isEqualToArray:_changes]) return;
    [_changes release]; _changes = [changes copy];
    for (UIView *v in _rows) [v removeFromSuperview];
    [_rows removeAllObjects];
    NSUInteger i = 0;
    for (RCFileChange *c in _changes) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.tag = (NSInteger)i++;
        [b addTarget:self action:@selector(tapRow:) forControlEvents:UIControlEventTouchUpInside];
        UIImageView *badge = [[[UIImageView alloc] initWithImage:RCFileChangeBadge(c.kind)] autorelease]; badge.tag = 101; [b addSubview:badge];
        UILabel *path = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease]; path.tag = 102; path.backgroundColor = [UIColor clearColor]; path.lineBreakMode = NSLineBreakByTruncatingHead; [b addSubview:path];
        UILabel *counts = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease]; counts.tag = 103; counts.backgroundColor = [UIColor clearColor]; counts.textAlignment = NSTextAlignmentRight; [b addSubview:counts];
        b.isAccessibilityElement = YES; b.accessibilityTraits = UIAccessibilityTraitButton;
        b.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", RCFileChangeKindName(c.kind), c.path];
        b.accessibilityValue = RCChangeCountsAccessibilityText(c.added, c.removed);
        b.accessibilityHint = RCL(@"Opens the diff");
        [self addSubview:b]; [_rows addObject:b];
    }
    [self applyAppearance];
    [self notifyHeightChange];
}

- (void)applyAppearance {
    [super applyAppearance];
    NSInteger a = 0, d = 0;
    for (RCFileChange *c in _changes) { a += c.added; d += c.removed; }
    _head.text = [NSString stringWithFormat:RCL(@"Changed files: %lu"), (unsigned long)_changes.count];
    _head.accessibilityValue = RCChangeCountsAccessibilityText(a, d);
    _total.attributedText = RCChangeCountsText(a, d, 12);
    NSUInteger i = 0;
    for (UIButton *b in _rows) {
        RCFileChange *c = [_changes objectAtIndex:i++];
        [b setBackgroundImage:RCRowHighlight() forState:UIControlStateHighlighted];
        ((UILabel *)[b viewWithTag:102]).attributedText = RCPathText(c);
        ((UILabel *)[b viewWithTag:103]).attributedText = RCChangeCountsText(c.added, c.removed, 11);
    }
}

- (CGFloat)layoutForWidth:(CGFloat)w apply:(BOOL)apply {
    if (apply) {
        _head.frame = CGRectMake(10, 0, w - 110, RC_FC_HEAD);
        _total.frame = CGRectMake(w - 100, 0, 90, RC_FC_HEAD);
        CGFloat y = RC_FC_HEAD + 1;
        for (UIButton *b in _rows) {
            b.frame = CGRectMake(1, y, w - 2, RC_FC_ROW);
            [b viewWithTag:101].frame = CGRectMake(9, 9, 17, 18);
            [b viewWithTag:103].frame = CGRectMake(w - 92, 0, 82, RC_FC_ROW);
            [b viewWithTag:102].frame = CGRectMake(33, 0, w - 2 - 33 - 92, RC_FC_ROW);
            y += RC_FC_ROW;
        }
    }
    return RC_FC_HEAD + 1 + RC_FC_ROW * _rows.count + 1;
}

- (void)drawContent:(CGContextRef)ctx {
    BOOL dark = [RCTheme isDark];
    RCDrawVerticalGradient(ctx, CGRectMake(0, 0, self.bounds.size.width, RC_FC_HEAD), [NSArray arrayWithObjects:RCHex(dark ? 0x26352e : 0xf7faf8), RCHex(dark ? 0x1f2c26 : 0xe9efec), nil], nil);
    if (dark) { CGContextSetFillColorWithColor(ctx, RCHex(0x1d2a24).CGColor); CGContextFillRect(ctx, CGRectMake(0, RC_FC_HEAD, self.bounds.size.width, self.bounds.size.height - RC_FC_HEAD)); }
    [self drawHairlineAtY:RC_FC_HEAD context:ctx];
    for (NSUInteger i = 1; i < _rows.count; i++) [self drawHairlineAtY:RC_FC_HEAD + 1 + RC_FC_ROW * i context:ctx];
}

- (void)tapRow:(UIButton *)b {
    if ((NSUInteger)b.tag >= _changes.count) return;
    if ([_changesDelegate respondsToSelector:@selector(fileChangesPart:didSelectChange:)]) [_changesDelegate fileChangesPart:self didSelectChange:[_changes objectAtIndex:(NSUInteger)b.tag]];
}
@end

@interface RCChangesStripView () { UIImageView *_bg, *_glyph, *_chev; UILabel *_text, *_counts; }
@end

@implementation RCChangesStripView
@synthesize fileCount = _fileCount, added = _added, removed = _removed, review = _review, reviewCount = _reviewCount;

- (id)initWithFrame:(CGRect)frame {
    if (CGRectIsEmpty(frame)) frame = CGRectMake(0, 0, 300, 38);
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        _bg = [[UIImageView alloc] initWithFrame:self.bounds]; _bg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; [self addSubview:_bg];
        _glyph = [[UIImageView alloc] initWithFrame:CGRectMake(10, 11, 16, 16)]; [self addSubview:_glyph];
        _text = [[UILabel alloc] initWithFrame:CGRectZero]; _text.backgroundColor = [UIColor clearColor]; _text.font = [UIFont systemFontOfSize:14]; [self addSubview:_text];
        _counts = [[UILabel alloc] initWithFrame:CGRectZero]; _counts.backgroundColor = [UIColor clearColor]; _counts.textAlignment = NSTextAlignmentRight; [self addSubview:_counts];
        _chev = [[UIImageView alloc] initWithFrame:CGRectZero]; [self addSubview:_chev];
        self.isAccessibilityElement = YES; self.accessibilityTraits = UIAccessibilityTraitButton;
        self.accessibilityHint = RCL(@"Opens the list of changed files");
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh) name:RCThemeAppearanceDidChangeNotification object:nil];
        [self refresh];
    }
    return self;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; [_bg release]; [_glyph release]; [_chev release]; [_text release]; [_counts release]; [super dealloc]; }
- (CGFloat)heightForWidth:(CGFloat)width { (void)width; return 38; }
- (CGSize)sizeThatFits:(CGSize)size { return CGSizeMake(size.width, 38); }

static UIImage *RCStripImage(BOOL pressed, BOOL review) {
    BOOL dark = [RCTheme isDark];
    NSString *key = [NSString stringWithFormat:@"cx-strip-%d%d%d", dark, pressed, review];
    return [RCTheme imageForKey:key size:CGSizeMake(22, 38) capInsets:UIEdgeInsetsMake(10, 10, 10, 10) drawing:^(CGContextRef ctx, CGRect r) {
        CGRect box = CGRectMake(.5, .5, r.size.width - 1, r.size.height - 2);
        CGContextSetFillColorWithColor(ctx, (dark ? RCHexA(0x000000, .4) : RCHexA(0xffffff, .9)).CGColor);
        CGPathRef sh = RCCreateRoundedRectPath(CGRectOffset(box, 0, 1), 9); CGContextAddPath(ctx, sh); CGContextFillPath(ctx); CGPathRelease(sh);
        CGPathRef p = RCCreateRoundedRectPath(box, 9);
        CGContextSaveGState(ctx); CGContextAddPath(ctx, p); CGContextClip(ctx);
        unsigned t = pressed ? (dark ? 0x2c3d35 : 0xe2f1e9) : (dark ? 0x26352e : 0xffffff), b = pressed ? (dark ? 0x24342c : 0xd5e8de) : (dark ? 0x1d2a24 : 0xeef3f0);
        if (review) { t = pressed ? (dark ? 0x3a3218 : 0xf5df8e) : (dark ? 0x4a4020 : 0xfff8d8); b = pressed ? (dark ? 0x30290f : 0xedd47a) : (dark ? 0x3a3218 : 0xfbe9a6); }
        RCDrawVerticalGradient(ctx, box, [NSArray arrayWithObjects:RCHex(t), RCHex(b), nil], nil);
        CGContextRestoreGState(ctx);
        CGContextAddPath(ctx, p); CGContextSetStrokeColorWithColor(ctx, RCHex(review ? (dark ? 0x7a6420 : 0xd8b54a) : (dark ? 0x2c3d35 : 0xaebbb4)).CGColor); CGContextSetLineWidth(ctx, 1); CGContextStrokePath(ctx);
        CGPathRelease(p);
    }];
}

- (void)refresh {
    BOOL dark = [RCTheme isDark];
    _bg.image = RCStripImage(self.highlighted, _review);
    _glyph.image = _review ? [RCGlyph imageNamed:@"edit" size:16 color:RCHex(dark ? 0xf3d27a : 0x8a6a00)] : [RCGlyph imageNamed:@"branch" size:16 color:RCHex(dark ? 0x8fcfab : 0x3c6f57)];
    if (_review) {
        UIColor *ink = RCHex(dark ? 0xf3e3a8 : 0x5a3a00);
        NSMutableAttributedString *r = [[[NSMutableAttributedString alloc] initWithString:RCL(@"Review") attributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIFont boldSystemFontOfSize:14], NSFontAttributeName, ink, NSForegroundColorAttributeName, nil]] autorelease];
        NSString *n = [NSString stringWithFormat:RCL(@"comments: %lu"), (unsigned long)_reviewCount];
        [r appendAttributedString:[[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" \u00b7 %@", n] attributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIFont systemFontOfSize:14], NSFontAttributeName, ink, NSForegroundColorAttributeName, nil]] autorelease]];
        _text.attributedText = r; _counts.attributedText = nil;
        _chev.image = [RCGlyph imageNamed:@"down" size:12 color:RCHex(dark ? 0xc9b46a : 0x9a7a20)]; _chev.transform = CGAffineTransformMakeRotation(-M_PI_2);
        self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", RCL(@"Review"), n]; self.accessibilityValue = nil;
        self.accessibilityHint = RCL(@"Opens the diff with the review comments");
        [self setNeedsLayout];
        return;
    }
    self.accessibilityHint = RCL(@"Opens the list of changed files");
    _chev.image = [RCGlyph imageNamed:@"down" size:12 color:RCHex(dark ? 0x8fa39a : 0x7c8c84)];
    _chev.transform = CGAffineTransformMakeRotation(-M_PI_2);
    NSMutableAttributedString *t = [[[NSMutableAttributedString alloc] initWithString:RCL(@"Changes") attributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIFont boldSystemFontOfSize:14], NSFontAttributeName, RCHex(dark ? 0xcfe0d7 : 0x33453d), NSForegroundColorAttributeName, nil]] autorelease];
    [t appendAttributedString:[[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" · %@", [NSString stringWithFormat:RCL(@"files: %lu"), (unsigned long)_fileCount]] attributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIFont systemFontOfSize:14], NSFontAttributeName, RCHex(dark ? 0xcfe0d7 : 0x33453d), NSForegroundColorAttributeName, nil]] autorelease]];
    _text.attributedText = t;
    _counts.attributedText = RCChangeCountsText(_added, _removed, 12);
    self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", RCL(@"Changes"), [NSString stringWithFormat:RCL(@"files: %lu"), (unsigned long)_fileCount]];
    self.accessibilityValue = RCChangeCountsAccessibilityText(_added, _removed);
}
- (void)setFileCount:(NSUInteger)n { _fileCount = n; [self refresh]; }
- (void)setAdded:(NSInteger)a { _added = a; [self refresh]; }
- (void)setRemoved:(NSInteger)r { _removed = r; [self refresh]; }
- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; _bg.image = RCStripImage(h, _review); }
- (void)setReview:(BOOL)r { _review = r; [self refresh]; }
- (void)setReviewCount:(NSUInteger)n { _reviewCount = n; [self refresh]; }

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    _glyph.frame = CGRectMake(11, 10, 16, 16);
    _chev.frame = CGRectMake(w - 22, 12, 12, 12);
    CGFloat cw = ceil([_counts.attributedText size].width);
    _counts.frame = CGRectMake(w - 28 - cw, 0, cw, 37);
    _text.frame = CGRectMake(34, 0, w - 34 - 28 - cw - 6, 37);
}
@end
