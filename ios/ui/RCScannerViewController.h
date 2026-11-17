// RCScannerViewController — document scanner (app.css .scanner, stage 6): dark bar
// «Сканирование» with Отмена / Готово (save as PDF), a viewfinder (the caller's camera preview,
// or a dim placeholder with a paper sheet) with green corner guides, a strip of
// page thumbnails (tap selects), the white shutter and «N стр.». The caller owns
// the camera and the pages; this screen reports taps.
#import <UIKit/UIKit.h>

@class RCScannerViewController;
@protocol RCScannerViewControllerDelegate <NSObject>
- (void)scannerDidTapShutter:(RCScannerViewController *)scanner;
- (void)scannerDidCancel:(RCScannerViewController *)scanner;
- (void)scannerDidSave:(RCScannerViewController *)scanner;
@optional
- (void)scanner:(RCScannerViewController *)scanner didSelectPageAtIndex:(NSUInteger)index; // page menu
@end

@interface RCScannerViewController : UIViewController
@property (nonatomic, retain) UIView *previewView;  // camera preview; nil shows the placeholder
@property (nonatomic, copy) NSArray *pages;         // UIImage thumbnails (NSNull: blank page)
@property (nonatomic, assign) NSInteger selectedPage; // -1: none
@property (nonatomic, assign) BOOL shutterEnabled;  // default YES
// Automatic code reading reuses the existing viewfinder and Cancel chrome.
// The app owns decoding; page thumbnails, shutter and Done are hidden.
@property (nonatomic, assign) BOOL readingCode;
@property (nonatomic, assign) id<RCScannerViewControllerDelegate> delegate;
+ (UINavigationController *)navigationControllerWithDelegate:(id<RCScannerViewControllerDelegate>)delegate;
@end
