#import "../OR6APICore.h"
// Canonical TFzY/mNEt source contracts: nullable labels, optional availability,
// fixed preset efforts and the explicit Instant alternative for Auto-off.
// Private graph metadata retains source version order. DTOs remain closed;
// downstream ModelCatalog admission merges efforts for any shared model slug.
NSDictionary *OR6API6FModels(id raw,BOOL temporary,NSError **error);
NSDictionary *OR6API6FResolveModel(NSDictionary *graph,NSDictionary *selection,BOOL prefersAuto,BOOL paidPersonal,NSError **error);
NSDictionary *OR6API6FModelPlan(NSDictionary *selection,NSDictionary *parameters,NSError **error);
