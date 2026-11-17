#import "RCTerminalPartView.h"
#import "RCCodeBlockView.h"
#import "RCTextStackView.h"
#import "RCLampView.h"
#import "RCTheme.h"
#import <QuartzCore/QuartzCore.h> // headers only (layer messages)

#define RC_TERM_HEAD 27
#define RC_TERM_TAIL 4
#define RC_TERM_MAX 200

@interface RCTerminalPartView () { UIImageView *_head; UILabel *_title, *_status; RCLampView *_lamp; UIButton *_stop, *_body; RCTextStackView *_text; BOOL _dying; }
@end

@implementation RCTerminalPartView
@synthesize command = _command, outputLines = _outputLines, state = _state, exitCode = _exitCode, duration = _duration, stopped = _stopped, stopAvailable = _stopAvailable, expanded = _expanded, delegate = _delegate;

static UIImage *RCStopImage(BOOL pressed) {
    return [RCTheme imageForKey:(pressed ? @"cx-stop-p" : @"cx-stop") size:CGSizeMake(14, 19) capInsets:UIEdgeInsetsMake(6, 6, 6, 6) drawing:^(CGContextRef ctx, CGRect r) {
        CGRect box = CGRectInset(r, .5, .5);
        CGPathRef p = RCCreateRoundedRectPath(box, 4);
        CGContextSaveGState(ctx); CGContextAddPath(ctx, p); CGContextClip(ctx);
        RCDrawVerticalGradient(ctx, box, [NSArray arrayWithObjects:RCHex(pressed ? 0x8e1105 : 0xef8378), RCHex(pressed ? 0xb81506 : 0xc51c0b), nil], nil);
        CGContextRestoreGState(ctx);
        CGContextAddPath(ctx, p); CGContextSetStrokeColorWithColor(ctx, RCHex(0x5c0b03).CGColor); CGContextSetLineWidth(ctx, 1); CGContextStrokePath(ctx);
        CGPathRelease(p);
    }];
}

- (id)initWithFrame:(CGRect)frame {
    if (CGRectIsEmpty(frame)) frame = CGRectMake(0, 0, 300, 80);
    if ((self = [super initWithFrame:frame])) {
        _duration = -1;
        self.backgroundColor = RCHex(0x1b2b24);
        self.layer.cornerRadius = 7; self.layer.borderWidth = 1; self.layer.borderColor = RCHex(0x10241b).CGColor;
        self.clipsToBounds = YES;
        _head = [[UIImageView alloc] initWithImage:[RCTheme imageForKey:@"code-head" size:CGSizeMake(4, 27) capInsets:UIEdgeInsetsMake(0, 1, 0, 1) drawing:^(CGContextRef ctx, CGRect r) {
            RCDrawVerticalGradient(ctx, CGRectMake(0, 0, r.size.width, 26), [NSArray arrayWithObjects:RCHex(0x3a5045), RCHex(0x26392f), nil], nil);
            CGContextSetFillColorWithColor(ctx, RCHex(0x0c1a13).CGColor); CGContextFillRect(ctx, CGRectMake(0, 26, r.size.width, 1));
            CGContextSetFillColorWithColor(ctx, RCHexA(0xffffff, .08).CGColor); CGContextFillRect(ctx, CGRectMake(0, 0, r.size.width, 1));
        }]];
        [self addSubview:_head];
        _title = [[UILabel alloc] initWithFrame:CGRectZero]; _title.backgroundColor = [UIColor clearColor];
        _title.attributedText = [[[NSAttributedString alloc] initWithString:[RCL(@"Terminal") uppercaseString] attributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIFont boldSystemFontOfSize:11], NSFontAttributeName, RCHex(0xa9c4b6), NSForegroundColorAttributeName, [NSNumber numberWithFloat:.5], NSKernAttributeName, nil]] autorelease];
        _title.shadowColor = [UIColor blackColor]; _title.shadowOffset = CGSizeMake(0, -1);
        _title.isAccessibilityElement = NO;
        [self addSubview:_title];
        _status = [[UILabel alloc] initWithFrame:CGRectZero]; _status.backgroundColor = [UIColor clearColor];
        _status.font = [UIFont boldSystemFontOfSize:11]; _status.textColor = RCHex(0xcfe3d8); _status.textAlignment = NSTextAlignmentRight;
        _status.shadowColor = [UIColor blackColor]; _status.shadowOffset = CGSizeMake(0, -1);
        _status.isAccessibilityElement = NO;
        [self addSubview:_status];
        _lamp = [[RCLampView alloc] initWithDiameter:7]; [self addSubview:_lamp];
        _stop = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        [_stop setBackgroundImage:RCStopImage(NO) forState:UIControlStateNormal];
        [_stop setBackgroundImage:RCStopImage(YES) forState:UIControlStateHighlighted];
        [_stop setTitle:RCL(@"Stop") forState:UIControlStateNormal];
        _stop.titleLabel.font = [UIFont boldSystemFontOfSize:11];
        _stop.titleLabel.shadowOffset = CGSizeMake(0, -1); [_stop setTitleShadowColor:RCHexA(0x000000, .4) forState:UIControlStateNormal];
        _stop.accessibilityLabel = RCL(@"Stop the command");
        [_stop addTarget:self action:@selector(tapStop) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_stop];
        _body = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        [_body setBackgroundImage:[RCTheme imageForKey:@"cx-term-hl" size:CGSizeMake(4, 4) capInsets:UIEdgeInsetsMake(1, 1, 1, 1) drawing:^(CGContextRef ctx, CGRect r) { CGContextSetFillColorWithColor(ctx, RCHex(0x23382e).CGColor); CGContextFillRect(ctx, r); }] forState:UIControlStateHighlighted];
        [_body addTarget:self action:@selector(toggle) forControlEvents:UIControlEventTouchUpInside];
        _body.isAccessibilityElement = YES; _body.accessibilityTraits = UIAccessibilityTraitButton | UIAccessibilityTraitStaticText;
        [self addSubview:_body];
        _text = [[RCTextStackView alloc] initWithFrame:CGRectZero]; _text.userInteractionEnabled = NO;
        [_body addSubview:_text];
        [self refresh];
    }
    return self;
}
- (void)dealloc { _dying = YES; [_command release]; [_outputLines release]; [_head release]; [_title release]; [_status release]; [_lamp release]; [_stop release]; [_body release]; [_text release]; [super dealloc]; }

