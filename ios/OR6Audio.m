#import "OR6Audio.h"
#import <AudioToolbox/AudioToolbox.h>
#import <TargetConditionals.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif
#import <sys/stat.h>
#import <sys/statvfs.h>
#import <fcntl.h>
#import <unistd.h>
#import <errno.h>
#import <math.h>
#import <mach/mach_time.h>

static const unsigned long long OR6AudioMaxBytes=8ULL*1024*1024;
static NSString *const OR6AudioDomain=@"OR6Audio";
static BOOL OR6AudioFail(NSError **error, NSString *code) {
    if(error) *error=[NSError errorWithDomain:OR6AudioDomain code:1 userInfo:[NSDictionary dictionaryWithObject:code forKey:NSLocalizedDescriptionKey]];
    return NO;
}
static BOOL OR6AudioID(NSString *value) {
    if(![value isKindOfClass:[NSString class]] || value.length!=36) return NO;
    for(NSUInteger i=0;i<36;i++) {unichar c=[value characterAtIndex:i];BOOL dash=i==8||i==13||i==18||i==23;if(dash?c!='-':!((c>='0'&&c<='9')||(c>='a'&&c<='f')))return NO;}
    return YES;
}
static double OR6AudioNow(void) {mach_timebase_info_data_t t;mach_timebase_info(&t);return (double)mach_absolute_time()*(double)t.numer/(double)t.denom/1e9;}
static BOOL OR6AudioWrite(int fd,const void *data,size_t length) {
    const unsigned char *p=data;while(length) {ssize_t n=write(fd,p,length);if(n<0&&errno==EINTR)continue;if(n<=0)return NO;p+=n;length-=(size_t)n;}return YES;
}
static BOOL OR6AudioRead(int fd,void *data,size_t length,off_t offset) {
    unsigned char *p=data;while(length) {ssize_t n=pread(fd,p,length,offset);if(n<0&&errno==EINTR)continue;if(n<=0)return NO;p+=n;offset+=n;length-=(size_t)n;}return YES;
}
static uint16_t OR6AudioU16(const unsigned char *p) {return (uint16_t)(p[0]|p[1]<<8);}
static uint32_t OR6AudioU32(const unsigned char *p) {return (uint32_t)p[0]|(uint32_t)p[1]<<8|(uint32_t)p[2]<<16|(uint32_t)p[3]<<24;}
static void OR6AudioPut32(unsigned char *p,uint32_t n) {p[0]=n;p[1]=n>>8;p[2]=n>>16;p[3]=n>>24;}
static BOOL OR6AudioSyncDirectory(NSString *directory) {int fd=open(directory.fileSystemRepresentation,O_RDONLY|O_NOFOLLOW);if(fd<0)return NO;BOOL ok=fsync(fd)==0;if(close(fd)!=0)ok=NO;return ok;}

/* Configured roots are trusted app-owned paths; canonicalize their ancestors
 * (iOS /var is a system symlink). Descendants never follow a symlink or hardlink. */
