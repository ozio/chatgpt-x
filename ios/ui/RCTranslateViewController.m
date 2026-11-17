#import "RCTranslateViewController.h"
#import "RCTheme.h"
#import "RCGlyph.h"
#import "RCButton.h"
#import "RCHUD.h"
#import <QuartzCore/QuartzCore.h> // headers only (layer messages)

// Jade glossy language pill (.tr-bar .lang), flat when fixed.
static UIImage *RCLangPill(BOOL fixed, BOOL pressed) {
    NSString *key = [NSString stringWithFormat:@"tr-lang-%d-%d", fixed, pressed];
    return [RCTheme imageForKey:key size:CGSizeMake(14, 30) capInsets:UIEdgeInsetsMake(6, 6, 6, 6) drawing:^(CGContextRef ctx, CGRect r) {
        CGPathRef p = RCCreateRoundedRectPath(CGRectInset(r, .5, .5), 5);
        CGContextSaveGState(ctx); CGContextAddPath(ctx, p); CGContextClip(ctx);
        if (fixed) { CGContextSetFillColorWithColor(ctx, RCHexA(0, .15).CGColor); CGContextFillRect(ctx, r); }
        else {
            CGContextSetFillColorWithColor(ctx, RCHex(pressed ? 0x0b5d3a : 0x1f8656).CGColor); CGContextFillRect(ctx, r);
            NSArray *locs = [NSArray arrayWithObjects:[NSNumber numberWithFloat:0], [NSNumber numberWithFloat:.5], [NSNumber numberWithFloat:.51], [NSNumber numberWithFloat:1], nil];
            RCDrawVerticalGradient(ctx, r, [NSArray arrayWithObjects:RCHexA(0xdcffec, .38), RCHexA(0xdcffec, .1), RCHexA(0, .02), RCHexA(0, .14), nil], locs);
        }
        CGContextRestoreGState(ctx);
        CGContextAddPath(ctx, p); CGContextSetStrokeColorWithColor(ctx, RCHexA(0x04341e, fixed ? .4 : .85).CGColor); CGContextStrokePath(ctx);
        CGPathRelease(p);
    }];
}

// White box with a footer strip (.tr-box / .tf).
@interface RCTranslateBox : UIView { @public UIView *footer; UILabel *footLabel; }
@end
@implementation RCTranslateBox
- (id)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.backgroundColor = [UIColor whiteColor];
        self.layer.cornerRadius = 9; self.layer.borderWidth = 1; self.layer.borderColor = RCHex(0xaebbb4).CGColor;
        self.clipsToBounds = YES;
        footer = [[UIView alloc] initWithFrame:CGRectZero];
        footer.backgroundColor = RCHex(0xf3f6f4);
        UIView *line = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 1000, 1)] autorelease];
        line.backgroundColor = RCHex(0xe0e7e3);
        [footer addSubview:line];
        footLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        footLabel.backgroundColor = [UIColor clearColor];
        footLabel.font = [UIFont boldSystemFontOfSize:12];
        footLabel.textColor = RCHex(0x6b7a72);
        [footer addSubview:footLabel];
        [self addSubview:footer];
    }
    return self;
}
- (void)dealloc { [footer release]; [footLabel release]; [super dealloc]; }
@end

@interface RCTranslateViewController () {
    UIToolbar *_bar;
    UIButton *_from, *_to, *_swap;
    UILabel *_arrow;
    UIScrollView *_scroll;
    RCTranslateBox *_sourceBox, *_resultBox;
    UITextView *_input;
    UILabel *_placeholder, *_output, *_note;
    RCButton *_go, *_copy, *_share;
    UIActivityIndicatorView *_spinner;
    CGFloat _keyboard;
}
@end

@implementation RCTranslateViewController
@synthesize sourceLanguage = _sourceLanguage, targetLanguage = _targetLanguage, languagesEditable = _languagesEditable, sourceText = _sourceText,
    detectedText = _detectedText, resultText = _resultText, busy = _busy, errorText = _errorText, shareAvailable = _shareAvailable, delegate = _delegate;

