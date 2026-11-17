#import "RCVoiceViewController.h"
#import "RCTheme.h"
#import "RCGlyph.h"
#import <QuartzCore/QuartzCore.h> // headers only (layer messages)

static UIImage *RCOrbImage(BOOL amber) {
    return [RCTheme imageForKey:(amber ? @"voice-orb-amber" : @"voice-orb") size:CGSizeMake(170, 170) capInsets:UIEdgeInsetsZero drawing:^(CGContextRef ctx, CGRect r) {
        CGContextAddEllipseInRect(ctx, r); CGContextClip(ctx);
        NSArray *c = amber ? [NSArray arrayWithObjects:RCHex(0xfff8e6), RCHex(0xffd36e), RCHex(0xe29a0e), RCHex(0x8a5200), nil]
                           : [NSArray arrayWithObjects:RCHex(0xf2fff8), RCHex(0x8fe6b9), RCHex(0x2fae6c), RCHex(0x126b40), nil];
        NSMutableArray *cg = [NSMutableArray array];
        for (UIColor *x in c) [cg addObject:(id)x.CGColor];
        CGFloat locs[4] = {0, .25, .6, 1};
        CGColorSpaceRef sp = CGColorSpaceCreateDeviceRGB();
        CGGradientRef g = CGGradientCreateWithColors(sp, (CFArrayRef)cg, locs);
        CGPoint centre = CGPointMake(r.size.width * .38, r.size.height * .32);
        CGContextDrawRadialGradient(ctx, g, centre, 0, centre, r.size.width * .78, kCGGradientDrawsAfterEndLocation);
        CGGradientRelease(g); CGColorSpaceRelease(sp);
        // inset 0 -8px 20px dark rim at the bottom
        RCDrawVerticalGradient(ctx, CGRectMake(0, r.size.height * .7, r.size.width, r.size.height * .3), [NSArray arrayWithObjects:RCHexA(amber ? 0x3c2400 : 0x003c1e, 0), RCHexA(amber ? 0x3c2400 : 0x003c1e, .45), nil], nil);
        // gloss: the :after highlight
        CGRect gl = CGRectMake(r.size.width * .2, r.size.height * .06, r.size.width * .6, r.size.height * .38);
        CGContextSaveGState(ctx);
        CGContextAddEllipseInRect(ctx, gl); CGContextClip(ctx);
        RCDrawVerticalGradient(ctx, gl, [NSArray arrayWithObjects:RCHexA(0xffffff, .7), RCHexA(0xffffff, 0), nil], nil);
        CGContextRestoreGState(ctx);
    }];
}

@interface RCVoiceBackdrop : UIView
@end
@implementation RCVoiceBackdrop
- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    NSArray *c = [NSArray arrayWithObjects:(id)RCHex(0x2d6e55).CGColor, (id)RCHex(0x163a2d).CGColor, (id)RCHex(0x0b1f17).CGColor, nil];
    CGFloat locs[3] = {0, .55, 1};
    CGColorSpaceRef sp = CGColorSpaceCreateDeviceRGB();
    CGGradientRef g = CGGradientCreateWithColors(sp, (CFArrayRef)c, locs);
    CGPoint centre = CGPointMake(b.size.width / 2, b.size.height * .38);
    CGFloat radius = sqrt(b.size.width * b.size.width / 4 + b.size.height * b.size.height * .62 * .62);
    CGContextDrawRadialGradient(ctx, g, centre, 0, centre, radius, kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(g); CGColorSpaceRelease(sp);
}
@end

