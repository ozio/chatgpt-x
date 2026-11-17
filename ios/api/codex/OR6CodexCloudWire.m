#import "OR6CodexCloudInternal.h"
#import "OR6CodexOperation.h"
#import "../OR6APIHTTP.h"
#import <dispatch/dispatch.h>
static NSString*const Origin=@"https://codex-cloud-backend.chatgpt.com";
static NSString*Escape(NSString*s){return(NSString*)[(id)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,(CFStringRef)s,NULL,CFSTR(":/?#[]@!$&'()*+,;=%"),kCFStringEncodingUTF8)autorelease];}
static NSString*QueryValue(id value){if([value isKindOfClass:NSNumber.class]&&CFGetTypeID((CFTypeRef)value)==CFBooleanGetTypeID())return[value boolValue]?@"true":@"false";return[value description];}
static BOOL Stop(NSError*e){return[@[@"not_authenticated",@"service_challenge",@"rate_limited",@"stale_context"]containsObject:e.userInfo[@"code"]];}
@interface OR6CodexCloudStop:NSObject{@public BOOL stopped;}
@end
@implementation OR6CodexCloudStop
@end
@implementation OR6CodexCloudWire
- (id)initWithBinding:(OR6CodexCloudBinding*)b roots:(NSString*)r error:(NSError**)error{
 // Deliberately bypass the ordinary capability-token initializer. No public URL
 // or headers are accepted on the hosted route, and no app-server guard changes.
 if(!(self=[super init]))return nil;if(!NSThread.isMainThread||![b current]||!OR6CodexPath(r)){if(error)*error=OR6CodexError(@"invalid_request",NO);[self release];return nil;}
 _binding=[b retain];_roots=[r copy];_URL=[[NSURL URLWithString:@"wss://codex-cloud-backend.chatgpt.com/"]retain];_outgoing=[NSMutableArray new];_reads=[NSMutableSet new];return self;
}
- (BOOL)channelIsCurrent{return!_halted&&[_binding current];}
- (NSDictionary*)handshakeHeaders{return[_binding socketHeaders];}
- (NSString*)handshakeProtocol{return@"codex-app-server";}
- (void)stopWithError:(NSError*)error{
 if(Stop(error))_halted=YES;void(^closed)(NSError*)=[[_closedCallback copy]autorelease];[self close];if(closed)closed(error);
}
- (id<OR6APITask>)readPath:(NSString*)path completion:(OR6APIReply)cb{
 if(!cb)return nil;
 // Path safety also protects test injection mistakes; endpoint creation and
 // arbitrary URLs/bodies are unavailable. REST surface is read-only.
 BOOL pathOK=OR6CodexText(path,16384,NO)&&[path hasPrefix:@"/v"]&&![path hasPrefix:@"//"]&&[path rangeOfString:@"#"].location==NSNotFound&&[path rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location==NSNotFound;
 NSURL*u=pathOK?[NSURL URLWithString:[Origin stringByAppendingString:path]]:nil;
 if(!NSThread.isMainThread||!u||![u.host isEqual:@"codex-cloud-backend.chatgpt.com"]||u.user||u.password||u.fragment||_halted||_HTTPWorkers>=8||![_binding current]){cb(nil,OR6CodexError(@"unavailable",NO));return nil;}
 NSDictionary*headers=[_binding headers];if(!headers){cb(nil,OR6CodexError(@"stale_context",NO));return nil;}
 OR6CodexOperation*c=[[[OR6CodexOperation alloc]init]autorelease];[_reads addObject:c];c->reply=[^(NSDictionary*r,NSError*e){[_reads removeObject:c];cb(r,e);}copy];OR6CodexCloudStop*stop=[[[OR6CodexCloudStop alloc]init]autorelease];c->cancelAction=[^{@synchronized(stop){stop->stopped=YES;}}copy];NSUInteger epoch=_readEpoch;_HTTPWorkers++;
 NSMutableURLRequest*request=[NSMutableURLRequest requestWithURL:u cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];for(NSString*k in headers)[request setValue:headers[k]forHTTPHeaderField:k];[request setValue:@"application/json"forHTTPHeaderField:@"Accept"];
 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{NSAutoreleasePool*pool=[NSAutoreleasePool new];NSError*failure=nil;
  NSDictionary*r=OR6APIHTTPPerform(request,_roots,[NSSet setWithObject:@"codex-cloud-backend.chatgpt.com"],@{@"connectTimeout":@10,@"idleTimeout":@15,@"overallTimeout":@30,@"maxEncodedBytes":@1048576,@"maxDecodedBytes":@1048576,@"maxRequestBytes":@32768},^BOOL{__block BOOL current=NO;dispatch_sync(dispatch_get_main_queue(),^{current=[_binding current];});@synchronized(stop){return stop->stopped||!current;}},nil,nil,&failure);
  NSDictionary*value=nil;if(r){NSInteger status=[r[@"status"]integerValue];NSString*rawType=r[@"headers"][@"content-type"];if(![rawType isKindOfClass:NSString.class])rawType=@"";NSArray*parts=[rawType.lowercaseString componentsSeparatedByString:@";"];NSString*content=[[parts objectAtIndex:0]stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];BOOL json=[content isEqual:@"application/json"]||[content isEqual:@"application/problem+json"];
   if(![r[@"certificateVerified"]isEqual:@YES])failure=OR6CodexError(@"tls",NO);
   else if(status==401)failure=OR6CodexError(@"not_authenticated",NO);
   else if(status==403)failure=OR6CodexError(@"service_challenge",NO);
   else if(status==429)failure=OR6CodexError(@"rate_limited",NO);
   else if(status!=200)failure=OR6CodexError(@"upstream_error",NO);
   else if(!json||![r[@"data"]isKindOfClass:NSData.class]||[r[@"data"]length]>1048576)failure=OR6CodexError(@"invalid_response",NO);
   else{value=[NSJSONSerialization JSONObjectWithData:r[@"data"]options:0 error:NULL];if(![value isKindOfClass:NSDictionary.class]){value=nil;failure=OR6CodexError(@"invalid_response",NO);}}
  }else failure=OR6CodexError(@"network_unavailable",NO);
  [value retain];[failure retain];dispatch_async(dispatch_get_main_queue(),^{
   if(_HTTPWorkers)_HTTPWorkers--;
   if(!c->done){if(epoch!=_readEpoch||![_binding current]){[c finish:nil error:OR6CodexError(@"stale_context",NO)];}else{if(Stop(failure)){// Fail closed before invoking caller code; close may itself settle c.
     [_reads removeObject:c];[self stopWithError:failure];
    }if(!c->done)[c finish:failure?nil:value error:failure];}}
   [value release];[failure release];
  });[pool drain];
 });return c;
}
- (BOOL)send:(NSDictionary*)m error:(NSError**)error{
 if(!NSThread.isMainThread||_halted||![_binding current]){if(error)*error=OR6CodexError(@"stale_context",NO);return NO;}
 m=OR6APIJSONSnapshot(m,24576);if(!m){if(error)*error=OR6CodexError(@"invalid_request",NO);return NO;}
 NSString*method=m[@"method"];NSDictionary*p=m[@"params"];NSString*path=nil;
 if(method&&!OR6CodexText(method,128,NO)){if(error)*error=OR6CodexError(@"invalid_request",NO);return NO;}
 BOOL read=[@[@"thread/read",@"thread/turns/list",@"thread/items/list",@"model/list",@"collaborationMode/list"]containsObject:method?:@""];
 if(read&&(!OR6CodexID(m[@"id"])||![p isKindOfClass:NSDictionary.class]||([method hasPrefix:@"thread/"]&&!OR6CodexID(p[@"threadId"])))){if(error)*error=OR6CodexError(@"invalid_request",NO);return NO;}
 if([method isEqual:@"thread/read"])path=[@"/v1/threads/"stringByAppendingString:Escape(p[@"threadId"])];
 else if([method isEqual:@"thread/turns/list"]||[method isEqual:@"thread/items/list"])path=[NSString stringWithFormat:@"/v2/threads/%@/%@",Escape(p[@"threadId"]),[method isEqual:@"thread/items/list"]?@"items":@"turns"];
 else if([method isEqual:@"model/list"])path=@"/v2/models";
 else if([method isEqual:@"collaborationMode/list"])path=@"/v2/collaboration-modes";
 // Account ownership is exclusively the trusted source; never forward account
 // RPCs to cloud or synthesize desktop ownership/auth/config results.
 else if([method hasPrefix:@"account/"]||[method isEqual:@"getAuthStatus"]||[method isEqual:@"configRequirements/read"]){if(error)*error=OR6CodexError(@"unavailable",NO);return NO;}
 if(!path){
  if([method isEqual:@"thread/resume"]||[method isEqual:@"thread/list"]){NSMutableDictionary*changed=[[m mutableCopy]autorelease];NSMutableDictionary*params=[[p mutableCopy]autorelease];if([method isEqual:@"thread/resume"])params[@"config"]=@{@"features.mcp_app_ui":@YES};else params[@"useStateDbOnly"]=@YES;changed[@"params"]=params;m=changed;}
  return[super send:m error:error];
 }
 if(!_upgraded||_cancelled||_reads.count>=8){if(error)*error=OR6CodexError(@"unavailable",NO);return NO;}
 NSMutableArray*q=[NSMutableArray array];for(NSString*k in[[p allKeys]sortedArrayUsingSelector:@selector(compare:)])if(![@[@"threadId",@"includeTurns"]containsObject:k]&&p[k]!=NSNull.null)[q addObject:[NSString stringWithFormat:@"%@=%@",Escape(k),Escape(QueryValue(p[k]))]];
 if(q.count)path=[path stringByAppendingFormat:@"?%@",[q componentsJoinedByString:@"&"]];id identifier=m[@"id"];NSUInteger epoch=_readEpoch;
 [self readPath:path completion:^(NSDictionary*r,NSError*e){if(epoch!=_readEpoch||_cancelled)return;if(e||!r){[self stopWithError:e?:OR6CodexError(@"invalid_response",YES)];return;}
  if([method isEqual:@"thread/read"]){if(![r[@"thread"]isKindOfClass:NSDictionary.class]||![r[@"thread"][@"id"]isEqual:p[@"threadId"]]){[self stopWithError:OR6CodexError(@"schema_mismatch",YES)];return;}NSMutableDictionary*t=[[r[@"thread"]mutableCopy]autorelease];t[@"turns"]=@[];NSMutableDictionary*result=[[r mutableCopy]autorelease];result[@"thread"]=t;r=result;}
  void(^receive)(NSDictionary*)=[[_receiver copy]autorelease];if(receive)receive(@{@"id":identifier,@"result":r});
 }];return YES;
}
- (void)open:(void(^)(NSDictionary*))receive closed:(void(^)(NSError*))closed ready:(void(^)(NSError*))ready{
 [super open:^(NSDictionary*raw){
  // Hosted notifications carry optional delivery timestamps outside JSON-RPC.
  // Validate the envelope metadata, then pass only the strict RPC envelope on.
  NSMutableDictionary*m=[[raw mutableCopy]autorelease];for(NSString*k in @[@"emittedAtMs",@"emitted_at_ms"]){if(m[k]){if(!OR6APISchemaCheck(m[k],@{@"type":@"integer",@"minimum":@0,@"maximum":@9007199254740991LL},@{})){[self stopWithError:OR6CodexError(@"schema_mismatch",YES)];return;}[m removeObjectForKey:k];}}
  if(receive)receive(m);
 }closed:closed ready:ready];
}
- (void)close{_readEpoch++;for(OR6CodexOperation*c in[[_reads.allObjects copy]autorelease])[c cancel];[super close];}
- (void)dealloc{[_binding release];[_reads release];[super dealloc];}
@end
