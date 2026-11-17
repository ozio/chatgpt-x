// Shared pieces of the stage-6 screens (private to ios/ui/priority6).
#import "OR6Chat6Screens.h"
#import "OR6Chat6Models.h"
#import "../priority7/OR6Chat7Models.h"
#import "../priority8/OR6Chat8Screens.h"
#import "../../localization/OR6Localization.h"
#import "RCFormViewController.h"

id<OR6Chat6TrustedHost> OR6Chat6TrustedHostNow(void);
NSString *OR6Chat6Text(id value, NSString *fallback);     // a non-empty string, else fallback
NSString *OR6Chat6RelativeDate(id value);                  // ISO-8601 / epoch → «сегодня, 14:05» style; nil if unknown
// The trusted host bound this eligibility policy for the current context (OR6Chat6TrustedHost
// -chat6PolicyBound:). NO when the host does not say so: the setting stays read-only.
BOOL OR6Chat6PolicyBound(NSString *policy);
// A policy-bound setting write may be offered: the host can prepare it (chat6PrepareOperation…) or
// already says the policy is bound. operation: the write; policy: its OR6Chat6PolicyBound key.
BOOL OR6Chat6PolicyWritable(NSString *operation, NSString *policy);
// Prepares one policy-bound write through the host, then calls `ready` once on main (nil error: go
// ahead with the write; an error: do not write, show it). The returned task (async host form) is
// owned by the caller: cancel it when the screen goes away (ready is then not called).
id<OR6APITask> OR6Chat6Prepare(NSString *operation, NSString *policy, void (^ready)(NSError *error));
// Confirmation sheet (stock UIActionSheet through OR6Chat8ShowSheet): one destructive or one
// ordinary confirm button + Cancel; `confirmed` runs only after the explicit tap.
void OR6Chat6Confirm(UIView *view, NSString *title, NSString *confirmTitle, BOOL destructive, void (^confirmed)(void));
// Text HUD (and VoiceOver announcement).
void OR6Chat6Say(UIView *view, NSString *text);

// A grouped form with one read (OR6Chat7Call) and the honest list states:
// loading («Загрузка…»), error (+ «Прочитать снова» when retryable), empty (note).
@interface OR6Chat6Form : RCFormViewController <RCFormDelegate, OR6Chat8ModelDelegate> {
@protected OR6APICore *_core; id<OR6Chat7Navigator> _nav; OR6Chat7Call *_read; BOOL _loaded;
}
- (id)initWithCore:(OR6APICore *)core navigator:(id<OR6Chat7Navigator>)nav title:(NSString *)title;
- (void)load;                 // first appearance and «Прочитать снова»
- (void)render;
- (RCFormRow *)note:(NSString *)text;
- (RCFormRow *)button:(NSString *)title info:(id)info identifier:(NSString *)identifier;
- (RCFormRow *)value:(NSString *)title value:(NSString *)value info:(id)info identifier:(NSString *)identifier;
// Appends the state rows of `call` to rows: loading / error + retry / empty. YES when a state was added.
- (BOOL)addStateOf:(OR6Chat7Call *)call to:(NSMutableArray *)rows empty:(NSString *)empty hasItems:(BOOL)hasItems identifier:(NSString *)identifier;
// The same for a pager: loading / error + «Прочитать снова» (that page) / «Показать ещё» / empty.
// The rows' userInfo is handled by this class (-form:didSelectRow: calls the pager); subclasses
// that override -form:didSelectRow: call super for rows they do not own.
- (BOOL)addStateOfPager:(OR6Chat6Pager *)pager to:(NSMutableArray *)rows empty:(NSString *)empty identifier:(NSString *)identifier;
// A pager owned by this form (delegate = self, cancelled on dealloc).
- (OR6Chat6Pager *)pager:(NSString *)operation parameters:(NSDictionary *)parameters tokenKey:(NSString *)tokenKey nextKey:(NSString *)nextKey idKey:(NSString *)idKey;
// A call owned by this form (delegate = self, cancelled on dealloc).
- (OR6Chat7Call *)call;
@end
