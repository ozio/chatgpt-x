#import "OR6ChatNativeHTTP.h"
#import "../api/OR6APIHTTP.h"
#import "../api/OR6APIWire.h"
#include <mach/mach_time.h>
static double Clock(void){mach_timebase_info_data_t t;mach_timebase_info(&t);return(double)mach_absolute_time()*t.numer/t.denom/1e9;}
static NSString*MediaType(NSDictionary*h){NSString*v=nil;for(id k in h)if([k isKindOfClass:NSString.class]&&[k caseInsensitiveCompare:@"Content-Type"]==NSOrderedSame){if(v||![h[k]isKindOfClass:NSString.class])return nil;v=h[k];}return v?[[[v componentsSeparatedByString:@";"][0]stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]lowercaseString]:nil;}
static NSString*TransportIssue(NSError*e){
 if([e.domain isEqual:OR6APIHTTPErrorDomain]){if([@[@(OR6APIHTTPConnectTimeout),@(OR6APIHTTPIdleTimeout),@(OR6APIHTTPOverallTimeout)]containsObject:@(e.code)])return @"timeout";if(e.code==OR6APIHTTPCancelled)return @"cancelled";}
 return @"network_unavailable";
}
NSDictionary*OR6ChatNativeHTTP(NSURLRequest*request,NSString*roots,BOOL stream,BOOL(^cancelled)(void),BOOL(^events)(NSArray*)){
 double began=Clock();NSMutableDictionary*m=[NSMutableDictionary dictionary];NSMutableArray*timeline=[NSMutableArray array];OR6APIDeltaDecoder*d=stream?[[OR6APIDeltaDecoder new]autorelease]:nil;__block NSUInteger chunks=0,count=0;__block BOOL wireError=NO,truncated=NO;__block double first=0,firstEvent=0,decodeMS=0,consumerMS=0;NSError*network=nil;
 NSDictionary*r=OR6APIHTTPPerform(request,roots,[NSSet setWithObject:@"chatgpt.com"],@{@"connectTimeout":@15,@"idleTimeout":@35,@"overallTimeout":@(stream?180:50),@"collectBody":@(!stream),@"acceptEncoding":stream?@"identity":@"gzip",@"traceReadTiming":@(stream),@"maxDecodedBytes":@(8*1024*1024)},cancelled,^BOOL(NSInteger status,NSDictionary*h){
  NSString*mime=MediaType(h);m[@"mimeClass"]=[mime isEqual:@"text/event-stream"]?@"sse":[mime isEqual:@"application/json"]?@"json":mime?@"other":@"missing";m[@"headersMs"]=@((Clock()-began)*1000);m[@"status"]=@(status);return!stream||(status==200&&[mime isEqual:@"text/event-stream"]);
 },stream?^BOOL(NSData*bytes){
  if(cancelled&&cancelled())return NO;chunks++;NSError*e=nil;double entered=Clock();NSArray*batch=[d feed:bytes final:NO error:&e];double decoded=Clock();decodeMS+=(decoded-entered)*1000;
  if(!batch){wireError=YES;batch=[d takeFailureEvents];}count+=batch.count;if(batch.count&&!firstEvent)firstEvent=(decoded-began)*1000;
  BOOL hasText=NO;for(NSDictionary*v in batch)if([v[@"type"]isEqual:@"messageSnapshot"]&&[v[@"message"][@"role"]isEqual:@"assistant"]&&[v[@"message"][@"text"]length])hasText=YES;
  if(hasText&&!first)first=(decoded-began)*1000;double consumerBegan=Clock();BOOL accepted=batch&&(!batch.count||!events||events(batch));double returned=Clock();consumerMS+=(returned-consumerBegan)*1000;
  if(timeline.count<128){NSDictionary*stats=d.diagnostics;[timeline addObject:@[@((entered-began)*1000),@((decoded-began)*1000),@((consumerBegan-began)*1000),@((returned-began)*1000),@(bytes.length),@(batch.count),stats[@"frames"],stats[@"analysisFrames"],stats[@"hiddenAssistantFrames"],stats[@"pendingFrameBytes"],@(hasText)]];}else truncated=YES;
  return accepted&&!wireError;
 }:(OR6APIHTTPBytes)nil,&network);
 NSInteger status=[(r[@"status"]?:m[@"status"])integerValue];m[@"status"]=@(status);m[@"elapsedMs"]=@((Clock()-began)*1000);m[@"startedMonotonic"]=@(began);m[@"certificateVerified"]=r[@"certificateVerified"]?:@NO;m[@"requestBytesSent"]=r[@"requestBytesSent"]?:network.userInfo[@"requestBytesSent"]?:@0;m[@"chunks"]=@(chunks);m[@"events"]=@(count);if(first)m[@"firstTextMs"]=@(first);if(firstEvent)m[@"firstSSEEventMs"]=@(firstEvent);
 NSDictionary*networkMetrics=r?:network.userInfo;for(NSString*k in @[@"timings",@"timingOriginMonotonic",@"configuredAcceptEncoding",@"responseContentEncoding",@"responseFraming",@"connectionAttempts",@"connectionReused",@"tlsVersion",@"streamTiming"])if(networkMetrics[k])m[k]=networkMetrics[k];
 NSMutableDictionary*out=[NSMutableDictionary dictionaryWithDictionary:@{@"metrics":m,@"status":@(status),@"setCookies":r[@"setCookies"]?:@[]}];
 if(stream){NSError*e=nil;NSArray*tail=!wireError?[d feed:[NSData data]final:YES error:&e]:nil;BOOL complete=tail&&d.done&&d.complete&&!network;NSArray*last=tail?:[d takeFailureEvents];if(last.count&&events&&!events(last))complete=NO;out[@"streamComplete"]=@(complete);
  if(!complete){
   if(wireError||(e&&e.code!=7))out[@"issue"]=d.failureIssue?:@"unknown_wire_shape";
   else if([network.domain isEqual:OR6APIHTTPErrorDomain]&&[@[@(OR6APIHTTPConnectTimeout),@(OR6APIHTTPIdleTimeout),@(OR6APIHTTPOverallTimeout)]containsObject:@(network.code)])out[@"issue"]=@"timeout";
   else if([network.domain isEqual:OR6APIHTTPErrorDomain]&&network.code==OR6APIHTTPCancelled)out[@"issue"]=@"cancelled";
   else if(network&&network.code!=OR6APIHTTPConsumerStopped)out[@"issue"]=@"network_unavailable";
   else out[@"issue"]=d.failureIssue?:@"uncertain_outcome";
  }
  m[@"streamWork"]=@{@"rows":timeline,@"truncated":@(truncated),@"decodeMs":@(decodeMS),@"consumerMs":@(consumerMS),@"decoder":d.diagnostics};
 }
 else if(r[@"data"]){NSData*bytes=r[@"data"];id json=bytes.length<=1024*1024?[NSJSONSerialization JSONObjectWithData:bytes options:0 error:NULL]:nil;if([json isKindOfClass:NSDictionary.class])out[@"json"]=json;else out[@"issue"]=@"unknown_wire_shape";}
 if(status>0&&status!=200)out[@"issue"]=status==401?@"not_authenticated":status==403?@"service_challenge":status==429?@"rate_limited":status==408||status==504?@"timeout":@"upstream_error";
 else if(!status&&!out[@"issue"])out[@"issue"]=network?TransportIssue(network):@"upstream_error";
 if(stream&&status==200&&![m[@"mimeClass"]isEqual:@"sse"]){out[@"issue"]=@"unknown_wire_shape";m[@"protocolFailure"]=@{@"stage":@"response_headers",@"reason":@"unexpected_content_type"};}
 return out;
}
