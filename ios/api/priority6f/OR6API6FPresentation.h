#import "../OR6APICore.h"
@interface OR6API6FPresentation:NSObject
- (BOOL)bindSession:(NSString*)sessionId conversation:(NSString*)conversationId context:(NSDictionary*)context error:(NSError**)error;
- (BOOL)applyEvent:(NSDictionary*)event session:(NSString*)sessionId sequence:(NSUInteger)sequence context:(NSDictionary*)context error:(NSError**)error;
- (NSDictionary*)transcript:(NSString*)sessionId visible:(NSNumber*)visible context:(NSDictionary*)context error:(NSError**)error;
- (NSDictionary*)usage:(NSString*)sessionId context:(NSDictionary*)context error:(NSError**)error;
- (BOOL)consumeFallback:(NSString*)noticeId session:(NSString*)sessionId context:(NSDictionary*)context error:(NSError**)error;
- (void)deactivate;
@end
