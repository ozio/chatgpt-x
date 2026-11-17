#import "RCFormViewController.h"
#import "RCTheme.h"
#import <objc/runtime.h>

@implementation RCFormRow
@synthesize kind = _kind, title = _title, subtitle = _subtitle, value = _value, glyph = _glyph, tile = _tile, showsLamp = _showsLamp, lamp = _lamp, on = _on, checked = _checked,
    enabled = _enabled, destructive = _destructive, disclosure = _disclosure, busy = _busy, text = _text, placeholder = _placeholder, maxLength = _maxLength, identifier = _identifier, userInfo = _userInfo;
+ (RCFormRow *)rowWithKind:(RCFormRowKind)kind title:(NSString *)title {
    RCFormRow *r = [[[self alloc] init] autorelease];
    r.kind = kind; r.title = title; r.enabled = YES;
    return r;
}
- (void)dealloc { [_title release]; [_subtitle release]; [_value release]; [_glyph release]; [_text release]; [_placeholder release]; [_identifier release]; [_userInfo release]; [super dealloc]; }
@end

@implementation RCFormSection
@synthesize title = _title, footer = _footer, rows = _rows;
+ (RCFormSection *)sectionWithTitle:(NSString *)title rows:(NSArray *)rows {
    RCFormSection *s = [[[self alloc] init] autorelease];
    s.title = title; s.rows = rows;
    return s;
}
- (void)dealloc { [_title release]; [_footer release]; [_rows release]; [super dealloc]; }
@end

// Fonts follow the text size: titles bold body + 1 (17 pt at the default step), second
// lines, values, notes and footers body − 2 (14 pt).
static UIFont *RCFormTitleFont(void) { return [UIFont boldSystemFontOfSize:[RCTheme bodyFont].pointSize + 1]; }
static UIFont *RCFormSmallFont(void) { return [UIFont systemFontOfSize:[RCTheme bodyFont].pointSize - 2]; }
static UIFont *RCFormFieldFont(void) { return [UIFont systemFontOfSize:[RCTheme bodyFont].pointSize]; }
static const char kRCFormRowKey = 0;

@interface RCFormViewController () { NSArray *_sections; NSString *_headerText, *_busyLabel; BOOL _busy; id<RCFormDelegate> _delegate; RCFormRow *_editing; UIBarButtonItem *_savedItem; }
@end

@implementation RCFormViewController
@synthesize sections = _sections, headerText = _headerText, busy = _busy, busyAccessibilityLabel = _busyLabel, delegate = _delegate;

