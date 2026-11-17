#import "OR6CodexPairRelay.h"
#import "../../../auth/OR6OAuthCrypto.h"
static BOOL Integer(id v,uint64_t minimum,uint64_t maximum) {
    return OR6APISchemaCheck(v,@{@"type":@"integer",@"minimum":@(minimum),@"maximum":@(maximum)},@{});
}
@implementation OR6CodexPairCodec
- (id)initClient:(NSString *)client environment:(NSString *)environment {
    if((self=[super init])){if(!OR6CodexID(client)||!OR6CodexID(environment)){[self release];return nil;}_client=[client copy];_environment=[environment copy];}return self;
}
- (NSArray *)outgoing:(NSDictionary *)RPC error:(NSError **)error {
    RPC=OR6APIJSONSnapshot(RPC,262144);if(!RPC)goto invalid;
    if([RPC[@"method"]isEqual:@"initialize"]||!_stream){[_stream release];_stream=[NSProcessInfo.processInfo.globallyUniqueString copy];_outSequence=0;_lastSequence=0;_hasSequence=NO;[_assembly release];_assembly=nil;[_segment release];_segment=nil;[_cursor release];_cursor=nil;}
    if(_outSequence>=9007199254740991ULL)goto invalid;
    NSMutableDictionary *envelope=[NSMutableDictionary dictionaryWithDictionary:@{@"type":@"client_message",@"client_id":_client,@"env_id":_environment,@"stream_id":_stream,@"seq_id":@(++_outSequence),@"skip_history":@NO}];
    NSData *bytes=[NSJSONSerialization dataWithJSONObject:RPC options:0 error:NULL];
    if(bytes.length<=16384){envelope[@"message"]=RPC;return @[envelope];}
    // Smaller segments than Desktop keep the existing iOS6 websocket queue and
    // decoder bounded. The wire segment fields and ordering remain identical.
    NSUInteger count=(bytes.length+12287)/12288;if(count>24)goto invalid;
    NSMutableArray *segments=[NSMutableArray array];
    for(NSUInteger i=0;i<count;i++){
        NSMutableDictionary *segment=[[envelope mutableCopy]autorelease];segment[@"type"]=@"client_message_chunk";segment[@"segment_id"]=@(i);segment[@"segment_count"]=@(count);segment[@"message_size_bytes"]=@(bytes.length);segment[@"message_chunk_base64"]=OR6CodexPairBase64([bytes subdataWithRange:NSMakeRange(i*12288,MIN((NSUInteger)12288,bytes.length-i*12288))]);[segments addObject:segment];
    }return segments;
invalid:if(error)*error=OR6CodexError(@"size_limit",NO);return nil;
}
- (NSDictionary *)heartbeat {if(!_stream||_outSequence>=9007199254740991ULL)return nil;return @{@"type":@"ping",@"client_id":_client,@"env_id":_environment,@"stream_id":_stream,@"seq_id":@(++_outSequence),@"state":@"foreground",@"skip_history":@YES};}
- (NSArray *)incoming:(NSDictionary *)raw error:(NSError **)error {
    NSDictionary *e=OR6APIJSONSnapshot(raw,180224);if(!e||!_stream||![e[@"client_id"]isEqual:_client])goto invalid;
    if(![e[@"env_id"]isEqual:_environment]||![e[@"stream_id"]isEqual:_stream])goto invalid;
    NSString *type=e[@"type"];
    if([type isEqual:@"ack"]){if(!Integer(e[@"seq_id"],0,9007199254740991ULL)||[e[@"seq_id"]unsignedLongLongValue]>_outSequence)goto invalid;return @[];}
    if(![@[@"server_message",@"server_message_chunk",@"pong"]containsObject:type]||!Integer(e[@"seq_id"],0,9007199254740991ULL))goto invalid;
    uint64_t seq=[e[@"seq_id"]unsignedLongLongValue];
    if([type isEqual:@"pong"]){if([e[@"status"]isEqual:@"unknown"])goto gap;if(![e[@"status"]isEqual:@"active"])goto invalid;}
    if(_hasSequence&&seq<=_lastSequence)return @[];
    if(_hasSequence&&seq!=_lastSequence+1)goto gap;
    if([type isEqual:@"pong"]){if(_assembly)goto gap;_lastSequence=seq;_hasSequence=YES;return @[];}
    NSDictionary *message=e[@"message"];
    if([type isEqual:@"server_message_chunk"]){
        if(!Integer(e[@"segment_id"],0,127)||!Integer(e[@"segment_count"],2,128)||!Integer(e[@"message_size_bytes"],1,1048576))goto invalid;
        NSUInteger index=[e[@"segment_id"]unsignedIntegerValue],count=[e[@"segment_count"]unsignedIntegerValue];if(index>=count)goto invalid;
        NSData *part=OR6CodexPairDecode64(e[@"message_chunk_base64"]);if(!part.length||part.length>114688)goto invalid;
        if(!_assembly){if(index)goto gap;_assembly=[NSMutableData new];_segment=[e copy];_nextSegment=0;}
        if(![e[@"seq_id"]isEqual:_segment[@"seq_id"]]||![e[@"segment_count"]isEqual:_segment[@"segment_count"]]||![e[@"message_size_bytes"]isEqual:_segment[@"message_size_bytes"]])goto invalid;
        if(index<_nextSegment)return @[];if(index!=_nextSegment)goto gap;
        if(_assembly.length+part.length>[e[@"message_size_bytes"]unsignedIntegerValue])goto invalid;
        [_assembly appendData:part];_nextSegment++;
        if(_nextSegment<count)return @[];
        if(_assembly.length!=[e[@"message_size_bytes"]unsignedIntegerValue])goto invalid;
        id v=[NSJSONSerialization JSONObjectWithData:_assembly options:0 error:NULL];
        message=[v isKindOfClass:NSDictionary.class]?OR6APIJSONSnapshot(v,1048576):nil;
        [_assembly release];_assembly=nil;[_segment release];_segment=nil;_nextSegment=0;
    }else if(_assembly)goto gap;
    if(![message isKindOfClass:NSDictionary.class]||(!message[@"method"]&&!message[@"result"]&&!message[@"error"]))goto invalid;
    if(e[@"cursor"]&&e[@"cursor"]!=NSNull.null&&!OR6CodexText(e[@"cursor"],8192,NO))goto invalid;
    _lastSequence=seq;_hasSequence=YES;if([e[@"cursor"]isKindOfClass:NSString.class]){[_cursor release];_cursor=[e[@"cursor"]copy];}
    return @[message];
gap:if(error)*error=OR6CodexError(@"uncertain_outcome",YES);return nil;
invalid:if(error)*error=OR6CodexError(@"schema_mismatch",YES);return nil;
}
- (void)dealloc {[_client release];[_environment release];[_stream release];[_cursor release];[_assembly release];[_segment release];[super dealloc];}
@end

