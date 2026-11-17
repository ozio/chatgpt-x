#import "OR6CodexProtocol.h"
#import <CoreFoundation/CoreFoundation.h>
#include <math.h>
BOOL OR6CodexText(id v,NSUInteger n,BOOL empty){return[v isKindOfClass:NSString.class]&&[v length]<=n&&(empty||[v length]>0);}
BOOL OR6CodexID(id v){return OR6CodexText(v,256,NO)&&[v rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location==NSNotFound;}
BOOL OR6CodexPath(id v){if(!OR6CodexText(v,4096,NO)||![v hasPrefix:@"/"]||[v rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound)return NO;for(NSString*s in[v componentsSeparatedByString:@"/"])if([s isEqual:@".."]||[s isEqual:@"."])return NO;return YES;}
BOOL OR6CodexKeys(id v,NSArray*r,NSArray*o){if(![v isKindOfClass:NSDictionary.class])return NO;for(id k in r)if(!v[k])return NO;for(id k in v)if(![r containsObject:k]&&![o containsObject:k])return NO;return YES;}
NSError *OR6CodexError(NSString*c,BOOL p){return OR6APIError(c,p?@"possible":@"none");}
static BOOL Type(id v,NSString*t){BOOL num=[v isKindOfClass:NSNumber.class],b=num&&CFGetTypeID((CFTypeRef)v)==CFBooleanGetTypeID();if([t isEqual:@"null"])return v==NSNull.null;if([t isEqual:@"object"])return[v isKindOfClass:NSDictionary.class];if([t isEqual:@"array"])return[v isKindOfClass:NSArray.class];if([t isEqual:@"string"])return[v isKindOfClass:NSString.class];if([t isEqual:@"boolean"])return b;if([t isEqual:@"number"])return num&&!b&&isfinite([v doubleValue]);if([t isEqual:@"integer"])return num&&!b&&isfinite([v doubleValue])&&floor([v doubleValue])==[v doubleValue];return NO;}
static BOOL Check(id v,id schema,NSDictionary*defs,NSUInteger depth,NSUInteger*budget){
 if(depth>64||!*budget)return NO;--*budget;if([schema isKindOfClass:NSNumber.class])return[schema boolValue];if(![schema isKindOfClass:NSDictionary.class])return NO;NSDictionary*s=schema;
 if(s[@"$ref"]){NSString*r=s[@"$ref"];if(![r hasPrefix:@"#/definitions/"])return NO;id ref=defs[[r substringFromIndex:14]];if(!ref||!Check(v,ref,defs,depth+1,budget))return NO;}
 for(NSString*k in @[@"anyOf",@"oneOf",@"allOf"]){NSArray*choices=s[k];if(!choices)continue;NSUInteger count=0;for(id x in choices)if(Check(v,x,defs,depth+1,budget))count++;if(([k isEqual:@"anyOf"]&&!count)||([k isEqual:@"oneOf"]&&count!=1)||([k isEqual:@"allOf"]&&count!=choices.count))return NO;}
 if(s[@"type"]){NSArray*a=[s[@"type"]isKindOfClass:NSArray.class]?s[@"type"]:@[s[@"type"]];BOOL match=NO;for(NSString*t in a)if(Type(v,t))match=YES;if(!match)return NO;}
 if(s[@"enum"]){BOOL match=NO;for(id x in s[@"enum"]){if(Type(v,@"boolean")!=Type(x,@"boolean"))continue;if([x isEqual:v])match=YES;}if(!match)return NO;}
 if([v isKindOfClass:NSString.class]){NSUInteger n=[v length];if((s[@"minLength"]&&n<[s[@"minLength"]unsignedIntegerValue])||(s[@"maxLength"]&&n>[s[@"maxLength"]unsignedIntegerValue]))return NO;}
 if(Type(v,@"number")){if((s[@"minimum"]&&[v doubleValue]<[s[@"minimum"]doubleValue])||(s[@"maximum"]&&[v doubleValue]>[s[@"maximum"]doubleValue]))return NO;}
 if([v isKindOfClass:NSArray.class]){NSUInteger n=[v count];if(n>4096||(s[@"minItems"]&&n<[s[@"minItems"]unsignedIntegerValue])||(s[@"maxItems"]&&n>[s[@"maxItems"]unsignedIntegerValue]))return NO;if(s[@"items"])for(id x in v)if(!Check(x,s[@"items"],defs,depth+1,budget))return NO;}
 if([v isKindOfClass:NSDictionary.class]){if([v count]>4096)return NO;for(id k in s[@"required"])if(!v[k])return NO;for(id k in v){id child=s[@"properties"][k]?:s[@"additionalProperties"];if(child&&!Check(v[k],child,defs,depth+1,budget))return NO;}}
 return YES;
}
@implementation OR6CodexProtocol
- (id)initWithContracts:(NSDictionary*)d error:(NSError**)error{if((self=[super init])){d=OR6APIJSONSnapshot(d,4*1024*1024);if(![d isKindOfClass:NSDictionary.class]||![d[@"protocolVersion"]isEqual:@"0.163.0"]||![d[@"definitions"]isKindOfClass:NSDictionary.class]||[d[@"features"]count]!=11){if(error)*error=OR6CodexError(@"schema_mismatch",NO);[self release];return nil;}_contracts=[d retain];}return self;}
- (BOOL)validate:(id)v group:(NSString*)g method:(NSString*)m direction:(NSString*)dir{@try{id s=_contracts[g][m];if(dir)s=s[dir];NSUInteger budget=262144;return s&&Check(v,s,_contracts[@"definitions"],0,&budget);}@catch(NSException*e){(void)e;return NO;}}
- (BOOL)supports:(NSString*)g method:(NSString*)m{return _contracts[g][m]!=nil;}
- (NSDictionary*)features7{return _contracts[@"features7"]?:@{};}
- (NSDictionary*)features8{return _contracts[@"features8"]?:@{};}
- (NSDictionary*)features{return _contracts[@"features"];}
- (void)dealloc{[_contracts release];[super dealloc];}
@end
