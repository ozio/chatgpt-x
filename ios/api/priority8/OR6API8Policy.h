#import "../OR6APICore.h"
// Private generation plans contain inert request data, never credentials.
NSDictionary *OR6API8Plan(NSString *operation, NSDictionary *parameters, NSDictionary *conversation,
                         NSString *model, NSArray *attachments, NSError **error);
NSArray *OR6API8Sources(NSDictionary *message, NSError **error);
BOOL OR6API8HasFile(NSDictionary *conversation, NSString *message, NSString *file);
NSDictionary *OR6API8Processing(NSData *bytes, NSString *file, BOOL final, NSError **error);
BOOL OR6API8RemoteID(id value);
// Acknowledge only an OS-delivered regular file already in this app's Inbox.
// Selection, import, upload and Send remain separate explicit UI actions.
BOOL OR6API8InboxDeliveryURL(NSURL *url, NSString *documents);
NSDictionary *OR6API8Registry(NSDictionary *base);
