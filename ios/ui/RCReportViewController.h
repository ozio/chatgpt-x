// RCReportViewController — «Отчёт» of a deep research task (prototype, stage 7): an
// orange research tile with the title and the meta line («Готово · 12 мин ·
// 18 источников · 9 стр.»), the report body as RCMarkdownView on an answer card,
// the numbered sources (RCSourceRowView) and footer pills «Сохранить PDF» /
// «Поделиться». Follows text size and appearance. Actions go to the delegate.
#import <UIKit/UIKit.h>
#import "RCSourcesSheet.h"

@class RCReportViewController;
@protocol RCReportViewControllerDelegate <NSObject>
@optional
- (void)report:(RCReportViewController *)report didSelectSource:(RCSourceItem *)source;
- (void)reportDidTapSavePDF:(RCReportViewController *)report;
- (void)reportDidTapShare:(RCReportViewController *)report;
@end

@interface RCReportViewController : UIViewController
- (id)initWithTitle:(NSString *)title markdown:(NSString *)markdown;
@property (nonatomic, copy) NSString *reportTitle, *meta, *markdown;
@property (nonatomic, copy) NSArray *sources;          // RCSourceItem
@property (nonatomic, assign) BOOL savePDFAvailable;   // research export (stage 7)
@property (nonatomic, assign) BOOL shareAvailable;
@property (nonatomic, assign) id<RCReportViewControllerDelegate> delegate;
@property (nonatomic, readonly) UIScrollView *scrollView;
@end
