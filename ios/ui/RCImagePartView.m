#import "RCImagePartView.h"
#import "RCTheme.h"
#import <QuartzCore/QuartzCore.h> // headers only (layer messages), no QuartzCore link

@interface RCImageShade : UIView @end
@implementation RCImageShade
- (void)drawRect:(CGRect)r { RCDrawVerticalGradient(UIGraphicsGetCurrentContext(), self.bounds, [NSArray arrayWithObjects:RCHexA(0, 0), RCHexA(0, .55), nil], nil); }
@end

// Preview states use their own role labels (RCPartView recolours them for dark), wrapped through
// RCLabelSetText, sized from the body text step; the making label keeps its original look.
// Everything drawn over the picture (art, preview/making wash, bottom shade, tap target) lives in
// _clip: 1 pt inside the part's stroke with the concentric 7 pt radius, so all four corners are
// rounded and nothing covers the border (art used to sit on the stroke; wash and shade were square).
@interface RCImagePartView () { UIView *_clip; UIImageView *_art; UIView *_making; UILabel *_makingLabel, *_previewTitle, *_previewDetail; RCProgressView *_bar; RCImageShade *_shade; UIImage *_image; }
@end

@implementation RCImagePartView
@synthesize making = _making_, progress = _progress, actionsEnabled = _actionsEnabled, viewerAvailable = _viewerAvailable, previewState = _previewState, saveButton = _save, sendButton = _send, artButton = _artButton;

+ (UIImage *)placeholderArt {
    return [RCTheme imageForKey:@"image-part-placeholder" size:CGSizeMake(16, 230) capInsets:UIEdgeInsetsMake(0, 4, 0, 4) drawing:^(CGContextRef ctx, CGRect r) {
        RCDrawVerticalGradient(ctx, r, [NSArray arrayWithObjects:RCHex(0xdfe9e3), RCHex(0x9cbfae), RCHex(0x3f6b55), RCHex(0x24453a), nil],
                               [NSArray arrayWithObjects:[NSNumber numberWithFloat:0], [NSNumber numberWithFloat:.5], [NSNumber numberWithFloat:.51], [NSNumber numberWithFloat:1], nil]);
    }];
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        _clip = [[UIView alloc] initWithFrame:CGRectZero];
        _clip.backgroundColor = [UIColor clearColor];
        _clip.clipsToBounds = YES;
        _clip.layer.cornerRadius = 7;
        [self addSubview:_clip];
        _art = [[UIImageView alloc] initWithImage:[RCImagePartView placeholderArt]];
        _art.contentMode = UIViewContentModeScaleAspectFill;
        _art.clipsToBounds = YES;
        [_clip addSubview:_art];
        _artButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        _artButton.accessibilityLabel = RCL(@"Image");
        [_clip addSubview:_artButton];
        _shade = [[RCImageShade alloc] initWithFrame:CGRectZero];
        _shade.opaque = NO; _shade.backgroundColor = [UIColor clearColor]; _shade.contentMode = UIViewContentModeRedraw;
        _shade.userInteractionEnabled = NO;
        [_clip addSubview:_shade];
        _save = [[RCButton buttonWithStyle:RCButtonStylePill title:RCL(@"Save")] retain];
        _send = [[RCButton buttonWithStyle:RCButtonStylePill title:RCL(@"Send")] retain];
        [self addSubview:_save]; [self addSubview:_send];
        _making = [[UIView alloc] initWithFrame:CGRectZero];
        _making.backgroundColor = RCHexA(0xf0f6f3, .55);
        _makingLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _makingLabel.backgroundColor = [UIColor clearColor];
        _makingLabel.font = [UIFont boldSystemFontOfSize:13];
        _makingLabel.textColor = RCHex(0x2c3d35);
        _makingLabel.shadowColor = [UIColor whiteColor]; _makingLabel.shadowOffset = CGSizeMake(0, 1);
        _makingLabel.textAlignment = NSTextAlignmentCenter;
        _makingLabel.text = RCL(@"Creating image…");
        [_making addSubview:_makingLabel];
        _previewTitle = [[self labelWithRole:RCPartTextTitle font:nil] retain];
        _previewDetail = [[self labelWithRole:RCPartTextSecondary font:nil] retain];
        for (UILabel *l in [NSArray arrayWithObjects:_previewTitle, _previewDetail, nil]) {
            l.numberOfLines = 0; l.lineBreakMode = NSLineBreakByWordWrapping; l.textAlignment = NSTextAlignmentCenter; l.shadowOffset = CGSizeMake(0, 1);
            [_making addSubview:l]; // still a role label: -applyAppearance recolours it
        }
        _bar = [[RCProgressView alloc] initWithFrame:CGRectMake(0, 0, 160, 9)];
        [_making addSubview:_bar];
        _making.userInteractionEnabled = NO; // taps reach artButton below; Save/Send stay above it
        [_clip insertSubview:_making belowSubview:_shade];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textSizeChanged) name:RCThemeTextSizeDidChangeNotification object:nil];
        [self applyPreviewLook];
        [self refresh];
    }
    return self;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self name:RCThemeTextSizeDidChangeNotification object:nil]; [_previewTitle release]; [_previewDetail release]; [_clip release]; [_art release]; [_artButton release]; [_shade release]; [_save release]; [_send release]; [_making release]; [_makingLabel release]; [_bar release]; [_image release]; [super dealloc]; }

