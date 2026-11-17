#import "RCShareLinkSheet.h"
#import "RCTheme.h"
#import "RCButton.h"
#import "RCHUD.h"
#import "RCLampView.h"
#import "RCPartView.h" // +colorForRole: (body / link text that follows the appearance)
#import <QuartzCore/QuartzCore.h> // headers only (layer messages)

@interface RCShareLinkSheet () { RCButton *_open, *_revoke; BOOL _openAvailable, _revokeAvailable, _preparationRetryAvailable;
    UIScrollView *_scroll;
    UILabel *_intro, *_title, *_meta, *_excerpt, *_switchLabel, *_linkLabel, *_status;
    UIView *_card, *_switchRow, *_linkBox;
    UIImageView *_icon;
    UISwitch *_switch;
    RCButton *_primary, *_secondary;
    UIActivityIndicatorView *_spinner;
    RCLampView *_lamp;
}
@end

@implementation RCShareLinkSheet
@synthesize chatTitle = _chatTitle, chatMeta = _chatMeta, excerpt = _excerptText, includeName = _includeName, showsNameSwitch = _showsNameSwitch,
    state = _state, link = _link, failureText = _failureText, delegate = _delegate;

+ (UINavigationController *)navigationControllerWithSheet:(RCShareLinkSheet *)sheet {
    UINavigationController *nav = [[[UINavigationController alloc] initWithRootViewController:sheet] autorelease];
    [RCTheme styleNavigationBar:nav.navigationBar variant:RCBarVariantJade];
    return nav;
}

- (id)initWithNibName:(NSString *)n bundle:(NSBundle *)b {
    if ((self = [super initWithNibName:n bundle:b])) {
        _showsNameSwitch = YES;
        self.title = RCL(@"Chat link");
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeChanged) name:RCThemeAppearanceDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeChanged) name:RCThemeTextSizeDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [_open release]; [_revoke release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_scroll release]; [_intro release]; [_title release]; [_meta release]; [_excerpt release]; [_switchLabel release]; [_linkLabel release]; [_status release];
    [_card release]; [_switchRow release]; [_linkBox release]; [_icon release]; [_switch release]; [_primary release]; [_secondary release]; [_spinner release]; [_lamp release];
    [_chatTitle release]; [_chatMeta release]; [_excerptText release]; [_link release]; [_failureText release];
    [super dealloc];
}

static UILabel *RCSLLabel(UIFont *f, UIColor *c) { UILabel *l = [[UILabel alloc] initWithFrame:CGRectZero]; l.backgroundColor = [UIColor clearColor]; l.font = f; l.textColor = c; return l; }
static UIView *RCSLBox(void) { UIView *v = [[UIView alloc] initWithFrame:CGRectZero]; v.backgroundColor = [UIColor whiteColor]; v.layer.cornerRadius = 9; v.layer.borderWidth = 1; v.layer.borderColor = RCHex(0xaebbb4).CGColor; return v; }

