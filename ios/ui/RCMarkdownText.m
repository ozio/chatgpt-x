#import "RCMarkdownText.h"

BOOL RCMarkdownIsRule(NSString *line) {
    NSString *s = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (s.length < 3) return NO;
    unichar mark = [s characterAtIndex:0];
    if (mark != '-' && mark != '*' && mark != '_') return NO;
    NSUInteger n = 0;
    for (NSUInteger i = 0; i < s.length; i++) { unichar c = [s characterAtIndex:i]; if (c == mark) n++; else if (c != ' ' && c != '\t') return NO; }
    return n >= 3;
}

BOOL RCMarkdownEscapable(unichar c) { return c > 32 && c < 127 && strchr("!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~", (int)c) != NULL; }

NSRange RCMarkdownFindUnescaped(NSString *s, NSString *token, NSRange r) {
    while (r.length) {
        NSRange f = [s rangeOfString:token options:0 range:r];
        if (f.location == NSNotFound) return f;
        NSUInteger k = f.location, slashes = 0;
        while (k > 0 && [s characterAtIndex:k - 1] == '\\') { slashes++; k--; }
        if (slashes % 2 == 0) return f;
        NSUInteger next = f.location + 1; r = NSMakeRange(next, NSMaxRange(r) - next);
    }
    return NSMakeRange(NSNotFound, 0);
}

NSString *RCMarkdownUnescape(NSString *s) {
    if ([s rangeOfString:@"\\"].location == NSNotFound) return s;
    NSMutableString *o = [NSMutableString stringWithCapacity:s.length];
    for (NSUInteger i = 0, n = s.length; i < n; i++) {
        unichar c = [s characterAtIndex:i];
        if (c == '\\' && i + 1 < n && RCMarkdownEscapable([s characterAtIndex:i + 1])) { c = [s characterAtIndex:++i]; }
        [o appendFormat:@"%C", c];
    }
    return o;
}

// The regex-based plain/readable conversions run on protected text: each escaped punctuation
// outside code becomes a private-use stand-in (U+E000 + ASCII) that no rule matches, and is
// restored as the plain character afterwards. Text that already uses those code points is left
// unprotected (old behaviour) rather than being misread.
static const unichar RCMDStandIn = 0xE000;
static BOOL RCMDHasStandIns(NSString *s) { for (NSUInteger i = 0; i < s.length; i++) { unichar c = [s characterAtIndex:i]; if (c >= RCMDStandIn && c < RCMDStandIn + 128) return YES; } return NO; }
static NSString *RCMDProtectLine(NSString *l) {
    NSMutableString *o = [NSMutableString stringWithCapacity:l.length];
    for (NSUInteger i = 0, n = l.length; i < n; i++) {
        unichar c = [l characterAtIndex:i];
        if (c == '`') { // an inline code span is copied verbatim (its backslashes are literal)
            NSRange e = [l rangeOfString:@"`" options:0 range:NSMakeRange(i + 1, n - i - 1)];
            if (e.location != NSNotFound) { [o appendString:[l substringWithRange:NSMakeRange(i, e.location - i + 1)]]; i = e.location; continue; }
        }
        if (c == '\\' && i + 1 < n && RCMarkdownEscapable([l characterAtIndex:i + 1])) { [o appendFormat:@"%C", (unichar)(RCMDStandIn + [l characterAtIndex:++i])]; continue; }
        [o appendFormat:@"%C", c];
    }
    return o;
}
static NSString *RCMDProtect(NSString *s, BOOL multiline) {
    if ([s rangeOfString:@"\\"].location == NSNotFound || RCMDHasStandIns(s)) return s;
    if (!multiline) return RCMDProtectLine(s);
    NSMutableArray *out = [NSMutableArray array]; BOOL fence = NO;
    for (NSString *l in [s componentsSeparatedByString:@"\n"]) {
        if ([l hasPrefix:@"```"]) { fence = !fence; [out addObject:l]; continue; }
        [out addObject:fence ? l : RCMDProtectLine(l)];
    }
    return [out componentsJoinedByString:@"\n"];
}
static NSString *RCMDRestore(NSString *s) {
    if (!RCMDHasStandIns(s)) return s;
    NSMutableString *o = [NSMutableString stringWithCapacity:s.length];
    for (NSUInteger i = 0; i < s.length; i++) { unichar c = [s characterAtIndex:i]; [o appendFormat:@"%C", (unichar)(c >= RCMDStandIn && c < RCMDStandIn + 128 ? c - RCMDStandIn : c)]; }
    return o;
}

