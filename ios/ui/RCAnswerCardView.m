#import "RCAnswerCardView.h"
#import "RCTextStackView.h"
#import "RCTheme.h"
#import "RCGlyph.h"
#import "RCLampView.h"
#import "RCButton.h"
#import <QuartzCore/QuartzCore.h> // headers only (layer messages), no QuartzCore link

@interface RCAnswerCardView () <RCActionBarDelegate, RCMarkdownViewDelegate> {
    UIImageView *_icon;
    UILabel *_who, *_thinkLabel, *_cutNote;
    RCTextStackView *_body;
    UIImageView *_cardBg;
    BOOL _dying; // UIKit can lay a view out again while [super dealloc] tears down its subviews
    RCMarkdownView *_md;
    UIControl *_thinkRow;
    RCLampView *_thinkLamp;
    UIImageView *_twisty;
    UIView *_steps, *_dots;
    RCButton *_continue;
    RCActionBar *_bar;
    NSTimer *_blink;
    BOOL _cursorOn, _held;
    NSString *_text, *_assistantName, *_reasoningTitle, *_cutNoteText;
    NSArray *_reasoningSteps, *_partViews;
}
@end

@implementation RCAnswerCardView
@synthesize textMode = _textMode, copyCodeEnabled = _copyCodeEnabled, codeDelegate = _codeDelegate, state = _state, showsReasoning = _showsReasoning, reasoningExpanded = _reasoningExpanded, continueAvailable = _continueAvailable, selectMenuEnabled = _selectMenuEnabled, copyMenuEnabled = _copyMenuEnabled, actionBar = _bar, delegate = _delegate;

static UILabel *RCLabel(UIFont *font, UIColor *color) {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectZero];
    l.backgroundColor = [UIColor clearColor];
    l.font = font;
    l.textColor = color;
    return l;
}

+ (UIImage *)headerIcon {
    return [RCTheme imageForKey:@"answer-header-icon" size:CGSizeMake(16, 16) capInsets:UIEdgeInsetsZero drawing:^(CGContextRef ctx, CGRect r) {
        CGPathRef p = RCCreateRoundedRectPath(r, 4);
        CGContextAddPath(ctx, p); CGContextClip(ctx); CGPathRelease(p);
        [[RCTheme appIconImage:29] drawInRect:r];
    }];
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        _copyMenuEnabled = YES;
        _assistantName = [@"ChatGPT" copy];
        _cutNoteText = [RCL(@"The answer is incomplete") copy];
        // Created here, never inside -layoutSubviews: inserting a subview while UIKit walks
        // this view's subviews (window changes during navigation) crashed on iOS 6.1.4.
        _cardBg = [[UIImageView alloc] initWithFrame:CGRectZero];
        [self addSubview:_cardBg];
        _icon = [[UIImageView alloc] initWithImage:[RCAnswerCardView headerIcon]];
        [self addSubview:_icon];
        _who = RCLabel([UIFont boldSystemFontOfSize:12], [RCTheme secondaryInkColor]);
        [self addSubview:_who];

        _thinkRow = [[UIControl alloc] initWithFrame:CGRectZero];
        [_thinkRow addTarget:self action:@selector(toggleReasoning) forControlEvents:UIControlEventTouchUpInside];
        _thinkLamp = [[RCLampView alloc] initWithDiameter:8];
        _thinkLamp.state = RCLampBusy;
        [_thinkRow addSubview:_thinkLamp];
        _thinkLabel = RCLabel([UIFont boldSystemFontOfSize:13], [RCTheme secondaryInkColor]);
        [_thinkRow addSubview:_thinkLabel];
        _twisty = [[UIImageView alloc] initWithImage:[RCGlyph imageNamed:@"down" size:10 color:[RCTheme secondaryInkColor]]];
        [_thinkRow addSubview:_twisty];
        _steps = [[UIView alloc] initWithFrame:CGRectZero];
        _steps.userInteractionEnabled = NO;
        [_thinkRow addSubview:_steps];
        [self addSubview:_thinkRow];

        _dots = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 40, 12)];
        for (int i = 0; i < 3; i++) {
            UIView *d = [[[UIView alloc] initWithFrame:CGRectMake(i * 11, 2, 7, 7)] autorelease];
            d.backgroundColor = RCHex(0x9fb3a9);
            d.layer.cornerRadius = 3.5;
            d.alpha = .3;
            [_dots addSubview:d];
        }
        [self addSubview:_dots];

        _body = [[RCTextStackView alloc] initWithFrame:CGRectZero];
        [self addSubview:_body];
        _md = [[RCMarkdownView alloc] initWithFrame:CGRectZero];
        _md.hidden = YES;
        _md.linkDelegate = self;
        [self addSubview:_md];

        _cutNote = RCLabel([UIFont boldSystemFontOfSize:12], [RCTheme warningInkColor]);
        [self addSubview:_cutNote];
        _continue = [[RCButton buttonWithStyle:RCButtonStylePillGo title:RCL(@"Continue answer")] retain];
        [_continue addTarget:self action:@selector(tapContinue) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_continue];

        _bar = [[RCActionBar alloc] initWithFrame:CGRectZero];
        _bar.delegate = self;
        [self addSubview:_bar];

        UILongPressGestureRecognizer *lp = [[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)] autorelease];
        [self addGestureRecognizer:lp];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(menuWillHide:) name:UIMenuControllerWillHideMenuNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeChanged) name:RCThemeAppearanceDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeChanged) name:RCThemeTextSizeDidChangeNotification object:nil];
        [self refresh];
    }
    return self;
}

