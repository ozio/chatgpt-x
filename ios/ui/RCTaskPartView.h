// RCTaskPartView — long-running or gated work in an answer (app.css .research):
// tile + title + status line, optional progress, rows with status lamps (deep
// research steps) or key/value rows (app action approval), footer pills.
#import "RCPartView.h"
#import "RCGlyph.h"
#import "RCLampView.h"
#import "RCButton.h"

@interface RCTaskRow : NSObject
+ (id)stepWithText:(NSString *)text lamp:(RCLampState)lamp;   // lamp Off: no lamp
+ (id)paramWithKey:(NSString *)key value:(NSString *)value;
@property (nonatomic, copy) NSString *text, *key;
@property (nonatomic, assign) RCLampState lamp;
@end

@interface RCTaskPartView : RCPartView
- (id)initWithGlyph:(NSString *)glyph tile:(RCTileColor)tile;
@property (nonatomic, copy) NSString *title, *subtitle;
@property (nonatomic, assign) CGFloat progress;      // < 0 hides the bar
@property (nonatomic, copy) NSArray *rows;           // RCTaskRow
@property (nonatomic, copy) NSArray *footerButtons;  // RCButton pills, left to right
@end
