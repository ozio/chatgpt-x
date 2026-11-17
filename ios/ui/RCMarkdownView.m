#import "RCMarkdownView.h"
#import "RCMarkdownText.h"
#import "RCTheme.h"
#import "RCTextStackView.h"
#import <QuartzCore/QuartzCore.h> // headers only (layer messages), no QuartzCore link

static NSString *const RCMDLinkAttribute = @"RCMDLink";

static NSURL *RCMDSafeURL(NSString *raw) {
    NSString *t = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!t.length || t.length > 2048) return nil;
    NSURL *u = [NSURL URLWithString:t];
    NSString *scheme = [u.scheme lowercaseString];
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"] && ![scheme isEqualToString:@"mailto"]) return nil;
    if (![scheme isEqualToString:@"mailto"] && !u.host.length) return nil;
    return u;
}

typedef enum { RCMDPara, RCMDHeading2, RCMDHeading3, RCMDList, RCMDQuote, RCMDTable, RCMDCode, RCMDRule } RCMDKind;

#pragma mark - Inline

static NSDictionary *RCMDBase(UIFont *font, UIColor *color, CGFloat lineHeight) {
    NSMutableParagraphStyle *ps = [[[NSMutableParagraphStyle alloc] init] autorelease];
    ps.minimumLineHeight = lineHeight; ps.maximumLineHeight = lineHeight;
    return [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, color, NSForegroundColorAttributeName, ps, NSParagraphStyleAttributeName, nil];
}