- (id)initWithNibName:(NSString *)n bundle:(NSBundle *)b {
    if ((self = [super initWithNibName:n bundle:b])) {
        _sourceLanguage = [RCL(@"Detect") copy];
        _targetLanguage = [@"English" copy];
        _sourceText = [@"" copy];
        self.title = RCL(@"Translate");
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(themeChanged) name:RCThemeAppearanceDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(keyboard:) name:UIKeyboardWillChangeFrameNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _input.delegate = nil;
    [_bar release]; [_from release]; [_to release]; [_swap release]; [_arrow release]; [_scroll release];
    [_sourceBox release]; [_resultBox release]; [_input release]; [_placeholder release]; [_output release]; [_note release];
    [_go release]; [_copy release]; [_share release]; [_spinner release];
    [_sourceLanguage release]; [_targetLanguage release]; [_sourceText release]; [_detectedText release]; [_resultText release]; [_errorText release];
    [super dealloc];
}

- (UIButton *)langButton:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    b.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    b.titleLabel.shadowOffset = CGSizeMake(0, -1);
    [b setTitleShadowColor:RCHexA(0x002d16, .7) forState:UIControlStateNormal];
    b.contentEdgeInsets = UIEdgeInsetsMake(0, 6, 0, 6);
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return [b retain];
}

