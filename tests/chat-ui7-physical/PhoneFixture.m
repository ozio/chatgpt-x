// Acceptance-only UI7 physical fixture (never in ordinary builds). The production window
// classes (OR6ChatRootController → conversation → OR6Chat7Conversation, translation, mail
// form, editor, system sheets) run over the production OR6API7AllComposition + AllCore with
// the real G provider and the real OR6API7GDevice (AVAudioPlayer, Photos write), real
// Media/vault downloads and API8/9 chain, all in isolated Library storage. Below that,
// Backend.m answers only fixture reads and refuses/counts everything that would reach the
// service. No account, session, socket or microphone.
#import <UIKit/UIKit.h>
#include <sys/stat.h>
#import "Backend.h"
#import "../../ios/chat/OR6ChatRootController.h"
#import "../../ios/chat/OR6ChatConversationController.h"
#import "../../ios/chat/OR6ChatUIState.h"
#import "../../ios/api/priority7all/OR6API7AllComposition.h"
#import "../../ios/api/priority7g/OR6API7GDevice.h"
#import "../../ios/api/priority8/OR6API8Media.h"
#import "../../ios/api/priority8/OR6API8Policy.h"
#import "../../ios/api/OR6APILocalProvider.h"
#import "../../ios/api/OR6APIWebAdapter.h"
#import "../../ios/OR6Files.h"
#import "../../ios/ui/priority7/OR6Chat7Models.h"
#import "../../ios/ui/priority7/OR6Chat7Conversation.h"
#import "RCTheme.h"
#import "RCStage.h"
#import "RCPlaybackView.h"
#import "RCCodeBlockView.h"
#import "RCFilePartView.h"
#import "RCImagePartView.h"
#import "RCFormViewController.h"

// Counting pass-through to the real device platform; observation reads the real player status.
@interface UI7FPlatform:NSObject<OR6API7GPlatform>{@public OR6API7GDevice*device;NSMutableDictionary*actions;NSDictionary*lastPlayback,*lastSave;NSUInteger saves,suspends;}
@end
@implementation UI7FPlatform
- (id)init{if((self=[super init])){device=[OR6API7GDevice new];actions=[NSMutableDictionary new];}return self;}
- (NSDictionary*)playback:(NSString*)a assetURL:(NSURL*)u assetId:(NSString*)asset rate:(NSNumber*)rate error:(NSError**)error{
 actions[a]=@([actions[a]unsignedIntegerValue]+1);NSError*e=nil;NSDictionary*r=[device playback:a assetURL:u assetId:asset rate:rate error:&e];
 [lastPlayback release];lastPlayback=[@{@"action":a,@"ok":@(r!=nil),@"code":e.userInfo[@"code"]?:@"",@"fileSHA256":u?UI7FSHA256([NSData dataWithContentsOfURL:u]?:[NSData data]):@""}retain];if(error)*error=e;return r;
}
- (id<OR6APITask>)saveImages:(NSArray*)URLs completion:(OR6APIReply)completion{
 saves++;OR6APIReply done=[[completion copy]autorelease];NSString*hash=URLs.count?UI7FSHA256([NSData dataWithContentsOfURL:URLs[0]]?:[NSData data]):@"";
 return[device saveImages:URLs completion:^(NSDictionary*r,NSError*e){[lastSave release];lastSave=[@{@"files":@(URLs.count),@"fileSHA256":hash,@"saved":r[@"saved"]?:@0,@"completed":r[@"completed"]?:@NO,@"code":e.userInfo[@"code"]?:@"",@"dispatch":e.userInfo[@"dispatch"]?:@""}retain];done(r,e);}];
}
- (void)suspend{suspends++;[device suspend];}
- (NSDictionary*)player{return[device playback:@"status" assetURL:nil assetId:nil rate:nil error:NULL]?:@{};}
- (void)dealloc{[device release];[actions release];[lastPlayback release];[lastSave release];[super dealloc];}
@end
@interface UI7FHost:NSObject<OR6ChatUIHost>{@public NSUInteger requests;}
@end
@implementation UI7FHost
- (void)chatPrepareConversation:(NSString*)identifier{(void)identifier;}
- (void)chatSignIn{requests++;}
- (void)chatSignInWithProvider:(NSString*)provider{(void)provider;requests++;}
- (void)chatRenew{requests++;}
- (void)chatRestore{requests++;}
- (void)chatSignOut{requests++;}
@end

