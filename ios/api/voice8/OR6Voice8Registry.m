#import "OR6Voice8.h"
static NSDictionary *Text(BOOL nullable,NSUInteger max){return@{@"type":nullable?@[@"string",@"null"]:@"string",@"minLength":@1,@"maxLength":@(max)};}
static NSDictionary *Obj(NSDictionary*p,NSArray*r){return@{@"type":@"object",@"properties":p,@"required":r,@"additionalProperties":@NO};}
NSDictionary *OR6Voice8Registry(NSDictionary *base){
 NSMutableDictionary*r=[[base mutableCopy]autorelease],*types=[[base[@"types"]mutableCopy]autorelease];NSMutableArray*ops=[NSMutableArray array];
 NSArray*names=@[@"voice.start",@"voice.state",@"voice.submit",@"voice.interrupt",@"voice.mute",@"voice.end",@"voice.resume"];
 for(NSDictionary*o in base[@"operations"])if(![names containsObject:o[@"id"]])[ops addObject:o];
 NSDictionary*identifier=Text(NO,128),*nullable=Text(YES,128),*boolean=@{@"type":@"boolean"};
 NSDictionary*line=Obj(@{@"role":@{@"enum":@[@"user",@"assistant"]},@"text":@{@"type":@"string",@"maxLength":@16000}},@[@"role",@"text"]);
 NSDictionary*p=@{@"sessionId":identifier,@"state":@{@"enum":@[@"listening",@"sending",@"thinking",@"speaking",@"reconnecting",@"paused",@"ended",@"failed"]},@"microphoneMuted":boolean,@"outputMuted":boolean,@"canResume":boolean,@"sequence":@{@"type":@"integer",@"minimum":@0,@"maximum":@2147483647},@"conversationId":nullable,@"issue":@{@"type":@"string",@"maxLength":@128},@"uncertain":boolean,@"transcript":@{@"type":@"array",@"maxItems":@128,@"items":line},@"mode":@{@"enum":@[@"turn_based"]}};
 types[@"Voice8State"]=Obj(p,p.allKeys);
 for(NSString*n in names){NSDictionary*request=nil;
  if([n isEqual:@"voice.start"])request=Obj(@{@"operationId":identifier,@"conversationId":nullable,@"voiceId":@{@"type":@"null"},@"modelId":identifier,@"thinkingEffort":Text(YES,64)},@[@"operationId",@"conversationId",@"voiceId"]);
  else if([n isEqual:@"voice.mute"])request=Obj(@{@"sessionId":identifier,@"microphoneMuted":boolean,@"outputMuted":boolean},@[@"sessionId",@"microphoneMuted",@"outputMuted"]);
  else if([n isEqual:@"voice.resume"])request=Obj(@{@"operationId":identifier,@"sessionId":identifier},@[@"operationId",@"sessionId"]);
  else request=Obj(@{@"sessionId":identifier},@[@"sessionId"]);
  [ops addObject:@{@"id":n,@"requestSchema":request,@"responseSchema":@{@"$ref":@"#/types/Voice8State"},@"events":@[],@"execution":@"native",@"transport":@"local_composition",@"notes":@"Turn-based kit adaptation; current-account dictation/chat/read-aloud, no realtime session claim."}];
 }
 NSDictionary*features=@{@"voice.conversation":@[@"voice.start",@"voice.submit",@"voice.state"],@"voice.interrupt":@[@"voice.interrupt"],@"voice.mute":@[@"voice.mute"],@"voice.end":@[@"voice.end"],@"voice.resume":@[@"voice.resume"],@"voice.connection_recovery":@[@"voice.state",@"voice.resume"]};
 NSMutableArray*map=[NSMutableArray array];for(NSDictionary*f in base[@"featureMap"])if(!features[f[@"featureId"]])[map addObject:f];for(NSString*f in features)[map addObject:@{@"featureId":f,@"operations":features[f]}];r[@"featureMap"]=map;
 r[@"operations"]=ops;r[@"types"]=types;
 return OR6APIJSONSnapshot(r,4*1024*1024);
}
