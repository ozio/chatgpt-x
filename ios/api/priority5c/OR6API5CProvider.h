#import "../priority7/OR6API7Network.h"
@interface OR6API5CProvider:NSObject<OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP extension:(NSDictionary*)extension journalDirectory:(NSString*)directory capabilities:(NSSet*)capabilities error:(NSError**)error;
// Trusted native message observer. The returned opaque block ID carries the
// observed conversation/message/reference and library ownership; public inputs
// cannot supply or replace those identities. Normalized fields mirror original
// FlashcardWidget and LanguageLearningBlock stored-property descriptors.
- (NSString*)observeStudyBlock:(NSDictionary*)block conversationId:(NSString*)conversationId messageId:(NSString*)messageId referenceId:(NSString*)referenceId context:(NSDictionary*)context error:(NSError**)error;
- (NSString*)observeLanguageBlock:(NSDictionary*)block conversationId:(NSString*)conversationId messageId:(NSString*)messageId referenceId:(NSString*)referenceId context:(NSDictionary*)context error:(NSError**)error;
- (NSString*)observeDeferredImage:(NSDictionary*)metadata conversationId:(NSString*)conversationId messageId:(NSString*)messageId context:(NSDictionary*)context error:(NSError**)error;
- (BOOL)observeLanguageSave:(NSDictionary*)widgetState blockId:(NSString*)blockId operationId:(NSString*)operationId context:(NSDictionary*)context error:(NSError**)error;
- (BOOL)observeStartScreenOptions:(NSArray*)options context:(NSDictionary*)context error:(NSError**)error;
- (void)deactivate;
- (NSDictionary*)diagnostics;
@end
