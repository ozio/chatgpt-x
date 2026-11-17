#import <Foundation/Foundation.h>

// iOS 6 / MRC. Returned key material and JWTs are sensitive RAM values.
// No method logs, persists, performs network I/O, or returns detailed errors.
@interface OR6OAuthCrypto : NSObject
+ (NSData *)randomDataOfLength:(NSUInteger)length;
+ (NSString *)base64urlStringForData:(NSData *)data;
+ (NSData *)dataForBase64urlString:(NSString *)string;
+ (NSData *)sha256:(NSData *)data;
+ (NSString *)pkceChallengeForVerifier:(NSString *)verifier;

// P-256 private keys use the original CryptoKit-compatible raw 32-byte scalar.
// publicJWK excludes private material; thumbprints use RFC 7638 canonical JSON.
+ (NSData *)generateP256PrivateKey;
+ (NSDictionary *)publicJWKForPrivateKey:(NSData *)privateKey;
+ (NSString *)thumbprintForJWK:(NSDictionary *)JWK;
+ (NSData *)ES256SignatureForData:(NSData *)data privateKey:(NSData *)privateKey;

// HTTPS origin/path only: no userinfo, non-443 port, query or fragment in htu.
// The input URL may have query/fragment; both are removed from the signed htu.
// iat uses the supplied clock; jti is fresh SecRandom data on every call.
+ (NSString *)dpopProofWithPrivateKey:(NSData *)privateKey
                            method:(NSString *)method
                               URL:(NSURL *)URL
                          issuedAt:(NSDate *)issuedAt
                             nonce:(NSString *)nonce;
// For a DPoP-protected resource request; ath is the SHA-256 access-token hash.
// Keep accessToken nil for token-endpoint requests that do not need ath.
+ (NSString *)dpopProofWithPrivateKey:(NSData *)privateKey method:(NSString *)method
                               URL:(NSURL *)URL issuedAt:(NSDate *)issuedAt
                             nonce:(NSString *)nonce accessToken:(NSString *)accessToken;

// Verifies only against the explicit trusted JWK, never a key/URL from the JWT.
// Only RS256 and ES256 are admitted. Returns claims only after signature success.
// Caller still owns issuer/audience/nonce/time/account-policy validation.
+ (NSDictionary *)verifiedClaimsForJWT:(NSString *)JWT
                           trustedJWK:(NSDictionary *)JWK
                            algorithm:(NSString *)algorithm;

// ID-token helper: additionally checks issuer, audience/azp, expected nonce,
// required exp/iat and optional nbf using an explicit now/leeway (0..300 sec).
// This is cryptographic verification; it is not advisory JWT decoding.
+ (NSDictionary *)verifiedIDToken:(NSString *)JWT
                      trustedJWK:(NSDictionary *)JWK
                          issuer:(NSString *)issuer
                        audience:(NSString *)audience
                           nonce:(NSString *)nonce
                             now:(NSDate *)now
                          leeway:(NSTimeInterval)leeway;

// Refresh ID tokens must retain the original subject. A missing nonce is
// permitted here only; any returned nonce must match the saved original nonce.
+ (NSDictionary *)verifiedRefreshIDToken:(NSString *)JWT trustedJWK:(NSDictionary *)JWK
                                 issuer:(NSString *)issuer audience:(NSString *)audience
                                subject:(NSString *)subject originalNonce:(NSString *)nonce
                                    now:(NSDate *)now leeway:(NSTimeInterval)leeway;

#if defined(OR6_OAUTH_CRYPTO_TESTING)
+ (NSString *)testDPoPWithPrivateKey:(NSData *)privateKey method:(NSString *)method
                               URL:(NSURL *)URL issuedAt:(NSDate *)issuedAt
                             nonce:(NSString *)nonce identifier:(NSString *)identifier;
#endif
@end
