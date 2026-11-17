#import "voice8/OR6ChatVoice8.h"
#import "../ui/selected20/OR6Chat20Conversation.h"
// Conversation screen assembled from the ChatGPT X UI kit (ios/ui): jade title
// with the real send status lamp, linen message list (reused cells, cached row
// heights), Messages-style composer with inline dictation, honest delivery
// badges and banners. Feature slots follow what this build can really do;
// nothing appears as a disabled "soon" control.
#import "../localization/OR6Localization.h"
#import "OR6ChatConversationController.h"
#import "OR6ChatUIState.h"
#import "OR6ChatScreens.h"
#import "../ui/priority9/OR6Chat9Actions.h"
#import "../ui/priority9/OR6Chat9Content.h"
#import "../ui/priority9/OR6Chat9Dictation.h"
#import "../ui/priority9/OR6Chat9MessageController.h"
#import "../ui/priority8/OR6Chat8Models.h"
#import "../ui/priority8/OR6Chat8Screens.h"
#import "../ui/priority7/OR6Chat7Conversation.h"
#import "../ui/priority6/OR6Chat6Conversation.h"
#import "../OR6Content.h"
#import <objc/runtime.h>
#import "RCTheme.h"
#import "RCGlyph.h"
#import "RCTitleView.h"
#import "RCBannerView.h"
#import "RCUserMessageView.h"
#import "RCAnswerCardView.h"
#import "RCComposerView.h"
#import "RCEmptyChatView.h"
#import "RCPartPlaceholderView.h"
#import "RCHUD.h"
#import "RCButton.h"
#import "RCActivitySheet.h"
#import "RCFilePartView.h"
#import "RCRefreshControl.h"
#import "OR6ChatFavicons.h"

enum { OR6SheetRetry = 1, OR6SheetCheck, OR6SheetLink, OR6SheetMore, OR6SheetSources };
// Implemented in OR6Chat7Conversation.m: the row's image preview states (pure reads, nil without images).
@interface OR6Chat7Conversation(OR6ChatImagePreviewRevision)
- (NSString*)imagePreviewRevisionForRow:(NSDictionary*)row;
@end

#pragma mark - Cell

@interface OR6ChatMessageCell:UITableViewCell{UIView*_item;}
@property(nonatomic,retain)UIView*item;
@end
@implementation OR6ChatMessageCell
@synthesize item=_item;
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString*)identifier{if((self=[super initWithStyle:style reuseIdentifier:identifier])){self.selectionStyle=UITableViewCellSelectionStyleNone;self.backgroundColor=UIColor.clearColor;self.contentView.backgroundColor=UIColor.clearColor;self.backgroundView=[[[UIView alloc]init]autorelease];self.backgroundView.backgroundColor=UIColor.clearColor;}return self;}
- (void)setItem:(UIView*)item{if(item==_item)return;[_item removeFromSuperview];[_item release];_item=[item retain];if(item)[self.contentView addSubview:item];[self setNeedsLayout];}
- (void)layoutSubviews{[super layoutSubviews];_item.frame=self.contentView.bounds;}
- (void)dealloc{[_item release];[super dealloc];}
@end

#pragma mark - Controller

@interface OR6ChatConversationController()<UITableViewDataSource,UITableViewDelegate,UIActionSheetDelegate,RCComposerViewDelegate,RCAnswerCardViewDelegate,RCUserMessageViewDelegate,RCCodeBlockViewDelegate,OR6Chat9DictationDelegate,RCActivitySheetDelegate,OR6Chat8ModelDelegate,OR6Chat7ConversationHost,OR6ChatVoice8Host>{
 OR6APICore*_core;OR6ChatConversationState*_state;OR6Chat9Actions*_actions;OR6Chat9Dictation*_dictation;
 id<OR6ChatConversationHost>_host;NSString*_conversationTitle;NSDictionary*_summary;
 UITableView*_table;RCRefreshControl*_refresh;RCComposerView*_composer;RCTitleView*_titleView;RCBannerView*_banner;RCEmptyChatView*_empty;
 RCAnswerCardView*_measureCard;RCUserMessageView*_measureUser;NSMutableDictionary*_heights;NSMutableSet*_reasoningOpen;CGFloat _heightsWidth;
 NSArray*_rows;id<OR6APITask>_request,_stopRequest;NSUInteger _epoch,_stopEpoch;NSString*_notice,*_stopIssue;
 CGFloat _keyboardHeight;CGRect _keyboardFrame;NSUInteger _editorEpoch;BOOL _busy,_draftPrepared,_sendRequested,_sessionReady,_disposed,_stickToBottom,_stopped,_dictationDone,_dictationInserted;
 NSUInteger _windowStart;BOOL _windowSet;NSMutableDictionary*_cards;NSMutableArray*_cardOrder;
 NSDictionary*_pendingRecovery;NSString*_recoveryOperation;BOOL _recoveryLatched,_hydrateLatched,_recoveryHydrate,_hydrating,_recoveryOff;
 NSTimer*_historyPoll;NSUInteger _historyPolls,_historyReads,_historyRefreshes,_historyReadSuccesses;NSTimer*_streamTimer,*_clock;NSDate*_sendStarted,*_dictationStarted;NSDictionary*_sheetRow;NSURL*_sheetURL;NSArray*_sheetSources;
 // Priority 8: draft files, downloads, shared model catalog, explicit web search mode, search status polling.
 UIActivityIndicatorView*_historySpinner;
 OR6Chat8Attachments*_files;OR6Chat8Downloads*_downloads;OR6Chat8Catalog*_catalog;NSTimer*_statusPoll;NSArray*_plusActions;NSString*_traySignature;
 BOOL _webSearch,_chipShown,_wantsPicker;
 OR6Chat7Conversation*_api7; // API 7/10 of this screen (tools, continue, links, images, player, mail, editor); detached before release
 OR6ChatVoice8*_voice8;
 OR6Chat20Conversation*_api20; RCReadAloudBar *_readAloud;
 OR6Chat6Conversation*_api6; // stage 6 of this screen (branch, report, lock, Library, memory used, PDF, Work, mentions, GPT); detached before release
}
@end

@implementation OR6ChatConversationController
@synthesize host=_host;

- (id)initWithCore:(OR6APICore*)core conversationId:(NSString*)identifier{
 if((self=[super init])){
  _sessionReady=YES;_stickToBottom=YES;_core=[core retain];_state=[[OR6ChatConversationState alloc]initWithConversationId:identifier];_actions=[[OR6Chat9Actions alloc]initWithState:_state];
  _dictation=[[OR6Chat9Dictation alloc]initWithCore:core recordingId:[NSUserDefaults.standardUserDefaults objectForKey:@"ChatGPTXUI9RecordingID"]];_dictation.delegate=self;
  _heights=[NSMutableDictionary new];_reasoningOpen=[NSMutableSet new];_cards=[NSMutableDictionary new];_cardOrder=[NSMutableArray new];
  _files=[[OR6Chat8Attachments alloc]initWithCore:core];_files.delegate=self;_downloads=[[OR6Chat8Downloads alloc]initWithCore:core];_downloads.delegate=self;_api7=[[OR6Chat7Conversation alloc]initWithCore:core host:self];_api6=[[OR6Chat6Conversation alloc]initWithCore:core host:self api7:_api7];_api20=[[OR6Chat20Conversation alloc]initWithCore:core host:self];
  NSNotificationCenter*nc=NSNotificationCenter.defaultCenter;
  for(NSString*name in @[RCThemeTextSizeDidChangeNotification,RCThemeAppearanceDidChangeNotification])[nc addObserver:self selector:@selector(lookChanged:)name:name object:nil];
 }return self;
}
- (NSString*)conversationId{return _state.conversationId;}
- (BOOL)temporary{return _state.temporary;}
- (OR6Chat8Catalog*)catalog{return _catalog;}
- (void)setCatalog:(OR6Chat8Catalog*)c{if(c==_catalog)return;_api6.catalog=c;if(_catalog.delegate==(id)self)_catalog.delegate=nil;[_catalog release];_catalog=[c retain];if(self.isViewLoaded&&self.view.window)_catalog.delegate=self;[self renderTitle];}
- (NSString*)conversationTitle{return _conversationTitle;}
- (void)setConversationTitle:(NSString*)t{[_conversationTitle release];_conversationTitle=[t copy];[self renderTitle];}

#pragma mark View

- (UIBarButtonItem*)barGlyph:(NSString*)glyph action:(SEL)action label:(NSString*)label identifier:(NSString*)identifier{
 UIBarButtonItem*i=[[[UIBarButtonItem alloc]initWithImage:[RCGlyph imageNamed:glyph size:20 color:UIColor.whiteColor]style:UIBarButtonItemStyleBordered target:self action:action]autorelease];i.accessibilityLabel=label;(void)identifier;return i;
}
- (void)loadView{
 UIView*v=[[[UIView alloc]initWithFrame:UIScreen.mainScreen.applicationFrame]autorelease];v.backgroundColor=[RCTheme contentBackgroundColor];self.view=v;
 _table=[[UITableView alloc]initWithFrame:v.bounds style:UITableViewStylePlain];_table.delegate=self;_table.dataSource=self;_table.separatorStyle=UITableViewCellSeparatorStyleNone;_table.backgroundColor=UIColor.clearColor;_table.backgroundView=nil;_table.accessibilityIdentifier=@"chat.messages";_table.contentInset=UIEdgeInsetsMake(10,0,0,0);[v addSubview:_table];
 _empty=[[RCEmptyChatView alloc]initWithFrame:CGRectZero];_empty.title=OR6L(@"What can I help with?");RCEmptyChatViewSetMessage(_empty);[_empty.temporarySwitch addTarget:self action:@selector(temporaryChanged:)forControlEvents:UIControlEventValueChanged];_empty.temporarySwitch.accessibilityIdentifier=@"chat.temporary";[v addSubview:_empty];
 _historySpinner=[[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];_historySpinner.hidesWhenStopped=YES;_historySpinner.accessibilityIdentifier=@"chat.history.loading";_historySpinner.accessibilityLabel=OR6L(@"Loading conversation…");[v addSubview:_historySpinner];
 _readAloud=[_api20 readAloudBar];[v addSubview:_readAloud];
 _composer=[[RCComposerView alloc]initWithFrame:CGRectMake(0,0,v.bounds.size.width,46)];_composer.delegate=self;_composer.placeholder=OR6L(@"Message");_composer.textView.accessibilityIdentifier=@"chat.composer";_composer.sendButton.accessibilityIdentifier=@"chat.send";_composer.micButton.accessibilityIdentifier=@"chat.dictation.open";[v addSubview:_composer];
 [_composer.dictationView.cancelButton addTarget:self action:@selector(dictationCancel)forControlEvents:UIControlEventTouchUpInside];[_composer.dictationView.doneButton addTarget:self action:@selector(dictationDone)forControlEvents:UIControlEventTouchUpInside];
 _composer.dictationView.cancelButton.accessibilityIdentifier=@"chat.dictation.discard";_composer.dictationView.doneButton.accessibilityIdentifier=@"chat.dictation.done";
 _titleView=[[RCTitleView alloc]initWithFrame:CGRectMake(0,0,200,44)];_titleView.variant=RCBarVariantJade;_titleView.animatesSubtitleAppearance=YES;[_titleView addTarget:self action:@selector(titleTapped)forControlEvents:UIControlEventTouchUpInside];self.navigationItem.titleView=_titleView;
 self.navigationItem.leftBarButtonItem=[self barGlyph:@"menu" action:@selector(toggleDrawer)label:OR6L(@"Chats")identifier:@"chat.drawer"];
 self.navigationItem.rightBarButtonItem=[self barGlyph:@"compose" action:@selector(newChat)label:OR6L(@"New chat")identifier:@"chat.new"];
 _refresh=[[RCRefreshControl alloc]init];[_refresh addTarget:self action:@selector(refreshConversation:)forControlEvents:UIControlEventValueChanged];[_refresh attachToTableView:_table inViewController:self];_table.alwaysBounceVertical=YES;
 _measureCard=[[RCAnswerCardView alloc]initWithFrame:CGRectMake(0,0,320,100)];_measureUser=[[RCUserMessageView alloc]initWithFrame:CGRectMake(0,0,320,100)];
 [self render:YES];
}
static void RCEmptyChatViewSetMessage(RCEmptyChatView*e){e.message=e.temporary?OR6L(@"This chat is not saved in your history and is not used for training. It disappears when you leave it."):OR6L(@"Ask anything. The answer appears as it is written.");}
- (void)viewDidLoad{
 [super viewDidLoad];[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(faviconsLoaded:) name:OR6ChatFaviconDidLoadNotification object:nil];_keyboardFrame=CGRectNull;for(NSString*name in @[UIKeyboardWillChangeFrameNotification,UIKeyboardWillHideNotification])[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboard:)name:name object:nil];
 if(_recoveryHydrate)[self hydrateRecoveredHistory];else if(_state.conversationId&&!_state.loaded)[self loadConversation]; // a restored send hydrates (once) instead
 if([@[@"recoverable",@"stopped",@"transcribing",@"failed",@"uncertain",@"transcribed"]containsObject:_dictation.phase])[self showDictation];
 [self importDeploymentDraft]; // a new chat is loaded now; an existing one after history.get
}
// One-shot developer-install handoff of an unsent draft (OR6ChatUIState.h): only into the matching,
// loaded, idle conversation with an empty draft; local only, nothing is prepared or sent.
- (void)importDeploymentDraft{
 if(_disposed||_recoveryHydrate||_pendingRecovery||_busy)return;
 NSString*status=[_state importDeploymentDraftAtPath:OR6ChatDeploymentDraftPath()];
 if(![status hasPrefix:@"imported"])return;
 if(self.isViewLoaded){_composer.text=_state.text;[self renderComposer];[self layout];} // the field was empty (state mirrors it)
}
- (RCBarVariant)barVariant{return _state.temporary?RCBarVariantTemporary:RCBarVariantJade;}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];if(!_webSearch)[_api7 refreshModeChip];if(!_state.conversationId&&!_state.messages.count&&_sessionReady)[_api6 newChatOpened];[RCTheme styleNavigationBar:self.navigationController.navigationBar variant:[self barVariant]];_titleView.variant=[self barVariant];_catalog.delegate=self;if([self updateKeyboardInset])[self layout];[self render:NO];}
- (void)viewWillDisappear:(BOOL)animated{[super viewWillDisappear:animated];[_historyPoll invalidate];_historyPoll=nil;}
- (void)viewDidAppear:(BOOL)animated{[super viewDidAppear:animated];[self scheduleRemoteHistory];if([self updateKeyboardInset])[UIView animateWithDuration:.25 animations:^{[self layout];}];} // back in the window: a keyboard still up is measured against this view now
- (void)viewDidLayoutSubviews{[super viewDidLayoutSubviews];[self layout];}
- (void)layout{
 if(!self.isViewLoaded)return;CGFloat w=self.view.bounds.size.width,h=MAX(0,self.view.bounds.size.height-_keyboardHeight);
 CGFloat ch=[_composer heightForWidth:w];_composer.frame=CGRectMake(0,h-ch,w,ch);
 CGFloat bh=_banner?[_banner heightForWidth:w]:0;_banner.frame=CGRectMake(0,0,w,bh);CGFloat ph=_readAloud.presented?[_readAloud heightForWidth:w]:0;_readAloud.frame=CGRectMake(0,bh,w,ph);
 CGRect old=_table.frame;_table.frame=CGRectMake(0,bh+ph,w,MAX(0,h-ch-bh-ph));
 _historySpinner.center=CGPointMake(CGRectGetMidX(_table.frame),CGRectGetMidY(_table.frame));
 CGFloat eh=[_empty heightForWidth:w];_empty.frame=CGRectMake(0,bh+ph+MAX(0,floor((h-ch-bh-ph-eh)/2.5)),w,eh);
 if(w!=_heightsWidth){[_heights removeAllObjects];_heightsWidth=w;[_table reloadData];}
 if(!CGRectEqualToRect(old,_table.frame)&&_stickToBottom)[self scrollToBottom:NO];
}
// Keyboard inset (tests/chat-keyboard). `keyboard` is the last end frame in screen coordinates (CGRectNull
// after WillHide); `inView` is the same frame in this view, meaningful only while the view is in a window.
// A hidden keyboard takes nothing, nor one that slid off the screen sideways with a navigation pop: its edge
// still touches the bounds, a zero-width but non-null intersection that used to keep the full height.
// Detached (a pushed Library search or the modal editor owns the keyboard) a visible keyboard is not
// measured against this view: the inset stays until the view is back (viewWillAppear/viewDidAppear).
static CGFloat OR6ChatKeyboardInset(CGFloat current,BOOL inWindow,CGRect screen,CGRect keyboard,CGRect bounds,CGRect inView){
 CGRect shown=CGRectIntersection(screen,keyboard);
 if(CGRectIsNull(shown)||shown.size.width<1||shown.size.height<1)return 0;
 if(!inWindow)return current;
 return MIN(bounds.size.height,MAX(0,CGRectGetMaxY(bounds)-CGRectGetMinY(inView)));
}
- (BOOL)updateKeyboardInset{
 if(!self.isViewLoaded)return NO;UIWindow*w=self.view.window;CGFloat old=_keyboardHeight;
 _keyboardHeight=OR6ChatKeyboardInset(old,w!=nil,UIScreen.mainScreen.bounds,_keyboardFrame,self.view.bounds,w&&!CGRectIsNull(_keyboardFrame)?[self.view convertRect:_keyboardFrame fromView:nil]:CGRectNull);
 return _keyboardHeight!=old;
}
- (void)keyboard:(NSNotification*)note{
 NSValue*v=note.userInfo[UIKeyboardFrameEndUserInfoKey];if([note.name isEqual:UIKeyboardWillHideNotification])_keyboardFrame=CGRectNull;else if(v)_keyboardFrame=v.CGRectValue;else return;
 if(!self.isViewLoaded)return;if(!self.view.window){if([self updateKeyboardInset])[self layout];return;} // offscreen: no animation or scroll
 [self updateKeyboardInset];NSTimeInterval d=[note.userInfo[UIKeyboardAnimationDurationUserInfoKey]doubleValue];UIViewAnimationCurve c=[note.userInfo[UIKeyboardAnimationCurveUserInfoKey]integerValue];
 [UIView animateWithDuration:d delay:0 options:(UIViewAnimationOptions)(c<<16)|UIViewAnimationOptionBeginFromCurrentState animations:^{[self layout];if(_keyboardHeight>0)[self scrollToBottom:NO];}completion:nil];
}
- (void)lookChanged:(NSNotification*)n{(void)n;[_heights removeAllObjects];if(!self.isViewLoaded)return;self.view.backgroundColor=[RCTheme contentBackgroundColor];[_rows release];_rows=nil;[_cards removeAllObjects];[_cardOrder removeAllObjects];[self render:NO];} // stage/size/appearance change the cells, not the rows