- (UIImage *)image { return _image; }
- (void)setImage:(UIImage *)img { [_image release]; _image = [img retain]; _art.image = img ? img : [RCImagePartView placeholderArt]; }
- (BOOL)making { return _making_; }
- (void)setMaking:(BOOL)m { _making_ = m; [self refresh]; }
- (void)setProgress:(CGFloat)p { _progress = p; [_bar setProgress:p animated:YES]; }
- (void)setViewerAvailable:(BOOL)v { if (_viewerAvailable == v) return; _viewerAvailable = v; [self refresh]; }
- (void)setActionsEnabled:(BOOL)v { _actionsEnabled = v; [self refresh]; }
- (void)setPreviewState:(RCImagePreviewState)s { if (s == _previewState) return; _previewState = s; [self refresh]; }

// Body text step: title one point under the body, detail three (XS 13/11 … XL 21/19).
- (void)applyPreviewLook {
    CGFloat pt = [RCTheme bodyFont].pointSize;
    _previewTitle.font = [UIFont boldSystemFontOfSize:pt - 1]; _previewDetail.font = [UIFont systemFontOfSize:pt - 3];
    _previewTitle.shadowColor = _previewDetail.shadowColor = [RCTheme engravedShadowColor];
}
- (void)applyAppearance { [super applyAppearance]; [self applyPreviewLook]; [self refresh]; }
- (void)textSizeChanged { [self applyPreviewLook]; [self refresh]; }

