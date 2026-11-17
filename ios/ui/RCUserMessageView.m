#import "RCUserMessageView.h"
#import "RCFileIcon.h"
#import "RCTheme.h"
#import "RCComposerView.h"
#import "RCTextStackView.h"
#import <QuartzCore/QuartzCore.h> // headers only (layer messages), no QuartzCore link

#pragma mark - Bubble

@interface RCBubbleView : UIView { @public RCBubbleTint _tint; BOOL _held; RCTextStackView *_label; UIImageView *_tall; BOOL _dying; }
@end

@implementation RCBubbleView
- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        _tall = [[UIImageView alloc] initWithFrame:CGRectZero]; // created here, never inside -layoutSubviews
        _tall.hidden = YES;
        [self addSubview:_tall];
        _label = [[RCTextStackView alloc] initWithFrame:CGRectZero];
        [self addSubview:_label];
    }
    return self;
}
- (void)dealloc { _dying = YES; [_label release]; [_tall release]; [super dealloc]; }

// One outline for body and tail ("swoosh"): rounded body whose flat bottom runs
// straight into a sharp tip at the bottom right, with a concave right side above
// it. A single path keeps the 1-pt stroke seamless. The body is size.width - 6
// wide; the tip uses the 6 pt on the right.
static CGPathRef RCCreateBubblePath(CGSize size) {
    CGFloat r = 17, maxX = size.width - 6, maxY = size.height - 1;
    CGMutablePathRef p = CGPathCreateMutable();
    CGPathMoveToPoint(p, NULL, r, 0);
    CGPathAddArcToPoint(p, NULL, maxX, 0, maxX, maxY, r);
    CGPathAddLineToPoint(p, NULL, maxX, maxY - 14);
    CGPathAddCurveToPoint(p, NULL, maxX, maxY - 5, maxX + 3, maxY - 1, maxX + 6, maxY);
    CGPathAddArcToPoint(p, NULL, 0, maxY, 0, 0, r);
    CGPathAddArcToPoint(p, NULL, 0, 0, maxX, 0, r);
    CGPathCloseSubpath(p);
    return p;
}

// Matte jade (graphite in a temporary chat): one flat fill, a 1-pt darker
// stroke inside the outline, a 1-pt light inner edge on top and a soft drop.
// Nothing depends on the height, so tall bubbles look like short ones.
static void RCDrawBubble(CGContextRef ctx, CGSize size, RCBubbleTint tint, BOOL held) {
    BOOL green = tint == RCBubbleGreen;
    UIColor *fill = green ? RCHex(0x2b9f63) : RCHex(0x5b666c);
    UIColor *stroke = green ? RCHex(0x1e8650) : RCHex(0x454f55);
    CGPathRef o = RCCreateBubblePath(size);
    // fill with 0 1px 1px rgba(0,0,0,.15)
    CGContextSaveGState(ctx);
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1), 1, RCHexA(0, .15).CGColor);
    CGContextSetFillColorWithColor(ctx, fill.CGColor);
    CGContextAddPath(ctx, o); CGContextFillPath(ctx);
    CGContextRestoreGState(ctx);
    // inset 0 1px 0 rgba(255,255,255,.3) along the top arc: a 2-pt light band,
    // the outer point of which the stroke covers next
    CGContextSaveGState(ctx);
    CGContextAddPath(ctx, o); CGContextClip(ctx);
    CGContextClipToRect(ctx, CGRectMake(0, 0, size.width, 19));
    CGContextSetFillColorWithColor(ctx, RCHexA(0xffffff, .3).CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, size.width, size.height));
    CGContextTranslateCTM(ctx, 0, 2);
    CGContextSetFillColorWithColor(ctx, fill.CGColor);
    CGContextAddPath(ctx, o); CGContextFillPath(ctx);
    CGContextRestoreGState(ctx);
    // 1-pt stroke: a 2-pt line clipped to the inside
    CGContextSaveGState(ctx);
    CGContextAddPath(ctx, o); CGContextClip(ctx);
    CGContextAddPath(ctx, o);
    CGContextSetLineWidth(ctx, 2);
    CGContextSetStrokeColorWithColor(ctx, stroke.CGColor);
    CGContextStrokePath(ctx);
    CGContextRestoreGState(ctx);
    if (held) {
        CGContextSaveGState(ctx);
        CGContextAddPath(ctx, o);
        CGContextSetFillColorWithColor(ctx, RCHexA(0, .18).CGColor);
        CGContextFillPath(ctx);
        CGContextRestoreGState(ctx);
    }
    CGPathRelease(o);
}
// A layer taller than the GPU texture limit is not drawn on the iPhone 5: very
// tall bubbles (long pasted text) use a stretchable rendering instead.
- (BOOL)isTall { return self.bounds.size.height > 1800; }
- (void)layoutSubviews {
    [super layoutSubviews];
    if (_dying) return;
    if ([self isTall]) {
        NSString *key = [NSString stringWithFormat:@"bubble-tall-c-%d-%d", _tint, _held];
        RCBubbleTint tint = _tint; BOOL held = _held;
        _tall.image = [RCTheme imageForKey:key size:CGSizeMake(64, 64) capInsets:UIEdgeInsetsMake(24, 20, 24, 26) drawing:^(CGContextRef ctx, CGRect r) { RCDrawBubble(ctx, r.size, tint, held); }];
        _tall.frame = self.bounds;
        _tall.hidden = NO;
    } else _tall.hidden = YES;
}
- (void)drawRect:(CGRect)rect {
    if ([self isTall]) return;
    RCDrawBubble(UIGraphicsGetCurrentContext(), self.bounds.size, _tint, _held);
}
@end

