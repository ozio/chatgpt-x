#import "OR6CodexStore.h"
#import "OR6CodexTranscript.h"
// All methods and transport callbacks are main-thread. Transport must only ever
// invoke receiver after verified channel setup; send NO may still be ambiguous.
@protocol OR6CodexTransport<NSObject>
- (void)open:(void(^)(NSDictionary*))receiver closed:(void(^)(NSError*))closed ready:(void(^)(NSError*))ready;
- (BOOL)send:(NSDictionary*)message error:(NSError**)error;
- (void)close;
@end
@interface OR6CodexSession:NSObject {
 id<OR6CodexTransport> _transport;
 OR6CodexProtocol *_protocol;
 OR6CodexStore *_store;
 OR6CodexTranscript *_transcript;
 NSDictionary *_context;
 NSMutableDictionary *_pending,*_server;
 NSMutableSet *_seen;
 OR6APIEvent _event;
 NSString *_state;
 NSUInteger _epoch,_counter;
 BOOL _closing,_deactivated;
 NSMutableDictionary *_models,*_settings;
 NSMutableSet *_modes;
 NSMutableDictionary *_mcpServers;
}
- (id)initWithTransport:(id<OR6CodexTransport>)transport contracts:(NSDictionary*)contracts context:(NSDictionary*)context directory:(NSString*)directory error:(NSError**)error;
- (void)connect:(OR6APIReply)completion;
- (void)setEventHandler:(OR6APIEvent)event;
- (id<OR6APITask>)request:(NSString*)method parameters:(NSDictionary*)parameters operationID:(NSString*)operationID completion:(OR6APIReply)completion;
- (BOOL)answer:(NSString*)token response:(NSDictionary*)response operationID:(NSString*)identifier error:(NSError**)error;
- (BOOL)matchesContext:(NSDictionary*)context;
- (NSDictionary*)status;
- (NSDictionary*)model:(NSString*)model;
- (BOOL)hasMode:(NSString*)mode;
- (BOOL)hasMCPServer:(NSString*)server thread:(NSString*)thread;
- (NSDictionary*)settings:(NSString*)thread;
- (NSDictionary*)journal;
- (NSDictionary*)transcript:(NSString*)thread;
- (void)disconnect;
- (void)deactivate;
// Protected admission hooks. The hosted subclass uses its trusted session owner,
// never a synthetic account/read response or a caller-supplied account receipt.
+ (Class)protocolClass;
- (BOOL)contextIsCurrent;
- (void)verifyAdmission:(OR6APIReply)completion;
@end
