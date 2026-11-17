#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class OR6Audio;
@protocol OR6AudioDelegate <NSObject>
/* Always called on the main thread. Read coordinator.snapshot for an immutable value. */
- (void)audioCoordinatorDidChange:(OR6Audio *)coordinator;
@end

/* Foreground, file-backed coordinator. ALL methods, properties and delegate use are
 * main-thread-only. A non-main mutating call fails/does nothing; it never starts
 * audio. No networking, transcription, upload, Send, or automatic resume exists.
 *
 * One pending recording is retained until explicit cancelRecording, including
 * across restart and playback. Copy a finalized recording to the file vault
 * before cancelling it. Capture uses <uuid>.partial.wav; only verified, fsynced
 * PCM files become <uuid>.wav. Never hand a partial to the vault/bridge.
 *
 * snapshot: state (idle/recording/recorded/playing/stopped/error/interrupted),
 * notice (stable internal code), pending (BOOL); optional recordingID,
 * recordingURL (absolute file URL string, finalized only), recording (immutable
 * {bytes,frames,duration,sampleRate,channels,bits,format}), playbackID; an active
 * real player adds playback {isPlaying,currentTime,duration,channels}.
 * Recovery can expose an interrupted finalized recording, but never starts media.
 * Playback requires a canonical file URL below a supplied app-owned directory.
 * Bounds: recording PCM16 LE mono 16000 Hz <=60s, wall watchdog90s; playback
 * same WAV format <=180s; any accepted file <=8MiB. Device behavior is separate
 * from header/ASBD validation and compile tests. Caller must suspend on teardown.
 */
@interface OR6Audio : NSObject <AVAudioRecorderDelegate, AVAudioPlayerDelegate> {
@private
    NSString *_directory;
    NSArray *_playbackDirectories;
    NSString *_state;
    NSString *_notice;
    NSString *_pendingID;
    NSString *_playbackID;
    NSDictionary *_recording;
    AVAudioRecorder *_recorder;
    AVAudioPlayer *_player;
    NSTimer *_watchdog;
    id _timerTarget;
    id<OR6AudioDelegate> _delegate;
    double _startedAt;
    BOOL _sessionActive;
    BOOL _finishing;
}
@property(nonatomic, assign) id<OR6AudioDelegate> delegate;
@property(nonatomic, readonly) NSDictionary *snapshot;
- (id)initWithDirectory:(NSString *)directory allowedPlaybackDirectories:(NSArray *)directories error:(NSError **)error;
- (BOOL)startRecording:(NSString *)identifier error:(NSError **)error;
- (void)stopRecording;
- (void)cancelRecording;
- (BOOL)playFileURL:(NSURL *)url identifier:(NSString *)identifier error:(NSError **)error;
- (void)stopPlayback;
- (void)suspend;
@end

/* Deterministic, generated files and fake audio objects only; no hardware access.
 * Uses a new child inside directory and returns {ok, checks, failures}. */
NSDictionary *OR6AudioSelfTest(NSString *directory);