#pragma mark - Message row

@interface RCUserMessageView () {
    BOOL _dying;
    RCBubbleView *_bubble;
    UIButton *_badge;
    UILabel *_meta;
    RCLampView *_metaLamp;
    NSString *_text, *_metaText;
    NSArray *_attachments;
    NSMutableArray *_thumbs;
    UIButton *_pager;
}
@end

@implementation RCUserMessageView
@synthesize pagerIndex = _pagerIndex, pagerCount = _pagerCount, copyMenuEnabled = _copyMenuEnabled, tint = _tint, delivery = _delivery, editMenuEnabled = _editMenuEnabled, delegate = _delegate, badgeButton = _badge, bubbleView = _bubble;

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        _copyMenuEnabled = YES;
        _bubble = [[RCBubbleView alloc] initWithFrame:CGRectZero];
        [self addSubview:_bubble];
        _badge = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        _badge.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        [_badge addTarget:self action:@selector(badgeTapped) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_badge];
        _meta = [[UILabel alloc] initWithFrame:CGRectZero];
        _meta.backgroundColor = [UIColor clearColor];
        _meta.font = [UIFont boldSystemFontOfSize:11];
        [self appearanceChanged];
        _meta.textAlignment = NSTextAlignmentRight;
        _meta.numberOfLines = 0;
        _meta.lineBreakMode = NSLineBreakByWordWrapping;
        [self addSubview:_meta];
        _thumbs = [[NSMutableArray alloc] init];
        _pager = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        _pager.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        _pager.hidden = YES;
        [_pager addTarget:self action:@selector(pagerTapped) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_pager];
        _metaLamp = [[RCLampView alloc] initWithDiameter:7];
        [self addSubview:_metaLamp];
        UILongPressGestureRecognizer *lp = [[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)] autorelease];
        [_bubble addGestureRecognizer:lp];
        _bubble.userInteractionEnabled = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(menuWillHide:) name:UIMenuControllerWillHideMenuNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appearanceChanged) name:RCThemeAppearanceDidChangeNotification object:nil];
        [self applyDelivery];
    }
    return self;
}

