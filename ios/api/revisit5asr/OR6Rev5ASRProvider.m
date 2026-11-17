#import "OR6Rev5ASR.h"
#import "OR6Rev5ASREngine.h"
#import "../priority8/OR6API8Media.h"
#import "../../OR6Files.h"
#import <dispatch/dispatch.h>
#import <CommonCrypto/CommonDigest.h>
static BOOL Text(id s,NSUInteger max){return[s isKindOfClass:NSString.class]&&[s length]&&[s length]<=max&&[s rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location==NSNotFound;}
static BOOL Context(id x){return OR6APISchemaCheck(x,@{@"type":@"object",@"properties":@{@"key":@{@"type":@"string",@"minLength":@1,@"maxLength":@256},@"generation":@{@"type":@"integer",@"minimum":@1}},@"required":@[@"key",@"generation"],@"additionalProperties":@NO},@{});}
static NSString *Hash(NSData*d){unsigned char b[32];CC_SHA256(d.bytes,(CC_LONG)d.length,b);NSMutableString*s=[NSMutableString string];for(int n=0;n<32;n++)[s appendFormat:@"%02x",b[n]];return s;}
@class OR6Rev5ASRCall;
@interface OR6Rev5ASRProvider(){id<OR6APIProvider>_next;OR6Files*_vault;OR6API8Media*_media;NSDictionary*_registry,*_identity,*_context;NSMutableDictionary*_assets;NSString*_models;dispatch_queue_t _queue;OR6Rev5ASRCall*_pending;NSUInteger _epoch;BOOL _transitioning,_working;}
- (void)cancel:(OR6Rev5ASRCall*)c;
- (void)finish:(OR6Rev5ASRCall*)c result:(NSDictionary*)r error:(NSError*)error;
@end
@interface OR6Rev5ASRCall:NSObject<OR6APITask>{@public OR6Rev5ASRProvider*owner;NSDictionary*identity,*context,*asset,*parameters;OR6APIReply reply;NSUInteger epoch;BOOL stopped,done;}
- (BOOL)isStopped;
- (void)stop;
@end
@implementation OR6Rev5ASRCall
- (BOOL)isStopped{@synchronized(self){return stopped;}}
- (void)stop{@synchronized(self){stopped=YES;}}
- (void)cancel{[self stop];if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self cancel];});return;}[owner cancel:self];}
- (void)dealloc{[owner release];[identity release];[context release];[asset release];[parameters release];[reply release];[super dealloc];}
@end
@implementation OR6Rev5ASRProvider
- (id)initWithNext:(id<OR6APIProvider>)next registry:(NSDictionary*)registry vault:(OR6Files*)vault media:(OR6API8Media*)media modelsDirectory:(NSString*)directory error:(NSError**)error{
 if(!(self=[super init]))return nil;_registry=[OR6APIJSONSnapshot(registry,4*1024*1024)retain];BOOL found=NO;NSArray *registered=[_registry isKindOfClass:NSDictionary.class]&&[_registry[@"operations"]isKindOfClass:NSArray.class]?_registry[@"operations"]:nil;for(id op in registered)if([op isKindOfClass:NSDictionary.class]&&[op[@"id"]isEqual:@"audio.localTranscription.transcribe"])found=YES;if(!next||!vault||!media||!directory.isAbsolutePath||!found){if(error)*error=OR6APIError(@"invalid_request",@"none");[self release];return nil;}_next=[next retain];_vault=[vault retain];_media=[media retain];_models=[directory copy];_assets=[NSMutableDictionary new];_queue=dispatch_queue_create("io.ozio.chatgptx.asr",DISPATCH_QUEUE_SERIAL);return self;
}
- (BOOL)current:(OR6Rev5ASRCall*)c{return c&&!c->done&&!_transitioning&&_pending==c&&c->epoch==_epoch&&[_identity isEqual:c->identity]&&[_context isEqual:c->context];}
- (void)finish:(OR6Rev5ASRCall*)c result:(NSDictionary*)r error:(NSError*)error{
 if(!c||c->done)return;[c retain];c->done=YES;[c stop];NSDictionary*safe=error?nil:OR6APIJSONSnapshot(r,16384);NSDictionary*schema=nil;for(NSDictionary*o in _registry[@"operations"])if([o[@"id"]isEqual:@"audio.localTranscription.transcribe"])schema=o[@"responseSchema"];if(!error&&(!safe||!OR6APISchemaCheck(safe,schema,_registry[@"types"])))error=OR6APIError(@"invalid_response",@"none");OR6APIReply cb=[[c->reply copy]autorelease];[c->reply release];c->reply=nil;if(_pending==c){[_pending release];_pending=nil;}OR6Rev5ASRProvider*held=c->owner;c->owner=nil;if(cb)cb(error?nil:safe,error);[held release];[c release];
}
- (void)cancel:(OR6Rev5ASRCall*)c{[self finish:c result:nil error:OR6APIError(@"cancelled",@"none")];}
- (void)deactivate{if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self deactivate];});return;}_transitioning=YES;_epoch++;if(_pending)[self finish:_pending result:nil error:OR6APIError(@"stale_context",@"none")];[_assets removeAllObjects];[_identity release];_identity=nil;[_context release];_context=nil;_transitioning=NO;}
- (BOOL)bindIdentity:(NSDictionary*)identity context:(NSDictionary*)context{
 NSDictionary*i=OR6APIJSONSnapshot(identity,4096),*c=OR6APIJSONSnapshot(context,4096);if(!NSThread.isMainThread||_transitioning||![i isKindOfClass:NSDictionary.class]||i.count!=2||!Text(i[@"accountId"],128)||!Text(i[@"userId"],256)||!Context(c))return NO;if(![_identity isEqual:i]||![_context isEqual:c]){[self deactivate];_identity=[i retain];_context=[c retain];}return YES;
}
- (BOOL)bindAssets:(NSArray*)assets context:(NSDictionary*)context{
 if(!NSThread.isMainThread||_transitioning||!_identity||![_context isEqual:context]||![assets isKindOfClass:NSArray.class]||assets.count>16)return NO;NSArray*snapshot=OR6APIJSONSnapshot(assets,32768);if(!snapshot)return NO;NSMutableDictionary*found=[NSMutableDictionary dictionary];for(id a in snapshot){if(![a isKindOfClass:NSDictionary.class]||!Text(a[@"id"],128))return NO;NSDictionary*actual=[_vault assetForID:a[@"id"]error:NULL];if(![actual isEqual:a]||[actual[@"bytes"]unsignedLongLongValue]>8*1024*1024||![@[@"audio/wav",@"audio/x-wav",@"audio/mp4",@"audio/m4a",@"application/octet-stream"]containsObject:actual[@"mediaType"]]||![_vault URLForAssetID:a[@"id"]error:NULL])return NO;found[a[@"id"]]=a;}[_assets addEntriesFromDictionary:found];return YES;
}
- (id<OR6APITask>)execute:(NSString*)operation parameters:(NSDictionary*)parameters context:(NSDictionary*)context event:(OR6APIEvent)event completion:(OR6APIReply)completion{
 if(!NSThread.isMainThread){OR6APIReply cb=[[completion copy]autorelease];if(cb)dispatch_async(dispatch_get_main_queue(),^{cb(nil,OR6APIError(@"invalid_request",@"none"));});return nil;}if(!Text(operation,128)){if(completion)completion(nil,OR6APIError(@"invalid_request",@"none"));return nil;}NSString*op=[[operation copy]autorelease];if(!OR6Rev5ASROperations()[op]){if([op isEqual:@"auth.logout"])[self deactivate];return[_next execute:op parameters:parameters context:context event:event completion:completion];}
 NSDictionary*p=OR6APIJSONSnapshot(parameters,4096),*ctx=OR6APIJSONSnapshot(context,4096);NSError*e=nil;if(!p||!OR6APISchemaCheck(p,OR6Rev5ASROperations()[op],@{}))e=OR6APIError(@"invalid_request",@"none");else if(_transitioning||!_identity||![_context isEqual:ctx]||![_media bindContext:ctx])e=OR6APIError(@"stale_context",@"none");else if(!_assets[p[@"assetId"]])e=OR6APIError(@"owner_mismatch",@"none");else if(_pending||_working)e=OR6APIError(@"conflict",@"none");if(e){if(completion)completion(nil,e);return nil;}
 OR6Rev5ASRCall*c=[[[OR6Rev5ASRCall alloc]init]autorelease];c->owner=[self retain];c->identity=[_identity retain];c->context=[ctx retain];c->parameters=[p retain];c->asset=[_assets[p[@"assetId"]]retain];c->epoch=_epoch;c->reply=[completion copy];_pending=[c retain];_working=YES;
 dispatch_async(_queue,^{NSAutoreleasePool*pool=[NSAutoreleasePool new];NSError*error=nil;NSDictionary*result=nil;if(![c isStopped]){NSDictionary*actual=[_vault assetForID:c->asset[@"id"]error:NULL];NSURL*url=[actual isEqual:c->asset]?[_vault URLForAssetID:c->asset[@"id"]error:NULL]:nil;NSData*bytes=url?[[NSData alloc]initWithContentsOfURL:url]:nil;if(!bytes||bytes.length>8*1024*1024||bytes.length!=[c->asset[@"bytes"]unsignedLongLongValue]||![Hash(bytes)isEqual:c->asset[@"sha256"]])error=OR6APIError(@"storage_failure",@"none");else if(![c isStopped]){NSDictionary*decoded=OR6Rev5ASRDecode(bytes,_models,^BOOL{return[c isStopped];},&error);if(decoded){NSMutableDictionary*r=[[decoded mutableCopy]autorelease];r[@"assetId"]=c->asset[@"id"];result=OR6APIJSONSnapshot(r,16384);}}[bytes release];}NSDictionary*out=[result retain];NSError*failure=[error retain];dispatch_async(dispatch_get_main_queue(),^{_working=NO;if([self current:c])[self finish:c result:out error:failure?:(!out?OR6APIError(@"cancelled",@"none"):nil)];[out release];[failure release];});[pool drain];});return c;
}
- (void)didValidate:(NSString*)op result:(NSDictionary*)r context:(NSDictionary*)ctx{if([_next respondsToSelector:_cmd])[_next didValidate:op result:r context:ctx];}
- (void)releaseCompletedDraft:(NSString*)draft context:(NSDictionary*)ctx{if([_next respondsToSelector:_cmd])[_next releaseCompletedDraft:draft context:ctx];}
- (NSDictionary*)diagnostics{return @{@"active":_pending?@YES:@NO,@"workerBusy":_working?@YES:@NO,@"assets":@(_assets.count),@"language":@"en-US",@"offline":@YES,@"maximumSeconds":@30,@"modelDownload":@NO};}
- (void)dealloc{[_next release];[_vault release];[_media release];[_registry release];[_identity release];[_context release];[_assets release];[_models release];if(_queue)dispatch_release(_queue);[super dealloc];}
@end
