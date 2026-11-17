#import "../OR6CodexProtocol.h"

// Source-shaped canonical JSON and ECDSA. No credentials, I/O or logging.
NSData *OR6CodexPairCanonical(id value);
NSString *OR6CodexPairBase64(NSData *data);
NSData *OR6CodexPairDecode64(NSString *value);
NSDictionary *OR6CodexPairClaims(NSString *JWT); // advisory; never grants identity
NSData *OR6CodexPairSPKI(NSData *scalar);
NSData *OR6CodexPairDER(NSData *signature);
NSDictionary *OR6CodexPairSign(NSData *scalar, NSString *keyID, NSDictionary *payload);
NSString *OR6CodexPairIdentityHash(NSDictionary *identity);
BOOL OR6CodexPairStepUp(NSString *token, NSString *accountUserID, NSTimeInterval now);
NSDictionary *OR6CodexPairEnrollmentPayload(NSDictionary *challenge, NSDictionary *identity,
    NSString *user, NSString *client, BOOL refresh, NSTimeInterval now);
NSDictionary *OR6CodexPairConnectionPayload(NSDictionary *challenge, NSString *user,
    NSString *client, NSString *token, NSNumber *expiry, NSTimeInterval now);
// Opaque codes only. URI/QR wrappers are decoded separately against source pins.
NSString *OR6CodexPairCode(NSString *input);