static NSString *OR6AudioRoot(NSString *path,BOOL create,NSError **error) {
    if(![path isKindOfClass:[NSString class]]||![path isAbsolutePath]||[path rangeOfString:@"\0"].location!=NSNotFound)return OR6AudioFail(error,@"audio_directory"),nil;
    NSString *root=[[path stringByStandardizingPath] stringByResolvingSymlinksInPath];
    if([root isEqual:@"/"])return OR6AudioFail(error,@"audio_directory"),nil;
    struct stat st;
    if(lstat(root.fileSystemRepresentation,&st)!=0) {
        if(errno!=ENOENT||!create)return OR6AudioFail(error,@"audio_directory_missing"),nil;
        NSString *parent=root.stringByDeletingLastPathComponent;
        if(stat(parent.fileSystemRepresentation,&st)!=0||!S_ISDIR(st.st_mode)||mkdir(root.fileSystemRepresentation,0700)!=0)return OR6AudioFail(error,@"audio_directory_create"),nil;
        if(!OR6AudioSyncDirectory(parent))return OR6AudioFail(error,@"audio_directory_sync"),nil;
    } else if(!S_ISDIR(st.st_mode)) return OR6AudioFail(error,@"audio_directory_type"),nil;
    return root;
}
static BOOL OR6AudioOwned(NSString *path,NSString *root,struct stat *out) {
    if(![path isKindOfClass:[NSString class]]||![path isAbsolutePath]||[path rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location!=NSNotFound||![[path stringByStandardizingPath] isEqual:path]||![path hasPrefix:[root stringByAppendingString:@"/"]])return NO;
    NSString *relative=[path substringFromIndex:root.length+1];NSString *cursor=root;struct stat st;memset(&st,0,sizeof(st));
    NSArray *parts=[relative pathComponents];if(!parts.count)return NO;
    for(NSUInteger i=0;i<parts.count;i++) {cursor=[cursor stringByAppendingPathComponent:[parts objectAtIndex:i]];if(lstat(cursor.fileSystemRepresentation,&st)!=0||S_ISLNK(st.st_mode))return NO;if(i+1<parts.count&&!S_ISDIR(st.st_mode))return NO;}
    if(!S_ISREG(st.st_mode)||st.st_nlink!=1||st.st_size<0)return NO;if(out)*out=st;return YES;
}
static BOOL OR6AudioSame(struct stat a,struct stat b) {return a.st_dev==b.st_dev&&a.st_ino==b.st_ino&&a.st_size==b.st_size&&a.st_mtimespec.tv_sec==b.st_mtimespec.tv_sec&&a.st_mtimespec.tv_nsec==b.st_mtimespec.tv_nsec&&a.st_ctimespec.tv_sec==b.st_ctimespec.tv_sec&&a.st_ctimespec.tv_nsec==b.st_ctimespec.tv_nsec&&a.st_nlink==1&&b.st_nlink==1;}

/* Inspect bounded RIFF chunks, then independently query AudioFile ASBD/duration.
 * Repair is ONLY for the journal's own interrupted partial, and ONLY zero size
 * placeholders. Arbitrary/truncated declared data is never silently repaired. */
static NSDictionary *OR6AudioInspect(NSString *path,NSString *root,double maximum,BOOL repair,NSError **error) {
    struct stat before,after;int fd=-1;NSString *failure=@"audio_file_ownership";NSDictionary *result=nil;
    if(!OR6AudioOwned(path,root,&before))goto done;
    if(before.st_size<44||(unsigned long long)before.st_size>OR6AudioMaxBytes){failure=@"audio_file_size";goto done;}
    fd=open(path.fileSystemRepresentation,(repair?O_RDWR:O_RDONLY)|O_NOFOLLOW);if(fd<0){failure=@"audio_file_open";goto done;}
    if(fstat(fd,&after)!=0||!OR6AudioSame(before,after))goto done;
    unsigned char header[12];if(!OR6AudioRead(fd,header,12,0)||memcmp(header,"RIFF",4)||memcmp(header+8,"WAVE",4)){failure=@"audio_wav_header";goto done;}
    uint32_t riff=OR6AudioU32(header+4);BOOL fixRIFF=repair&&riff==0;
    if(!fixRIFF&&(unsigned long long)riff+8!=(unsigned long long)before.st_size){failure=@"audio_wav_length";goto done;}
    BOOL fmt=NO,data=NO,fixData=NO;uint32_t payload=0;off_t dataLengthOffset=0,offset=12;NSUInteger chunks=0;
    while(offset<before.st_size) {
        unsigned char chunk[8];if(++chunks>128||before.st_size-offset<8||!OR6AudioRead(fd,chunk,8,offset)){failure=@"audio_wav_chunks";goto done;}
        uint32_t size=OR6AudioU32(chunk+4);off_t body=offset+8;
        if(!memcmp(chunk,"data",4)) {
            if(data){failure=@"audio_wav_duplicate_data";goto done;}data=YES;dataLengthOffset=offset+4;
            if(repair&&size==0&&body<before.st_size){size=(uint32_t)(before.st_size-body);fixData=YES;}
            payload=size;
        }
        if((unsigned long long)size>(unsigned long long)(before.st_size-body)){failure=@"audio_wav_truncated";goto done;}
        if(!memcmp(chunk,"fmt ",4)) {
            unsigned char f[16];if(fmt||size<16||!OR6AudioRead(fd,f,16,body)){failure=@"audio_wav_format";goto done;}fmt=YES;
            if(OR6AudioU16(f)!=1||OR6AudioU16(f+2)!=1||OR6AudioU32(f+4)!=16000||OR6AudioU32(f+8)!=32000||OR6AudioU16(f+12)!=2||OR6AudioU16(f+14)!=16){failure=@"audio_wav_format";goto done;}
        }
        offset=body+(off_t)size+(size&1);if(offset>before.st_size){failure=@"audio_wav_padding";goto done;}
    }
    if(!fmt||!data||!payload||(payload&1)||payload/2>maximum*16000.0||offset!=before.st_size){failure=@"audio_wav_duration";goto done;}
    if(fixRIFF||fixData) {
        unsigned char n[4];if(fixRIFF){OR6AudioPut32(n,(uint32_t)(before.st_size-8));if(pwrite(fd,n,4,4)!=4){failure=@"audio_repair_write";goto done;}}
        if(fixData){OR6AudioPut32(n,payload);if(pwrite(fd,n,4,dataLengthOffset)!=4){failure=@"audio_repair_write";goto done;}}
        if(fsync(fd)!=0){failure=@"audio_repair_sync";goto done;}
    }
    if(fstat(fd,&after)!=0||after.st_dev!=before.st_dev||after.st_ino!=before.st_ino||after.st_size!=before.st_size||after.st_nlink!=1){failure=@"audio_file_changed";goto done;}
    before=after;
    AudioFileID audio=NULL;OSStatus status=AudioFileOpenURL((CFURLRef)[NSURL fileURLWithPath:path],kAudioFileReadPermission,kAudioFileWAVEType,&audio);
    if(status!=noErr){failure=@"audio_asbd_open";goto done;}
    AudioStreamBasicDescription asbd;memset(&asbd,0,sizeof(asbd));UInt32 length=sizeof(asbd);Float64 duration=0;UInt32 durationLength=sizeof(duration);UInt64 audioBytes=0;UInt32 audioBytesLength=sizeof(audioBytes);
    OSStatus formatStatus=AudioFileGetProperty(audio,kAudioFilePropertyDataFormat,&length,&asbd);
    OSStatus durationStatus=AudioFileGetProperty(audio,kAudioFilePropertyEstimatedDuration,&durationLength,&duration);
    OSStatus bytesStatus=AudioFileGetProperty(audio,kAudioFilePropertyAudioDataByteCount,&audioBytesLength,&audioBytes);
    OSStatus closeStatus=AudioFileClose(audio);
    if(formatStatus!=noErr||durationStatus!=noErr||bytesStatus!=noErr||closeStatus!=noErr||length!=sizeof(asbd)||durationLength!=sizeof(duration)||audioBytesLength!=sizeof(audioBytes)||audioBytes!=payload||asbd.mFormatID!=kAudioFormatLinearPCM||asbd.mSampleRate!=16000.0||asbd.mChannelsPerFrame!=1||asbd.mBitsPerChannel!=16||asbd.mBytesPerFrame!=2||asbd.mFramesPerPacket!=1||asbd.mBytesPerPacket!=2||!(asbd.mFormatFlags&kAudioFormatFlagIsSignedInteger)||(asbd.mFormatFlags&(kAudioFormatFlagIsFloat|kAudioFormatFlagIsBigEndian|kAudioFormatFlagIsNonInterleaved))||!isfinite(duration)||duration<=0||fabs(duration-(double)payload/32000.0)>1.0/16000.0){failure=@"audio_asbd_format";goto done;}
    if(!OR6AudioOwned(path,root,&after)||!OR6AudioSame(before,after)){failure=@"audio_file_changed";goto done;}
    result=[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedLongLong:(unsigned long long)before.st_size],@"bytes",[NSNumber numberWithUnsignedInt:payload/2],@"frames",[NSNumber numberWithDouble:duration],@"duration",@16000,@"sampleRate",@1,@"channels",@16,@"bits",@"wav-pcm16le",@"format",nil];
done:
    if(fd>=0&&close(fd)!=0){result=nil;failure=@"audio_file_close";}if(!result)OR6AudioFail(error,failure);return result;
}

