// «Аккаунт»: one grouped table that grows with the stage, as in the prototype.
// Every row is real in this build: session restore/renew/login (10), log out (9),
// text size (8), appearance (7) and the stage itself. Rows for features this
// build cannot perform are not shown.
#import "../localization/OR6Localization.h"
#import "OR6ChatSessionController.h"
#import "OR6ChatUIState.h"
#import "OR6ChatScreens.h"
#import "../ui/priority7/OR6Chat7Screens.h"
#import "../ui/priority6/OR6Chat6Screens.h"
#import "RCTheme.h"
#import "RCGlyph.h"
#import "RCLampView.h"
#import "RCButton.h"
#import "RCHUD.h"
#import "RCAccountHeaderView.h"
#import "RCFormViewController.h"
#import "../ui/selected20/OR6Chat20Screens.h"
#import <QuartzCore/QuartzCore.h> // headers only (layer messages)

typedef enum { OR6RowStatus, OR6RowRenewal, OR6RowRenew, OR6RowRestore, OR6RowSignIn, OR6RowTextSize, OR6RowAppearance, OR6RowDrawer, OR6RowSource } OR6AccountRow;

@interface OR6ChatSessionController()<UIActionSheetDelegate>{id<OR6ChatUIHost> _host;NSDictionary*_summary;NSString*_notice;NSArray*_sections;UIView*_footer;OR6APICore*_core;NSDictionary*_profile;}
@end

NSString *OR6ChatAccountDisplayName(NSDictionary *profile){NSString*n=profile[@"name"];return [n isKindOfClass:NSString.class]&&n.length?n:([profile[@"email"]isKindOfClass:NSString.class]&&[profile[@"email"]length]?profile[@"email"]:nil);}
NSString *OR6ChatAccountInitials(NSDictionary *profile){
 // First letters of the name's words (letters/digits only), else the e-mail's first letter.
 NSMutableString*s=[NSMutableString string];NSString*name=[profile[@"name"]isKindOfClass:NSString.class]?profile[@"name"]:nil;
 for(NSString*w in [name componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet]){if(!w.length||![NSCharacterSet.alphanumericCharacterSet characterIsMember:[w characterAtIndex:0]])continue;[s appendString:[[w substringWithRange:[w rangeOfComposedCharacterSequenceAtIndex:0]]uppercaseString]];if(s.length>=2)break;}
 NSString*email=[profile[@"email"]isKindOfClass:NSString.class]?profile[@"email"]:nil;
 if(!s.length&&email.length&&[NSCharacterSet.alphanumericCharacterSet characterIsMember:[email characterAtIndex:0]])[s appendString:[[email substringWithRange:[email rangeOfComposedCharacterSequenceAtIndex:0]]uppercaseString]];
 return s.length?s:@"C";
}

#pragma mark - Side menu visibility (local, per iPhone)

