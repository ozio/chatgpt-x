#import <Foundation/Foundation.h>

extern NSString * const OR6FilesErrorDomain;

// Synchronous, MRC, Foundation-only local asset vault. All instances serialize
// operations in-process and flock the vault across processes. Never starts I/O
// to a service or deletes an import's source. Only cache assets are ever evicted.
//
// Cache assets (-importCacheURL:) are re-fetchable copies such as downloads. An
// import of identical bytes returns the existing cache asset. When any import
// needs room in the count/byte budget, or the device would keep less than
// 100 MiB free, cache assets are removed least recently used first (a URL
// lookup counts as a use). Ordinary imports and recordings are never evicted;
// their owners remove them explicitly. A cache asset's ID can therefore vanish:
// owners treat a missing cache asset as "fetch again".
//
// directory and inbox must be sibling MediaFiles-v1 and Inbox directories in an
// existing app-owned Documents directory. Only those two directories are created.
// Recording imports come from the sibling MediaAudio-v1/<lowercase UUID>.wav;
// OR6Audio reserves that name for a verified, finalized recording.
//
// Descriptors are immutable {id,name,mediaType,bytes,sha256}. Names are display
// data only. URLs always use generated UUID paths. URL lookup streams and hashes
// the entire bounded payload before returning it; use that URL promptly and do
// not mutate vault files. The caller owns selection/journal references and must
// arrange an explicit removal only when those references permit it.
//
// A failed durability step can leave a committed import. Such an NSError has
// code 6 and userInfo.assetID. Enumerate/reconcile it; never retry automatically.
@interface OR6Files : NSObject {
    NSString *_directory, *_inbox, *_inboxInput, *_recordings, *_recordingsInput, *_parent;
    unsigned long long _parentDevice, _parentInode, _directoryDevice, _directoryInode, _inboxDevice, _inboxInode;
    unsigned long long _fileBytes, _totalBytes;
    NSUInteger _assetCount;
    int _directoryFD, _lockFD;
}
- (id)initWithDirectory:(NSString *)directory inbox:(NSString *)inbox error:(NSError **)error;
// Isolated tests may LOWER fileBytes/totalBytes/assetCount only. Production
// maxima are 8 MiB/file, 256 MiB total retained/staging bytes, 256 retained assets.
- (id)initWithDirectory:(NSString *)directory inbox:(NSString *)inbox limits:(NSDictionary *)limits error:(NSError **)error;
- (NSDictionary *)importInboxURL:(NSURL *)url error:(NSError **)error;
- (NSDictionary *)importCacheURL:(NSURL *)url error:(NSError **)error;
- (NSDictionary *)importRecordingURL:(NSURL *)url error:(NSError **)error;
- (NSArray *)assets;
// Unlike the convenience method above (which returns [] on failure), this
// returns nil plus an error when ownership, metadata or capacity is invalid.
- (NSArray *)assetsWithError:(NSError **)error;
- (NSDictionary *)assetForID:(NSString *)identifier error:(NSError **)error;
- (NSURL *)URLForAssetID:(NSString *)identifier error:(NSError **)error;
- (BOOL)removeAssetID:(NSString *)identifier error:(NSError **)error;
// Makes an existing asset a cache asset (idempotent): for owners adopting re-fetchable copies
// imported before -importCacheURL: existed. Never the reverse.
- (BOOL)markCacheAssetID:(NSString *)identifier error:(NSError **)error;
@end

// Isolated offline validation; creates a fresh child under the supplied existing
// directory. Does not use hardware or the network and never exits its caller.
NSDictionary *OR6FilesSelfTest(NSString *directory);
