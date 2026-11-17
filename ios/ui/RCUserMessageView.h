// RCUserMessageView — the user's own message (app.css .msg.user): matte jade
// bubble with a swoosh tail (graphite in a temporary chat), honest delivery
// badge ("!" failed → safe retry, "?" unconfirmed → check history) and meta line.
// Long press shows the system Copy menu (UIMenuController), plus "Изменить" if enabled.
#import <UIKit/UIKit.h>
#import "RCLampView.h"

typedef enum {
    RCDeliverySent = 0,  // no badge, no meta
    RCDeliveryQueued,    // busy lamp: waits for the connection, sends once
    RCDeliverySending,   // busy lamp
    RCDeliveryFailed,    // red "!" badge
    RCDeliveryUncertain, // amber "?" badge + warn lamp
    RCDeliveryStopped    // meta only
} RCDeliveryState;

typedef enum { RCBubbleGreen = 0, RCBubbleGraphite } RCBubbleTint;

@class RCUserMessageView;
@protocol RCUserMessageViewDelegate <NSObject>
@optional
- (void)userMessageViewDidTapBadge:(RCUserMessageView *)view;
- (void)userMessageViewDidRequestEdit:(RCUserMessageView *)view;
- (void)userMessageViewDidTapPager:(RCUserMessageView *)view;
- (void)userMessageViewDidRequestCopy:(RCUserMessageView *)view; // else the text goes to the pasteboard
@end

@interface RCUserMessageView : UIView
// Shared red ! / amber ? artwork, also used by concrete file icons.
+ (UIImage *)badgeImage:(BOOL)uncertain;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, assign) RCBubbleTint tint;
@property (nonatomic, assign) RCDeliveryState delivery;
@property (nonatomic, copy) NSString *metaText;    // shown under the bubble when not sent
@property (nonatomic, copy) NSArray *attachments;  // RCComposerAttachment: 74 pt thumbnails above the bubble
@property (nonatomic, assign) NSUInteger pagerIndex, pagerCount; // edited versions "‹ 1 / 2 ›" (stage 8)
@property (nonatomic, assign) BOOL copyMenuEnabled; // long-press callout (stage 9+), default YES
@property (nonatomic, assign) BOOL editMenuEnabled; // adds "Изменить" to the callout
@property (nonatomic, assign) id<RCUserMessageViewDelegate> delegate;
@property (nonatomic, readonly) UIButton *badgeButton;
@property (nonatomic, readonly) UIView *bubbleView;
- (CGFloat)heightForWidth:(CGFloat)width; // full row incl. the 12 pt gap below
@end
