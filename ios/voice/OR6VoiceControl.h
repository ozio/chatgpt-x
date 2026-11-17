#import <Foundation/Foundation.h>

/* Serial-worker state and local control intent, not a claim of service admission.
 * No credentials, network, microphone or automatic resumption in this object. */
@interface OR6VoiceControl : NSObject
- (NSString *)start;
- (NSString *)resumeSession:(NSString *)oldSession serverContext:(NSDictionary *)context;
- (BOOL)transportConnected:(NSString *)session;
- (BOOL)channelOpened:(NSString *)session;
- (NSString *)interrupt:(NSString *)session;
- (BOOL)mute:(NSString *)session microphone:(BOOL)microphone output:(BOOL)output;
- (BOOL)end:(NSString *)session;
- (BOOL)fail:(NSString *)session;
- (BOOL)acceptServerEvent:(NSData *)event session:(NSString *)session;
- (NSDictionary *)state:(NSString *)session;
@end