- (void)refresh {
    RCImagePreviewState s = _making_ ? RCImagePreviewNone : _previewState;
    NSString *title = nil, *detail = nil, *hint = nil;
    switch (s) {
        case RCImagePreviewOffer: title = RCL(@"Tap to show"); hint = RCL(@"Downloads and shows the image"); break;
        case RCImagePreviewLoading: title = RCL(@"Downloading image…"); break;
        case RCImagePreviewFailed: title = RCL(@"Could not show the image"); detail = RCL(@"Tap to retry"); hint = RCL(@"Downloads the image again"); break;
        case RCImagePreviewUnknown: title = RCL(@"Download result unknown"); detail = RCL(@"The download is not repeated"); break;
        case RCImagePreviewUnavailable: title = RCL(@"Preview unavailable"); break;
        default: break;
    }
    BOOL loading = s == RCImagePreviewLoading;
    RCLabelSetText(_previewTitle, title ?: @""); RCLabelSetText(_previewDetail, detail ?: @"");
    _previewTitle.hidden = !title; _previewDetail.hidden = !detail; _makingLabel.hidden = !_making_;
    // Preview overlay: the card colour of the appearance; the making overlay keeps its old wash.
    _making.backgroundColor = _making_ ? RCHexA(0xf0f6f3, .55) : [[RCTheme cardColor] colorWithAlphaComponent:.82];
    if (_making_) title = RCL(@"Creating image…");
    _bar.hidden = !(_making_ || loading);
    if (_bar.indeterminate != loading) _bar.indeterminate = loading;
    _making.hidden = !title;
    BOOL bar = !_making_;
    _shade.hidden = !bar || !_actionsEnabled;
    _save.hidden = _send.hidden = !(bar && _actionsEnabled);
    // The art is a button only where a tap does something: viewer (None), Offer, Failed.
    BOOL tappable = !_making_ && (s == RCImagePreviewNone || s == RCImagePreviewOffer || s == RCImagePreviewFailed || (s == RCImagePreviewShown && _viewerAvailable));
    _artButton.enabled = tappable || s == RCImagePreviewShown;
    _artButton.userInteractionEnabled = tappable;
    _artButton.accessibilityTraits = s == RCImagePreviewShown ? (UIAccessibilityTraitImage | (tappable ? UIAccessibilityTraitButton : 0)) : UIAccessibilityTraitButton;
    if (s == RCImagePreviewShown && tappable) hint = RCL(@"Open image");
    _artButton.accessibilityLabel = !title ? RCL(@"Image") : detail ? [NSString stringWithFormat:@"%@. %@", title, detail] : title;
    _artButton.accessibilityHint = hint;
    self.accessibilityLabel = _making_ ? title : RCL(@"Image");
    [self setNeedsLayout];
}

- (CGFloat)layoutForWidth:(CGFloat)w apply:(BOOL)apply {
    if (apply) {
        _clip.frame = CGRectMake(1, 1, w - 2, 228);
        CGRect art = _clip.bounds;
        _art.frame = art; _artButton.frame = art; _making.frame = art;
        _makingLabel.frame = CGRectMake(0, 92, art.size.width, 17);
        _bar.frame = CGRectMake(floor((art.size.width - 160) / 2), 92 + 17 + 8, 160, 9);
        if (!_making_) { // preview: measured, wrapped and centred above the Сохранить / Отправить strip
            CGFloat lw = art.size.width - 24, top = 6, avail = 230 - 38 - 4 - top;
            CGFloat th = _previewTitle.hidden ? 0 : ceil(RCMeasureText(_previewTitle.text, _previewTitle.font, lw).height);
            CGFloat dh = _previewDetail.hidden ? 0 : ceil(RCMeasureText(_previewDetail.text, _previewDetail.font, lw).height);
            CGFloat bh = _bar.hidden ? 0 : 8 + 9;
            th = MIN(th, avail - bh); dh = MIN(dh, MAX(0, avail - bh - th - 4)); // XL never runs into the strip
            CGFloat total = th + (dh > 0 ? 4 + dh : 0) + bh, y = top + MAX(0, floor((avail - total) / 2));
            _previewTitle.frame = CGRectMake(12, y, lw, th); y += th;
            if (dh > 0) { _previewDetail.frame = CGRectMake(12, y + 4, lw, dh); y += 4 + dh; }
            _previewDetail.hidden = _previewDetail.hidden || dh <= 0;
            if (bh) _bar.frame = CGRectMake(floor((art.size.width - 160) / 2), y + 8, 160, 9);
        }
        _shade.frame = CGRectMake(0, 228 - 37, art.size.width, 37); // bottom 38 pt of the part, under the pills
        CGFloat x = w - 6;
        for (RCButton *b in [NSArray arrayWithObjects:_send, _save, nil]) { CGRect f = b.frame; x -= f.size.width; b.frame = CGRectMake(x, 230 - 6 - 26, f.size.width, 26); x -= 6; }
    }
    return 230;
}
@end
