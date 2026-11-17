#import "OR6Rev67Content.h"
#import <TargetConditionals.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
@interface OR6Rev67ContentMail()<MFMailComposeViewControllerDelegate,OR6APITask>{UIViewController*_presenter;MFMailComposeViewController*_sheet;OR6APIReply _reply;}
@end
@implementation OR6Rev67ContentMail
- (id)initWithPresenter:(id)presenter{if((self=[super init]))_presenter=presenter;return self;}
- (id<OR6APITask>)compose:(NSDictionary*)p completion:(OR6APIReply)reply{
 if(!NSThread.isMainThread||_sheet||!_presenter.view.window||_presenter.presentedViewController||![MFMailComposeViewController canSendMail]){if(reply)reply(nil,OR6APIError(@"capability_unavailable",@"none"));return nil;}
 NSArray*to=p[@"to"];BOOL valid=[to isKindOfClass:NSArray.class]&&to.count>0&&to.count<=10;for(id address in valid?to:@[]){if(![address isKindOfClass:NSString.class]||[address length]>320||[address rangeOfString:@"@"].location==NSNotFound||[address rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound)valid=NO;}NSString*subject=p[@"subject"],*body=p[@"body"];if(!valid||![subject isKindOfClass:NSString.class]||subject.length>998||[subject rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound||![body isKindOfClass:NSString.class]||body.length>200000){if(reply)reply(nil,OR6APIError(@"invalid_request",@"none"));return nil;}
 _reply=[reply copy];_sheet=[MFMailComposeViewController new];_sheet.mailComposeDelegate=self;[_sheet setToRecipients:to];[_sheet setSubject:subject];[_sheet setMessageBody:body isHTML:NO];[_presenter presentViewController:_sheet animated:YES completion:nil];return self;
}
- (void)complete:(NSDictionary*)result error:(NSError*)error{OR6APIReply cb=[[_reply copy]autorelease];[_reply release];_reply=nil;_sheet.mailComposeDelegate=nil;[_sheet dismissViewControllerAnimated:YES completion:nil];[_sheet release];_sheet=nil;if(cb)cb(result,error);}
- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error{if(controller!=_sheet)return;if(error||result==MFMailComposeResultFailed){[self complete:nil error:OR6APIError(@"unavailable",@"possible")];return;}NSString*state=result==MFMailComposeResultSent?@"sent":result==MFMailComposeResultSaved?@"saved":@"cancelled";[self complete:@{@"state":state,@"handedToMail":@((BOOL)(result==MFMailComposeResultSent)),@"delivered":@NO}error:nil];}
- (void)cancel{if(_sheet)[self complete:nil error:OR6APIError(@"cancelled",@"possible")];}
- (void)dealloc{_sheet.mailComposeDelegate=nil;[_sheet release];[_reply release];[super dealloc];}
@end
#else
@implementation OR6Rev67ContentMail
- (id)initWithPresenter:(id)presenter{(void)presenter;return[super init];}
- (id<OR6APITask>)compose:(NSDictionary*)p completion:(OR6APIReply)reply{(void)p;if(reply)reply(nil,OR6APIError(@"capability_unavailable",@"none"));return nil;}
@end
#endif