// Round glass button with a label under it (.vb).
@interface RCVoiceButton : UIControl { @public UIImageView *icon; UILabel *label; BOOL on, red; NSString *glyph; }
@end
@implementation RCVoiceButton
- (id)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        icon = [[UIImageView alloc] initWithFrame:CGRectMake(19, 19, 26, 26)];
        [self addSubview:icon];
        label = [[UILabel alloc] initWithFrame:CGRectMake(-10, 70, 84, 14)];
        label.backgroundColor = [UIColor clearColor];
        label.font = [UIFont boldSystemFontOfSize:11];
        label.textColor = RCHexA(0xe6f2ec, .85);
        label.textAlignment = NSTextAlignmentCenter;
        [self addSubview:label];
        self.isAccessibilityElement = YES;
        self.accessibilityTraits = UIAccessibilityTraitButton;
    }
    return self;
}
- (void)dealloc { [icon release]; [label release]; [glyph release]; [super dealloc]; }
- (void)setGlyph:(NSString *)g title:(NSString *)t on:(BOOL)o red:(BOOL)r {
    [glyph release]; glyph = [g copy]; on = o; red = r;
    icon.image = [RCGlyph imageNamed:g size:26 color:(o ? RCHex(0x1d3d2e) : [UIColor whiteColor])];
    label.text = t;
    self.accessibilityLabel = t;
    self.accessibilityTraits = UIAccessibilityTraitButton | (o ? UIAccessibilityTraitSelected : 0);
    [self setNeedsDisplay];
}
- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; icon.alpha = h ? .6 : 1; [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect c = CGRectMake(.5, .5, 63, 63);
    CGContextSaveGState(ctx);
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, 2), 6, RCHexA(0, .4).CGColor);
    CGContextSetFillColorWithColor(ctx, (red ? RCHex(0xc9200f) : on ? RCHexA(0xffffff, .85) : RCHexA(0xffffff, .12)).CGColor);
    CGContextFillEllipseInRect(ctx, c);
    CGContextRestoreGState(ctx);
    CGContextSaveGState(ctx);
    CGContextAddEllipseInRect(ctx, c); CGContextClip(ctx);
    NSArray *locs = [NSArray arrayWithObjects:[NSNumber numberWithFloat:0], [NSNumber numberWithFloat:.5], [NSNumber numberWithFloat:.51], [NSNumber numberWithFloat:1], nil];
    if (red) RCDrawVerticalGradient(ctx, c, [NSArray arrayWithObjects:RCHex(0xff8c7f), RCHex(0xd4301f), RCHex(0xc51c0b), RCHex(0xb81506), nil], locs);
    else RCDrawVerticalGradient(ctx, c, [NSArray arrayWithObjects:RCHexA(0xffffff, .35), RCHexA(0xffffff, .1), RCHexA(0xffffff, .02), RCHexA(0xffffff, .1), nil], locs);
    if (self.highlighted) { CGContextSetFillColorWithColor(ctx, RCHexA(0, .25).CGColor); CGContextFillRect(ctx, c); }
    CGContextRestoreGState(ctx);
    CGContextSetStrokeColorWithColor(ctx, RCHexA(0, .6).CGColor);
    CGContextStrokeEllipseInRect(ctx, c);
}
@end

@interface RCVoiceViewController () {
    RCVoiceBackdrop *_backdrop;
    UIButton *_orb;
    UILabel *_stateLabel, *_hintLabel, *_noticeLabel;
    UIScrollView *_transcriptScroll;
    UILabel *_transcriptLabel;
    UIView *_noticeBox;
    UIButton *_textButton, *_settingsButton;
    RCVoiceButton *_mic, *_sound, *_end;
    NSMutableArray *_lines;
}
@end

@implementation RCVoiceViewController
@synthesize state = _state, muted = _muted, soundOff = _soundOff, showsMuteControls = _showsMuteControls, interruptAvailable = _interruptAvailable,
    showsTranscriptToggle = _showsTranscriptToggle, transcriptShown = _transcriptShown, showsSettings = _showsSettings,
    stateText = _stateText, hintText = _hintText, noticeText = _noticeText, delegate = _delegate;

- (id)initWithNibName:(NSString *)n bundle:(NSBundle *)b {
    if ((self = [super initWithNibName:n bundle:b])) { _lines = [[NSMutableArray alloc] init]; _showsMuteControls = YES; _interruptAvailable = YES; }
    return self;
}

