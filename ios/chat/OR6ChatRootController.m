#import "../ui/selected20/OR6Chat20Screens.h"
#import "../localization/OR6Localization.h"
#import "OR6ChatRootController.h"
#import "OR6ChatConversationController.h"
#import "OR6ChatSessionController.h"
#import "OR6ChatWelcomeController.h"
#import "OR6ChatUIState.h"
#import "OR6ChatScreens.h"
#import "../ui/priority9/OR6Chat9MessageController.h"
#import "../ui/priority8/OR6Chat8Models.h"
#import "../ui/priority8/OR6Chat8Screens.h"
#import "../ui/priority7/OR6Chat7Conversation.h"
#import "../ui/priority6/OR6Chat6Screens.h"
#import "../ui/priority6/OR6Chat6Models.h"
#import "../ui/priority6/OR6Chat6Conversation.h"
#import "../ui/priority6/OR6Chat6Library.h"
#import "RCHUD.h"
#import "RCTheme.h"
#import "RCRevealController.h"
#import "RCDrawerController.h"
#import "RCTransition.h"
#import "RCLaunchView.h"
#import "RCHUD.h"
#import "../ui/priority8/OR6Chat8Screens.h"

@interface OR6ChatRootController()<RCDrawerControllerDelegate,OR6ChatConversationHost,OR6ChatWelcomeDelegate,OR6Chat8ModelDelegate,OR6Chat7Navigator>{
 OR6APICore*_core;id<OR6ChatUIHost> _host;OR6ChatHistoryState*_history;NSDictionary*_summary,*_profile;
 RCRevealController*_reveal;UINavigationController*_nav;RCDrawerController*_drawer;OR6ChatConversationController*_conversation;
 UINavigationController*_welcomeNav;OR6ChatWelcomeController*_welcome;OR6ChatSessionController*_account;RCLaunchView*_launch;
 id<OR6APITask>_request;NSUInteger _epoch;BOOL _busy,_everAuthenticated,_historyStale,_initialConversation,_flipToWelcome;NSString*_notice,*_search;NSDate*_historyLoaded;
 OR6Chat8Catalog*_catalog;OR6Chat8HistorySearch*_searcher;NSTimer*_searchTimer;NSString*_signInNotice; // priority 8
 OR6Chat6Pager*_global;NSString*_globalQuery; // stage 6: search.global, only on an explicit tap; opaque pages, partial sources
 OR6Chat7Call*_pins;BOOL _pinsWanted;NSURL*_pendingRoute; // priority 7: pinned chats (pins.list, once per drawer session), a route that waits for the session
}
@end

@implementation OR6ChatRootController
- (id)initWithCore:(OR6APICore*)core host:(id<OR6ChatUIHost>)host{
 if((self=[super init])){_core=[core retain];_host=host;_history=[OR6ChatHistoryState new];_catalog=[[OR6Chat8Catalog alloc]initWithCore:core];OR6Chat6SetChatCatalog(_catalog); /* Account Models uses the same catalog as Send. */
  _searcher=[[OR6Chat8HistorySearch alloc]initWithCore:core];_searcher.delegate=self;_global=[[OR6Chat6Pager alloc]initWithCore:core operation:@"search.global" parameters:@{} tokenKey:@"pageToken" nextKey:@"nextPageToken" idKey:@"id"];_global.maxPages=5;_global.delegate=self;_pins=[[OR6Chat7Call alloc]initWithCore:core];_pins.delegate=self;_pinsWanted=YES;
}
 return self;
}

// Every conversation screen shares the account's model catalog (models.list/select).
- (OR6ChatConversationController*)makeConversation:(NSString*)identifier{OR6ChatConversationController*c=[[[OR6ChatConversationController alloc]initWithCore:_core conversationId:identifier]autorelease];c.catalog=_catalog;return c;}
- (BOOL)api8:(NSString*)feature{return OR6Chat8Supports(_core,feature);}
- (void)setPriority8Features:(NSSet*)features{OR6Chat8SetAdmittedFeatures(features);[self renderDrawer];}

#pragma mark Containment

- (void)loadView{UIView*v=[[[UIView alloc]initWithFrame:UIScreen.mainScreen.applicationFrame]autorelease];v.backgroundColor=RCHex(0x1e4838);v.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;self.view=v;
 // Kit launch screen over the first frame (matches the bundled Default*.png) until the restored session says chat or welcome.
 _launch=[[RCLaunchView alloc]initWithFrame:v.bounds];_launch.autoresizingMask=v.autoresizingMask;_launch.accessibilityIdentifier=@"chat.launch";_launch.statusText=OR6L(@"Restoring session…");[v addSubview:_launch];[_launch showStatusAfterDelay:1.5];
 [self performSelector:@selector(finishLaunch) withObject:nil afterDelay:8];[self updateChild];}
- (void)finishLaunchIfReady{if(_launch&&_summary&&([_summary[@"authenticated"]boolValue]||![_summary[@"state"]isEqual:@"validating"]))[self finishLaunch];}
- (void)finishLaunch{if(!_launch)return;[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(finishLaunch) object:nil];RCLaunchView*l=_launch;_launch=nil;[l finish:[self wantsWelcome]?RCLaunchFinishWelcome:RCLaunchFinishContent completion:nil];[l release];}
- (void)show:(UIViewController*)child{
 UIViewController*current=nil;for(UIViewController*c in self.childViewControllers)if(c!=child)current=c;
 if(child.parentViewController==self&&!current)return;
 // Logging out turns the chat over to the sign-in screen like a card (kit flip).
 if(_flipToWelcome&&current&&child==_welcomeNav&&child.parentViewController!=self&&self.view.window){
  _flipToWelcome=NO;RCFlipChildViewControllers(self,current,child,RCFlipFromLeft,nil);return;
 }
 _flipToWelcome=NO;
 for(UIViewController*c in [[self.childViewControllers copy]autorelease]){if(c==child)continue;[c willMoveToParentViewController:nil];[c.view removeFromSuperview];[c removeFromParentViewController];}
 if(child.parentViewController==self)return;[self addChildViewController:child];child.view.frame=self.view.bounds;child.view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;if(_launch.superview==self.view)[self.view insertSubview:child.view belowSubview:_launch];else[self.view addSubview:child.view];[child didMoveToParentViewController:self];
}
- (BOOL)wantsWelcome{
 if(_everAuthenticated&&![_summary[@"state"]isEqual:@"signed_out"])return NO; // expired: banner in the chat keeps the draft
 return _summary&&![_summary[@"authenticated"]boolValue];
}
- (void)updateChild{
 if(!self.isViewLoaded)return;
 if([self wantsWelcome]){
  if(!_welcome){_welcome=[[OR6ChatWelcomeController alloc]init];_welcome.chatDelegate=self;_welcomeNav=[[UINavigationController alloc]initWithRootViewController:_welcome];[RCTheme styleNavigationBar:_welcomeNav.navigationBar variant:RCBarVariantJade];_welcomeNav.navigationBarHidden=YES;}
  [_welcome applySessionSummary:_summary notice:_notice];[self show:_welcomeNav];[self finishLaunchIfReady];return;
 }
 if(!_reveal){
  _drawer=[[RCDrawerController alloc]init];_drawer.delegate=self;_drawer.searchPlaceholder=OR6L(@"Search chats");
  if(!_conversation){_conversation=[[self makeConversation:nil]retain];_conversation.host=self;_initialConversation=YES;} // may already hold a restored send
  _nav=[[UINavigationController alloc]initWithRootViewController:_conversation];[RCTheme styleNavigationBar:_nav.navigationBar variant:RCBarVariantJade];
  _reveal=[[RCRevealController alloc]initWithFrontViewController:_nav drawerViewController:_drawer];
  [_conversation applySessionSummary:_summary];
 }
 [self show:_reveal];[self renderDrawer];[self finishLaunchIfReady];
}
- (UINavigationController*)frontNavigationController{return[self wantsWelcome]?_welcomeNav:_nav;}
- (void)setFront:(OR6ChatConversationController*)c{
 if(_conversation!=c){_initialConversation=NO;[_conversation prepareForBackground];_conversation.host=nil;[_conversation release];_conversation=[c retain];_conversation.host=self;}
 [_conversation applySessionSummary:_summary];[_conversation applySessionReady:[self sessionReady]];
 [_nav setViewControllers:@[_conversation]animated:NO];[_reveal setDrawerOpen:NO animated:YES];[self renderDrawer];
}
- (BOOL)sessionReady{return[_summary[@"authenticated"]boolValue]&&![_summary[@"state"]isEqual:@"validating"];}

