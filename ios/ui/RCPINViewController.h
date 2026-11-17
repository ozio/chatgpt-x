// RCPINViewController — PIN for locked chats (app.css .pin/.keypad, stage 6): dark
// linen, title, four white boxes with ●, a message line and the iOS 6 passcode
// keypad (1…9, 0, ⌫; pressed keys turn blue). Modes: set → confirm (mismatch shakes
// and starts over), and unlock (the delegate checks; a wrong PIN shakes). States: entry,
// checking (the caller verifies asynchronously), error (shake), locked (countdown). The kit
// never stores or compares a saved PIN: the caller does, and may impose a lockout.
#import <UIKit/UIKit.h>

typedef enum { RCPINModeUnlock = 0, RCPINModeSet } RCPINMode; // Set includes the confirm step

@class RCPINViewController;
@protocol RCPINViewControllerDelegate <NSObject>
// Unlock: return YES when correct (the caller then dismisses), NO shakes and clears.
- (BOOL)pinController:(RCPINViewController *)controller checkPIN:(NSString *)pin;
@optional
- (void)pinController:(RCPINViewController *)controller didSetPIN:(NSString *)pin; // Set: entered twice, equal
- (void)pinControllerDidCancel:(RCPINViewController *)controller;               // «Отмена»
@end

@interface RCPINViewController : UIViewController
- (id)initWithMode:(RCPINMode)mode;
@property (nonatomic, readonly) RCPINMode mode;
@property (nonatomic, copy) NSString *titleText;   // nil: «Введите PIN» / «Придумайте PIN» / «Повторите PIN»
@property (nonatomic, copy) NSString *message;     // grey line under the boxes (e.g. which chat)
@property (nonatomic, readonly) NSUInteger failures;
@property (nonatomic, assign) BOOL showsCancel;    // «Отмена» in the navigation bar, default YES
@property (nonatomic, assign) id<RCPINViewControllerDelegate> delegate;
- (void)showError:(NSString *)text;                 // red line + shake
- (void)lockForSeconds:(NSUInteger)seconds;         // «Слишком много попыток. Повторите через N с» (N мин from a minute on); counts down by the clock, also while hidden
// The caller checks the PIN elsewhere (e.g. with the service): boxes stay filled, «Проверка…», keypad off.
// -showError:, -lockForSeconds: and -reset end it.
@property (nonatomic, assign) BOOL checking;
- (void)reset;
@end
