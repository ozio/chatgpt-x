#import "OR6API7CPolicy.h"
#import "../priority7/OR6API7Policy.h"
#import "../priority8/OR6API8Policy.h"
#include <string.h>

static id Fail(NSError **error,NSString *code){if(error)*error=OR6APIError(code,@"none");return nil;}
static BOOL String(id v,NSUInteger n){return[v isKindOfClass:NSString.class]&&[v length]&&[v length]<=n&&[v rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location==NSNotFound;}
static BOOL Number(id v,unsigned long long max){return OR6APISchemaCheck(v,@{@"type":@"integer",@"minimum":@0,@"maximum":@(max)},@{});}
BOOL OR6API7CLibraryID(id v){return String(v,128)&&![v hasPrefix:@"external-"]&&[v rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"]invertedSet]].location==NSNotFound;}
BOOL OR6API7CHandle(id v){return[v isKindOfClass:NSString.class]&&[v hasPrefix:@"library:"]&&OR6API7UUID([v substringFromIndex:8]);}
BOOL OR6API7CCommand(NSString *op){return[@[@"library.list",@"library.search",@"library.get",@"library.conversationFiles",@"library.attach",@"library.detach"]containsObject:op];}
NSDictionary *OR6API7CRegistry(NSDictionary *base,NSDictionary *ext,NSError **error){
 if(![base[@"schemaVersion"]isEqual:@1]||![ext[@"schemaVersion"]isEqual:@1]||![base[@"operations"]isKindOfClass:NSArray.class]||![ext[@"operations"]isKindOfClass:NSArray.class]||![base[@"types"]isKindOfClass:NSDictionary.class]||![ext[@"types"]isKindOfClass:NSDictionary.class]||![base[@"featureMap"]isKindOfClass:NSArray.class]||![ext[@"featureMap"]isKindOfClass:NSArray.class])return Fail(error,@"invalid_request");
 BOOL attach=NO;for(NSDictionary*o in base[@"operations"])if([o[@"id"]isEqual:@"assets.attach"])attach=YES;
 if(!attach)base=OR6API8Registry(base);
 NSMutableDictionary*r=[[base mutableCopy]autorelease],*types=[[base[@"types"]mutableCopy]autorelease];NSMutableArray*ops=[[base[@"operations"]mutableCopy]autorelease],*features=[[base[@"featureMap"]mutableCopy]autorelease];NSMutableSet*ids=[NSMutableSet set];
 for(NSDictionary*o in ops)[ids addObject:o[@"id"]];for(NSString*k in ext[@"types"]){if(types[k])return Fail(error,@"conflict");types[k]=ext[@"types"][k];}
 for(NSDictionary*o in ext[@"operations"]){if(!OR6API7CCommand(o[@"id"])||[ids containsObject:o[@"id"]])return Fail(error,@"conflict");[ids addObject:o[@"id"]];[ops addObject:o];}
 [features addObjectsFromArray:ext[@"featureMap"]];r[@"operations"]=ops;r[@"types"]=types;r[@"featureMap"]=features;return OR6APIJSONSnapshot(r,4*1024*1024);
}
static BOOL MIME(id v){return String(v,128)&&[[NSRegularExpression regularExpressionWithPattern:@"^[A-Za-z0-9!#$&^_.+-]+/[A-Za-z0-9!#$&^_.+-]+$"options:0 error:NULL]numberOfMatchesInString:v options:0 range:NSMakeRange(0,[v length])]==1;}
NSDictionary *OR6API7CItem(id raw,BOOL node,NSString *expected,NSError **error){
 if(![raw isKindOfClass:NSDictionary.class]||!String(raw[@"id"],512)||[raw[@"id"]rangeOfString:@"/"].location!=NSNotFound||(expected&&![raw[@"id"]isEqual:expected]))return Fail(error,@"unknown_wire_shape");
 NSString*name=raw[node?@"name":@"file_name"];if(!String(name,240)||!String(raw[@"state"],64)||(node&&![raw[@"kind"]isEqual:@"file"]))return Fail(error,@"unknown_wire_shape");
 id file=raw[@"file_id"]?:NSNull.null,mime=raw[@"mime_type"]?:NSNull.null,size=raw[@"file_size_bytes"]?:NSNull.null,artifact=raw[@"library_artifact_type"]?:NSNull.null;
 if((file!=NSNull.null&&(!String(file,128)||[file rangeOfString:@"://"].location!=NSNotFound))||(mime!=NSNull.null&&!MIME(mime))||(size!=NSNull.null&&!Number(size,1099511627776ULL))||(artifact!=NSNull.null&&!String(artifact,128)))return Fail(error,@"unknown_wire_shape");
 NSString*access=[@[@"owned",@"shared",@"mounted"]containsObject:raw[@"access_kind"]]?raw[@"access_kind"]:@"unknown";
 BOOL native=(!raw[@"provider"]||raw[@"provider"]==NSNull.null||[raw[@"provider"]isEqual:@"native"])&&OR6API7CLibraryID(raw[@"id"]);
 BOOL can=native&&[access isEqual:@"owned"]&&[raw[@"state"]isEqual:@"ready"]&&artifact==NSNull.null&&OR6API8RemoteID(file)&&mime!=NSNull.null&&![[mime lowercaseString] hasPrefix:@"image/"]&&size!=NSNull.null&&[size unsignedLongLongValue]>0&&[size unsignedLongLongValue]<=8*1024*1024;
 return @{@"id":raw[@"id"],@"fileId":file,@"name":name,@"mediaType":mime,@"bytes":size,@"state":raw[@"state"],@"access":access,@"artifactType":artifact,@"canAttach":@(can)};
}
NSDictionary *OR6API7CPage(id raw,NSUInteger limit,NSError **error){
 if(![raw isKindOfClass:NSDictionary.class]||![raw[@"items"]isKindOfClass:NSArray.class]||[raw[@"items"]count]>limit||!raw[@"cursor"]||(raw[@"cursor"]!=NSNull.null&&!String(raw[@"cursor"],4096)))return Fail(error,@"unknown_wire_shape");
 NSMutableArray*items=[NSMutableArray array];NSMutableSet*seen=[NSMutableSet set];for(id value in raw[@"items"]){NSDictionary*item=OR6API7CItem(value,NO,nil,error);if(!item||[seen containsObject:item[@"id"]])return Fail(error,@"unknown_wire_shape");[seen addObject:item[@"id"]];[items addObject:item];}
 if(!items.count&&raw[@"cursor"]!=NSNull.null)return Fail(error,@"unknown_wire_shape");return@{@"items":items,@"cursor":raw[@"cursor"]};
}
NSDictionary *OR6API7CAsset(NSDictionary *item,NSString *handle,NSError **error){
 if(!OR6API7CHandle(handle)||![item[@"canAttach"]isEqual:@YES]||!OR6API8RemoteID(item[@"fileId"])||!MIME(item[@"mediaType"])||[[item[@"mediaType"]lowercaseString]hasPrefix:@"image/"]||!Number(item[@"bytes"],8*1024*1024)||![item[@"bytes"]unsignedIntegerValue])return Fail(error,@"unsupported_media");
 return@{@"assetId":handle,@"remoteId":item[@"fileId"],@"name":item[@"name"],@"mediaType":item[@"mediaType"],@"bytes":item[@"bytes"],@"state":@"ready"};
}
static NSString *Encode(NSString*s){NSData*d=[s dataUsingEncoding:NSUTF8StringEncoding];const unsigned char*p=d.bytes;NSMutableString*out=[NSMutableString string];for(NSUInteger i=0;i<d.length;i++){unsigned char c=p[i];if((c>='a'&&c<='z')||(c>='A'&&c<='Z')||(c>='0'&&c<='9')||strchr("-._~",c))[out appendFormat:@"%c",c];else[out appendFormat:@"%%%02X",c];}return out;}
NSURLRequest *OR6API7CRequest(NSString *op,NSDictionary *p,NSString *cursor,NSError **error){
 if(cursor&&!String(cursor,4096))return Fail(error,@"invalid_request");NSString*path=nil;NSDictionary*body=nil;
 if([@[@"library.list",@"library.search"]containsObject:op]){
  if(!OR6APISchemaCheck(p[@"limit"],@{@"type":@"integer",@"minimum":@1,@"maximum":@50},@{}))return Fail(error,@"invalid_request");
  id q=NSNull.null;if([op isEqual:@"library.search"]){if(!String(p[@"query"],256)||![[p[@"query"]stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]length])return Fail(error,@"invalid_request");q=p[@"query"];}
  path=@"/backend-api/files/library";body=@{@"defer_sharing_badges":@YES,@"limit":p[@"limit"],@"cursor":cursor?:(id)NSNull.null,@"state":@"ready",@"q":q};
 }else if([op isEqual:@"library.conversationFiles"]){if(!OR6API7UUID(p[@"conversationId"])||!OR6APISchemaCheck(p[@"limit"],@{@"type":@"integer",@"minimum":@1,@"maximum":@50},@{}))return Fail(error,@"invalid_request");path=[NSString stringWithFormat:@"/backend-api/conversations/%@/files?limit=%lu%@",[p[@"conversationId"]lowercaseString],(unsigned long)[p[@"limit"]unsignedIntegerValue],cursor?[@"&cursor="stringByAppendingString:Encode(cursor)]:@""];
 }else if([@[@"library.get",@"library.attach",@"library.node"]containsObject:op]){NSString*identifier=p[@"libraryId"];if(!OR6API7CLibraryID(identifier))return Fail(error,@"invalid_request");BOOL node=[op isEqual:@"library.node"];for(NSString*prefix in @[@"libfile_fde1_",@"libfile_fde2_",@"libfile_fde3_"])if([identifier hasPrefix:prefix])node=YES;path=[NSString stringWithFormat:@"/backend-api/files/library/files/%@%@",identifier,node?@"/node":@""];
 }else return Fail(error,@"invalid_request");
 NSMutableURLRequest*r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:[@"https://chatgpt.com"stringByAppendingString:path]]];r.HTTPMethod=body?@"POST":@"GET";if(body){r.HTTPBody=[NSJSONSerialization dataWithJSONObject:body options:0 error:NULL];[r setValue:@"application/json"forHTTPHeaderField:@"Content-Type"];}return r;
}
BOOL OR6API7CAllowedRequest(NSURLRequest*r){
 NSURL*u=r.URL;if(![u.scheme isEqual:@"https"]||![u.host isEqual:@"chatgpt.com"]||u.user||u.password||u.port||u.fragment||r.HTTPBodyStream||r.HTTPBody.length>16384||u.absoluteString.length>8192)return NO;
 for(NSString*k in r.allHTTPHeaderFields)if(![k.lowercaseString isEqual:@"content-type"]||![[r valueForHTTPHeaderField:k]isEqual:@"application/json"])return NO;
 if([u.path isEqual:@"/backend-api/files/library"]&&!u.query&&[r.HTTPMethod isEqual:@"POST"]){id b=[NSJSONSerialization JSONObjectWithData:r.HTTPBody?:[NSData data]options:0 error:NULL];return[b isKindOfClass:NSDictionary.class]&&[b count]==5&&[b[@"defer_sharing_badges"]isEqual:@YES]&&OR6APISchemaCheck(b[@"defer_sharing_badges"],@{@"type":@"boolean"},@{})&&[b[@"state"]isEqual:@"ready"]&&OR6APISchemaCheck(b[@"limit"],@{@"type":@"integer",@"minimum":@1,@"maximum":@50},@{})&&(b[@"cursor"]==NSNull.null||String(b[@"cursor"],4096))&&(b[@"q"]==NSNull.null||String(b[@"q"],256));}
 if(![r.HTTPMethod isEqual:@"GET"]||r.HTTPBody.length)return NO;NSArray*a=[u.path componentsSeparatedByString:@"/"];
 if((a.count==6||a.count==7)&&[a[1]isEqual:@"backend-api"]&&[a[2]isEqual:@"files"]&&[a[3]isEqual:@"library"]&&[a[4]isEqual:@"files"]&&OR6API7CLibraryID(a[5])&&!u.query){NSURLRequest*canonical=OR6API7CRequest(a.count==7?@"library.node":@"library.get",@{@"libraryId":a[5]},nil,NULL);return[u.absoluteString isEqual:canonical.URL.absoluteString];}
 if(a.count!=5||![a[1]isEqual:@"backend-api"]||![a[2]isEqual:@"conversations"]||!OR6API7UUID(a[3])||![a[4]isEqual:@"files"])return NO;
 NSArray*query=[u.query componentsSeparatedByString:@"&cursor="];if(query.count<1||query.count>2||![query[0]hasPrefix:@"limit="])return NO;NSString*n=[query[0]substringFromIndex:6];if(!n.length||n.length>2||[n rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet]invertedSet]].location!=NSNotFound)return NO;
 NSString*cursor=query.count==2?[[query lastObject]stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]:nil;NSURLRequest*canonical=OR6API7CRequest(@"library.conversationFiles",@{@"conversationId":a[3],@"limit":@([n integerValue])},cursor,NULL);return[u.absoluteString isEqual:canonical.URL.absoluteString];
}