- (void)dealloc {
    _dying = YES;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_bubble release]; [_badge release]; [_meta release]; [_metaLamp release];
    [_text release]; [_metaText release]; [_attachments release]; [_thumbs release]; [_pager release];
    [super dealloc];
}

- (void)appearanceChanged {
    [self updatePager];
    _meta.textColor = [RCTheme metaTextColor];
    _meta.shadowColor = [RCTheme engravedShadowColor];
    _meta.shadowOffset = [RCTheme engravedShadowOffset];
}

- (NSString *)text { return _text; }
- (void)setText:(NSString *)text { [_text release]; _text = [text copy]; [self setNeedsLayout]; }
- (NSString *)metaText { return _metaText; }
- (void)setMetaText:(NSString *)t { [_metaText release]; _metaText = [t copy]; RCLabelSetText(_meta, t); _meta.textAlignment = NSTextAlignmentRight; [self setNeedsLayout]; }
- (void)setTint:(RCBubbleTint)tint { _tint = tint; _bubble->_tint = tint; [_bubble setNeedsDisplay]; [_bubble setNeedsLayout]; }
- (void)setDelivery:(RCDeliveryState)d { _delivery = d; [self applyDelivery]; [self setNeedsLayout]; }

// "!" / "?" centred by their ink box, not by the line box UIButton uses (that
// leaves cap-height marks high). The ink box is measured once from an alpha-only
// render, since iOS 6 system fonts give no glyph names to CGFont.
static CGRect RCInkRect(NSString *mark, UIFont *font, CGPoint at) {
    CGFloat sc = [UIScreen mainScreen].scale;
    size_t w = (size_t)(40 * sc), h = (size_t)(40 * sc);
    unsigned char *px = calloc(w * h, 1);
    if (!px) return CGRectNull;
    CGContextRef c = CGBitmapContextCreate(px, w, h, 8, w, NULL, (CGBitmapInfo)kCGImageAlphaOnly);
    if (!c) { free(px); return CGRectNull; }
    CGContextTranslateCTM(c, 0, h); CGContextScaleCTM(c, sc, -sc); // top-left origin, points
    UIGraphicsPushContext(c);
    [mark drawAtPoint:at withFont:font];
    UIGraphicsPopContext();
    long x0 = (long)w, y0 = (long)h, x1 = -1, y1 = -1;
    for (size_t y = 0; y < h; y++) for (size_t x = 0; x < w; x++) if (px[y * w + x] > 96) {
        if ((long)x < x0) x0 = x; if ((long)x > x1) x1 = x;
        if ((long)y < y0) y0 = y; if ((long)y > y1) y1 = y;
    }
    CGContextRelease(c); free(px);
    if (x1 < 0) return CGRectNull;
    return CGRectMake(x0 / sc, y0 / sc, (x1 - x0 + 1) / sc, (y1 - y0 + 1) / sc);
}

static void RCDrawBadgeMark(CGContextRef ctx, BOOL uncertain, CGPoint center) {
    NSString *mark = uncertain ? @"?" : @"!";
    UIFont *font = [UIFont boldSystemFontOfSize:16];
    CGPoint probe = CGPointMake(10, 5);
    CGRect ink = RCInkRect(mark, font, probe);
    CGFloat sc = [UIScreen mainScreen].scale;
    CGPoint at = CGPointMake(center.x - 4, center.y - 10); // fallback: rough line-box centring
    if (!CGRectIsNull(ink)) {
        at.x = round((probe.x + center.x - CGRectGetMidX(ink)) * sc) / sc;
        at.y = round((probe.y + center.y - CGRectGetMidY(ink)) * sc) / sc;
    }
    CGContextSaveGState(ctx);
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, -.5), 0, RCHexA(0, .25).CGColor);
    UIGraphicsPushContext(ctx);
    [[UIColor whiteColor] set];
    [mark drawAtPoint:at withFont:font];
    UIGraphicsPopContext();
    CGContextRestoreGState(ctx);
}