static OR6ChatRootController*root7;static OR6API7AllCore*core7;static OR6API7AllComposition*comp7,*production7;static UI7FCounter*counter7;static UI7FBackend*backend7;static UI7FWeb*web7;static UI7FPlatform*platform7;
static OR6API8Media*media7;static OR6API8Provider*eight7;static OR6API9Provider*nine7;static OR6Files*vault7;static UI7FHost*host7;static NSString*directory7;static NSDictionary*defaults7;static int stage7,appearance7,size7;static id observer7;static NSUInteger resigns7,synthetic7,owners7;
static NSArray*Keys(void){return @[@"RCFeatureStage",@"RCAppearance",@"RCTextSize",@"AppleLanguages",@"ChatGPTXUI9RecordingID"];}
static NSDictionary*Load(NSString*name){NSString*p=[NSBundle.mainBundle pathForResource:name ofType:@"json"];NSData*d=p?[NSData dataWithContentsOfFile:p]:nil;id v=d?[NSJSONSerialization JSONObjectWithData:d options:0 error:NULL]:nil;return[v isKindOfClass:NSDictionary.class]?v:nil;}
// The production coordinator's -deactivate/-invalidateProviders for the fixture stack.
static void Deactivate(void){[root7 prepareForBackground];[root7 invalidateAPI7Context];[comp7 deactivate];[nine7 deactivate];[eight7 deactivate];[media7 deactivate];}
static BOOL Fail(void);
OR6ChatRootController*OR6Chat7FixtureRoot(void){return root7;}
UIViewController*OR6Chat7FixtureCreate(OR6API7AllComposition*production){
 if(root7||directory7)return nil;NSFileManager*fm=NSFileManager.defaultManager;
 // App-wide state the fixture may change, captured first: any failure below restores exactly this.
 NSDictionary*domain=[NSUserDefaults.standardUserDefaults persistentDomainForName:NSBundle.mainBundle.bundleIdentifier];NSMutableDictionary*saved=[NSMutableDictionary dictionary];for(NSString*k in Keys())if(domain[k])saved[k]=domain[k];defaults7=[saved copy];
 stage7=RCStageCurrent();appearance7=[RCTheme appearance];size7=[RCTheme textSize];production7=[production retain];NSString*library=NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES)[0];
 directory7=[[library stringByAppendingPathComponent:[@"ChatGPTXUI7Fixture-"stringByAppendingString:OR6ChatUUID()]]copy];NSString*docs=[directory7 stringByAppendingPathComponent:@"Documents"],*inbox=[docs stringByAppendingPathComponent:@"Inbox"],*journal=[directory7 stringByAppendingPathComponent:@"core"];
 if(![fm createDirectoryAtPath:docs withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700}error:NULL]){Fail();return nil;}chmod(directory7.fileSystemRepresentation,0700);
 NSMutableDictionary*x=[NSMutableDictionary dictionary];for(NSString*k in @[@"7",@"7b",@"7c",@"7d",@"7e",@"7f",@"7g"])if(Load([@"contracts-"stringByAppendingString:k]))x[k]=Load([@"contracts-"stringByAppendingString:k]);NSDictionary*admission=Load(@"priority7-admission"),*base=OR6API8Registry(Load(@"contracts"));
 backend7=[UI7FBackend new];web7=[UI7FWeb new];web7->backend=backend7;platform7=[UI7FPlatform new];NSError*e=nil;
 vault7=[[OR6Files alloc]initWithDirectory:[docs stringByAppendingPathComponent:@"MediaFiles-v1"]inbox:inbox error:&e];
 OR6WebSession*session=[[[OR6WebSession alloc]initWithStore:web7 provider:web7 jar:web7 clock:^NSTimeInterval{return[[NSDate date]timeIntervalSince1970];}]autorelease];
 NSString*roots=@"/nonexistent/ui7-fixture-roots.pem"; // no trust store: an accidental TLS path cannot connect
 OR6APIWebAdapter*adapter=[[[OR6APIWebAdapter alloc]initWithSession:session roots:roots workspace:nil permittedReads:[NSSet set]]autorelease];
 OR6APILocalProvider*local=[[[OR6APILocalProvider alloc]initWithNext:backend7]autorelease];
 media7=vault7?[[OR6API8Media alloc]initWithNext:local vault:vault7 inbox:inbox HTTP:backend7 picker:nil journal:[directory7 stringByAppendingPathComponent:@"media"]capabilities:[NSSet setWithObject:@"download"]error:&e]:nil;
 eight7=media7?[[OR6API8Provider alloc]initWithNext:media7 generation:backend7 media:media7 capabilities:[NSSet setWithArray:@[@"model",@"translate"]]]:nil;
 nine7=eight7?[[OR6API9Provider alloc]initWithNext:eight7 HTTP:backend7 recorder:backend7 coreJournalDirectory:journal controlJournalDirectory:[directory7 stringByAppendingPathComponent:@"controls"]capabilities:[NSSet setWithArray:@[@"stop",@"transcribe"]]error:&e]:nil;
 comp7=nine7&&x.count==7&&admission&&base?[[OR6API7AllComposition alloc]initWithBase:base extensions:x admission:admission adapter:adapter roots:roots next:nine7 media:media7 generation:backend7 vault:vault7 directory:[directory7 stringByAppendingPathComponent:@"API7"]platform:platform7 capture:nil transport:backend7 error:&e]:nil;
 counter7=comp7?[[UI7FCounter alloc]initWithNext:comp7.provider]:nil;core7=counter7?[[OR6API7AllCore alloc]initWithRegistry:comp7.registry provider:counter7 journalDirectory:journal error:&e]:nil;
 if(!core7){Fail();return nil;}[core7 setContextKey:@"ui7-fixture-no-account"];
 [NSUserDefaults.standardUserDefaults removeObjectForKey:@"ChatGPTXUI9RecordingID"]; // the fixture never adopts a production recording
 if(!RCStageOn(7))RCStageSet(7);
 OR6Chat7SetTiers(comp7.tiers);OR6Chat7SetExportResolver(^NSArray*(NSString*token){return[comp7 exportURLsForToken:token];});
 observer7=[[NSNotificationCenter.defaultCenter addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:nil usingBlock:^(NSNotification*n){(void)n;resigns7++;Deactivate();}]retain];
 host7=[UI7FHost new];root7=[[OR6ChatRootController alloc]initWithCore:core7 host:host7];[root7 view];
 [root7 applySessionSummary:@{@"authenticated":@YES,@"state":@"authenticated",@"revision":@1,@"renewable":@NO}];
 if(![root7 openConversationIdentifier:UI7FConversationID]){Fail();return nil;}return root7;
}
static NSDictionary*Asset(NSString*file,NSData*bytes){
 NSDictionary*d=counter7->last[[@"assets.download:"stringByAppendingString:file]];NSDictionary*v=d[@"assetId"]?[vault7 assetForID:d[@"assetId"]error:NULL]:nil;NSURL*u=v?[vault7 URLForAssetID:d[@"assetId"]error:NULL]:nil;
 return @{@"downloaded":@(d!=nil),@"mediaType":d[@"mediaType"]?:@"",@"vaultPresent":@(v!=nil),@"vaultSHA256":v[@"sha256"]?:@"",@"fileSHA256":u?UI7FSHA256([NSData dataWithContentsOfURL:u]?:[NSData data]):@"",@"expectedSHA256":UI7FSHA256(bytes),@"bytes":@(bytes.length)};
}
static void Find(UIView*v,Class c,NSMutableArray*out){if([v isKindOfClass:c])[out addObject:v];for(UIView*s in v.subviews)Find(s,c,out);}
static NSArray*Sheets(void){NSMutableArray*a=[NSMutableArray array];for(UIWindow*w in UIApplication.sharedApplication.windows)Find(w,UIActionSheet.class,a);return a;}
// Runtime regression for the height pass: every cached live player stays out of the controller's
// off-screen measuring card and keeps its delegate; on-screen players are exactly cached instances.
// Fixture-only KVC introspection of private ivars (_api7, _players, _measureCard); read-only.
static NSDictionary*Players(UIViewController*chat){
 if(!chat)return @{};NSDictionary*cache=nil;UIView*measure=nil;id helper=nil;
 @try{helper=[chat valueForKey:@"api7"];cache=[helper valueForKey:@"players"];measure=[chat valueForKey:@"measureCard"];}@catch(NSException*e){(void)e;return @{@"error":@"introspection_unavailable"};}
 NSMutableArray*tables=[NSMutableArray array];Find(chat.view,UITableView.class,tables);UITableView*table=nil;for(UITableView*t in tables)if([t.accessibilityIdentifier isEqual:@"chat.messages"])table=t;
 NSUInteger window=0,inTable=0,inMeasure=0,bound=0;for(RCPlaybackView*v in cache.allValues){if(v.window)window++;if(table&&[v isDescendantOfView:table])inTable++;if(measure&&[v isDescendantOfView:measure])inMeasure++;if(v.delegate==helper)bound++;}
 NSMutableArray*shown=[NSMutableArray array],*measuring=[NSMutableArray array];if(table)Find(table,RCPlaybackView.class,shown);if(measure)Find(measure,RCPlaybackView.class,measuring);
 NSUInteger shownCached=0,measuringCached=0;for(id v in shown)if([cache.allValues indexOfObjectIdenticalTo:v]!=NSNotFound)shownCached++;for(id v in measuring)if([cache.allValues indexOfObjectIdenticalTo:v]!=NSNotFound)measuringCached++;
 BOOL ok=inMeasure==0&&measuringCached==0&&bound==cache.count&&shownCached==shown.count;
 return @{@"cached":@(cache.count),@"cachedInWindow":@(window),@"cachedInMessagesTable":@(inTable),@"cachedInMeasureCard":@(inMeasure),@"cachedDelegateBound":@(bound),@"shownInTable":@(shown.count),@"shownCached":@(shownCached),@"measureCardPlayers":@(measuring.count),@"measureCardCached":@(measuringCached),@"ok":@(ok)};
}
static NSDictionary*Text(NSString*t){return @{@"characters":@(t.length),@"textSHA256":UI7FTextSHA256(t?:@"")};}
// The kit's iOS 6 line-break check (+[RCComposerView lineBreakProbe], synthetic text: lengths, hashes,
// booleans): measured once per fixture on the first state read, cached, released on close.
static NSArray*lineBreak7;
NSDictionary*OR6Chat7FixtureState(void){
 if(!root7)return @{@"ok":@NO,@"error":@"fixture_closed"};
 if(!lineBreak7)lineBreak7=[[RCComposerView lineBreakProbe]copy];
 NSMutableArray*stack=[NSMutableArray array];for(UIViewController*c in root7.frontNavigationController.viewControllers)[stack addObject:NSStringFromClass(c.class)];
 NSMutableArray*presented=[NSMutableArray array];for(UIViewController*c=root7.presentedViewController;c;c=c.presentedViewController)[presented addObject:[c isKindOfClass:UINavigationController.class]?[NSString stringWithFormat:@"%@>%@",NSStringFromClass(c.class),NSStringFromClass([(UINavigationController*)c topViewController].class)]:NSStringFromClass(c.class)];
 OR6ChatConversationController*chat=nil;for(UIViewController*c in root7.frontNavigationController.viewControllers)if([c isKindOfClass:OR6ChatConversationController.class])chat=(id)c;
 RCComposerView*composer=[(id)chat chat7Composer];NSMutableArray*editors=[NSMutableArray array];if(root7.presentedViewController)Find(root7.presentedViewController.view,UITextView.class,editors);UITextView*editor=nil;for(UITextView*t in editors)if([t.accessibilityIdentifier isEqual:@"chat.composer.expanded"])editor=t;
 NSMutableArray*sheets=[NSMutableArray array];for(UIActionSheet*s in Sheets()){NSMutableArray*titles=[NSMutableArray array];for(NSInteger i=0;i<s.numberOfButtons;i++)[titles addObject:[s buttonTitleAtIndex:i]?:@""];[sheets addObject:titles];}
 NSMutableDictionary*latches=[NSMutableDictionary dictionary];for(NSString*f in @[UI7FImageFile,UI7FAudioFile])for(NSString*k in @[[@"photos:"stringByAppendingString:f],[NSString stringWithFormat:@"download:%@:%@",UI7FAssistantID,f]])latches[k]=@(OR6Chat7IsUnresolved(k));
 NSRange sel=composer.textView.selectedRange;
 NSDictionary*state=@{@"ok":@YES,@"fixture":@"ui7-physical",@"ui":root7.diagnostics?:@{},@"core":core7.diagnostics?:@{},@"composition":comp7.diagnostics?:@{},@"contextGeneration":@(OR6Chat7Generation(core7)),
  @"dispatched":[[counter7->dispatched copy]autorelease],@"completed":[[counter7->completed copy]autorelease],@"failures":[[counter7->failures copy]autorelease],@"results":[[counter7->last copy]autorelease],@"backend":backend7.diagnostics,
  @"platform":@{@"actions":[[platform7->actions copy]autorelease],@"suspends":@(platform7->suspends),@"photosSaves":@(platform7->saves),@"lastPlayback":platform7->lastPlayback?:@{},@"lastSave":platform7->lastSave?:@{},@"player":[platform7 player]},
  @"assets":@{@"image":Asset(UI7FImageFile,UI7FImagePNG()),@"audio":Asset(UI7FAudioFile,UI7FAudioWAV())},@"latches":latches,
  @"expected":@{@"code":Text(UI7FExpectedCode()),@"audioSeconds":@30,@"imagePixels":@"64x64"},
  @"composer":composer?@{@"text":Text(composer.text),@"selectionStart":@(sel.location==NSNotFound?0:sel.location),@"selectionLength":@(sel.length),@"dictating":@(composer.dictating)}:@{},
  @"editor":editor?@{@"presented":@YES,@"text":Text(editor.text)}:@{@"presented":@NO},@"lineBreakProbe":lineBreak7?:@[],@"playerHierarchy":Players(chat),@"stack":stack,@"presented":presented,@"actionSheets":sheets,
  @"lifecycle":@{@"resignActive":@(resigns7),@"syntheticBackground":@(synthetic7),@"ownerChanges":@(owners7)},@"stage":@(RCStageCurrent()),@"hostRequests":@(host7->requests),@"accountRequests":@0,@"networkRequests":@0};
 return[NSJSONSerialization isValidJSONObject:state]?state:@{@"ok":@NO,@"error":@"state_not_json"}; // the actor serializes outside its @try
}
NSDictionary*OR6Chat7FixtureMode(NSString*mode){
 NSArray*modes=@[@"files-ready",@"files-hold",@"translation-synthetic",@"translation-pending",@"translation-refused"];
 if(!root7||![modes containsObject:mode]||[core7.diagnostics[@"activeCount"]unsignedIntegerValue])return @{@"ok":@NO,@"error":@"fixture_busy_or_bad_mode"};
 if([mode hasPrefix:@"files-"])backend7->holdFiles=[mode isEqual:@"files-hold"];else{[backend7->translation release];backend7->translation=[[mode substringFromIndex:12]copy];}
 return OR6Chat7FixtureState();
}
// owner_change: the production binding's owner/credential transition (new Core context, providers
// invalidated). background: the same handler as a real resign, counted separately as synthetic.
NSDictionary*OR6Chat7FixtureLifecycle(NSString*event){
 if(!root7)return @{@"ok":@NO,@"error":@"fixture_closed"};
 if([event isEqual:@"owner_change"]){owners7++;[core7 setContextKey:[NSString stringWithFormat:@"ui7-fixture-owner-%lu",(unsigned long)owners7+1]];[root7 invalidateAPI7Context];[comp7 deactivate];[nine7 deactivate];[eight7 deactivate];[media7 deactivate];}
 else if([event isEqual:@"background"]){synthetic7++;Deactivate();}else return @{@"ok":@NO,@"error":@"bad_event"};
 return OR6Chat7FixtureState();
}
// A visible action sheet button by exact title, through the button's own UIKit target-action.
NSDictionary*OR6Chat7FixtureSheet(NSString*title){
 NSArray*s=Sheets();if(!root7||s.count!=1||![title isKindOfClass:NSString.class])return @{@"ok":@NO,@"error":@"sheet_unavailable"};
 NSMutableArray*buttons=[NSMutableArray array];Find(s[0],UIButton.class,buttons);UIButton*hit=nil;NSUInteger n=0;for(UIButton*b in buttons)if([[b titleForState:UIControlStateNormal]isEqual:title]&&b.enabled&&!b.hidden){hit=b;n++;}
 if(n!=1)return @{@"ok":@NO,@"error":@"button_unavailable"};[hit sendActionsForControlEvents:UIControlEventTouchUpInside];return @{@"ok":@YES};
}
// Brings an answer part of the fixture conversation on screen (the user's scroll, via UIKit).
NSDictionary*OR6Chat7FixtureScroll(NSString*part){
 NSDictionary*classes=@{@"code":RCCodeBlockView.class,@"image":RCImagePartView.class,@"file":RCFilePartView.class,@"playback":RCPlaybackView.class};
 NSMutableArray*tables=[NSMutableArray array];if(root7)Find(root7.view,UITableView.class,tables);UITableView*table=nil;for(UITableView*t in tables)if([t.accessibilityIdentifier isEqual:@"chat.messages"]&&t.window)table=t;
 if(!table||![part isKindOfClass:NSString.class])return @{@"ok":@NO,@"error":@"scroll_unavailable"};
 if([part isEqual:@"top"]){[table setContentOffset:CGPointMake(0,-table.contentInset.top)animated:NO];return @{@"ok":@YES};}
 Class c=classes[part];NSMutableArray*views=[NSMutableArray array];if(c)Find(table,c,views);if(views.count!=1)return @{@"ok":@NO,@"error":@"part_unavailable",@"count":@(views.count)};
 UIView*v=views[0];[table scrollRectToVisible:[v convertRect:v.bounds toView:table]animated:NO];return @{@"ok":@YES};
}
BOOL OR6Chat7FixtureClose(void){
 if(!root7&&!directory7)return NO;
 if(observer7){[NSNotificationCenter.defaultCenter removeObserver:observer7];[observer7 release];observer7=nil;}
 [root7 prepareForBackground];[root7 invalidateAPI7Context];[core7 cancelAll];[comp7 deactivate];[nine7 deactivate];[eight7 deactivate];[media7 deactivate];
 // The production composition's tiers and export resolver come back; fixture latches end with it.
 OR6API7AllComposition*p=production7;OR6Chat7SetTiers(p?p.tiers:nil);OR6Chat7SetExportResolver(p?^NSArray*(NSString*token){return[p exportURLsForToken:token];}:nil);
 for(NSString*f in @[UI7FImageFile,UI7FAudioFile]){OR6Chat7ForgetUnresolvedKey([@"photos:"stringByAppendingString:f]);OR6Chat7ForgetUnresolvedKey([NSString stringWithFormat:@"download:%@:%@",UI7FAssistantID,f]);}
 [root7 release];root7=nil;[core7 release];core7=nil;[counter7 release];counter7=nil;[comp7 release];comp7=nil;[nine7 release];nine7=nil;[eight7 release];eight7=nil;[media7 release];media7=nil;[vault7 release];vault7=nil;
 [platform7 release];platform7=nil;[web7 release];web7=nil;[backend7 release];backend7=nil;[host7 release];host7=nil;[production7 release];production7=nil;[lineBreak7 release];lineBreak7=nil;
 RCStageSet(stage7);[RCTheme setAppearance:(RCAppearance)appearance7];[RCTheme setTextSize:(RCTextSize)size7];
 // Raw app-domain values back now and once more after the released fixture controllers finished
 // deallocating (their dictation delegate writes ChatGPTXUI9RecordingID while it tears down).
 NSDictionary*saved=[defaults7 autorelease];defaults7=nil;void(^restore)(void)=^{NSUserDefaults*d=NSUserDefaults.standardUserDefaults;for(NSString*k in Keys()){if(saved[k])[d setObject:saved[k]forKey:k];else[d removeObjectForKey:k];}[d synchronize];};
 restore();dispatch_async(dispatch_get_main_queue(),[[restore copy]autorelease]);
 BOOL clean=directory7&&[NSFileManager.defaultManager removeItemAtPath:directory7 error:NULL];[directory7 release];directory7=nil;resigns7=synthetic7=owners7=0;return clean;
}
static BOOL Fail(void){OR6Chat7FixtureClose();return NO;}
// Fixture-only stable names for kit controls that have no production identifier.
NSString*OR6Chat7FixtureIdentify(UIView*v){
 if(!root7)return nil;UIView*s=v.superview;
 if([s isKindOfClass:RCPlaybackView.class])return v==[(RCPlaybackView*)s playButton]?@"chat.ui7.playback.play":v==[(RCPlaybackView*)s stopButton]?@"chat.ui7.playback.stop":nil;
 if([s isKindOfClass:RCFilePartView.class]&&v==[(RCFilePartView*)s actionButton])return @"chat.ui7.file.action";
 if([v isKindOfClass:UIButton.class])for(UIView*a=s;a;a=a.superview)if([a isKindOfClass:RCCodeBlockView.class])return @"chat.ui7.code.copy";
 if([v isKindOfClass:UITableView.class]){for(UIResponder*r=v;r;r=r.nextResponder)if([r isKindOfClass:UIViewController.class])return[r isKindOfClass:RCFormViewController.class]?@"chat.ui7.form":nil;}
 return nil;
}