#pragma mark Session

- (void)applyAccountProfile:(NSDictionary*)profile{if(profile==_profile||[profile isEqual:_profile])return;[_profile release];_profile=[profile copy];[_account applyAccountProfile:_profile];[self renderDrawer];}
- (void)applySessionSummary:(NSDictionary*)summary{
 BOOL wasAuth=[_summary[@"authenticated"]boolValue],auth=[summary[@"authenticated"]boolValue];[_summary release];_summary=[summary copy];[_notice release];_notice=nil;
 if(auth)_everAuthenticated=YES;
 if(wasAuth&&!auth){[self cancelRequest];[_history reset];[_historyLoaded release];_historyLoaded=nil;if([summary[@"state"]isEqual:@"signed_out"]){_flipToWelcome=YES;[_nav popToRootViewControllerAnimated:NO];[self setFront:[self makeConversation:nil]];_everAuthenticated=NO;}[_catalog reset];[_searcher reset];[_searchTimer invalidate];_searchTimer=nil;OR6Chat8ForgetUnresolved();[_pins reset];_pinsWanted=YES;[_pendingRoute release];_pendingRoute=nil;OR6Chat7ForgetSession();OR6Chat6ForgetSession();[_global reset];[_globalQuery release];_globalQuery=nil;} // the owner changed: no catalog or search results of the old session
 for(UIViewController*c in _nav.viewControllers)if([c isKindOfClass:OR6ChatConversationController.class]){[(id)c applySessionSummary:summary];[(id)c applySessionReady:[self sessionReady]];}
 [_account applySessionSummary:summary];[self updateChild];
 if(auth&&[self sessionReady]&&(_historyStale||!_history.loaded)&&_reveal.drawerOpen)[self loadFirst];
 if(_pendingRoute&&[self sessionReady]&&_nav){NSURL*u=[[_pendingRoute retain]autorelease];[_pendingRoute release];_pendingRoute=nil;[self openRouteURL:u];}
}
- (void)showSessionError:(NSError*)error{[_signInNotice release];_signInNotice=nil;[_notice release];_notice=[OR6ChatErrorText(error)copy];[_account showSessionError:error];[_welcome applySessionSummary:_summary notice:_notice];[self renderDrawer];}
- (void)welcomeDidRequestSignIn:(OR6ChatWelcomeController*)w{(void)w;OR6ChatSignIn(_host,_core,self.view.window?:self.view);}
- (void)conversationRequestsSignIn:(OR6ChatConversationController*)c{(void)c;OR6ChatSignIn(_host,_core,self.view.window?:self.view);}
- (void)applySignInInteraction:(NSDictionary*)interaction{
 NSDictionary*n=OR6Chat8InteractionNotice(interaction);NSString*text=[n[@"text"]length]?n[@"text"]:nil;
 [_signInNotice release];_signInNotice=[text copy];[_notice release];_notice=nil;
 if([n[@"phase"]isEqual:@"cancelled"]||[n[@"phase"]isEqual:@"failed"]){_notice=[text copy];[_account showSessionError:OR6APIError([n[@"phase"]isEqual:@"cancelled"]?@"auth_cancelled":@"auth_failed",@"none")];}
 [_welcome applySessionSummary:_summary notice:_notice];[self renderDrawer];
}

#pragma mark History in the drawer

