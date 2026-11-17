#import "RCComposerView.h"
#import "RCTheme.h"
#import "RCLampView.h"
#import "RCProgressView.h"
#import "RCFileIcon.h"
#import <QuartzCore/QuartzCore.h> // headers only (layer messages), no QuartzCore link
#ifdef OR6_CHAT_ACCEPTANCE
#import <CommonCrypto/CommonDigest.h> // libSystem: the acceptance-only line-break probe's SHA-256
#endif

static const CGFloat kFieldMin = 30, kFieldMax = 118, kSendW = 58;

#pragma mark - Attachment model

@implementation RCComposerAttachment
@synthesize title = _title, glyph = _glyph, image = _image, progress = _progress, failed = _failed, detail = _detail;
+ (id)attachmentWithTitle:(NSString *)title glyph:(NSString *)glyph image:(UIImage *)image {
    RCComposerAttachment *a = [[[self alloc] init] autorelease];
    a.title = title; a.glyph = glyph; a.image = image; a.progress = 1;
    return a;
}
- (void)dealloc { [_title release]; [_glyph release]; [_image release]; [_detail release]; [super dealloc]; }
@end

#pragma mark - Tray item

@interface RCTrayItemView : UIView { @public UIButton *_remove, *_open; RCComposerAttachment *_att; }
- (id)initWithAttachment:(RCComposerAttachment *)a;
@end
@implementation RCTrayItemView
+ (UIImage *)removeImage {
    return [RCTheme imageForKey:@"tray-x" size:CGSizeMake(22, 23) capInsets:UIEdgeInsetsZero drawing:^(CGContextRef ctx, CGRect r) {
        CGRect c = CGRectMake(1, 1, 20, 20);
        CGContextSaveGState(ctx);
        CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1), 2, RCHexA(0, .4).CGColor);
        CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor); CGContextFillEllipseInRect(ctx, c);
        CGContextRestoreGState(ctx);
        CGContextSetFillColorWithColor(ctx, RCHex(0x49524e).CGColor); CGContextFillEllipseInRect(ctx, CGRectInset(c, 2, 2));
        CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor); CGContextSetLineWidth(ctx, 1.8); CGContextSetLineCap(ctx, kCGLineCapRound);
        CGContextMoveToPoint(ctx, 8, 8); CGContextAddLineToPoint(ctx, 14, 14); CGContextMoveToPoint(ctx, 14, 8); CGContextAddLineToPoint(ctx, 8, 14);
        CGContextStrokePath(ctx);
        (void)r;
    }];
}
- (id)initWithAttachment:(RCComposerAttachment *)a {
    if ((self = [super initWithFrame:CGRectMake(0, 0, 54, 54)])) {
        _att = [a retain];
        // The file itself (RCFileIcon): a Polaroid print for pictures, a paper sheet with
        // the extension band for documents; failed adds the shared red exclamation badge. The remove badge
        // (added last, on self) sits above it (app.css .tray .ti .x).
        UIImageView *icon = [[[UIImageView alloc] initWithImage:[RCFileIcon iconForFileName:a.title glyph:a.glyph photo:a.image size:CGSizeMake(54, 54) failed:a.failed]] autorelease];
        icon.frame = self.bounds;
        icon.userInteractionEnabled = NO;
        [self addSubview:icon];
        if (a.progress < 1) {
            RCProgressView *p = [[[RCProgressView alloc] initWithFrame:CGRectMake(8, 54 - 6 - 8, 38, 6)] autorelease];
            p.progress = a.progress;
            p.userInteractionEnabled = NO;
            [self addSubview:p];
        }
        // Whole-item tap target under the ✕ (wired only when the delegate wants item taps).
        _open = [UIButton buttonWithType:UIButtonTypeCustom];
        _open.frame = self.bounds;
        _open.accessibilityLabel = a.title; _open.accessibilityValue = a.detail;
        _open.hidden = YES;
        [self addSubview:_open];
        _remove = [UIButton buttonWithType:UIButtonTypeCustom];
        [_remove setImage:[RCTrayItemView removeImage] forState:UIControlStateNormal];
        _remove.frame = CGRectMake(54 - 13 - 4, -7 - 4, 30, 31); // 22 pt image, larger tap target
        _remove.contentEdgeInsets = UIEdgeInsetsMake(4, 4, 5, 4);
        _remove.accessibilityLabel = [NSString stringWithFormat:RCL(@"Remove %@"), a.title ? a.title : @""];
        [self addSubview:_remove];
        self.isAccessibilityElement = NO;
    }
    return self;
}
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    CGPoint p = [self convertPoint:point toView:_remove];
    if ([_remove pointInside:p withEvent:event]) return _remove;
    return [super hitTest:point withEvent:event];
}
- (void)dealloc { [_att release]; [super dealloc]; }
@end

