#import "OR6ChatNativePolicy.h"
#import <CommonCrypto/CommonDigest.h>
BOOL OR6CNUUID(id s){return[s isKindOfClass:NSString.class]&&[s length]==36&&[[NSRegularExpression regularExpressionWithPattern:@"^[a-fA-F0-9]{8}(-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}$"options:0 error:NULL]numberOfMatchesInString:s options:0 range:NSMakeRange(0,[s length])]==1;}
BOOL OR6CNSameUUID(id a,id b){return OR6CNUUID(a)&&OR6CNUUID(b)&&[a caseInsensitiveCompare:b]==NSOrderedSame;}
NSString *OR6CNHash(NSString*s){if(![s isKindOfClass:NSString.class])return nil;NSData*d=[s dataUsingEncoding:NSUTF8StringEncoding];unsigned char hash[CC_SHA256_DIGEST_LENGTH];CC_SHA256(d.bytes,(CC_LONG)d.length,hash);NSMutableString*r=[NSMutableString string];for(NSUInteger i=0;i<sizeof(hash);i++)[r appendFormat:@"%02x",hash[i]];return r;}
NSDictionary *OR6CNHeaders(id v){
 if(![v isKindOfClass:NSDictionary.class]||![v count]||[v count]>4)return nil;
 NSSet*allowed=[NSSet setWithArray:@[@"OpenAI-Sentinel-Chat-Requirements-Prepare-Token",@"OpenAI-Sentinel-Chat-Requirements-Token",@"OpenAI-Sentinel-Proof-Token",@"OpenAI-Sentinel-Turnstile-Token"]];
 for(id key in v){id value=v[key];if(![allowed containsObject:key]||![value isKindOfClass:NSString.class]||![value length]||[value length]>32768||[value rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound)return nil;}
 if(!v[@"OpenAI-Sentinel-Chat-Requirements-Prepare-Token"]&&!v[@"OpenAI-Sentinel-Chat-Requirements-Token"])return nil;
 return[[v copy]autorelease];
}
NSDictionary *OR6CNBody(NSString*text,NSString*uid,NSString*parent,NSString*cid,NSString*model){
 if(![text isKindOfClass:NSString.class]||!text.length||text.length>16000||!OR6CNUUID(uid)||!OR6CNUUID(parent)||(cid&&!OR6CNUUID(cid))||![model isKindOfClass:NSString.class]||!model.length||model.length>256)return nil;
 NSMutableDictionary*b=[NSMutableDictionary dictionaryWithDictionary:@{@"action":@"next",@"messages":@[@{@"id":uid.lowercaseString,@"author":@{@"role":@"user"},@"content":@{@"content_type":@"text",@"parts":@[text]},@"metadata":@{}}],@"parent_message_id":parent.lowercaseString,@"model":model,@"supported_encodings":@[@"v1"],@"client_prepare_state":@"none",@"conversation_mode":@{@"kind":@"primary_assistant"}}];
 if(cid)b[@"conversation_id"]=cid.lowercaseString;return[[b copy]autorelease];
}
NSString *OR6CNReadback(NSDictionary*c,NSString*cid,NSString*uid,NSString*aid,NSString*hash){
 if(!OR6CNUUID(cid)||!OR6CNUUID(uid)||(aid&&!OR6CNUUID(aid))||![c isKindOfClass:NSDictionary.class]||!OR6CNSameUUID(c[@"id"],cid)||![c[@"messages"]isKindOfClass:NSArray.class]||[c[@"messages"]count]>2048||![hash isKindOfClass:NSString.class]||hash.length!=64)return nil;
 BOOL user=NO;for(id m in c[@"messages"]){if(![m isKindOfClass:NSDictionary.class])return nil;
  if(OR6CNSameUUID(m[@"id"],uid)&&[m[@"role"]isEqual:@"user"]&&[OR6CNHash(m[@"text"])isEqual:hash]){if(user)return nil;user=YES;continue;}
  if(!user)continue;if([m[@"role"]isEqual:@"user"])return nil;
  if([m[@"role"]isEqual:@"assistant"]&&[m[@"finished"]isEqual:@YES]&&OR6CNUUID(m[@"id"])&&(!aid||OR6CNSameUUID(aid,m[@"id"])))return m[@"id"];
 }return nil;
}
NSString *OR6CNPlanReadback(NSDictionary*c,NSString*cid,NSString*uid,NSString*hash){
 if(![c isKindOfClass:NSDictionary.class]||![c[@"messages"]isKindOfClass:NSArray.class]||[c[@"messages"]count]>2048)return nil;
 BOOL turn=NO;NSString*aid=nil;for(id m in c[@"messages"]){if(![m isKindOfClass:NSDictionary.class])return nil;if(OR6CNSameUUID(m[@"id"],uid)&&[m[@"role"]isEqual:@"user"]){if(turn)return nil;turn=YES;continue;}if(!turn)continue;if([m[@"role"]isEqual:@"user"])break;if([m[@"role"]isEqual:@"assistant"]){id end=m[@"endTurn"];BOOL terminal=!end||end==NSNull.null||[end isEqual:@YES];aid=[m[@"finished"]isEqual:@YES]&&terminal&&OR6CNUUID(m[@"id"])?m[@"id"]:nil;}}
 return aid?OR6CNReadback(c,cid,uid,aid,hash):nil;
}
NSDictionary *OR6CNRecoveryMessage(NSDictionary*c,NSString*cid,NSString*uid,NSString*aid,NSString*hash){
 if(!OR6CNUUID(cid)||!OR6CNUUID(uid)||!OR6CNUUID(aid)||![c isKindOfClass:NSDictionary.class]||!OR6CNSameUUID(c[@"id"],cid)||![c[@"messages"]isKindOfClass:NSArray.class]||[c[@"messages"]count]>2048||![hash isKindOfClass:NSString.class]||hash.length!=64)return nil;
 BOOL user=NO;NSDictionary*found=nil;
 for(id m in c[@"messages"]){if(![m isKindOfClass:NSDictionary.class])return nil;
  if(OR6CNSameUUID(m[@"id"],uid)&&[m[@"role"]isEqual:@"user"]){if(user||![OR6CNHash(m[@"text"])isEqual:hash])return nil;user=YES;continue;}
  if(!user)continue;if([m[@"role"]isEqual:@"user"])break;
  if(OR6CNSameUUID(m[@"id"],aid)&&[m[@"role"]isEqual:@"assistant"]){if(found||![m[@"text"]isKindOfClass:NSString.class]||[m[@"text"]length]>262144||!([m[@"finished"]isEqual:@YES]||[m[@"finished"]isEqual:@NO]))return nil;found=m;}
 }return found;
}
NSTimeInterval OR6CNRecoveryDelay(NSUInteger completedReads){static const NSTimeInterval delays[]={2,4,8,16,24};return completedReads>=1&&completedReads<=5?delays[completedReads-1]:-1;}
