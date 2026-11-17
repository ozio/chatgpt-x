#import "../../localization/OR6Localization.h"
#import "OR6Chat9DictationController.h"
#import "OR6Chat9MessageController.h"
#import "../../chat/OR6ChatUIState.h"
@interface OR6Chat9DictationController(){
 OR6Chat9Dictation*_model;id<OR6Chat9TranscriptHost>_host;UITextView*_text;UILabel*_status;
 UIButton*_start,*_stop,*_transcribe,*_retry,*_discard,*_insert;BOOL _inserted;CGFloat _keyboardHeight;
}
@end
@implementation OR6Chat9DictationController
- (id)initWithModel:(OR6Chat9Dictation *)model host:(id<OR6Chat9TranscriptHost>)host{if((self=[super init])){_model=[model retain];_host=host;self.title=OR6L(@"Dictation");}return self;}
- (UIButton *)button:(NSString *)title action:(SEL)action identifier:(NSString *)identifier{
 UIButton*b=[UIButton buttonWithType:UIButtonTypeRoundedRect];[b setTitle:title forState:UIControlStateNormal];[b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];b.accessibilityIdentifier=identifier;[self.view addSubview:b];return b;
}
- (void)loadView{
 self.view=[[[UIView alloc]initWithFrame:UIScreen.mainScreen.applicationFrame]autorelease];self.view.backgroundColor=UIColor.whiteColor;
 _status=[[UILabel alloc]initWithFrame:CGRectZero];_status.numberOfLines=4;_status.font=[UIFont systemFontOfSize:14];_status.accessibilityIdentifier=@"chat.dictation.status";[self.view addSubview:_status];
 _start=[[self button:OR6L(@"Record")action:@selector(start)identifier:@"chat.dictation.start"]retain];_stop=[[self button:OR6L(@"Stop recording")action:@selector(stop)identifier:@"chat.dictation.stop"]retain];
 _transcribe=[[self button:OR6L(@"Transcribe")action:@selector(transcribe)identifier:@"chat.dictation.transcribe"]retain];_retry=[[self button:OR6L(@"Retry transcription")action:@selector(retry)identifier:@"chat.dictation.retry"]retain];
 _discard=[[self button:OR6L(@"Delete recording")action:@selector(discard)identifier:@"chat.dictation.discard"]retain];_insert=[[self button:OR6L(@"Insert into message")action:@selector(insert)identifier:@"chat.dictation.insert"]retain];
 _text=[[UITextView alloc]initWithFrame:CGRectZero];_text.font=[UIFont systemFontOfSize:17];_text.backgroundColor=[UIColor colorWithWhite:.96 alpha:1];_text.delegate=self;_text.accessibilityIdentifier=@"chat.dictation.text";_text.accessibilityLabel=OR6L(@"Dictation text");_text.accessibilityHint=OR6L(@"Edit the text before inserting it into your message");[self.view addSubview:_text];[self render];
}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];_model.delegate=self;[_model restoreRecording];[self render];}
- (void)viewDidLoad{[super viewDidLoad];[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboard:)name:UIKeyboardWillChangeFrameNotification object:nil];}
- (void)viewWillDisappear:(BOOL)animated{[super viewWillDisappear:animated];[_text resignFirstResponder];[_model prepareForBackground];if(_model.delegate==self)_model.delegate=nil;}
- (void)viewDidLayoutSubviews{
 [super viewDidLayoutSubviews];CGFloat w=self.view.bounds.size.width,h=MAX(0,self.view.bounds.size.height-_keyboardHeight),half=(w-24)/2;
 _status.frame=CGRectMake(10,6,w-20,76);_start.frame=CGRectMake(8,86,half,42);_stop.frame=CGRectMake(16+half,86,half,42);_transcribe.frame=CGRectMake(8,132,half,42);_discard.frame=CGRectMake(16+half,132,half,42);
 _retry.frame=CGRectMake(8,178,w-16,38);_text.frame=CGRectMake(8,220,w-16,MAX(60,h-274));_insert.frame=CGRectMake(8,MAX(284,h-48),w-16,40);
 BOOL editing=_keyboardHeight>0&&[_model.phase isEqual:@"transcribed"];if(editing){_status.frame=CGRectMake(10,4,w-20,58);_text.frame=CGRectMake(8,66,w-16,MAX(40,h-120));_insert.frame=CGRectMake(8,MAX(110,h-48),w-16,40);}for(UIButton*b in @[_start,_stop,_transcribe,_discard])b.hidden=editing;_retry.hidden=editing||!_model.canRetry;
}
- (void)keyboard:(NSNotification *)notification{NSValue*v=notification.userInfo[UIKeyboardFrameEndUserInfoKey];if(!v)return;CGRect overlap=CGRectIntersection(self.view.bounds,[self.view convertRect:v.CGRectValue fromView:nil]);_keyboardHeight=CGRectIsNull(overlap)?0:overlap.size.height;[self.view setNeedsLayout];}
- (void)setMaximumCaptureDurationMS:(NSUInteger)maximum{_model.maximumDurationMS=maximum;[self render];}
- (void)render{
 if(!self.isViewLoaded)return;NSString*phase=_model.phase,*status=[NSString stringWithFormat:OR6L(@"Record up to %lu seconds. Transcription starts separately; send your message from the chat."),(unsigned long)(_model.maximumDurationMS/1000)];
 if([phase isEqual:@"recording"])status=OR6L(@"The microphone is on. Tap Stop recording.");
 else if([phase isEqual:@"stopped"])status=OR6L(@"Recording stopped. Tap Transcribe to submit it for transcription.");
 else if([phase isEqual:@"transcribing"])status=OR6L(@"Transcribing recording…");
 else if([phase isEqual:@"transcribed"])status=_inserted?OR6L(@"Text inserted into the message field. Send it from the chat when you are ready."):OR6L(@"Review the text. Inserting will add it to the message field.");
 else if(_model.uncertain)status=OR6L(@"The transcription result is unknown. Uploading the recording again is disabled.");
 if(_model.issue.length)status=OR6ChatErrorText(OR6APIError(_model.issue,_model.uncertain?@"possible":@"none"));_status.text=status;
 _start.enabled=!_model.busy&&!_model.recordingId&&[phase isEqual:@"idle"];_stop.enabled=!_model.busy&&[phase isEqual:@"recording"];_transcribe.enabled=_model.canTranscribe;_retry.hidden=!_model.canRetry;_retry.enabled=_model.canRetry;_discard.enabled=_model.recordingId!=nil;_insert.enabled=[phase isEqual:@"transcribed"]&&!_model.busy&&_model.text.length>0&&!_inserted;
 _text.editable=[phase isEqual:@"transcribed"]&&!_model.busy;if(![_text.text isEqual:_model.text])_text.text=_model.text;
 for(UIButton*b in @[_start,_stop,_transcribe,_retry,_discard,_insert])OR6Chat9ApplyControlAccessibility(b,[b titleForState:UIControlStateNormal],b==_start?OR6L(@"Turns on the iPhone microphone"):b==_insert?OR6L(@"Inserts text without sending the message"):@"",b.enabled);
}
- (void)dictationChanged:(OR6Chat9Dictation *)dictation{(void)dictation;[self render];[NSNotificationCenter.defaultCenter postNotificationName:@"OR6ChatUIChanged"object:self];}
- (void)textViewDidChange:(UITextView *)view{_model.text=view.text;_inserted=NO;_insert.enabled=view.text.length>0&&view.text.length<=16000;OR6Chat9ApplyControlAccessibility(_insert,OR6L(@"Insert into message"),OR6L(@"Inserts text without sending the message"),_insert.enabled);}
- (void)start{_inserted=NO;[_model start];[self render];}
- (void)stop{[_model stop];[self render];}
- (void)transcribe{[_model transcribe];[self render];}
- (void)retry{[_model retry];[self render];}
- (void)discard{[_text resignFirstResponder];[_model discard];_inserted=NO;[self render];}
- (void)insert{if(!_insert.enabled)return;_model.text=_text.text;_inserted=[_host insertDictationText:_model];[self render];if(_inserted){[_text resignFirstResponder];[self.navigationController popViewControllerAnimated:YES];}}
- (void)prepareForBackground{[_text resignFirstResponder];[_model prepareForBackground];[self render];}
- (void)dealloc{[NSNotificationCenter.defaultCenter removeObserver:self];if(_model.delegate==self)_model.delegate=nil;_text.delegate=nil;[_model release];[_text release];[_status release];[_start release];[_stop release];[_transcribe release];[_retry release];[_discard release];[_insert release];[super dealloc];}
@end
