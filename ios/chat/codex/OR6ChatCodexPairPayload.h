#import <Foundation/Foundation.h>
struct quirc;
NSString *OR6ChatCodexPairQRPayload(NSString *payload);
NSString *OR6ChatCodexPairDecodeQR(struct quirc *decoder);

// Counters and payload shape only: never raw frames, URLs, codes or QR data.
NSDictionary *OR6ChatCodexPairQRDiagnostics(void);
void OR6ChatCodexPairQRReset(void);
NSString *OR6ChatCodexPairDecodeGray(struct quirc *decoder, const unsigned char *gray, NSUInteger length);
