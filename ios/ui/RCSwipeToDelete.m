#import "RCSwipeToDelete.h"
#import "RCTheme.h"
#import <QuartzCore/QuartzCore.h> // headers only (layer messages)

@implementation RCDeleteButton
+ (UIImage *)backgroundPressed:(BOOL)pressed {
    return [RCTheme imageForKey:(pressed ? @"delete-btn-p" : @"delete-btn") size:CGSizeMake(16, 30) capInsets:UIEdgeInsetsMake(7, 7, 7, 7) drawing:^(CGContextRef ctx, CGRect b) {
        CGRect r = CGRectInset(b, .5, .5);
        CGPathRef p = RCCreateRoundedRectPath(r, 5);
        CGContextSaveGState(ctx);
        CGContextAddPath(ctx, p); CGContextClip(ctx);
        NSArray *locs = [NSArray arrayWithObjects:[NSNumber numberWithFloat:0], [NSNumber numberWithFloat:.5], [NSNumber numberWithFloat:.51], [NSNumber numberWithFloat:1], nil];
        if (pressed) RCDrawVerticalGradient(ctx, b, [NSArray arrayWithObjects:RCHex(0x8e1105), RCHex(0xb81506), nil], nil);
        else RCDrawVerticalGradient(ctx, b, [NSArray arrayWithObjects:RCHex(0xef8378), RCHex(0xd4301f), RCHex(0xc51c0b), RCHex(0xb81506), nil], locs);
        CGContextSetFillColorWithColor(ctx, RCHexA(0xffffff, pressed ? 0 : .3).CGColor);
        CGContextFillRect(ctx, CGRectMake(0, 1, b.size.width, 1));
        CGContextRestoreGState(ctx);
        CGContextAddPath(ctx, p);
        CGContextSetStrokeColorWithColor(ctx, RCHex(0x7d0f05).CGColor);
        CGContextStrokePath(ctx);
        CGPathRelease(p);
    }];
}
+ (id)deleteButtonWithTitle:(NSString *)title {
    RCDeleteButton *b = [self buttonWithType:UIButtonTypeCustom];
    [b setBackgroundImage:[self backgroundPressed:NO] forState:UIControlStateNormal];
    [b setBackgroundImage:[self backgroundPressed:YES] forState:UIControlStateHighlighted];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [b setTitleShadowColor:RCHexA(0, .4) forState:UIControlStateNormal];
    b.titleLabel.shadowOffset = CGSizeMake(0, -1);
    b.contentEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 10);
    [b setTitle:title forState:UIControlStateNormal];
    CGSize s = [title sizeWithFont:b.titleLabel.font];
    b.frame = CGRectMake(0, 0, ceil(s.width) + 20, 30);
    b.accessibilityLabel = title;
    return b;
}
@end

@interface RCSwipeToDelete () {
    UITableView *_table;
    UISwipeGestureRecognizer *_swipe;
    UITapGestureRecognizer *_tap;
    RCDeleteButton *_button;
    NSIndexPath *_revealed;
}
@end

@implementation RCSwipeToDelete
@synthesize title = _title, delegate = _delegate, revealedIndexPath = _revealed;

- (id)initWithTableView:(UITableView *)tableView {
    if ((self = [super init])) {
        _table = tableView;
        _title = [RCL(@"Delete") copy];
        _swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swiped:)];
        _swipe.direction = UISwipeGestureRecognizerDirectionLeft | UISwipeGestureRecognizerDirectionRight;
        _swipe.delegate = self;
        [_table addGestureRecognizer:_swipe];
        _tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
        _tap.delegate = self;
        _tap.enabled = NO; // only while a button is shown: then the tap is swallowed (no row selection)
        [_table addGestureRecognizer:_tap];
        [_table.panGestureRecognizer addTarget:self action:@selector(scrolled:)];
    }
    return self;
}

- (void)detach {
    [self hideAnimated:NO];
    [_table removeGestureRecognizer:_swipe];
    [_table removeGestureRecognizer:_tap];
    [_table.panGestureRecognizer removeTarget:self action:@selector(scrolled:)];
    _table = nil;
}

- (void)dealloc {
    [self detach];
    [_swipe release]; [_tap release]; [_button release]; [_revealed release]; [_title release];
    [super dealloc];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldReceiveTouch:(UITouch *)touch {
    if (g == _tap) return !(_button && [touch.view isDescendantOfView:_button]);
    return YES;
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other { return g == _swipe; }

- (void)swiped:(UISwipeGestureRecognizer *)g {
    if (!_table || g.state != UIGestureRecognizerStateEnded) return;
    NSIndexPath *ip = [_table indexPathForRowAtPoint:[g locationInView:_table]];
    if (!ip) { [self hideAnimated:YES]; return; }
    if (_revealed && [_revealed isEqual:ip]) { [self hideAnimated:YES]; return; }
    if ([_delegate respondsToSelector:@selector(swipeToDelete:canDeleteRowAtIndexPath:)] && ![_delegate swipeToDelete:self canDeleteRowAtIndexPath:ip]) { [self hideAnimated:YES]; return; }
    [self hideAnimated:NO];
    [self revealAtIndexPath:ip];
}

- (void)revealAtIndexPath:(NSIndexPath *)ip {
    CGRect row = [_table rectForRowAtIndexPath:ip];
    UITableViewCell *cell = [_table cellForRowAtIndexPath:ip];
    if (cell) row = cell.frame;
    _revealed = [ip retain];
    _button = [[RCDeleteButton deleteButtonWithTitle:_title] retain];
    [_button addTarget:self action:@selector(deleteTapped) forControlEvents:UIControlEventTouchUpInside];
    // 10 pt from the row's right edge; grouped iOS 6 rows are themselves inset by 10 pt.
    CGFloat right = _table.style == UITableViewStyleGrouped ? 20 : 10;
    CGRect f = _button.frame;
    f.origin = CGPointMake(CGRectGetMaxX(row) - right - f.size.width, round(CGRectGetMidY(row) - 15));
    // grow from the right edge (scale 0 → 1 with the anchor at the right)
    _button.layer.anchorPoint = CGPointMake(1, .5);
    _button.frame = f;
    _button.transform = CGAffineTransformMakeScale(.01, 1);
    [_table addSubview:_button];
    _tap.enabled = YES;
    [UIView animateWithDuration:.2 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{ _button.transform = CGAffineTransformIdentity; } completion:nil];
    cell.accessibilityHint = [NSString stringWithFormat:RCL(@"Shows the “%@” button"), _title];
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, _button);
}

- (void)hideAnimated:(BOOL)animated {
    _tap.enabled = NO;
    if (!_button) return;
    RCDeleteButton *b = _button;
    _button = nil;
    [_revealed release]; _revealed = nil;
    if (!animated) { [b removeFromSuperview]; [b release]; return; }
    [UIView animateWithDuration:.2 animations:^{ b.transform = CGAffineTransformMakeScale(.01, 1); } completion:^(BOOL finished) { [b removeFromSuperview]; [b release]; }];
}

- (void)tapped:(UITapGestureRecognizer *)g { [self hideAnimated:YES]; }
- (void)scrolled:(UIPanGestureRecognizer *)g { if (g.state == UIGestureRecognizerStateBegan) [self hideAnimated:YES]; }

- (void)deleteTapped {
    NSIndexPath *ip = [[_revealed retain] autorelease];
    [self hideAnimated:NO];
    if (ip) [_delegate swipeToDelete:self deleteRowAtIndexPath:ip];
}
@end
