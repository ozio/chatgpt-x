// RCLaunchView — the launch screen (prototype app.js launch(); concept B
// «Прожектор», chosen 10 November 2026): dark linen, a soft jade spotlight with a
// vignette and only the bare white embossed brand mark (RCBrandMarkEmbossedWhite,
// no tile) centred in the view — no title, status text or spinner.
// The bundled launch images (Default.png, Default@2x.png, Default-568h@2x.png in
// ios/chat/Resources) are rendered from this exact layout by
// ios/ui/tools/render-launch.swift, so the first app frame matches the system
// launch image. The window root covers itself with the view at once and finishes
// it when it knows what to show:
//   RCLaunchFinishContent — fades out (0.4 s, the logo grows slightly) over the
//                           screen underneath (the chat);
//   RCLaunchFinishWelcome — the spotlight fades while the logo rises to the
//                           RCWelcomeViewController position, then the view fades
//                           over the welcome screen, which has it in the same place.
// -showStatusAfterDelay: draws nothing (user decision, 10 November 2026: the
// splash is the mark alone); after the delay only the VoiceOver label gains
// statusText («Восстанавливаю сессию…»).
// Looks the same in light and dark appearance (like the welcome screen).
#import <UIKit/UIKit.h>

typedef enum {
    RCLaunchFinishContent = 0,
    RCLaunchFinishWelcome
} RCLaunchFinish;

@interface RCLaunchView : UIView
@property (nonatomic, copy) NSString *appTitle;    // «ChatGPT X»; VoiceOver label only, not drawn
@property (nonatomic, copy) NSString *statusText;  // nil: «Восстанавливаю сессию…»; VoiceOver only, not drawn
@property (nonatomic, readonly, getter=isFinishing) BOOL finishing;
- (void)showStatusAfterDelay:(NSTimeInterval)delay; // VoiceOver label only; no-op once finishing
// Animates, removes itself from its superview, then calls completion. Once only.
- (void)finish:(RCLaunchFinish)finish completion:(void (^)(void))completion;
+ (CGFloat)logoTopForHeight:(CGFloat)height;       // logo canvas top: mark centre on the middle of the view
@end
