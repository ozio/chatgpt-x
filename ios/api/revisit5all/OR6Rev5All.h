#import "../revisit67all/OR6Rev67All.h"
#import "../priority5all/OR6API5AllComposition.h"
// Source-backed explicit API admission; each provider retains exact private
// identity, policy, fresh permission/catalog and durable operation guards.
NSDictionary *OR6Rev5LegacyCapabilities(NSDictionary *extensions);
NSDictionary *OR6Rev5LegacyTiers(NSDictionary *extensions);
@interface OR6Rev5AllCore:OR6Rev67AllCore
- (void)setLiveContextSource:(NSDictionary*(^)(void))source;
@end
@class OR6Rev5Host,OR6API5EProvider;
@interface OR6Rev5FamilyPolicy:NSObject<OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next HTTP:(id<OR6API7HTTP>)HTTP registry:(NSDictionary*)registry family:(OR6API5EProvider*)family;
- (BOOL)bindIdentity:(NSDictionary*)identity context:(NSDictionary*)context;
- (void)deactivate;
- (NSDictionary*)diagnostics;
@end
@interface OR6Rev5Observer:NSObject<OR6APIProvider>
- (id)initWithNext:(id<OR6APIProvider>)next adapter:(OR6APIWebAdapter*)adapter host:(OR6Rev5Host*)host;
- (void)setWorkspaceChanged:(void(^)(void))changed;
- (void)setAudioWillStart:(void(^)(void))callback;
- (void)setWorkspaceAllowed:(BOOL(^)(void))allowed;
- (void)setAssetDidValidate:(void(^)(NSString*,NSDictionary*,NSDictionary*))observer;
@end
NSDictionary *OR6Rev5AllRegistry(NSDictionary *base,NSError **error);
NSDictionary *OR6Rev5AllTiers(void);
