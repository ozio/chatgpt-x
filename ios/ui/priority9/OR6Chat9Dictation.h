#import <Foundation/Foundation.h>
#import "../../api/OR6APICore.h"
@class OR6Chat9Dictation;
@protocol OR6Chat9DictationDelegate<NSObject>
- (void)dictationChanged:(OR6Chat9Dictation *)dictation;
@end
@interface OR6Chat9Dictation:NSObject {
 OR6APICore *_core;id<OR6APITask>_task;id<OR6Chat9DictationDelegate>_delegate;
 NSString *_recordingId,*_assetId,*_phase,*_text,*_issue,*_operationId,*_retryOperation;
 NSUInteger _epoch,_maximumDurationMS,_durationMS,_bytes;BOOL _busy,_uncertain,_disposed;
 NSTimer *_limit;
}
@property(nonatomic,assign)id<OR6Chat9DictationDelegate>delegate;
@property(nonatomic,readonly)NSString *recordingId;
@property(nonatomic,readonly)NSString *phase;
@property(nonatomic,readonly)NSString *issue;
@property(nonatomic,copy)NSString *text;
@property(nonatomic,readonly)BOOL busy;
@property(nonatomic,readonly)BOOL uncertain;
@property(nonatomic,assign)NSUInteger maximumDurationMS;
- (id)initWithCore:(OR6APICore *)core recordingId:(NSString *)identifier;
- (void)restoreRecording;
- (void)start;
- (void)stop;
- (void)transcribe;
- (void)retry;
- (void)discard;
- (void)prepareForBackground;
- (BOOL)canTranscribe;
- (BOOL)canRetry;
- (NSString *)insertingInto:(NSString *)draft range:(NSRange)range;
- (NSDictionary *)diagnostics;
@end