- (void)loadView {
    _scroll = [[UIScrollView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    _scroll.alwaysBounceVertical = YES;
    self.view = _scroll;
    _intro = RCSLLabel([UIFont systemFontOfSize:13], [RCTheme noteTextColor]);
    [_scroll addSubview:_intro];
    _card = RCSLBox();
    _icon = [[UIImageView alloc] initWithImage:[RCTheme appIconImage:29]];
    _icon.layer.cornerRadius = 6; _icon.clipsToBounds = YES;
    _title = RCSLLabel([UIFont boldSystemFontOfSize:16], [RCTheme inkColor]);
    _meta = RCSLLabel([UIFont systemFontOfSize:12], [RCTheme secondaryInkColor]);
    _excerpt = RCSLLabel([UIFont systemFontOfSize:14], RCHex(0x3f4d47));
    for (UIView *v in [NSArray arrayWithObjects:_icon, _title, _meta, _excerpt, nil]) [_card addSubview:v];
    _card.isAccessibilityElement = YES;
    [_scroll addSubview:_card];
    _switchRow = RCSLBox();
    _switchLabel = RCSLLabel([UIFont boldSystemFontOfSize:16], [RCTheme inkColor]);
    _switchLabel.numberOfLines = 0; RCLabelSetText(_switchLabel, RCL(@"Show my name")); // wraps at XL
    _switch = [[UISwitch alloc] initWithFrame:CGRectZero];
    [_switch addTarget:self action:@selector(switched) forControlEvents:UIControlEventValueChanged];
    _switch.accessibilityLabel = _switchLabel.text;
    [_switchRow addSubview:_switchLabel]; [_switchRow addSubview:_switch];
    [_scroll addSubview:_switchRow];
    _linkBox = RCSLBox();
    _linkBox.backgroundColor = RCHex(0xf3f6f4);
    _linkLabel = RCSLLabel([UIFont systemFontOfSize:15], [RCTheme linkColor]);
    _linkLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    _linkLabel.textAlignment = NSTextAlignmentCenter;
    [_linkBox addSubview:_linkLabel];
    [_scroll addSubview:_linkBox];
    _status = RCSLLabel([UIFont systemFontOfSize:13], [RCTheme noteTextColor]);
    _status.textAlignment = NSTextAlignmentCenter;
    [_scroll addSubview:_status];
    _lamp = [[RCLampView alloc] initWithDiameter:8];
    [_scroll addSubview:_lamp];
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    _spinner.hidesWhenStopped = YES;
    _primary = [[RCButton buttonWithStyle:RCButtonStyleLargeGreen title:RCL(@"Create link")] retain];
    [_primary addTarget:self action:@selector(primaryTapped) forControlEvents:UIControlEventTouchUpInside];
    [_primary addSubview:_spinner];
    _secondary = [[RCButton buttonWithStyle:RCButtonStyleLarge title:RCL(@"Send…")] retain];
    [_secondary addTarget:self action:@selector(secondaryTapped) forControlEvents:UIControlEventTouchUpInside];
    [_scroll addSubview:_primary]; [_scroll addSubview:_secondary];
    _open = [[RCButton buttonWithStyle:RCButtonStyleLarge title:RCL(@"Open snapshot")] retain];
    [_open addTarget:self action:@selector(openTapped) forControlEvents:UIControlEventTouchUpInside];
    _revoke = [[RCButton buttonWithStyle:RCButtonStyleLargeRed title:RCL(@"Delete link")] retain];
    [_revoke addTarget:self action:@selector(revokeTapped) forControlEvents:UIControlEventTouchUpInside];
    [_scroll addSubview:_open]; [_scroll addSubview:_revoke];
    _primary.accessibilityIdentifier = @"chat.share.primary"; _secondary.accessibilityIdentifier = @"chat.share.send";
    _open.accessibilityIdentifier = @"chat.share.open"; _revoke.accessibilityIdentifier = @"chat.share.revoke"; _status.accessibilityIdentifier = @"chat.share.status";
    _status.numberOfLines = 0;
    [self themeChanged];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:RCL(@"Done") style:UIBarButtonItemStyleDone target:self action:@selector(done)] autorelease];
}

- (void)themeChanged {
    if (![self isViewLoaded]) return;
    _scroll.backgroundColor = [RCTheme contentBackgroundColor];
    for (UILabel *l in [NSArray arrayWithObjects:_intro, _status, nil]) { l.textColor = [RCTheme noteTextColor]; l.shadowColor = [RCTheme engravedShadowColor]; l.shadowOffset = [RCTheme engravedShadowOffset]; }
    // Boxes and their text follow the appearance (answer-card palette) and the body text step;
    // at M every font is the size it always had (16/12/14/16/15/13 pt).
    for (UIView *b in [NSArray arrayWithObjects:_card, _switchRow, nil]) { b.backgroundColor = [RCTheme cardColor]; b.layer.borderColor = [RCTheme cardStrokeColor].CGColor; }
    _linkBox.backgroundColor = [RCTheme cardHeldColor]; _linkBox.layer.borderColor = [RCTheme cardStrokeColor].CGColor;
    _title.textColor = _switchLabel.textColor = [RCTheme answerTextColor]; _meta.textColor = [RCTheme answerSecondaryColor];
    _excerpt.textColor = [RCPartView colorForRole:RCPartTextBody]; _linkLabel.textColor = [RCPartView colorForRole:RCPartTextLink];
    CGFloat pt = [RCTheme bodyFont].pointSize;
    _title.font = _switchLabel.font = [UIFont boldSystemFontOfSize:pt]; _meta.font = [UIFont systemFontOfSize:pt - 4]; _excerpt.font = [UIFont systemFontOfSize:pt - 2];
    _linkLabel.font = [UIFont systemFontOfSize:pt - 1]; _intro.font = [UIFont systemFontOfSize:pt - 3];
    _status.font = [UIFont systemFontOfSize:pt - 3]; // the status (preparing, errors) follows the text size: M = 13 pt as before
    [self refresh];
}