- (void)loadView {
    UIView *v = [[[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame] autorelease];
    self.view = v;
    _scroll = [[UIScrollView alloc] initWithFrame:CGRectZero];
    _scroll.alwaysBounceVertical = YES;
    [v addSubview:_scroll];
    _bar = [[UIToolbar alloc] initWithFrame:CGRectZero];
    [_bar setBackgroundImage:[RCTheme navigationBarBackgroundForVariant:RCBarVariantJade] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
    [v addSubview:_bar];
    _from = [self langButton:@selector(fromTapped)];
    _to = [self langButton:@selector(toTapped)];
    _swap = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
    [_swap setImage:[RCGlyph imageNamed:@"swap" size:20 color:[UIColor whiteColor]] forState:UIControlStateNormal];
    _swap.showsTouchWhenHighlighted = YES;
    _swap.accessibilityLabel = RCL(@"Swap languages");
    [_swap addTarget:self action:@selector(swapTapped) forControlEvents:UIControlEventTouchUpInside];
    _arrow = [[UILabel alloc] initWithFrame:CGRectZero];
    _arrow.backgroundColor = [UIColor clearColor]; _arrow.textColor = [UIColor whiteColor]; _arrow.font = [UIFont boldSystemFontOfSize:15]; _arrow.text = @"→"; _arrow.textAlignment = NSTextAlignmentCenter;
    _arrow.isAccessibilityElement = NO;
    for (UIView *x in [NSArray arrayWithObjects:_from, _to, _swap, _arrow, nil]) [_bar addSubview:x];

    _sourceBox = [[RCTranslateBox alloc] initWithFrame:CGRectZero];
    _input = [[UITextView alloc] initWithFrame:CGRectZero];
    _input.font = [UIFont systemFontOfSize:17];
    _input.textColor = [RCTheme inkColor];
    _input.backgroundColor = [UIColor clearColor];
    _input.delegate = self;
    _input.accessibilityLabel = RCL(@"Text to translate");
    [_sourceBox addSubview:_input];
    _placeholder = [[UILabel alloc] initWithFrame:CGRectZero];
    _placeholder.backgroundColor = [UIColor clearColor]; _placeholder.font = [UIFont systemFontOfSize:17]; _placeholder.textColor = RCHex(0xa9b6af);
    _placeholder.text = RCL(@"Type or paste text");
    _placeholder.isAccessibilityElement = NO;
    [_sourceBox addSubview:_placeholder];
    _go = [[RCButton buttonWithStyle:RCButtonStylePillGo title:RCL(@"Translate")] retain];
    [_go addTarget:self action:@selector(goTapped) forControlEvents:UIControlEventTouchUpInside];
    [_sourceBox->footer addSubview:_go];
    [_scroll addSubview:_sourceBox];

    _resultBox = [[RCTranslateBox alloc] initWithFrame:CGRectZero];
    _output = [[UILabel alloc] initWithFrame:CGRectZero];
    _output.backgroundColor = [UIColor clearColor]; _output.font = [UIFont systemFontOfSize:17]; _output.textColor = [RCTheme inkColor];
    [_resultBox addSubview:_output];
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    _spinner.hidesWhenStopped = YES;
    [_resultBox addSubview:_spinner];
    _copy = [[RCButton buttonWithStyle:RCButtonStylePill title:RCL(@"Copy")] retain];
    [_copy addTarget:self action:@selector(copyTapped) forControlEvents:UIControlEventTouchUpInside];
    _share = [[RCButton buttonWithStyle:RCButtonStylePill title:RCL(@"Share")] retain];
    [_share addTarget:self action:@selector(shareTapped) forControlEvents:UIControlEventTouchUpInside];
    [_resultBox->footer addSubview:_copy]; [_resultBox->footer addSubview:_share];
    [_scroll addSubview:_resultBox];

    _note = [[UILabel alloc] initWithFrame:CGRectZero];
    _note.backgroundColor = [UIColor clearColor];
    _note.font = [UIFont systemFontOfSize:13];
    [_scroll addSubview:_note];
    UITapGestureRecognizer *tap = [[[UITapGestureRecognizer alloc] initWithTarget:_input action:@selector(resignFirstResponder)] autorelease];
    tap.cancelsTouchesInView = NO;
    [_scroll addGestureRecognizer:tap];
    [self themeChanged];
}

- (void)themeChanged {
    if (![self isViewLoaded]) return;
    self.view.backgroundColor = [RCTheme contentBackgroundColor];
    _note.textColor = [RCTheme noteTextColor];
    _note.shadowColor = [RCTheme engravedShadowColor]; _note.shadowOffset = [RCTheme engravedShadowOffset];
    RCLabelSetText(_note, RCL(@"Translations are not saved in the chat history."));
    [self refresh];
}

- (void)refresh {
    if (![self isViewLoaded]) return;
    for (UIButton *b in [NSArray arrayWithObjects:_from, _to, nil]) {
        [b setBackgroundImage:RCLangPill(!_languagesEditable, NO) forState:UIControlStateNormal];
        [b setBackgroundImage:RCLangPill(!_languagesEditable, _languagesEditable) forState:UIControlStateHighlighted];
        b.userInteractionEnabled = _languagesEditable;
    }
    [_from setTitle:_sourceLanguage forState:UIControlStateNormal];
    [_to setTitle:_targetLanguage forState:UIControlStateNormal];
    _from.accessibilityLabel = [RCL(@"From: ") stringByAppendingString:_sourceLanguage ? _sourceLanguage : @""];
    _to.accessibilityLabel = [RCL(@"To: ") stringByAppendingString:_targetLanguage ? _targetLanguage : @""];
    _swap.hidden = !_languagesEditable;
    _arrow.hidden = _languagesEditable;
    if (![_input.text isEqualToString:_sourceText]) {
        NSDictionary *a = RCTextViewAttributes(_input.font, [RCTheme inkColor]);
        _input.attributedText = [[[NSAttributedString alloc] initWithString:(_sourceText ? _sourceText : @"") attributes:a] autorelease];
    }
    _placeholder.hidden = _input.text.length > 0;
    _sourceBox->footLabel.text = _detectedText;
    _go.enabled = !_busy && [_input.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0;
    BOOL showResult = _busy || _resultText.length || _errorText.length;
    _resultBox.hidden = !showResult;
    _resultBox->footLabel.text = _targetLanguage;
    if (_busy) { [_spinner startAnimating]; _output.text = nil; }
    else {
        [_spinner stopAnimating];
        _output.textColor = _errorText.length ? [RCTheme errorInkColor] : [RCTheme inkColor];
        RCLabelSetText(_output, _errorText.length ? _errorText : _resultText);
    }
    _copy.hidden = _share.hidden = !_shareAvailable || _busy || !_resultText.length || _errorText.length;
    [self.view setNeedsLayout];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width, h = self.view.bounds.size.height;
    _bar.frame = CGRectMake(0, 0, w, 44);
    if (_languagesEditable) {
        _from.frame = CGRectMake(round(w / 2 - 20 - 118), 7, 118, 30);
        _swap.frame = CGRectMake(round(w / 2 - 20), 7, 40, 30);
        _to.frame = CGRectMake(round(w / 2 + 20), 7, 118, 30);
    } else {
        _from.frame = CGRectMake(round(w / 2 - 20 - 118), 7, 118, 30);
        _arrow.frame = CGRectMake(round(w / 2 - 20), 7, 40, 30);
        _to.frame = CGRectMake(round(w / 2 + 20), 7, 118, 30);
    }
    _scroll.frame = CGRectMake(0, 44, w, MAX(0, h - 44 - _keyboard));
    CGFloat bw = w - 18, y = 10;
    _sourceBox.frame = CGRectMake(9, y, bw, 120 + 38);
    _input.frame = CGRectMake(2, 2, bw - 4, 116);
    _placeholder.frame = CGRectMake(10, 9, bw - 20, 22);
    _sourceBox->footer.frame = CGRectMake(0, 120, bw, 38);
    _sourceBox->footLabel.frame = CGRectMake(8, 6, bw - 120, 26);
    CGRect gf = _go.frame; gf.origin = CGPointMake(bw - 8 - gf.size.width, 6); _go.frame = gf;
    y += 158 + 10;
    if (!_resultBox.hidden) {
        CGFloat oh = MAX(60, RCMeasureText(_output.text, _output.font, bw - 20).height);
        _resultBox.frame = CGRectMake(9, y, bw, oh + 20 + 38);
        _output.frame = CGRectMake(10, 10, bw - 20, oh);
        _spinner.center = CGPointMake(22, 22);
        _resultBox->footer.frame = CGRectMake(0, oh + 20, bw, 38);
        _resultBox->footLabel.frame = CGRectMake(8, 6, bw - 180, 26);
        CGFloat x = bw - 8;
        for (RCButton *b in [NSArray arrayWithObjects:_share, _copy, nil]) { CGRect f = b.frame; x -= f.size.width; f.origin = CGPointMake(x, 6); b.frame = f; x -= 6; }
        y += _resultBox.frame.size.height + 10;
    }
    CGFloat nh = RCMeasureText(_note.text, _note.font, w - 28).height;
    _note.frame = CGRectMake(14, y + 2, w - 28, nh);
    _scroll.contentSize = CGSizeMake(w, y + nh + 20);
}

- (void)keyboard:(NSNotification *)n {
    if (![self isViewLoaded] || !self.view.window) return;
    CGRect f = [self.view convertRect:[[n.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue] fromView:nil];
    CGRect o = CGRectIntersection(self.view.bounds, f);
    _keyboard = CGRectIsNull(o) ? 0 : o.size.height;
    [self.view setNeedsLayout];
    [UIView animateWithDuration:.25 animations:^{ [self.view layoutIfNeeded]; }];
}

- (void)textViewDidChange:(UITextView *)t { [_sourceText release]; _sourceText = [t.text copy]; _placeholder.hidden = t.text.length > 0; _go.enabled = !_busy && [t.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0; }

#define RC_SETTER(name, ivar) - (void)name:(NSString *)v { [ivar release]; ivar = [v copy]; [self refresh]; }
RC_SETTER(setSourceLanguage, _sourceLanguage)
RC_SETTER(setTargetLanguage, _targetLanguage)
RC_SETTER(setSourceText, _sourceText)
RC_SETTER(setDetectedText, _detectedText)
RC_SETTER(setResultText, _resultText)
RC_SETTER(setErrorText, _errorText)
#undef RC_SETTER
- (void)setBusy:(BOOL)b { _busy = b; [self refresh]; if (b) UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, RCL(@"Translating")); else if (_resultText.length) UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, _output); }
- (void)setLanguagesEditable:(BOOL)e { _languagesEditable = e; [self refresh]; }
- (void)setShareAvailable:(BOOL)s { _shareAvailable = s; [self refresh]; }

- (void)goTapped { [_input resignFirstResponder]; [_delegate translate:self translateText:_input.text]; }
- (void)fromTapped { if ([_delegate respondsToSelector:@selector(translateDidTapSourceLanguage:)]) [_delegate translateDidTapSourceLanguage:self]; }
- (void)toTapped { if ([_delegate respondsToSelector:@selector(translateDidTapTargetLanguage:)]) [_delegate translateDidTapTargetLanguage:self]; }
- (void)swapTapped {
    NSString *f = [[_sourceLanguage retain] autorelease];
    // «Определить» cannot be a target: the caller replaces it after the swap if needed.
    [_sourceLanguage release]; _sourceLanguage = [_targetLanguage copy];
    [_targetLanguage release]; _targetLanguage = [f copy];
    [_resultText release]; _resultText = nil;
    [self refresh];
    if ([_delegate respondsToSelector:@selector(translateDidSwapLanguages:)]) [_delegate translateDidSwapLanguages:self];
}
- (void)copyTapped {
    if ([_delegate respondsToSelector:@selector(translate:copyResult:)]) { [_delegate translate:self copyResult:_resultText]; return; }
    [UIPasteboard generalPasteboard].string = _resultText;
    [RCHUD showText:RCL(@"Copied") kind:RCHUDDone inView:(self.view.window ? self.view.window : self.view) seconds:0];
}
- (void)shareTapped { if ([_delegate respondsToSelector:@selector(translate:shareResult:)]) [_delegate translate:self shareResult:_resultText]; }
@end