- (void)dealloc {
    [_backdrop release]; [_orb release]; [_stateLabel release]; [_hintLabel release]; [_noticeLabel release];
    [_transcriptScroll release]; [_transcriptLabel release]; [_noticeBox release]; [_textButton release]; [_settingsButton release];
    [_mic release]; [_sound release]; [_end release]; [_lines release];
    [_stateText release]; [_hintText release]; [_noticeText release];
    [super dealloc];
}

static UILabel *RCVoiceLabel(UIFont *f, UIColor *c) {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectZero];
    l.backgroundColor = [UIColor clearColor]; l.font = f; l.textColor = c; l.textAlignment = NSTextAlignmentCenter;
    l.shadowColor = [UIColor blackColor]; l.shadowOffset = CGSizeMake(0, -1);
    return l;
}

static UIButton *RCVoiceBarButton(NSString *title, UIImage *image, id target, SEL action) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *bg = [RCTheme imageForKey:@"voice-barbtn" size:CGSizeMake(14, 30) capInsets:UIEdgeInsetsMake(6, 6, 6, 6) drawing:^(CGContextRef ctx, CGRect r) {
        CGPathRef p = RCCreateRoundedRectPath(CGRectInset(r, .5, .5), 5);
        CGContextSaveGState(ctx); CGContextAddPath(ctx, p); CGContextClip(ctx);
        RCDrawVerticalGradient(ctx, r, [NSArray arrayWithObjects:RCHexA(0xffffff, .3), RCHexA(0xffffff, .08), nil], nil);
        CGContextRestoreGState(ctx);
        CGContextAddPath(ctx, p); CGContextSetStrokeColorWithColor(ctx, RCHexA(0, .6).CGColor); CGContextStrokePath(ctx);
        CGPathRelease(p);
    }];
    [b setBackgroundImage:bg forState:UIControlStateNormal];
    if (title) { [b setTitle:title forState:UIControlStateNormal]; b.titleLabel.font = [UIFont boldSystemFontOfSize:12]; b.titleLabel.shadowOffset = CGSizeMake(0, -1); [b setTitleShadowColor:[UIColor blackColor] forState:UIControlStateNormal]; }
    if (image) { [b setImage:image forState:UIControlStateNormal]; b.accessibilityLabel = RCL(@"Voice settings"); }
    [b addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    CGSize s = title ? [title sizeWithFont:[UIFont boldSystemFontOfSize:12]] : CGSizeMake(20, 20);
    b.frame = CGRectMake(0, 0, ceil(s.width) + 20, 30);
    return b;
}

