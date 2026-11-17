#import <UIKit/UIKit.h>
#import "OR6ChatRootController.h"
@interface OR6ChatSessionController:UITableViewController
- (id)initWithHost:(id<OR6ChatUIHost>)host summary:(NSDictionary*)summary;
- (void)applySessionSummary:(NSDictionary*)summary;
- (void)showSessionError:(NSError*)error;
// The signed-in account's {name?, email?} from the session (nil: not known / signed out).
- (void)applyAccountProfile:(NSDictionary*)profile;
@property(nonatomic,retain)OR6APICore*core; // text size through content.scale; sign-in provider choice
@end
// Display helpers shared with the drawer footer: the name (else e-mail) and up to two initials.
NSString *OR6ChatAccountDisplayName(NSDictionary *profile);
NSString *OR6ChatAccountInitials(NSDictionary *profile);
// Side menu: destinations the user can show or hide in Account › Side menu.
// Entries: {key, title, glyph, tile, shown}. «New chat» and the chat list always stay.
extern NSString *const OR6ChatDrawerVisibilityChanged;
NSArray *OR6ChatDrawerOptionalEntries(void);
BOOL OR6ChatDrawerShows(NSString *key);
void OR6ChatDrawerSetShows(NSString *key, BOOL shown);
