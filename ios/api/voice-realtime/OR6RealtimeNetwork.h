#import "../OR6APICore.h"
@class OR6APIWebAdapter;
// Private native boundary: only validated session metadata and SDP, never tokens.
id<OR6APITask> OR6RealtimeConnect(OR6APIWebAdapter *adapter,NSString *roots,NSDictionary *context,NSDictionary *session,NSString *offer,OR6APIReply reply);
BOOL OR6RealtimeSessionValid(NSDictionary *session);
