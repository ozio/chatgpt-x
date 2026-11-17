#import "RCImageViewerController.h"
#import "RCTheme.h"
#import "RCGlyph.h"

// iOS 6 black translucent glass (Photos): a dark veil with a soft upper sheen.
// Top bar: highlight above, black hairline below; toolbar: black hairline above, highlight under it.
static UIImage *RCLightboxBar(BOOL top) {
    return [RCTheme imageForKey:(top ? @"lightbox-navbar" : @"lightbox-toolbar") size:CGSizeMake(4, 44) capInsets:UIEdgeInsetsMake(2, 1, 2, 1) drawing:^(CGContextRef ctx, CGRect r) {
        CGFloat px = 1 / [UIScreen mainScreen].scale, w = r.size.width, h = r.size.height;
        CGContextSetFillColorWithColor(ctx, RCHexA(0, .5).CGColor); CGContextFillRect(ctx, r);
        RCDrawVerticalGradient(ctx, CGRectMake(0, 0, w, h / 2), [NSArray arrayWithObjects:RCHexA(0xffffff, .2), RCHexA(0xffffff, .07), nil], nil);
        CGContextSetFillColorWithColor(ctx, RCHexA(0xffffff, .26).CGColor); CGContextFillRect(ctx, CGRectMake(0, top ? 0 : px, w, px));
        CGContextSetFillColorWithColor(ctx, RCHexA(0, .7).CGColor); CGContextFillRect(ctx, CGRectMake(0, top ? h - px : 0, w, px));
    }];
}
static UIImage *RCLightboxNoShadow(void) {
    return [RCTheme imageForKey:@"lightbox-noshadow" size:CGSizeMake(1, 1) capInsets:UIEdgeInsetsZero drawing:^(CGContextRef ctx, CGRect r) { (void)ctx; (void)r; }];
}
static UIColor *RCLightboxButtonTint(void) { return RCHex(0x2c2c2e); } // dark bordered buttons on the black glass, not the jade default

@interface RCImageViewerController () <UIActionSheetDelegate> {
    UIScrollView *_scroll;
    UIImageView *_imageView;
    UIView *_captionBand;
    UILabel *_captionLabel;
    UIToolbar *_toolbar;
    UIStatusBarStyle _savedStatus;
    RCHUD *_hud;
    NSInteger _saveIndex, _shareIndex;
}
@end

@implementation RCImageViewerController
@synthesize image = _image, caption = _caption, saveAvailable = _saveAvailable, shareAvailable = _shareAvailable, editAvailable = _editAvailable, barsHidden = _barsHidden, delegate = _delegate;

+ (UINavigationController *)navigationControllerWithImage:(UIImage *)image caption:(NSString *)caption delegate:(id<RCImageViewerControllerDelegate>)delegate {
    RCImageViewerController *c = [[[self alloc] initWithImage:image caption:caption] autorelease];
    c.delegate = delegate;
    UINavigationController *nav = [[[UINavigationController alloc] initWithRootViewController:c] autorelease];
    nav.wantsFullScreenLayout = YES;
    nav.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    return nav;
}

- (id)initWithImage:(UIImage *)image caption:(NSString *)caption {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _image = [image retain];
        _caption = [caption copy];
        _saveAvailable = _shareAvailable = YES;
        _saveIndex = _shareIndex = -1;
        self.wantsFullScreenLayout = YES;
    }
    return self;
}

- (void)dealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    _scroll.delegate = nil; [_scroll release]; [_imageView release]; [_captionBand release]; [_captionLabel release]; [_toolbar release];
    [_hud release]; [_image release]; [_caption release]; [super dealloc];
}

