#import "RCActivitySheet.h"
#import "RCTheme.h"
#import <QuartzCore/QuartzCore.h> // headers only (layer messages), no QuartzCore link

@implementation RCActivityItem
@synthesize title = _title, glyph = _glyph, tile = _tile, on = _on;
+ (id)itemWithTitle:(NSString *)title glyph:(NSString *)glyph tile:(RCTileColor)tile {
    RCActivityItem *i = [[[self alloc] init] autorelease];
    i.title = title; i.glyph = glyph; i.tile = tile;
    return i;
}
- (void)dealloc { [_title release]; [_glyph release]; [super dealloc]; }
@end

@interface RCActivityPanel : UIView
@end
@implementation RCActivityPanel
- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    CGContextSetFillColorWithColor(ctx, RCHexA(0x1e2228, .88).CGColor);
    CGContextFillRect(ctx, b);
    CGFloat h = b.size.height;
    NSArray *c = [NSArray arrayWithObjects:RCHexA(0x969baa, .55), RCHexA(0x464b5a, .45), RCHexA(0x1e2028, .2), RCHexA(0, 0), nil];
    NSArray *l = [NSArray arrayWithObjects:[NSNumber numberWithFloat:0], [NSNumber numberWithFloat:3 / h], [NSNumber numberWithFloat:40 / h], [NSNumber numberWithFloat:1], nil];
    RCDrawVerticalGradient(ctx, b, c, l);
    CGContextSetFillColorWithColor(ctx, RCHexA(0, .8).CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, b.size.width, 1));
    CGContextSetFillColorWithColor(ctx, RCHexA(0xffffff, .35).CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 1, b.size.width, 1));
}
@end

@interface RCActivitySheet () {
    UIView *_dim;
    RCActivityPanel *_panel;
    UILabel *_title;
    UIButton *_cancel;
    NSArray *_items;
    NSMutableArray *_cells;
    NSString *_cancelTitle;
    BOOL _dismissing;
}
@end

@implementation RCActivitySheet
@synthesize delegate = _delegate, items = _items;

+ (UIImage *)cancelImage:(BOOL)pressed {
    return [RCTheme imageForKey:(pressed ? @"sheet-cancel-p" : @"sheet-cancel") size:CGSizeMake(24, 44) capInsets:UIEdgeInsetsMake(20, 11, 20, 11) drawing:^(CGContextRef ctx, CGRect r) {
        CGRect b = CGRectInset(r, .5, .5);
        CGPathRef p = RCCreateRoundedRectPath(b, 9);
        CGContextSaveGState(ctx); CGContextAddPath(ctx, p); CGContextClip(ctx);
        if (pressed) RCDrawVerticalGradient(ctx, r, [NSArray arrayWithObjects:RCHex(0x2f8bf1), RCHex(0x0d5ad9), nil], nil);
        else {
            NSArray *l = [NSArray arrayWithObjects:[NSNumber numberWithFloat:0], [NSNumber numberWithFloat:.5], [NSNumber numberWithFloat:.51], [NSNumber numberWithFloat:1], nil];
            RCDrawVerticalGradient(ctx, r, [NSArray arrayWithObjects:RCHex(0x7d818b), RCHex(0x3d4049), RCHex(0x2b2d34), RCHex(0x33363e), nil], l);
            CGContextSetFillColorWithColor(ctx, RCHexA(0xffffff, .35).CGColor); CGContextFillRect(ctx, CGRectMake(0, 1, r.size.width, 1));
        }
        CGContextRestoreGState(ctx);
        CGContextAddPath(ctx, p); CGContextSetStrokeColorWithColor(ctx, [UIColor blackColor].CGColor); CGContextSetLineWidth(ctx, 1); CGContextStrokePath(ctx);
        CGPathRelease(p);
    }];
}

