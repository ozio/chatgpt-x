// RCActionBar — the strip under a finished answer (app.css .actions): copy,
// another variant, read aloud, share, more; "Источники N" and a version pager
// float right. Only the actions the current stage has are present; slots never
// show disabled "soon" buttons.
#import <UIKit/UIKit.h>

typedef enum {
    RCAnswerActionCopy = 1 << 0,
    RCAnswerActionRegenerate = 1 << 1,
    RCAnswerActionSpeak = 1 << 2,
    RCAnswerActionShare = 1 << 3,
    RCAnswerActionMore = 1 << 4,
    RCAnswerActionSources = 1 << 5, // tapped "Источники"
    RCAnswerActionPager = 1 << 6    // tapped the version pager
} RCAnswerAction;

@class RCActionBar;
@protocol RCActionBarDelegate <NSObject>
- (void)actionBar:(RCActionBar *)bar didSelectAction:(RCAnswerAction)action;
@end

@interface RCActionBar : UIView
@property (nonatomic, assign) NSUInteger actions;       // RCAnswerAction mask (Copy…More)
@property (nonatomic, copy) NSArray *sourceIcons; // UIImage, up to three site favicons; no networking in the kit
@property (nonatomic, assign) NSUInteger sourcesCount;  // 0 hides "Источники"
@property (nonatomic, assign) NSUInteger pagerIndex;    // 0-based
@property (nonatomic, assign) NSUInteger pagerCount;    // < 2 hides the pager
@property (nonatomic, assign) BOOL speaking;            // speaker glyph turns jade
@property (nonatomic, assign) id<RCActionBarDelegate> delegate;
@property (nonatomic, readonly) BOOL isEmpty;
+ (CGFloat)height; // 36
@end
