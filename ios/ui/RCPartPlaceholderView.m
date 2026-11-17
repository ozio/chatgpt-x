#import "RCPartPlaceholderView.h"
#import "RCTheme.h"

@interface RCPartPlaceholderView () { UIImageView *_tile; UILabel *_title, *_text; }
@end

@implementation RCPartPlaceholderView

+ (NSString *)defaultText { return RCL(@"This part of the answer cannot be shown on the iPhone yet — it is saved in the conversation."); }

- (id)initWithGlyph:(NSString *)glyph tile:(RCTileColor)tile title:(NSString *)title text:(NSString *)text {
    if ((self = [super initWithFrame:CGRectMake(0, 0, 274, 60)])) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        _tile = [[UIImageView alloc] initWithImage:[RCGlyph tileNamed:glyph color:tile size:29]];
        [self addSubview:_tile];
        _title = [[UILabel alloc] initWithFrame:CGRectZero];
        _title.font = [UIFont boldSystemFontOfSize:14];
        _title.textColor = RCHex(0x33453d);
        _title.text = title;
        _text = [[UILabel alloc] initWithFrame:CGRectZero];
        _text.font = [UIFont systemFontOfSize:13];
        _text.textColor = RCHex(0x5f6f67);
        _text.numberOfLines = 0;
        _text.lineBreakMode = NSLineBreakByWordWrapping;
        RCLabelSetText(_text, text ? text : [RCPartPlaceholderView defaultText]);
        for (UILabel *l in [NSArray arrayWithObjects:_title, _text, nil]) { l.backgroundColor = [UIColor clearColor]; [self addSubview:l]; }
        self.isAccessibilityElement = YES;
        self.accessibilityLabel = [NSString stringWithFormat:@"%@. %@", title, _text.text];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appearanceChanged) name:RCThemeAppearanceDidChangeNotification object:nil];
        [self appearanceChanged];
    }
    return self;
}

- (void)appearanceChanged {
    BOOL dark = [RCTheme isDark];
    _title.textColor = dark ? RCHex(0xe3ece7) : RCHex(0x33453d);
    _text.textColor = dark ? RCHex(0xb8c9c0) : RCHex(0x5f6f67);
    [self setNeedsDisplay];
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; [_tile release]; [_title release]; [_text release]; [super dealloc]; }

- (CGFloat)textHeightForWidth:(CGFloat)width {
    return RCMeasureText(_text.text, _text.font, width - 54).height;
}
- (CGFloat)heightForWidth:(CGFloat)width { return MAX(10 + 18 + [self textHeightForWidth:width] + 10, 47); }
- (CGSize)sizeThatFits:(CGSize)size { return CGSizeMake(size.width, [self heightForWidth:size.width]); }

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width;
    _tile.frame = CGRectMake(8, 8, 29, 31);
    _title.frame = CGRectMake(44, 10, w - 54, 18);
    _text.frame = CGRectMake(44, 28, w - 54, [self textHeightForWidth:w]);
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGPathRef p = RCCreateRoundedRectPath(CGRectInset(self.bounds, .5, .5), 8);
    CGContextAddPath(ctx, p);
    BOOL dark = [RCTheme isDark];
    CGContextSetFillColorWithColor(ctx, RCHex(dark ? 0x22302a : 0xf4f7f5).CGColor);
    CGContextFillPath(ctx);
    CGFloat dash[2] = {3, 2};
    CGContextSetLineDash(ctx, 0, dash, 2);
    CGContextAddPath(ctx, p);
    CGContextSetStrokeColorWithColor(ctx, RCHex(dark ? 0x3d5248 : 0xb7c5be).CGColor);
    CGContextSetLineWidth(ctx, 1);
    CGContextStrokePath(ctx);
    CGPathRelease(p);
}
@end