// `code`, **bold**, *italic*, [text](url)
static NSRange RCMDClosing(NSString*src,NSString*token,NSUInteger start) {
    for(NSUInteger i=start;i<src.length;i++){
        unichar c=[src characterAtIndex:i];
        if(c=='\\'&&i+1<src.length&&RCMarkdownEscapable([src characterAtIndex:i+1])){i++;continue;}
        if(c=='`'){NSRange e=[src rangeOfString:@"`" options:0 range:NSMakeRange(i+1,src.length-i-1)];if(e.location!=NSNotFound){i=e.location;continue;}}
        if([src rangeOfString:token options:NSAnchoredSearch range:NSMakeRange(i,src.length-i)].location==i)return NSMakeRange(i,token.length);
    }
    return NSMakeRange(NSNotFound,0);
}
static NSAttributedString *RCMDInlineDepth(NSString *src, NSDictionary *base, BOOL forceBold,NSUInteger depth,NSSet *citationURLs) {
    if(depth>8)return [[[NSAttributedString alloc]initWithString:RCMarkdownUnescape(src) attributes:base]autorelease];
    UIFont *font = [base objectForKey:NSFontAttributeName];
    CGFloat size = font.pointSize;
    BOOL dark = [RCTheme isDark];
    NSMutableAttributedString *out = [[[NSMutableAttributedString alloc] init] autorelease];
    NSMutableString *run = [NSMutableString string];
    void (^flush)(void) = ^{
        if (!run.length) return;
        NSMutableDictionary *a = [[base mutableCopy] autorelease];
        if (forceBold) [a setObject:[UIFont boldSystemFontOfSize:size] forKey:NSFontAttributeName];
        [out appendAttributedString:[[[NSAttributedString alloc] initWithString:run attributes:a] autorelease]];
        [run setString:@""];
    };
    NSUInteger i = 0, n = src.length;
    while (i < n) {
        unichar c = [src characterAtIndex:i];
        NSRange rest = NSMakeRange(i + 1, n - i - 1);
        // "\" before ASCII punctuation: the character itself, never a delimiter (\. \, \* \_ \\ \`).
        if (c == '\\' && i + 1 < n && RCMarkdownEscapable([src characterAtIndex:i + 1])) { [run appendFormat:@"%C", [src characterAtIndex:i + 1]]; i += 2; continue; }
        if (c == '`') {
            NSRange e = [src rangeOfString:@"`" options:0 range:rest];
            if (e.location != NSNotFound) {
                flush();
                NSMutableDictionary *a = [[base mutableCopy] autorelease];
                UIFont *mono = [UIFont fontWithName:@"Menlo-Regular" size:size - 3]; if (!mono) mono = [UIFont fontWithName:@"Courier" size:size - 2];
                [a setObject:mono forKey:NSFontAttributeName];
                [a setObject:RCHex(dark ? 0x26352e : 0xedf2ef) forKey:NSBackgroundColorAttributeName];
                NSString *code = [src substringWithRange:NSMakeRange(i + 1, e.location - i - 1)];
                [out appendAttributedString:[[[NSAttributedString alloc] initWithString:code attributes:a] autorelease]];
                i = e.location + 1; continue;
            }
        }
        if (c == '*' && i + 1 < n && [src characterAtIndex:i + 1] == '*') {
            NSRange e = RCMDClosing(src, @"**", i+2);
            if (e.location != NSNotFound && e.location > i + 2) {
                flush();
                NSMutableDictionary *a = [[base mutableCopy] autorelease];
                [a setObject:[UIFont boldSystemFontOfSize:size] forKey:NSFontAttributeName];
                [out appendAttributedString:RCMDInlineDepth([src substringWithRange:NSMakeRange(i+2,e.location-i-2)],a,NO,depth+1,citationURLs)];
                i = e.location + 2; continue;
            }
        }
        if (c == '*' && !(i + 1 < n && [src characterAtIndex:i + 1] == ' ')) {
            NSRange e = RCMDClosing(src, @"*", i+1);
            if (e.location != NSNotFound && e.location > i + 1) {
                flush();
                NSMutableDictionary *a = [[base mutableCopy] autorelease];
                [a setObject:[UIFont italicSystemFontOfSize:size] forKey:NSFontAttributeName];
                [out appendAttributedString:RCMDInlineDepth([src substringWithRange:NSMakeRange(i+1,e.location-i-1)],a,NO,depth+1,citationURLs)];
                i = e.location + 1; continue;
            }
        }
        if (c == '[') {
            NSRange mid = RCMDClosing(src, @"](", i+1);
            NSRange end = mid.location == NSNotFound ? mid : RCMarkdownFindUnescaped(src, @")", NSMakeRange(mid.location + 2, n - mid.location - 2));
            if (mid.location != NSNotFound && end.location != NSNotFound) {
                flush();
                NSMutableDictionary *a = [[base mutableCopy] autorelease];
                [a setObject:[UIFont boldSystemFontOfSize:size] forKey:NSFontAttributeName];
                [a setObject:(dark ? RCHex(0x7fdcab) : RCHex(0x1c7449)) forKey:NSForegroundColorAttributeName];
                [a setObject:[NSNumber numberWithInt:NSUnderlineStyleSingle] forKey:NSUnderlineStyleAttributeName];
                NSURL *url = RCMDSafeURL(RCMarkdownUnescape([src substringWithRange:NSMakeRange(mid.location + 2, end.location - mid.location - 2)]));
                if (url) [a setObject:url forKey:RCMDLinkAttribute];
                [out appendAttributedString:RCMDInlineDepth([src substringWithRange:NSMakeRange(i+1,mid.location-i-1)],a,NO,depth+1,citationURLs)];
                i = end.location + 1; continue;
            }
        }
        [run appendFormat:@"%C", c];
        i++;
    }
    flush();
    return out;
}

static NSAttributedString *RCMDInline(NSString*src,NSDictionary*base,BOOL forceBold,NSSet *citationURLs){return RCMDInlineDepth(src,base,forceBold,0,citationURLs);}

static CGFloat RCMDTextHeight(NSAttributedString *s, CGFloat width) {
    if (!s.length) return 0;
    return ceil([s boundingRectWithSize:CGSizeMake(width, 100000) options:NSStringDrawingUsesLineFragmentOrigin context:nil].size.height);
}

static NSArray *RCMDLinksIn(NSAttributedString *s) {
    NSMutableArray *links = [NSMutableArray array];
    if (!s.length) return links;
    [s enumerateAttribute:RCMDLinkAttribute inRange:NSMakeRange(0, s.length) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
        if (!value) return;
        NSString *title = [[s.string substringWithRange:range] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [links addObject:[NSDictionary dictionaryWithObjectsAndKeys:value, @"url", (title.length ? title : [value absoluteString]), @"title", nil]];
    }];
    return links;
}

