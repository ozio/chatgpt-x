#import "OR6ChatCodexModel.h"
#import "../../ui/RCComposerView.h"
@class OR6ChatCodexImages,RCActivitySheet;
@protocol OR6ChatCodexImagesDelegate<NSObject>
- (void)codexImagesChanged:(OR6ChatCodexImages*)images;
@end
// Ephemeral preparation; owner is the presenting controller, delegate is assign.
// Tokens/bytes never cross account/connection epochs or enter diagnostics.
@interface OR6ChatCodexImages:NSObject<UIImagePickerControllerDelegate,UINavigationControllerDelegate>{
 OR6ChatCodexModel *_model;UIViewController *_owner;id<OR6ChatCodexImagesDelegate>_delegate;
 NSMutableArray *_tokens,*_attachments;NSString *_note;NSUInteger _epoch;BOOL _invalid;NSArray *_sources;RCActivitySheet *_sheet;UIImagePickerController *_picker;
}
- (id)initWithBackend:(id<OR6ChatCodexBackend>)backend owner:(UIViewController*)owner;
@property(nonatomic,assign)id<OR6ChatCodexImagesDelegate>delegate;
@property(nonatomic,readonly)NSArray*tokens,*attachments;
@property(nonatomic,readonly)NSString*note;
@property(nonatomic,readonly)BOOL busy;
- (void)choose;
- (void)remove:(NSUInteger)index;
- (void)consume;
- (void)invalidate;
#ifdef OR6_CHAT_ACCEPTANCE
- (void)stageImage:(UIImage*)image;
#endif
@end
