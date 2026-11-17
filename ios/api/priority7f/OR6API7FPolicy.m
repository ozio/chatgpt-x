#import "OR6API7FPolicy.h"
#import "../priority8/OR6API8Policy.h"
#import "../../chat/OR6ChatNativePolicy.h"
#import "../OR6APIWire.h"
#import <CoreFoundation/CoreFoundation.h>
static id Fail(NSError**e,NSString*c){if(e)*e=OR6APIError(c,@"none");return nil;}
static NSDictionary *Dict(id v){return[v isKindOfClass:NSDictionary.class]?v:nil;}
static NSString *Canonical(id v){if([v isKindOfClass:NSDictionary.class]){NSMutableArray*a=[NSMutableArray array];for(NSString*k in [[v allKeys]sortedArrayUsingSelector:@selector(compare:)])[a addObject:[NSString stringWithFormat:@"%@:%@",Canonical(k),Canonical(v[k])]];return[@"{"stringByAppendingFormat:@"%@}",[a componentsJoinedByString:@","]];}if([v isKindOfClass:NSArray.class]){NSMutableArray*a=[NSMutableArray array];for(id x in v)[a addObject:Canonical(x)];return[@"["stringByAppendingFormat:@"%@]",[a componentsJoinedByString:@","]];}NSData*d=[NSJSONSerialization dataWithJSONObject:@[v]options:0 error:NULL];NSString*s=[[[NSString alloc]initWithData:d encoding:NSUTF8StringEncoding]autorelease];return s.length>=2?[s substringWithRange:NSMakeRange(1,s.length-2)]:nil;}
static BOOL Text(id x,NSUInteger n){return[x isKindOfClass:NSString.class]&&[x length]>0&&[x length]<=n;}
NSString *OR6API7FUUID(void){CFUUIDRef u=CFUUIDCreate(NULL);NSString*s=[(NSString*)CFUUIDCreateString(NULL,u)autorelease];CFRelease(u);return s.lowercaseString;}
BOOL OR6API7FCommand(NSString*op){return[@[@"chat.continue",@"chat.sharedLink.delete",@"compose.clarifications.get",@"compose.clarifications.respond",@"tools.deepResearch",@"tools.deepResearch.status",@"tools.deepResearch.cancel",@"tools.dataAnalysis",@"tools.dataAnalysis.result",@"tools.study",@"tools.actionApproval.get",@"tools.actionApproval.respond",@"images.create",@"tools.operation.reconcile"]containsObject:op];}
BOOL OR6API7FMutation(NSString*op){return OR6API7FCommand(op)&&![@[@"compose.clarifications.get",@"tools.actionApproval.get",@"tools.deepResearch.status",@"tools.operation.reconcile",@"tools.dataAnalysis.result"]containsObject:op];}
NSDictionary *OR6API7FRegistry(NSDictionary*base,NSDictionary*ext,NSError**error){
 if(![base[@"schemaVersion"]isEqual:@1]||![ext[@"schemaVersion"]isEqual:@1]||![base[@"types"]isKindOfClass:NSDictionary.class]||![ext[@"types"]isKindOfClass:NSDictionary.class]||![base[@"operations"]isKindOfClass:NSArray.class]||![ext[@"operations"]isKindOfClass:NSArray.class]||![base[@"featureMap"]isKindOfClass:NSArray.class]||![ext[@"featureMap"]isKindOfClass:NSArray.class])return Fail(error,@"invalid_request");
 NSMutableDictionary*r=[[base mutableCopy]autorelease],*types=[[base[@"types"]mutableCopy]autorelease];NSMutableArray*ops=[[base[@"operations"]mutableCopy]autorelease],*features=[[base[@"featureMap"]mutableCopy]autorelease];NSMutableSet*ids=[NSMutableSet set];for(NSDictionary*o in ops)[ids addObject:o[@"id"]];for(NSString*k in ext[@"types"]){if(types[k])return Fail(error,@"conflict");types[k]=ext[@"types"][k];}for(NSDictionary*o in ext[@"operations"]){if(!OR6API7FCommand(o[@"id"])||[ids containsObject:o[@"id"]])return Fail(error,@"conflict");[ids addObject:o[@"id"]];[ops addObject:o];}[features addObjectsFromArray:ext[@"featureMap"]];r[@"types"]=types;r[@"operations"]=ops;r[@"featureMap"]=features;return OR6APIJSONSnapshot(r,4*1024*1024);
}
static NSDictionary *Message(NSDictionary*c,NSString*mid){for(NSDictionary*m in c[@"messages"])if([m[@"id"]isEqual:mid])return m;return nil;}
NSDictionary *OR6API7FPlan(NSString*op,NSDictionary*p,NSDictionary*c,NSString*model,NSString*hint,NSDictionary*challenge,NSError**error){
 if(error)*error=nil;if(!OR6CNUUID(p[@"operationId"])||!Text(model,128))return Fail(error,@"invalid_request");
 NSMutableDictionary*input=[NSMutableDictionary dictionaryWithDictionary:@{@"operationId":p[@"operationId"],@"draftId":OR6API7FUUID(),@"modelId":model,@"parentMessageId":p[@"parentMessageId"]?:OR6API7FUUID(),@"temporary":@NO,@"text":p[@"text"]?:@"",@"attachments":@[]}];if(p[@"conversationId"]&&p[@"conversationId"]!=NSNull.null)input[@"conversationId"]=p[@"conversationId"];
 BOOL continuation=[op isEqual:@"chat.continue"],approval=[op isEqual:@"tools.actionApproval.respond"],answers=[op isEqual:@"compose.clarifications.respond"];
 NSString*uid=nil;NSDictionary*target=nil;
 if(continuation){
  if(![c[@"id"]isEqual:p[@"conversationId"]])return Fail(error,@"owner_mismatch");target=Message(c,p[@"assistantMessageId"]);
  if(![target[@"role"]isEqual:@"assistant"]||![target[@"finished"]isEqual:@NO]||![target[@"status"]isEqual:@"finished_partial_completion"]||![target[@"nodeId"]isEqual:c[@"currentNode"]])return Fail(error,@"invalid_operation_state");
  NSDictionary*node=nil;for(NSDictionary*n in c[@"nodes"])if([n[@"id"]isEqual:target[@"nodeId"]])node=n;NSMutableSet*seen=[NSMutableSet set];NSDictionary*user=nil;
  while(node&&seen.count<2048){NSString*parent=node[@"parent"];if(!Text(parent,36)||[seen containsObject:parent])break;[seen addObject:parent];node=nil;for(NSDictionary*n in c[@"nodes"])if([n[@"id"]isEqual:parent])node=n;if(!node)break;NSDictionary*m=Message(c,node[@"messageId"]);if([m[@"role"]isEqual:@"user"]){user=m;break;}}
  if(!user||!Text(user[@"text"],16000))return Fail(error,@"invalid_response");uid=user[@"id"];input[@"text"]=user[@"text"];input[@"parentMessageId"]=target[@"nodeId"];
 }else if(approval||answers){if(![challenge isKindOfClass:NSDictionary.class]||!OR6CNUUID(challenge[@"conversationId"])||!OR6CNUUID(challenge[@"parentMessageId"]))return Fail(error,@"invalid_request");input[@"conversationId"]=challenge[@"conversationId"];input[@"parentMessageId"]=challenge[@"parentMessageId"];input[@"text"]=challenge[@"responseText"]?:@"approval";}
 else if(input[@"conversationId"]&&(![c[@"id"]isEqual:input[@"conversationId"]]||![c[@"currentNode"]isEqual:input[@"parentMessageId"]]))return Fail(error,@"conflict");
 NSDictionary*original=OR6API8Plan(@"messages.send",input,nil,model,@[],error);if(!original)return nil;NSMutableDictionary*plan=[[original mutableCopy]autorelease],*body=[[original[@"body"]mutableCopy]autorelease];
 if(continuation){body[@"action"]=@"continue";body[@"messages"]=@[];plan[@"userMessageId"]=uid;}
 else if(approval){NSMutableDictionary*m=[[[body[@"messages"]objectAtIndex:0]mutableCopy]autorelease];m[@"content"]=@{@"content_type":@"text",@"parts":@[@""]};m[@"metadata"]=challenge[@"responseMetadata"];m[@"author"]=@{@"role":@"tool",@"name":challenge[@"recipient"],@"metadata":@{}};m[@"recipient"]=@"all";body[@"messages"]=@[m];NSMutableDictionary*np=[[plan[@"parameters"]mutableCopy]autorelease];np[@"text"]=challenge[@"originalUserText"];plan[@"parameters"]=np;plan[@"userMessageId"]=challenge[@"originalUserId"];}
 if(answers&&[challenge[@"format"]isEqual:@"questionnaire"]){NSMutableDictionary*m=[[[body[@"messages"]objectAtIndex:0]mutableCopy]autorelease];NSMutableDictionary*metadata=[NSMutableDictionary dictionaryWithDictionary:Dict(m[@"metadata"])?:@{}];metadata[@"message_submission_source"]=@"ask_user_input";m[@"metadata"]=metadata;body[@"messages"]=@[m];}
 if(hint){if(![@[@"picture_v2",@"tatertot",@"connector:connector_openai_deep_research",@"plugin:connector_openai_deep_research"]containsObject:hint])return Fail(error,@"invalid_request");body[@"system_hints"]=@[hint];if([body[@"messages"]count]){NSMutableDictionary*m=[[[body[@"messages"]objectAtIndex:0]mutableCopy]autorelease],*metadata=[NSMutableDictionary dictionaryWithDictionary:m[@"metadata"]?:@{}];metadata[@"system_hints"]=@[hint];m[@"metadata"]=metadata;body[@"messages"]=@[m];}}
 plan[@"body"]=body;plan[@"operation"]=op;return OR6APIJSONSnapshot(plan,512*1024);
}
NSDictionary *OR6API7FResult(NSDictionary*r,NSDictionary*a,NSError**error){
 if(![r isKindOfClass:NSDictionary.class]||!OR6CNUUID(r[@"operationId"])||![@[@"completed",@"uncertain",@"background",@"rejected",@"cancelled"]containsObject:r[@"state"]]||!OR6APISchemaCheck(r[@"persisted"],@{@"type":@"boolean"},@{}))return Fail(error,@"invalid_response");
 if([r[@"persisted"]boolValue]!=[r[@"state"]isEqual:@"completed"])return Fail(error,@"invalid_response");for(NSString*k in @[@"conversationId",@"userMessageId",@"assistantMessageId"])if(r[k]!=NSNull.null&&!OR6CNUUID(r[k]))return Fail(error,@"invalid_response");if(a&&![a isKindOfClass:NSDictionary.class])return Fail(error,@"invalid_response");if(a[@"parts"]&&![a[@"parts"]isKindOfClass:NSArray.class])return Fail(error,@"invalid_response");NSString*text=a[@"text"]?:@"";if(![text isKindOfClass:NSString.class]||text.length>262144)return Fail(error,@"invalid_response");NSMutableArray*images=[NSMutableArray array];
 for(NSDictionary*p in a[@"parts"]){if(![p isKindOfClass:NSDictionary.class])return Fail(error,@"invalid_response");NSDictionary*d=p[@"data"];if(![@[@"image",@"asset"]containsObject:p[@"kind"]]||![d isKindOfClass:NSDictionary.class]||!d[@"asset_pointer"])continue;NSString*pointer=d[@"asset_pointer"],*file=nil;for(NSString*prefix in @[@"sediment://",@"file-service://"])if([pointer hasPrefix:prefix])file=[pointer substringFromIndex:prefix.length];if(!file||!OR6API8RemoteID(file)||images.count>=16)return Fail(error,@"unsupported_media");for(NSString*k in @[@"width",@"height"])if(d[k]&&!OR6APISchemaCheck(d[k],@{@"type":@"integer",@"minimum":@0,@"maximum":@100000},@{}))return Fail(error,@"invalid_response");[images addObject:@{@"fileId":file,@"width":d[@"width"]?:@0,@"height":d[@"height"]?:@0}];}
 NSMutableDictionary*out=[NSMutableDictionary dictionary];for(NSString*k in @[@"operationId",@"state",@"conversationId",@"userMessageId",@"assistantMessageId",@"persisted"])out[k]=r[k];out[@"text"]=text;out[@"images"]=images;return out;
}
NSDictionary *OR6API7FImageResult(id raw,NSDictionary*b,NSString*op,NSError**error){
 if(error)*error=nil;
 if(!Dict(raw)||!OR6CNUUID(op)||!OR6CNUUID(b[@"conversationId"])||!OR6CNUUID(b[@"userMessageId"])||
    !Text(b[@"textSHA256"],64)||[b[@"textSHA256"]length]!=64)return Fail(error,@"invalid_request");
 NSData*data=[NSJSONSerialization dataWithJSONObject:raw options:0 error:NULL];
 NSDictionary*c=OR6APIWireConversation(data,b[@"conversationId"],NULL);
 if(!c)return Fail(error,@"unknown_wire_shape");
 BOOL found=NO;NSDictionary*image=nil,*answer=nil;
 for(NSDictionary*m in c[@"messages"]){
  if([m[@"role"]isEqual:@"user"]){
   if(found)break;
   if(![m[@"id"]isEqual:b[@"userMessageId"]])continue;
   if(![OR6CNHash(m[@"text"])isEqual:b[@"textSHA256"]])return Fail(error,@"conflict");
   if([b[@"existingConversation"]isEqual:@YES]){BOOL parent=NO;for(NSDictionary*n in c[@"nodes"])if([n[@"id"]isEqual:m[@"nodeId"]])parent=[n[@"parent"]isEqual:b[@"parentMessageId"]];if(!parent)return Fail(error,@"conflict");}
   found=YES;
  }else if(found&&[m[@"type"]isEqual:@"generated_image"]&&[m[@"finished"]isEqual:@YES]){image=m;break;}
  else if(found&&[m[@"role"]isEqual:@"assistant"]&&[m[@"finished"]isEqual:@YES]&&[m[@"endTurn"]isEqual:@YES]&&[m[@"text"]length])answer=m;
 }
 if(!found)return Fail(error,@"conflict");
 NSDictionary*resultMessage=image?:answer;
 NSDictionary*r=@{@"operationId":op,@"conversationId":b[@"conversationId"],@"userMessageId":b[@"userMessageId"],
  @"assistantMessageId":resultMessage?resultMessage[@"id"]:(id)NSNull.null,@"state":resultMessage?@"completed":@"uncertain",@"persisted":resultMessage?@YES:@NO};
 return OR6API7FResult(r,resultMessage?:@{},error);
}
NSURLRequest *OR6API7FRequest(NSString*op,NSDictionary*p,NSError**error){
 NSString*path=nil,*method=@"GET";NSDictionary*body=nil;
 if([op isEqual:@"chat.sharedLink.delete"]||[op isEqual:@"share.read"]){if(!OR6CNUUID(p[@"shareId"]))return Fail(error,@"invalid_request");path=[@"/backend-api/share/"stringByAppendingString:[p[@"shareId"]lowercaseString]];if([op isEqual:@"chat.sharedLink.delete"])method=@"DELETE";}
 else if([op isEqual:@"tools.deepResearch.cancel"]){if(!OR6CNUUID(p[@"conversationId"]))return Fail(error,@"invalid_request");path=@"/backend-api/stop_conversation";method=@"POST";body=@{@"conversation_id":[p[@"conversationId"]lowercaseString],@"exclude_async_types":@[]};}
 else if([op isEqual:@"analysis.models"])path=@"/backend-api/models?iim=false&include_icons=false&is_gizmo=false";
 else if([op isEqual:@"hints.basic"])path=@"/backend-api/system_hints?exclude_logo=true&mode=basic";
 else if([op isEqual:@"hints.plugins"])path=@"/backend-api/system_hints?exclude_logo=true&mode=plugins";
 else if([@[@"compose.clarifications.get",@"tools.actionApproval.get",@"history.raw",@"tools.deepResearch.status"]containsObject:op]){if(!OR6CNUUID(p[@"conversationId"]))return Fail(error,@"invalid_request");path=[NSString stringWithFormat:@"/backend-api/conversation/%@%@",[p[@"conversationId"]lowercaseString],[op isEqual:@"tools.deepResearch.status"]?@"/stream_status":@""];}
 else return Fail(error,@"invalid_request");NSMutableURLRequest*r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:[@"https://chatgpt.com"stringByAppendingString:path]]];r.HTTPMethod=method;if(body){r.HTTPBody=[NSJSONSerialization dataWithJSONObject:body options:0 error:NULL];[r setValue:@"application/json"forHTTPHeaderField:@"Content-Type"];}return r;
}
BOOL OR6API7FAllowedRequest(NSURLRequest*r){
 NSURL*u=r.URL;if(![u.scheme isEqual:@"https"]||![u.host isEqual:@"chatgpt.com"]||u.user||u.password||u.port||u.fragment||r.HTTPBodyStream||r.HTTPBody.length>4096||u.absoluteString.length>512)return NO;for(NSString*k in r.allHTTPHeaderFields)if(![k.lowercaseString isEqual:@"content-type"]||![[r valueForHTTPHeaderField:k]isEqual:@"application/json"])return NO;
 NSArray*a=[u.path componentsSeparatedByString:@"/"];NSString*op=nil;NSDictionary*p=@{};
 if([u.path isEqual:@"/backend-api/models"]&&[r.HTTPMethod isEqual:@"GET"]&&[u.query isEqual:@"iim=false&include_icons=false&is_gizmo=false"]){op=@"analysis.models";}
 else if([u.path isEqual:@"/backend-api/system_hints"]&&[r.HTTPMethod isEqual:@"GET"]){if([u.query isEqual:@"exclude_logo=true&mode=basic"])op=@"hints.basic";else if([u.query isEqual:@"exclude_logo=true&mode=plugins"])op=@"hints.plugins";}
 else if([u.path isEqual:@"/backend-api/stop_conversation"]&&[r.HTTPMethod isEqual:@"POST"]&&!u.query){id b=[NSJSONSerialization JSONObjectWithData:r.HTTPBody?:[NSData data]options:0 error:NULL];if([b isKindOfClass:NSDictionary.class]&&[b count]==2&&[b[@"exclude_async_types"]isEqual:@[]]&&OR6CNUUID(b[@"conversation_id"])){op=@"tools.deepResearch.cancel";p=@{@"conversationId":b[@"conversation_id"]};}}
 else if(a.count==4&&[a[1]isEqual:@"backend-api"]&&[a[2]isEqual:@"share"]&&!u.query&&OR6CNUUID(a[3])&&[@[@"GET",@"DELETE"]containsObject:r.HTTPMethod]){op=[r.HTTPMethod isEqual:@"DELETE"]?@"chat.sharedLink.delete":@"share.read";p=@{@"shareId":a[3]};}
 else if((a.count==4||a.count==5)&&[a[1]isEqual:@"backend-api"]&&[a[2]isEqual:@"conversation"]&&OR6CNUUID(a[3])&&[r.HTTPMethod isEqual:@"GET"]&&!u.query){op=a.count==4?@"history.raw":([a[4]isEqual:@"stream_status"]?@"tools.deepResearch.status":nil);p=@{@"conversationId":a[3]};}
 NSURLRequest*canonical=op?OR6API7FRequest(op,p,NULL):nil;return canonical&&[canonical.URL.absoluteString isEqual:u.absoluteString]&&[canonical.HTTPMethod isEqual:r.HTTPMethod]&&((!canonical.HTTPBody&&!r.HTTPBody)||[canonical.HTTPBody isEqual:r.HTTPBody]);
}
// The web preference questionnaire is a distinct source-backed envelope from
// codex_request_user_input_async. Native/tool elicitation is never silently
// downgraded to a plain-text questionnaire response.
static NSDictionary *Questionnaire(NSDictionary*message,NSString*mid){
 NSDictionary*metadata=Dict(message[@"metadata"]);if(![Dict(message[@"author"])[@"role"]isEqual:@"assistant"]||![message[@"status"]isEqual:@"finished_successfully"]||metadata[@"codex_request_user_input"]||![@[@"text",@"multimodal_text"]containsObject:Dict(message[@"content"])[@"content_type"]?:@""])return nil;
 for(NSString*k in @[@"is_visually_hidden_from_conversation",@"is_visually_hidden_reasoning",@"is_visually_hidden_reasoning_group"])if(metadata[k]&&![metadata[k]isEqual:@NO])return nil;
 NSArray*refs=metadata[@"content_references"];if(![refs isKindOfClass:NSArray.class]||refs.count>256)return nil;NSDictionary*request=nil;NSMutableArray*rows=[NSMutableArray array];
 for(id value in refs){NSDictionary*ref=Dict(value);if(![ref[@"type"]isEqual:@"client_defined_widget"]||![ref[@"category"]isEqual:@"ask_user_input"])continue;if(request)return nil;NSDictionary*data=Dict(ref[@"data"]);NSArray*questions=data[@"questions"];
  if(!data||data[@"widget_variant"]||data[@"codex_request_user_input"]||![questions isKindOfClass:NSArray.class]||!questions.count||questions.count>20)return nil;
  NSUInteger index=0;for(id value in questions){NSDictionary*q=Dict(value);NSString*question=[q[@"question"]isKindOfClass:NSString.class]?[q[@"question"]stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]:nil;NSString*kind=q[@"type"],*placeholder=[q[@"free_text_placeholder"]isKindOfClass:NSString.class]?[q[@"free_text_placeholder"]stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]:nil;NSArray*options=q[@"options"];
   if(!Text(question,4000)||!Text(placeholder,4000)||![@[@"single_select",@"multi_select"]containsObject:kind?:@""]||![options isKindOfClass:NSArray.class]||options.count<2||options.count>10||(q[@"allow_custom_text"]&&!OR6APISchemaCheck(q[@"allow_custom_text"],@{@"type":@"boolean"},@{})))return nil;
   NSMutableArray*normalized=[NSMutableArray array];NSMutableSet*labels=[NSMutableSet set];for(id value in options){NSString*label=[value isKindOfClass:NSString.class]?[value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]:nil;if(!Text(label,1000)||[labels containsObject:label])return nil;[labels addObject:label];[normalized addObject:@{@"label":label,@"description":@""}];}
   NSData*json=[NSJSONSerialization dataWithJSONObject:@[@"ask_user_input",mid,@(index++)]options:0 error:NULL];NSString*identifier=[[[NSString alloc]initWithData:json encoding:NSUTF8StringEncoding]autorelease];[rows addObject:@{@"id":identifier,@"question":question,@"options":normalized,@"allowFreeText":[q[@"allow_custom_text"]isEqual:@NO]?@NO:@YES,@"multiple":[kind isEqual:@"multi_select"]?@YES:@NO,@"allowSkip":@YES}];
  }request=ref;
 }
 return request?@{@"questions":rows,@"request":request,@"format":@"questionnaire"}:nil;
}
NSDictionary *OR6API7FPending(NSString*op,NSDictionary*raw,NSString*cid,NSString*mid,NSError**error){
 if(!OR6APIJSONSnapshot(raw,4*1024*1024)||![raw isKindOfClass:NSDictionary.class]||!OR6CNUUID(cid)||!OR6CNUUID(mid)||![raw[@"conversation_id"]isEqual:cid]||![raw[@"mapping"]isKindOfClass:NSDictionary.class]||[raw[@"mapping"]count]>2048||!OR6CNUUID(raw[@"current_node"]))return Fail(error,@"invalid_response");
 NSDictionary*mapping=raw[@"mapping"],*node=Dict(mapping[raw[@"current_node"]]);NSDictionary*message=Dict(node[@"message"]);if(![message[@"id"]isEqual:mid])return Fail(error,@"invalid_operation_state");NSDictionary*metadata=message[@"metadata"];if(![metadata isKindOfClass:NSDictionary.class]||!Dict(message[@"author"]))return Fail(error,@"invalid_response");
 NSString*model=metadata[@"model_slug"]?:@"auto";if(!Text(model,128))return Fail(error,@"invalid_response");NSMutableDictionary*out=[NSMutableDictionary dictionaryWithDictionary:@{@"conversationId":cid,@"messageId":mid,@"parentMessageId":raw[@"current_node"],@"model":model}];
 // Retain only the nearest original user turn for the native transport's
 // persistence proof; never treat a later conversation turn as this challenge.
 NSMutableSet*seen=[NSMutableSet set];NSDictionary*cursor=node,*user=nil;while(cursor&&seen.count<2048){NSDictionary*m=Dict(cursor[@"message"]);if([Dict(m[@"author"])[@"role"]isEqual:@"user"]){user=m;break;}NSString*parent=cursor[@"parent"];if(!Text(parent,36)||[seen containsObject:parent])break;[seen addObject:parent];cursor=Dict(mapping[parent]);}
 if(!OR6CNUUID(user[@"id"])||!Dict(user[@"content"])||![user[@"content"][@"parts"]isKindOfClass:NSArray.class]||[user[@"content"][@"parts"]count]!=1||!Text(user[@"content"][@"parts"][0],16000))return Fail(error,@"unsupported_media");out[@"originalUserId"]=user[@"id"];out[@"originalUserText"]=user[@"content"][@"parts"][0];
 if([op isEqual:@"tools.actionApproval.get"]){
  NSDictionary*request=Dict(Dict(metadata[@"jit_plugin_data"])[@"from_server"]);BOOL elicitation=NO;if(!request){request=Dict(Dict(Dict(metadata[@"elicitation_metadata"])[@"plugin_data"])[@"from_server"]);elicitation=YES;}
  if(![request isKindOfClass:NSDictionary.class]||![@[@"confirm_action",@"approve_tool_in_context_scope"]containsObject:request[@"type"]]||![message[@"author"][@"role"]isEqual:@"tool"])return Fail(error,@"unsupported_media");NSDictionary*b=request[@"body"];
  // Rich forms, authentication, wallet and permission-policy mutations require
  // their own schema; plain per-action allow/deny is admitted here.
  if(![b isKindOfClass:NSDictionary.class]||b[@"codex_mcp_elicitation"]||![b[@"actions"]isKindOfClass:NSArray.class]||[b[@"actions"]count]>32)return Fail(error,@"unsupported_media");NSString*allow=nil,*deny=nil;
  for(NSDictionary*a in b[@"actions"]){if(![a isKindOfClass:NSDictionary.class])return Fail(error,@"invalid_response");NSString*target=Dict(a[@"allow_once"])[@"target_message_id"]?:Dict(a[@"allow"])[@"target_message_id"];if(target&&![a[@"name"]isEqual:@"approve_for_me"]&&!allow)allow=target;if(Dict(a[@"deny"])[@"target_message_id"]&&!deny)deny=Dict(a[@"deny"])[@"target_message_id"];}
  if((allow&&!OR6CNUUID(allow))||(deny&&!OR6CNUUID(deny))||(!allow&&!deny))return Fail(error,@"unsupported_media");NSString*recipient=message[@"author"][@"name"]?:@"api_tool.call_tool";if(!Text(recipient,256))return Fail(error,@"invalid_response");NSDictionary*summary=Dict(b[@"tool_call_safety_summary"]);NSString*title=summary[@"title"]?:b[@"operation"]?:@"",*description=summary[@"description"]?:b[@"approval_reason"]?:@"";if(![title isKindOfClass:NSString.class]||title.length>4000||![description isKindOfClass:NSString.class]||description.length>8000)return Fail(error,@"invalid_response");out[@"allowTarget"]=allow?:NSNull.null;out[@"denyTarget"]=deny?:NSNull.null;out[@"elicitation"]=@(elicitation);out[@"recipient"]=recipient;out[@"request"]=request;out[@"dto"]=@{@"conversationId":cid,@"messageId":mid,@"challengeId":NSNull.null,@"title":title,@"description":description,@"recipient":recipient,@"canAllow":allow?@YES:@NO,@"canDeny":deny?@YES:@NO};
 }else if([op isEqual:@"compose.clarifications.get"]){
  NSDictionary*q=Dict(metadata[@"codex_request_user_input_async"]),*generic=metadata[@"codex_request_user_input_async"]?nil:Questionnaire(message,mid);NSArray*questions=q[@"questions"];NSMutableArray*rows=[NSMutableArray array];
  if(generic){[rows addObjectsFromArray:generic[@"questions"]];out[@"request"]=generic[@"request"];out[@"format"]=@"questionnaire";}
  else{if(![message[@"author"][@"role"]isEqual:@"assistant"]||![q isKindOfClass:NSDictionary.class]||!Text(q[@"item_id"],128)||![questions isKindOfClass:NSArray.class]||!questions.count||questions.count>20)return Fail(error,@"unsupported_media");NSUInteger index=0;for(NSDictionary*question in questions){if(![question isKindOfClass:NSDictionary.class]||!Text(question[@"title"],4000))return Fail(error,@"invalid_response");NSArray*options=question[@"options"]?:@[];if(![options isKindOfClass:NSArray.class]||options.count>20)return Fail(error,@"invalid_response");NSMutableArray*normalized=[NSMutableArray array];for(NSString*choice in options){if(!Text(choice,1000))return Fail(error,@"invalid_response");[normalized addObject:@{@"label":choice,@"description":@""}];}NSData*d=[NSJSONSerialization dataWithJSONObject:@[@"request_user_input_async",q[@"item_id"],@(index++)]options:0 error:NULL];NSString*identifier=[[[NSString alloc]initWithData:d encoding:NSUTF8StringEncoding]autorelease];[rows addObject:@{@"id":identifier,@"question":question[@"title"],@"options":normalized,@"allowFreeText":@YES,@"multiple":@NO,@"allowSkip":@NO}];}out[@"request"]=q;out[@"format"]=@"async";}
  out[@"questions"]=rows;out[@"dto"]=@{@"conversationId":cid,@"messageId":mid,@"challengeId":NSNull.null,@"questions":rows};
 }else return Fail(error,@"invalid_request");
 NSString*encoded=Canonical(@[out[@"request"],raw[@"current_node"],user[@"id"],user[@"content"],model,out[@"recipient"]?:@""]);if(!encoded)return Fail(error,@"invalid_response");out[@"fingerprint"]=OR6CNHash(encoded);return out;
}

