#import "OR6APISessionProvider.h"
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>
@interface OR6APISessionProvider(InteractionResult)
- (void)interactionState:(NSString*)state identifier:(NSString*)identifier;
@end
@interface OR6APIInteractionForwarder:NSObject{@public OR6APISessionProvider*owner;NSString*identifier;}
- (void)receive:(NSString*)state;
@end
@implementation OR6APIInteractionForwarder
- (void)receive:(NSString*)state{if(!NSThread.isMainThread){dispatch_async(dispatch_get_main_queue(),^{[self receive:state];});return;}[owner interactionState:state identifier:identifier];}
- (void)dealloc{[identifier release];[super dealloc];}
@end
static id Flag(BOOL b){return b?(id)kCFBooleanTrue:(id)kCFBooleanFalse;}
@interface OR6APISessionTask:NSObject<OR6APITask>{@public BOOL cancelled;void(^stop)(void);}
@end
@implementation OR6APISessionTask
- (void)cancel{cancelled=YES;if(stop){void(^b)(void)=[[stop copy]autorelease];[stop release];stop=nil;b();}}
- (void)dealloc{[stop release];[super dealloc];}
@end
@implementation OR6APISessionProvider
@synthesize observer=_observer;
- (id)initWithSession:(OR6WebSession*)s host:(id<OR6APIInteractionHost>)host next:(id<OR6APIProvider>)next{
 if((self=[super init])){if(!s||s.delegate){[self release];return nil;}_session=[s retain];_host=[host retain];_next=[next retain];_session.delegate=self;}return self;
}
- (NSDictionary*)summary{
 NSDictionary*d=_session.diagnostics;NSString*phase=_session.phase,*state=[@[@"restoring",@"validating",@"refreshing",@"signing_in"]containsObject:phase]?@"validating":(_session.authenticated?@"authenticated":([phase isEqual:@"signed_out"]?@"signed_out":([phase isEqual:@"reauthentication_required"]?@"login_required":@"recovery_required")));
 return @{@"state":state,@"revision":d[@"revision"],@"authenticated":Flag(_session.authenticated),@"renewable":Flag(_session.renewable),@"expiresAt":NSNull.null,@"cleanupPending":Flag([d[@"legacyCleanupPending"]boolValue])};
}
- (NSDictionary*)interaction{return @{@"interactionId":_interactionId,@"provider":_interactionProvider,@"state":_interactionState,@"session":[self summary]};}
- (void)finishPending{
 if(!_pending)return;NSDictionary*d=_session.diagnostics;if(!((OR6APISessionTask*)_pendingTask)->cancelled&&[d[@"busy"]boolValue])return;
 OR6APIReply reply=[[_pending copy]autorelease];[_pending release];_pending=nil;OR6APISessionTask*task=[[_pendingTask retain]autorelease];[_pendingTask release];_pendingTask=nil;[task->stop release];task->stop=nil;
 if(task->cancelled){reply(nil,OR6APIError(@"cancelled",@"none"));return;}
 if(_session.issue.length)reply(nil,OR6APIError([_session.issue isEqual:@"access_denied"]?@"service_challenge":[_session.issue isEqual:@"rate_limited"]?@"rate_limited":@"session_recovery",@"none"));else reply([self summary],nil);
}
- (void)webSessionChanged:(OR6WebSession*)session{
 (void)session;if(_session.authenticated&&[_interactionState isEqual:@"interactive"]){[_interactionState release];_interactionState=[@"complete"copy];}
 [self finishPending];[_observer apiSessionDidChange];
}
- (void)interactionState:(NSString*)state identifier:(NSString*)identifier{
 if(![_interactionId isEqual:identifier]||![_interactionState isEqual:@"interactive"])return;
 if([state isEqual:@"cancelled"]||[state isEqual:@"failed"]){[_interactionState release];_interactionState=[state copy];[_session cancelSignIn];}
 else if(_session.authenticated){[_interactionState release];_interactionState=[@"complete"copy];}
 [_observer apiSessionDidChange];
}
- (id<OR6APITask>)execute:(NSString*)op parameters:(NSDictionary*)p context:(NSDictionary*)ctx event:(OR6APIEvent)event completion:(OR6APIReply)reply{
 (void)ctx;(void)event;OR6APISessionTask*task=[[[OR6APISessionTask alloc]init]autorelease];
 if([op isEqual:@"auth.begin"]){
  if(!_host||[_interactionState isEqual:@"interactive"]){reply(nil,OR6APIError(_host?@"conflict":@"not_implemented",@"none"));return task;}
  [_interactionTask cancel];[_interactionTask release];_interactionTask=nil;[_interactionId release];_interactionId=[NSProcessInfo.processInfo.globallyUniqueString copy];[_interactionProvider release];_interactionProvider=[p[@"provider"]copy];[_interactionState release];_interactionState=[@"interactive"copy];NSUInteger gen=[_session beginSignIn];NSString*identifier=[[_interactionId copy]autorelease];
  if(_interactionObserver)((OR6APIInteractionForwarder*)_interactionObserver)->owner=nil;[_interactionObserver release];OR6APIInteractionForwarder*f=[[[OR6APIInteractionForwarder alloc]init]autorelease];f->owner=self;f->identifier=[identifier copy];_interactionObserver=[f retain];
  _interactionTask=[[_host presentProvider:_interactionProvider session:_session generation:gen completion:^(NSString*state){[f receive:state];}]retain];
  if(!_interactionTask){[_session cancelSignIn];[_interactionState release];_interactionState=[@"failed"copy];reply(nil,OR6APIError(@"auth_failed",@"none"));}else reply([self interaction],nil);return task;
 }
 if([op isEqual:@"auth.status"]||[op isEqual:@"auth.cancel"]){
  if(![_interactionId isEqual:p[@"interactionId"]]){reply(nil,OR6APIError(@"not_found",@"none"));return task;}
  if([op isEqual:@"auth.cancel"]&&[_interactionState isEqual:@"interactive"]){[_interactionState release];_interactionState=[@"cancelled"copy];[_interactionTask cancel];[_session cancelSignIn];}reply([self interaction],nil);return task;
 }
 if([op isEqual:@"auth.logout"]){if(_pendingTask)[_pendingTask cancel];[_interactionTask cancel];[_interactionState release];_interactionState=[@"cancelled"copy];if([_session signOut])reply([self summary],nil);else reply(nil,OR6APIError(@"storage_failure",@"none"));return task;}
 if([op isEqual:@"auth.restore"]||[op isEqual:@"auth.renew"]){
  if(_pending){reply(nil,OR6APIError(@"conflict",@"none"));return task;}_pending=[reply copy];_pendingTask=[task retain];task->stop=[^{[self finishPending];}copy];if([op isEqual:@"auth.restore"])[_session restore];else[_session renew];[self finishPending];return task;
 }
 if(_next)return[_next execute:op parameters:p context:ctx event:event completion:reply];reply(nil,OR6APIError(@"capability_unverified",@"none"));return task;
}
- (void)dealloc{if(_session.delegate==self)_session.delegate=nil;if(_interactionObserver)((OR6APIInteractionForwarder*)_interactionObserver)->owner=nil;[_interactionTask cancel];[_interactionTask release];[_interactionObserver release];[_pending release];[_pendingTask release];[_session release];[_host release];[_next release];[_interactionId release];[_interactionProvider release];[_interactionState release];[super dealloc];}
@end
