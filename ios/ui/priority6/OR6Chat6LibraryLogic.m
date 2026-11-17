#import "OR6Chat6LibraryLogic.h"
#import "../../localization/OR6Localization.h"

static NSString *Str(id v, NSUInteger max) { return [v isKindOfClass:NSString.class] && [v length] && [v length] <= max ? v : nil; }
static NSString *Trim(NSString *s) { return [s isKindOfClass:NSString.class] ? [s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] : @""; }
static id OrNull(id v) { return v ?: (id)NSNull.null; }

NSArray *OR6Chat6LibraryCategories(void) { return @[@"images", @"documents", @"spreadsheets", @"presentations", @"pdfs"]; }
NSArray *OR6Chat6LibrarySources(void) { return @[@"uploaded", @"generated"]; }
NSString *OR6Chat6LibraryCategoryTitle(NSString *c) {
    if ([c isEqual:@"images"]) return OR6L(@"Images");
    if ([c isEqual:@"documents"]) return OR6L(@"Documents");
    if ([c isEqual:@"spreadsheets"]) return OR6L(@"Spreadsheets");
    if ([c isEqual:@"presentations"]) return OR6L(@"Presentations");
    if ([c isEqual:@"pdfs"]) return OR6L(@"PDF files");
    return OR6L(@"All types");
}
NSString *OR6Chat6LibrarySourceTitle(NSString *s) {
    if ([s isEqual:@"uploaded"]) return OR6L(@"Uploaded by you");
    if ([s isEqual:@"generated"]) return OR6L(@"Created by ChatGPT");
    return OR6L(@"All sources");
}

NSDictionary *OR6Chat6LibraryBrowseParameters(NSString *directoryId, NSString *query, NSString *category, NSString *source) {
    if (directoryId && !Str(directoryId, 128)) return nil;
    NSString *q = Trim(query) ?: @""; if (q.length > 256) q = [q substringToIndex:256];
    id c = category && [OR6Chat6LibraryCategories() containsObject:category] ? category : (id)NSNull.null;
    id s = source && [OR6Chat6LibrarySources() containsObject:source] ? source : (id)NSNull.null;
    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    p[@"directoryId"] = OrNull(directoryId); p[@"query"] = q; p[@"category"] = c; p[@"source"] = s; p[@"includeHidden"] = @NO;
    return p;
}
NSArray *OR6Chat6LibraryProviders(void) { return @[@"google_drive", @"box", @"dropbox", @"sharepoint", @"onedrive"]; }
NSDictionary *OR6Chat6LibraryMountedBrowseParameters(NSString *provider, NSString *directoryId) {
    NSString *d = Str(directoryId, 4096);
    if (!provider || ![OR6Chat6LibraryProviders() containsObject:provider] || !d) return nil;
    return [NSDictionary dictionaryWithObjectsAndKeys:provider, @"provider", d, @"directoryId", nil];
}
NSDictionary *OR6Chat6LibraryMountedSearchParameters(NSString *provider, NSString *query) {
    NSString *q = Trim(query);
    if (!provider || ![OR6Chat6LibraryProviders() containsObject:provider] || !q.length) return nil;
    if (q.length > 256) q = [q substringToIndex:256];
    return [NSDictionary dictionaryWithObjectsAndKeys:provider, @"provider", q, @"query", nil];
}
NSDictionary *OR6Chat6LibraryFavoriteParameters(NSString *nodeId, BOOL favorited) {
    return Str(nodeId, 128) ? @{@"id": nodeId, @"isFavorited": @(favorited)} : nil;
}

NSDictionary *OR6Chat6LibraryNode(id raw) {
    if (![raw isKindOfClass:NSDictionary.class] || !Str(raw[@"id"], 4096) || ![@[@"file", @"directory"] containsObject:raw[@"kind"] ?: @""] || ![raw[@"name"] isKindOfClass:NSString.class]) return nil;
    return raw;
}
BOOL OR6Chat6LibraryIsFolder(NSDictionary *n) { return [n[@"kind"] isEqual:@"directory"]; }
BOOL OR6Chat6LibraryIsPicture(NSDictionary *n) { return !OR6Chat6LibraryIsFolder(n) && [Str(n[@"mediaType"], 128) hasPrefix:@"image/"]; }
NSString *OR6Chat6LibraryNodeGlyph(NSDictionary *n) { return OR6Chat6LibraryIsFolder(n) ? @"folder" : OR6Chat6LibraryIsPicture(n) ? @"photo" : @"file"; }
NSString *OR6Chat6LibraryKindTitle(NSDictionary *n) {
    if (OR6Chat6LibraryIsFolder(n)) return OR6L(@"Folder");
    NSString *m = [Str(n[@"mediaType"], 128) lowercaseString];
    if ([m hasPrefix:@"image/"]) return OR6L(@"Image");
    if ([m isEqual:@"application/pdf"]) return OR6L(@"PDF");
    if ([m rangeOfString:@"sheet"].location != NSNotFound || [m rangeOfString:@"excel"].location != NSNotFound || [m isEqual:@"text/csv"]) return OR6L(@"Spreadsheet");
    if ([m hasPrefix:@"text/"] || [m rangeOfString:@"document"].location != NSNotFound || [m rangeOfString:@"msword"].location != NSNotFound) return OR6L(@"Document");
    if ([m rangeOfString:@"presentation"].location != NSNotFound || [m rangeOfString:@"powerpoint"].location != NSNotFound) return OR6L(@"Presentation");
    return OR6L(@"File");
}
NSString *OR6Chat6LibraryAccessTitle(NSString *a) {
    if ([a isEqual:@"owned"]) return OR6L(@"Yours");
    if ([a isEqual:@"shared"]) return OR6L(@"Shared with you");
    if ([a isEqual:@"mounted"]) return OR6L(@"Connected source");
    return OR6L(@"Unknown");
}
BOOL OR6Chat6LibraryCanMutate(NSDictionary *n) {
    return OR6Chat6LibraryNode(n) && [n[@"canMutate"] isEqual:@YES] && ![n[@"isRoot"] isEqual:@YES] && ![n[@"access"] isEqual:@"shared"] && ![n[@"access"] isEqual:@"mounted"];
}
NSString *OR6Chat6LibraryPathText(NSArray *items) {
    NSMutableArray *names = [NSMutableArray arrayWithObject:OR6L(@"Library")];
    for (NSDictionary *n in [items isKindOfClass:NSArray.class] ? items : @[]) {
        if (!OR6Chat6LibraryNode(n) || [n[@"isRoot"] isEqual:@YES]) continue;
        [names addObject:Str(n[@"name"], 240) ?: OR6L(@"Untitled")];
    }
    return [names componentsJoinedByString:@" › "];
}

