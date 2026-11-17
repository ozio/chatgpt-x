#import "RCStage.h"
#import "RCTheme.h"

NSString *const RCStageDidChangeNotification = @"RCStageDidChangeNotification";
static NSString *const RCStageKey = @"RCFeatureStage";
static int gDefaultStage = 9;
static int gStage = 0; // 0: not loaded

static int RCStageClamp(int stage) { return MAX(6, MIN(10, stage)); }

void RCStageRegisterDefault(int stage) { gDefaultStage = RCStageClamp(stage); }

int RCStageCurrent(void) {
    if (!gStage) {
        id stored = [[NSUserDefaults standardUserDefaults] objectForKey:RCStageKey];
        gStage = [stored isKindOfClass:[NSNumber class]] ? RCStageClamp([stored intValue]) : gDefaultStage;
    }
    return gStage;
}

void RCStageSet(int stage) {
    stage = RCStageClamp(stage);
    if (stage == RCStageCurrent()) return;
    gStage = stage;
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:stage] forKey:RCStageKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:RCStageDidChangeNotification object:nil];
}

BOOL RCStageOn(int usefulness) { return usefulness >= RCStageCurrent(); }

NSString *RCStageTitle(int stage) {
    switch (RCStageClamp(stage)) {
        case 10: return RCL(@"Stage 10 · core");
        case 9: return RCL(@"Stage 9 · reliability and text");
        case 8: return RCL(@"Stage 8 · model, attachments, voice");
        case 7: return RCL(@"Stage 7 · library and tools");
        default: return RCL(@"Stage 6 · everything");
    }
}