- (void)cancelRequest{_epoch++;[_request cancel];[_request release];_request=nil;_busy=NO;}
- (void)loadPage:(NSString*)token{
 if(_busy||![self sessionReady])return;_busy=YES;[_notice release];_notice=nil;[self renderDrawer];NSUInteger epoch=++_epoch;__block BOOL finished=NO;
 id<OR6APITask>task=[_core perform:@"history.list"parameters:@{@"pageToken":token?:(id)NSNull.null,@"limit":@20}event:nil completion:^(NSDictionary*page,NSError*error){finished=YES;if(epoch!=_epoch)return;[_request release];_request=nil;_busy=NO;
  if(error){[_notice release];_notice=[OR6ChatErrorText(error)copy];}else if(![_history acceptPage:page token:token]){[_notice release];_notice=[OR6L(@"History arrived in an unknown format. Try loading it again later.")copy];}else{_historyStale=NO;[_historyLoaded release];_historyLoaded=[NSDate new];}
  [self renderDrawer];[NSNotificationCenter.defaultCenter postNotificationName:@"OR6ChatUIChanged"object:self];}];
 if(!finished&&epoch==_epoch)_request=[task retain];
}
- (void)loadFirst{if(_busy)return;[_history reset];[self loadPage:nil];}
- (void)loadMore{if(_history.nextToken)[self loadPage:_history.nextToken];}
- (void)drawerWillOpen{
 // History is read when the drawer opens (once, then again when stale or after 2 minutes).
 if([self sessionReady]&&(!_history.loaded||_historyStale||(_historyLoaded&&-_historyLoaded.timeIntervalSinceNow>120))&&!_busy)[self loadFirst];
 if([self sessionReady]&&_pinsWanted&&!_pins.busy&&OR6Chat7On(_core,@"pins.list")){_pinsWanted=NO;[_pins perform:@"pins.list"parameters:@{}];} // pinned chats: once, again after a pin change
}
static NSString*OR6DayLabel(NSNumber*updated){
 if(![updated isKindOfClass:NSNumber.class])return OR6L(@"Earlier");NSTimeInterval age=[[NSDate date]timeIntervalSince1970]-updated.doubleValue;
 NSCalendar*cal=NSCalendar.currentCalendar;NSDate*d=[NSDate dateWithTimeIntervalSince1970:updated.doubleValue];NSDateComponents*a=[cal components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit fromDate:d],*b=[cal components:NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit fromDate:[NSDate date]];
 if(a.year==b.year&&a.month==b.month&&a.day==b.day)return OR6L(@"Today");if(age<2*86400)return OR6L(@"Yesterday");if(age<7*86400)return OR6L(@"Previous 7 days");if(age<30*86400)return OR6L(@"Previous 30 days");return OR6L(@"Earlier");
}
- (void)renderDrawer{
 if(!_drawer)return;BOOL search=YES;_drawer.showsSearch=search;if(!search){[_search release];_search=nil;}
 NSMutableArray*sections=[NSMutableArray array];NSString*current=_conversation.conversationId;
 RCDrawerItem*newChat=[RCDrawerItem itemWithTitle:OR6L(@"New chat")glyph:@"compose" style:RCDrawerRowNav];newChat.current=current==nil&&_nav.topViewController==_conversation;newChat.userInfo=@"new";
 NSArray*items=_history.items;
 if(_search.length&&[self api8:OR6Chat8FHistorySearch]){
  // history.search (stage 8): paged results from the account, not a filter of the loaded titles.
  NSMutableArray*found=[NSMutableArray array];for(NSDictionary*d in _searcher.items){RCDrawerItem*i=[RCDrawerItem itemWithTitle:([d[@"title"]length]?d[@"title"]:OR6L(@"Untitled"))glyph:nil style:RCDrawerRowChat];i.userInfo=d;i.current=[d[@"id"]isEqual:current];[found addObject:i];}
  RCDrawerSection*s=[RCDrawerSection sectionWithTitle:(_searcher.loaded?[NSString stringWithFormat:OR6L(@"Found · %lu"),(unsigned long)found.count]:OR6L(@"Search in chats"))items:found];
  if(!found.count)s.emptyText=_searcher.issue?OR6ChatErrorText(OR6APIError(_searcher.issue,@"none")):_searcher.loaded?[NSString stringWithFormat:OR6L(@"Nothing found for “%@”."),_search]:(_searcher.busy?nil:OR6L(@"Searching starts when you stop typing."));
  [sections addObject:s];NSMutableArray*tail=[NSMutableArray array];
  if(_searcher.busy||_searcher.nextToken){RCDrawerItem*more=[RCDrawerItem itemWithTitle:(_searcher.busy?OR6L(@"Searching…"):OR6L(@"Show more"))glyph:nil style:RCDrawerRowMore];more.busy=_searcher.busy;more.userInfo=@"search-more";[tail addObject:more];}
  if(_searcher.issue&&!_searcher.busy){RCDrawerItem*retry=[RCDrawerItem itemWithTitle:OR6L(@"Try again")glyph:nil style:RCDrawerRowMore];retry.userInfo=@"search-retry";[tail addObject:retry];}
  if(tail.count)[sections addObject:[RCDrawerSection sectionWithTitle:nil items:tail]];
  [self addGlobalSearchTo:sections];
 }else if(_search.length){
  NSMutableArray*found=[NSMutableArray array];for(NSDictionary*d in items){NSString*t=[d[@"title"]length]?d[@"title"]:OR6L(@"Untitled");if([t rangeOfString:_search options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch].location!=NSNotFound){RCDrawerItem*i=[RCDrawerItem itemWithTitle:t glyph:nil style:RCDrawerRowChat];i.userInfo=d;i.current=[d[@"id"]isEqual:current];[found addObject:i];}}
  RCDrawerSection*s=[RCDrawerSection sectionWithTitle:[NSString stringWithFormat:OR6L(@"Chats · %lu"),(unsigned long)found.count]items:found];s.emptyText=[NSString stringWithFormat:OR6L(@"Nothing found for “%@”."),_search];[sections addObject:s];
  [self addGlobalSearchTo:sections];
 }else{
  NSMutableArray*top=[NSMutableArray arrayWithObject:newChat];
  if(OR6Chat7LibraryAvailable(_core)){RCDrawerItem*i=[RCDrawerItem itemWithTitle:OR6L(@"Library")glyph:@"library" style:RCDrawerRowNav];i.userInfo=@"library";[top addObject:i];}
  if(OR6Chat7ProjectsAvailable(_core)){RCDrawerItem*i=[RCDrawerItem itemWithTitle:OR6L(@"Projects")glyph:@"folder" style:RCDrawerRowNav];i.userInfo=@"projects";[top addObject:i];}
  if(OR6Chat7ArchiveAvailable(_core)){RCDrawerItem*i=[RCDrawerItem itemWithTitle:OR6L(@"Archive (collection)")glyph:@"archive" style:RCDrawerRowNav];i.userInfo=@"archive";[top addObject:i];}
  // Stage 6 destinations (prototype order: GPT, Tasks, Locked chats), each only when its read is granted.
  for(NSDictionary*e in [OR6Chat6DrawerEntries(_core) arrayByAddingObjectsFromArray:OR6Chat20DrawerEntries(_core)]){if([e[@"key"]isEqual:@"codex20"]&&[_host respondsToSelector:@selector(chatCodexController)])continue;RCDrawerItem*i=[RCDrawerItem itemWithTitle:e[@"title"]glyph:e[@"glyph"]style:RCDrawerRowNav];i.userInfo=e[@"key"];i.accessibilityIdentifier=e[@"identifier"];[top addObject:i];}
  if([_host respondsToSelector:@selector(chatCodexAvailable)]&&[_host chatCodexAvailable]){RCDrawerItem*i=[RCDrawerItem itemWithTitle:OR6L(@"Codex")glyph:@"terminal"style:RCDrawerRowNav];i.userInfo=@"codex20";i.accessibilityIdentifier=@"chat.drawer.codex";[top addObject:i];}
  // Account › Side menu: the user's choice of shown destinations («New chat» always stays).
  for(RCDrawerItem*i in [[top copy]autorelease])if(i!=newChat&&[i.userInfo isKindOfClass:NSString.class]&&!OR6ChatDrawerShows(i.userInfo))[top removeObject:i];
  [sections addObject:[RCDrawerSection sectionWithTitle:nil items:top]];
  NSArray*pinned=!_pins.error?_pins.result[@"items"]:nil;NSMutableArray*pins=[NSMutableArray array];
  for(NSDictionary*d in pinned){if(![d isKindOfClass:NSDictionary.class]||![d[@"id"]isKindOfClass:NSString.class])continue;RCDrawerItem*i=[RCDrawerItem itemWithTitle:([d[@"title"]length]?d[@"title"]:OR6L(@"Untitled"))glyph:@"pin" style:RCDrawerRowChat];i.userInfo=d;i.current=[d[@"id"]isEqual:current];i.actionsAvailable=OR6Chat7ConversationActions(_core,[self conversationInfo:d[@"id"]]).count>0;[pins addObject:i];}
  if(pins.count)[sections addObject:[RCDrawerSection sectionWithTitle:OR6L(@"Pinned")items:pins]];
  NSString*label=nil;NSMutableArray*group=nil;
  for(NSDictionary*d in items){NSString*l=OR6DayLabel(d[@"updatedAt"]);if(![l isEqual:label]){if(group.count)[sections addObject:[RCDrawerSection sectionWithTitle:label items:group]];label=l;group=[NSMutableArray array];}
   RCDrawerItem*i=[RCDrawerItem itemWithTitle:([d[@"title"]length]?d[@"title"]:OR6L(@"Untitled"))glyph:nil style:RCDrawerRowChat];i.userInfo=d;i.current=[d[@"id"]isEqual:current];i.actionsAvailable=OR6Chat7ConversationActions(_core,[self conversationInfo:d[@"id"]]).count>0;[group addObject:i];}
  if(group.count)[sections addObject:[RCDrawerSection sectionWithTitle:label items:group]];
  if(_notice&&!_busy){RCDrawerSection*note=[RCDrawerSection sectionWithTitle:nil items:@[]];note.emptyText=_notice;[sections addObject:note];}
  NSMutableArray*tail=[NSMutableArray array];
  if(_busy||_history.nextToken){RCDrawerItem*more=[RCDrawerItem itemWithTitle:(_busy?OR6L(@"Loading…"):OR6L(@"Show more"))glyph:nil style:RCDrawerRowMore];more.busy=_busy;more.userInfo=@"more";[tail addObject:more];}
  if(_notice&&!_busy){RCDrawerItem*retry=[RCDrawerItem itemWithTitle:OR6L(@"Try again")glyph:nil style:RCDrawerRowMore];retry.userInfo=@"retry";[tail addObject:retry];}
  RCDrawerSection*t=[RCDrawerSection sectionWithTitle:nil items:tail];
  if(!tail.count&&!items.count&&!_notice)t.emptyText=_history.loaded?OR6L(@"Your conversations will appear here."):([self sessionReady]?nil:OR6L(@"History appears after the session is restored."));
  if(tail.count||t.emptyText)[sections addObject:t];
 }
 _drawer.sections=sections;
 // Name / e-mail from the session's /me check when known; the second line stays the session state
 // unless the session is active and both a name and an e-mail are known.
 BOOL auth=[_summary[@"authenticated"]boolValue],validating=[_summary[@"state"]isEqual:@"validating"];NSString*shown=OR6ChatAccountDisplayName(_profile);
 _drawer.accountName=shown?:OR6L(@"Account");_drawer.accountEmail=validating?OR6L(@"Checking session…"):!auth?OR6L(@"Login required"):(_profile[@"name"]&&_profile[@"email"])?_profile[@"email"]:OR6L(@"Session active");_drawer.accountInitials=OR6ChatAccountInitials(_profile);
 _drawer.tableView.accessibilityIdentifier=@"chat.history.table";
}
- (void)drawer:(RCDrawerController*)d didSelectItem:(RCDrawerItem*)item{
 (void)d;id info=item.userInfo;
 if([info isEqual:@"new"]){[self newConversation];return;}
 if([info isEqual:@"more"]){if(!_busy)[self loadMore];return;}
 if([info isEqual:@"retry"]){[self loadFirst];return;}
 if([info isEqual:@"search-more"]){[_searcher loadMore];return;}
 if([info isEqual:@"search-global"]){[self searchGlobal];return;}
 if([info isEqual:@"search-global-more"]){[_global loadMore];[self renderDrawer];return;}
 if([info isEqual:@"search-global-retry"]){[_global retry];[self renderDrawer];return;}
 if([info isKindOfClass:NSDictionary.class]&&info[@"global"]){[self openGlobal:info[@"global"]];return;}
 if([info isEqual:@"library"]||[info isEqual:@"projects"]||[info isEqual:@"archive"]||OR6Chat6IsDrawerKey(info)||[info isEqual:@"images20"]||[info isEqual:@"codex20"]){[self pushCollection:info];return;}
 if([info isEqual:@"search-retry"]){NSString*q=[[_searcher.query copy]autorelease];[_searcher setQuery:@""];[_searcher setQuery:q];[_searcher search];return;}
 if(![info isKindOfClass:NSDictionary.class]||![self sessionReady])return;
 NSString*identifier=info[@"id"];if([identifier isEqual:_conversation.conversationId]&&_nav.topViewController==_conversation){[_reveal setDrawerOpen:NO animated:YES];return;}
 if([_conversation.diagnostics[@"sending"]boolValue]&&![identifier isEqual:_conversation.conversationId]){/* the running send keeps its own screen state; switching cancels only observation */}
 NSDictionary*snapshot=nil;OR6ChatConversationController*c=[self conversationForIdentifier:identifier snapshot:&snapshot];c.conversationTitle=[info[@"title"]length]?info[@"title"]:nil;[self setFront:c];if(snapshot)[c resumeRecoverySnapshot:snapshot];[_host chatPrepareConversation:identifier];
}
// Stage 6 (prototype: «Поиск в меню находит также проекты, GPT и файлы»): search.global runs only on
// an explicit tap for the typed query. Every result kind is listed — chats, projects, Library files and
// pages — those ChatGPT X cannot open say where they open; further pages continue with the service's
// opaque token, and a partial answer names the sources that did not answer.
- (NSString*)globalTrimmed{return[_search stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];}
- (BOOL)globalOpenable:(NSDictionary*)e{
 NSString*k=e[@"kind"];if([k isEqual:@"conversation"])return YES;if([k isEqual:@"project"])return OR6Chat7ProjectsAvailable(_core);
 if([k isEqual:@"file"])return OR6Chat6On(_core,@"library.node.get");return NO;
}
- (void)addGlobalSearchTo:(NSMutableArray*)sections{
 if(!OR6Chat6On(_core,@"search.global")||![self sessionReady])return;NSString*q=[self globalTrimmed];if(!q.length||q.length>240)return;
 if(![_globalQuery isEqual:q]){RCDrawerItem*go=[RCDrawerItem itemWithTitle:OR6L(@"Also search projects and files")glyph:nil style:RCDrawerRowMore];go.userInfo=@"search-global";go.accessibilityIdentifier=@"chat.drawer.search_global";[sections addObject:[RCDrawerSection sectionWithTitle:nil items:@[go]]];return;}
 NSMutableArray*found=[NSMutableArray array];NSDictionary*glyphs=@{@"conversation":@"compose",@"project":@"folder",@"file":@"file",@"page":@"text"};
 for(NSDictionary*r in _global.items){NSDictionary*e=OR6Chat6SearchEntry(r);if(!e)continue;
  RCDrawerItem*i=[RCDrawerItem itemWithTitle:e[@"title"]glyph:glyphs[e[@"kind"]]style:RCDrawerRowChat];i.userInfo=@{@"global":e};i.accessibilityIdentifier=@"chat.drawer.global_row";
  if(![self globalOpenable:e])i.count=OR6L(@"Web"); // opens in the web version: tapping explains it
  [found addObject:i];}
 NSString*notice=OR6Chat6SearchNotice(_global.pageResults);
 RCDrawerSection*s=[RCDrawerSection sectionWithTitle:(_global.loaded?[NSString stringWithFormat:OR6L(@"Elsewhere · %lu"),(unsigned long)found.count]:OR6L(@"Elsewhere"))items:found];
 if(!found.count)s.emptyText=_global.busy?OR6L(@"Searching…"):_global.error?OR6Chat7ErrorText(_global.error):notice?:[NSString stringWithFormat:OR6L(@"Nothing found for “%@”."),q];
 [sections addObject:s];
 NSMutableArray*tail=[NSMutableArray array];
 if(found.count&&notice){RCDrawerSection*n=[RCDrawerSection sectionWithTitle:nil items:@[]];n.emptyText=notice;[sections addObject:n];}
 if(found.count&&_global.error){RCDrawerSection*e=[RCDrawerSection sectionWithTitle:nil items:@[]];e.emptyText=OR6Chat7ErrorText(_global.error);[sections addObject:e];}
 if(_global.busy&&found.count){RCDrawerItem*b=[RCDrawerItem itemWithTitle:OR6L(@"Searching…")glyph:nil style:RCDrawerRowMore];b.busy=YES;[tail addObject:b];}
 else if(_global.retryAvailable){RCDrawerItem*retry=[RCDrawerItem itemWithTitle:OR6L(@"Try again")glyph:nil style:RCDrawerRowMore];retry.userInfo=@"search-global-retry";retry.accessibilityIdentifier=@"chat.drawer.global_retry";[tail addObject:retry];}
 else if(_global.hasMore){RCDrawerItem*more=[RCDrawerItem itemWithTitle:OR6L(@"Show more")glyph:nil style:RCDrawerRowMore];more.userInfo=@"search-global-more";more.accessibilityIdentifier=@"chat.drawer.global_more";[tail addObject:more];}
 if(tail.count)[sections addObject:[RCDrawerSection sectionWithTitle:nil items:tail]];
}
- (void)openGlobal:(NSDictionary*)e{
 NSString*k=e[@"kind"];
 if([k isEqual:@"conversation"]){[self chat7OpenConversation:e[@"conversationId"]title:e[@"title"]];return;}
 if([k isEqual:@"project"]&&OR6Chat7ProjectsAvailable(_core)){[self chat7OpenProject:e[@"projectId"]];return;}
 if([k isEqual:@"file"]&&OR6Chat6On(_core,@"library.node.get")){[self chat6OpenLibraryItem:e[@"libraryItemId"]];return;}
 NSString*where=[k isEqual:@"page"]?OR6L(@"Pages open in the ChatGPT web version."):[k isEqual:@"file"]?OR6L(@"This file opens in the ChatGPT web version."):OR6L(@"This result opens in the ChatGPT web version.");
 [RCHUD showText:(e[@"snippet"]?[NSString stringWithFormat:@"%@\n%@",e[@"snippet"],where]:where)kind:RCHUDTextOnly inView:self.view.window seconds:2.4];
}
- (void)searchGlobal{
 NSString*q=[self globalTrimmed];if(!q.length||q.length>240||![self sessionReady])return;
 [_globalQuery release];_globalQuery=[q copy];_global.parameters=@{@"query":q,@"filter":@"all",@"includeFolders":@NO,@"includeSpaces":@NO,@"providers":@[@"native"]};[_global reload];[self renderDrawer];
}
- (void)drawer:(RCDrawerController*)d searchTextDidChange:(NSString*)text{
 (void)d;[_search release];_search=[text copy];[_searchTimer invalidate];_searchTimer=nil;
 if(_globalQuery&&![_globalQuery isEqual:[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]]){[_global reset];[_globalQuery release];_globalQuery=nil;}
 if([self api8:OR6Chat8FHistorySearch]){[_searcher setQuery:text];if(_searcher.query.length&&[self sessionReady])_searchTimer=[NSTimer scheduledTimerWithTimeInterval:.45 target:self selector:@selector(searchTimer:)userInfo:nil repeats:NO];} // one request after typing pauses
 [self renderDrawer];
}
- (void)searchTimer:(NSTimer*)t{(void)t;_searchTimer=nil;if([self sessionReady])[_searcher search];}
- (void)chat8ModelChanged:(id)model{if(model==_searcher||model==_pins||model==_global)[self renderDrawer];}
- (void)drawerDidTapAccount:(RCDrawerController*)d{
 (void)d;if(!_account){_account=[[OR6ChatSessionController alloc]initWithHost:_host summary:_summary];_account.core=_core;}[_account applyAccountProfile:_profile];[_account applySessionSummary:_summary];
 [_nav popToRootViewControllerAnimated:NO];[_reveal setDrawerOpen:NO animated:YES];[_nav pushViewController:_account animated:YES];
}
- (void)viewDidLoad{[super viewDidLoad];[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(revealChanged:)name:RCRevealControllerWillOpenDrawerNotification object:nil];[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(drawerVisibilityChanged:)name:OR6ChatDrawerVisibilityChanged object:nil];}
- (void)drawerVisibilityChanged:(NSNotification*)n{(void)n;[self renderDrawer];}
- (void)revealChanged:(NSNotification*)n{if(n.object==_reveal)[self drawerWillOpen];}

