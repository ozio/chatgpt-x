#import <UIKit/UIKit.h>
#import "OR6Chat9Dictation.h"
@protocol OR6Chat9TranscriptHost<NSObject>
- (BOOL)insertDictationText:(OR6Chat9Dictation *)dictation;
@end
@interface OR6Chat9DictationController:UIViewController<OR6Chat9DictationDelegate,UITextViewDelegate>
- (id)initWithModel:(OR6Chat9Dictation *)model host:(id<OR6Chat9TranscriptHost>)host;
- (void)prepareForBackground;
- (void)setMaximumCaptureDurationMS:(NSUInteger)maximum;
@end
