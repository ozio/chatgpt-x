#import "OR6Chat20Models.h"
NSString *OR6Chat20SelectedDraft(NSString *current, NSString *original, NSUInteger cg, NSUInteger og, NSString *selection, BOOL autocomplete) {
    if (![current isKindOfClass:NSString.class] || ![original isKindOfClass:NSString.class] ||
        ![selection isKindOfClass:NSString.class] || !selection.length || cg != og || ![current isEqual:original]) return nil;
    NSString *text = autocomplete || !current.length ? selection : [current stringByAppendingFormat:@"\n\n%@", selection];
    return text.length <= 65536 ? text : nil;
}
