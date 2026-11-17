#import "OR6CodexPolicy8.h"
#import <CommonCrypto/CommonDigest.h>
NSString*OR6CodexDigest(NSString*s){if(![s isKindOfClass:NSString.class])return nil;NSData*d=[s dataUsingEncoding:NSUTF8StringEncoding];if(!d)return nil;unsigned char h[CC_SHA256_DIGEST_LENGTH];CC_SHA256(d.bytes,(CC_LONG)d.length,h);NSMutableString*out=[NSMutableString string];for(NSUInteger i=0;i<sizeof(h);i++)[out appendFormat:@"%02x",h[i]];return out;}
static BOOL Subset(id requested,id granted,NSUInteger depth){
 if(depth>16)return NO;if(granted==NSNull.null)return YES;
 if([granted isKindOfClass:NSDictionary.class]){if(![requested isKindOfClass:NSDictionary.class])return[granted count]==0;for(id k in granted)if(!Subset(requested[k],granted[k],depth+1))return NO;return YES;}
 if([granted isKindOfClass:NSArray.class]){if(![requested isKindOfClass:NSArray.class])return[granted count]==0;for(id x in granted)if(![requested containsObject:x])return NO;return YES;}
 if([granted isEqual:@NO]&&OR6APISchemaCheck(granted,@{@"type":@"boolean"},@{}))return YES;
 return requested&&[requested isEqual:granted];
}
BOOL OR6CodexPermissionSubset(NSDictionary*requested,NSDictionary*response){return OR6CodexKeys(response,@[@"permissions"],@[@"scope",@"strictAutoReview"])&&OR6CodexKeys(response[@"permissions"],@[],@[@"network",@"fileSystem"])&&Subset(requested,response[@"permissions"],0)&&(!response[@"scope"]||[response[@"scope"]isEqual:@"turn"]);}
static BOOL Primitive(id v,NSDictionary*s){
 NSString*t=s[@"type"];if(![@[@"string",@"number",@"integer",@"boolean",@"array"]containsObject:t])return NO;
 NSMutableDictionary*check=[NSMutableDictionary dictionaryWithObject:t forKey:@"type"];for(NSString*k in @[@"minimum",@"maximum",@"minLength",@"maxLength",@"minItems",@"maxItems",@"enum"])if(s[k]&&s[k]!=NSNull.null)check[k]=s[k];
 if(!OR6APISchemaCheck(v,check,@{}))return NO;
 if([t isEqual:@"array"]){if(![s[@"items"]isKindOfClass:NSDictionary.class])return NO;for(id x in v)if(!Primitive(x,s[@"items"]))return NO;}
 if(s[@"oneOf"]){BOOL found=NO;for(NSDictionary*c in s[@"oneOf"])if([c[@"const"]isEqual:v])found=YES;if(!found)return NO;}
 if(!OR6APISchemaCheck(v,check,@{}))return NO;
 NSString*format=s[@"format"];if(format&&format!=(id)NSNull.null){if(![v isKindOfClass:NSString.class])return NO;if([format isEqual:@"uri"]){NSURL*u=[NSURL URLWithString:v];if(!u.scheme.length)return NO;}else if([format isEqual:@"email"]){NSArray*a=[v componentsSeparatedByString:@"@"];if(a.count!=2||![a[0]length]||![a[1]length]||[v rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location!=NSNotFound)return NO;}else if([format isEqual:@"date"]||[format isEqual:@"date-time"]){NSDateFormatter*f=[[[NSDateFormatter alloc]init]autorelease];f.locale=[[[NSLocale alloc]initWithLocaleIdentifier:@"en_US_POSIX"]autorelease];f.lenient=NO;f.dateFormat=[format isEqual:@"date"]?@"yyyy-MM-dd":@"yyyy-MM-dd'T'HH:mm:ssZZZZZ";if(![f dateFromString:v])return NO;}else return NO;}
 return YES;
}
BOOL OR6CodexElicitationResponse(NSDictionary*q,NSDictionary*r){
 if(!OR6CodexKeys(r,@[@"action"],@[@"content"]))return NO;NSString*action=r[@"action"];
 if([action isEqual:@"decline"]||[action isEqual:@"cancel"])return!r[@"content"]||r[@"content"]==NSNull.null;
 if(![action isEqual:@"accept"])return NO;
 NSString*mode=q[@"mode"];if([mode isEqual:@"url"])return!r[@"content"]||r[@"content"]==NSNull.null;
 // Device proof is deliberately unavailable. Extended arbitrary JSON schemas
 // are not treated as validated forms; clients may decline/cancel those safely.
 if(![mode isEqual:@"form"])return NO;
 NSDictionary*s=q[@"requestedSchema"],*content=r[@"content"];if(!OR6CodexKeys(content,@[],[s[@"properties"]allKeys])||content.count>32)return NO;
 for(NSString*k in s[@"required"]==NSNull.null?@[]:s[@"required"])if(!content[k])return NO;
 for(NSString*k in content)if(!Primitive(content[k],s[@"properties"][k]))return NO;return YES;
}
