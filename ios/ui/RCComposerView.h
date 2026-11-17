// RCComposerView — Messages-style input bar (app.css .composer).
// Fixed slots from stage 10 on: [+] (8) | growing field with mic (9) and expand |
// Send. Send becomes Stop while an answer streams (9) and Voice when the field is
// empty and voice exists (8); otherwise Send is simply disabled. A 7 pt amber lamp
// on Send shows that send preparation is still running (an early tap is queued once).
// Above the row: optional mode chip, attachment tray and a red tray note.
#import <UIKit/UIKit.h>
#import "RCGlyph.h"
#import "RCDictationView.h"

typedef enum { RCSendModeSend = 0, RCSendModeStop, RCSendModeVoice } RCSendMode;
typedef enum { RCChipBlue = 0, RCChipGreen, RCChipPurple, RCChipOrange } RCChipColor;

@interface RCComposerAttachment : NSObject
+ (id)attachmentWithTitle:(NSString *)title glyph:(NSString *)glyph image:(UIImage *)image;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *glyph;   // document glyph when there is no image
@property (nonatomic, retain) UIImage *image;  // thumbnail
@property (nonatomic, assign) CGFloat progress; // < 1 shows the upload bar
@property (nonatomic, assign) BOOL failed;      // red border
@property (nonatomic, copy) NSString *detail;   // VoiceOver value: the caller's status line (uploading, failed…)
@end

@class RCComposerView;
@protocol RCComposerViewDelegate <NSObject>
@optional
- (void)composerView:(RCComposerView *)view didChangeHeight:(CGFloat)height;
- (void)composerViewTextDidChange:(RCComposerView *)view;
- (void)composerViewDidTapSend:(RCComposerView *)view;
- (void)composerViewDidTapStop:(RCComposerView *)view;
- (void)composerViewDidTapVoice:(RCComposerView *)view;
- (void)composerViewDidTapPlus:(RCComposerView *)view;
- (void)composerViewDidTapMic:(RCComposerView *)view;
- (void)composerViewDidTapExpand:(RCComposerView *)view;
- (void)composerViewDidClearMode:(RCComposerView *)view;
- (void)composerView:(RCComposerView *)view didRemoveAttachmentAtIndex:(NSUInteger)index;
// A tap on a tray item (not its ✕): implement to show its status / retry / replace.
- (void)composerView:(RCComposerView *)view didTapAttachmentAtIndex:(NSUInteger)index;
@end

@interface RCComposerView : UIView <UITextViewDelegate>
// stage capabilities (slots appear, never as disabled placeholders)
@property (nonatomic, assign) BOOL showsPlus;      // 8+
@property (nonatomic, assign) BOOL showsMic;       // 9+ dictation
@property (nonatomic, assign) BOOL expandAvailable; // full-screen editor when tall
@property (nonatomic, assign) BOOL stopAvailable;  // 9+
@property (nonatomic, assign) BOOL voiceAvailable; // 8+
// live state
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *placeholder;  // "Сообщение"
@property (nonatomic, assign) BOOL streaming;
@property (nonatomic, assign) BOOL preparing;       // readiness lamp on Send
@property (nonatomic, assign) BOOL sendBlocked;      // Send unavailable for the caller's reasons (session, loading)
@property (nonatomic, assign) BOOL editable;         // default YES
@property (nonatomic, readonly) RCSendMode sendMode;
@property (nonatomic, readonly) BOOL sendEnabled;
// chips, tray, note
- (void)setModeChipTitle:(NSString *)title glyph:(NSString *)glyph color:(RCChipColor)color; // nil title clears
@property (nonatomic, copy) NSArray *attachments;   // RCComposerAttachment
@property (nonatomic, copy) NSString *trayNote;
@property (nonatomic, assign) id<RCComposerViewDelegate> delegate;
@property (nonatomic, readonly) UITextView *textView;
@property (nonatomic, readonly) UIButton *sendButton, *micButton, *plusButton;
// Dictation (stage 9): the row is replaced by dictationView; wire its buttons.
@property (nonatomic, assign) BOOL dictating;
@property (nonatomic, readonly) RCDictationView *dictationView;
- (CGFloat)heightForWidth:(CGFloat)width;
#ifdef OR6_CHAT_ACCEPTANCE
// Acceptance builds only (ui7_fixture_state, once per fixture): a bare, off-window UITextView and a
// real composer fed synthetic texts; per case the assigned/read-back lengths, read-back SHA-256 and
// whether the model below recovers the intended text, also after c.text = c.text. No user text.
+ (NSArray *)lineBreakProbe;
#endif
@end

// iOS 6.1.4 UITextView (WebKit) line breaks, device-proven: every "\n" of an attributed string ends a
// paragraph. Assigning "a\n" shows one paragraph and reads back "a" (QA81: a 168-character draft with a
// typed final Return came back as 167). An empty last paragraph reads back with one extra "\n" (QA80:
// emptied text read "\n"; Return at the end read ORIGINAL+"\n\n"). The composer and the app's full-screen
// editor keep the intended text and use these three (tests/chat-keyboard/editor.m):
NSString *RCTextViewStoredText(NSString *text);  // what to assign: one more "\n" when the last paragraph is empty
// The intended text for a read-back: it, or it plus that one extra "\n" while its last paragraph is
// empty ("" or ending in "\n"). Any other read-back (a change not reported) is returned as read.
NSString *RCTextViewIntendedText(NSString *readBack, NSString *intended);
// The intended text after one -textView:shouldChangeTextInRange:replacementText: edit (range in the
// read-back; reaching the extra "\n" ends at the intended text). nil: the range is not trusted.
NSString *RCTextViewEditedText(NSString *readBack, NSString *intended, NSRange range, NSString *replacement);
