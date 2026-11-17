#import "RCReportViewController.h"
#import "RCTheme.h"
#import "RCGlyph.h"
#import "RCButton.h"
#import "RCMarkdownView.h"
#import <QuartzCore/QuartzCore.h> // headers only (layer messages)

@interface RCReportViewController () {
    UIScrollView *_scroll;
    UIImageView *_tile;
    UILabel *_titleLabel, *_metaLabel, *_sourcesHead;
    UIView *_card, *_sourcesCard;
    RCMarkdownView *_body;
    NSMutableArray *_rows;
    RCButton *_pdf, *_share;
}
@end

@implementation RCReportViewController
@synthesize reportTitle = _reportTitle, meta = _meta, markdown = _markdown, sources = _sources, savePDFAvailable = _savePDFAvailable, shareAvailable = _shareAvailable, delegate = _delegate, scrollView = _scroll;

- (id)initWithTitle:(NSString *)title markdown:(NSString *)markdown {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _reportTitle = [title copy];
        _markdown = [markdown copy];
        _rows = [[NSMutableArray alloc] init];
        _savePDFAvailable = _shareAvailable = YES;
        self.title = RCL(@"Report");
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(themeChanged) name:RCThemeAppearanceDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(themeChanged) name:RCThemeTextSizeDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_scroll release]; [_tile release]; [_titleLabel release]; [_metaLabel release]; [_sourcesHead release]; [_card release]; [_sourcesCard release];
    [_body release]; [_rows release]; [_pdf release]; [_share release];
    [_reportTitle release]; [_meta release]; [_markdown release]; [_sources release];
    [super dealloc];
}

static UILabel *RCRepLabel(UIFont *f) { UILabel *l = [[UILabel alloc] initWithFrame:CGRectZero]; l.backgroundColor = [UIColor clearColor]; l.font = f; return l; }

