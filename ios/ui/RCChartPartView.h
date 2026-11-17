// RCChartPartView — data-analysis chart in an answer (app.css .chart): title,
// bars with values, category labels, and "Show analysis code ›" that reveals
// the analysis code as an RCCodeBlockView.
#import "RCPartView.h"
#import "RCCodeBlockView.h"

@interface RCChartPartView : RCPartView
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSArray *values;   // [[@"Jan", @1.2], …]
@property (nonatomic, copy) NSString *code;    // nil hides the link
@property (nonatomic, copy) NSString *codeLanguage;
@property (nonatomic, assign) BOOL codeCopyEnabled;
@end
