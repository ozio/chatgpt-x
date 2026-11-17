#import "OR6API7DNetwork.h"
#import "../priority8/OR6API8Provider.h"
@interface OR6API7DProvider:NSObject<OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP extension:(NSDictionary*)extension journalDirectory:(NSString*)directory capabilities:(NSSet*)capabilities error:(NSError**)error;
// Trusted composition boundary, same native generator as the existing send chain.
// Bind before executing calls. Empty capabilities disable every project operation.
- (BOOL)bindGeneration:(id<OR6API8Generation>)generation;
// Actual authenticated user/workspace identity, supplied by trusted session host.
// {userId:string,workspaceId:string|null}; never derive it from editable requests.
- (BOOL)bindIdentity:(NSDictionary*)identity context:(NSDictionary*)context;
// Successful native upload records from trusted host, in this exact session.
// Same fields as projects.filesAdd.files; never accept editable UI assertions.
- (BOOL)bindUploadedFiles:(NSArray*)files context:(NSDictionary*)context;
- (void)deactivate;
- (NSDictionary*)diagnostics;
@end
