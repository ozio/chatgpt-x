#import "OR6VoiceSignaling.h"
#include "OR6VoicePeer.h"
NSMutableURLRequest *OR6VoiceSignalingRequest(NSURL*url,NSString*offer,NSDictionary*session){
    if(![url isKindOfClass:NSURL.class]||![url.scheme isEqual:@"https"]||!url.host.length||
       url.user||url.password||url.query||url.fragment||
       !([url.path hasSuffix:@"/realtime/wm"]||[url.path hasSuffix:@"/realtime/vp"])||
       ![offer isKindOfClass:NSString.class]||![session isKindOfClass:NSDictionary.class]||
       ![NSJSONSerialization isValidJSONObject:session])return nil;
    NSData*sdp=[offer dataUsingEncoding:NSUTF8StringEncoding];
    if(!sdp.length||sdp.length>8191||![offer hasPrefix:@"v=0\r\n"])return nil;
    NSData*json=[NSJSONSerialization dataWithJSONObject:session options:0 error:NULL];
    if(!json||json.length>32768)return nil;
    NSString*boundary=[@"ChatGPTXVoice-" stringByAppendingString:[[NSUUID UUID]UUIDString]];
    NSMutableData*body=[NSMutableData data];
    NSArray*names=@[@"sdp",@"session"],*values=@[sdp,json];
    for(NSUInteger i=0;i<names.count;i++){
        NSString*header=[NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"%@\"\r\n\r\n",boundary,names[i]];
        [body appendData:[header dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:values[i]];[body appendBytes:"\r\n" length:2];
    }
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n",boundary]dataUsingEncoding:NSUTF8StringEncoding]];
    NSMutableURLRequest*request=[NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:20];
    request.HTTPMethod=@"POST";request.HTTPBody=body;request.HTTPShouldHandleCookies=NO;
    [request setValue:[@"multipart/form-data; boundary="stringByAppendingString:boundary]forHTTPHeaderField:@"Content-Type"];
    return request;
}