- (void)dealloc {
    _dying = YES;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_blink invalidate];
    _md.linkDelegate = nil;
    [_icon release]; [_who release]; [_body release]; [_cardBg release]; _cardBg = nil; [_md release]; [_thinkLabel release]; [_cutNote release];
    [_thinkRow release]; [_thinkLamp release]; [_twisty release]; [_steps release]; [_dots release];
    [_continue release]; _bar.delegate = nil; [_bar release];
    [_text release]; [_assistantName release]; [_reasoningTitle release]; [_cutNoteText release];
    [_reasoningSteps release]; [_partViews release];
    [super dealloc];
}

#pragma mark - Properties

#define RC_COPY_SETTER(Name, ivar) - (void)set##Name:(id)v { if (ivar == v || [ivar isEqual:v]) return; [ivar release]; ivar = [v copy]; [self refresh]; }
- (NSString *)text { return _text; }
RC_COPY_SETTER(Text, _text)
- (NSString *)assistantName { return _assistantName; }
RC_COPY_SETTER(AssistantName, _assistantName)
- (NSString *)reasoningTitle { return _reasoningTitle; }
RC_COPY_SETTER(ReasoningTitle, _reasoningTitle)
- (NSString *)cutNoteText { return _cutNoteText; }
RC_COPY_SETTER(CutNoteText, _cutNoteText)
- (NSArray *)reasoningSteps { return _reasoningSteps; }
RC_COPY_SETTER(ReasoningSteps, _reasoningSteps)
#undef RC_COPY_SETTER

- (NSArray *)partViews { return _partViews; }
- (void)setPartViews:(NSArray *)views {
    if (!views.count && !_partViews.count) return;
    for (UIView *v in _partViews) [v removeFromSuperview];
    [_partViews release];
    _partViews = [views copy];
    for (UIView *v in _partViews) [self addSubview:v];
    [self refresh];
}
- (void)setState:(RCAnswerState)s { if (s == _state) return; _state = s; [self refresh]; }
- (void)setShowsReasoning:(BOOL)v { if (v == _showsReasoning) return; _showsReasoning = v; [self refresh]; }
- (void)setReasoningExpanded:(BOOL)v { if(_reasoningExpanded==v)return;_reasoningExpanded = v; [self refresh]; }
- (void)setContinueAvailable:(BOOL)v { if (v == _continueAvailable) return; _continueAvailable = v; [self refresh]; }
- (NSSet *)citationURLs { return _md.citationURLs; }
- (void)setCitationURLs:(NSSet *)urls { _md.citationURLs = urls; }
- (void)setTextMode:(RCAnswerTextMode)m { if (m == _textMode) return; _textMode = m; [self refresh]; }
- (void)setCopyCodeEnabled:(BOOL)v { if (v == _copyCodeEnabled) return; _copyCodeEnabled = v; _md.copyCodeEnabled = v; }
- (void)setCodeDelegate:(id<RCCodeBlockViewDelegate>)d { _codeDelegate = d; _md.codeDelegate = d; }
- (void)themeChanged { [_md reload]; [self refresh]; [self setNeedsLayout]; }
- (BOOL)usesMarkdown { return _textMode == RCAnswerTextMarkdown; }

