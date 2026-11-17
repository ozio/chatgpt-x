#import <Foundation/Foundation.h>
#import "../../chat/OR6ChatUIState.h"

// UI admission only. Core/provider journals remain the authority for Retry/Stop.
@interface OR6Chat9Actions:NSObject {
 OR6ChatConversationState *_state;
 NSDictionary *_submitted;
 NSString *_retryOperation;
 BOOL _serverObserved,_stopAttempted,_blocked;
}
- (id)initWithState:(OR6ChatConversationState *)state;
- (void)beganSend:(NSDictionary *)parameters;
- (void)receivedEvent:(NSDictionary *)event;
- (void)finished:(NSDictionary *)receipt error:(NSError *)error;
- (NSDictionary *)beginRetry;
- (NSDictionary *)beginStop;
- (void)invalidate;
- (BOOL)canRetry;
- (BOOL)canStop;
- (NSString *)submittedText; // text of the last send (for the failed "!" bubble)
- (NSDictionary *)diagnostics;
@end
