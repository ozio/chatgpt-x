#import "OR6API8Binding.h"
#import "../OR6APIWebAdapter.h"
#import <dispatch/dispatch.h>
@interface OR6API8Binding(){OR6APICore*_core;OR6APIWebAdapter*_adapter;OR6WebSession*_session;NSString*_key;NSUInteger _generation;BOOL _pending,_stopped;void(^_invalidate)(void);void(^_changed)(void);}
@end
@implementation OR6API8Binding
- (id)initWithCore:(OR6APICore*)core adapter:(OR6APIWebAdapter*)adapter session:(OR6WebSession*)session invalidate:(void(^)(void))invalidate changed:(void(^)(void))changed {
 if((self=[super init])){if(!NSThread.isMainThread||!core||!adapter||!session){[self release];return nil;}_core=[core retain];_adapter=[adapter retain];_session=[session retain];_invalidate=[invalidate copy];_changed=[changed copy];_key=[adapter.contextKey copy];_generation=adapter.credentialGeneration;[_core setContextKey:_key];}return self;
}
- (void)apiSessionDidChange {
 if(_stopped)return;[self retain];void(^changed)(void)=[[_changed copy]autorelease];if(changed)changed();if(_stopped||_pending){[self release];return;}_pending=YES;
 dispatch_async(dispatch_get_main_queue(),^{_pending=NO;if(_stopped||[_session.diagnostics[@"busy"]boolValue])return;
  NSString*k=_adapter.contextKey;NSUInteger g=_adapter.credentialGeneration;
  if((![_key isEqual:k]&&(_key||k))||g!=_generation){if(_invalidate)_invalidate();[_core setContextKey:k];[_key release];_key=[k copy];_generation=g;}
 });[self release];
}
- (void)stop{_stopped=YES;[_invalidate release];_invalidate=nil;[_changed release];_changed=nil;}
- (void)dealloc{[self stop];[_core release];[_adapter release];[_session release];[_key release];[super dealloc];}
@end
