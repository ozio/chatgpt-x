// Gallery pages: each shows one component family in all its states. The stage
// switcher (10…6) mirrors the prototype's staged rollout: a slot appears only from
// the stage whose feature needs it, and the layout of other slots never moves.
#import <UIKit/UIKit.h>

extern NSString *const RCGalleryStageDidChangeNotification;
int RCGalleryStage(void);            // 10 (core) … 6 (everything)
void RCGallerySetStage(int stage);
BOOL RCGalleryOn(int usefulness);    // feature with this usefulness is present at the current stage

// Scrolling page on light linen; subclasses implement -build and call the add* helpers.
@interface RCGalleryPage : UIViewController
@property (nonatomic, readonly) UIScrollView *scrollView;
- (void)build;                                 // rebuilt on appear and on stage/text-size change
- (void)rebuild;
- (void)addCaption:(NSString *)caption;        // engraved group header
- (void)addNote:(NSString *)note;              // small engraved note
- (void)addView:(UIView *)view;                // full width; height from -heightForWidth: or frame
- (void)addView:(UIView *)view height:(CGFloat)height;
- (void)addSpace:(CGFloat)space;
- (void)addInsetView:(UIView *)view height:(CGFloat)height; // 10 pt side insets
- (void)relayout;                              // after a component changed height
@end

void RCGalleryAlert(NSString *title, NSString *message);
void RCGalleryHUD(UIView *anyView, NSString *text);

@interface RCGalleryThemePage : RCGalleryPage @end
@interface RCGalleryStockPage : UITableViewController @end
@interface RCGalleryTitlePage : RCGalleryPage @end
@interface RCGalleryBannerPage : RCGalleryPage @end
@interface RCGalleryUserMessagePage : RCGalleryPage @end
@interface RCGalleryAnswerPage : RCGalleryPage @end
@interface RCGalleryPartsPage : RCGalleryPage @end
@interface RCGalleryComposerPage : RCGalleryPage @end
@interface RCGalleryActivityPage : RCGalleryPage @end
@interface RCGalleryDrawerPage : RCGalleryPage @end
@interface RCGalleryGlyphPage : RCGalleryPage @end
@interface RCGalleryMarkdownPage : RCGalleryPage @end
@interface RCGalleryEmptyPage : RCGalleryPage @end
@interface RCGalleryHUDPage : RCGalleryPage @end
// Shell screens and small elements (RCGalleryDemos3.m)
@interface RCGalleryControlsPage : RCGalleryPage @end
@interface RCGallerySelectPage : RCGalleryPage @end
@interface RCGalleryWelcomePage : RCGalleryPage @end
@interface RCGalleryVoicePage : RCGalleryPage @end
@interface RCGalleryPINPage : RCGalleryPage @end
@interface RCGalleryMediaPage : RCGalleryPage @end
@interface RCGalleryGridsPage : RCGalleryPage @end
@interface RCGalleryTranslatePage : RCGalleryPage @end
@interface RCGallerySheetsPage : RCGalleryPage @end
@interface RCGalleryReportPage : RCGalleryPage @end
