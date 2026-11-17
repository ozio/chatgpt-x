#import "../localization/OR6Localization.h"
#import "OR6ChatUIState.h"
#import <CoreFoundation/CoreFoundation.h>
#import <CommonCrypto/CommonDigest.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
NSString*OR6ChatUUID(void){CFUUIDRef uuid=CFUUIDCreate(NULL);NSString*s=[(NSString*)CFUUIDCreateString(NULL,uuid)autorelease];CFRelease(uuid);return s;}
static BOOL String(id value){return[value isKindOfClass:NSString.class]&&[value length]>0&&[value length]<=128;}
NSString*OR6ChatDraftSHA256(NSString*text){
 NSData*d=[text?:@"" dataUsingEncoding:NSUTF8StringEncoding];unsigned char h[CC_SHA256_DIGEST_LENGTH];CC_SHA256(d.bytes,(CC_LONG)d.length,h);
 NSMutableString*hex=[NSMutableString stringWithCapacity:64];for(int i=0;i<CC_SHA256_DIGEST_LENGTH;i++)[hex appendFormat:@"%02x",h[i]];return hex;
}
NSString*OR6ChatDeploymentDraftPath(void){
 NSArray*dirs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);return dirs.count?[dirs[0]stringByAppendingPathComponent:@"ChatGPTXDeploymentDraft.json"]:nil;
}
static BOOL OR6ChatUUIDString(id v){
 if(![v isKindOfClass:NSString.class]||[v length]!=36)return NO;
 for(NSUInteger i=0;i<36;i++){unichar c=[v characterAtIndex:i];BOOL dash=i==8||i==13||i==18||i==23;if(dash?c!='-':!((c>='0'&&c<='9')||(c>='a'&&c<='f')||(c>='A'&&c<='F')))return NO;}return YES;
}
NSDictionary*OR6ChatReadDeploymentDraft(NSString*path,NSString**status){
 if(status)*status=@"invalid";if(![path isKindOfClass:NSString.class]||!path.length)return nil;
 // O_NOFOLLOW + fstat on the opened descriptor: a symlink, FIFO or swapped file is never read.
 int fd=open(path.fileSystemRepresentation,O_RDONLY|O_NOFOLLOW|O_NONBLOCK);
 if(fd<0){if(errno==ENOENT&&status)*status=@"absent";return nil;}
 struct stat st;NSMutableData*data=nil;
 if(fstat(fd,&st)==0&&S_ISREG(st.st_mode)&&st.st_nlink==1&&st.st_uid==geteuid()&&!(st.st_mode&077)&&st.st_size>0&&st.st_size<=131072){
  data=[NSMutableData dataWithLength:(NSUInteger)st.st_size+1];ssize_t total=0,n;
  while((n=read(fd,(char*)data.mutableBytes+total,data.length-(NSUInteger)total))>0)total+=n;
  data.length=n<0||total!=st.st_size?0:(NSUInteger)total; // grew, shrank or failed while reading: invalid
 }
 close(fd);if(!data.length)return nil;
 NSDictionary*d=[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
 if(![d isKindOfClass:NSDictionary.class]||![[NSSet setWithArray:d.allKeys]isEqual:[NSSet setWithObjects:@"schema",@"conversationId",@"text",@"textSHA256",nil]])return nil;
 id schema=d[@"schema"],cid=d[@"conversationId"],text=d[@"text"],hash=d[@"textSHA256"];
 if(![schema isKindOfClass:NSNumber.class]||CFGetTypeID((CFTypeRef)schema)==CFBooleanGetTypeID()||![schema isEqual:@1])return nil;
 if(cid!=NSNull.null&&!OR6ChatUUIDString(cid))return nil;
 if(![text isKindOfClass:NSString.class]||![text length]||[text length]>16000)return nil;
 if(![hash isKindOfClass:NSString.class]||[hash length]!=64||![[hash lowercaseString]isEqual:OR6ChatDraftSHA256(text)])return nil;
 if(status)*status=@"valid";
 return @{@"conversationId":cid,@"text":text,@"device":@((long long)st.st_dev),@"inode":@((unsigned long long)st.st_ino)};
}
NSArray*OR6ChatDisplayRows(NSArray*messages){NSMutableArray*rows=[NSMutableArray array];for(NSDictionary*m in messages){NSString*text=m[@"text"];NSUInteger offset=0;do{NSRange range=NSMakeRange(offset,MIN((NSUInteger)4096,text.length-offset));if(range.length)range=[text rangeOfComposedCharacterSequencesForRange:range];[rows addObject:@{@"id":m[@"id"],@"role":m[@"role"],@"text":[text substringWithRange:range],@"continued":@(offset>0)}];offset=NSMaxRange(range);}while(offset<text.length);}return rows;}
NSString*OR6ChatErrorText(NSError*error){
 NSString*code=error.userInfo[@"code"];if(![code isKindOfClass:NSString.class])code=@"";
 if([@[@"not_authenticated",@"login_required",@"session_recovery"]containsObject:code])return OR6L(@"The session is unavailable. Open Session to restore your login.");
 if([@[@"service_challenge",@"rate_limited",@"access_denied"]containsObject:code])return OR6L(@"The service has temporarily restricted access. Do not send again now.");
 if([@[@"capability_unverified",@"not_implemented",@"capability_unavailable"]containsObject:code])return OR6L(@"This connection method is not available yet.");
 if([code isEqual:@"upstream_error"])return OR6L(@"ChatGPT could not finish the response.");
 if([code isEqual:@"timeout"])return OR6L(@"The connection timed out.");
 if([@[@"unknown_wire_shape",@"invalid_response"]containsObject:code])return OR6L(@"The response format is not supported yet.");
 if([@[@"network_unavailable",@"network",@"tls"]containsObject:code])return OR6L(@"The connection was interrupted.");
 if([code isEqual:@"uncertain_outcome"])return OR6L(@"Updates were interrupted. The response may still be running on the server.");
 if([code isEqual:@"stale_context"])return OR6L(@"The session changed. Reopen the conversation.");
 if([code isEqual:@"storage_failure"])return OR6L(@"Could not save state on this iPhone. Check the result before sending again.");
 if([code isEqual:@"cancelled"])return OR6L(@"Updates were interrupted. The response may still be running on the server.");
 if([code isEqual:@"duplicate_operation"])return OR6L(@"This send was already attempted. Check its result first.");
 if([code isEqual:@"invalid_request"])return OR6L(@"Check your message and try again.");
 if([code isEqual:@"auth_cancelled"])return OR6L(@"Login was cancelled. You can try again.");
 if([code isEqual:@"auth_failed"])return OR6L(@"Login did not complete. Try again.");
 if([code isEqual:@"size_limit"])return OR6L(@"This is larger than the allowed size.");
 if([code isEqual:@"expired"])return OR6L(@"The file has expired.");
 if([code isEqual:@"not_found"])return OR6L(@"It is no longer available.");
 return OR6L(@"Could not complete the request. Check your connection and the operation result.");
}
// Sources (citations with a safe http(s) URL), files and images (asset parts)
// and the parts this client cannot show yet. All come from history.get, whose
// normalized parts keep their fields under "data"; text and Send are unaffected.
static NSString*OR6ChatPartString(NSDictionary*d,NSString*key,NSUInteger max){id v=d[key];return[v isKindOfClass:NSString.class]&&[v length]&&[v length]<=max?v:nil;}
static NSDictionary*OR6ChatSourceRow(NSDictionary*d,NSMutableSet*seen){
 NSString*url=OR6ChatPartString(d,@"url",2048);NSURL*u=url?[NSURL URLWithString:url]:nil;NSString*scheme=u.scheme.lowercaseString;
 if(!u.host.length||u.user.length||u.password.length||[url rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location!=NSNotFound||[url rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound||!([scheme isEqual:@"http"]||[scheme isEqual:@"https"])||[seen containsObject:url])return nil;[seen addObject:url];
 NSString*title=OR6ChatPartString(d,@"title",100000)?:u.host;NSMutableDictionary*r=[NSMutableDictionary dictionaryWithDictionary:@{@"title":[title substringToIndex:MIN(title.length,(NSUInteger)300)],@"url":url,@"host":u.host}];
 if(OR6ChatPartString(d,@"id",128))r[@"id"]=d[@"id"];if(OR6ChatPartString(d,@"matched_text",4096))r[@"matched_text"]=d[@"matched_text"];return r;
}
static BOOL OR6ChatFileID(id v){if(![v isKindOfClass:NSString.class]||![v length]||[v length]>128||!([v hasPrefix:@"file-"]||[v hasPrefix:@"file_"]))return NO;NSCharacterSet*bad=[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"]invertedSet];return[v rangeOfCharacterFromSet:bad].location==NSNotFound&&[v length]>5;}
static NSDictionary*OR6ChatMessageExtras(id parts){
 NSMutableArray*reasoning=[NSMutableArray array],*sources=[NSMutableArray array],*unsupported=[NSMutableArray array],*files=[NSMutableArray array],*images=[NSMutableArray array];NSMutableDictionary*context=[NSMutableDictionary dictionary];NSMutableSet*seen=[NSMutableSet set],*imageIDs=[NSMutableSet set],*fileIDs=[NSMutableSet set];
 if([parts isKindOfClass:NSArray.class])for(NSDictionary*p in parts){if(![p isKindOfClass:NSDictionary.class])continue;NSString*kind=p[@"kind"];NSDictionary*d=[p[@"data"]isKindOfClass:NSDictionary.class]?p[@"data"]:p;
  if([kind isEqual:@"context"]){for(NSString*key in @[@"researchReport",@"pendingQuestions",@"pendingAction"])if([d[key]isEqual:@YES])context[key]=@YES;NSString*mid=OR6ChatPartString(d,@"pendingMessageId",128);if(mid)context[@"pendingMessageId"]=mid;}
  else if([kind isEqual:@"reasoning"]){NSString*t=OR6ChatPartString(p,@"text",240);if(t&&reasoning.count<32)[reasoning addObject:t];}
  else if([kind isEqual:@"citation"]){if(sources.count>=64)continue;
   NSMutableDictionary*existing=nil;for(NSMutableDictionary*s in sources)if([s[@"url"]isEqual:d[@"url"]]){existing=s;break;}
   if(existing){NSMutableArray*aliases=[NSMutableArray arrayWithArray:existing[@"aliases"]?:@[]];for(NSString*k in @[@"id",@"matched_text"]){NSString*v=OR6ChatPartString(d,k,4096);if(v&&![aliases containsObject:v]&&aliases.count<128)[aliases addObject:v];}existing[@"aliases"]=aliases;}
   else{NSDictionary*s=OR6ChatSourceRow(d,seen);if(s)[sources addObject:s];}}
  else if([kind isEqual:@"asset"]){
   NSString*pointer=OR6ChatPartString(d,@"asset_pointer",4096),*prefix=[pointer hasPrefix:@"sediment://"]?@"sediment://":[pointer hasPrefix:@"file-service://"]?@"file-service://":nil,*file=prefix?[pointer substringFromIndex:prefix.length]:nil;
   if(pointer&&OR6ChatFileID(file)){if(![imageIDs containsObject:file]&&images.count<16){[imageIDs addObject:file];[images addObject:@{@"fileId":file}];}}
   else if(!pointer&&OR6ChatFileID(d[@"id"])){if(![fileIDs containsObject:d[@"id"]]&&files.count<16){[fileIDs addObject:d[@"id"]];[files addObject:@{@"fileId":d[@"id"],@"name":OR6ChatPartString(d,@"name",240)?:@"",@"mediaType":OR6ChatPartString(d,@"mime_type",128)?:@"application/octet-stream",@"bytes":[d[@"size"]isKindOfClass:NSNumber.class]?d[@"size"]:@0}];}}
   else if(unsupported.count<16)[unsupported addObject:@"image_asset_pointer"];
  }
  else if([kind isEqual:@"unsupported"]){NSString*type=OR6ChatPartString(p,@"type",100000)?:OR6ChatPartString(d,@"type",100000)?:@"unknown";if(unsupported.count<16)[unsupported addObject:[type substringToIndex:MIN(type.length,(NSUInteger)64)]];}
 }
 NSMutableArray*plain=[NSMutableArray array];for(NSDictionary*f in files)if(![imageIDs containsObject:f[@"fileId"]])[plain addObject:f]; // an image's attachment entry is the same file
 NSMutableDictionary*out=[NSMutableDictionary dictionaryWithDictionary:context];if(reasoning.count)out[@"reasoningSteps"]=reasoning;if(sources.count)out[@"sources"]=sources;if(unsupported.count)out[@"unsupported"]=unsupported;if(plain.count)out[@"files"]=plain;if(images.count)out[@"images"]=images;return out;
}
// search.web Source DTOs → the same safe rows as history citations.
static NSArray*OR6ChatSourceRows(id dtos){NSMutableArray*out=[NSMutableArray array];NSMutableSet*seen=[NSMutableSet set];if([dtos isKindOfClass:NSArray.class])for(NSDictionary*d in dtos){if(![d isKindOfClass:NSDictionary.class]||out.count>=100)continue;NSDictionary*s=OR6ChatSourceRow(d,seen);if(s)[out addObject:s];}return out;}
@implementation OR6ChatHistoryState
@synthesize nextToken=_nextToken,loaded=_loaded;
- (id)init{if((self=[super init])){_items=[NSMutableArray new];_tokens=[NSMutableSet new];}return self;}
- (NSArray*)items{return[[_items copy]autorelease];}
- (BOOL)updateTitle:(NSString*)title conversation:(NSString*)identifier{
 if(![title isKindOfClass:NSString.class]||title.length>2000||!String(identifier))return NO;
 for(NSUInteger n=0;n<_items.count;n++)if([_items[n][@"id"]isEqual:identifier]){NSMutableDictionary*r=[[_items[n]mutableCopy]autorelease];r[@"title"]=title;_items[n]=r;return YES;}return NO;
}
- (void)reset{[_items removeAllObjects];[_tokens removeAllObjects];[_nextToken release];_nextToken=nil;_loaded=NO;}
- (BOOL)acceptPage:(NSDictionary*)page token:(NSString*)token{
 if(![page isKindOfClass:NSDictionary.class]||![page[@"items"]isKindOfClass:NSArray.class]||(token&&![_nextToken isEqual:token])||(!token&&_loaded))return NO;
 id next=page[@"nextToken"];if(next!=NSNull.null&&!String(next))return NO;if(next!=NSNull.null&&([next isEqual:token]||[_tokens containsObject:next]))return NO;
 NSMutableArray*merged=[NSMutableArray arrayWithArray:_items];NSMutableSet*pageIDs=[NSMutableSet set];
 for(id row in page[@"items"]){if(![row isKindOfClass:NSDictionary.class]||!String(row[@"id"])||![row[@"title"]isKindOfClass:NSString.class]||[pageIDs containsObject:row[@"id"]])return NO;[pageIDs addObject:row[@"id"]];NSUInteger existing=NSNotFound;for(NSUInteger n=0;n<merged.count;n++)if([merged[n][@"id"]isEqual:row[@"id"]]){existing=n;break;}if(existing==NSNotFound)[merged addObject:row];else merged[existing]=row;}
 if(merged.count>1000||(next!=NSNull.null&&![page[@"items"]count]))return NO;
 [_items setArray:merged];if(token)[_tokens addObject:token];if(next!=NSNull.null)[_tokens addObject:next];[_nextToken release];_nextToken=next==NSNull.null?nil:[next copy];_loaded=YES;return YES;
}
- (void)dealloc{[_items release];[_tokens release];[_nextToken release];[super dealloc];}
@end
@implementation OR6ChatConversationState
@synthesize conversationTitle=_conversationTitle,conversationId=_conversationId,operationId=_operationId,phase=_phase,sending=_sending,uncertain=_uncertain,loaded=_loaded,text=_text;
@synthesize optionsLocked=_optionsLocked,temporary=_temporary,modelId=_modelId,attachments=_attachments,sentAttachments=_sentAttachments,draftId=_draftId,kind=_kind,generationPhase=_generationPhase,rejectedRequest=_rejected;
- (id)initWithConversationId:(NSString*)identifier{if((self=[super init])){_messages=[NSMutableArray new];_conversationId=[identifier copy];_parentId=[OR6ChatUUID()copy];_draftId=[OR6ChatUUID()copy];_text=[@""copy];_phase=[(identifier?@"loading":@"ready")copy];_loaded=!identifier;_modelId=[@"web-current"copy];_kind=[@"send"copy];_attachments=[@[]copy];}return self;}
- (NSArray*)messages{return[[_messages copy]autorelease];}
- (void)setPhase:(NSString*)phase{[_phase release];_phase=[phase copy];}
- (void)setKind:(NSString*)kind{[_kind release];_kind=[kind copy];}
- (void)setGeneration:(NSString*)phase{[_generationPhase release];_generationPhase=[phase copy];}
// Setters copy before they release: callers may pass the state's own getters.
- (void)setModelId:(NSString*)modelId{if(_optionsLocked)return;if(!String(modelId))modelId=@"web-current";NSString*m=[modelId copy];if(![m isEqual:_modelId]){[_effort release];_effort=nil;}[_modelId release];_modelId=m;}
- (NSString*)thinkingEffort{return _effort;}
- (void)setModelId:(NSString*)modelId thinkingEffort:(NSString*)effort{if(_optionsLocked)return;NSString*e=String(effort)&&effort.length<=64?[effort copy]:nil;self.modelId=modelId;if([_modelId isEqual:@"web-current"]){[e release];e=nil;}[_effort release];_effort=e;}
// The chosen effort travels with the model in every generation request (and so in the journal); none: omitted.
- (NSDictionary*)withEffort:(NSDictionary*)p{if(!_effort)return p;NSMutableDictionary*m=[[p mutableCopy]autorelease];m[@"thinkingEffort"]=_effort;return m;}
- (void)setAttachments:(NSArray*)a{if(_optionsLocked)return;[_attachments release];_attachments=[([a isKindOfClass:NSArray.class]?a:@[])copy];}
- (BOOL)setTemporary:(BOOL)temporary{
 if(temporary==_temporary)return YES;if(_optionsLocked||_conversationId||_messages.count||_sending||_uncertain||_attachments.count)return NO;
 _temporary=temporary;[_draftId release];_draftId=[OR6ChatUUID()copy];return YES; // a draft carries its temporary flag: start a new one
}
- (NSDictionary*)draftRequest{return[self withEffort:@{@"draftId":_draftId,@"parentMessageId":_parentId,@"modelId":_modelId,@"temporary":_temporary?@YES:@NO}];} // schema booleans as CFBoolean on every ABI
- (BOOL)remoteGenerationActive{return self.awaitingRemoteResponse&&![_messages.lastObject[@"waiting"]boolValue];}
- (BOOL)awaitingRemoteResponse{return !_sending&&[_messages.lastObject[@"pending"]boolValue];}
- (BOOL)acceptConversation:(NSDictionary*)conversation{
 if(_sending||_uncertain||!String(conversation[@"id"])||![_conversationId isEqual:conversation[@"id"]]||![conversation[@"messages"]isKindOfClass:NSArray.class]||!String(conversation[@"currentNode"])||[conversation[@"messages"]count]>2048)return NO;
 NSMutableArray*rows=[NSMutableArray array];for(NSDictionary*m in conversation[@"messages"]){if(![m isKindOfClass:NSDictionary.class]||!String(m[@"id"])||![m[@"text"]isKindOfClass:NSString.class]||![@[@"user",@"assistant"]containsObject:m[@"role"]])return NO;NSMutableDictionary*row=[NSMutableDictionary dictionaryWithDictionary:@{@"id":m[@"id"],@"role":m[@"role"],@"text":m[@"text"]}];[row addEntriesFromDictionary:OR6ChatMessageExtras(m[@"parts"])];if(![row[@"pendingQuestions"]boolValue]&&![row[@"pendingAction"]boolValue]&&[m[@"role"]isEqual:@"assistant"]&&[m[@"status"]isEqual:@"in_progress"]&&![m[@"endTurn"]isEqual:@YES])row[@"pending"]=@YES;if([m[@"type"]isEqual:@"awaiting_response"]&&![row[@"pendingQuestions"]boolValue]&&![row[@"pendingAction"]boolValue]){row[@"pending"]=@YES;row[@"waiting"]=@YES;}[rows addObject:row];}
 [_messages setArray:rows];[_parentId release];_parentId=[conversation[@"currentNode"]copy];_loaded=YES;[self setPhase:@"ready"];return YES;
}
- (void)begin:(NSString*)kind text:(NSString*)submitted{
 [_operationId release];_operationId=[OR6ChatUUID()copy];[_submittedText release];_submittedText=[submitted copy];_sequence=0;_sending=YES;[self setPhase:@"dispatching"];[self setKind:kind];[self setGeneration:nil];[_rejected release];_rejected=nil;
}
- (NSDictionary*)beginSend{
 if(!_loaded||_sending||_uncertain||self.remoteGenerationActive||![_text isKindOfClass:NSString.class]||![_text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length||_text.length>16000)return nil;
 [self begin:@"send"text:_text];[_restore release];_restore=nil;
 NSMutableDictionary*user=[NSMutableDictionary dictionaryWithDictionary:@{@"id":[@"local-user-"stringByAppendingString:_operationId],@"role":@"user",@"text":_submittedText}];if(_sentAttachments.count)user[@"attachments"]=_sentAttachments;
 [_messages addObject:user];
 [_messages addObject:@{@"id":[@"local-assistant-"stringByAppendingString:_operationId],@"role":@"assistant",@"text":@""}];
 NSMutableDictionary*p=[NSMutableDictionary dictionaryWithDictionary:@{@"operationId":_operationId,@"draftId":_draftId,@"text":_submittedText,@"modelId":_modelId,@"parentMessageId":_parentId,@"temporary":_temporary?@YES:@NO,@"attachments":_attachments?:@[]}];if(_conversationId)p[@"conversationId"]=_conversationId;if(_effort)p[@"thinkingEffort"]=_effort;return p;
}
- (NSUInteger)indexOfMessage:(NSString*)identifier role:(NSString*)role{
 if(!String(identifier)||[identifier hasPrefix:@"local-"])return NSNotFound;
 for(NSUInteger i=0;i<_messages.count;i++){NSDictionary*m=_messages[i];if([m[@"id"]isEqual:identifier])return[m[@"role"]isEqual:role]?i:NSNotFound;}return NSNotFound;
}
- (BOOL)editable{return !_temporary&&String(_conversationId)&&_loaded&&!_sending&&!_uncertain&&!self.remoteGenerationActive;}
- (BOOL)branchEditable{return[self editable];}
- (BOOL)canEditMessage:(NSString*)identifier{return[self editable]&&[self indexOfMessage:identifier role:@"user"]!=NSNotFound;}
- (BOOL)canRegenerate:(NSString*)identifier{
 NSUInteger i=[self editable]?[self indexOfMessage:identifier role:@"assistant"]:NSNotFound;if(i==NSNotFound)return NO;
 for(NSUInteger k=0;k<i;k++)if([_messages[k][@"role"]isEqual:@"user"])return YES;return NO; // the variant's parent is the nearest user message
}
- (NSDictionary*)beginEditMessage:(NSString*)identifier text:(NSString*)text{
 NSUInteger i=[self canEditMessage:identifier]?[self indexOfMessage:identifier role:@"user"]:NSNotFound;
 if(i==NSNotFound||![text isKindOfClass:NSString.class]||![text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length||text.length>16000)return nil;
 NSDictionary*original=[[_messages[i]retain]autorelease];[_restore release];_restore=[_messages copy];[self begin:@"edit"text:nil];
 [_messages removeObjectsInRange:NSMakeRange(i,_messages.count-i)];
 // The service keeps the original's file references; the bubble keeps showing them.
 NSMutableDictionary*user=[NSMutableDictionary dictionaryWithDictionary:@{@"id":[@"local-user-"stringByAppendingString:_operationId],@"role":@"user",@"text":text,@"target":identifier}];for(NSString*k in @[@"files",@"images",@"attachments"])if(original[k])user[k]=original[k];
 [_messages addObject:user];[_messages addObject:@{@"id":[@"local-assistant-"stringByAppendingString:_operationId],@"role":@"assistant",@"text":@""}];
 return[self withEffort:@{@"operationId":_operationId,@"conversationId":_conversationId,@"messageId":identifier,@"text":text,@"modelId":_modelId}];
}
- (NSDictionary*)beginRegenerate:(NSString*)identifier{
 NSUInteger i=[self canRegenerate:identifier]?[self indexOfMessage:identifier role:@"assistant"]:NSNotFound;if(i==NSNotFound)return nil;
 [_restore release];_restore=[_messages copy];[self begin:@"regenerate"text:nil];
 [_messages removeObjectsInRange:NSMakeRange(i,_messages.count-i)];[_messages addObject:@{@"id":[@"local-assistant-"stringByAppendingString:_operationId],@"role":@"assistant",@"text":@"",@"target":identifier}];
 return[self withEffort:@{@"operationId":_operationId,@"conversationId":_conversationId,@"assistantMessageId":identifier,@"modelId":_modelId}];
}
- (NSDictionary*)beginRepeatRejected{
 NSDictionary*r=[[_rejected retain]autorelease];if(!r||_sending||_uncertain)return nil;
 if([r[@"operation"]isEqual:@"messages.edit"])return[self beginEditMessage:r[@"messageId"]text:r[@"text"]];
 if([r[@"operation"]isEqual:@"messages.regenerate"])return[self beginRegenerate:r[@"messageId"]];return nil;
}
- (NSDictionary*)beginWebSearch{
 if(!_loaded||_sending||_uncertain||self.remoteGenerationActive||_temporary||![_text isKindOfClass:NSString.class]||![_text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length||_text.length>16000)return nil;
 [self begin:@"search"text:_text];[_restore release];_restore=nil;
 [_messages addObject:@{@"id":[@"local-user-"stringByAppendingString:_operationId],@"role":@"user",@"text":_submittedText}];
 [_messages addObject:@{@"id":[@"local-assistant-"stringByAppendingString:_operationId],@"role":@"assistant",@"text":@""}];
 // Standalone: the search.web result carries no conversation/message IDs, so it must
 // not be generated inside this chat (that would move the service's branch away from
 // _parentId). The service runs it as its own conversation; this chat stays unchanged.
 // The chat's chosen model and effort apply to its search mode too; Default omits both (old DTO).
 NSMutableDictionary*p=[NSMutableDictionary dictionaryWithDictionary:@{@"operationId":_operationId,@"query":_submittedText,@"conversationId":NSNull.null}];
 if(![_modelId isEqual:@"web-current"])p[@"modelId"]=_modelId;return[self withEffort:p];
}
- (void)finishWebSearch:(NSDictionary*)r error:(NSError*)error{
 if(!_operationId||![_kind isEqual:@"search"]||_messages.count<2)return;_sending=NO;
 if(!error&&[r[@"operationId"]isEqual:_operationId]&&[r[@"text"]isKindOfClass:NSString.class]){
  NSMutableDictionary*m=[NSMutableDictionary dictionaryWithDictionary:_messages.lastObject];m[@"text"]=r[@"text"];m[@"search"]=@YES;NSArray*sources=OR6ChatSourceRows(r[@"sources"]);if(sources.count)m[@"sources"]=sources;
  m[@"detached"]=@YES;_messages[_messages.count-1]=m; // a separate tool result: not part of this conversation
  if([_text isEqual:_submittedText])self.text=@"";[self setPhase:@"completed"];
 }else if(error&&[error.userInfo[@"dispatch"]isEqual:@"none"]){[_messages removeObjectsInRange:NSMakeRange(_messages.count-2,2)];[self setPhase:@"rejected"];}
 else{NSMutableDictionary*m=[NSMutableDictionary dictionaryWithDictionary:_messages.lastObject];m[@"search"]=@YES;m[@"interrupted"]=@YES;m[@"detached"]=@YES;_messages[_messages.count-1]=m;[self setPhase:@"completed"];} // unknown outcome: shown, never repeated automatically
 [_operationId release];_operationId=nil;[_submittedText release];_submittedText=nil;
}
- (BOOL)receiveEvent:(NSDictionary*)event{
 if(!_sending)return NO;NSDictionary*p=event[@"payload"];if(![p isKindOfClass:NSDictionary.class]||![p[@"operationId"]isEqual:_operationId])return NO;
 NSString*name=event[@"name"];
 if([name isEqual:@"message"]){NSUInteger sequence=[p[@"sequence"]unsignedIntegerValue];if(sequence<=_sequence||![p[@"text"]isKindOfClass:NSString.class]||[p[@"text"]length]>262144)return NO;if(String(p[@"conversationId"])){if(_conversationId&&![_conversationId isEqual:p[@"conversationId"]])return NO;[_conversationId release];_conversationId=[p[@"conversationId"]copy];}_sequence=sequence;NSMutableDictionary*m=[NSMutableDictionary dictionaryWithDictionary:_messages.lastObject];m[@"text"]=p[@"text"];if([p[@"parts"]isKindOfClass:NSArray.class]){for(NSString*k in @[@"sources",@"files",@"images",@"unsupported",@"researchReport",@"pendingQuestions",@"pendingAction",@"pendingMessageId"])[m removeObjectForKey:k];[m addEntriesFromDictionary:OR6ChatMessageExtras(p[@"parts"])];}if([p[@"conversationTitle"]isKindOfClass:NSString.class]){[_conversationTitle release];_conversationTitle=[p[@"conversationTitle"]copy];}if(String(p[@"messageId"]))m[@"id"]=p[@"messageId"];_messages[_messages.count-1]=m;[self setPhase:@"streaming"];return YES;}
 if([name isEqual:@"state"]){if(String(p[@"conversationId"])){if(_conversationId&&![_conversationId isEqual:p[@"conversationId"]])return NO;[_conversationId release];_conversationId=[p[@"conversationId"]copy];}if([@[@"dispatching",@"streaming",@"reconciling"]containsObject:p[@"state"]])[self setPhase:p[@"state"]];return YES;}
 if([name isEqual:@"status"]){
  // GenerationStatus: queued/preparing happen before dispatch; terminal phases come with the receipt.
  NSString*phase=[p[@"phase"]isKindOfClass:NSString.class]?p[@"phase"]:nil;if(phase.length&&phase.length<=32)[self setGeneration:phase];
  NSString*label=p[@"label"];if([label isKindOfClass:NSString.class]&&label.length&&label.length<=240&&[phase isEqual:@"thinking"]){NSMutableDictionary*m=[[_messages.lastObject mutableCopy]autorelease];NSMutableArray*steps=[NSMutableArray arrayWithArray:m[@"reasoningSteps"]?:@[]];if(![steps.lastObject isEqual:label]){if(steps.count>=32)[steps removeObjectAtIndex:0];[steps addObject:label];}m[@"reasoningSteps"]=steps;_messages[_messages.count-1]=m;}

  if(![@[@"queued",@"preparing",@"complete",@"failed",@"interrupted",@"unknown"]containsObject:phase?:@""])[self setPhase:@"streaming"];return YES;}
 return NO;
}
- (void)finishReceipt:(NSDictionary*)receipt error:(NSError*)error{
 if(!_operationId)return;
 _sending=NO;BOOL ephemeral=_temporary&&[receipt[@"persisted"]isEqual:@NO]; // a completed temporary exchange is delivered, deliberately not saved
 BOOL complete=!error&&[receipt[@"operationId"]isEqual:_operationId]&&[receipt[@"state"]isEqual:@"completed"]&&([receipt[@"persisted"]boolValue]||ephemeral)&&String(receipt[@"conversationId"])&&String(receipt[@"userMessageId"])&&String(receipt[@"assistantMessageId"]);
 if(complete&&_conversationId&&![_conversationId isEqual:receipt[@"conversationId"]])complete=NO;
 if(complete){
  [_conversationId release];_conversationId=[receipt[@"conversationId"]copy];[_parentId release];_parentId=[receipt[@"assistantMessageId"]copy];
  // The local rows get their real IDs, so Edit/New answer work without a reload.
  NSUInteger n=_messages.count;if(n&&[_messages[n-1][@"role"]isEqual:@"assistant"]){NSMutableDictionary*m=[NSMutableDictionary dictionaryWithDictionary:_messages[n-1]];m[@"id"]=receipt[@"assistantMessageId"];[m removeObjectForKey:@"target"];_messages[n-1]=m;}
  if(n>1&&[_messages[n-2][@"role"]isEqual:@"user"]&&[_messages[n-2][@"id"]hasPrefix:@"local-"]){NSMutableDictionary*m=[NSMutableDictionary dictionaryWithDictionary:_messages[n-2]];m[@"id"]=receipt[@"userMessageId"];[m removeObjectForKey:@"target"];_messages[n-2]=m;}
  // The reserved draft was consumed (also by a Retry): the lock ends; a newer typed text stays.
  if([_kind isEqual:@"send"]){_optionsLocked=NO;[_draftId release];_draftId=[OR6ChatUUID()copy];if([_text isEqual:_submittedText])self.text=@"";self.attachments=@[];self.sentAttachments=nil;}
  _uncertain=NO;[self setPhase:@"completed"];[_operationId release];_operationId=nil;[_submittedText release];_submittedText=nil;[_restore release];_restore=nil;return;
 }
 BOOL noDispatch=!_uncertain&&_sequence==0&&error&&[error.userInfo[@"dispatch"]isEqual:@"none"];
 if(noDispatch){
  if([_kind isEqual:@"send"]){if(_messages.count>=2)[_messages removeObjectsInRange:NSMakeRange(_messages.count-2,2)];}
  else{
   // Edit/regenerate: the original branch comes back; an explicit repeat is a new operation.
   NSDictionary*user=_messages.count>=2?_messages[_messages.count-2]:nil;NSString*target=_messages.lastObject[@"target"];
   // A service stop signal (challenge, rate limit, login) is never offered as a repeat.
   NSString*code=error.userInfo[@"code"];BOOL stop=[@[@"service_challenge",@"rate_limited",@"access_denied",@"not_authenticated",@"login_required",@"auth_failed",@"session_recovery",@"stale_context"]containsObject:code?:@""];
   [_rejected release];_rejected=stop?nil:[[_kind isEqual:@"edit"]?@{@"operation":@"messages.edit",@"messageId":user[@"target"]?:@"",@"text":user[@"text"]?:@""}:@{@"operation":@"messages.regenerate",@"messageId":target?:@""}retain];
   if(_restore)[_messages setArray:_restore];
  }
  _uncertain=NO;[self setPhase:@"rejected"];[_operationId release];_operationId=nil;[_submittedText release];_submittedText=nil;[_restore release];_restore=nil;
 }
 else{_uncertain=YES;[self setPhase:@"uncertain"];}
}
- (NSDictionary*)reconcileRequest{return _uncertain&&_operationId?@{@"operationId":_operationId}:nil;}
- (BOOL)restoreRecoverySnapshot:(NSDictionary*)s{
 NSDictionary*p=s[@"request"];id cid=s[@"conversationId"];BOOL completed=[s[@"completed"]boolValue];
 if(_messages.count||_sending||_text.length||![s[@"schema"]isEqual:@1]||![p isKindOfClass:NSDictionary.class]||!String(s[@"operationId"])||![p[@"operationId"]isEqual:s[@"operationId"]]||![p[@"text"]isKindOfClass:NSString.class]||![p[@"text"]length]||[p[@"text"]length]>16000||![s[@"text"]isKindOfClass:NSString.class]||[s[@"text"]length]>262144||!String(s[@"userMessageId"])||!String(p[@"parentMessageId"])||!String(p[@"draftId"])||(cid!=NSNull.null&&!String(cid))||(_conversationId&&![_conversationId isEqual:cid])||(completed&&(!String(cid)||!String(s[@"assistantMessageId"]))))return NO;
 [_conversationId release];_conversationId=cid==NSNull.null?nil:[cid copy];[_parentId release];_parentId=[(completed?s[@"assistantMessageId"]:p[@"parentMessageId"])copy];[_draftId release];_draftId=[p[@"draftId"]copy];
 _temporary=[p[@"temporary"]isEqual:@YES];if(String(p[@"modelId"]))[self setModelId:p[@"modelId"]thinkingEffort:p[@"thinkingEffort"]];[self setKind:@"send"];
 [_messages addObject:@{@"id":s[@"userMessageId"],@"role":@"user",@"text":p[@"text"]}];[_messages addObject:@{@"id":String(s[@"assistantMessageId"])?s[@"assistantMessageId"]:[@"local-assistant-"stringByAppendingString:s[@"operationId"]],@"role":@"assistant",@"text":s[@"text"]}];
 _loaded=YES;_uncertain=!completed;_sequence=0;if(!completed){_operationId=[s[@"operationId"]copy];_submittedText=[p[@"text"]copy];}[self setPhase:completed?@"completed":@"uncertain"];return YES;
}
- (NSDictionary*)beginRecovery{
 if(_sending||!_uncertain||!_operationId)return nil;_sending=YES;_sequence=0;[self setPhase:@"reconciling"];return @{@"operationId":_operationId};
}
- (NSString*)importDeploymentDraftAtPath:(NSString*)path{
 NSString*status=nil;NSDictionary*d=OR6ChatReadDeploymentDraft(path,&status);if(!d)return status;
 id cid=d[@"conversationId"];BOOL match=cid==NSNull.null?_conversationId==nil:(_conversationId&&[_conversationId caseInsensitiveCompare:cid]==NSOrderedSame);
 if(!match)return @"other-conversation";
 if(!_loaded||_sending||_uncertain||self.remoteGenerationActive||_optionsLocked)return @"not-idle";
 if(_text.length)return @"draft-not-empty"; // the user's own text always wins
 self.text=d[@"text"];
 // Remove exactly the file that was read (same device/inode), only now that the text is restored.
 struct stat st;BOOL same=lstat(path.fileSystemRepresentation,&st)==0&&(long long)st.st_dev==[d[@"device"]longLongValue]&&(unsigned long long)st.st_ino==[d[@"inode"]unsignedLongLongValue];
 return same&&unlink(path.fileSystemRepresentation)==0?@"imported":@"imported-file-kept";
}
- (NSDictionary*)diagnostics{return @{@"draftSHA256":_text.length?OR6ChatDraftSHA256(_text):@"",@"phase":_phase,@"messageCount":@(_messages.count),@"sending":@(_sending),@"uncertain":@(_uncertain),@"loaded":@(_loaded),@"hasConversation":@(_conversationId!=nil),@"draftLength":@(_text.length),@"streamSequence":@(_sequence),@"temporary":@(_temporary),@"kind":_kind,@"generationPhase":_generationPhase?:@"",@"attachments":@(_attachments.count),@"customModel":@(![_modelId isEqual:@"web-current"]),@"customEffort":@(_effort!=nil),@"repeatAvailable":@(_rejected!=nil),@"optionsLocked":@(_optionsLocked)};}
- (void)dealloc{[_messages release];[_conversationId release];[_conversationTitle release];[_parentId release];[_draftId release];[_text release];[_operationId release];[_submittedText release];[_phase release];[_modelId release];[_effort release];[_kind release];[_generationPhase release];[_attachments release];[_sentAttachments release];[_restore release];[_rejected release];[super dealloc];}
@end
