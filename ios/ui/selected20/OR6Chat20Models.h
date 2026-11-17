#import <Foundation/Foundation.h>
// Selectable compose result → a draft, only if the exact draft and Core generation still match.
// Suggestions append after a blank line; autocomplete replaces the exact input snapshot.
// Never sends, never truncates, nil on stale/malformed/overlong input.
NSString *OR6Chat20SelectedDraft(NSString *current, NSString *original, NSUInteger currentGeneration,
                               NSUInteger originalGeneration, NSString *selection, BOOL autocomplete);