- (void)loadView {
    UIView *v = [[[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds] autorelease];
    v.backgroundColor = [UIColor blackColor];
    self.view = v;
    _scroll = [[UIScrollView alloc] initWithFrame:v.bounds];
    _scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scroll.delegate = self;
    _scroll.maximumZoomScale = 4;
    _scroll.showsHorizontalScrollIndicator = _scroll.showsVerticalScrollIndicator = NO;
    _scroll.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    [v addSubview:_scroll];
    _imageView = [[UIImageView alloc] initWithImage:_image];
    _imageView.isAccessibilityElement = YES;
    _imageView.accessibilityTraits = UIAccessibilityTraitImage;
    [_scroll addSubview:_imageView];
    // Caption band (.lightbox .cap): the prompt under the navigation bar, on the same black glass.
    _captionBand = [[UIView alloc] initWithFrame:CGRectZero];
    _captionBand.backgroundColor = RCHexA(0, .5);
    _captionBand.userInteractionEnabled = NO;
    [v addSubview:_captionBand];
    _captionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _captionLabel.backgroundColor = [UIColor clearColor];
    _captionLabel.font = [UIFont systemFontOfSize:13];
    _captionLabel.textColor = RCHex(0xdddddd);
    _captionLabel.shadowColor = RCHexA(0, .8); _captionLabel.shadowOffset = CGSizeMake(0, -1);
    _captionLabel.textAlignment = NSTextAlignmentCenter;
    _captionLabel.numberOfLines = 3;
    _captionLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_captionBand addSubview:_captionLabel];
    _toolbar = [[UIToolbar alloc] initWithFrame:CGRectZero];
    _toolbar.barStyle = UIBarStyleBlackTranslucent;
    _toolbar.translucent = YES;
    [_toolbar setBackgroundImage:RCLightboxBar(NO) forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
    _toolbar.tintColor = RCLightboxButtonTint();
    [v addSubview:_toolbar];
    UITapGestureRecognizer *two = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTap:)] autorelease];
    two.numberOfTapsRequired = 2;
    UITapGestureRecognizer *one = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleTap:)] autorelease];
    [one requireGestureRecognizerToFail:two];
    [_scroll addGestureRecognizer:two];
    [_scroll addGestureRecognizer:one];
    [self refresh];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    UINavigationBar *bar = self.navigationController.navigationBar;
    bar.barStyle = UIBarStyleBlackTranslucent;
    bar.translucent = YES;
    [bar setBackgroundImage:RCLightboxBar(YES) forBarMetrics:UIBarMetricsDefault];
    if ([bar respondsToSelector:@selector(setShadowImage:)]) bar.shadowImage = RCLightboxNoShadow();
    bar.tintColor = RCLightboxButtonTint();
    bar.titleTextAttributes = [NSDictionary dictionaryWithObjectsAndKeys:[UIFont boldSystemFontOfSize:20], UITextAttributeFont, [UIColor whiteColor], UITextAttributeTextColor,
                               RCHexA(0, .8), UITextAttributeTextShadowColor, [NSValue valueWithUIOffset:UIOffsetMake(0, -1)], UITextAttributeTextShadowOffset, nil];
    _savedStatus = [UIApplication sharedApplication].statusBarStyle;
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackTranslucent animated:animated];
    [self refreshBarItems];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    [[UIApplication sharedApplication] setStatusBarStyle:_savedStatus animated:animated];
}

- (void)refreshBarItems {
    UIBarButtonItem *done = [[[UIBarButtonItem alloc] initWithTitle:RCL(@"Done") style:UIBarButtonItemStyleBordered target:self action:@selector(done)] autorelease];
    done.tintColor = RCLightboxButtonTint();
    self.navigationItem.leftBarButtonItem = done;
    UIBarButtonItem *action = nil;
    if (_saveAvailable || _shareAvailable) {
        action = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(showActions:)] autorelease];
        action.tintColor = RCLightboxButtonTint();
        action.accessibilityLabel = RCL(@"Actions");
        action.accessibilityHint = _saveAvailable ? RCL(@"Save to Photos or share") : RCL(@"Share");
    }
    self.navigationItem.rightBarButtonItem = action;
}

- (void)refresh {
    if (![self isViewLoaded]) return;
    _imageView.image = _image;
    _imageView.accessibilityLabel = _caption.length ? _caption : RCL(@"Image");
    RCLabelSetText(_captionLabel, _caption.length ? _caption : nil);
    _captionLabel.accessibilityLabel = _caption;
    // Editing tools only (the prototype's toolbar): plain white glyphs on the black glass.
    NSMutableArray *items = [NSMutableArray array];
    if (_editAvailable) {
        UIBarButtonItem *flex = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL] autorelease];
        UIBarButtonItem *edit = [[[UIBarButtonItem alloc] initWithImage:[RCGlyph imageNamed:@"edit" size:22 color:[UIColor whiteColor]] style:UIBarButtonItemStylePlain target:self action:@selector(edit)] autorelease];
        edit.accessibilityLabel = RCL(@"Edit");
        [items addObject:flex]; [items addObject:edit]; [items addObject:flex];
    }
    _toolbar.items = items;
    _toolbar.hidden = !items.count;
    if (self.navigationController) [self refreshBarItems];
    [self fitImage];
    [self.view setNeedsLayout];
}

- (void)fitImage {
    CGSize b = self.view.bounds.size, s = _image.size;
    if (s.width <= 0 || s.height <= 0) return;
    _scroll.zoomScale = 1;
    CGFloat k = MIN(b.width / s.width, b.height / s.height);
    _imageView.frame = CGRectMake(0, 0, round(s.width * k), round(s.height * k));
    _scroll.contentSize = _imageView.frame.size;
    [self centre];
}

