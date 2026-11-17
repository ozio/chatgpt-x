#import "RCApprovalPartView.h"
#import "RCCodeBlockView.h"
#import "RCLampView.h"
#import "RCButton.h"
#import "RCTheme.h"

#define RC_AP_HEAD 31

@interface RCApprovalPartView () {
    NSString *_title, *_target, *_targetGlyph, *_detail, *_command, *_allowTitle, *_resolvedText;
    RCLampView *_lamp; UILabel *_head, *_targetLabel, *_detailLabel, *_commandLabel, *_resolved; UIImageView *_tile;
    BOOL _allowAvailable,_denyAvailable;
    RCButton *_deny, *_allow; UIActivityIndicatorView *_spinner; CGRect _cmdBox;
}
@end

@implementation RCApprovalPartView
@synthesize allowAvailable=_allowAvailable,denyAvailable=_denyAvailable;
@synthesize title = _title, target = _target, targetGlyph = _targetGlyph, targetTile = _targetTile, detail = _detail, command = _command, allowTitle = _allowTitle, resolvedText = _resolvedText, state = _state, busy = _busy, approvalDelegate = _approvalDelegate;

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _allowAvailable=_denyAvailable=YES;self.plainFill = YES; self.fillTop = 0xffffff;
        _lamp = [[RCLampView alloc] initWithDiameter:8]; [self addSubview:_lamp];
        _head = [[self labelWithRole:RCPartTextTitle font:[UIFont boldSystemFontOfSize:14]] retain];
        _head.accessibilityTraits = UIAccessibilityTraitHeader;
        _tile = [[UIImageView alloc] initWithFrame:CGRectZero]; [self addSubview:_tile];
        _targetLabel = [[self labelWithRole:RCPartTextTitle font:[UIFont boldSystemFontOfSize:15]] retain];
        _targetLabel.numberOfLines = 0; _targetLabel.lineBreakMode = NSLineBreakByCharWrapping;
        _detailLabel = [[self labelWithRole:RCPartTextSecondary font:[UIFont systemFontOfSize:13]] retain];
        _detailLabel.numberOfLines = 0; _detailLabel.lineBreakMode = NSLineBreakByWordWrapping;
        _commandLabel = [[UILabel alloc] initWithFrame:CGRectZero]; _commandLabel.backgroundColor = [UIColor clearColor];
        _commandLabel.font = [RCCodeBlockView codeFont]; _commandLabel.textColor = RCHex(0xd8efe2);
        _commandLabel.numberOfLines = 0; _commandLabel.lineBreakMode = NSLineBreakByCharWrapping;
        [self addSubview:_commandLabel];
        _resolved = [[self labelWithRole:RCPartTextSecondary font:[UIFont boldSystemFontOfSize:13]] retain];
        _deny = [[RCButton buttonWithStyle:RCButtonStyleLarge title:RCL(@"Deny")] retain];
        _deny.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        [_deny addTarget:self action:@selector(tapDeny) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_deny];
        _allow = [[RCButton buttonWithStyle:RCButtonStyleLargeGreen title:RCL(@"Allow")] retain];
        _allow.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        [_allow addTarget:self action:@selector(tapAllow) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_allow];
        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _spinner.hidesWhenStopped = YES; [self addSubview:_spinner];
        [self refresh];
    }
    return self;
}
- (void)dealloc {
    [_title release]; [_target release]; [_targetGlyph release]; [_detail release]; [_command release]; [_allowTitle release]; [_resolvedText release];
    [_lamp release]; [_head release]; [_targetLabel release]; [_detailLabel release]; [_commandLabel release]; [_resolved release]; [_tile release];
    [_deny release]; [_allow release]; [_spinner release]; [super dealloc];
}

static void RCSetCopy(NSString **slot, NSString *v) { if (*slot != v) { [*slot release]; *slot = [v copy]; } }
- (void)setTitle:(NSString *)v { RCSetCopy(&_title, v); [self changed]; }
- (void)setTarget:(NSString *)v { RCSetCopy(&_target, v); [self changed]; }
- (void)setTargetGlyph:(NSString *)v { RCSetCopy(&_targetGlyph, v); [self changed]; }
- (void)setTargetTile:(RCTileColor)t { _targetTile = t; [self changed]; }
- (void)setDetail:(NSString *)v { RCSetCopy(&_detail, v); [self changed]; }
- (void)setCommand:(NSString *)v { RCSetCopy(&_command, v); [self changed]; }
- (void)setAllowTitle:(NSString *)v { RCSetCopy(&_allowTitle, v); [self changed]; }
- (void)setResolvedText:(NSString *)v { RCSetCopy(&_resolvedText, v); [self changed]; }
- (void)setState:(RCApprovalState)s { _state = s; if (s != RCApprovalPending) _busy = NO; [self changed]; }
- (void)setAllowAvailable:(BOOL)b{_allowAvailable=b;[self changed];}
- (void)setDenyAvailable:(BOOL)b{_denyAvailable=b;[self changed];}
- (void)setBusy:(BOOL)b { _busy = b; [self changed]; }
- (void)changed { [self refresh]; [self notifyHeightChange]; }

