#import <Foundation/Foundation.h>
NSString *OR6ChatUUID(void);
NSString *OR6ChatErrorText(NSError *error);
NSArray *OR6ChatDisplayRows(NSArray *messages);
// One-shot deployment draft handoff (developer install keeps an unsent draft).
// Documents/ChatGPTXDeploymentDraft.json, a regular file (no symlink, one link) owned by
// this user with no group/other permissions, 1…131072 bytes, exactly
// {"schema":1,"conversationId":"<UUID>"|null,"text":"<1…16000 UTF-16 units>","textSHA256":"<64 hex of the UTF-8 text>"}.
NSString*OR6ChatDraftSHA256(NSString*text);      // lowercase hex SHA-256 of the UTF-8 text
NSString*OR6ChatDeploymentDraftPath(void);
// Validated {conversationId: NSString|NSNull, text} or nil; status: absent | invalid.
NSDictionary*OR6ChatReadDeploymentDraft(NSString*path,NSString**status);
@interface OR6ChatHistoryState:NSObject{
 NSMutableArray*_items;NSMutableSet*_tokens;NSString*_nextToken;BOOL _loaded;
}
@property(nonatomic,readonly)NSArray*items;
@property(nonatomic,readonly)NSString*nextToken;
@property(nonatomic,readonly)BOOL loaded;
- (void)reset;
- (BOOL)updateTitle:(NSString*)title conversation:(NSString*)identifier;
- (BOOL)acceptPage:(NSDictionary*)page token:(NSString*)token;
@end
// Message rows: {id, role, text, sources?, unsupported?, files?, images?, attachments?, note?}.
// Local rows of a running operation have IDs with the "local-" prefix.
@interface OR6ChatConversationState:NSObject{
 NSMutableArray*_messages;NSString*_conversationId,*_conversationTitle,*_parentId,*_draftId,*_text,*_operationId,*_submittedText,*_phase;
 NSUInteger _sequence;BOOL _sending,_uncertain,_loaded;
 BOOL _temporary,_optionsLocked;NSString*_modelId,*_effort,*_kind,*_generationPhase;NSArray*_attachments,*_sentAttachments,*_restore;NSDictionary*_rejected;
}
@property(nonatomic,readonly)NSArray*messages;
@property(nonatomic,readonly)NSString*conversationId;
@property(nonatomic,readonly)NSString*conversationTitle;
@property(nonatomic,readonly)NSString*operationId;
@property(nonatomic,readonly)NSString*phase;
@property(nonatomic,readonly)BOOL sending;
@property(nonatomic,readonly)BOOL uncertain;
@property(nonatomic,readonly)BOOL loaded;
@property(nonatomic,readonly)BOOL awaitingRemoteResponse;
@property(nonatomic,readonly)BOOL remoteGenerationActive;
@property(nonatomic,copy)NSString*text;
// Priority 8. A temporary chat sends with temporary:true (completed, not persisted)
// and is never read back from history. Only an empty new chat can switch it.
@property(nonatomic,readonly)BOOL temporary;
- (BOOL)setTemporary:(BOOL)temporary;
@property(nonatomic,copy)NSString*modelId;           // "web-current" unless a catalog model was chosen; a different model clears thinkingEffort
@property(nonatomic,readonly)NSString*thinkingEffort; // effort of the chosen mode, or nil (service default): sent only when set
- (void)setModelId:(NSString*)modelId thinkingEffort:(NSString*)effort; // both at once (refused while optionsLocked)
@property(nonatomic,copy)NSArray*attachments;        // asset IDs attached to the draft, exactly as Send sends them
@property(nonatomic,copy)NSArray*sentAttachments;    // display items {name,image} for the next local user bubble
@property(nonatomic,readonly)NSString*draftId;
// A safe Retry of a send refused before dispatch replays the journal's immutable
// request (its draft, temporary flag, model, effort and attachments). While it waits, the
// draft options stay as they were sent: setTemporary: refuses, modelId/effort/attachments
// keep their values. New text can still be typed; a completed send unlocks.
@property(nonatomic,assign)BOOL optionsLocked;
@property(nonatomic,readonly)NSString*kind;          // send | edit | regenerate | search: the current/last operation
@property(nonatomic,readonly)NSString*generationPhase; // last GenerationStatus phase of the running operation
// Last edit/regenerate proven not dispatched (and not a service stop signal): {operation, messageId, text?} for an explicit new attempt.
@property(nonatomic,readonly)NSDictionary*rejectedRequest;
- (id)initWithConversationId:(NSString*)identifier;
- (NSDictionary*)draftRequest;
- (BOOL)acceptConversation:(NSDictionary*)conversation;
- (NSDictionary*)beginSend;
- (BOOL)canEditMessage:(NSString*)messageId;
@property(nonatomic,readonly)BOOL branchEditable; // edit/regenerate possible now (cheap; per-row check is the row's real ID)
- (BOOL)canRegenerate:(NSString*)assistantMessageId;
- (NSDictionary*)beginEditMessage:(NSString*)messageId text:(NSString*)text; // messages.edit parameters; the draft is untouched
- (NSDictionary*)beginRegenerate:(NSString*)assistantMessageId;           // messages.regenerate parameters
- (NSDictionary*)beginRepeatRejected;                                     // new operation for rejectedRequest
- (NSDictionary*)beginWebSearch;                                          // standalone search.web (conversationId:null): never moves this chat's parent
- (void)finishWebSearch:(NSDictionary*)result error:(NSError*)error;
- (BOOL)receiveEvent:(NSDictionary*)event;
- (void)finishReceipt:(NSDictionary*)receipt error:(NSError*)error;
- (NSDictionary*)reconcileRequest;
- (BOOL)restoreRecoverySnapshot:(NSDictionary*)snapshot;
- (NSDictionary*)beginRecovery;
// Restores the handoff's text only into this conversation (null: a new chat) while it is
// loaded, idle and its draft is empty; never sends or prepares anything. The file is removed
// only after the text was restored; otherwise it stays untouched. Returns the status:
// absent | invalid | other-conversation | not-idle | draft-not-empty | imported | imported-file-kept.
- (NSString*)importDeploymentDraftAtPath:(NSString*)path;
- (NSDictionary*)diagnostics; // draftSHA256: hash of the draft text only ("" when empty), never the text
@end
