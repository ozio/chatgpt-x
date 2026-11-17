#import "OR6CodexTranscript.h"
#import "OR6CodexPolicy8.h"
static NSString*Key(NSString*t,NSString*u,NSString*i){return[NSString stringWithFormat:@"%lu:%@%lu:%@%@",(unsigned long)t.length,t,(unsigned long)u.length,u,i];}
@implementation OR6CodexTranscript
- (id)init{if((self=[super init])){_items=[NSMutableDictionary new];_turns=[NSMutableDictionary new];_diffs=[NSMutableDictionary new];_plans=[NSMutableDictionary new];_order=[NSMutableArray new];_complete=[NSMutableSet new];_hydrated=[NSMutableSet new];_gaps=[NSMutableDictionary new];}return self;}
- (NSUInteger)revision{return _revision;}
- (void)invalidate{[_hydrated removeAllObjects];_revision++;}
- (void)reset{[_items removeAllObjects];[_turns removeAllObjects];[_diffs removeAllObjects];[_plans removeAllObjects];[_order removeAllObjects];[_complete removeAllObjects];[_hydrated removeAllObjects];[_gaps removeAllObjects];_revision++;}
- (void)trim{while(_order.count>64){NSString*k=[[_order[0]retain]autorelease];[_items removeObjectForKey:k];[_complete removeObject:k];[_order removeObjectAtIndex:0];}if(_turns.count>32)[_turns removeObjectForKey:_turns.allKeys[0]];while(_gaps.count>64)[_gaps removeObjectForKey:_gaps.allKeys[0]];while(_hydrated.count>64)[_hydrated removeObject:_hydrated.anyObject];if(_plans.count>8)[_plans removeObjectForKey:_plans.allKeys[0]];if(_diffs.count>8)[_diffs removeObjectForKey:_diffs.allKeys[0]];}
- (BOOL)put:(NSDictionary*)i thread:(NSString*)t turn:(NSString*)u complete:(BOOL)done{
 if(!OR6CodexID(t)||!OR6CodexID(u)||!OR6CodexID(i[@"id"]))return NO;
 if([i[@"type"]isEqual:@"userMessage"]){if(!OR6APIJSONSnapshot(i,262144))return NO;NSMutableArray*content=[NSMutableArray array];for(NSDictionary*c in i[@"content"]){NSString*url=[c[@"url"]isKindOfClass:NSString.class]?c[@"url"]:nil;if([c[@"type"]isEqual:@"image"]&&[url hasPrefix:@"data:image/"]&&url.length>32768){NSMutableDictionary*image=[[c mutableCopy]autorelease];image[@"url"]=@"";image[@"reviveInlineImageOmitted"]=@YES;image[@"reviveInlineImageSHA256"]=OR6CodexDigest(url);[content addObject:image];}else[content addObject:c];}NSMutableDictionary*bounded=[[i mutableCopy]autorelease];bounded[@"content"]=content;i=bounded;}
 if(!OR6APIJSONSnapshot(i,65536))return NO;NSString*k=Key(t,u,i[@"id"]);if(![_order containsObject:k])[_order addObject:k];_items[k]=@{@"threadId":t,@"turnId":u,@"item":i,@"revision":@(_revision+1)};if(done)[_complete addObject:k];[self trim];_revision++;return YES;
}
- (BOOL)mergeItems:(NSArray*)a thread:(NSString*)t beforeRevision:(NSUInteger)revision{
 if(![a isKindOfClass:NSArray.class]||a.count>100)return NO;
 for(NSDictionary*r in a){NSString*k=Key(t,r[@"turnId"],r[@"item"][@"id"]);if([_items[k][@"revision"]unsignedIntegerValue]>revision)continue;
 // History entries can belong to the active turn, so hydration alone does not
 // make an item terminal. A later completed event remains authoritative.
 if(![self put:r[@"item"]thread:t turn:r[@"turnId"]complete:NO])return NO;}
 if([_gaps[t]unsignedIntegerValue]<=revision){[_gaps removeObjectForKey:t];[_hydrated addObject:t];}return YES;
}
- (BOOL)mergeTurns:(NSArray*)a thread:(NSString*)t beforeRevision:(NSUInteger)revision{if(![a isKindOfClass:NSArray.class]||a.count>100)return NO;for(NSDictionary*r in a){if(!OR6CodexID(r[@"id"]))return NO;NSMutableDictionary*metadata=[[r mutableCopy]autorelease];metadata[@"items"]=@[];if(!OR6APIJSONSnapshot(metadata,8192))return NO;NSString*turnKey=Key(t,r[@"id"],@"");if([_turns[turnKey][@"revision"]unsignedIntegerValue]<=revision)_turns[turnKey]=@{@"threadId":t,@"turn":metadata,@"revision":@(_revision+1)};for(NSDictionary*i in r[@"items"]){NSString*k=Key(t,r[@"id"],i[@"id"]);if([_items[k][@"revision"]unsignedIntegerValue]>revision)continue;if(![self put:i thread:t turn:r[@"id"]complete:![r[@"status"]isEqual:@"inProgress"]])return NO;}}[self trim];_revision++;return YES;}
- (BOOL)consume:(NSString*)m parameters:(NSDictionary*)p{
 NSString*t=p[@"threadId"],*u=p[@"turnId"];
 if([m isEqual:@"item/started"]&&[_complete containsObject:Key(t,u,p[@"item"][@"id"])])return YES;
 if([m isEqual:@"item/started"]||[m isEqual:@"item/completed"])return[self put:p[@"item"]thread:t turn:u complete:[m isEqual:@"item/completed"]];
 if([m isEqual:@"turn/started"]||[m isEqual:@"turn/completed"])return[self mergeTurns:@[p[@"turn"]]thread:t beforeRevision:NSUIntegerMax];
 if([m isEqual:@"turn/diff/updated"]){if(!OR6CodexText(p[@"diff"],131072,YES)||[p[@"diff"]lengthOfBytesUsingEncoding:NSUTF8StringEncoding]>131072)return NO;_diffs[Key(t,u,@"")]=@{@"threadId":t,@"turnId":u,@"diff":p[@"diff"]};[self trim];_revision++;return YES;}
 if([m isEqual:@"turn/plan/updated"]){if(!OR6APIJSONSnapshot(p,16384))return NO;_plans[Key(t,u,@"")]=p;[self trim];_revision++;return YES;}
 NSString*field=nil;if([m isEqual:@"item/agentMessage/delta"]||[m isEqual:@"item/plan/delta"])field=@"text";else if([m isEqual:@"item/commandExecution/outputDelta"]||[m isEqual:@"item/fileChange/outputDelta"])field=@"aggregatedOutput";
 if(field){NSString*k=Key(t,u,p[@"itemId"]);NSDictionary*row=_items[k];if([_complete containsObject:k])return YES;if(!row){_gaps[t]=@(++_revision);[self trim];return YES;}NSMutableDictionary*i=[[row[@"item"]mutableCopy]autorelease];NSString*text=i[field];if(![text isKindOfClass:NSString.class])text=@"";NSString*delta=p[@"delta"];if(!OR6CodexText(delta,65536,YES))return NO;NSString*joined=[text stringByAppendingString:delta];BOOL truncated=joined.length>8192;if(truncated){NSUInteger start=joined.length-8192;NSRange cluster=[joined rangeOfComposedCharacterSequenceAtIndex:start];if(cluster.location<start)start=NSMaxRange(cluster);joined=[joined substringFromIndex:start];}i[field]=joined;if(truncated)i[@"reviveOutputTruncated"]=@YES;return[self put:i thread:t turn:u complete:NO];}
 if([m isEqual:@"item/fileChange/patchUpdated"]){NSString*k=Key(t,u,p[@"itemId"]);NSDictionary*r=_items[k];if(r&&![_complete containsObject:k]){NSMutableDictionary*i=[[r[@"item"]mutableCopy]autorelease];i[@"changes"]=p[@"changes"];return[self put:i thread:t turn:u complete:NO];}_gaps[t]=@(++_revision);}
 return YES;
}
- (NSDictionary*)snapshot:(NSString*)t{NSMutableArray*items=[NSMutableArray array],*turns=[NSMutableArray array],*diffs=[NSMutableArray array],*plans=[NSMutableArray array];for(NSString*k in _order)if([_items[k][@"threadId"]isEqual:t])[items addObject:_items[k]];for(NSDictionary*r in _turns.allValues)if([r[@"threadId"]isEqual:t])[turns addObject:r[@"turn"]];for(NSDictionary*r in _diffs.allValues)if([r[@"threadId"]isEqual:t])[diffs addObject:r];for(NSDictionary*r in _plans.allValues)if([r[@"threadId"]isEqual:t])[plans addObject:r];return OR6APIJSONSnapshot(@{@"plans":plans,@"items":items,@"turns":turns,@"diffs":diffs,@"needsReadback":@(![_hydrated containsObject:t]||_gaps[t]!=nil),@"revision":@(_revision)},6*1024*1024);}
- (void)dealloc{[_items release];[_turns release];[_diffs release];[_plans release];[_order release];[_complete release];[_hydrated release];[_gaps release];[super dealloc];}
@end