@implementation OR6CodexPairRelay
- (id)initWithSource:(OR6CodexPairCredentials)source snapshot:(NSDictionary *)snapshot grant:(NSDictionary *)grant identity:(NSDictionary *)identity scalar:(NSData *)scalar environment:(NSString *)environment roots:(NSString *)roots {
    // Bypass only the generic host initializer. This separate transport admits
    // exactly the pinned first-party relay; generic app-server rules stay intact.
    if((self=[super init])){
        if(!source||!OR6CodexID(grant[@"clientId"])||!OR6CodexID(environment)||!OR6CodexText(grant[@"token"],16384,NO)||!OR6CodexPath(roots)||scalar.length!=32){[self release];return nil;}
        _source=[source copy];_snapshot=[snapshot retain];_grant=[grant copy];_identity=[identity copy];_scalar=[scalar copy];_roots=[roots copy];_URL=[[NSURL URLWithString:@"wss://chatgpt.com/backend-api/codex/remote/control/client"]retain];_outgoing=[NSMutableArray new];_codec=[[OR6CodexPairCodec alloc]initClient:grant[@"clientId"]environment:environment];
    }return self;
}
- (BOOL)channelIsCurrent {
    return _source&&[_source()isEqual:_snapshot]&&[_snapshot[@"expiresAt"]doubleValue]>[NSDate.date timeIntervalSince1970]+5&&[_grant[@"expiry"]doubleValue]>[NSDate.date timeIntervalSince1970]+5;
}
- (NSDictionary *)handshakeHeaders {
    if(![self channelIsCurrent])return nil;
    return @{@"Authorization":[@"Bearer "stringByAppendingString:_snapshot[@"accessToken"]],@"ChatGPT-Account-Id":_snapshot[@"context"][@"workspace"],@"originator":@"legacy_ios6",@"User-Agent":@"LegacyClient/1 (iOS 6; Codex)",@"x-codex-client-id":_grant[@"clientId"],@"x-codex-protocol-version":@"3",@"x-codex-client-session-token":[@"Bearer "stringByAppendingString:_grant[@"token"]]};
}
- (NSString *)handshakeProtocol {return nil;}
- (void)fail:(NSError *)e {
    void(^ready)(NSError *)=[[_relayOpened copy]autorelease];[_relayOpened release];_relayOpened=nil;
    void(^closed)(NSError *)=[[_relayClosed copy]autorelease];[_relayClosed release];_relayClosed=nil;[self close];
    if(ready)ready(e);else if(closed)closed(e);
}
- (void)heartbeat {
    if(!_relayReady)return;if(![self channelIsCurrent]){[self fail:OR6CodexError(@"stale_context",NO)];return;}NSDictionary *ping=[_codec heartbeat];NSError *e=nil;if(ping&&![super send:ping error:&e]){[self fail:e];return;}[self performSelector:@selector(heartbeat)withObject:nil afterDelay:15];
}
- (void)challengeTimedOut {if(!_relayReady)[self fail:OR6CodexError(@"timeout",NO)];}
- (void)open:(void(^)(NSDictionary *))receive closed:(void(^)(NSError *))closed ready:(void(^)(NSError *))ready {
    if(_relayOpened||_running){if(ready)ready(OR6CodexError(@"conflict",NO));return;}
    _proofSent=NO;_relayReady=NO;_relayOpened=[ready copy];[_relayClosed release];_relayClosed=[closed copy];
    [super open:^(NSDictionary *raw){
        if(!_relayReady){
            if(_proofSent||![raw[@"type"]isEqual:@"device_key_challenge"]||![raw[@"purpose"]isEqual:@"remote_control_client_websocket"]){[self fail:OR6CodexError(@"schema_mismatch",NO)];return;}
            NSDictionary *payload=OR6CodexPairConnectionPayload(raw,_snapshot[@"accountUserId"],_grant[@"clientId"],_grant[@"token"],_grant[@"expiry"],[NSDate.date timeIntervalSince1970]);
            NSDictionary *proof=payload?OR6CodexPairSign(_scalar,_identity[@"keyId"],payload):nil;
            if(!proof){[self fail:OR6CodexError(@"access_denied",NO)];return;}
            NSMutableDictionary *response=[[proof mutableCopy]autorelease];response[@"type"]=@"device_key_proof";NSError *e=nil;
            if(![super send:response error:&e]){[self fail:e];return;}
            _proofSent=YES;_relayReady=YES;[self performSelector:@selector(heartbeat)withObject:nil afterDelay:15];[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(challengeTimedOut)object:nil];
            void(^opened)(NSError *)=[[_relayOpened copy]autorelease];[_relayOpened release];_relayOpened=nil;if(opened)opened(nil);return;
        }
        NSError *e=nil;NSArray *messages=[_codec incoming:raw error:&e];
        if(!messages){[self fail:e];return;}for(NSDictionary *message in messages)if(receive)receive(message);
    }closed:^(NSError *e){[self fail:e];}ready:^(NSError *e){if(e){[self fail:e];return;}[self performSelector:@selector(challengeTimedOut)withObject:nil afterDelay:10];}];
}
- (BOOL)send:(NSDictionary *)message error:(NSError **)error {
    if(!_relayReady||![self channelIsCurrent]){if(error)*error=OR6CodexError(@"unavailable",NO);return NO;}
    NSArray *segments=[_codec outgoing:message error:error];if(!segments)return NO;
    @synchronized(self){if(_outgoing.count+segments.count>32){if(error)*error=OR6CodexError(@"size_limit",NO);return NO;}for(NSDictionary *segment in segments)if(![super send:segment error:error])return NO;}
    return YES;
}
- (void)close {[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(heartbeat)object:nil];[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(challengeTimedOut)object:nil];_relayReady=NO;[super close];}
- (NSString *)description {return @"<OR6CodexPairRelay private>";}
- (void)dealloc {[self close];[_relayOpened release];[_relayClosed release];[_source release];[_snapshot release];[_grant release];[_identity release];[_scalar release];[_codec release];[super dealloc];}
@end
