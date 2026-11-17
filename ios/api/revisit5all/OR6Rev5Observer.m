#import "OR6Rev5All.h"
#import "OR6Rev5Host.h"
@implementation OR6Rev5Observer{
 NSMutableDictionary*_switches;id<OR6APIProvider>_next;OR6APIWebAdapter *_adapter;OR6Rev5Host *_host;void(^_changed)(void);void(^_audio)(void);BOOL(^_allowed)(void);void(^_asset)(NSString*,NSDictionary*,NSDictionary*);
}
- (id)initWithNext:(id<OR6APIProvider>)next adapter:(OR6APIWebAdapter*)adapter host:(OR6Rev5Host*)host{if((self=[super init])){if(!next||!adapter||!host){[self release];return nil;}_next=[next retain];_adapter=[adapter retain];_host=[host retain];_switches=[NSMutableDictionary new];}return self;}
- (void)setWorkspaceChanged:(void(^)(void))changed{[_changed release];_changed=[changed copy];}
- (void)setWorkspaceAllowed:(BOOL(^)(void))allowed{[_allowed release];_allowed=[allowed copy];}
- (void)setAssetDidValidate:(void(^)(NSString*,NSDictionary*,NSDictionary*))observer{[_asset release];_asset=[observer copy];}
- (void)setAudioWillStart:(void(^)(void))callback{[_audio release];_audio=[callback copy];}
- (id<OR6APITask>)execute:(NSString*)op parameters:(NSDictionary*)p context:(NSDictionary*)ctx event:(OR6APIEvent)event completion:(OR6APIReply)reply{
 // A native exchange may complete before the queued Core generation refresh.
 // Reject even LOCAL reads during that gap; old-workspace data cannot escape.
 if(!NSThread.isMainThread){if(reply)dispatch_async(dispatch_get_main_queue(),^{reply(nil,OR6APIError(@"invalid_request",@"none"));});return nil;}
 NSDictionary*live=_host.liveContext;
 if(![op hasPrefix:@"auth."]&&(![live[@"valid"]isEqual:@YES]||![ctx[@"key"]isEqual:live[@"key"]])){if(reply)reply(nil,OR6APIError(@"stale_context",@"none"));return nil;}
 if([op isEqual:@"workspaces.select"]&&(!_allowed||!_allowed())){if(reply)reply(nil,OR6APIError(@"conflict",@"none"));return nil;}
 if(_audio&&([@[@"audio.readAloud",@"audio.play",@"audio.resume",@"audio.retry",@"media.audioRecording.start",@"media.audioAttachment.play",@"dictation.start",@"dictation.retry",@"dictation.stream.start"]containsObject:op]||[op isEqual:@"pronunciation.play"]))_audio();
 if([op isEqual:@"workspaces.select"]){NSString*identifier=[p[@"operationId"]isKindOfClass:NSString.class]?[[p[@"operationId"]copy]autorelease]:nil;if(!identifier||_switches[identifier]||_switches.count>=8){if(reply)reply(nil,OR6APIError(@"conflict",@"none"));return nil;}_switches[identifier]=OR6APIJSONSnapshot(@{@"context":ctx,@"userId":live[@"userId"]?:NSNull.null,@"targetId":p[@"workspaceId"]?:NSNull.null},8192);return[_next execute:op parameters:p context:ctx event:event completion:^(NSDictionary*r,NSError*e){if(reply)reply(r,e);[_switches removeObjectForKey:identifier];}];}
 return[_next execute:op parameters:p context:ctx event:event completion:reply];
}
- (void)didValidate:(NSString*)op result:(NSDictionary*)r context:(NSDictionary*)ctx{NSDictionary*live=_host.liveContext;NSDictionary*source=[r[@"operationId"]isKindOfClass:NSString.class]?_switches[r[@"operationId"]]:nil;BOOL switched=source&&[source[@"userId"]isEqual:live[@"userId"]]&&[source[@"targetId"]isEqual:r[@"selectedWorkspaceId"]]&&[source[@"context"]isEqual:ctx]&&[op isEqual:@"workspaces.select"]&&[r[@"selected"]isEqual:@YES]&&[live[@"valid"]isEqual:@YES]&&[live[@"accountId"]isEqual:r[@"selectedWorkspaceId"]];if(![op hasPrefix:@"auth."]&&!switched&&(![live[@"valid"]isEqual:@YES]||![ctx[@"key"]isEqual:live[@"key"]]))return;if([_next respondsToSelector:_cmd])[_next didValidate:op result:r context:ctx];if(_asset)_asset(op,r,ctx);if([op isEqual:@"workspaces.select"]&&[r[@"selected"]isEqual:@YES]&&_changed){void(^changed)(void)=[[_changed copy]autorelease];dispatch_async(dispatch_get_main_queue(),changed);}}
- (void)releaseCompletedDraft:(NSString*)draft context:(NSDictionary*)ctx{NSDictionary*live=_host.liveContext;if(![live[@"valid"]isEqual:@YES]||![live[@"key"]isEqual:ctx[@"key"]])return;if([_next respondsToSelector:_cmd])[_next releaseCompletedDraft:draft context:ctx];}
- (void)dealloc{[_switches release];[_next release];[_adapter release];[_host release];[_changed release];[_audio release];[_allowed release];[_asset release];[super dealloc];}
@end