#pragma mark - Composer

@interface RCComposerView () {
    UIButton *_plus, *_send, *_mic, *_expand, *_chip;
    UIImageView *_field;
    UITextView *_tv;
    UILabel *_placeholderLabel, *_note;
    RCLampView *_sendLamp;
    RCDictationView *_dictation;
    BOOL _dictating, _sendBlocked;
    UIScrollView *_tray;
    NSMutableArray *_trayViews;
    NSString *_placeholder, *_trayNote, *_chipTitle, *_chipGlyph;
    RCChipColor _chipColor;
    NSArray *_attachments;
    CGFloat _lastHeight;
    NSString *_intended; // the text as set or typed (the field's read-back differs at line breaks, see .h)
    BOOL _assigning;     // -setText: in progress: not a user edit
}
@end

#pragma mark - iOS 6 text view line breaks (RCComposerView.h)

NSString *RCTextViewStoredText(NSString *text) {
    if (!text) return @"";
    return [text hasSuffix:@"\n"] ? [text stringByAppendingString:@"\n"] : text;
}
NSString *RCTextViewIntendedText(NSString *text, NSString *intended) {
    if (!text) text = @"";
    if (!intended || [text isEqualToString:intended]) return text;
    BOOL emptyLast = !intended.length || [intended hasSuffix:@"\n"];
    return (emptyLast && [text isEqualToString:[intended stringByAppendingString:@"\n"]]) ? intended : text;
}
NSString *RCTextViewEditedText(NSString *text, NSString *intended, NSRange range, NSString *replacement) {
    if (!text) text = @"";
    NSString *base = RCTextViewIntendedText(text, intended);
    NSUInteger end = range.location + range.length;
    if (range.location == NSNotFound || end < range.location) return nil;
    if (text.length == base.length + 1 && ![text isEqualToString:base] && end == text.length) {
        if (range.location > base.length) range.location = base.length;
        range.length = base.length - range.location; end = base.length;
    }
    if (end > base.length) return nil;
    return [base stringByReplacingCharactersInRange:range withString:(replacement ? replacement : @"")];
}

@implementation RCComposerView
@synthesize showsPlus = _showsPlus, showsMic = _showsMic, expandAvailable = _expandAvailable, stopAvailable = _stopAvailable, voiceAvailable = _voiceAvailable, streaming = _streaming, preparing = _preparing, sendBlocked = _sendBlocked, delegate = _delegate, textView = _tv;

static UIImage *RCComposerImage(NSString *key, CGSize size, UIEdgeInsets caps, void (^draw)(CGContextRef, CGRect)) {
    return [RCTheme imageForKey:key size:size capInsets:caps drawing:draw];
}

+ (UIImage *)fieldImage {
    BOOL dark = [RCTheme isDark]; // dark: .fieldwrap #e6ece9
    return RCComposerImage(dark ? @"composer-field-dark" : @"composer-field", CGSizeMake(36, 32), UIEdgeInsetsMake(15, 17, 15, 17), ^(CGContextRef ctx, CGRect r) {
        CGRect b = CGRectInset(r, .5, .5);
        CGPathRef p = RCCreateRoundedRectPath(b, 15.5);
        CGContextAddPath(ctx, p); CGContextSetFillColorWithColor(ctx, (dark ? RCHex(0xe6ece9) : [UIColor whiteColor]).CGColor); CGContextFillPath(ctx);
        // inset 0 1px 2px rgba(0,0,0,.25)
        CGContextSaveGState(ctx);
        CGContextAddPath(ctx, p); CGContextClip(ctx);
        CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1), 2, RCHexA(0, .25).CGColor);
        CGPathRef outer = RCCreateRoundedRectPath(CGRectInset(b, -2, -2), 17.5);
        CGContextAddPath(ctx, outer); CGContextSetStrokeColorWithColor(ctx, [UIColor blackColor].CGColor); CGContextSetLineWidth(ctx, 4); CGContextStrokePath(ctx);
        CGPathRelease(outer);
        CGContextRestoreGState(ctx);
        CGContextAddPath(ctx, p); CGContextSetStrokeColorWithColor(ctx, RCHex(0x8b9b93).CGColor); CGContextSetLineWidth(ctx, 1); CGContextStrokePath(ctx);
        CGPathRelease(p);
    });
}

