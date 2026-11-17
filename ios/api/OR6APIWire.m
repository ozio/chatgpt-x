#import "OR6APIWire.h"
#import <CoreFoundation/CoreFoundation.h>
#import <CommonCrypto/CommonDigest.h>
#include <math.h>
#include <string.h>

NSString *const OR6APIWireErrorDomain=@"OR6APIWire";
/* These limits apply before Foundation parses JSON and again after each patch.
 * Model UI code is never executed. Only bounded data fields are projected. */
static const NSUInteger WJSON=2097152, WFRAME=131072, WSTREAM=8388608;
static const NSUInteger WDEPTH=32, WVALUES=32768, WNODES=2048, WTEXT=262144;
static id WNull(void) { return [NSNull null]; }
static BOOL WDict(id x) { return [x isKindOfClass:[NSDictionary class]]; }
static BOOL WArray(id x) { return [x isKindOfClass:[NSArray class]]; }
static BOOL WString(id x,NSUInteger cap) { return [x isKindOfClass:[NSString class]] && [x length]<=cap; }
static BOOL WBool(id x) { return x && CFGetTypeID((CFTypeRef)x)==CFBooleanGetTypeID(); }
static BOOL WNumber(id x) { return [x isKindOfClass:[NSNumber class]] && !WBool(x) && isfinite([x doubleValue]); }
static BOOL WInteger(id x,NSUInteger cap) { return WNumber(x) && [x doubleValue]>=0 && [x doubleValue]<=cap && floor([x doubleValue])==[x doubleValue]; }
static BOOL WUUID(id x) {
    if (!WString(x,36) || [x length]!=36) return NO;
    for (NSUInteger i=0;i<36;i++) { unichar c=[x characterAtIndex:i];
        if (i==8 || i==13 || i==18 || i==23) {if(c!='-') return NO;}
        else if (!((c>='0'&&c<='9') || (c>='a'&&c<='f') || (c>='A'&&c<='F'))) return NO;
    } return YES;
}
static BOOL WNodeID(id x) { return WUUID(x) || [x isEqual:@"client-created-root"]; }
static BOOL WFileID(id x) {
    if(!WString(x,105)||![x hasPrefix:@"file_"]||[x length]<=5)return NO;
    for(NSUInteger i=5;i<[x length];i++){unichar c=[x characterAtIndex:i];if(!((c>='a'&&c<='z')||(c>='A'&&c<='Z')||(c>='0'&&c<='9')||c=='_'||c=='-'))return NO;}
    return YES;
}
static id WFail(NSError **error,NSInteger code) {
    /* Fixed descriptions only: never attach JSON parser errors, paths, IDs,
     * upstream error objects, URLs or response data. */
    static NSString *const messages[]={@"Invalid wire data",@"Wire limit exceeded",@"Invalid conversation graph",@"Invalid stream data",@"Unsupported stream encoding",@"Upstream stream error",@"Incomplete stream",@"Wire identity mismatch"};
    if(error) *error=[NSError errorWithDomain:OR6APIWireErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey:messages[(code>=1&&code<=8)?code-1:0]}];
    return nil;
}
static BOOL WUnicode(NSString *s) {
    for(NSUInteger i=0;i<[s length];i++) {unichar c=[s characterAtIndex:i];
        if(CFStringIsSurrogateHighCharacter(c)) {if(++i==[s length] || !CFStringIsSurrogateLowCharacter([s characterAtIndex:i])) return NO;}
        else if(CFStringIsSurrogateLowCharacter(c)) return NO;
    } return YES;
}
static BOOL WTree(id x,NSUInteger depth,NSUInteger *count) {
    if(depth>WDEPTH || ++*count>WVALUES) return NO;
    if([x isKindOfClass:[NSString class]]) return WString(x,WTEXT)&&WUnicode(x);
    if(x==WNull() || WBool(x) || WNumber(x)) return YES;
    if(WArray(x)) {if([x count]>WVALUES) return NO;for(id v in x) if(!WTree(v,depth+1,count)) return NO;return YES;}
    if(WDict(x)) {if([x count]>WVALUES) return NO;for(id k in x) if(!WString(k,512)||!WUnicode(k)||!WTree([x objectForKey:k],depth+1,count)) return NO;return YES;}
    return NO;
}
static BOOL WJSONBounds(NSData *data,NSUInteger cap) {
    if(![data isKindOfClass:[NSData class]] || ![data length] || [data length]>cap) return NO;
    NSString *text=[[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    if(!text || !WUnicode(text)) return NO;
    const unsigned char *p=[data bytes];NSUInteger depth=0,keyStart=NSNotFound,containers=0;BOOL quoted=NO,escape=NO;
    NSMutableArray *keys=[NSMutableArray array],*expectKey=[NSMutableArray array];
    for(NSUInteger i=0;i<[data length];i++) {unsigned char c=p[i];
        if(quoted) {if(escape) escape=NO;else if(c=='\\') escape=YES;else if(c=='"') {
            quoted=NO;
            if(keyStart!=NSNotFound) {
                if(i-keyStart>4096)return NO;
                NSData *encoded=[NSData dataWithBytes:p+keyStart length:i-keyStart+1];
                id key=[NSJSONSerialization JSONObjectWithData:encoded options:NSJSONReadingAllowFragments error:NULL];
                NSMutableSet *seen=[keys lastObject];
                if(!WString(key,512)||!WUnicode(key)||[seen containsObject:key])return NO;
                [seen addObject:key];expectKey[[expectKey count]-1]=@NO;keyStart=NSNotFound;
            }
        }}
        else if(c=='"') {quoted=YES;if([keys count]&&[keys lastObject]!=WNull()&&[[expectKey lastObject]boolValue])keyStart=i;}
        else if(c=='[' || c=='{') {if(++depth>WDEPTH||++containers>WVALUES) return NO;[keys addObject:c=='{'?[NSMutableSet set]:WNull()];[expectKey addObject:@(c=='{')];}
        else if(c==']' || c=='}') {if(!depth) return NO;depth--;[keys removeLastObject];[expectKey removeLastObject];}
        else if(c==','&&[keys count]&&[keys lastObject]!=WNull())expectKey[[expectKey count]-1]=@YES;
    } return !quoted&&!depth;
}
static id WJSONRead(NSData *data,NSUInteger cap,NSError **error) {
    if(![data isKindOfClass:[NSData class]])return WFail(error,1);
    if(!WJSONBounds(data,cap)) return WFail(error,[data length]>cap?2:1);
    id x=[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers|NSJSONReadingAllowFragments error:NULL];
    NSUInteger count=0;if(!x || !WTree(x,0,&count)) return WFail(error,1);return x;
}
static id WOptional(id x) { return x?:WNull(); }
static BOOL WOptionalString(id x,NSUInteger cap) {return !x||x==WNull()||WString(x,cap);}
static BOOL WOptionalNumber(id x) {return !x||x==WNull()||WNumber(x);}
static BOOL WOptionalBool(id x) {return !x||x==WNull()||WBool(x);}
static NSInteger WDigits(const unichar *s,NSUInteger start,NSUInteger length) {
    NSInteger value=0;
    for(NSUInteger i=start;i<start+length;i++){if(s[i]<'0'||s[i]>'9')return -1;value=value*10+s[i]-'0';}
    return value;
}
/* History/search use both epoch numbers and RFC3339 strings. Parse the latter
 * without locale, date-formatter leniency or the 32-bit time_t range. Strings
 * require an explicit offset, Gregorian year1..9999 and at most9 fraction
 * digits; leap seconds are explicitly unsupported by this POSIX projection.
 * RFC3339 -00:00 still identifies UTC, with unknown original local offset. */
static id WTimestamp(id value) {
    if(!value||value==WNull())return WNull();if(WNumber(value))return value;
    if(!WString(value,35)||[value length]<20)return nil;
    NSUInteger length=[value length];unichar s[35];[value getCharacters:s range:NSMakeRange(0,length)];
    if(s[4]!='-'||s[7]!='-'||(s[10]!='T'&&s[10]!='t')||s[13]!=':'||s[16]!=':')return nil;
    NSInteger year=WDigits(s,0,4),month=WDigits(s,5,2),day=WDigits(s,8,2),hour=WDigits(s,11,2),minute=WDigits(s,14,2),second=WDigits(s,17,2);
    if(year<1||month<1||month>12||day<1||hour<0||hour>23||minute<0||minute>59||second<0||second>59)return nil;
    BOOL leap=year%4==0&&(year%100!=0||year%400==0);
    static const NSInteger monthDays[]={31,28,31,30,31,30,31,31,30,31,30,31};
    if(day>monthDays[month-1]+(month==2&&leap?1:0))return nil;
    NSUInteger cursor=19,digits=0;double fraction=0,scale=10;
    if(s[cursor]=='.'){
        cursor++;while(cursor<length&&s[cursor]>='0'&&s[cursor]<='9'){
            if(++digits>9)return nil;fraction+=(s[cursor++]-'0')/scale;scale*=10;
        }if(!digits)return nil;
    }
    NSInteger offset=0;
    if(cursor+1==length&&(s[cursor]=='Z'||s[cursor]=='z')){}
    else if(cursor+6==length&&(s[cursor]=='+'||s[cursor]=='-')&&s[cursor+3]==':'){
        NSInteger oh=WDigits(s,cursor+1,2),om=WDigits(s,cursor+4,2);
        if(oh<0||oh>23||om<0||om>59)return nil;
        offset=(oh*60+om)*60*(s[cursor]=='-'?-1:1);
    }else return nil;
    /* Proleptic Gregorian day arithmetic stays bounded and works on ARMv7. */
    long long prior=year-1;
    long long days=365LL*(year-1970)+(prior/4-prior/100+prior/400)-(1969/4-1969/100+1969/400)+day-1;
    for(NSInteger m=1;m<month;m++)days+=monthDays[m-1]+(m==2&&leap?1:0);
    double epoch=(double)(days*86400LL+hour*3600+minute*60+second-offset)+fraction;
    return isfinite(epoch)?@(epoch):nil;
}
static NSDictionary *WHistoryItem(id item,NSError **error) {
    if(!WDict(item)||!WUUID(item[@"id"])||!WString(item[@"title"],4096)||!WOptionalBool(item[@"is_archived"])||
       (item[@"current_node"]&&item[@"current_node"]!=WNull()&&!WNodeID(item[@"current_node"]))) return WFail(error,1);
    id updated=WTimestamp(item[@"update_time"]);if(!updated)return WFail(error,1);
    return @{@"id":item[@"id"],@"title":item[@"title"],@"updatedAt":updated,@"currentNode":WOptional(item[@"current_node"]),@"archived":@([item[@"is_archived"] isEqual:@YES])};
}
NSDictionary *OR6APIWireHistory(NSData *data,NSUInteger offset,NSUInteger limit,NSError **error) {
    if(error)*error=nil;
    if(offset>10000||limit<1||limit>100)return WFail(error,1);
    id root=WJSONRead(data,WJSON,error);if(!root)return nil;
    if(!WDict(root)||!WArray(root[@"items"])||[root[@"items"] count]>limit||!WInteger(root[@"total"],1000000)||!WInteger(root[@"offset"],10000)||!WInteger(root[@"limit"],100)||
       [root[@"offset"] unsignedIntegerValue]!=offset||[root[@"limit"] unsignedIntegerValue]!=limit||([root[@"items"] count]&&[root[@"total"] unsignedIntegerValue]<offset+[root[@"items"] count]))return WFail(error,1);
    NSMutableArray *items=[NSMutableArray array];NSMutableSet *seen=[NSMutableSet set];
    for(id raw in root[@"items"]) {NSDictionary *item=WHistoryItem(raw,error);if(!item)return nil;NSString *identifier=[item[@"id"] lowercaseString];if([seen containsObject:identifier])return WFail(error,1);[seen addObject:identifier];[items addObject:item];}
    NSUInteger next=offset+[items count],total=[root[@"total"] unsignedIntegerValue];
    if(next<total && ![items count])return WFail(error,1);
    return @{@"items":items,@"offset":@(offset),@"limit":@(limit),@"total":@(total),@"nextToken":next<total?[NSString stringWithFormat:@"offset:%lu",(unsigned long)next]:WNull()};
}

/* A normalized part contains only inert data from a narrow allowlist. Unknown
 * content has an explicit marker; it cannot disappear or become executable UI. */
static NSDictionary *WReference(id raw,NSString *kind,NSError **error) {
    if(!WDict(raw))return WFail(error,1);
    if([kind isEqual:@"asset"]&&raw[@"id"]&&!WFileID(raw[@"id"]))return WFail(error,1);
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    for(NSString *key in @[@"id",@"title",@"url",@"name",@"mime_type",@"asset_pointer",@"matched_text",@"type",@"content_type",@"reference_id"]) {
        id value=raw[key];if(!value||value==WNull())continue;
        if(!WString(value,[key isEqual:@"matched_text"]?WTEXT:4096))return WFail(error,1);result[key]=value;
    }
    for(NSString *key in @[@"start_idx",@"end_idx",@"size",@"width",@"height"]) {id v=raw[key];if(!v||v==WNull())continue;if(!WInteger(v,1073741824))return WFail(error,1);result[key]=v;}
    if(result[@"start_idx"]&&result[@"end_idx"]&&[result[@"end_idx"] unsignedIntegerValue]<[result[@"start_idx"] unsignedIntegerValue])return WFail(error,1);
    id ref=raw[@"ref_id"];
    if(WString(ref,128))result[@"id"]=ref;
    else if(WDict(ref)&&WInteger(ref[@"turn_index"],1000000000)&&WInteger(ref[@"ref_index"],1000000000)&&[@[@"search",@"view",@"news"]containsObject:ref[@"ref_type"]])result[@"id"]=[NSString stringWithFormat:@"turn%@%@%@",ref[@"turn_index"],ref[@"ref_type"],ref[@"ref_index"]];
    if(!result[@"id"]&&result[@"reference_id"])result[@"id"]=result[@"reference_id"];
    return @{@"kind":kind,@"data":result};
}
static BOOL WPublicImageMessage(NSDictionary *m);
// Menu hints contain presence/identity only, never question bodies or tool parameters.
// The authoritative history branch decides whether a request is still pending.
static BOOL WPendingQuestions(NSDictionary *m) {
    if(!WDict(m)||!WPublicImageMessage(m)||![m[@"author"][@"role"]isEqual:@"assistant"])return NO;
    NSDictionary *meta=WDict(m[@"metadata"])?m[@"metadata"]:nil;
    NSDictionary *q=WDict(meta[@"codex_request_user_input_async"])?meta[@"codex_request_user_input_async"]:nil;
    if(q) {
        if(!WString(q[@"item_id"],128)||![q[@"item_id"]length]||!WArray(q[@"questions"])||![q[@"questions"]count]||[q[@"questions"]count]>20)return NO;
        for(id row in q[@"questions"]) { if(!WDict(row)||!WString(row[@"title"],4000)||![row[@"title"]length])return NO;id options=row[@"options"];if(options&&(!WArray(options)||[options count]>20))return NO;for(id option in options)if(!WString(option,1000)||![option length])return NO; }
        return YES;
    }
    if(meta[@"codex_request_user_input"]||meta[@"codex_request_user_input_async"]||![m[@"status"]isEqual:@"finished_successfully"]||![@[@"text",@"multimodal_text"]containsObject:m[@"content"][@"content_type"]])return NO;
    NSArray *refs=meta[@"content_references"];if(!WArray(refs)||refs.count>128)return NO;NSUInteger widgets=0;
    for(id ref in refs) {
        if(!WDict(ref)||![ref[@"type"]isEqual:@"client_defined_widget"]||![ref[@"category"]isEqual:@"ask_user_input"])continue;
        if(++widgets>1||!WDict(ref[@"data"]))return NO;NSDictionary *data=ref[@"data"];NSArray *questions=data[@"questions"];
        if(data[@"codex_request_user_input"]||data[@"widget_variant"]||!WArray(questions)||!questions.count||questions.count>20)return NO;
        for(id question in questions) {
            if(!WDict(question)||!WString(question[@"question"],4000)||![question[@"question"]length]||![@[@"single_select",@"multi_select"]containsObject:question[@"type"]]||!WOptionalBool(question[@"allow_custom_text"]))return NO;
            id options=question[@"options"];if(!WArray(options)||[options count]<2||[options count]>10)return NO;NSMutableSet *seen=[NSMutableSet set];
            for(id option in options){if(!WString(option,1000)||![option length]||[seen containsObject:option])return NO;[seen addObject:option];}
        }
    }
    return widgets==1;
}
static BOOL WPendingApproval(NSDictionary *m) {
    if(!WDict(m)||!WPublicImageMessage(m))return NO;
    NSDictionary *meta=WDict(m[@"metadata"])?m[@"metadata"]:nil,*plugin=WDict(meta[@"jit_plugin_data"])?meta[@"jit_plugin_data"]:nil;
    if(!plugin){NSDictionary *e=WDict(meta[@"elicitation_metadata"])?meta[@"elicitation_metadata"]:nil;plugin=WDict(e[@"plugin_data"])?e[@"plugin_data"]:nil;}
    NSDictionary *request=WDict(plugin[@"from_server"])?plugin[@"from_server"]:nil,*body=WDict(request[@"body"])?request[@"body"]:nil;
    if(![m[@"author"][@"role"]isEqual:@"tool"]||![@[@"confirm_action",@"approve_tool_in_context_scope"]containsObject:request[@"type"]?:@""]||body[@"codex_mcp_elicitation"]||!WArray(body[@"actions"])||[body[@"actions"]count]>32)return NO;
    BOOL actionable=NO;for(id action in body[@"actions"]){if(!WDict(action))return NO;for(NSString *key in @[@"allow_once",@"allow",@"deny"]){id v=action[key];if(!WDict(v))continue;id target=v[@"target_message_id"];if(target&&!WUUID(target))return NO;if(WUUID(target)&&(![action[@"name"]isEqual:@"approve_for_me"]||[key isEqual:@"deny"]))actionable=YES;}}
    return actionable;
}
static BOOL WResearchReport(NSDictionary *m) {
    NSDictionary *meta=WDict(m[@"metadata"])?m[@"metadata"]:nil;
    // A research mode or ordinary citations do not prove that a report exists.
    if([m[@"content"][@"content_type"]isEqual:@"deep_research_report"]||[meta[@"library_artifact_type"]isEqual:@"deep_research_report"])return YES;
    id attachments=meta[@"attachments"];if(!WArray(attachments)||[attachments count]>256)return NO;
    for(id file in attachments)if(WDict(file)&&[file[@"library_artifact_type"]isEqual:@"deep_research_report"])return YES;
    return NO;
}
static void WAddMenuContext(NSMutableArray *rows,NSUInteger index,NSDictionary *context) {
    if([rows[index][@"parts"]count]>=1000)return;
    NSMutableDictionary *row=[[rows[index]mutableCopy]autorelease];
    row[@"parts"]=[row[@"parts"]arrayByAddingObject:@{@"kind":@"context",@"data":context}];rows[index]=row;
}
static NSString *WReasoningSummary(NSDictionary *m);
static NSDictionary *WMessage(id message,NSString *nodeID,NSError **error) {
    if(!WDict(message)||!WUUID(message[@"id"])||!WDict(message[@"author"])||!WString(message[@"author"][@"role"],64)||!WDict(message[@"content"])||
       !WString(message[@"content"][@"content_type"],128)||!WOptionalString(message[@"recipient"],256)||!WOptionalString(message[@"channel"],64)||!WOptionalString(message[@"status"],128)||!WOptionalBool(message[@"end_turn"])||!WOptionalNumber(message[@"create_time"]))return WFail(error,1);
    id metadata=message[@"metadata"];if(metadata&&metadata!=WNull()&&!WDict(metadata))return WFail(error,1);
    if(metadata==WNull()||!metadata)metadata=@{};
    if(!WOptionalBool(metadata[@"is_visually_hidden_from_conversation"])||!WOptionalString(metadata[@"model_slug"],256))return WFail(error,1);
    NSString *role=message[@"author"][@"role"],*channel=message[@"channel"],*type=message[@"content"][@"content_type"];
    if(([role isEqual:@"assistant"]&&[message[@"recipient"]isKindOfClass:NSString.class]&&[message[@"recipient"]length]&&![message[@"recipient"]isEqual:@"all"])||!([role isEqual:@"user"]||[role isEqual:@"assistant"]) || (channel&&channel!=(id)WNull()&&![channel isEqual:@"final"]) || [metadata[@"is_visually_hidden_from_conversation"] isEqual:@YES] ||
       [@[@"reasoning_recap",@"reasoning",@"model_editable_context",@"thoughts"] containsObject:type]) return @{};
    NSMutableArray *parts=[NSMutableArray array];NSMutableString *text=[NSMutableString string];id values=message[@"content"][@"parts"];
    if([type isEqual:@"text"]||[type isEqual:@"multimodal_text"]) {
        if(!WArray(values)||[values count]>512)return WFail(error,1);
        for(id value in values) {
            if(WString(value,WTEXT)) {if([text length]+[value length]>WTEXT)return WFail(error,2);[text appendString:value];[parts addObject:@{@"kind":@"text",@"text":value}];}
            else if(WDict(value)) {
                NSString *contentType=value[@"content_type"];if(!WString(contentType,128))return WFail(error,1);
                NSDictionary *part=nil;
                if([contentType isEqual:@"image_asset_pointer"]) {if(!WString(value[@"asset_pointer"],4096)||![value[@"asset_pointer"] length])return WFail(error,1);part=WReference(value,@"asset",error);}
                else if([contentType isEqual:@"audio_transcription"]) {NSString*spoken=value[@"text"];if(!WString(spoken,WTEXT))return WFail(error,1);if(text.length+spoken.length>WTEXT)return WFail(error,2);[text appendString:spoken];part=@{@"kind":@"text",@"text":spoken};}
                else part=@{@"kind":@"unsupported",@"type":contentType};
                if(!part)return nil;[parts addObject:part];
            } else return WFail(error,1);
        }
    } else [parts addObject:@{@"kind":@"unsupported",@"type":type}];
    for(NSString *key in @[@"citations",@"content_references",@"attachments"]) {
        id references=metadata[key];if(!references||references==WNull())continue;
        if(!WArray(references)||[references count]>256)return WFail(error,1);
        for(id raw in references) {if(!WDict(raw))return WFail(error,1);NSString *kind=([key isEqual:@"attachments"]||[raw[@"type"] isEqual:@"file"])?@"asset":@"citation";
            NSDictionary *part=WReference(raw,kind,error);if(!part)return nil;
            NSArray *items=raw[@"items"];
            if([kind isEqual:@"citation"]&&WArray(items)) {
                if(items.count>100)return WFail(error,2);
                for(id item in items){if(!WDict(item))return WFail(error,1);NSMutableDictionary *source=[[item mutableCopy]autorelease];if(raw[@"matched_text"])source[@"matched_text"]=raw[@"matched_text"];NSDictionary *nested=WReference(source,kind,error);if(!nested)return nil;[parts addObject:nested];}
            }else [parts addObject:part];}
    }
    if(parts.count>1000)return WFail(error,2);
    NSMutableDictionary *out=[NSMutableDictionary dictionaryWithDictionary:@{@"id":message[@"id"],@"role":role,@"type":type,@"text":text,@"parts":parts,
        @"status":WOptional(message[@"status"]),@"endTurn":WOptional(message[@"end_turn"]),@"finished":@([message[@"status"] isEqual:@"finished_successfully"]),
        @"createdAt":WOptional(message[@"create_time"]),@"model":WOptional(metadata[@"model_slug"])}];
    if(nodeID)out[@"nodeId"]=nodeID;return out;
}
static BOOL WPublicImageMessage(NSDictionary *m) {
    NSDictionary *meta=WDict(m[@"metadata"])?m[@"metadata"]:nil;
    for(NSString *k in @[@"is_visually_hidden_from_conversation",@"is_visually_hidden_reasoning",@"is_visually_hidden_reasoning_group"])
        if(meta[k] && meta[k]!=WNull() && (![meta[k]isEqual:@NO] || !WBool(meta[k])))return NO;
    return YES;
}
/* A visible tool image is an answer artifact, not tool text. Project ONLY its
 * image pointers into the existing answer DTO. The reciprocal, acyclic graph is
 * validated first; the immediate call and nearest user bind the artifact. SSE
 * cannot make this projection because it has no authoritative parent graph. */
static NSDictionary *WToolImage(NSDictionary *mapping,NSString *key,NSError **error) {
    NSDictionary *node=mapping[key],*m=WDict(node[@"message"])?node[@"message"]:nil,*author=m[@"author"];
    if(!WDict(m)||![author[@"role"]isEqual:@"tool"]||!WString(author[@"name"],128)||![author[@"name"]length]||
       !WPublicImageMessage(m)||![m[@"status"]isEqual:@"finished_successfully"]||
       ![m[@"content"][@"content_type"]isEqual:@"multimodal_text"]||
       (m[@"channel"]&&m[@"channel"]!=WNull()&&![m[@"channel"]isEqual:@"commentary"]&&![m[@"channel"]isEqual:@"final"]))return @{};
    NSDictionary *callNode=mapping[node[@"parent"]],*call=callNode[@"message"];
    BOOL directUser=WDict(call)&&[call[@"author"][@"role"]isEqual:@"user"]&&WPublicImageMessage(call)&&[m[@"channel"]isEqual:@"final"];
    if(!directUser&&(!WDict(call)||![call[@"author"][@"role"]isEqual:@"assistant"]||!WPublicImageMessage(call)||
       ![call[@"channel"]isEqual:@"commentary"]||![call[@"recipient"]isEqual:author[@"name"]]||
       ![@[@"code",@"text"]containsObject:call[@"content"][@"content_type"]]))return @{};
    id cursor=directUser?node[@"parent"]:callNode[@"parent"];BOOL user=NO;
    for(NSUInteger n=0;cursor&&cursor!=WNull()&&n<WNODES;n++){
        NSDictionary *ancestor=mapping[cursor],*message=ancestor[@"message"];
        if([message isKindOfClass:NSDictionary.class]&&[message[@"author"][@"role"]isEqual:@"user"]){user=WPublicImageMessage(message);break;}
        cursor=ancestor[@"parent"];
    }
    if(!user)return @{};
    id values=m[@"content"][@"parts"];if(!WArray(values)||[values count]>16)return WFail(error,1);
    NSMutableArray *parts=[NSMutableArray array];NSMutableSet *files=[NSMutableSet set];
    for(id value in values){
        if(WString(value,WTEXT))continue; // never publish accompanying tool text
        if(!WDict(value)||![value[@"content_type"]isEqual:@"image_asset_pointer"])return @{};
        NSString *pointer=value[@"asset_pointer"],*file=nil;
        if(!WString(pointer,128))return WFail(error,1);
        for(NSString *prefix in @[@"sediment://",@"file-service://"])if([pointer hasPrefix:prefix])file=[pointer substringFromIndex:prefix.length];
        if(!file||!WFileID(file)||[files containsObject:file])return WFail(error,1);
        for(NSString *dimension in @[@"width",@"height"])if(value[dimension]&&!WInteger(value[dimension],100000))return WFail(error,1);
        NSDictionary *part=WReference(value,@"asset",error);if(!part)return nil;
        [files addObject:file];[parts addObject:part];
    }
    if(!parts.count)return @{};
    return @{@"id":m[@"id"],@"nodeId":key,@"role":@"assistant",@"type":@"generated_image",@"text":@"",@"parts":parts,
        @"status":m[@"status"],@"endTurn":WOptional(m[@"end_turn"]),@"finished":@YES,
        @"createdAt":WOptional(m[@"create_time"]),@"model":WNull()};
}
NSDictionary *OR6APIWireConversation(NSData *data,NSString *expectedID,NSError **error) {
    if(error)*error=nil;if(!WUUID(expectedID))return WFail(error,1);
    id root=WJSONRead(data,WJSON,error);if(!root)return nil;
    if(!WDict(root)||!WUUID(root[@"conversation_id"]))return WFail(error,1);
    if([root[@"conversation_id"] caseInsensitiveCompare:expectedID]!=NSOrderedSame)return WFail(error,8);
    id mapping=root[@"mapping"];
    if(!WDict(mapping)||![mapping count]||[mapping count]>WNODES||!WNodeID(root[@"current_node"])||!mapping[root[@"current_node"]]||!WString(root[@"title"],4096)||!WOptionalBool(root[@"is_archived"]))return WFail(error,3);
    NSMutableArray *nodes=[NSMutableArray array];NSMutableDictionary *visible=[NSMutableDictionary dictionary];NSMutableSet *messageIDs=[NSMutableSet set],*nodeIDs=[NSMutableSet set];
    for(NSString *key in [[mapping allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
        id node=mapping[key];if(!WDict(node))return WFail(error,3);
        id parent=node[@"parent"],children=node[@"children"],message=node[@"message"];
        if(!WNodeID(key)||[nodeIDs containsObject:[key lowercaseString]]||![node[@"id"] isEqual:key]||!parent||!(parent==WNull()||WNodeID(parent))||!WArray(children)||[children count]>WNODES||
           (parent!=WNull()&&!mapping[parent]))return WFail(error,3);
        [nodeIDs addObject:[key lowercaseString]];
        if([key isEqual:@"client-created-root"]&&(parent!=WNull()||(message&&message!=WNull())))return WFail(error,3);
        NSMutableSet *childIDs=[NSMutableSet set];
        for(id child in children) {if(!WNodeID(child)||[childIDs containsObject:child]||!WDict(mapping[child])||![mapping[child][@"parent"] isEqual:key])return WFail(error,3);[childIDs addObject:child];}
        if(parent!=WNull()&&(!WDict(mapping[parent])||!WArray(mapping[parent][@"children"])||![mapping[parent][@"children"] containsObject:key]))return WFail(error,3);
        NSString *messageID=nil;
        if(message&&message!=WNull()) {NSDictionary *dto=WMessage(message,key,error);if(!dto)return nil;messageID=message[@"id"];NSString *lower=[messageID lowercaseString];if([messageIDs containsObject:lower])return WFail(error,3);[messageIDs addObject:lower];if([dto count])visible[key]=dto;}
        [nodes addObject:@{@"id":key,@"parent":parent,@"children":children,@"messageId":WOptional(messageID)}];
    }
    /* Check every component, not just the visible branch. */
    NSMutableSet *checked=[NSMutableSet set];
    for(NSString *key in mapping) {NSMutableSet *walk=[NSMutableSet set];id cursor=key;
        while(cursor!=WNull()&&![checked containsObject:cursor]) {if([walk containsObject:cursor]||[walk count]>=WNODES)return WFail(error,3);[walk addObject:cursor];cursor=mapping[cursor][@"parent"];}
        [checked unionSet:walk];
    }
    NSMutableArray *branch=[NSMutableArray array];id current=root[@"current_node"];
    while(current!=WNull()) {
        NSDictionary *message=visible[current]?:WToolImage(mapping,current,error);if(!message)return nil;
        if(message.count)[branch addObject:message];current=mapping[current][@"parent"];
    }
    NSMutableArray*ordered=[NSMutableArray arrayWithArray:[[branch reverseObjectEnumerator]allObjects]],*summaries=[NSMutableArray array],*path=[NSMutableArray array];current=root[@"current_node"];
    while(current!=WNull()){[path insertObject:current atIndex:0];current=mapping[current][@"parent"];}
    NSMutableDictionary*indexes=[NSMutableDictionary dictionary];for(NSUInteger n=0;n<ordered.count;n++)indexes[ordered[n][@"nodeId"]]=@(n);
    for(NSString*key in path){NSDictionary*m=mapping[key][@"message"];if(!WDict(m))continue;if([m[@"author"][@"role"]isEqual:@"user"])[summaries removeAllObjects];NSString*summary=WReasoningSummary(m);if(summary.length&&summaries.count<32)[summaries addObject:@{@"kind":@"reasoning",@"text":summary}];
        if(summaries.count&&indexes[key]){NSUInteger n=[indexes[key]unsignedIntegerValue];if([ordered[n][@"role"]isEqual:@"assistant"]){NSMutableDictionary*row=[[ordered[n]mutableCopy]autorelease];row[@"parts"]=[row[@"parts"]arrayByAddingObjectsFromArray:summaries];ordered[n]=row;}}
    }
    NSDictionary*active=mapping[root[@"current_node"]][@"message"];
    if(WDict(active)&&[active[@"author"][@"role"]isEqual:@"assistant"]&&[active[@"status"]isEqual:@"in_progress"]&&![active[@"end_turn"]isEqual:@YES]&&
       ([active[@"channel"]isEqual:@"analysis"]||[@[@"reasoning_recap",@"thoughts"]containsObject:active[@"content"][@"content_type"]])&&(!ordered.count||![ordered.lastObject[@"role"]isEqual:@"assistant"])) {
        [ordered addObject:@{@"id":[@"pending:"stringByAppendingString:root[@"conversation_id"]],@"nodeId":root[@"current_node"],@"role":@"assistant",@"type":@"generation_status",@"text":@"",@"parts":summaries,@"status":@"in_progress",@"endTurn":WNull(),@"finished":@NO,@"createdAt":WNull(),@"model":WNull()}];
    }
    BOOL terminalAssistant=WDict(active)&&[active[@"author"][@"role"]isEqual:@"assistant"]&&[active[@"status"]isEqual:@"finished_successfully"]&&[active[@"end_turn"]isEqual:@YES];
    if([ordered.lastObject[@"role"]isEqual:@"user"]&&!terminalAssistant){
        [ordered addObject:@{@"id":[@"pending:"stringByAppendingString:root[@"conversation_id"]],@"nodeId":root[@"current_node"],@"role":@"assistant",@"type":@"awaiting_response",@"text":@"",@"parts":@[],@"status":@"waiting",@"endTurn":WNull(),@"finished":@NO,@"createdAt":WNull(),@"model":WNull()}];
    }
    for(NSString *key in path){NSDictionary *m=mapping[key][@"message"];if(!WDict(m))continue;
        NSNumber *index=indexes[key];if(!index||![ordered[index.unsignedIntegerValue][@"role"]isEqual:@"assistant"])continue;
        BOOL report=WResearchReport(m);
        if(report&&WPublicImageMessage(m)&&[m[@"status"]isEqual:@"finished_successfully"]&&[m[@"end_turn"]isEqual:@YES]&&!WPendingQuestions(m))WAddMenuContext(ordered,index.unsignedIntegerValue,@{@"researchReport":@YES});
    }
    BOOL questions=WPendingQuestions(active),approval=WPendingApproval(active);
    if((questions||approval)&&WUUID(active[@"id"])){
        for(NSUInteger n=0;n<ordered.count;n++)if([ordered[n][@"nodeId"]isEqual:root[@"current_node"]]&&[ordered[n][@"role"]isEqual:@"assistant"]){WAddMenuContext(ordered,n,@{@"pendingQuestions":@(questions),@"pendingAction":@(approval),@"pendingMessageId":active[@"id"]});break;}
    }
    // A finished empty final envelope often closes a generated-image turn. It
    // remains a real graph node/send parent, but is not a second answer card.
    // Do this after reasoning/menu context projection; all meaningful parts and
    // in-progress placeholders survive. SSE snapshots keep their status events.
    for (NSUInteger n=ordered.count;n>0;n--) {
        NSDictionary *m=ordered[n-1];
        if (![m[@"role"]isEqual:@"assistant"] || ![m[@"finished"]isEqual:@YES] ||
            ![m[@"endTurn"]isEqual:@YES] || [[m[@"text"]stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]length]) continue;
        BOOL meaningful=NO;
        for (NSDictionary *part in m[@"parts"]) if (![part[@"kind"]isEqual:@"text"] ||
            [[part[@"text"]stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]length]) { meaningful=YES;break; }
        if (!meaningful) [ordered removeObjectAtIndex:n-1];
    }
    return @{@"id":root[@"conversation_id"],@"title":root[@"title"],@"archived":@([root[@"is_archived"] isEqual:@YES]),@"currentNode":root[@"current_node"],@"nodes":nodes,@"messages":ordered};
}
/* A technical model configuration is not a menu entry. Only enabled public
 * version presets, linked to ordinary-chat categories, admit a model/mode.
 * No marketing-name allowlist and no fallback exposing the whole models array. */
static BOOL WModelText(id x,NSUInteger cap) { return WString(x,cap)&&[x length]>0; }
static BOOL WModelPublic(NSDictionary *m,NSSet *internal) {
    return m && WBool(m[@"is_work_mode_model"]) && [m[@"is_work_mode_model"] isEqual:@NO] &&
        WArray(m[@"tags"]) && ![m[@"tags"] containsObject:@"hidden"] && ![internal containsObject:m[@"slug"]];
}
static NSDictionary *WModelCategory(NSArray *categories,NSString *slug,NSString *lane) {
    for(id c in categories) if(WDict(c)&&[c[@"default_model"] isEqual:slug]&&
        [c[@"model_lane"] isEqual:lane]&&WArray(c[@"supported_models"])&&
        [c[@"supported_models"] containsObject:slug]&&WModelText(c[@"human_category_name"],240)) return c;
    return nil;
}
NSDictionary *OR6APIWireModels(NSData *data,NSError **error) {
    if(error)*error=nil;id root=WJSONRead(data,WJSON,error);if(!root)return nil;
    if(!WDict(root)||!WArray(root[@"models"])||[root[@"models"] count]>128)return WFail(error,1);
    NSMutableDictionary *models=[NSMutableDictionary dictionary];
    for(id m in root[@"models"]) {
        if(!WDict(m)||!WModelText(m[@"slug"],128)||!WModelText(m[@"title"],240)||models[m[@"slug"]])return WFail(error,1);
        models[m[@"slug"]]=m;
    }
    NSArray *versions=root[@"versions"],*categories=root[@"categories"];
    // Older/unknown catalogs are safe to read, but do not confer picker admission.
    if(!versions&&!categories)return @{@"items":@[]};
    if(!WArray(versions)||versions.count>32||!WArray(categories)||categories.count>128)return WFail(error,1);
    NSMutableSet *internal=[NSMutableSet set];
    id groups=root[@"internal_groups"];
    if(groups){
        if(!WArray(groups)||[groups count]>32)return WFail(error,1);
        for(id g in groups){if(!WDict(g)||!WArray(g[@"model_ids"])||[g[@"model_ids"] count]>128)return WFail(error,1);
            for(id slug in g[@"model_ids"]){if(!WModelText(slug,128))return WFail(error,1);[internal addObject:slug];}}
    }
    NSMutableArray *items=[NSMutableArray array];NSMutableSet *seen=[NSMutableSet set],*families=[NSMutableSet set];
    for(id v in versions){
        if(!WDict(v)||!WModelText(v[@"id"],128)||[families containsObject:v[@"id"]])return WFail(error,1);
        [families addObject:v[@"id"]];
        if(!WBool(v[@"enabled"])||![v[@"enabled"] isEqual:@YES])continue;
        NSString *family=v[@"display_text_for_intelligence"]?:v[@"display_text_full"]?:v[@"display_text"];
        NSArray *slugs=v[@"slugs"],*presets=v[@"intelligence_presets"];
        if(!WModelText(family,240)||!WArray(slugs)||slugs.count>128||!WArray(presets)||presets.count>64)return WFail(error,1);
        for(id slug in slugs)if(!WModelText(slug,128))return WFail(error,1);
        NSMutableDictionary *modes=[NSMutableDictionary dictionary];NSMutableArray *modeOrder=[NSMutableArray array];
        for(id preset in presets){
            if(!WDict(preset))return WFail(error,1);
            if(![preset[@"preset_type"] isEqual:@"available"])continue;
            NSString *slug=preset[@"model_slug"],*lane=preset[@"lane"],*effort=preset[@"thinking_effort"];
            if(!WModelText(slug,128)||!WModelText(lane,128)||!WModelText(preset[@"title"],240))return WFail(error,1);
            if(![slugs containsObject:slug]||!WModelPublic(models[slug],internal))continue;
            NSDictionary *category=WModelCategory(categories,slug,lane);if(!category)continue;
            // The observed frontend maps the current family's Instant preset to
            // its server-default auto route when that route is explicitly grouped.
            NSString *def=root[@"default_model_slug"];
            if([lane isEqual:@"instant"]&&[slugs containsObject:def]&&WModelPublic(models[def],internal)&&WModelCategory(categories,def,@"auto"))slug=def;
            NSMutableDictionary *mode=modes[lane];
            if(mode&&![mode[@"id"] isEqual:slug])return WFail(error,1);
            if(effort&&effort!=WNull()){
                if(!WModelText(effort,64)||![models[slug][@"configurable_thinking_effort"] isEqual:@YES])continue;
                BOOL admitted=NO;id efforts=models[slug][@"thinking_efforts"];
                if(!WArray(efforts)||[efforts count]>32)return WFail(error,1);
                for(id e in efforts)if(WDict(e)&&[e[@"thinking_effort"] isEqual:effort])admitted=YES;
                if(!admitted)continue;
            }
            if(!mode){mode=[NSMutableDictionary dictionaryWithDictionary:@{@"id":slug,@"title":models[slug][@"title"],@"capabilities":@[],@"familyId":v[@"id"],@"familyTitle":family,@"modeId":lane,@"modeTitle":category[@"human_category_name"],@"efforts":[NSMutableArray array],@"defaultEffort":WNull()}];modes[lane]=mode;[modeOrder addObject:lane];}
            if(effort&&effort!=WNull()){
                NSMutableArray *efforts=mode[@"efforts"];BOOL duplicate=NO;
                for(NSDictionary *e in efforts)if([e[@"id"] isEqual:effort])duplicate=YES;
                if(!duplicate)[efforts addObject:@{@"id":effort,@"title":preset[@"title"]}];
            }
        }
        for(NSString *lane in modeOrder){NSDictionary *mode=modes[lane];if([seen containsObject:mode[@"id"]])continue;[seen addObject:mode[@"id"]];[items addObject:mode];}
    }
    if(items.count>100)return WFail(error,1);
    return @{@"items":items};
}
NSDictionary *OR6APIWireSearch(NSData *data,NSString *previousCursor,NSError **error) {
    if(error)*error=nil;if(previousCursor&&!WString(previousCursor,4096))return WFail(error,1);
    id root=WJSONRead(data,WJSON,error);if(!root)return nil;
    if(!WDict(root)||!WArray(root[@"items"])||[root[@"items"] count]>100||!(root[@"cursor"]==WNull()||(WString(root[@"cursor"],4096)&&[root[@"cursor"] length])))return WFail(error,1);
    if(previousCursor&&[root[@"cursor"] isEqual:previousCursor])return WFail(error,1);
    NSMutableArray *items=[NSMutableArray array];NSMutableSet *seen=[NSMutableSet set];
    for(id raw in root[@"items"]) {if(!WDict(raw)||!WString(raw[@"source_type"],128))return WFail(error,1);if(![raw[@"source_type"] isEqual:@"conversation"])continue;
        id payload=raw[@"payload"];if(!WDict(payload)||!WString(payload[@"kind"],128))return WFail(error,1);if(![payload[@"kind"] isEqual:@"conversation"])continue;
        if(!WUUID(payload[@"conversation_id"])||!WString(raw[@"title"],4096)||!WOptionalBool(payload[@"is_archived"])||!WOptionalString(raw[@"snippet"],WTEXT))return WFail(error,1);
        id updated=WTimestamp(raw[@"update_time"]);if(!updated)return WFail(error,1);
        NSString *identifier=payload[@"conversation_id"];if([seen containsObject:[identifier lowercaseString]])continue;[seen addObject:[identifier lowercaseString]];
        [items addObject:@{@"id":identifier,@"title":raw[@"title"],@"updatedAt":updated,@"archived":@([payload[@"is_archived"] isEqual:@YES]),@"snippet":(raw[@"snippet"]&&raw[@"snippet"]!=WNull())?raw[@"snippet"]:@""}];
    }return @{@"items":items,@"nextToken":root[@"cursor"]};
}

/* Safe JSON Pointer and patch subset, with canonical decimal array indices. */
static NSArray *WPath(id path) {
    if(!WString(path,4096))return nil;if(![path length])return @[];if(![path hasPrefix:@"/"])return nil;
    NSArray *raw=[[path substringFromIndex:1] componentsSeparatedByString:@"/"];if([raw count]>WDEPTH)return nil;NSMutableArray *parts=[NSMutableArray array];
    for(NSString *part in raw) {NSMutableString *key=[NSMutableString string];
        for(NSUInteger i=0;i<[part length];i++) {unichar c=[part characterAtIndex:i];if(c=='~'){if(++i==[part length])return nil;unichar next=[part characterAtIndex:i];if(next!='0'&&next!='1')return nil;[key appendString:next=='0'?@"~":@"/"];}
            else [key appendFormat:@"%C",c];}
        if([@[@"__proto__",@"constructor",@"prototype"] containsObject:key])return nil;[parts addObject:key];
    }return parts;
}
static BOOL WIndex(NSString *key,NSUInteger count,BOOL insertion,NSUInteger *index) {
    if(insertion&&[key isEqual:@"-"]){*index=count;return YES;}if(![key length]||[key length]>8||([key length]>1&&[key characterAtIndex:0]=='0'))return NO;
    NSUInteger n=0;for(NSUInteger i=0;i<[key length];i++){unichar c=[key characterAtIndex:i];if(c<'0'||c>'9')return NO;n=n*10+(c-'0');if(n>WVALUES)return NO;}
    if(insertion?n>count:n>=count)return NO;*index=n;return YES;
}
static id WClone(id value) {
    if(WDict(value)){NSMutableDictionary *out=[NSMutableDictionary dictionary];for(id key in value)out[key]=WClone(value[key]);return out;}
    if(WArray(value)){NSMutableArray *out=[NSMutableArray array];for(id x in value)[out addObject:WClone(x)];return out;}
    return [[value copy] autorelease];
}
static BOOL WPatch(NSMutableDictionary *state,NSString *path,NSString *operation,id value) {
    NSArray *parts=WPath(path);if(!parts||!WString(operation,32)||![@[@"add",@"replace",@"remove",@"append"] containsObject:operation])return NO;
    if(![parts count]) {if(!([operation isEqual:@"add"]||[operation isEqual:@"replace"])||!WDict(value))return NO;[state setDictionary:WClone(value)];return YES;}
    id parent=state;
    for(NSUInteger i=0;i+1<[parts count];i++){NSString *key=parts[i];if(WDict(parent))parent=parent[key];else if(WArray(parent)){NSUInteger index;if(!WIndex(key,[parent count],NO,&index))return NO;parent=parent[index];}else return NO;if(!parent)return NO;}
    NSString *key=[parts lastObject];BOOL add=[operation isEqual:@"add"],remove=[operation isEqual:@"remove"];NSUInteger index=0;id old=nil;
    if(WDict(parent))old=parent[key];else if(WArray(parent)){if(!WIndex(key,[parent count],add,&index))return NO;if(index<[parent count])old=parent[index];}else return NO;
    if(!add&&!old)return NO;
    if([operation isEqual:@"append"]) {
        if(WString(old,WTEXT)&&WString(value,WTEXT)) {if([old length]+[value length]>WTEXT)return NO;value=[old stringByAppendingString:value];}
        else if(WArray(old)&&WArray(value)){if([old count]+[value count]>WVALUES)return NO;NSMutableArray *joined=WClone(old);[joined addObjectsFromArray:WClone(value)];value=joined;}
        else if(WDict(old)&&WDict(value)){NSMutableDictionary *joined=WClone(old);for(NSString *member in value){if(!WPath([@"/" stringByAppendingString:member]))return NO;joined[member]=WClone(value[member]);}value=joined;}
        else return NO;
    } else if(!remove) {if(!value)return NO;value=WClone(value);}
    if(WDict(parent)){if(remove)[parent removeObjectForKey:key];else parent[key]=value;}
    else {if(remove)[parent removeObjectAtIndex:index];else if(add)[parent insertObject:value atIndex:index];else parent[index]=value;}
    NSUInteger count=0;return WTree(state,0,&count);
}

// Protocol tag fingerprints never include data fields or server error messages.
static NSString *WTagHash(id value){
    if(!WString(value,128))return nil;NSData*d=[value dataUsingEncoding:NSUTF8StringEncoding];unsigned char bytes[CC_SHA256_DIGEST_LENGTH];CC_SHA256(d.bytes,(CC_LONG)d.length,bytes);NSMutableString*s=[NSMutableString string];for(NSUInteger i=0;i<sizeof(bytes);i++)[s appendFormat:@"%02x",bytes[i]];return s;
}
static BOOL WActiveError(id value){return value&&value!=WNull()&&![value isEqual:@NO]&&![value isEqual:@""];}
static NSString *WServerIssue(id payload){
    NSDictionary*p=WDict(payload)?payload:@{},*e=WDict(p[@"error"])?p[@"error"]:p;
    NSArray*values=@[e[@"code"]?:WNull(),e[@"type"]?:WNull(),p[@"error_code"]?:WNull(),p[@"code"]?:WNull()];
    NSDictionary*groups=@{@"rate_limited":@[@"rate_limit_exceeded",@"rate_limit_error",@"rate_limited",@"too_many_requests",@"model_cap_exceeded",@"usage_limit_reached"],@"not_authenticated":@[@"unauthorized",@"invalid_token",@"token_expired",@"authentication_error"],@"access_denied":@[@"access_denied",@"permission_denied",@"forbidden",@"content_policy_violation"],@"timeout":@[@"timeout",@"request_timeout",@"upstream_timeout",@"gateway_timeout"]};
    for(id value in values)if(WString(value,128))for(NSString*issue in groups)if([groups[issue]containsObject:[value lowercaseString]])return issue;
    id status=e[@"status"]?:e[@"status_code"]?:p[@"status"];if(WInteger(status,599)){NSInteger n=[status integerValue];if(n==401)return @"not_authenticated";if(n==403)return @"access_denied";if(n==429)return @"rate_limited";if(n==408||n==504)return @"timeout";}
    return @"upstream_error";
}

static NSString *WReasoningSummary(NSDictionary *m) {
    NSString*type=m[@"content"][@"content_type"];
    if(![m[@"author"][@"role"]isEqual:@"assistant"]||![@[@"reasoning_recap",@"thoughts"]containsObject:type]||!WPublicImageMessage(m)||
       (m[@"recipient"]&&m[@"recipient"]!=WNull()&&![m[@"recipient"]isEqual:@"all"]))return nil;
    id parts=m[@"content"][@"parts"];
    if([type isEqual:@"reasoning_recap"]&&WString(m[@"content"][@"content"],WTEXT))parts=@[m[@"content"][@"content"]];
    if([type isEqual:@"thoughts"]){id thoughts=m[@"content"][@"thoughts"];if(!WArray(thoughts)||[thoughts count]>64)return nil;NSMutableArray*safe=[NSMutableArray array];for(id thought in thoughts){if(!WDict(thought)||!WString(thought[@"summary"],WTEXT))return nil;[safe addObject:thought[@"summary"]];}parts=safe;}
    if(!WArray(parts)||[parts count]>64)return nil;NSMutableString *s=[NSMutableString string];
    for(id value in parts){if(!WString(value,WTEXT))return nil;if(s.length)[s appendString:@" "];[s appendString:value];if(s.length>=240)break;}
    if(s.length>240){NSUInteger n=240;if(CFStringIsSurrogateHighCharacter([s characterAtIndex:n-1]))n--;return[s substringToIndex:n];}return s;
}

@interface OR6APIDeltaDecoder ()
- (BOOL)block:(NSData *)block events:(NSMutableArray *)events error:(NSError **)error;
- (NSArray *)fail:(NSError **)error code:(NSInteger)code;
- (BOOL)reject:(NSInteger)code reason:(NSString *)reason error:(NSError **)error;
- (void)failure:(NSInteger)code reason:(NSString *)reason;
@end
@implementation OR6APIDeltaDecoder
- (id)init {if((self=[super init])){_pending=[[NSMutableData alloc]init];_state=[[NSMutableDictionary alloc]init];_path=[@"" copy];_operation=[@"add" copy];}return self;}
- (BOOL)done{return _done;}
- (BOOL)complete{return _complete;}
- (void)failure:(NSInteger)code reason:(NSString *)reason {
    if(_failureInfo)return;NSMutableDictionary*d=[NSMutableDictionary dictionaryWithDictionary:_frameInfo?:@{}];d[@"frame"]=@(_blocks);d[@"dataFrame"]=@(_events);d[@"wireCode"]=@(code);d[@"reason"]=reason;
    NSString*issue=_failureIssue?:code==6?@"upstream_error":code==2?@"size_limit":code==7?@"uncertain_outcome":@"unknown_wire_shape";d[@"issue"]=issue;_failureInfo=[d copy];if(!_failureIssue)_failureIssue=[issue copy];
}
- (BOOL)reject:(NSInteger)code reason:(NSString *)reason error:(NSError **)error{[self failure:code reason:reason];WFail(error,code);return NO;}
- (NSArray *)fail:(NSError **)error code:(NSInteger)code { [self failure:code reason:code==7?@"incomplete_stream":@"stream_limit"];_failed=YES;[_pending setLength:0];[_state removeAllObjects];return WFail(error,code); }
- (NSString *)failureIssue{return _failureIssue;}
- (NSArray *)takeFailureEvents{NSArray*r=[[_failureEvents retain]autorelease];[_failureEvents release];_failureEvents=nil;return r?:@[];}
- (BOOL)block:(NSData *)block events:(NSMutableArray *)events error:(NSError **)error {
    _blocks++;[_frameInfo release];_frameInfo=[NSMutableDictionary new];_frameInfo[@"event"]=@"message";_frameInfo[@"frameBytes"]=@(block.length);
    NSString *text=[[[NSString alloc]initWithData:block encoding:NSUTF8StringEncoding]autorelease];if(!text||!WUnicode(text))return[self reject:4 reason:@"invalid_utf8"error:error];
    NSMutableArray *lines=[NSMutableArray array];NSString *event=@"message";BOOL eventSeen=NO;
    for(NSString *raw in [text componentsSeparatedByString:@"\n"]) {
        NSString *line=[raw hasSuffix:@"\r"]?[raw substringToIndex:[raw length]-1]:raw;
        if([line rangeOfString:@"\r"].location!=NSNotFound){return[self reject:4 reason:@"invalid_frame"error:error];}
        if([line hasPrefix:@":"]||![line length])continue;
        NSRange colon=[line rangeOfString:@":"];NSString *field=colon.location==NSNotFound?line:[line substringToIndex:colon.location];NSString *value=colon.location==NSNotFound?@"":[line substringFromIndex:colon.location+1];if([value hasPrefix:@" "])value=[value substringFromIndex:1];
        if([field isEqual:@"event"]){if(eventSeen||![value length]||[value length]>128){return[self reject:4 reason:@"invalid_frame"error:error];}event=value;eventSeen=YES;}
        else if([field isEqual:@"data"])[lines addObject:value];
        else if(![field isEqual:@"id"]&&![field isEqual:@"retry"]){return[self reject:4 reason:@"invalid_frame"error:error];}
    }
    NSArray*knownEvents=@[@"message",@"delta",@"delta_encoding",@"error"];
    _frameInfo[@"event"]=[knownEvents containsObject:event]?event:@"other";if(![knownEvents containsObject:event]){NSString*h=WTagHash(event);if(h)_frameInfo[@"eventTagSHA256"]=h;}
    if(![lines count])return YES;
    if(_done){return[self reject:4 reason:@"invalid_frame"error:error];}
    if(++_events>8192){return[self reject:2 reason:@"frame_limit"error:error];}
    NSString *body=[lines componentsJoinedByString:@"\n"];
    if([body isEqual:@"[DONE]"]&&[event isEqual:@"error"]){_failureIssue=[@"upstream_error"copy];return[self reject:6 reason:@"error_event"error:error];}
    if([body isEqual:@"[DONE]"]){_done=YES;[events addObject:@{@"type":@"done",@"complete":@(_complete)}];return YES;}
    id payload=WJSONRead([body dataUsingEncoding:NSUTF8StringEncoding],WFRAME,error);
    if(!payload){if([event isEqual:@"error"]){_failureIssue=[@"upstream_error"copy];return[self reject:6 reason:@"error_event_non_json"error:error];}[self failure:(error&&*error)?(*error).code:4 reason:@"invalid_json"];return NO;}
    if(WDict(payload)){
        NSArray*keys=@[@"error",@"error_code",@"type",@"code",@"message",@"detail",@"status"];NSUInteger mask=0;for(NSUInteger n=0;n<keys.count;n++)if(payload[keys[n]])mask|=(1u<<n);_frameInfo[@"rootKeyMask"]=@(mask);
        id kind=payload[@"type"];NSArray*known=@[@"error",@"message_stream_error",@"message_stream_complete",@"resume_conversation_token",@"input_message",@"title_generation",@"message_marker",@"server_ste_metadata",@"conversation_detail_metadata"];
        if(kind){_frameInfo[@"control"]=[known containsObject:kind]?kind:@"other";if(![known containsObject:kind]){NSString*h=WTagHash(kind);if(h)_frameInfo[@"controlTagSHA256"]=h;}}
        id value=payload[@"error"];_frameInfo[@"errorShape"]=!value||value==WNull()?@"none":WDict(value)?@"object":WString(value,WFRAME)?@"string":[value isKindOfClass:NSNumber.class]?@"number":@"other";
        NSDictionary*err=WDict(payload[@"error"])?payload[@"error"]:payload;id code=err[@"code"]?:payload[@"error_code"]?:err[@"type"];
        NSArray*knownCodes=@[@"error",@"server_error",@"internal_server_error",@"internal_error",@"upstream_error",@"rate_limit_exceeded",@"rate_limit_error",@"rate_limited",@"too_many_requests",@"model_cap_exceeded",@"usage_limit_reached",@"unauthorized",@"invalid_token",@"token_expired",@"authentication_error",@"access_denied",@"permission_denied",@"forbidden",@"content_policy_violation",@"timeout",@"request_timeout",@"upstream_timeout",@"gateway_timeout",@"engine_overloaded",@"model_not_found",@"context_length_exceeded"];
        _frameInfo[@"serverCode"]=!code||code==WNull()?@"none":[knownCodes containsObject:code]?code:@"other";
        if(code&&code!=WNull()&&![knownCodes containsObject:code]){NSString*h=WTagHash(code);if(h)_frameInfo[@"serverCodeTagSHA256"]=h;}

    }
    BOOL envelope=WDict(payload)&&(WActiveError(payload[@"error"])||WActiveError(payload[@"error_code"])||[payload[@"type"]isEqual:@"error"]||[payload[@"type"]isEqual:@"message_stream_error"]);
    if([event isEqual:@"error"]||envelope){_failureIssue=[WServerIssue(payload)copy];return[self reject:6 reason:[event isEqual:@"error"]?@"error_event":@"error_envelope"error:error];}
    if([event isEqual:@"delta_encoding"]){if(_encodingSeen||![payload isEqual:@"v1"]){return[self reject:5 reason:@"unsupported_encoding"error:error];}_encodingSeen=YES;return YES;}
    if(!WDict(payload)){return[self reject:4 reason:@"invalid_frame"error:error];}
    if(![event isEqual:@"delta"]) {
        // Newer informational events (unknown names or control types) are skipped, not fatal:
        // they carry no answer text and the message itself still arrives through delta patches.
        if(![event isEqual:@"message"])return YES;
        NSString *kind=payload[@"type"];if(!WString(kind,128))return[self reject:4 reason:@"invalid_frame"error:error];
        if([kind isEqual:@"message_stream_complete"]){if(_complete){return[self reject:4 reason:@"invalid_frame"error:error];}_complete=YES;[events addObject:@{@"type":@"complete"}];return YES;}
        if(![@[@"resume_conversation_token",@"input_message",@"title_generation",@"message_marker",@"server_ste_metadata",@"conversation_detail_metadata"] containsObject:kind])return YES;
        if([kind isEqual:@"title_generation"]&&WUUID(payload[@"conversation_id"])&&WString(payload[@"title"],2000)) {
            if(_state[@"conversation_id"]&&[_state[@"conversation_id"]caseInsensitiveCompare:payload[@"conversation_id"]]!=NSOrderedSame)return[self reject:8 reason:@"identity_mismatch"error:error];
            [events addObject:@{@"type":@"title",@"conversationId":payload[@"conversation_id"],@"title":payload[@"title"]}];
        }else [events addObject:@{@"type":@"status",@"status":kind}];return YES;
    }
    if(!_encodingSeen){return[self reject:5 reason:@"unsupported_encoding"error:error];}
    // Informational delta frames (for example reasoning status) carry none of the patch keys;
    // they change no message state and are skipped. Partial or mixed patch frames stay invalid.
    if(!payload[@"p"]&&!payload[@"o"]&&!payload[@"c"]&&!payload[@"v"])return YES;
    if(_complete){return[self reject:4 reason:@"invalid_frame"error:error];}
    for(NSString *key in payload)if(![@[@"p",@"o",@"c",@"v"] containsObject:key]){return[self reject:4 reason:@"invalid_frame"error:error];}
    NSString *path=(payload[@"p"]&&payload[@"p"]!=WNull())?payload[@"p"]:_path,*operation=(payload[@"o"]&&payload[@"o"]!=WNull())?payload[@"o"]:_operation;
    id context=(payload[@"c"]&&payload[@"c"]!=WNull())?payload[@"c"]:_context;
    if(!WPath(path)||!WString(operation,32)||![@[@"add",@"replace",@"remove",@"append",@"patch"] containsObject:operation]||
       (context&&context!=WNull()&&!WInteger(context,2147483647))){return[self reject:4 reason:@"invalid_frame"error:error];}
    BOOL contextChanged=!(context==_context||[context isEqual:_context]);
    if(contextChanged&& !([path isEqual:@""]&&([operation isEqual:@"add"]||[operation isEqual:@"replace"]))){return[self reject:4 reason:@"invalid_frame"error:error];}
    NSMutableDictionary *next=WClone(_state);BOOL applied=YES;
    if([operation isEqual:@"patch"]){if(!WArray(payload[@"v"])||[payload[@"v"] count]>256){return[self reject:4 reason:@"invalid_frame"error:error];}
        for(id patch in payload[@"v"]){if(!WDict(patch)||[patch count]<2||[patch count]>3){applied=NO;break;}for(NSString *key in patch)if(![@[@"p",@"o",@"v"] containsObject:key])applied=NO;
            if(!applied||!WPatch(next,patch[@"p"],patch[@"o"],patch[@"v"])){applied=NO;break;}}
    }else applied=WPatch(next,path,operation,payload[@"v"]);
    if(!applied)return[self reject:4 reason:@"invalid_patch"error:error];
    if(WActiveError(next[@"error"])||WActiveError(next[@"error_code"])){_failureIssue=[WServerIssue(next)copy];return[self reject:6 reason:@"delta_error_state"error:error];}
    id conversationID=next[@"conversation_id"],oldConversation=_state[@"conversation_id"],message=next[@"message"];
    if(conversationID&&!WUUID(conversationID)){return[self reject:4 reason:@"invalid_frame"error:error];}
    if(oldConversation&&conversationID&&[oldConversation caseInsensitiveCompare:conversationID]!=NSOrderedSame){return[self reject:8 reason:@"identity_mismatch"error:error];}
    if(oldConversation&&!conversationID){return[self reject:8 reason:@"identity_mismatch"error:error];}
    NSDictionary *dto=nil;if(message&&message!=WNull()){if(!conversationID){return[self reject:8 reason:@"identity_mismatch"error:error];}dto=WMessage(message,nil,error);if(!dto){[self failure:(error&&*error)?(*error).code:1 reason:@"invalid_message"];return NO;}}
    id priorMessage=_state[@"message"];
    if(WDict(priorMessage)&&WDict(message)&&![priorMessage[@"id"] isEqual:message[@"id"]]&& !([path isEqual:@""]&&([operation isEqual:@"add"]||[operation isEqual:@"replace"]))) {return[self reject:8 reason:@"identity_mismatch"error:error];}
    /* Every new identity is emitted before its snapshot; hidden messages do not
     * leak their IDs/content into presentation events. */
    if([dto count]) {
        id oldMessage=_state[@"message"];NSDictionary *oldDTO=WDict(oldMessage)?WMessage(oldMessage,nil,NULL):nil;
        if(![oldConversation isEqual:conversationID]||![oldDTO count]||![oldMessage[@"id"] isEqual:message[@"id"]])
            [events addObject:@{@"type":@"identity",@"conversationId":conversationID,@"messageId":message[@"id"]}];
        [events addObject:@{@"type":@"messageSnapshot",@"conversationId":conversationID,@"message":dto}];
        if(message[@"status"]&&message[@"status"]!=WNull())[events addObject:@{@"type":@"status",@"status":message[@"status"],@"conversationId":conversationID,@"messageId":message[@"id"]}];
    }
    if(!dto.count&&WDict(message)&&[message[@"author"][@"role"]isEqual:@"assistant"]&&([message[@"channel"]isEqual:@"analysis"]||[@[@"reasoning_recap",@"thoughts"]containsObject:message[@"content"][@"content_type"]])&&[message[@"status"]isEqual:@"in_progress"]){
        NSString *summary=WReasoningSummary(message);
        [events addObject:@{@"type":@"status",@"status":@"in_progress",@"phase":@"thinking",@"label":summary?:@""}];
    }
    _deltaFrames++;
    if(WDict(message)&&[message[@"author"][@"role"]isEqual:@"assistant"]){
        if([message[@"channel"]isEqual:@"analysis"])_analysisFrames++;
        if([dto count])_visibleAssistantFrames++;else _hiddenAssistantFrames++;
    }
    NSString *nextPath=[path copy],*nextOperation=[operation copy];id nextContext=[context copy];
    [_state setDictionary:next];[_path release];_path=nextPath;[_operation release];_operation=nextOperation;[_context release];_context=nextContext;return YES;
}
- (NSDictionary *)diagnostics{return @{@"bytes":@(_bytes),@"frames":@(_events),@"deltaFrames":@(_deltaFrames),@"analysisFrames":@(_analysisFrames),@"hiddenAssistantFrames":@(_hiddenAssistantFrames),@"visibleAssistantFrames":@(_visibleAssistantFrames),@"pendingFrameBytes":@(_pending.length),@"failure":_failureInfo?:@{}};}
- (NSArray *)feed:(NSData *)bytes final:(BOOL)final error:(NSError **)error {
    if(error)*error=nil;if(_failed)return WFail(error,4);
    if(![bytes isKindOfClass:[NSData class]]||[bytes length]>WSTREAM-_bytes)return [self fail:error code:2];_bytes+=[bytes length];
    NSMutableArray *events=[NSMutableArray array];const unsigned char *input=[bytes bytes];NSUInteger queuedBytes=0;
    /* Append incrementally, so a large caller chunk cannot bypass frame bounds
     * or force an equally large temporary copy. UTF8 is decoded per full frame. */
    for(NSUInteger i=0;i<[bytes length];i++) {
        unsigned char c=input[i];[_pending appendBytes:&c length:1];if([_pending length]>WFRAME){[_frameInfo release];_frameInfo=[@{@"event":@"unparsed",@"frameBytes":@(_pending.length)}mutableCopy];_blocks++;[_failureEvents release];_failureEvents=[events copy];return [self fail:error code:2];}
        if(c!='\n')continue;NSUInteger n=[_pending length];const unsigned char *p=[_pending bytes];NSUInteger end=n-1;if(end&&p[end-1]=='\r')end--;
        BOOL boundary=end==0||p[end-1]=='\n';if(!boundary)continue;
        /* A caller may feed thousands of tiny chunks inside one outer pool.
         * Drain patch clones and JSON temporaries per complete frame. */
        NSAutoreleasePool *pool=[[NSAutoreleasePool alloc]init];NSError *blockError=nil;NSUInteger before=[events count];
        NSData *block=[NSData dataWithBytes:p length:end];BOOL valid=[self block:block events:events error:&blockError];[blockError retain];
        BOOL overflow=[events count]>256;
        if(valid&&!overflow)for(NSUInteger e=before;e<[events count];e++) {
            NSData *encoded=[NSJSONSerialization dataWithJSONObject:events[e] options:0 error:NULL];
            if(!encoded||[encoded length]>WJSON-queuedBytes){overflow=YES;break;}queuedBytes+=[encoded length];
        }
        [pool drain];[_pending setLength:0];
        if(!valid){[self failure:blockError.code reason:@"invalid_frame"];[_failureEvents release];_failureEvents=[[events subarrayWithRange:NSMakeRange(0,before)]copy];_failed=YES;[_state removeAllObjects];if(error)*error=[blockError autorelease];else[blockError release];return nil;}
        [blockError release];if(overflow){[_failureEvents release];_failureEvents=[[events subarrayWithRange:NSMakeRange(0,before)]copy];return [self fail:error code:2];}
    }
    if(final&&[_pending length]){[_frameInfo release];_frameInfo=[@{@"event":@"eof",@"pendingBytes":@(_pending.length)}mutableCopy];[_failureEvents release];_failureEvents=[events copy];return [self fail:error code:7];}
    if(final&&!_done){[_frameInfo release];_frameInfo=[@{@"event":@"eof",@"pendingBytes":@0}mutableCopy];[_failureEvents release];_failureEvents=[events copy];return [self fail:error code:7];}
    return events;
}
- (void)dealloc {[_frameInfo release];[_failureInfo release];[_failureEvents release];[_failureIssue release];[_pending release];[_state release];[_path release];[_operation release];[_context release];[super dealloc];}
@end
