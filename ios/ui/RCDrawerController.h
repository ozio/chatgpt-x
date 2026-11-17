// RCDrawerController — the reveal drawer's content (app.css .dr): dark green
// linen, dark search bar, uppercase section headers, rows (navigation, chats,
// sub-items with a colour dot, "Показать ещё"), and the account footer.
#import <UIKit/UIKit.h>

typedef enum {
    RCDrawerRowNav = 0, // bold 16, glyph at left: Новый чат, Библиотека…
    RCDrawerRowChat,    // regular 15, optional small glyph (pinned)
    RCDrawerRowSub,     // regular 15, inset, optional colour dot (projects)
    RCDrawerRowMore     // 14 bold dim, optional spinner: "Показать ещё"
} RCDrawerRowStyle;

@interface RCDrawerItem : NSObject
+ (id)itemWithTitle:(NSString *)title glyph:(NSString *)glyph style:(RCDrawerRowStyle)style;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *glyph;
@property (nonatomic, copy) NSString *count;     // right-aligned dim number
@property (nonatomic, retain) UIColor *dotColor; // RCDrawerRowSub
@property (nonatomic, assign) RCDrawerRowStyle style;
@property (nonatomic, assign) BOOL current;      // the open screen/chat (inset dark)
@property (nonatomic, assign) BOOL busy;         // RCDrawerRowMore spinner
@property (nonatomic, retain) id userInfo;
@property (nonatomic, assign) BOOL actionsAvailable; // long press (VoiceOver: double-tap and hold) asks the delegate for row actions
@property (nonatomic, copy) NSString *accessibilityIdentifier; // the row cell's identifier (chat.* automation); nil: none
@end

@interface RCDrawerSection : NSObject
+ (id)sectionWithTitle:(NSString *)title items:(NSArray *)items;
@property (nonatomic, copy) NSString *title; // nil: no header
@property (nonatomic, copy) NSArray *items;
@property (nonatomic, copy) NSString *emptyText; // shown when items is empty
@end

@class RCDrawerController;
@protocol RCDrawerControllerDelegate <NSObject>
@optional
- (void)drawer:(RCDrawerController *)drawer didSelectItem:(RCDrawerItem *)item;
- (void)drawer:(RCDrawerController *)drawer searchTextDidChange:(NSString *)text;
- (void)drawerDidTapAccount:(RCDrawerController *)drawer;
// Long press on an item with actionsAvailable (e.g. rename / pin / archive / delete).
- (void)drawer:(RCDrawerController *)drawer didLongPressItem:(RCDrawerItem *)item;
@end

@interface RCDrawerController : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property (nonatomic, copy) NSArray *sections; // RCDrawerSection
@property (nonatomic, assign) BOOL showsSearch;
@property (nonatomic, copy) NSString *searchPlaceholder; // "Поиск по чатам"
@property (nonatomic, copy) NSString *accountName, *accountEmail, *accountInitials;
@property (nonatomic, assign) id<RCDrawerControllerDelegate> delegate;
@property (nonatomic, readonly) UITableView *tableView;
@end