- (void)loadView {
    _backdrop = [[RCVoiceBackdrop alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    _backdrop.contentMode = UIViewContentModeRedraw;
    self.view = _backdrop;
    UIView *v = _backdrop;
    _orb = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
    [_orb setImage:RCOrbImage(NO) forState:UIControlStateNormal];
    _orb.adjustsImageWhenHighlighted = NO;
    _orb.accessibilityIdentifier = @"chat.voice.orb";
    _orb.frame = CGRectMake(0, 0, 170, 170);
    _orb.layer.shadowColor = RCHex(0x6ef0aa).CGColor;
    _orb.layer.shadowOpacity = .45; _orb.layer.shadowRadius = 20; _orb.layer.shadowOffset = CGSizeZero;
    [_orb addTarget:self action:@selector(orbTapped) forControlEvents:UIControlEventTouchUpInside];
    [v addSubview:_orb];
    _stateLabel = RCVoiceLabel([UIFont boldSystemFontOfSize:19], [UIColor whiteColor]);
    _hintLabel = RCVoiceLabel([UIFont systemFontOfSize:13], RCHexA(0xe6f2ec, .7));
    [v addSubview:_stateLabel]; [v addSubview:_hintLabel];
    _transcriptScroll = [[UIScrollView alloc] initWithFrame:CGRectZero];
    _transcriptScroll.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    _transcriptLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _transcriptLabel.backgroundColor = [UIColor clearColor];
    _transcriptLabel.numberOfLines = 0;
    [_transcriptScroll addSubview:_transcriptLabel];
    [v addSubview:_transcriptScroll];
    _noticeBox = [[UIView alloc] initWithFrame:CGRectZero];
    _noticeBox.backgroundColor = RCHexA(0, .35);
    _noticeBox.layer.cornerRadius = 9;
    _noticeLabel = RCVoiceLabel([UIFont systemFontOfSize:13], RCHexA(0xffffff, .85));
    _noticeLabel.textAlignment = NSTextAlignmentLeft;
    _noticeLabel.shadowColor = nil;
    [_noticeBox addSubview:_noticeLabel];
    [v addSubview:_noticeBox];
    _textButton = [RCVoiceBarButton(RCL(@"Text"), nil, self, @selector(toggleTranscript)) retain];
    _settingsButton = [RCVoiceBarButton(nil, [RCGlyph imageNamed:@"sliders" size:20 color:[UIColor whiteColor]], self, @selector(settings)) retain];
    [v addSubview:_textButton]; [v addSubview:_settingsButton];
    _mic = [[RCVoiceButton alloc] initWithFrame:CGRectMake(0, 0, 64, 86)];
    _sound = [[RCVoiceButton alloc] initWithFrame:CGRectMake(0, 0, 64, 86)];
    _end = [[RCVoiceButton alloc] initWithFrame:CGRectMake(0, 0, 64, 86)];
    [_mic addTarget:self action:@selector(toggleMute) forControlEvents:UIControlEventTouchUpInside];
    [_sound addTarget:self action:@selector(toggleSound) forControlEvents:UIControlEventTouchUpInside];
    [_end addTarget:self action:@selector(endTapped) forControlEvents:UIControlEventTouchUpInside];
    [_end setGlyph:@"plus" title:RCL(@"End") on:NO red:YES];
    _end->icon.transform = CGAffineTransformMakeRotation(M_PI_4);
    _end.accessibilityHint = RCL(@"Ends the voice conversation");
    _mic.accessibilityIdentifier = @"chat.voice.microphone";
    _sound.accessibilityIdentifier = @"chat.voice.sound";
    _end.accessibilityIdentifier = @"chat.voice.end";
    [v addSubview:_mic]; [v addSubview:_sound]; [v addSubview:_end];
    [self refresh];
}

- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self.navigationController setNavigationBarHidden:YES animated:animated]; [self animateOrb]; }
- (void)viewDidDisappear:(BOOL)animated { [super viewDidDisappear:animated]; [_orb.layer removeAllAnimations]; }

- (NSString *)defaultState {
    switch (_state) {
        case RCVoiceListening: return _muted ? RCL(@"Microphone off") : RCL(@"Listening");
        case RCVoiceSending: return RCL(@"Sending…");
        case RCVoiceThinking: return RCL(@"Thinking…");
        case RCVoiceSpeaking: return RCL(@"Speaking");
        case RCVoiceReconnecting: return RCL(@"Poor connection");
        default: return RCL(@"Voice mode unavailable");
    }
}
- (NSString *)defaultHint {
    switch (_state) {
        case RCVoiceListening: return _muted ? RCL(@"Turn on the microphone to continue") : RCL(@"Speak. When you finish, tap the orb.");
        case RCVoiceSpeaking: return _interruptAvailable ? RCL(@"Tap the orb to interrupt") : nil;
        case RCVoiceReconnecting: return RCL(@"Reconnecting… Your last phrase is saved and will be sent once.");
        case RCVoiceError: return RCL(@"You can continue by text in the same chat.");
        default: return nil;
    }
}

