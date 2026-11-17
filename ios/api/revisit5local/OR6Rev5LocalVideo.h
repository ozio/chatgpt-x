#import "../OR6APICore.h"
// Native codec probe. An extensionless vault file is copied into a private,
// bounded .mov decoder file; no user source is mutated. No player or permission
// request is created and external media references are forbidden.
NSDictionary *OR6Rev5LocalInspectVideo(NSURL *URL,NSError **error);
// Native adapters only; caller releases this private decoder copy explicitly.
NSURL *OR6Rev5LocalMovieCopy(NSURL *URL,NSError **error);
void OR6Rev5LocalReleaseMovieCopy(NSURL *URL);
