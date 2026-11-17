#import <Foundation/Foundation.h>
#include <stdint.h>
/* Public iOS6 AudioUnit adapter. Constructing it never activates audio.
 * Start/stop and mute changes: main. PCM input/output: the serial voice worker.
 * startCapture is the explicit microphone action; there is no auto-resume.
 * Stop may overlap worker unwinding. Quiesce the worker before restarting or
 * releasing this object; retain it while a worker holds the PCM interface. */
@interface OR6VoiceAudio:NSObject
- (BOOL)startCapture:(NSError**)error;
- (void)stop;
- (void)setMicrophoneMuted:(BOOL)microphone outputMuted:(BOOL)output;
- (NSUInteger)readMicrophone:(int16_t*)samples frames:(NSUInteger)frames;
- (BOOL)enqueueOutput:(const int16_t*)samples frames:(NSUInteger)frames;
- (void)flushOutput;
- (BOOL)isActive;
- (NSDictionary*)diagnostics;
@end
