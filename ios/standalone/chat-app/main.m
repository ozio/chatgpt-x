#import "../../localization/OR6Localization.h"
#import <UIKit/UIKit.h>
#import "../../chat/OR6ChatCoordinator.h"
#import "../../chat/OR6ChatScreens.h"
#import "../../api/priority8/OR6API8Policy.h"
#import "RCTheme.h"
#import "RCFormViewController.h"
#import "../../webport/OR6WebPortBootstrap.h"
#import "../../ui/priority7/OR6Chat7Conversation.h"
#import "../../api/priority7g/OR6API7GDevice.h"
#ifdef OR6_CHAT_ACCEPTANCE
void OR6ChatAcceptanceStart(UIWindow*,OR6ChatCoordinator*);
#endif
// UIResponder: the end of the responder chain, so lock-screen/headset play-pause reaches -remoteControlReceivedWithEvent:.
@interface ChatGPTXApp:UIResponder<UIApplicationDelegate>{UIWindow*_window;UIView*_privacy;OR6ChatCoordinator*_coordinator;}
@property(nonatomic,retain)UIWindow*window;
@end
@implementation ChatGPTXApp
@synthesize window=_window;
- (BOOL)application:(UIApplication*)app didFinishLaunchingWithOptions:(NSDictionary*)options{(void)app;(void)options;[RCTheme applyAppearance];OR6ChatApplySavedLook();_window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];if(![OR6WebPortDiagnostics()[@"ready"]boolValue]){RCFormViewController*failure=[[[RCFormViewController alloc]init]autorelease];failure.title=@"ChatGPT X";failure.sections=@[[RCFormSection sectionWithTitle:nil rows:@[[RCFormRow rowWithKind:RCFormRowNote title:OR6L(@"Could not open ChatGPT X. Restart the app.")]]]];_window.rootViewController=[[[UINavigationController alloc]initWithRootViewController:failure]autorelease];[_window makeKeyAndVisible];return YES;}NSError*error=nil;_coordinator=[[OR6ChatCoordinator alloc]initWithWindow:_window error:&error];if(!_coordinator){UIViewController*vc=[[[UIViewController alloc]init]autorelease];vc.view.backgroundColor=UIColor.whiteColor;UILabel*label=[[[UILabel alloc]initWithFrame:CGRectMake(20,80,280,180)]autorelease];label.numberOfLines=0;label.text=OR6L(@"Could not open ChatGPT X. Restart the app.");[vc.view addSubview:label];_window.rootViewController=vc;}else _window.rootViewController=_coordinator.root;[_window makeKeyAndVisible];
 // Finish UIKit launch before the provider/auth chain restores the existing session.
 // The full legacy API registry can otherwise consume the iOS6 launch watchdog budget.
 [self performSelector:@selector(startCoordinator) withObject:nil afterDelay:0];return YES;}
- (void)startCoordinator{[_coordinator start];
#ifdef OR6_CHAT_ACCEPTANCE
 OR6ChatAcceptanceStart(_window,_coordinator);
#endif
}
- (BOOL)application:(UIApplication*)app openURL:(NSURL*)url sourceApplication:(NSString*)source annotation:(id)annotation{(void)app;(void)source;(void)annotation;if(url.isFileURL)return OR6API8InboxDeliveryURL(url,NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES)[0]);
 /* chatgpt:/openai:/com.openai.chat:/codex: links: routes.resolve after the session is ready; the draft stays, nothing is sent. */
 if(OR6Chat7RouteURL(url))return url.absoluteString.length<=4096&&!url.user&&!url.password&&!url.port&&[_coordinator openRouteURL:url];if(![url.scheme isEqual:@"chatgptx-auth"]||url.query||url.fragment||url.user||url.password||url.port)return NO;if([url.host isEqual:@"open"])return !url.path.length;if([url.host isEqual:@"conversation"]&&[url.path hasPrefix:@"/"])return[_coordinator openConversationIdentifier:[url.path substringFromIndex:1]];return NO;}
- (void)applicationWillResignActive:(UIApplication*)app{(void)app;[_coordinator deactivate];if(!_privacy){_privacy=[[UIView alloc]initWithFrame:_window.bounds];_privacy.backgroundColor=[RCTheme contentBackgroundColor];[_window addSubview:_privacy];}}
- (void)applicationDidBecomeActive:(UIApplication*)app{(void)app;[_privacy removeFromSuperview];[_privacy release];_privacy=nil;[_coordinator activate];}
- (void)remoteControlReceivedWithEvent:(UIEvent*)event{if(event.type==UIEventTypeRemoteControl)[NSNotificationCenter.defaultCenter postNotificationName:OR6API7GRemoteControlNotification object:nil userInfo:@{@"subtype":@(event.subtype)}];} // read aloud: the playback device acts
- (void)dealloc{[_coordinator deactivate];[_coordinator release];[_privacy release];[_window release];[super dealloc];}
@end
int main(int argc,char**argv){NSAutoreleasePool*p=[NSAutoreleasePool new];OR6WebPortBootstrap([[NSBundle.mainBundle objectForInfoDictionaryKey:@"OR6WebPortProbeRequireBundled"]boolValue]);int result=UIApplicationMain(argc,argv,nil,NSStringFromClass(ChatGPTXApp.class));[p drain];return result;}