+ (UIImage *)roundButtonImage:(NSString *)key colors:(NSArray *)colors locations:(NSArray *)locs border:(unsigned)border highlight:(CGFloat)hi width:(CGFloat)w {
    return RCComposerImage(key, CGSizeMake(w, 32), UIEdgeInsetsMake(15, 16, 15, 16), ^(CGContextRef ctx, CGRect r) {
        CGRect b = CGRectInset(r, .5, .5);
        CGPathRef p = RCCreateRoundedRectPath(b, 15.5);
        CGContextSaveGState(ctx); CGContextAddPath(ctx, p); CGContextClip(ctx);
        RCDrawVerticalGradient(ctx, r, colors, locs);
        CGContextSetFillColorWithColor(ctx, RCHexA(0xffffff, hi).CGColor); CGContextFillRect(ctx, CGRectMake(0, 1, r.size.width, 1));
        CGContextRestoreGState(ctx);
        CGContextAddPath(ctx, p); CGContextSetStrokeColorWithColor(ctx, RCHex(border).CGColor); CGContextSetLineWidth(ctx, 1); CGContextStrokePath(ctx);
        CGPathRelease(p);
    });
}

static NSArray *RCGloss4(void) { return [NSArray arrayWithObjects:[NSNumber numberWithFloat:0], [NSNumber numberWithFloat:.5], [NSNumber numberWithFloat:.51], [NSNumber numberWithFloat:1], nil]; }

+ (UIImage *)sendImage:(BOOL)red pressed:(BOOL)pressed {
    NSString *key = [NSString stringWithFormat:@"composer-send-%d-%d", red, pressed];
    NSArray *c, *l = RCGloss4();
    if (red) c = pressed ? [NSArray arrayWithObjects:RCHex(0x8e1105), RCHex(0xb81506), nil] : [NSArray arrayWithObjects:RCHex(0xef8378), RCHex(0xd4301f), RCHex(0xc51c0b), RCHex(0xb81506), nil];
    else c = pressed ? [NSArray arrayWithObjects:RCHex(0x157c45), RCHex(0x22a05e), nil] : [NSArray arrayWithObjects:RCHex(0x7fdcab), RCHex(0x35b06f), RCHex(0x22a05e), RCHex(0x1e9656), nil];
    return [self roundButtonImage:key colors:c locations:(pressed ? nil : l) border:(red ? 0x7d0f05 : 0x0f5c37) highlight:(pressed ? 0 : .45) width:34];
}

+ (UIImage *)plusImage:(BOOL)pressed {
    NSArray *c = pressed ? [NSArray arrayWithObjects:RCHex(0xcdd7d2), RCHex(0xe6ece9), nil] : [NSArray arrayWithObjects:RCHex(0xffffff), RCHex(0xdfe7e3), nil];
    return [self roundButtonImage:(pressed ? @"composer-plus-p" : @"composer-plus") colors:c locations:nil border:0x8b9b93 highlight:(pressed ? 0 : 1) width:32];
}

+ (UIImage *)chipImage:(RCChipColor)color {
    static const unsigned spec[4][3] = {{0x6ea9ef, 0x2f6fcf, 0x1f4f9e}, {0x6fd29d, 0x1f9a5a, 0x0f5c37}, {0xb493ef, 0x6c3fc2, 0x4b2591}, {0xffbe63, 0xe07a0c, 0x9a5205}};
    int i = MIN(3, MAX(0, (int)color));
    return RCComposerImage([NSString stringWithFormat:@"chip-%d", i], CGSizeMake(26, 24), UIEdgeInsetsMake(11, 12, 11, 12), ^(CGContextRef ctx, CGRect r) {
        CGRect b = CGRectInset(r, .5, .5);
        CGPathRef p = RCCreateRoundedRectPath(b, 11.5);
        CGContextSaveGState(ctx); CGContextAddPath(ctx, p); CGContextClip(ctx);
        RCDrawVerticalGradient(ctx, r, [NSArray arrayWithObjects:RCHex(spec[i][0]), RCHex(spec[i][1]), nil], nil);
        CGContextRestoreGState(ctx);
        CGContextAddPath(ctx, p); CGContextSetStrokeColorWithColor(ctx, RCHex(spec[i][2]).CGColor); CGContextSetLineWidth(ctx, 1); CGContextStrokePath(ctx);
        CGPathRelease(p);
    });
}