#pragma mark State → UI

- (BOOL)richText{return YES;}           // chat.rich_text
- (BOOL)copyAvailable{return YES;}      // chat.copy_text / chat.select_text
- (BOOL)retryAvailable{return YES;}     // chat.retry
- (BOOL)stopAvailable{return YES;}      // chat.stop
- (BOOL)dictationAvailable{return YES;} // audio.dictation
- (BOOL)sourcesAvailable{return YES;}   // chat.sources
- (BOOL)actionBarAvailable{return YES;} // answer action bar (copy)
- (BOOL)shareAvailable{return YES;}     // chat.share_text (system share sheet)
- (BOOL)expandAvailable{return YES;}    // full-screen composer
// Priority 8 (features.json): shown whenever the composed Core really has the operations.
- (BOOL)api8:(NSString*)feature{return OR6Chat8Supports(_core,feature);}
- (BOOL)temporaryAvailable{return[self api8:OR6Chat8FTemporary]&&!_state.conversationId&&!_state.messages.count&&!_state.sending&&!_files.items.count;}
- (BOOL)editAvailable{return[self api8:OR6Chat8FEdit];}
- (BOOL)regenerateAvailable{return[self api8:OR6Chat8FRegenerate];}
- (BOOL)modelsAvailable{return[self api8:OR6Chat8FModels]&&_catalog!=nil;}
- (BOOL)statusAvailable{return[self api8:OR6Chat8FStatus];}
- (BOOL)translateAvailable{return[self api8:OR6Chat8FTranslate];}
- (BOOL)webSearchAvailable{return[self api8:OR6Chat8FWebSearch]&&!_state.temporary;}
- (BOOL)downloadAvailable{return[self api8:OR6Chat8FDownload]&&_state.conversationId&&!_state.temporary;}
static BOOL OR6ChatPickerSource(UIImagePickerControllerSourceType type){static int known[3]={-1,-1,-1};if((int)type<0||(int)type>2)return NO;if(known[type]<0)known[type]=[UIImagePickerController isSourceTypeAvailable:type]?1:0;return known[type]==1;} // asked once: renders run per stream chunk
- (BOOL)cameraAvailable{return[self api8:OR6Chat8FCamera]&&OR6ChatPickerSource(UIImagePickerControllerSourceTypeCamera);}
- (BOOL)photosAvailable{return[self api8:OR6Chat8FPhotos]&&OR6ChatPickerSource(UIImagePickerControllerSourceTypePhotoLibrary);}
- (BOOL)filesAvailable{return[self api8:OR6Chat8FFiles];}
- (BOOL)attachAvailable{return[self cameraAvailable]||[self photosAvailable]||[self filesAvailable];}
- (BOOL)plusAvailable{NSMutableArray*i=[NSMutableArray array],*a=[NSMutableArray array];[_api7 addPlusItems:i actions:a];[_api6 addPlusItems:i actions:a];return[self attachAvailable]||[self webSearchAvailable]||a.count>0;}

- (NSArray*)buildRows{
 NSMutableArray*rows=[NSMutableArray array];NSArray*messages=_state.messages;NSUInteger n=messages.count;
 // Edit / New answer: O(1) per row (a real ID in an editable branch; a variant needs an earlier user message).
 BOOL editRows=[self editAvailable]&&_state.branchEditable,regenRows=[self regenerateAvailable]&&_state.branchEditable;NSUInteger firstUser=NSNotFound;
 if(regenRows)for(NSUInteger k=0;k<n;k++)if([messages[k][@"role"]isEqual:@"user"]){firstUser=k;break;}
 // Like Messages on iOS 6: a long chat opens with its last 40 messages and an
 // "earlier" row (iOS 6 measures every row height before the first frame).
 if(!_windowSet&&_state.loaded){_windowStart=n>40?n-40:0;_windowSet=YES;}
 if(_windowStart>n)_windowStart=0;
 if(_windowStart>0)[rows addObject:@{@"kind":@"earlier",@"id":@"earlier",@"count":@(_windowStart)}];
 for(NSUInteger i=_windowStart;i<n;i++){NSDictionary*m=messages[i];BOOL last=i+1==n,lastPair=i+2>=n;
  NSMutableDictionary*r=[NSMutableDictionary dictionaryWithDictionary:m];r[@"index"]=@(i);r[@"reasoningExpanded"]=@([_reasoningOpen containsObject:r[@"id"]]);
  if([m[@"role"]isEqual:@"user"]){
   RCDeliveryState d=RCDeliverySent;NSString*meta=nil;
   if(lastPair&&_state.sending&&[_state.phase isEqual:@"dispatching"]){d=RCDeliverySending;meta=OR6L(@"Sending…");}
   else if(lastPair&&_state.uncertain){d=RCDeliveryUncertain;meta=OR6L(@"Delivery not confirmed · tap “?”");}
   else if(lastPair&&_stopped&&!_state.sending){d=RCDeliveryStopped;meta=OR6L(@"Response stopped");}
   r[@"kind"]=@"user";r[@"delivery"]=@(d);if(meta)r[@"meta"]=meta;if(editRows&&![m[@"id"]hasPrefix:@"local-"])r[@"editable"]=@YES;
  }else{
   RCAnswerState s=RCAnswerDone;NSString*note=nil;
   if(last&&(_state.sending||[m[@"pending"]boolValue]))s=[m[@"text"]length]?RCAnswerStreaming:RCAnswerThinking;
   else if(last&&_state.uncertain){s=RCAnswerCut;note=OR6L(@"The answer was not received completely");}
   else if(last&&_stopped){s=RCAnswerCut;note=OR6L(@"Response stopped");}
   else if([m[@"interrupted"]boolValue]){s=RCAnswerCut;note=OR6L(@"The web search result is unknown. It was not repeated.");}
   r[@"kind"]=@"answer";r[@"state"]=@(s);NSString*twenty=[_api20 answerRevisionForRow:r];if(twenty)r[@"twenty"]=twenty;if(note)r[@"note"]=note;
   // generation.status: only the phase the service reported, no invented reasoning text.
   if(last&&(_state.sending||_state.awaitingRemoteResponse)&&s==RCAnswerThinking){r[@"reasoning"]=[m[@"waiting"]boolValue]?OR6L(@"Waiting for the answer…"):OR6Chat8StatusTitle(_state.generationPhase)?:OR6L(@"Thinking…");}else if([m[@"reasoningSteps"]count])r[@"reasoning"]=OR6L(@"Reasoning summary");
   // A preview change (tap → loading → shown/failed) is row data: render reconfigures only this row. Not in heightKey (fixed height).
   if([m[@"images"]count]){for(NSUInteger source=i;source>0;source--){NSDictionary*u=messages[source-1];if([u[@"role"]isEqual:@"user"]&&[u[@"text"]length]){r[@"imageCaption"]=u[@"text"];break;}}NSString*p=[_api7 imagePreviewRevisionForRow:r];if(p)r[@"preview7"]=p;}
   if(last&&s==RCAnswerDone){NSString*six=[_api6 answerRevisionForRow:r isLast:YES];if(six)r[@"six"]=six;} // stage 6 card (Work handoff offer) changes the height
   if([m[@"files"]count]){NSMutableArray*d=[NSMutableArray array];for(NSDictionary*f in m[@"files"])[d addObject:[_downloads stateForFile:f[@"fileId"]message:m[@"id"]]];r[@"downloads"]=d;}
   if(s==RCAnswerDone&&regenRows&&firstUser<i&&![m[@"id"]hasPrefix:@"local-"])r[@"regenerate"]=@YES;
  }
  [rows addObject:r];
 }
 // Stage 9: a send refused before dispatch stays visible as a failed "!" bubble
 // (safe retry). Stage 10: the text simply stays in the composer.
 [rows addObjectsFromArray:[_api7 rows]]; // a running/unknown API7 generation (tool, continue, project chat)
 if([self retryAvailable]&&_actions.canRetry&&_actions.submittedText.length)[rows addObject:@{@"kind":@"user",@"id":@"failed-send",@"text":_actions.submittedText,@"delivery":@(RCDeliveryFailed),@"meta":OR6L(@"Not sent · tap “!”"),@"failed":@YES}];
 return rows;
}

