#import "OR6CodexProtocol.h"
// Pure bounded unified-diff model with old/new line anchors. Unsupported combined
// diffs and malformed/truncated hunks fail; binary changes remain explicit.
NSDictionary *OR6CodexParseDiff(NSString*patch,NSError**error);
NSArray *OR6CodexDiffCommand(NSString*mode,NSString*base);