#pragma mark API 7/10 navigation (OR6Chat7Navigator)

- (void)pushCollection:(NSString*)kind{
 if(![self sessionReady])return;UIViewController*c=([kind isEqual:@"codex20"]&&[_host respondsToSelector:@selector(chatCodexController)])?[_host chatCodexController]:OR6Chat20DrawerScreen(_core,kind,self);if(!c&&[kind isEqual:@"codex20"]&&[_host respondsToSelector:@selector(chatCodexController)])return;if(!c)c=[kind isEqual:@"library"]?OR6Chat7CreateLibrary(_core,self):[kind isEqual:@"projects"]?OR6Chat7CreateProjects(_core,self):OR6Chat6IsDrawerKey(kind)?OR6Chat6CreateDrawerScreen(_core,kind,self):OR6Chat7CreateArchive(_core,self);
 [_nav popToRootViewControllerAnimated:NO];[_reveal setDrawerOpen:NO animated:YES];if(c)[_nav pushViewController:c animated:YES];
}
- (id)conversationNavigator{return self;}
- (NSDictionary*)conversationInfo:(NSString*)identifier{
 if(![identifier isKindOfClass:NSString.class])return @{};NSMutableDictionary*d=[NSMutableDictionary dictionaryWithObject:identifier forKey:@"id"];
 for(NSDictionary*h in _history.items)if([h[@"id"]isEqual:identifier]){if([h[@"currentNode"]isKindOfClass:NSString.class])d[@"currentNode"]=h[@"currentNode"];d[@"archived"]=h[@"archived"]?:@NO;if(h[@"title"])d[@"title"]=h[@"title"];break;}
 if(_pins.result&&!_pins.error){d[@"pinned"]=@NO;for(NSDictionary*x in _pins.result[@"items"])if([x[@"id"]isEqual:identifier])d[@"pinned"]=@YES;}
 return d;
}
- (void)drawer:(RCDrawerController*)d didLongPressItem:(RCDrawerItem*)item{
 (void)d;NSDictionary*info=item.userInfo;if(![info isKindOfClass:NSDictionary.class]||![self sessionReady])return;NSDictionary*v=[self conversationInfo:info[@"id"]];NSArray*actions=OR6Chat7ConversationActions(_core,v);NSArray*six=OR6Chat6ConversationActions(_core,v);if(!actions.count&&!six.count)return;
 NSDictionary*titles=@{@"rename":OR6L(@"Rename"),@"pin":OR6L(@"Pin"),@"unpin":OR6L(@"Unpin"),@"share":OR6L(@"Share link…"),@"move":OR6L(@"Move to project…"),@"files":OR6L(@"Files in this chat"),@"archive":OR6L(@"Archive"),@"unarchive":OR6L(@"Return from archive")};
 NSMutableArray*buttons=[NSMutableArray array],*keys=[NSMutableArray array];for(NSString*a in actions)if(titles[a]){[buttons addObject:titles[a]];[keys addObject:a];}
 for(NSDictionary*x in six){[buttons addObject:x[@"title"]];[keys addObject:[@"six:"stringByAppendingString:x[@"key"]]];} // stage 6: lock, report, voice
 OR6Chat8ShowSheet(self.view.window?:self.view,item.title,buttons,[actions containsObject:@"delete"]?OR6L(@"Delete chat"):nil,^(NSInteger n,NSString*t){(void)t;NSString*a=n==-2?@"delete":(n>=0&&(NSUInteger)n<keys.count)?keys[(NSUInteger)n]:nil;if(!a)return;
  // Delivered after the action sheet is gone. Share is a modal: the drawer closes without animation and
  // the window's root (this controller) presents it, so no drawer or sheet transition overlaps it.
  if([a hasPrefix:@"six:"]){[_reveal setDrawerOpen:NO animated:YES];OR6Chat6RunConversationAction(_nav,_core,[a substringFromIndex:4],v,self);return;}
  if([a isEqual:@"share"]){[_reveal setDrawerOpen:NO animated:NO];OR6Chat7RunConversationAction(self,_core,a,v,self);}
  else if([a isEqual:@"files"]){[_reveal setDrawerOpen:NO animated:YES];OR6Chat7RunConversationAction(_nav.topViewController,_core,a,v,self);}else OR6Chat7RunConversationAction(self,_core,a,v,self);});
}
- (void)chat7OpenConversation:(NSString*)identifier title:(NSString*)title{
 if(![self sessionReady]||!_nav)return;[_conversation dismissViewControllerAnimated:NO completion:nil];
 if(![self openConversationIdentifier:identifier])[RCHUD showText:OR6L(@"Finish the current message first.")kind:RCHUDTextOnly inView:self.view.window seconds:1.6];
 else if(title.length&&!_conversation.conversationTitle.length)_conversation.conversationTitle=title;
}
- (void)chat7Conversation:(NSString*)identifier changed:(NSString*)change{
 _historyStale=YES;if([change isEqual:@"pinned"]){_pinsWanted=YES;[_pins reset];}
 if(([change isEqual:@"deleted"]||[change isEqual:@"archived"]||[change isEqual:@"locked"])&&[identifier isEqual:_conversation.conversationId]){[_nav popToRootViewControllerAnimated:NO];[self setFront:[self makeConversation:nil]];}
 if(_reveal.drawerOpen)[self loadFirst];[self renderDrawer]; // a new title arrives with the history refresh
}
// App routes never replace an unsent draft: home only reveals the open chat; a conversation
// route waits until the draft is sent or cleared (explicit New chat / history stay as before).
- (void)chat7ShowHome{if(!_nav)return;[_conversation dismissViewControllerAnimated:NO completion:nil];[_nav popToRootViewControllerAnimated:NO];[_reveal setDrawerOpen:NO animated:YES];}
- (BOOL)routeKeepsDraft:(NSString*)identifier{
 NSDictionary*d=_conversation.diagnostics;BOOL unsent=[d[@"draftLength"]unsignedIntegerValue]>0||[d[@"files8"][@"items"]unsignedIntegerValue]>0;
 return unsent&&![identifier isEqual:_conversation.conversationId];
}
- (void)chat7RouteToConversation:(NSString*)identifier{
 if([identifier isEqual:_conversation.conversationId]){[self chat7ShowHome];return;}
 if([self routeKeepsDraft:identifier]){[self chat7ShowHome];[RCHUD showText:OR6L(@"This chat has an unsent message. Send or clear it, then open the link again.")kind:RCHUDTextOnly inView:self.view.window seconds:2.2];return;}
 [self chat7OpenConversation:identifier title:nil];
}
- (BOOL)chat7AttachLibraryDraft:(NSDictionary*)draft item:(NSDictionary*)item{return[_conversation attachLibraryDraft:draft item:item];}
- (NSString*)chat7CurrentDraftId{return[_conversation chat7DraftId];}
- (void)chat7ComposeText:(NSString*)text{if(![self sessionReady]||!_nav)return;[_nav popToRootViewControllerAnimated:NO];[_reveal setDrawerOpen:NO animated:YES];[_conversation composeRouteText:text];}
- (void)chat7OpenProject:(NSString*)projectId{
 if(![self sessionReady]||!_nav||!OR6Chat7On(_core,@"projects.get"))return;[_reveal setDrawerOpen:NO animated:YES];
 if(![_nav.topViewController.title isEqual:OR6L(@"Projects")])[_nav popToRootViewControllerAnimated:NO];[_nav pushViewController:OR6Chat7CreateProject(_core,projectId,self)animated:YES];
}
- (void)chat6NewChatWithGPT:(NSDictionary*)gpt{
 if(![self sessionReady]||!_nav||![gpt isKindOfClass:NSDictionary.class])return;OR6ChatConversationController*c=[self makeConversation:nil];[c setGPT:gpt];
 [_nav popToRootViewControllerAnimated:NO];[self setFront:c];[_host chatPrepareConversation:nil];
 if([gpt[@"starter"]isKindOfClass:NSString.class])[c composeRouteText:gpt[@"starter"]]; // into the field, never sent
}
- (void)chat6OpenLibraryItem:(NSString*)libraryItemId{
 if(![self sessionReady]||!_nav)return;UIViewController*c=OR6Chat6CreateLibraryItem(_core,libraryItemId,self);if(!c)return;
 [_reveal setDrawerOpen:NO animated:YES];[_nav popToRootViewControllerAnimated:NO];[_nav pushViewController:c animated:YES];
}
- (void)chat7NewChatInProject:(NSDictionary*)project{
 if(![self sessionReady]||!_nav)return;OR6ChatConversationController*c=[self makeConversation:nil];[c setProject:project];[_nav popToRootViewControllerAnimated:NO];[self setFront:c];[_host chatPrepareConversation:nil];
}
// openURL (main.m) and answer links: routes.resolve, then in-app navigation; waits for the session.
- (BOOL)openRouteURL:(NSURL*)url{
 if(!OR6Chat7RouteURL(url))return NO;if(![self sessionReady]||!_nav){[_pendingRoute release];_pendingRoute=[url copy];return YES;}
 return OR6Chat7HandleRoute(_core,url,self,^{[self chat7ShowHome];});
}