static UILabel *RCMDLabel(NSAttributedString *s) {
    UILabel *l = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
    l.backgroundColor = [UIColor clearColor];
    l.numberOfLines = 0;
    l.lineBreakMode = NSLineBreakByWordWrapping;
    l.attributedText = s;
    if (RCMDLinksIn(s).count) {
        l.accessibilityTraits = UIAccessibilityTraitStaticText | UIAccessibilityTraitLink;
        l.accessibilityHint = RCL(@"Opens the link");
    }
    return l;
}

#pragma mark - Block views

@interface RCMDBlock : UIView { @public RCMDKind _kind; CGFloat _top, _bottom; NSMutableArray *_labels; NSArray *_rows; BOOL _ordered; }
- (CGFloat)heightForWidth:(CGFloat)w;
@end

@implementation RCMDBlock
- (id)initWithKind:(RCMDKind)k { if ((self = [super initWithFrame:CGRectZero])) { _kind = k; _labels = [[NSMutableArray alloc] init]; self.backgroundColor = [UIColor clearColor]; self.contentMode = UIViewContentModeRedraw; } return self; }
- (void)dealloc { [_labels release]; [_rows release]; [super dealloc]; }

- (CGFloat)layout:(CGFloat)w apply:(BOOL)apply {
    if (_kind == RCMDRule) return 9;
    if (_kind == RCMDCode) {
        RCCodeBlockView *cb = [_labels lastObject];
        if (apply) cb.frame = CGRectMake(0, 0, w, self.bounds.size.height);
        return [cb heightForWidth:w];
    }
    if (_kind == RCMDList) {
        // Markers "10." and longer get a wider column instead of wrapping the dot.
        CGFloat mw = 18;
        for (NSUInteger i = 0; i + 1 < _labels.count; i += 2) mw = MAX(mw, ceil([[[_labels objectAtIndex:i] attributedText] size].width) + 1);
        CGFloat y = 0;
        for (NSUInteger i = 0; i + 1 < _labels.count; i += 2) {
            UILabel *mark = [_labels objectAtIndex:i], *text = [_labels objectAtIndex:i + 1];
            CGFloat h = RCMDTextHeight(text.attributedText, w - mw - 4);
            if (apply) { mark.frame = CGRectMake(0, y, mw, RCMDTextHeight(mark.attributedText, mw)); text.frame = CGRectMake(mw + 4, y, w - mw - 4, h); }
            y += h + (i + 2 < _labels.count ? 4 : 0);
        }
        return y;
    }
    if (_kind == RCMDQuote) {
        UILabel *l = [_labels lastObject];
        CGFloat h = RCMDTextHeight(l.attributedText, w - 13);
        if (apply) l.frame = CGRectMake(13, 2, w - 13, h);
        return h + 4;
    }
    if (_kind == RCMDTable) {
        NSUInteger cols = 0;
        for (NSArray *r in _rows) cols = MAX(cols, r.count);
        if (!cols) return 0;
        CGFloat cw = floor(w / cols), y = 0;
        NSUInteger li = 0;
        for (NSArray *r in _rows) {
            CGFloat rh = 0;
            for (NSUInteger c = 0; c < r.count; c++) rh = MAX(rh, RCMDTextHeight([[_labels objectAtIndex:li + c] attributedText], cw - 12));
            rh += 8;
            for (NSUInteger c = 0; c < r.count; c++) if (apply) [[_labels objectAtIndex:li + c] setFrame:CGRectMake(c * cw + 6, y + 4, cw - 12, rh - 8)];
            li += r.count;
            y += rh;
        }
        return y + 1;
    }
    UILabel *l = [_labels lastObject];
    CGFloat h = RCMDTextHeight(l.attributedText, w);
    if (apply) l.frame = CGRectMake(0, 0, w, h);
    return h;
}
- (CGFloat)heightForWidth:(CGFloat)w { return [self layout:w apply:NO]; }
- (void)layoutSubviews { [super layoutSubviews]; [self layout:self.bounds.size.width apply:YES]; }

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    BOOL dark = [RCTheme isDark];
    if (_kind == RCMDRule) {
        CGContextSetFillColorWithColor(ctx, [RCTheme cardStrokeColor].CGColor);
        CGContextFillRect(ctx, CGRectMake(0, 4, self.bounds.size.width, 1 / UIScreen.mainScreen.scale));
    } else if (_kind == RCMDQuote) {
        CGContextSetFillColorWithColor(ctx, RCHex(0x8fcdb0).CGColor);
        CGContextFillRect(ctx, CGRectMake(0, 0, 3, self.bounds.size.height));
    } else if (_kind == RCMDTable) {
        NSUInteger cols = 0;
        for (NSArray *r in _rows) cols = MAX(cols, r.count);
        if (!cols) return;
        CGFloat w = self.bounds.size.width, cw = floor(w / cols);
        UIColor *line = RCHex(dark ? 0x2c3d35 : 0xcfd9d4);
        // header row gradient (th)
        UILabel *first = _labels.count ? [_labels objectAtIndex:0] : nil;
        CGFloat hh = first ? CGRectGetMaxY(first.frame) + 4 : 0;
        RCDrawVerticalGradient(ctx, CGRectMake(0, 0, cw * cols, hh), [NSArray arrayWithObjects:RCHex(dark ? 0x2a3a33 : 0xf6f9f7), RCHex(dark ? 0x22302a : 0xe4ebe7), nil], nil);
        CGContextSetStrokeColorWithColor(ctx, line.CGColor);
        CGContextSetLineWidth(ctx, 1);
        CGContextStrokeRect(ctx, CGRectMake(.5, .5, cw * cols - 1, self.bounds.size.height - 1));
        for (NSUInteger c = 1; c < cols; c++) { CGContextMoveToPoint(ctx, c * cw + .5, 0); CGContextAddLineToPoint(ctx, c * cw + .5, self.bounds.size.height); }
        NSUInteger li = 0;
        for (NSUInteger r = 0; r + 1 < _rows.count; r++) {
            li += [[_rows objectAtIndex:r] count];
            UILabel *l = [_labels objectAtIndex:li];
            CGFloat y = l.frame.origin.y - 4 + .5;
            CGContextMoveToPoint(ctx, 0, y); CGContextAddLineToPoint(ctx, cw * cols, y);
        }
        CGContextStrokePath(ctx);
    }
}
@end

