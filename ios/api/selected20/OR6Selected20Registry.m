#import "OR6Selected20.h"
static NSDictionary *Obj(NSDictionary *p,NSArray *required){return @{ @"type":@"object",@"properties":p,@"required":required,@"additionalProperties":@NO};}
static NSDictionary *Text(NSUInteger n,BOOL nullable){return @{ @"type":nullable?@[@"string",@"null"]:(id)@"string",@"maxLength":@(n)};}
static NSDictionary *Op(NSString *name,NSDictionary *request,NSDictionary *response){return @{ @"id":name,@"requestSchema":request,@"responseSchema":response,@"events":@[]};}
NSDictionary *OR6Selected20Tiers(void){return @{ @"chat.copyMarkdown":@"local",@"compose.suggestions":@"candidate_read",@"compose.suggestions.select":@"local",@"compose.autocomplete.get":@"user_action",@"compose.autocomplete.select":@"local",@"skills.list":@"candidate_read",@"skills.get":@"candidate_read",@"skills.install":@"user_action",@"skills.remove":@"user_action",@"skills.reconcile":@"candidate_read",@"skills.pending":@"local",@"images.library":@"candidate_read",@"images.library.open":@"candidate_read",@"images.gallery.prepare":@"local",@"audio.readAloud":@"user_action",@"codex.home":@"candidate_read",@"codex.task.get":@"candidate_read",@"codex.environment.get":@"candidate_read",@"compose.workPrediction.get":@"user_action",@"compose.workPrediction.select":@"local"};}
NSDictionary *OR6Selected20Registry(NSDictionary *base,NSDictionary *five,NSDictionary *four,NSError **error){
 if(![base[@"operations"]isKindOfClass:NSArray.class]||![base[@"types"]isKindOfClass:NSDictionary.class]||![five[@"operations"]isKindOfClass:NSArray.class]||![four[@"operations"]isKindOfClass:NSArray.class]){if(error)*error=OR6APIError(@"invalid_request",@"none");return nil;}
 NSMutableDictionary *r=[[base mutableCopy]autorelease],*types=[[base[@"types"]mutableCopy]autorelease];NSMutableArray *ops=[[base[@"operations"]mutableCopy]autorelease];NSMutableSet *ids=[NSMutableSet set];for(NSDictionary *o in ops)[ids addObject:o[@"id"]];
 // Full API5 may already own the three unchanged 5A operations/types. The
 // Selected20 provider still handles these first, preserving its current UI.
 NSSet *shared=[NSSet setWithArray:@[@"chat.copyMarkdown",@"compose.suggestions",@"compose.suggestions.select"]];
 for(NSDictionary *x in @[five,four]){
  for(NSString *k in x[@"types"]){if(types[k]){if(x==five&&[types[k]isEqual:x[@"types"][k]])continue;if(error)*error=OR6APIError(@"conflict",@"none");return nil;}types[k]=x[@"types"][k];}
  for(NSDictionary *o in x[@"operations"]){if(!OR6Selected20Tiers()[o[@"id"]])continue;if([ids containsObject:o[@"id"]]){NSDictionary *existing=nil;for(NSDictionary *v in ops)if([v[@"id"]isEqual:o[@"id"]]){existing=v;break;}if(x==five&&[shared containsObject:o[@"id"]]&&[existing isEqual:o])continue;if(error)*error=OR6APIError(@"conflict",@"none");return nil;}[ops addObject:o];[ids addObject:o[@"id"]];}
 }
 // This read-only catalog does not claim a trusted safety policy or permit skill execution.
 NSMutableDictionary *skill=[[types[@"API4BSkill"]mutableCopy]autorelease],*sp=[[skill[@"properties"]mutableCopy]autorelease];sp[@"safety"]=@{@"enum":@[@"allowed",@"blocked",@"needsReview",@"unknown"]};skill[@"properties"]=sp;types[@"API4BSkill"]=skill;
 NSDictionary *asset=Text(128,NO),*identifier=Text(128,NO),*play=@{@"$ref":@"#/types/API7GPlayback"};
 NSDictionary *item=Obj(@{@"id":identifier,@"title":Text(2048,NO),@"status":Text(128,YES),@"environmentId":Text(128,YES)},@[@"id",@"title",@"status",@"environmentId"]),*env=Obj(@{@"id":identifier,@"label":Text(2048,NO)},@[@"id",@"label"]);
 NSArray *added=@[
 Op(@"skills.pending",Obj(@{@"skillId":identifier},@[@"skillId"]),Obj(@{@"operationId":Text(36,YES)},@[@"operationId"])),
 Op(@"images.gallery.prepare",Obj(@{@"assetId":asset},@[@"assetId"]),Obj(@{@"assetId":asset,@"available":@{@"enum":@[@YES]}},@[@"assetId",@"available"])),
 Op(@"images.library.open",Obj(@{@"libraryId":identifier},@[@"libraryId"]),Obj(@{@"assetId":asset,@"available":@{@"enum":@[@YES]}},@[@"assetId",@"available"])),
 Op(@"images.library",Obj(@{@"pageToken":Text(128,YES)},@[@"pageToken"]),@{@"$ref":@"#/types/API6CNodes"}),
 Op(@"audio.readAloud",Obj(@{@"conversationId":Text(36,NO),@"messageId":Text(36,NO)},@[@"conversationId",@"messageId"]),Obj(@{@"assetId":asset,@"playback":play},@[@"assetId",@"playback"])),
 Op(@"codex.home",Obj(@{@"pageToken":Text(4096,YES)},@[@"pageToken"]),Obj(@{@"items":@{@"type":@"array",@"maxItems":@100,@"items":item},@"environments":@{@"type":@"array",@"maxItems":@200,@"items":env},@"nextPageToken":Text(4096,YES),@"context":@{@"enum":@[@"cloud"]}},@[@"items",@"environments",@"nextPageToken",@"context"])),
 Op(@"codex.task.get",Obj(@{@"taskId":identifier},@[@"taskId"]),Obj(@{@"id":identifier,@"title":Text(2048,NO),@"status":Text(128,YES),@"environmentId":Text(128,YES),@"summary":Text(32768,NO)},@[@"id",@"title",@"status",@"environmentId",@"summary"])),
 Op(@"codex.environment.get",Obj(@{@"environmentId":identifier},@[@"environmentId"]),Obj(@{@"id":identifier,@"label":Text(2048,NO),@"description":Text(32768,NO)},@[@"id",@"label",@"description"])),
 Op(@"compose.workPrediction.get",Obj(@{@"conversationId":Text(36,NO),@"expectedMessageId":Text(36,YES),@"generationTrigger":@{@"enum":@[@"live",@"catch_up"]}},@[@"conversationId",@"expectedMessageId",@"generationTrigger"]),Obj(@{@"responseId":Text(128,NO),@"suggestion":Text(16000,YES)},@[@"responseId",@"suggestion"])),
 Op(@"compose.workPrediction.select",Obj(@{@"responseId":Text(128,NO)},@[@"responseId"]),Obj(@{@"text":Text(16000,NO),@"completed":@{@"enum":@[@NO]},@"submitted":@{@"enum":@[@NO]}},@[@"text",@"completed",@"submitted"]))];
 for(NSDictionary *o in added){if([ids containsObject:o[@"id"]]){if(error)*error=OR6APIError(@"conflict",@"none");return nil;}[ops addObject:o];}
 NSDictionary*features=@{@"chat.copy_markdown":@[@"chat.copyMarkdown"],@"compose.suggestions":@[@"compose.suggestions",@"compose.suggestions.select"],@"compose.autocomplete":@[@"compose.autocomplete.get",@"compose.autocomplete.select"],@"compose.work_prediction":@[@"compose.workPrediction.get",@"compose.workPrediction.select"],@"tools.skills":@[@"skills.list",@"skills.get",@"skills.install",@"skills.remove",@"skills.reconcile",@"skills.pending"],@"audio.read_aloud":@[@"audio.readAloud"],@"images.library":@[@"images.library",@"images.library.open"],@"images.gallery":@[@"images.gallery.prepare"],@"codex.home":@[@"codex.home",@"codex.task.get",@"codex.environment.get"]};
 NSMutableArray*map=[NSMutableArray array];for(NSDictionary*f in base[@"featureMap"])if(!features[f[@"featureId"]])[map addObject:f];for(NSString*f in [[features allKeys]sortedArrayUsingSelector:@selector(compare:)])[map addObject:@{@"featureId":f,@"operations":features[f]}];r[@"featureMap"]=map;
 r[@"types"]=types;r[@"operations"]=ops;return OR6APIJSONSnapshot(r,4*1024*1024);
}