- (void)centre {
    CGSize b = _scroll.bounds.size, c = _imageView.frame.size;
    _scroll.contentInset = UIEdgeInsetsMake(MAX(0, (b.height - c.height) / 2), MAX(0, (b.width - c.width) / 2), 0, 0);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width, h = self.view.bounds.size.height;
    CGFloat top = 20 + 44, lw = w - 24;
    CGFloat lh = _captionLabel.text.length ? MIN(ceil(RCMeasureText(_captionLabel.text, _captionLabel.font, lw).height), ceil(_captionLabel.font.lineHeight * 3)) : 0;
    _captionBand.frame = CGRectMake(0, top, w, lh ? lh + 14 : 0);
    _captionLabel.frame = CGRectMake(12, 7, lw, lh);
    _captionBand.hidden = !lh;
    _toolbar.frame = CGRectMake(0, h - 44, w, 44);
    if (_scroll.zoomScale == 1) [self fitImage];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)s { (void)s; return _imageView; }
- (void)scrollViewDidZoom:(UIScrollView *)s { (void)s; [self centre]; }

- (void)doubleTap:(UITapGestureRecognizer *)g {
    if (_scroll.zoomScale > 1.01) { [_scroll setZoomScale:1 animated:YES]; return; }
    CGPoint p = [g locationInView:_imageView];
    CGFloat k = 2.5;
    CGSize s = _scroll.bounds.size;
    [_scroll zoomToRect:CGRectMake(p.x - s.width / k / 2, p.y - s.height / k / 2, s.width / k, s.height / k) animated:YES];
}
- (void)singleTap:(UITapGestureRecognizer *)g { (void)g; [self setBarsHidden:!_barsHidden animated:YES]; }

- (void)setBarsHidden:(BOOL)hidden { [self setBarsHidden:hidden animated:NO]; }
- (void)setBarsHidden:(BOOL)hidden animated:(BOOL)animated {
    _barsHidden = hidden;
    [[UIApplication sharedApplication] setStatusBarHidden:hidden withAnimation:(animated ? UIStatusBarAnimationFade : UIStatusBarAnimationNone)];
    [self.navigationController setNavigationBarHidden:hidden animated:animated];
    [UIView animateWithDuration:(animated ? .25 : 0) animations:^{
        _toolbar.alpha = hidden ? 0 : 1;
        _captionBand.alpha = hidden ? 0 : 1;
    }];
}

- (void)setImage:(UIImage *)i { [_image release]; _image = [i retain]; [self refresh]; }
- (void)setCaption:(NSString *)c { [_caption release]; _caption = [c copy]; [self refresh]; }
- (void)setSaveAvailable:(BOOL)v { _saveAvailable = v; [self refresh]; }
- (void)setShareAvailable:(BOOL)v { _shareAvailable = v; [self refresh]; }
- (void)setEditAvailable:(BOOL)v { _editAvailable = v; [self refresh]; }

#pragma mark Actions

- (void)showActions:(id)sender {
    (void)sender;
    UIActionSheet *sheet = [[[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil] autorelease];
    sheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
    _saveIndex = _saveAvailable ? [sheet addButtonWithTitle:RCL(@"Save to Photos")] : -1;
    _shareIndex = _shareAvailable ? [sheet addButtonWithTitle:RCL(@"Share…")] : -1;
    sheet.cancelButtonIndex = [sheet addButtonWithTitle:RCL(@"Cancel")];
    [sheet showInView:self.view];
}
- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
    (void)sheet;
    if (index == _saveIndex) [self save]; else if (index == _shareIndex) [self share];
}
- (void)save { if ([_delegate respondsToSelector:@selector(imageViewerDidTapSave:)]) [_delegate imageViewerDidTapSave:self]; }
- (void)share { if ([_delegate respondsToSelector:@selector(imageViewerDidTapShare:)]) [_delegate imageViewerDidTapShare:self]; }
- (void)edit { if ([_delegate respondsToSelector:@selector(imageViewerDidTapEdit:)]) [_delegate imageViewerDidTapEdit:self]; }
- (void)done {
    [self hideHUD];
    if ([_delegate respondsToSelector:@selector(imageViewerDidFinish:)]) [_delegate imageViewerDidFinish:self];
    else [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark Feedback

- (RCHUD *)showHUDText:(NSString *)text kind:(RCHUDKind)kind seconds:(NSTimeInterval)seconds {
    if (![self isViewLoaded]) return nil;
    if (kind == RCHUDBusy) [self hideHUD];
    RCHUD *hud = [RCHUD showText:text kind:kind inView:self.view seconds:seconds];
    if (kind == RCHUDBusy) { [_hud release]; _hud = [hud retain]; }
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, text);
    return hud;
}
- (void)finishHUDWithText:(NSString *)text {
    if (!_hud) { [self showHUDText:text kind:RCHUDDone seconds:0]; return; }
    [_hud finishWithText:text]; [_hud release]; _hud = nil;
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, text);
}
- (void)hideHUD { [_hud hide]; [_hud release]; _hud = nil; }
@end