+ (UIImage *)badgeImage:(BOOL)uncertain {
    NSString *key = uncertain ? @"badge-unk-3" : @"badge-err-3";
    return [RCTheme imageForKey:key size:CGSizeMake(26, 27) capInsets:UIEdgeInsetsZero drawing:^(CGContextRef ctx, CGRect b) {
        CGRect r = CGRectMake(1, 1, 24, 24);
        CGContextSaveGState(ctx);
        CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1), 2, RCHexA(0, .4).CGColor);
        CGContextSetFillColorWithColor(ctx, RCHex(uncertain ? 0x9a6400 : 0x8a1206).CGColor);
        CGContextFillEllipseInRect(ctx, r);
        CGContextRestoreGState(ctx);
        CGContextSaveGState(ctx);
        CGContextAddEllipseInRect(ctx, CGRectInset(r, 1, 1));
        CGContextClip(ctx);
        NSArray *c = uncertain ? [NSArray arrayWithObjects:RCHex(0xffd36e), RCHex(0xe29a0e), nil] : [NSArray arrayWithObjects:RCHex(0xf37a6c), RCHex(0xd01e0c), nil];
        RCDrawVerticalGradient(ctx, r, c, nil);
        CGContextSetFillColorWithColor(ctx, RCHexA(0xffffff, .4).CGColor);
        CGContextFillRect(ctx, CGRectMake(0, 2, 26, 1));
        CGContextRestoreGState(ctx);
        RCDrawBadgeMark(ctx, uncertain, CGPointMake(CGRectGetMidX(r), CGRectGetMidY(r)));
        (void)b;
    }];
}

- (void)applyDelivery {
    BOOL badge = _delivery == RCDeliveryFailed || _delivery == RCDeliveryUncertain;
    _badge.hidden = !badge;
    if (badge) {
        BOOL unk = _delivery == RCDeliveryUncertain;
        [_badge setBackgroundImage:[RCUserMessageView badgeImage:unk] forState:UIControlStateNormal];
        [_badge setTitle:nil forState:UIControlStateNormal]; // the mark is drawn into the image
        _badge.accessibilityLabel = unk ? RCL(@"Delivery not confirmed") : RCL(@"Not sent");
    }
    switch (_delivery) {
        case RCDeliveryQueued:
        case RCDeliverySending: _metaLamp.state = RCLampBusy; _metaLamp.hidden = NO; break;
        case RCDeliveryUncertain: _metaLamp.state = RCLampWarn; _metaLamp.hidden = NO; break;
        default: _metaLamp.state = RCLampOff; _metaLamp.hidden = YES; break;
    }
}

- (NSAttributedString *)attributedText {
    NSMutableParagraphStyle *ps = [[[NSMutableParagraphStyle alloc] init] autorelease];
    CGFloat lh = [RCTheme bodyLineHeight:NO];
    ps.minimumLineHeight = lh; ps.maximumLineHeight = lh;
    // matte bubble: plain white text, no engraved shadow
    NSDictionary *a = [NSDictionary dictionaryWithObjectsAndKeys:[RCTheme bodyFont], NSFontAttributeName, [UIColor whiteColor], NSForegroundColorAttributeName, ps, NSParagraphStyleAttributeName, nil];
    return [[[NSAttributedString alloc] initWithString:RCDisplayText(_text ? _text : @"") attributes:a] autorelease];
}

// Geometry shared by layout and height: row has 10 pt side margins and 46 pt left inset.
- (BOOL)hasBubble { return _text.length > 0; }
- (CGFloat)thumbsHeight { return _attachments.count ? 74 + 4 : 0; }

- (CGRect)bubbleFrameForWidth:(CGFloat)width text:(NSAttributedString *)at {
    if (![self hasBubble]) return CGRectMake(width - 10, [self thumbsHeight], 0, 0);
    BOOL badge = _delivery == RCDeliveryFailed || _delivery == RCDeliveryUncertain;
    CGFloat maxBubble = width - 20 - 46 - (badge ? 30 : 0);
    CGRect tr = [at boundingRectWithSize:CGSizeMake(maxBubble - 26 - 6, 10000) options:NSStringDrawingUsesLineFragmentOrigin context:nil];
    CGFloat bw = ceil(tr.size.width) + 26 + 6, bh = ceil(tr.size.height) + 17 + 1;
    return CGRectMake(width - 10 - bw + 6, [self thumbsHeight], bw, bh);
}

