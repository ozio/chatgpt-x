#import "OR6CodexAPI.h"
@implementation OR6CodexAPI
- (id)initWithTransport:(id<OR6CodexTransport>)t contracts:(NSDictionary*)c context:(NSDictionary*)ctx privateDirectory:(NSString*)directory error:(NSError**)error{
 if(!(self=[super init]))return nil;if(!NSThread.isMainThread){if(error)*error=OR6CodexError(@"invalid_request",NO);[self release];return nil;}
 OR6CodexSession*s=[[[OR6CodexSession alloc]initWithTransport:t contracts:c context:ctx directory:directory error:error]autorelease];if(!s){[self release];return nil;}_context=[OR6APIJSONSnapshot(ctx,8192)retain];_provider=[[OR6CodexProvider alloc]initWithSession:s context:_context];if(!_provider){if(error)*error=OR6CodexError(@"invalid_request",NO);[self release];return nil;}return self;
}
- (id)initWithURL:(NSURL*)u capabilityToken:(NSString*)token roots:(NSString*)roots contracts:(NSDictionary*)contracts context:(NSDictionary*)ctx privateDirectory:(NSString*)directory error:(NSError**)error{
 OR6CodexWSS*t=[[[OR6CodexWSS alloc]initWithURL:u capabilityToken:token roots:roots error:error]autorelease];if(!t){[self release];return nil;}return[self initWithTransport:t contracts:contracts context:ctx privateDirectory:directory error:error];
}
- (id<OR6APITask>)perform:(NSString*)op parameters:(NSDictionary*)p event:(OR6APIEvent)e completion:(OR6APIReply)reply{return[_provider execute:op parameters:p context:_context event:e completion:reply];}
- (BOOL)matchesContext:(NSDictionary*)c{return[_context isEqual:c];}
- (void)deactivate{[_provider deactivate];}
- (void)dealloc{[_provider deactivate];[_provider release];[_context release];[super dealloc];}
@end