- (id)initWithFrame:(CGRect)frame {
    if (CGRectIsEmpty(frame)) frame = CGRectMake(0, 0, 320, 46);
    if ((self = [super initWithFrame:frame])) {
        self.contentMode = UIViewContentModeRedraw;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        _placeholder = [RCL(@"Message") copy];
        _trayViews = [[NSMutableArray alloc] init];

        _plus = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        [_plus setBackgroundImage:[RCComposerView plusImage:NO] forState:UIControlStateNormal];
        [_plus setBackgroundImage:[RCComposerView plusImage:YES] forState:UIControlStateHighlighted];
        [_plus setImage:[RCGlyph imageNamed:@"plus" size:18 color:RCHex(0x4b5d55)] forState:UIControlStateNormal];
        _plus.adjustsImageWhenHighlighted = NO;
        _plus.accessibilityLabel = RCL(@"Add");
        [_plus addTarget:self action:@selector(tapPlus) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_plus];

        _field = [[UIImageView alloc] initWithImage:[RCComposerView fieldImage]];
        _field.userInteractionEnabled = YES;
        _field.clipsToBounds = YES;
        [self addSubview:_field];
        _tv = [[UITextView alloc] initWithFrame:CGRectZero];
        _tv.backgroundColor = [UIColor clearColor];
        _tv.font = RCTextViewFont([UIFont systemFontOfSize:16]);
        _tv.textColor = [RCTheme inkColor];
        _tv.delegate = self;
        _tv.scrollsToTop = NO;
        _tv.accessibilityLabel = _placeholder;
        [_field addSubview:_tv];
        _placeholderLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _placeholderLabel.backgroundColor = [UIColor clearColor];
        _placeholderLabel.font = [UIFont systemFontOfSize:16];
        _placeholderLabel.textColor = RCHex(0xa3b0a9);
        _placeholderLabel.text = _placeholder;
        _placeholderLabel.userInteractionEnabled = NO;
        _placeholderLabel.isAccessibilityElement = NO;
        [_field addSubview:_placeholderLabel];
        _mic = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        [_mic setImage:[RCGlyph imageNamed:@"mic" size:20 color:RCHex(0x6b7a72)] forState:UIControlStateNormal];
        _mic.accessibilityLabel = RCL(@"Dictation");
        [_mic addTarget:self action:@selector(tapMic) forControlEvents:UIControlEventTouchUpInside];
        [_field addSubview:_mic];
        _expand = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        [_expand setImage:[RCGlyph imageNamed:@"expand" size:16 color:RCHex(0x6b7a72)] forState:UIControlStateNormal];
        _expand.accessibilityLabel = RCL(@"Expand");
        [_expand addTarget:self action:@selector(tapExpand) forControlEvents:UIControlEventTouchUpInside];
        [_field addSubview:_expand];

        _send = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        _send.titleLabel.font = [UIFont boldSystemFontOfSize:15];
        [_send setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _send.titleLabel.shadowOffset = CGSizeMake(0, -1);
        [_send setTitleShadowColor:RCHexA(0x003c19, .55) forState:UIControlStateNormal];
        _send.adjustsImageWhenHighlighted = NO;
        _send.adjustsImageWhenDisabled = NO;
        [_send addTarget:self action:@selector(tapSend) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_send];
        _sendLamp = [[RCLampView alloc] initWithDiameter:7];
        _sendLamp.state = RCLampBusy;
        [_send addSubview:_sendLamp];

        _chip = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        _chip.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        [_chip setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _chip.titleLabel.shadowOffset = CGSizeMake(0, -1);
        [_chip setTitleShadowColor:RCHexA(0, .3) forState:UIControlStateNormal];
        _chip.adjustsImageWhenHighlighted = NO;
        _chip.contentEdgeInsets = UIEdgeInsetsMake(0, 6, 0, 8);
        _chip.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 3);
        [_chip addTarget:self action:@selector(tapChip) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_chip];

        _tray = [[UIScrollView alloc] initWithFrame:CGRectZero];
        _tray.showsHorizontalScrollIndicator = NO;
        _tray.clipsToBounds = NO;
        [self addSubview:_tray];
        _note = [[UILabel alloc] initWithFrame:CGRectZero];
        _note.backgroundColor = [UIColor clearColor];
        _note.font = [UIFont boldSystemFontOfSize:12];
        _note.textColor = [RCTheme isDark] ? RCHex(0xff8c7f) : [RCTheme errorInkColor];
        _note.numberOfLines = 0;
        _note.lineBreakMode = NSLineBreakByWordWrapping;
        [self addSubview:_note];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appearanceChanged) name:RCThemeAppearanceDidChangeNotification object:nil];
        [self refresh];
    }
    return self;
}

- (void)appearanceChanged {
    _field.image = [RCComposerView fieldImage];
    _note.textColor = [RCTheme isDark] ? RCHex(0xff8c7f) : [RCTheme errorInkColor]; // dark tray note: kit extension
    [self setNeedsDisplay];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _tv.delegate = nil;
    [_plus release]; [_send release]; [_mic release]; [_expand release]; [_chip release];
    [_field release]; [_tv release]; [_placeholderLabel release]; [_note release]; [_sendLamp release];
    [_tray release]; [_trayViews release]; [_dictation release];
    [_placeholder release]; [_trayNote release]; [_chipTitle release]; [_chipGlyph release]; [_attachments release]; [_intended release];
    [super dealloc];
}

