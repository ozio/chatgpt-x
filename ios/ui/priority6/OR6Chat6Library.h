// Stage-6 Library (API6C) entry points beyond OR6Chat6Screens.h.
#import <UIKit/UIKit.h>
#import "../../api/OR6APICore.h"
#import "../priority7/OR6Chat7Screens.h"

#ifdef __cplusplus
extern "C" {
#endif
// A Library file found by the global search (libraryItemId): the node card of the Library
// browser (library.node.get {id, kind:"file"}) with the same actions (rename, move, favorite,
// delete), each only when granted and the node can be changed. nil when library.node.get is
// not callable or the ID is not a string.
UIViewController *OR6Chat6CreateLibraryItem(OR6APICore *core, NSString *libraryItemId, id<OR6Chat7Navigator> navigator);
#ifdef __cplusplus
}
#endif
