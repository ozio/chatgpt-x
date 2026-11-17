#import "RCEmptyChatView.h"
#import "RCTheme.h"
#import "RCGlyph.h"
#import <QuartzCore/QuartzCore.h> // headers only (layer messages), no QuartzCore link

@interface RCEmptyChatView () { UIImageView *_logo; UILabel *_titleLabel, *_messageLabel, *_toggleLabel; UIView *_cell; UIImageView *_ghost; UISwitch *_switch; }
@end

@implementation RCEmptyChatView
@synthesize temporary = _temporary, showsTemporaryToggle = _showsTemporaryToggle, temporarySwitch = _switch;

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        // Bare debossed mark engraved into the linen: no tile, clip or layer shadow.
        _logo = [[UIImageView alloc] initWithImage:[RCTheme brandMarkImage:RCBrandMarkDebossed size:72 grey:NO]];
        _logo.isAccessibilityElement = NO;
        [self addSubview:_logo];
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.font = [UIFont boldSystemFontOfSize:22];
        _titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
        _messageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _messageLabel.font = [UIFont systemFontOfSize:14];
        _messageLabel.numberOfLines = 0;
        _messageLabel.lineBreakMode = NSLineBreakByWordWrapping;
        for (UILabel *l in [NSArray arrayWithObjects:_titleLabel, _messageLabel, nil]) { l.backgroundColor = [UIColor clearColor]; l.textAlignment = NSTextAlignmentCenter; [self addSubview:l]; }
        _cell = [[UIView alloc] initWithFrame:CGRectZero];
        _cell.backgroundColor = [UIColor whiteColor];
        _cell.layer.cornerRadius = 9;
        _cell.layer.borderWidth = 1;
        _cell.layer.borderColor = RCHex(0xaebbb4).CGColor;
        [self addSubview:_cell];
        _ghost = [[UIImageView alloc] initWithImage:[RCGlyph imageNamed:@"ghost" size:20 color:RCHex(0x4b5d55)]];
        [_cell addSubview:_ghost];
        _toggleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _toggleLabel.backgroundColor = [UIColor clearColor];
        _toggleLabel.font = [UIFont boldSystemFontOfSize:17];
        _toggleLabel.textColor = [RCTheme inkColor];
        _toggleLabel.text = RCL(@"Temporary chat");
        [_cell addSubview:_toggleLabel];
        _switch = [[UISwitch alloc] init];
        _switch.accessibilityLabel = RCL(@"Temporary chat");
        [_cell addSubview:_switch];
        _cell.hidden = YES;
        self.title = RCL(@"What can I help with?");
        self.message = RCL(@"Ask anything. The answer appears as it is written.");
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyAppearance) name:RCThemeAppearanceDidChangeNotification object:nil];
        [self applyAppearance];
    }
    return self;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; [_logo release]; [_titleLabel release]; [_messageLabel release]; [_toggleLabel release]; [_cell release]; [_ghost release]; [_switch release]; [super dealloc]; }

- (void)applyAppearance {
    BOOL dark = [RCTheme isDark];
    _logo.image = [RCTheme brandMarkImage:RCBrandMarkDebossed size:72 grey:_temporary];
    _titleLabel.textColor = dark ? RCHex(0xb8c9c0) : RCHex(0x22362c);
    _messageLabel.textColor = dark ? RCHex(0xb8c9c0) : RCHex(0x6b7a72);
    _titleLabel.shadowColor = _messageLabel.shadowColor = [RCTheme engravedShadowColor];
    _titleLabel.shadowOffset = _messageLabel.shadowOffset = [RCTheme engravedShadowOffset];
}

- (NSString *)title { return _titleLabel.text; }
- (void)setTitle:(NSString *)t { RCLabelSetText(_titleLabel, t); [self setNeedsLayout]; }
- (NSString *)message { return _messageLabel.text; }
- (void)setMessage:(NSString *)m { RCLabelSetText(_messageLabel, m); [self setNeedsLayout]; }
- (void)setTemporary:(BOOL)t { _temporary = t; _logo.image = [RCTheme brandMarkImage:RCBrandMarkDebossed size:72 grey:t]; _logo.alpha = t ? .8 : 1; if (_switch.on != t) _switch.on = t; }
- (void)setShowsTemporaryToggle:(BOOL)v { _showsTemporaryToggle = v; _cell.hidden = !v; [self setNeedsLayout]; }

- (CGFloat)layoutForWidth:(CGFloat)w apply:(BOOL)apply {
    CGFloat y = 58;
    if (apply) _logo.frame = CGRectMake(floor((w - 72) / 2), y, 72, 72);
    y += 72 + 14;
    CGFloat th = RCMeasureText(_titleLabel.text, _titleLabel.font, w - 48).height;
    if (apply) _titleLabel.frame = CGRectMake(24, y, w - 48, th);
    y += th + 8;
    CGFloat mh = RCMeasureText(_messageLabel.text, _messageLabel.font, w - 48).height;
    if (apply) _messageLabel.frame = CGRectMake(24, y, w - 48, mh);
    y += mh;
    if (_showsTemporaryToggle) {
        y += 22;
        if (apply) {
            _cell.frame = CGRectMake(24, y, w - 48, 46);
            _ghost.frame = CGRectMake(10, 13, 20, 20);
            _toggleLabel.frame = CGRectMake(36, 12, w - 48 - 36 - 100, 21);
            CGRect sf = _switch.frame;
            _switch.frame = CGRectMake(w - 48 - 10 - sf.size.width, floor((46 - sf.size.height) / 2), sf.size.width, sf.size.height);
        }
        y += 46;
    }
    return y + 20;
}
- (CGFloat)heightForWidth:(CGFloat)width { return [self layoutForWidth:width apply:NO]; }
- (CGSize)sizeThatFits:(CGSize)size { return CGSizeMake(size.width, [self heightForWidth:size.width]); }
- (void)layoutSubviews { [super layoutSubviews]; [self layoutForWidth:self.bounds.size.width apply:YES]; }
@end