#pragma mark - State

// The intended text, not the raw read-back: a trailing Return or an emptied field reads back with an
// extra "\n" on iOS 6 (RCComposerView.h).
- (NSString *)text { return RCTextViewIntendedText(_tv.text, _intended); }
// iOS 6.1.4 UITextView -setText: replaces every "\n" with a space (device-verified,
// also on a bare text view); -setAttributedText: keeps line breaks, but each "\n" ends a paragraph, so a
// text whose last paragraph is empty is assigned with one more "\n" (RCTextViewStoredText; QA81 lost the
// final "\n" of a 168-character draft here).
// An empty value takes the plain setter (nothing to lose to the "\n" bug above), so no attributed
// empty paragraph is left behind; an emptied text view may also drop its font (RCTheme.h), so font
// and colour are re-applied. (The ordinary78 two-line empty field was the app editor returning "\n".)
// A change notification the text view sends while it is assigned is not passed on as a user edit.
- (void)setText:(NSString *)text {
    // `text` may be _intended itself (c.text = c.text: -text returns it): copy before releasing the old one.
    NSString *t = [[(text ? text : @"") copy] autorelease];
    UIFont *font = RCTextViewFont(_tv.font);
    UIColor *color = _tv.textColor ? _tv.textColor : [RCTheme inkColor];
    [_intended release]; _intended = [t retain];
    _assigning = YES;
    if (t.length) _tv.attributedText = [[[NSAttributedString alloc] initWithString:RCTextViewStoredText(t) attributes:RCTextViewAttributes(font, color)] autorelease];
    else { _tv.text = @""; _tv.font = font; _tv.textColor = color; }
    _assigning = NO;
    [self refresh];
}
- (NSString *)placeholder { return _placeholder; }
- (void)setPlaceholder:(NSString *)p { [_placeholder release]; _placeholder = [p copy]; _placeholderLabel.text = p; _tv.accessibilityLabel = p; }
- (NSString *)trayNote { return _trayNote; }
- (void)setTrayNote:(NSString *)n { [_trayNote release]; _trayNote = [n copy]; RCLabelSetText(_note, n); [self refresh]; }
- (NSArray *)attachments { return _attachments; }
- (void)setAttachments:(NSArray *)a { [_attachments release]; _attachments = [a copy]; [self rebuildTray]; [self refresh]; }
- (void)setShowsPlus:(BOOL)v { _showsPlus = v; [self refresh]; }
- (void)setShowsMic:(BOOL)v { _showsMic = v; [self refresh]; }
- (void)setExpandAvailable:(BOOL)v { _expandAvailable = v; [self refresh]; }
- (void)setStopAvailable:(BOOL)v { _stopAvailable = v; [self refresh]; }
- (void)setVoiceAvailable:(BOOL)v { _voiceAvailable = v; [self refresh]; }
- (void)setStreaming:(BOOL)v { _streaming = v; [self refresh]; }
- (void)setSendBlocked:(BOOL)v { if (v == _sendBlocked) return; _sendBlocked = v; [self refresh]; }
- (BOOL)editable { return _tv.editable; }
- (void)setEditable:(BOOL)v { _tv.editable = v; if (!v) [_tv resignFirstResponder]; }
- (UIButton *)sendButton { return _send; }
- (UIButton *)micButton { return _mic; }
- (UIButton *)plusButton { return _plus; }
- (void)setPreparing:(BOOL)v { _preparing = v; [self refresh]; }
- (BOOL)dictating { return _dictating; }
- (RCDictationView *)dictationView {
    if (!_dictation) { _dictation = [[RCDictationView alloc] initWithFrame:CGRectMake(0, 0, 308, 32)]; _dictation.hidden = YES; [self addSubview:_dictation]; }
    return _dictation;
}
- (void)setDictating:(BOOL)v {
    _dictating = v;
    if (v) [_tv resignFirstResponder];
    self.dictationView.hidden = !v;
    [self refresh];
}

