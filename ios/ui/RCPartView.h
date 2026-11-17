// RCPartView — base for rich answer parts (app.css .imgcard/.support/.mailcard/
// .clarify/.filecard): 8 pt rounded box, optional dashed border, gradient fill,
// role-coloured labels that follow the appearance, hairlines and a footer strip.
// Subclasses implement -layoutForWidth:apply: and optionally -drawContent:.
#import <UIKit/UIKit.h>

typedef enum { RCPartTextTitle = 0, RCPartTextBody, RCPartTextSecondary, RCPartTextLink } RCPartTextRole;

@class RCPartView;
@protocol RCPartViewDelegate <NSObject>
@optional
- (void)partViewDidChangeHeight:(RCPartView *)part; // relayout the answer
@end

@interface RCPartView : UIView
@property (nonatomic, assign) BOOL dashed;
@property (nonatomic, assign) BOOL plainFill;           // flat fill instead of the gradient
@property (nonatomic, assign) unsigned fillTop, fillBottom; // light-appearance fill (hex)
@property (nonatomic, assign) id<RCPartViewDelegate> delegate;
- (UILabel *)labelWithRole:(RCPartTextRole)role font:(UIFont *)font;
- (CGFloat)layoutForWidth:(CGFloat)width apply:(BOOL)apply; // subclass
- (CGFloat)heightForWidth:(CGFloat)width;
- (void)applyAppearance;                                  // subclass may extend (call super)
- (void)drawContent:(CGContextRef)ctx;                    // subclass hook, inside the box clip
- (void)drawHairlineAtY:(CGFloat)y context:(CGContextRef)ctx;
- (void)drawFooterFromY:(CGFloat)y context:(CGContextRef)ctx;
- (void)notifyHeightChange;
+ (UIColor *)colorForRole:(RCPartTextRole)role;
@end
