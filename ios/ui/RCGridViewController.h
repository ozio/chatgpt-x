// RCGridViewController — collection screens from the drawer (s-tools.js):
//  • Images (stage 6): 3-up 100 pt thumbnails on linen (app.css .grid);
//  • GPT (stage 6): grouped cells with a 40 pt glossy tile, name, description and author;
//  • Library (stage 7): grouped file rows (kind tile or thumbnail, name, size · date),
//    or the same items as a 3-up grid (files as a tile + name card).
// Optional search bar and light segmented control in the header, an empty state,
// sections with headers/footers. Selection, search and segment changes go to the delegate.
#import <UIKit/UIKit.h>
#import "RCGlyph.h"

typedef enum { RCGridStyleImages = 0, RCGridStyleGPT, RCGridStyleLibrary } RCGridStyle;

@interface RCGridItem : NSObject
+ (id)itemWithTitle:(NSString *)title subtitle:(NSString *)subtitle glyph:(NSString *)glyph tile:(RCTileColor)tile;
+ (id)itemWithImage:(UIImage *)image title:(NSString *)title;
@property (nonatomic, copy) NSString *title, *subtitle, *detail; // detail: «Автор: …» line (GPT)
@property (nonatomic, retain) UIImage *image;                    // thumbnail (images, library pictures)
@property (nonatomic, copy) NSString *glyph;
@property (nonatomic, assign) RCTileColor tile;
@property (nonatomic, assign) BOOL fileIcon;                     // a concrete file: RCFileIcon from title + glyph ("photo" → Polaroid) instead of the tile
@property (nonatomic, copy) NSString *value;                     // right-aligned value (folder count)
@property (nonatomic, assign) BOOL showsDisclosure;
@property (nonatomic, retain) id userInfo;
@end

@interface RCGridSection : NSObject
+ (id)sectionWithTitle:(NSString *)title items:(NSArray *)items;
@property (nonatomic, copy) NSString *title, *footer;
@property (nonatomic, copy) NSArray *items;
@end

@class RCGridViewController;
@protocol RCGridViewControllerDelegate <NSObject>
@optional
- (void)grid:(RCGridViewController *)grid didSelectItem:(RCGridItem *)item;
- (void)grid:(RCGridViewController *)grid searchTextDidChange:(NSString *)text;
- (void)grid:(RCGridViewController *)grid searchDidSubmit:(NSString *)text; // keyboard «Search»: one explicit query (network searches)
- (void)grid:(RCGridViewController *)grid didSelectSegment:(NSInteger)index;
@end

@interface RCGridViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
- (id)initWithStyle:(RCGridStyle)style title:(NSString *)title;
@property (nonatomic, readonly) RCGridStyle style;
@property (nonatomic, assign) BOOL showsGrid;                 // Library: grid instead of rows
@property (nonatomic, copy) NSArray *sections;                // RCGridSection
@property (nonatomic, copy) NSString *searchPlaceholder;      // non-nil shows the search bar
@property (nonatomic, copy) NSArray *segmentTitles;           // non-nil shows the light segmented control
@property (nonatomic, assign) NSInteger selectedSegment;
@property (nonatomic, copy) NSString *emptyTitle, *emptyText; // shown when there are no items
@property (nonatomic, copy) NSString *emptyGlyph;             // tile above the empty title
@property (nonatomic, assign) id<RCGridViewControllerDelegate> delegate;
@property (nonatomic, readonly) UITableView *tableView;
- (void)reloadData;
@end
