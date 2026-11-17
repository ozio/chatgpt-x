#import "../../localization/OR6Localization.h"
#import "OR6Chat9MessageController.h"
#import "OR6Chat9Content.h"
#import "../../OR6Content.h"

void OR6Chat9ApplyControlAccessibility(UIView *view,NSString *label,NSString *hint,BOOL enabled){
 view.isAccessibilityElement=YES;view.accessibilityLabel=label;view.accessibilityHint=hint;view.accessibilityTraits=UIAccessibilityTraitButton|(enabled?0:UIAccessibilityTraitNotEnabled);
}
NSAttributedString *OR6Chat9AttributedBlock(NSDictionary *block,CGFloat size){
 NSString*text=block[@"text"]?:@"";BOOL code=[block[@"kind"]isEqual:@"code"];BOOL heading=[block[@"level"]unsignedIntegerValue]>0;UIFont*font=code?([UIFont fontWithName:@"Courier"size:size]?:[UIFont systemFontOfSize:size]):heading?[UIFont boldSystemFontOfSize:size+2]:[UIFont systemFontOfSize:size];
 NSMutableAttributedString*a=[[[NSMutableAttributedString alloc]initWithString:text attributes:@{NSFontAttributeName:font,NSForegroundColorAttributeName:UIColor.blackColor}]autorelease];
 for(NSDictionary*r in block[@"runs"]){NSUInteger start=[r[@"location"]unsignedIntegerValue],length=[r[@"length"]unsignedIntegerValue];if(start>text.length||length>text.length-start)continue;NSString*style=r[@"style"];NSRange range=NSMakeRange(start,length);
  if([style isEqual:@"bold"])[a addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:size]range:range];
  else if([style isEqual:@"italic"])[a addAttribute:NSFontAttributeName value:[UIFont italicSystemFontOfSize:size]range:range];
  else if([style isEqual:@"code"])[a addAttribute:NSFontAttributeName value:([UIFont fontWithName:@"Courier"size:size]?:font)range:range];
  else if([style isEqual:@"strike"])[a addAttribute:NSStrikethroughStyleAttributeName value:@1 range:range];
  else if([style isEqual:@"link"]){[a addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithRed:0 green:.3 blue:.7 alpha:1]range:range];[a addAttribute:NSUnderlineStyleAttributeName value:@1 range:range];}
 }return[[a copy]autorelease];
}
@interface OR6Chat9SelectionView:UITextView
@property(nonatomic,retain)OR6APICore *selectionCore;
@property(nonatomic,copy)NSString *messageId;
@end
@implementation OR6Chat9SelectionView
@synthesize selectionCore=_selectionCore,messageId=_messageId;
- (void)copy:(id)sender{
 (void)sender;NSString*text=[[self.text copy]autorelease];NSRange range=self.selectedRange;if(!range.length||range.location>text.length||range.length>text.length-range.location)return;
 [_selectionCore perform:@"content.select"parameters:@{@"messageId":_messageId,@"text":text,@"start":@(range.location),@"length":@(range.length)}event:nil completion:^(NSDictionary*r,NSError*e){if(!e)[UIPasteboard generalPasteboard].string=r[@"selectedText"];}];
}
- (void)dealloc{[_selectionCore release];[_messageId release];[super dealloc];}
@end
@interface OR6Chat9MessageController(){OR6APICore*_core;NSDictionary*_message,*_block;OR6Chat9SelectionView*_text;UILabel*_status;UIButton*_copy,*_select;}
@end
@implementation OR6Chat9MessageController
- (id)initWithCore:(OR6APICore *)core message:(NSDictionary *)message{return[self initWithCore:core message:message block:nil];}
- (id)initWithCore:(OR6APICore *)core message:(NSDictionary *)message block:(NSDictionary *)block{if((self=[super init])){_core=[core retain];_message=[message copy];_block=[block copy];self.title=OR6L(@"Message text");}return self;}
- (UIButton *)button:(NSString *)title action:(SEL)action identifier:(NSString *)identifier{
 UIButton*b=[UIButton buttonWithType:UIButtonTypeRoundedRect];[b setTitle:title forState:UIControlStateNormal];[b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];b.accessibilityIdentifier=identifier;OR6Chat9ApplyControlAccessibility(b,title,@"",YES);return b;
}
- (void)loadView{
 self.view=[[[UIView alloc]initWithFrame:UIScreen.mainScreen.applicationFrame]autorelease];self.view.backgroundColor=UIColor.whiteColor;
 _copy=[[self button:OR6L(@"Copy text")action:@selector(copyAll)identifier:@"chat.message.copy"]retain];[self.view addSubview:_copy];
 _select=[[self button:OR6L(@"Select all")action:@selector(selectAllText)identifier:@"chat.message.select"]retain];[self.view addSubview:_select];
 _status=[[UILabel alloc]initWithFrame:CGRectZero];_status.font=[UIFont systemFontOfSize:13];_status.numberOfLines=2;_status.text=OR6L(@"Touch and hold the text to select a passage.");_status.accessibilityIdentifier=@"chat.message.text_status";[self.view addSubview:_status];
 _text=[[OR6Chat9SelectionView alloc]initWithFrame:CGRectZero];_text.selectionCore=_core;_text.messageId=_message[@"id"];_text.editable=NO;_text.font=[UIFont systemFontOfSize:17];_text.dataDetectorTypes=UIDataDetectorTypeNone;_text.text=OR6Chat9ReadableText(_message[@"text"],[_message[@"role"]isEqual:@"assistant"]);_text.accessibilityIdentifier=@"chat.message.selection";_text.accessibilityLabel=[_message[@"role"]isEqual:@"user"]?OR6L(@"Your message"):OR6L(@"ChatGPT response");[self.view addSubview:_text];
 if([_block[@"kind"]isEqual:@"code"]){UIButton*code=[self button:OR6L(@"Copy code")action:@selector(copyCode)identifier:@"chat.message.copy_code"];code.frame=CGRectMake(0,0,130,32);self.navigationItem.rightBarButtonItem=[[[UIBarButtonItem alloc]initWithCustomView:code]autorelease];}
}
- (void)viewDidLayoutSubviews{[super viewDidLayoutSubviews];CGFloat w=self.view.bounds.size.width,h=self.view.bounds.size.height;_copy.frame=CGRectMake(8,8,(w-24)/2,40);_select.frame=CGRectMake(16+(w-24)/2,8,(w-24)/2,40);_status.frame=CGRectMake(10,52,w-20,42);_text.frame=CGRectMake(4,98,w-8,MAX(0,h-102));}
- (void)copyAll{[_core perform:@"content.copy"parameters:OR6Chat9CopyParameters(_message[@"id"],_message[@"text"]?:@"")event:nil completion:^(NSDictionary*r,NSError*e){if(!e){[UIPasteboard generalPasteboard].string=r[@"text"];_status.text=OR6L(@"Message copied.");UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,_status.text);}}];}
- (void)selectAllText{[_text becomeFirstResponder];[_text selectAll:nil];_status.text=OR6L(@"All text is selected. Tap Copy in the selection menu.");}
- (void)copyCode{NSString*code=_block[@"copyText"]?:_block[@"text"];if(!code)return;[_core perform:@"content.copy"parameters:OR6Chat9CopyParameters(_message[@"id"],code)event:nil completion:^(NSDictionary*r,NSError*e){if(!e){[UIPasteboard generalPasteboard].string=r[@"text"];_status.text=OR6L(@"Code block copied.");UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,_status.text);}}];}
- (void)dealloc{[_core release];[_message release];[_block release];[_text release];[_status release];[_copy release];[_select release];[super dealloc];}
@end
