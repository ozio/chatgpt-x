#import "../../ui/RCVoiceViewController.h"
#import "../../api/OR6APICore.h"
BOOL OR6ChatVoice8Available(OR6APICore *core);
@class OR6ChatVoice8;
@protocol OR6ChatVoice8Host<NSObject>
- (void)voice8:(OR6ChatVoice8 *)voice endedInConversation:(NSString *)conversation;
@end
@interface OR6ChatVoice8 : RCVoiceViewController<RCVoiceViewControllerDelegate>
- (id)initWithCore:(OR6APICore *)core;
@property(nonatomic,assign)id<OR6ChatVoice8Host> host;
- (void)beginInConversation:(NSString *)conversation model:(NSString *)model effort:(NSString *)effort;
- (void)invalidate;
- (NSDictionary *)diagnostics;
@end
