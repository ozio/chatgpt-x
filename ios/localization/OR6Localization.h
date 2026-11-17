#import <Foundation/Foundation.h>

// Foundation selects en/ru from the user's preferred languages (or the in-app
// language setting). The development region is English and keys are the English
// text, so a missing translation falls back to the key itself.
static inline NSString *OR6LocalizedStringInBundle(NSBundle *bundle, NSString *key) {
    return [bundle localizedStringForKey:key value:key table:@"Client"];
}

static inline NSString *OR6L(NSString *key) {
    return OR6LocalizedStringInBundle([NSBundle mainBundle], key);
}
