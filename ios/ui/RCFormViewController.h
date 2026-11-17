// RCFormViewController — grouped iOS 6 settings form (kit.css .group/.cell, prototype
// s-account.js «Персонализация», «Память», «Конфиденциальность»…). Sections with an
// engraved header and a centred engraved footer; an optional note above the first
// section. Rows:
//   Value     title (+ second line), right value, optional 29 pt tile, lamp, disclosure, spinner
//   Switch    title (+ second line) with a jade UISwitch; disabled switches stay readable
//   Button    centred link-coloured or destructive red title
//   Text      single-line field with placeholder (and length limit)
//   LongText  multi-line field (line breaks kept, iOS 6 attributed setter), 4 lines high
//   Note      read-only multi-line text (state that cannot be changed here)
//   Check     title (+ second line) with the jade check
// States: busy (stock spinner in the navigation item, taps ignored, rows not enabled).
// The form never changes values by itself except what the user typed/toggled; it reports
// every change to the delegate and the caller sets new `sections` when the change is real
// (a refused switch is put back by the caller). Light/dark, five text sizes, VoiceOver
// (headers, button / selected / not enabled traits, values), accessibilityIdentifier per row.
#import <UIKit/UIKit.h>
#import "RCGlyph.h"
#import "RCLampView.h"
typedef enum { RCFormRowValue = 0, RCFormRowSwitch, RCFormRowButton, RCFormRowText, RCFormRowLongText, RCFormRowNote, RCFormRowCheck } RCFormRowKind;
@interface RCFormRow : NSObject
+ (RCFormRow *)rowWithKind:(RCFormRowKind)kind title:(NSString *)title;
@property (nonatomic, assign) RCFormRowKind kind;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;    // second line (Value, Switch, Check); the text of a Note
@property (nonatomic, copy) NSString *value;       // right value (Value)
@property (nonatomic, copy) NSString *glyph;       // 29 pt tile (Value, Switch)
@property (nonatomic, assign) RCTileColor tile;
@property (nonatomic, assign) BOOL showsLamp;      // status lamp before the value (Value)
@property (nonatomic, assign) RCLampState lamp;
@property (nonatomic, assign) BOOL on;             // Switch
@property (nonatomic, assign) BOOL checked;        // Check
@property (nonatomic, assign) BOOL enabled;        // default YES
@property (nonatomic, assign) BOOL destructive;    // Button: red
@property (nonatomic, assign) BOOL disclosure;     // Value: chevron
@property (nonatomic, assign) BOOL busy;           // Value/Button: spinner instead of the value
@property (nonatomic, copy) NSString *text;        // Text / LongText content (updated as the user types)
@property (nonatomic, copy) NSString *placeholder; // Text / LongText
@property (nonatomic, assign) NSUInteger maxLength; // Text / LongText, 0: none (UTF-16 units)
@property (nonatomic, copy) NSString *identifier;  // accessibilityIdentifier
@property (nonatomic, retain) id userInfo;
@end
@interface RCFormSection : NSObject
+ (RCFormSection *)sectionWithTitle:(NSString *)title rows:(NSArray *)rows;
@property (nonatomic, copy) NSString *title, *footer;
@property (nonatomic, copy) NSArray *rows; // RCFormRow
@end
@class RCFormViewController;
@protocol RCFormDelegate <NSObject>
@optional
- (void)form:(RCFormViewController *)form didSelectRow:(RCFormRow *)row;      // Value (enabled), Button, Check
- (void)form:(RCFormViewController *)form didToggleRow:(RCFormRow *)row;      // Switch: row.on is the new value
- (void)form:(RCFormViewController *)form didChangeTextOfRow:(RCFormRow *)row; // Text / LongText: row.text
@end
@interface RCFormViewController : UITableViewController <UITextFieldDelegate, UITextViewDelegate>
@property (nonatomic, copy) NSArray *sections;      // RCFormSection; setting reloads (an edited field keeps its text)
@property (nonatomic, copy) NSString *headerText;   // engraved note above the first section
@property (nonatomic, assign) BOOL busy;
@property (nonatomic, copy) NSString *busyAccessibilityLabel;
@property (nonatomic, assign) id<RCFormDelegate> delegate;
- (void)endEditing;                                 // resigns the active field (its text is already reported)
@end
