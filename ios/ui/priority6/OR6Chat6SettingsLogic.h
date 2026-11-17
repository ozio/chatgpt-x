// Foundation-only logic of the stage-6 «Apps», «Voice», «Models» screens and the sign-in
// handoffs (OR6Chat6Settings.m): request parameters exactly as support/priority6b/6e/6f
// contracts.json define them, DTO → row mapping, receipt (API6BMutation / API6FMutation)
// outcome and handoff validation. No UIKit. Tests: tests/chat-ui6/settings.m.
#import <Foundation/Foundation.h>
#import "../../api/OR6APICore.h"
#import "../priority7/OR6Chat7Models.h"

#ifdef __cplusplus
extern "C" {
#endif
#pragma mark Apps (API6B connectors)
// connectors.catalog base parameters (the pager adds pageToken): {query} trimmed; "" is the
// service's home list. nil: longer than 240 characters.
NSDictionary *OR6Chat6AppsCatalogParameters(NSString *query);
// The plugin actions its state allows, in display order, mirroring the provider's own refusals:
// install (not installed, status ENABLED, policy not NOT_AVAILABLE, no computer app needed),
// enable (installed and off, status ENABLED, policy not NOT_AVAILABLE), disable (installed and on),
// remove (installed, policy not INSTALLED_BY_DEFAULT).
NSArray *OR6Chat6AppActions(NSDictionary *plugin);
// action install|enable|disable|remove → {operation, parameters {pluginId, confirm:YES}, intent "<op>:<pluginId>"}; nil when the state refuses it.
NSDictionary *OR6Chat6AppMutation(NSString *action, NSDictionary *plugin);
// A service status / policy word (ENABLED, NOT_AVAILABLE, REAUTH_REQUIRED…) as a short human label; nil when absent.
NSString *OR6Chat6ServiceLabel(id value);
// Connector permission policies. Default: always_ask, ask_before_writes, review_important_actions.
// Per link: those, full_access and NSNull (use the default).
NSArray *OR6Chat6DefaultPolicies(void);
NSArray *OR6Chat6LinkPolicies(void);
NSString *OR6Chat6PolicyLabel(id policy);        // «Always ask»…; NSNull/nil → «Use default»; unknown → nil
NSDictionary *OR6Chat6DefaultPolicyParameters(id policy);                 // {policy} or nil
NSDictionary *OR6Chat6LinkPolicyParameters(NSString *linkId, id policy);  // {linkId, policy (NSNull: default)} or nil
NSDictionary *OR6Chat6DisconnectParameters(NSString *linkId);             // {linkId, confirm:YES} or nil
// Apps → Connections: connectors.installed with the explicit opt-in {pageToken:null, includeConnections:YES},
// and its source connections [{id, connectorId, authStatus, privacyControl}] validated and deduplicated by id.
NSDictionary *OR6Chat6ConnectionsParameters(void);
NSArray *OR6Chat6Connections(NSDictionary *page);

#pragma mark Receipts
// API6BMutation / API6FMutation: confirmed (state completed and confirmed:true), unconfirmed
// (completed without confirmation, or state uncertain: unknown, never a resend), rejected (the
// service refused it: nothing was changed). A local op's own state DTO (no state/confirmed): result.
NSString *OR6Chat6ReceiptOutcome(NSDictionary *receipt);

#pragma mark Voice (API6F)
NSString *OR6Chat6VoiceModeName(id mode);                                   // Standard / Advanced / Wingman; nil unknown
NSDictionary *OR6Chat6VoiceCatalogParameters(NSDictionary *settings);       // voice.catalog.list {mode, language} from voice.settings.get
NSDictionary *OR6Chat6VoiceSelectParameters(NSDictionary *catalog, NSString *voiceId);  // {catalogId, voiceId}: the voice is in that catalogue
NSDictionary *OR6Chat6VoicePreviewParameters(NSDictionary *catalog, NSString *voiceId); // + a new operationId; nil unless previewAvailable
NSDictionary *OR6Chat6VoiceModeParameters(id mode, NSDictionary *settings); // voice.modes.select {mode, language (current)}
NSDictionary *OR6Chat6VoiceLanguageParameters(id language, NSDictionary *languages); // {language} listed by voice.languages.list
NSString *OR6Chat6VoiceLanguageName(NSString *identifier, NSLocale *locale); // «auto» → Automatic; locale display name; else the ID
NSArray *OR6Chat6VoiceLanguages(NSDictionary *languages, NSLocale *locale); // [{id, title}]: auto first, then by title
// voice.usage.get notices: [{kind warning|exceeded, id, title, text (plain), hint, switchToStandard, resetsAfter?}].
NSArray *OR6Chat6VoiceNotices(NSDictionary *usage);
NSString *OR6Chat6PlainMarkdown(NSString *markdown);                         // emphasis/heading/code marks and link targets removed
NSString *OR6Chat6PlaybackText(NSDictionary *playback);                      // «Playing · 0:03 of 0:10»; nil when idle

#pragma mark Models (API6F model controls)
NSString *OR6Chat6LaneName(id lane);                                         // Auto, Instant, Thinking, Thinking mini, Pro
// modelControls.catalog → [{familyId, title, versions:[API6FModel]}] in service order.
NSArray *OR6Chat6ModelFamilies(NSDictionary *catalog);
// modelControls.select parameters (the write adds operationId): {versionId (familyId), lane,
// thinkingEffort (NSNull: the model's default), temporary:NO}; nil when the effort is not one of the model's.
NSDictionary *OR6Chat6ModelSelectParameters(NSDictionary *model, id effort);
NSDictionary *OR6Chat6AutoPreferenceParameters(BOOL prefersAuto);            // {prefersAuto, temporary:NO}
NSString *OR6Chat6SelectionText(NSDictionary *selection, NSDictionary *catalog); // «GPT-5 · Thinking · Extended»

#pragma mark Sign-in handoffs (API6E)
NSArray *OR6Chat6SignInHandoffCandidates(void);   // the six [{key, title, operation}] in sheet order
// The page of a handoff DTO: https://chatgpt.com/… (no user, password or port) with completed exactly NO; else nil.
NSURL *OR6Chat6SignInHandoffURL(NSDictionary *handoff);
#ifdef __cplusplus
}
#endif

