// Acceptance-only UI7 physical fixture backend. See Backend.h. Foundation only.
#import "Backend.h"
#import "../../ios/api/OR6APIWire.h"
#import <CommonCrypto/CommonDigest.h>
#include <zlib.h>

NSString *const UI7FConversationID=@"77777777-7777-4777-8777-777777777777",*const UI7FAssistantID=@"77777777-7777-4777-8777-777777777772",*const UI7FImageFile=@"file_ui7fixtureimage",*const UI7FAudioFile=@"file_ui7fixtureaudio";
static NSString*const UserID=@"77777777-7777-4777-8777-777777777771",*const RootID=@"77777777-7777-4777-8777-777777777770";
NSString*UI7FSHA256(NSData*d){unsigned char h[CC_SHA256_DIGEST_LENGTH];CC_SHA256(d.bytes,(CC_LONG)d.length,h);NSMutableString*s=[NSMutableString string];for(int i=0;i<CC_SHA256_DIGEST_LENGTH;i++)[s appendFormat:@"%02x",h[i]];return s;}
NSString*UI7FTextSHA256(NSString*t){return[t isKindOfClass:NSString.class]?UI7FSHA256([t dataUsingEncoding:NSUTF8StringEncoding]):@"";}
NSString*UI7FExpectedCode(void){return @"int fixture = 7;\nreturn fixture;";}
static void Big32(NSMutableData*d,uint32_t v){uint8_t b[4]={(uint8_t)(v>>24),(uint8_t)(v>>16),(uint8_t)(v>>8),(uint8_t)v};[d appendBytes:b length:4];}
static void Little(NSMutableData*d,uint32_t v,int n){for(int i=0;i<n;i++){uint8_t b=(uint8_t)(v>>(8*i));[d appendBytes:&b length:1];}}
static void Chunk(NSMutableData*png,const char*type,NSData*body){NSMutableData*c=[NSMutableData dataWithBytes:type length:4];[c appendData:body];Big32(png,(uint32_t)body.length);[png appendData:c];Big32(png,(uint32_t)crc32(0,c.bytes,(uInt)c.length));}
NSData*UI7FImagePNG(void){
 // No zlib compressor: a single stored deflate block keeps the bytes identical across zlib versions.
 NSMutableData*raw=[NSMutableData data];for(int y=0;y<64;y++){uint8_t f=0;[raw appendBytes:&f length:1];for(int x=0;x<64;x++){uint8_t p[3]={(uint8_t)(20+x*2),(uint8_t)(140+y),(uint8_t)(100+((x^y)&63))};[raw appendBytes:p length:3];}}
 NSMutableData*z=[NSMutableData data],*ihdr=[NSMutableData data],*png=[NSMutableData dataWithBytes:"\x89PNG\r\n\x1a\n" length:8];uint8_t head[3]={0x78,0x01,0x01};[z appendBytes:head length:3];Little(z,(uint32_t)raw.length,2);Little(z,(uint32_t)(~raw.length&0xffff),2);[z appendData:raw];Big32(z,(uint32_t)adler32(1,raw.bytes,(uInt)raw.length));
 Big32(ihdr,64);Big32(ihdr,64);uint8_t mode[5]={8,2,0,0,0};[ihdr appendBytes:mode length:5];Chunk(png,"IHDR",ihdr);Chunk(png,"IDAT",z);Chunk(png,"IEND",[NSData data]);return png;
}
NSData*UI7FAudioWAV(void){
 // 30 s: room for paced pause/resume checks over the actor.
 const uint32_t samples=240000;NSMutableData*w=[NSMutableData dataWithBytes:"RIFF" length:4];Little(w,36+samples*2,4);[w appendBytes:"WAVEfmt " length:8];Little(w,16,4);Little(w,1,2);Little(w,1,2);Little(w,8000,4);Little(w,16000,4);Little(w,2,2);Little(w,16,2);[w appendBytes:"data" length:4];Little(w,samples*2,4);
 for(uint32_t i=0;i<samples;i++){int k=(int)(i%32),v=(k<16?k:32-k)*200-1600;Little(w,(uint32_t)(uint16_t)(int16_t)v,2);}return w;
}
static NSData*JSON(id v){return[NSJSONSerialization dataWithJSONObject:v options:0 error:NULL];}
static NSDictionary*Conversation(void){
 NSString*md=[NSString stringWithFormat:@"UI7 local fixture answer (synthetic, not from the service).\n\n```c\n%@\n```\n\nThe PNG image and the WAV file below are fixture files.",UI7FExpectedCode()];
 NSDictionary*user=@{@"id":UserID,@"author":@{@"role":@"user"},@"content":@{@"content_type":@"text",@"parts":@[@"UI7 fixture: code, image and audio"]},@"status":@"finished_successfully",@"metadata":@{}};
 NSDictionary*answer=@{@"id":UI7FAssistantID,@"author":@{@"role":@"assistant"},@"content":@{@"content_type":@"multimodal_text",@"parts":@[@{@"content_type":@"image_asset_pointer",@"asset_pointer":[@"sediment://"stringByAppendingString:UI7FImageFile],@"width":@64,@"height":@64},md]},@"status":@"finished_successfully",@"end_turn":@YES,
  @"metadata":@{@"attachments":@[@{@"id":UI7FAudioFile,@"name":@"ui7-fixture.wav",@"mime_type":@"audio/wav",@"size":@(UI7FAudioWAV().length)}]}};
 return OR6APIWireConversation(JSON(@{@"conversation_id":UI7FConversationID,@"title":@"UI7 fixture",@"current_node":UI7FAssistantID,@"mapping":@{RootID:@{@"id":RootID,@"parent":NSNull.null,@"children":@[UserID],@"message":NSNull.null},UserID:@{@"id":UserID,@"parent":RootID,@"children":@[UI7FAssistantID],@"message":user},UI7FAssistantID:@{@"id":UI7FAssistantID,@"parent":UserID,@"children":@[],@"message":answer}}}),UI7FConversationID,NULL);
}

