#import "OR6CodexSession.h"
// Native SSH2, no shelling out on the phone. Exact SHA-256 host-key pin is
// required before auth. Auth is supplied privately as password or paired RSA PEM/private and OpenSSH public key bytes.
// Opens only `codex app-server proxy`, no PTY, forwarding, agent, or arbitrary exec.
@interface OR6CodexSSH:NSObject<OR6CodexTransport> {
 NSString *_host,*_username,*_hostKey;
 NSDictionary *_credentials;
 NSUInteger _port,_revision;
 NSMutableArray *_outgoing;
 void(^_receiver)(NSDictionary*);
 void(^_ready)(NSError*);
 void(^_closed)(NSError*);
 BOOL _running,_cancelled,_opened,_probeOnly;
 NSString *_probeFingerprint;
}
// One bounded handshake, no authentication or remote command; the caller must
// explicitly confirm the returned fingerprint before saving/using a profile.
+ (id<OR6APITask>)probeHost:(NSString*)host port:(NSUInteger)port completion:(OR6APIReply)completion;
- (id)initWithHost:(NSString*)host port:(NSUInteger)port username:(NSString*)username hostKeySHA256:(NSString*)fingerprint credentials:(NSDictionary*)credentials error:(NSError**)error;
@end
