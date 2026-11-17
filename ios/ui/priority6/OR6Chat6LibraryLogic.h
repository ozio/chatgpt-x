// Foundation-only logic of the stage-6 Library screens (API6C library.*, support/priority6c/
// contracts.json): exact request parameters, API6CNode mapping, the folder-cycle refusal for
// «Move to folder…», name validation and the honest titles of kinds/sources/providers.
// No UIKit. Tests: tests/chat-ui6/library.m (held provider over the real registry).
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif
// Filter values of library.browse (service values, in menu order).
NSArray *OR6Chat6LibraryCategories(void);   // images documents spreadsheets presentations pdfs
NSArray *OR6Chat6LibrarySources(void);      // uploaded generated
NSString *OR6Chat6LibraryCategoryTitle(NSString *category); // nil → «All types»
NSString *OR6Chat6LibrarySourceTitle(NSString *source);     // nil → «All sources»
// library.browse parameters WITHOUT pageToken (OR6Chat6Pager adds it): {directoryId (id|null),
// query (trimmed, ≤256, "" when none), category (|null), source (|null), includeHidden: NO}.
// An unknown category/source becomes null; an invalid directory ID → nil.
NSDictionary *OR6Chat6LibraryBrowseParameters(NSString *directoryId, NSString *query, NSString *category, NSString *source);
// library.mounted.browse without pageToken {provider, directoryId}; library.mounted.search
// {provider, query}. nil: provider not one of the five / missing directory / empty query.
NSDictionary *OR6Chat6LibraryMountedBrowseParameters(NSString *provider, NSString *directoryId);
NSDictionary *OR6Chat6LibraryMountedSearchParameters(NSString *provider, NSString *query);
// library.favorite.set without operationId: {id, isFavorited}; nil for an invalid ID.
NSDictionary *OR6Chat6LibraryFavoriteParameters(NSString *nodeId, BOOL favorited);

// A validated API6CNode (id, kind file|directory, name present) or nil.
NSDictionary *OR6Chat6LibraryNode(id raw);
BOOL OR6Chat6LibraryIsFolder(NSDictionary *node);
BOOL OR6Chat6LibraryIsPicture(NSDictionary *node);          // mediaType image/*
NSString *OR6Chat6LibraryNodeGlyph(NSDictionary *node);     // folder | photo | file
NSString *OR6Chat6LibraryKindTitle(NSDictionary *node);     // «Folder», «Image», «PDF», «File»…
NSString *OR6Chat6LibraryAccessTitle(NSString *access);     // Yours / Shared with you / Connected source / Unknown
// Remote changes of this node may be offered: canMutate YES, not shared/mounted, not a root.
BOOL OR6Chat6LibraryCanMutate(NSDictionary *node);
// «Library › A › B» from library.folder.path items (root nodes are not repeated).
NSString *OR6Chat6LibraryPathText(NSArray *pathItems);

// «Move to folder…»: nil when node may be moved to destinationId (nil/NSNull: the top level of
// the Library), else a localized reason. destinationPath: the FRESH library.folder.path items of
// a non-null destination (its last item must be that destination); a folder is refused into
// itself or any folder inside it; the current parent is refused as «already there».
NSString *OR6Chat6LibraryMoveProblem(NSDictionary *node, id destinationId, NSArray *destinationPath);
// Folder/item name for library.folder.create / library.node.rename: trimmed, 1…240 UTF-16
// units, no line breaks or slashes; nil with *problem (localized) otherwise.
NSString *OR6Chat6LibraryName(NSString *text, NSString **problem);

// Connected sources: provider of an external node ID (external-gdrive:… → google_drive), or nil.
NSString *OR6Chat6LibraryProviderOfId(NSString *nodeId);
NSArray *OR6Chat6LibraryProviders(void);                     // google_drive box dropbox sharepoint onedrive
NSString *OR6Chat6LibraryProviderTitle(NSString *provider);  // product names (not translated)
// library.favorites.list item kinds.
NSString *OR6Chat6LibraryFavoriteKindTitle(NSString *kind);  // nil → «All»
NSString *OR6Chat6LibraryFavoriteKindGlyph(NSString *kind);
NSArray *OR6Chat6LibraryFavoriteKinds(void);                 // file assistant_response place product image other
#ifdef __cplusplus
}
#endif
