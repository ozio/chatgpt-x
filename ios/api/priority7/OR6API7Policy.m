#import "OR6API7Policy.h"
#import "../../OR6Content.h"
#import "../OR6APIWire.h"

static id Fail(NSError **error, NSString *code) {
    if (error) *error = OR6APIError(code, @"none");
    return nil;
}
BOOL OR6API7UUID(id value) {
    if (![value isKindOfClass:NSString.class] || [value length] != 36) return NO;
    NSCharacterSet *hex = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
    for (NSUInteger i=0; i<36; i++) {
        unichar c=[value characterAtIndex:i];
        if (i==8 || i==13 || i==18 || i==23) { if (c!='-') return NO; }
        else if (![hex characterIsMember:c]) return NO;
    }
    return YES;
}
BOOL OR6API7Mutation(NSString *op) {
    return [@[@"conversations.rename", @"conversations.archive", @"conversations.unarchive", @"conversations.delete", @"conversations.pin", @"shares.create"] containsObject:op];
}
BOOL OR6API7Command(NSString *op) {
    return OR6API7Mutation(op) || [@[@"archives.list", @"pins.list", @"conversations.reconcile", @"shares.get", @"content.copyCode"] containsObject:op];
}
NSDictionary *OR6API7Registry(NSDictionary *base, NSDictionary *ext, NSError **error) {
    if (![base[@"operations"] isKindOfClass:NSArray.class] || ![ext[@"operations"] isKindOfClass:NSArray.class] ||
        ![base[@"types"] isKindOfClass:NSDictionary.class] || ![ext[@"types"] isKindOfClass:NSDictionary.class] ||
        ![base[@"schemaVersion"] isEqual:@1] || ![ext[@"schemaVersion"] isEqual:@1]) return Fail(error, @"invalid_request");
    NSMutableDictionary *result=[[base mutableCopy] autorelease], *types=[[base[@"types"] mutableCopy] autorelease];
    NSMutableArray *ops=[[base[@"operations"] mutableCopy] autorelease], *features=[[base[@"featureMap"] mutableCopy] autorelease];
    NSMutableSet *ids=[NSMutableSet set]; for (NSDictionary *op in ops) [ids addObject:op[@"id"]];
    for (NSString *name in ext[@"types"]) { if (types[name]) return Fail(error, @"conflict"); types[name]=ext[@"types"][name]; }
    for (NSDictionary *op in ext[@"operations"]) {
        if (!OR6API7Command(op[@"id"]) || [ids containsObject:op[@"id"]]) return Fail(error, @"conflict");
        [ids addObject:op[@"id"]]; [ops addObject:op];
    }
    [features addObjectsFromArray:ext[@"featureMap"]]; result[@"operations"]=ops; result[@"types"]=types; result[@"featureMap"]=features;
    return OR6APIJSONSnapshot(result, 4*1024*1024);
}
static BOOL Title(id value) {
    return [value isKindOfClass:NSString.class] && [value length] <= 2000 &&
        [[value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] length] &&
        [value rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location==NSNotFound;
}
static BOOL Integer(id n, NSUInteger low, NSUInteger high) {
    return OR6APISchemaCheck(n, @{@"type":@"integer", @"minimum":@(low), @"maximum":@(high)}, @{});
}
NSURLRequest *OR6API7Request(NSString *op, NSDictionary *p, NSError **error) {
    NSString *path=nil, *method=@"GET"; NSDictionary *body=nil;
    if (OR6API7Mutation(op)) {
        if (!OR6API7UUID(p[@"operationId"]) || !OR6API7UUID(p[@"conversationId"])) return Fail(error, @"invalid_request");
        NSString *cid=[p[@"conversationId"] lowercaseString];
        path=[@"/backend-api/conversation/" stringByAppendingString:cid]; method=@"PATCH";
        if ([op isEqual:@"conversations.rename"]) {
            if (!Title(p[@"title"])) return Fail(error, @"invalid_request");
            path=[NSString stringWithFormat:@"/backend-api/conversation/id/%@/rename", cid]; method=@"POST"; body=@{@"title":p[@"title"]};
        } else if ([op isEqual:@"conversations.delete"]) {
            path=[@"/backend-api/conversation/id/" stringByAppendingString:cid]; method=@"DELETE";
        } else if ([op isEqual:@"conversations.pin"]) {
            if (!OR6APISchemaCheck(p[@"pinned"], @{@"type":@"boolean"}, @{})) return Fail(error, @"invalid_request");
            body=@{@"is_starred":p[@"pinned"]};
        } else if ([op isEqual:@"shares.create"]) {
            if (![p[@"publish"] isEqual:@YES] || !OR6API7UUID(p[@"currentNode"])) return Fail(error, @"invalid_request");
            path=@"/backend-api/share/v2/create"; method=@"POST";
            body=@{@"conversation_id":cid, @"current_node_id":[p[@"currentNode"] lowercaseString], @"is_anonymous":@YES};
        } else body=@{@"is_archived":@([op isEqual:@"conversations.archive"])};
    } else if ([op isEqual:@"archives.list"]) {
        if (!Integer(p[@"offset"],0,10000) || !Integer(p[@"limit"],1,50)) return Fail(error,@"invalid_request");
        path=[NSString stringWithFormat:@"/backend-api/conversations?is_archived=true&offset=%lu&limit=%lu&order=updated", (unsigned long)[p[@"offset"] unsignedIntegerValue], (unsigned long)[p[@"limit"] unsignedIntegerValue]];
    } else if ([op isEqual:@"pins.list"]) path=@"/backend-api/pins?item_type=conversation";
    else if ([op isEqual:@"shares.get"]) {
        if (!OR6API7UUID(p[@"shareId"])) return Fail(error,@"invalid_request");
        path=[@"/backend-api/share/" stringByAppendingString:[p[@"shareId"] lowercaseString]];
    } else if ([op isEqual:@"conversations.readback"]) {
        if (!OR6API7UUID(p[@"conversationId"])) return Fail(error,@"invalid_request");
        path=[@"/backend-api/conversation/" stringByAppendingString:[p[@"conversationId"] lowercaseString]];
    } else return Fail(error, @"invalid_request");
    NSMutableURLRequest *r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:[@"https://chatgpt.com" stringByAppendingString:path]]];
    r.HTTPMethod=method;
    if (body) { r.HTTPBody=[NSJSONSerialization dataWithJSONObject:body options:0 error:NULL]; [r setValue:@"application/json" forHTTPHeaderField:@"Content-Type"]; }
    return r;
}
BOOL OR6API7AllowedRequest(NSURLRequest *r) {
    NSURL *u=r.URL;
    if (![u.scheme isEqual:@"https"] || ![u.host isEqual:@"chatgpt.com"] || u.user || u.password || u.fragment || u.port || r.HTTPBody.length>16384 || r.HTTPBodyStream) return NO;
    for (NSString *k in r.allHTTPHeaderFields) if (![k.lowercaseString isEqual:@"content-type"]) return NO;
    NSArray *parts=[u.path componentsSeparatedByString:@"/"]; NSDictionary *body=nil;
    if (r.HTTPBody.length) { body=[NSJSONSerialization JSONObjectWithData:r.HTTPBody options:0 error:NULL]; if (![body isKindOfClass:NSDictionary.class]) return NO; }
    BOOL get=[r.HTTPMethod isEqual:@"GET"], patch=[r.HTTPMethod isEqual:@"PATCH"], post=[r.HTTPMethod isEqual:@"POST"], del=[r.HTTPMethod isEqual:@"DELETE"];
    if ([u.path isEqual:@"/backend-api/conversations"] && get && !body) {
        NSScanner *scanner=[NSScanner scannerWithString:u.query?:@""]; scanner.charactersToBeSkipped=nil; int offset=0,limit=0;
        if (![scanner scanString:@"is_archived=true&offset=" intoString:NULL] || ![scanner scanInt:&offset] || ![scanner scanString:@"&limit=" intoString:NULL] || ![scanner scanInt:&limit] || ![scanner scanString:@"&order=updated" intoString:NULL] || !scanner.isAtEnd || offset<0 || offset>10000 || limit<1 || limit>50) return NO;
        return [u.query isEqual:[NSString stringWithFormat:@"is_archived=true&offset=%d&limit=%d&order=updated",offset,limit]];
    }
    if ([u.path isEqual:@"/backend-api/pins"]) return get && !body && [u.query isEqual:@"item_type=conversation"];
    if (u.query) return NO;
    if ([u.path isEqual:@"/backend-api/share/v2/create"]) return post && body.count==3 && OR6API7UUID(body[@"conversation_id"]) && OR6API7UUID(body[@"current_node_id"]) && OR6APISchemaCheck(body[@"is_anonymous"],@{@"type":@"boolean",@"enum":@[@YES]},@{});
    if (parts.count==4 && [parts[1] isEqual:@"backend-api"] && [parts[2] isEqual:@"share"]) return get && !body && OR6API7UUID(parts[3]);
    if (parts.count<4 || ![parts[1] isEqual:@"backend-api"] || ![parts[2] isEqual:@"conversation"]) return NO;
    if (parts.count==4 && OR6API7UUID(parts[3])) {
        if (get) return !body;
        return patch && body.count==1 && ((body[@"is_starred"] && OR6APISchemaCheck(body[@"is_starred"],@{@"type":@"boolean"},@{})) || (body[@"is_archived"] && OR6APISchemaCheck(body[@"is_archived"],@{@"type":@"boolean"},@{})));
    }
    if (parts.count>=5 && [parts[3] isEqual:@"id"] && OR6API7UUID(parts[4])) {
        if (parts.count==5) return del && !body;
        return parts.count==6 && [parts[5] isEqual:@"rename"] && post && body.count==1 && Title(body[@"title"]);
    }
    return NO;
}
NSDictionary *OR6API7Share(id raw, NSString *expected, NSError **error) {
    if (![raw isKindOfClass:NSDictionary.class] || !OR6API7UUID(raw[@"share_id"]) || !OR6API7UUID(raw[@"current_node_id"]) ||
        (expected && [expected caseInsensitiveCompare:raw[@"share_id"]]!=NSOrderedSame)) return Fail(error,@"unknown_wire_shape");
    NSString *identifier=[raw[@"share_id"] lowercaseString]; NSString *url=raw[@"share_url"];
    if (![url isKindOfClass:NSString.class]) return Fail(error,@"unknown_wire_shape");
    NSString *publicURL=[@"https://chatgpt.com/share/" stringByAppendingString:identifier];
    NSString *workspaceURL=[@"https://chatgpt.com/share/e/" stringByAppendingString:identifier];
    if (![url isEqual:publicURL] && ![url isEqual:workspaceURL]) return Fail(error,@"unknown_wire_shape");
    id moderation=raw[@"moderation_state"];
    if (moderation && ![moderation isKindOfClass:NSDictionary.class]) return Fail(error,@"unknown_wire_shape");
    for (NSString *k in @[@"has_been_auto_blocked", @"has_been_auto_moderated", @"has_been_blocked"]) {
        if (moderation[k] && !OR6APISchemaCheck(moderation[k],@{@"type":@"boolean"},@{})) return Fail(error,@"unknown_wire_shape");
        if ([moderation[k] isEqual:@YES]) return Fail(error,@"access_denied");
    }
    return @{@"id":identifier, @"url":url, @"currentNode":[raw[@"current_node_id"] lowercaseString], @"workspaceOnly":@([url isEqual:workspaceURL])};
}
NSDictionary *OR6API7Code(NSDictionary *p, NSError **error) {
    if (![p[@"markdown"] isKindOfClass:NSString.class] || [p[@"markdown"] length]>16000 || !Integer(p[@"codeBlockIndex"],0,255)) return Fail(error,@"invalid_request");
    NSUInteger index=0, remaining=0;
    for (NSDictionary *row in OR6ContentBlocks(p[@"markdown"])) {
        if (![row[@"kind"] isEqual:@"code"]) { remaining=0; continue; }
        if (remaining) { NSUInteger length=[row[@"text"] length]; if (length>remaining) return Fail(error,@"invalid_response"); remaining-=length; continue; }
        NSString *code=row[@"copyText"]; if (![code isKindOfClass:NSString.class]) return Fail(error,@"invalid_response");
        if (index++==[p[@"codeBlockIndex"] unsignedIntegerValue]) return @{@"text":code, @"language":row[@"language"]?:(id)NSNull.null};
        remaining=code.length-[row[@"text"] length];
    }
    return Fail(error,@"not_found");
}

