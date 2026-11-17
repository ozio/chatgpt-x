#import "../priority7/OR6API7Network.h"
@interface OR6API5EProvider:NSObject<OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP extension:(NSDictionary*)extension journalDirectory:(NSString*)directory capabilities:(NSSet*)capabilities error:(NSError**)error;
// Trusted native session/policy observer, never a registry operation. Fields:
// userId/accountId, personal/canFamily/canSchedule/canAge/canVerifyAge, locale.
// Caller must derive these from the authenticated account/policy, not API input.
- (BOOL)observeIdentity:(NSDictionary*)identity context:(NSDictionary*)context error:(NSError**)error;
// Persona is interactive. The inquiry ID stays on the native side. Completion
// must come from the exact original Persona inquiry callback, never public input.
- (NSDictionary*)ageInquiryForVerification:(NSString*)verificationId context:(NSDictionary*)context error:(NSError**)error;
- (BOOL)observeAgeVerificationCompleted:(NSString*)verificationId inquiryId:(NSString*)inquiryId context:(NSDictionary*)context error:(NSError**)error;
// Optional original-response observer for a lost family-create callback. Binds a
// canonical returned id to the reserved original request; never matches by role.
- (BOOL)observeCreatedFamily:(NSDictionary*)response operationId:(NSString*)operationId context:(NSDictionary*)context error:(NSError**)error;
// Native conversation observer: source oSzk eligibility and existing hints.
- (NSString*)observeNewChat:(NSDictionary*)facts context:(NSDictionary*)context error:(NSError**)error;
- (void)deactivate;
- (NSDictionary*)diagnostics;
@end
