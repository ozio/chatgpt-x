#import "../OR6APICore.h"
// Pinned app-server schemas, independent of ChatGPT web/API credentials.
BOOL OR6CodexText(id value,NSUInteger maximum,BOOL empty);
BOOL OR6CodexID(id value);
BOOL OR6CodexPath(id value);
BOOL OR6CodexKeys(id value,NSArray *required,NSArray *optional);
NSError *OR6CodexError(NSString *code,BOOL possible);
@interface OR6CodexProtocol:NSObject {
 NSDictionary *_contracts;
}
- (id)initWithContracts:(NSDictionary*)contracts error:(NSError**)error;
- (BOOL)validate:(id)value group:(NSString*)group method:(NSString*)method direction:(NSString*)direction;
- (BOOL)supports:(NSString*)group method:(NSString*)method;
- (NSDictionary*)features;
- (NSDictionary*)features8;
- (NSDictionary*)features7;
@end
