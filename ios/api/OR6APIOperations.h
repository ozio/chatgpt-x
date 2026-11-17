#import <Foundation/Foundation.h>
@interface OR6APIOperations:NSObject{NSString *_directory;int _lockfd;}
- (id)initWithDirectory:(NSString *)directory error:(NSError **)error;
- (NSDictionary *)record:(NSString *)identifier scope:(NSString *)scope error:(NSError **)error;
- (BOOL)reserve:(NSString *)identifier command:(NSString *)command request:(NSDictionary *)request scope:(NSString *)scope error:(NSError **)error;
- (BOOL)finish:(NSString *)identifier scope:(NSString *)scope state:(NSString *)state metadata:(NSDictionary *)metadata error:(NSError **)error;
@end