- (void)configureUser:(RCUserMessageView*)v row:(NSDictionary*)r index:(NSUInteger)index{
 v.tag=(NSInteger)index;v.delegate=self;v.text=r[@"text"];v.delivery=(RCDeliveryState)[r[@"delivery"]intValue];v.metaText=r[@"meta"];v.copyMenuEnabled=[self copyAvailable];v.editMenuEnabled=[r[@"editable"]boolValue];v.tint=_state.temporary?RCBubbleGraphite:RCBubbleGreen;v.attachments=OR6Chat8BubbleAttachments(r);
 v.isAccessibilityElement=YES;v.accessibilityIdentifier=@"chat.message.user";v.accessibilityLabel=[NSString stringWithFormat:@"%@. %@",OR6L(@"You"),r[@"text"]?:@""];v.accessibilityHint=r[@"meta"];
}
- (void)faviconsLoaded:(NSNotification *)note { if (_disposed || !self.isViewLoaded) return; for (NSIndexPath *p in [_table indexPathsForVisibleRows]) { OR6ChatMessageCell *cell=(id)[_table cellForRowAtIndexPath:p]; if ([cell.item isKindOfClass:RCAnswerCardView.class] && (NSUInteger)p.row < _rows.count) { NSDictionary *row=_rows[p.row]; ((RCAnswerCardView *)cell.item).actionBar.sourceIcons=OR6ChatSourceIcons(row[@"sources"],NO); } } }
- (void)configureAnswer:(RCAnswerCardView*)c row:(NSDictionary*)r index:(NSUInteger)index{
 c.tag=(NSInteger)index;c.delegate=self;c.codeDelegate=self;c.assistantName=@"ChatGPT";
 c.textMode=[self richText]?RCAnswerTextMarkdown:RCAnswerTextPlain;c.copyCodeEnabled=YES;BOOL hasText=[[r[@"text"]stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]length]>0;c.copyMenuEnabled=hasText&&[self copyAvailable];c.selectMenuEnabled=hasText&&[self copyAvailable];
 c.state=(RCAnswerState)[r[@"state"]intValue];c.cutNoteText=r[@"note"]?:OR6L(@"The answer is incomplete");c.continueAvailable=NO;c.showsReasoning=r[@"reasoning"]!=nil;c.reasoningTitle=r[@"reasoning"];c.reasoningSteps=r[@"reasoningSteps"];c.reasoningExpanded=[r[@"reasoningExpanded"]boolValue];
 NSMutableSet *citationURLs=[NSMutableSet set];for(NSDictionary *source in r[@"sources"])if([source[@"url"]isKindOfClass:NSString.class])[citationURLs addObject:source[@"url"]];c.citationURLs=citationURLs;
 c.text=OR6ContentResolveCitations(r[@"text"],r[@"sources"]);
 NSMutableArray*parts=[NSMutableArray array];for(NSString*type in r[@"unsupported"]){BOOL image=[type rangeOfString:@"image"].location!=NSNotFound;[parts addObject:[[[RCPartPlaceholderView alloc]initWithGlyph:(image?@"photo":@"file")tile:(image?RCTileBlue:RCTileGray)title:(image?OR6L(@"Image"):OR6L(@"Answer element"))text:[RCPartPlaceholderView defaultText]]autorelease]];}
  for(NSDictionary*i in r[@"images"]){(void)i;[parts addObject:[[[RCPartPlaceholderView alloc]initWithGlyph:@"photo"tile:RCTileBlue title:OR6L(@"Image")text:[RCPartPlaceholderView defaultText]]autorelease]];}
 // Answer files: assets.download into the private vault (stage 8); elsewhere an honest placeholder.
 NSArray*files=r[@"files"];BOOL download=[self downloadAvailable]&&![r[@"id"]hasPrefix:@"local-"];
 for(NSUInteger k=0;k<files.count;k++){NSDictionary*f=files[k];
  if(!download){[parts addObject:[[[RCPartPlaceholderView alloc]initWithGlyph:@"file"tile:RCTileGray title:([f[@"name"]length]?f[@"name"]:OR6L(@"File"))text:[RCPartPlaceholderView defaultText]]autorelease]];continue;}
  NSDictionary*state=k<[r[@"downloads"]count]?r[@"downloads"][k]:@{};RCFilePartView*part=OR6Chat8FilePart(f,state);
  objc_setAssociatedObject(part.actionButton,@selector(downloadTapped:),@{@"fileId":f[@"fileId"],@"messageId":r[@"id"]},OBJC_ASSOCIATION_RETAIN_NONATOMIC);[part.actionButton addTarget:self action:@selector(downloadTapped:)forControlEvents:UIControlEventTouchUpInside];[parts addObject:part];}
 if([r[@"detached"]boolValue])[parts addObject:[[[RCPartPlaceholderView alloc]initWithGlyph:@"globe"tile:RCTileBlue title:OR6L(@"Web search")text:OR6L(@"A separate web search, not part of this conversation. The service may keep it as its own chat.")]autorelease]];
 [_api7 configureAnswerRow:r card:c parts:parts isLast:[r[@"index"]isKindOfClass:NSNumber.class]&&[r[@"index"]unsignedIntegerValue]+1==_state.messages.count measuring:c==_measureCard]; // continue, images, audio, research card; the height card never takes live views
 [_api6 configureAnswerRow:r parts:parts isLast:[r[@"index"]isKindOfClass:NSNumber.class]&&[r[@"index"]unsignedIntegerValue]+1==_state.messages.count measuring:c==_measureCard]; // stage 6: Work handoff offer
 c.partViews=parts;
 NSUInteger actions=0;BOOL lastAnswer=[r[@"index"]isKindOfClass:NSNumber.class]&&[r[@"index"]unsignedIntegerValue]+1==_state.messages.count;if(hasText&&[self actionBarAvailable]&&[self copyAvailable])actions|=RCAnswerActionCopy;if([[_api7 moreTitlesForRow:r isLast:lastAnswer]count]||[[_api6 moreTitlesForRow:r isLast:lastAnswer]count])actions|=RCAnswerActionMore;c.actionBar.speaking=[_api20 isSpeakingRow:r];if([_api20 canReadRow:r])actions|=RCAnswerActionSpeak;if((hasText&&[self shareAvailable])||[_api7 canExportImagesForRow:r])actions|=RCAnswerActionShare;actions|=RCAnswerActionMore;
 c.actionBar.actions=actions;c.actionBar.sourcesCount=[self sourcesAvailable]?[r[@"sources"]count]:0;c.actionBar.sourceIcons=OR6ChatSourceIcons(r[@"sources"],c!=_measureCard);c.actionBar.pagerCount=0;
 c.accessibilityIdentifier=@"chat.message.assistant";
}
- (NSString*)heightKey:(NSDictionary*)r{NSString*t=[r[@"kind"]isEqual:@"answer"]?OR6ContentResolveCitations(r[@"text"],r[@"sources"]):r[@"text"]?:@"";return[NSString stringWithFormat:@"%@|%@|%lu|%lu|%@|%@|%@|%lu|%lu|%@|%lu|%lu|%lu|%@|%@",r[@"kind"],r[@"id"],(unsigned long)t.length,(unsigned long)t.hash,r[@"state"]?:@"",r[@"delivery"]?:@"",r[@"meta"]?:@"",(unsigned long)[r[@"unsupported"]count],(unsigned long)[r[@"sources"]count],[NSString stringWithFormat:@"%@%@%@",r[@"reasoning"]?:@"",r[@"reasoningExpanded"]?:@NO,r[@"reasoningSteps"]?:@[]],(unsigned long)[r[@"downloads"]description].hash,(unsigned long)([r[@"images"]count]+[r[@"files"]count]),(unsigned long)[r[@"attachments"]count],r[@"note"]?:@"",[NSString stringWithFormat:@"%@%@%@",r[@"detached"]?:@"",r[@"tool7"]?:@"",[NSString stringWithFormat:@"%@%@",r[@"six"]?:@"",r[@"twenty"]?:@""]]];}
- (CGFloat)heightForRow:(NSDictionary*)r index:(NSUInteger)i{
 if([r[@"kind"]isEqual:@"earlier"])return 52;
 NSString*key=[self heightKey:r];NSNumber*cached=_heights[key];if(cached)return cached.floatValue;CGFloat w=_table.bounds.size.width?:320,h;
 if([r[@"kind"]isEqual:@"user"]){[self configureUser:_measureUser row:r index:i];h=[_measureUser heightForWidth:w];}else{[self configureAnswer:_measureCard row:r index:i];h=[_measureCard heightForWidth:w];}
 // Streaming text changes every chunk: do not grow the cache with intermediate keys.
 if(![r[@"state"]isEqual:@(RCAnswerStreaming)])_heights[key]=@(h);return h;
}

- (void)renderTitle{
 if(!_titleView)return;NSString*title=_state.temporary?OR6L(@"Temporary chat"):_conversationTitle.length?_conversationTitle:(_state.conversationId?OR6L(@"Chat"):OR6L(@"New chat"));
 BOOL auth=[_summary[@"authenticated"]boolValue];NSString*sub=nil;BOOL caret=NO;
 if(_state.loaded&&_sessionReady&&[self modelsAvailable]){
  if(auth&&!_catalog.loaded&&!_catalog.busy&&!_catalog.issue){_catalog.delegate=self;[_catalog load];}
  if(_catalog.loaded){sub=_catalog.title?:[_catalog titleForModel:_catalog.catalogDefaultModelId effort:nil];caret=sub.length>0;}
 }
 [_titleView setTitle:title subtitle:sub lamp:RCLampOK showsLamp:NO caret:caret];_titleView.variant=[self barVariant];_titleView.accessibilityTraits=caret?UIAccessibilityTraitButton:UIAccessibilityTraitStaticText;_titleView.accessibilityHint=caret?OR6L(@"Chooses the model for the next messages"):nil;
 _titleView.accessibilityLabel=sub?[NSString stringWithFormat:@"%@, %@",title,sub]:title;_titleView.accessibilityIdentifier=@"chat.conversation.status";
 if(_state.sending&&!_clock){_clock=[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(clockTick)userInfo:nil repeats:YES];}
 else if(!_state.sending&&_clock){[_clock invalidate];_clock=nil;}
}
- (void)clockTick{[self renderTitle];if(_composer.dictating&&[_dictation.phase isEqual:@"recording"])_composer.dictationView.elapsed=_dictationStarted?-_dictationStarted.timeIntervalSinceNow:0;}

- (void)renderBanner{
 BOOL auth=[_summary[@"authenticated"]boolValue];NSString*text=nil,*action=nil;RCBannerKind kind=RCBannerError;SEL sel=NULL;
 if(_summary&&!auth&&![_summary[@"state"]isEqual:@"validating"]){kind=RCBannerWarning;text=OR6L(@"The session has expired. Your draft and chats are safe.");action=OR6L(@"Log in");sel=@selector(signIn);}
 else if(_state.uncertain&&!_state.sending){kind=RCBannerWarning;text=_notice?[_notice stringByAppendingString:OR6L(@" The send result is unknown.")]:OR6L(@"The send result is unknown. Check it before sending again.");action=OR6L(@"Check");sel=@selector(reconcile);}
 else if([_api7 runUncertain]&&!_state.sending){kind=RCBannerWarning;text=OR6L(@"The result is unknown. It is not sent again; check it before continuing.");action=OR6L(@"Check");sel=@selector(api7Reconcile);}
 else if(_notice&&_state.rejectedRequest&&!_state.sending){kind=RCBannerError;text=_notice;action=OR6L(@"Try again");sel=@selector(repeatRejected);} // proven not dispatched: a new explicit operation
 else if(_notice){kind=RCBannerError;text=_notice;if(!_state.loaded&&_state.conversationId){action=OR6L(@"Retry");sel=@selector(loadConversation);}}
 (void)0;
 if(!text){[_banner removeFromSuperview];[_banner release];_banner=nil;return;}
 if(!_banner||_banner.kind!=kind||![[_banner.actionButton titleForState:UIControlStateNormal]?:@"" isEqual:action?:@""]){[_banner removeFromSuperview];[_banner release];_banner=[[RCBannerView alloc]initWithKind:kind text:text actionTitle:action];if(sel)[_banner.actionButton addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];_banner.actionButton.accessibilityIdentifier=sel==@selector(reconcile)?@"chat.reconcile":sel==@selector(repeatRejected)?@"chat.repeat":@"chat.banner.action";[self.view addSubview:_banner];}
 _banner.text=text;_banner.accessibilityIdentifier=@"chat.banner";
}