- (void)refresh {
    if (![self isViewLoaded]) return;
    RCLabelSetText(_intro, RCL(@"Anyone with the link can read this conversation. Messages added after the link is created are not included."));
    _title.text = _chatTitle.length ? _chatTitle : RCL(@"Conversation");
    _meta.text = _chatMeta;
    RCLabelSetText(_excerpt, _excerptText);
    _excerpt.numberOfLines = 3;
    _card.accessibilityLabel = [NSString stringWithFormat:@"%@. %@. %@", _title.text, _chatMeta ? _chatMeta : @"", _excerptText ? _excerptText : @""];
    _switch.on = _includeName;
    _switchRow.hidden = !_showsNameSwitch;
    _switch.enabled = _state == RCShareLinkIdle || _state == RCShareLinkFailed;
    BOOL retryRead = _state == RCShareLinkPreparationFailed && _preparationRetryAvailable && [_delegate respondsToSelector:@selector(shareLinkSheetRetryPreparation:)];
    _linkBox.hidden = _state != RCShareLinkCreated;
    _linkLabel.text = _link;
    _linkBox.isAccessibilityElement = YES;
    _linkBox.accessibilityLabel = [RCL(@"Link: ") stringByAppendingString:_link ? _link : @""];
    NSString *status = nil;
    _lamp.hidden = YES;
    switch (_state) {
        case RCShareLinkIdle: [_primary setTitle:RCL(@"Create link") forState:UIControlStateNormal]; _primary.enabled = YES; [_spinner stopAnimating]; break;
        case RCShareLinkCreating: [_primary setTitle:RCL(@"Creating link…") forState:UIControlStateNormal]; _primary.enabled = NO; [_spinner startAnimating]; break;
        case RCShareLinkCreated: [_primary setTitle:RCL(@"Copy link") forState:UIControlStateNormal]; _primary.enabled = _link.length > 0; [_spinner stopAnimating];
            status = _includeName ? RCL(@"Your name is visible in the link.") : RCL(@"Your name is not shown."); break;
        case RCShareLinkFailed: [_primary setTitle:RCL(@"Retry") forState:UIControlStateNormal]; _primary.enabled = YES; [_spinner stopAnimating];
            status = _failureText.length ? _failureText : RCL(@"The link could not be created. Nothing was published."); _lamp.hidden = NO; _lamp.state = RCLampError; break;
        case RCShareLinkPreparing: [_primary setTitle:RCL(@"Checking the chat…") forState:UIControlStateNormal]; _primary.enabled = NO; [_spinner startAnimating];
            status = RCL(@"Reading the latest version of the chat. Nothing is published."); _lamp.hidden = NO; _lamp.state = RCLampBusy; break;
        case RCShareLinkPreparationFailed: [_primary setTitle:(retryRead ? RCL(@"Check again") : RCL(@"Create link")) forState:UIControlStateNormal]; _primary.enabled = retryRead; [_spinner stopAnimating];
            status = _failureText.length ? _failureText : RCL(@"Could not check the chat. Nothing was published."); _lamp.hidden = NO; _lamp.state = RCLampError; break;
    }
    _primary.accessibilityHint = _state == RCShareLinkPreparationFailed && retryRead ? RCL(@"Reads the chat again. No link is created") : nil;
    _primary.alpha = 1; // stays readable while creating (the spinner shows progress)
    _secondary.hidden = _state != RCShareLinkCreated;
    _open.hidden = _state != RCShareLinkCreated || !_openAvailable || !_link.length;
    _revoke.hidden = _state != RCShareLinkCreated || !_revokeAvailable || !_link.length;
    _status.textColor = (_state == RCShareLinkFailed || _state == RCShareLinkPreparationFailed) ? [RCTheme errorInkColor] : [RCTheme noteTextColor];
    RCLabelSetText(_status, status);
    _status.hidden = !status.length;
    [self.view setNeedsLayout];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width, bw = w - 18, y = 12;
    CGFloat ih = RCMeasureText(_intro.text, _intro.font, w - 28).height;
    _intro.frame = CGRectMake(14, y, w - 28, ih); y += ih + 12;
    CGFloat eh = MIN(RCMeasureText(_excerpt.text, _excerpt.font, bw - 20).height, 3 * ceil(_excerpt.font.lineHeight));
    CGFloat th = ceil(_title.font.lineHeight), mh = ceil(_meta.font.lineHeight), hh = MAX(29, th + mh); // header: icon or title + meta
    CGFloat ch = 10 + hh + (eh ? 8 + eh : 0) + 10;
    _card.frame = CGRectMake(9, y, bw, ch);
    _icon.frame = CGRectMake(10, 10, 29, 29);
    _title.frame = CGRectMake(47, 9, bw - 57, th);
    _meta.frame = CGRectMake(47, 9 + th - 1, bw - 57, mh);
    _excerpt.frame = CGRectMake(10, 10 + hh + 8, bw - 20, eh);
    y += ch + 12;
    if (!_switchRow.hidden) {
        CGRect sf = _switch.frame; CGFloat lw = bw - 10 - sf.size.width - 16;
        CGFloat lh = RCMeasureText(_switchLabel.text, _switchLabel.font, lw).height, rh = MAX(44, ceil(lh) + 16);
        _switchRow.frame = CGRectMake(9, y, bw, rh);
        sf.origin = CGPointMake(bw - 10 - sf.size.width, round((rh - sf.size.height) / 2)); _switch.frame = sf;
        _switchLabel.frame = CGRectMake(10, round((rh - lh) / 2), lw, ceil(lh));
        y += rh + 14;
    }
    if (!_linkBox.hidden) { _linkBox.frame = CGRectMake(9, y, bw, 40); _linkLabel.frame = CGRectMake(10, 0, bw - 20, 40); y += 40 + 12; }
    _primary.frame = CGRectMake(9, y, bw, 44);
    _spinner.center = CGPointMake(26, 22);
    y += 44 + 10;
    if (!_secondary.hidden) { _secondary.frame = CGRectMake(9, y, bw, 44); y += 44 + 10; }
    if (!_open.hidden) { _open.frame = CGRectMake(9, y, bw, 44); y += 44 + 10; }
    if (!_revoke.hidden) { _revoke.frame = CGRectMake(9, y, bw, 44); y += 44 + 10; }
    if (!_status.hidden) {
        CGFloat sh = RCMeasureText(_status.text, _status.font, w - 48).height;
        _status.frame = CGRectMake(24, y, w - 48, sh);
        _lamp.center = CGPointMake(16, y + 8);
        y += sh + 10;
    }
    _scroll.contentSize = CGSizeMake(w, y + 10);
}