NSDictionary *OR6API7FResearchResult(NSDictionary*c,NSDictionary*b,NSString*op,NSError**error){
 if(error)*error=nil;
 if(!OR6CNUUID(op)||!OR6CNUUID(b[@"conversationId"])||!OR6CNUUID(b[@"userMessageId"])||![c[@"id"]isEqual:b[@"conversationId"]]||![c[@"messages"]isKindOfClass:NSArray.class]||[c[@"messages"]count]>2048)return Fail(error,@"invalid_response");
 BOOL found=NO;NSDictionary*report=nil;NSArray*followups=b[@"followups"]?:@[];if(![followups isKindOfClass:NSArray.class]||followups.count>20)return Fail(error,@"invalid_response");NSUInteger followed=0;
 for(id raw in c[@"messages"]){NSDictionary*m=Dict(raw);if(!m)return Fail(error,@"invalid_response");
  if([m[@"role"]isEqual:@"user"]){if(found){NSDictionary*link=followed<followups.count?Dict(followups[followed++]):nil;if(!link||![m[@"id"]isEqual:link[@"userMessageId"]]||![OR6CNHash(m[@"text"])isEqual:link[@"textSHA256"]])return Fail(error,@"conflict");BOOL parent=NO;for(NSDictionary*n in c[@"nodes"])if([n[@"id"]isEqual:m[@"nodeId"]])parent=[n[@"parent"]isEqual:link[@"parentMessageId"]];if(!parent)return Fail(error,@"conflict");report=nil;continue;}
   if(![m[@"id"]isEqual:b[@"userMessageId"]])continue;
   if(b[@"textSHA256"]&&![OR6CNHash(m[@"text"])isEqual:b[@"textSHA256"]])return Fail(error,@"conflict");found=YES;
  }else if(found&&[m[@"role"]isEqual:@"assistant"]&&[m[@"finished"]isEqual:@YES]&&[m[@"endTurn"]isEqual:@YES]){
   for(id part in m[@"parts"]){NSDictionary*p=Dict(part);if([p[@"kind"]isEqual:@"context"]&&[Dict(p[@"data"])[@"researchReport"]isEqual:@YES]){report=m;break;}}
  }
 }
 if(!found)return Fail(error,@"conflict");
 NSDictionary*r=@{@"operationId":op,@"conversationId":b[@"conversationId"],@"userMessageId":b[@"userMessageId"],@"assistantMessageId":report?report[@"id"]:(id)NSNull.null,@"state":report?@"completed":@"background",@"persisted":report?@YES:@NO};
 return OR6API7FResult(r,report?:@{},error);
}