- (void)renderComposer{
 BOOL files=_files.items.count>0;BOOL blocked=!_sessionReady||!_state.loaded||_busy||_state.sending||_state.uncertain||_state.remoteGenerationActive||_api7.running||[_actions.diagnostics[@"blocked"]boolValue]||_state.text.length>16000||(files&&[_files blocksSend])||(files&&_webSearch);
 NSString*draft=[self displayDraft];if(![_composer.text isEqual:draft]&&!_composer.textView.isFirstResponder)_composer.text=draft;
 _composer.showsPlus=[self plusAvailable];_composer.plusButton.enabled=_sessionReady&&!_state.sending&&!_state.uncertain;_composer.plusButton.accessibilityIdentifier=@"chat.plus";_composer.voiceAvailable=OR6ChatVoice8Available(_core)&&!blocked&&!_state.temporary&&!files&&!_webSearch&&!_api7.wantsSend&&[_dictation.phase isEqual:@"idle"];_composer.expandAvailable=[self expandAvailable];
 NSArray*items=_files.items;NSString*signature=[NSString stringWithFormat:@"%@|%@",items,_webSearch&&files?@"conflict":_files.notice?:@""];
 if(![signature isEqual:_traySignature]){[_traySignature release];_traySignature=[signature copy];_composer.attachments=OR6Chat8TrayAttachments(items);_composer.trayNote=_webSearch&&files?OR6L(@"Web search sends text only. Remove the files or turn web search off."):_files.notice;}
 if(_webSearch!=_chipShown){_chipShown=_webSearch;[_composer setModeChipTitle:_webSearch?OR6L(@"Web search"):nil glyph:@"globe" color:RCChipBlue];if(!_webSearch)[_api7 refreshModeChip];}
 _composer.dictationView.cancelsRecognition=[self api8:OR6Chat8FDictationCancel];
 _composer.dictationView.failureText=_dictation.uncertain?OR6L(@"The recognition result is unknown. It is not repeated, so the recording is not uploaded twice. Cancel deletes it."):nil;
 _composer.showsMic=[self dictationAvailable];_composer.micButton.enabled=_sessionReady&&_state.loaded&&!_busy&&!_state.sending&&!_state.uncertain&&[_dictation.phase isEqual:@"idle"]&&!_dictation.busy;
 _composer.stopAvailable=([self stopAvailable]&&(_actions.canStop||_stopRequest!=nil))||_api7.running;_composer.streaming=_state.sending||_api7.running;_composer.preparing=_busy&&_sendRequested;
 // beginSend requires non-whitespace text (API text minLength 1): files alone do not make Send available.
 if(![[_composer.text?:@"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]length])blocked=YES;
 _composer.sendBlocked=blocked;_composer.editable=!_state.uncertain;
 OR6Chat9ApplyControlAccessibility(_composer.sendButton,_composer.sendMode==RCSendModeStop?OR6L(@"Stop generating"):OR6L(@"Send"),_composer.sendMode==RCSendModeStop?OR6L(@"Asks ChatGPT to stop the response"):@"",_composer.sendEnabled);
 _composer.sendButton.accessibilityIdentifier=_composer.sendMode==RCSendModeStop?@"chat.stop":@"chat.send";
 OR6Chat9ApplyControlAccessibility(_composer.micButton,OR6L(@"Dictation"),OR6L(@"Opens dictation. Recording starts with a separate button"),_composer.micButton.enabled);
}

- (void)render:(BOOL)scroll{
 // While a safe Retry waits, its reserved draft keeps temporary/model/files (the journal replays them).
 OR6Chat8SyncRetryLock(_state,_actions,_files,[self retryAvailable]);
 if(!self.isViewLoaded)return;
 NSArray*rows=[self buildRows];BOOL structural=rows.count!=_rows.count;
 if(!structural)for(NSUInteger i=0;i<rows.count;i++){NSDictionary*a=rows[i],*b=_rows[i];if(![a[@"id"]isEqual:b[@"id"]]||![a[@"kind"]isEqual:b[@"kind"]]){structural=YES;break;}}
 NSArray*old=[_rows retain];[_rows release];_rows=[rows retain];
 if(structural||!old)[_table reloadData];
 else{
  NSMutableArray*changed=[NSMutableArray array];for(NSUInteger i=0;i<rows.count;i++)if(![rows[i]isEqual:old[i]])[changed addObject:[NSIndexPath indexPathForRow:(NSInteger)i inSection:0]];
  if(changed.count){for(NSIndexPath*p in changed){OR6ChatMessageCell*cell=(id)[_table cellForRowAtIndexPath:p];if(cell)[self configureCell:cell index:(NSUInteger)p.row];}
   [UIView setAnimationsEnabled:NO];[_table beginUpdates];[_table endUpdates];[UIView setAnimationsEnabled:YES];}
 }
 [old release];
 BOOL loadingHistory=_state.conversationId&&!_state.loaded&&!_notice&&_sessionReady;
 _table.hidden=loadingHistory;_historySpinner.activityIndicatorViewStyle=[RCTheme isDark]?UIActivityIndicatorViewStyleWhite:UIActivityIndicatorViewStyleGray;
 if(loadingHistory)[_historySpinner startAnimating];else[_historySpinner stopAnimating];
 _empty.hidden=rows.count>0||_state.conversationId!=nil;_empty.showsTemporaryToggle=[self temporaryAvailable];_empty.temporarySwitch.on=_state.temporary;
 if(_empty.temporary!=_state.temporary){_empty.temporary=_state.temporary;_empty.title=_state.temporary?OR6L(@"Temporary chat"):OR6L(@"What can I help with?");RCEmptyChatViewSetMessage(_empty);}
 _refresh.enabled=_sessionReady&&_state.conversationId!=nil&&!_busy&&!_state.sending&&!_state.uncertain&&!_api7.running;_refresh.hidden=_state.conversationId==nil;BOOL playerShown=_readAloud.presented;[_api20 readAloudBar];[self renderTitle];[self renderBanner];[self renderComposer];[self renderActionsButton];if(playerShown!=_readAloud.presented&&self.view.window)[UIView animateWithDuration:[RCReadAloudBar presentationDuration]delay:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionCurveEaseInOut animations:^{[self layout];[_readAloud layoutIfNeeded];}completion:nil];else[self layout]; // read-aloud player slides in/out with the chat
 if(scroll||_stickToBottom)[self scrollToBottom:NO];
}
- (void)scrollToBottom:(BOOL)animated{NSInteger n=[_table numberOfRowsInSection:0];if(n>0)[_table scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:n-1 inSection:0]atScrollPosition:UITableViewScrollPositionBottom animated:animated];}
- (void)scrollViewDidScroll:(UIScrollView*)s{if(s!=_table||!s.isDragging)return;_stickToBottom=s.contentOffset.y+s.bounds.size.height>=s.contentSize.height-24;}
- (void)scrollViewWillBeginDragging:(UIScrollView*)s{if(s==_table&&_composer.textView.isFirstResponder&&!_composer.text.length)[_composer resignFirstResponder];}

#pragma mark Table

- (NSInteger)tableView:(UITableView*)t numberOfRowsInSection:(NSInteger)s{(void)t;(void)s;return (NSInteger)_rows.count;}
- (CGFloat)tableView:(UITableView*)t heightForRowAtIndexPath:(NSIndexPath*)p{(void)t;return[self heightForRow:_rows[(NSUInteger)p.row]index:(NSUInteger)p.row];}
- (void)configureCell:(OR6ChatMessageCell*)cell index:(NSUInteger)i{
 NSDictionary*r=_rows[i];
 if([r[@"kind"]isEqual:@"earlier"]){
  UIView*box=cell.item;UIButton*b=(UIButton*)[box viewWithTag:77];
  if(!b){box=[[[UIView alloc]initWithFrame:cell.contentView.bounds]autorelease];b=[RCButton buttonWithStyle:RCButtonStylePill title:OR6L(@"Load earlier messages")];b.tag=77;[b addTarget:self action:@selector(showEarlier)forControlEvents:UIControlEventTouchUpInside];b.accessibilityIdentifier=@"chat.messages.earlier";[box addSubview:b];cell.item=box;}
  CGSize ts=[[b titleForState:UIControlStateNormal]sizeWithFont:b.titleLabel.font];b.frame=CGRectMake(floor(((_table.bounds.size.width?:320)-ts.width-36)/2),13,ts.width+36,26);return;
 }
 if([r[@"kind"]isEqual:@"user"]){RCUserMessageView*v=(id)cell.item;if(![v isKindOfClass:RCUserMessageView.class]){v=[[[RCUserMessageView alloc]initWithFrame:cell.contentView.bounds]autorelease];cell.item=v;}[self configureUser:v row:r index:i];}
 else{
  // Built answer cards are kept per message (up to 30): scrolling back does not rebuild Markdown.
  NSString*identifier=r[@"id"];RCAnswerCardView*c=identifier?_cards[identifier]:nil;
  if(!c){c=[[[RCAnswerCardView alloc]initWithFrame:cell.contentView.bounds]autorelease];if(identifier){_cards[identifier]=c;[_cardOrder addObject:identifier];while(_cardOrder.count>30){NSString*old=_cardOrder[0];RCAnswerCardView*o=_cards[old];if(!o.window){[_cards removeObjectForKey:old];}[_cardOrder removeObjectAtIndex:0];}}}
  else{[_cardOrder removeObject:identifier];[_cardOrder addObject:identifier];}
  if(c.superview&&c.superview!=cell.contentView){for(UITableViewCell*other in _table.visibleCells)if([other isKindOfClass:OR6ChatMessageCell.class]&&((OR6ChatMessageCell*)other).item==c)((OR6ChatMessageCell*)other).item=nil;[c removeFromSuperview];}
  cell.item=c;[self configureAnswer:c row:r index:i];}
 [cell setNeedsLayout];
}
- (UITableViewCell*)tableView:(UITableView*)t cellForRowAtIndexPath:(NSIndexPath*)p{
 NSString*identifier=_rows[(NSUInteger)p.row][@"kind"];OR6ChatMessageCell*cell=[t dequeueReusableCellWithIdentifier:identifier];if(!cell)cell=[[[OR6ChatMessageCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier]autorelease];
 [self configureCell:cell index:(NSUInteger)p.row];return cell;
}
- (void)showEarlier{
 if(!_windowStart)return;CGFloat oldHeight=_table.contentSize.height,offset=_table.contentOffset.y;_windowStart=_windowStart>40?_windowStart-40:0;_stickToBottom=NO;
 [_rows release];_rows=nil;[self render:NO];[_table layoutIfNeeded];[_table setContentOffset:CGPointMake(0,MAX(-_table.contentInset.top,offset+_table.contentSize.height-oldHeight))animated:NO];
}
- (NSDictionary*)rowForView:(UIView*)v{NSUInteger i=(NSUInteger)v.tag;return i<_rows.count?_rows[i]:nil;}

// The field clears on Send, like Messages. The state keeps the submitted text
// as the draft until the receipt: a send refused before dispatch returns it to
// the field (stage 10) or to the failed "!" bubble (stage 9, safe retry).
- (NSString*)displayDraft{
 NSString*t=_state.text?:@"";NSString*submitted=_actions.submittedText;if(!submitted.length||![t isEqual:submitted])return t;
 if(_state.sending||_state.uncertain||([self retryAvailable]&&_actions.canRetry))return @"";return t;
}

#pragma mark Requests (unchanged Core contract)

// The catalog choice (model + thinking effort) goes into the draft and every new generation
// request; the state refuses it while a safe Retry keeps the reserved draft's options.
- (void)syncModelChoice{BOOL m=[self modelsAvailable];[_state setModelId:m?_catalog.sendModelId:@"web-current"thinkingEffort:m?_catalog.sendThinkingEffort:nil];}
- (void)prepareDraft{
 if(_busy||_draftPrepared)return;[self syncModelChoice];_busy=YES;[self render:NO];NSUInteger epoch=++_epoch;__block BOOL finished=NO;
 id<OR6APITask>task=[_core perform:@"messages.newDraft"parameters:[_state draftRequest]event:nil completion:^(NSDictionary*result,NSError*error){finished=YES;if(epoch!=_epoch)return;[_request release];_request=nil;_busy=NO;_draftPrepared=result&&!error;if(_draftPrepared)_files.draftId=_state.draftId;BOOL send=_sendRequested&&_draftPrepared;_sendRequested=NO;if(error)[self setNotice:OR6ChatErrorText(error)];[self render:NO];if(send)[self sendMessage];}];
 if(!finished&&epoch==_epoch)_request=[task retain];
}
- (void)setNotice:(NSString*)notice{if(notice==_notice||[notice isEqual:_notice])return;[_notice release];_notice=[notice copy];if(notice&&self.view.window)UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,notice);}
- (void)refreshConversation:(RCRefreshControl*)control {
 if(_busy||_state.sending||_state.uncertain||_api7.running||!_sessionReady||!_state.conversationId){[control endRefreshing];return;}
 _historyRefreshes++;_historyPolls=0;[self loadConversation];
}
- (void)pollRemoteHistory:(NSTimer*)timer{(void)timer;_historyPoll=nil;if(!self.view.window||_disposed||!_sessionReady||!_state.awaitingRemoteResponse)return;_historyPolls++;[self loadConversation];}
- (void)scheduleRemoteHistory{
 [_historyPoll invalidate];_historyPoll=nil;if(!_state.awaitingRemoteResponse||_historyPolls>=4||!self.view.window||_disposed||!_sessionReady)return;
 const NSTimeInterval delays[]={5,10,20,30};_historyPoll=[NSTimer scheduledTimerWithTimeInterval:delays[_historyPolls]target:self selector:@selector(pollRemoteHistory:)userInfo:nil repeats:NO];
}
- (void)loadConversation{
 if(_busy||_state.sending||_state.uncertain||!_state.conversationId)return;[_historyPoll invalidate];_historyPoll=nil;_historyReads++;_busy=YES;[self setNotice:nil];[self render:NO];NSUInteger epoch=++_epoch;__block BOOL finished=NO;NSString*identifier=[[_state.conversationId copy]autorelease];
 id<OR6APITask>task=[_core perform:@"history.get"parameters:@{@"conversationId":identifier}event:nil completion:^(NSDictionary*result,NSError*error){finished=YES;if(epoch!=_epoch)return;[_request release];_request=nil;_busy=NO;[_refresh endRefreshing];BOOL hydrating=_hydrating;_hydrating=NO;
  _windowSet=NO;if(error||![_state acceptConversation:result]){[self setNotice:error?OR6ChatErrorText(error):OR6L(@"Could not read this conversation.")];if(hydrating)_recoveryHydrate=YES;} // rows (partial) stay; next activation reads again
  else{_historyReadSuccesses++;if([result[@"title"]isKindOfClass:NSString.class])self.conversationTitle=result[@"title"];[self importDeploymentDraft];[_api6 conversationLoaded];[self scheduleRemoteHistory];}
  [self render:_stickToBottom];[_host conversationDidChange:self];[NSNotificationCenter.defaultCenter postNotificationName:@"OR6ChatUIChanged"object:self];}];
 if(!finished&&epoch==_epoch)_request=[task retain];
}
- (void)sendMessage{
 if(_busy||!_sessionReady)return;_state.text=_composer.text;
 if([_api7 wantsSend]){if(_files.items.count){[self setNotice:OR6L(@"This mode sends text only. Remove the files first.")];[self render:NO];return;}[_api7 send];return;} // explicit tool / project chat operation, never messages.send
 if(_webSearch&&[self webSearchAvailable]){[self searchWeb];return;} // explicit mode: search.web instead of messages.send
 [self syncModelChoice];
 if(_files.items.count){[_files checkStatus];if([_files blocksSend]||![_files.draftId isEqual:_state.draftId]){[self setNotice:OR6L(@"Wait until the files are ready, or remove the ones that were not uploaded.")];[self render:NO];return;}_state.attachments=[_files attachedAssetIds];_state.sentAttachments=[_files sentItems];}
 else{_state.attachments=@[];_state.sentAttachments=nil;}
 if(!_draftPrepared){if(![_state.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length||_state.text.length>16000)return;_sendRequested=YES;[self prepareDraft];return;}
 NSDictionary*parameters=[_state beginSend];if(!parameters){[self setNotice:OR6L(@"Enter a message of up to 16,000 characters.")];[self render:NO];return;}
 [self performMessage:@"messages.send"parameters:parameters];
}
- (void)performMessage:(NSString*)operation parameters:(NSDictionary*)parameters{
 BOOL planned=[operation isEqual:@"messages.edit"]||[operation isEqual:@"messages.regenerate"];
 if([operation isEqual:@"messages.send"]||planned)[_actions beganSend:parameters]; // Stop observes planned edit/regenerate too
 if(![operation isEqual:@"messages.reconcile"]){[_recoveryOperation release];_recoveryOperation=[parameters[@"operationId"]copy];_recoveryOff=NO;_recoveryLatched=NO;[_pendingRecovery release];_pendingRecovery=nil;
  // A new send/retry/edit is a new operation: Stop and its "stopped" mark of the old one no longer apply
  // (this was inside the comment above before; reconcile keeps them as before).
  _stopEpoch++;[_stopRequest cancel];[_stopRequest release];_stopRequest=nil;_stopped=NO;[_stopIssue release];_stopIssue=nil;}
 _busy=YES;[self setNotice:nil];[_sendStarted release];_sendStarted=[NSDate new];_stickToBottom=YES;if(!planned&&[_composer.text isEqual:_actions.submittedText])_composer.text=@"";[self render:YES];NSUInteger epoch=++_epoch;__block BOOL finished=NO;
 id<OR6APITask>task=[_core perform:operation parameters:parameters event:^(NSDictionary*event){if(epoch!=_epoch)return;[_actions receivedEvent:event];if([_state receiveEvent:event]){if(_state.conversationTitle)self.conversationTitle=_state.conversationTitle;[self scheduleStreamRender];}}
  completion:^(NSDictionary*result,NSError*error){finished=YES;if(epoch!=_epoch)return;[_request release];_request=nil;_busy=NO;[_streamTimer invalidate];_streamTimer=nil;
   [_state finishReceipt:result error:error];[_actions finished:result error:error];
   // Retry replays only an ordinary Send; an edit/regenerate proven not dispatched is repeated as a new operation (banner).
   if(planned)[_actions beganSend:@{}];
   BOOL completed=[_state.phase isEqual:@"completed"],branch=completed&&([_state.kind isEqual:@"edit"]||[_state.kind isEqual:@"regenerate"]);
   if(completed&&[_state.kind isEqual:@"send"]){_draftPrepared=NO;if(_files.items.count)[_files clearAfterSend];}if(error)[self setNotice:OR6ChatErrorText(error)];
   if(![_composer.text isEqual:[self displayDraft]]&&(!_composer.textView.isFirstResponder||!_composer.text.length))_composer.text=[self displayDraft];
   [self render:YES];[_host conversationDidChange:self];[NSNotificationCenter.defaultCenter postNotificationName:@"OR6ChatUIChanged"object:self];
   if([operation isEqual:@"messages.reconcile"]&&[_state.phase isEqual:@"completed"])[self hydrateRecoveredHistory];
   if(branch&&!_state.temporary)[self loadConversation];}]; // the service's new branch replaces the local rows
 if(!finished&&epoch==_epoch)_request=[task retain];
}
// Stream chunks arrive faster than a long Markdown answer can be laid out on an
// iPhone 5: coalesce them to at most ~6 renders per second.
- (void)scheduleStreamRender{if(_streamTimer)return;_streamTimer=[NSTimer scheduledTimerWithTimeInterval:.16 target:self selector:@selector(streamTick)userInfo:nil repeats:NO];}
- (void)streamTick{_streamTimer=nil;[self render:NO];}
- (void)retryMessage{if(_busy||!_sessionReady)return;NSDictionary*p=[_actions beginRetry];if(p)[self performMessage:@"messages.retry"parameters:p];}
- (void)stopMessage{
 if(!_sessionReady||_stopRequest)return;NSDictionary*p=[_actions beginStop];if(!p)return;_recoveryOff=YES;[_pendingRecovery release];_pendingRecovery=nil;/* explicit Stop ends automatic recovery */NSUInteger epoch=++_stopEpoch,sendEpoch=_epoch;__block BOOL done=NO;
 id<OR6APITask>task=[_core perform:@"messages.stop"parameters:p event:nil completion:^(NSDictionary*r,NSError*e){done=YES;if(epoch!=_stopEpoch)return;[_stopRequest release];_stopRequest=nil;if(sendEpoch!=_epoch)return;
  [_stopIssue release];_stopIssue=[(e.userInfo[@"code"]?:@"")copy];BOOL confirmed=!e&&[r[@"serverStopConfirmed"]boolValue];_stopped=confirmed;
  [self setNotice:e?OR6ChatErrorText(e):confirmed?(_state.temporary?OR6L(@"ChatGPT confirmed that the response stopped."):OR6L(@"ChatGPT confirmed that the response stopped. Check that the conversation was saved.")):OR6L(@"The response stop was not confirmed.")];
  [self render:NO];[NSNotificationCenter.defaultCenter postNotificationName:@"OR6ChatUIChanged"object:self];}];
 if(!done&&epoch==_stopEpoch)_stopRequest=[task retain];[self render:NO];
}
// Check (banner / "?" badge): the same history-only messages.reconcile the
// automatic recovery uses; its state/message events update the partial answer.
- (void)reconcile{
 if(_busy||_state.sending||!_state.uncertain||!_sessionReady)return;NSDictionary*p=[_state beginRecovery];if(p)[self performMessage:@"messages.reconcile"parameters:p];
}

#pragma mark Priority 8: edit, new answer, explicit web search, status

- (void)editMessage:(NSString*)identifier text:(NSString*)text{
 if(_busy||!_sessionReady)return;[self syncModelChoice];NSDictionary*p=[_state beginEditMessage:identifier text:text];
 if(!p){[self setNotice:OR6L(@"This message cannot be edited now.")];[self render:NO];return;}
 [self performMessage:@"messages.edit"parameters:p]; // the typed draft stays in the field
}
- (void)regenerate:(NSString*)identifier{
 if(_busy||!_sessionReady)return;[self syncModelChoice];NSDictionary*p=[_state beginRegenerate:identifier];if(p)[self performMessage:@"messages.regenerate"parameters:p];
}
- (void)repeatRejected{
 if(_busy||!_sessionReady)return;[self syncModelChoice];NSString*operation=[[_state.rejectedRequest[@"operation"]copy]autorelease];NSDictionary*p=[_state beginRepeatRejected];if(p)[self performMessage:operation parameters:p];
}
- (void)searchWeb{
 if(_busy||!_sessionReady)return;
 if(_files.items.count){[self renderComposer];return;}
 [self syncModelChoice]; // the title's model/effort also run the search
 NSDictionary*p=[_state beginWebSearch];if(!p){[self setNotice:OR6L(@"Enter a search query of up to 16,000 characters.")];[self render:NO];return;}
 _busy=YES;[self setNotice:nil];[_sendStarted release];_sendStarted=[NSDate new];_stickToBottom=YES;[self render:YES];NSUInteger epoch=++_epoch;__block BOOL finished=NO;
 [self startStatusPoll];
 id<OR6APITask>task=[_core perform:@"search.web"parameters:p event:nil completion:^(NSDictionary*r,NSError*e){finished=YES;if(epoch!=_epoch)return;[_request release];_request=nil;_busy=NO;[self stopStatusPoll];
  [_state finishWebSearch:r error:e];if(!e)_webSearch=NO; // the mode is per message
  [self setNotice:e?([e.userInfo[@"dispatch"]isEqual:@"none"]?OR6ChatErrorText(e):OR6L(@"The web search may still have run. It was not repeated; check your chats before searching again.")):nil];
  if(![_composer.text isEqual:[self displayDraft]]&&(!_composer.textView.isFirstResponder||!_composer.text.length))_composer.text=[self displayDraft];
  [self render:YES];[_host conversationDidChange:self];[NSNotificationCenter.defaultCenter postNotificationName:@"OR6ChatUIChanged"object:self];
  }]; // standalone: this chat's branch and parent are untouched, nothing to read back
 if(!finished&&epoch==_epoch)_request=[task retain];
}
// search.web has no event stream: poll the local generation.status (no network) for its truthful phase.
- (void)startStatusPoll{[self stopStatusPoll];if([self statusAvailable])_statusPoll=[[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(pollStatus)userInfo:nil repeats:YES]retain];}
- (void)stopStatusPoll{[_statusPoll invalidate];[_statusPoll release];_statusPoll=nil;}
- (void)pollStatus{
 NSString*op=_state.operationId;if(!_state.sending||!op){[self stopStatusPoll];return;}
 [_core perform:@"generation.status"parameters:@{@"operationId":op}event:nil completion:^(NSDictionary*r,NSError*e){if(e||![op isEqual:_state.operationId])return;if([_state receiveEvent:@{@"name":@"status",@"payload":r}])[self render:NO];}];
}

#pragma mark Recovery of an interrupted send (question + partial persisted by the host)

static BOOL OR6RecoveryString(id v){return[v isKindOfClass:NSString.class]&&[(NSString*)v length]>0;}
- (BOOL)recoverySessionReady{return _sessionReady&&(!_summary||[_summary[@"authenticated"]boolValue]);}
- (BOOL)matchesRecoverySnapshot:(NSDictionary*)s{
 if(![s isKindOfClass:NSDictionary.class]||!OR6RecoveryString(s[@"operationId"]))return NO;
 return[_state.operationId isEqual:s[@"operationId"]]||[_recoveryOperation isEqual:s[@"operationId"]];
}
- (BOOL)restoreRecoverySnapshot:(NSDictionary*)s{
 if(_disposed||![s isKindOfClass:NSDictionary.class]||!OR6RecoveryString(s[@"operationId"])||_busy||_request||_state.sending||_state.uncertain||_state.messages.count||_state.text.length)return NO;
 if(_state.conversationId&&![_state.conversationId isEqual:s[@"conversationId"]])return NO;
 if(![_state restoreRecoverySnapshot:s])return NO;
 [_recoveryOperation release];_recoveryOperation=[s[@"operationId"]copy];_recoveryOff=NO;_draftPrepared=NO;_stopped=NO;_windowSet=NO;
 // The 2-row preview lacks older messages: read the full history once the send is final.
 _recoveryHydrate=_state.conversationId!=nil&&!_state.temporary; // a temporary chat is never read back from history
 // Stop stays available for the recovered operation (no network here).
 if(_state.operationId&&[s[@"request"]isKindOfClass:NSDictionary.class]){NSMutableDictionary*p=[[s[@"request"]mutableCopy]autorelease];p[@"operationId"]=_state.operationId;[_actions beganSend:p];}
 [self setNotice:nil];_stickToBottom=YES;[self render:YES];[_host conversationDidChange:self];[NSNotificationCenter.defaultCenter postNotificationName:@"OR6ChatUIChanged"object:self];
 if(!_state.operationId&&self.isViewLoaded)[self hydrateRecoveredHistory]; // completed: final rows from history (else viewDidLoad does it)
 return YES;
}
- (BOOL)resumeRecoverySnapshot:(NSDictionary*)s{
 if(_disposed||![self matchesRecoverySnapshot:s])return NO;
 if(!_state.operationId){[self hydrateRecoveredHistory];return NO;} // already final
 // autoResume NO: keep the partial and the Check banner; never re-send.
 BOOL wanted=[s[@"autoResume"]boolValue]||([s[@"completed"]boolValue]&&_state.uncertain);
 if(!wanted||_recoveryOff||_recoveryLatched||!_state.conversationId||![_state.operationId isEqual:s[@"operationId"]])return NO;
 if(![self recoverySessionReady]){[_pendingRecovery release];_pendingRecovery=[s copy];return NO;}
 if(_busy||_state.sending||!_state.uncertain||[_actions.diagnostics[@"blocked"]boolValue])return NO;
 NSDictionary*p=[_state beginRecovery];if(!p)return NO;
 _recoveryLatched=YES;[_pendingRecovery release];_pendingRecovery=nil;
 [self performMessage:@"messages.reconcile"parameters:p];return YES;
}
- (void)hydrateRecoveredHistory{
 if(!_recoveryHydrate||_hydrateLatched||!_state.conversationId||_busy||_state.sending||_state.uncertain||![self recoverySessionReady])return;
 _recoveryHydrate=NO;_hydrateLatched=YES;_hydrating=YES;[self loadConversation]; // its completion clears _hydrating
}

#pragma mark Composer

- (void)composerViewTextDidChange:(RCComposerView*)v{_state.text=v.text;[self renderComposer];}
- (void)composerView:(RCComposerView*)v didChangeHeight:(CGFloat)h{(void)v;(void)h;[UIView animateWithDuration:.15 animations:^{[self layout];}];if(_stickToBottom)[self scrollToBottom:NO];}
- (void)composerViewDidTapSend:(RCComposerView*)v{(void)v;[self sendMessage];}
- (void)composerViewDidTapStop:(RCComposerView*)v{(void)v;if([_api7 stop])return;[self stopMessage];}
- (void)composerViewDidTapVoice:(RCComposerView*)view{
 (void)view;if(!_composer.voiceAvailable||_state.text.length||_state.sending||_busy)return;
 [_composer resignFirstResponder];[_api20 stopPlayback];[self syncModelChoice];
 if(!_voice8){_voice8=[[OR6ChatVoice8 alloc]initWithCore:_core];_voice8.host=self;}
 [self presentViewController:_voice8 animated:YES completion:^{[_voice8 beginInConversation:_state.conversationId model:_state.modelId effort:_state.thinkingEffort];}];
}
- (void)voice8:(OR6ChatVoice8*)voice endedInConversation:(NSString*)conversation{
 (void)voice;[self dismissViewControllerAnimated:YES completion:^{
  if(conversation&&!_state.conversationId&&!_state.text.length){[_state release];_state=[[OR6ChatConversationState alloc]initWithConversationId:conversation];_draftPrepared=NO;}
  if([conversation isEqual:_state.conversationId]){[self loadConversation];[_host conversationDidChange:self];}
  [self render:NO];
 }];
}
- (void)composerViewDidTapMic:(RCComposerView*)v{(void)v;if([_api7 streamingAvailable]){[_api20 stopPlayback];[_composer resignFirstResponder];[_api7 startStreaming];return;}[self dictationStart];}
// «+»: camera / photos / Open In files (assets.acquire → upload → attach), explicit web search, translation.
- (void)composerViewDidTapPlus:(RCComposerView*)v{
 (void)v;if(![self plusAvailable])return;[_composer resignFirstResponder];NSMutableArray*items=[NSMutableArray array],*actions=[NSMutableArray array];
 if([self attachAvailable])[_files loadLimits];
 if([self cameraAvailable]){[items addObject:[RCActivityItem itemWithTitle:OR6L(@"Camera")glyph:@"camera" tile:RCTileGraphite]];[actions addObject:@"camera"];}
 if([self photosAvailable]){[items addObject:[RCActivityItem itemWithTitle:OR6L(@"Photos")glyph:@"photo" tile:RCTileBlue]];[actions addObject:@"photo_library"];}
 if([self filesAvailable]){[items addObject:[RCActivityItem itemWithTitle:OR6L(@"Files")glyph:@"file" tile:RCTileGray]];[actions addObject:@"document"];}
 if([self webSearchAvailable]){RCActivityItem*i=[RCActivityItem itemWithTitle:OR6L(@"Web search")glyph:@"globe" tile:RCTileTeal];i.on=_webSearch;[items addObject:i];[actions addObject:@"search"];}
 [_api7 addPlusItems:items actions:actions];[_api6 addPlusItems:items actions:actions];
 [_plusActions release];_plusActions=[actions copy];
 NSString*title=[self attachAvailable]?[NSString stringWithFormat:OR6L(@"Up to %lu files · %@ each"),(unsigned long)([_files.limits[@"maxCount"]unsignedIntegerValue]?:4),OR6Chat8Bytes([_files.limits[@"maxBytes"]unsignedLongLongValue]?:8*1024*1024)]:nil;
 RCActivitySheet*sheet=[[[RCActivitySheet alloc]initWithTitle:title items:items]autorelease];sheet.delegate=self;sheet.accessibilityIdentifier=@"chat.plus.sheet";[sheet showInView:self.view.window?:self.view];
}
- (void)activitySheet:(RCActivitySheet*)sheet didSelectItemAtIndex:(NSUInteger)index{
 (void)sheet;if(index>=_plusActions.count)return;NSString*action=_plusActions[index];
 if([action isEqual:@"search"]){if(_api7.toolMode||_api7.sendMode)[_api7 clearToolMode];_webSearch=!_webSearch;[self renderComposer];[self layout];UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,_webSearch?OR6L(@"Web search is on for the next message"):OR6L(@"Web search is off"));return;}
 if([action isEqual:@"translate"]){[self openTranslation:_composer.text];return;}
 if([action isEqual:@"library"]&&!_draftPrepared&&!_busy)[self prepareDraft]; // Library attaches to this chat's draft
 if(([action hasPrefix:@"tool:"]||[action hasPrefix:@"six:"])&&_webSearch){_webSearch=NO;[self renderComposer];} // one mode at a time
 if([_api20 handlePlusAction:action])return;
 if([_api6 handlePlusAction:action])return;
 if([_api7 handlePlusAction:action])return;
 [self attachFrom:action replacing:nil];
}
- (void)composerViewDidClearMode:(RCComposerView*)v{(void)v;_webSearch=NO;if(_api7.toolMode)[_api7 clearToolMode];[self renderComposer];[self layout];}
- (void)attachFrom:(NSString*)source replacing:(NSString*)key{
 if(!_sessionReady||_state.sending||_state.uncertain||[self explainRetryLock])return;
 if(![_files acquireFrom:source replacing:key])return; // never sends: the file waits in the tray
 if(!_draftPrepared&&!_busy)[self prepareDraft];
}
- (NSDictionary*)trayItem:(NSUInteger)index{NSArray*items=_files.items;return index<items.count?items[index]:nil;}
- (void)composerView:(RCComposerView*)v didRemoveAttachmentAtIndex:(NSUInteger)index{(void)v;NSDictionary*i=[self trayItem:index];if(i&&!_state.sending)[_files remove:i[@"key"]];} // the running send's draft is not changed under it
- (void)composerView:(RCComposerView*)v didTapAttachmentAtIndex:(NSUInteger)index{
 (void)v;NSDictionary*i=[self trayItem:index];if(!i||_state.sending)return;NSString*key=[[i[@"key"]copy]autorelease],*phase=i[@"phase"];NSMutableArray*buttons=[NSMutableArray array];
 BOOL retry=([phase isEqual:@"failed"]&&[i[@"retryable"]boolValue])||([phase isEqual:@"ready"]&&![i[@"attached"]boolValue]);
 BOOL locked=_state.optionsLocked;if(locked||_files.halted)retry=NO;
 BOOL replace=!locked&&!_files.halted&&[self api8:OR6Chat8FAttachmentEdit]&&![phase isEqual:@"acquiring"]&&[self attachAvailable],check=[self api8:OR6Chat8FExpiry]&&[phase isEqual:@"ready"]&&[i[@"attached"]boolValue];
 if([phase isEqual:@"uncertain"]&&!locked&&!_files.halted)[buttons addObject:OR6L(@"Check upload")];
 if(retry)[buttons addObject:OR6L(@"Try again")];if(replace)[buttons addObject:OR6L(@"Replace…")];if(check)[buttons addObject:OR6L(@"Check availability")];
 NSString*title=[NSString stringWithFormat:@"%@\n%@",[i[@"name"]length]?i[@"name"]:OR6L(@"File"),OR6Chat8AttachmentStatus(i)];
 if(locked)title=[title stringByAppendingFormat:@"\n%@",OR6L(@"The unsent message keeps its files until you send it again or send a new message.")];
 OR6Chat8ShowSheet(self.view.window?:self.view,title,buttons,(locked&&[i[@"attached"]boolValue])?nil:OR6L(@"Remove from message"),^(NSInteger n,NSString*t){
  if(n==-2){[_files remove:key];return;}if(n<0)return;
  if([t isEqual:OR6L(@"Try again")]){if(!_draftPrepared&&!_busy)[self prepareDraft];[_files retry:key];}
  else if([t isEqual:OR6L(@"Check upload")])[_files checkUpload:key];
  else if([t isEqual:OR6L(@"Check availability")])[_files checkStatus];
  else if([t isEqual:OR6L(@"Replace…")])[self chooseReplacement:key];
 });
}
- (void)chooseReplacement:(NSString*)key{
 NSMutableArray*buttons=[NSMutableArray array],*sources=[NSMutableArray array];
 if([self cameraAvailable]){[buttons addObject:OR6L(@"Camera")];[sources addObject:@"camera"];}if([self photosAvailable]){[buttons addObject:OR6L(@"Photos")];[sources addObject:@"photo_library"];}if([self filesAvailable]){[buttons addObject:OR6L(@"Files")];[sources addObject:@"document"];}
 OR6Chat8ShowSheet(self.view.window?:self.view,OR6L(@"The current file stays in the message until the new one is ready."),buttons,nil,^(NSInteger n,NSString*t){(void)t;if(n>=0&&(NSUInteger)n<sources.count)[self attachFrom:sources[(NSUInteger)n]replacing:key];});
}
- (void)downloadTapped:(UIButton*)b{
 NSDictionary*t=objc_getAssociatedObject(b,@selector(downloadTapped:));if(!t||!_sessionReady)return;
 [_downloads download:t[@"fileId"]message:t[@"messageId"]conversation:_state.conversationId];
}
// The temporary switch of the empty chat (stage 8): history_and_training_disabled, never read back from history.
- (BOOL)explainRetryLock{
 if(!_state.optionsLocked)return NO;
 [RCHUD showText:OR6L(@"The unsent message keeps its options and files until you send it again or send a new message.")kind:RCHUDTextOnly inView:self.view.window seconds:2];return YES;
}
- (void)temporaryChanged:(UISwitch*)sw{
 if([self explainRetryLock]){sw.on=_state.temporary;return;}
 if(![self temporaryAvailable]||![_state setTemporary:sw.on]){sw.on=_state.temporary;return;}
 _draftPrepared=NO;[_heights removeAllObjects];[RCTheme styleNavigationBar:self.navigationController.navigationBar variant:[self barVariant]];[self render:NO];
 UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,_state.temporary?OR6L(@"Temporary chat is on"):OR6L(@"Temporary chat is off"));
}
// The title's model line: models.list once, then the catalog choice (models.select of a
// version/mode and its thinking effort). The picker asks again before every change.
- (UIViewController*)modelPicker{
 return OR6Chat8CreateModelPicker(_catalog,^BOOL{
  if(_disposed||_state.sending||!_sessionReady)return NO;if(!_state.optionsLocked)return YES;
  [RCHUD showText:OR6L(@"The unsent message keeps its options and files until you send it again or send a new message.")kind:RCHUDTextOnly inView:self.navigationController.view.window seconds:2];return NO;});
}
- (void)titleTapped{
 if(![self modelsAvailable]||_state.sending||!_sessionReady||[self explainRetryLock])return;
 if(_catalog.loaded&&_catalog.items.count){[_composer resignFirstResponder];[self.navigationController pushViewController:[self modelPicker]animated:YES];return;}
 _wantsPicker=YES;_catalog.delegate=self;if(![_catalog load])return;[self renderTitle];
}
- (void)chat8ModelChanged:(id)model{
 if(model==_files){[self renderComposer];[self layout];if(_files.items.count&&!_draftPrepared&&!_busy&&_sessionReady&&!_state.sending)[self prepareDraft];return;}
 if(model==_downloads){[self render:NO];return;}
 if(model==_catalog){if(!_catalog.busy&&_catalog.loaded&&!_state.conversationId&&!_state.messages.count&&_sessionReady)[_api6 newChatOpened]; // the Auto preference waits for the catalog (one bounded read, latched)
  if(_wantsPicker&&!_catalog.busy){_wantsPicker=NO;
   if(_catalog.loaded&&_catalog.items.count&&self.view.window&&self.navigationController.topViewController==self){UIView*w=self.view.window;[self.navigationController pushViewController:[self modelPicker]animated:YES];
    if(_catalog.choiceDropped)[RCHUD showText:OR6L(@"The previously chosen model option is no longer offered, so the default is used.")kind:RCHUDTextOnly inView:w seconds:2.2];}
   else[RCHUD showText:_catalog.issue?OR6ChatErrorText(OR6APIError(_catalog.issue,@"none")):OR6L(@"No models were received for this account.")kind:RCHUDTextOnly inView:self.view.window seconds:1.6];}
  else if(self.navigationController.topViewController==self&&!_catalog.busy){ // an open picker reports its own result
   if([_catalog.issue isEqual:@"default_unknown"])[RCHUD showText:OR6L(@"The service did not name its default model, so the chosen model stays.")kind:RCHUDTextOnly inView:self.view.window seconds:2];
   else if(_catalog.issue&&_catalog.loaded)[RCHUD showText:OR6ChatErrorText(OR6APIError(_catalog.issue,@"none"))kind:RCHUDTextOnly inView:self.view.window seconds:1.6];
   else if(_catalog.choiceDropped)[RCHUD showText:OR6L(@"The previously chosen model option is no longer offered, so the default is used.")kind:RCHUDTextOnly inView:self.view.window seconds:2.2];}
  [self renderTitle];[NSNotificationCenter.defaultCenter postNotificationName:@"OR6ChatUIChanged"object:self];}
}
// Full-screen editor context (tests/chat-keyboard): Done applies only while it is unchanged. Background,
// owner/credential change and teardown bump the epoch; the Core generation, chat, draft and the field's
// text must also be the ones it opened with, else the old editor's text is dropped and the draft stays.
static NSDictionary*OR6ChatEditorContext(NSUInteger epoch,NSUInteger generation,NSString*conversationId,NSString*draftId,NSString*text){
 return @{@"epoch":@(epoch),@"generation":@(generation),@"conversationId":conversationId?:(id)NSNull.null,@"draftId":draftId?:(id)NSNull.null,@"text":text?:@""};
}
- (NSDictionary*)editorContext{return OR6ChatEditorContext(_editorEpoch,OR6Chat7Generation(_core),_state.conversationId,_state.draftId,_composer.text);}
- (void)composerViewDidTapExpand:(RCComposerView*)v{
 (void)v;if([_api7 openEditorFromText:_composer.text])return; // stage 7: composer.editor.* keeps text/selection bound to the draft
 NSDictionary*opened=[self editorContext]; // the fallback (no composer.editor.* binding) applies only into this exact context
OR6ChatTextEditorController*e=[[[OR6ChatTextEditorController alloc]initWithTitle:OR6L(@"Message")text:_composer.text completion:^(NSString*text){if(!text||_disposed||![opened isEqual:[self editorContext]])return;_state.text=text;_composer.text=text;[self renderComposer];}]autorelease];
 [self presentViewController:[[[UINavigationController alloc]initWithRootViewController:e]autorelease]animated:YES completion:nil];
}

#pragma mark Dictation (inline, stage 9): record → Готово uploads once → text into the field, never sent

- (void)showDictation{
 if(![self dictationAvailable])return;_composer.dictating=YES;RCDictationView*d=_composer.dictationView;d.cancelAvailable=YES;
 NSString*phase=_dictation.phase;d.state=[@[@"transcribing"]containsObject:phase]?RCDictationRecognising:[@[@"failed",@"uncertain"]containsObject:phase]?RCDictationFailed:RCDictationRecording;
 if([phase isEqual:@"recording"])d.elapsed=_dictationStarted?-_dictationStarted.timeIntervalSinceNow:0;
 d.doneButton.enabled=!_dictation.busy&&([phase isEqual:@"recording"]||[phase isEqual:@"stopped"]||[phase isEqual:@"recoverable"]||(_dictation.canRetry));
 d.accessibilityLabel=[phase isEqual:@"recording"]?OR6L(@"The microphone is on. Tap Stop recording."):phase;
 if(_dictation.uncertain)d.doneButton.enabled=NO;
 if([phase isEqual:@"recording"]&&!_clock)_clock=[NSTimer scheduledTimerWithTimeInterval:.5 target:self selector:@selector(clockTick)userInfo:nil repeats:YES];
 [self layout];
}
- (void)hideDictation{_composer.dictating=NO;_dictationDone=NO;if(!_state.sending){[_clock invalidate];_clock=nil;}[self layout];[self renderComposer];}
- (void)dictationStart{
 if(!_composer.micButton.enabled)return;[_api20 stopPlayback];[_api7 stopPlayback];[_composer resignFirstResponder];_dictationInserted=NO;_dictationDone=NO;[_dictationStarted release];_dictationStarted=[NSDate new];[_dictation start];[self showDictationIfActive];
}
- (void)dictationDone{
 if(_api7.streaming){[_api7 stopStreaming];return;}
 NSString*phase=_dictation.phase;_dictationDone=YES;
 if([phase isEqual:@"recording"]||[phase isEqual:@"recoverable"])[_dictation stop];
 else if([phase isEqual:@"stopped"])[_dictation transcribe];
 else if(_dictation.canRetry)[_dictation retry];
 [self showDictationIfActive];
}
// A completion can arrive synchronously inside start/stop/transcribe/retry (local or
// pre-dispatch replies, fake recorder): dictationChanged: may already have inserted the
// text, discarded the recording and hidden the row. Reopen only while the model still has
// a recording or a request in flight (recording, stopped, transcribing, failed, uncertain…).
- (void)showDictationIfActive{if(_dictation.busy||![_dictation.phase isEqual:@"idle"])[self showDictation];}
- (void)dictationCancel{if(_api7.streaming){[_api7 cancelStreaming];return;}_dictationDone=NO;if(_dictation.recordingId)[_dictation discard];else[self hideDictation];}
- (void)dictationChanged:(OR6Chat9Dictation*)d{
 NSString*identifier=d.recordingId;if(identifier)[NSUserDefaults.standardUserDefaults setObject:identifier forKey:@"ChatGPTXUI9RecordingID"];else[NSUserDefaults.standardUserDefaults removeObjectForKey:@"ChatGPTXUI9RecordingID"];
 NSString*phase=d.phase;
 if([phase isEqual:@"idle"]){if(d.issue.length)[RCHUD showText:OR6ChatErrorText(OR6APIError(d.issue,@"none"))kind:RCHUDTextOnly inView:self.view.window seconds:2];[self hideDictation];}
 else if([phase isEqual:@"stopped"]&&_dictationDone&&d.canTranscribe)[d transcribe];
 else if([phase isEqual:@"transcribed"]){
  if(!_dictationInserted&&[self insertDictationText:d]){_dictationInserted=YES;[d discard];[RCHUD showText:OR6L(@"Text inserted into the message field. Send it from the chat when you are ready.")kind:RCHUDTextOnly inView:self.view.window seconds:1.6];}
  else if(!_dictationInserted)[self showDictation];
 }
 if(_composer.dictating&&![phase isEqual:@"idle"])[self showDictation];
 if([phase isEqual:@"failed"]||[phase isEqual:@"uncertain"])UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,OR6ChatErrorText(OR6APIError(d.issue.length?d.issue:@"unknown",d.uncertain?@"possible":@"none")));
 [self renderComposer];[NSNotificationCenter.defaultCenter postNotificationName:@"OR6ChatUIChanged"object:self];
}
- (BOOL)insertDictationText:(OR6Chat9Dictation*)dictation{
 if(dictation!=_dictation||!_sessionReady||_busy||_state.sending||_state.uncertain)return NO;
 NSRange range=_composer.textView.selectedRange;if(range.location==NSNotFound||range.location>_state.text.length)range=NSMakeRange(_state.text.length,0);
 NSString*text=[dictation insertingInto:_state.text range:range];if(!text)return NO;_state.text=text;_composer.text=text;[self renderComposer];return YES;
}
- (BOOL)setDictationLimitMS:(NSUInteger)ms{if(ms<1||ms>60000)return NO;_dictation.maximumDurationMS=ms;return _dictation.maximumDurationMS==ms;}