- (CGFloat)pagerHeight { return _pagerCount >= 2 ? 3 + 16 : 0; }

- (CGFloat)metaHeightForWidth:(CGFloat)width {
    if (!_metaText.length || _delivery == RCDeliverySent) return 0;
    CGFloat lampW = _metaLamp.hidden ? 0 : 10;
    CGSize s = RCMeasureText(_metaText, _meta.font, width - 20 - lampW);
    return 3 + ceil(s.height);
}

- (CGFloat)heightForWidth:(CGFloat)width {
    CGRect bf = [self bubbleFrameForWidth:width text:[self attributedText]];
    return CGRectGetMaxY(bf) + [self pagerHeight] + [self metaHeightForWidth:width] + 12;
}
- (CGSize)sizeThatFits:(CGSize)size { CGFloat w = size.width > 0 ? size.width : 320; return CGSizeMake(w, [self heightForWidth:w]); }

- (void)rebuildThumbs {
    for (UIView *v in _thumbs) [v removeFromSuperview];
    [_thumbs removeAllObjects];
    for (RCComposerAttachment *a in _attachments) {
        // The sent file itself (RCFileIcon): Polaroid for pictures, paper sheet for documents.
        UIImageView *t = [[[UIImageView alloc] initWithImage:[RCFileIcon iconForFileName:a.title glyph:a.glyph photo:a.image size:CGSizeMake(74, 74) failed:a.failed]] autorelease];
        t.frame = CGRectMake(0, 0, 74, 74);
        t.isAccessibilityElement = YES;
        t.accessibilityLabel = a.title;t.accessibilityValue=a.failed?RCL(@"Error"):nil;
        [self addSubview:t];
        [_thumbs addObject:t];
    }
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (_dying) return;
    CGFloat w = self.bounds.size.width;
    CGFloat x = w - 10;
    for (UIView *t in [_thumbs reverseObjectEnumerator]) { x -= 74; t.frame = CGRectMake(x, 0, 74, 74); x -= 4; }
    NSAttributedString *at = [self attributedText];
    CGRect bf = [self bubbleFrameForWidth:w text:at];
    _bubble.hidden = ![self hasBubble];
    _bubble.frame = bf;
    _bubble->_label.attributedText = at;
    _bubble->_label.frame = CGRectMake(13, 8, MAX(0, bf.size.width - 26 - 6), MAX(0, bf.size.height - 17 - 1));
    [_bubble setNeedsDisplay]; [_bubble setNeedsLayout];
    _badge.frame = CGRectMake(bf.origin.x - 6 - 26, CGRectGetMaxY(bf) - 4 - 27 + 1, 26, 27);
    CGFloat y = CGRectGetMaxY(bf);
    _pager.hidden = _pagerCount < 2;
    if (!_pager.hidden) {
        CGFloat pw = ceil([[_pager titleForState:UIControlStateNormal] sizeWithFont:_pager.titleLabel.font].width) + 12;
        _pager.frame = CGRectMake(w - 10 - pw + 6, y + 1, pw, 18);
        y += [self pagerHeight];
    }
    CGFloat mh = [self metaHeightForWidth:w];
    _meta.hidden = mh == 0;
    if (mh > 0) {
        CGFloat lampW = _metaLamp.hidden ? 0 : 10;
        CGSize s = RCMeasureText(_metaText, _meta.font, w - 20 - lampW);
        CGFloat tw = ceil(s.width);
        _meta.frame = CGRectMake(w - 10 - tw, y + 3, tw, ceil(s.height));
        // lamp centred between the x-height and cap-height middles of the first
        // line (mixed-case text reads centred there), not on the label box
        UIFont *f = _meta.font;
        CGFloat midY = y + 3 + (f.lineHeight > 0 ? f.ascender - (f.xHeight + f.capHeight) / 4 : 7);
        CGFloat scale = [UIScreen mainScreen].scale;
        // one more device pixel up: the lamp's glow makes it read low (device-checked)
        _metaLamp.center = CGPointMake(w - 10 - tw - 10 + 3.5, (floor(midY * scale) - 1) / scale);
    } else _metaLamp.hidden = YES;
    self.accessibilityLabel = _text;
}

