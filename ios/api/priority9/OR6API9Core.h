#import "../OR6APICore.h"
// Existing Core intentionally journals Send/Transcribe mutations. Stop shares
// the active Send ID; dictation.retry is journaled by Priority9 itself. Their
// cancellation/late-context errors still need conservative dispatch semantics.
@interface OR6API9Core:OR6APICore@end