#pragma mark Messages: copy, select, links, sources, retry/check

- (void)copyText:(NSString*)text messageId:(NSString*)identifier announce:(NSString*)announce{
 NSDictionary*p=OR6Chat9CopyParameters(identifier?:@"message",text?:@"");if(!p)return;UIView*hudHost=self.view.window;
 [_core perform:@"content.copy"parameters:p event:nil completion:^(NSDictionary*r,NSError*e){if(e)return;[UIPasteboard generalPasteboard].string=r[@"text"];[RCHUD showText:announce kind:RCHUDDone inView:hudHost seconds:0];UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,announce);}];
}
- (void)userMessageViewDidRequestEdit:(RCUserMessageView*)v{
 NSDictionary*r=[self rowForView:v];if(![r[@"editable"]boolValue]||![_state canEditMessage:r[@"id"]])return;NSString*identifier=[[r[@"id"]copy]autorelease],*original=[[r[@"text"]copy]autorelease];[_composer resignFirstResponder];
 OR6ChatTextEditorController*e=[[[OR6ChatTextEditorController alloc]initWithTitle:OR6L(@"Edit message")text:original completion:^(NSString*text){if(!text||[text isEqual:original])return;[self editMessage:identifier text:text];}]autorelease];
 [self presentViewController:[[[UINavigationController alloc]initWithRootViewController:e]autorelease]animated:YES completion:nil];
}
- (void)userMessageViewDidRequestCopy:(RCUserMessageView*)v{NSDictionary*r=[self rowForView:v];[self copyText:r[@"text"]messageId:r[@"id"]announce:OR6L(@"Copied")];}
- (void)userMessageViewDidTapBadge:(RCUserMessageView*)v{
 NSDictionary*r=[self rowForView:v];UIActionSheet*s=nil;
 if([r[@"failed"]boolValue]&&_actions.canRetry){s=[[[UIActionSheet alloc]initWithTitle:OR6L(@"The message was not sent. Sending again is safe: it will be sent once.")delegate:self cancelButtonTitle:OR6L(@"Cancel")destructiveButtonTitle:nil otherButtonTitles:OR6L(@"Send again"),nil]autorelease];s.tag=OR6SheetRetry;}
 else if(_state.uncertain){s=[[[UIActionSheet alloc]initWithTitle:OR6L(@"The connection dropped after sending. Check the conversation history before sending again.")delegate:self cancelButtonTitle:OR6L(@"Cancel")destructiveButtonTitle:nil otherButtonTitles:OR6L(@"Check in history"),nil]autorelease];s.tag=OR6SheetCheck;}
 [s showInView:self.view.window?:self.view];
}
- (void)answerCardDidRequestCopy:(RCAnswerCardView*)c{NSDictionary*r=[self rowForView:c];[self copyText:[c readableText]messageId:r[@"id"]announce:OR6L(@"Copied")];}
- (void)answerCardDidTapContinue:(RCAnswerCardView*)c{NSDictionary*r=[self rowForView:c];if(r)[_api7 continueRow:r];}
- (void)answerCardDidRequestSelect:(RCAnswerCardView*)c{[self selectRow:[self rowForView:c]];}
- (BOOL)codeBlockViewShouldCopy:(RCCodeBlockView*)v{UIView*x=v;while(x&&![x isKindOfClass:RCAnswerCardView.class])x=x.superview;NSDictionary*r=x?[self rowForView:x]:nil;return r?[_api7 shouldKitCopyCode:v row:r]:YES;} // content.copyCode (stage 7)
- (void)codeBlockViewDidCopy:(RCCodeBlockView*)v{NSString*code=v.code;NSDictionary*p=OR6Chat9CopyParameters(@"code",code?:@"");if(p)[_core perform:@"content.copy"parameters:p event:nil completion:^(NSDictionary*r,NSError*e){if(!e)[UIPasteboard generalPasteboard].string=r[@"text"];}];[RCHUD showText:OR6L(@"Copied")kind:RCHUDDone inView:self.view.window seconds:0];}
- (void)openLink:(NSURL*)url title:(NSString*)title{
 if([_api7 handleLink:url])return; // app routes (routes.resolve) and shared-chat links (shares.get) stay in the app
 NSString*safe=OR6ContentSafeURL(url.absoluteString,NO);if(!safe){[RCHUD showText:OR6L(@"This link cannot be opened.")kind:RCHUDTextOnly inView:self.view.window seconds:1.5];return;}
 [_sheetURL release];_sheetURL=[[NSURL URLWithString:safe]retain];NSString*shown=_sheetURL.host?[_sheetURL.host stringByAppendingString:_sheetURL.path.length>1?_sheetURL.path:@""]:safe;(void)title;
 UIActionSheet*s=[[[UIActionSheet alloc]initWithTitle:shown delegate:self cancelButtonTitle:OR6L(@"Cancel")destructiveButtonTitle:nil otherButtonTitles:OR6L(@"Open in Safari"),OR6L(@"Copy link"),nil]autorelease];s.tag=OR6SheetLink;[s showInView:self.view.window?:self.view];
}
- (void)answerCardDidToggleReasoning:(RCAnswerCardView*)card {
 NSDictionary*r=[self rowForView:card];if(!r[@"id"])return;
 if(card.reasoningExpanded)[_reasoningOpen addObject:r[@"id"]];else[_reasoningOpen removeObject:r[@"id"]];
 [self render:NO];
}
- (void)answerCard:(RCAnswerCardView*)c didSelectLinkURL:(NSURL*)url title:(NSString*)title{(void)c;[self openLink:url title:title];}
- (void)answerCard:(RCAnswerCardView*)c didSelectAction:(RCAnswerAction)action{
 NSDictionary*r=[self rowForView:c];
 if(action==RCAnswerActionCopy)[_api20 copyMarkdownRow:r];
 else if(action==RCAnswerActionSpeak){[_api7 stopPlayback];[_api20 performMore:OR6L(@"Read aloud") row:r];}
 else if(action==RCAnswerActionShare){
  if(![_api7 canExportImagesForRow:r])[self shareText:[c readableText]];
  else if(![[r[@"text"]stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]length])[_api7 exportImagesForRow:r destination:@"share"];
  else {NSDictionary*row=[[r copy]autorelease];NSString*text=[[c readableText]copy];NSUInteger epoch=_epoch;
   OR6Chat8ShowSheet(self.view.window?:self.view,OR6L(@"Share"),@[OR6L(@"Share image"),OR6L(@"Share text")],nil,^(NSInteger index,NSString*title){(void)title;if(_disposed||epoch!=_epoch)return;if(index==0)[_api7 exportImagesForRow:row destination:@"share"];else if(index==1)[self shareText:text];});[text release];}
 }
 else if(action==RCAnswerActionSources){NSArray*sources=r[@"sources"];if(sources.count)[self showSources:sources messageId:r[@"id"]];}
 else if(action==RCAnswerActionMore){[_sheetRow release];_sheetRow=[r retain];UIActionSheet*s=[[[UIActionSheet alloc]initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil]autorelease];if([r[@"regenerate"]boolValue])[s addButtonWithTitle:OR6L(@"Regenerate")];if([[r[@"text"]stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]length]&&[self translateAvailable])[s addButtonWithTitle:OR6L(@"Translate")];if([self shareAvailable]&&!(c.actionBar.actions&RCAnswerActionShare))[s addButtonWithTitle:OR6L(@"Share")];BOOL last=[r[@"index"]isKindOfClass:NSNumber.class]&&[r[@"index"]unsignedIntegerValue]+1==_state.messages.count;for(NSString*t in [_api7 moreTitlesForRow:r isLast:last])[s addButtonWithTitle:t];for(NSString*t in [_api6 moreTitlesForRow:r isLast:last]){NSInteger button=[s addButtonWithTitle:t];if([t isEqual:OR6L(@"Report…")])s.destructiveButtonIndex=button;}s.cancelButtonIndex=[s addButtonWithTitle:OR6L(@"Cancel")];s.tag=OR6SheetMore;[s showInView:self.view.window?:self.view];}
}
- (NSString*)readableTextForRow:(NSDictionary*)r{return[RCMarkdownView readableTextFromMarkdown:OR6ContentResolveCitations(r[@"text"],r[@"sources"])];}
- (void)selectRow:(NSDictionary*)r{
 NSUInteger i=[r[@"index"]unsignedIntegerValue];NSArray*messages=_state.messages;if(!r||i>=messages.count)return;[_composer resignFirstResponder];
 UIViewController*select=OR6ChatCreateSelectController(_core,messages[i],[self readableTextForRow:r]);if(select)[self.navigationController pushViewController:select animated:YES];
}
- (void)showSources:(NSArray*)sources{
 [_sheetSources release];_sheetSources=[sources copy];
 OR6ChatPresentSources(self,sources,^(NSDictionary*source){[self openLink:[NSURL URLWithString:source[@"url"]]title:source[@"title"]];});
}
// content.sources validates the Source DTOs (safe URLs) before the sheet shows them.
- (void)showSources:(NSArray*)sources messageId:(NSString*)identifier{
 if(![self api8:OR6Chat8FSources]||!identifier.length||identifier.length>128){[self showSources:sources];return;}
 [_core perform:@"content.sources"parameters:@{@"messageId":identifier,@"sources":OR6Chat8SourceDTOs(sources)}event:nil completion:^(NSDictionary*r,NSError*e){
  NSArray*rows=e?nil:OR6Chat8SourceRows(r[@"sources"]);if(rows.count&&self.view.window)[self showSources:rows];
  else if(e)[RCHUD showText:OR6ChatErrorText(e)kind:RCHUDTextOnly inView:self.view.window seconds:1.6];}];
}
- (void)openTranslation:(NSString*)text{
 if(![self translateAvailable])return;[_composer resignFirstResponder];
 OR6Chat8TranslateController*t=[[[OR6Chat8TranslateController alloc]initWithCore:_core text:text]autorelease];[self.navigationController pushViewController:t animated:YES];
}
- (void)shareText:(NSString*)text{if(!text.length)return;UIActivityViewController*a=[[[UIActivityViewController alloc]initWithActivityItems:@[text]applicationActivities:nil]autorelease];[self presentViewController:a animated:YES completion:nil];}
- (void)actionSheet:(UIActionSheet*)s clickedButtonAtIndex:(NSInteger)i{
 if(i==s.cancelButtonIndex||i<0)return;
 switch(s.tag){
  case OR6SheetRetry:[self retryMessage];break;
  case OR6SheetCheck:[self reconcile];break;
  case OR6SheetLink:if(i==s.firstOtherButtonIndex)[UIApplication.sharedApplication openURL:_sheetURL];else[self copyText:_sheetURL.absoluteString messageId:@"link" announce:OR6L(@"Link copied")];break;
  case OR6SheetMore:{NSDictionary*r=[[_sheetRow retain]autorelease];NSString*title=[s buttonTitleAtIndex:i];if(!r)break;if([title isEqual:OR6L(@"Regenerate")]){if([r[@"regenerate"]boolValue])[self regenerate:r[@"id"]];}else if([title isEqual:OR6L(@"Share")])[self shareText:[self readableTextForRow:r]];else if([title isEqual:OR6L(@"Translate")])[self openTranslation:[self readableTextForRow:r]];else {if([title isEqual:OR6L(@"Read aloud")])[_api7 stopPlayback];if(![_api20 performMore:title row:r]&&![_api6 performMore:title row:r])[_api7 performMore:title row:r];}break;}
 }
}

