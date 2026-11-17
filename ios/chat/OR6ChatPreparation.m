#import "OR6ChatPreparation.h"
#import "OR6ChatNativePolicy.h"
#include <math.h>
static NSDictionary*Context(id c){
 if(![c isKindOfClass:NSDictionary.class]||![c[@"key"]isKindOfClass:NSString.class]||![c[@"key"]length]||[c[@"key"]length]>1024||![c[@"generation"]isKindOfClass:NSNumber.class]||[c[@"generation"]doubleValue]<0)return nil;
 return @{@"key":c[@"key"],@"generation":c[@"generation"]};
}
static BOOL Token(id v){return[v isKindOfClass:NSString.class]&&[v length]&&[v length]<=32768&&[v rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location==NSNotFound;}
static NSDictionary*Failed(NSString*code){return @{@"phase":@"failed",@"issue":code};}
@implementation OR6ChatPreparationState{
 NSDictionary*_context;NSString*_nonce,*_lastNonce;NSUInteger _stage;double _began;
}
- (BOOL)matchesContext:(NSDictionary*)context{return _context&&[_context isEqual:Context(context)];}
- (BOOL)bindContext:(NSDictionary*)context{
 NSDictionary*c=Context(context);if(!c)return NO;if([self matchesContext:c])return YES;
 [self cancel];[_context release];_context=[c copy];return YES;
}
- (BOOL)beginAttempt:(NSString*)nonce context:(NSDictionary*)context now:(double)now{
 if(![self matchesContext:context]||!OR6CNUUID(nonce)||[nonce isEqual:_lastNonce]||(_stage>0&&_stage<4)||!isfinite(now))return NO;
 [_nonce release];_nonce=[nonce copy];[_lastNonce release];_lastNonce=[nonce copy];_began=now;_stage=1;return YES;
}
- (BOOL)current:(NSString*)nonce context:(NSDictionary*)context now:(double)now{
 return[self matchesContext:context]&&[_nonce isEqual:nonce]&&_stage>0&&_stage<4&&isfinite(now)&&now>=_began&&now-_began<=240;
}
- (NSDictionary*)consume:(id)raw attempt:(NSString*)nonce context:(NSDictionary*)context now:(double)now{
 if(![self current:nonce context:context now:now])return Failed(@"stale_context");
 if(![raw isKindOfClass:NSDictionary.class]||![raw[@"nonce"]isEqual:nonce]){[self cancel];return Failed(@"invalid_response");}
 if(![raw[@"phase"]isKindOfClass:NSString.class]||(raw[@"chatBootstrapResources"]&&![raw[@"chatBootstrapResources"]isKindOfClass:NSNumber.class])){[self cancel];return Failed(@"invalid_response");}
 if([raw[@"chatBootstrapResources"]unsignedIntegerValue]||[raw[@"phase"]isEqual:@"failed"]){[self cancel];return Failed(@"service_challenge");}
 NSString*phase=raw[@"phase"];NSMutableDictionary*r=[NSMutableDictionary dictionaryWithObject:phase?:@""forKey:@"phase"];
 for(NSString*k in @[@"resourceCount",@"chatBootstrapResources",@"computeMs",@"proofRequired",@"vmRequired",@"prepareKeyMs",@"requirementsWaitMs",@"readyWaitMs"])if([raw[k]isKindOfClass:NSNumber.class])r[k]=raw[k];
 if([phase isEqual:@"requirements"]&&_stage==1&&Token(raw[@"p"])) {_stage=2;r[@"p"]=raw[@"p"];return r;}
 if([phase isEqual:@"ready"]&&_stage==3){NSDictionary*h=OR6CNHeaders(raw[@"headers"]);if(h){_stage=4;r[@"headers"]=h;return r;}}
 if((_stage==1&&[phase isEqual:@"starting"])||(_stage==2&&[phase isEqual:@"awaiting_requirements"])||(_stage==3&&[phase isEqual:@"computing"]))return r;
 [self cancel];return Failed(@"invalid_response");
}
- (BOOL)maySupply:(NSDictionary*)r attempt:(NSString*)nonce context:(NSDictionary*)context now:(double)now{
 return[self current:nonce context:context now:now]&&_stage==2&&[r isKindOfClass:NSDictionary.class]&&![r[@"force_login"]isEqual:@YES]&&(Token(r[@"token"])||Token(r[@"prepare_token"]))&&[r[@"proofofwork"]isKindOfClass:NSDictionary.class]&&[r[@"turnstile"]isKindOfClass:NSDictionary.class]&&[@[@YES,@NO]containsObject:r[@"proofofwork"][@"required"]]&&[@[@YES,@NO]containsObject:r[@"turnstile"][@"required"]];
}
- (void)didSupply{if(_stage==2)_stage=3;}
- (void)cancel{_stage=0;[_nonce release];_nonce=nil;}
- (void)dealloc{[_context release];[_nonce release];[_lastNonce release];[super dealloc];}
@end