@interface UI7FTask:NSObject<OR6APITask,OR6WebTask>{@public void(^onCancel)(void);}
@end
@implementation UI7FTask
- (void)cancel{void(^b)(void)=[[onCancel copy]autorelease];[onCancel release];onCancel=nil;if(b)b();}
- (void)dealloc{[onCancel release];[super dealloc];}
@end

@implementation UI7FBackend
- (id)init{if((self=[super init])){counts=[NSMutableDictionary new];refused=[NSMutableArray new];held=[NSMutableArray new];translation=[@"synthetic"copy];}return self;}
- (void)count:(NSString*)k{counts[k]=@([counts[k]unsignedIntegerValue]+1);}
- (UI7FTask*)refuse:(NSString*)kind what:(NSString*)what reply:(void(^)(NSDictionary*,NSError*))reply{
 [self count:[kind stringByAppendingString:@".refused"]];if(refused.count<64)[refused addObject:[NSString stringWithFormat:@"%@ %@",kind,what?:@""]];if(reply)reply(nil,OR6APIError(@"capability_unavailable",@"none"));return[[[UI7FTask alloc]init]autorelease];
}
// A held reply completes only by cancellation (its owner's task), never by itself.
- (UI7FTask*)hold:(OR6APIReply)reply kind:(NSString*)kind{
 [self count:[kind stringByAppendingString:@".held"]];OR6APIReply copy=[[reply copy]autorelease];[held addObject:copy];UI7FTask*t=[[[UI7FTask alloc]init]autorelease];
 t->onCancel=[^{if(![held containsObject:copy])return;[[copy retain]autorelease];[held removeObject:copy];[self count:[kind stringByAppendingString:@".cancelled"]];copy(nil,OR6APIError(@"cancelled",@"possible"));}copy];return t;
}
#pragma mark Bottom provider (below Local): fixture reads only
- (id<OR6APITask>)execute:(NSString*)op parameters:(NSDictionary*)p context:(NSDictionary*)ctx event:(OR6APIEvent)event completion:(OR6APIReply)reply{
 (void)ctx;(void)event;
 if([op isEqual:@"history.get"]&&[p[@"conversationId"]isEqual:UI7FConversationID]){[self count:@"bottom.history.get"];reply(Conversation(),nil);}
 else if([op isEqual:@"history.list"]){[self count:@"bottom.history.list"];reply(@{@"items":@[@{@"id":UI7FConversationID,@"title":@"UI7 fixture",@"updatedAt":@0}],@"nextToken":NSNull.null},nil);}
 else if([op isEqual:@"models.list"]){[self count:@"bottom.models.list"];reply(@{@"items":@[@{@"id":@"auto",@"title":@"Auto",@"capabilities":@[]}],@"selectedModelId":@"auto"},nil);}
 else return[self refuse:@"bottom" what:op reply:reply];
 return[[[UI7FTask alloc]init]autorelease];
}
// API8 generation boundary: only translation, and only as an explicitly synthetic local result.
- (id<OR6APITask>)executeNativePlan:(NSDictionary*)plan context:(NSDictionary*)ctx event:(OR6APIEvent)event completion:(OR6APIReply)reply{
 (void)ctx;(void)event;NSString*op=plan[@"parameters"][@"operationId"];
 if(![plan[@"operation"]isEqual:@"translation.translate"]||![op isKindOfClass:NSString.class])return[self refuse:@"generation" what:plan[@"operation"] reply:reply];
 if([translation isEqual:@"refused"])return[self refuse:@"translation" what:@"refused-mode" reply:reply];
 if([translation isEqual:@"pending"])return[self hold:reply kind:@"translation"];
 [self count:@"translation.synthetic"];
 NSDictionary*receipt=@{@"operationId":op,@"state":@"completed",@"conversationId":UI7FConversationID,@"userMessageId":plan[@"userMessageId"]?:UserID,@"assistantMessageId":UI7FAssistantID,@"persisted":@NO};
 reply(@{@"receipt":receipt,@"streamComplete":@YES,@"assistant":@{@"text":@"UI7 fixture translation (synthetic local text, not a service result)",@"parts":@[]}},nil);return[[[UI7FTask alloc]init]autorelease];
}
#pragma mark API8 file HTTP: the two fixture files only, through the real Media download path
- (id<OR6APITask>)request:(NSURLRequest*)r kind:(NSString*)kind file:(NSString*)file context:(NSDictionary*)ctx completion:(OR6APIReply)reply{
 (void)ctx;BOOL known=[file isEqual:UI7FImageFile]||[file isEqual:UI7FAudioFile];NSString*path=r.URL.path;
 if(!known||[r valueForHTTPHeaderField:@"Authorization"]||[r valueForHTTPHeaderField:@"Cookie"])return[self refuse:@"files" what:path reply:reply];
 if([kind isEqual:@"json"]&&[path isEqual:[@"/backend-api/files/download/"stringByAppendingString:file]]){[self count:@"files.json"];reply(@{@"status":@200,@"json":@{@"download_url":[@"https://chatgpt.com/backend-api/estuary/content?id="stringByAppendingString:file],@"file_name":[file isEqual:UI7FImageFile]?@"ui7-fixture.png":@"ui7-fixture.wav"}},nil);return[[[UI7FTask alloc]init]autorelease];}
 if([kind isEqual:@"content"]&&[path isEqual:@"/backend-api/estuary/content"]){if(holdFiles)return[self hold:reply kind:@"files"];[self count:@"files.content"];reply(@{@"status":@200,@"bytes":[file isEqual:UI7FImageFile]?UI7FImagePNG():UI7FAudioWAV()},nil);return[[[UI7FTask alloc]init]autorelease];}
 return[self refuse:@"files" what:path reply:reply];
}
#pragma mark API7 transport and API9 controls: always refused
- (id<OR6APITask>)request:(NSURLRequest*)r context:(NSDictionary*)ctx completion:(OR6APIReply)reply{(void)ctx;return[self refuse:@"api7" what:[NSString stringWithFormat:@"%@ %@",r.HTTPMethod?:@"GET",r.URL.path] reply:reply];}
- (id<OR6APITask>)performRequest:(NSURLRequest*)r context:(NSDictionary*)ctx completion:(void(^)(NSDictionary*,NSError*))reply{(void)ctx;return[self refuse:@"controls" what:r.URL.path reply:reply];}
#pragma mark API9 recorder: synthetic, no microphone (audio-focus arbitration only)
- (BOOL)start:(NSString*)rid maxDurationMS:(NSUInteger)maximum error:(NSError**)error{(void)maximum;(void)error;[self count:@"recorder.start"];[recording release];recording=[rid copy];recordingActive=YES;return YES;}
- (void)stop{[self count:@"recorder.stop"];recordingActive=NO;}
- (void)suspend{[self count:@"recorder.suspend"];recordingActive=NO;}
- (void)cancel{[self count:@"recorder.cancel"];recordingActive=NO;[recording release];recording=nil;}
- (NSDictionary*)snapshot{return @{@"recordingId":recording?:(id)NSNull.null,@"state":!recording?@"idle":recordingActive?@"recording":@"stopped",@"assetId":recording&&!recordingActive?recording:(id)NSNull.null,@"durationMS":@1000,@"bytes":@(UI7FAudioWAV().length)};}
- (NSData*)recordingData:(NSString*)rid error:(NSError**)error{(void)error;return[rid isEqual:recording]?UI7FAudioWAV():nil;}
- (NSDictionary*)diagnostics{
 NSUInteger refusedTotal=0;for(NSString*k in counts)if([k hasSuffix:@".refused"])refusedTotal+=[counts[k]unsignedIntegerValue];
 return @{@"counts":[[counts copy]autorelease],@"refusedTotal":@(refusedTotal),@"refused":[[refused copy]autorelease],@"held":@(held.count),@"translationMode":translation,@"holdFiles":@(holdFiles),@"recorder":[self snapshot],@"accountRequests":@0,@"networkRequests":@0,@"microphoneRecordings":@0};
}
- (void)dealloc{for(OR6APIReply r in [[held copy]autorelease])r(nil,OR6APIError(@"cancelled",@"possible"));[held release];[counts release];[refused release];[translation release];[recording release];[super dealloc];}
@end