- (BOOL)hasContent { return [self.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0 || _attachments.count > 0; }

- (RCSendMode)sendMode {
    if (_streaming && _stopAvailable) return RCSendModeStop;
    if (![self hasContent] && _voiceAvailable && !_streaming) return RCSendModeVoice;
    return RCSendModeSend;
}
- (BOOL)sendEnabled {
    RCSendMode m = [self sendMode];
    return m != RCSendModeSend || ([self hasContent] && !_streaming && !_sendBlocked);
}

- (void)setModeChipTitle:(NSString *)title glyph:(NSString *)glyph color:(RCChipColor)color {
    [_chipTitle release]; _chipTitle = [title copy];
    [_chipGlyph release]; _chipGlyph = [glyph copy];
    _chipColor = color;
    if (title) {
        [_chip setBackgroundImage:[RCComposerView chipImage:color] forState:UIControlStateNormal];
        [_chip setImage:(glyph ? [RCGlyph imageNamed:glyph size:14 color:[UIColor whiteColor]] : nil) forState:UIControlStateNormal];
        NSString *t = [NSString stringWithFormat:@"%@  ✕", title];
        [_chip setTitle:t forState:UIControlStateNormal];
        _chip.accessibilityLabel = [NSString stringWithFormat:RCL(@"%@, remove mode"), title];
    }
    [self refresh];
}

- (void)rebuildTray {
    for (UIView *v in _trayViews) [v removeFromSuperview];
    [_trayViews removeAllObjects];
    NSUInteger i = 0;
    for (RCComposerAttachment *a in _attachments) {
        RCTrayItemView *v = [[[RCTrayItemView alloc] initWithAttachment:a] autorelease];
        v.frame = CGRectMake(i * 62, 0, 54, 54);
        v->_remove.tag = i;
        [v->_remove addTarget:self action:@selector(tapRemove:) forControlEvents:UIControlEventTouchUpInside];
        if ([_delegate respondsToSelector:@selector(composerView:didTapAttachmentAtIndex:)]) { v->_open.hidden = NO; v->_open.tag = i; [v->_open addTarget:self action:@selector(tapAttachment:) forControlEvents:UIControlEventTouchUpInside]; }
        [_tray addSubview:v];
        [_trayViews addObject:v];
        i++;
    }
    _tray.contentSize = CGSizeMake(MAX(0, (CGFloat)i * 62 - 8), 54);
}

- (void)refresh {
    _plus.hidden = !_showsPlus || _dictating;
    _field.hidden = _send.hidden = _dictating;
    _mic.hidden = !_showsMic;
    _placeholderLabel.hidden = self.text.length > 0;
    RCSendMode m = [self sendMode];
    BOOL red = m == RCSendModeStop;
    [_send setBackgroundImage:[RCComposerView sendImage:red pressed:NO] forState:UIControlStateNormal];
    [_send setBackgroundImage:[RCComposerView sendImage:red pressed:YES] forState:UIControlStateHighlighted];
    [_send setTitleShadowColor:RCHexA(red ? 0x500000 : 0x003c19, .55) forState:UIControlStateNormal];
    if (m == RCSendModeSend) {
        [_send setImage:nil forState:UIControlStateNormal];
        [_send setTitle:RCL(@"Send (short composer title)") forState:UIControlStateNormal]; // ru «Отпр.» fits 58 pt; VoiceOver keeps the full word
        _send.accessibilityLabel = RCL(@"Send");
    } else {
        [_send setTitle:nil forState:UIControlStateNormal];
        [_send setImage:[RCGlyph imageNamed:(red ? @"stop" : @"voice") size:(red ? 14 : 20) color:[UIColor whiteColor]] forState:UIControlStateNormal];
        _send.accessibilityLabel = red ? RCL(@"Stop") : RCL(@"Voice conversation");
    }
    BOOL enabled = [self sendEnabled];
    _send.enabled = enabled;
    _send.alpha = enabled ? 1 : .5;
    _sendLamp.hidden = !(m == RCSendModeSend && _preparing);
    _chip.hidden = _chipTitle == nil;
    _tray.hidden = _attachments.count == 0;
    _note.hidden = _trayNote.length == 0;
    [self setNeedsLayout];
    CGFloat h = [self heightForWidth:self.bounds.size.width];
    if (h != _lastHeight) {
        _lastHeight = h;
        if ([_delegate respondsToSelector:@selector(composerView:didChangeHeight:)]) [_delegate composerView:self didChangeHeight:h];
    }
}

#pragma mark - Layout

- (CGFloat)fieldWidthForWidth:(CGFloat)width { return width - 12 - (_showsPlus ? 38 : 0) - (kSendW + 6); }
- (CGFloat)textRightPad { return _showsMic ? 34 : 12; }

- (CGFloat)fieldHeightForWidth:(CGFloat)width {
    CGFloat tw = [self fieldWidthForWidth:width] - 2 - 12 - [self textRightPad];
    NSString *t = self.text; t = t.length ? t : @"M"; // the intended text: its lines are the ones shown
    if ([t hasSuffix:@"\n"]) t = [t stringByAppendingString:@"M"];
    CGFloat th = ceil([t sizeWithFont:RCTextViewFont(_tv.font) constrainedToSize:CGSizeMake(tw, 10000) lineBreakMode:NSLineBreakByWordWrapping].height);
    return MIN(kFieldMax, MAX(kFieldMin, th + 11)) + 2;
}

- (CGFloat)layoutForWidth:(CGFloat)width apply:(BOOL)apply {
    CGFloat y = 7;
    if (_trayNote.length) {
        CGFloat nh = RCMeasureText(_trayNote, _note.font, width - 16).height;
        if (apply) _note.frame = CGRectMake(8, y - 3, width - 16, nh);
        y += -3 + nh + 6;
    }
    if (_attachments.count) {
        if (apply) _tray.frame = CGRectMake(6, y + 6, width - 12, 54);
        y += 6 + 54 + 7;
    }
    if (_chipTitle) {
        if (apply) {
            CGSize ts = [[_chip titleForState:UIControlStateNormal] sizeWithFont:_chip.titleLabel.font];
            CGFloat cw = MIN(width - 12, ceil(ts.width) + 14 + 3 + 14 + 2);
            _chip.frame = CGRectMake(6, y - 1, cw, 24);
        }
        y += -1 + 24 + 6;
    }
    CGFloat fh = [self fieldHeightForWidth:width], rowH = _dictating ? 32 : MAX(32, fh);
    if (apply && _dictation) _dictation.frame = CGRectMake(6, y, width - 12, 32);
    if (apply) {
        CGFloat fx = 6 + (_showsPlus ? 38 : 0), fw = [self fieldWidthForWidth:width];
        _plus.frame = CGRectMake(6, y + rowH - 32, 32, 32);
        _field.frame = CGRectMake(fx, y + rowH - fh, fw, fh);
        CGFloat inner = fh - 2;
        // UITextView on iOS 6 pads text by 8 pt; offset it so text sits at 12/6 like the prototype.
        _tv.frame = CGRectMake(1 + 12 - 8, 1 + 6 - 8, fw - 2 - 12 - [self textRightPad] + 16, inner + 8 - 3);
        _placeholderLabel.frame = CGRectMake(1 + 12, 1 + 6, fw - 2 - 12 - [self textRightPad], 19);
        _mic.frame = CGRectMake(fw - 4 - 26 - 1, fh - 3 - 26 - 1, 26, 26);
        BOOL tall = fh - 2 > 60;
        _expand.hidden = !(tall && _expandAvailable);
        _expand.frame = CGRectMake(fw - 6 - 22 - 1, 5, 22, 22);
        _send.frame = CGRectMake(width - 6 - kSendW, y + rowH - 32, kSendW, 32);
        CGRect lf = _sendLamp.frame;
        lf.origin = CGPointMake(kSendW - 3 - 7 - (lf.size.width - 7) / 2, 3 - (lf.size.height - 7) / 2);
        _sendLamp.frame = lf;
        _tv.scrollEnabled = fh >= kFieldMax + 2;
    }
    y += rowH + 7;
    return y;
}

- (CGFloat)heightForWidth:(CGFloat)width { return [self layoutForWidth:(width > 0 ? width : 320) apply:NO]; }
- (CGSize)sizeThatFits:(CGSize)size { CGFloat w = size.width > 0 ? size.width : 320; return CGSizeMake(w, [self heightForWidth:w]); }
- (void)layoutSubviews { [super layoutSubviews]; [self layoutForWidth:self.bounds.size.width apply:YES]; }

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    BOOL dark = [RCTheme isDark];
    RCDrawVerticalGradient(ctx, b, [NSArray arrayWithObjects:RCHex(dark ? 0x2a332f : 0xf3f6f4), RCHex(dark ? 0x161c19 : 0xd3ddd8), nil], nil);
    CGContextSetFillColorWithColor(ctx, RCHex(dark ? 0x000000 : 0x94a39b).CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, b.size.width, 1));
    CGContextSetFillColorWithColor(ctx, (dark ? RCHexA(0xffffff, .1) : [UIColor whiteColor]).CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 1, b.size.width, 1));
}

