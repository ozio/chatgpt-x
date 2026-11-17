#import "RCTimelineNoteView.h"
#import "RCTheme.h"

@interface RCTimelineNoteView () { UIImageView *_bg; UILabel *_label; RCLampView *_lampView; UIActivityIndicatorView *_spin; NSString *_text; }
@end

@implementation RCTimelineNoteView
@synthesize style = _style, lamp = _lamp;

- (id)initWithStyle:(RCTimelineNoteStyle)style {
    if ((self = [super initWithFrame:CGRectMake(0, 0, 300, 28)])) {
        _style = style;
        self.backgroundColor = [UIColor clearColor];
        _bg = [[UIImageView alloc] initWithFrame:CGRectZero]; [self addSubview:_bg];
        _label = [[UILabel alloc] initWithFrame:CGRectZero]; _label.backgroundColor = [UIColor clearColor];
        UIFont *mono = [UIFont fontWithName:@"Menlo-Regular" size:11]; if (!mono) mono = [UIFont fontWithName:@"Courier" size:12];
        _label.font = style == RCTimelineNoteMeta ? mono : [UIFont boldSystemFontOfSize:style == RCTimelineNoteCapsule ? 12 : 13];
        _label.numberOfLines = style == RCTimelineNoteActivity ? 1 : 0;
        _label.textAlignment = style == RCTimelineNoteCapsule ? NSTextAlignmentCenter : NSTextAlignmentLeft;
        [self addSubview:_label];
        _lampView = [[RCLampView alloc] initWithDiameter:style == RCTimelineNoteMeta ? 6 : 7]; [self addSubview:_lampView];
        _spin = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _spin.transform = CGAffineTransformMakeScale(.7, .7);
        [self addSubview:_spin];
        if (style == RCTimelineNoteActivity) [_spin startAnimating]; else _spin.hidden = YES;
        self.isAccessibilityElement = YES; self.accessibilityTraits = UIAccessibilityTraitStaticText | (style == RCTimelineNoteActivity ? UIAccessibilityTraitUpdatesFrequently : 0);
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh) name:RCThemeAppearanceDidChangeNotification object:nil];
        [self refresh];
    }
    return self;
}
- (id)initWithFrame:(CGRect)frame { (void)frame; return [self initWithStyle:RCTimelineNoteCapsule]; }
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; [_bg release]; [_label release]; [_lampView release]; [_spin release]; [_text release]; [super dealloc]; }

- (NSString *)text { return _text; }
- (void)setText:(NSString *)t { if ([t isEqualToString:_text]) return; [_text release]; _text = [t copy]; [self refresh]; }
- (void)setLamp:(RCLampState)l { _lamp = l; [self refresh]; }

- (void)refresh {
    BOOL dark = [RCTheme isDark];
    if (_style != RCTimelineNoteActivity) RCLabelSetText(_label, RCDisplayText(_text)); else _label.text = RCDisplayText(_text);
    _label.textColor = _style == RCTimelineNoteCapsule ? (dark ? RCHex(0xb8c9c0) : [RCTheme headerInkColor]) : [RCTheme noteTextColor];
    if (_style == RCTimelineNoteMeta) _label.textColor = _lamp == RCLampError ? RCHex(dark ? 0xff8c7f : 0xb0261a) : [RCTheme metaTextColor];
    _label.shadowColor = [RCTheme engravedShadowColor]; _label.shadowOffset = [RCTheme engravedShadowOffset];
    _lampView.state = _lamp; _lampView.hidden = _style == RCTimelineNoteActivity || _lamp == RCLampOff;
    _spin.activityIndicatorViewStyle = dark ? UIActivityIndicatorViewStyleWhite : UIActivityIndicatorViewStyleGray;
    _bg.hidden = _style != RCTimelineNoteCapsule;
    _bg.image = [RCTheme imageForKey:(dark ? @"cx-capsule-d" : @"cx-capsule") size:CGSizeMake(24, 22) capInsets:UIEdgeInsetsMake(11, 11, 10, 11) drawing:^(CGContextRef ctx, CGRect r) {
        CGPathRef p = RCCreateRoundedRectPath(r, 11);
        CGContextAddPath(ctx, p); CGContextSetFillColorWithColor(ctx, (dark ? RCHexA(0x000000, .35) : RCHexA(0xffffff, .55)).CGColor); CGContextFillPath(ctx);
        CGContextSaveGState(ctx); CGContextAddPath(ctx, p); CGContextClip(ctx);
        CGContextSetFillColorWithColor(ctx, RCHexA(0x000000, .1).CGColor); CGContextFillRect(ctx, CGRectMake(0, 0, r.size.width, 1));
        CGContextRestoreGState(ctx); CGPathRelease(p);
    }];
    self.accessibilityLabel = _text;
    [self setNeedsLayout];
}

- (CGFloat)labelWidthFor:(CGFloat)w { return w - 60 - (_lampView.hidden ? 0 : 12) - 20; }
- (CGFloat)heightForWidth:(CGFloat)width {
    if (_style == RCTimelineNoteActivity) return 26;
    if (_style == RCTimelineNoteMeta) return MAX(16, ceil(RCMeasureText(_label.text, _label.font, width - 8 - 12).height)) + 6;
    return MAX(22, ceil(RCMeasureText(_label.text, _label.font, [self labelWidthFor:width]).height) + 8) + 4;
}
- (CGSize)sizeThatFits:(CGSize)size { return CGSizeMake(size.width, [self heightForWidth:size.width]); }

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    if (_style == RCTimelineNoteActivity) {
        _spin.center = CGPointMake(12, 13);
        _label.frame = CGRectMake(26, 0, w - 30, 26);
        return;
    }
    if (_style == RCTimelineNoteMeta) {
        CGFloat lx = _lampView.hidden ? 4 : 16;
        _lampView.center = CGPointMake(7, 3 + 8);
        _label.frame = CGRectMake(lx, 3, w - lx - 4, ceil(RCMeasureText(_label.text, _label.font, w - lx - 4).height));
        return;
    }
    CGFloat lw = [self labelWidthFor:w];
    CGSize ts = RCMeasureText(_label.text, _label.font, lw);
    CGFloat tw = ceil(MIN(lw, ts.width)), th = ceil(ts.height), lampW = _lampView.hidden ? 0 : 12;
    CGFloat bw = tw + lampW + 20, bh = MAX(22, th + 8), bx = floor((w - bw) / 2);
    _bg.frame = CGRectMake(bx, 2, bw, bh);
    _lampView.center = CGPointMake(bx + 10 + 3.5, 2 + bh / 2);
    _label.frame = CGRectMake(bx + 10 + lampW, 2 + floor((bh - th) / 2), tw, th);
}
@end
