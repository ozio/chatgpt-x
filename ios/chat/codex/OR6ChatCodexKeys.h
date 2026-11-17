#import <Foundation/Foundation.h>
// Account-scoped generic Keychain records. Public key may cross UI; private key
// is a legacy SSH software key, never device enrollment/OS-nonextractable proof.
NSDictionary*OR6ChatCodexLoadKey(NSString*service,NSError**error);
BOOL OR6ChatCodexSaveKey(NSString*service,NSDictionary*key,NSError**error);
NSDictionary*OR6ChatCodexGenerateKey(NSError**error);
NSString*OR6ChatCodexFingerprint(NSString*hex);
