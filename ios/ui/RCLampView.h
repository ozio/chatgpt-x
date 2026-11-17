// RCLampView — "what the app actually observes" status lamp (kit.css .lamp).
// ok = green, busy = amber pulsing (1 s), warn = amber, err = red, info = blue, off = grey.
#import <UIKit/UIKit.h>

typedef enum {
    RCLampOff = 0, RCLampOK, RCLampBusy, RCLampWarn, RCLampError, RCLampInfo
} RCLampState;

@interface RCLampView : UIView
// diameter in points: 9 default, 8 in titles/reasoning, 7 in meta lines and Send.
- (id)initWithDiameter:(CGFloat)diameter;
@property (nonatomic, assign) RCLampState state;
@property (nonatomic, readonly) CGFloat diameter;
+ (NSString *)nameForState:(RCLampState)state;
@end
