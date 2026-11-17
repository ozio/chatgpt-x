#import "OR6APILocalProvider.h"
#import "../OR6Content.h"
#import <CoreFoundation/CoreFoundation.h>
@interface OR6APILocalTask:NSObject<OR6APITask>@end
@implementation OR6APILocalTask
- (void)cancel{}
@end
@implementation OR6APILocalProvider
- (id)initWithNext:(id<OR6APIProvider>)next{if((self=[super init])){_next=[next retain];_drafts=[NSMutableDictionary new];}return self;}
- (void)installModels:(NSArray*)models{NSMutableDictionary*s=[NSMutableDictionary dictionary];for(NSDictionary*m in models){if([m isKindOfClass:NSDictionary.class]&&[m[@"id"]isKindOfClass:NSString.class])s[m[@"id"]]=m;}[_models release];_models=[s copy];if(_selected&&!_models[_selected]){[_selected release];_selected=nil;}}
- (void)didValidate:(NSString*)op result:(NSDictionary*)result context:(NSDictionary*)context{if([op isEqual:@"models.list"]&&[_scope isEqual:context[@"key"]])[self installModels:result[@"items"]];}
- (void)releaseCompletedDraft:(NSString*)draftId context:(NSDictionary*)context{if([_scope isEqual:context[@"key"]]&&draftId)[_drafts removeObjectForKey:draftId];}
- (id<OR6APITask>)execute:(NSString*)operation parameters:(NSDictionary*)p context:(NSDictionary*)ctx event:(OR6APIEvent)event completion:(OR6APIReply)completion{
 (void)event;if(![_scope isEqual:ctx[@"key"]]){[_scope release];_scope=[ctx[@"key"]copy];[_drafts removeAllObjects];[_models release];_models=nil;[_selected release];_selected=nil;}
 NSDictionary*result=nil;NSError*error=nil;
 if([operation isEqual:@"content.copy"])result=@{@"text":p[@"text"]};
 else if([operation isEqual:@"content.select"]){NSString*s=p[@"text"];NSUInteger start=[p[@"start"]unsignedIntegerValue],length=[p[@"length"]unsignedIntegerValue];if(start>s.length||length>s.length-start)error=OR6APIError(@"invalid_request",@"none");else{NSRange r=NSMakeRange(start,length);if(length)r=[s rangeOfComposedCharacterSequencesForRange:r];else if(start>0&&start<s.length&&CFStringIsSurrogateLowCharacter([s characterAtIndex:start]))error=OR6APIError(@"invalid_request",@"none");if(!error)result=@{@"messageId":p[@"messageId"],@"start":@(r.location),@"length":@(r.length),@"selectedText":[s substringWithRange:r]};}}
 else if([operation isEqual:@"content.scale"])result=@{@"scale":p[@"scale"]};
 else if([operation isEqual:@"content.accessibility"])result=@{@"messageId":p[@"messageId"],@"elements":p[@"elements"]};
 else if([operation isEqual:@"content.sources"]){for(NSDictionary*s in p[@"sources"])if(!OR6ContentSafeURL(s[@"url"],NO)){error=OR6APIError(@"invalid_request",@"none");break;}if(!error)result=@{@"messageId":p[@"messageId"],@"sources":p[@"sources"]};}
 else if([operation isEqual:@"content.present"]){
  NSArray*rows=[p[@"format"]isEqual:@"markdown"]?OR6ContentBlocks(p[@"text"]):OR6PlainContentBlocks(p[@"text"]);NSMutableArray*blocks=[NSMutableArray array];NSMutableString*plain=[NSMutableString string];
  for(NSDictionary*r in rows){NSString*k=r[@"kind"];if(![@[@"code",@"link",@"image",@"citation"]containsObject:k])k=@"paragraph";NSMutableDictionary*b=[NSMutableDictionary dictionaryWithDictionary:@{@"kind":k,@"text":r[@"text"]?:@"",@"url":r[@"url"]?:(id)NSNull.null,@"language":r[@"language"]?:(id)NSNull.null}];if(r[@"runs"])b[@"runs"]=r[@"runs"];if(r[@"level"])b[@"level"]=r[@"level"];if(r[@"copyText"])b[@"copyText"]=r[@"copyText"];[blocks addObject:b];if(plain.length)[plain appendString:@"\n"];[plain appendString:b[@"text"]];}
  result=@{@"messageId":p[@"messageId"],@"blocks":blocks,@"plainText":plain,@"format":p[@"format"]};
 }
 else if([operation isEqual:@"models.select"]){NSDictionary*m=_models[p[@"modelId"]];id effort=p[@"thinkingEffort"];BOOL valid=!effort||effort==NSNull.null;for(NSDictionary*e in m[@"efforts"])if([e[@"id"]isEqual:effort])valid=YES;if(!m||!valid)error=OR6APIError(@"capability_unverified",@"none");else{[_selected release];_selected=[p[@"modelId"]copy];result=effort?@{@"modelId":_selected,@"thinkingEffort":effort}:@{@"modelId":_selected};}}
 else if([operation isEqual:@"messages.newDraft"]){if(_drafts.count>=32||_drafts[p[@"draftId"]])error=OR6APIError(@"conflict",@"none");else{result=@{@"draftId":p[@"draftId"],@"conversationId":NSNull.null,@"parentMessageId":p[@"parentMessageId"],@"modelId":p[@"modelId"],@"temporary":p[@"temporary"],@"text":@"",@"attachments":@[]};if(p[@"thinkingEffort"]){NSMutableDictionary*d=[[result mutableCopy]autorelease];d[@"thinkingEffort"]=p[@"thinkingEffort"];result=d;}_drafts[p[@"draftId"]]=result;}}
 else if([operation isEqual:@"assets.detach"]){NSDictionary*d=_drafts[p[@"draftId"]];if(!d||![d[@"attachments"]containsObject:p[@"assetId"]])error=OR6APIError(@"not_found",@"none");else{NSMutableDictionary*n=[[d mutableCopy]autorelease];NSMutableArray*a=[[n[@"attachments"]mutableCopy]autorelease];[a removeObject:p[@"assetId"]];n[@"attachments"]=a;_drafts[p[@"draftId"]]=n;result=@{@"draftId":p[@"draftId"],@"assetId":p[@"assetId"],@"detached":(id)kCFBooleanTrue};}}
 else if([operation isEqual:@"assets.limits"])result=@{@"maxBytes":@(8*1024*1024),@"maxCount":@4,@"allowedMediaTypes":@[@"text/plain",@"image/png",@"image/jpeg",@"audio/wav"],@"scope":@"client_policy",@"serverLimitsKnown":(id)kCFBooleanFalse};
 else if(_next)return[_next execute:operation parameters:p context:ctx event:event completion:completion];
 else error=OR6APIError(@"capability_unverified",@"none");
 completion(result,error);return[[[OR6APILocalTask alloc]init]autorelease];
}
- (void)dealloc{[_next release];[_drafts release];[_models release];[_selected release];[_scope release];[super dealloc];}
@end