- (void)refresh {
    BOOL pending = _state == RCApprovalPending;
    _lamp.state = pending ? RCLampInfo : (_state == RCApprovalAllowed ? RCLampOK : RCLampError);
    _head.text = _title.length ? _title : (pending ? RCL(@"Codex is waiting for permission") : RCL(@"Codex asked for permission"));
    _tile.image = _targetGlyph.length ? [RCGlyph tileNamed:_targetGlyph color:_targetTile size:29] : nil;
    RCLabelSetText(_targetLabel, _target.length ? RCDisplayText(_target) : nil);
    RCLabelSetText(_detailLabel, _detail.length ? RCDisplayText(_detail) : nil);
    _commandLabel.text = _command.length ? [@"$ " stringByAppendingString:_command] : nil;
    _commandLabel.accessibilityLabel = _command.length ? [NSString stringWithFormat:@"%@: %@", RCL(@"Command"), _command] : nil;
    _resolved.text = pending ? nil : (_resolvedText.length ? _resolvedText : (_state == RCApprovalAllowed ? RCL(@"Allowed") : RCL(@"Denied")));
    [_allow setTitle:(_allowTitle.length ? _allowTitle : RCL(@"Allow")) forState:UIControlStateNormal];
    _deny.hidden = !pending || _busy || !_denyAvailable;
    _allow.hidden = !pending || _busy || !_allowAvailable;
    if (pending && _busy) [_spinner startAnimating]; else [_spinner stopAnimating];
    _spinner.activityIndicatorViewStyle = [RCTheme isDark] ? UIActivityIndicatorViewStyleWhite : UIActivityIndicatorViewStyleGray;
    _head.accessibilityValue = pending ? (_busy ? RCL(@"Sending your decision…") : RCL(@"Waiting for your decision")) : _resolved.text;
    _allow.accessibilityHint = RCL(@"Lets Codex run this action");
    _deny.accessibilityHint = RCL(@"Codex will not run this action");
    [self setNeedsLayout]; [self setNeedsDisplay];
}
- (void)applyAppearance { [super applyAppearance]; [self refresh]; }

- (CGFloat)layoutForWidth:(CGFloat)w apply:(BOOL)apply {
    if (apply) { _lamp.center = CGPointMake(14, RC_AP_HEAD / 2.0); _head.frame = CGRectMake(24, 0, w - 34, RC_AP_HEAD); }
    CGFloat y = RC_AP_HEAD + 1 + 8, x = 10;
    if (_tile.image) { if (apply) _tile.frame = CGRectMake(10, y, 29, 31); x = 47; }
    CGFloat tw = w - x - 10, top = y;
    if (_targetLabel.text.length) { CGFloat h = ceil(RCMeasureText(_targetLabel.text, _targetLabel.font, tw).height); if (apply) _targetLabel.frame = CGRectMake(x, y, tw, h); y += h + 1; }
    if (_detailLabel.text.length) { CGFloat h = ceil(RCMeasureText(_detailLabel.text, _detailLabel.font, tw).height); if (apply) _detailLabel.frame = CGRectMake(x, y, tw, h); y += h; }
    if (_tile.image) y = MAX(y, top + 31);
    if (_commandLabel.text.length) {
        CGFloat cw = w - 20 - 16, h = ceil(RCMeasureText(_commandLabel.text, _commandLabel.font, cw).height);
        y += 8; _cmdBox = CGRectMake(10, y, w - 20, h + 14);
        if (apply) _commandLabel.frame = CGRectMake(18, y + 7, cw, h);
        y += h + 14;
    } else _cmdBox = CGRectZero;
    if (_state == RCApprovalPending) {
        if (_busy) { if (apply) _spinner.center = CGPointMake(w / 2, y + 10 + 22); }
        else if (apply) { CGFloat bw = floor((w - 20 - 10) / 2); _deny.frame = CGRectMake(10, y + 10, bw, 44); _allow.frame = CGRectMake(w - 10 - bw, y + 10, bw, 44); }
        y += 10 + 44 + 10;
    } else {
        if (apply) _resolved.frame = CGRectMake(10, y + 7, w - 20, 18);
        y += 7 + 18 + 8;
    }
    return y;
}

- (void)drawContent:(CGContextRef)ctx {
    BOOL dark = [RCTheme isDark];
    CGFloat w = self.bounds.size.width;
    if (dark) { CGContextSetFillColorWithColor(ctx, RCHex(0x1d2a24).CGColor); CGContextFillRect(ctx, self.bounds); }
    RCDrawVerticalGradient(ctx, CGRectMake(0, 0, w, RC_AP_HEAD), [NSArray arrayWithObjects:RCHex(dark ? 0x22334a : 0xf3f8ff), RCHex(dark ? 0x1b2a3d : 0xe1ebf8), nil], nil);
    [self drawHairlineAtY:RC_AP_HEAD context:ctx];
    if (!CGRectIsEmpty(_cmdBox)) {
        CGPathRef p = RCCreateRoundedRectPath(_cmdBox, 6);
        CGContextAddPath(ctx, p); CGContextSetFillColorWithColor(ctx, RCHex(dark ? 0x101a15 : 0x1b2b24).CGColor); CGContextFillPath(ctx); CGPathRelease(p);
    }
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    if (_state != RCApprovalPending) return;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGPathRef p = RCCreateRoundedRectPath(CGRectInset(self.bounds, 1, 1), 8);
    CGContextAddPath(ctx, p); CGContextSetStrokeColorWithColor(ctx, RCHex([RCTheme isDark] ? 0x4c7fc4 : 0x6f9fe0).CGColor); CGContextSetLineWidth(ctx, 2); CGContextStrokePath(ctx);
    CGPathRelease(p);
}

- (void)tapAllow { if ([_approvalDelegate respondsToSelector:@selector(approvalPartDidAllow:)]) [_approvalDelegate approvalPartDidAllow:self]; }
- (void)tapDeny { if ([_approvalDelegate respondsToSelector:@selector(approvalPartDidDeny:)]) [_approvalDelegate approvalPartDidDeny:self]; }
@end
