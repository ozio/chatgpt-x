#import "OR6Files.h"
#import <CommonCrypto/CommonDigest.h>
#include <sys/stat.h>
#include <sys/file.h>
#include <sys/mount.h>
#include <sys/time.h>
#include <fcntl.h>
#include <unistd.h>
#include <dirent.h>
#include <errno.h>
#include <limits.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

NSString * const OR6FilesErrorDomain = @"OR6Files";
static const unsigned long long OR6FileMaximum = 8ULL * 1024 * 1024;
static const unsigned long long OR6TotalMaximum = 256ULL * 1024 * 1024;
static const NSUInteger OR6CountMaximum = 256;
// Cache assets (re-fetchable downloads) are evicted least recently used first when an import needs room
// or the device keeps less than this free after the import.
static const unsigned long long OR6DiskReserve = 100ULL * 1024 * 1024;

static BOOL OR6Fail(NSError **error, NSInteger code, NSString *reason) {
    if (error) *error=[NSError errorWithDomain:OR6FilesErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey:reason}];
    return NO;
}
static BOOL OR6ID(NSString *value) {
    if (![value isKindOfClass:NSString.class] || value.length!=36) return NO;
    for (NSUInteger i=0;i<36;i++) {
        unichar c=[value characterAtIndex:i];
        if (i==8 || i==13 || i==18 || i==23) {if (c!='-') return NO;}
        else if (!((c>='0' && c<='9') || (c>='a' && c<='f'))) return NO;
    }
    return YES;
}
static NSString *OR6UUID(void) {
    CFUUIDRef uuid=CFUUIDCreate(NULL);
    NSString *value=[[(NSString *)CFUUIDCreateString(NULL,uuid) autorelease] lowercaseString];
    CFRelease(uuid);return value;
}
static BOOL OR6SafeName(NSString *name) {
    if (![name isKindOfClass:NSString.class] || !name.length || [name isEqual:@"."] || [name isEqual:@".."]
        || [name lengthOfBytesUsingEncoding:NSUTF8StringEncoding]>240) return NO;
    if ([name rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location!=NSNotFound
        || [name rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/\\:"]].location!=NSNotFound) return NO;
    return [name canBeConvertedToEncoding:NSUTF8StringEncoding];
}
static BOOL OR6AbsolutePath(NSString *path) {
    if (![path isKindOfClass:NSString.class] || !path.isAbsolutePath || !path.length
        || [path rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location!=NSNotFound) return NO;
    for (NSString *part in path.pathComponents) if ([part isEqual:@".."] || [part isEqual:@"."]) return NO;
    return YES;
}
static BOOL OR6SameStat(struct stat a, struct stat b) {
    return a.st_dev==b.st_dev && a.st_ino==b.st_ino && a.st_size==b.st_size && a.st_nlink==b.st_nlink
        && a.st_mtimespec.tv_sec==b.st_mtimespec.tv_sec && a.st_mtimespec.tv_nsec==b.st_mtimespec.tv_nsec
        && a.st_ctimespec.tv_sec==b.st_ctimespec.tv_sec && a.st_ctimespec.tv_nsec==b.st_ctimespec.tv_nsec;
}
static BOOL OR6Regular(struct stat st) {return S_ISREG(st.st_mode) && st.st_nlink==1 && st.st_uid==getuid() && st.st_size>=0;}
static int OR6OpenRegular(NSString *path, struct stat *state) {
    struct stat before,after;
    if (lstat(path.fileSystemRepresentation,&before) || !OR6Regular(before)) return -1;
    int fd=open(path.fileSystemRepresentation,O_RDONLY|O_NOFOLLOW|O_NONBLOCK);
    if (fd<0) return -1;
    if (fstat(fd,&after) || !OR6Regular(after) || !OR6SameStat(before,after)) {close(fd);return -1;}
    if (state) *state=after;return fd;
}
static BOOL OR6WriteAll(int fd, const void *buffer, size_t length) {
    const unsigned char *bytes=buffer;
    while (length) {ssize_t n=write(fd,bytes,length);if (n<0 && errno==EINTR) continue;if (n<=0) return NO;bytes+=n;length-=(size_t)n;}
    return YES;
}
static BOOL OR6Directory(NSString *path, BOOL create, struct stat *state) {
    struct stat st;
    if (lstat(path.fileSystemRepresentation,&st)) {
        if (errno!=ENOENT || !create || mkdir(path.fileSystemRepresentation,0700)) return NO;
        if (lstat(path.fileSystemRepresentation,&st)) return NO;
    }
    if (!S_ISDIR(st.st_mode) || st.st_uid!=getuid() || (st.st_mode&0022)) return NO;
    if (state) *state=st;return YES;
}
static NSDictionary *OR6ReadMetadata(NSString *path) {
    struct stat st;int fd=OR6OpenRegular(path,&st);
    if (fd<0) return nil;
    if (st.st_size<=0 || st.st_size>8192) {close(fd);return nil;}
    unsigned char buffer[8192];size_t used=0;BOOL ok=YES;
    while (used<(size_t)st.st_size) {ssize_t n=read(fd,buffer+used,(size_t)st.st_size-used);if (n<0 && errno==EINTR) continue;if (n<=0) {ok=NO;break;}used+=(size_t)n;}
    struct stat after;unsigned char extra;
    if (fstat(fd,&after) || !OR6SameStat(st,after) || read(fd,&extra,1)!=0) ok=NO;
    if (close(fd)) ok=NO;
    if (!ok) return nil;
    // NSData is strictly bounded metadata, never an asset payload.
    NSData *data=[NSData dataWithBytes:buffer length:used];
    id value=[NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];
    return [value isKindOfClass:NSDictionary.class] ? value : nil;
}
static BOOL OR6WriteMetadata(NSString *path, NSDictionary *value, BOOL *created) {
    if (created) *created=NO;
    NSData *data=[NSPropertyListSerialization dataWithPropertyList:value format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
    if (!data || data.length>8192) return NO;
    int fd=open(path.fileSystemRepresentation,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600);
    if (fd<0) return NO;
    if (created) *created=YES;
    BOOL ok=OR6WriteAll(fd,data.bytes,data.length) && fsync(fd)==0;
    if (close(fd)) ok=NO;
    return ok;
}
typedef struct {unsigned need,code,minimum;BOOL valid;} OR6TextState;
static void OR6TextByte(OR6TextState *s, unsigned char c) {
    if (!s->valid) return;
    if (s->need) {
        if ((c&0xc0)!=0x80) {s->valid=NO;return;}
        s->code=(s->code<<6)|(c&63);s->need--;
        if (!s->need && (s->code<s->minimum || s->code>0x10ffff || (s->code>=0xd800 && s->code<=0xdfff)
            || (s->code>=0x7f && s->code<=0x9f))) s->valid=NO;
    } else if (c<128) {if ((c<32 && c!=9 && c!=10 && c!=13) || c==127) s->valid=NO;}
    else if (c>=0xc2 && c<=0xdf) {s->need=1;s->code=c&31;s->minimum=0x80;}
    else if (c>=0xe0 && c<=0xef) {s->need=2;s->code=c&15;s->minimum=0x800;}
    else if (c>=0xf0 && c<=0xf4) {s->need=3;s->code=c&7;s->minimum=0x10000;}
    else s->valid=NO;
}
static NSString *OR6MediaType(const unsigned char *p, size_t n, BOOL text) {
    const unsigned char png[]={137,80,78,71,13,10,26,10};
    if (n>=8 && !memcmp(p,png,8)) return @"image/png";
    if (n>=3 && p[0]==255 && p[1]==216 && p[2]==255) return @"image/jpeg";
    if (n>=5 && !memcmp(p,"%PDF-",5)) return @"application/pdf";
    if (n>=12 && !memcmp(p,"RIFF",4) && !memcmp(p+8,"WAVE",4)) return @"audio/wav";
    if (n>=12 && !memcmp(p+4,"ftyp",4)) {
        unsigned long size=((unsigned long)p[0]<<24)|((unsigned long)p[1]<<16)|((unsigned long)p[2]<<8)|p[3];
        if (size>=12 && size<=n && !memcmp(p+8,"M4A ",4)) return @"audio/mp4";
    }
    // HTML remains an inert file; callers must never render any vault file in a web view.
    return text ? @"text/plain" : @"application/octet-stream";
}
static NSDictionary *OR6Stream(int source, int destination, unsigned long long maximum, NSError **error) {
    CC_SHA256_CTX hash;CC_SHA256_Init(&hash);
    unsigned char buffer[32768],prefix[64];size_t prefixLength=0;unsigned long long total=0;
    OR6TextState text={0,0,0,YES};
    for (;;) {
        ssize_t n=read(source,buffer,sizeof(buffer));if (n<0 && errno==EINTR) continue;
        if (n<0) {OR6Fail(error,3,@"files.read");return nil;}if (!n) break;
        if ((unsigned long long)n>maximum-total) {OR6Fail(error,5,@"files.file_limit");return nil;}
        total+=(unsigned long long)n;
        if (prefixLength<sizeof(prefix)) {size_t take=MIN((size_t)n,sizeof(prefix)-prefixLength);memcpy(prefix+prefixLength,buffer,take);prefixLength+=take;}
        for (ssize_t i=0;i<n;i++) OR6TextByte(&text,buffer[i]);
        CC_SHA256_Update(&hash,buffer,(CC_LONG)n);
        if (destination>=0 && !OR6WriteAll(destination,buffer,(size_t)n)) {OR6Fail(error,3,@"files.write");return nil;}
    }
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];CC_SHA256_Final(digest,&hash);
    char hex[65];for (NSUInteger i=0;i<sizeof(digest);i++) snprintf(hex+2*i,3,"%02x",digest[i]);hex[64]=0;
    return @{@"bytes":@(total),@"sha256":[NSString stringWithUTF8String:hex],@"mediaType":OR6MediaType(prefix,prefixLength,text.valid && !text.need)};
}

@interface OR6Files ()
- (BOOL)begin:(NSError **)error;
- (void)end;
- (BOOL)recover:(NSError **)error;
- (NSArray *)records:(NSError **)error;
@end

@implementation OR6Files
- (id)initWithDirectory:(NSString *)directory inbox:(NSString *)inbox error:(NSError **)error {
    return [self initWithDirectory:directory inbox:inbox limits:nil error:error];
}
- (id)initWithDirectory:(NSString *)directory inbox:(NSString *)inbox limits:(NSDictionary *)limits error:(NSError **)error {
    if (error) *error=nil;
    if ((self=[super init])) {
        _directoryFD=-1;_lockFD=-1;_fileBytes=OR6FileMaximum;_totalBytes=OR6TotalMaximum;_assetCount=OR6CountMaximum;
        @synchronized(OR6Files.class) {
            if (!OR6AbsolutePath(directory) || !OR6AbsolutePath(inbox) || ![directory.lastPathComponent isEqual:@"MediaFiles-v1"]
                || ![inbox.lastPathComponent isEqual:@"Inbox"] || ![directory.stringByDeletingLastPathComponent isEqual:inbox.stringByDeletingLastPathComponent]) {
                OR6Fail(error,1,@"files.roots");[self release];return nil;
            }
            if (limits && ![limits isKindOfClass:NSDictionary.class]) {OR6Fail(error,1,@"files.limits");[self release];return nil;}
            for (NSString *key in limits) {
                NSNumber *number=limits[key];unsigned long long max=[key isEqual:@"fileBytes"] ? OR6FileMaximum : ([key isEqual:@"totalBytes"] ? OR6TotalMaximum : ([key isEqual:@"assetCount"] ? OR6CountMaximum : 0));
                if (![number isKindOfClass:NSNumber.class] || number.doubleValue<1 || number.doubleValue>(double)max || number.doubleValue!=(double)number.unsignedLongLongValue) {
                    OR6Fail(error,1,@"files.limits");[self release];return nil;
                }
                if ([key isEqual:@"fileBytes"]) _fileBytes=number.unsignedLongLongValue;
                if ([key isEqual:@"totalBytes"]) _totalBytes=number.unsignedLongLongValue;
                if ([key isEqual:@"assetCount"]) _assetCount=number.unsignedIntegerValue;
            }
            char canonical[PATH_MAX];
            if (!realpath(directory.stringByDeletingLastPathComponent.fileSystemRepresentation,canonical)) {OR6Fail(error,2,@"files.parent");[self release];return nil;}
            _parent=[[NSString stringWithUTF8String:canonical] copy];struct stat parent,dir,box;
            _directory=[[_parent stringByAppendingPathComponent:@"MediaFiles-v1"] copy];
            _inbox=[[_parent stringByAppendingPathComponent:@"Inbox"] copy];_inboxInput=[inbox copy];
            _recordings=[[_parent stringByAppendingPathComponent:@"MediaAudio-v1"] copy];
            _recordingsInput=[[directory.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"MediaAudio-v1"] copy];
            if (!OR6Directory(_parent,NO,&parent) || !OR6Directory(_directory,YES,&dir) || !OR6Directory(_inbox,YES,&box)) {
                OR6Fail(error,2,@"files.directory");[self release];return nil;
            }
            _parentDevice=parent.st_dev;_parentInode=parent.st_ino;_directoryDevice=dir.st_dev;_directoryInode=dir.st_ino;_inboxDevice=box.st_dev;_inboxInode=box.st_ino;
            _directoryFD=open(_directory.fileSystemRepresentation,O_RDONLY|O_NOFOLLOW|O_NONBLOCK);
            int parentFD=open(_parent.fileSystemRepresentation,O_RDONLY|O_NOFOLLOW|O_NONBLOCK);
            BOOL parentSynced=parentFD>=0 && fsync(parentFD)==0;
            if (parentFD>=0 && close(parentFD)) parentSynced=NO;
            NSString *lock=[_directory stringByAppendingPathComponent:@".or6files.lock"];
            _lockFD=open(lock.fileSystemRepresentation,O_RDWR|O_CREAT|O_EXCL|O_NOFOLLOW,0600);
            if (_lockFD<0 && errno==EEXIST) _lockFD=OR6OpenRegular(lock,NULL);
            struct stat locked;
            if (!parentSynced || _directoryFD<0 || _lockFD<0 || fstat(_lockFD,&locked) || !OR6Regular(locked) || fsync(_directoryFD) || ![self begin:error]) {
                if (!error || !*error) OR6Fail(error,3,@"files.lock");[self release];return nil;
            }
            BOOL ok=[self recover:error] && [self records:error]!=nil;
            [self end];if (!ok) {[self release];return nil;}
        }
    }
    return self;
}
- (NSString *)path:(NSString *)identifier suffix:(NSString *)suffix {return [_directory stringByAppendingPathComponent:[identifier stringByAppendingString:suffix]];}
- (NSString *)transaction:(NSString *)identifier {return [_directory stringByAppendingPathComponent:[NSString stringWithFormat:@".txn-%@.plist",identifier]];}
- (BOOL)prepareTransaction:(NSString *)identifier operation:(NSString *)operation error:(NSError **)error {
    NSString *temporary=[self path:identifier suffix:@".transaction-partial"],*final=[self transaction:identifier];
    struct stat st;if (!lstat(final.fileSystemRepresentation,&st) || errno!=ENOENT) return OR6Fail(error,4,@"files.transaction_exists");
    BOOL created=NO;
    BOOL ok=OR6WriteMetadata(temporary,@{@"version":@1,@"id":identifier,@"operation":operation},&created);
    if (ok) ok=!rename(temporary.fileSystemRepresentation,final.fileSystemRepresentation);
    if (!ok && created) [self unlinkOwned:temporary error:NULL];
    if (!ok || fsync(_directoryFD)) return OR6Fail(error,3,@"files.prepare");
    return YES;
}
- (BOOL)roots:(NSError **)error {
    struct stat parent,dir,box,fd,pathLock,fdLock;
    NSString *lock=[_directory stringByAppendingPathComponent:@".or6files.lock"];
    BOOL ok=OR6Directory(_parent,NO,&parent) && OR6Directory(_directory,NO,&dir) && OR6Directory(_inbox,NO,&box)
        && (unsigned long long)parent.st_dev==_parentDevice && parent.st_ino==_parentInode && (unsigned long long)dir.st_dev==_directoryDevice && dir.st_ino==_directoryInode
        && (unsigned long long)box.st_dev==_inboxDevice && box.st_ino==_inboxInode && !fstat(_directoryFD,&fd) && fd.st_dev==dir.st_dev && fd.st_ino==dir.st_ino
        && !lstat(lock.fileSystemRepresentation,&pathLock) && !fstat(_lockFD,&fdLock) && OR6Regular(pathLock) && OR6Regular(fdLock)
        && pathLock.st_dev==fdLock.st_dev && pathLock.st_ino==fdLock.st_ino;
    return ok || OR6Fail(error,2,@"files.root_changed");
}
- (BOOL)begin:(NSError **)error {
    if (![self roots:error]) return NO;
    int status;do {status=flock(_lockFD,LOCK_EX);} while (status<0 && errno==EINTR);
    if (status) return OR6Fail(error,3,@"files.lock");
    if (![self roots:error]) {[self end];return NO;}return YES;
}
- (void)end {flock(_lockFD,LOCK_UN);}
- (NSArray *)names:(NSError **)error {
    DIR *dir=opendir(_directory.fileSystemRepresentation);if (!dir) {OR6Fail(error,3,@"files.list");return nil;}
    NSMutableArray *names=[NSMutableArray array];struct dirent *entry;BOOL ok=YES;errno=0;
    while ((entry=readdir(dir))) {
        if (!strcmp(entry->d_name,".") || !strcmp(entry->d_name,"..")) continue;
        NSString *name=[NSString stringWithUTF8String:entry->d_name];
        if (!name || names.count>=1024) {ok=NO;break;}[names addObject:name];errno=0;
    }
    if (errno) ok=NO;if (closedir(dir)) ok=NO;
    if (!ok) {OR6Fail(error,4,@"files.directory_entries");return nil;}return names;
}
- (NSDictionary *)descriptor:(NSString *)identifier error:(NSError **)error {
    NSDictionary *row=OR6ReadMetadata([self path:identifier suffix:@".plist"]);
    NSString *hash=row[@"sha256"],*type=row[@"mediaType"];NSNumber *bytes=row[@"bytes"];
    NSCharacterSet *hex=[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"];
    BOOL valid=row.count==5 && [row[@"id"] isEqual:identifier] && OR6SafeName(row[@"name"])
        && [hash isKindOfClass:NSString.class] && hash.length==64 && [hash rangeOfCharacterFromSet:hex.invertedSet].location==NSNotFound
        && [type isKindOfClass:NSString.class] && [@[@"image/png",@"image/jpeg",@"application/pdf",@"text/plain",@"audio/wav",@"audio/mp4",@"application/octet-stream"] containsObject:type]
        && [bytes isKindOfClass:NSNumber.class] && bytes.doubleValue>=0 && bytes.doubleValue<=(double)OR6FileMaximum && bytes.doubleValue==(double)bytes.unsignedLongLongValue;
    if (!valid) {OR6Fail(error,4,@"files.metadata");return nil;}
    struct stat payload;int fd=OR6OpenRegular([self path:identifier suffix:@".blob"],&payload);
    if (fd<0 || (unsigned long long)payload.st_size!=bytes.unsignedLongLongValue) {if (fd>=0) close(fd);OR6Fail(error,4,@"files.payload");return nil;}
    if (close(fd)) {OR6Fail(error,3,@"files.close");return nil;}
    return [NSDictionary dictionaryWithDictionary:row];
}
- (NSArray *)records:(NSError **)error {
    NSArray *names=[self names:error];if (!names) return nil;
    NSMutableArray *rows=[NSMutableArray array];unsigned long long total=0;
    for (NSString *name in names) {
        if (name.length==42 && [name hasSuffix:@".plist"] && OR6ID([name substringToIndex:36])) {
            NSDictionary *row=[self descriptor:[name substringToIndex:36] error:error];if (!row) return nil;
            unsigned long long bytes=[row[@"bytes"] unsignedLongLongValue];
            if (bytes>_fileBytes || bytes>_totalBytes-total || rows.count>=_assetCount) {OR6Fail(error,5,@"files.capacity");return nil;}
            total+=bytes;[rows addObject:row];
        }
        if (name.length==41 && [name hasSuffix:@".blob"] && OR6ID([name substringToIndex:36])) {
            NSString *meta=[self path:[name substringToIndex:36] suffix:@".plist"];struct stat st;
            if (lstat(meta.fileSystemRepresentation,&st)) {OR6Fail(error,4,@"files.orphan");return nil;}
        }
    }
    return [rows sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES]]];
}
- (BOOL)unlinkOwned:(NSString *)path error:(NSError **)error {
    struct stat st;if (lstat(path.fileSystemRepresentation,&st)) return errno==ENOENT || OR6Fail(error,3,@"files.stat");
    if (!OR6Regular(st)) return OR6Fail(error,2,@"files.cleanup_ownership");
    return !unlink(path.fileSystemRepresentation) || OR6Fail(error,3,@"files.unlink");
}
- (BOOL)recover:(NSError **)error {
    NSArray *names=[self names:error];if (!names) return NO;
    for (NSString *name in names) {
        if ([name hasSuffix:@".transaction-partial"] && name.length==56 && OR6ID([name substringToIndex:36])) {
            // A crash before atomic transaction publication never authorizes
            // touching payloads. Only a complete, recognizable marker is pruned.
            NSString *identifier=[name substringToIndex:36],*path=[_directory stringByAppendingPathComponent:name];
            NSDictionary *row=OR6ReadMetadata(path);
            if (row.count==3 && [row[@"version"] isEqual:@1] && [row[@"id"] isEqual:identifier]
                && [@[@"import",@"remove"] containsObject:row[@"operation"]]) {
                if (![self unlinkOwned:path error:error] || fsync(_directoryFD)) return OR6Fail(error,3,@"files.recovery");
            }
        }
        if (name.length==42 && [name hasSuffix:@".cache"] && OR6ID([name substringToIndex:36])) {
            // A cache marker without its asset (crash during removal) is only a marker: pruned.
            struct stat st;if (lstat([self path:[name substringToIndex:36] suffix:@".plist"].fileSystemRepresentation,&st) && errno==ENOENT
                && ![self unlinkOwned:[_directory stringByAppendingPathComponent:name] error:error]) return NO;
            continue;
        }
        if (![name hasPrefix:@".txn-"]) continue;
        if (name.length!=47 || ![name hasSuffix:@".plist"] || !OR6ID([name substringWithRange:NSMakeRange(5,36)])) return OR6Fail(error,4,@"files.transaction_name");
        NSString *identifier=[name substringWithRange:NSMakeRange(5,36)],*txn=[self transaction:identifier];
        NSDictionary *row=OR6ReadMetadata(txn);NSString *operation=row[@"operation"];
        if (row.count!=3 || ![row[@"version"] isEqual:@1] || ![row[@"id"] isEqual:identifier]
            || ![@[@"import",@"remove"] containsObject:operation]) return OR6Fail(error,4,@"files.transaction");
        NSString *metadata=[self path:identifier suffix:@".plist"];struct stat st;BOOL exists=lstat(metadata.fileSystemRepresentation,&st)==0;
        if (!exists && errno!=ENOENT) return OR6Fail(error,3,@"files.stat");
        if ([operation isEqual:@"import"] && exists) {
            if (![self descriptor:identifier error:error]) return NO;
        } else {
            if (![self unlinkOwned:metadata error:error] || ![self unlinkOwned:[self path:identifier suffix:@".blob"] error:error]
                || ![self unlinkOwned:[self path:identifier suffix:@".cache"] error:error]) return NO;
        }
        if (![self unlinkOwned:[self path:identifier suffix:@".partial"] error:error]
            || ![self unlinkOwned:[self path:identifier suffix:@".metadata-partial"] error:error] || fsync(_directoryFD)) return OR6Fail(error,3,@"files.recovery");
        if (![self unlinkOwned:txn error:error] || fsync(_directoryFD)) return OR6Fail(error,3,@"files.recovery");
    }
    return YES;
}
- (BOOL)isCache:(NSString *)identifier {struct stat st;return !lstat([self path:identifier suffix:@".cache"].fileSystemRepresentation,&st) && OR6Regular(st);}
- (void)touch:(NSString *)identifier {utimes([self path:identifier suffix:@".cache"].fileSystemRepresentation,NULL);}
- (double)usedAt:(NSString *)identifier {struct stat st;return lstat([self path:identifier suffix:@".cache"].fileSystemRepresentation,&st) ? 0 : st.st_mtimespec.tv_sec+st.st_mtimespec.tv_nsec/1e9;}
- (unsigned long long)diskFree {struct statfs fs;return statfs(_directory.fileSystemRepresentation,&fs) ? ULLONG_MAX : (unsigned long long)fs.f_bavail*(unsigned long long)fs.f_bsize;}
// Under the lock: removes cache assets, least recently used first, until `bytes` more fit the count and byte
// budgets and the device keeps OR6DiskReserve free. Other assets are never evicted. Returns the remaining rows.
- (NSArray *)makeRoom:(unsigned long long)bytes rows:(NSArray *)rows error:(NSError **)error {
    unsigned long long total=0;for (NSDictionary *row in rows) total+=[row[@"bytes"] unsignedLongLongValue];
    NSMutableArray *cache=[NSMutableArray array];for (NSDictionary *row in rows) if ([self isCache:row[@"id"]]) [cache addObject:row];
    [cache sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {double x=[self usedAt:a[@"id"]],y=[self usedAt:b[@"id"]];return x<y ? NSOrderedAscending : x>y ? NSOrderedDescending : [a[@"id"] compare:b[@"id"]];}];
    NSUInteger count=rows.count;BOOL removed=NO;
    for (NSDictionary *row in cache) {
        BOOL full=count>=_assetCount || bytes>_totalBytes-MIN(total,_totalBytes),low=[self diskFree]<bytes+OR6DiskReserve;
        if (!full && !low) break;
        if (![self prepareTransaction:row[@"id"] operation:@"remove" error:error] || ![self recover:error]) return nil;
        total-=[row[@"bytes"] unsignedLongLongValue];count--;removed=YES;
    }
    return removed ? [self records:error] : rows;
}
- (NSDictionary *)importURL:(NSURL *)url recording:(BOOL)recording error:(NSError **)error {return [self importURL:url recording:recording cache:NO error:error];}
- (NSDictionary *)importURL:(NSURL *)url recording:(BOOL)recording cache:(BOOL)cache error:(NSError **)error {
    if (![url isKindOfClass:NSURL.class] || !url.isFileURL || url.query || url.fragment || url.user || url.password || url.port
        || (url.host.length && ![url.host isEqual:@"localhost"]) || !OR6AbsolutePath(url.path)) {
        OR6Fail(error,1,@"files.url");return nil;
    }
    NSString *root=recording ? _recordings : _inbox,*input=recording ? _recordingsInput : _inboxInput;
    NSString *name=url.path.lastPathComponent,*suppliedParent=url.path.stringByDeletingLastPathComponent;
    if ((!([suppliedParent isEqual:root] || [suppliedParent isEqual:input])) || !OR6SafeName(name)
        || (recording && (name.length!=40 || ![name hasSuffix:@".wav"] || !OR6ID([name substringToIndex:36])))) {
        OR6Fail(error,2,@"files.source_ownership");return nil;
    }
    struct stat sourceRoot;
    if (!OR6Directory(root,NO,&sourceRoot)) {OR6Fail(error,2,@"files.source_root");return nil;}
    struct stat before;int source=OR6OpenRegular([root stringByAppendingPathComponent:name],&before);
    if (source<0) {OR6Fail(error,2,@"files.source");return nil;}
    if ((unsigned long long)before.st_size>_fileBytes) {close(source);OR6Fail(error,5,@"files.file_limit");return nil;}
    NSArray *rows=[self records:error];if (!rows) {close(source);return nil;}
    if (cache) { // the same bytes already cached: that asset is reused (and counts as used now), no second copy
        NSDictionary *hash=OR6Stream(source,-1,_fileBytes,error);
        if (!hash || lseek(source,0,SEEK_SET)!=0) {close(source);if (!error || !*error) OR6Fail(error,3,@"files.read");return nil;}
        for (NSDictionary *row in rows) if ([row[@"sha256"] isEqual:hash[@"sha256"]] && [row[@"bytes"] isEqual:hash[@"bytes"]] && [self isCache:row[@"id"]]) {close(source);[self touch:row[@"id"]];return row;}
    }
    rows=[self makeRoom:(unsigned long long)before.st_size rows:rows error:error];if (!rows) {close(source);return nil;}
    unsigned long long total=0;for (NSDictionary *row in rows) total+=[row[@"bytes"] unsignedLongLongValue];
    if (rows.count>=_assetCount || (unsigned long long)before.st_size>_totalBytes-total) {close(source);OR6Fail(error,5,@"files.capacity");return nil;}
    NSString *identifier=nil;
    for (NSUInteger attempt=0;attempt<4;attempt++) {
        NSString *candidate=OR6UUID();BOOL available=YES;struct stat st;
        for (NSString *suffix in @[@".plist",@".blob",@".partial",@".metadata-partial",@".transaction-partial",@".cache"]) {
            if (!lstat([self path:candidate suffix:suffix].fileSystemRepresentation,&st) || errno!=ENOENT) available=NO;
        }
        if (!lstat([self transaction:candidate].fileSystemRepresentation,&st) || errno!=ENOENT) available=NO;
        if (available) {identifier=candidate;break;}
    }
    if (!identifier) {close(source);OR6Fail(error,3,@"files.identifier_collision");return nil;}
    NSString *txn=[self transaction:identifier],*partial=[self path:identifier suffix:@".partial"],*blob=[self path:identifier suffix:@".blob"],*metaPartial=[self path:identifier suffix:@".metadata-partial"],*meta=[self path:identifier suffix:@".plist"];
    if (![self prepareTransaction:identifier operation:@"import" error:error]) {close(source);return nil;}
    int output=open(partial.fileSystemRepresentation,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600);
    NSDictionary *stream=output>=0 ? OR6Stream(source,output,MIN(_fileBytes,_totalBytes-total),error) : nil;
    struct stat after,sourcePath,currentRoot;
    BOOL unchanged=!fstat(source,&after) && OR6SameStat(before,after)
        && !lstat([root stringByAppendingPathComponent:name].fileSystemRepresentation,&sourcePath) && OR6SameStat(before,sourcePath)
        && OR6Directory(root,NO,&currentRoot) && sourceRoot.st_ino==currentRoot.st_ino && sourceRoot.st_dev==currentRoot.st_dev;
    BOOL ok=stream && unchanged && [stream[@"bytes"] unsignedLongLongValue]==(unsigned long long)before.st_size;
    if (recording && ![stream[@"mediaType"] isEqual:@"audio/wav"]) ok=NO;
    if (close(source)) ok=NO;if (output>=0) {if (ok && fsync(output)) ok=NO;if (close(output)) ok=NO;}
    if (!ok && (!error || !*error)) OR6Fail(error,3,unchanged ? @"files.copy" : @"files.source_changed");
    NSDictionary *descriptor=ok ? @{@"id":identifier,@"name":name,@"mediaType":stream[@"mediaType"],@"bytes":stream[@"bytes"],@"sha256":stream[@"sha256"]} : nil;
    BOOL committed=NO;
    if (ok) ok=[self roots:error] && !rename(partial.fileSystemRepresentation,blob.fileSystemRepresentation) && !fsync(_directoryFD);
    if (ok) ok=OR6WriteMetadata(metaPartial,descriptor,NULL);
    if (ok) {ok=!rename(metaPartial.fileSystemRepresentation,meta.fileSystemRepresentation);committed=ok;}
    if (ok) ok=!fsync(_directoryFD);
    if (ok && cache) {NSString *marker=[self path:identifier suffix:@".cache"];int m=open(marker.fileSystemRepresentation,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600);if (m>=0) close(m);} // evictable; without it the asset is merely kept
    if (ok) ok=[self unlinkOwned:txn error:error] && !fsync(_directoryFD);
    if (!ok) {
        if (!committed) {NSError *cleanup=nil;[self recover:&cleanup];if (!error || !*error) OR6Fail(error,3,@"files.commit");}
        else if (error) *error=[NSError errorWithDomain:OR6FilesErrorDomain code:6 userInfo:@{NSLocalizedDescriptionKey:@"files.durability_uncertain",@"assetID":identifier}];
        return nil;
    }
    return descriptor;
}
- (NSDictionary *)importInboxURL:(NSURL *)url error:(NSError **)error {
    if (error) *error=nil;
    @synchronized(OR6Files.class) {if (![self begin:error]) return nil;NSDictionary *result=[self recover:error] ? [self importURL:url recording:NO error:error] : nil;[self end];return result;}
}
- (NSDictionary *)importCacheURL:(NSURL *)url error:(NSError **)error {
    if (error) *error=nil;
    @synchronized(OR6Files.class) {if (![self begin:error]) return nil;NSDictionary *result=[self recover:error] ? [self importURL:url recording:NO cache:YES error:error] : nil;[self end];return result;}
}
- (NSDictionary *)importRecordingURL:(NSURL *)url error:(NSError **)error {
    if (error) *error=nil;
    @synchronized(OR6Files.class) {if (![self begin:error]) return nil;NSDictionary *result=[self recover:error] ? [self importURL:url recording:YES error:error] : nil;[self end];return result;}
}
- (NSArray *)assets {
    return [self assetsWithError:NULL] ?: @[];
}
- (NSArray *)assetsWithError:(NSError **)error {
    if (error) *error=nil;
    @synchronized(OR6Files.class) {if (![self begin:error]) return nil;NSArray *result=[self recover:error] ? [self records:error] : nil;[self end];return result;}
}
- (NSDictionary *)assetForID:(NSString *)identifier error:(NSError **)error {
    if (error) *error=nil;
    @synchronized(OR6Files.class) {
        if (!OR6ID(identifier)) {OR6Fail(error,1,@"files.id");return nil;}if (![self begin:error]) return nil;
        NSDictionary *result=[self recover:error] ? [self descriptor:identifier error:error] : nil;[self end];return result;
    }
}
- (NSURL *)URLForAssetID:(NSString *)identifier error:(NSError **)error {
    if (error) *error=nil;
    @synchronized(OR6Files.class) {
        if (!OR6ID(identifier)) {OR6Fail(error,1,@"files.id");return nil;}if (![self begin:error]) return nil;
        NSDictionary *row=[self recover:error] ? [self descriptor:identifier error:error] : nil;NSURL *result=nil;
        if (row) {
            NSString *path=[self path:identifier suffix:@".blob"];struct stat before,after,pathState;int fd=OR6OpenRegular(path,&before);
            NSDictionary *stream=fd>=0 ? OR6Stream(fd,-1,_fileBytes,error) : nil;
            BOOL valid=stream && !fstat(fd,&after) && OR6SameStat(before,after) && !lstat(path.fileSystemRepresentation,&pathState)
                && OR6SameStat(before,pathState) && [stream[@"bytes"] isEqual:row[@"bytes"]] && [stream[@"sha256"] isEqual:row[@"sha256"]]
                && [stream[@"mediaType"] isEqual:row[@"mediaType"]] && [self roots:error];
            if (fd>=0 && close(fd)) valid=NO;
            if (valid) {result=[NSURL fileURLWithPath:path];[self touch:identifier];} // a read is a use: cache eviction is least recently used
            else if (!error || !*error) OR6Fail(error,4,@"files.integrity");
        }
        [self end];return result;
    }
}
- (BOOL)markCacheAssetID:(NSString *)identifier error:(NSError **)error {
    if (error) *error=nil;
    @synchronized(OR6Files.class) {
        if (!OR6ID(identifier)) return OR6Fail(error,1,@"files.id");if (![self begin:error]) return NO;
        BOOL ok=[self recover:error] && [self descriptor:identifier error:error]!=nil;
        if (ok && ![self isCache:identifier]) {
            int m=open([self path:identifier suffix:@".cache"].fileSystemRepresentation,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0600);
            ok=(m>=0 || errno==EEXIST) && (m<0 || !close(m)) && !fsync(_directoryFD);if (!ok && (!error || !*error)) OR6Fail(error,3,@"files.mark");
        }
        [self end];return ok;
    }
}
- (BOOL)removeAssetID:(NSString *)identifier error:(NSError **)error {
    if (error) *error=nil;
    @synchronized(OR6Files.class) {
        if (!OR6ID(identifier)) return OR6Fail(error,1,@"files.id");if (![self begin:error]) return NO;
        BOOL ok=[self recover:error] && [self descriptor:identifier error:error]!=nil;
        if (ok) ok=[self prepareTransaction:identifier operation:@"remove" error:error];
        if (ok) ok=[self recover:error];if (!ok && (!error || !*error)) OR6Fail(error,3,@"files.remove");[self end];return ok;
    }
}
- (void)dealloc {
    if (_lockFD>=0) close(_lockFD);if (_directoryFD>=0) close(_directoryFD);
    [_directory release];[_inbox release];[_inboxInput release];[_recordings release];[_recordingsInput release];[_parent release];[super dealloc];
}
@end