NSString *RCMarkdownPlainText(NSString *md) {
    NSMutableArray *lines = [NSMutableArray array]; BOOL fenced = NO;
    for (NSString *line in [(md ?: @"") componentsSeparatedByString:@"\n"]) { if ([line hasPrefix:@"```"]) fenced = !fenced; [lines addObject:(!fenced && RCMarkdownIsRule(line)) ? @"" : line]; }
    NSString *source = [lines componentsJoinedByString:@"\n"], *s = RCMDProtect(source, YES); BOOL protectedText = s != source; // restore only what was protected
    NSArray *rules = [NSArray arrayWithObjects:
        @"```[a-z]*\\n?", @"", @"\\*\\*", @"", @"\\*([^*\\n]+)\\*", @"$1", @"\\[([^\\]]+)\\]\\([^)]*\\)", @"$1", @"`", @"", @"(?m)^#{2,3} ", @"", @"(?m)^- ", @"• ", @"(?m)^> ", @"", @"(?m)^\\|[-| ]+\\|$", @"", @"\\|", @"  ", nil];
    for (NSUInteger i = 0; i + 1 < rules.count; i += 2) {
        NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:[rules objectAtIndex:i] options:0 error:NULL];
        s = [re stringByReplacingMatchesInString:s options:0 range:NSMakeRange(0, s.length) withTemplate:[rules objectAtIndex:i + 1]];
    }
    return protectedText ? RCMDRestore(s) : s;
}

NSString *RCMarkdownReadableText(NSString *md) {
    NSArray *lines = [(md ? md : @"") componentsSeparatedByString:@"\n"];
    NSMutableArray *out = [NSMutableArray array];
    NSRegularExpression *link = [NSRegularExpression regularExpressionWithPattern:@"\\[([^\\]]+)\\]\\(([^)]*)\\)" options:0 error:NULL];
    NSRegularExpression *sep = [NSRegularExpression regularExpressionWithPattern:@"^\\s*\\|[-| :]+\\|\\s*$" options:0 error:NULL];
    NSArray *inlineRules = [NSArray arrayWithObjects:@"\\*\\*([^*]+)\\*\\*", @"$1", @"(^|[^*])\\*([^*\\s][^*\\n]*)\\*", @"$1$2", @"`([^`]+)`", @"$1", nil];
    BOOL code = NO;
    for (NSString *raw in lines) {
        if ([raw hasPrefix:@"```"]) { code = !code; continue; }
        if (code) { [out addObject:raw]; continue; }
        if (RCMarkdownIsRule(raw)) { [out addObject:@""]; continue; }
        NSString *l = RCMDProtect(raw, NO); BOOL protectedLine = l != raw;
        if ([sep firstMatchInString:l options:0 range:NSMakeRange(0, l.length)]) continue;
        // links first: "title (url)", or just the url when both are the same
        NSMutableString *m = [NSMutableString string];
        NSUInteger at = 0;
        for (NSTextCheckingResult *r in [link matchesInString:l options:0 range:NSMakeRange(0, l.length)]) {
            [m appendString:[l substringWithRange:NSMakeRange(at, r.range.location - at)]];
            NSString *title = [l substringWithRange:[r rangeAtIndex:1]], *url = [l substringWithRange:[r rangeAtIndex:2]];
            [m appendString:([title isEqualToString:url] || !url.length) ? title : [NSString stringWithFormat:@"%@ (%@)", title, url]];
            at = NSMaxRange(r.range);
        }
        [m appendString:[l substringFromIndex:at]];
        l = m;
        for (NSUInteger i = 0; i + 1 < inlineRules.count; i += 2) {
            NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:[inlineRules objectAtIndex:i] options:0 error:NULL];
            l = [re stringByReplacingMatchesInString:l options:0 range:NSMakeRange(0, l.length) withTemplate:[inlineRules objectAtIndex:i + 1]];
        }
        if ([l hasPrefix:@"### "]) l = [l substringFromIndex:4];
        else if ([l hasPrefix:@"## "]) l = [l substringFromIndex:3];
        else if ([l hasPrefix:@"# "]) l = [l substringFromIndex:2];
        else if ([l hasPrefix:@"> "]) l = [l substringFromIndex:2];
        else if ([l hasPrefix:@"- "] || [l hasPrefix:@"* "]) l = [@"• " stringByAppendingString:[l substringFromIndex:2]];
        NSString *trim = [l stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if ([trim hasPrefix:@"|"] && [trim hasSuffix:@"|"] && trim.length > 1) {
            NSMutableArray *cells = [NSMutableArray array];
            for (NSString *c in [[trim substringWithRange:NSMakeRange(1, trim.length - 2)] componentsSeparatedByString:@"|"]) [cells addObject:[c stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
            l = [cells componentsJoinedByString:@"\t"];
        }
        [out addObject:protectedLine ? RCMDRestore(l) : l];
    }
    NSString *s = [out componentsJoinedByString:@"\n"];
    while ([s rangeOfString:@"\n\n\n"].location != NSNotFound) s = [s stringByReplacingOccurrencesOfString:@"\n\n\n" withString:@"\n\n"];
    return [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}