NSString *const OR6ChatDrawerVisibilityChanged=@"OR6ChatDrawerVisibilityChanged";
static NSString *const OR6DrawerDefaultsKey=@"OR6ChatDrawerVisibility";
// Order follows the drawer. Everyday destinations are shown by default; the rest
// start hidden and are turned on here.
NSArray *OR6ChatDrawerOptionalEntries(void){
 return @[@{@"key":@"library",@"title":OR6L(@"Library"),@"glyph":@"library",@"tile":@(RCTileGreen),@"shown":@YES},
          @{@"key":@"projects",@"title":OR6L(@"Projects"),@"glyph":@"folder",@"tile":@(RCTileBlue),@"shown":@YES},
          @{@"key":@"archive",@"title":OR6L(@"Archive (collection)"),@"glyph":@"archive",@"tile":@(RCTileGraphite),@"shown":@NO},
          @{@"key":@"gpts",@"title":OR6L(@"GPT"),@"glyph":@"gpt",@"tile":@(RCTileTeal),@"shown":@YES},
          @{@"key":@"tasks",@"title":OR6L(@"Tasks"),@"glyph":@"clock",@"tile":@(RCTileOrange),@"shown":@NO},
          @{@"key":@"locked",@"title":OR6L(@"Locked chats"),@"glyph":@"lock",@"tile":@(RCTileGraphite),@"shown":@NO},
          @{@"key":@"images20",@"title":OR6L(@"Images"),@"glyph":@"images",@"tile":@(RCTilePurple),@"shown":@YES},
          @{@"key":@"codex20",@"title":OR6L(@"Codex"),@"glyph":@"terminal",@"tile":@(RCTileDark),@"shown":@NO}];
}
BOOL OR6ChatDrawerShows(NSString *key){
 NSDictionary*stored=[NSUserDefaults.standardUserDefaults dictionaryForKey:OR6DrawerDefaultsKey];id v=stored[key?:@""];
 if([v isKindOfClass:NSNumber.class])return[v boolValue];
 for(NSDictionary*e in OR6ChatDrawerOptionalEntries())if([e[@"key"]isEqual:key])return[e[@"shown"]boolValue];
 return YES; // not an optional destination
}
void OR6ChatDrawerSetShows(NSString *key, BOOL shown){
 if(!key.length)return;NSMutableDictionary*d=[NSMutableDictionary dictionaryWithDictionary:[NSUserDefaults.standardUserDefaults dictionaryForKey:OR6DrawerDefaultsKey]?:@{}];
 d[key]=@(shown);[NSUserDefaults.standardUserDefaults setObject:d forKey:OR6DrawerDefaultsKey];[NSUserDefaults.standardUserDefaults synchronize];
 [NSNotificationCenter.defaultCenter postNotificationName:OR6ChatDrawerVisibilityChanged object:nil];
}
// Destinations this build and account can open (the same checks the drawer makes).
static NSArray *OR6DrawerAvailableEntries(OR6APICore *core,id<OR6ChatUIHost> host){
 NSMutableSet*keys=[NSMutableSet set];
 if(core){if(OR6Chat7LibraryAvailable(core))[keys addObject:@"library"];if(OR6Chat7ProjectsAvailable(core))[keys addObject:@"projects"];if(OR6Chat7ArchiveAvailable(core))[keys addObject:@"archive"];
  for(NSDictionary*e in [OR6Chat6DrawerEntries(core) arrayByAddingObjectsFromArray:OR6Chat20DrawerEntries(core)])[keys addObject:e[@"key"]];}
 if([host respondsToSelector:@selector(chatCodexAvailable)]&&[host chatCodexAvailable])[keys addObject:@"codex20"];
 NSMutableArray*out=[NSMutableArray array];for(NSDictionary*e in OR6ChatDrawerOptionalEntries())if([keys containsObject:e[@"key"]])[out addObject:e];return out;
}

@interface OR6ChatDrawerSettingsController:RCFormViewController<RCFormDelegate>{NSArray*_entries;}
@end
@implementation OR6ChatDrawerSettingsController
- (id)initWithEntries:(NSArray*)entries{if((self=[super initWithStyle:UITableViewStyleGrouped])){_entries=[entries copy];self.title=OR6L(@"Side menu");self.delegate=self;}return self;}
- (void)viewDidLoad{[super viewDidLoad];self.tableView.accessibilityIdentifier=@"chat.settings.drawer";[self render];}
- (void)render{
 NSMutableArray*rows=[NSMutableArray array];
 for(NSDictionary*e in _entries){RCFormRow*r=[RCFormRow rowWithKind:RCFormRowSwitch title:e[@"title"]];r.glyph=e[@"glyph"];r.tile=(RCTileColor)[e[@"tile"]intValue];r.on=OR6ChatDrawerShows(e[@"key"]);r.userInfo=e[@"key"];r.identifier=[@"chat.settings.drawer." stringByAppendingString:e[@"key"]];[rows addObject:r];}
 RCFormSection*s=[RCFormSection sectionWithTitle:OR6L(@"Show in the menu")rows:rows];s.footer=OR6L(@"New chat and your chats are always in the menu. A hidden section keeps its content; turn it on here to bring it back.");
 self.sections=@[s];
}
- (void)form:(RCFormViewController*)f didToggleRow:(RCFormRow*)row{(void)f;OR6ChatDrawerSetShows(row.userInfo,row.on);[self render];}
- (void)dealloc{[_entries release];[super dealloc];}
@end

