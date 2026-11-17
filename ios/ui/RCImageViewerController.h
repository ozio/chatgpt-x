// RCImageViewerController — image lightbox (S.lightbox in design/uxui/js/s-sheets.js,
// app.css .lightbox) in the iOS 6 Photos idiom: black backdrop, the image fitted under
// black translucent bars, zoom/pan (double tap zooms), a single tap fades the bars and
// status bar. Navigation bar: «Готово» on the left, one Action button on the right that
// opens a black translucent action sheet («Сохранить в «Фото»», «Поделиться…»). The
// prompt is a caption band below the navigation bar. A bottom toolbar appears only for
// editing tools («Изменить»). Actions go to the delegate; nothing is saved here.
// Feedback for an action (saving, saved, failure) belongs in `viewer.view`: the
// presenting screen is off-screen while the viewer is up. -showHUDText:kind:seconds:
// does that and keeps a busy HUD so -finishHUDWithText: can resolve it.
#import <UIKit/UIKit.h>
#import "RCHUD.h"

@class RCImageViewerController;
@protocol RCImageViewerControllerDelegate <NSObject>
@optional
- (void)imageViewerDidTapSave:(RCImageViewerController *)viewer;
- (void)imageViewerDidTapShare:(RCImageViewerController *)viewer;
- (void)imageViewerDidTapEdit:(RCImageViewerController *)viewer;
- (void)imageViewerDidFinish:(RCImageViewerController *)viewer; // without it the viewer dismisses itself
@end

@interface RCImageViewerController : UIViewController <UIScrollViewDelegate>
- (id)initWithImage:(UIImage *)image caption:(NSString *)caption;
@property (nonatomic, retain) UIImage *image;
@property (nonatomic, copy) NSString *caption;
@property (nonatomic, assign) BOOL saveAvailable, shareAvailable, editAvailable; // save/share YES by default
@property (nonatomic, assign) BOOL barsHidden;
@property (nonatomic, assign) id<RCImageViewerControllerDelegate> delegate;
- (void)setBarsHidden:(BOOL)hidden animated:(BOOL)animated;
// HUD centred over the image. Busy stays (and replaces an earlier busy HUD) until
// -finishHUDWithText: (check, then hides) or -hideHUD.
- (RCHUD *)showHUDText:(NSString *)text kind:(RCHUDKind)kind seconds:(NSTimeInterval)seconds;
- (void)finishHUDWithText:(NSString *)text;
- (void)hideHUD;
+ (UINavigationController *)navigationControllerWithImage:(UIImage *)image caption:(NSString *)caption delegate:(id<RCImageViewerControllerDelegate>)delegate;
@end
