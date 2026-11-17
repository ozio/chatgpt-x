// API 7/10 inside one conversation screen. The conversation controller owns this helper
// and calls it from a few hooks; the helper owns every API7 request of the screen and
// renders only kit components. Nothing here sends an ordinary message; the tool modes
// and Continue are their own explicit generation operations, available only when the
// operation is live_verified, and an unknown result is checked (read-only), never resent.
#import <UIKit/UIKit.h>
#import "OR6Chat7Models.h"
#import "OR6Chat7Screens.h"
#import "OR6Chat7ImagePreview.h" // OR6Chat7SetImagePreviewResolver (trusted composition host)
#import "RCCodeBlockView.h"
#import "RCComposerView.h"
#import "RCActivitySheet.h"

@protocol OR6Chat7ConversationHost <NSObject>
- (NSString *)chat7ConversationId;
- (NSDictionary *)chat7DraftRequest;     // {draftId, conversationId, parentMessageId, modelId, temporary}
- (NSString *)chat7DraftId;               // prepared draft (messages.newDraft succeeded), else nil
- (NSString *)chat7ModelId;               // catalog choice or "web-current"
- (NSString *)chat7LastMessageId;         // the branch's last real message ID (parent of a new turn)
- (RCComposerView *)chat7Composer;
- (BOOL)chat7Idle;                        // session ready, nothing sending/uncertain, no dictation
- (void)chat7SetDraftText:(NSString *)text; // state + composer (the user's draft)
- (void)chat7Reload;                      // history.get of this conversation
- (void)chat7Render;
- (void)chat7OpenConversation:(NSString *)identifier; // a tool created a new conversation
- (void)chat7NewChat;
- (UIViewController *)chat7Presenter;
- (id<OR6Chat7Navigator>)chat7Navigator;
@end

@interface OR6Chat7Conversation : NSObject
- (id)initWithCore:(OR6APICore *)core host:(id<OR6Chat7ConversationHost>)host;
@property (nonatomic, copy) NSString *projectId; // new chat inside a project (projects.newDraft / projects.send)
@property (nonatomic, copy) NSDictionary *project;
// «+» sheet: tool modes and Library. Items/actions are appended to the controller's own.
- (void)addPlusItems:(NSMutableArray *)items actions:(NSMutableArray *)actions;
- (BOOL)handlePlusAction:(NSString *)action;  // NO: not an API7 action
@property (nonatomic, readonly) NSString *toolMode; // nil | research | analysis | study | image
- (void)clearToolMode;
- (void)refreshModeChip;                    // the composer exists now: show the active tool/send mode chip
// Stage 6 send modes (OR6Chat6Conversation): another generation operation for the next message(s):
// {operation (gpts.send | work.send | composer.mentions.send), reconcile (its read-only check op),
//  title, glyph, chip (NSNumber RCChipColor), sticky (NSNumber: kept after a completed message),
//  build: NSDictionary *(^)(NSString *text) → the extra parameters for this text, nil = refuse (the
//  block says why)}. nil clears it. A tool mode and a send mode are exclusive.
@property (nonatomic, copy) NSDictionary *sendMode;
@property (nonatomic, copy) void (^sendFinished)(NSString *operation, NSDictionary *result); // a send mode's completed result (before navigation)
- (BOOL)wantsSend;                          // Send goes to the API7 tool/project path
- (void)send;                               // the composer text through the tool/project operation
@property (nonatomic, readonly) BOOL running; // a tool/continue/project generation is running
- (BOOL)stop;                               // cancels the running generation (it becomes uncertain)
- (NSArray *)rows;                          // extra rows to append: {kind:user|answer, id, text, ...}
- (void)configureAnswerRow:(NSDictionary *)row card:(id)card parts:(NSMutableArray *)parts isLast:(BOOL)last; // continue pill, image/audio parts, task cards
// measuring: the off-screen height card. Throwaway part views only (persistent players are never
// reparented into it); no image tag/asset entry, player cache or playback state changes.
- (void)configureAnswerRow:(NSDictionary *)row card:(id)card parts:(NSMutableArray *)parts isLast:(BOOL)last measuring:(BOOL)measuring;
- (BOOL)canExportImagesForRow:(NSDictionary *)row;
- (void)exportImagesForRow:(NSDictionary *)row destination:(NSString *)destination; // photos | share; choose when several images
- (BOOL)continueRow:(NSDictionary *)row;    // RCAnswerCut «Продолжить ответ»
- (NSArray *)moreTitlesForRow:(NSDictionary *)row isLast:(BOOL)last;
- (BOOL)performMore:(NSString *)title row:(NSDictionary *)row;
- (BOOL)shouldKitCopyCode:(RCCodeBlockView *)view row:(NSDictionary *)row; // NO: copied through content.copyCode
- (BOOL)handleLink:(NSURL *)url;            // routes.resolve / shared link; NO: not handled
- (BOOL)openEditorFromText:(NSString *)text; // composer.editor.* around the full-screen editor
- (BOOL)streamingAvailable;
- (void)startStreaming;
- (void)stopStreaming;
- (void)cancelStreaming;
@property (nonatomic, readonly) BOOL streaming;
- (void)stopPlayback;                       // audio focus: before any recording
- (void)prepareForBackground;     // also background/owner change: drops every late callback
- (void)detach;                   // controller teardown: before release (blocks may keep the helper alive)
- (BOOL)runUncertain;
- (void)reconcileRun;
- (NSDictionary *)diagnostics;
@end

#ifdef __cplusplus
extern "C" {
#endif
// Trusted composition host only (coordinator): one-use export token → file URLs for the system sheet.
void OR6Chat7SetExportResolver(NSArray *(^resolver)(NSString *token));
// Trusted composition host only (coordinator): OR6Chat7SetImagePreviewResolver (OR6Chat7ImagePreview.h),
// exact current asset binding → bounded PNG/JPEG bytes for the automatic image preview.
// Route a URL that came from outside (openURL) or from an answer link; YES when handled.
BOOL OR6Chat7HandleRoute(OR6APICore *core, NSURL *url, id<OR6Chat7Navigator> navigator, void (^home)(void));
BOOL OR6Chat7RouteURL(NSURL *url);          // scheme check only (chatgpt, openai, com.openai.chat, codex)
#ifdef __cplusplus
}
#endif
