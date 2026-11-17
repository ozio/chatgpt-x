#import "Policy.h"
#import "../../ios/api/priority7/OR6API7Policy.h"
#import "../../ios/api/priority7f/OR6API7FPolicy.h"
BOOL OR6Live7Allowed(NSURLRequest*r,NSString*cid,NSString*sid){
 if(!OR6API7UUID(cid)||(!OR6API7AllowedRequest(r)&&!OR6API7FAllowedRequest(r)))return NO;
 NSString*p=r.URL.path,*m=r.HTTPMethod;
 if([p isEqual:[@"/backend-api/conversation/"stringByAppendingString:cid]]||[p isEqual:[@"/backend-api/conversation/id/"stringByAppendingString:cid]]||[p isEqual:[NSString stringWithFormat:@"/backend-api/conversation/id/%@/rename",cid]]||[p isEqual:[NSString stringWithFormat:@"/backend-api/conversation/%@/stream_status",cid]])return YES;
 if(OR6API7UUID(sid)&&[p isEqual:[@"/backend-api/share/"stringByAppendingString:sid]])return YES;
 if([m isEqual:@"GET"])return [@[@"/backend-api/conversations",@"/backend-api/pins",@"/backend-api/models",@"/backend-api/system_hints"]containsObject:p];
 if([@[@"/backend-api/share/v2/create",@"/backend-api/stop_conversation"]containsObject:p]){id b=[NSJSONSerialization JSONObjectWithData:r.HTTPBody options:0 error:NULL];return [b[@"conversation_id"]isEqual:cid];}
 return NO;
}
NSDictionary*OR6Live7Limits(void){return @{@"ownDiagnostics":@1,@"streamStatus":@1,@"catalog":@1,@"seed":@1,@"readback":@12,@"rename":@1,@"renameBack":@1,@"pin":@1,@"unpin":@1,@"archive":@1,@"unarchive":@1,@"share":@1,@"shareGet":@1,@"shareGetAfterFix":@1,@"revoke":@1,@"shareGone":@1,@"delete":@1,@"verifyDeleted":@1,@"pins":@2,@"archives":@2,@"analysis":@1,@"analysisResult":@1,@"study":@1,@"image":@1,@"imageDownload":@1,@"imageCleanup":@1,@"research":@1,@"researchStatus":@2,@"researchCancel":@1,@"continue":@1,@"reconcile":@8};}
BOOL OR6Live7Mutation(NSString*op){return [op isEqual:@"messages.send"]||OR6API7Mutation(op)||OR6API7FMutation(op);}
BOOL OR6Live7ResumeValid(id s,NSString*run){
 if(![s isKindOfClass:NSDictionary.class]||!OR6API7UUID(run)||![s[@"runId"]isEqual:run]||![s[@"marker"]isEqual:[@"ChatGPT X API7 acceptance "stringByAppendingString:run]]||!OR6API7UUID(s[@"conversationId"])||s[@"stopCode"])return NO;
 id counts=s[@"counts"],seed=s[@"steps"][@"seed"];if(![counts isKindOfClass:NSDictionary.class]||![seed isKindOfClass:NSDictionary.class]||![counts[@"seed"]isEqual:@1]||![seed[@"completed"]isEqual:@YES]||![seed[@"result"][@"persisted"]isEqual:@YES]||![seed[@"result"][@"conversationId"]isEqual:s[@"conversationId"]])return NO;
 for(NSString*k in counts){NSNumber*limit=OR6Live7Limits()[k],*v=counts[k];if(!limit||![v isKindOfClass:NSNumber.class]||v.integerValue<0||v.unsignedIntegerValue>limit.unsignedIntegerValue)return NO;}
 return YES;
}

BOOL OR6Live7NeedsReconcile(NSString*op,BOOL possible,NSUInteger before,NSUInteger after,NSUInteger writes){return possible&&OR6Live7Mutation(op)&&(after>before||writes>0);}
BOOL OR6Live7Reconciled(NSDictionary*r,NSString*op){return OR6API7UUID(op)&&[r[@"operationId"]isEqual:op]&&([r[@"verified"]isEqual:@YES]||([r[@"state"]isEqual:@"completed"]&&[r[@"persisted"]isEqual:@YES]));}
BOOL OR6Live7OwnRecovery(id s,NSString*cid,NSString*uid,NSString*scope,NSString*marker){
 if(![s isKindOfClass:NSDictionary.class]||!OR6API7UUID(cid)||!OR6API7UUID(uid)||!scope.length||!marker.length)return NO;
 if(![s[@"request"]isKindOfClass:NSDictionary.class])return NO;id text=s[@"request"][@"text"];
 return OR6API7UUID(s[@"operationId"])&&[s[@"conversationId"]isEqual:cid]&&[s[@"userMessageId"]isEqual:uid]&&[s[@"scope"]isEqual:scope]&&[text isKindOfClass:NSString.class]&&[text hasPrefix:[marker stringByAppendingString:@". This is a temporary software acceptance test."]];
}
