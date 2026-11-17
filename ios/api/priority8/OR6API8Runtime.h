#import <UIKit/UIKit.h>
#import "../OR6APICore.h"
#import "../OR6APISessionProvider.h"
// Owns a complete callable API composition. A fresh session (no delegate) is
// required; the installed app's existing coordinator must never be stolen.
@interface OR6API8Runtime:NSObject<OR6APISessionObserver>
- (id)initWithRegistry:(NSDictionary*)registry session:(OR6WebSession*)session presenter:(UIViewController*)presenter
 documents:(NSString*)documents library:(NSString*)library roots:(NSString*)roots
 permittedReads:(NSSet*)reads generationCapabilities:(NSSet*)generationCapabilities
 mediaCapabilities:(NSSet*)mediaCapabilities controlCapabilities:(NSSet*)controlCapabilities
 storageHosts:(NSSet*)storageHosts error:(NSError**)error;
@property(nonatomic,readonly)OR6APICore*core;
- (void)deactivate;
- (void)prepareConversation:(NSString*)identifier;
@end