#pragma mark - Events

// Every edit UIKit reports is applied to the intended text (typed Return, Backspace, paste, Select All).
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    NSString *edited = RCTextViewEditedText(textView.text, _intended, range, text);
    [_intended release]; _intended = [edited copy];
    return YES;
}
- (void)textViewDidChange:(UITextView *)textView {
    [self refresh];
    if (_assigning) return; // -setText: itself, not the user
    if ([_delegate respondsToSelector:@selector(composerViewTextDidChange:)]) [_delegate composerViewTextDidChange:self];
    [_tv scrollRangeToVisible:_tv.selectedRange];
}
- (BOOL)becomeFirstResponder { return [_tv becomeFirstResponder]; }
- (BOOL)resignFirstResponder { return [_tv resignFirstResponder]; }
- (BOOL)isFirstResponder { return [_tv isFirstResponder]; }

- (void)tapSend {
    switch ([self sendMode]) {
        case RCSendModeStop: if ([_delegate respondsToSelector:@selector(composerViewDidTapStop:)]) [_delegate composerViewDidTapStop:self]; break;
        case RCSendModeVoice: if ([_delegate respondsToSelector:@selector(composerViewDidTapVoice:)]) [_delegate composerViewDidTapVoice:self]; break;
        default: if ([self sendEnabled] && [_delegate respondsToSelector:@selector(composerViewDidTapSend:)]) [_delegate composerViewDidTapSend:self]; break;
    }
}
- (void)tapPlus { if ([_delegate respondsToSelector:@selector(composerViewDidTapPlus:)]) [_delegate composerViewDidTapPlus:self]; }
- (void)tapMic { if ([_delegate respondsToSelector:@selector(composerViewDidTapMic:)]) [_delegate composerViewDidTapMic:self]; }
- (void)tapExpand { if ([_delegate respondsToSelector:@selector(composerViewDidTapExpand:)]) [_delegate composerViewDidTapExpand:self]; }
- (void)tapChip { if ([_delegate respondsToSelector:@selector(composerViewDidClearMode:)]) [_delegate composerViewDidClearMode:self]; }
- (void)tapAttachment:(UIButton *)b { if ([_delegate respondsToSelector:@selector(composerView:didTapAttachmentAtIndex:)]) [_delegate composerView:self didTapAttachmentAtIndex:(NSUInteger)b.tag]; }
- (void)tapRemove:(UIButton *)b { if ([_delegate respondsToSelector:@selector(composerView:didRemoveAttachmentAtIndex:)]) [_delegate composerView:self didRemoveAttachmentAtIndex:(NSUInteger)b.tag]; }