#pragma mark API 7/10 host (OR6Chat7ConversationHost) and chat actions

- (NSString*)chat7ConversationId{return _state.conversationId;}
- (NSDictionary*)chat7DraftRequest{return[_state draftRequest];}
- (NSString*)chat7DraftId{return _draftPrepared?_state.draftId:nil;}
- (NSString*)chat7ModelId{[self syncModelChoice];return _state.modelId;}
- (NSString*)chat7LastMessageId{return[_state draftRequest][@"parentMessageId"];} // the parent the next turn would use
- (RCComposerView*)chat7Composer{return _composer;}
- (BOOL)chat7Idle{return _sessionReady&&_state.loaded&&!_busy&&!_state.sending&&!_state.uncertain&&!_composer.dictating&&!_disposed;}
- (void)chat7SetDraftText:(NSString*)text{_state.text=text?:@"";_composer.text=_state.text;[self renderComposer];[self layout];}
- (void)chat7Reload{if(_state.conversationId&&!_state.temporary)[self loadConversation];}
- (void)chat7Render{[self render:NO];}
- (void)chat7OpenConversation:(NSString*)identifier{[[self chat7Navigator]chat7OpenConversation:identifier title:nil];}
- (void)chat7NewChat{[self newChat];}
- (UIViewController*)chat7Presenter{return self;}
- (id<OR6Chat7Navigator>)chat7Navigator{return[(id)_host respondsToSelector:@selector(conversationNavigator)]?[(id)_host conversationNavigator]:nil;}
- (void)api7Reconcile{[_api7 reconcileRun];}
- (void)invalidateAPI7{_editorEpoch++;[_api7 prepareForBackground];[_api6 prepareForBackground];[_api20 prepareForBackground];[self render:NO];} // owner/credential context changed: no API7 callback of the old context applies
// A new chat inside a project: Send goes through projects.newDraft / projects.send.
- (void)setGPT:(NSDictionary*)gpt{[_api6 setGPT:gpt];if(_api6.gpt)self.conversationTitle=_api6.gpt[@"name"];}
- (void)setProject:(NSDictionary*)project{_api7.projectId=project[@"projectId"];_api7.project=project;if([project[@"name"]isKindOfClass:NSString.class])self.conversationTitle=project[@"name"];}
- (BOOL)attachLibraryDraft:(NSDictionary*)draft item:(NSDictionary*)item{
 if(!_draftPrepared||_state.sending||_state.uncertain||![draft[@"draftId"]isEqual:_state.draftId]||![_files.draftId isEqual:_state.draftId])return NO;
 if(![_files adoptLibraryDraft:draft item:item])return NO;[self renderComposer];[self layout];return YES;
}
// Route compose?text=…: into an empty field; an existing draft is kept and the text is offered to add at its end. Never sent.
- (void)composeRouteText:(NSString*)text{
 if(!text.length)return;if(!_state.text.length){[self chat7SetDraftText:text];return;}
 NSString*draft=[[_state.text copy]autorelease];
 OR6Chat8ShowSheet(self.view.window?:self.view,OR6L(@"The message field already has a draft. Add the link's text at its end?"),@[OR6L(@"Add to the draft")],nil,^(NSInteger n,NSString*t){(void)t;if(n==0&&[_state.text isEqual:draft])[self chat7SetDraftText:[draft stringByAppendingFormat:@"\n%@",text]];});
}
- (NSDictionary*)conversationInfo{
 NSMutableDictionary*d=[NSMutableDictionary dictionaryWithDictionary:([(id)_host respondsToSelector:@selector(conversationInfo:)]?[(id)_host conversationInfo:_state.conversationId]:nil)?:@{}];
 if(_state.conversationId)d[@"id"]=_state.conversationId;d[@"title"]=_conversationTitle?:@"";return d;
}
- (void)renderActionsButton{
 if(!self.isViewLoaded)return;UIBarButtonItem*compose=[self barGlyph:@"compose" action:@selector(newChat)label:OR6L(@"New chat")identifier:@"chat.new"];
 BOOL more=_state.conversationId&&!_state.temporary&&(OR6Chat7ConversationActions(_core,[self conversationInfo]).count>0||OR6Chat6ConversationActions(_core,[self conversationInfo]).count>0);
 if(more==(self.navigationItem.rightBarButtonItems.count==2))return;
 self.navigationItem.rightBarButtonItems=more?@[compose,[self barGlyph:@"more" action:@selector(chatActions)label:OR6L(@"Chat actions")identifier:@"chat.actions"]]:@[compose];
}
- (void)chatActions{
 NSDictionary*info=[self conversationInfo];NSArray*actions=OR6Chat7ConversationActions(_core,info),*six=OR6Chat6ConversationActions(_core,info);if(!actions.count&&!six.count)return;[_composer resignFirstResponder];
 NSDictionary*titles=@{@"rename":OR6L(@"Rename"),@"pin":OR6L(@"Pin"),@"unpin":OR6L(@"Unpin"),@"share":OR6L(@"Share link…"),@"move":OR6L(@"Move to project…"),@"files":OR6L(@"Files in this chat"),@"archive":OR6L(@"Archive"),@"unarchive":OR6L(@"Return from archive")};
 NSMutableArray*buttons=[NSMutableArray array],*keys=[NSMutableArray array];for(NSString*a in actions)if(titles[a]){[buttons addObject:titles[a]];[keys addObject:a];}
 for(NSDictionary*x in six){[buttons addObject:x[@"title"]];[keys addObject:[@"six:"stringByAppendingString:x[@"key"]]];} // stage 6: lock, report, voice
 BOOL del=[actions containsObject:@"delete"];
 OR6Chat8ShowSheet(self.view.window?:self.view,_conversationTitle,buttons,del?OR6L(@"Delete chat"):nil,^(NSInteger n,NSString*t){(void)t;NSString*a=n==-2?@"delete":(n>=0&&(NSUInteger)n<keys.count)?keys[(NSUInteger)n]:nil;if(!a)return;
  if([a hasPrefix:@"six:"]){OR6Chat6RunConversationAction(self,_core,[a substringFromIndex:4],info,[self chat7Navigator]);return;}
  OR6Chat7RunConversationAction(self,_core,a,info,[self chat7Navigator]);});
}

