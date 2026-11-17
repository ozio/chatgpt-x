#import "OR6CodexSession.h"
// Separate app-server capability token, supplied by trusted connection storage.
// Never pass ChatGPT cookies/access tokens here. WSS via TLS on exact host:443;
// no redirects, HTTP fallback, external login, retry or SSH enrollment side effect.
@interface OR6CodexWSS:NSObject<OR6CodexTransport> {
 NSURL *_URL;
 NSString *_token,*_roots;
 NSMutableArray *_outgoing;
 void(^_receiver)(NSDictionary*);
 void(^_closedCallback)(NSError*);
 void(^_readyCallback)(NSError*);
 BOOL _running,_cancelled,_upgraded;
 NSUInteger _revision;
}
- (id)initWithURL:(NSURL*)URL capabilityToken:(NSString*)token roots:(NSString*)roots error:(NSError**)error;
@end
// Private framing helpers are exported for adversarial offline wire fixtures.
BOOL OR6CodexHandshake(NSData*data,NSString*key,NSError**error);
BOOL OR6CodexHandshakeProtocol(NSData*data,NSString*key,NSString*protocol,NSError**error);
// Subclass hooks for the separate fixed-origin hosted adapter. The ordinary
// app-server initializer continues to reject every OpenAI/ChatGPT origin.
@interface OR6CodexWSS(HostedHooks)
- (NSDictionary*)handshakeHeaders;
- (NSString*)handshakeProtocol;
- (BOOL)channelIsCurrent;
@end
@interface OR6CodexFrames:NSObject {
 NSMutableData *_buffer,*_fragment;
 NSUInteger _fragmentOpcode,_count;
 BOOL _closed;
}
- (NSArray*)append:(NSData*)bytes error:(NSError**)error;
@end
