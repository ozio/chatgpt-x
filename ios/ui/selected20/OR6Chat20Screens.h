#import "../priority7/OR6Chat7Conversation.h"
// Existing kit forms; one explicit read when opened, no automatic composer network calls.
UIViewController *OR6Chat20ComposeScreen(OR6APICore *core, NSString *kind, id<OR6Chat7ConversationHost> host);
NSArray *OR6Chat20DrawerEntries(OR6APICore *core);
UIViewController *OR6Chat20DrawerScreen(OR6APICore *core, NSString *key, id<OR6Chat7Navigator> navigator);