- (NSArray *)shownLines {
    NSUInteger n = _outputLines.count, keep = _expanded ? RC_TERM_MAX : RC_TERM_TAIL;
    return n > keep ? [_outputLines subarrayWithRange:NSMakeRange(n - keep, keep)] : (_outputLines ? _outputLines : [NSArray array]);
}
- (NSUInteger)hiddenCount { NSUInteger n = _outputLines.count, keep = _expanded ? RC_TERM_MAX : RC_TERM_TAIL; return n > keep ? n - keep : 0; }

- (NSAttributedString *)bodyText {
    UIFont *font = [RCCodeBlockView codeFont];
    NSMutableParagraphStyle *ps = [[[NSMutableParagraphStyle alloc] init] autorelease];
    ps.minimumLineHeight = 16; ps.maximumLineHeight = 16; ps.lineBreakMode = NSLineBreakByCharWrapping;
    NSDictionary *base = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, RCHex(0xd8efe2), NSForegroundColorAttributeName, ps, NSParagraphStyleAttributeName, nil];
    NSMutableAttributedString *s = [[[NSMutableAttributedString alloc] init] autorelease];
    NSMutableDictionary *prompt = [[base mutableCopy] autorelease]; [prompt setObject:RCHex(0x7fdcab) forKey:NSForegroundColorAttributeName];
    [s appendAttributedString:[[[NSAttributedString alloc] initWithString:@"$ " attributes:prompt] autorelease]];
    [s appendAttributedString:[[[NSAttributedString alloc] initWithString:(_command ? _command : @"") attributes:base] autorelease]];
    NSUInteger hidden = [self hiddenCount];
    if (hidden && _expanded) {
        NSMutableDictionary *dim = [[base mutableCopy] autorelease]; [dim setObject:RCHex(0x7c958a) forKey:NSForegroundColorAttributeName];
        [s appendAttributedString:[[[NSAttributedString alloc] initWithString:[@"\n" stringByAppendingString:[NSString stringWithFormat:RCL(@"… %lu earlier lines"), (unsigned long)hidden]] attributes:dim] autorelease]];
    }
    NSArray *shown = [self shownLines];
    if (shown.count) [s appendAttributedString:[[[NSAttributedString alloc] initWithString:[@"\n" stringByAppendingString:[shown componentsJoinedByString:@"\n"]] attributes:base] autorelease]];
    if (hidden && !_expanded) {
        NSMutableDictionary *dim = [[base mutableCopy] autorelease]; [dim setObject:RCHex(0x7c958a) forKey:NSForegroundColorAttributeName];
        [s appendAttributedString:[[[NSAttributedString alloc] initWithString:[@"\n" stringByAppendingString:[NSString stringWithFormat:RCL(@"… %lu more lines"), (unsigned long)hidden]] attributes:dim] autorelease]];
    }
    return s;
}

