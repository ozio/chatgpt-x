#import "RCBannerView.h"
#import "RCTheme.h"
#import "RCLampView.h"

@interface RCBannerView () { UILabel *_label; RCLampView *_lamp; RCButton *_action; }
@end

@implementation RCBannerView
@synthesize kind = _kind, actionButton = _action;

- (id)initWithKind:(RCBannerKind)kind text:(NSString *)text actionTitle:(NSString *)actionTitle {
    if ((self = [super initWithFrame:CGRectMake(0, 0, 320, 34)])) {
        self.contentMode = UIViewContentModeRedraw;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _label = [[UILabel alloc] initWithFrame:CGRectZero];
        _label.backgroundColor = [UIColor clearColor];
        _label.font = [UIFont boldSystemFontOfSize:13];
        _label.numberOfLines = 0;
        _label.lineBreakMode = NSLineBreakByWordWrapping;
        [self addSubview:_label];
        _lamp = [[RCLampView alloc] initWithDiameter:9];
        [self addSubview:_lamp];
        if (actionTitle.length) {
            _action = [[RCButton buttonWithStyle:RCButtonStylePillGo title:actionTitle] retain];
            [self addSubview:_action];
        }
        self.text = text;
        self.kind = kind;
    }
    return self;
}

- (void)dealloc { [_label release]; [_lamp release]; [_action release]; [super dealloc]; }

- (NSString *)text { return _label.text; }
- (void)setText:(NSString *)text { RCLabelSetText(_label, text); self.accessibilityLabel = text; [self setNeedsLayout]; }

- (void)setKind:(RCBannerKind)kind {
    _kind = kind;
    BOOL warn = kind == RCBannerWarning, busy = kind == RCBannerBusy;
    _lamp.state = busy ? RCLampBusy : warn ? RCLampWarn : RCLampError;
    _label.textColor = busy ? [RCTheme answerTextColor] : warn ? RCHex(0x5a3a00) : [UIColor whiteColor];
    _label.shadowColor = busy ? [UIColor clearColor] : warn ? RCHexA(0xffffff, .5) : RCHexA(0, .4);
    _label.shadowOffset = warn ? CGSizeMake(0, 1) : CGSizeMake(0, -1);
    [self setNeedsDisplay];
}

- (CGFloat)textWidthForWidth:(CGFloat)width { return width - 34 - (_action ? 90 : 10); }

- (CGFloat)heightForWidth:(CGFloat)width {
    CGSize s = RCMeasureText(_label.text, _label.font, [self textWidthForWidth:width]);
    return MAX(34, ceil(s.height) + 16 + 1);
}
- (CGSize)sizeThatFits:(CGSize)size { CGFloat w = size.width > 0 ? size.width : 320; return CGSizeMake(w, [self heightForWidth:w]); }

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    _label.frame = CGRectMake(34, 8, [self textWidthForWidth:w], self.bounds.size.height - 17);
    CGRect lf = _lamp.frame;
    lf.origin = CGPointMake(13 - (lf.size.width - 9) / 2, 12 - (lf.size.height - 9) / 2);
    _lamp.frame = lf;
    if (_action) { CGRect af = _action.frame; af.origin = CGPointMake(w - 8 - af.size.width, 6); _action.frame = af; }
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    BOOL warn = _kind == RCBannerWarning, busy = _kind == RCBannerBusy;
    NSArray *colors = busy ? @[[RCTheme cardColor],[RCTheme cardHeldColor]] : warn ? [NSArray arrayWithObjects:RCHex(0xffe7a3), RCHex(0xf7cd5c), nil] : [NSArray arrayWithObjects:RCHex(0xe86a5d), RCHex(0xc33a2b), nil];
    RCDrawVerticalGradient(ctx, b, colors, nil);
    CGContextSetFillColorWithColor(ctx, (busy ? [RCTheme cardStrokeColor] : RCHex(warn ? 0xb98a16 : 0x7d1a10)).CGColor);
    CGContextFillRect(ctx, CGRectMake(0, b.size.height - 1, b.size.width, 1));
}
@end
