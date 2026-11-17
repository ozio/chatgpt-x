#import "OR6Chat9Dictation.h"
#import "../../api/priority9/OR6API9Policy.h"
#import "../../chat/OR6ChatUIState.h"
@implementation OR6Chat9Dictation
@synthesize delegate=_delegate,recordingId=_recordingId,phase=_phase,issue=_issue,text=_text,busy=_busy,uncertain=_uncertain;
- (id)initWithCore:(OR6APICore *)core recordingId:(NSString *)identifier{
 if((self=[super init])){_maximumDurationMS=60000;_core=[core retain];_recordingId=OR6API9UUID(identifier)?[identifier copy]:nil;_phase=[(_recordingId?@"recoverable":@"idle")copy];_text=[@""copy];_issue=[@""copy];}return self;
}
- (NSUInteger)maximumDurationMS{return _maximumDurationMS;}
- (void)setMaximumDurationMS:(NSUInteger)maximum{if(maximum>0&&maximum<=60000&&!_busy&&![_phase isEqual:@"recording"])_maximumDurationMS=maximum;}
- (void)changed:(NSString *)phase issue:(NSString *)issue{[_phase release];_phase=[phase copy];[_issue release];_issue=[(issue?:@"")copy];[_delegate dictationChanged:self];[NSNotificationCenter.defaultCenter postNotificationName:@"OR6Chat9DictationChanged"object:self];}
- (void)request:(NSString *)operation parameters:(NSDictionary *)parameters completion:(OR6APIReply)completion{
 if(_busy||_disposed)return;_busy=YES;NSUInteger epoch=++_epoch;__block BOOL done=NO;
 id<OR6APITask>task=[_core perform:operation parameters:parameters event:nil completion:^(NSDictionary*r,NSError*e){
  done=YES;if(epoch!=_epoch||_disposed)return;[_task release];_task=nil;_busy=NO;completion(r,e);
 }];if(!done&&epoch==_epoch)_task=[task retain];
}
- (void)captureReply:(NSDictionary *)result error:(NSError *)error{
 if(error){[self changed:@"failed"issue:error.userInfo[@"code"]];return;}
 NSString*state=result[@"state"];if(![@[@"recording",@"stopped"]containsObject:state]){[self changed:@"failed"issue:@"invalid_response"];return;}
 _durationMS=[result[@"durationMS"]unsignedIntegerValue];_bytes=[result[@"bytes"]unsignedIntegerValue];[_assetId release];_assetId=[result[@"assetId"]isKindOfClass:NSString.class]?[result[@"assetId"]copy]:nil;if([state isEqual:@"stopped"]){[_limit invalidate];[_limit release];_limit=nil;}[self changed:state issue:@""];
}
- (void)restoreRecording{if(_busy||![_phase isEqual:@"recoverable"])return;[self stop];}
- (void)start{
 if(_busy||_recordingId||![_phase isEqual:@"idle"])return;_recordingId=[OR6ChatUUID()copy];_uncertain=NO;_durationMS=0;_bytes=0;self.text=@"";
 [self request:@"dictation.start"parameters:@{@"recordingId":_recordingId,@"maxDurationMS":@(_maximumDurationMS)}completion:^(NSDictionary*r,NSError*e){if(e){[_recordingId release];_recordingId=nil;[self changed:@"idle"issue:e.userInfo[@"code"]];}else{[self captureReply:r error:nil];if([_phase isEqual:@"recording"]){[_limit invalidate];[_limit release];_limit=[[NSTimer timerWithTimeInterval:(double)_maximumDurationMS/1000 target:self selector:@selector(recordingExpired:)userInfo:nil repeats:NO]retain];[NSRunLoop.mainRunLoop addTimer:_limit forMode:NSRunLoopCommonModes];}}}];
 [_delegate dictationChanged:self];
}
- (void)recordingExpired:(NSTimer *)timer{(void)timer;[self stop];}
- (void)stop{
 if(_busy||!_recordingId||![@[@"recording",@"recoverable"]containsObject:_phase])return;
 [self request:@"dictation.stop"parameters:@{@"recordingId":_recordingId}completion:^(NSDictionary*r,NSError*e){[self captureReply:r error:e];}];
}
- (BOOL)canTranscribe{return !_busy&&!_uncertain&&_assetId.length&&[_phase isEqual:@"stopped"];}
- (BOOL)canRetry{return !_busy&&!_uncertain&&_retryOperation.length;}
- (void)transcription:(NSString *)operation parameters:(NSDictionary *)parameters{
 [_operationId release];_operationId=[parameters[@"operationId"]copy];[_retryOperation release];_retryOperation=nil;
 [self changed:@"transcribing"issue:@""];
 [self request:operation parameters:parameters completion:^(NSDictionary*r,NSError*e){
  if(e){_uncertain=![e.userInfo[@"dispatch"]isEqual:@"none"];NSString*code=e.userInfo[@"code"];BOOL blocked=[@[@"service_challenge",@"rate_limited",@"access_denied",@"not_authenticated",@"login_required",@"stale_context"]containsObject:code];if(!_uncertain&&!blocked)_retryOperation=[_operationId copy];[self changed:_uncertain?@"uncertain":@"failed"issue:code];}
  else{self.text=r[@"text"]?:@"";_uncertain=NO;[self changed:@"transcribed"issue:@""];}
 }];[_delegate dictationChanged:self];
}
- (void)transcribe{if(self.canTranscribe)[self transcription:@"dictation.transcribe"parameters:@{@"operationId":OR6ChatUUID(),@"recordingId":_recordingId,@"assetId":_assetId}];}
- (void)retry{if(self.canRetry)[self transcription:@"dictation.retry"parameters:@{@"operationId":OR6ChatUUID(),@"recordingId":_recordingId,@"priorOperationId":_retryOperation}];}
- (void)discard{
 if(!_recordingId||_disposed)return;[_limit invalidate];[_limit release];_limit=nil;_epoch++;[_task cancel];[_task release];_task=nil;_busy=NO;
 [self request:@"dictation.cancel"parameters:@{@"recordingId":_recordingId}completion:^(NSDictionary*r,NSError*e){(void)r;if(e){[self changed:@"failed"issue:e.userInfo[@"code"]];return;}[_recordingId release];_recordingId=nil;[_assetId release];_assetId=nil;[_retryOperation release];_retryOperation=nil;self.text=@"";_uncertain=NO;_durationMS=0;_bytes=0;[self changed:@"idle"issue:@""];}];
}
- (void)prepareForBackground{
 if(_disposed)return;[_limit invalidate];[_limit release];_limit=nil;
 if(_busy){BOOL upload=[_phase isEqual:@"transcribing"];_epoch++;[_task cancel];[_task release];_task=nil;_busy=NO;if(upload){_uncertain=YES;[_retryOperation release];_retryOperation=nil;[self changed:@"uncertain"issue:@"cancelled"];}else[self changed:@"recoverable"issue:@""];}
 if([_phase isEqual:@"recording"]) [self stop];
}
- (NSString *)insertingInto:(NSString *)draft range:(NSRange)range{
 if([draft isKindOfClass:NSString.class]&&range.location==NSNotFound&&range.length==0)range=NSMakeRange(draft.length,0);
 if(_busy||![_phase isEqual:@"transcribed"]||![draft isKindOfClass:NSString.class]||range.location>draft.length||range.length>draft.length-range.location||!_text.length||_text.length>16000)return nil;
 if(range.length){NSRange full=[draft rangeOfComposedCharacterSequencesForRange:range];if(!NSEqualRanges(full,range))return nil;}
 else if(range.location>0&&range.location<draft.length){NSRange full=[draft rangeOfComposedCharacterSequenceAtIndex:range.location];if(full.location!=range.location)return nil;}
 NSString*next=[draft stringByReplacingCharactersInRange:range withString:_text];return next.length<=16000?next:nil;
}
- (NSDictionary *)diagnostics{return @{@"phase":_phase,@"maxDurationMS":@(_maximumDurationMS),@"durationMS":@(_durationMS),@"bytes":@(_bytes),@"busy":@(_busy),@"uncertain":@(_uncertain),@"hasRecording":@(_recordingId!=nil),@"hasAsset":@(_assetId!=nil),@"textLength":@(_text.length),@"retryAvailable":@(self.canRetry),@"issue":_issue};}
- (void)dealloc{_delegate=nil;_disposed=YES;_epoch++;[_limit invalidate];[_limit release];[_task cancel];[_task release];if([_phase isEqual:@"recording"]&&_recordingId)[_core perform:@"dictation.stop"parameters:@{@"recordingId":_recordingId}event:nil completion:^(NSDictionary*r,NSError*e){(void)r;(void)e;}];[_core release];[_recordingId release];[_assetId release];[_phase release];[_text release];[_issue release];[_operationId release];[_retryOperation release];[super dealloc];}
@end
