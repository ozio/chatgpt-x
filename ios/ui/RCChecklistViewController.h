// RCChecklistViewController — sectioned grouped checklist (iOS 6 settings list with
// the jade check, kit.css .cell .check). One or more sections, each with an optional
// engraved header and rows: title, optional second line, checked. An optional footer
// note sits under the last section. Several sections may each carry their own check
// (e.g. model family / mode / thinking effort).
//
// States: idle; busy (stock spinner in the navigation item, rows not enabled, taps
// ignored). The check never moves by itself: a tap asks -checklist:shouldSelectRow:
// inSection: (optional), then reports -checklist:didSelectRow:inSection:; the caller
// sets new `sections` when the choice is really applied.
//
// Light/dark (RCThemeAppearanceDidChangeNotification), the five text sizes
// (RCThemeTextSizeDidChangeNotification), VoiceOver (headers, button + selected /
// not enabled traits, second line as the value). The navigation bar is the caller's.
#import <UIKit/UIKit.h>

@interface RCChecklistRow : NSObject
+ (RCChecklistRow *)rowWithTitle:(NSString *)title detail:(NSString *)detail checked:(BOOL)checked;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *detail;      // second line (nil: one line)
@property (nonatomic, assign) BOOL checked;
@property (nonatomic, copy) NSString *identifier;  // accessibilityIdentifier of the row
@end

@interface RCChecklistSection : NSObject
+ (RCChecklistSection *)sectionWithTitle:(NSString *)title rows:(NSArray *)rows;
@property (nonatomic, copy) NSString *title;       // engraved header (nil: none)
@property (nonatomic, copy) NSArray *rows;         // RCChecklistRow
@end

@class RCChecklistViewController;
@protocol RCChecklistDelegate <NSObject>
- (void)checklist:(RCChecklistViewController *)checklist didSelectRow:(NSUInteger)row inSection:(NSUInteger)section;
@optional
- (BOOL)checklist:(RCChecklistViewController *)checklist shouldSelectRow:(NSUInteger)row inSection:(NSUInteger)section;
@end

@interface RCChecklistViewController : UITableViewController
@property (nonatomic, assign) id<RCChecklistDelegate> delegate;
@property (nonatomic, copy) NSArray *sections;              // RCChecklistSection; setting reloads
@property (nonatomic, copy) NSString *footerText;           // note under the last section (nil: none)
@property (nonatomic, assign) BOOL busy;
@property (nonatomic, copy) NSString *busyAccessibilityLabel; // spinner's VoiceOver label (default «Подождите…»)
@end
