#import <UIKit/UIKit.h>
// Public icons only. No web adapter, session cookies or authenticated request.
extern NSString *const OR6ChatFaviconDidLoadNotification;
UIImage *OR6ChatFavicon(NSString *URLString, BOOL load);
NSArray *OR6ChatSourceIcons(NSArray *sources, BOOL load);