- (void)refresh {
    if (![self isViewLoaded]) return;
    _stateLabel.text = _stateText.length ? _stateText : [self defaultState];
    RCLabelSetText(_hintLabel, _hintText.length ? _hintText : [self defaultHint]);
    [_orb setImage:RCOrbImage(_state == RCVoiceReconnecting) forState:UIControlStateNormal];
    _orb.layer.shadowColor = (_state == RCVoiceReconnecting ? RCHex(0xffc850) : RCHex(0x6ef0aa)).CGColor;
    _orb.alpha = (_state == RCVoiceListening && _muted) || _state == RCVoiceError ? .45 : 1;
    _orb.accessibilityLabel = [NSString stringWithFormat:RCL(@"Voice: %@"), _stateLabel.text];
    _orb.accessibilityHint = _state == RCVoiceListening && !_muted ? RCL(@"Finishes the phrase and sends it") : (_state == RCVoiceSpeaking && _interruptAvailable ? RCL(@"Interrupts the answer") : nil);
    _textButton.hidden = !_showsTranscriptToggle;
    _settingsButton.hidden = !_showsSettings;
    _mic.hidden = _sound.hidden = !_showsMuteControls;
    [_mic setGlyph:@"mic" title:(_muted ? RCL(@"Mic off") : RCL(@"Microphone")) on:_muted red:NO];
    [_sound setGlyph:(_soundOff ? @"speakerOff" : @"speaker") title:(_soundOff ? RCL(@"Sound off") : RCL(@"Sound")) on:_soundOff red:NO];
    RCLabelSetText(_noticeLabel, _noticeText);
    _noticeBox.hidden = !_noticeText.length;
    _transcriptScroll.hidden = _noticeText.length || !_transcriptShown;
    [self renderTranscript];
    [self animateOrb];
    [self.view setNeedsLayout];
}

- (void)animateOrb {
    // UIView repeat/autoreverse only: QuartzCore is not linked (no CAAnimation classes).
    [_orb.layer removeAllAnimations];
    _orb.transform = CGAffineTransformIdentity;
    if (!self.view.window && ![self isViewLoaded]) return;
    if (_state != RCVoiceThinking && _state != RCVoiceSpeaking && _state != RCVoiceReconnecting) return;
    BOOL speak = _state == RCVoiceSpeaking;
    CGFloat from = speak ? .96 : 1, to = speak ? 1.08 : 1.06;
    _orb.transform = CGAffineTransformMakeScale(from, from);
    [UIView animateWithDuration:(speak ? .5 : (_state == RCVoiceReconnecting ? .6 : .8)) delay:0
                        options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionCurveEaseInOut
                     animations:^{ _orb.transform = CGAffineTransformMakeScale(to, to); } completion:nil];
}

- (void)renderTranscript {
    NSMutableAttributedString *s = [[[NSMutableAttributedString alloc] init] autorelease];
    NSMutableParagraphStyle *ps = [[[NSMutableParagraphStyle alloc] init] autorelease];
    ps.lineBreakMode = NSLineBreakByWordWrapping; ps.paragraphSpacing = 6;
    for (NSArray *l in _lines) {
        if (s.length) [s appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\n"] autorelease]];
        [s appendAttributedString:[[[NSAttributedString alloc] initWithString:[[l objectAtIndex:0] stringByAppendingString:@": "] attributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIFont boldSystemFontOfSize:14], NSFontAttributeName, RCHex(0x8fe6b9), NSForegroundColorAttributeName, nil]] autorelease]];
        [s appendAttributedString:[[[NSAttributedString alloc] initWithString:[l objectAtIndex:1] attributes:[NSDictionary dictionaryWithObjectsAndKeys:[UIFont systemFontOfSize:14], NSFontAttributeName, RCHexA(0xe6f2ec, .9), NSForegroundColorAttributeName, nil]] autorelease]];
    }
    [s addAttribute:NSParagraphStyleAttributeName value:ps range:NSMakeRange(0, s.length)];
    _transcriptLabel.attributedText = s;
    _transcriptScroll.accessibilityLabel = s.string;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width, h = self.view.bounds.size.height;
    CGFloat k = h > 500 ? 1 : .82; // iPhone 4: compress vertically
    CGRect tf = _textButton.frame; tf.origin = CGPointMake(6, 7); _textButton.frame = tf;
    CGRect sf = _settingsButton.frame; sf.origin = CGPointMake(w - 6 - sf.size.width, 7); _settingsButton.frame = sf;
    _orb.center = CGPointMake(w / 2, round(76 * k + 85));
    CGFloat y = round(270 * k);
    _stateLabel.frame = CGRectMake(20, y, w - 40, 24);
    CGFloat hh = RCMeasureText(_hintLabel.text, _hintLabel.font, w - 48).height;
    _hintLabel.frame = CGRectMake(24, y + 28, w - 48, hh);
    CGFloat buttonsTop = h - 26 - 86;
    CGFloat ty = y + 28 + MAX(hh, 17) + 14;
    CGRect area = CGRectMake(14, ty, w - 28, MAX(0, buttonsTop - 10 - ty));
    _transcriptScroll.frame = area;
    CGFloat lh = _lines.count ? ceil([_transcriptLabel.attributedText boundingRectWithSize:CGSizeMake(area.size.width, 100000) options:NSStringDrawingUsesLineFragmentOrigin context:nil].size.height) + 4 : 0;
    _transcriptLabel.frame = CGRectMake(0, 0, area.size.width, lh);
    _transcriptScroll.contentSize = CGSizeMake(area.size.width, lh);
    if (lh > area.size.height) _transcriptScroll.contentOffset = CGPointMake(0, lh - area.size.height);
    CGFloat nh = RCMeasureText(_noticeLabel.text, _noticeLabel.font, area.size.width - 20).height;
    _noticeBox.frame = CGRectMake(14, ty, w - 28, nh + 20);
    _noticeLabel.frame = CGRectMake(10, 10, area.size.width - 20, nh);
    NSArray *buttons = _showsMuteControls ? [NSArray arrayWithObjects:_mic, _sound, _end, nil] : [NSArray arrayWithObject:_end];
    CGFloat total = buttons.count * 64 + (buttons.count - 1) * 24, x = round((w - total) / 2);
    for (UIView *b in buttons) { b.frame = CGRectMake(x, buttonsTop, 64, 86); x += 88; }
}

