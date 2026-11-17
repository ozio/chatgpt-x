#import "RCSelectTextViewController.h"
#import "RCTheme.h"
#import "RCHUD.h"
#import <QuartzCore/QuartzCore.h> // headers only (layer messages)

@interface RCSelectTextViewController ()
- (void)textViewRequestedCopy;
@end

// Read-only text view whose callout offers only Copy / Select / Select All, and whose
// Copy goes through the controller (so the caller can own the clipboard write).
@interface RCSelectableTextView : UITextView { @public RCSelectTextViewController *owner; }
@end
@implementation RCSelectableTextView
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(copy:)) return self.selectedRange.length > 0;
    if (action == @selector(select:) || action == @selector(selectAll:)) return [super canPerformAction:action withSender:sender];
    return NO;
}
- (void)copy:(id)sender { [owner textViewRequestedCopy]; }
@end

@interface RCSelectTextViewController () {
    RCSelectableTextView *_textView;
    UIView *_card;
    UILabel *_hintLabel;
    UIToolbar *_toolbar;
}
@end

@implementation RCSelectTextViewController
@synthesize text = _text, hint = _hint, showsDoneButton = _showsDoneButton, delegate = _delegate, textView = _textView;

+ (UINavigationController *)navigationControllerWithText:(NSString *)text delegate:(id<RCSelectTextViewControllerDelegate>)delegate {
    RCSelectTextViewController *c = [[[self alloc] initWithText:text] autorelease];
    c.delegate = delegate;
    UINavigationController *nav = [[[UINavigationController alloc] initWithRootViewController:c] autorelease];
    [RCTheme styleNavigationBar:nav.navigationBar variant:RCBarVariantJade];
    return nav;
}

- (id)initWithText:(NSString *)text {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _text = [text copy];
        _hint = [RCL(@"Select a passage: touch and hold a word, then drag the handles.") copy];
        _showsDoneButton = YES;
        self.title = RCL(@"Selection");
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(themeChanged) name:RCThemeAppearanceDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(themeChanged) name:RCThemeTextSizeDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _textView->owner = nil;
    [_textView release]; [_card release]; [_hintLabel release]; [_toolbar release];
    [_text release]; [_hint release];
    [super dealloc];
}

- (void)loadView {
    UIView *v = [[[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame] autorelease];
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view = v;

    _card = [[UIView alloc] initWithFrame:CGRectZero];
    _card.layer.cornerRadius = 9;
    _card.layer.borderWidth = 1;
    [v addSubview:_card];

    _textView = [[RCSelectableTextView alloc] initWithFrame:CGRectZero];
    _textView->owner = self;
    _textView.editable = NO;
    _textView.dataDetectorTypes = UIDataDetectorTypeNone;
    _textView.backgroundColor = [UIColor clearColor];
    _textView.alwaysBounceVertical = YES;
    _textView.accessibilityLabel = RCL(@"Text to select");
    [_card addSubview:_textView];

    _hintLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _hintLabel.backgroundColor = [UIColor clearColor];
    _hintLabel.font = [UIFont systemFontOfSize:13];
    _hintLabel.textAlignment = NSTextAlignmentCenter;
    [v addSubview:_hintLabel];

    _toolbar = [[UIToolbar alloc] initWithFrame:CGRectZero];
    [RCTheme styleToolbar:_toolbar];
    UIBarButtonItem *all = [[[UIBarButtonItem alloc] initWithTitle:RCL(@"Select All") style:UIBarButtonItemStyleBordered target:self action:@selector(selectAll)] autorelease];
    UIBarButtonItem *flex = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL] autorelease];
    UIBarButtonItem *copy = [[[UIBarButtonItem alloc] initWithTitle:RCL(@"Copy") style:UIBarButtonItemStyleDone target:self action:@selector(copySelection)] autorelease];
    all.accessibilityHint = RCL(@"Selects all the text");
    copy.accessibilityHint = RCL(@"Copies the selection or all the text");
    _toolbar.items = [NSArray arrayWithObjects:all, flex, copy, nil];
    [v addSubview:_toolbar];
    [self applyTheme];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationItem.rightBarButtonItem = _showsDoneButton ? [[[UIBarButtonItem alloc] initWithTitle:RCL(@"Done") style:UIBarButtonItemStyleDone target:self action:@selector(done)] autorelease] : nil;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect b = self.view.bounds;
    CGFloat tb = 44, hintH = 0;
    if (_hint.length) hintH = RCMeasureText(_hint, _hintLabel.font, b.size.width - 40).height + 14;
    _toolbar.frame = CGRectMake(0, b.size.height - tb, b.size.width, tb);
    _hintLabel.frame = CGRectMake(20, b.size.height - tb - hintH, b.size.width - 40, hintH);
    _card.frame = CGRectMake(9, 10, b.size.width - 18, MAX(60, b.size.height - tb - hintH - 10 - (hintH ? 0 : 10)));
    _textView.frame = CGRectInset(_card.bounds, 2, 2);
}

