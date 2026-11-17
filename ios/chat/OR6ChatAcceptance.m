// Optional development acceptance actor, excluded from ordinary app builds.
// Own process/public UIKit only. No credential fields or browser DOM observation.
// This file exists only in acceptance builds; it needs the acceptance-only declarations.
#ifndef OR6_CHAT_ACCEPTANCE
#define OR6_CHAT_ACCEPTANCE 1
#endif
#import "OR6ChatCoordinator.h"
#include <unistd.h>
#import <CommonCrypto/CommonDigest.h>
#include <sys/stat.h>
UIViewController*OR6CodexFixtureCreate(void);
NSDictionary*OR6CodexFixtureState(NSString*page);
BOOL OR6CodexFixtureClose(void);
UIViewController*OR6Chat9FixtureCreate(void);
NSDictionary*OR6Chat9FixtureState(NSString*mode);
BOOL OR6Chat9FixtureClose(void);
UIViewController*OR6Chat8FixtureCreate(void);
OR6ChatRootController*OR6Chat8FixtureRoot(void);
NSDictionary*OR6Chat8FixtureState(void);
NSDictionary*OR6Chat8FixtureMode(NSString*mode);
BOOL OR6Chat8FixtureClose(void);
@class OR6API7AllComposition;
UIViewController*OR6Chat7FixtureCreate(OR6API7AllComposition*production);
OR6ChatRootController*OR6Chat7FixtureRoot(void);
NSDictionary*OR6Chat7FixtureState(void);
NSDictionary*OR6Chat7FixtureMode(NSString*mode);
NSDictionary*OR6Chat7FixtureLifecycle(NSString*event);
NSDictionary*OR6Chat7FixtureSheet(NSString*title);
NSDictionary*OR6Chat7FixtureScroll(NSString*part);
NSString*OR6Chat7FixtureIdentify(UIView*view);
BOOL OR6Chat7FixtureClose(void);
// The open synthetic fixture root (UI8 or UI7), if any: fixture-only input/select/identification.
static OR6ChatRootController*FixtureRoot(void){return OR6Chat8FixtureRoot()?:OR6Chat7FixtureRoot();}
@interface OR6ChatAcceptance:NSObject{UIWindow*_window;OR6ChatCoordinator*_coordinator;NSString*_directory,*_key,*_snapshot;NSTimer*_timer;NSDictionary*_targets;NSDate*_observed;NSMutableSet*_seen;BOOL _keptAwake,_idleBefore;}
- (id)initWithWindow:(UIWindow*)window coordinator:(OR6ChatCoordinator*)coordinator;
@end
NSDictionary*OR6ChatLive7(OR6ChatCoordinator*,NSDictionary*);
NSDictionary*OR6StockCycle(OR6ChatCoordinator*,NSDictionary*);
@implementation OR6ChatAcceptance
- (id)initWithWindow:(UIWindow*)window coordinator:(OR6ChatCoordinator*)coordinator{if((self=[super init])){_directory=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES)[0]copy];NSData*d=[NSData dataWithContentsOfFile:[_directory stringByAppendingPathComponent:@"ChatUIAcceptanceKey"]];if(d.length!=64){[self release];return nil;}_key=[[NSString alloc]initWithData:d encoding:NSASCIIStringEncoding];if(_key.length!=64){[self release];return nil;}_window=[window retain];_coordinator=[coordinator retain];_seen=[NSMutableSet new];_timer=[[NSTimer scheduledTimerWithTimeInterval:.3 target:self selector:@selector(tick:)userInfo:nil repeats:YES]retain];for(NSString*n in @[UIApplicationWillResignActiveNotification,UIApplicationDidEnterBackgroundNotification])[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(lifecycle:)name:n object:nil];}return self;}
- (void)lifecycle:(NSNotification*)n{(void)n;[_snapshot release];_snapshot=nil;} // a lifecycle transition invalidates every observation
- (void)walk:(UIView*)v into:(NSMutableDictionary*)targets nodes:(NSMutableArray*)nodes{
 if(v.hidden||v.alpha<.01||[v isKindOfClass:UIWebView.class])return;NSString*identifier=v.accessibilityIdentifier;
 if(OR6Chat7FixtureRoot()&&!identifier.length)identifier=OR6Chat7FixtureIdentify(v);
 if(FixtureRoot()&&!identifier.length){
  if([v isKindOfClass:UIButton.class]){NSString*t=[(UIButton*)v titleForState:UIControlStateNormal];if(!t.length)t=v.accessibilityLabel;if(t.length&&t.length<=200)identifier=[@"chat.acceptance.button."stringByAppendingString:t];}
  else if([v isKindOfClass:UITextView.class])identifier=[NSString stringWithFormat:@"chat.acceptance.input.%lu",(unsigned long)nodes.count];
  else if([v isKindOfClass:UITextField.class])identifier=@"chat.acceptance.search";
 }
 if([identifier hasPrefix:@"chat."]&&([v isKindOfClass:UIControl.class]||[v isKindOfClass:UITextView.class]||[v isKindOfClass:UITableView.class])){
  CGRect frame=[v convertRect:v.bounds toView:_window];if(CGRectIntersectsRect(frame,_window.bounds)){if(targets[identifier])targets[identifier]=NSNull.null;else targets[identifier]=v;[nodes addObject:@{@"id":identifier,@"class":NSStringFromClass(v.class),@"enabled":[v isKindOfClass:UIControl.class]?@(((UIControl*)v).enabled):@YES,@"frame":@[@(frame.origin.x),@(frame.origin.y),@(frame.size.width),@(frame.size.height)]}];}
 }for(UIView*child in v.subviews)[self walk:child into:targets nodes:nodes];
}
- (NSDictionary*)observe{NSMutableDictionary*t=[NSMutableDictionary dictionary];NSMutableArray*n=[NSMutableArray array];[self walk:_window into:t nodes:n];[_targets release];_targets=[t copy];[_snapshot release];_snapshot=[NSProcessInfo.processInfo.globallyUniqueString copy];[_observed release];_observed=[NSDate new];return @{@"snapshot":_snapshot,@"nodes":n,@"pid":@((int)getpid())};}
- (NSString*)clipboardFingerprint{NSData*d=[NSPropertyListSerialization dataWithPropertyList:UIPasteboard.generalPasteboard.items?:@[] format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];if(!d)return nil;unsigned char hash[CC_SHA256_DIGEST_LENGTH];CC_SHA256(d.bytes,(CC_LONG)d.length,hash);NSMutableString*s=[NSMutableString string];for(NSUInteger i=0;i<sizeof(hash);i++)[s appendFormat:@"%02x",hash[i]];return s;}
- (NSString*)clipboardPath{return[_directory stringByAppendingPathComponent:@"ChatUIAcceptancePasteboard.plist"];}
- (BOOL)updateClipboardExpectation{NSString*path=[self clipboardPath];NSDictionary*old=[NSDictionary dictionaryWithContentsOfFile:path];if(!old)return YES;NSMutableDictionary*next=[[old mutableCopy]autorelease];next[@"expected"]=[self clipboardFingerprint]?:@"";BOOL ok=[next writeToFile:path atomically:YES];chmod(path.fileSystemRepresentation,0600);return ok;}
- (NSDictionary*)clipboardAction:(NSString*)action{
 NSString*path=[self clipboardPath];if([action isEqual:@"clipboard_backup"]){if([NSFileManager.defaultManager fileExistsAtPath:path])return @{@"ok":@NO,@"error":@"clipboard_backup_exists"};NSArray*items=UIPasteboard.generalPasteboard.items?:@[];NSData*data=[NSPropertyListSerialization dataWithPropertyList:items format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];if(!data||data.length>1048576)return @{@"ok":@NO,@"error":@"clipboard_not_restorable"};BOOL ok=[@{@"items":items,@"expected":[self clipboardFingerprint]?:@""}writeToFile:path atomically:YES];if(ok)chmod(path.fileSystemRepresentation,0600);return @{@"ok":@(ok)};}
 if([action isEqual:@"clipboard_restore"]){NSDictionary*backup=[NSDictionary dictionaryWithContentsOfFile:path];if(!backup||![backup[@"expected"]isEqual:[self clipboardFingerprint]])return @{@"ok":@NO,@"error":@"clipboard_changed_or_missing"};UIPasteboard.generalPasteboard.items=backup[@"items"];BOOL ok=[UIPasteboard.generalPasteboard.items isEqual:backup[@"items"]];if(ok)ok=[NSFileManager.defaultManager removeItemAtPath:path error:NULL];return @{@"ok":@(ok)};}
 NSString*text=UIPasteboard.generalPasteboard.string?:@"";NSData*data=[text dataUsingEncoding:NSUTF8StringEncoding];unsigned char hash[CC_SHA256_DIGEST_LENGTH];CC_SHA256(data.bytes,(CC_LONG)data.length,hash);NSMutableString*sum=[NSMutableString string];for(NSUInteger i=0;i<sizeof(hash);i++)[sum appendFormat:@"%02x",hash[i]];return @{@"ok":@YES,@"characters":@(text.length),@"textSHA256":sum,@"backupPresent":@([NSFileManager.defaultManager fileExistsAtPath:path])};
}
- (NSDictionary*)perform:(NSDictionary*)p{
 if([p[@"action"]hasPrefix:@"stock_"]){if(![_snapshot isEqual:p[@"snapshot"]]||-_observed.timeIntervalSinceNow>30)return @{@"ok":@NO,@"error":@"stale_observation"};return OR6StockCycle(_coordinator,p);}
 if([p[@"action"]hasPrefix:@"live7_"]){if(![_snapshot isEqual:p[@"snapshot"]]||-_observed.timeIntervalSinceNow>30)return @{@"ok":@NO,@"error":@"stale_observation"};return OR6ChatLive7(_coordinator,p);}
 if([p[@"action"]hasPrefix:@"ui_"]){if(![_snapshot isEqual:p[@"snapshot"]]||-_observed.timeIntervalSinceNow>30)return @{@"ok":@NO,@"error":@"stale_observation"};NSDictionary*r=[(FixtureRoot()?:_coordinator.root) acceptanceAction:p[@"action"]value:p[@"value"]];return r?:@{@"ok":@NO};}
 if([p[@"action"]isEqual:@"observe"])return @{@"ok":@YES,@"observation":[self observe]};
 if([p[@"action"]hasPrefix:@"codex_fixture_"]){
  if(![_snapshot isEqual:p[@"snapshot"]]||-_observed.timeIntervalSinceNow>30)return@{@"ok":@NO,@"error":@"stale_observation"};
  if([p[@"action"]isEqual:@"codex_fixture_open"]){if(_coordinator.root.presentedViewController||[_coordinator.root.diagnostics[@"conversation"][@"sending"]boolValue]||[_coordinator.root.diagnostics[@"conversation"][@"uncertain"]boolValue])return@{@"ok":@NO,@"error":@"active_chat"};UIViewController*c=OR6CodexFixtureCreate();if(!c)return@{@"ok":@NO};[_coordinator.root presentViewController:c animated:NO completion:nil];return@{@"ok":@YES};}
  if([p[@"action"]isEqual:@"codex_fixture_close"]){[_coordinator.root dismissViewControllerAnimated:NO completion:nil];return@{@"ok":@(OR6CodexFixtureClose())};}
  return OR6CodexFixtureState(p[@"page"]?:@"state");
 }
 if([p[@"action"]hasPrefix:@"ui8_fixture_"]){
  if(![_snapshot isEqual:p[@"snapshot"]]||-_observed.timeIntervalSinceNow>30)return @{@"ok":@NO,@"error":@"stale_observation"};
  if([p[@"action"]isEqual:@"ui8_fixture_state"])return OR6Chat8FixtureState();
  if([p[@"action"]isEqual:@"ui8_fixture_mode"]&&[p[@"mode"]isKindOfClass:NSString.class])return OR6Chat8FixtureMode(p[@"mode"]);
  if([p[@"action"]isEqual:@"ui8_fixture_open"]){if(OR6Chat7FixtureRoot()||_coordinator.root.presentedViewController||[_coordinator.root.diagnostics[@"conversation"][@"sending"]boolValue]||[_coordinator.root.diagnostics[@"conversation"][@"uncertain"]boolValue])return @{@"ok":@NO,@"error":@"active_chat"};UIViewController*f=OR6Chat8FixtureCreate();if(!f)return @{@"ok":@NO,@"error":@"fixture_unavailable"};[_coordinator.root presentViewController:f animated:NO completion:nil];return @{@"ok":@YES};}
  if([p[@"action"]isEqual:@"ui8_fixture_close"]){if(!OR6Chat8FixtureRoot())return @{@"ok":@NO};[_coordinator.root dismissViewControllerAnimated:NO completion:nil];return @{@"ok":@(OR6Chat8FixtureClose())};}
 }
 // UI7 physical fixture: production UI over the local fixture composition (tests/chat-ui7-physical).
 if([p[@"action"]hasPrefix:@"ui7_fixture_"]){
  if(![_snapshot isEqual:p[@"snapshot"]]||-_observed.timeIntervalSinceNow>30)return @{@"ok":@NO,@"error":@"stale_observation"};
  if([p[@"action"]isEqual:@"ui7_fixture_open"]){if(FixtureRoot()||_coordinator.root.presentedViewController||[_coordinator.root.diagnostics[@"conversation"][@"sending"]boolValue]||[_coordinator.root.diagnostics[@"conversation"][@"uncertain"]boolValue])return @{@"ok":@NO,@"error":@"active_chat"};UIViewController*f=OR6Chat7FixtureCreate([_coordinator valueForKey:@"api7"]);if(!f)return @{@"ok":@NO,@"error":@"fixture_unavailable"};[_coordinator.root presentViewController:f animated:NO completion:nil];return @{@"ok":@YES};}
  if(!OR6Chat7FixtureRoot())return @{@"ok":@NO,@"error":@"fixture_closed"};
  if([p[@"action"]isEqual:@"ui7_fixture_state"])return OR6Chat7FixtureState();
  if([p[@"action"]isEqual:@"ui7_fixture_mode"]&&[p[@"mode"]isKindOfClass:NSString.class])return OR6Chat7FixtureMode(p[@"mode"]);
  if([p[@"action"]isEqual:@"ui7_fixture_lifecycle"]&&[p[@"event"]isKindOfClass:NSString.class])return OR6Chat7FixtureLifecycle(p[@"event"]);
  if([p[@"action"]isEqual:@"ui7_fixture_sheet"])return OR6Chat7FixtureSheet(p[@"title"]);
  if([p[@"action"]isEqual:@"ui7_fixture_scroll"])return OR6Chat7FixtureScroll(p[@"part"]);
  if([p[@"action"]isEqual:@"ui7_fixture_close"]){[_coordinator.root dismissViewControllerAnimated:NO completion:nil];return @{@"ok":@(OR6Chat7FixtureClose())};}
  return @{@"ok":@NO,@"error":@"action_unavailable"};
 }
 OR6ChatRootController*host=FixtureRoot()?:_coordinator.root;
 UINavigationController*nav=host.frontNavigationController;if(![nav isKindOfClass:UINavigationController.class]||(host.presentedViewController&&!FixtureRoot()))return @{@"ok":@NO,@"error":@"modal_or_unavailable"};
 if([p[@"action"]isEqual:@"observe"])return @{@"ok":@YES,@"observation":[self observe]};
 if(![_snapshot isEqual:p[@"snapshot"]]||-_observed.timeIntervalSinceNow>30)return @{@"ok":@NO,@"error":@"stale_observation"};
 if([p[@"action"]isEqual:@"hold_awake"]){if(!_keptAwake){_idleBefore=UIApplication.sharedApplication.idleTimerDisabled;_keptAwake=YES;}UIApplication.sharedApplication.idleTimerDisabled=YES;return @{@"ok":@YES};}
 if([p[@"action"]isEqual:@"release_awake"]){if(_keptAwake)UIApplication.sharedApplication.idleTimerDisabled=_idleBefore;_keptAwake=NO;return @{@"ok":@YES};}
 if([p[@"action"]isEqual:@"dictation_limit"]){NSNumber*ms=p[@"milliseconds"];if(![ms isKindOfClass:NSNumber.class]||![_coordinator.root setDictationLimitMS:ms.unsignedIntegerValue])return @{@"ok":@NO,@"error":@"limit_unavailable"};return @{@"ok":@YES};}
 if([p[@"action"]isEqual:@"ui9_fixture_open"]){if([_coordinator.root.diagnostics[@"conversation"][@"sending"]boolValue]||[_coordinator.root.diagnostics[@"conversation"][@"uncertain"]boolValue])return @{@"ok":@NO,@"error":@"active_chat"};UIViewController*c=OR6Chat9FixtureCreate();if(!c)return @{@"ok":@NO,@"error":@"fixture_exists"};[nav pushViewController:c animated:NO];return @{@"ok":@YES};}
 if([p[@"action"]isEqual:@"ui9_fixture_state"])return OR6Chat9FixtureState(nil);
 if([p[@"action"]isEqual:@"ui9_fixture_mode"]){if(![p[@"mode"]isKindOfClass:NSString.class])return @{@"ok":@NO,@"error":@"bad_mode"};return OR6Chat9FixtureState(p[@"mode"]);}
 if([p[@"action"]isEqual:@"ui9_fixture_close"]){[nav popToRootViewControllerAnimated:NO];return @{@"ok":@(OR6Chat9FixtureClose())};}
 if([p[@"action"]isEqual:@"clipboard_expect"])return @{@"ok":@([self updateClipboardExpectation])}; // after an acceptance-driven copy
 if([@[@"clipboard_backup",@"clipboard_status",@"clipboard_restore"]containsObject:p[@"action"]])return[self clipboardAction:p[@"action"]];
 if([p[@"action"]isEqual:@"back"]){if(nav.viewControllers.count<2)return @{@"ok":@NO,@"error":@"no_back"};[nav popViewControllerAnimated:NO];return @{@"ok":@YES};}
 id target=_targets[p[@"target"]];if(!target||target==NSNull.null||![(UIView*)target window]||[(UIView*)target isHidden])return @{@"ok":@NO,@"error":@"target_unavailable"};
 if(FixtureRoot()&&[p[@"action"]isEqual:@"switch"]&&[target isKindOfClass:UISwitch.class]&&[p[@"on"]isKindOfClass:NSNumber.class]){[(UISwitch*)target setOn:[p[@"on"]boolValue]animated:NO];[(UISwitch*)target sendActionsForControlEvents:UIControlEventValueChanged];return @{@"ok":@YES};}
 if(FixtureRoot()&&[p[@"action"]isEqual:@"input"]&&[p[@"target"]isEqual:@"chat.acceptance.search"]&&[target isKindOfClass:UITextField.class]&&[p[@"text"]isKindOfClass:NSString.class]&&[p[@"text"]length]<=128){UIView*v=target;while(v&&![v isKindOfClass:UISearchBar.class])v=v.superview;if(!v)return @{@"ok":@NO};UISearchBar*bar=(id)v;bar.text=p[@"text"];if([bar.delegate respondsToSelector:@selector(searchBar:textDidChange:)])[bar.delegate searchBar:bar textDidChange:p[@"text"]];return @{@"ok":@YES};}
 if([p[@"action"]isEqual:@"tap"]&&[target isKindOfClass:UIControl.class]&&[target isEnabled]){[target sendActionsForControlEvents:UIControlEventTouchUpInside];if([@[@"chat.message.copy",@"chat.message.copy_code",@"chat.ui7.code.copy"]containsObject:p[@"target"]]&&![self updateClipboardExpectation])return @{@"ok":@NO,@"error":@"clipboard_receipt_write"};return @{@"ok":@YES};}
 if([p[@"action"]isEqual:@"focus"]&&([p[@"target"]isEqual:@"chat.composer"]||[p[@"target"]isEqual:@"chat.dictation.text"]||(FixtureRoot()&&([p[@"target"]hasPrefix:@"chat.acceptance.input."]||[p[@"target"]isEqual:@"chat.composer.expanded"])))&&[target isKindOfClass:UITextView.class]&&[target isEditable])return @{@"ok":@([target becomeFirstResponder])};
 if([p[@"action"]isEqual:@"input"]&&([p[@"target"]isEqual:@"chat.composer"]||[p[@"target"]isEqual:@"chat.dictation.text"]||(FixtureRoot()&&([p[@"target"]hasPrefix:@"chat.acceptance.input."]||[p[@"target"]isEqual:@"chat.composer.expanded"])))&&[target isKindOfClass:UITextView.class]&&[target isEditable]&&[p[@"text"]isKindOfClass:NSString.class]&&[p[@"text"]length]<=1024){UITextView*v=target;v.text=p[@"text"];if([v.delegate respondsToSelector:@selector(textViewDidChange:)])[v.delegate textViewDidChange:v];return @{@"ok":@YES,@"characters":@(v.text.length)};}
 if([p[@"action"]isEqual:@"copy_selection"]&&[p[@"target"]isEqual:@"chat.message.selection"]&&[target isKindOfClass:UITextView.class]){UITextView*v=target;if(!v.selectedRange.length)return @{@"ok":@NO,@"error":@"no_selection"};[v copy:nil];return @{@"ok":@([self updateClipboardExpectation])};}
 if([p[@"action"]isEqual:@"select"]&&([p[@"target"]isEqual:@"chat.history.table"]||[p[@"target"]isEqual:@"chat.session.table"]||[p[@"target"]isEqual:@"chat.messages"]||(FixtureRoot()&&([p[@"target"]isEqual:@"chat.settings.choice"]||[p[@"target"]isEqual:@"chat.inbox"]||[p[@"target"]isEqual:@"chat.ui7.form"])))&&[target isKindOfClass:UITableView.class]&&[p[@"row"]isKindOfClass:NSNumber.class]&&(!p[@"section"]||[p[@"section"]isKindOfClass:NSNumber.class])){UITableView*t=target;NSInteger row=[p[@"row"]integerValue],section=[p[@"section"]integerValue];if(section>=0&&section<[t numberOfSections]&&row>=0&&row<[t numberOfRowsInSection:section]){NSIndexPath*i=[NSIndexPath indexPathForRow:row inSection:section];if([t.delegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)])[t.delegate tableView:t didSelectRowAtIndexPath:i];return @{@"ok":@YES};}}
 return @{@"ok":@NO,@"error":@"action_unavailable"};
}
- (void)tick:(NSTimer*)timer{
 (void)timer;if(![NSFileManager.defaultManager fileExistsAtPath:[_directory stringByAppendingPathComponent:@"ChatUIAcceptanceKey"]]){if(_keptAwake)UIApplication.sharedApplication.idleTimerDisabled=_idleBefore;_keptAwake=NO;[_timer invalidate];return;}[_coordinator writeReceipt];NSString*path=[_directory stringByAppendingPathComponent:@"ChatUIAcceptanceCommand.json"];NSData*d=[NSData dataWithContentsOfFile:path];if(!d||d.length>4096)return;NSDictionary*p=[NSJSONSerialization JSONObjectWithData:d options:0 error:NULL];if(![p isKindOfClass:NSDictionary.class]||![p[@"key"]isEqual:_key]||![p[@"id"]isKindOfClass:NSString.class]||[p[@"id"]length]>64||[_seen containsObject:p[@"id"]]||_seen.count>=512)return;
 [_seen addObject:p[@"id"]];NSDictionary*r=nil;@try{r=[self perform:p];}@catch(NSException*e){(void)e;r=@{@"ok":@NO,@"error":@"action_failed"};}NSMutableDictionary*out=[NSMutableDictionary dictionaryWithDictionary:r];out[@"id"]=p[@"id"];[[NSJSONSerialization dataWithJSONObject:out options:0 error:NULL]writeToFile:[_directory stringByAppendingPathComponent:@"ChatUIAcceptanceResult.json"]atomically:YES];if(![p[@"action"]isEqual:@"observe"]){[_snapshot release];_snapshot=nil;}[_coordinator writeReceipt];
}
- (void)dealloc{[NSNotificationCenter.defaultCenter removeObserver:self];[_timer invalidate];[_timer release];[_window release];[_coordinator release];[_directory release];[_key release];[_snapshot release];[_observed release];[_targets release];[_seen release];[super dealloc];}
@end
void OR6ChatAcceptanceStart(UIWindow*window,OR6ChatCoordinator*coordinator){static OR6ChatAcceptance*actor;actor=[[OR6ChatAcceptance alloc]initWithWindow:window coordinator:coordinator];(void)actor;}