- (void)setState:(RCVoiceState)s { _state = s; [self refresh]; UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, _stateLabel.text); }
- (void)setMuted:(BOOL)m { _muted = m; [self refresh]; }
- (void)setSoundOff:(BOOL)m { _soundOff = m; [self refresh]; }
- (void)setShowsMuteControls:(BOOL)v { _showsMuteControls = v; [self refresh]; }
- (void)setInterruptAvailable:(BOOL)v { _interruptAvailable = v; [self refresh]; }
- (void)setShowsTranscriptToggle:(BOOL)v { _showsTranscriptToggle = v; [self refresh]; }
- (void)setTranscriptShown:(BOOL)v { _transcriptShown = v; [self refresh]; }
- (void)setShowsSettings:(BOOL)v { _showsSettings = v; [self refresh]; }
- (void)setStateText:(NSString *)t { [_stateText release]; _stateText = [t copy]; [self refresh]; }
- (void)setHintText:(NSString *)t { [_hintText release]; _hintText = [t copy]; [self refresh]; }
- (void)setNoticeText:(NSString *)t { [_noticeText release]; _noticeText = [t copy]; [self refresh]; }

- (void)appendTranscriptLine:(NSString *)text speaker:(NSString *)speaker {
    if (!text.length) return;
    [_lines addObject:[NSArray arrayWithObjects:(speaker ? speaker : @""), text, nil]];
    [self refresh];
}
- (void)clearTranscript { [_lines removeAllObjects]; [self refresh]; }

- (void)orbTapped { [_delegate voiceDidTapOrb:self]; }
- (void)endTapped { [_delegate voiceDidEnd:self]; }
- (void)toggleTranscript { self.transcriptShown = !_transcriptShown; }
- (void)settings { if ([_delegate respondsToSelector:@selector(voiceDidTapSettings:)]) [_delegate voiceDidTapSettings:self]; }
- (void)toggleMute { self.muted = !_muted; if ([_delegate respondsToSelector:@selector(voice:didChangeMuted:)]) [_delegate voice:self didChangeMuted:_muted]; }
- (void)toggleSound { self.soundOff = !_soundOff; if ([_delegate respondsToSelector:@selector(voice:didChangeSoundOff:)]) [_delegate voice:self didChangeSoundOff:_soundOff]; }
@end
