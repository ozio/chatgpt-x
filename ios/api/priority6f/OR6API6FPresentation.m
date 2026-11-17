#import "OR6API6FPresentation.h"
#import "OR6API6FPolicy.h"
static id Fail(NSError**e,NSString*c){if(e)*e=OR6APIError(c,@"none");return nil;}
static NSDictionary*D(id v){return[v isKindOfClass:NSDictionary.class]?v:nil;}
static BOOL Text(id v,NSUInteger n){return[v isKindOfClass:NSString.class]&&[v length]<=n;}
@interface OR6API6FPresentation(){NSString*_session,*_conversation;NSMutableSet*_consumedFallback;NSDictionary*_context,*_warning,*_exceeded;NSString*_resets;NSUInteger _sequence;BOOL _visible,_observed,_hangUp;}
@end
static NSDictionary*Notice(id raw,BOOL warning,NSError**error){
 NSDictionary*r=D(raw);if(!r)return Fail(error,@"unknown_wire_shape");NSString*title=r[@"title"]?:@"",*hint=warning?r[@"hint"]?:@"":@"",*body=r[warning?@"message_markdown":@"description_markdown"]?:@"";NSArray*buttons=r[@"buttons"]?:@[];
 if(!Text(title,240)||!Text(hint,1000)||!Text(body,8000)||![buttons isKindOfClass:NSArray.class]||buttons.count>8)return Fail(error,@"unknown_wire_shape");NSMutableArray*actions=[NSMutableArray array];
 for(id value in buttons){NSDictionary*b=D(value);if(!b||!Text(b[@"action"],128))return Fail(error,@"unknown_wire_shape");NSString*action=b[@"action"];if([@[@"switch_to_standard",@"upgrade_to_plus",@"upgrade_to_pro",@"new_chat",@"dismiss"]containsObject:action]&&![actions containsObject:action])[actions addObject:action];}
 return@{@"id":OR6API6FNewUUID(),@"title":title,@"descriptionMarkdown":body,@"hint":hint,@"actions":actions};
}
@implementation OR6API6FPresentation
- (id)init{if((self=[super init]))_consumedFallback=[NSMutableSet new];return self;}
- (BOOL)current:(NSString*)session context:(NSDictionary*)ctx{return NSThread.isMainThread&&[_context isEqual:ctx]&&[_session isEqual:session];}
- (BOOL)bindSession:(NSString*)session conversation:(NSString*)cid context:(NSDictionary*)ctx error:(NSError**)error{
 if(!NSThread.isMainThread||!OR6API6FUUID(session)||(cid&&!OR6API6FUUID(cid))||!D(ctx)||!OR6APIJSONSnapshot(ctx,4096)){Fail(error,@"invalid_request");return NO;}
 if([self current:session context:ctx]){if(cid&&_conversation&&![_conversation isEqual:cid]){Fail(error,@"conflict");return NO;}if(cid&&!_conversation)_conversation=[cid copy];return YES;}
 [self deactivate];_session=[session copy];_conversation=[cid copy];_context=[OR6APIJSONSnapshot(ctx,4096)retain];return YES;
}
- (BOOL)applyEvent:(NSDictionary*)event session:(NSString*)session sequence:(NSUInteger)sequence context:(NSDictionary*)ctx error:(NSError**)error{
 if(![self current:session context:ctx]){Fail(error,@"stale_context");return NO;}NSDictionary*e=D(OR6APIJSONSnapshot(event,65536)),*p=D(e[@"payload"]);NSString*type=e[@"type"];
 if(!p||sequence<=_sequence||sequence>2147483647||![@[@"usage_update",@"conversation_detail_metadata"]containsObject:type]){Fail(error,@"invalid_response");return NO;}
 id cid=p[@"conversation_id"];if(cid&&cid!=NSNull.null&&(!OR6API6FUUID(cid)||(_conversation&&![_conversation isEqual:cid]))){Fail(error,@"owner_mismatch");return NO;}
 if([type isEqual:@"conversation_detail_metadata"]){NSDictionary*banner=D(p[@"banner_info"]);id resets=banner[@"resets_after"];if(resets&&resets!=NSNull.null&&(!Text(resets,40)||![resets length])){Fail(error,@"unknown_wire_shape");return NO;}if(cid&&cid!=NSNull.null&&!_conversation)_conversation=[cid copy];[_resets release];_resets=resets==NSNull.null?nil:[resets copy];_sequence=sequence;return YES;}
 NSDictionary*rate=D(p[@"rate_limit_message"]),*instructions=D(p[@"instructions"]);if(p[@"rate_limit_message"]&&p[@"rate_limit_message"]!=NSNull.null&&!rate){Fail(error,@"unknown_wire_shape");return NO;}if(p[@"instructions"]&&p[@"instructions"]!=NSNull.null&&!instructions){Fail(error,@"unknown_wire_shape");return NO;}if(instructions[@"hang_up"]&&!OR6APISchemaCheck(instructions[@"hang_up"],@{@"type":@"boolean"},@{})){Fail(error,@"unknown_wire_shape");return NO;}
 NSDictionary*warning=nil,*exceeded=nil;id w=rate[@"reaching_limit_disclosure"],x=rate[@"exceed_limit_message"];if(w&&w!=NSNull.null){warning=Notice(w,YES,error);if(!warning)return NO;}if(x&&x!=NSNull.null){exceeded=Notice(x,NO,error);if(!exceeded)return NO;}
 if(warning&&[_warning[@"hint"]isEqual:warning[@"hint"]])warning=_warning;
 if(cid&&cid!=NSNull.null&&!_conversation)_conversation=[cid copy];[warning retain];[_warning release];_warning=warning;[exceeded retain];[_exceeded release];_exceeded=exceeded;NSMutableSet*active=[NSMutableSet set];if(warning[@"id"])[active addObject:warning[@"id"]];if(exceeded[@"id"])[active addObject:exceeded[@"id"]];[_consumedFallback intersectSet:active];_hangUp=exceeded&&(!instructions||[instructions[@"hang_up"]isEqual:@YES]);_sequence=sequence;_observed=YES;return YES;
}
- (NSDictionary*)transcript:(NSString*)session visible:(NSNumber*)visible context:(NSDictionary*)ctx error:(NSError**)error{
 if(![self current:session context:ctx])return Fail(error,@"stale_context");if(visible){if(!OR6APISchemaCheck(visible,@{@"type":@"boolean"},@{}))return Fail(error,@"invalid_request");_visible=visible.boolValue;}
 return@{@"sessionId":_session,@"conversationId":_conversation?:NSNull.null,@"visible":@(_visible),@"uiShown":@NO};
}
- (NSDictionary*)usage:(NSString*)session context:(NSDictionary*)ctx error:(NSError**)error{
 if(![self current:session context:ctx])return Fail(error,@"stale_context");return@{@"sessionId":_session,@"observed":@(_observed),@"warning":_warning?:NSNull.null,@"exceeded":_exceeded?:NSNull.null,@"resetsAfter":_resets?:NSNull.null,@"hangUp":@(_hangUp)};
}
- (BOOL)consumeFallback:(NSString*)notice session:(NSString*)session context:(NSDictionary*)ctx error:(NSError**)error{
 if(![self current:session context:ctx]){Fail(error,@"stale_context");return NO;}NSDictionary*n=[_exceeded[@"id"]isEqual:notice]?_exceeded:[_warning[@"id"]isEqual:notice]?_warning:nil;
 if(!n||!OR6API6FUUID(notice)||![n[@"actions"]containsObject:@"switch_to_standard"]||[_consumedFallback containsObject:notice]){Fail(error,@"conflict");return NO;}[_consumedFallback addObject:notice];return YES;
}
- (void)deactivate{[_session release];_session=nil;[_conversation release];_conversation=nil;[_context release];_context=nil;[_warning release];_warning=nil;[_exceeded release];_exceeded=nil;[_resets release];_resets=nil;[_consumedFallback removeAllObjects];_sequence=0;_visible=NO;_observed=NO;_hangUp=NO;}
- (void)dealloc{[self deactivate];[_consumedFallback release];[super dealloc];}
@end