#pragma mark - View

@interface RCMarkdownView () <UIActionSheetDelegate> { NSString *_markdown; NSMutableArray *_blocks; UILabel *_cursorLabel; NSAttributedString *_cursorBase; NSArray *_choice; UITapGestureRecognizer *_tap; BOOL _dying; }
@end

@implementation RCMarkdownView
@synthesize citationURLs = _citationURLs;
@synthesize copyCodeEnabled = _copyCodeEnabled, showsCursor = _showsCursor, cursorOn = _cursorOn, codeDelegate = _codeDelegate, linkDelegate = _linkDelegate;

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        _blocks = [[NSMutableArray alloc] init];
        _cursorOn = YES;
        _tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
        _tap.enabled = NO;
        [self addGestureRecognizer:_tap];
    }
    return self;
}
- (void)dealloc { [_citationURLs release]; _dying = YES; [_tap removeTarget:self action:NULL]; [self removeGestureRecognizer:_tap]; [_tap release]; [_markdown release]; [_blocks release]; [_cursorBase release]; [_choice release]; [super dealloc]; }

#pragma mark - Links

- (NSArray *)links {
    NSMutableArray *all = [NSMutableArray array];
    for (RCMDBlock *b in _blocks) for (id l in b->_labels) if ([l isKindOfClass:[UILabel class]]) [all addObjectsFromArray:RCMDLinksIn([(UILabel *)l attributedText])];
    return all;
}

- (void)setLinkDelegate:(id<RCMarkdownViewDelegate>)d { _linkDelegate = d; [self updateTap]; }
- (void)updateTap { _tap.enabled = _linkDelegate != nil && self.links.count > 0; }

- (void)selectLink:(NSDictionary *)link {
    if ([_linkDelegate respondsToSelector:@selector(markdownView:didSelectLinkURL:title:)]) [_linkDelegate markdownView:self didSelectLinkURL:[link objectForKey:@"url"] title:[link objectForKey:@"title"]];
}