#pragma mark Navigation and session

- (void)toggleDrawer{[_composer resignFirstResponder];OR6ChatToggleDrawer(self);}
- (void)newChat{[_composer resignFirstResponder];if([_api6 confirmLeaving:^{[_host conversationRequestsNewChat:self];}])return;[_host conversationRequestsNewChat:self];} // staged scan pages: Keep / Discard first
- (void)signIn{[_host conversationRequestsSignIn:self];}
- (void)applySessionReady:(BOOL)ready{_sessionReady=ready;[self render:NO];if(!ready)return;if(_pendingRecovery)[self resumeRecoverySnapshot:[[_pendingRecovery retain]autorelease]];else[self hydrateRecoveredHistory];}
- (void)applySessionSummary:(NSDictionary*)summary{
 [_summary release];_summary=[summary copy];
 if(summary&&![summary[@"authenticated"]boolValue]){[_pendingRecovery release];_pendingRecovery=nil;if([summary[@"state"]isEqual:@"signed_out"])_recoveryOff=YES;} // logout ends automatic recovery
 [self render:NO];
}
- (void)prepareForBackground{
 if(_disposed)return;[_refresh endRefreshing];[_historyPoll invalidate];_historyPoll=nil;_editorEpoch++;[_api7 prepareForBackground];[_api6 prepareForBackground];[_api20 prepareForBackground];[_dictation prepareForBackground];[_files prepareForBackground];[_downloads cancelAll];[self stopStatusPoll];_wantsPicker=NO;
 if(_state.sending&&[_state.kind isEqual:@"search"]){[_state finishWebSearch:nil error:OR6APIError(@"cancelled",@"possible")];[self setNotice:OR6L(@"The web search may still have run. It was not repeated; check your chats before searching again.")];}_stopEpoch++;[_stopRequest cancel];[_stopRequest release];_stopRequest=nil;[_composer resignFirstResponder];_sendRequested=NO;[_streamTimer invalidate];_streamTimer=nil;
 if(_state.sending){[_state finishReceipt:nil error:[NSError errorWithDomain:@"OR6API"code:1 userInfo:@{@"code":@"cancelled",@"dispatch":@"possible"}]];[self setNotice:OR6L(@"Updates were interrupted. Check the send result before continuing.")];}
 if(_hydrating){_hydrating=NO;_recoveryHydrate=YES;} // interrupted history read: again on the next activation
 _recoveryLatched=NO;_hydrateLatched=NO;[_pendingRecovery release];_pendingRecovery=nil; // next activation may check once more
 _epoch++;[_request cancel];[_request release];_request=nil;_busy=NO;[self render:NO];
}
- (NSDictionary*)diagnostics{NSMutableDictionary*d=[[[_state diagnostics]mutableCopy]autorelease];d[@"voice8"]=_voice8.diagnostics?:@{};d[@"actions9"]=_actions.diagnostics;d[@"stopIssue"]=_stopIssue?:@"";d[@"dictation"]=_dictation.diagnostics;d[@"files8"]=_files.diagnostics;d[@"webSearchMode"]=@(_webSearch);d[@"model8"]=_catalog.chosenModelId?:@"web-current";d[@"effort8"]=_catalog.sendThinkingEffort?:@"";d[@"historyReads"]=@(_historyReads);d[@"manualRefreshes"]=@(_historyRefreshes);d[@"historyReadSuccesses"]=@(_historyReadSuccesses);d[@"refreshing"]=@(_refresh.refreshing);d[@"rows"]=@(_rows.count);d[@"cachedHeights"]=@(_heights.count);d[@"api7"]=_api7.diagnostics?:@{};d[@"api6"]=_api6.diagnostics?:@{};d[@"conversationId"]=_state.conversationId?:@"";return d;} // the open chat's ID (private receipt) for exact restore by a direct install; never the draft text
#ifdef OR6_CHAT_ACCEPTANCE
#import <CommonCrypto/CommonDigest.h>
#include <mach/mach.h>
static double OR6Now(void){return CFAbsoluteTimeGetCurrent();}
static NSUInteger OR6Resident(void){struct task_basic_info info;mach_msg_type_number_t n=TASK_BASIC_INFO_COUNT;return task_info(mach_task_self(),TASK_BASIC_INFO,(task_info_t)&info,&n)==KERN_SUCCESS?(NSUInteger)info.resident_size:0;}
// Opens the same screens as the long-press menu, the action bar and the badges,
// without synthesising touches (no private event API): navigation for screenshots.
- (BOOL)acceptanceInject:(NSDictionary*)conversation{return[_state acceptConversation:conversation];}
- (NSDictionary*)acceptanceAction:(NSDictionary*)a{
 NSString*kind=a[@"kind"];NSInteger index=-1;for(NSInteger i=(NSInteger)_rows.count-1;i>=0;i--)if([_rows[(NSUInteger)i][@"kind"]isEqual:@"answer"]){index=i;break;}
 NSDictionary*r=index>=0?_rows[(NSUInteger)index]:nil;
 if([kind isEqual:@"scroll"]){if([a[@"top"]boolValue])[_table setContentOffset:CGPointMake(0,-_table.contentInset.top)animated:NO];else[self scrollToBottom:NO];if(a[@"y"])[_table setContentOffset:CGPointMake(0,[a[@"y"]floatValue])animated:NO];return @{@"ok":@YES};}
 if([kind isEqual:@"compose"]&&[a[@"text"]isKindOfClass:NSString.class]){_state.text=a[@"text"];_composer.text=a[@"text"];[self renderComposer];[self layout];return @{@"ok":@YES,@"height":@(_composer.bounds.size.height)};}
 if([kind isEqual:@"perf"]){
  // Long synthetic conversation (no account): first render, full scroll, memory.
  if(!self.isViewLoaded||!_rows.count)return @{@"ok":@NO,@"error":@"inject_first"};
  NSUInteger before=OR6Resident();double t0=OR6Now();[_heights removeAllObjects];[_rows release];_rows=nil;[self render:YES];[_table layoutIfNeeded];double first=OR6Now()-t0;
  NSMutableArray*steps=[NSMutableArray array];CGFloat y=_table.contentOffset.y;double worst=0,total=0;NSUInteger n=0;
  while(y>0){y=MAX(0,y-360);double s0=OR6Now();[_table setContentOffset:CGPointMake(0,y)animated:NO];[_table layoutIfNeeded];double dt=OR6Now()-s0;worst=MAX(worst,dt);total+=dt;n++;if(steps.count<12&&dt>.05)[steps addObject:@((int)(dt*1000))];}
  double s1=OR6Now();[self scrollToBottom:NO];[_table layoutIfNeeded];double jump=OR6Now()-s1;
  return @{@"ok":@YES,@"rows":@(_rows.count),@"firstRenderMs":@((int)(first*1000)),@"scrollSteps":@(n),@"scrollMeanMs":@(n?(int)(total/n*1000):0),@"scrollWorstMs":@((int)(worst*1000)),@"slowSteps":steps,@"jumpToBottomMs":@((int)(jump*1000)),@"cachedHeights":@(_heights.count),@"residentBeforeMB":@(before/1048576),@"residentAfterMB":@(OR6Resident()/1048576),@"contentHeight":@((int)_table.contentSize.height)};
 }
 if(!r)return @{@"ok":@NO,@"error":@"no_answer"};
 if([kind isEqual:@"select"]){[self selectRow:r];return @{@"ok":@YES};}
 if([kind isEqual:@"sources"]){NSArray*s=r[@"sources"];if(!s.count)return @{@"ok":@NO,@"error":@"no_sources"};[self showSources:s];return @{@"ok":@YES};}
 if([kind isEqual:@"copy"]){
  // Same path as long-press Copy. Reports only lengths, marker flags and a hash, never the text.
  NSString*t=[self readableTextForRow:r],*raw=r[@"text"]?:@"";[self copyText:t messageId:r[@"id"]announce:OR6L(@"Copied")];
  NSData*d=[t dataUsingEncoding:NSUTF8StringEncoding];unsigned char h[CC_SHA256_DIGEST_LENGTH];CC_SHA256(d.bytes,(CC_LONG)d.length,h);NSMutableString*hex=[NSMutableString string];for(int i=0;i<CC_SHA256_DIGEST_LENGTH;i++)[hex appendFormat:@"%02x",h[i]];
  BOOL(^markers)(NSString*)=^BOOL(NSString*x){for(NSString*m in @[@"**",@"## ",@"```",@"]("])if([x rangeOfString:m].location!=NSNotFound)return YES;return NO;};
  return @{@"ok":@YES,@"characters":@(t.length),@"rawCharacters":@(raw.length),@"rawHasMarkdown":@(markers(raw)),@"copiedHasMarkdown":@(markers(t)),@"copiedSHA256":hex};}
 if([kind isEqual:@"link"]){RCMarkdownView*m=[[[RCMarkdownView alloc]initWithFrame:CGRectZero]autorelease];m.markdown=r[@"text"];NSArray*links=m.links;if(!links.count)return @{@"ok":@NO,@"error":@"no_links"};[self openLink:links[0][@"url"]title:links[0][@"title"]];return @{@"ok":@YES,@"links":@(links.count)};}
 return @{@"ok":@NO,@"error":@"unknown"};
}
#endif
- (void)dealloc{
 [NSNotificationCenter.defaultCenter removeObserver:self];[self prepareForBackground];_voice8.host=nil;[_voice8 invalidate];[_voice8 release];_voice8=nil;_disposed=YES;[_api20 detach];[_api20 release];_api20=nil;[_api6 detach];[_api6 release];_api6=nil;[_api7 detach];[_api7 release];_api7=nil; // detached first: its pending blocks never reach this controller
_dictation.delegate=nil;[_historyPoll invalidate];[_clock invalidate];[_streamTimer invalidate];_files.delegate=nil;_downloads.delegate=nil;if(_catalog.delegate==(id)self)_catalog.delegate=nil;
 _table.delegate=nil;_table.dataSource=nil;_composer.delegate=nil;_measureCard.delegate=nil;_measureUser.delegate=nil; [_actions release];[_dictation release];[_core release];[_state release];[_rows release];[_table release];[_composer release];[_titleView release];[_banner release];[_empty release];[_historySpinner release];[_measureCard release];[_measureUser release];for(RCAnswerCardView*c in _cards.allValues){c.delegate=nil;c.codeDelegate=nil;}[_heights release];[_reasoningOpen release];[_cards release];[_cardOrder release];
 [_notice release];[_stopIssue release];[_sendStarted release];[_dictationStarted release];[_sheetRow release];[_sheetURL release];[_sheetSources release];[_conversationTitle release];[_summary release];[_pendingRecovery release];[_recoveryOperation release];[_files release];[_downloads release];[_catalog release];[_plusActions release];[_traySignature release];[super dealloc];
}
@end