@interface OR6Audio ()
- (void)audioTick:(NSTimer *)timer;
- (void)audioNotification:(NSNotification *)notification;
- (void)finishRecordingInterrupted:(BOOL)interrupted notice:(NSString *)notice;
- (BOOL)prepareSessionRecording:(BOOL)recording error:(NSError **)error;
- (BOOL)deactivateSession;
- (AVAudioRecorder *)newRecorderURL:(NSURL *)url settings:(NSDictionary *)settings error:(NSError **)error;
- (AVAudioPlayer *)newPlayerURL:(NSURL *)url error:(NSError **)error;
- (void)finishPlaybackState:(NSString *)state notice:(NSString *)notice;
@end
@interface OR6AudioTimerTarget : NSObject { @public OR6Audio *owner; }
- (void)tick:(NSTimer *)timer;
@end
@implementation OR6AudioTimerTarget
- (void)tick:(NSTimer *)timer {[owner audioTick:timer];}
@end

@implementation OR6Audio
@synthesize delegate=_delegate;
- (NSString *)pathPartial:(BOOL)partial {return [_directory stringByAppendingPathComponent:[_pendingID stringByAppendingString:partial?@".partial.wav":@".wav"]];}
- (NSString *)markerPath {return [_directory stringByAppendingPathComponent:@"pending.plist"];}
- (void)changeState:(NSString *)state notice:(NSString *)notice {
    [_state release];_state=[state copy];[_notice release];_notice=[(notice?:@"") copy];
    if([_delegate respondsToSelector:@selector(audioCoordinatorDidChange:)])[_delegate audioCoordinatorDidChange:self];
}
- (NSDictionary *)snapshot {
    if(![NSThread isMainThread])return [NSDictionary dictionaryWithObjectsAndKeys:@"error",@"state",@"audio_main_thread",@"notice",nil];
    NSMutableDictionary *s=[NSMutableDictionary dictionaryWithObjectsAndKeys:_state?:@"idle",@"state",_notice?:@"",@"notice",[NSNumber numberWithBool:_pendingID!=nil],@"pending",nil];
    if(_pendingID)[s setObject:_pendingID forKey:@"recordingID"];
    if(_recording){[s setObject:_recording forKey:@"recording"];[s setObject:[[NSURL fileURLWithPath:[self pathPartial:NO]] absoluteString] forKey:@"recordingURL"];}
    if(_playbackID)[s setObject:_playbackID forKey:@"playbackID"];
    if([_player isKindOfClass:AVAudioPlayer.class])s[@"playback"]=@{@"isPlaying":@(_player.playing),@"currentTime":@(_player.currentTime),@"duration":@(_player.duration),@"channels":@(_player.numberOfChannels)};
    return [[s copy] autorelease];
}
- (BOOL)writeMarker:(NSString *)state error:(NSError **)error {
    NSDictionary *value=[NSDictionary dictionaryWithObjectsAndKeys:@1,@"version",_pendingID,@"id",state,@"state",nil];
    NSData *bytes=[NSPropertyListSerialization dataWithPropertyList:value format:NSPropertyListBinaryFormat_v1_0 options:0 error:error];if(!bytes)return NO;
    NSString *tmp=[_directory stringByAppendingPathComponent:@"pending.tmp"];
    /* A stale own temp from a killed atomic metadata write is safe to unlink,
     * but a symlink/nonregular file is left untouched and fails closed. */
    struct stat st;if(lstat(tmp.fileSystemRepresentation,&st)==0){if(!S_ISREG(st.st_mode)||st.st_nlink!=1||unlink(tmp.fileSystemRepresentation)!=0)return OR6AudioFail(error,@"audio_marker_temp");}else if(errno!=ENOENT)return OR6AudioFail(error,@"audio_marker_temp");
    int fd=open(tmp.fileSystemRepresentation,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600);if(fd<0)return OR6AudioFail(error,@"audio_marker_create");
    BOOL ok=OR6AudioWrite(fd,bytes.bytes,bytes.length)&&fsync(fd)==0;if(close(fd)!=0)ok=NO;
    if(ok)ok=rename(tmp.fileSystemRepresentation,self.markerPath.fileSystemRepresentation)==0&&OR6AudioSyncDirectory(_directory);
    if(!ok){unlink(tmp.fileSystemRepresentation);return OR6AudioFail(error,@"audio_marker_sync");}return YES;
}
- (BOOL)promotePartial:(NSError **)error {
    NSString *partial=[self pathPartial:YES],*final=[self pathPartial:NO];
    int fd=open(partial.fileSystemRepresentation,O_RDONLY|O_NOFOLLOW);if(fd<0)return OR6AudioFail(error,@"audio_finalize_open");BOOL ok=fsync(fd)==0;if(close(fd)!=0)ok=NO;
    /* link is exclusive, unlike rename: a prior final recording is never overwritten. */
    if(!ok||link(partial.fileSystemRepresentation,final.fileSystemRepresentation)!=0)return OR6AudioFail(error,@"audio_finalize_publish");
    if(unlink(partial.fileSystemRepresentation)!=0||!OR6AudioSyncDirectory(_directory))return OR6AudioFail(error,@"audio_finalize_sync");return YES;
}
- (BOOL)recoverPublishWindow:(NSError **)error {
    /* A kill between exclusive link and unlink leaves two known names for the
     * same inode. Only this exact generated pair with exactly two links can be
     * reconciled. Foreign hardlinks and unrelated files remain rejected. */
    NSString *partial=[self pathPartial:YES],*final=[self pathPartial:NO];struct stat a,b;
    if(lstat(partial.fileSystemRepresentation,&a)!=0||lstat(final.fileSystemRepresentation,&b)!=0)return YES;
    if(S_ISREG(a.st_mode)&&S_ISREG(b.st_mode)&&a.st_nlink==2&&b.st_nlink==2&&a.st_dev==b.st_dev&&a.st_ino==b.st_ino){
        if(unlink(partial.fileSystemRepresentation)!=0||!OR6AudioSyncDirectory(_directory))return OR6AudioFail(error,@"audio_recovery_publish");
    }return YES;
}
- (id)initWithDirectory:(NSString *)directory allowedPlaybackDirectories:(NSArray *)directories error:(NSError **)error {
    if(!(self=[super init]))return nil;
    if(![NSThread isMainThread]){OR6AudioFail(error,@"audio_main_thread");[self release];return nil;}
    _directory=[OR6AudioRoot(directory,YES,error) copy];if(!_directory){[self release];return nil;}
    if(![directories isKindOfClass:[NSArray class]]){OR6AudioFail(error,@"audio_playback_roots");[self release];return nil;}
    NSMutableArray *roots=[NSMutableArray arrayWithObject:_directory];
    for(id path in directories){NSString *root=OR6AudioRoot(path,NO,error);if(!root){[self release];return nil;}if(![roots containsObject:root])[roots addObject:root];}_playbackDirectories=[roots copy];
    _state=[@"idle" copy];_notice=[@"" copy];
    struct stat st;NSString *marker=self.markerPath;
    if(lstat(marker.fileSystemRepresentation,&st)==0){
        if(!OR6AudioOwned(marker,_directory,NULL)||st.st_size<=0||st.st_size>4096){OR6AudioFail(error,@"audio_marker_invalid");[self release];return nil;}
        int fd=open(marker.fileSystemRepresentation,O_RDONLY|O_NOFOLLOW);NSMutableData *data=[NSMutableData dataWithLength:(NSUInteger)st.st_size];BOOL readOK=fd>=0&&OR6AudioRead(fd,data.mutableBytes,data.length,0);if(fd>=0&&close(fd)!=0)readOK=NO;
        id record=readOK?[NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL]:nil;
        if(![record isKindOfClass:[NSDictionary class]]||![[record objectForKey:@"version"] isEqual:@1]||!OR6AudioID([record objectForKey:@"id"])||![@[@"capturing",@"recorded",@"interrupted"] containsObject:[record objectForKey:@"state"]]){OR6AudioFail(error,@"audio_marker_invalid");[self release];return nil;}
        _pendingID=[[record objectForKey:@"id"] copy];NSError *local=nil;
        BOOL publishRecovered=[self recoverPublishWindow:&local];
        NSDictionary *metadata=publishRecovered?OR6AudioInspect([self pathPartial:NO],_directory,60.0,NO,&local):nil;
        if(!metadata){struct stat finalStat;if(lstat([[self pathPartial:NO] fileSystemRepresentation],&finalStat)!=0&&errno==ENOENT){metadata=OR6AudioInspect([self pathPartial:YES],_directory,60.0,YES,&local);if(metadata&&![self promotePartial:&local])metadata=nil;}}
        if(metadata){_recording=[metadata copy];BOOL wasRecorded=[[record objectForKey:@"state"] isEqual:@"recorded"];if(![self writeMarker:wasRecorded?@"recorded":@"interrupted" error:&local])[self changeState:@"error" notice:@"audio_recovery_marker"];else [self changeState:wasRecorded?@"recorded":@"interrupted" notice:wasRecorded?@"audio_pending_recording":@"audio_recovered_interrupted"];}
        else [self changeState:@"interrupted" notice:@"audio_recovery_unusable_cancel_required"];
    } else if(errno!=ENOENT){OR6AudioFail(error,@"audio_marker_read");[self release];return nil;}
    NSNotificationCenter *nc=[NSNotificationCenter defaultCenter];
#if TARGET_OS_IPHONE
    for(NSString *name in @[UIApplicationWillResignActiveNotification,UIApplicationDidEnterBackgroundNotification,UIApplicationWillTerminateNotification,AVAudioSessionInterruptionNotification,AVAudioSessionRouteChangeNotification,AVAudioSessionMediaServicesWereResetNotification])[nc addObserver:self selector:@selector(audioNotification:) name:name object:nil];
#else
    /* Host tests use the same event names with fake media/session objects. */
    for(NSString *name in @[@"UIApplicationWillResignActiveNotification",@"UIApplicationDidEnterBackgroundNotification",@"UIApplicationWillTerminateNotification",@"AVAudioSessionInterruptionNotification",@"AVAudioSessionRouteChangeNotification",@"AVAudioSessionMediaServicesWereResetNotification"])[nc addObserver:self selector:@selector(audioNotification:) name:name object:nil];
#endif
    return self;
}
- (BOOL)prepareSessionRecording:(BOOL)recording error:(NSError **)error {
#if TARGET_OS_IPHONE
    AVAudioSession *session=[AVAudioSession sharedInstance];
    if(![session setCategory:recording?AVAudioSessionCategoryRecord:AVAudioSessionCategoryPlayback error:error])return NO;
    if(![session setMode:AVAudioSessionModeDefault error:error])return NO;
    if(recording&&![session setPreferredSampleRate:16000.0 error:error])return NO;
    if(recording&&![session isInputAvailable])return OR6AudioFail(error,@"audio_input_unavailable");
    /* An unsuccessful activation may be uncertain; cleanup still attempts to
     * deactivate, and keeps this flag set if that cleanup fails. */
    _sessionActive=YES;if(![session setActive:YES error:error])return NO;return YES;
#else
    (void)recording;return OR6AudioFail(error,@"audio_host_hardware_disabled");
#endif
}
- (BOOL)deactivateSession {
    if(!_sessionActive)return YES;
#if TARGET_OS_IPHONE
    NSError *error=nil;BOOL ok=[[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error];if(ok)_sessionActive=NO;return ok;
#else
    _sessionActive=NO;return YES;
#endif
}
- (AVAudioRecorder *)newRecorderURL:(NSURL *)url settings:(NSDictionary *)settings error:(NSError **)error {return [[AVAudioRecorder alloc] initWithURL:url settings:settings error:error];}
- (AVAudioPlayer *)newPlayerURL:(NSURL *)url error:(NSError **)error {return [[AVAudioPlayer alloc] initWithContentsOfURL:url error:error];}
- (void)clearWatchdog {[_watchdog invalidate];[_watchdog release];_watchdog=nil;if(_timerTarget)((OR6AudioTimerTarget *)_timerTarget)->owner=nil;[_timerTarget release];_timerTarget=nil;}
- (BOOL)startRecording:(NSString *)identifier error:(NSError **)error {
    if(![NSThread isMainThread])return OR6AudioFail(error,@"audio_main_thread");
    if(!OR6AudioID(identifier))return OR6AudioFail(error,@"audio_recording_id");
    if(_pendingID||_recorder||_player||_finishing)return OR6AudioFail(error,@"audio_pending_or_busy");
    struct statvfs space;if(statvfs(_directory.fileSystemRepresentation,&space)!=0||(double)space.f_bavail*(double)space.f_frsize<OR6AudioMaxBytes+65536)return OR6AudioFail(error,@"audio_disk_space");
    _pendingID=[identifier copy];NSString *path=[self pathPartial:YES];struct stat existing;
    if(lstat([[self pathPartial:NO] fileSystemRepresentation],&existing)==0||errno!=ENOENT||lstat(self.markerPath.fileSystemRepresentation,&existing)==0||errno!=ENOENT){[_pendingID release];_pendingID=nil;return OR6AudioFail(error,@"audio_capture_exists");}
    int fd=open(path.fileSystemRepresentation,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600);if(fd<0){[_pendingID release];_pendingID=nil;return OR6AudioFail(error,@"audio_capture_exists");}
    BOOL durable=fsync(fd)==0;if(close(fd)!=0)durable=NO;
    if(!durable||![self writeMarker:@"capturing" error:error]){unlink(path.fileSystemRepresentation);[self changeState:@"error" notice:@"audio_marker_failed_cancel_required"];return OR6AudioFail(error,@"audio_marker_failed_cancel_required");}
    NSError *local=nil;
    if(![self prepareSessionRecording:YES error:&local]){BOOL ok=[self deactivateSession];[self changeState:@"error" notice:ok?@"audio_session_record":@"audio_session_deactivate"];return OR6AudioFail(error,ok?@"audio_session_record":@"audio_session_deactivate");}
    NSDictionary *settings=@{AVFormatIDKey:@(kAudioFormatLinearPCM),AVSampleRateKey:@16000,AVNumberOfChannelsKey:@1,AVLinearPCMBitDepthKey:@16,AVLinearPCMIsBigEndianKey:@NO,AVLinearPCMIsFloatKey:@NO,AVLinearPCMIsNonInterleaved:@NO};
    _recorder=[self newRecorderURL:[NSURL fileURLWithPath:path] settings:settings error:&local];
    if(!_recorder){BOOL ok=[self deactivateSession];[self changeState:@"error" notice:ok?@"audio_recorder_create":@"audio_session_deactivate"];return OR6AudioFail(error,ok?@"audio_recorder_create":@"audio_session_deactivate");}
    _recorder.delegate=self;
    if(![_recorder prepareToRecord]||![_recorder recordForDuration:60.0]){_recorder.delegate=nil;[_recorder stop];[_recorder release];_recorder=nil;BOOL ok=[self deactivateSession];[self changeState:@"error" notice:ok?@"audio_record_start":@"audio_session_deactivate"];return OR6AudioFail(error,ok?@"audio_record_start":@"audio_session_deactivate");}
    _startedAt=OR6AudioNow();OR6AudioTimerTarget *target=[[OR6AudioTimerTarget alloc] init];target->owner=self;_timerTarget=target;
    _watchdog=[[NSTimer timerWithTimeInterval:0.25 target:target selector:@selector(tick:) userInfo:nil repeats:YES] retain];[[NSRunLoop mainRunLoop] addTimer:_watchdog forMode:NSRunLoopCommonModes];[self changeState:@"recording" notice:@""];return YES;
}
- (void)finishRecordingInterrupted:(BOOL)interrupted notice:(NSString *)notice {
    if(!_recorder||_finishing)return;_finishing=YES;[self clearWatchdog];
    _recorder.delegate=nil;[_recorder stop];[_recorder release];_recorder=nil;
    NSError *error=nil;NSDictionary *metadata=OR6AudioInspect([self pathPartial:YES],_directory,60.0,NO,&error);
    if(metadata&&![self promotePartial:&error])metadata=nil;
    [_recording release];_recording=[metadata copy];BOOL marker=[self writeMarker:interrupted||!metadata?@"interrupted":@"recorded" error:&error];BOOL deactivated=[self deactivateSession];_finishing=NO;
    if(!metadata||!marker||!deactivated)[self changeState:@"error" notice:!metadata?@"audio_final_file_invalid_cancel_required":!marker?@"audio_final_marker_failed":@"audio_session_deactivate"];
    else [self changeState:interrupted?@"interrupted":@"recorded" notice:notice];
}
- (void)stopRecording {if([NSThread isMainThread])[self finishRecordingInterrupted:NO notice:@"audio_recording_stopped"];}
- (void)cancelRecording {
    if(![NSThread isMainThread]||_finishing||!_pendingID)return;_finishing=YES;[self clearWatchdog];
    _recorder.delegate=nil;[_recorder stop];[_recorder release];_recorder=nil;
    /* Playback may be using this pending recording, so explicit cancellation
     * always closes it before deleting that file. */
    _player.delegate=nil;[_player stop];[_player release];_player=nil;[_playbackID release];_playbackID=nil;
    BOOL ok=YES;for(NSString *path in @[[self pathPartial:YES],[self pathPartial:NO]]){struct stat st;if(lstat(path.fileSystemRepresentation,&st)==0){if(!OR6AudioOwned(path,_directory,NULL)||unlink(path.fileSystemRepresentation)!=0)ok=NO;}else if(errno!=ENOENT)ok=NO;}
    if(ok){struct stat st;NSString *marker=self.markerPath;if(lstat(marker.fileSystemRepresentation,&st)==0){if(!OR6AudioOwned(marker,_directory,NULL)||unlink(marker.fileSystemRepresentation)!=0)ok=NO;}else if(errno!=ENOENT)ok=NO;}
    if(ok)ok=OR6AudioSyncDirectory(_directory);BOOL deactivated=[self deactivateSession];
    if(ok){[_pendingID release];_pendingID=nil;[_recording release];_recording=nil;}_finishing=NO;
    [self changeState:ok&&deactivated?@"idle":@"error" notice:!ok?@"audio_cancel_failed":!deactivated?@"audio_session_deactivate":@"audio_recording_cancelled"];
}
- (BOOL)playFileURL:(NSURL *)url identifier:(NSString *)identifier error:(NSError **)error {
    if(![NSThread isMainThread])return OR6AudioFail(error,@"audio_main_thread");
    if(![identifier isKindOfClass:[NSString class]]||!identifier.length||identifier.length>160||[identifier rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location!=NSNotFound)return OR6AudioFail(error,@"audio_playback_id");
    if(_recorder||_player||_finishing)return OR6AudioFail(error,@"audio_busy");
    if(![url isKindOfClass:[NSURL class]]||!url.isFileURL||url.query||url.fragment||url.user||url.password||(url.host.length&&![url.host isEqual:@"localhost"]))return OR6AudioFail(error,@"audio_playback_url");
    NSString *path=url.path,*root=nil;for(NSString *candidate in _playbackDirectories)if(OR6AudioOwned(path,candidate,NULL)){root=candidate;break;}
    if(!root)return OR6AudioFail(error,@"audio_file_ownership");
    /* Partials are never a playback source, even when their current headers look valid. */
    if([path hasSuffix:@".partial.wav"])return OR6AudioFail(error,@"audio_unfinalized");
    if(!OR6AudioInspect(path,root,180.0,NO,error))return NO;struct stat before,after;if(!OR6AudioOwned(path,root,&before))return OR6AudioFail(error,@"audio_file_changed");
    NSError *local=nil;if(![self prepareSessionRecording:NO error:&local]){BOOL ok=[self deactivateSession];[self changeState:@"error" notice:ok?@"audio_session_play":@"audio_session_deactivate"];return OR6AudioFail(error,ok?@"audio_session_play":@"audio_session_deactivate");}
    _player=[self newPlayerURL:url error:&local];
    if(!_player||!OR6AudioOwned(path,root,&after)||!OR6AudioSame(before,after)||![_player prepareToPlay]){_player.delegate=nil;[_player stop];[_player release];_player=nil;BOOL ok=[self deactivateSession];[self changeState:@"error" notice:ok?@"audio_player_prepare":@"audio_session_deactivate"];return OR6AudioFail(error,ok?@"audio_player_prepare":@"audio_session_deactivate");}
    _player.delegate=self;if(![_player play]){_player.delegate=nil;[_player stop];[_player release];_player=nil;BOOL ok=[self deactivateSession];[self changeState:@"error" notice:ok?@"audio_player_start":@"audio_session_deactivate"];return OR6AudioFail(error,ok?@"audio_player_start":@"audio_session_deactivate");}
    [_playbackID release];_playbackID=[identifier copy];[self changeState:@"playing" notice:@""];return YES;
}
- (void)finishPlaybackState:(NSString *)state notice:(NSString *)notice {
    if(!_player||_finishing)return;_finishing=YES;_player.delegate=nil;[_player stop];[_player release];_player=nil;
    BOOL ok=[self deactivateSession];_finishing=NO;[self changeState:ok?state:@"error" notice:ok?notice:@"audio_session_deactivate"];
}
- (void)stopPlayback {
    if([NSThread isMainThread])[self finishPlaybackState:@"stopped" notice:@"audio_playback_stopped"];
}
- (void)suspend {
    if(![NSThread isMainThread])return;BOOL active=_recorder||_player;
    if(_recorder)[self finishRecordingInterrupted:YES notice:@"audio_suspended"];
    if(_player)[self finishPlaybackState:@"interrupted" notice:@"audio_suspended"];
    if(!active&&![self deactivateSession])[self changeState:@"error" notice:@"audio_session_deactivate"];
}
- (void)audioTick:(NSTimer *)timer {
    (void)timer;if(!_recorder)return;struct stat st;BOOL safe=OR6AudioOwned([self pathPartial:YES],_directory,&st);
    if(!safe||(unsigned long long)st.st_size>=6ULL*1024*1024||OR6AudioNow()-_startedAt>=90.0)[self finishRecordingInterrupted:YES notice:@"audio_watchdog_stopped"];
}
- (void)audioNotification:(NSNotification *)notification {
    if(![NSThread isMainThread]){[self performSelectorOnMainThread:@selector(audioNotification:) withObject:notification waitUntilDone:NO];return;}
#if TARGET_OS_IPHONE
    NSString *interruptionName=AVAudioSessionInterruptionNotification,*interruptionKey=AVAudioSessionInterruptionTypeKey,*routeName=AVAudioSessionRouteChangeNotification,*routeKey=AVAudioSessionRouteChangeReasonKey;
#else
    NSString *interruptionName=@"AVAudioSessionInterruptionNotification",*interruptionKey=@"AVAudioSessionInterruptionTypeKey",*routeName=@"AVAudioSessionRouteChangeNotification",*routeKey=@"AVAudioSessionRouteChangeReasonKey";
#endif
    NSNumber *type=[notification.userInfo objectForKey:interruptionKey];
    if([notification.name isEqual:interruptionName]&&[type isKindOfClass:[NSNumber class]]&&type.unsignedIntegerValue==0)return; /* interruption ended: never resume */
    if([notification.name isEqual:routeName]){NSUInteger reason=[[notification.userInfo objectForKey:routeKey] unsignedIntegerValue];if(reason!=2&&reason!=7)return;} /* lost device / no suitable route */
    [self suspend];
}
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
    if(recorder!=_recorder)return;[self finishRecordingInterrupted:!flag notice:flag?@"audio_duration_limit":@"audio_recording_failed"];
}
- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error {(void)error;if(recorder==_recorder)[self finishRecordingInterrupted:YES notice:@"audio_encode_error"];}
- (void)audioRecorderBeginInterruption:(AVAudioRecorder *)recorder {if(recorder==_recorder)[self suspend];}
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {if(player==_player)[self finishPlaybackState:flag?@"stopped":@"error" notice:flag?@"audio_playback_finished":@"audio_decode_error"];}
- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error {(void)error;if(player==_player)[self finishPlaybackState:@"error" notice:@"audio_decode_error"];}
- (void)audioPlayerBeginInterruption:(AVAudioPlayer *)player {if(player==_player)[self suspend];}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];_delegate=nil;[self clearWatchdog];
    _recorder.delegate=nil;[_recorder stop];[_recorder release];_player.delegate=nil;[_player stop];[_player release];[self deactivateSession];
    [_directory release];[_playbackDirectories release];[_state release];[_notice release];[_pendingID release];[_playbackID release];[_recording release];[super dealloc];
}
@end