- (id)init { return [self initWithStyle:UITableViewStyleGrouped]; }
- (id)initWithStyle:(UITableViewStyle)style {
    (void)style;
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) _sections = [[NSArray alloc] init];
    return self;
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _delegate = nil; [_sections release]; [_headerText release]; [_busyLabel release]; [_editing release]; [_savedItem release];
    [super dealloc];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    [RCTheme styleGroupedTableView:self.tableView];
    NSNotificationCenter *n = [NSNotificationCenter defaultCenter];
    [n addObserver:self selector:@selector(looksChanged:) name:RCThemeAppearanceDidChangeNotification object:nil];
    [n addObserver:self selector:@selector(looksChanged:) name:RCThemeTextSizeDidChangeNotification object:nil];
    [self renderBusy]; [self renderHeader];
}
- (void)looksChanged:(NSNotification *)n { (void)n; if (!self.isViewLoaded) return; [RCTheme styleGroupedTableView:self.tableView]; [self renderHeader]; [self.tableView reloadData]; }
- (void)setSections:(NSArray *)sections {
    NSArray *s = [(sections ? sections : [NSArray array]) copy];
    [_sections release]; _sections = s;
    if (self.isViewLoaded) [self.tableView reloadData];
}
- (void)setHeaderText:(NSString *)t { NSString *c = [t copy]; [_headerText release]; _headerText = c; if (self.isViewLoaded) [self renderHeader]; }
- (void)setBusyAccessibilityLabel:(NSString *)l { NSString *c = [l copy]; [_busyLabel release]; _busyLabel = c; if (self.isViewLoaded) [self renderBusy]; }
- (void)setBusy:(BOOL)busy { if (busy == _busy) return; _busy = busy; if (self.isViewLoaded) { [self renderBusy]; [self.tableView reloadData]; } }
- (void)endEditing { [self.view endEditing:YES]; }
- (void)renderBusy {
    self.tableView.userInteractionEnabled = !_busy;
    if (!_busy) { if ([self.navigationItem.rightBarButtonItem.customView isKindOfClass:[UIActivityIndicatorView class]]) self.navigationItem.rightBarButtonItem = _savedItem; [_savedItem release]; _savedItem = nil; return; }
    if (![self.navigationItem.rightBarButtonItem.customView isKindOfClass:[UIActivityIndicatorView class]]) { [_savedItem release]; _savedItem = [self.navigationItem.rightBarButtonItem retain]; } // the caller's item returns after busy
    UIActivityIndicatorView *spin = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite] autorelease];
    [spin startAnimating];
    spin.accessibilityLabel = _busyLabel.length ? _busyLabel : RCL(@"Please wait…");
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithCustomView:spin] autorelease];
}
- (UILabel *)engravedLabel:(NSString *)text width:(CGFloat)w {
    UILabel *l = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
    l.backgroundColor = [UIColor clearColor]; l.font = RCFormSmallFont(); l.numberOfLines = 0; l.textAlignment = NSTextAlignmentCenter;
    l.textColor = [RCTheme noteTextColor]; l.shadowColor = [RCTheme engravedShadowColor]; l.shadowOffset = [RCTheme engravedShadowOffset];
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    RCLabelSetText(l, text);
    l.frame = CGRectMake(20, 6, w - 40, RCMeasureText(text, l.font, w - 40).height);
    return l;
}
- (void)renderHeader {
    if (!_headerText.length) { self.tableView.tableHeaderView = nil; return; }
    CGFloat w = self.tableView.bounds.size.width ? self.tableView.bounds.size.width : 320;
    UILabel *l = [self engravedLabel:_headerText width:w];
    l.frame = CGRectMake(20, 14, w - 40, l.frame.size.height);
    UIView *v = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, w, l.frame.size.height + 18)] autorelease];
    [v addSubview:l];
    self.tableView.tableHeaderView = v;
}

