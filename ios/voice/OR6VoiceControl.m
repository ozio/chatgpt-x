#import "OR6VoiceControl.h"
@interface OR6VoiceControl(){
    NSString *_session,*_phase,*_conversation,*_parent;
    BOOL _transport,_channel,_microphoneMuted,_outputMuted;
}
@end
static BOOL Text(id x,NSUInteger max){return[x isKindOfClass:NSString.class]&&[x length]>0&&[x length]<=max;}
@implementation OR6VoiceControl
- (BOOL)matches:(NSString*)session{return Text(session,128)&&[_session isEqual:session];}
- (BOOL)live{return [_phase isEqual:@"connecting"]||[_phase isEqual:@"connected"];}
- (void)phase:(NSString*)phase{[_phase release];_phase=[phase copy];}
- (NSString*)start{
    if([self live])return nil;
    [_session release];_session=[[[NSUUID UUID]UUIDString]copy];
    [_conversation release];_conversation=nil;[_parent release];_parent=nil;
    _transport=_channel=_microphoneMuted=_outputMuted=NO;[self phase:@"connecting"];
    return [[_session copy]autorelease];
}
- (NSString*)resumeSession:(NSString*)oldSession serverContext:(NSDictionary*)context{
    if(![self matches:oldSession]||[self live]||![context isKindOfClass:NSDictionary.class]||
       !Text(context[@"conversationId"],128)||!Text(context[@"parentMessageId"],128))return nil;
    /* A fresh transport and confirmed server context are required. This never
       turns a local mute flag into a successful server-side resumption. */
    NSDictionary*saved=[[context copy]autorelease];NSString*session=[self start];
    _conversation=[saved[@"conversationId"]copy];_parent=[saved[@"parentMessageId"]copy];return session;
}
- (BOOL)transportConnected:(NSString*)session{
    if(![self matches:session]||![self live])return NO;
    _transport=YES;return YES;
}
- (BOOL)channelOpened:(NSString*)session{
    if(![self matches:session]||![self live]||!_transport)return NO;
    _channel=YES;[self phase:@"connected"];return YES;
}
- (NSString*)interrupt:(NSString*)session{
    if(![self matches:session]||!_transport||!_channel||![self live])return nil;
    /* Original haltAllActivity rawValue. Envelope admission is a separate gate. */
    return @"stop_speaking";
}
- (BOOL)mute:(NSString*)session microphone:(BOOL)mic output:(BOOL)output{
    if(![self matches:session]||![self live])return NO;
    _microphoneMuted=mic;_outputMuted=output;return YES;
}
- (BOOL)end:(NSString*)session{
    if(![self matches:session])return NO;
    _transport=_channel=NO;[self phase:@"ended"];return YES;
}
- (BOOL)fail:(NSString*)session{
    if(![self matches:session]||![self live])return NO;
    _transport=_channel=NO;[self phase:@"failed"];return YES;
}
- (BOOL)acceptServerEvent:(NSData*)data session:(NSString*)session{
    if(![self matches:session]||!_channel||![self live]||![data isKindOfClass:NSData.class]||!data.length||data.length>16384)return NO;
    id event=[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    if(![event isKindOfClass:NSDictionary.class]||!Text(event[@"type"],64))return NO;
    /* Candidate transceiver schema, tested locally. Unknown events are rejected
       without losing the connection; wire spelling still needs service proof. */
    if([event[@"type"]isEqual:@"conversation_update"]){
        if(!Text(event[@"conversationId"],128)||!Text(event[@"parentMessageId"],128))return NO;
        [_conversation release];_conversation=[event[@"conversationId"]copy];
        [_parent release];_parent=[event[@"parentMessageId"]copy];return YES;
    }
    if([event[@"type"]isEqual:@"goodbye"]){return[self end:session];}
    return NO;
}
- (NSDictionary*)state:(NSString*)session{
    if(![self matches:session])return nil;
    return @{ @"sessionId":_session,@"phase":_phase,@"transportConnected":@(_transport),
      @"channelOpen":@(_channel),@"microphoneMuted":@(_microphoneMuted),@"outputMuted":@(_outputMuted),
      @"conversationId":_conversation?:NSNull.null,@"parentMessageId":_parent?:NSNull.null,
      @"serviceAdmissionVerified":@NO };
}
- (void)dealloc{[_session release];[_phase release];[_conversation release];[_parent release];[super dealloc];}
@end