NSDictionary *OR6API7SharedConversation(id value,NSString *shareId,NSError **error){
 if(![value isKindOfClass:NSDictionary.class]||!OR6API7UUID(shareId)||!OR6API7UUID(value[@"conversation_id"])||(value[@"share_id"]&&![value[@"share_id"]isEqual:shareId]))return Fail(error,@"unknown_wire_shape");
 id mapping=value[@"mapping"];if(![mapping isKindOfClass:NSDictionary.class]||![mapping count]||[mapping count]>10000)return Fail(error,@"unknown_wire_shape");
 NSString*omitted=nil;NSUInteger roots=0;
 for(NSString*k in mapping){id node=mapping[k];if(![node isKindOfClass:NSDictionary.class])return Fail(error,@"unknown_wire_shape");id parent=node[@"parent"];
  if(!parent||parent==NSNull.null)roots++;
  if(!parent){if(omitted||![node[@"id"]isEqual:k]||(node[@"message"]&&node[@"message"]!=NSNull.null)||![node[@"children"]isKindOfClass:NSArray.class])return Fail(error,@"unknown_wire_shape");omitted=k;}
 }
 NSDictionary*wire=value;
 if(omitted){if(roots!=1)return Fail(error,@"unknown_wire_shape");
  // A missing field is accepted only for the sole message-free root, never an orphan.
  for(NSDictionary*n in [mapping allValues])if([n[@"children"]isKindOfClass:NSArray.class]&&[n[@"children"]containsObject:omitted])return Fail(error,@"unknown_wire_shape");
  NSMutableDictionary*m=[[mapping mutableCopy]autorelease],*n=[[mapping[omitted]mutableCopy]autorelease],*v=[[value mutableCopy]autorelease];n[@"parent"]=NSNull.null;m[omitted]=n;v[@"mapping"]=m;wire=v;
 }
 NSData*bytes=[NSJSONSerialization dataWithJSONObject:wire options:0 error:NULL];return OR6APIWireConversation(bytes,wire[@"conversation_id"],error);
}
