#import "OR6APISchema.h"
#import <CoreFoundation/CoreFoundation.h>
#include <math.h>
NSString *const OR6APIErrorDomain=@"OR6API";
NSError *OR6APIError(NSString *code,NSString *dispatch){
 NSSet *codes=[NSSet setWithArray:@[@"invalid_request",@"invalid_response",@"stale_context",@"unavailable",@"capability_unverified",@"storage_failure",@"uncertain_outcome",@"cancelled",@"not_authenticated",@"access_denied",@"rate_limited",@"network_unavailable",@"timeout",@"duplicate_operation",@"invalid_operation_state",@"unknown_operation",@"schema_mismatch",@"not_implemented",@"capability_unavailable",@"login_required",@"auth_cancelled",@"auth_failed",@"session_recovery",@"owner_mismatch",@"network",@"tls",@"service_challenge",@"upstream_error",@"unknown_wire_shape",@"size_limit",@"conflict",@"uncertain",@"not_found",@"expired",@"unsupported_media",@"permission_denied"]];
 if(![code isKindOfClass:NSString.class]||![codes containsObject:code])code=@"invalid_response";
 if(![dispatch isKindOfClass:NSString.class]||![@[@"none",@"possible",@"confirmed"]containsObject:dispatch])dispatch=@"possible";
 return [NSError errorWithDomain:OR6APIErrorDomain code:1 userInfo:@{@"code":code,@"dispatch":dispatch}];
}
NSDictionary *OR6APIErrorDTO(NSError *error,NSString *identifier){NSError*safe=OR6APIError(error.userInfo[@"code"],error.userInfo[@"dispatch"]);return @{@"domain":@"OR6API",@"code":safe.userInfo[@"code"],@"operationId":[identifier isKindOfClass:NSString.class]&&identifier.length<=64?identifier:(id)NSNull.null,@"retryable":(id)kCFBooleanFalse,@"dispatched":[safe.userInfo[@"dispatch"]isEqual:@"none"]?(id)kCFBooleanFalse:(id)kCFBooleanTrue};}
// A bounded recursive walk avoids allocating an autoreleased queue row for
// every registry value. Depth is capped before descent, including cyclic input.
static BOOL JSONSnapshotTree(id value,NSUInteger depth,NSUInteger *visited){
 if(++*visited>131072||depth>32)return NO;
 if([value isKindOfClass:NSDictionary.class]){if([value count]>4096)return NO;for(id key in value){if(![key isKindOfClass:NSString.class]||[key length]>4096||!JSONSnapshotTree(value[key],depth+1,visited))return NO;}return YES;}
 if([value isKindOfClass:NSArray.class]){if([value count]>32768)return NO;for(id child in value)if(!JSONSnapshotTree(child,depth+1,visited))return NO;return YES;}
 if([value isKindOfClass:NSString.class])return[value length]<=262144;
 if([value isKindOfClass:NSNumber.class])return isfinite([value doubleValue]);
 return value==NSNull.null;
}
// Launch composes about twenty registry layers. Each layer is a new dictionary built from the
// previous one, and re-serializing the whole ~1 MB tree for every layer took ~20 s on an
// iPhone 4 and tripped the launch watchdog. Registry-shaped values ({operations, types}) are
// therefore frozen by a direct deep copy that reuses subtrees frozen earlier. Frozen nodes are
// immutable objects created here, so sharing them is safe. Other values keep the JSON round trip.
static CFMutableDictionaryRef Frozen; // frozen container -> @[JSON length, node count]
static const void *FrozenRetain(CFAllocatorRef a,const void *v){(void)a;return CFRetain(v);}
static void FrozenRelease(CFAllocatorRef a,const void *v){(void)a;CFRelease(v);}
static NSArray *FrozenInfo(id v){
 if(![v isKindOfClass:NSDictionary.class]&&![v isKindOfClass:NSArray.class])return nil;
 @synchronized(NSObject.class){return Frozen?[[(id)CFDictionaryGetValue(Frozen,v)retain]autorelease]:nil;}
}
static NSUInteger StringJSONLength(NSString *s){
 NSUInteger n=[s lengthOfBytesUsingEncoding:NSUTF8StringEncoding]+2,count=s.length;unichar buffer[256];
 for(NSUInteger at=0;at<count;at+=256){NSUInteger take=MIN((NSUInteger)256,count-at);[s getCharacters:buffer range:NSMakeRange(at,take)];
  for(NSUInteger i=0;i<take;i++){unichar c=buffer[i];if(c=='"'||c=='\\'||c=='/'||c=='\b'||c=='\f'||c=='\n'||c=='\r'||c=='\t')n++;else if(c<0x20)n+=5;}}
 return n;
}
static id Freeze(id v,NSUInteger depth,NSUInteger *visited,unsigned long long *length,NSMutableArray *made){
 NSArray *info=FrozenInfo(v);
 if(info){*visited+=[info[1]unsignedIntegerValue];*length+=[info[0]unsignedLongLongValue];return *visited>131072?nil:v;}
 if(++*visited>131072||depth>32)return nil;
 if([v isKindOfClass:NSDictionary.class]||[v isKindOfClass:NSArray.class]){
  BOOL dict=[v isKindOfClass:NSDictionary.class];NSUInteger count=[v count];if(count>(dict?4096:32768))return nil;
  NSUInteger start=*visited;unsigned long long size=2+(count?count-1:0);
  id *keys=dict?calloc(count?count:1,sizeof(id)):NULL,*values=calloc(count?count:1,sizeof(id));NSUInteger i=0;id result=nil;BOOL ok=YES;
  for(id item in v){
   if(dict){if(![item isKindOfClass:NSString.class]||[item length]>4096){ok=NO;break;}keys[i]=[[item copy]autorelease];size+=StringJSONLength(item)+1;}
   id child=Freeze(dict?[v objectForKey:item]:item,depth+1,visited,&size,made);if(!child){ok=NO;break;}values[i++]=child;
  }
  if(ok)result=dict?[NSDictionary dictionaryWithObjects:values forKeys:keys count:i]:[NSArray arrayWithObjects:values count:i];
  free(keys);free(values);if(!result)return nil;
  *length+=size;[made addObject:@[result,@[@(size),@(*visited-start+1)]]];return result;
 }
 if([v isKindOfClass:NSString.class]){if([v length]>262144)return nil;*length+=StringJSONLength(v);return[[v copy]autorelease];}
 if([v isKindOfClass:NSNumber.class]){
  if(CFGetTypeID((CFTypeRef)v)==CFBooleanGetTypeID()){*length+=[v boolValue]?4:5;return v;}
  if(!isfinite([v doubleValue]))return nil;*length+=[[v stringValue]length];return v;
 }
 if(v==NSNull.null){*length+=4;return v;}
 return nil;
}
static BOOL RegistryShaped(id v){return[v isKindOfClass:NSDictionary.class]&&[v[@"operations"]isKindOfClass:NSArray.class]&&[v[@"types"]isKindOfClass:NSDictionary.class];}
id OR6APIJSONSnapshot(id value,NSUInteger max){
 @try{
  if(![value isKindOfClass:NSDictionary.class]&&![value isKindOfClass:NSArray.class])return nil;
  NSArray *info=FrozenInfo(value);
  if(info)return[info[0]unsignedLongLongValue]<=max?value:nil;
  if(RegistryShaped(value)){
   NSUInteger visited=0;unsigned long long length=0;NSMutableArray *made=[NSMutableArray array];
   id copy=Freeze(value,0,&visited,&length,made);if(!copy||length>max)return nil;
   @synchronized(NSObject.class){
    if(!Frozen){CFDictionaryKeyCallBacks k={0,FrozenRetain,FrozenRelease,NULL,NULL,NULL};Frozen=CFDictionaryCreateMutable(NULL,0,&k,&kCFTypeDictionaryValueCallBacks);}
    for(NSArray *entry in made)CFDictionarySetValue(Frozen,entry[0],entry[1]);
   }
   return copy;
  }
  NSUInteger visited=0;if(!JSONSnapshotTree(value,0,&visited))return nil;
  NSData*d=[NSJSONSerialization dataWithJSONObject:value options:0 error:NULL];if(!d||d.length>max)return nil;
  return[NSJSONSerialization JSONObjectWithData:d options:0 error:NULL];
 }@catch(NSException*e){(void)e;return nil;}
}
static BOOL IsBool(id v){return[v isKindOfClass:NSNumber.class]&&CFGetTypeID((CFTypeRef)v)==CFBooleanGetTypeID();}
static BOOL IsNumber(id v){return[v isKindOfClass:NSNumber.class]&&!IsBool(v)&&isfinite([v doubleValue]);}
static BOOL Type(id v,NSString*t){
 if([t isEqual:@"null"])return v==NSNull.null;
 if([t isEqual:@"object"])return[v isKindOfClass:NSDictionary.class];
 if([t isEqual:@"array"])return[v isKindOfClass:NSArray.class];
 if([t isEqual:@"string"])return[v isKindOfClass:NSString.class];
 if([t isEqual:@"boolean"])return IsBool(v);
 if([t isEqual:@"number"])return IsNumber(v);
 if([t isEqual:@"integer"])return IsNumber(v)&&floor([v doubleValue])==[v doubleValue];
 return NO;
}
static BOOL Check(id v,NSDictionary*s,NSDictionary*types,NSUInteger depth,NSUInteger*budget){
 if(![s isKindOfClass:NSDictionary.class]||depth>48||!*budget)return NO;--*budget;
 NSSet*allowed=[NSSet setWithArray:@[@"type",@"enum",@"required",@"properties",@"additionalProperties",@"items",@"minLength",@"maxLength",@"minimum",@"maximum",@"minItems",@"maxItems",@"$ref",@"description",@"title"]];
 for(id key in s)if(![key isKindOfClass:NSString.class]||![allowed containsObject:key])return NO;
 if(s[@"$ref"]){NSString*r=s[@"$ref"];if(![r isKindOfClass:NSString.class]||![r hasPrefix:@"#/types/"]||r.length<=8||s.count!=1)return NO;NSString*key=[r substringFromIndex:8];if([key rangeOfString:@"/"].location!=NSNotFound||!types[key])return NO;return Check(v,types[key],types,depth+1,budget);}
 id type=s[@"type"];if(type){NSArray*ts=[type isKindOfClass:NSArray.class]?type:@[type];BOOL match=NO;for(id t in ts){if(![t isKindOfClass:NSString.class])return NO;if(Type(v,t))match=YES;}if(!match)return NO;}
 if(s[@"enum"]){if(![s[@"enum"]isKindOfClass:NSArray.class])return NO;BOOL match=NO;for(id e in s[@"enum"]){if(IsBool(e)!=IsBool(v))continue;if([e isEqual:v])match=YES;}if(!match)return NO;}
 if([v isKindOfClass:NSString.class]){NSUInteger n=[v length];if(s[@"minLength"]&&n<[s[@"minLength"]unsignedIntegerValue])return NO;if(s[@"maxLength"]&&n>[s[@"maxLength"]unsignedIntegerValue])return NO;}
 if(IsNumber(v)){if(s[@"minimum"]&&[v doubleValue]<[s[@"minimum"]doubleValue])return NO;if(s[@"maximum"]&&[v doubleValue]>[s[@"maximum"]doubleValue])return NO;}
 if([v isKindOfClass:NSArray.class]){
  NSUInteger n=[v count];if(n>32768||(s[@"minItems"]&&n<[s[@"minItems"]unsignedIntegerValue])||(s[@"maxItems"]&&n>[s[@"maxItems"]unsignedIntegerValue]))return NO;
  if(s[@"items"])for(id x in v)if(!Check(x,s[@"items"],types,depth+1,budget))return NO;
 }
 if([v isKindOfClass:NSDictionary.class]){
  if(!s[@"properties"]&&!OR6APIJSONSnapshot(v,262144))return NO;
  if([v count]>4096)return NO;NSDictionary*props=s[@"properties"]?:@{};if(![props isKindOfClass:NSDictionary.class])return NO;
  NSArray*req=s[@"required"]?:@[];if(![req isKindOfClass:NSArray.class])return NO;for(id k in req)if(![k isKindOfClass:NSString.class]||!v[k])return NO;
  for(id k in v){if(![k isKindOfClass:NSString.class])return NO;id p=props[k];if(p){if(!Check(v[k],p,types,depth+1,budget))return NO;}else if([s[@"additionalProperties"]isEqual:@NO])return NO;}
 }
 return YES;
}
BOOL OR6APISchemaCheck(id v,NSDictionary*s,NSDictionary*types){@try{NSUInteger budget=131072;return Check(v,s,types,0,&budget);}@catch(NSException*e){(void)e;return NO;}}