- (RCFormSection *)sectionAt:(NSInteger)s { return (s >= 0 && (NSUInteger)s < _sections.count) ? [_sections objectAtIndex:(NSUInteger)s] : nil; }
- (RCFormRow *)rowAt:(NSIndexPath *)p { NSArray *r = [self sectionAt:p.section].rows; return (p.row >= 0 && (NSUInteger)p.row < r.count) ? [r objectAtIndex:(NSUInteger)p.row] : nil; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { (void)t; return (NSInteger)_sections.count; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { (void)t; return (NSInteger)[self sectionAt:s].rows.count; }
- (UIView *)tableView:(UITableView *)t viewForHeaderInSection:(NSInteger)s {
    NSString *title = [self sectionAt:s].title;
    if (!title.length) return nil;
    UIView *v = [RCTheme groupedHeaderViewWithTitle:title width:(t.bounds.size.width ? t.bounds.size.width : 320)];
    for (UIView *l in v.subviews) l.accessibilityTraits = UIAccessibilityTraitHeader;
    return v;
}
- (CGFloat)tableView:(UITableView *)t heightForHeaderInSection:(NSInteger)s { (void)t; return [self sectionAt:s].title.length ? 44 : 10; }
- (UIView *)tableView:(UITableView *)t viewForFooterInSection:(NSInteger)s {
    NSString *f = [self sectionAt:s].footer;
    if (!f.length) return nil;
    CGFloat w = t.bounds.size.width ? t.bounds.size.width : 320;
    UILabel *l = [self engravedLabel:f width:w];
    UIView *v = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, w, l.frame.size.height + 16)] autorelease];
    [v addSubview:l];
    return v;
}
- (CGFloat)tableView:(UITableView *)t heightForFooterInSection:(NSInteger)s {
    NSString *f = [self sectionAt:s].footer;
    return f.length ? RCMeasureText(f, RCFormSmallFont(), (t.bounds.size.width ? t.bounds.size.width : 320) - 40).height + 16 : 1;
}
- (CGFloat)textWidth:(UITableView *)t row:(RCFormRow *)row {
    CGFloat w = (t.bounds.size.width ? t.bounds.size.width : 320) - 20 - 20; // grouped inset + cell padding
    if (row.glyph.length) w -= 29 + 10;
    if (row.kind == RCFormRowValue && row.value.length) w -= 130;
    if (row.kind == RCFormRowSwitch) w -= 79 + 8;
    if (row.kind == RCFormRowCheck || row.disclosure) w -= 24;
    return MAX(80, w);
}
- (CGFloat)tableView:(UITableView *)t heightForRowAtIndexPath:(NSIndexPath *)p {
    RCFormRow *row = [self rowAt:p];
    switch (row.kind) {
        case RCFormRowLongText: return ceil(RCFormFieldFont().lineHeight * 4 + 20);
        case RCFormRowNote: return MAX(44, ceil(RCMeasureText(row.subtitle.length ? row.subtitle : row.title, RCFormSmallFont(), [self textWidth:t row:row]).height + 22));
        case RCFormRowText: case RCFormRowButton: return 44;
        default: {
            CGFloat h = RCFormTitleFont().lineHeight + 20;
            if (row.subtitle.length) h += RCMeasureText(row.subtitle, RCFormSmallFont(), [self textWidth:t row:row]).height + 1;
            return MAX(44, ceil(h));
        }
    }
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p {
    RCFormRow *row = [self rowAt:p];
    BOOL twoLines = row.kind == RCFormRowValue && row.subtitle.length; // value moves into a right-hand label
    NSString *reuse = [NSString stringWithFormat:@"RCForm%d%@", (int)row.kind, twoLines ? @"s" : @""];
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:reuse];
    if (!c) {
        c = [[[UITableViewCell alloc] initWithStyle:(row.kind == RCFormRowValue && !twoLines ? UITableViewCellStyleValue1 : UITableViewCellStyleSubtitle) reuseIdentifier:reuse] autorelease];
        if (row.kind == RCFormRowSwitch) { UISwitch *sw = [[[UISwitch alloc] initWithFrame:CGRectZero] autorelease]; [sw addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged]; c.accessoryView = sw; }
        if (row.kind == RCFormRowText) {
            UITextField *f = [[[UITextField alloc] initWithFrame:CGRectInset(c.contentView.bounds, 10, 0)] autorelease];
            f.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; f.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
            f.delegate = self; f.tag = 71; f.clearButtonMode = UITextFieldViewModeWhileEditing; f.returnKeyType = UIReturnKeyDone;
            [f addTarget:self action:@selector(fieldChanged:) forControlEvents:UIControlEventEditingChanged];
            [c.contentView addSubview:f];
        }
        if (row.kind == RCFormRowLongText) {
            UITextView *v = [[[UITextView alloc] initWithFrame:CGRectInset(c.contentView.bounds, 4, 4)] autorelease];
            v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; v.backgroundColor = [UIColor clearColor]; v.delegate = self; v.tag = 72;
            [c.contentView addSubview:v];
        }
    }
    [RCTheme styleGroupedCell:c position:[RCTheme positionForRow:p.row count:(NSInteger)[self sectionAt:p.section].rows.count]];
    objc_setAssociatedObject(c, &kRCFormRowKey, row, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    BOOL enabled = row.enabled && !_busy;
    c.textLabel.backgroundColor = c.detailTextLabel.backgroundColor = [UIColor clearColor];
    c.textLabel.font = RCFormTitleFont(); c.textLabel.textAlignment = NSTextAlignmentLeft; c.textLabel.numberOfLines = 1; c.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    c.textLabel.textColor = enabled || row.kind == RCFormRowNote ? [RCTheme inkColor] : [RCTheme secondaryInkColor];
    c.detailTextLabel.font = RCFormSmallFont(); c.detailTextLabel.textColor = [RCTheme secondaryInkColor]; c.detailTextLabel.numberOfLines = 0;
    c.imageView.image = row.glyph.length ? [RCGlyph tileNamed:row.glyph color:row.tile size:29] : nil;
    c.accessoryType = UITableViewCellAccessoryNone;
    if (row.kind != RCFormRowSwitch) c.accessoryView = nil;
    c.selectionStyle = UITableViewCellSelectionStyleNone;
    c.isAccessibilityElement = YES; c.accessibilityIdentifier = row.identifier; c.accessibilityHint = nil;
    UIAccessibilityTraits traits = enabled ? 0 : UIAccessibilityTraitNotEnabled;
    c.textLabel.text = row.title;
    RCLabelSetText(c.detailTextLabel, row.subtitle.length ? row.subtitle : nil); // multi-line: iOS 6 drops words with plain .text
    switch (row.kind) {
        case RCFormRowValue: {
            c.detailTextLabel.numberOfLines = twoLines ? 0 : 1; if (twoLines) RCLabelSetText(c.detailTextLabel, row.subtitle); else c.detailTextLabel.text = row.value;
            if (row.busy) { UIActivityIndicatorView *s = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray] autorelease]; [s startAnimating]; c.accessoryView = s; }
            else if (row.showsLamp || (twoLines && row.value.length)) {
                UIView *box = [[[UIView alloc] initWithFrame:CGRectZero] autorelease]; CGFloat x = 0;
                if (row.showsLamp) { RCLampView *l = [[[RCLampView alloc] initWithDiameter:9] autorelease]; l.state = row.lamp; l.center = CGPointMake(5, 11); [box addSubview:l]; x = 14; }
                if (twoLines && row.value.length) { UILabel *v = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease]; v.backgroundColor = [UIColor clearColor]; v.font = RCFormSmallFont(); v.textColor = [RCTheme linkColor]; v.text = row.value; [v sizeToFit]; v.frame = CGRectMake(x, 0, MIN(v.frame.size.width, 120), 22); [box addSubview:v]; x += v.frame.size.width; }
                box.frame = CGRectMake(0, 0, MAX(x, 10), 22); c.accessoryView = box;
            }
            if (row.disclosure && !row.busy && !c.accessoryView) c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            if (row.disclosure && enabled) c.selectionStyle = UITableViewCellSelectionStyleBlue;
            traits |= row.disclosure ? UIAccessibilityTraitButton : UIAccessibilityTraitStaticText;
            c.accessibilityValue = [[NSArray arrayWithObjects:(row.value ? row.value : @""), (row.subtitle ? row.subtitle : @""), nil] componentsJoinedByString:@" "];
            break; }
        case RCFormRowSwitch: {
            UISwitch *sw = (UISwitch *)c.accessoryView; sw.on = row.on; sw.enabled = enabled;
            traits |= UIAccessibilityTraitButton | (row.on ? UIAccessibilityTraitSelected : 0);
            c.accessibilityValue = [NSString stringWithFormat:@"%@%@%@", row.on ? RCL(@"On") : RCL(@"Off"), row.subtitle.length ? @". " : @"", row.subtitle ? row.subtitle : @""];
            break; }
        case RCFormRowButton: {
            c.textLabel.textAlignment = NSTextAlignmentCenter; c.detailTextLabel.text = nil;
            c.textLabel.textColor = !enabled ? [RCTheme secondaryInkColor] : row.destructive ? [RCTheme errorInkColor] : [RCTheme linkColor];
            if (row.busy) { UIActivityIndicatorView *s = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray] autorelease]; [s startAnimating]; c.accessoryView = s; }
            if (enabled) c.selectionStyle = UITableViewCellSelectionStyleBlue;
            traits |= UIAccessibilityTraitButton;
            break; }
        case RCFormRowText: {
            c.textLabel.text = nil; c.detailTextLabel.text = nil;
            UITextField *f = (UITextField *)[c.contentView viewWithTag:71];
            f.font = RCFormFieldFont(); f.textColor = [RCTheme inkColor]; f.placeholder = row.placeholder.length ? row.placeholder : row.title; f.enabled = enabled;
            if (row != _editing || !f.isFirstResponder) f.text = row.text;
            objc_setAssociatedObject(f, &kRCFormRowKey, row, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            f.accessibilityLabel = row.title; f.accessibilityIdentifier = row.identifier; c.isAccessibilityElement = NO;
            break; }
        case RCFormRowLongText: {
            c.textLabel.text = nil; c.detailTextLabel.text = nil;
            UITextView *v = (UITextView *)[c.contentView viewWithTag:72];
            v.editable = enabled;
            if (row != _editing || !v.isFirstResponder) v.attributedText = [[[NSAttributedString alloc] initWithString:(row.text ? row.text : @"") attributes:RCTextViewAttributes(RCFormFieldFont(), [RCTheme inkColor])] autorelease];
            objc_setAssociatedObject(v, &kRCFormRowKey, row, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            v.accessibilityLabel = row.title; v.accessibilityHint = row.placeholder; v.accessibilityIdentifier = row.identifier; c.isAccessibilityElement = NO;
            break; }
        case RCFormRowNote: {
            c.textLabel.font = RCFormSmallFont(); c.textLabel.numberOfLines = 0; c.textLabel.textColor = [RCTheme secondaryInkColor];
            RCLabelSetText(c.textLabel, row.subtitle.length ? row.subtitle : row.title);
            c.detailTextLabel.text = nil; traits = UIAccessibilityTraitStaticText;
            break; }
        case RCFormRowCheck: {
            c.accessoryView = row.checked ? [RCTheme checkmarkAccessoryView] : nil;
            if (enabled) c.selectionStyle = UITableViewCellSelectionStyleBlue;
            traits |= UIAccessibilityTraitButton | (row.checked ? UIAccessibilityTraitSelected : 0);
            c.accessibilityValue = row.subtitle;
            break; }
    }
    if (row.kind != RCFormRowValue && row.kind != RCFormRowSwitch && row.kind != RCFormRowCheck) c.accessibilityValue = nil;
    c.accessibilityLabel = row.kind == RCFormRowNote ? (row.subtitle.length ? row.subtitle : row.title) : row.title;
    c.accessibilityTraits = traits;
    return c;
}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p {
    [t deselectRowAtIndexPath:p animated:YES];
    RCFormRow *row = [self rowAt:p];
    if (_busy || !row.enabled || row.busy) return;
    if (row.kind == RCFormRowButton || row.kind == RCFormRowCheck || (row.kind == RCFormRowValue && row.disclosure))
        if ([_delegate respondsToSelector:@selector(form:didSelectRow:)]) [_delegate form:self didSelectRow:row];
}
- (void)toggled:(UISwitch *)sw {
    UIView *v = sw; while (v && ![v isKindOfClass:[UITableViewCell class]]) v = v.superview;
    RCFormRow *row = v ? objc_getAssociatedObject(v, &kRCFormRowKey) : nil;
    if (!row || _busy || !row.enabled) { sw.on = row.on; return; }
    row.on = sw.on;
    if ([_delegate respondsToSelector:@selector(form:didToggleRow:)]) [_delegate form:self didToggleRow:row];
}
- (void)report:(RCFormRow *)row text:(NSString *)text {
    if (!row) return;
    if (row.maxLength && text.length > row.maxLength) text = [text substringToIndex:row.maxLength];
    row.text = text;
    if ([_delegate respondsToSelector:@selector(form:didChangeTextOfRow:)]) [_delegate form:self didChangeTextOfRow:row];
}
- (void)fieldChanged:(UITextField *)f { [self report:objc_getAssociatedObject(f, &kRCFormRowKey) text:f.text ? f.text : @""]; }
- (void)textFieldDidBeginEditing:(UITextField *)f { [_editing release]; _editing = [objc_getAssociatedObject(f, &kRCFormRowKey) retain]; }
- (void)textFieldDidEndEditing:(UITextField *)f { (void)f; [_editing release]; _editing = nil; }
- (BOOL)textFieldShouldReturn:(UITextField *)f { [f resignFirstResponder]; return NO; }
- (BOOL)textField:(UITextField *)f shouldChangeCharactersInRange:(NSRange)r replacementString:(NSString *)s {
    RCFormRow *row = objc_getAssociatedObject(f, &kRCFormRowKey);
    return !row.maxLength || f.text.length - r.length + s.length <= row.maxLength;
}
- (void)textViewDidBeginEditing:(UITextView *)v { [_editing release]; _editing = [objc_getAssociatedObject(v, &kRCFormRowKey) retain]; }
- (void)textViewDidEndEditing:(UITextView *)v { (void)v; [_editing release]; _editing = nil; }
- (void)textViewDidChange:(UITextView *)v { [self report:objc_getAssociatedObject(v, &kRCFormRowKey) text:v.attributedText.string ? v.attributedText.string : @""]; }
- (BOOL)textView:(UITextView *)v shouldChangeTextInRange:(NSRange)r replacementText:(NSString *)s {
    RCFormRow *row = objc_getAssociatedObject(v, &kRCFormRowKey);
    return !row.maxLength || v.attributedText.length - r.length + s.length <= row.maxLength;
}
@end
