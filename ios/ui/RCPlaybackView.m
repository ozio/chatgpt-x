#import "RCPlaybackView.h"
#import "RCTheme.h"
#import "RCGlyph.h"
#import "RCProgressView.h"
#import "RCSegmentedControl.h"

static const double kRCRates[4] = { .5, 1, 1.5, 2 };

@interface RCPlaybackView () { UIImageView *_tile; UILabel *_name, *_time, *_note; RCProgressView *_bar; RCButton *_play, *_stop; RCSegmentedControl *_rates; NSString *_title, *_failure; }
@end

@implementation RCPlaybackView
@synthesize state = _state, position = _position, duration = _duration, rate = _rate, rateAvailable = _rateAvailable, busy = _busy, playButton = _play, stopButton = _stop;

+ (NSString *)timeText:(NSTimeInterval)s {
    if (!(s >= 0) || s > 359999) s = 0;
    NSUInteger t = (NSUInteger)floor(s);
    return [NSString stringWithFormat:@"%lu:%02lu", (unsigned long)(t / 60), (unsigned long)(t % 60)];
}
- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.fillTop = 0xffffff; self.fillBottom = 0xf1f5f3; _rate = 1; _rateAvailable = YES;
        _tile = [[UIImageView alloc] initWithFrame:CGRectMake(10, 10, 29, 31)];
        [self addSubview:_tile];
        _name = [[self labelWithRole:RCPartTextTitle font:[UIFont boldSystemFontOfSize:14]] retain];
        _name.lineBreakMode = NSLineBreakByTruncatingMiddle;
        _time = [[self labelWithRole:RCPartTextSecondary font:[UIFont systemFontOfSize:12]] retain];
        _note = [[self labelWithRole:RCPartTextSecondary font:[UIFont systemFontOfSize:12]] retain];
        _note.numberOfLines = 0;
        _bar = [[RCProgressView alloc] initWithFrame:CGRectMake(0, 0, 100, 6)];
        [self addSubview:_bar];
        _play = [[RCButton buttonWithStyle:RCButtonStylePillGo title:RCL(@"Listen")] retain];
        _stop = [[RCButton buttonWithStyle:RCButtonStylePill title:RCL(@"Stop")] retain];
        [_play addTarget:self action:@selector(playTapped) forControlEvents:UIControlEventTouchUpInside];
        [_stop addTarget:self action:@selector(stopTapped) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_play]; [self addSubview:_stop];
        _rates = [[RCSegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:RCL(@"0.5×"), RCL(@"1×"), RCL(@"1.5×"), RCL(@"2×"), nil] style:RCSegmentedLight];
        [_rates addTarget:self action:@selector(rateChanged) forControlEvents:UIControlEventValueChanged];
        [self addSubview:_rates];
        [self refresh];
    }
    return self;
}
- (void)dealloc { [_tile release]; [_name release]; [_time release]; [_note release]; [_bar release]; [_play release]; [_stop release]; [_rates release]; [_title release]; [_failure release]; [super dealloc]; }

- (NSString *)title { return _title; }
- (void)setTitle:(NSString *)t { [_title release]; _title = [t copy]; [self refresh]; }
- (NSString *)failureText { return _failure; }
- (void)setFailureText:(NSString *)t { [_failure release]; _failure = [t copy]; [self refresh]; }
- (void)setState:(RCPlaybackState)s { _state = s; [self refresh]; }
- (void)setPosition:(NSTimeInterval)p { _position = p; [self refresh]; }
- (void)setDuration:(NSTimeInterval)d { _duration = d; [self refresh]; }
- (void)setRate:(double)r { _rate = r; [self refresh]; }
- (void)setRateAvailable:(BOOL)v { _rateAvailable = v; [self refresh]; [self notifyHeightChange]; }
- (void)setBusy:(BOOL)b { _busy = b; [self refresh]; }