@implementation OR6ChatSessionController
@synthesize core=_core;
- (id)initWithHost:(id<OR6ChatUIHost>)host summary:(NSDictionary*)summary{
 if((self=[super initWithStyle:UITableViewStyleGrouped])){_host=host;_summary=[summary copy];self.title=OR6L(@"Account");
  for(NSString*n in @[RCThemeAppearanceDidChangeNotification,RCThemeTextSizeDidChangeNotification])[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(changed:)name:n object:nil];}
 return self;
}
- (void)viewDidLoad{[super viewDidLoad];self.tableView.accessibilityIdentifier=@"chat.session.table";[RCTheme styleGroupedTableView:self.tableView];[self rebuild];}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self rebuild];}
- (void)changed:(NSNotification*)n{(void)n;if(self.isViewLoaded){[RCTheme styleGroupedTableView:self.tableView];[self rebuild];}}
- (void)applySessionSummary:(NSDictionary*)summary{[_summary release];_summary=[summary copy];[_notice release];_notice=nil;[self rebuild];}
- (void)applyAccountProfile:(NSDictionary*)profile{if(profile==_profile||[profile isEqual:_profile])return;[_profile release];_profile=[profile copy];[self rebuild];}
- (void)showSessionError:(NSError*)error{[_notice release];_notice=[OR6ChatErrorText(error)copy];[self rebuild];}
- (BOOL)busy{return[_summary[@"state"]isEqual:@"validating"];}
- (BOOL)auth{return[_summary[@"authenticated"]boolValue];}

- (void)rebuild{
 NSMutableArray*s=[NSMutableArray array];
 NSMutableArray*session=[NSMutableArray arrayWithObjects:@(OR6RowStatus),nil];if([self auth])[session addObject:@(OR6RowRenewal)];
 [session addObject:@([self auth]?OR6RowRenew:OR6RowSignIn)];[session addObject:@(OR6RowRestore)];
 [s addObject:@{@"title":OR6L(@"Session"),@"footer":_notice?:OR6L(@"Your login and saved session stay on this iPhone."),@"rows":session}];
 // Stage 7 (API 7/10): account screens whose reads or local work this build can run; they
 // replace the plain appearance row with the stored preference (light / dark).
 NSArray*api7=OR6Chat7AccountEntries(_core);/* local preferences work signed out; account screens need the session (below) */BOOL theme=NO;for(NSDictionary*e in api7)if([e[@"key"]isEqual:@"appearance"])theme=YES;
 NSMutableArray*chat=[NSMutableArray array];[chat addObject:@(OR6RowTextSize)];if(!theme)[chat addObject:@(OR6RowAppearance)];
 for(NSDictionary*e in api7)if([@[@"appearance",@"language",@"storage"]containsObject:e[@"key"]])[chat addObject:e];
 if(OR6DrawerAvailableEntries(_core,_host).count)[chat addObject:@(OR6RowDrawer)];
 if(chat.count)[s addObject:@{@"title":OR6L(@"Chat"),@"rows":chat}];
 NSMutableArray*account=[NSMutableArray array];for(NSDictionary*e in api7)if(![@[@"appearance",@"language",@"storage"]containsObject:e[@"key"]])[account addObject:e];
 if([self auth])[account addObjectsFromArray:OR6Chat6AccountEntries(_core)]; // stage 6: granted reads only
 if(account.count&&[self auth])[s addObject:@{@"title":OR6L(@"Account settings"),@"rows":account}];
 NSDictionary*info=NSBundle.mainBundle.infoDictionary;
 [s addObject:@{@"title":OR6L(@"About"),@"footer":[NSString stringWithFormat:OR6L(@"ChatGPT X %@ (build %@). Unofficial app, not affiliated with OpenAI."),info[@"CFBundleShortVersionString"]?:@"1.0",info[@"CFBundleVersion"]?:@"1"],@"rows":@[@(OR6RowSource)]}];
 [_sections release];_sections=[s copy];
 if(self.isViewLoaded){self.tableView.tableHeaderView=[self header];self.tableView.tableFooterView=[self footer];[self.tableView reloadData];}
}

