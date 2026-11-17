#import "../localization/OR6Localization.h"
#import "OR6ChatWelcomeController.h"

@interface OR6ChatWelcomeController () <RCWelcomeViewControllerDelegate>
@end

@implementation OR6ChatWelcomeController
@synthesize chatDelegate = _chatDelegate;

- (id)init {
    if ((self = [super init])) {
        self.delegate = self;
        self.appTitle = @"ChatGPT X";
        self.message = nil;
        self.footnote = OR6L(@"Unofficial app. Not affiliated with OpenAI.");
        self.signUpAvailable = NO; // no separate sign-up path in this build
        [self setState:RCWelcomeChecking text:OR6L(@"Restoring session…")];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.accessibilityIdentifier = @"chat.welcome";
}

- (void)applySessionSummary:(NSDictionary *)summary notice:(NSString *)notice {
    NSString *state = [summary objectForKey:@"state"];
    if (!summary || [state isEqual:@"validating"]) [self setState:RCWelcomeChecking text:OR6L(@"Restoring session…")];
    else if (notice.length) [self setState:RCWelcomeError text:notice];
    else if ([state isEqual:@"login_required"] || [state isEqual:@"recovery_required"]) [self setState:RCWelcomeIdle text:nil];
    else [self setState:RCWelcomeIdle text:nil];
}

- (void)welcomeDidTapSignIn:(RCWelcomeViewController *)welcome { (void)welcome; [_chatDelegate welcomeDidRequestSignIn:self]; }
@end
