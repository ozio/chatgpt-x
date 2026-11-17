#import <Foundation/Foundation.h>
// Public AudioToolbox decoder, bounded to 180 seconds / 16kHz mono PCM16 WAV.
// Input/output are app-created staging files only. No downloaded path crosses Core.
BOOL OR6Selected20DecodeAudio(NSURL *input, NSURL *output, BOOL (^cancelled)(void), NSError **error);