NSString *OR6Chat6LibraryMoveProblem(NSDictionary *node, id destination, NSArray *path) {
    if (!OR6Chat6LibraryCanMutate(node)) return OR6L(@"This item cannot be moved from ChatGPT X.");
    NSString *dest = destination == NSNull.null ? nil : Str(destination, 128);
    if (destination && destination != NSNull.null && !dest) return OR6L(@"The destination folder could not be checked.");
    NSString *parent = Str(node[@"parentId"], 4096);
    if (OR6Chat6LibraryIsFolder(node) && [dest isEqual:node[@"id"]]) return OR6L(@"A folder cannot be moved into itself.");
    if ((!dest && !parent) || (dest && [dest isEqual:parent])) return OR6L(@"It is already in this folder.");
    if (!dest) return nil; // the top level of the Library
    NSDictionary *last = [path isKindOfClass:NSArray.class] && path.count ? OR6Chat6LibraryNode(path.lastObject) : nil;
    if (![last[@"id"] isEqual:dest] || !OR6Chat6LibraryIsFolder(last)) return OR6L(@"The destination folder could not be checked.");
    if (OR6Chat6LibraryIsFolder(node)) for (NSDictionary *n in path) if ([n isKindOfClass:NSDictionary.class] && [n[@"id"] isEqual:node[@"id"]]) return OR6L(@"A folder cannot be moved into a folder inside it.");
    return nil;
}
NSString *OR6Chat6LibraryName(NSString *text, NSString **problem) {
    NSString *t = Trim(text), *why = nil;
    if (!t.length) why = OR6L(@"Enter a name.");
    else if (t.length > 240) why = OR6L(@"The name is too long.");
    else if ([t rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/\\\n\r\t"]].location != NSNotFound) why = OR6L(@"The name cannot contain slashes or line breaks.");
    if (why) { if (problem) *problem = why; return nil; }
    return t;
}

NSString *OR6Chat6LibraryProviderOfId(NSString *nodeId) {
    if (![Str(nodeId, 4096) hasPrefix:@"external-"]) return nil;
    NSString *rest = [nodeId substringFromIndex:9]; NSRange colon = [rest rangeOfString:@":"]; if (colon.location == NSNotFound) return nil;
    NSString *slug = [rest substringToIndex:colon.location]; NSString *p = [slug isEqual:@"gdrive"] ? @"google_drive" : slug;
    return [OR6Chat6LibraryProviders() containsObject:p] && ![slug isEqual:@"google_drive"] ? p : nil;
}
NSString *OR6Chat6LibraryProviderTitle(NSString *p) {
    if ([p isEqual:@"google_drive"]) return @"Google Drive";
    if ([p isEqual:@"box"]) return @"Box";
    if ([p isEqual:@"dropbox"]) return @"Dropbox";
    if ([p isEqual:@"sharepoint"]) return @"SharePoint";
    if ([p isEqual:@"onedrive"]) return @"OneDrive";
    return OR6L(@"Unknown source");
}
NSArray *OR6Chat6LibraryFavoriteKinds(void) { return @[@"file", @"assistant_response", @"place", @"product", @"image", @"other"]; }
NSString *OR6Chat6LibraryFavoriteKindTitle(NSString *k) {
    if ([k isEqual:@"file"]) return OR6L(@"Files");
    if ([k isEqual:@"assistant_response"]) return OR6L(@"Saved answers");
    if ([k isEqual:@"place"]) return OR6L(@"Places");
    if ([k isEqual:@"product"]) return OR6L(@"Products");
    if ([k isEqual:@"image"]) return OR6L(@"Images");
    if ([k isEqual:@"other"]) return OR6L(@"Other");
    return OR6L(@"All");
}
NSString *OR6Chat6LibraryFavoriteKindGlyph(NSString *k) {
    if ([k isEqual:@"file"]) return @"file";
    if ([k isEqual:@"assistant_response"]) return @"text";
    if ([k isEqual:@"place"]) return @"location";
    if ([k isEqual:@"product"]) return @"bag";
    if ([k isEqual:@"image"]) return @"photo";
    return @"star";
}
