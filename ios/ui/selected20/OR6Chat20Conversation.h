#import "RCReadAloudBar.h"
#import "OR6Chat20Screens.h"
void OR6Chat20SetPlaybackHold(BOOL hold);
@interface OR6Chat20Conversation : NSObject
- (id)initWithCore:(OR6APICore *)core host:(id<OR6Chat7ConversationHost>)host;
- (void)addPlusItems:(NSMutableArray *)items actions:(NSMutableArray *)actions;
- (BOOL)handlePlusAction:(NSString *)action;
- (void)copyMarkdownRow:(NSDictionary *)row;
- (BOOL)performMore:(NSString *)title row:(NSDictionary *)row;
- (BOOL)isSpeakingRow:(NSDictionary *)row;
- (BOOL)canReadRow:(NSDictionary *)row;
- (RCReadAloudBar *)readAloudBar; // one shared strip below the navbar, from S.player
- (NSString *)answerRevisionForRow:(NSDictionary *)row;
- (void)stopPlayback;
// While the app-background hold is on (the coordinator sets it only around its
// own resign-active teardown), a playing or paused read-aloud keeps its strip and
// player; status resynchronises after activation. Otherwise playback stops.
- (void)prepareForBackground;
- (void)detach;
@end