#pragma mark - Content

- (NSAttributedString *)bodyText {
    NSMutableParagraphStyle *ps = [[[NSMutableParagraphStyle alloc] init] autorelease];
    CGFloat lh = [RCTheme bodyLineHeight:YES];
    ps.minimumLineHeight = lh; ps.maximumLineHeight = lh;
    NSDictionary *a = [NSDictionary dictionaryWithObjectsAndKeys:[RCTheme bodyFont], NSFontAttributeName, [RCTheme answerTextColor], NSForegroundColorAttributeName, ps, NSParagraphStyleAttributeName, nil];
    NSString *t = _text ? _text : @"";
    if (_textMode == RCAnswerTextPlain) t = [RCMarkdownView plainTextFromMarkdown:t];
    t = RCDisplayText(t);
    NSMutableAttributedString *s = [[[NSMutableAttributedString alloc] initWithString:t attributes:a] autorelease];
    if (_state == RCAnswerStreaming) {
        NSMutableDictionary *c = [[a mutableCopy] autorelease];
        [c setObject:(_cursorOn ? RCHex(0x2fae6c) : [UIColor clearColor]) forKey:NSForegroundColorAttributeName];
        [s appendAttributedString:[[[NSAttributedString alloc] initWithString:@"▌" attributes:c] autorelease]];
    }
    return s;
}

- (BOOL)showsBody { return _text.length > 0 || _state == RCAnswerStreaming; }
- (BOOL)showsDots { return _state == RCAnswerThinking && !_showsReasoning; }
- (BOOL)showsThinkRow { return _showsReasoning && (_state == RCAnswerThinking || _reasoningTitle.length); }
- (BOOL)showsBar { return (_state == RCAnswerDone || _state == RCAnswerCut) && !_bar.isEmpty; }

- (void)refresh {
    UIColor *secondary = [RCTheme answerSecondaryColor];
    _who.textColor = secondary;
    _thinkLabel.textColor = secondary;
    _twisty.image = [RCGlyph imageNamed:@"down" size:10 color:secondary];
    _who.text = _assistantName;
    BOOL running = _state == RCAnswerThinking;
    _thinkLamp.hidden = !running;
    _thinkLabel.text = _reasoningTitle.length ? _reasoningTitle : (running ? RCL(@"Thinking") : @"");
    _twisty.hidden = !_reasoningSteps.count;
    _thinkRow.enabled = _reasoningSteps.count > 0;
    _twisty.transform = CGAffineTransformMakeRotation(_reasoningExpanded ? 0 : -M_PI_2);
    _thinkRow.accessibilityLabel = _thinkLabel.text;
    _thinkRow.accessibilityValue=_reasoningSteps.count?(_reasoningExpanded?RCL(@"Expanded"):RCL(@"Collapsed")):nil;
    _thinkRow.isAccessibilityElement = YES;
    _thinkRow.accessibilityTraits = _reasoningSteps.count ? UIAccessibilityTraitButton : UIAccessibilityTraitStaticText;
    _thinkRow.hidden = ![self showsThinkRow];
    _dots.hidden = ![self showsDots];
    _cutNote.text = _cutNoteText;
    _cutNote.hidden = !(_state == RCAnswerCut && !_continueAvailable);
    _continue.hidden = !(_state == RCAnswerCut && _continueAvailable);
    // Inset numbered steps, using the existing answer-card palette.
    _steps.backgroundColor=[RCTheme cardHeldColor];_steps.layer.cornerRadius=6;
    _steps.layer.borderColor=[RCTheme cardStrokeColor].CGColor;_steps.layer.borderWidth=.5;
    // steps
    for (UIView *v in _steps.subviews) [v removeFromSuperview];
    _steps.hidden = !_reasoningExpanded;
    if (_reasoningExpanded) {
        NSUInteger number=0;
        for (NSString *step in _reasoningSteps) {
            UILabel *l = [RCLabel([UIFont systemFontOfSize:MAX(11,[RCTheme bodyFont].pointSize-3)], [RCTheme answerTextColor]) autorelease];
            l.numberOfLines = 0;
            RCLabelSetText(l, step);
            [_steps addSubview:l];
            UILabel *mark=[RCLabel([UIFont boldSystemFontOfSize:11],[RCTheme jadeColor])autorelease];
            mark.text=[NSString stringWithFormat:@"%lu",(unsigned long)++number];mark.textAlignment=NSTextAlignmentCenter;
            mark.backgroundColor=[RCTheme cardColor];mark.layer.cornerRadius=9;mark.layer.borderColor=[RCTheme cardStrokeColor].CGColor;mark.layer.borderWidth=.5;
            mark.isAccessibilityElement=NO;[_steps addSubview:mark];
        }
    }
    [self updateTimers];
    [self setNeedsLayout];
    [self setNeedsDisplay];
    [_bar setNeedsDisplay];
}