#define RC_SETTER(name, ivar) - (void)name:(NSString *)v { [ivar release]; ivar = [v copy]; [self refresh]; }
RC_SETTER(setChatTitle, _chatTitle)
RC_SETTER(setChatMeta, _chatMeta)
RC_SETTER(setExcerpt, _excerptText)
RC_SETTER(setLink, _link)
RC_SETTER(setFailureText, _failureText)
#undef RC_SETTER
- (void)setIncludeName:(BOOL)v { _includeName = v; [self refresh]; }
- (void)setShowsNameSwitch:(BOOL)v { _showsNameSwitch = v; [self refresh]; }
- (BOOL)openAvailable { return _openAvailable; }
- (void)setOpenAvailable:(BOOL)v { _openAvailable = v; [self refresh]; }
- (BOOL)revokeAvailable { return _revokeAvailable; }
- (void)setRevokeAvailable:(BOOL)v { _revokeAvailable = v; [self refresh]; }
- (BOOL)preparationRetryAvailable { return _preparationRetryAvailable; }
- (void)setPreparationRetryAvailable:(BOOL)v { _preparationRetryAvailable = v; [self refresh]; }
- (void)openTapped { if ([_delegate respondsToSelector:@selector(shareLinkSheet:openLink:)]) [_delegate shareLinkSheet:self openLink:_link]; }
- (void)revokeTapped { if ([_delegate respondsToSelector:@selector(shareLinkSheet:revokeLink:)]) [_delegate shareLinkSheet:self revokeLink:_link]; }
- (void)setState:(RCShareLinkState)s {
    _state = s; [self refresh];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, s == RCShareLinkCreated ? RCL(@"Link created") : s == RCShareLinkFailed ? RCL(@"Could not create the link") :
                                    s == RCShareLinkPreparing ? RCL(@"Checking the chat") : s == RCShareLinkPreparationFailed ? RCL(@"Could not check the chat") : nil);
}

- (void)switched { _includeName = _switch.on; [self refresh]; }
- (void)primaryTapped {
    if (_state == RCShareLinkCreated) {
        if ([_delegate respondsToSelector:@selector(shareLinkSheet:copyLink:)]) { [_delegate shareLinkSheet:self copyLink:_link]; return; }
        [UIPasteboard generalPasteboard].string = _link;
        [RCHUD showText:RCL(@"Link copied") kind:RCHUDDone inView:(self.view.window ? self.view.window : self.view) seconds:0];
        return;
    }
    if (_state == RCShareLinkCreating || _state == RCShareLinkPreparing) return;
    if (_state == RCShareLinkPreparationFailed) { // a read again, never a create
        if (_preparationRetryAvailable && [_delegate respondsToSelector:@selector(shareLinkSheetRetryPreparation:)]) [_delegate shareLinkSheetRetryPreparation:self];
        return;
    }
    [_delegate shareLinkSheet:self createLinkIncludingName:_includeName];
}
- (void)secondaryTapped { if ([_delegate respondsToSelector:@selector(shareLinkSheet:shareLink:)]) [_delegate shareLinkSheet:self shareLink:_link]; }
- (void)done {
    if ([_delegate respondsToSelector:@selector(shareLinkSheetDidFinish:)]) [_delegate shareLinkSheetDidFinish:self];
    else [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}
@end
