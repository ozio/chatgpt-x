#import "localization/OR6Localization.h"
#import "OR6Content.h"

static const NSUInteger OR6ContentChunk=1600;

NSString *OR6ContentSafeURL(NSString *value, BOOL image) {
    if (![value isKindOfClass:NSString.class] || !value.length || value.length>4096) return nil;
    if ([value rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location!=NSNotFound || [value rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound) return nil;
    NSURL *url=[NSURL URLWithString:value];NSString *scheme=[url.scheme lowercaseString],*host=[url.host lowercaseString];
    if (!(image ? [scheme isEqual:@"https"] : ([scheme isEqual:@"https"] || [scheme isEqual:@"http"])) || !host.length || url.user.length || url.password.length) return nil;
    if (image) {
        if ([host isEqual:@"localhost"] || [host hasSuffix:@".localhost"] || [host hasSuffix:@".local"] || [host rangeOfString:@"."].location==NSNotFound || [host rangeOfString:@":"].location!=NSNotFound) return nil;
        NSArray *parts=[host componentsSeparatedByString:@"."];BOOL numeric=YES;
        for (NSString *part in parts) if (!part.length || [part rangeOfCharacterFromSet:[NSCharacterSet.decimalDigitCharacterSet invertedSet]].location!=NSNotFound) numeric=NO;
        if (numeric) {
            if (parts.count!=4) return nil;
            for (NSString *part in parts) if (part.integerValue>255) return nil;
            NSInteger a=[parts[0] integerValue],b=[parts[1] integerValue];
            if (a==0 || a==10 || a==127 || a>=224 || (a==169 && b==254) || (a==172 && b>=16 && b<=31) || (a==192 && b==168) || (a==100 && b>=64 && b<=127) || (a==198 && (b==18 || b==19))) return nil;
        }
    }
    return url.absoluteString;
}

NSData *OR6ContentDecodeBase64(NSString *value, NSUInteger maximumBytes) {
    if (![value isKindOfClass:NSString.class] || !value.length || value.length%4 || value.length>((maximumBytes+2)/3)*4) return nil;
    NSMutableData *output=[NSMutableData dataWithCapacity:MIN(maximumBytes,(value.length/4)*3)];
    for (NSUInteger i=0;i<value.length;i+=4) {
        unsigned int word=0;NSUInteger padding=0;
        for (NSUInteger j=0;j<4;j++) {
            unichar c=[value characterAtIndex:i+j];int n=-1;
            if (c>='A' && c<='Z') n=c-'A';else if (c>='a' && c<='z') n=c-'a'+26;else if (c>='0' && c<='9') n=c-'0'+52;else if (c=='+') n=62;else if (c=='/') n=63;
            if (c=='=') {if (i+4!=value.length || j<2) return nil;padding++;n=0;} else if (padding || n<0) return nil;
            word=(word<<6)|(unsigned int)n;
        }
        if (padding>2 || (padding==2 && (word&0xffff)) || (padding==1 && (word&0xff))) return nil;
        unsigned char bytes[3]={(word>>16)&255,(word>>8)&255,word&255};
        if (output.length+3-padding>maximumBytes) return nil;
        [output appendBytes:bytes length:3-padding];
    }
    return output;
}

static void OR6Run(NSMutableArray *runs, NSUInteger start, NSUInteger length, NSString *style) {
    if (length) [runs addObject:@{@"location":@(start),@"length":@(length),@"style":style}];
}

static BOOL OR6Prefix(NSString *text, NSUInteger position, NSString *token) {
    return position+token.length<=text.length && [text compare:token options:0 range:NSMakeRange(position,token.length)]==NSOrderedSame;
}

/* Searches only within a 1600-unit chunk. Recursion is capped so adversarial
 * delimiter nesting cannot exhaust the stack. Every unrecognised byte is text. */
static void OR6Inline(NSString *input, NSMutableString *output, NSMutableArray *runs, NSMutableArray *actions, NSUInteger depth) {
    if (depth>8) {[output appendString:input];return;}
    NSUInteger i=0;NSArray *tokens=@[@"`",@"**",@"__",@"~~",@"*",@"_"];NSCharacterSet *special=[NSCharacterSet characterSetWithCharactersInString:@"\\![`*_~"];
    while (i<input.length) {
        unichar c=[input characterAtIndex:i];
        if (![special characterIsMember:c]) {
            NSRange next=[input rangeOfCharacterFromSet:special options:0 range:NSMakeRange(i,input.length-i)];NSUInteger end=next.location==NSNotFound ? input.length : next.location;
            [output appendString:[input substringWithRange:NSMakeRange(i,end-i)]];i=end;continue;
        }
        if (c=='\\' && i+1<input.length && [@"\\`*_{}[]()#+-.!>~" rangeOfString:[input substringWithRange:NSMakeRange(i+1,1)]].location!=NSNotFound) {[output appendString:[input substringWithRange:NSMakeRange(i+1,1)]];i+=2;continue;}
        BOOL image=(c=='!' && OR6Prefix(input,i,@"!["));NSUInteger opening=i+(image ? 1 : 0);
        if (c=='[' || image) {
            NSRange labelEnd=[input rangeOfString:@"](" options:0 range:NSMakeRange(opening+1,input.length-opening-1)];
            if (labelEnd.location!=NSNotFound) {
                NSUInteger destination=labelEnd.location+2,end=destination,nesting=0;
                for (;end<input.length;end++) {unichar t=[input characterAtIndex:end];if (t=='(') nesting++;if (t==')') {if (!nesting) break;nesting--;}}
                if (end<input.length) {
                    NSString *raw=[input substringWithRange:NSMakeRange(destination,end-destination)];
                    if ([raw hasPrefix:@"<"] && [raw hasSuffix:@">"]) raw=[raw substringWithRange:NSMakeRange(1,raw.length-2)];
                    NSString *url=OR6ContentSafeURL(raw,image);
                    if (url) {
                        NSString *label=[input substringWithRange:NSMakeRange(opening+1,labelEnd.location-opening-1)];NSUInteger start=output.length;
                        if (image) [output appendFormat:OR6L(@"[Image: %@]"),label.length ? label : OR6L(@"no caption")];else OR6Inline(label,output,runs,actions,depth+1);
                        OR6Run(runs,start,output.length-start,@"link");[actions addObject:@{@"kind":image ? @"image" : @"link",@"text":label.length ? label : url,@"url":url}];i=end+1;continue;
                    }
                }
            }
        }
        BOOL consumed=NO;
        for (NSString *token in tokens) {
            if (!OR6Prefix(input,i,token)) continue;
            NSUInteger start=i+token.length;NSRange end=[input rangeOfString:token options:0 range:NSMakeRange(start,input.length-start)];
            if (end.location==NSNotFound || end.location==start) continue;
            NSString *inside=[input substringWithRange:NSMakeRange(start,end.location-start)];NSUInteger offset=output.length;
            if ([token isEqual:@"`"]) [output appendString:inside];else OR6Inline(inside,output,runs,actions,depth+1);
            NSString *style=[token isEqual:@"`"] ? @"code" : ([token isEqual:@"~~"] ? @"strike" : (token.length==2 ? @"bold" : @"italic"));
            OR6Run(runs,offset,output.length-offset,style);i=end.location+token.length;consumed=YES;break;
        }
        if (consumed) continue;
        [output appendString:[input substringWithRange:NSMakeRange(i,1)]];i++;
    }
}

static void OR6Append(NSMutableArray *blocks, NSString *source, NSString *kind, NSString *language, NSUInteger level) {
    if (!source.length) return;
    NSString *copyText=[kind isEqual:@"code"] ? [[source copy] autorelease] : nil;
    for (NSUInteger start=0;start<source.length;) {
      @autoreleasepool {
        NSUInteger length=MIN(OR6ContentChunk,source.length-start);
        NSUInteger breaks=0;for (NSUInteger i=0;i<length;i++) if ([source characterAtIndex:start+i]=='\n' && ++breaks==40) {length=i+1;break;}
        if (start+length<source.length && CFStringIsSurrogateHighCharacter([source characterAtIndex:start+length-1]) && CFStringIsSurrogateLowCharacter([source characterAtIndex:start+length])) length--;
        NSString *part=[source substringWithRange:NSMakeRange(start,length)];
        NSMutableString *text=[NSMutableString string];NSMutableArray *runs=[NSMutableArray array],*actions=[NSMutableArray array];
        if ([kind isEqual:@"code"] || [kind isEqual:@"plain"]) [text appendString:part];else OR6Inline(part,text,runs,actions,0);
        NSMutableDictionary *block=[NSMutableDictionary dictionaryWithObjectsAndKeys:kind,@"kind",text,@"text",runs,@"runs",@(level),@"level",nil];
        if (language.length) block[@"language"]=language;
        if (copyText) block[@"copyText"]=copyText;
        [blocks addObject:block];
        /* Native link rows also make long destinations copyable without relying
         * on UIKit's version-specific data detector or attributed-link behavior. */
        for (NSDictionary *action in actions) [blocks addObject:action];
        if (![kind isEqual:@"code"]) {
            NSError *error=nil;NSRegularExpression *pattern=[NSRegularExpression regularExpressionWithPattern:@"https?://[^\\s<>\\\"']+" options:NSRegularExpressionCaseInsensitive error:&error];
            for (NSTextCheckingResult *match in [pattern matchesInString:text options:0 range:NSMakeRange(0,text.length)]) {
                NSString *raw=[text substringWithRange:match.range];
                while (raw.length && [@".,;:!?)]}" rangeOfString:[raw substringFromIndex:raw.length-1]].location!=NSNotFound) raw=[raw substringToIndex:raw.length-1];
                NSString *url=OR6ContentSafeURL(raw,NO);BOOL known=NO;for (NSDictionary *action in actions) if ([action[@"url"] isEqual:url]) known=YES;
                if (url && !known) {[blocks addObject:@{@"kind":@"link",@"text":url,@"url":url}];[actions addObject:@{@"url":url}];}
            }
        }
        start+=length;
      }
    }
}

NSArray *OR6PlainContentBlocks(NSString *source) {
    NSMutableArray *blocks=[NSMutableArray array];OR6Append(blocks,[source isKindOfClass:NSString.class] ? source : @"",@"plain",nil,0);
    if (!blocks.count) [blocks addObject:@{@"kind":@"plain",@"text":@"",@"runs":@[]}];return blocks;
}

NSArray *OR6ContentBlocks(NSString *source) {
    if (![source isKindOfClass:NSString.class]) source=@"";
    NSString *normal=[[source stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"] stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
    NSMutableArray *blocks=[NSMutableArray array];NSMutableString *paragraph=[NSMutableString string],*code=[NSMutableString string];NSString *fence=nil,*language=nil;BOOL codeLine=NO;
    for (NSString *line in [normal componentsSeparatedByString:@"\n"]) {
        NSString *trim=[line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (fence) {
            NSUInteger count=0;while (count<trim.length && [trim characterAtIndex:count]==[fence characterAtIndex:0]) count++;
            if (count>=fence.length && ![[trim substringFromIndex:count] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].length) {OR6Append(blocks,code,@"code",language,0);[code setString:@""];fence=nil;language=nil;}
            else {if (codeLine) [code appendString:@"\n"];[code appendString:line];codeLine=YES;}
            continue;
        }
        NSUInteger ticks=0;if ([trim hasPrefix:@"```"] || [trim hasPrefix:@"~~~"]) while (ticks<trim.length && [trim characterAtIndex:ticks]==[trim characterAtIndex:0]) ticks++;
        if (ticks>=3) {OR6Append(blocks,paragraph,@"text",nil,0);[paragraph setString:@""];fence=[trim substringToIndex:ticks];language=[[trim substringFromIndex:ticks] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];if (language.length>24) {NSUInteger end=CFStringIsSurrogateHighCharacter([language characterAtIndex:23]) && CFStringIsSurrogateLowCharacter([language characterAtIndex:24]) ? 23 : 24;language=[language substringToIndex:end];}codeLine=NO;continue;}
        if (!trim.length) {OR6Append(blocks,paragraph,@"text",nil,0);[paragraph setString:@""];continue;}
        NSUInteger heading=0;while (heading<line.length && [line characterAtIndex:heading]=='#') heading++;
        NSString *kind=nil,*text=line;
        if (heading && heading<=6 && heading<line.length && [line characterAtIndex:heading]==' ') {kind=@"heading";text=[line substringFromIndex:heading+1];}
        else if ([trim hasPrefix:@"> "]) {kind=@"quote";text=[trim substringFromIndex:2];}
        else if ([trim hasPrefix:@"- "] || [trim hasPrefix:@"* "] || [trim hasPrefix:@"+ "]) {kind=@"list";text=[@"• " stringByAppendingString:[trim substringFromIndex:2]];}
        if (kind) {OR6Append(blocks,paragraph,@"text",nil,0);[paragraph setString:@""];OR6Append(blocks,text,kind,nil,heading);}
        else {if (paragraph.length) [paragraph appendString:@"\n"];[paragraph appendString:line];}
    }
    if (fence) OR6Append(blocks,code,@"code",language,0);else OR6Append(blocks,paragraph,@"text",nil,0);
    if (!blocks.count) [blocks addObject:@{@"kind":@"text",@"text":@"",@"runs":@[]}];
    return blocks;
}


// Display name of a vendor entity marker body: entity<E202>["category","Name",…].
static NSString *OR6ContentEntityName(NSString *body) {
    NSRange sep = [body rangeOfString:@""]; if (sep.location == NSNotFound) return nil;
    NSData *json = [[body substringFromIndex:NSMaxRange(sep)] dataUsingEncoding:NSUTF8StringEncoding];
    id value = json.length <= 4096 ? [NSJSONSerialization JSONObjectWithData:json options:0 error:NULL] : nil;
    if (![value isKindOfClass:NSArray.class] || ![value count]) return nil;
    id name = [value count] > 1 ? value[1] : value[0];
    return [name isKindOfClass:NSString.class] && [name length] && [name length] <= 200 ? name : nil;
}

// CommonMark decodes HTML entity references in text but never inside `code`.
static NSString *OR6ContentDecodeEntities(NSString *line) {
    if ([line rangeOfString:@"&"].location == NSNotFound) return line;
    NSArray *pieces = [line componentsSeparatedByString:@"`"]; NSMutableArray *out = [NSMutableArray array];
    for (NSUInteger i = 0; i < pieces.count; i++) {
        NSMutableString *t = [NSMutableString stringWithString:pieces[i]];
        if (i % 2 == 0 || i == pieces.count - 1)
            for (NSArray *pair in @[@[@"&lt;", @"<"], @[@"&gt;", @">"], @[@"&quot;", @"\""], @[@"&#39;", @"'"], @[@"&nbsp;", @"\u00a0"], @[@"&amp;", @"&"]])
                [t replaceOccurrencesOfString:pair[0] withString:pair[1] options:0 range:NSMakeRange(0, t.length)];
        [out addObject:t];
    }
    return [out componentsJoinedByString:@"`"];
}

// "Visual" answers mix Markdown with layout markup (<row>, <box>, <Entity value="…"/>,
// <AsyncImage …/>). iOS 6 shows them as plain Markdown: entities become their names,
// images and layout tags are dropped, indentation is removed so list items parse and
// HTML entities are decoded. Code fences are left untouched. Other answers pass through.
NSString *OR6ContentFlattenVisualMarkup(NSString *source) {
    if (![source isKindOfClass:NSString.class]) return @"";
    static NSRegularExpression *marker, *entity, *image, *tag;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        marker = [[NSRegularExpression alloc] initWithPattern:@"<(?:Entity|AsyncImage)\\b|<(?:row|box)\\b[^<>]*\\{" options:0 error:NULL];
        entity = [[NSRegularExpression alloc] initWithPattern:@"<Entity\\b[^<>]*?\\bvalue=\"([^\"<>]*)\"[^<>]*?/?>" options:0 error:NULL];
        image = [[NSRegularExpression alloc] initWithPattern:@"<AsyncImage\\b[^<>]*/?>" options:0 error:NULL];
        tag = [[NSRegularExpression alloc] initWithPattern:@"</?[A-Za-z][A-Za-z0-9]*(?:\\s[^<>]*)?/?>" options:0 error:NULL];
    });
    BOOL visual = [marker firstMatchInString:source options:0 range:NSMakeRange(0, source.length)] != nil;
    // The stored copy of a visual answer keeps the indentation and entity markers instead of tags.
    BOOL stored = [source rangeOfString:@"\uE200entity\uE202"].location != NSNotFound;
    BOOL entities = NO;
    for (NSString *e in @[@"&amp;", @"&lt;", @"&gt;", @"&quot;", @"&#39;", @"&nbsp;"]) if ([source rangeOfString:e].location != NSNotFound) entities = YES;
    if (!visual && !stored && !entities) return source;
    NSMutableArray *lines = [NSMutableArray array]; BOOL fence = NO;
    for (NSString *raw in [source componentsSeparatedByString:@"\n"]) {
        NSString *trim = [raw stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if ([trim hasPrefix:@"```"]) { fence = !fence; [lines addObject:visual ? trim : raw]; continue; }
        if (fence) { [lines addObject:raw]; continue; }
        BOOL item = [trim hasPrefix:@"- "] || [trim hasPrefix:@"* "] || [trim hasPrefix:@"+ "];
        NSMutableString *line = [NSMutableString stringWithString:(visual || (item && raw.length - trim.length >= 2)) ? trim : raw];
        if (visual) {
            [entity replaceMatchesInString:line options:0 range:NSMakeRange(0, line.length) withTemplate:@"$1"];
            [image replaceMatchesInString:line options:0 range:NSMakeRange(0, line.length) withTemplate:@""];
            [tag replaceMatchesInString:line options:0 range:NSMakeRange(0, line.length) withTemplate:@"\n"];
        }
        [line setString:OR6ContentDecodeEntities(line)];
        for (NSString *part in [line componentsSeparatedByString:@"\n"]) {
            NSString *t = visual ? [part stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] : part;
            if (visual && !t.length && [lines.lastObject length] == 0) continue; // collapse blank runs left by layout tags
            [lines addObject:t];
        }
    }
    while (lines.count && ![[lines objectAtIndex:0] length]) [lines removeObjectAtIndex:0];
    return [lines componentsJoinedByString:@"\n"];
}

NSString *OR6ContentResolveCitations(NSString *source, NSArray *sources) {
    if (![source isKindOfClass:NSString.class]) return @"";
    source = OR6ContentFlattenVisualMarkup(source);
    if ([source rangeOfString:@"- ["].location != NSNotFound) { // GFM task list items
        NSMutableArray *rows = [NSMutableArray array]; BOOL fence = NO;
        for (NSString *line in [source componentsSeparatedByString:@"\n"]) {
            NSString *trim = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
            if ([trim hasPrefix:@"```"]) fence = !fence;
            NSString *row = line;
            if (!fence) for (NSArray *pair in @[@[@"- [ ] ", @"- \u2610 "], @[@"- [x] ", @"- \u2611 "], @[@"- [X] ", @"- \u2611 "]])
                if ([trim hasPrefix:pair[0]]) { row = [pair[1] stringByAppendingString:[trim substringFromIndex:[pair[0] length]]]; break; }
            [rows addObject:row];
        }
        source = [rows componentsJoinedByString:@"\n"];
    }
    if ([source rangeOfString:@"\uE200"].location == NSNotFound) return source;
    NSMutableString *out = [NSMutableString string]; NSUInteger at = 0;
    while (at < source.length) {
        NSRange open = [source rangeOfString:@"\uE200" options:0 range:NSMakeRange(at, source.length-at)];
        if (open.location == NSNotFound) { [out appendString:[source substringFromIndex:at]]; break; }
        [out appendString:[source substringWithRange:NSMakeRange(at,open.location-at)]];
        NSRange close = [source rangeOfString:@"\uE201" options:0 range:NSMakeRange(open.location+1,source.length-open.location-1)];
        if (close.location == NSNotFound) break; // fragment belongs to the next snapshot
        NSString *marker = [source substringWithRange:NSMakeRange(open.location,NSMaxRange(close)-open.location)];
        NSString *body = [marker substringWithRange:NSMakeRange(1,marker.length-2)];
        if ([body hasPrefix:@"cite\uE202"] || [body hasPrefix:@"cite\uE201"] || [body isEqual:@"cite"]) {
            NSArray *ids = [body componentsSeparatedByString:@"\uE202"];
            for (NSDictionary *s in sources) {
                NSString *url = OR6ContentSafeURL(s[@"url"],NO);
                BOOL match=[s[@"matched_text"]isEqual:marker]||([s[@"id"]isKindOfClass:NSString.class]&&[ids containsObject:s[@"id"]]);
                for(NSString*alias in s[@"aliases"])if([alias isEqual:marker]||[ids containsObject:alias])match=YES;
                if(!url||!match)continue;
                url = [[url stringByReplacingOccurrencesOfString:@"(" withString:@"%28"] stringByReplacingOccurrencesOfString:@")" withString:@"%29"];
                NSString *host = [[[NSURL URLWithString:url] host] lowercaseString]; if ([host hasPrefix:@"www."]) host = [host substringFromIndex:4];
                if (!host.length) continue;
                NSString *label = host.length > 30 ? [[host substringToIndex:29] stringByAppendingString:@"…"] : host;
                [out appendFormat:@"[\u00a0%@\u00a0](%@)",label,url];
            }
        } else if ([body hasPrefix:@"entity\uE202"]) { NSString *name = OR6ContentEntityName(body); if (name) [out appendString:name]; }
        // Other private control blocks have no readable prose.
        at = NSMaxRange(close);
    }
    if ([source rangeOfString:@"\uE200entity\uE202"].location == NSNotFound) return out;
    // Removed markers can leave indentation before list items of a stored visual answer.
    NSMutableArray *lines = [NSMutableArray array]; BOOL fence = NO;
    for (NSString *line in [out componentsSeparatedByString:@"\n"]) {
        NSString *trim = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if ([trim hasPrefix:@"```"]) fence = !fence;
        if (!fence && [trim hasPrefix:@"\\- "]) trim = [trim substringFromIndex:1]; // escaped list marker
        BOOL item = !fence && ([trim hasPrefix:@"- "] || [trim hasPrefix:@"* "] || [trim hasPrefix:@"+ "]);
        [lines addObject:item ? trim : line];
    }
    return [lines componentsJoinedByString:@"\n"];
}