#ifdef OR6_CHAT_ACCEPTANCE
#pragma mark - Acceptance-only line-break probe (RCComposerView.h)

static NSString *RCProbeSHA256(NSString *s) {
    NSData *d = [s dataUsingEncoding:NSUTF8StringEncoding]; unsigned char h[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(d.bytes, (CC_LONG)d.length, h);
    NSMutableString *x = [NSMutableString stringWithCapacity:64];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [x appendFormat:@"%02x", h[i]];
    return x;
}
// "raw": the attributed string assigned as is (the pre-QA82 setter); "stored": RCTextViewStoredText.
// "composer": a real RCComposerView -setText: then -text (the QA81 round trip), then c.text = c.text
// (-text may return the stored intended string itself: the setter must copy it before releasing).
// The views are autoreleased: nothing stays off-screen after the call.
+ (NSArray *)lineBreakProbe {
    NSArray *texts = [NSArray arrayWithObjects:@"a", @"a\nb", @"a\n", @"a\n\n", @"\n", @"", nil];
    NSMutableArray *out = [NSMutableArray array];
    UITextView *tv = [[[UITextView alloc] initWithFrame:CGRectMake(0, 0, 200, 100)] autorelease];
    tv.font = RCTextViewFont([UIFont systemFontOfSize:16]);
    RCComposerView *c = [[[RCComposerView alloc] initWithFrame:CGRectMake(0, 0, 320, 46)] autorelease];
    for (NSString *mode in [NSArray arrayWithObjects:@"raw", @"stored", nil])
        for (NSString *t in texts) {
            NSString *assigned = [mode isEqualToString:@"raw"] ? t : RCTextViewStoredText(t);
            if (assigned.length) tv.attributedText = [[[NSAttributedString alloc] initWithString:assigned attributes:RCTextViewAttributes(tv.font, [RCTheme inkColor])] autorelease];
            else tv.text = @"";
            NSString *back = tv.text ? tv.text : @"";
            [out addObject:@{@"mode": mode, @"intendedLength": @(t.length), @"intendedSHA256": RCProbeSHA256(t), @"assignedLength": @(assigned.length),
                             @"readBackLength": @(back.length), @"readBackSHA256": RCProbeSHA256(back), @"recovered": @([RCTextViewIntendedText(back, t) isEqualToString:t])}];
        }
    for (NSString *t in texts) {
        c.text = t;
        NSString *back = c.textView.text ? c.textView.text : @"";
        BOOL recovered = [c.text isEqualToString:t];
        c.text = c.text; // self-assignment through the getter
        [out addObject:@{@"mode": @"composer", @"intendedLength": @(t.length), @"intendedSHA256": RCProbeSHA256(t), @"readBackLength": @(back.length),
                         @"readBackSHA256": RCProbeSHA256(back), @"textLength": @(c.text.length), @"recovered": @(recovered),
                         @"selfAssignRecovered": @([c.text isEqualToString:t])}];
    }
    return out;
}
#endif
@end
