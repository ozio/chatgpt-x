#import <Foundation/Foundation.h>

// Main-thread, pull-based boundary. Context contains only key + credential
// generation, never credentials, conversation IDs or message text. Requirements
// HTTP remains native. A prepared document is reusable; attempt output is not.
@protocol OR6ChatPreparation <NSObject>
- (void)prepareForContext:(NSDictionary*)context;
// Pin the document before owner/catalog HTTP; idle expiry cannot interrupt Send.
- (BOOL)reserveAttempt:(NSString*)nonce context:(NSDictionary*)context;
- (BOOL)isReadyForContext:(NSDictionary*)context;
- (NSString*)userAgentForContext:(NSDictionary*)context;
- (BOOL)beginAttempt:(NSString*)nonce context:(NSDictionary*)context;
- (NSDictionary*)pollAttempt:(NSString*)nonce context:(NSDictionary*)context;
- (BOOL)supplyRequirements:(NSDictionary*)requirements attempt:(NSString*)nonce context:(NSDictionary*)context;
- (void)endAttempt:(NSString*)nonce context:(NSDictionary*)context reuseDocument:(BOOL)reuse;
- (void)deactivate;
- (NSDictionary*)diagnostics;
@end

// Shared state validation, independent of UIKit/JavaScript. Only a fresh active
// attempt can expose p or headers, each once. Monotonic time is supplied by the
// implementation; the 240s limit is an application deadline, not server TTL.
@interface OR6ChatPreparationState:NSObject
- (BOOL)bindContext:(NSDictionary*)context;
- (BOOL)matchesContext:(NSDictionary*)context;
- (BOOL)beginAttempt:(NSString*)nonce context:(NSDictionary*)context now:(double)now;
- (NSDictionary*)consume:(id)raw attempt:(NSString*)nonce context:(NSDictionary*)context now:(double)now;
- (BOOL)maySupply:(NSDictionary*)requirements attempt:(NSString*)nonce context:(NSDictionary*)context now:(double)now;
- (void)didSupply;
- (void)cancel;
@end
