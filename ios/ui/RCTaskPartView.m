#import "RCTaskPartView.h"
#import "RCTheme.h"
#import "RCProgressView.h"

@implementation RCTaskRow
@synthesize text = _text, key = _key, lamp = _lamp;
+ (id)stepWithText:(NSString *)text lamp:(RCLampState)lamp { RCTaskRow *r = [[[self alloc] init] autorelease]; r.text = text; r.lamp = lamp; return r; }
+ (id)paramWithKey:(NSString *)key value:(NSString *)value { RCTaskRow *r = [[[self alloc] init] autorelease]; r.key = key; r.text = value; return r; }
- (void)dealloc { [_text release]; [_key release]; [super dealloc]; }
@end

@interface RCTaskPartView () { UIImageView *_tile; UILabel *_titleLabel, *_subLabel; RCProgressView *_bar; NSMutableArray *_rowViews; NSArray *_rows, *_footer; CGFloat _rowsTop, _footerTop; }
@end

@implementation RCTaskPartView
@synthesize progress = _progress;

- (id)initWithGlyph:(NSString *)glyph tile:(RCTileColor)tile {
    if ((self = [super initWithFrame:CGRectZero])) {
        _tile = [[UIImageView alloc] initWithImage:[RCGlyph tileNamed:glyph color:tile size:29]];
        [self addSubview:_tile];
        _titleLabel = [[self labelWithRole:RCPartTextTitle font:[UIFont boldSystemFontOfSize:15]] retain];
        _titleLabel.numberOfLines = 0;
        _titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
        _subLabel = [[self labelWithRole:RCPartTextSecondary font:[UIFont systemFontOfSize:12]] retain];
        _subLabel.numberOfLines = 0;
        _subLabel.lineBreakMode = NSLineBreakByWordWrapping;
        _bar = [[RCProgressView alloc] initWithFrame:CGRectMake(0, 0, 100, 9)];
        [self addSubview:_bar];
        _rowViews = [[NSMutableArray alloc] init];
        _progress = -1;
        _bar.hidden = YES;
    }
    return self;
}
- (id)initWithFrame:(CGRect)frame { return [self initWithGlyph:@"research" tile:RCTileOrange]; }

- (void)dealloc { [_tile release]; [_titleLabel release]; [_subLabel release]; [_bar release]; [_rowViews release]; [_rows release]; [_footer release]; [super dealloc]; }

- (NSString *)title { return _titleLabel.text; }
- (void)setTitle:(NSString *)t { RCLabelSetText(_titleLabel, RCDisplayText(t)); [self setNeedsLayout]; }
- (NSString *)subtitle { return _subLabel.text; }
- (void)setSubtitle:(NSString *)t { RCLabelSetText(_subLabel, RCDisplayText(t)); [self setNeedsLayout]; }
- (void)setProgress:(CGFloat)p { BOOL was = _bar.hidden; _progress = p; _bar.hidden = p < 0; if (p >= 0) [_bar setProgress:p animated:!was]; [self setNeedsLayout]; }

- (NSArray *)rows { return _rows; }
- (void)setRows:(NSArray *)rows {
    [_rows release]; _rows = [rows copy];
    for (NSArray *rv in _rowViews) for (UIView *v in rv) if ([v isKindOfClass:[UIView class]]) [v removeFromSuperview];
    [_rowViews removeAllObjects];
    for (RCTaskRow *r in _rows) {
        NSMutableArray *rv = [NSMutableArray array];
        UILabel *text = [self labelWithRole:RCPartTextBody font:[UIFont systemFontOfSize:13]];
        text.numberOfLines = 0;
        text.lineBreakMode = NSLineBreakByWordWrapping; RCLabelSetText(text, RCDisplayText(r.text));
        [rv addObject:text];
        if (r.key) { UILabel *k = [self labelWithRole:RCPartTextSecondary font:[UIFont systemFontOfSize:13]]; k.text = r.key; [rv addObject:k]; }
        else if (r.lamp != RCLampOff) { RCLampView *l = [[[RCLampView alloc] initWithDiameter:8] autorelease]; l.state = r.lamp; [self addSubview:l]; [rv addObject:l]; }
        [_rowViews addObject:rv];
    }
    [self setNeedsLayout];
}
- (NSArray *)footerButtons { return _footer; }
- (void)setFooterButtons:(NSArray *)b { for (UIView *v in _footer) [v removeFromSuperview]; [_footer release]; _footer = [b copy]; for (UIView *v in _footer) [self addSubview:v]; [self setNeedsLayout]; }

static CGFloat RCTextH(UILabel *l, CGFloat w) { return RCMeasureText(l.text, l.font, w).height; }

- (CGFloat)layoutForWidth:(CGFloat)w apply:(BOOL)apply {
    CGFloat tw = w - 48 - 10, th = RCTextH(_titleLabel, tw), sh = RCTextH(_subLabel, tw);
    if (apply) { _tile.frame = CGRectMake(10, 10, 29, 31); _titleLabel.frame = CGRectMake(48, 10, tw, th); _subLabel.frame = CGRectMake(48, 10 + th + 2, tw, sh); }
    CGFloat y = MAX(50, 10 + th + (sh ? 2 + sh : 0) + 8);
    if (_progress >= 0) { if (apply) _bar.frame = CGRectMake(10, y + 2, w - 20, 9); y += 2 + 9 + 10; }
    _rowsTop = _rowViews.count ? y : -1;
    if (_rowViews.count) {
        y += 7;
        for (NSArray *rv in _rowViews) {
            UILabel *text = [rv objectAtIndex:0];
            BOOL param = rv.count > 1 && [[rv objectAtIndex:1] isKindOfClass:[UILabel class]];
            BOOL lamp = rv.count > 1 && !param;
            CGFloat x = 10 + (param ? 76 : (lamp ? 13 : 0)), h = MAX(19, RCTextH(text, w - x - 10) + 2);
            if (apply) {
                text.frame = CGRectMake(x, y + 1, w - x - 10, h - 2);
                if (param) [[rv objectAtIndex:1] setFrame:CGRectMake(10, y + 1, 74, 17)];
                if (lamp) { UIView *l = [rv objectAtIndex:1]; l.center = CGPointMake(10 + 4, y + 10); }
            }
            y += h;
        }
        y += 8;
    }
    _footerTop = _footer.count ? y : -1;
    if (_footer.count) {
        CGFloat x = 10;
        for (UIView *b in _footer) { if (apply) b.frame = CGRectMake(x, y + 8, b.frame.size.width, 26); x += b.frame.size.width + 6; }
        y += 8 + 26 + 8;
    }
    return y;
}

- (void)drawContent:(CGContextRef)ctx {
    if (_rowsTop >= 0) [self drawHairlineAtY:_rowsTop context:ctx];
    if (_footerTop >= 0) [self drawHairlineAtY:_footerTop context:ctx];
}
@end
