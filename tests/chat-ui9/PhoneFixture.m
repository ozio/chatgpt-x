// Development-only, inert I/O for physical Retry/Stop/selection checks.
// Actual production UIKit, Local/Core/Priority9 paths; zero account transport.
#import <UIKit/UIKit.h>
#import "../../ios/chat/OR6ChatConversationController.h"
#import "../../ios/api/OR6APILocalProvider.h"
#import "../../ios/api/priority9/OR6API9Provider.h"
#import "../../ios/api/priority9/OR6API9Core.h"
#import "../../ios/chat/OR6ChatUIState.h"
static NSString*const FC= @"11111111-1111-4111-8111-111111111111",*const FU=@"22222222-2222-4222-8222-222222222222",*const FA=@"33333333-3333-4333-8333-333333333333";
@interface OR6UI9FixtureTask:NSObject<OR6APITask>{@public void(^cancelBlock)(void);}
@end
@implementation OR6UI9FixtureTask
- (void)cancel{void(^b)(void)=[[cancelBlock copy]autorelease];[cancelBlock release];cancelBlock=nil;if(b)b();}
- (void)dealloc{[cancelBlock release];[super dealloc];}
@end
@interface OR6UI9FixtureSend:NSObject<OR6APIProvider>{@public NSString*mode,*operation;NSUInteger sends;NSDictionary*last;OR6APIReply pending;OR6UI9FixtureTask*task;}
@end
@implementation OR6UI9FixtureSend
- (id)init{if((self=[super init]))mode=[@"rejected"copy];return self;}
- (NSDictionary*)receipt:(NSString*)op{return @{@"operationId":op,@"state":@"completed",@"conversationId":FC,@"userMessageId":FU,@"assistantMessageId":FA,@"persisted":@YES};}
- (id<OR6APITask>)execute:(NSString*)op parameters:(NSDictionary*)p context:(NSDictionary*)ctx event:(OR6APIEvent)event completion:(OR6APIReply)reply{
 (void)ctx;OR6UI9FixtureTask*t=[[[OR6UI9FixtureTask alloc]init]autorelease];
 if([op isEqual:@"messages.reconcile"]){reply([self receipt:p[@"operationId"]],nil);return t;}
 if(![op isEqual:@"messages.send"]){reply(nil,OR6APIError(@"capability_unavailable",@"none"));return t;}sends++;[last release];last=[p copy];[operation release];operation=[p[@"operationId"]copy];
 if([mode isEqual:@"rejected"]){reply(nil,OR6APIError(@"network_unavailable",@"none"));return t;}
 if([mode isEqual:@"thinking"]||[mode isEqual:@"render"]){
  if(event){event(@{@"name":@"state",@"payload":@{@"operationId":operation,@"state":@"streaming",@"conversationId":FC,@"userMessageId":FU,@"assistantMessageId":FA,@"persisted":@NO}});
   event(@{@"name":@"status",@"payload":@{@"operationId":operation,@"phase":@"thinking",@"label":@"Checking the supplied sources",@"sequence":@1}});
   event(@{@"name":@"status",@"payload":@{@"operationId":operation,@"phase":@"thinking",@"label":@"Comparing the relevant details and checking that the explanation remains consistent with the original question.",@"sequence":@2}});
   event(@{@"name":@"status",@"payload":@{@"operationId":operation,@"phase":@"thinking",@"label":@"Preparing a concise answer",@"sequence":@3}});
   event(@{@"name":@"message",@"payload":@{@"operationId":operation,@"sequence":@4,@"conversationId":FC,@"messageId":FA,@"text":[mode isEqual:@"thinking"]?@"":@"Inline: `plain`.\n\n**Bold with `nested`**, *italic with `value`*.\n\n[`linked`](https://openai.com/brand/).\n\n---\n\nA sourced answer. \uE200cite\uE202turn995773view2\uE201",@"finished":@([mode isEqual:@"render"]),@"conversationTitle":@"Rendered source fixture",@"parts":@[@{@"kind":@"citation",@"data":@{@"id":@"turn995773view2",@"title":@"Example source",@"url":@"https://openai.com/brand/"}}]}});
  }
  if([mode isEqual:@"thinking"]){[pending release];pending=[reply copy];[task release];task=[t retain];t->cancelBlock=[^{OR6APIReply cb=[[pending copy]autorelease];[pending release];pending=nil;if(cb)cb(nil,OR6APIError(@"cancelled",@"possible"));}copy];}
  else reply([self receipt:operation],nil);return t;
 }
 if(event){event(@{@"name":@"state",@"payload":@{@"operationId":operation,@"state":@"streaming",@"conversationId":FC,@"userMessageId":FU,@"assistantMessageId":FA,@"persisted":@NO}});event(@{@"name":@"message",@"payload":@{@"operationId":operation,@"sequence":@1,@"conversationId":FC,@"messageId":FA,@"text":@"# Локальный ответ\n\n**Жирный** и *курсив* 🙂\n\n```c\nint answer = 42;\n```\n[Ссылка](https://example.com)",@"finished":@([mode isEqual:@"success"])}});}
 if([mode isEqual:@"pending"]){[pending release];pending=[reply copy];[task release];task=[t retain];t->cancelBlock=[^{OR6APIReply cb=[[pending copy]autorelease];[pending release];pending=nil;if(cb)cb(nil,OR6APIError(@"cancelled",@"possible"));}copy];}
 else reply([self receipt:operation],nil);return t;
}
- (void)dealloc{[mode release];[operation release];[last release];[pending release];[task release];[super dealloc];}
@end
@interface OR6UI9FixtureHTTP:NSObject<OR6API9HTTP>{@public NSUInteger calls;}
@end
@implementation OR6UI9FixtureHTTP
- (id<OR6APITask>)performRequest:(NSURLRequest*)r context:(NSDictionary*)ctx completion:(void(^)(NSDictionary*,NSError*))reply{(void)ctx;calls++;if([r.URL.path isEqual:@"/backend-api/stop_conversation"])reply(@{@"status":@204,@"json":NSNull.null},nil);else if([r.URL.path isEqual:@"/backend-api/transcribe"])reply(@{@"status":@200,@"json":@{@"text":@"Локальная диктовка 🙂"}},nil);else reply(nil,OR6APIError(@"capability_unavailable",@"none"));return[[[OR6UI9FixtureTask alloc]init]autorelease];}
@end
@interface OR6UI9FixtureRecorder:NSObject<OR6API9Recorder>{@public NSString*identifier;BOOL recording;}
@end
@implementation OR6UI9FixtureRecorder
- (BOOL)start:(NSString*)rid maxDurationMS:(NSUInteger)maximum error:(NSError**)error{(void)maximum;(void)error;[identifier release];identifier=[rid copy];recording=YES;return YES;}
- (void)stop{recording=NO;}
- (void)suspend{recording=NO;}
- (void)cancel{recording=NO;[identifier release];identifier=nil;}
- (NSDictionary*)snapshot{return @{@"recordingId":identifier?:(id)NSNull.null,@"state":!identifier?@"idle":recording?@"recording":@"stopped",@"assetId":identifier&&!recording?identifier:(id)NSNull.null,@"durationMS":@10,@"bytes":@364};}
- (NSData*)recordingData:(NSString*)rid error:(NSError**)error{(void)rid;(void)error;unsigned char h[44]={'R','I','F','F',0x64,1,0,0,'W','A','V','E','f','m','t',' ',16,0,0,0,1,0,1,0,0x80,0x3e,0,0,0,0x7d,0,0,2,0,16,0,'d','a','t','a',0x40,1,0,0};NSMutableData*d=[NSMutableData dataWithBytes:h length:44];[d increaseLengthBy:320];return d;}
- (void)dealloc{[identifier release];[super dealloc];}
@end
static OR6ChatConversationController*FixtureController;
static OR6UI9FixtureRecorder*FixtureRecorder;
static OR6API9Core*FixtureCore;static OR6API9Provider*FixtureOuter;static OR6UI9FixtureSend*FixtureSend;static OR6UI9FixtureHTTP*FixtureHTTP;static NSString*FixtureDirectory;
UIViewController*OR6Chat9FixtureCreate(void){
 if(FixtureCore)return nil;NSString*library=NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES)[0];FixtureDirectory=[[library stringByAppendingPathComponent:[@"ChatGPTXUI9Fixture-"stringByAppendingString:OR6ChatUUID()]]copy];NSString*coreDirectory=[FixtureDirectory stringByAppendingPathComponent:@"core"];FixtureSend=[OR6UI9FixtureSend new];FixtureHTTP=[OR6UI9FixtureHTTP new];FixtureRecorder=[OR6UI9FixtureRecorder new];OR6APILocalProvider*local=[[[OR6APILocalProvider alloc]initWithNext:FixtureSend]autorelease];
 FixtureOuter=[[OR6API9Provider alloc]initWithNext:local HTTP:FixtureHTTP recorder:FixtureRecorder coreJournalDirectory:coreDirectory controlJournalDirectory:[FixtureDirectory stringByAppendingPathComponent:@"controls"]capabilities:[NSSet setWithArray:@[@"stop",@"transcribe"]]error:NULL];NSData*d=[NSData dataWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"contracts"ofType:@"json"]];NSDictionary*registry=d?[NSJSONSerialization JSONObjectWithData:d options:0 error:NULL]:nil;FixtureCore=[[OR6API9Core alloc]initWithRegistry:registry provider:FixtureOuter journalDirectory:coreDirectory error:NULL];if(!FixtureCore)return nil;[FixtureCore setContextKey:@"ui9-local-fixture-no-account"];FixtureController=[[OR6ChatConversationController alloc]initWithCore:FixtureCore conversationId:nil];return[[FixtureController retain]autorelease];
}
static void FixtureInlineAudit(UIView*v,NSUInteger*code,NSUInteger*linked,NSUInteger*ticks){
 if([v isKindOfClass:UILabel.class]){NSAttributedString*a=[(UILabel*)v attributedText];if([a.string rangeOfString:@"`"].location!=NSNotFound&&a.length)(*ticks)++;
  [a enumerateAttributesInRange:NSMakeRange(0,a.length)options:0 usingBlock:^(NSDictionary*d,NSRange r,BOOL*stop){(void)r;(void)stop;if(d[NSBackgroundColorAttributeName]){(*code)++;if(d[@"RCMDLink"])(*linked)++;}}];}
 for(UIView*child in v.subviews)FixtureInlineAudit(child,code,linked,ticks);
}
NSDictionary*OR6Chat9FixtureState(NSString*mode){
 if([mode isEqual:@"render"]||[mode isEqual:@"thinking"]){[FixtureController acceptanceAction:@{@"kind":@"compose",@"text":@"Local rendering check"}];}
 if(mode){if(![@[@"rejected",@"success",@"pending",@"thinking",@"render"]containsObject:mode]||[FixtureCore.diagnostics[@"activeCount"]unsignedIntegerValue])return @{@"ok":@NO,@"error":@"fixture_busy_or_bad_mode"};[FixtureSend->mode release];FixtureSend->mode=[mode copy];}
 NSUInteger codes=0,linked=0,ticks=0;if(FixtureController.isViewLoaded)FixtureInlineAudit(FixtureController.view,&codes,&linked,&ticks);
 return @{@"inlineCodeRuns":@(codes),@"linkedCodeRuns":@(linked),@"rawInlineBackticks":@(ticks),@"ok":@(FixtureCore!=nil),@"mode":FixtureSend?FixtureSend->mode:@"",@"sendCalls":@(FixtureSend?FixtureSend->sends:0),@"stopCalls":@(FixtureHTTP?FixtureHTTP->calls:0),@"active":FixtureCore.diagnostics[@"activeCount"]?:@0,@"accountRequests":@0,@"microphoneRecordings":@0};
}
BOOL OR6Chat9FixtureClose(void){if(!FixtureCore)return NO;[FixtureController release];FixtureController=nil;[FixtureCore cancelAll];[FixtureOuter deactivate];if([FixtureRecorder->identifier isEqual:[NSUserDefaults.standardUserDefaults objectForKey:@"ChatGPTXUI9RecordingID"]])[NSUserDefaults.standardUserDefaults removeObjectForKey:@"ChatGPTXUI9RecordingID"];[FixtureRecorder cancel];[FixtureRecorder release];FixtureRecorder=nil;[FixtureCore release];FixtureCore=nil;[FixtureOuter release];FixtureOuter=nil;[FixtureSend release];FixtureSend=nil;[FixtureHTTP release];FixtureHTTP=nil;BOOL clean=[NSFileManager.defaultManager removeItemAtPath:FixtureDirectory error:NULL];[FixtureDirectory release];FixtureDirectory=nil;return clean;}
