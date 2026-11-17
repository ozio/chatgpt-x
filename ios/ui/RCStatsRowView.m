#import "RCStatsRowView.h"
#import "RCTheme.h"

@implementation RCStatItem
@synthesize value = _value, caption = _caption, tint = _tint;
+ (id)itemWithValue:(NSString *)value caption:(NSString *)caption tint:(RCStatTint)tint { RCStatItem *i = [[[self alloc] init] autorelease]; i.value = value; i.caption = caption; i.tint = tint; return i; }
- (void)dealloc { [_value release]; [_caption release]; [super dealloc]; }
@end

@interface RCStatsRowView () { NSArray *_items; NSMutableArray *_cols, *_ax; }
@end

@implementation RCStatsRowView
- (id)initWithFrame:(CGRect)frame {
    if (CGRectIsEmpty(frame)) frame = CGRectMake(0, 0, 320, 46);
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor]; _cols = [[NSMutableArray alloc] init]; _ax = [[NSMutableArray alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh) name:RCThemeAppearanceDidChangeNotification object:nil];
    }
    return self;
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; [_items release]; [_cols release]; [_ax release]; [super dealloc]; }
- (NSArray *)items { return _items; }
- (void)setItems:(NSArray *)items {
    [_items release]; _items = [(items.count > 4 ? [items subarrayWithRange:NSMakeRange(0, 4)] : items) copy];
    for (NSArray *c in _cols) for (UIView *v in c) [v removeFromSuperview];
    [_cols removeAllObjects];
    for (NSUInteger i = 0; i < _items.count; i++) {
        UILabel *v = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease], *c = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
        for (UILabel *l in [NSArray arrayWithObjects:v, c, nil]) { l.backgroundColor = [UIColor clearColor]; l.textAlignment = NSTextAlignmentCenter; l.isAccessibilityElement = NO; [self addSubview:l]; }
        v.font = [UIFont boldSystemFontOfSize:17]; c.font = [UIFont systemFontOfSize:11];
        [_cols addObject:[NSArray arrayWithObjects:v, c, nil]];
    }
    [self refresh];
}
- (void)refresh {
    BOOL dark = [RCTheme isDark];
    [_ax removeAllObjects];
    for (NSUInteger i = 0; i < _cols.count; i++) {
        RCStatItem *it = [_items objectAtIndex:i]; UILabel *v = [[_cols objectAtIndex:i] objectAtIndex:0], *c = [[_cols objectAtIndex:i] objectAtIndex:1];
        v.text = RCDisplayText(it.value); c.text = it.caption;
        v.textColor = it.tint == RCStatAdded ? RCHex(dark ? 0x6fd49a : 0x1f8a4c) : (it.tint == RCStatRemoved ? RCHex(dark ? 0xff8c7f : 0xc42515) : (dark ? RCHex(0xe3ece7) : [RCTheme inkColor]));
        c.textColor = [RCTheme noteTextColor];
        v.shadowColor = c.shadowColor = [RCTheme engravedShadowColor]; v.shadowOffset = c.shadowOffset = [RCTheme engravedShadowOffset];
        UIAccessibilityElement *e = [[[UIAccessibilityElement alloc] initWithAccessibilityContainer:self] autorelease];
        e.accessibilityLabel = [NSString stringWithFormat:@"%@: %@", it.caption, it.value]; [_ax addObject:e];
    }
    [self setNeedsLayout];
}
- (BOOL)isAccessibilityElement { return NO; }
- (NSInteger)accessibilityElementCount { return (NSInteger)_ax.count; }
- (id)accessibilityElementAtIndex:(NSInteger)i { return i >= 0 && (NSUInteger)i < _ax.count ? [_ax objectAtIndex:(NSUInteger)i] : nil; }
- (NSInteger)indexOfAccessibilityElement:(id)e { NSUInteger i = [_ax indexOfObject:e]; return i == NSNotFound ? NSNotFound : (NSInteger)i; }
- (CGFloat)heightForWidth:(CGFloat)w { (void)w; return 46; }
- (CGSize)sizeThatFits:(CGSize)s { return CGSizeMake(s.width, 46); }
- (void)layoutSubviews {
    [super layoutSubviews];
    NSUInteger n = _cols.count; if (!n) return;
    CGFloat w = self.bounds.size.width - 20, cw = floor(w / n);
    for (NSUInteger i = 0; i < n; i++) {
        CGFloat x = 10 + cw * i;
        [[[_cols objectAtIndex:i] objectAtIndex:0] setFrame:CGRectMake(x, 4, cw, 21)];
        [[[_cols objectAtIndex:i] objectAtIndex:1] setFrame:CGRectMake(x, 25, cw, 15)];
        if (i < _ax.count) [[_ax objectAtIndex:i] setAccessibilityFrame:[self convertRect:CGRectMake(x, 4, cw, 36) toView:nil]];
    }
}
@end
