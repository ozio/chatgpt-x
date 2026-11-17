// Acceptance-only composition of production UIKit/Core8 with synthetic account,
// generation, picker, recorder and HTTP boundaries. No live service or capture.
#import <UIKit/UIKit.h>
#define OR6_API8_NO_MAIN 1
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-function"
#import "../api/priority8/main.m"
#pragma clang diagnostic pop
#import "../../ios/chat/OR6ChatRootController.h"
#import "../../ios/chat/OR6ChatUIState.h"
#import "RCTheme.h"
#import "RCStage.h"
@interface UI8Generation:G8{@public NSDictionary*conversation;NSUInteger reads;}
@end
@implementation UI8Generation
- (id<OR6APITask>)execute:(NSString*)op parameters:(NSDictionary*)p context:(NSDictionary*)ctx event:(OR6APIEvent)event completion:(OR6APIReply)reply {
 if([op isEqual:@"history.list"]){reads++;reply(@{@"items":@[@{@"id":CID,@"title":@"Synthetic API8",@"updatedAt":@0}],@"nextToken":NSNull.null},nil);return[[[NineTask alloc]init]autorelease];}
 if([op isEqual:@"messages.reconcile"]){reply(@{@"operationId":p[@"operationId"],@"state":@"completed",@"conversationId":CID,@"userMessageId":plan[@"userMessageId"]?:UID,@"assistantMessageId":AID,@"persisted":@YES},nil);return[[[NineTask alloc]init]autorelease];}
 if([op isEqual:@"history.search"]){reads++;BOOL more=p[@"pageToken"]!=NSNull.null;NSString*cid=more?@"99999999-9999-4999-8999-999999999999":CID;reply(OR6APIWireSearch(J8(@{@"items":@[@{@"source_type":@"conversation",@"payload":@{@"kind":@"conversation",@"conversation_id":cid},@"title":more?@"Synthetic second page":@"Synthetic search"}],@"cursor":more?(id)NSNull.null:@"synthetic-next-page"}),more?p[@"pageToken"]:nil,NULL),nil);return[[[NineTask alloc]init]autorelease];}
 if([op isEqual:@"history.get"]){reads++;reply(conversation?:Conversation8(),nil);return[[[NineTask alloc]init]autorelease];}
 if([op isEqual:@"messages.send"]){NSDictionary*planned=OR6API8Plan(op,p,nil,@"auto",@[],NULL);return[self executeNativePlan:planned context:ctx event:event completion:^(NSDictionary*r,NSError*e){reply(r[@"receipt"],e);}];}
 return[super execute:op parameters:p context:ctx event:event completion:reply];
}
- (id<OR6APITask>)executeNativePlan:(NSDictionary*)p context:(NSDictionary*)ctx event:(OR6APIEvent)event completion:(OR6APIReply)reply {
 return[super executeNativePlan:p context:ctx event:event completion:^(NSDictionary*r,NSError*e){
  if(!e&&![p[@"temporary"]boolValue]&&[@[@"messages.send",@"messages.edit",@"messages.regenerate"]containsObject:p[@"operation"]]){
   NSDictionary*old=Conversation8();NSMutableDictionary*c=[[old mutableCopy]autorelease];NSMutableArray*messages=[[old[@"messages"]mutableCopy]autorelease];
   NSMutableDictionary*u=[[messages[0]mutableCopy]autorelease],*a=[[messages[1]mutableCopy]autorelease];NSString*uid=p[@"userMessageId"];
   u[@"id"]=uid;u[@"nodeId"]=uid;u[@"text"]=p[@"parameters"][@"text"]?:u[@"text"];a[@"text"]=@"answer";
   messages[0]=u;messages[1]=a;c[@"messages"]=messages;c[@"nodes"]=@[@{@"id":@"55555555-5555-4555-8555-555555555555",@"parent":NSNull.null,@"children":@[uid],@"messageId":NSNull.null},@{@"id":uid,@"parent":@"55555555-5555-4555-8555-555555555555",@"children":@[AID],@"messageId":uid},@{@"id":AID,@"parent":uid,@"children":@[],@"messageId":AID}];
   [conversation release];conversation=[c copy];
  }
  reply(r,e);
 }];
}
- (void)dealloc{[conversation release];[super dealloc];}
@end
// Exercise the actual app-supplied Inbox screen and native picker adapter;
// camera/photos still use synthetic files, and all file HTTP remains synthetic.
#import "../../ios/api/priority8/OR6API8Interactions.h"
@interface UI8Picker:P8{OR6API8Picker*_documents;}
- (id)initWithInbox:(NSString*)inbox;
- (void)setPresenter:(UIViewController*)presenter;
@end
@implementation UI8Picker
- (id)initWithInbox:(NSString*)inbox{if((self=[super init]))_documents=[[OR6API8Picker alloc]initWithPresenter:nil inbox:inbox];return self;}
- (void)setPresenter:(UIViewController*)presenter{[_documents setPresenter:presenter];}
- (id<OR6APITask>)acquire:(NSString*)source selection:(NSString*)selection completion:(void(^)(NSURL*,NSError*))reply{if([source isEqual:@"document"]){calls++;return[_documents acquire:source selection:selection completion:reply];}return[super acquire:source selection:selection completion:reply];}
- (void)dealloc{[_documents release];[super dealloc];}
@end
@interface UI8Host:NSObject<OR6ChatUIHost>{@public NSUInteger signins,logouts;}
@end
@implementation UI8Host
- (void)chatPrepareConversation:(NSString*)identifier{(void)identifier;}
- (void)chatSignIn{signins++;}
- (void)chatSignInWithProvider:(NSString*)provider{(void)provider;signins++;}
- (void)chatRenew{}
- (void)chatRestore{}
- (void)chatSignOut{logouts++;}
@end
static OR6ChatRootController*root8;static OR6API8Core*core8;static OR6API9Provider*nine8;static OR6API8Provider*eight8;static OR6API8Media*media8;static UI8Generation*generation8;static H8*http8;static P8*picker8;static UI8Host*host8;static NineHTTP*controls8;static NineRecorder*recorder8;static NSString*directory8,*recordingBefore8;static int sizeBefore8,appearanceBefore8,stageBefore8;static id sizePreference8,appearancePreference8;
UIViewController*OR6Chat8FixtureCreate(void){
 if(root8)return nil;NSString*library=NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES)[0];directory8=[[library stringByAppendingPathComponent:[@"ChatGPTXUI8Fixture-"stringByAppendingString:OR6ChatUUID()]]copy];
 NSString*documents=[directory8 stringByAppendingPathComponent:@"Documents"],*inbox=[documents stringByAppendingPathComponent:@"Inbox"],*journal=[directory8 stringByAppendingPathComponent:@"core"];
 NSFileManager*fm=NSFileManager.defaultManager;if(![fm createDirectoryAtPath:documents withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700}error:NULL])return nil;
 OR6Files*vault=[[[OR6Files alloc]initWithDirectory:[documents stringByAppendingPathComponent:@"MediaFiles-v1"]inbox:inbox error:NULL]autorelease];if(!vault)return nil;
 NSString*file=[inbox stringByAppendingPathComponent:@"synthetic.txt"];[[@"A synthetic attachment"dataUsingEncoding:NSUTF8StringEncoding]writeToFile:file atomically:YES];
 UIGraphicsBeginImageContextWithOptions(CGSizeMake(1,1),YES,1);[UIColor.whiteColor setFill];UIRectFill(CGRectMake(0,0,1,1));NSData*png=UIImagePNGRepresentation(UIGraphicsGetImageFromCurrentImageContext());UIGraphicsEndImageContext();NSString*image=[inbox stringByAppendingPathComponent:@"synthetic.png"];[png writeToFile:image atomically:YES];
 picker8=[[UI8Picker alloc]initWithInbox:inbox];picker8->url=[[NSURL fileURLWithPath:file]retain];picker8->imageURL=[[NSURL fileURLWithPath:image]retain];http8=[H8 new];http8->estuary=YES;generation8=[UI8Generation new];
 OR6APILocalProvider*local=[[[OR6APILocalProvider alloc]initWithNext:generation8]autorelease];media8=[[OR6API8Media alloc]initWithNext:local vault:vault inbox:inbox HTTP:http8 picker:picker8 journal:[directory8 stringByAppendingPathComponent:@"media"]capabilities:[NSSet setWithArray:@[@"upload",@"download"]]error:NULL];
 eight8=[[OR6API8Provider alloc]initWithNext:media8 generation:generation8 media:media8 capabilities:[NSSet setWithArray:@[@"temporary",@"edit",@"regenerate",@"model",@"attachments",@"search",@"translate"]]];
 controls8=[NineHTTP new];recorder8=[NineRecorder new];nine8=[[OR6API9Provider alloc]initWithNext:eight8 HTTP:controls8 recorder:recorder8 coreJournalDirectory:journal controlJournalDirectory:[directory8 stringByAppendingPathComponent:@"controls"]capabilities:[NSSet setWithArray:@[@"stop",@"transcribe"]]error:NULL];
 NSDictionary*registry=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"contracts"ofType:@"json"]]options:0 error:NULL];core8=[[OR6API8Core alloc]initWithRegistry:OR6API8Registry(registry)provider:nine8 journalDirectory:journal error:NULL];if(!core8)return nil;[core8 setContextKey:@"ui8-local-no-account"];
 recordingBefore8=[[NSUserDefaults.standardUserDefaults objectForKey:@"ChatGPTXUI9RecordingID"]copy];[NSUserDefaults.standardUserDefaults removeObjectForKey:@"ChatGPTXUI9RecordingID"];
 sizeBefore8=[RCTheme textSize];appearanceBefore8=[RCTheme appearance];stageBefore8=RCStageCurrent();sizePreference8=[[NSUserDefaults.standardUserDefaults objectForKey:@"RCTextSize"]copy];appearancePreference8=[[NSUserDefaults.standardUserDefaults objectForKey:@"RCAppearance"]copy];
 host8=[UI8Host new];root8=[[OR6ChatRootController alloc]initWithCore:core8 host:host8];[(UI8Picker*)picker8 setPresenter:root8];[root8 applySessionSummary:@{@"authenticated":@YES,@"state":@"authenticated",@"revision":@1,@"renewable":@YES}];return root8;
}
OR6ChatRootController*OR6Chat8FixtureRoot(void){return root8;}
NSDictionary*OR6Chat8FixtureState(void){return @{@"ok":@(root8!=nil),@"ui":root8.diagnostics?:@{},@"core":core8.diagnostics?:@{},@"plans":@(generation8?generation8->calls:0),@"pickerCalls":@(picker8?picker8->calls:0),@"fileHTTPCalls":@(http8?http8->requests.count:0),@"controlHTTPCalls":@(controls8?controls8->calls:0),@"syntheticRecordings":@(recorder8?recorder8->starts:0),@"lastPlanOperation":(generation8?generation8->plan[@"operation"]:nil)?:@"",@"lastPlanModel":(generation8?generation8->plan[@"body"][@"model"]:nil)?:@"",@"lastPlanTemporary":(generation8?generation8->plan[@"temporary"]:nil)?:@NO,@"accountRequests":@0,@"microphoneRecordings":@0,@"cameraCaptures":@0};}
NSDictionary*OR6Chat8FixtureMode(NSString*mode){
 if(!root8||[core8.diagnostics[@"activeCount"]unsignedIntegerValue]||![@[@"success",@"transcribe-no-dispatch",@"transcribe-uncertain",@"upload-uncertain",@"generation-rejected",@"generation-pending"]containsObject:mode])return @{@"ok":@NO};
 [controls8->mode release];controls8->mode=[([mode isEqual:@"transcribe-no-dispatch"]?@"no-dispatch":[mode isEqual:@"transcribe-uncertain"]?@"uncertain":@"success")copy];http8->fail=[mode isEqual:@"upload-uncertain"];generation8->rejectBefore=[mode isEqual:@"generation-rejected"];generation8->pending=[mode isEqual:@"generation-pending"];generation8->thinking=generation8->pending;return OR6Chat8FixtureState();
}
BOOL OR6Chat8FixtureClose(void){if(!root8)return NO;[root8 prepareForBackground];[core8 cancelAll];[nine8 deactivate];[eight8 deactivate];[media8 deactivate];[root8 release];root8=nil;[core8 release];core8=nil;[nine8 release];nine8=nil;[controls8 release];controls8=nil;[recorder8 release];recorder8=nil;[eight8 release];eight8=nil;[media8 release];media8=nil;[generation8 release];generation8=nil;[http8 release];http8=nil;[picker8 release];picker8=nil;[host8 release];host8=nil;if(recordingBefore8)[NSUserDefaults.standardUserDefaults setObject:recordingBefore8 forKey:@"ChatGPTXUI9RecordingID"];else[NSUserDefaults.standardUserDefaults removeObjectForKey:@"ChatGPTXUI9RecordingID"];[recordingBefore8 release];recordingBefore8=nil;[RCTheme setTextSize:sizeBefore8];[RCTheme setAppearance:appearanceBefore8];RCStageSet(stageBefore8);if(sizePreference8)[NSUserDefaults.standardUserDefaults setObject:sizePreference8 forKey:@"RCTextSize"];else[NSUserDefaults.standardUserDefaults removeObjectForKey:@"RCTextSize"];if(appearancePreference8)[NSUserDefaults.standardUserDefaults setObject:appearancePreference8 forKey:@"RCAppearance"];else[NSUserDefaults.standardUserDefaults removeObjectForKey:@"RCAppearance"];[sizePreference8 release];sizePreference8=nil;[appearancePreference8 release];appearancePreference8=nil;BOOL okay=[NSFileManager.defaultManager removeItemAtPath:directory8 error:NULL];[directory8 release];directory8=nil;return okay;}
