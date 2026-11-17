#import "OR6Chat9Actions.h"
#import "../../api/priority9/OR6API9Policy.h"
@implementation OR6Chat9Actions
- (id)initWithState:(OR6ChatConversationState *)state{if((self=[super init]))_state=[state retain];return self;}
- (void)beganSend:(NSDictionary *)parameters{
 [_submitted release];_submitted=[parameters copy];[_retryOperation release];_retryOperation=nil;_serverObserved=NO;_stopAttempted=NO;
}
- (void)receivedEvent:(NSDictionary *)event{
 NSDictionary*p=event[@"payload"];if(![p[@"operationId"]isEqual:_submitted[@"operationId"]])return;
 NSString*kind=event[@"name"];BOOL observed=[kind isEqual:@"message"]||([kind isEqual:@"state"]&&[@[@"streaming",@"reconciling"]containsObject:p[@"state"]]);
 if(observed&&OR6API9UUID(p[@"conversationId"]))_serverObserved=YES;
}
- (void)finished:(NSDictionary *)receipt error:(NSError *)error{
 (void)receipt;NSString*code=error.userInfo[@"code"];
 if([@[@"service_challenge",@"rate_limited",@"access_denied",@"not_authenticated",@"login_required",@"stale_context"]containsObject:code])_blocked=YES;
 // The state must already have consumed the final receipt. A rejected stream
 // with any observed response never becomes an automatic/explicit resend.
 BOOL cannotRetry=[@[@"duplicate_operation",@"invalid_operation_state",@"storage_failure",@"cancelled"]containsObject:code];
 BOOL rejected=!cannotRetry&&error&&[error.userInfo[@"dispatch"]isEqual:@"none"]&&[_state.phase isEqual:@"rejected"]&&!_state.uncertain&&!_serverObserved&&!_blocked;
 [_retryOperation release];_retryOperation=rejected?[_submitted[@"operationId"]copy]:nil;
}
- (BOOL)canRetry{return !_blocked&&_retryOperation.length&&!_state.sending&&!_state.uncertain&&[_state.phase isEqual:@"rejected"];}
- (BOOL)canStop{return !_blocked&&_state.sending&&_serverObserved&&!_stopAttempted&&[_state.operationId isEqual:_submitted[@"operationId"]];}
- (NSDictionary *)beginRetry{
 if(!self.canRetry)return nil;NSString*previous=[[_retryOperation copy]autorelease];NSString*draft=[[_state.text copy]autorelease];
 // Retry shows the immutable old text while preserving any new draft the user
 // has typed since failure. The provider reconstructs the actual old request.
 _state.text=_submitted[@"text"];NSDictionary*next=[_state beginSend];_state.text=draft;
 if(!next)return nil;[self beganSend:next];return @{@"operationId":next[@"operationId"],@"previousOperationId":previous};
}
- (NSString *)submittedText{return _submitted[@"text"];}
- (NSDictionary *)beginStop{if(!self.canStop)return nil;_stopAttempted=YES;return @{@"operationId":_state.operationId};}
- (void)invalidate{_blocked=YES;_serverObserved=NO;[_retryOperation release];_retryOperation=nil;}
- (NSDictionary *)diagnostics{return @{@"retryAvailable":@(self.canRetry),@"stopAvailable":@(self.canStop),@"stopAttempted":@(_stopAttempted),@"serverObserved":@(_serverObserved),@"blocked":@(_blocked)};}
- (void)dealloc{[_state release];[_submitted release];[_retryOperation release];[super dealloc];}
@end