- (void)tapped:(UITapGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateEnded) return;
    // The label under the finger (paragraph, list item, quote, heading or table cell).
    UILabel *hit = nil;
    for (RCMDBlock *b in _blocks) {
        if (!CGRectContainsPoint(b.frame, [g locationInView:self])) continue;
        CGPoint p = [g locationInView:b];
        CGFloat best = 10000;
        for (id l in b->_labels) {
            if (![l isKindOfClass:[UILabel class]]) continue;
            CGRect f = CGRectInset([(UILabel *)l frame], -4, -6);
            if (CGRectContainsPoint(f, p)) { hit = l; break; }
            CGFloat d = fabs(CGRectGetMidY(f) - p.y);
            if (d < best && p.y >= f.origin.y - 6 && p.y <= CGRectGetMaxY(f) + 6) { best = d; hit = l; }
        }
        break;
    }
    NSArray *links = hit ? RCMDLinksIn(hit.attributedText) : nil;
    if (!links.count) return;
    if (links.count == 1) { [self selectLink:[links objectAtIndex:0]]; return; }
    [_choice release]; _choice = [links copy];
    UIActionSheet *sheet = [[[UIActionSheet alloc] initWithTitle:RCL(@"Links") delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil] autorelease];
    for (NSDictionary *l in links) [sheet addButtonWithTitle:[l objectForKey:@"title"]];
    sheet.cancelButtonIndex = [sheet addButtonWithTitle:RCL(@"Cancel")];
    [sheet showInView:self.window ? self.window : self];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
    if (index != sheet.cancelButtonIndex && index >= 0 && (NSUInteger)index < _choice.count) [self selectLink:[_choice objectAtIndex:(NSUInteger)index]];
    [_choice release]; _choice = nil;
}

- (NSString *)markdown { return _markdown; }
- (void)setMarkdown:(NSString *)md { if ([md isEqualToString:_markdown]) return; [_markdown release]; _markdown = [md copy]; [self rebuild]; }
- (void)setCopyCodeEnabled:(BOOL)v { if (v == _copyCodeEnabled) return; _copyCodeEnabled = v; [self rebuild]; }
- (void)setShowsCursor:(BOOL)v { if (v == _showsCursor) return; _showsCursor = v; [self rebuild]; }
- (void)setCursorOn:(BOOL)v { _cursorOn = v; [self applyCursor]; }

+ (NSString *)plainTextFromMarkdown:(NSString *)md { return RCMarkdownPlainText(md); }

+ (NSString *)readableTextFromMarkdown:(NSString *)md { return RCMarkdownReadableText(md); }

- (RCMDBlock *)addBlock:(RCMDKind)kind top:(CGFloat)top bottom:(CGFloat)bottom {
    RCMDBlock *b = [[[RCMDBlock alloc] initWithKind:kind] autorelease];
    b->_top = top; b->_bottom = bottom;
    [self addSubview:b];
    [_blocks addObject:b];
    return b;
}

- (void)setCitationURLs:(NSSet *)urls { if ([_citationURLs isEqual:urls]) return; [_citationURLs release]; _citationURLs = [urls copy]; [self rebuild]; }
- (void)reload { [self rebuild]; }

