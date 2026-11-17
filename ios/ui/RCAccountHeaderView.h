// RCAccountHeaderView — the «Аккаунт» hero (app.css .hero/.badge-plan): 64 pt round
// avatar (photo, or initials on the jade gradient), name, e-mail and the plan
// badge pill. Engraved text on linen, follows the appearance. Use as a grouped
// table header (set the frame height from -heightForWidth:). With showsDisclosure
// the whole header is a button (UIControlEventTouchUpInside) with a chevron.
#import <UIKit/UIKit.h>

@interface RCAccountHeaderView : UIControl
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *email;
@property (nonatomic, copy) NSString *initials;   // derived from name when nil
@property (nonatomic, retain) UIImage *avatarImage; // photo instead of initials
@property (nonatomic, copy) NSString *planTitle;  // «Plus», «Free»; nil hides the badge
@property (nonatomic, assign) BOOL showsDisclosure;
- (CGFloat)heightForWidth:(CGFloat)width;
+ (NSString *)initialsForName:(NSString *)name;
+ (UIImage *)avatarImageWithInitials:(NSString *)initials diameter:(CGFloat)diameter; // jade gradient disc
@end
