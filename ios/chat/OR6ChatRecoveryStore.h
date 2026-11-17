#import <Foundation/Foundation.h>
// Private, account-scoped current exchanges. No credentials or transport state.
@interface OR6ChatRecoveryStore:NSObject{
 NSString*_directory;
}
- (id)initWithDirectory:(NSString*)directory;
- (BOOL)save:(NSDictionary*)snapshot;
- (NSDictionary*)snapshotForOperation:(NSString*)operation scope:(NSString*)scope;
- (NSDictionary*)latestForScope:(NSString*)scope conversation:(NSString*)identifier;
- (BOOL)clearScope:(NSString*)scope;
@end