- (void)applyTheme {
    if (![self isViewLoaded]) return;
    self.view.backgroundColor = [RCTheme contentBackgroundColor];
    _card.backgroundColor = [RCTheme cardColor];
    _card.layer.borderColor = [RCTheme cardStrokeColor].CGColor;
    _hintLabel.textColor = [RCTheme noteTextColor];
    _hintLabel.shadowColor = [RCTheme engravedShadowColor];
    _hintLabel.shadowOffset = [RCTheme engravedShadowOffset];
    RCLabelSetText(_hintLabel, _hint);
    _hintLabel.hidden = !_hint.length;
    // iOS 6: -setText: turns line breaks into spaces; the attributed form keeps them.
    NSString *t = RCDisplayText(_text ? _text : @"");
    NSDictionary *a = RCTextViewAttributes([RCTheme bodyFont], [RCTheme answerTextColor]);
    _textView.attributedText = [[[NSAttributedString alloc] initWithString:t attributes:a] autorelease];
    _textView.indicatorStyle = [RCTheme isDark] ? UIScrollViewIndicatorStyleWhite : UIScrollViewIndicatorStyleDefault;
    [self.view setNeedsLayout];
}

- (void)themeChanged { [self applyTheme]; }

- (void)setText:(NSString *)text { if (text == _text) return; [_text release]; _text = [text copy]; [self applyTheme]; }
- (void)setHint:(NSString *)hint { [_hint release]; _hint = [hint copy]; [self applyTheme]; }

- (NSString *)textToCopy {
    NSString *shown = _textView.text ? _textView.text : @"";
    NSRange r = _textView.selectedRange;
    // The view shows RCDisplayText (₽ → "руб."); copy the original text unless a fragment is selected.
    if (r.location == NSNotFound || r.length == 0 || NSMaxRange(r) > shown.length) return _text ? _text : @"";
    if (r.location == 0 && r.length == shown.length) return _text ? _text : @"";
    return [shown substringWithRange:r];
}

- (void)selectAll {
    [_textView becomeFirstResponder];
    _textView.selectedRange = NSMakeRange(0, _textView.text.length);
    [[UIMenuController sharedMenuController] setTargetRect:CGRectMake(_textView.bounds.size.width / 2, _textView.contentOffset.y + 10, 1, 1) inView:_textView];
    [[UIMenuController sharedMenuController] setMenuVisible:YES animated:YES];
}

- (void)textViewRequestedCopy { [self copySelection]; }

- (void)copySelection {
    NSString *t = self.textToCopy;
    if (!t.length) return;
    if ([_delegate respondsToSelector:@selector(selectTextController:copyText:)]) {
        [_delegate selectTextController:self copyText:t];
        return;
    }
    [UIPasteboard generalPasteboard].string = t;
    [RCHUD showText:RCL(@"Copied") kind:RCHUDDone inView:(self.view.window ? self.view.window : self.view) seconds:0];
}

- (void)done {
    if ([_delegate respondsToSelector:@selector(selectTextControllerDidFinish:)]) [_delegate selectTextControllerDidFinish:self];
    else [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}
@end