+ (UIImage *)ringImage {
    return [RCTheme imageForKey:@"actgrid-ring" size:CGSizeMake(71, 71) capInsets:UIEdgeInsetsZero drawing:^(CGContextRef ctx, CGRect r) {
        CGRect t = CGRectMake(7, 7, 57, 57);
        CGContextSaveGState(ctx);
        CGContextSetShadowWithColor(ctx, CGSizeZero, 10, RCHexA(0x78ffaa, .9).CGColor);
        CGPathRef p = RCCreateRoundedRectPath(CGRectInset(t, -1, -1), 11);
        CGContextAddPath(ctx, p); CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor); CGContextSetLineWidth(ctx, 2); CGContextStrokePath(ctx);
        CGPathRelease(p);
        CGContextRestoreGState(ctx);
        (void)r;
    }];
}

- (id)initWithTitle:(NSString *)title items:(NSArray *)items {
    if ((self = [super initWithFrame:CGRectMake(0, 0, 320, 480)])) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _items = [items copy];
        _cells = [[NSMutableArray alloc] init];
        _cancelTitle = [RCL(@"Cancel") copy];
        _dim = [[UIView alloc] initWithFrame:self.bounds];
        _dim.backgroundColor = RCHexA(0, .45);
        _dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [_dim addGestureRecognizer:[[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cancel)] autorelease]];
        [self addSubview:_dim];
        _panel = [[RCActivityPanel alloc] initWithFrame:CGRectZero];
        _panel.contentMode = UIViewContentModeRedraw;
        [self addSubview:_panel];
        if (title.length) {
            _title = [[UILabel alloc] initWithFrame:CGRectZero];
            _title.backgroundColor = [UIColor clearColor];
            _title.font = [UIFont systemFontOfSize:13];
            _title.textColor = [UIColor colorWithWhite:1 alpha:.8];
            _title.shadowColor = [UIColor blackColor]; _title.shadowOffset = CGSizeMake(0, -1);
            _title.textAlignment = NSTextAlignmentCenter;
            _title.text = title;
            [_panel addSubview:_title];
        }
        NSUInteger i = 0;
        for (RCActivityItem *it in _items) {
            UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
            b.tag = i++;
            [b addTarget:self action:@selector(tapItem:) forControlEvents:UIControlEventTouchUpInside];
            b.accessibilityLabel = it.title;
            if (it.on) { UIImageView *ring = [[[UIImageView alloc] initWithImage:[RCActivitySheet ringImage]] autorelease]; ring.frame = CGRectMake(1.5, -7, 71, 71); [b addSubview:ring]; }
            UIImageView *tile = [[[UIImageView alloc] initWithImage:[RCGlyph tileNamed:it.glyph color:it.tile size:57]] autorelease];
            tile.frame = CGRectMake(8.5, 0, 57, 59);
            tile.tag = 100;
            [b addSubview:tile];
            UILabel *l = [[[UILabel alloc] initWithFrame:CGRectMake(0, 62, 74, 26)] autorelease];
            l.backgroundColor = [UIColor clearColor];
            l.font = [UIFont boldSystemFontOfSize:11];
            l.textColor = [UIColor whiteColor];
            l.shadowColor = [UIColor blackColor]; l.shadowOffset = CGSizeMake(0, -1);
            l.textAlignment = NSTextAlignmentCenter;
            l.numberOfLines = 2;
            l.text = it.title;
            [l sizeToFit];
            l.frame = CGRectMake(0, 62, 74, MIN(26, l.frame.size.height));
            [b addSubview:l];
            [b addTarget:self action:@selector(itemDown:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
            [b addTarget:self action:@selector(itemUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchDragExit | UIControlEventTouchCancel];
            [_panel addSubview:b];
            [_cells addObject:b];
        }
        _cancel = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        [_cancel setBackgroundImage:[RCActivitySheet cancelImage:NO] forState:UIControlStateNormal];
        [_cancel setBackgroundImage:[RCActivitySheet cancelImage:YES] forState:UIControlStateHighlighted];
        _cancel.titleLabel.font = [UIFont boldSystemFontOfSize:18];
        _cancel.titleLabel.shadowOffset = CGSizeMake(0, -1);
        [_cancel setTitleShadowColor:[UIColor blackColor] forState:UIControlStateNormal];
        [_cancel setTitle:_cancelTitle forState:UIControlStateNormal];
        [_cancel addTarget:self action:@selector(cancel) forControlEvents:UIControlEventTouchUpInside];
        [_panel addSubview:_cancel];
    }
    return self;
}

- (void)dealloc {
    [_dim release]; [_panel release]; [_title release]; [_cancel release];
    [_items release]; [_cells release]; [_cancelTitle release];
    [super dealloc];
}

- (NSString *)cancelTitle { return _cancelTitle; }
- (void)setCancelTitle:(NSString *)t { [_cancelTitle release]; _cancelTitle = [t copy]; [_cancel setTitle:t forState:UIControlStateNormal]; }

- (CGFloat)panelHeightForWidth:(CGFloat)width {
    NSUInteger perRow = MAX(1, (NSUInteger)((width - 20) / 74));
    NSUInteger rows = (_items.count + perRow - 1) / perRow;
    CGFloat y = _title ? 12 + 16 + 10 : 16;
    y += rows * (62 + 26 + 12);
    return y + 4 + 44 + 16;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.bounds.size.width, ph = [self panelHeightForWidth:w];
    if (!_dismissing) _panel.frame = CGRectMake(0, self.bounds.size.height - ph, w, ph);
    CGFloat y = 16;
    if (_title) { _title.frame = CGRectMake(10, 12, w - 20, 16); y = 12 + 16 + 10; }
    NSUInteger perRow = MAX(1, (NSUInteger)((w - 20) / 74));
    for (NSUInteger i = 0; i < _cells.count; i++) {
        NSUInteger row = i / perRow, col = i % perRow;
        NSUInteger inRow = MIN(perRow, _cells.count - row * perRow);
        CGFloat x0 = floor((w - inRow * 74) / 2);
        [[_cells objectAtIndex:i] setFrame:CGRectMake(x0 + col * 74, y + row * 100, 74, 88)];
    }
    NSUInteger rows = (_cells.count + perRow - 1) / perRow;
    _cancel.frame = CGRectMake(20, y + rows * 100 + 4, w - 40, 44);
}

- (void)showInView:(UIView *)view {
    self.frame = view.bounds;
    [view addSubview:self];
    [self layoutIfNeeded];
    CGRect end = _panel.frame, start = end;
    start.origin.y = self.bounds.size.height;
    _panel.frame = start;
    _dim.alpha = 0;
    [UIView animateWithDuration:.32 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{ _panel.frame = end; _dim.alpha = 1; } completion:nil];
}

- (void)dismissThen:(void (^)(void))then {
    if (_dismissing) return;
    _dismissing = YES;
    [self retain];
    CGRect end = _panel.frame;
    end.origin.y = self.bounds.size.height;
    void (^after)(void) = [[then copy] autorelease];
    [UIView animateWithDuration:.32 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{ _panel.frame = end; _dim.alpha = 0; } completion:^(BOOL finished) {
        [self removeFromSuperview];
        if (after) after();
        [self release];
    }];
}
- (void)dismiss { [self dismissThen:nil]; }
- (void)cancel {
    [self dismissThen:^{ if ([_delegate respondsToSelector:@selector(activitySheetDidCancel:)]) [_delegate activitySheetDidCancel:self]; }];
}
- (void)tapItem:(UIButton *)b {
    NSUInteger idx = (NSUInteger)b.tag;
    [self dismissThen:^{ if ([_delegate respondsToSelector:@selector(activitySheet:didSelectItemAtIndex:)]) [_delegate activitySheet:self didSelectItemAtIndex:idx]; }];
}
- (void)itemDown:(UIButton *)b { [b viewWithTag:100].alpha = .7; }
- (void)itemUp:(UIButton *)b { [b viewWithTag:100].alpha = 1; }
@end
