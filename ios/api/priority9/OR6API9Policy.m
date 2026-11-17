#import "../../localization/OR6Localization.h"
#import "OR6API9Policy.h"
#import "../OR6APISchema.h"
#include <stdint.h>
static id Fail(NSError**e,NSString*code){if(e)*e=OR6APIError(code,@"none");return nil;}
static BOOL Text(id v,NSUInteger n){return[v isKindOfClass:NSString.class]&&[v length]&&[v length]<=n&&[v rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location==NSNotFound;}
BOOL OR6API9UUID(id v){return Text(v,36)&&[v length]==36&&[[NSRegularExpression regularExpressionWithPattern:@"^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$"options:0 error:NULL]numberOfMatchesInString:v options:0 range:NSMakeRange(0,36)]==1;}
static uint16_t U16(const unsigned char*p){return(uint16_t)(p[0]|p[1]<<8);}
static uint32_t U32(const unsigned char*p){return(uint32_t)p[0]|(uint32_t)p[1]<<8|(uint32_t)p[2]<<16|(uint32_t)p[3]<<24;}
NSDictionary*OR6API9WAVInfo(NSData*d,NSError**error){
 if(error)*error=nil;if(![d isKindOfClass:NSData.class]||d.length<44||d.length>8*1024*1024)return Fail(error,@"unsupported_media");const unsigned char*p=d.bytes;NSUInteger length=d.length;
 if(memcmp(p,"RIFF",4)||memcmp(p+8,"WAVE",4)||(uint64_t)U32(p+4)+8!=length)return Fail(error,@"unsupported_media");BOOL fmt=NO,data=NO;NSUInteger bytes=0,at=12,chunks=0;
 while(at<length){if(++chunks>128||length-at<8)return Fail(error,@"unsupported_media");uint32_t n=U32(p+at+4);NSUInteger body=at+8;if(n>length-body)return Fail(error,@"unsupported_media");
  if(!memcmp(p+at,"fmt ",4)){if(fmt||n<16||U16(p+body)!=1||U16(p+body+2)!=1||U32(p+body+4)!=16000||U32(p+body+8)!=32000||U16(p+body+12)!=2||U16(p+body+14)!=16)return Fail(error,@"unsupported_media");fmt=YES;}
  if(!memcmp(p+at,"data",4)){if(data||!n||(n&1)||n/2>60*16000)return Fail(error,@"unsupported_media");data=YES;bytes=n;}
  if((NSUInteger)n+(n&1)>length-body)return Fail(error,@"unsupported_media");at=body+n+(n&1);
 }
 if(!fmt||!data)return Fail(error,@"unsupported_media");return @{@"bytes":@(length),@"frames":@(bytes/2),@"durationMS":@((bytes/2)*1000/16000),@"sampleRate":@16000,@"channels":@1,@"bits":@16};
}
NSURLRequest*OR6API9TranscriptionRequest(NSData*d,NSString*boundary,NSError**error){
 if(!OR6API9WAVInfo(d,error))return nil;if(!Text(boundary,70)||boundary.length<16||[boundary rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"]invertedSet]].location!=NSNotFound)return Fail(error,@"invalid_request");
 NSData*needle=[boundary dataUsingEncoding:NSASCIIStringEncoding];if([d rangeOfData:needle options:0 range:NSMakeRange(0,d.length)].location!=NSNotFound)return Fail(error,@"invalid_request");
 NSMutableData*body=[NSMutableData dataWithData:[[NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"file\"; filename=\"recording.wav\"\r\nContent-Type: audio/wav\r\n\r\n",boundary]dataUsingEncoding:NSASCIIStringEncoding]];[body appendData:d];[body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n",boundary]dataUsingEncoding:NSASCIIStringEncoding]];
 NSMutableURLRequest*r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://chatgpt.com/backend-api/transcribe"]];r.HTTPMethod=@"POST";r.HTTPBody=body;[r setValue:[@"multipart/form-data; boundary="stringByAppendingString:boundary]forHTTPHeaderField:@"Content-Type"];return[[r copy]autorelease];
}
NSURLRequest*OR6API9StopRequest(NSString*cid,NSString*token,NSError**error){
 if(!OR6API9UUID(cid)||(token&&!Text(token,32768)))return Fail(error,@"invalid_request");NSMutableURLRequest*r=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://chatgpt.com/backend-api/stop_conversation"]];r.HTTPMethod=@"POST";r.HTTPBody=[NSJSONSerialization dataWithJSONObject:@{@"conversation_id":cid.lowercaseString,@"exclude_async_types":@[]}options:0 error:NULL];[r setValue:@"application/json"forHTTPHeaderField:@"Content-Type"];if(token)[r setValue:token forHTTPHeaderField:@"x-conduit-token"];return[[r copy]autorelease];
}
NSArray*OR6API9AccessibleContent(NSDictionary*p,NSError**error){
 if(![p isKindOfClass:NSDictionary.class]||!Text(p[@"messageId"],96)||![p[@"blocks"]isKindOfClass:NSArray.class]||[p[@"blocks"]count]>2048)return Fail(error,@"invalid_request");NSMutableArray*out=[NSMutableArray array];NSUInteger n=0;
 for(id value in p[@"blocks"]){if(![value isKindOfClass:NSDictionary.class]||![value[@"text"]isKindOfClass:NSString.class]||[value[@"text"]length]>200000)return Fail(error,@"invalid_request");NSString*kind=value[@"kind"],*text=value[@"text"],*label=text,*hint=@"",*trait=@"text",*action=@"none";
  if([kind isEqual:@"link"]||[kind isEqual:@"citation"]){if(!Text(value[@"url"],4096))return Fail(error,@"invalid_request");NSURL*u=[NSURL URLWithString:value[@"url"]];if(![@[@"http",@"https"]containsObject:u.scheme.lowercaseString]||!u.host.length||u.user||u.password)return Fail(error,@"invalid_request");label=text.length?text:value[@"url"];trait=@"link";action=@"open";hint=OR6L(@"Open link");}
  else if([kind isEqual:@"image"]){label=text.length?text:OR6L(@"Image");trait=@"image";}
  else if([kind isEqual:@"code"]){label=text.length?text:OR6L(@"Empty code block");hint=OR6L(@"Code block");action=@"copy";}
  else if(![kind isEqual:@"paragraph"])return Fail(error,@"invalid_request");if(!label.length)continue;
  [out addObject:@{@"id":[NSString stringWithFormat:@"%@:part:%lu",p[@"messageId"],(unsigned long)n++],@"label":label,@"hint":hint,@"traits":@[trait],@"action":action}];
 }return[[out copy]autorelease];
}
NSDictionary*OR6API9AccessibleControl(NSString*identifier,NSString*label,NSString*hint,NSString*action,BOOL enabled,BOOL selected,NSError**error){
 if(!Text(identifier,128)||!Text(label,200000)||![hint isKindOfClass:NSString.class]||hint.length>2000||![@[@"activate",@"copy",@"open",@"remove",@"replace"]containsObject:action])return Fail(error,@"invalid_request");NSMutableArray*traits=[NSMutableArray arrayWithObject:@"button"];if(!enabled)[traits addObject:@"disabled"];if(selected)[traits addObject:@"selected"];return @{@"id":identifier,@"label":label,@"hint":hint,@"traits":traits,@"action":action};
}