// One settings write (6B connectors.* / 6F voice.* / modelControls.*) over OR6Chat7Write: one
// immutable operation ID, never resent. outcome:
//   idle | running | checking | confirmed | unconfirmed (applied or not is not proven yet: only
//   -check, the read-only reconcile, is offered) | rejected (nothing changed) | uncertain |
//   failed (proven not sent) | blocked (service stop signal)
// confirmed/rejected release the intent's unresolved latch; unconfirmed/uncertain keep it, and
// the operation ID stays known for this intent so a later screen can still -checkIntent:.
@interface OR6Chat6SettingsWrite : NSObject <OR6Chat8ModelDelegate>
- (id)initWithCore:(OR6APICore *)core reconcile:(NSString *)reconcileOperation;
@property (nonatomic, assign) id<OR6Chat8ModelDelegate> delegate;
@property (nonatomic, readonly) NSString *outcome, *operation, *intent, *operationId;
@property (nonatomic, readonly) NSDictionary *receipt;
@property (nonatomic, readonly) NSError *error;
- (BOOL)perform:(NSString *)operation parameters:(NSDictionary *)parameters intent:(NSString *)intent; // NO: nothing was sent
- (BOOL)check;                            // unconfirmed/uncertain: reconcile with the same operation ID
- (BOOL)checkIntent:(NSString *)intent;   // an earlier unresolved write of this intent (this session): its reconcile
- (void)cancel;                           // a running write stays uncertain
@end
