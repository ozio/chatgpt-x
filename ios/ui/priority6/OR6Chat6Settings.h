// Stage-6 «Apps» (API6B connectors), «Voice» and «Models» (API6F) account screens and the
// API6E sign-in handoffs (OR6Chat6Settings.m). The account rows / privacy rows / screens are
// composed by OR6Chat6Base.m (OR6Chat6SettingsRows, OR6Chat6CreateSettings,
// OR6Chat6SettingsPrivacyEntries); these are the extra entry points other screens may link.
#import <UIKit/UIKit.h>
#import "../../api/OR6APICore.h"

#ifdef __cplusplus
extern "C" {
#endif
// Transcript and voice-limit notices of the voice session the trusted host bound for this
// conversation (-chat6VoiceSessionIdForConversation:); nil when there is none or nothing of
// voice.transcript.get / voice.usage.get is callable. ChatGPT X itself has no voice runtime.
UIViewController *OR6Chat6CreateVoiceSession(OR6APICore *core, NSString *conversationId);
// Connection state of one connector (connectors.settings.get) with its links: Disconnect and
// per-link permissions. connectorId must be the exact connector ID the service reported (it is
// not a plugin ID, and no public API6 read returns it today); nil when invalid or not callable.
UIViewController *OR6Chat6CreateConnectorSettings(OR6APICore *core, NSString *connectorId);
// One API6E sign-in page: performs the handoff operation (no session needed), accepts only
// https://chatgpt.com with completed:false, opens Safari and says so. Nothing is done in-app.
void OR6Chat6OpenSignInHandoff(UIView *view, OR6APICore *core, NSString *operation);
// «Other ways to sign in…»: a sheet with the callable OR6Chat6SignInHandoffs; the choice opens it.
void OR6Chat6ChooseSignInHandoff(UIView *view, OR6APICore *core);
#ifdef __cplusplus
}
#endif