- (void)didMoveToWindow { [super didMoveToWindow]; [self updateTimers]; }

- (void)updateTimers {
    BOOL wantBlink = _state == RCAnswerStreaming && self.window;
    if (wantBlink && !_blink) {
        _cursorOn = YES;
        _blink = [NSTimer scheduledTimerWithTimeInterval:.5 target:self selector:@selector(blinkTick) userInfo:nil repeats:YES];
    } else if (!wantBlink && _blink) { [_blink invalidate]; _blink = nil; }
    BOOL wantDots = [self showsDots] && self.window;
    for (NSUInteger i = 0; i < _dots.subviews.count; i++) {
        UIView *d = [_dots.subviews objectAtIndex:i];
        [d.layer removeAllAnimations];
        d.alpha = .3; d.transform = CGAffineTransformMakeScale(.8, .8);
        if (wantDots) [UIView animateWithDuration:.48 delay:.2 * i options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionCurveEaseInOut animations:^{ d.alpha = 1; d.transform = CGAffineTransformIdentity; } completion:nil];
    }
}
- (void)removeFromSuperview { [_blink invalidate]; _blink = nil; [super removeFromSuperview]; }
- (void)blinkTick {
    _cursorOn = !_cursorOn;
    if ([self usesMarkdown]) _md.cursorOn = _cursorOn;
    else _body.attributedText = [self bodyText];
}

#pragma mark - Layout

static CGFloat RCViewHeight(UIView *v, CGFloat width) {
    if ([v respondsToSelector:@selector(heightForWidth:)]) return [(id)v heightForWidth:width];
    return [v sizeThatFits:CGSizeMake(width, 10000)].height;
}

