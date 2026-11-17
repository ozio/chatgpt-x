#import <Foundation/Foundation.h>
/* Creates an UNAUTHENTICATED candidate request. Does not send it. Base URL,
 * headers, session fields, eligibility and channel schema need service proof.
 * Caller must bind one attempt to one account/credential generation. */
NSMutableURLRequest *OR6VoiceSignalingRequest(NSURL *URL,NSString *offer,NSDictionary *session);
