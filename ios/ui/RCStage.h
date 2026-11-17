// RCStage — the prototype's staged feature rollout (usefulness 10 → 6), shared by
// the app and the gallery. Stage 10 is the core; stage 6 shows everything. A
// feature with usefulness u is present when u >= current stage. The app combines
// this with its own capability checks: a slot appears only when the stage allows
// it AND the app can really do it — never as a disabled "soon" control.
#import <Foundation/Foundation.h>
#ifdef __cplusplus
extern "C" {
#endif
extern NSString *const RCStageDidChangeNotification;
// Default used until a stage is stored (NSUserDefaults "RCFeatureStage").
void RCStageRegisterDefault(int stage);
int RCStageCurrent(void);           // 6…10
void RCStageSet(int stage);         // clamps, stores, posts RCStageDidChangeNotification
BOOL RCStageOn(int usefulness);     // usefulness >= current stage
NSString *RCStageTitle(int stage);  // "Этап 9 · ядро и надёжность"
#ifdef __cplusplus
}
#endif