#pragma mark Conversations

- (void)newConversation{if(![self sessionReady]&&_summary)return;OR6ChatConversationController*c=[self makeConversation:nil];[self setFront:c];[_host chatPrepareConversation:nil];}
- (void)conversationRequestsNewChat:(OR6ChatConversationController*)c{(void)c;if(_conversation.conversationId||_nav.topViewController!=_conversation||[_conversation.diagnostics[@"messageCount"]unsignedIntegerValue])[self newConversation];}
- (void)conversationDidChange:(OR6ChatConversationController*)c{
 if(c.temporary){[self renderDrawer];return;} // not saved in history: no refresh, no row
 NSString*identifier=c.conversationId;BOOL known=NO;for(NSDictionary*d in _history.items)if([d[@"id"]isEqual:identifier]){known=YES;break;}
 if(identifier&&!known)_historyStale=YES;
 if(identifier&&c.conversationTitle.length)[_history updateTitle:c.conversationTitle conversation:identifier];
 [self renderDrawer];
}
- (BOOL)openConversationIdentifier:(NSString*)identifier{
 if(![self sessionReady]||!_nav)return NO;NSDictionary*current=_conversation.diagnostics;if([current[@"sending"]boolValue]||[current[@"uncertain"]boolValue])return NO;
 [_nav popToRootViewControllerAnimated:NO];NSDictionary*snapshot=nil;OR6ChatConversationController*c=[self conversationForIdentifier:identifier snapshot:&snapshot];
 for(NSDictionary*d in _history.items)if([d[@"id"]isEqual:identifier]&&[d[@"title"]length])c.conversationTitle=d[@"title"];
 [self setFront:c];if(snapshot)[c resumeRecoverySnapshot:snapshot];[_host chatPrepareConversation:identifier];return YES;
}

