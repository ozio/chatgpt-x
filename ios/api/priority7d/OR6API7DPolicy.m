#import "OR6API7DPolicy.h"
#import "../priority7/OR6API7Policy.h"
#import "../priority8/OR6API8Policy.h"
#include <string.h>
static id Fail(NSError**e,NSString*c){if(e)*e=OR6APIError(c,@"none");return nil;}
static BOOL S(id s,NSUInteger max){return[s isKindOfClass:NSString.class]&&[s length]&&[s length]<=max&&[s rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location==NSNotFound;}
static BOOL N(id n,unsigned long long max){return OR6APISchemaCheck(n,@{@"type":@"integer",@"minimum":@0,@"maximum":@(max)},@{});}
static BOOL SafeID(id s){return S(s,128)&&[s rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_- "]invertedSet]].location==NSNotFound&&[s rangeOfString:@" "].location==NSNotFound;}
BOOL OR6API7DProjectID(id s){return SafeID(s)&&[s hasPrefix:@"g-p-"]&&[s length]>4;}
BOOL OR6API7DCommand(NSString*o){return[@[@"projects.get",@"projects.conversations",@"projects.newDraft",@"projects.send",@"projects.moveConversation",@"projects.memoryGet",@"projects.memoryUpdate",@"projects.filesList",@"projects.filesAdd",@"projects.filesRemove",@"projects.reconcile",@"projects.reconcileChat"]containsObject:o];}
BOOL OR6API7DMutation(NSString*o){return[@[@"projects.send",@"projects.moveConversation",@"projects.memoryUpdate",@"projects.filesAdd",@"projects.filesRemove"]containsObject:o];}
NSDictionary*OR6API7DRegistry(NSDictionary*b,NSDictionary*x,NSError**e){
 if(![b[@"schemaVersion"]isEqual:@1]||![x[@"schemaVersion"]isEqual:@1]||![b[@"operations"]isKindOfClass:NSArray.class]||![x[@"operations"]isKindOfClass:NSArray.class]||![b[@"types"]isKindOfClass:NSDictionary.class]||![x[@"types"]isKindOfClass:NSDictionary.class]||![b[@"featureMap"]isKindOfClass:NSArray.class]||![x[@"featureMap"]isKindOfClass:NSArray.class])return Fail(e,@"invalid_request");
 NSMutableDictionary*r=[[b mutableCopy]autorelease],*types=[[b[@"types"]mutableCopy]autorelease];NSMutableArray*ops=[[b[@"operations"]mutableCopy]autorelease],*features=[[b[@"featureMap"]mutableCopy]autorelease];NSMutableSet*ids=[NSMutableSet set],*fids=[NSMutableSet set];
 for(NSDictionary*o in ops)[ids addObject:o[@"id"]];for(NSDictionary*f in features)[fids addObject:f[@"featureId"]];
 for(NSString*k in x[@"types"]){if(types[k])return Fail(e,@"conflict");types[k]=x[@"types"][k];}
 for(NSDictionary*o in x[@"operations"]){if(!OR6API7DCommand(o[@"id"])||[ids containsObject:o[@"id"]])return Fail(e,@"conflict");[ids addObject:o[@"id"]];[ops addObject:o];}
 for(NSDictionary*f in x[@"featureMap"]){if([fids containsObject:f[@"featureId"]])return Fail(e,@"conflict");[fids addObject:f[@"featureId"]];[features addObject:f];}
 r[@"types"]=types;r[@"operations"]=ops;r[@"featureMap"]=features;return OR6APIJSONSnapshot(r,4*1024*1024);
}
NSArray*OR6API7DFiles(id raw,NSError**e){
 if(![raw isKindOfClass:NSArray.class]||[raw count]>2000)return Fail(e,@"unknown_wire_shape");NSMutableArray*out=[NSMutableArray array];NSMutableSet*seen=[NSMutableSet set];
 for(id f in raw){if(![f isKindOfClass:NSDictionary.class]||!OR6API8RemoteID(f[@"file_id"])||[seen containsObject:f[@"file_id"]]||!S(f[@"name"],240)||!S(f[@"file_response_type"],64))return Fail(e,@"unknown_wire_shape");
  id library=f[@"library_file_id"]?:NSNull.null,mime=f[@"type"]?:NSNull.null,size=f[@"size"]?:NSNull.null;
  if((library!=NSNull.null&&!SafeID(library))||(mime!=NSNull.null&&!S(mime,128))||(size!=NSNull.null&&!N(size,1099511627776ULL)))return Fail(e,@"unknown_wire_shape");
  [seen addObject:f[@"file_id"]];[out addObject:@{@"fileId":f[@"file_id"],@"libraryFileId":library,@"name":f[@"name"],@"mediaType":mime,@"bytes":size,@"responseType":f[@"file_response_type"]}];
 }return out;
}
NSDictionary*OR6API7DProject(id raw,NSString*expected,NSError**e){
 if(![raw isKindOfClass:NSDictionary.class]||![raw[@"gizmo"]isKindOfClass:NSDictionary.class])return Fail(e,@"unknown_wire_shape");NSDictionary*g=raw[@"gizmo"],*d=g[@"display"],*author=g[@"author"];
 if(!OR6API7DProjectID(g[@"id"])||![g[@"id"]isEqual:expected]||![d isKindOfClass:NSDictionary.class]||!S(d[@"name"],240)||![author isKindOfClass:NSDictionary.class]||!S(author[@"user_id"],256))return Fail(e,@"unknown_wire_shape");
 if((g[@"gizmo_snorlax_type"]&&g[@"gizmo_snorlax_type"]!=NSNull.null)||(g[@"first_party_project_type"]&&g[@"first_party_project_type"]!=NSNull.null))return Fail(e,@"capability_unavailable");
 id sharing=g[@"sharing"];if(sharing&&sharing!=NSNull.null&&(![sharing isKindOfClass:NSDictionary.class]||![sharing[@"subjects"]isKindOfClass:NSArray.class]))return Fail(e,@"unknown_wire_shape");
 NSArray*files=OR6API7DFiles(raw[@"files"],e);if(!files)return nil;BOOL shared=![g[@"share_recipient"]isEqual:@"private"]||[raw[@"hasSharingSubjects"]isEqual:@YES]||(sharing!=NSNull.null&&[sharing[@"subjects"]count]>0);
 id ws=g[@"workspace_id"]?:NSNull.null;if(ws!=NSNull.null&&!S(ws,256))return Fail(e,@"unknown_wire_shape");
 NSString*scope=[g[@"memory_scope"]isEqual:@"project_v2"]?@"project-only":@"unknown";
 return@{@"projectId":g[@"id"],@"name":d[@"name"],@"memoryScope":scope,@"shared":@(shared),@"canWrite":@NO,@"fileCount":@(files.count),@"files":files,@"author":author[@"user_id"],@"workspace":ws,@"wire":@{@"name":d[@"name"],@"instructions":g[@"instructions"]?:@"",@"emoji":d[@"emoji"]?:NSNull.null,@"theme":d[@"theme"]?:NSNull.null}};
}
NSDictionary*OR6API7DConversation(id raw,NSString*expected,NSError**e){
 if(![raw isKindOfClass:NSDictionary.class]||![raw[@"conversation_id"]isEqual:expected]||!OR6API7UUID(expected))return Fail(e,@"unknown_wire_shape");
 if(![raw[@"owner"]isKindOfClass:NSDictionary.class])return Fail(e,@"owner_mismatch");
 for(NSString*k in @[@"is_read_only",@"is_temporary_chat",@"is_archived"])if(raw[k]&&!OR6APISchemaCheck(raw[k],@{@"type":@"boolean"},@{}))return Fail(e,@"unknown_wire_shape");
 if(raw[@"context_scopes"]&&![raw[@"context_scopes"]isKindOfClass:NSArray.class])return Fail(e,@"unknown_wire_shape");
 id project=raw[@"gizmo_id"]?:NSNull.null;if([project isEqual:@""])project=NSNull.null;if(project!=NSNull.null&&!OR6API7DProjectID(project))return Fail(e,@"capability_unavailable");
 if([raw[@"is_read_only"]isEqual:@YES]||[raw[@"is_temporary_chat"]isEqual:@YES]||[raw[@"is_archived"]isEqual:@YES]||([raw[@"conversation_origin"]isKindOfClass:NSString.class]&&[@[@"tpp",@"flora"]containsObject:raw[@"conversation_origin"]])||[raw[@"context_scopes"]count])return Fail(e,@"permission_denied");
 NSString*owner=raw[@"owner"][@"user_id"];if(!S(owner,256))return Fail(e,@"owner_mismatch");return@{@"projectId":project,@"owner":owner};
}
static NSString*Encode(NSString*s){NSData*d=[s dataUsingEncoding:NSUTF8StringEncoding];const unsigned char*p=d.bytes;NSMutableString*r=[NSMutableString string];for(NSUInteger i=0;i<d.length;i++){unsigned char c=p[i];if((c>='a'&&c<='z')||(c>='A'&&c<='Z')||(c>='0'&&c<='9')||strchr("-._~",c))[r appendFormat:@"%c",c];else[r appendFormat:@"%%%02X",c];}return r;}
NSURLRequest*OR6API7DRequest(NSString*op,NSDictionary*p,id body,NSString*cursor,NSError**e){
 id project=p[@"projectId"];NSString*path=nil,*method=@"GET";if(cursor&&!S(cursor,1024))return Fail(e,@"invalid_request");
 if([op isEqual:@"conversation.get"]||[op isEqual:@"projects.moveConversation"]){if(!OR6API7UUID(p[@"conversationId"]))return Fail(e,@"invalid_request");path=[@"/backend-api/conversation/"stringByAppendingString:p[@"conversationId"]];if([op isEqual:@"projects.moveConversation"]){if(project!=NSNull.null&&!OR6API7DProjectID(project))return Fail(e,@"invalid_request");method=@"PATCH";body=@{@"gizmo_id":project==NSNull.null?@"":project};}}
 else{if(!OR6API7DProjectID(project))return Fail(e,@"invalid_request");
  if([op isEqual:@"projects.conversations"]){if(!N(p[@"limit"],50)||![p[@"limit"]unsignedIntegerValue])return Fail(e,@"invalid_request");path=[NSString stringWithFormat:@"/backend-api/gizmos/%@/conversations?limit=%lu&owned_only=true%@",project,(unsigned long)[p[@"limit"]unsignedIntegerValue],cursor?[@"&cursor="stringByAppendingString:Encode(cursor)]:@""];}
  else if([op isEqual:@"projects.memoryUpdate"]){method=@"PATCH";path=[@"/backend-api/projects/"stringByAppendingString:project];}
  else if([op isEqual:@"projects.filesAdd"]){method=@"POST";path=[NSString stringWithFormat:@"/backend-api/projects/%@/files",project];}
  else if([op isEqual:@"projects.filesRemove"]){if(!OR6API8RemoteID(p[@"fileId"]))return Fail(e,@"invalid_request");method=@"DELETE";path=[NSString stringWithFormat:@"/backend-api/projects/%@/files/%@",project,p[@"fileId"]];}
  else if([@[@"projects.get",@"projects.memoryGet",@"projects.filesList",@"projects.newDraft",@"projects.send"]containsObject:op])path=[NSString stringWithFormat:@"/backend-api/gizmos/%@?include_file_limits=true",project];else return Fail(e,@"invalid_request");
 }
 NSMutableURLRequest*r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:[@"https://chatgpt.com"stringByAppendingString:path]]];r.HTTPMethod=method;if(body){if([method isEqual:@"GET"]||[method isEqual:@"DELETE"])return Fail(e,@"invalid_request");r.HTTPBody=[NSJSONSerialization dataWithJSONObject:body options:0 error:NULL];if(!r.HTTPBody)return Fail(e,@"invalid_request");[r setValue:@"application/json"forHTTPHeaderField:@"Content-Type"];}return r;
}
BOOL OR6API7DAllowedRequest(NSURLRequest*r){
 NSURL*u=r.URL;if(![u.scheme isEqual:@"https"]||![u.host isEqual:@"chatgpt.com"]||u.user||u.password||u.port||u.fragment||r.HTTPBodyStream||r.HTTPBody.length>32768||u.absoluteString.length>8192)return NO;
 for(NSString*k in r.allHTTPHeaderFields)if(![k.lowercaseString isEqual:@"content-type"]||![[r valueForHTTPHeaderField:k]isEqual:@"application/json"])return NO;
 NSArray*a=[u.path componentsSeparatedByString:@"/"];NSString*op=nil;NSMutableDictionary*p=[NSMutableDictionary dictionary];id body=nil;
 if(a.count==4&&[a[1]isEqual:@"backend-api"]&&[a[2]isEqual:@"conversation"]&&OR6API7UUID(a[3])){p[@"conversationId"]=a[3];op=[r.HTTPMethod isEqual:@"PATCH"]?@"projects.moveConversation":@"conversation.get";}
 else if(a.count>=4&&[a[1]isEqual:@"backend-api"]&&OR6API7DProjectID(a[3])){p[@"projectId"]=a[3];if([a[2]isEqual:@"gizmos"]){if(a.count==4)op=@"projects.get";else if(a.count==5&&[a[4]isEqual:@"conversations"]){NSArray*q=[u.query componentsSeparatedByString:@"&cursor="];if(q.count<1||q.count>2)return NO;NSArray*first=[q[0]componentsSeparatedByString:@"&owned_only=true"];if(first.count!=2||[first[1]length]||![first[0]hasPrefix:@"limit="])return NO;NSString*n=[first[0]substringFromIndex:6];if(!n.length||n.length>2||[n rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet]invertedSet]].location!=NSNotFound)return NO;p[@"limit"]=@([n integerValue]);NSString*c=q.count==2?[q[1]stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]:nil;NSURLRequest*canonical=OR6API7DRequest(@"projects.conversations",p,nil,c,NULL);return[r.HTTPMethod isEqual:@"GET"]&&!r.HTTPBody.length&&[u.absoluteString isEqual:canonical.URL.absoluteString];}}
  else if([a[2]isEqual:@"projects"]){if(a.count==4)op=@"projects.memoryUpdate";else if(a.count==5&&[a[4]isEqual:@"files"])op=@"projects.filesAdd";else if(a.count==6&&[a[4]isEqual:@"files"]){op=@"projects.filesRemove";p[@"fileId"]=a[5];}}}
 if(!op)return NO;if(r.HTTPBody.length){body=[NSJSONSerialization JSONObjectWithData:r.HTTPBody options:0 error:NULL];if(![body isKindOfClass:NSDictionary.class])return NO;}
 if([op isEqual:@"projects.moveConversation"]){if([body count]!=1||(![body[@"gizmo_id"]isEqual:@""]&&!OR6API7DProjectID(body[@"gizmo_id"])))return NO;p[@"projectId"]=[body[@"gizmo_id"]isEqual:@""]?(id)NSNull.null:body[@"gizmo_id"];}
 else if([op isEqual:@"projects.memoryUpdate"]){if([body count]!=5||!S(body[@"name"],240)||![body[@"instructions"]isKindOfClass:NSString.class]||[body[@"instructions"]length]>16000||![body[@"memory_scope"]isEqual:@"project_v2"]||(body[@"emoji"]!=NSNull.null&&!S(body[@"emoji"],64))||(body[@"theme"]!=NSNull.null&&!S(body[@"theme"],128)))return NO;}
 else if([op isEqual:@"projects.filesAdd"]){if([body count]!=1||![body[@"files"]isKindOfClass:NSArray.class]||![body[@"files"]count]||[body[@"files"]count]>4)return NO;NSMutableSet*seen=[NSMutableSet set];for(id f in body[@"files"]){NSSet*keys=[NSSet setWithArray:@[@"file_id",@"library_file_id",@"location",@"name",@"type",@"size",@"last_modified"]];if(![f isKindOfClass:NSDictionary.class]||![[NSSet setWithArray:[f allKeys]]isSubsetOfSet:keys]||[f count]!=(f[@"library_file_id"]?7:6)||!OR6API8RemoteID(f[@"file_id"])||[seen containsObject:f[@"file_id"]]||![f[@"location"]isEqual:@"fs"]||!S(f[@"name"],240)||!S(f[@"type"],128)||!N(f[@"size"],8388608)||![f[@"size"]unsignedIntegerValue]||!N(f[@"last_modified"],9007199254740991ULL)||(f[@"library_file_id"]&&!SafeID(f[@"library_file_id"])))return NO;[seen addObject:f[@"file_id"]];}}
 else if(body)return NO;
 NSURLRequest*canonical=OR6API7DRequest(op,p,body,nil,NULL);return canonical&&[canonical.HTTPMethod isEqual:r.HTTPMethod]&&[canonical.URL.absoluteString isEqual:u.absoluteString];
}