- (CGFloat)layoutForWidth:(CGFloat)width apply:(BOOL)apply {
    CGFloat cardX = 10, cardW = width - 20, x = cardX + 12, w = cardW - 24, y = 9;
    if (apply) { _icon.frame = CGRectMake(x, y, 16, 16); _who.frame = CGRectMake(x + 22, y, w - 22, 16); }
    y += 16 + 4;
    if ([self showsThinkRow]) {
        y -= 2;
        CGFloat rowH = 3 + 16 + 3, lampW = _thinkLamp.hidden ? 0 : 13;
        CGFloat tw = ceil([_thinkLabel.text sizeWithFont:_thinkLabel.font].width);
        tw = MIN(tw, w - lampW - 14);
        CGFloat stepsH = 0;
        if (_reasoningExpanded) {
            stepsH = 10;
            NSArray *sv = _steps.subviews;
            for (NSUInteger i = 0; i + 1 < sv.count; i += 2) {
                UILabel *l = [sv objectAtIndex:i];
                CGFloat lh = ceil(RCMeasureText(l.text,l.font,MAX(1,w-44)).height),rh=MAX(20,lh);
                if(apply){l.frame=CGRectMake(34,stepsH,w-44,lh);[[sv objectAtIndex:i+1]setFrame:CGRectMake(8,stepsH,18,18)];}
                stepsH+=rh+(i+2<sv.count?10:0);
            }
            stepsH += 10;
        }
        if (apply) {
            _thinkRow.frame = CGRectMake(x, y, w, rowH + stepsH);
            _thinkLamp.center = CGPointMake(4, 3 + 9);
            _thinkLabel.frame = CGRectMake(lampW, 3, tw, 16);
            _twisty.frame = CGRectMake(lampW + tw + 2, 3 + 4, 10, 10);
            _steps.frame = CGRectMake(0, rowH, w, stepsH);
        }
        y += rowH + stepsH + 6;
    }
    if ([self showsDots]) { if (apply) _dots.frame = CGRectMake(x, y + 2, 40, 12); y += 16; }
    if ([self showsBody] && [self usesMarkdown]) {
        _md.markdown = _text ? _text : @"";
        _md.showsCursor = _state == RCAnswerStreaming;
        CGFloat mh = [_md heightForWidth:w];
        if (apply) { _md.frame = CGRectMake(x, y, w, mh); [_md setNeedsLayout]; }
        y += mh;
    } else if ([self showsBody]) {
        NSAttributedString *at = [self bodyText];
        CGFloat bh = 0;
        for (NSAttributedString *chunk in [RCTextStackView chunksOfAttributedString:at]) bh += ceil([chunk boundingRectWithSize:CGSizeMake(w, 100000) options:NSStringDrawingUsesLineFragmentOrigin context:nil].size.height);
        if (apply) { _body.attributedText = at; _body.frame = CGRectMake(x, y, w, bh); }
        y += bh;
    }
    _body.hidden = ![self showsBody] || [self usesMarkdown];
    _md.hidden = ![self showsBody] || ![self usesMarkdown];
    if (_state != RCAnswerThinking && _state != RCAnswerStreaming) {
        for (UIView *v in _partViews) {
            CGFloat ph = RCViewHeight(v, w);
            if (apply) { v.hidden = NO; v.frame = CGRectMake(x, y + 8, w, ph); }
            y += 8 + ph + 2;
        }
    } else if (apply) for (UIView *v in _partViews) v.hidden = YES;
    if (_state == RCAnswerCut) {
        if (_continueAvailable) { if (apply) { CGRect f = _continue.frame; f.origin = CGPointMake(x, y + 8); _continue.frame = f; } y += 8 + 26; }
        else { if (apply) _cutNote.frame = CGRectMake(x, y + 6, w, 15); y += 6 + 15; }
    }
    BOOL bar = [self showsBar];
    _bar.hidden = !bar;
    if (bar) { if (apply) _bar.frame = CGRectMake(cardX + 1, y + 9, cardW - 2, 35); y += 9 + 35 + 1; }
    else y += 10;
    return y + 12;
}

- (CGFloat)heightForWidth:(CGFloat)width { return [self layoutForWidth:width apply:NO]; }
- (CGSize)sizeThatFits:(CGSize)size { CGFloat w = size.width > 0 ? size.width : 320; return CGSizeMake(w, [self heightForWidth:w]); }
- (void)layoutSubviews { [super layoutSubviews]; if (_dying) return; [self updateCardBackground]; [self layoutForWidth:self.bounds.size.width apply:YES]; }

