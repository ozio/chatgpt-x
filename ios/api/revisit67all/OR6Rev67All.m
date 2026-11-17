#import "OR6Rev67All.h"
#import "../revisit67local/OR6Rev67Local.h"
#import "../revisit67content/OR6Rev67Content.h"
#import "../revisit67account/OR6Rev67Account.h"
#import "../priority8/OR6API8Media.h"
#import "../../OR6Files.h"
NSDictionary *OR6Rev67AllRegistry(NSDictionary *base,NSError **error){
 if(![base isKindOfClass:NSDictionary.class]){if(error)*error=OR6APIError(@"invalid_request",@"none");return nil;}
 NSDictionary *r=OR6Rev67LocalRegistry(base,error);
 if(r)r=OR6Rev67ContentRegistry(r,error);
 if(r)r=OR6Rev67AccountRegistry(r,error);
 if(!r)return nil;
 NSDictionary*fileSchema=nil;for(NSDictionary*op in r[@"operations"])if([op[@"id"]isEqual:@"projects.filesAdd"])fileSchema=op[@"requestSchema"][@"properties"][@"files"][@"items"];
 if(!fileSchema){if(error)*error=OR6APIError(@"invalid_request",@"none");return nil;}
 NSMutableDictionary*result=[[r mutableCopy]autorelease];NSMutableArray*ops=[[r[@"operations"]mutableCopy]autorelease];
 [ops addObject:@{@"id":@"projects.uploads.list",@"requestSchema":@{@"type":@"object",@"properties":@{},@"required":@[],@"additionalProperties":@NO},@"responseSchema":@{@"type":@"object",@"properties":@{@"items":@{@"type":@"array",@"items":fileSchema,@"maxItems":@128}},@"required":@[@"items"],@"additionalProperties":@NO},@"events":@[]}];result[@"operations"]=ops;
 NSMutableArray*map=[NSMutableArray array];for(NSDictionary*f in r[@"featureMap"]){if([f[@"featureId"]isEqual:@"projects.files"]){NSMutableDictionary*updated=[[f mutableCopy]autorelease];updated[@"operations"]=[f[@"operations"]arrayByAddingObject:@"projects.uploads.list"];[map addObject:updated];}else[map addObject:f];}result[@"featureMap"]=map;
 return OR6APIJSONSnapshot(result,4*1024*1024);
}
NSDictionary *OR6Rev67AllTiers(void){
 NSMutableDictionary *r=[NSMutableDictionary dictionaryWithDictionary:OR6Rev67LocalTiers()];
 r[@"projects.uploads.list"]=@"local";[r addEntriesFromDictionary:OR6Rev67ContentTiers()];[r addEntriesFromDictionary:OR6Rev67AccountTiers()];
 return [[r copy]autorelease];
}
@implementation OR6Rev67AllCore
- (id<OR6APITask>)perform:(NSString *)op parameters:(NSDictionary *)p event:(OR6APIEvent)event completion:(OR6APIReply)reply{
 // Snapshot before dispatch: a caller mutating a mutable NSString cannot change
 // how the eventual cancellation is classified.
 NSString *command=[op isKindOfClass:NSString.class]?[[op copy]autorelease]:nil;
 BOOL mutation=command&&OR6Rev67ContentMutation(command);
 return [super perform:command parameters:p event:event completion:^(NSDictionary *r,NSError *e){
  if(mutation&&[@[@"cancelled",@"stale_context",@"invalid_response"]containsObject:e.userInfo[@"code"]]&&[e.userInfo[@"dispatch"]isEqual:@"none"])e=OR6APIError(e.userInfo[@"code"],@"possible");
  if(reply)reply(r,e);
 }];
}
@end
@interface OR6Rev67AllObserver(){id<OR6APIProvider> _next;OR6Rev67LocalProvider *_local;OR6API8Media *_media;OR6Files *_vault;BOOL(^_projectBinder)(NSArray*,NSDictionary*);}
@end
@implementation OR6Rev67AllObserver
- (id)initWithNext:(id<OR6APIProvider>)next local:(OR6Rev67LocalProvider *)local media:(OR6API8Media *)media vault:(OR6Files *)vault{
 if((self=[super init])){if(!next||!local||!media||!vault){[self release];return nil;}_next=[next retain];_local=[local retain];_media=[media retain];_vault=[vault retain];}return self;
}
- (void)setProjectUploadBinder:(BOOL(^)(NSArray*,NSDictionary*))binder{[_projectBinder release];_projectBinder=[binder copy];}
- (id<OR6APITask>)execute:(NSString *)op parameters:(NSDictionary *)p context:(NSDictionary *)ctx event:(OR6APIEvent)event completion:(OR6APIReply)reply{
 if(![_media bindContext:ctx]){if(reply)reply(nil,OR6APIError(@"invalid_request",@"none"));return nil;}
 if([@[@"projects.uploads.list",@"projects.filesAdd"]containsObject:op]){
  NSError*error=nil;NSArray*files=[_media uploadedProjectFilesForContext:ctx error:&error];
  if(!files){if(reply)reply(nil,error);return nil;}
  if([op isEqual:@"projects.uploads.list"]){if(reply)reply(@{@"items":files},nil);return nil;}
  NSMutableArray*selected=[NSMutableArray array];
  for(NSDictionary*requested in p[@"files"]){NSDictionary*matched=nil;for(NSDictionary*actual in files)if([actual isEqual:requested]){matched=actual;break;}if(!matched){if(reply)reply(nil,OR6APIError(@"owner_mismatch",@"none"));return nil;}[selected addObject:matched];}
  if(!_projectBinder||!_projectBinder(selected,ctx)){if(reply)reply(nil,OR6APIError(@"capability_unverified",@"none"));return nil;}
 }
 return [_next execute:op parameters:p context:ctx event:event completion:reply];
}
- (void)didValidate:(NSString *)op result:(NSDictionary *)r context:(NSDictionary *)ctx{
 if([_next respondsToSelector:_cmd])[_next didValidate:op result:r context:ctx];
 if([@[@"messages.newDraft",@"projects.newDraft"]containsObject:op]&&[r[@"draftId"]isKindOfClass:NSString.class])[_local bindDraft:r[@"draftId"]context:ctx];
 if([@[@"assets.acquire",@"assets.upload",@"assets.download",@"images.resize",@"images.sketch",@"images.annotate",@"images.mask.create"]containsObject:op]&&[r[@"assetId"]isKindOfClass:NSString.class]){
  NSDictionary *asset=[_vault assetForID:r[@"assetId"]error:NULL];if(asset)[_local bindAssets:@[asset]context:ctx];
 }
 // Only a completed, validated reply may trigger an opt-in local notice. No
 // polling, background network claim, message body or temporary text is stored.
 if([@[@"messages.send",@"messages.edit",@"messages.regenerate",@"messages.retry",@"projects.send",@"tools.deepResearch",@"tools.dataAnalysis",@"images.create",@"chat.continue"]containsObject:op]&&[r[@"state"]isEqual:@"completed"]&&[r[@"assistantMessageId"]isKindOfClass:NSString.class]){
  [_local execute:@"notifications.local.preferences.get"parameters:@{}context:ctx event:nil completion:^(NSDictionary *prefs,NSError *error){
   if(error||![prefs[@"enabled"]isEqual:@YES])return;
   NSString *token=[_local bindCompletedResponse:r[@"assistantMessageId"]context:ctx];
   if(token)[_local execute:@"notifications.local.presentCompletion"parameters:@{@"completionToken":token}context:ctx event:nil completion:^(NSDictionary *notice,NSError *e){(void)notice;(void)e;}];
  }];
 }
}
- (void)releaseCompletedDraft:(NSString *)draft context:(NSDictionary *)ctx{if([_next respondsToSelector:_cmd])[_next releaseCompletedDraft:draft context:ctx];}
- (void)dealloc{[_next release];[_local release];[_media release];[_vault release];[_projectBinder release];[super dealloc];}
@end
