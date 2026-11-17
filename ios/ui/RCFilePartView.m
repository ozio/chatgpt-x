#import "RCFilePartView.h"
#import "RCTheme.h"
#import "RCGlyph.h"
#import "RCProgressView.h"
#import "RCFileIcon.h"

@interface RCFilePartView () { UIImageView *_tile; UILabel *_name, *_sub; RCButton *_action; RCProgressView *_bar; NSString *_detail; }
@end

@implementation RCFilePartView
@synthesize thumbnail = _thumbnail, state = _state, progress = _progress, actionButton = _action;

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.fillTop = 0xffffff; self.fillBottom = 0xf1f5f3;
        _tile = [[UIImageView alloc] initWithFrame:CGRectMake(8, 6, 34, 40)];
        [self addSubview:_tile];
        _name = [[self labelWithRole:RCPartTextTitle font:[UIFont boldSystemFontOfSize:14]] retain];
        _name.lineBreakMode = NSLineBreakByTruncatingMiddle;
        _sub = [[self labelWithRole:RCPartTextSecondary font:[UIFont systemFontOfSize:12]] retain];
        _action = [[RCButton buttonWithStyle:RCButtonStylePillGo title:RCL(@"Download")] retain];
        [self addSubview:_action];
        _bar = [[RCProgressView alloc] initWithFrame:CGRectMake(0, 0, 100, 9)];
        [self addSubview:_bar];
        [self refresh];
    }
    return self;
}
- (void)dealloc { [_tile release]; [_name release]; [_sub release]; [_action release]; [_bar release]; [_detail release]; [_thumbnail release]; [super dealloc]; }

- (void)setThumbnail:(UIImage*)image {if(_thumbnail==image)return;[_thumbnail release];_thumbnail=[image retain];[self refresh];}
- (NSString *)fileName { return _name.text; }
- (void)setFileName:(NSString *)n { _name.text = n; [self refresh]; }
- (NSString *)detail { return _detail; }
- (void)setDetail:(NSString *)d { [_detail release]; _detail = [d copy]; [self refresh]; }
- (void)setState:(RCFileState)s { _state = s; [self refresh]; }
- (void)setProgress:(CGFloat)p { _progress = p; [_bar setProgress:p animated:YES]; }

- (void)refresh {
    BOOL expired = _state == RCFileExpired || _state == RCFileUnavailable;
    self.dashed = expired;
    self.plainFill = expired; if (expired) self.fillTop = 0xf7f7f5; else { self.fillTop = 0xffffff; self.fillBottom = 0xf1f5f3; }
    // The file itself: its kind sheet (or a Polaroid for a picture), faded when it is gone.
    _tile.image = [RCFileIcon iconForFileName:_name.text glyph:nil photo:_thumbnail size:CGSizeMake(34, 40) failed:NO];
    _tile.alpha = expired ? .5 : 1;
    switch (_state) {
        case RCFileReady: _action.style = RCButtonStylePillGo; [_action setTitle:RCL(@"Download") forState:UIControlStateNormal]; break;
        case RCFileSaved: _action.style = RCButtonStylePill; [_action setTitle:RCL(@"Open in…") forState:UIControlStateNormal]; break;
        case RCFileExpired: _action.style = RCButtonStylePill; [_action setTitle:RCL(@"Download") forState:UIControlStateNormal]; break;
        default: break;
    }
    [_action sizeToFit];
    _action.hidden = _state == RCFileDownloading || _state == RCFileUnavailable;
    _bar.hidden = _state != RCFileDownloading;
    NSString *sub = _detail;
    if (_state == RCFileSaved && _detail) sub = [NSString stringWithFormat:RCL(@"Saved · %@"), _detail];
    if (_state == RCFileExpired) sub = RCL(@"Expired — download the file again");
    if (_state == RCFileUnavailable) sub = RCL(@"Unavailable");
    _sub.text = sub;
    self.isAccessibilityElement = NO;
    [self setNeedsLayout];
    [self setNeedsDisplay];
}

- (CGFloat)layoutForWidth:(CGFloat)w apply:(BOOL)apply {
    CGFloat right = (_state == RCFileUnavailable) ? 10 : 84;
    if (apply) {
        _name.frame = CGRectMake(48, 9, w - 48 - right, 18);
        _sub.frame = CGRectMake(48, 27, w - 48 - right, 15);
        CGRect f = _action.frame;
        _action.frame = CGRectMake(w - 10 - f.size.width, 13, f.size.width, 26);
        _bar.frame = CGRectMake(48, 27 + 15 + 5, w - 48 - 84, 9);
    }
    return _bar.hidden ? 52 : 27 + 15 + 5 + 9 + 9;
}
@end