@implementation UI7FWeb
- (NSDictionary*)load:(NSInteger*)s{*s=0;return nil;}
- (NSDictionary*)legacy:(NSInteger*)s{*s=0;return nil;}
- (BOOL)save:(NSDictionary*)record status:(NSInteger*)s{(void)record;*s=0;[backend count:@"web.save"];return YES;}
- (BOOL)clearLegacy:(NSInteger*)s{*s=0;return YES;}
- (NSArray*)snapshot{return @[];}
- (void)install:(NSArray*)records{(void)records;[backend count:@"web.install"];}
- (void)clear{[backend count:@"web.clear"];}
- (id<OR6WebTask>)validate:(NSString*)token owner:(NSString*)owner completion:(OR6WebReply)completion{(void)token;(void)owner;(void)completion;[backend count:@"web.refused"];return nil;}
- (id<OR6WebTask>)fetch:(NSArray*)cookies completion:(OR6WebReply)completion{(void)cookies;(void)completion;[backend count:@"web.refused"];return nil;}
@end

@implementation UI7FCounter
- (id)initWithNext:(id<OR6APIProvider>)provider{if((self=[super init])){next=[provider retain];dispatched=[NSMutableDictionary new];completed=[NSMutableDictionary new];failures=[NSMutableDictionary new];last=[NSMutableDictionary new];}return self;}
static NSDictionary*Text(id t){return @{@"characters":@([t isKindOfClass:NSString.class]?[t length]:0),@"textSHA256":UI7FTextSHA256(t)};}
// Nonsecret fingerprints only: hashes and lengths of text, local codes/states, asset metadata.
- (void)record:(NSString*)op parameters:(NSDictionary*)p result:(NSDictionary*)r{
 if([op isEqual:@"content.copyCode"]||[op isEqual:@"translation.copy"]||[op isEqual:@"translation.share"]||[op isEqual:@"translation.translate"])last[op]=Text(r[@"text"]);
 else if([op hasPrefix:@"composer.editor."]){NSMutableDictionary*d=[[Text(r[@"text"])mutableCopy]autorelease];for(NSString*k in @[@"selectionStart",@"selectionLength",@"expanded"])if(r[k])d[k]=r[k];last[op]=d;}
 else if([op isEqual:@"emailDraft.prepare"]){NSURL*u=[r[@"url"]isKindOfClass:NSString.class]?[NSURL URLWithString:r[@"url"]]:nil;last[op]=@{@"scheme":u.scheme?:@"",@"urlSHA256":UI7FTextSHA256(r[@"url"]),@"sent":r[@"sent"]?:NSNull.null};}
 else if([op isEqual:@"emailDraft.set"])last[op]=@{@"recipients":@([r[@"to"]count]+[r[@"cc"]count]+[r[@"bcc"]count]),@"body":Text(r[@"body"])};
 else if([op isEqual:@"translation.languages"])last[op]=@{@"items":@([r[@"items"]count])};
 else if([op hasPrefix:@"translation."]||[op hasPrefix:@"playback."]||[op hasPrefix:@"clientPreferences."])last[op]=r?:@{};
 else if([@[@"assets.download",@"assets.status"]containsObject:op]){NSMutableDictionary*d=[NSMutableDictionary dictionary];for(NSString*k in @[@"assetId",@"mediaType",@"bytes",@"sha256",@"state",@"available"])if(r[k])d[k]=r[k];d[@"fileId"]=p[@"fileId"]?:NSNull.null;last[[op stringByAppendingFormat:@":%@",p[@"fileId"]?:p[@"assetId"]?:@""]]=d;last[op]=d;} // download by file, status by asset
 else if([op isEqual:@"images.export"])last[op]=@{@"destination":p[@"destination"]?:@"",@"token":@([r[@"token"]isKindOfClass:NSString.class]),@"saved":r[@"saved"]?:@0,@"completed":r[@"completed"]?:@NO};
}
- (id<OR6APITask>)execute:(NSString*)op parameters:(NSDictionary*)p context:(NSDictionary*)ctx event:(OR6APIEvent)event completion:(OR6APIReply)reply{
 dispatched[op]=@([dispatched[op]unsignedIntegerValue]+1);OR6APIReply done=[[reply copy]autorelease];
 return[next execute:op parameters:p context:ctx event:event completion:^(NSDictionary*r,NSError*e){
  if(e)failures[op]=@{@"code":e.userInfo[@"code"]?:@"",@"dispatch":e.userInfo[@"dispatch"]?:@""};else{completed[op]=@([completed[op]unsignedIntegerValue]+1);[self record:op parameters:p result:r];}
  if(done)done(r,e);
 }];
}
- (void)didValidate:(NSString*)op result:(NSDictionary*)r context:(NSDictionary*)ctx{if([next respondsToSelector:_cmd])[next didValidate:op result:r context:ctx];}
- (void)releaseCompletedDraft:(NSString*)d context:(NSDictionary*)ctx{if([next respondsToSelector:_cmd])[next releaseCompletedDraft:d context:ctx];}
- (void)dealloc{[next release];[dispatched release];[completed release];[failures release];[last release];[super dealloc];}
@end
