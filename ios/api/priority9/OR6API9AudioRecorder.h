#import "OR6API9Provider.h"
#import "../../OR6Audio.h"
// Public AVFoundation only, reuses the accepted OR6Audio lifecycle. Constructing
// this adapter never starts a microphone. Only an explicit dictation.start does.
@interface OR6API9AudioRecorder:NSObject<OR6API9Recorder>{OR6Audio*_audio;NSString*_directory,*_externalID;NSTimer*_limit;}
- (id)initWithDirectory:(NSString*)directory error:(NSError**)error;
@end
