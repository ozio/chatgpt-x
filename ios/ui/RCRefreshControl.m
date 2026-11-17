#import "RCRefreshControl.h"
#import "RCTheme.h"
@interface RCRefreshControl () { BOOL _attached; }
@end
@implementation RCRefreshControl
- (id)init {
    if ((self = [super init])) {
        self.accessibilityIdentifier = @"chat.refresh";
        self.accessibilityTraits = UIAccessibilityTraitButton;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(lookChanged:) name:RCThemeAppearanceDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(lookChanged:) name:RCThemeTextSizeDidChangeNotification object:nil];
        [self refreshAppearance];
    }
    return self;
}
- (void)attachToTableView:(UITableView*)table inViewController:(UIViewController*)parent {
    if(_attached||!table||!parent)return;
    id<UITableViewDelegate> delegate=table.delegate;id<UITableViewDataSource> source=table.dataSource;
    UITableViewController *host=[[[UITableViewController alloc]initWithStyle:table.style]autorelease];
    [parent addChildViewController:host];host.tableView=table;(void)host.view;
    table.delegate=delegate;table.dataSource=source;host.refreshControl=self;
    [host didMoveToParentViewController:parent];_attached=YES;
}
- (void)refreshAppearance {
    self.tintColor = [RCTheme jadeColor];
    NSString *title = self.refreshing ? RCL(@"Refreshing…") : RCL(@"Pull to refresh");
    self.attributedTitle = [[[NSAttributedString alloc] initWithString:title attributes:RCTextViewAttributes([RCTheme bodyFont], [RCTheme secondaryInkColor])] autorelease];
    self.accessibilityLabel = title;
    self.accessibilityHint = RCL(@"Refreshes this conversation and its title");
}
- (void)lookChanged:(NSNotification*)note { (void)note; [self refreshAppearance]; }
- (void)beginRefreshing { [super beginRefreshing]; [self refreshAppearance]; }
- (void)endRefreshing { [super endRefreshing]; [self refreshAppearance]; }
- (void)setEnabled:(BOOL)enabled { [super setEnabled:enabled]; self.accessibilityTraits = UIAccessibilityTraitButton | (enabled ? 0 : UIAccessibilityTraitNotEnabled); }
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; [super dealloc]; }
@end