- (NSString *)statusText {
    if (_state == RCTerminalRunning) return RCL(@"running");
    NSString *s = [NSString stringWithFormat:RCL(@"exit %ld"), (long)_exitCode];
    if (_duration >= 0) s = [s stringByAppendingFormat:@" · %@", [NSString stringWithFormat:RCL(@"%@ s"), [NSString localizedStringWithFormat:@"%.1f", _duration]]];
    if (_stopped) s = [s stringByAppendingFormat:@" · %@", RCL(@"stopped")];
    return s;
}

- (void)refresh {
    _status.text = [self statusText];
    _lamp.state = _state == RCTerminalRunning ? RCLampBusy : (_exitCode == 0 ? RCLampOK : RCLampError);
    _stop.hidden = !(_state == RCTerminalRunning && _stopAvailable);
    _text.attributedText = [self bodyText];
    NSString *out = [[self shownLines] componentsJoinedByString:@"\n"];
    _body.accessibilityLabel = [NSString stringWithFormat:@"%@: %@. %@", RCL(@"Command"), _command ? _command : @"", [self statusText]];
    _body.accessibilityValue = out;
    _body.accessibilityHint = _outputLines.count > RC_TERM_TAIL ? (_expanded ? RCL(@"Shows only the last lines") : RCL(@"Shows more output")) : nil;
    [self setNeedsLayout];
}
- (void)changed { [self refresh]; if ([_delegate respondsToSelector:@selector(terminalPartDidChangeHeight:)]) [_delegate terminalPartDidChangeHeight:self]; }

- (void)setCommand:(NSString *)c { if ([c isEqualToString:_command]) return; [_command release]; _command = [c copy]; [self changed]; }
- (void)setOutputLines:(NSArray *)l { if ([l isEqualToArray:_outputLines]) return; [_outputLines release]; _outputLines = [l copy]; [self changed]; }
- (void)setState:(RCTerminalState)s { _state = s; [self refresh]; }
- (void)setExitCode:(NSInteger)c { _exitCode = c; [self refresh]; }
- (void)setDuration:(NSTimeInterval)d { _duration = d; [self refresh]; }
- (void)setStopped:(BOOL)s { _stopped = s; [self refresh]; }
- (void)setStopAvailable:(BOOL)s { _stopAvailable = s; [self refresh]; }
- (void)setExpanded:(BOOL)e { if (e == _expanded) return; _expanded = e; [self changed]; }

- (CGFloat)heightForWidth:(CGFloat)width { return RC_TERM_HEAD + 8 + ceil([_text heightForWidth:width - 20]) + 8; }
- (CGSize)sizeThatFits:(CGSize)size { return CGSizeMake(size.width, [self heightForWidth:size.width]); }

- (void)layoutSubviews {
    [super layoutSubviews];
    if (_dying) return;
    CGFloat w = self.bounds.size.width, sx = w - 8;
    _head.frame = CGRectMake(0, 0, w, RC_TERM_HEAD);
    if (!_stop.hidden) { CGFloat bw = MAX(44, [_stop.currentTitle sizeWithFont:_stop.titleLabel.font].width + 16); _stop.frame = CGRectMake(w - 6 - bw, 4, bw, 19); sx = w - 6 - bw - 8; }
    CGFloat stw = [_status.text sizeWithFont:_status.font].width;
    _status.frame = CGRectMake(sx - stw, 0, stw, 26);
    _lamp.center = CGPointMake(sx - stw - 8, 13.5);
    _title.frame = CGRectMake(8, 0, MAX(0, sx - stw - 20 - 8), 26);
    _body.frame = CGRectMake(0, RC_TERM_HEAD, w, self.bounds.size.height - RC_TERM_HEAD);
    _text.frame = CGRectMake(10, 8, w - 20, ceil([_text heightForWidth:w - 20]));
}

- (void)tapStop { if ([_delegate respondsToSelector:@selector(terminalPartDidTapStop:)]) [_delegate terminalPartDidTapStop:self]; }
- (void)toggle { if (_outputLines.count > RC_TERM_TAIL) self.expanded = !_expanded; }
@end
