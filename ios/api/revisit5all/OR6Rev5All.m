#import "OR6Rev5All.h"
#import "../revisit5asr/OR6Rev5ASR.h"
#import <dispatch/dispatch.h>
#import "../revisit5local/OR6Rev5Local.h"
#import "../revisit5content/OR6Rev5Content.h"
#import "../revisit5system/OR6Rev5System.h"
#import "../priority5a/OR6API5APolicy.h"
#import "../priority5b/OR6API5BPolicy.h"
#import "../priority5c/OR6API5CPolicy.h"
#import "../priority5d/OR6API5DPolicy.h"
#import "../priority5e/OR6API5EPolicy.h"
#import "../priority6a/OR6API6APolicy.h"
#import "../priority6b/OR6API6BPolicy.h"
#import "../priority6c/OR6API6CPolicy.h"
#import "../priority6d/OR6API6DPolicy.h"
#import "../priority6e/OR6API6EPolicy.h"
#import "../priority6f/OR6API6FPolicy.h"
#import "../priority7/OR6API7Policy.h"
#import "../priority7b/OR6API7BPolicy.h"
#import "../priority7d/OR6API7DPolicy.h"
#import "../priority7e/OR6API7EPolicy.h"
#import "../priority7f/OR6API7FPolicy.h"
#import "../revisit67content/OR6Rev67Content.h"
NSDictionary *OR6Rev5AllRegistry(NSDictionary *base,NSError **error){NSDictionary*r=OR6Rev5LocalRegistry(base,error);if(r)r=OR6Rev5ContentRegistry(r,error);if(r)r=OR6Rev5SystemRegistry(r,error);if(r)r=OR6Rev5ASRRegistry(r,error);return r;}
NSDictionary *OR6Rev5AllTiers(void){NSMutableDictionary*r=[NSMutableDictionary dictionaryWithDictionary:OR6Rev5LocalTiers()];[r addEntriesFromDictionary:OR6Rev5ContentTiers()];[r addEntriesFromDictionary:OR6Rev5SystemTiers()];[r addEntriesFromDictionary:OR6Rev5ASRTiers()];return[[r copy]autorelease];}
static BOOL LegacyMutation(NSString *op){return OR6API5AMutation(op)||OR6API5BMutation(op)||OR6API5CMutation(op)||OR6API5DMutation(op)||OR6API5EMutation(op);}
NSDictionary *OR6Rev5LegacyCapabilities(NSDictionary *extensions){
 if(![extensions isKindOfClass:NSDictionary.class])return nil;
 NSMutableDictionary *caps=[NSMutableDictionary dictionary];
 for(NSString *module in @[@"5a",@"5b",@"5c",@"5d",@"5e"]){
  NSDictionary *extension=extensions[module];if(![extension isKindOfClass:NSDictionary.class])return nil;NSArray *ops=extension[@"operations"];if(![ops isKindOfClass:NSArray.class])return nil;NSMutableSet *values=[NSMutableSet set];
  for(id entry in ops){if(![entry isKindOfClass:NSDictionary.class])return nil;NSDictionary *op=entry;NSString *value=[@[@"5c",@"5e"]containsObject:module]?op[@"capability"]:op[@"id"];if(![value isKindOfClass:NSString.class]||!value.length)return nil;[values addObject:value];}
  caps[module]=[NSSet setWithSet:values];
 }
 return[[caps copy]autorelease];
}
NSDictionary *OR6Rev5LegacyTiers(NSDictionary *extensions){
 if(!OR6Rev5LegacyCapabilities(extensions))return nil;
 NSSet *local=[NSSet setWithArray:@[@"chat.copyMarkdown",@"compose.suggestions.select",@"study.deck.grid",@"study.card.draft",@"study.card.draft.get",@"study.session.start",@"study.session.get",@"study.session.undo",@"study.session.shuffle",@"study.session.orientation",@"study.session.flip",@"study.session.rate",@"study.session.restart",@"preferences.start_screen.get",@"preferences.start_screen.set",@"preferences.spelling.get",@"preferences.spelling.set",@"safety.study_hours.new_chat"]];
 NSSet *handoff=[NSSet setWithArray:@[@"security.sms.open",@"security.advanced.open"]];NSMutableDictionary *tiers=[NSMutableDictionary dictionary];
 for(NSString *module in @[@"5a",@"5b",@"5c",@"5d",@"5e"])for(NSDictionary *op in extensions[module][@"operations"]){NSString *name=op[@"id"];tiers[name]=[local containsObject:name]?@"local":[handoff containsObject:name]?@"handoff":LegacyMutation(name)||[name isEqual:@"language.block.translate"]?@"user_action":@"candidate_read";}
 return[[tiers copy]autorelease];
}
static BOOL InheritedMutation(NSString*op,NSDictionary*p){
 return OR6API6AMutation(op)||OR6API6BMutation(op)||OR6API6CMutation(op)||OR6API6DMutation(op)||OR6API6EMutation(op)||OR6API6FMutation(op)||OR6API7Mutation(op)||OR6API7BMutation(op)||OR6API7DMutation(op)||OR6API7EMutation(op)||OR6API7FMutation(op)||OR6Rev67ContentMutation(op)||([op isEqual:@"images.export"]&&[p[@"destination"]isEqual:@"photos"])||[@[@"messages.send",@"messages.edit",@"messages.regenerate",@"messages.retry",@"assets.upload",@"assets.processing.resume",@"dictation.transcribe",@"messages.stop",@"dictation.retry",@"translation.translate",@"search.web",@"assets.download",@"assets.attach",@"assets.detach",@"library.attach",@"library.detach",@"projects.newDraft",@"skills.install",@"skills.remove",@"audio.readAloud",@"compose.autocomplete.get",@"compose.workPrediction.get"]containsObject:op];
}
@implementation OR6Rev5AllCore{NSDictionary*(^_live)(void);}
- (void)setLiveContextSource:(NSDictionary*(^)(void))source{[_live release];_live=[source copy];}
- (id<OR6APITask>)perform:(NSString *)op parameters:(NSDictionary *)p event:(OR6APIEvent)event completion:(OR6APIReply)reply{
 if(!NSThread.isMainThread){if(reply)dispatch_async(dispatch_get_main_queue(),^{reply(nil,OR6APIError(@"invalid_request",@"none"));});return nil;}
 NSString *command=[op isKindOfClass:NSString.class]?[[op copy]autorelease]:nil;
 NSString*expected=[[_context[@"key"]copy]autorelease];BOOL auth=[command hasPrefix:@"auth."];NSDictionary*live=_live?_live():nil;NSString*expectedUser=[live[@"userId"]isKindOfClass:NSString.class]?[[live[@"userId"]copy]autorelease]:nil;
 if(command&&!auth&&_live&&(![live[@"valid"]isEqual:@YES]||![live[@"key"]isEqual:expected])){if(reply)reply(nil,OR6APIError(@"stale_context",@"none"));return nil;}
 BOOL mutation=command&&(InheritedMutation(command,p)||LegacyMutation(command)||OR6Rev5LocalMutation(command)||OR6Rev5ContentMutation(command)||OR6Rev5SystemMutation(command));NSUInteger generation=_generation;
 return[super perform:command parameters:p event:event?^(NSDictionary*value){NSDictionary*current=_live?_live():nil;if(!_live||auth||([current[@"valid"]isEqual:@YES]&&[current[@"key"]isEqual:expected]))event(value);}:nil completion:^(NSDictionary *result,NSError *error){
  if(generation!=_generation){result=nil;error=OR6APIError(@"stale_context",mutation||[error.userInfo[@"dispatch"]isEqual:@"possible"]?@"possible":@"none");}
  if(mutation&&[@[@"cancelled",@"stale_context",@"invalid_response"]containsObject:error.userInfo[@"code"]]&&[error.userInfo[@"dispatch"]isEqual:@"none"])error=OR6APIError(error.userInfo[@"code"],@"possible");
  NSDictionary*current=_live?_live():nil;
  BOOL selected=expectedUser&&[current[@"userId"]isEqual:expectedUser]&&[command isEqual:@"workspaces.select"]&&[result[@"selected"]isEqual:@YES]&&[current[@"valid"]isEqual:@YES]&&[current[@"accountId"]isEqual:result[@"selectedWorkspaceId"]];
  if(_live&&!auth&&!selected&&(![current[@"valid"]isEqual:@YES]||![current[@"key"]isEqual:expected])){result=nil;error=OR6APIError(@"stale_context",mutation||[error.userInfo[@"dispatch"]isEqual:@"possible"]?@"possible":@"none");}
  if(reply)reply(result,error);
 }];
}
- (void)dealloc{[_live release];[super dealloc];}
@end