- (UIView*)header{
 // Name and e-mail come from the session's /me check (kept with the session on this iPhone);
 // without them the header names the account and shows the real session state. No plan read.
 CGFloat w=self.tableView.bounds.size.width?:320;RCAccountHeaderView*h=[[[RCAccountHeaderView alloc]initWithFrame:CGRectZero]autorelease];
 NSString*name=OR6ChatAccountDisplayName(_profile),*email=_profile[@"name"]?_profile[@"email"]:nil;
 h.name=name?:OR6L(@"ChatGPT account");h.initials=OR6ChatAccountInitials(_profile);
 h.email=email?:([self busy]?OR6L(@"Checking session…"):[self auth]?OR6L(@"Session active on this iPhone"):OR6L(@"Login required"));h.planTitle=nil;
 h.frame=CGRectMake(0,0,w,[h heightForWidth:w]);h.accessibilityIdentifier=@"chat.account.header";return h;
}
- (UIView*)footer{
 if(![self auth])return[[[UIView alloc]initWithFrame:CGRectMake(0,0,10,10)]autorelease];
 CGFloat w=self.tableView.bounds.size.width?:320;UIView*v=[[[UIView alloc]initWithFrame:CGRectMake(0,0,w,84)]autorelease];
 RCButton*b=[RCButton buttonWithStyle:RCButtonStyleLargeRed title:OR6L(@"Log out of ChatGPT X")];b.frame=CGRectMake(10,10,w-20,44);b.enabled=![self busy];b.accessibilityIdentifier=@"chat.session.sign_out";[b addTarget:self action:@selector(confirmSignOut)forControlEvents:UIControlEventTouchUpInside];[v addSubview:b];
 UILabel*n=[[[UILabel alloc]initWithFrame:CGRectMake(20,58,w-40,20)]autorelease];n.backgroundColor=UIColor.clearColor;n.font=[UIFont systemFontOfSize:13];n.textAlignment=NSTextAlignmentCenter;n.textColor=[RCTheme noteTextColor];n.shadowColor=[RCTheme engravedShadowColor];n.shadowOffset=[RCTheme engravedShadowOffset];n.text=OR6L(@"Other devices stay logged in.");[v addSubview:n];
 return v;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView*)t{(void)t;return (NSInteger)_sections.count;}
- (NSInteger)tableView:(UITableView*)t numberOfRowsInSection:(NSInteger)s{(void)t;return (NSInteger)[_sections[(NSUInteger)s][@"rows"]count];}
- (UIView*)tableView:(UITableView*)t viewForHeaderInSection:(NSInteger)s{return[RCTheme groupedHeaderViewWithTitle:_sections[(NSUInteger)s][@"title"]width:t.bounds.size.width];}
- (CGFloat)tableView:(UITableView*)t heightForHeaderInSection:(NSInteger)s{(void)t;(void)s;return 44;}
- (UIView*)tableView:(UITableView*)t viewForFooterInSection:(NSInteger)s{
 NSString*text=_sections[(NSUInteger)s][@"footer"];if(!text)return nil;UILabel*l=[[[UILabel alloc]initWithFrame:CGRectZero]autorelease];l.backgroundColor=UIColor.clearColor;l.font=[UIFont systemFontOfSize:14];l.textColor=[RCTheme noteTextColor];l.shadowColor=[RCTheme engravedShadowColor];l.shadowOffset=[RCTheme engravedShadowOffset];l.numberOfLines=0;l.textAlignment=NSTextAlignmentCenter;RCLabelSetText(l,text);
 CGFloat w=t.bounds.size.width;CGFloat h=RCMeasureText(text,l.font,w-40).height;UIView*v=[[[UIView alloc]initWithFrame:CGRectMake(0,0,w,h+16)]autorelease];l.frame=CGRectMake(20,6,w-40,h);[v addSubview:l];return v;
}
- (CGFloat)tableView:(UITableView*)t heightForFooterInSection:(NSInteger)s{NSString*text=_sections[(NSUInteger)s][@"footer"];return text?RCMeasureText(text,[UIFont systemFontOfSize:14],t.bounds.size.width-40).height+16:1;}
- (id)itemAt:(NSIndexPath*)p{return _sections[(NSUInteger)p.section][@"rows"][(NSUInteger)p.row];}
- (OR6AccountRow)rowAt:(NSIndexPath*)p{id v=[self itemAt:p];return[v isKindOfClass:NSNumber.class]?(OR6AccountRow)[v intValue]:(OR6AccountRow)-1;}

