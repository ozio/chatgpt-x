#import "OR6APICore.h"
#import "../auth/OR6WebSession.h"
@protocol OR6APIInteractionHost <NSObject>
// UIKit/WebPort host uses the ordinary page. No email/password/OTP crosses this
// interface. The host accepts the callback credential directly into session.
- (id<OR6APITask>)presentProvider:(NSString *)provider session:(OR6WebSession *)session
 generation:(NSUInteger)generation completion:(void(^)(NSString *state))completion;
@end
@protocol OR6APISessionObserver <NSObject>
- (void)apiSessionDidChange;
@end
// Requires a session with no delegate; owns its delegate while alive. Existing
// UI must be composed with this adapter, never have its delegate stolen.
@interface OR6APISessionProvider:NSObject<OR6APIProvider,OR6WebSessionDelegate>{
 OR6WebSession *_session;id<OR6APIInteractionHost> _host;id<OR6APIProvider> _next;
 NSString *_interactionId,*_interactionProvider,*_interactionState;
 id<OR6APITask> _interactionTask;
 id _interactionObserver;
 OR6APIReply _pending;id _pendingTask;
 id<OR6APISessionObserver> _observer;
}
@property(nonatomic,assign)id<OR6APISessionObserver> observer;
- (id)initWithSession:(OR6WebSession *)session host:(id<OR6APIInteractionHost>)host next:(id<OR6APIProvider>)next;
@end
