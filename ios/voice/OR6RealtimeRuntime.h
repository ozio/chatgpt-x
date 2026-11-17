#import <Foundation/Foundation.h>
// All peer operations stay on one serial worker. Devices and callbacks on main.
@interface OR6RealtimeRuntime:NSObject
- (void)offer:(void(^)(NSString*,NSError*))reply;
- (void)connect:(NSString*)answer event:(void(^)(NSDictionary*))event ready:(void(^)(void))ready failure:(void(^)(NSString*))failure;
- (void)setMicrophoneMuted:(BOOL)mic outputMuted:(BOOL)output;
- (void)send:(NSDictionary*)event;
- (void)flushOutput;
- (void)stop;
- (BOOL)isQuiescent;
- (NSDictionary*)diagnostics;
@end