// The card is a stretchable image, not drawRect: a long answer's card can be
// taller than the iPhone 5 GPU texture limit, where a drawn layer is not shown.
+ (UIImage *)cardImageHeld:(BOOL)held {
    BOOL dark = [RCTheme isDark];
    NSString *key = [NSString stringWithFormat:@"answer-card-%d-%d", held, dark];
    return [RCTheme imageForKey:key size:CGSizeMake(30, 33) capInsets:UIEdgeInsetsMake(13, 13, 16, 13) drawing:^(CGContextRef ctx, CGRect r) {
        CGRect card = CGRectMake(.5, .5, 29, 29);
        CGPathRef p = RCCreateRoundedRectPath(card, 10);
        CGContextSaveGState(ctx);
        if (!dark) CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1), 2, RCHexA(0, .12).CGColor); // dark: box-shadow none
        CGContextAddPath(ctx, p);
        CGContextSetFillColorWithColor(ctx, (held ? [RCTheme cardHeldColor] : [RCTheme cardColor]).CGColor);
        CGContextFillPath(ctx);
        CGContextRestoreGState(ctx);
        CGContextAddPath(ctx, p);
        CGContextSetStrokeColorWithColor(ctx, [RCTheme cardStrokeColor].CGColor);
        CGContextSetLineWidth(ctx, 1);
        CGContextStrokePath(ctx);
        CGPathRelease(p);
    }];
}
- (void)updateCardBackground {
    if (_dying) return;
    CGRect f = CGRectMake(10, 0, MAX(0, self.bounds.size.width - 20), MAX(0, self.bounds.size.height - 12 + 3));
    // iOS 6.1.4 (device): a stretchable image in a UIImageView smaller than its caps
    // (a card that has no size yet) crashed later in UIKit. Show it only when it fits.
    BOOL fits = f.size.width >= 30 && f.size.height >= 33;
    _cardBg.frame = f;
    _cardBg.image = fits ? [RCAnswerCardView cardImageHeld:_held] : nil;
}

#pragma mark - Actions and menu

- (void)toggleReasoning {
    _reasoningExpanded = !_reasoningExpanded;
    [self refresh];
    if ([_delegate respondsToSelector:@selector(answerCardDidToggleReasoning:)]) [_delegate answerCardDidToggleReasoning:self];
}
- (void)tapContinue { if ([_delegate respondsToSelector:@selector(answerCardDidTapContinue:)]) [_delegate answerCardDidTapContinue:self]; }
- (void)actionBar:(RCActionBar *)bar didSelectAction:(RCAnswerAction)action {
    if ([_delegate respondsToSelector:@selector(answerCard:didSelectAction:)]) [_delegate answerCard:self didSelectAction:action];
}

- (BOOL)canBecomeFirstResponder { return YES; }
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(copy:)) return YES;
    if (action == @selector(rc_select:)) return _selectMenuEnabled;
    return NO;
}
- (NSString *)readableText {
    NSString *t = _text ? _text : @"";
    return _textMode == RCAnswerTextRaw ? t : [RCMarkdownView readableTextFromMarkdown:t];
}
- (void)copy:(id)sender {
    if ([_delegate respondsToSelector:@selector(answerCardDidRequestCopy:)]) [_delegate answerCardDidRequestCopy:self];
    else [UIPasteboard generalPasteboard].string = [self readableText];
}
- (void)markdownView:(RCMarkdownView *)view didSelectLinkURL:(NSURL *)url title:(NSString *)title {
    if ([_delegate respondsToSelector:@selector(answerCard:didSelectLinkURL:title:)]) [_delegate answerCard:self didSelectLinkURL:url title:title];
}
- (void)rc_select:(id)sender { if ([_delegate respondsToSelector:@selector(answerCardDidRequestSelect:)]) [_delegate answerCardDidRequestSelect:self]; }

- (void)longPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan || !_copyMenuEnabled || _state == RCAnswerThinking || _state == RCAnswerStreaming) return;
    [self becomeFirstResponder];
    _held = YES; [self updateCardBackground];
    UIMenuController *m = [UIMenuController sharedMenuController];
    m.menuItems = _selectMenuEnabled ? [NSArray arrayWithObject:[[[UIMenuItem alloc] initWithTitle:RCL(@"Select Text") action:@selector(rc_select:)] autorelease]] : nil;
    CGPoint pt = [g locationInView:self];
    [m setTargetRect:CGRectMake(pt.x, pt.y, 1, 1) inView:self];
    [m setMenuVisible:YES animated:YES];
}
- (void)menuWillHide:(NSNotification *)n { if (_held) { _held = NO; [self updateCardBackground]; } }
@end