- (void)loadView {
    _scroll = [[UIScrollView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    _scroll.alwaysBounceVertical = YES;
    self.view = _scroll;
    _card = [[UIView alloc] initWithFrame:CGRectZero];
    _card.layer.cornerRadius = 9; _card.layer.borderWidth = 1;
    [_scroll addSubview:_card];
    _tile = [[UIImageView alloc] initWithImage:[RCGlyph tileNamed:@"research" color:RCTileOrange size:40]];
    [_card addSubview:_tile];
    _titleLabel = RCRepLabel([UIFont boldSystemFontOfSize:19]);
    _titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    _metaLabel = RCRepLabel([UIFont systemFontOfSize:13]);
    [_card addSubview:_titleLabel]; [_card addSubview:_metaLabel];
    _body = [[RCMarkdownView alloc] initWithFrame:CGRectZero];
    [_card addSubview:_body];
    _sourcesHead = RCRepLabel([UIFont boldSystemFontOfSize:16]);
    _sourcesHead.accessibilityTraits = UIAccessibilityTraitHeader;
    [_scroll addSubview:_sourcesHead];
    _sourcesCard = [[UIView alloc] initWithFrame:CGRectZero];
    _sourcesCard.layer.cornerRadius = 9; _sourcesCard.layer.borderWidth = 1;
    [_scroll addSubview:_sourcesCard];
    _pdf = [[RCButton buttonWithStyle:RCButtonStylePillGo title:RCL(@"Save PDF")] retain];
    [_pdf addTarget:self action:@selector(pdfTapped) forControlEvents:UIControlEventTouchUpInside];
    _share = [[RCButton buttonWithStyle:RCButtonStylePill title:RCL(@"Share")] retain];
    [_share addTarget:self action:@selector(shareTapped) forControlEvents:UIControlEventTouchUpInside];
    [_scroll addSubview:_pdf]; [_scroll addSubview:_share];
    [self themeChanged];
}

- (void)themeChanged {
    if (![self isViewLoaded]) return;
    _scroll.backgroundColor = [RCTheme contentBackgroundColor];
    for (UIView *c in [NSArray arrayWithObjects:_card, _sourcesCard, nil]) { c.backgroundColor = [RCTheme cardColor]; c.layer.borderColor = [RCTheme cardStrokeColor].CGColor; }
    _titleLabel.textColor = [RCTheme answerTextColor];
    _metaLabel.textColor = [RCTheme answerSecondaryColor];
    _sourcesHead.textColor = [RCTheme engravedTextColor];
    _sourcesHead.shadowColor = [RCTheme engravedShadowColor]; _sourcesHead.shadowOffset = [RCTheme engravedShadowOffset];
    [_body reload];
    [self refresh];
}

- (void)refresh {
    if (![self isViewLoaded]) return;
    RCLabelSetText(_titleLabel, RCDisplayText(_reportTitle));
    RCLabelSetText(_metaLabel, _meta);
    if (![_body.markdown isEqualToString:_markdown]) _body.markdown = _markdown;
    for (UIView *r in _rows) [r removeFromSuperview];
    [_rows removeAllObjects];
    for (NSUInteger i = 0; i < _sources.count; i++) {
        RCSourceRowView *r = [[[RCSourceRowView alloc] initWithSource:[_sources objectAtIndex:i] number:i + 1] autorelease];
        [r addTarget:self action:@selector(sourceTapped:) forControlEvents:UIControlEventTouchUpInside];
        r.tag = (NSInteger)i;
        [_sourcesCard addSubview:r];
        [_rows addObject:r];
    }
    _sourcesHead.text = _sources.count ? RCSourcesCountTitle(_sources.count) : nil;
    _sourcesHead.hidden = _sourcesCard.hidden = !_sources.count;
    _pdf.hidden = !_savePDFAvailable;
    _share.hidden = !_shareAvailable;
    [self.view setNeedsLayout];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width, cw = w - 18, y = 10;
    CGFloat inner = cw - 24;
    CGFloat th = RCMeasureText(_titleLabel.text, _titleLabel.font, inner - 50).height;
    CGFloat mh = RCMeasureText(_metaLabel.text, _metaLabel.font, inner - 50).height;
    _tile.frame = CGRectMake(12, 12, 40, 40);
    _titleLabel.frame = CGRectMake(62, 12, inner - 50, th);
    _metaLabel.frame = CGRectMake(62, 12 + th + 2, inner - 50, mh);
    CGFloat top = MAX(12 + 40, 12 + th + 2 + mh) + 12;
    CGFloat bh = [_body heightForWidth:inner];
    _body.frame = CGRectMake(12, top, inner, bh);
    _card.frame = CGRectMake(9, y, cw, top + bh + 12);
    y += _card.frame.size.height + 12;
    CGFloat px = 9;
    for (RCButton *b in [NSArray arrayWithObjects:_pdf, _share, nil]) { if (b.hidden) continue; CGRect f = b.frame; f.origin = CGPointMake(px, y); b.frame = f; px += f.size.width + 8; }
    if (!_pdf.hidden || !_share.hidden) y += 26 + 14;
    if (!_sourcesHead.hidden) {
        _sourcesHead.frame = CGRectMake(20, y, w - 40, 22); y += 28;
        CGFloat ry = 6;
        for (RCSourceRowView *r in _rows) { CGFloat rh = [r heightForWidth:inner]; r.frame = CGRectMake(12, ry, inner, rh); ry += rh + 2; }
        _sourcesCard.frame = CGRectMake(9, y, cw, ry + 4);
        y += ry + 4 + 12;
    }
    _scroll.contentSize = CGSizeMake(w, y + 10);
}

#define RC_SETTER(name, ivar) - (void)name:(NSString *)v { [ivar release]; ivar = [v copy]; [self refresh]; }
RC_SETTER(setReportTitle, _reportTitle)
RC_SETTER(setMeta, _meta)
RC_SETTER(setMarkdown, _markdown)
#undef RC_SETTER
- (void)setSources:(NSArray *)s { [_sources release]; _sources = [s copy]; [self refresh]; }
- (void)setSavePDFAvailable:(BOOL)v { _savePDFAvailable = v; [self refresh]; }
- (void)setShareAvailable:(BOOL)v { _shareAvailable = v; [self refresh]; }

- (void)sourceTapped:(RCSourceRowView *)r { if ([_delegate respondsToSelector:@selector(report:didSelectSource:)]) [_delegate report:self didSelectSource:r.source]; }
- (void)pdfTapped { if ([_delegate respondsToSelector:@selector(reportDidTapSavePDF:)]) [_delegate reportDidTapSavePDF:self]; }
- (void)shareTapped { if ([_delegate respondsToSelector:@selector(reportDidTapShare:)]) [_delegate reportDidTapShare:self]; }
@end
