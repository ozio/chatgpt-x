#import "OR6Chat9Content.h"
#import "../../OR6Content.h"
NSDictionary *OR6Chat9CopyParameters(NSString *messageId,NSString *text){if(![messageId isKindOfClass:NSString.class]||!messageId.length||messageId.length>96||![text isKindOfClass:NSString.class]||text.length>200000)return nil;return @{@"messageId":messageId,@"text":text};}
NSArray *OR6Chat9ContentRows(NSArray *messages){
 NSMutableArray*rows=[NSMutableArray array];NSUInteger index=0;
 for(NSDictionary*m in messages){NSString*source=m[@"text"];if(![source isKindOfClass:NSString.class])source=@"";
  NSArray*blocks=[m[@"role"]isEqual:@"assistant"]?OR6ContentBlocks(source):OR6PlainContentBlocks(source);NSUInteger part=0;
  for(NSDictionary*b in blocks){NSMutableDictionary*row=[NSMutableDictionary dictionaryWithDictionary:b];row[@"messageIndex"]=@(index);row[@"id"]=m[@"id"]?:@"message";row[@"role"]=m[@"role"]?:@"assistant";row[@"continued"]=@(part++>0);[rows addObject:row];}
  index++;
 }return[[rows copy]autorelease];
}
NSString *OR6Chat9ReadableText(NSString *source,BOOL markdown){
 NSMutableString*text=[NSMutableString string];for(NSDictionary*b in markdown?OR6ContentBlocks(source):OR6PlainContentBlocks(source)){
  if([@[@"link",@"image",@"citation"]containsObject:b[@"kind"]])continue;
  if(text.length)[text appendString:@"\n"];[text appendString:b[@"text"]?:@""];
 }return[[text copy]autorelease];
}
@implementation OR6Chat9ContentCache
- (id)init{if((self=[super init]))_messages=[NSMutableDictionary new];return self;}
- (NSUInteger)parseCount{return _parses;}
- (NSArray *)rowsForMessages:(NSArray *)messages{
 NSMutableArray*out=[NSMutableArray array];NSMutableSet*live=[NSMutableSet set];NSUInteger index=0;
 for(NSDictionary*m in messages){NSString*identifier=m[@"id"];if(![identifier isKindOfClass:NSString.class])continue;[live addObject:identifier];NSDictionary*cached=_messages[identifier];
  if(![cached[@"text"]isEqual:m[@"text"]]||![cached[@"role"]isEqual:m[@"role"]]){cached=@{@"text":m[@"text"]?:@"",@"role":m[@"role"]?:@"assistant",@"rows":OR6Chat9ContentRows(@[m])};_messages[identifier]=cached;_parses++;}
  for(NSDictionary*r in cached[@"rows"]){NSMutableDictionary*row=[[r mutableCopy]autorelease];row[@"messageIndex"]=@(index);[out addObject:row];}index++;
 }
 for(NSString*identifier in [[_messages.allKeys copy]autorelease])if(![live containsObject:identifier])[_messages removeObjectForKey:identifier];return[[out copy]autorelease];
}
- (void)dealloc{[_messages release];[super dealloc];}
@end