#pragma mark Recovery of an interrupted send

- (NSDictionary*)hostRecoveryFor:(NSString*)identifier{
 if(![_host respondsToSelector:@selector(chatRecoveryForConversation:)])return nil;NSDictionary*s=[_host chatRecoveryForConversation:identifier];
 if(![s isKindOfClass:NSDictionary.class]||![s[@"operationId"]isKindOfClass:NSString.class])return nil;
 return identifier&&![identifier isEqual:s[@"conversationId"]]?nil:s;
}
// A conversation opened by navigation shows its saved question + partial answer
// before the normal history read (the screen hydrates after the check).
- (OR6ChatConversationController*)conversationForIdentifier:(NSString*)identifier snapshot:(NSDictionary**)snapshot{
 OR6ChatConversationController*c=[self makeConversation:identifier];
 NSDictionary*s=identifier?[self hostRecoveryFor:identifier]:nil;[c applySessionSummary:_summary];[c applySessionReady:[self sessionReady]];
 if(s&&[c restoreRecoverySnapshot:s]){if(snapshot)*snapshot=s;}return c;
}
- (BOOL)restoreRecoverySnapshot:(NSDictionary*)s{
 if(![s isKindOfClass:NSDictionary.class]||![s[@"operationId"]isKindOfClass:NSString.class]||[self wantsWelcome]||![self sessionReady])return NO;
 if(!_conversation){_conversation=[[self makeConversation:nil]retain];_conversation.host=self;_initialConversation=YES;}
 [_conversation applySessionSummary:_summary];[_conversation applySessionReady:YES];
 if([_conversation matchesRecoverySnapshot:s]){[_conversation resumeRecoverySnapshot:s];[self renderDrawer];return YES;} // keeps its rows and older history
 NSDictionary*d=_conversation.diagnostics;BOOL front=!_nav||_nav.topViewController==_conversation;
 BOOL idle=![d[@"sending"]boolValue]&&![d[@"uncertain"]boolValue]&&![d[@"draftLength"]unsignedIntegerValue]&&!_conversation.presentedViewController;
 // Only the launch screen is filled; a New chat the user opened stays a new chat.
 if(idle&&front&&_initialConversation&&!_conversation.conversationId&&![d[@"messageCount"]unsignedIntegerValue]){
  if(![_conversation restoreRecoverySnapshot:s])return NO;[_conversation resumeRecoverySnapshot:s];[self renderDrawer];return YES;}
 // The same conversation is open from history without this send: reopen it from the snapshot (full history is read after the check).
 NSString*cid=s[@"conversationId"];
 if(idle&&front&&_nav&&![s[@"completed"]boolValue]&&[s[@"autoResume"]boolValue]&&[cid isKindOfClass:NSString.class]&&[cid isEqual:_conversation.conversationId]){
  OR6ChatConversationController*c=[self makeConversation:cid];c.conversationTitle=_conversation.conversationTitle;[c applySessionSummary:_summary];
  if(![c restoreRecoverySnapshot:s])return NO;[self setFront:c];[c resumeRecoverySnapshot:s];return YES;}
 return NO;
}
- (void)prepareForBackground{[self cancelRequest];[_searchTimer invalidate];_searchTimer=nil;[_searcher cancel];[_global reset];[_globalQuery release];_globalQuery=nil;[_pins cancel];_pinsWanted=YES;for(UIViewController*c in _nav.viewControllers)if([c isKindOfClass:OR6ChatConversationController.class])[(id)c prepareForBackground];[self renderDrawer];}
- (void)invalidateAPI7Context{[_pins cancel];[_pins reset];_pinsWanted=YES;for(UIViewController*c in _nav.viewControllers)if([c isKindOfClass:OR6ChatConversationController.class])[(id)c invalidateAPI7];}
- (BOOL)setDictationLimitMS:(NSUInteger)ms{return[_conversation setDictationLimitMS:ms];}
- (NSDictionary*)diagnostics{
 UIViewController*top=_nav.topViewController;NSString*screen=[self wantsWelcome]?@"welcome":_reveal.drawerOpen?@"history":[top isKindOfClass:OR6Chat9MessageController.class]?@"message_text":[top isKindOfClass:OR6ChatConversationController.class]?@"conversation":[top isKindOfClass:OR6ChatSessionController.class]?@"session":NSStringFromClass(top.class)?:@"none";
 return @{@"screen":screen,@"historyCount":@(_history.items.count),@"historyLoaded":@(_history.loaded),@"historyBusy":@(_busy),@"authenticated":@([_summary[@"authenticated"]boolValue]),@"search8":@{@"loaded":@(_searcher.loaded),@"items":@(_searcher.items.count),@"busy":@(_searcher.busy),@"more":@(_searcher.nextToken!=nil)},@"conversation":_conversation?[_conversation diagnostics]:@{},@"sharePresentation":OR6Chat7SharePresentationDiagnostics(),@"presented":NSStringFromClass(self.presentedViewController.class)?:@""};
}
#ifdef OR6_CHAT_ACCEPTANCE
static NSDictionary*objc_fakeSaved;
- (NSDictionary*)acceptanceAction:(NSString*)action value:(id)value{
 // UI-only logout rehearsal: no auth.logout, the real session stays; ui_restore_session puts the real summary back.
 if([action isEqual:@"ui_fake_signout"]){static NSDictionary*saved;[saved release];saved=[_summary copy];objc_fakeSaved=saved;[self applySessionSummary:@{@"state":@"signed_out",@"authenticated":@NO}];return @{@"ok":@YES,@"screen":[self diagnostics][@"screen"]};}
 if([action isEqual:@"ui_restore_session"]){if(!objc_fakeSaved)return @{@"ok":@NO};[self applySessionSummary:objc_fakeSaved];return @{@"ok":@YES,@"screen":[self diagnostics][@"screen"]};}
 if([action isEqual:@"ui_reveal"]){[_reveal setDrawerOpen:[value boolValue]animated:NO];return @{@"ok":@YES};}
 if([action isEqual:@"ui_account"]){[self drawerDidTapAccount:_drawer];return @{@"ok":@YES};}
 if([action isEqual:@"ui_pop"]){[_nav popToRootViewControllerAnimated:NO];[_conversation dismissViewControllerAnimated:NO completion:nil];[self dismissViewControllerAnimated:NO completion:nil];return @{@"ok":@YES};}
 
 if([action isEqual:@"ui_dark"]){OR6ChatSetAppearance([value boolValue]);return @{@"ok":@YES};}
 if([action isEqual:@"ui_text_size"]&&[value isKindOfClass:NSNumber.class]){OR6ChatSetTextSize([value intValue]);return @{@"ok":@YES};}
 if([action isEqual:@"ui_push"]&&[value isKindOfClass:NSString.class]){
  UIViewController*c=nil;if([value isEqual:@"text_size"])c=OR6ChatCreateTextSizeController();
  if(!c)return @{@"ok":@NO};[_nav pushViewController:c animated:NO];return @{@"ok":@YES};}
 if([action isEqual:@"ui_conversation"])return[_conversation acceptanceAction:value];
 if([action isEqual:@"ui_perf_open"]&&[value isKindOfClass:NSNumber.class]){
  // Synthetic long conversation for the performance check: local only, never sent or read.
  NSUInteger count=MIN((NSUInteger)1000,[value unsignedIntegerValue]);NSString*cid=@"00000000-0000-4000-8000-00000000c0de";NSMutableArray*m=[NSMutableArray array];
  NSArray*answers=@[@"## Heading\n\nA paragraph with **bold**, *italic*, `code` and a [link](https://example.com/a).\n\n- first item\n- second item with enough words to wrap the line\n- third",
   @"A short one-line answer.",
   @"```swift\nfunc hello(name: String) -> String {\n    return \"Hello, \\(name)\"\n}\n```\n\nThe code above is an example.\n\n1. One\n2. Two\n3. Three\n10. Ten",
   @"| City | Time |\n|---|---|\n| Kazan | 2 h |\n| Moscow | 1 h |\n\n> A quote to check.\n\nOne more paragraph, long enough to take several lines on an iPhone 5 screen at the normal size."];
  for(NSUInteger i=0;i<count;i++){BOOL user=i%2==0;[m addObject:@{@"id":[NSString stringWithFormat:@"perf-%lu",(unsigned long)i],@"role":user?@"user":@"assistant",@"text":user?[NSString stringWithFormat:@"Question %lu: how does this work?",(unsigned long)i/2]:answers[(i/2)%answers.count]}];}
  OR6ChatConversationController*c=[self makeConversation:cid];c.conversationTitle=@"Long chat (synthetic)";
  if(![c acceptanceInject:@{@"id":cid,@"currentNode":@"perf-node",@"messages":m}])return @{@"ok":@NO,@"error":@"inject"};
  [self setFront:c];return @{@"ok":@YES,@"messages":@(count)};}
 return @{@"ok":@NO,@"error":@"unknown_ui_action"};
}
#endif
- (void)dealloc{
 if(OR6Chat6ChatCatalog()==_catalog)OR6Chat6SetChatCatalog(nil);[NSNotificationCenter.defaultCenter removeObserver:self];[self cancelRequest];[_searchTimer invalidate];_searchTimer=nil;_searcher.delegate=nil;_global.delegate=nil;[_global cancel];_drawer.delegate=nil;_welcome.chatDelegate=nil;_conversation.host=nil;
 [_core release];[_history release];[_summary release];[_profile release];[_global release];[_globalQuery release];[_reveal release];[_nav release];[_drawer release];[_conversation release];[_welcomeNav release];[_welcome release];[_account release];[_launch release];[_notice release];[_search release];[_historyLoaded release];[_catalog release];[_searcher release];[_signInNotice release];_pins.delegate=nil;[_pins cancel];[_pins release];[_pendingRoute release];[super dealloc];
}
@end
