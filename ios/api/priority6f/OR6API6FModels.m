#import "OR6API6FModels.h"
#import "OR6API6FPolicy.h"
#import "../priority8/OR6API8Policy.h"

static NSDictionary *D(id value) { return [value isKindOfClass:NSDictionary.class] ? value : nil; }
static id Present(id value) { return value==NSNull.null ? nil : value; }
static BOOL Text(id value,NSUInteger cap) { return [value isKindOfClass:NSString.class] && [value length] && [value length]<=cap; }
static NSString *Name(id value,NSUInteger cap) {
 if (![value isKindOfClass:NSString.class]) return nil;
 NSString *trimmed=[value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
 return Text(trimmed,cap) ? trimmed : nil;
}
static NSString *Label(NSDictionary *value,NSArray *keys,NSString *fallback) {
 for (NSString *key in keys) { NSString *text=Name(value[key],240); if (text) return text; }
 return fallback;
}
static id Fail(NSError **error,NSString *code) { if (error) *error=OR6APIError(code,@"none"); return nil; }
static NSArray *Lanes(void) { return @[@"auto",@"instant",@"thinking",@"thinking_mini",@"pro"]; }
static NSArray *Efforts(void) { return @[@"zero",@"min",@"standard",@"extended",@"xhigh",@"max",@"ultra"]; }
static BOOL Bool(id value) { return OR6APISchemaCheck(value,@{@"type":@"boolean"},@{}); }
static BOOL Flag(NSDictionary *value,NSString *key) { return !Present(value[key]) || Bool(value[key]); }
static NSArray *Rows(id value,NSUInteger cap) {
 if (!Present(value)) return @[];
 return [value isKindOfClass:NSArray.class] && [value count]<=cap ? value : nil;
}
static void AddEffort(NSMutableArray *efforts,NSString *identifier,NSString *title) {
 for (NSDictionary *effort in efforts) if ([effort[@"id"] isEqual:identifier]) return;
 [efforts addObject:@{@"id":identifier,@"title":title}];
}

static NSString *CategorySlug(NSDictionary *category) {
 NSString *slug=Name(category[@"default_model"],128);
 if (!slug) for (id value in Rows(category[@"supported_models"],128)) { if (value==NSNull.null) continue; return Name(value,128); }
 return slug;
}
static NSString *PresetSlug(NSDictionary *preset,NSArray *slugs,NSArray *categories) {
 if ([preset[@"lane"] isEqual:@"instant"]) for (id value in categories) {
  NSDictionary *category=D(value); NSString *slug=Name(category[@"default_model"],128);
  if (![category[@"disabled_by_admin"]isEqual:@YES] && [category[@"model_lane"]isEqual:@"auto"] && slug && [slugs containsObject:slug]) return slug;
 }
 return Name(preset[@"model_slug"],128);
}

NSDictionary *OR6API6FModels(id raw,BOOL temporary,NSError **error) {
 NSDictionary *root=D(OR6APIJSONSnapshot(raw,4*1024*1024));
 NSArray *versions=Rows(root[@"versions"],32),*categories=Rows(root[@"categories"],128),*models=Rows(root[@"models"],128),*groups=Rows(root[@"internal_groups"],32);
 if (!root || !versions || !categories || !models || !groups) return Fail(error,@"unknown_wire_shape");
 NSMutableDictionary *bySlug=[NSMutableDictionary dictionary]; NSMutableSet *internal=[NSMutableSet set],*adminBlocked=[NSMutableSet set];
 for (id value in categories) { NSDictionary *category=D(value); if (value==NSNull.null) continue; if (!category || !Flag(category,@"disabled_by_admin")) return Fail(error,@"unknown_wire_shape"); NSString *slug=CategorySlug(category); if ([category[@"disabled_by_admin"]isEqual:@YES] && slug) [adminBlocked addObject:slug]; }
 for (id value in groups) {
  if (value==NSNull.null) continue;
  NSDictionary *group=D(value); NSArray *identifiers=Rows(group[@"model_ids"],128);
  if (!group || !identifiers) return Fail(error,@"unknown_wire_shape");
  for (id value in identifiers) { if (value==NSNull.null) continue; NSString *identifier=Name(value,128); if (!identifier) return Fail(error,@"unknown_wire_shape"); [internal addObject:identifier]; }
 }
 for (id value in models) {
  if (value==NSNull.null) continue;
  NSDictionary *model=D(value); NSString *slug=Name(model[@"slug"],128);
  if (!model || !slug || bySlug[slug] || !Flag(model,@"is_work_mode_model") || !Flag(model,@"configurable_thinking_effort")) return Fail(error,@"unknown_wire_shape");
  NSArray *tags=Rows(model[@"tags"],64); if (!tags) return Fail(error,@"unknown_wire_shape");
  for (id tag in tags) if (!Text(tag,128)) return Fail(error,@"unknown_wire_shape");
  bySlug[slug]=model;
 }
 NSMutableArray *items=[NSMutableArray array],*admission=[NSMutableArray array],*versionOrder=[NSMutableArray array];
 NSMutableDictionary *admitted=[NSMutableDictionary dictionary],*versionSlugs=[NSMutableDictionary dictionary]; NSMutableSet *families=[NSMutableSet set]; NSString *presetDefault=nil;
 for (id value in versions) {
  if (value==NSNull.null) continue;
  NSDictionary *version=D(value); NSString *family=Name(version[@"id"],128);
  NSArray *rawSlugs=Rows(version[@"slugs"],128),*rawPresets=Rows(version[@"intelligence_presets"],64);
  if (!version || !family || [families containsObject:family] || !rawSlugs || !rawPresets || !Flag(version,@"disabled") || !Flag(version,@"enabled")) return Fail(error,@"unknown_wire_shape");
  [families addObject:family];
  if ([version[@"disabled"] isEqual:@YES] || [version[@"enabled"] isEqual:@NO]) continue;
  NSMutableArray *slugs=[NSMutableArray array],*presets=[NSMutableArray array];
  BOOL historyOff=NO;
  for (id value in rawSlugs) {
   if (value==NSNull.null) continue;
   NSString *slug=Name(value,128); if (!slug) return Fail(error,@"unknown_wire_shape");
   [slugs addObject:slug]; if ([Rows(bySlug[slug][@"tags"],64) containsObject:@"history_off_approved"]) historyOff=YES;
  }
  if (slugs.count && (!temporary || historyOff)) [versionOrder addObject:family];
  for (id value in rawPresets) {
   // TFzY's nullable/catch schema drops invalid preset records. An absent or
   // null preset_type is the original default, not an unavailable preset.
   NSDictionary *preset=D(value); if (preset && Name(preset[@"model_slug"],128)) [presets addObject:preset];
  }
  // TFzY.S supplies this exact legacy version option when presets are absent.
  if (!presets.count && [family isEqual:@"o3"] && [slugs containsObject:@"o3"])
   [presets addObject:@{@"lane":@"thinking",@"model_slug":@"o3",@"title":@"Medium"}];
  if (!presetDefault && presets.count) presetDefault=PresetSlug(presets[0],slugs,categories);
  versionSlugs[family]=slugs;
  NSMutableArray *choices=[[categories mutableCopy]autorelease]; NSMutableSet *candidateSlugs=[NSMutableSet setWithArray:slugs];
  for (NSDictionary *preset in presets) {
   NSString *slug=PresetSlug(preset,slugs,categories),*lane=Name(preset[@"lane"],128);
   if (!slug || ![Lanes() containsObject:lane?:@""]) continue;
   if ([lane isEqual:@"instant"] && ![slug isEqual:Name(preset[@"model_slug"],128)]) lane=@"auto";
   [candidateSlugs addObject:slug]; BOOL exists=NO,blocked=NO;
   for (id value in categories) {
    NSDictionary *category=D(value); if (!category) continue;
    NSString *known=CategorySlug(category);
    if ([category[@"disabled_by_admin"]isEqual:@YES] && ([known isEqual:slug] || [Rows(category[@"supported_models"],128) containsObject:slug])) blocked=YES;
    if ([known isEqual:slug] && [category[@"model_lane"]isEqual:lane]) exists=YES;
   }
   // TFzY.M gets its model/lane directly from a preset even when no matching
   // category exists. This is an internal projection, not a fabricated wire row.
   if (!exists && !blocked) [choices addObject:@{@"default_model":slug,@"model_lane":lane,@"supported_models":@[slug],@"title":Label(preset,@[@"title"],lane)}];
  }
  NSString *familyTitle=Label(version,@[@"display_text_for_intelligence",@"display_text",@"display_text_full"],family);
  NSMutableSet *seen=[NSMutableSet set];
  for (id value in choices) {
   if (value==NSNull.null) continue;
   NSDictionary *category=D(value); if (!category || !Flag(category,@"disabled_by_admin")) return Fail(error,@"unknown_wire_shape");
   if ([category[@"disabled_by_admin"] isEqual:@YES]) continue;
   NSArray *supported=Rows(category[@"supported_models"],128); if (!supported) return Fail(error,@"unknown_wire_shape");
   NSString *slug=Name(category[@"default_model"],128),*lane=Name(category[@"model_lane"],128);
   // TFzY.P: a null default falls back to the first non-null supported model.
   if (!slug) for (id value in supported) { if (value==NSNull.null) continue; slug=Name(value,128); if (!slug) return Fail(error,@"unknown_wire_shape"); break; }
   if (!slug || ![Lanes() containsObject:lane?:@""] || ![candidateSlugs containsObject:slug] || [seen containsObject:[NSString stringWithFormat:@"%@:%@",slug,lane]]) continue;
   NSDictionary *model=bySlug[slug]; NSArray *tags=Rows(model[@"tags"],64);
   if (!model || [model[@"is_work_mode_model"] isEqual:@YES] || [adminBlocked containsObject:slug] || [internal containsObject:slug] || [tags containsObject:@"hidden"] || (temporary && ![tags containsObject:@"history_off_approved"])) continue;
   BOOL available=presets.count==0; NSMutableArray *allowed=[NSMutableArray array];
   for (NSDictionary *preset in presets) {
    id kind=Present(preset[@"preset_type"]); if (kind && ![kind isEqual:@"available"]) continue;
    NSString *presetLane=Name(preset[@"lane"],128),*presetSlug=Name(preset[@"model_slug"],128);
    BOOL match=[presetSlug isEqual:slug] && (!presetLane || [presetLane isEqual:lane]);
    // TFzY.M collapses the Instant preset onto the version's auto category;
    // mNEt independently selects the explicit Instant category for Auto-off.
    if (([lane isEqual:@"auto"] || [lane isEqual:@"instant"]) && [presetLane isEqual:@"instant"]) match=YES;
    if (!match) continue;
    available=YES; id effort=Present(preset[@"thinking_effort"]);
    if (![Efforts() containsObject:effort?:@""]) continue;
    // A fixed preset is itself the source admission. Slider configurability
    // and model.thinking_efforts do not veto TFzY.M's preset thinking_effort.
    AddEffort(allowed,effort,Label(preset,@[@"title"],effort));
   }
   if (!available) continue;
   [seen addObject:[NSString stringWithFormat:@"%@:%@",slug,lane]];
   NSString *title=Label(model,@[@"title"],slug),*modeTitle=Label(category,@[@"human_category_name",@"title",@"human_category_short_name"],lane);
   id defaultEffort=Present(model[@"default_thinking_effort"]); BOOL known=NO;
   for (NSDictionary *effort in allowed) if ([effort[@"id"] isEqual:defaultEffort]) known=YES;
   if (!known) defaultEffort=NSNull.null;
   NSDictionary *item=@{@"id":slug,@"title":title,@"familyId":family,@"familyTitle":familyTitle,@"lane":lane,@"efforts":allowed,@"defaultEffort":defaultEffort};
   [items addObject:item]; if (items.count>128) return Fail(error,@"size_limit");
   NSMutableDictionary *existing=admitted[slug];
   if (!existing) {
    existing=[NSMutableDictionary dictionaryWithDictionary:@{@"id":slug,@"title":title,@"capabilities":@[],@"familyId":family,@"familyTitle":familyTitle,@"modeId":lane,@"modeTitle":modeTitle,@"efforts":[NSMutableArray array],@"defaultEffort":defaultEffort}];
    admitted[slug]=existing; [admission addObject:existing]; if (admission.count>100) return Fail(error,@"size_limit");
   }
   // LocalProvider admits by slug, so every source-admitted version must share
   // the union of advertised efforts while each version DTO remains exact.
   for (NSDictionary *effort in allowed) AddEffort(existing[@"efforts"],effort[@"id"],effort[@"title"]);
  }
 }
 // TFzY.p chooses the first preset option, then the reversed category
 // projection, then the raw model map. Do not replace this with DTO row order.
 NSString *defaultModel=Name(root[@"default_model_slug"],128) ?: presetDefault;
 if (!defaultModel) for (id value in categories.reverseObjectEnumerator) { NSDictionary *category=D(value); if ([category[@"disabled_by_admin"]isEqual:@YES]) continue; defaultModel=CategorySlug(category); if (defaultModel) break; }
 if (!defaultModel) for (id value in models) { defaultModel=Name(D(value)[@"slug"],128); if (defaultModel) break; }
 if (!defaultModel) defaultModel=@"auto"; // Exact TFzY fallback; never admitted without a real source row.
 return OR6APIJSONSnapshot(@{@"dto":@{@"items":items},@"items":items,@"admission":@{@"items":admission,@"selectedModelId":NSNull.null},@"defaultModelId":defaultModel,@"versionOrder":versionOrder,@"versionSlugs":versionSlugs,@"temporary":@(temporary)},1024*1024);
}

static BOOL AllowsEffort(NSDictionary *item,id effort) {
 if (!effort) return YES;
 for (NSDictionary *candidate in item[@"efforts"]) if ([candidate[@"id"]isEqual:effort]) return YES;
 return NO;
}
static NSDictionary *FindItem(NSArray *items,NSString *family,NSString *lane,id effort,NSArray *slugs) {
 if (slugs) {
  for (NSString *slug in slugs) for (NSDictionary *item in items) if ([item[@"id"]isEqual:slug] && [item[@"familyId"]isEqual:family] && [item[@"lane"]isEqual:lane] && AllowsEffort(item,effort)) return item;
 } else for (NSDictionary *item in items) if ([item[@"familyId"]isEqual:family] && [item[@"lane"]isEqual:lane] && AllowsEffort(item,effort)) return item;
 return nil;
}

NSDictionary *OR6API6FResolveModel(NSDictionary *graph,NSDictionary *parameters,BOOL prefersAuto,BOOL paidEligible,NSError **error) {
 NSArray *items=Rows(D(graph)[@"items"],128); if (!D(graph) || !D(parameters) || !items || !Bool(graph[@"temporary"])) return Fail(error,@"unknown_wire_shape");
 NSDictionary *selected=nil; NSString *family=Present(parameters[@"versionId"]),*lane=Present(parameters[@"lane"]); id effort=Present(parameters[@"thinkingEffort"]);
 if (family) {
  if (!Text(family,128) || ![Lanes() containsObject:lane?:@""]) return Fail(error,@"invalid_request");
  NSArray *slugs=([lane isEqual:@"auto"]||[lane isEqual:@"instant"])?Rows(D(graph[@"versionSlugs"])[family],128):nil;
  selected=FindItem(items,family,lane,effort,slugs);
 } else {
  // mNEt uses the first eligible source version, not the first surviving lane
  // from a later version. If that version has no desired lane, use the default.
  NSArray *order=Rows(graph[@"versionOrder"],32); NSString *first=order.count?order[0]:(items.count?D(items[0])[@"familyId"]:nil);
  if (paidEligible && first) selected=FindItem(items,first,prefersAuto?@"auto":@"instant",nil,Rows(D(graph[@"versionSlugs"])[first],128));
  if (!selected) for (NSDictionary *item in items) if ([item[@"id"] isEqual:graph[@"defaultModelId"]]) { if (!selected || [item[@"familyId"] isEqual:@"latest"]) selected=item; }
 }
 if (!selected) return Fail(error,@"capability_unavailable");
 if (effort) { BOOL admitted=NO; for (NSDictionary *item in selected[@"efforts"]) if ([item[@"id"] isEqual:effort]) admitted=YES; if (!admitted) return Fail(error,@"capability_unavailable"); }
 return @{@"modelId":selected[@"id"],@"familyId":selected[@"familyId"],@"lane":selected[@"lane"],@"thinkingEffort":effort?:(id)NSNull.null,@"temporary":graph[@"temporary"]};
}

NSDictionary *OR6API6FModelPlan(NSDictionary *selection,NSDictionary *parameters,NSError **error) {
 if (!D(selection) || !D(parameters) || !OR6API6FUUID(parameters[@"operationId"]) || !OR6API6FUUID(parameters[@"draftId"]) || !OR6API6FUUID(parameters[@"parentMessageId"]) || !Text(selection[@"modelId"],128) || !Bool(selection[@"temporary"]) || !Text(parameters[@"text"],16000)) return Fail(error,@"invalid_request");
 id effort=Present(selection[@"thinkingEffort"]); if (effort && ![Efforts() containsObject:effort]) return Fail(error,@"invalid_request");
 NSMutableDictionary *params=[NSMutableDictionary dictionaryWithDictionary:@{@"operationId":parameters[@"operationId"],@"draftId":parameters[@"draftId"],@"parentMessageId":parameters[@"parentMessageId"],@"text":parameters[@"text"],@"modelId":selection[@"modelId"],@"temporary":selection[@"temporary"],@"thinkingEffort":effort?:(id)NSNull.null,@"attachments":@[]}];
 id conversation=Present(parameters[@"conversationId"]); if (conversation) { if (!OR6API6FUUID(conversation)) return Fail(error,@"invalid_request"); params[@"conversationId"]=conversation; }
 return OR6API8Plan(@"messages.send",params,nil,selection[@"modelId"],@[],error);
}