- (UITableViewCell*)tableView:(UITableView*)t cellForRowAtIndexPath:(NSIndexPath*)p{
 UITableViewCell*cell=[t dequeueReusableCellWithIdentifier:@"account"];if(!cell)cell=[[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"account"]autorelease];
 NSInteger count=[self tableView:t numberOfRowsInSection:p.section];[RCTheme styleGroupedCell:cell position:[RCTheme positionForRow:p.row count:count]];
 cell.accessoryType=UITableViewCellAccessoryNone;cell.accessoryView=nil;cell.imageView.image=nil;cell.detailTextLabel.text=nil;cell.textLabel.textAlignment=NSTextAlignmentLeft;cell.textLabel.textColor=[RCTheme inkColor];cell.selectionStyle=UITableViewCellSelectionStyleBlue;cell.userInteractionEnabled=YES;cell.accessibilityTraits=UIAccessibilityTraitStaticText;cell.accessibilityHint=nil;
 BOOL busy=[self busy];
 NSDictionary*entry=[self itemAt:p];
 if([entry isKindOfClass:NSDictionary.class]){cell.textLabel.text=entry[@"title"];cell.imageView.image=[RCGlyph tileNamed:entry[@"glyph"]color:(RCTileColor)[entry[@"tile"]intValue]size:29];cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
  cell.accessibilityIdentifier=[@"chat.settings." stringByAppendingString:entry[@"key"]];cell.accessibilityLabel=entry[@"title"];cell.accessibilityTraits=UIAccessibilityTraitButton;cell.accessibilityValue=nil;return cell;}
 switch([self rowAt:p]){
  case OR6RowStatus:{cell.textLabel.text=OR6L(@"Status");RCLampView*lamp=[[[RCLampView alloc]initWithDiameter:9]autorelease];lamp.state=busy?RCLampBusy:[self auth]?RCLampOK:RCLampWarn;
   UILabel*v=[[[UILabel alloc]initWithFrame:CGRectZero]autorelease];v.backgroundColor=UIColor.clearColor;v.font=[UIFont systemFontOfSize:16];v.textColor=RCHex(0x385487);v.text=busy?OR6L(@"Checking session…"):[self auth]?OR6L(@"Active"):OR6L(@"Login required");[v sizeToFit];
   UIView*box=[[[UIView alloc]initWithFrame:CGRectMake(0,0,v.bounds.size.width+16,22)]autorelease];lamp.center=CGPointMake(4.5,11);v.frame=CGRectMake(16,0,v.bounds.size.width,22);[box addSubview:lamp];[box addSubview:v];cell.accessoryView=box;cell.selectionStyle=UITableViewCellSelectionStyleNone;
   cell.accessibilityIdentifier=@"chat.session.status";cell.accessibilityLabel=[NSString stringWithFormat:@"%@: %@",cell.textLabel.text,v.text];break;}
  case OR6RowRenewal:cell.textLabel.text=OR6L(@"Renewal");cell.detailTextLabel.text=[_summary[@"renewable"]boolValue]?OR6L(@"Available"):OR6L(@"Login later");cell.selectionStyle=UITableViewCellSelectionStyleNone;cell.accessibilityIdentifier=@"chat.session.renewal";break;
  case OR6RowRenew:cell.textLabel.text=OR6L(@"Check and renew");cell.textLabel.textAlignment=NSTextAlignmentCenter;cell.textLabel.textColor=busy?[RCTheme secondaryInkColor]:RCHex(0x385487);cell.accessibilityIdentifier=@"chat.session.renew";cell.accessibilityTraits=UIAccessibilityTraitButton;break;
  case OR6RowSignIn:cell.textLabel.text=OR6L(@"Log in");cell.textLabel.textAlignment=NSTextAlignmentCenter;cell.textLabel.textColor=busy?[RCTheme secondaryInkColor]:RCHex(0x385487);cell.accessibilityIdentifier=@"chat.session.sign_in";cell.accessibilityTraits=UIAccessibilityTraitButton;break;
  case OR6RowRestore:cell.textLabel.text=OR6L(@"Restore session");cell.textLabel.textAlignment=NSTextAlignmentCenter;cell.textLabel.textColor=busy?[RCTheme secondaryInkColor]:RCHex(0x385487);cell.accessibilityIdentifier=@"chat.session.restore";cell.accessibilityTraits=UIAccessibilityTraitButton;break;
  case OR6RowTextSize:cell.textLabel.text=OR6L(@"Text size");cell.imageView.image=[RCGlyph tileNamed:@"text" color:RCTileGray size:29];cell.detailTextLabel.text=OR6TextSizeName([RCTheme textSize]);cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;cell.accessibilityIdentifier=@"chat.settings.text_size";break;
  case OR6RowSource:cell.textLabel.text=OR6L(@"Source code on GitHub");cell.imageView.image=[RCGlyph tileNamed:@"link" color:RCTileDark size:29];cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;cell.accessibilityIdentifier=@"chat.session.source";cell.accessibilityTraits=UIAccessibilityTraitLink;break;
  case OR6RowDrawer:{NSArray*a=OR6DrawerAvailableEntries(_core,_host);NSUInteger n=0;for(NSDictionary*e in a)if(OR6ChatDrawerShows(e[@"key"]))n++;cell.textLabel.text=OR6L(@"Side menu");cell.imageView.image=[RCGlyph tileNamed:@"menu" color:RCTileGray size:29];cell.detailTextLabel.text=[NSString stringWithFormat:OR6L(@"%lu of %lu"),(unsigned long)n,(unsigned long)a.count];cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;cell.accessibilityIdentifier=@"chat.session.drawer";cell.accessibilityTraits=UIAccessibilityTraitButton;break;}
  case OR6RowAppearance:cell.textLabel.text=OR6L(@"Appearance");cell.imageView.image=[RCGlyph tileNamed:@"sun" color:RCTileOrange size:29];cell.detailTextLabel.text=[RCTheme isDark]?OR6L(@"Dark"):OR6L(@"Light");cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;cell.accessibilityIdentifier=@"chat.settings.appearance";break;
 }
 if(busy&&([self rowAt:p]==OR6RowRenew||[self rowAt:p]==OR6RowSignIn||[self rowAt:p]==OR6RowRestore)){cell.userInteractionEnabled=NO;cell.accessibilityTraits|=UIAccessibilityTraitNotEnabled;}
 if(!cell.accessibilityLabel||[self rowAt:p]!=OR6RowStatus){cell.accessibilityLabel=cell.textLabel.text;cell.accessibilityValue=cell.detailTextLabel.text;}
 return cell;
}
- (void)tableView:(UITableView*)t didSelectRowAtIndexPath:(NSIndexPath*)p{
 [t deselectRowAtIndexPath:p animated:YES];
 NSDictionary*entry=[self itemAt:p];
 if([entry isKindOfClass:NSDictionary.class]){UIViewController*c=OR6Chat6CreateAccountScreen(_core,entry[@"key"])?:OR6Chat7CreateAccountScreen(_core,entry[@"key"]);if(c)[self.navigationController pushViewController:c animated:YES];return;}
 switch([self rowAt:p]){
  case OR6RowRenew:[_host chatRenew];break;
  case OR6RowRestore:[_host chatRestore];break;
  case OR6RowSignIn:OR6ChatSignIn(_host,_core,self.view.window?:self.view);break;
  case OR6RowTextSize:[self.navigationController pushViewController:(_core?OR6ChatCreateTextSizeControllerWithCore(_core):OR6ChatCreateTextSizeController()) animated:YES];break;
  case OR6RowSource:[UIApplication.sharedApplication openURL:[NSURL URLWithString:@"https://github.com/ozio/chatgpt-x"]];break;
  case OR6RowDrawer:[self.navigationController pushViewController:[[[OR6ChatDrawerSettingsController alloc]initWithEntries:OR6DrawerAvailableEntries(_core,_host)]autorelease]animated:YES];break;
  case OR6RowAppearance:[self.navigationController pushViewController:[[[OR6ChatChoiceController alloc]initWithTitle:OR6L(@"Appearance")options:@[OR6L(@"Light"),OR6L(@"Dark")]selected:[RCTheme isDark]?1:0 footer:nil choose:^(NSUInteger i){OR6ChatSetAppearance(i==1);}]autorelease]animated:YES];break;
  default:break;
 }
}
- (void)confirmSignOut{UIActionSheet*s=[[[UIActionSheet alloc]initWithTitle:OR6L(@"Log out of ChatGPT X on this iPhone? The session and recordings are removed from the device. Chats stay in your account.")delegate:self cancelButtonTitle:OR6L(@"Cancel")destructiveButtonTitle:OR6L(@"Log out")otherButtonTitles:nil]autorelease];[s showInView:self.view.window?:self.view];}
- (void)actionSheet:(UIActionSheet*)s clickedButtonAtIndex:(NSInteger)i{if(i==s.destructiveButtonIndex){[self.navigationController popToRootViewControllerAnimated:NO];[_host chatSignOut];}}
- (void)dealloc{[NSNotificationCenter.defaultCenter removeObserver:self];[_summary release];[_notice release];[_sections release];[_footer release];[_core release];[_profile release];[super dealloc];}
@end
