// Component gallery entry point. Compiled only with OR6_UI_GALLERY=1 (RCKit.mk);
// production builds contain none of this code.
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif
// Applies RCTheme appearance and returns an autoreleased navigation controller
// rooted at the gallery list. Offline only: no network, no account, no session.
UIViewController *RCGalleryCreateRootController(void);
// Development route: chatgptxkit://page/<Name>[?stage=6…10][&size=0…4][&open=1|2][&y=pt][&dark=0|1]
// pushes RCGallery<Name>Page on the root returned above (open=1 also opens the
// page's sheet/drawer demo, open=2 with the drawer slid out, open=3…9 a page's variant (shell pages); y scrolls the page). Used for on-device screenshots without touch input.
BOOL RCGalleryOpenURL(UIViewController *root, NSURL *url);
#ifdef __cplusplus
}
#endif
