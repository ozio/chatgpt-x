#import "OR6API7CProvider.h"
#import "OR6API7CPolicy.h"
#import "../priority7b/OR6API7BPolicy.h"
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>
#include <math.h>
@class CCall;
@interface OR6API7CProvider(){
 id<OR6APIProvider>_next;id<OR6API7HTTP>_HTTP;OR6API8Media*_media;
 NSDictionary*_extension,*_operations;NSSet*_caps;NSMutableSet*_calls;
 NSMutableDictionary*_handles,*_pages;NSString*_scope;NSUInteger _epoch,_requests;
 NSTimeInterval(^_clock)(void);
}
- (void)cancel:(CCall*)call;
@end
@interface CCall:NSObject<OR6APITask>{@public OR6API7CProvider*owner;NSString*op;NSDictionary*p,*ctx;OR6APIReply reply;id<OR6APITask>child;NSUInteger serial;BOOL terminal;}
@end
@implementation CCall
- (void)cancel{if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self cancel];});return;}if(!terminal)[owner cancel:self];}
- (void)dealloc{[op release];[p release];[ctx release];[reply release];[child release];[super dealloc];}
@end
static NSString*ID(void){CFUUIDRef u=CFUUIDCreate(NULL);NSString*s=[(NSString*)CFUUIDCreateString(NULL,u)autorelease];CFRelease(u);return s.lowercaseString;}
static BOOL Context(NSDictionary*c){return[c isKindOfClass:NSDictionary.class]&&[c[@"key"]isKindOfClass:NSString.class]&&[c[@"key"]length]&&[c[@"key"]length]<=256&&OR6APISchemaCheck(c[@"generation"],@{@"type":@"integer",@"minimum":@1},@{});}
@implementation OR6API7CProvider
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP media:(OR6API8Media*)media extension:(NSDictionary*)ext capabilities:(NSSet*)caps clock:(NSTimeInterval(^)(void))clock error:(NSError**)error{
 if(!(self=[super init]))return nil;_extension=[OR6APIJSONSnapshot(ext,1024*1024)retain];
 if(!next||!HTTP||!media||![_extension[@"operations"]isKindOfClass:NSArray.class]||![caps isKindOfClass:NSSet.class]||media.remoteAssets){if(error)*error=OR6APIError(@"invalid_request",@"none");[self release];return nil;}
 NSMutableDictionary*ops=[NSMutableDictionary dictionary];for(NSDictionary*o in _extension[@"operations"]){if(!OR6API7CCommand(o[@"id"])||ops[o[@"id"]]){if(error)*error=OR6APIError(@"invalid_request",@"none");[self release];return nil;}ops[o[@"id"]]=o;}
 _next=[next retain];_HTTP=[HTTP retain];_media=[media retain];_operations=[ops copy];_caps=[caps copy];_calls=[NSMutableSet new];_handles=[NSMutableDictionary new];_pages=[NSMutableDictionary new];
 _clock=[(clock?:^NSTimeInterval{return NSProcessInfo.processInfo.systemUptime;})copy];
 if(![_media setRemoteAssets:self]){if(error)*error=OR6APIError(@"conflict",@"none");[self release];return nil;}return self;
}
- (BOOL)current:(CCall*)c{return!c->terminal&&[_scope isEqual:c->ctx[@"key"]]&&_epoch==[c->ctx[@"generation"]unsignedIntegerValue];}
- (void)finish:(CCall*)c result:(NSDictionary*)r error:(NSError*)e{
 if(c->terminal)return;[c retain];c->terminal=YES;OR6APIReply cb=[[c->reply copy]autorelease];[c->reply release];c->reply=nil;id<OR6APITask>task=[[c->child retain]autorelease];[c->child release];c->child=nil;[_calls removeObject:c];if(e)[task cancel];if(cb)cb(r,e);[c release];
}
- (void)cancel:(CCall*)c{if(!c->terminal)[self finish:c result:nil error:OR6APIError(@"cancelled",@"none")];}
- (void)deactivate{for(CCall*c in [[_calls.allObjects copy]autorelease])[self cancel:c];[_handles removeAllObjects];[_pages removeAllObjects];}
- (void)adopt:(id<OR6APITask>)task serial:(NSUInteger)serial call:(CCall*)c{if(c->terminal||serial!=c->serial)[task cancel];else if(task){[c->child release];c->child=[task retain];}else[self finish:c result:nil error:OR6APIError(@"unavailable",@"none")];}
- (void)request:(NSString*)op parameters:(NSDictionary*)p cursor:(NSString*)cursor call:(CCall*)c completion:(OR6APIReply)completion{
 NSError*error=nil;NSURLRequest*r=OR6API7CRequest(op,p,cursor,&error);if(!r){[self finish:c result:nil error:error];return;}NSUInteger serial=++c->serial;_requests++;__block BOOL delivered=NO;
 id<OR6APITask>task=[_HTTP request:r context:c->ctx completion:^(NSDictionary*v,NSError*e){
  if(delivered||![self current:c]||serial!=c->serial)return;delivered=YES;
  if(e){[self finish:c result:nil error:OR6APIError(e.userInfo[@"code"],@"none")];return;}
  if(![v isKindOfClass:NSDictionary.class]||!OR6APIJSONSnapshot(v,4*1024*1024)||![v[@"status"]isKindOfClass:NSNumber.class]){[self finish:c result:nil error:OR6APIError(@"unknown_wire_shape",@"none")];return;}
  NSInteger status=[v[@"status"]integerValue];if(status==404&&[op isEqual:@"library.get"]&&![r.URL.path hasSuffix:@"/node"]){completion(v,nil);return;}if(status!=200){[self finish:c result:nil error:OR6APIError(status==404?@"not_found":@"upstream_error",@"none")];return;}completion(v,nil);
 }];[self adopt:task serial:serial call:c];
}
- (void)detail:(NSString*)identifier call:(CCall*)c completion:(OR6APIReply)completion{
 [self request:@"library.get"parameters:@{@"libraryId":identifier}cursor:nil call:c completion:^(NSDictionary*v,NSError*unused){
  (void)unused;NSError*error=nil;BOOL node=NO;for(NSString*p in @[@"libfile_fde1_",@"libfile_fde2_",@"libfile_fde3_"])if([identifier hasPrefix:p])node=YES;
  // First-party vvmK.js: a normal detail404 falls back once to the node endpoint.
  // Never take this path for transport/auth/challenge errors, or recurse after node404.
  if([v[@"status"]integerValue]==404&&!node){
   [self request:@"library.node" parameters:@{@"libraryId":identifier} cursor:nil call:c completion:^(NSDictionary*nv,NSError*ne){
    (void)ne;NSError*decode=nil;NSDictionary*item=OR6API7CItem(nv[@"json"],YES,identifier,&decode);if(!item)[self finish:c result:nil error:decode];else completion(item,nil);
   }];return;
  }
  NSDictionary*item=OR6API7CItem(v[@"json"],node,identifier,&error);if(!item)[self finish:c result:nil error:error];else completion(item,nil);
 }];
}
- (NSDictionary*)pageBinding:(CCall*)c{NSMutableDictionary*b=[[c->p mutableCopy]autorelease];[b removeObjectForKey:@"pageToken"];b[@"operation"]=c->op;return b;}
- (void)page:(CCall*)c{
 NSDictionary*binding=[self pageBinding:c];id token=c->p[@"pageToken"];NSDictionary*previous=token!=NSNull.null?_pages[token]:nil;
 if(token!=NSNull.null&&(!previous||![previous[@"binding"]isEqual:binding])){[self finish:c result:nil error:OR6APIError(@"invalid_request",@"none")];return;}
 NSString*cursor=previous[@"cursor"];
 [self request:c->op parameters:c->p cursor:cursor call:c completion:^(NSDictionary*v,NSError*unused){
  (void)unused;NSError*error=nil;NSDictionary*page=OR6API7CPage(v[@"json"],[c->p[@"limit"]unsignedIntegerValue],&error);if(!page){[self finish:c result:nil error:error];return;}
  id next=NSNull.null;NSString*server=page[@"cursor"]==NSNull.null?nil:page[@"cursor"];
  if(server){NSMutableArray*seen=[NSMutableArray arrayWithArray:previous[@"seen"]?:@[]];if(cursor)[seen addObject:cursor];
   if([seen containsObject:server]||seen.count>=128){[self finish:c result:nil error:OR6APIError(@"unknown_wire_shape",@"none")];return;}
   if(_pages.count>=128){[self finish:c result:nil error:OR6APIError(@"size_limit",@"none")];return;}next=ID();_pages[next]=@{@"binding":binding,@"cursor":server,@"seen":seen};
  }
  [self finish:c result:@{@"items":page[@"items"],@"nextPageToken":next}error:nil];
 }];
}
- (BOOL)canResolveRemoteAsset:(NSString*)identifier{return OR6API7CHandle(identifier);}
- (NSDictionary*)remoteAsset:(NSString*)identifier draft:(NSString*)draft context:(NSDictionary*)ctx error:(NSError**)error{
 NSDictionary*r=OR6API7CHandle(identifier)?_handles[identifier]:nil;NSTimeInterval now=_clock(),age=now-[r[@"checkedAt"]doubleValue];
 if(!NSThread.isMainThread||!r||![r[@"draft"]isEqual:draft]||![r[@"context"]isEqual:ctx]||![_scope isEqual:ctx[@"key"]]||_epoch!=[ctx[@"generation"]unsignedIntegerValue]){if(error)*error=OR6APIError(@"invalid_operation_state",@"none");return nil;}
 if(!isfinite(now)||age<0||age>300){if(error)*error=OR6APIError(@"expired",@"none");return nil;}return r[@"asset"];
}
- (void)releaseRemoteDraft:(NSString*)draft context:(NSDictionary*)ctx{for(NSString*k in [[_handles.allKeys copy]autorelease])if([_handles[k][@"draft"]isEqual:draft]&&[_handles[k][@"context"]isEqual:ctx])[_handles removeObjectForKey:k];}
- (NSError*)selectionError:(CCall*)c{
 NSString*old=c->p[@"replaceAssetId"]==NSNull.null?nil:c->p[@"replaceAssetId"];
 for(CCall*other in _calls)if(other!=c&&[other->op isEqual:@"library.attach"]&&[other->p[@"draftId"]isEqual:c->p[@"draftId"]]&&[other->p[@"libraryId"]isEqual:c->p[@"libraryId"]])return OR6APIError(@"conflict",@"none");
 for(NSString*k in _handles)if(![k isEqual:old]&&[_handles[k][@"draft"]isEqual:c->p[@"draftId"]]&&[_handles[k][@"item"][@"id"]isEqual:c->p[@"libraryId"]])return OR6APIError(@"conflict",@"none");
 if(_handles.count>=128&&(!old||!_handles[old]))return OR6APIError(@"size_limit",@"none");return nil;
}
- (void)attach:(CCall*)c{
 NSError*selectionError=[self selectionError:c];if(selectionError){[self finish:c result:nil error:selectionError];return;}
 NSString*old=c->p[@"replaceAssetId"]==NSNull.null?nil:c->p[@"replaceAssetId"];
 [self detail:c->p[@"libraryId"]call:c completion:^(NSDictionary*item,NSError*unused){
  NSError*selectionError=[self selectionError:c];if(selectionError){[self finish:c result:nil error:selectionError];return;}
  (void)unused;NSString*handle=[@"library:"stringByAppendingString:ID()];NSError*error=nil;NSDictionary*asset=OR6API7CAsset(item,handle,&error);NSTimeInterval now=_clock();
  if(!asset||!isfinite(now)){[self finish:c result:nil error:error?:OR6APIError(@"unavailable",@"none")];return;}
  _handles[handle]=@{@"asset":asset,@"item":item,@"draft":c->p[@"draftId"],@"context":c->ctx,@"checkedAt":@(now)};NSUInteger serial=++c->serial;__block BOOL delivered=NO;
  id<OR6APITask>task=[_next execute:@"assets.attach"parameters:@{@"draftId":c->p[@"draftId"],@"assetId":handle,@"replaceAssetId":c->p[@"replaceAssetId"]}context:c->ctx event:nil completion:^(NSDictionary*r,NSError*e){
   if(delivered||![self current:c])return;delivered=YES;if(e)[_handles removeObjectForKey:handle];else if(old)[_handles removeObjectForKey:old];[self finish:c result:r error:e];
  }];[self adopt:task serial:serial call:c];
 }];
}
- (void)refresh:(NSArray*)ids index:(NSUInteger)index call:(CCall*)c{
 if(index==ids.count){[self finish:c result:@{@"ready":@YES}error:nil];return;}NSString*handle=ids[index];NSDictionary*record=_handles[handle];
 if(!record||![record[@"draft"]isEqual:c->p[@"draftId"]]||![record[@"context"]isEqual:c->ctx]){[self finish:c result:nil error:OR6APIError(@"invalid_operation_state",@"none")];return;}
 [self detail:record[@"item"][@"id"]call:c completion:^(NSDictionary*item,NSError*unused){
  (void)unused;if(![item[@"canAttach"]isEqual:@YES]||![OR6API7BDigest(item)isEqual:OR6API7BDigest(record[@"item"])]){[self finish:c result:nil error:OR6APIError(@"conflict",@"none")];return;}
  NSTimeInterval now=_clock();if(!isfinite(now)){[self finish:c result:nil error:OR6APIError(@"unavailable",@"none")];return;}NSMutableDictionary*r=[[record mutableCopy]autorelease];r[@"checkedAt"]=@(now);_handles[handle]=r;[self refresh:ids index:index+1 call:c];
 }];
}
- (id<OR6APITask>)execute:(NSString*)op parameters:(NSDictionary*)p context:(NSDictionary*)ctx event:(OR6APIEvent)event completion:(OR6APIReply)reply{
 if(!NSThread.isMainThread||!Context(ctx)){reply(nil,OR6APIError(@"invalid_request",@"none"));return nil;}
 if(![_scope isEqual:ctx[@"key"]]||_epoch!=[ctx[@"generation"]unsignedIntegerValue]){[self deactivate];[_scope release];_scope=[ctx[@"key"]copy];_epoch=[ctx[@"generation"]unsignedIntegerValue];}
 BOOL own=OR6API7CCommand(op);if(!own){if([op isEqual:@"auth.logout"])[self deactivate];return[_next execute:op parameters:p context:ctx event:event completion:reply];}
 if((own&&!OR6APISchemaCheck(p,_operations[op][@"requestSchema"],_extension[@"types"]))||!OR6APIJSONSnapshot(p,512*1024)){reply(nil,OR6APIError(@"invalid_request",@"none"));return nil;}
 if(![_caps containsObject:op]){reply(nil,OR6APIError(@"capability_unverified",@"none"));return nil;}if(_calls.count>=8){reply(nil,OR6APIError(@"unavailable",@"none"));return nil;}
 CCall*c=[[[CCall alloc]init]autorelease];c->owner=self;c->op=[op copy];c->p=[OR6APIJSONSnapshot(p,512*1024)retain];c->ctx=[OR6APIJSONSnapshot(ctx,4096)retain];c->reply=[reply copy];[_calls addObject:c];
 if([@[@"library.list",@"library.search",@"library.conversationFiles"]containsObject:op])[self page:c];
 else if([op isEqual:@"library.get"])[self detail:p[@"libraryId"]call:c completion:^(NSDictionary*r,NSError*e){[self finish:c result:r error:e];}];
 else if([op isEqual:@"library.attach"])[self attach:c];
 else{NSDictionary*record=_handles[p[@"assetId"]];if(!OR6API7CHandle(p[@"assetId"])||![record[@"draft"]isEqual:p[@"draftId"]]||![record[@"context"]isEqual:ctx])[self finish:c result:nil error:OR6APIError(@"not_found",@"none")];else{
  NSUInteger serial=++c->serial;id<OR6APITask>task=[_next execute:@"assets.detach"parameters:p context:ctx event:nil completion:^(NSDictionary*r,NSError*e){if(![self current:c])return;if(!e)[_handles removeObjectForKey:p[@"assetId"]];[self finish:c result:r error:e];}];[self adopt:task serial:serial call:c];
 }}return c;
}
- (id<OR6APITask>)prepareRemoteAssets:(NSArray*)ids draft:(NSString*)draft context:(NSDictionary*)ctx completion:(OR6APIReply)completion{
 if(!NSThread.isMainThread||!Context(ctx)||![ids isKindOfClass:NSArray.class]||!ids.count||ids.count>4||[[NSSet setWithArray:ids]count]!=ids.count||![draft isKindOfClass:NSString.class]||!draft.length||draft.length>128){completion(nil,OR6APIError(@"invalid_request",@"none"));return nil;}
 if(![_caps containsObject:@"library.attach"]){completion(nil,OR6APIError(@"capability_unverified",@"none"));return nil;}
 if(![_scope isEqual:ctx[@"key"]]||_epoch!=[ctx[@"generation"]unsignedIntegerValue]||_calls.count>=8){completion(nil,OR6APIError(@"invalid_operation_state",@"none"));return nil;}
 for(NSString*i in ids)if(!OR6API7CHandle(i)){completion(nil,OR6APIError(@"invalid_request",@"none"));return nil;}
 CCall*c=[[[CCall alloc]init]autorelease];c->owner=self;c->op=[@"library.refresh"copy];c->p=[@{@"draftId":draft,@"attachments":ids}copy];c->ctx=[OR6APIJSONSnapshot(ctx,4096)retain];c->reply=[completion copy];[_calls addObject:c];[self refresh:ids index:0 call:c];return c;
}
- (void)didValidate:(NSString*)op result:(NSDictionary*)r context:(NSDictionary*)ctx{if([op isEqual:@"assets.detach"]&&[r[@"detached"]isEqual:@YES])[_handles removeObjectForKey:r[@"assetId"]];if([_next respondsToSelector:_cmd])[_next didValidate:op result:r context:ctx];}
- (void)releaseCompletedDraft:(NSString*)draft context:(NSDictionary*)ctx{[self releaseRemoteDraft:draft context:ctx];if([_next respondsToSelector:_cmd])[_next releaseCompletedDraft:draft context:ctx];}
- (NSDictionary*)diagnostics{return@{@"activeCount":@(_calls.count),@"selections":@(_handles.count),@"pageTokens":@(_pages.count),@"readRequests":@(_requests),@"uploads":@0,@"credentialsExposed":@NO};}
- (void)dealloc{[self deactivate];if(_media.remoteAssets==self)[_media setRemoteAssets:nil];[_next release];[_HTTP release];[_media release];[_extension release];[_operations release];[_caps release];[_calls release];[_handles release];[_pages release];[_scope release];[_clock release];[super dealloc];}
@end