- (void)refresh {
    BOOL failed = _state == RCPlaybackFailed, playing = _state == RCPlaybackPlaying;
    _tile.image = [RCGlyph tileNamed:@"speaker" color:(failed ? RCTileGray : RCTileGreen) size:29];
    _name.text = _title.length ? _title : RCL(@"Audio");
    NSString *state = playing ? RCL(@"Playing") : _state == RCPlaybackPaused ? RCL(@"Pause") : _state == RCPlaybackStopped ? RCL(@"Stopped") : failed ? RCL(@"Error") : RCL(@"Ready to play");
    _time.text = [NSString stringWithFormat:@"%@ / %@ · %@", [RCPlaybackView timeText:_position], [RCPlaybackView timeText:_duration], state];
    [_bar setProgress:(_duration > 0 ? MAX(0, MIN(1, _position / _duration)) : 0) animated:NO];
    if (failed) { _play.style = RCButtonStylePillGo; [_play setTitle:RCL(@"Retry") forState:UIControlStateNormal]; }
    else if (playing) { _play.style = RCButtonStylePill; [_play setTitle:RCL(@"Pause") forState:UIControlStateNormal]; }
    else { _play.style = RCButtonStylePillGo; [_play setTitle:(_state == RCPlaybackPaused ? RCL(@"Resume") : RCL(@"Listen")) forState:UIControlStateNormal]; }
    [_play sizeToFit]; [_stop sizeToFit];
    _play.enabled = !_busy; _stop.enabled = !_busy && (playing || _state == RCPlaybackPaused);
    _stop.hidden = failed;
    NSInteger sel = -1; for (NSInteger i = 0; i < 4; i++) if (fabs(kRCRates[i] - _rate) < .01) sel = i;
    _rates.selectedSegmentIndex = sel; _rates.hidden = !_rateAvailable || failed; _rates.userInteractionEnabled = !_busy;
    _note.text = failed ? (_failure.length ? _failure : RCL(@"Could not play.")) : nil; _note.hidden = !failed;
    _note.textColor = failed ? [RCTheme errorInkColor] : _note.textColor;
    _play.accessibilityHint = playing ? nil : RCL(@"Plays the file saved on this iPhone");
    _time.accessibilityLabel = [NSString stringWithFormat:RCL(@"Position %@ of %@"), [RCPlaybackView timeText:_position], [RCPlaybackView timeText:_duration]];
    _bar.isAccessibilityElement = NO;
    [self setNeedsLayout]; [self setNeedsDisplay];
}
- (void)playTapped {
    id d = self.delegate;
    if (_state == RCPlaybackFailed) { if ([d respondsToSelector:@selector(playbackViewDidTapRetry:)]) [d playbackViewDidTapRetry:self]; }
    else if (_state == RCPlaybackPlaying) { if ([d respondsToSelector:@selector(playbackViewDidTapPause:)]) [d playbackViewDidTapPause:self]; }
    else if ([d respondsToSelector:@selector(playbackViewDidTapPlay:)]) [d playbackViewDidTapPlay:self];
}
- (void)stopTapped { id d = self.delegate; if ([d respondsToSelector:@selector(playbackViewDidTapStop:)]) [d playbackViewDidTapStop:self]; }
- (void)rateChanged {
    NSInteger i = _rates.selectedSegmentIndex; if (i < 0 || i > 3) return;
    id d = self.delegate; if ([d respondsToSelector:@selector(playbackView:didChooseRate:)]) [d playbackView:self didChooseRate:kRCRates[i]];
    [self refresh]; // the check follows the caller's reported rate
}
- (CGFloat)layoutForWidth:(CGFloat)w apply:(BOOL)apply {
    CGFloat y = 9;
    if (apply) { _name.frame = CGRectMake(48, y, w - 58, 18); _time.frame = CGRectMake(48, y + 18, w - 58, 15); }
    y = 27 + 15 + 6;
    if (apply) _bar.frame = CGRectMake(48, y, w - 58, 6);
    y += 6 + 8;
    if (!_note.hidden) { CGFloat h = RCMeasureText(_note.text, _note.font, w - 58).height; if (apply) _note.frame = CGRectMake(48, y, w - 58, h); y += h + 6; }
    if (apply) {
        CGFloat x = 48;
        _play.frame = CGRectMake(x, y, MAX(70, _play.frame.size.width), 26); x += _play.frame.size.width + 6;
        _stop.frame = CGRectMake(x, y, MAX(52, _stop.frame.size.width), 26);
    }
    y += 26 + 8;
    if (!_rates.hidden) { if (apply) _rates.frame = CGRectMake(48, y, w - 58, [RCSegmentedControl height]); y += [RCSegmentedControl height] + 9; }
    return y;
}
@end
