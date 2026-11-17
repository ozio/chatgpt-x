#import "OR6API8Media.h"
#import "OR6API8Headers.h"
#import "OR6API8Policy.h"
#import "../OR6APIOperations.h"
#import "../../OR6Files.h"
#import "../../chat/OR6ChatNativePolicy.h"
#import <dispatch/dispatch.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <sys/stat.h>
#import <CommonCrypto/CommonDigest.h>
#import <ImageIO/ImageIO.h>
#include <math.h>
@class OR6API8Media;
@interface M8Call:NSObject<OR6APITask>{@public OR6API8Media*owner;NSString*op;NSDictionary*p,*ctx,*asset;OR6APIReply reply;OR6APIEvent event;id<OR6APITask>child;BOOL terminal,dispatched;NSUInteger requestSerial;}
@end
@interface OR6API8Media(){id<OR6APIProvider>_next;OR6Files*_vault;NSString*_inbox,*_scope;NSUInteger _epoch;id<OR6API8HTTP>_HTTP;id<OR6API8Acquisition>_picker;NSSet*_caps;OR6APIOperations*_journal;NSMutableSet*_calls,*_adopted;NSMutableDictionary*_drafts;id<OR6API8RemoteAssets>_remoteAssets;}
- (void)finish:(M8Call*)call result:(NSDictionary*)result error:(NSError*)error;
- (void)processUpload:(M8Call*)call;
- (BOOL)processingResumable:(NSDictionary*)asset;
@end
@implementation M8Call
- (void)cancel{if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self cancel];});return;}[owner finish:self result:nil error:OR6APIError(@"cancelled",dispatched?@"possible":@"none")];}
- (void)dealloc{[op release];[p release];[ctx release];[asset release];[reply release];[event release];[child release];[super dealloc];}
@end
static NSString*UseCase8(NSDictionary*a){if([a[@"uploadPurpose"]isEqual:@"image_edit_mask"])return @"dalle_agent";return[a[@"mediaType"]hasPrefix:@"image/"]?@"multimodal":@"my_files";}
static NSString*EntrySurface8(NSDictionary*a){return[a[@"uploadPurpose"]isEqual:@"image_edit_mask"]?@"image_edit_mask":@"chat_composer";}
static NSDictionary*PublicAsset8(NSDictionary*d){NSMutableDictionary*r=[NSMutableDictionary dictionary];for(NSString*k in @[@"assetId",@"name",@"mediaType",@"bytes",@"sha256",@"state",@"remoteId"])if(d[k])r[k]=d[k];return r;}
static NSDictionary*LocalAsset8(NSDictionary*d){return @{@"assetId":d[@"id"],@"name":d[@"name"],@"mediaType":d[@"mediaType"],@"bytes":d[@"bytes"],@"sha256":d[@"sha256"],@"state":@"selected",@"remoteId":NSNull.null};}
static NSData*ReadAsset8(NSURL*url,NSDictionary*asset){
 int fd=url?open(url.path.fileSystemRepresentation,O_RDONLY|O_NOFOLLOW|O_NONBLOCK):-1;struct stat a,b;BOOL okay=fd>=0&&!fstat(fd,&a)&&S_ISREG(a.st_mode)&&a.st_nlink==1&&a.st_size>0&&a.st_size<=8*1024*1024&&a.st_size==[asset[@"bytes"]longLongValue];NSMutableData*d=[NSMutableData data];
 while(okay){unsigned char buf[8192];ssize_t n=read(fd,buf,sizeof(buf));if(n<0&&errno==EINTR)continue;if(n<0||(n>0&&d.length+(NSUInteger)n>(NSUInteger)a.st_size)){okay=NO;break;}if(!n)break;[d appendBytes:buf length:(NSUInteger)n];}
 okay=okay&&!fstat(fd,&b)&&a.st_dev==b.st_dev&&a.st_ino==b.st_ino&&a.st_size==b.st_size&&a.st_mtimespec.tv_sec==b.st_mtimespec.tv_sec&&a.st_mtimespec.tv_nsec==b.st_mtimespec.tv_nsec&&d.length==(NSUInteger)a.st_size;if(fd>=0)close(fd);if(!okay)return nil;
 unsigned char digest[CC_SHA256_DIGEST_LENGTH];CC_SHA256(d.bytes,(CC_LONG)d.length,digest);NSMutableString*sha=[NSMutableString string];for(NSUInteger i=0;i<sizeof(digest);i++)[sha appendFormat:@"%02x",digest[i]];return[sha isEqual:asset[@"sha256"]]?d:nil;
}
@implementation OR6API8Media
- (id)initWithNext:(id<OR6APIProvider>)next vault:(OR6Files*)vault inbox:(NSString*)inbox HTTP:(id<OR6API8HTTP>)HTTP picker:(id<OR6API8Acquisition>)picker journal:(NSString*)directory capabilities:(NSSet*)caps error:(NSError**)error {
 if((self=[super init])){if(!next||!vault||![caps isKindOfClass:NSSet.class]||![caps isSubsetOfSet:[NSSet setWithArray:@[@"upload",@"download"]]]||(caps.count&&!HTTP)){[self release];return nil;}_next=[next retain];_vault=[vault retain];_inbox=[inbox copy];_HTTP=[HTTP retain];_picker=[picker retain];_caps=[caps copy];_journal=[[OR6APIOperations alloc]initWithDirectory:directory error:error];_calls=[NSMutableSet new];_drafts=[NSMutableDictionary new];if(!_journal){[self release];return nil;}}return self;
}
- (BOOL)setRemoteAssets:(id<OR6API8RemoteAssets>)source {if(!NSThread.isMainThread||(_remoteAssets&&source&&_remoteAssets!=source))return NO;_remoteAssets=source;return YES;}
- (id<OR6API8RemoteAssets>)remoteAssets{return _remoteAssets;}
- (BOOL)needsRemotePreparation:(NSArray*)identifiers{for(NSString*i in identifiers)if([_remoteAssets canResolveRemoteAsset:i])return YES;return NO;}
- (id<OR6APITask>)prepareRemoteAssets:(NSArray*)identifiers draft:(NSString*)draft context:(NSDictionary*)ctx completion:(OR6APIReply)completion {
 NSMutableArray*remote=[NSMutableArray array];for(NSString*i in identifiers)if([_remoteAssets canResolveRemoteAsset:i])[remote addObject:i];
 if(!remote.count){completion(@{@"ready":@YES},nil);return nil;}
 return[_remoteAssets prepareRemoteAssets:remote draft:draft context:ctx completion:completion];
}
- (NSDictionary*)draftAsset:(NSString*)identifier draft:(NSString*)draft context:(NSDictionary*)ctx error:(NSError**)error {
 if([_remoteAssets canResolveRemoteAsset:identifier])return[_remoteAssets remoteAsset:identifier draft:draft context:ctx error:error];
 NSDictionary*a=[self asset:identifier context:ctx error:error];
 if([a[@"uploadPurpose"]isEqual:@"image_edit_mask"]){if(error)*error=OR6APIError(@"invalid_operation_state",@"none");return nil;}
 return a;
}
- (BOOL)current:(M8Call*)c{return !c->terminal&&[c->ctx[@"key"]isEqual:_scope]&&[c->ctx[@"generation"]unsignedIntegerValue]==_epoch;}
- (NSDictionary*)stored:(NSString*)identifier scope:(NSString*)scope next:(NSUInteger*)next error:(NSError**)error {
 NSDictionary*last=nil;
 for(NSUInteger n=0;n<128;n++){NSString*k=[NSString stringWithFormat:@"asset:%@:%lu",identifier,(unsigned long)n];NSDictionary*r=[_journal record:k scope:scope error:error];if(!r){if(next)*next=n;return last;}if(![r[@"state"]isEqual:@"completed"]||![r[@"result"][@"assetId"]isEqual:identifier]){if(error)*error=OR6APIError(@"storage_failure",@"none");return nil;}last=r[@"result"];}
 if(error)*error=OR6APIError(@"size_limit",@"none");return nil;
}
- (NSData*)imagePreviewDataForAsset:(NSString*)identifier context:(NSDictionary*)ctx {
 if(!NSThread.isMainThread||![_scope isEqual:ctx[@"key"]]||_epoch!=[ctx[@"generation"]unsignedIntegerValue])return nil;
 if(OR6API8RemoteID(identifier)){NSDictionary*r=[_journal record:[@"preview:"stringByAppendingString:identifier]scope:_scope error:NULL];identifier=r[@"result"][@"assetId"];}
 if(![identifier isKindOfClass:NSString.class])return nil;
 NSDictionary*a=[self asset:identifier context:ctx error:NULL];if(![@[@"image/png",@"image/jpeg"]containsObject:a[@"mediaType"]])return nil;
 return ReadAsset8([_vault URLForAssetID:identifier error:NULL],a);
}
- (BOOL)store:(NSDictionary*)asset scope:(NSString*)scope error:(NSError**)error {
 NSUInteger n=0;[self stored:asset[@"assetId"]scope:scope next:&n error:error];if(error&&*error)return NO;
 NSString*k=[NSString stringWithFormat:@"asset:%@:%lu",asset[@"assetId"],(unsigned long)n];BOOL saved=[_journal reserve:k command:@"asset.state"request:@{@"assetId":asset[@"assetId"]}scope:scope error:error]&&[_journal finish:k scope:scope state:@"completed"metadata:asset error:error];
 if(saved&&OR6API8RemoteID(asset[@"remoteId"])){NSString*key=[@"preview:"stringByAppendingString:asset[@"remoteId"]];if(![_journal record:key scope:scope error:NULL]){if([_journal reserve:key command:@"asset.preview"request:@{}scope:scope error:NULL])[_journal finish:key scope:scope state:@"completed"metadata:@{@"assetId":asset[@"assetId"]}error:NULL];}}
 return saved;
}
- (NSDictionary*)enrich:(NSDictionary*)asset {
 if(![asset[@"mediaType"]hasPrefix:@"image/"])return asset;NSURL*url=[_vault URLForAssetID:asset[@"assetId"]error:NULL];CGImageSourceRef image=url?CGImageSourceCreateWithURL((CFURLRef)url,NULL):NULL;CFDictionaryRef props=image?CGImageSourceCopyPropertiesAtIndex(image,0,NULL):NULL;NSDictionary*p=(NSDictionary*)props;NSUInteger w=[p[(id)kCGImagePropertyPixelWidth]unsignedIntegerValue],h=[p[(id)kCGImagePropertyPixelHeight]unsignedIntegerValue];if(props)CFRelease(props);if(image)CFRelease(image);if(!w||!h||w>16384||h>16384)return nil;NSMutableDictionary*out=[[asset mutableCopy]autorelease];out[@"width"]=@(w);out[@"height"]=@(h);return out;
}
- (NSDictionary*)adoptLocalAsset:(NSDictionary*)descriptor context:(NSDictionary*)ctx error:(NSError**)error {
 if(error)*error=nil;
 if(!NSThread.isMainThread||![ctx isKindOfClass:NSDictionary.class]||![_scope isEqual:ctx[@"key"]]||_epoch!=[ctx[@"generation"]unsignedIntegerValue]){if(error)*error=OR6APIError(@"stale_context",@"none");return nil;}
 NSString*identifier=[descriptor isKindOfClass:NSDictionary.class]?descriptor[@"id"]:nil;
 NSDictionary*actual=[identifier isKindOfClass:NSString.class]?[_vault assetForID:identifier error:NULL]:nil;
 if(!actual||![actual isEqual:descriptor]){if(error)*error=OR6APIError(@"owner_mismatch",@"none");return nil;}
 NSDictionary*asset=[self enrich:LocalAsset8(actual)];
 if(!asset||!ReadAsset8([_vault URLForAssetID:identifier error:NULL],asset)){if(error)*error=OR6APIError(@"unavailable",@"none");return nil;}
 NSError*storage=nil;NSDictionary*previous=[self stored:identifier scope:ctx[@"key"]next:NULL error:&storage];
 if(storage){if(error)*error=storage;return nil;}
 if(previous){if(![previous[@"sha256"]isEqual:asset[@"sha256"]]){if(error)*error=OR6APIError(@"conflict",@"none");return nil;}return PublicAsset8(previous);}
 if(![self store:asset scope:ctx[@"key"]error:error])return nil;
 return PublicAsset8(asset);
}
- (BOOL)bindImageEditMaskAsset:(NSString*)identifier context:(NSDictionary*)ctx error:(NSError**)error {
 if(error)*error=nil;
 if(!NSThread.isMainThread||![ctx isKindOfClass:NSDictionary.class]||![_scope isEqual:ctx[@"key"]]||_epoch!=[ctx[@"generation"]unsignedIntegerValue]){if(error)*error=OR6APIError(@"stale_context",@"none");return NO;}
 NSDictionary*asset=[self asset:identifier context:ctx error:error];if(!asset)return NO;
 BOOL local=[@[@"selected",@"local"]containsObject:asset[@"state"]]&&asset[@"remoteId"]==NSNull.null&&!asset[@"uploadOperationId"];
 NSUInteger w=[asset[@"width"]unsignedIntegerValue],h=[asset[@"height"]unsignedIntegerValue];
 if(!local||![asset[@"mediaType"]isEqual:@"image/png"]||!w||!h||w>2048||h>2048||!ReadAsset8([_vault URLForAssetID:identifier error:NULL],asset)){if(error)*error=OR6APIError(@"invalid_operation_state",@"none");return NO;}
 if([asset[@"uploadPurpose"]isEqual:@"image_edit_mask"])return YES;
 NSMutableDictionary*mask=[[asset mutableCopy]autorelease];mask[@"uploadPurpose"]=@"image_edit_mask";
 return [self store:mask scope:ctx[@"key"]error:error];
}
- (NSDictionary*)imageEditMaskAsset:(NSString*)identifier context:(NSDictionary*)ctx error:(NSError**)error {
 if(error)*error=nil;
 if(!NSThread.isMainThread||![ctx isKindOfClass:NSDictionary.class]||![_scope isEqual:ctx[@"key"]]||_epoch!=[ctx[@"generation"]unsignedIntegerValue]){if(error)*error=OR6APIError(@"stale_context",@"none");return nil;}
 NSDictionary*asset=[self asset:identifier context:ctx error:error];if(!asset)return nil;
 if(![asset[@"uploadPurpose"]isEqual:@"image_edit_mask"]||![asset[@"mediaType"]isEqual:@"image/png"]||![asset[@"state"]isEqual:@"ready"]||!OR6API8RemoteID(asset[@"remoteId"])||!ReadAsset8([_vault URLForAssetID:identifier error:NULL],asset)){if(error)*error=OR6APIError(@"invalid_operation_state",@"none");return nil;}
 return OR6APIJSONSnapshot(asset,8192);
}
- (NSArray*)uploadedProjectFilesForContext:(NSDictionary*)ctx error:(NSError**)error {
 if(error)*error=nil;
 if(!NSThread.isMainThread||![ctx isKindOfClass:NSDictionary.class]||![_scope isEqual:ctx[@"key"]]||_epoch!=[ctx[@"generation"]unsignedIntegerValue]){if(error)*error=OR6APIError(@"stale_context",@"none");return nil;}
 NSMutableArray*files=[NSMutableArray array];NSMutableSet*seen=[NSMutableSet set];
 for(NSDictionary*descriptor in [_vault assets]){
  NSDictionary*a=[self stored:descriptor[@"id"]scope:ctx[@"key"]next:NULL error:NULL];
  if(![a[@"state"]isEqual:@"ready"]||!OR6API8RemoteID(a[@"remoteId"])||!OR6CNUUID(a[@"uploadOperationId"])||a[@"uploadPurpose"]||[seen containsObject:a[@"remoteId"]])continue;
  NSURL*url=[_vault URLForAssetID:descriptor[@"id"]error:NULL];if(!ReadAsset8(url,a))continue;
  id modified=[NSFileManager.defaultManager attributesOfItemAtPath:url.path error:NULL][NSFileModificationDate];
  double ms=[modified isKindOfClass:NSDate.class]?[modified timeIntervalSince1970]*1000:-1;
  if(!isfinite(ms)||ms<0||ms>9007199254740991.0)continue;
  if(files.count>=128){if(error)*error=OR6APIError(@"size_limit",@"none");return nil;}
  [seen addObject:a[@"remoteId"]];[files addObject:@{@"fileId":a[@"remoteId"],@"libraryFileId":NSNull.null,@"name":a[@"name"],@"mediaType":a[@"mediaType"],@"bytes":a[@"bytes"],@"lastModified":@((long long)ms)}];
 }
 return [[files copy]autorelease];
}
- (NSDictionary*)asset:(NSString*)identifier context:(NSDictionary*)ctx error:(NSError**)error {
 NSDictionary*a=[self stored:identifier scope:ctx[@"key"]next:NULL error:error];if(!a){if(error&&!*error)*error=OR6APIError(@"not_found",@"none");return nil;}
 NSDictionary*d=[_vault assetForID:identifier error:NULL];if(!d||![d[@"sha256"]isEqual:a[@"sha256"]]){if(error)*error=OR6APIError(@"unavailable",@"none");return nil;}return a;
}
- (void)finish:(M8Call*)c result:(NSDictionary*)r error:(NSError*)e {
 if(c->terminal)return;[c retain];if(![self current:c]){r=nil;e=OR6APIError(@"stale_context",c->dispatched?@"possible":@"none");}c->terminal=YES;
 if(e&&[@[@"assets.upload",@"assets.processing.resume"]containsObject:c->op]&&c->asset){NSMutableDictionary*a=[[c->asset mutableCopy]autorelease];a[@"lastUploadIssue"]=e.userInfo[@"code"]?:@"unknown";a[@"state"]=[e.userInfo[@"code"]isEqual:@"expired"]?@"expired":[e.userInfo[@"dispatch"]isEqual:@"none"]?@"selected":@"unavailable";[self store:a scope:c->ctx[@"key"]error:NULL];}
 id<OR6APITask>task=[[c->child retain]autorelease];[c->child release];c->child=nil;if(e)[task cancel];OR6APIReply cb=[[c->reply copy]autorelease];[c->reply release];c->reply=nil;[c->event release];c->event=nil;c->owner=nil;[_calls removeObject:c];if(cb)cb(r,e);[c release];
}
- (void)adopt:(id<OR6APITask>)task call:(M8Call*)c{if(c->terminal)[task cancel];else if(task)c->child=[task retain];else[self finish:c result:nil error:OR6APIError(@"unavailable",c->dispatched?@"possible":@"none")];}
- (void)progress:(M8Call*)c phase:(NSString*)phase bytes:(NSUInteger)bytes {
 if(c->event){OR6APIEvent cb=[[c->event copy]autorelease];cb(@{@"name":@"progress",@"payload":@{@"operationId":c->p[@"operationId"],@"completedBytes":@(bytes),@"totalBytes":c->asset[@"bytes"]?:@(MAX((NSUInteger)1,bytes)),@"phase":phase}});}
}
- (void)request:(NSURLRequest*)r kind:(NSString*)kind file:(NSString*)file call:(M8Call*)c completion:(OR6APIReply)completion {
 if(![self current:c])return;c->dispatched=YES;NSUInteger serial=++c->requestSerial;__block BOOL delivered=NO;
 id<OR6APITask>task=[_HTTP request:r kind:kind file:file context:c->ctx completion:^(NSDictionary*v,NSError*e){if(delivered||![self current:c]||serial!=c->requestSerial)return;delivered=YES;[c->child release];c->child=nil;if(e)[self finish:c result:nil error:OR6APIError(e.userInfo[@"code"],@"possible")];else completion(v,nil);}];if(!delivered&&serial==c->requestSerial&&!c->terminal&&!c->child)[self adopt:task call:c];
}
- (NSMutableURLRequest*)json:(NSString*)path body:(NSDictionary*)body {
 NSMutableURLRequest*r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:[@"https://chatgpt.com"stringByAppendingString:path]]];r.HTTPMethod=body?@"POST":@"GET";if(body){r.HTTPBody=[NSJSONSerialization dataWithJSONObject:body options:0 error:NULL];[r setValue:@"application/json"forHTTPHeaderField:@"Content-Type"];}return r;
}
- (void)upload:(M8Call*)c {
 NSError*error=nil;NSDictionary*a=[self asset:c->p[@"assetId"]context:c->ctx error:&error];if(!a){[self finish:c result:nil error:error];return;}
 if([a[@"state"]isEqual:@"ready"]){[self finish:c result:PublicAsset8(a)error:nil];return;}
 if(![@[@"selected",@"local"]containsObject:a[@"state"]]){[self finish:c result:nil error:OR6APIError(@"invalid_operation_state",@"none")];return;}
 NSURL*url=[_vault URLForAssetID:a[@"assetId"]error:NULL];NSData*data=ReadAsset8(url,a);
 if(data.length!=[a[@"bytes"]unsignedIntegerValue]){[self finish:c result:nil error:OR6APIError(@"unavailable",@"none")];return;}
 NSMutableDictionary*pending=[[a mutableCopy]autorelease];pending[@"state"]=@"uploading";pending[@"uploadOperationId"]=c->p[@"operationId"];if(![self store:pending scope:c->ctx[@"key"]error:&error]){[self finish:c result:nil error:error];return;}c->asset=[pending copy];[self progress:c phase:@"uploading"bytes:0];if(![self current:c])return;
 [self request:[self json:@"/backend-api/files"body:@{@"file_name":a[@"name"],@"file_size":a[@"bytes"],@"use_case":UseCase8(a),@"mime_type":a[@"mediaType"],@"store_in_library":@NO}]kind:@"json"file:nil call:c completion:^(NSDictionary*v,NSError*ignored){
  (void)ignored;NSDictionary*j=v[@"json"];NSURL*destination=[j[@"upload_url"]isKindOfClass:NSString.class]?[NSURL URLWithString:j[@"upload_url"]]:nil;NSString*fid=j[@"file_id"];
  if(!OR6API8RemoteID(fid)||!destination||![destination.scheme isEqual:@"https"]){[self finish:c result:nil error:OR6APIError(@"unknown_wire_shape",@"possible")];return;}
  NSMutableDictionary*created=[[c->asset mutableCopy]autorelease];created[@"remoteId"]=fid;[c->asset release];c->asset=[created copy];if(![self store:created scope:c->ctx[@"key"]error:NULL]){[self finish:c result:nil error:OR6APIError(@"storage_failure",@"possible")];return;}
  BOOL aws=NO;for(NSString*pair in [destination.query componentsSeparatedByString:@"&"]){NSString*k=[[[pair componentsSeparatedByString:@"="]objectAtIndex:0]stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];if([k.lowercaseString isEqual:@"x-amz-algorithm"])aws=YES;}
  NSMutableURLRequest*put=[NSMutableURLRequest requestWithURL:destination];put.HTTPMethod=@"PUT";put.HTTPBody=data;[put setValue:a[@"mediaType"]?:@"application/octet-stream"forHTTPHeaderField:@"Content-Type"];if(!aws){[put setValue:@"BlockBlob"forHTTPHeaderField:@"x-ms-blob-type"];[put setValue:@"2020-04-08"forHTTPHeaderField:@"x-ms-version"];[put setValue:a[@"mediaType"]forHTTPHeaderField:@"x-ms-blob-content-type"];}
  NSString*uploadKind=@"blob";
  if([destination.host isEqual:@"chatgpt.com"]&&[destination.path isEqual:@"/backend-api/estuary/upload_content_bytes"]){
   NSString*nested=nil;NSUInteger found=0;for(NSString*pair in [destination.query componentsSeparatedByString:@"&"]){NSRange eq=[pair rangeOfString:@"="];if(eq.location==NSNotFound)continue;NSString*k=[[pair substringToIndex:eq.location]stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];if([k isEqual:@"upload_url"]){nested=[[pair substringFromIndex:eq.location+1]stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];found++;}}
   NSURL*nestedURL=nested?[NSURL URLWithString:nested]:nil;if(found!=1||nested.length>8192||![nestedURL.scheme isEqual:@"https"]||!nestedURL.host.length||nestedURL.user||nestedURL.password||nestedURL.fragment){[self finish:c result:nil error:OR6APIError(@"unknown_wire_shape",@"possible")];return;}
   CFUUIDRef uuid=CFUUIDCreate(NULL);CFStringRef token=uuid?CFUUIDCreateString(NULL,uuid):NULL;if(uuid)CFRelease(uuid);NSString*boundary=token?[@"LegacyClient-"stringByAppendingString:(NSString*)token]:nil;if(token)CFRelease(token);if(!boundary){[self finish:c result:nil error:OR6APIError(@"storage_failure",@"possible")];return;}NSData*needle=[boundary dataUsingEncoding:NSUTF8StringEncoding];if([data rangeOfData:needle options:0 range:NSMakeRange(0,data.length)].location!=NSNotFound||[nested rangeOfString:boundary].location!=NSNotFound){[self finish:c result:nil error:OR6APIError(@"invalid_request",@"possible")];return;}
   NSString*filename=[[a[@"name"]stringByReplacingOccurrencesOfString:@"\""withString:@"%22"]stringByReplacingOccurrencesOfString:@"\\"withString:@"%5C"];NSMutableData*body=[NSMutableData dataWithData:[[NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"file\"; filename=\"%@\"\r\nContent-Type: application/octet-stream\r\n\r\n",boundary,filename]dataUsingEncoding:NSUTF8StringEncoding]];[body appendData:data];[body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\nContent-Disposition: form-data; name=\"upload_url\"\r\n\r\n%@\r\n--%@--\r\n",boundary,nested,boundary]dataUsingEncoding:NSUTF8StringEncoding]];
   put.HTTPMethod=@"POST";put.HTTPBody=body;OR6API8ReplaceHeaders(put,@{@"Content-Type":[@"multipart/form-data; boundary="stringByAppendingString:boundary]});uploadKind=@"upload-content";
  }
  id headers=[uploadKind isEqual:@"blob"]?j[@"upload_headers"]:nil;if(headers&&headers!=NSNull.null){if(![headers isKindOfClass:NSDictionary.class]){[self finish:c result:nil error:OR6APIError(@"unknown_wire_shape",@"possible")];return;}for(NSString*k in headers){id val=headers[k];if(![val isKindOfClass:NSString.class]||[val length]>4096||[val rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound){[self finish:c result:nil error:OR6APIError(@"invalid_response",@"possible")];return;}[put setValue:val forHTTPHeaderField:k];}}
  if([uploadKind isEqual:@"blob"]&&[_HTTP respondsToSelector:@selector(admitSignedUploadRequest:file:context:)]){if(![_HTTP admitSignedUploadRequest:put file:fid context:c->ctx]){[self finish:c result:nil error:OR6APIError(@"capability_unavailable",@"possible")];return;}}
  [self request:put kind:uploadKind file:fid call:c completion:^(NSDictionary*uploaded,NSError*unused){
   (void)unused;if([uploaded[@"status"]integerValue]!=200&&[uploaded[@"status"]integerValue]!=201&&[uploaded[@"status"]integerValue]!=204){[self finish:c result:nil error:OR6APIError(@"upstream_error",@"possible")];return;}
   NSMutableDictionary*confirmed=[[c->asset mutableCopy]autorelease];confirmed[@"bytesConfirmed"]=@YES;if(![self store:confirmed scope:c->ctx[@"key"]error:NULL]){[self finish:c result:nil error:OR6APIError(@"storage_failure",@"possible")];return;}[c->asset release];c->asset=[confirmed copy];[self processUpload:c];
  }];
 }];
}
// Processing can be resumed explicitly for the same remote ID; it never
// creates another metadata entry or retransmits bytes. No automatic retry.
- (void)processUpload:(M8Call*)c {
 NSString*fid=c->asset[@"remoteId"];[self progress:c phase:@"processing"bytes:[c->asset[@"bytes"]unsignedIntegerValue]];if(![self current:c])return;
 NSDictionary*body=@{@"file_id":fid,@"file_name":c->asset[@"name"],@"mime_type":c->asset[@"mediaType"],@"use_case":UseCase8(c->asset),@"index_for_retrieval":@([UseCase8(c->asset)isEqual:@"my_files"]),@"entry_surface":EntrySurface8(c->asset),@"library_persistence_mode":@"opportunistic",@"metadata":@{@"store_in_library":@NO}};
 [self request:[self json:@"/backend-api/files/process_upload_stream"body:body]kind:@"process"file:fid call:c completion:^(NSDictionary*processed,NSError*unused){(void)unused;if(![processed[@"json"][@"ready"]boolValue]||![processed[@"json"][@"file_id"]isEqual:fid]){[self finish:c result:nil error:OR6APIError(@"uncertain_outcome",@"possible")];return;}NSMutableDictionary*ready=[[c->asset mutableCopy]autorelease];ready[@"state"]=@"ready";[ready removeObjectForKey:@"lastUploadIssue"];if(![self store:ready scope:c->ctx[@"key"]error:NULL]){[self finish:c result:nil error:OR6APIError(@"storage_failure",@"possible")];return;}[self finish:c result:PublicAsset8(ready)error:nil];}];
}
- (BOOL)processingResumable:(NSDictionary*)a{
 NSUInteger attempts=a[@"processingResumeCount"]?[a[@"processingResumeCount"]unsignedIntegerValue]:[a[@"processingResumed"]boolValue]?1:0;
 return[a[@"state"]isEqual:@"unavailable"]&&[a[@"bytesConfirmed"]isEqual:@YES]&&OR6API8RemoteID(a[@"remoteId"])&&attempts<2&&![@[@"rate_limited",@"service_challenge",@"auth_failed",@"not_authenticated",@"permission_denied",@"expired",@"tls"]containsObject:a[@"lastUploadIssue"]?:@""];
}
- (id<OR6APITask>)resumeProcessingAsset:(NSString*)asset operation:(NSString*)operation context:(NSDictionary*)ctx completion:(OR6APIReply)reply {
 // Trusted native host only; no URL/credential/new operation is exposed in Core JSON.
 if(!NSThread.isMainThread||![_caps containsObject:@"upload"]||!OR6CNUUID(asset)||!OR6CNUUID(operation)||![_scope isEqual:ctx[@"key"]]||_epoch!=[ctx[@"generation"]unsignedIntegerValue]){reply(nil,OR6APIError(@"invalid_operation_state",@"none"));return nil;}
 NSError*e=nil;NSDictionary*a=[self asset:asset context:ctx error:&e];NSUInteger attempts=a[@"processingResumeCount"]?[a[@"processingResumeCount"]unsignedIntegerValue]:[a[@"processingResumed"]boolValue]?1:0;if(!a||![self processingResumable:a]||!ReadAsset8([_vault URLForAssetID:asset error:NULL],a)){reply(nil,e?:OR6APIError(@"invalid_operation_state",@"none"));return nil;}
 NSMutableDictionary*pending=[[a mutableCopy]autorelease];pending[@"processingResumed"]=@YES;pending[@"processingResumeCount"]=@(attempts+1);if(![self store:pending scope:ctx[@"key"]error:&e]){reply(nil,e);return nil;}
 M8Call*c=[[[M8Call alloc]init]autorelease];c->owner=self;c->op=[@"assets.processing.resume"copy];c->p=[@{@"operationId":operation,@"assetId":asset}copy];c->ctx=[ctx copy];c->asset=[pending copy];c->reply=[reply copy];[_calls addObject:c];[self processUpload:c];return c;
}
- (NSDictionary*)importBytes:(NSData*)bytes error:(NSError**)error {
 NSString*path=[_inbox stringByAppendingPathComponent:[@"api-download-"stringByAppendingString:NSProcessInfo.processInfo.globallyUniqueString]];int fd=open(path.fileSystemRepresentation,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600);if(fd<0){if(error)*error=OR6APIError(@"storage_failure",@"none");return nil;}
 const unsigned char*p=bytes.bytes;NSUInteger at=0;BOOL okay=YES;while(at<bytes.length){ssize_t n=write(fd,p+at,bytes.length-at);if(n<0&&errno==EINTR)continue;if(n<=0){okay=NO;break;}at+=(NSUInteger)n;}if(okay&&fsync(fd))okay=NO;if(close(fd))okay=NO;
 NSDictionary*d=okay?[_vault importCacheURL:[NSURL fileURLWithPath:path]error:NULL]:nil; /* a download: re-fetchable, evictable */unlink(path.fileSystemRepresentation);if(!d&&error)*error=OR6APIError(@"storage_failure",@"none");return d;
}
// Downloaded copies (state "local" with a remoteId) are vault cache assets: a later download of the same file
// reuses the intact copy; when room is needed OR6Files evicts them least recently used first.
- (NSDictionary*)localCopy:(NSString*)fid scope:(NSString*)scope {
 for(NSDictionary*d in [_vault assets]){NSDictionary*a=[self stored:d[@"id"]scope:scope next:NULL error:NULL];
  if([a[@"state"]isEqual:@"local"]&&[a[@"remoteId"]isEqual:fid]&&[a[@"assetId"]isEqual:d[@"id"]]&&[a[@"sha256"]isEqual:d[@"sha256"]])return a;}
 return nil;
}
// Once per account and process: downloaded copies imported before the vault had cache assets become cache
// assets, and byte-identical duplicates are removed, keeping the copy the preview record names (else the
// first). Drafts' attachments and assets this journal does not record as downloads are left alone.
- (void)adoptDownloadedCopies:(NSString*)scope {
 if(!scope.length||[_adopted containsObject:scope])return;if(!_adopted)_adopted=[NSMutableSet new];[_adopted addObject:scope];
 NSMutableSet*keep=[NSMutableSet set];for(NSDictionary*draft in _drafts.allValues){id ids=draft[@"attachments"];if([ids isKindOfClass:NSArray.class])[keep addObjectsFromArray:ids];}
 NSMutableDictionary*groups=[NSMutableDictionary dictionary],*remote=[NSMutableDictionary dictionary];
 for(NSDictionary*d in [_vault assets]){if([keep containsObject:d[@"id"]])continue;NSDictionary*a=[self stored:d[@"id"]scope:scope next:NULL error:NULL];
  if(![a[@"state"]isEqual:@"local"]||!OR6API8RemoteID(a[@"remoteId"])||![a[@"assetId"]isEqual:d[@"id"]]||![a[@"sha256"]isEqual:d[@"sha256"]])continue;
  if(![_vault markCacheAssetID:d[@"id"]error:NULL])continue;
  NSMutableArray*g=groups[d[@"sha256"]];if(!g)groups[d[@"sha256"]]=g=[NSMutableArray array];[g addObject:d[@"id"]];remote[d[@"id"]]=a[@"remoteId"];}
 for(NSArray*g in groups.allValues){if(g.count<2)continue;
  NSString*kept=g[0];for(NSString*i in g){NSDictionary*r=[_journal record:[@"preview:"stringByAppendingString:remote[i]]scope:scope error:NULL];if([r[@"result"][@"assetId"]isEqual:i]){kept=i;break;}}
  for(NSString*i in g)if(![i isEqual:kept])[_vault removeAssetID:i error:NULL];}
}
- (void)download:(M8Call*)c {
 id<OR6APITask>task=[_next execute:@"history.get"parameters:@{@"conversationId":c->p[@"conversationId"]}context:c->ctx event:nil completion:^(NSDictionary*conversation,NSError*e){
  if(![self current:c])return;[c->child release];c->child=nil;if(e){[self finish:c result:nil error:e];return;}
  NSString*fid=c->p[@"fileId"];if(!OR6API8HasFile(conversation,c->p[@"messageId"],fid)){[self finish:c result:nil error:OR6APIError(@"not_found",@"none")];return;}
  NSDictionary*copy=[self localCopy:fid scope:c->ctx[@"key"]];if(copy){c->asset=[copy copy];[self finish:c result:PublicAsset8(copy)error:nil];return;} // already on this iPhone: no second download
  NSString*path=[NSString stringWithFormat:@"/backend-api/files/download/%@?download_intent=false",fid];
  [self request:[self json:path body:nil]kind:@"json"file:fid call:c completion:^(NSDictionary*v,NSError*unused){
   (void)unused;id raw=v[@"json"][@"download_url"];NSURL*u=[raw isKindOfClass:NSString.class]?[[NSURL URLWithString:raw relativeToURL:[NSURL URLWithString:@"https://chatgpt.com"]]absoluteURL]:nil;
   if(![u.scheme isEqual:@"https"]||![u.host isEqual:@"chatgpt.com"]||![u.path isEqual:@"/backend-api/estuary/content"]||u.user||u.password||u.fragment||(u.port&&u.port.integerValue!=443)){[self finish:c result:nil error:OR6APIError(@"capability_unavailable",@"possible")];return;}
   [self request:[NSURLRequest requestWithURL:u]kind:@"content"file:fid call:c completion:^(NSDictionary*result,NSError*unused2){
    (void)unused2;NSData*bytes=result[@"bytes"];if(![bytes isKindOfClass:NSData.class]||!bytes.length||bytes.length>8*1024*1024){[self finish:c result:nil error:OR6APIError(@"size_limit",@"possible")];return;}
    NSError*problem=nil;NSDictionary*d=[self importBytes:bytes error:&problem];if(!d){[self finish:c result:nil error:OR6APIError(@"storage_failure",@"possible")];return;}
    NSMutableDictionary*a=[[[self enrich:LocalAsset8(d)]mutableCopy]autorelease];if(!a){[self finish:c result:nil error:OR6APIError(@"unsupported_media",@"possible")];return;}id display=v[@"json"][@"file_name"];if([display isKindOfClass:NSString.class]&&[display length]&&[display length]<=240&&[display rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location==NSNotFound)a[@"name"]=display;a[@"state"]=@"local";a[@"remoteId"]=fid;if(![self store:a scope:c->ctx[@"key"]error:NULL]){[self finish:c result:nil error:OR6APIError(@"storage_failure",@"possible")];return;}c->asset=[a copy];[self progress:c phase:@"downloading"bytes:bytes.length];if([self current:c])[self finish:c result:PublicAsset8(a)error:nil];
   }];
  }];
 }];if(!c->terminal&&!c->child)[self adopt:task call:c];
}
- (void)didValidate:(NSString*)op result:(NSDictionary*)r context:(NSDictionary*)ctx{if([op isEqual:@"messages.newDraft"]&&[_scope isEqual:ctx[@"key"]])_drafts[r[@"draftId"]]=r;if([_next respondsToSelector:@selector(didValidate:result:context:)])[_next didValidate:op result:r context:ctx];}
- (void)releaseCompletedDraft:(NSString*)draft context:(NSDictionary*)ctx{if([_scope isEqual:ctx[@"key"]]){[_drafts removeObjectForKey:draft];[_remoteAssets releaseRemoteDraft:draft context:ctx];}if([_next respondsToSelector:@selector(releaseCompletedDraft:context:)])[_next releaseCompletedDraft:draft context:ctx];}
- (NSArray*)attachments:(NSArray*)ids draft:(NSString*)draft context:(NSDictionary*)ctx error:(NSError**)error {
 if(error)*error=nil;if(![_scope isEqual:ctx[@"key"]]||![_drafts[draft][@"attachments"]isEqual:ids]){if(error)*error=OR6APIError(@"invalid_operation_state",@"none");return nil;}
 NSMutableArray*out=[NSMutableArray array];for(NSString*i in ids){NSDictionary*a=[self draftAsset:i draft:draft context:ctx error:error];if(![a[@"state"]isEqual:@"ready"]){if(error&&!*error)*error=OR6APIError(@"invalid_operation_state",@"none");return nil;}[out addObject:a];}return out;
}
- (void)deactivate{for(M8Call*c in [[_calls.allObjects copy]autorelease])[c cancel];}
- (BOOL)bindContext:(NSDictionary*)ctx {
 NSDictionary*snapshot=OR6APIJSONSnapshot(ctx,4096);
 NSDictionary*schema=@{@"type":@"object",@"properties":@{@"key":@{@"type":@"string",@"minLength":@1,@"maxLength":@256},@"generation":@{@"type":@"integer",@"minimum":@1}},@"required":@[@"key",@"generation"],@"additionalProperties":@NO};
 if(!NSThread.isMainThread||!OR6APISchemaCheck(snapshot,schema,@{}))return NO;
 if(![_scope isEqual:snapshot[@"key"]]||_epoch!=[snapshot[@"generation"]unsignedIntegerValue]){[self deactivate];if(![_scope isEqual:snapshot[@"key"]])[_drafts removeAllObjects];[_scope release];_scope=[snapshot[@"key"]copy];_epoch=[snapshot[@"generation"]unsignedIntegerValue];}
 [self adoptDownloadedCopies:_scope];return YES;
}
- (id<OR6APITask>)execute:(NSString*)op parameters:(NSDictionary*)p context:(NSDictionary*)ctx event:(OR6APIEvent)event completion:(OR6APIReply)reply {
 if(!NSThread.isMainThread){reply(nil,OR6APIError(@"invalid_request",@"none"));return nil;}
 if(![self bindContext:ctx]){reply(nil,OR6APIError(@"invalid_request",@"none"));return nil;}
 if(![op hasPrefix:@"assets."]){if([op isEqual:@"auth.logout"]){[self deactivate];[_drafts removeAllObjects];}return[_next execute:op parameters:p context:ctx event:event completion:reply];}
 if([op isEqual:@"assets.processing.resume"]){NSDictionary*a=[self asset:p[@"assetId"]context:ctx error:NULL];if(![a[@"uploadOperationId"]isEqual:p[@"operationId"]]){reply(nil,OR6APIError(@"invalid_operation_state",@"none"));return nil;}for(M8Call*active in _calls)if([active->asset[@"assetId"]isEqual:p[@"assetId"]]){reply(nil,OR6APIError(@"conflict",@"none"));return nil;}return[self resumeProcessingAsset:p[@"assetId"]operation:p[@"operationId"]context:ctx completion:reply];}
 M8Call*c=[[[M8Call alloc]init]autorelease];c->owner=self;c->op=[op copy];c->p=[p copy];c->ctx=[ctx copy];c->reply=[reply copy];c->event=[event copy];[_calls addObject:c];NSError*error=nil;
 if([op isEqual:@"assets.acquire"]){
  if(!_picker){[self finish:c result:nil error:OR6APIError(@"capability_unavailable",@"none")];return c;}
  __block BOOL acquired=NO;id<OR6APITask>task=[_picker acquire:p[@"source"]selection:p[@"selectionId"]completion:^(NSURL*u,NSError*e){if(acquired||![self current:c])return;acquired=YES;if(e){[self finish:c result:nil error:OR6APIError(e.userInfo[@"code"]?:@"cancelled",@"none")];return;}NSDictionary*d=[_vault importInboxURL:u error:NULL];if([_picker respondsToSelector:@selector(releaseSelectionURL:)])[_picker releaseSelectionURL:u];NSDictionary*a=d?[self enrich:LocalAsset8(d)]:nil;if(!a||![self store:a scope:c->ctx[@"key"]error:NULL]){[self finish:c result:nil error:OR6APIError(@"storage_failure",@"none")];return;}[self finish:c result:PublicAsset8(a)error:nil];}];[self adopt:task call:c];
 }else if([op isEqual:@"assets.upload"]||[op isEqual:@"assets.download"]){NSString*cap=[op isEqual:@"assets.upload"]?@"upload":@"download";if(![_caps containsObject:cap])[self finish:c result:nil error:OR6APIError(@"capability_unverified",@"none")];else if([op isEqual:@"assets.upload"])[self upload:c];else[self download:c];}
 else if([op isEqual:@"assets.limits"])[self finish:c result:@{@"maxBytes":@(8*1024*1024),@"maxCount":@4,@"allowedMediaTypes":@[@"text/plain",@"image/png",@"image/jpeg",@"application/pdf",@"application/octet-stream",@"audio/wav",@"audio/mp4"],@"scope":@"client_policy",@"serverLimitsKnown":@NO}error:nil];
 else if([op isEqual:@"assets.status"]){NSDictionary*a=[self asset:p[@"assetId"]context:ctx error:&error];NSString*s=[a[@"state"]isEqual:@"selected"]?@"local":a[@"state"];[self finish:c result:a?@{@"assetId":a[@"assetId"],@"state":s,@"available":@([@[@"local",@"ready"]containsObject:s]),@"expiresAt":NSNull.null,@"remoteId":a[@"remoteId"],@"processingResumable":@([self processingResumable:a])}:nil error:error];}
 else if([op isEqual:@"assets.attach"]||[op isEqual:@"assets.detach"]){
  NSDictionary*d=_drafts[p[@"draftId"]];if(!d){[self finish:c result:nil error:OR6APIError(@"not_found",@"none")];return c;}NSMutableArray*ids=[[d[@"attachments"]mutableCopy]autorelease];BOOL attach=[op isEqual:@"assets.attach"];
  if(attach){NSDictionary*a=[self draftAsset:p[@"assetId"]draft:p[@"draftId"]context:ctx error:&error];if(![a[@"state"]isEqual:@"ready"]||[ids containsObject:p[@"assetId"]]){[self finish:c result:nil error:error?:OR6APIError(@"invalid_operation_state",@"none")];return c;}id old=p[@"replaceAssetId"];if(old!=NSNull.null){NSUInteger index=[ids indexOfObject:old];if(index==NSNotFound){[self finish:c result:nil error:OR6APIError(@"not_found",@"none")];return c;}ids[index]=p[@"assetId"];}else{if(ids.count>=4){[self finish:c result:nil error:OR6APIError(@"size_limit",@"none")];return c;}[ids addObject:p[@"assetId"]];}}
  else{if(![ids containsObject:p[@"assetId"]]){[self finish:c result:nil error:OR6APIError(@"not_found",@"none")];return c;}[ids removeObject:p[@"assetId"]];}
  NSMutableDictionary*n=[[d mutableCopy]autorelease];n[@"attachments"]=ids;_drafts[p[@"draftId"]]=n;[self finish:c result:attach?n:@{@"draftId":p[@"draftId"],@"assetId":p[@"assetId"],@"detached":@YES}error:nil];
 }else[self finish:c result:nil error:OR6APIError(@"capability_unavailable",@"none")];return c;
}
- (void)dealloc{[self deactivate];[_next release];[_vault release];[_inbox release];[_scope release];[_HTTP release];[_picker release];[_caps release];[_adopted release];[_journal release];[_calls release];[_drafts release];[super dealloc];}
@end