- (NSArray *)attachments { return _attachments; }
- (void)setAttachments:(NSArray *)a { [_attachments release]; _attachments = [a copy]; [self rebuildThumbs]; }
- (void)setPagerIndex:(NSUInteger)i { _pagerIndex = i; [self updatePager]; }
- (void)setPagerCount:(NSUInteger)n { _pagerCount = n; [self updatePager]; }
- (void)updatePager {
    if (_pagerCount < 2) { [self setNeedsLayout]; return; }
    NSString *num = [NSString stringWithFormat:@"%lu / %lu", (unsigned long)_pagerIndex + 1, (unsigned long)_pagerCount];
    NSMutableAttributedString *t = [[[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"‹  %@  ›", num] attributes:
        [NSDictionary dictionaryWithObjectsAndKeys:[UIFont boldSystemFontOfSize:12], NSFontAttributeName, [RCTheme metaTextColor], NSForegroundColorAttributeName, nil]] autorelease];
    [t addAttribute:NSForegroundColorAttributeName value:([RCTheme isDark] ? RCHex(0x7fdcab) : RCHex(0x2f7a55)) range:NSMakeRange(3, num.length)];
    [_pager setAttributedTitle:t forState:UIControlStateNormal];
    [_pager setTitle:t.string forState:UIControlStateNormal];
    _pager.accessibilityLabel = [NSString stringWithFormat:RCL(@"Version %@"), num];
    [self setNeedsLayout];
}
- (void)pagerTapped { if ([_delegate respondsToSelector:@selector(userMessageViewDidTapPager:)]) [_delegate userMessageViewDidTapPager:self]; }

#pragma mark - Edit menu

- (BOOL)canBecomeFirstResponder { return YES; }
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(copy:)) return YES;
    if (action == @selector(rc_edit:)) return _editMenuEnabled;
    return NO;
}
- (void)copy:(id)sender {
    if ([_delegate respondsToSelector:@selector(userMessageViewDidRequestCopy:)]) [_delegate userMessageViewDidRequestCopy:self];
    else [UIPasteboard generalPasteboard].string = _text ? _text : @"";
}
- (void)rc_edit:(id)sender { if ([_delegate respondsToSelector:@selector(userMessageViewDidRequestEdit:)]) [_delegate userMessageViewDidRequestEdit:self]; }

- (void)longPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan || !_copyMenuEnabled) return;
    [self becomeFirstResponder];
    _bubble->_held = YES; [_bubble setNeedsDisplay]; [_bubble setNeedsLayout];
    UIMenuController *m = [UIMenuController sharedMenuController];
    m.menuItems = _editMenuEnabled ? [NSArray arrayWithObject:[[[UIMenuItem alloc] initWithTitle:RCL(@"Edit") action:@selector(rc_edit:)] autorelease]] : nil;
    [m setTargetRect:_bubble.frame inView:self];
    [m setMenuVisible:YES animated:YES];
}
- (void)menuWillHide:(NSNotification *)n {
    if (!_bubble->_held) return;
    _bubble->_held = NO; [_bubble setNeedsDisplay]; [_bubble setNeedsLayout];
}

- (void)badgeTapped { if ([_delegate respondsToSelector:@selector(userMessageViewDidTapBadge:)]) [_delegate userMessageViewDidTapBadge:self]; }
@end