- (void)rebuild {
    for (UIView *v in _blocks) [v removeFromSuperview];
    [_blocks removeAllObjects];
    _cursorLabel = nil;
    [_cursorBase release]; _cursorBase = nil;
    UIFont *body = [RCTheme bodyFont];
    CGFloat size = body.pointSize, lh = [RCTheme bodyLineHeight:YES];
    BOOL dark = [RCTheme isDark];
    UIColor *ink = [RCTheme answerTextColor];
    NSDictionary *base = RCMDBase(body, ink, lh);
    NSArray *lines = [RCDisplayText(_markdown ? _markdown : @"") componentsSeparatedByString:@"\n"];
    NSMutableArray *para = [NSMutableArray array];
    UILabel *lastText = nil;
    NSInteger codeBlocks = 0; // blockIndex: position among non-empty fences (content.copyCode)
    NSRegularExpression *listRe = [NSRegularExpression regularExpressionWithPattern:@"^(- |\\d+\\. )" options:0 error:NULL];
    NSUInteger i = 0;
    while (YES) {
        NSString *l = i < lines.count ? [lines objectAtIndex:i] : nil;
        BOOL isList = l && [listRe firstMatchInString:l options:0 range:NSMakeRange(0, l.length)] != nil;
        BOOL special = !l || RCMarkdownIsRule(l) || [l hasPrefix:@"```"] || [l hasPrefix:@"## "] || [l hasPrefix:@"### "] || [l hasPrefix:@"> "] || isList || [l hasPrefix:@"|"] || ![l stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].length;
        if (special && para.count) {
            // A huge paragraph is cut into several labels (GPU texture limit on iPhone 5).
            NSArray *chunks = [RCTextStackView chunksOfAttributedString:RCMDInline([para componentsJoinedByString:@" "], base, NO, _citationURLs)];
            for (NSUInteger c = 0; c < chunks.count; c++) {
                RCMDBlock *b = [self addBlock:RCMDPara top:0 bottom:(c + 1 == chunks.count ? 9 : 0)];
                UILabel *lab = RCMDLabel([chunks objectAtIndex:c]);
                [b addSubview:lab]; [b->_labels addObject:lab]; lastText = lab;
            }
            [para removeAllObjects];
        }
        if (!l) break;
        if (RCMarkdownIsRule(l)) { [self addBlock:RCMDRule top:2 bottom:9]; lastText = nil; i++; continue; }
        if ([l hasPrefix:@"```"]) {
            NSString *lang = [[l substringFromIndex:3] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            NSMutableArray *code = [NSMutableArray array];
            i++;
            while (i < lines.count && ![[lines objectAtIndex:i] hasPrefix:@"```"]) { [code addObject:[lines objectAtIndex:i]]; i++; }
            i++;
            RCCodeBlockView *cb = [[[RCCodeBlockView alloc] initWithCode:[code componentsJoinedByString:@"\n"] language:lang] autorelease];
            cb.copyEnabled = _copyCodeEnabled;
            cb.delegate = _codeDelegate;
            cb.blockIndex = cb.code.length ? codeBlocks++ : -1;
            RCMDBlock *b = [self addBlock:RCMDCode top:2 bottom:10];
            [b addSubview:cb]; [b->_labels addObject:cb];
            lastText = nil;
            continue;
        }
        if ([l hasPrefix:@"## "] || [l hasPrefix:@"### "]) {
            BOOL h2 = [l hasPrefix:@"## "];
            NSDictionary *hb = h2 ? RCMDBase([UIFont boldSystemFontOfSize:size + 3], ink, lh + 2) : RCMDBase([UIFont boldSystemFontOfSize:size], (dark ? ink : RCHex(0x2c3d35)), lh - 1);
            RCMDBlock *b = [self addBlock:(h2 ? RCMDHeading2 : RCMDHeading3) top:(h2 ? 4 : 12) bottom:(h2 ? 8 : 6)];
            UILabel *lab = RCMDLabel(RCMDInline([l substringFromIndex:(h2 ? 3 : 4)], hb, YES, _citationURLs));
            [b addSubview:lab]; [b->_labels addObject:lab]; lastText = lab;
            i++; continue;
        }
        if ([l hasPrefix:@"> "]) {
            NSMutableDictionary *qb = [[RCMDBase([UIFont italicSystemFontOfSize:size], (dark ? RCHex(0xb8c9c0) : RCHex(0x3f5249)), lh) mutableCopy] autorelease];
            RCMDBlock *b = [self addBlock:RCMDQuote top:0 bottom:9];
            UILabel *lab = RCMDLabel(RCMDInline([l substringFromIndex:2], qb, NO, _citationURLs));
            [b addSubview:lab]; [b->_labels addObject:lab]; lastText = lab;
            i++; continue;
        }
        if (isList) {
            BOOL ordered = isdigit([l characterAtIndex:0]);
            RCMDBlock *b = [self addBlock:RCMDList top:0 bottom:9];
            NSUInteger num = 1;
            while (i < lines.count) {
                NSString *li = [lines objectAtIndex:i];
                NSTextCheckingResult *m = [listRe firstMatchInString:li options:0 range:NSMakeRange(0, li.length)];
                if (!m) break;
                NSString *mark = ordered ? [NSString stringWithFormat:@"%lu.", (unsigned long)num++] : @"•";
                UILabel *ml = RCMDLabel([[[NSAttributedString alloc] initWithString:mark attributes:base] autorelease]);
                ml.textAlignment = NSTextAlignmentRight;
                UILabel *tl = RCMDLabel(RCMDInline([li substringFromIndex:m.range.length], base, NO, _citationURLs));
                [b addSubview:ml]; [b addSubview:tl]; [b->_labels addObject:ml]; [b->_labels addObject:tl];
                lastText = tl;
                i++;
            }
            continue;
        }
        if ([l hasPrefix:@"|"]) {
            NSMutableArray *rows = [NSMutableArray array];
            NSRegularExpression *sep = [NSRegularExpression regularExpressionWithPattern:@"^\\|[-| :]+\\|$" options:0 error:NULL];
            while (i < lines.count && [[lines objectAtIndex:i] hasPrefix:@"|"]) {
                NSString *r = [[lines objectAtIndex:i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                i++;
                if ([sep firstMatchInString:r options:0 range:NSMakeRange(0, r.length)]) continue;
                NSString *inner = [r substringWithRange:NSMakeRange(1, MAX((NSInteger)r.length - 2, 0))];
                NSMutableArray *cells = [NSMutableArray array];
                for (NSString *c in [inner componentsSeparatedByString:@"|"]) [cells addObject:[c stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
                [rows addObject:cells];
            }
            RCMDBlock *b = [self addBlock:RCMDTable top:2 bottom:10];
            b->_rows = [rows retain];
            NSDictionary *tb = RCMDBase([UIFont systemFontOfSize:13], ink, 17);
            NSUInteger r = 0;
            for (NSArray *row in rows) {
                for (NSString *c in row) {
                    UILabel *lab = RCMDLabel(RCMDInline(c, tb, r == 0, _citationURLs));
                    [b addSubview:lab]; [b->_labels addObject:lab];
                }
                r++;
            }
            lastText = nil;
            continue;
        }
        if (![l stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].length) { i++; continue; }
        [para addObject:l];
        i++;
    }
    if (_showsCursor) {
        if (!lastText || ![[_blocks lastObject] isKindOfClass:[RCMDBlock class]] || ((RCMDBlock *)[_blocks lastObject])->_kind == RCMDCode || ((RCMDBlock *)[_blocks lastObject])->_kind == RCMDTable) {
            RCMDBlock *b = [self addBlock:RCMDPara top:0 bottom:0];
            UILabel *lab = RCMDLabel([[[NSAttributedString alloc] initWithString:@"" attributes:base] autorelease]);
            [b addSubview:lab]; [b->_labels addObject:lab]; lastText = lab;
        }
        _cursorLabel = lastText;
        _cursorBase = [lastText.attributedText retain];
        [self applyCursor];
    }
    [self updateTap];
    [self setNeedsLayout];
}

- (void)applyCursor {
    if (!_cursorLabel || !_cursorBase) return;
    NSMutableAttributedString *s = [[_cursorBase mutableCopy] autorelease];
    NSDictionary *a = RCMDBase([RCTheme bodyFont], (_cursorOn ? RCHex(0x2fae6c) : [UIColor clearColor]), [RCTheme bodyLineHeight:YES]);
    [s appendAttributedString:[[[NSAttributedString alloc] initWithString:@"▌" attributes:a] autorelease]];
    _cursorLabel.attributedText = s;
}

- (CGFloat)layout:(CGFloat)w apply:(BOOL)apply {
    CGFloat y = 0;
    for (NSUInteger i = 0; i < _blocks.count; i++) {
        RCMDBlock *b = [_blocks objectAtIndex:i];
        BOOL last = i + 1 == _blocks.count;
        if (b->_kind == RCMDCode) {
            RCCodeBlockView *cb = [b->_labels lastObject];
            CGFloat h = [cb heightForWidth:w + 8];
            y += b->_top;
            if (apply) { b.frame = CGRectMake(-4, y, w + 8, h); cb.frame = b.bounds; [b setNeedsLayout]; }
            y += h + (last ? 0 : b->_bottom);
            continue;
        }
        if (i > 0 || b->_kind == RCMDHeading3) y += (i == 0 ? 0 : b->_top);
        CGFloat h = [b heightForWidth:w];
        if (apply) { b.frame = CGRectMake(0, y, w, h); [b setNeedsLayout]; [b setNeedsDisplay]; }
        y += h + (last ? 0 : b->_bottom);
    }
    return y;
}
- (CGFloat)heightForWidth:(CGFloat)width { return [self layout:width apply:NO]; }
- (CGSize)sizeThatFits:(CGSize)size { return CGSizeMake(size.width, [self heightForWidth:size.width]); }
- (void)layoutSubviews { [super layoutSubviews]; if (_dying) return; [self layout:self.bounds.size.width apply:YES]; }
@end
