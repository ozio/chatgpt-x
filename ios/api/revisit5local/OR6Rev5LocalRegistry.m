#import "OR6Rev5Local.h"
static NSDictionary *Obj(NSDictionary *p){return @{@"type":@"object",@"properties":p,@"required":p.allKeys,@"additionalProperties":@NO};}
static NSDictionary *S(NSUInteger max){return @{@"type":@"string",@"minLength":@1,@"maxLength":@(max)};}
static NSDictionary *N(NSUInteger max){return @{@"type":@[@"string",@"null"],@"maxLength":@(max)};}
static NSDictionary *Time(void){return @{@"type":@"number",@"minimum":@0,@"maximum":@4102444800};}
static NSDictionary *Item(NSString *kind){
 NSMutableDictionary *p=[NSMutableDictionary dictionaryWithDictionary:@{@"id":S(512),@"title":@{@"type":@"string",@"maxLength":@1024},@"calendarId":S(512),@"truncated":@{@"type":@"boolean"}}];
 if([kind isEqual:@"event"])[p addEntriesFromDictionary:@{@"start":Time(),@"end":Time(),@"allDay":@{@"type":@"boolean"},@"notes":N(4096),@"location":N(1024)}];
 else if([kind isEqual:@"reminder"])[p addEntriesFromDictionary:@{@"due":@{@"type":@[@"number",@"null"],@"minimum":@0,@"maximum":@4102444800},@"completed":@{@"type":@"boolean"},@"notes":N(4096)}];
 return Obj(p);
}
static NSDictionary *ListItem(void){return Obj(@{@"id":S(512),@"title":@{@"type":@"string",@"maxLength":@1024},@"writable":@{@"type":@"boolean"},@"truncated":@{@"type":@"boolean"}});}
static NSDictionary *Video(void){return Obj(@{@"duration":@{@"type":@"number",@"minimum":@0.01,@"maximum":@600},@"width":@{@"type":@"integer",@"minimum":@1,@"maximum":@1920},@"height":@{@"type":@"integer",@"minimum":@1,@"maximum":@1920}});}
static NSDictionary *Playback(void){return Obj(@{@"assetId":S(128),@"state":@{@"enum":@[@"idle",@"preparing",@"playing",@"paused",@"stopped",@"failed"]},@"position":@{@"type":@"number",@"minimum":@0,@"maximum":@600},@"duration":@{@"type":@"number",@"minimum":@0.01,@"maximum":@600}});}
NSDictionary *OR6Rev5LocalOperations(void){
 NSDictionary *empty=Obj(@{}),*access=Obj(@{@"access":@{@"enum":@[@"read",@"write"]},@"confirmed":@{@"enum":@[@YES]}}),*revoke=Obj(@{@"access":@{@"enum":@[@"read",@"write",@"all"]}}),*bounds=Obj(@{@"from":Time(),@"to":Time(),@"limit":@{@"type":@"integer",@"minimum":@1,@"maximum":@100}}),*idOnly=Obj(@{@"assetId":S(128)}),*confirmed=@{@"enum":@[@YES]};
 return @{@"device.calendar.access.get":empty,@"device.calendar.access.request":access,@"device.calendar.access.revoke":revoke,@"device.reminders.access.get":empty,@"device.reminders.access.request":access,@"device.reminders.access.revoke":revoke,
 @"device.calendar.events.list":bounds,@"device.calendar.event.create":Obj(@{@"operationId":S(36),@"title":S(1024),@"start":Time(),@"end":Time(),@"allDay":@{@"type":@"boolean"},@"notes":N(4096),@"location":N(1024),@"confirmed":confirmed}),
 @"device.reminders.lists":empty,@"device.reminders.items.list":bounds,@"device.reminders.item.create":Obj(@{@"operationId":S(36),@"title":S(1024),@"due":@{@"type":@[@"number",@"null"],@"minimum":@0,@"maximum":@4102444800},@"notes":N(4096),@"listId":N(512),@"confirmed":confirmed}),@"device.reminders.list.create":Obj(@{@"operationId":S(36),@"title":S(1024),@"confirmed":confirmed}),@"device.localOperation.reconcile":Obj(@{@"operationId":S(36)}),
 @"media.recentPhoto.get":empty,@"media.video.capture":empty,@"media.video.get":idOnly,@"media.video.play":idOnly,@"media.video.pause":idOnly,@"media.video.seek":Obj(@{@"assetId":S(128),@"position":@{@"type":@"number",@"minimum":@0,@"maximum":@600}}),@"media.video.stop":idOnly,@"media.video.savePhotos":Obj(@{@"assetId":S(128),@"operationId":S(36),@"confirmed":confirmed}),
 @"preferences.helpAbout.get":empty,@"preferences.helpAbout.open":Obj(@{@"kind":@{@"enum":@[@"help",@"faq",@"terms",@"privacy"]}})};
}
NSDictionary *OR6Rev5LocalResponse(NSString *op){
 if([op hasSuffix:@".access.get"]||[op hasSuffix:@".access.request"]||[op hasSuffix:@".access.revoke"])return Obj(@{@"read":@{@"type":@"boolean"},@"write":@{@"type":@"boolean"},@"system":@{@"enum":@[@"not_determined",@"restricted",@"denied",@"authorized"]},@"systemPermissionRevoked":@{@"enum":@[@NO]}});
 if([@[@"device.calendar.events.list",@"device.reminders.items.list",@"device.reminders.lists"]containsObject:op])return Obj(@{@"items":@{@"type":@"array",@"maxItems":@100,@"items":[op isEqual:@"device.reminders.lists"]?ListItem():Item([op isEqual:@"device.calendar.events.list"]?@"event":@"reminder")},@"hasMore":@{@"type":@"boolean"}});
 if(OR6Rev5LocalMutation(op)||[op isEqual:@"device.localOperation.reconcile"])return Obj(@{@"operationId":S(36),@"kind":@{@"enum":@[@"event",@"reminder",@"reminder_list",@"video_save"]},@"state":@{@"enum":@[@"completed",@"uncertain"]},@"itemId":N(512),@"verified":@{@"type":@"boolean"}});
 if([op isEqual:@"media.recentPhoto.get"])return Obj(@{@"assetId":S(128),@"takenAt":@{@"type":@[@"number",@"null"],@"minimum":@0,@"maximum":@4102444800},@"submitted":@{@"enum":@[@NO]}});
 if([op isEqual:@"media.video.capture"])return Obj(@{@"assetId":S(128),@"video":Video(),@"submitted":@{@"enum":@[@NO]}});
 if([op hasPrefix:@"media.video."])return Obj(@{@"video":Video(),@"playback":Playback()});
 if([op isEqual:@"preferences.helpAbout.open"])return Obj(@{@"kind":S(32),@"url":S(512),@"completed":@{@"enum":@[@NO]}});
 if([op isEqual:@"preferences.helpAbout.get"])return Obj(@{@"version":S(64),@"bundleId":S(128),@"links":@{@"type":@"array",@"maxItems":@4,@"items":Obj(@{@"kind":S(32),@"url":S(512),@"completed":@{@"enum":@[@NO]}})}});
 return nil;
}
BOOL OR6Rev5LocalMutation(NSString *op){return[@[@"device.calendar.event.create",@"device.reminders.item.create",@"device.reminders.list.create",@"media.video.savePhotos"]containsObject:op];}
NSDictionary *OR6Rev5LocalTiers(void){NSMutableDictionary *t=[NSMutableDictionary dictionary];for(NSString *op in OR6Rev5LocalOperations())t[op]=[op isEqual:@"preferences.helpAbout.open"]?@"handoff":@"local";return[[t copy]autorelease];}
NSDictionary *OR6Rev5LocalRegistry(NSDictionary *base,NSError **error){
 if(![base isKindOfClass:NSDictionary.class]||![base[@"operations"]isKindOfClass:NSArray.class]||![base[@"featureMap"]isKindOfClass:NSArray.class]||![base[@"types"]isKindOfClass:NSDictionary.class]){if(error)*error=OR6APIError(@"invalid_request",@"none");return nil;}
 for(id f in base[@"featureMap"])if(![f isKindOfClass:NSDictionary.class]||![f[@"featureId"]isKindOfClass:NSString.class]||![f[@"operations"]isKindOfClass:NSArray.class]){if(error)*error=OR6APIError(@"invalid_request",@"none");return nil;}
 NSMutableSet *ids=[NSMutableSet set];for(id o in base[@"operations"]){if(![o isKindOfClass:NSDictionary.class]||![o[@"id"]isKindOfClass:NSString.class]||[ids containsObject:o[@"id"]]){if(error)*error=OR6APIError(@"invalid_request",@"none");return nil;}[ids addObject:o[@"id"]];}
 NSMutableArray *ops=[[base[@"operations"]mutableCopy]autorelease];for(NSString *op in [[OR6Rev5LocalOperations()allKeys]sortedArrayUsingSelector:@selector(compare:)]){if([ids containsObject:op]){if(error)*error=OR6APIError(@"conflict",@"none");return nil;}[ops addObject:@{@"id":op,@"requestSchema":OR6Rev5LocalOperations()[op],@"responseSchema":OR6Rev5LocalResponse(op),@"events":@[]}];}
 NSMutableDictionary *features=[NSMutableDictionary dictionaryWithDictionary:@{@"media.recent_photo":@[@"media.recentPhoto.get"],@"media.capture_video":@[@"media.video.capture"],@"media.preview_video":@[@"media.video.get",@"media.video.play",@"media.video.pause",@"media.video.seek",@"media.video.stop",@"media.video.savePhotos",@"device.localOperation.reconcile"],@"integration.calendar_read":@[@"device.calendar.access.get",@"device.calendar.access.request",@"device.calendar.access.revoke",@"device.calendar.events.list"],@"integration.calendar_create":@[@"device.calendar.access.get",@"device.calendar.access.request",@"device.calendar.access.revoke",@"device.calendar.event.create",@"device.localOperation.reconcile"],@"integration.reminders_read":@[@"device.reminders.access.get",@"device.reminders.access.request",@"device.reminders.access.revoke",@"device.reminders.lists",@"device.reminders.items.list"],@"integration.reminders_create":@[@"device.reminders.access.get",@"device.reminders.access.request",@"device.reminders.access.revoke",@"device.reminders.item.create",@"device.reminders.list.create",@"device.localOperation.reconcile"],@"preferences.help_about":@[@"preferences.helpAbout.get",@"preferences.helpAbout.open"]}];
 if([ids containsObject:@"images.annotate"])features[@"media.annotate_photo"]=@[@"images.annotate"];
 if([ids containsObject:@"notifications.local.preferences.get"]&&[ids containsObject:@"notifications.local.preferences.set"])features[@"images.generation_notifications"]=@[@"notifications.local.preferences.get",@"notifications.local.preferences.set"];
 NSMutableArray *map=[NSMutableArray array];for(NSDictionary *f in base[@"featureMap"])if(!features[f[@"featureId"]])[map addObject:f];for(NSString *fid in [[features allKeys]sortedArrayUsingSelector:@selector(compare:)])[map addObject:@{@"featureId":fid,@"operations":features[fid]}];
 NSMutableDictionary *result=[[base mutableCopy]autorelease];result[@"operations"]=ops;result[@"featureMap"]=map;return OR6APIJSONSnapshot(result,4*1024*1024);
}
