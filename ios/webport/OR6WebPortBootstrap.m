#import "OR6WebPortBootstrap.h"
#include "OR6WebPortNamespace.h"
#import <CommonCrypto/CommonDigest.h>
#import <objc/runtime.h>
#include <mach-o/dyld.h>
#include <dlfcn.h>
#include <sys/stat.h>
#include <unistd.h>
#include <limits.h>

static NSMutableDictionary *State;
static BOOL Decided;
static NSString *Payload,*PrivateRoot;
static NSString *Canonical(NSString *path){char output[PATH_MAX];return path&&realpath(path.fileSystemRepresentation,output)?[NSString stringWithUTF8String:output]:nil;}
static NSString *Digest(NSString *path){
    FILE *f=path?fopen(path.fileSystemRepresentation,"rb"):NULL;if(!f)return nil;
    CC_SHA256_CTX c;CC_SHA256_Init(&c);unsigned char bytes[32768],digest[CC_SHA256_DIGEST_LENGTH];size_t n;
    while((n=fread(bytes,1,sizeof(bytes),f)))CC_SHA256_Update(&c,bytes,(CC_LONG)n);
    BOOL ok=!ferror(f);fclose(f);if(!ok)return nil;CC_SHA256_Final(digest,&c);NSMutableString *s=[NSMutableString string];for(unsigned i=0;i<sizeof(digest);i++)[s appendFormat:@"%02x",digest[i]];return s;
}
static void Checkpoint(NSString *phase){
    State[@"phase"]=phase;
    NSString *p=[NSHomeDirectory()stringByAppendingPathComponent:@"Library/ChatGPTXWebPortBootstrap.json"];
    NSData *data=[NSJSONSerialization dataWithJSONObject:State options:0 error:NULL];[data writeToFile:p atomically:YES];chmod(p.fileSystemRepresentation,0600);
}
static BOOL Fail(NSString *issue){State[@"ready"]=@NO;State[@"issue"]=issue;Checkpoint(@"failed");return NO;}
static NSArray *Images(void){
    NSMutableArray *a=[NSMutableArray array];
    for(uint32_t i=0;i<_dyld_image_count();i++){
        const char *raw=_dyld_get_image_name(i);if(!raw)continue;NSString *p=[NSString stringWithUTF8String:raw];NSString *name=p.lastPathComponent;
        BOOL relevant=[@[@"WK26.dylib",@"STBridge.dylib",@"libssl.3.dylib",@"libcrypto.3.dylib",@"libvlc.dylib",@"libicu-wk26.dylib"]containsObject:name]||[name hasPrefix:@"libWK26"]||[p rangeOfString:@"/var/wkd/"].location!=NSNotFound||[p hasPrefix:@"./WebKit/"]||[p rangeOfString:@"/WebPort/WebKit/"].location!=NSNotFound;
        if(relevant)[a addObject:@{@"reported":p,@"resolved":Canonical(p)?:@"unresolved",@"name":name}];
    }return a;
}
static BOOL Link(NSString *name,NSString *target){
    NSString *path=[PrivateRoot stringByAppendingPathComponent:name];struct stat st;
    if(lstat(path.fileSystemRepresentation,&st)==0){
        if(!S_ISLNK(st.st_mode))return NO;
        NSString *old=[NSFileManager.defaultManager destinationOfSymbolicLinkAtPath:path error:NULL];
        if([old isEqual:target])return YES;
        // Only replace our own runtime alias, never an unknown directory tree.
        if(unlink(path.fileSystemRepresentation))return NO;
    }
    return symlink(target.fileSystemRepresentation,path.fileSystemRepresentation)==0;
}
static BOOL PrepareContext(void){
    NSString *home=Canonical(NSHomeDirectory());if(!home)return NO;
    PrivateRoot=[[home stringByAppendingPathComponent:@"Library/ChatGPTXWebPort-v1"]copy];
    NSFileManager *fm=NSFileManager.defaultManager;
    for(NSString *suffix in @[@"",@"Config/WK26/Overrides",@"Config/WK26/UserAgent",@"Config/CFBridge/Enabled",@"Config/CFBridge/Overrides",@"Config/CFBridge/Sessions",@"Caches"]){
        NSString *path=[PrivateRoot stringByAppendingPathComponent:suffix];
        if(![fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700}error:NULL])return NO;
        NSString *real=Canonical(path);if(![real hasPrefix:[home stringByAppendingString:@"/"]])return NO;
    }
    NSString *identifier=NSBundle.mainBundle.bundleIdentifier;
    if(!identifier.length||identifier.length>200||[identifier rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"]invertedSet]].location!=NSNotFound)return NO;
    for(NSString *directory in @[@"Config/WK26/Overrides",@"Config/CFBridge/Enabled"]){
        NSString *path=[[PrivateRoot stringByAppendingPathComponent:directory]stringByAppendingPathComponent:identifier];
        if(![@"owned-by=ChatGPTX-private-bootstrap\n"writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL])return NO;chmod(path.fileSystemRepresentation,0600);
    }
    for(NSString *name in @[@"WebKit",@"LibSSL",@"LibVLC"])if(!Link(name,[Payload stringByAppendingPathComponent:name]))return NO;
    if(!Link(@"UserFiles",home))return NO;
    return chdir(PrivateRoot.fileSystemRepresentation)==0;
}
static BOOL VerifyNative(NSDictionary *manifest,NSString *prefix,BOOL system){
    NSDictionary *files=manifest[@"files"];if(![files isKindOfClass:NSDictionary.class]||files.count>5000)return NO;
    NSUInteger verified=0;
    for(NSString *relative in files){NSDictionary *record=files[relative];if(![record[@"macho"]boolValue])continue;
        if([relative hasPrefix:@"Loaders/"]&&![relative hasPrefix:[@"Loaders/"stringByAppendingString:prefix]])continue;
        NSString *path=[Payload stringByAppendingPathComponent:relative],*wanted=record[@"sha256"];
        if(system&&![relative hasPrefix:@"Loaders/"]){path=record[@"systemPath"];wanted=record[@"originalSHA256"];}
        if(![path isKindOfClass:NSString.class]||![wanted isKindOfClass:NSString.class]||![Digest(path)isEqual:wanted])return NO;
        verified++;
    }
    return verified>=14;
}
static BOOL ProbeJSC(NSString *path){
    void *h=dlopen(path.fileSystemRepresentation,RTLD_NOW|RTLD_NOLOAD);if(!h)return NO;
    void *(*create)(void *)=dlsym(h,"JSGlobalContextCreate");void(*release)(void *)=dlsym(h,"JSGlobalContextRelease");
    void *(*string)(const char *)=dlsym(h,"JSStringCreateWithUTF8CString");void(*freeString)(void *)=dlsym(h,"JSStringRelease");
    void *(*evaluate)(void *,void *,void *,void *,int,void **)=dlsym(h,"JSEvaluateScript");double(*number)(void *,void *,void **)=dlsym(h,"JSValueToNumber");
    if(!create||!release||!string||!freeString||!evaluate||!number)return NO;
    void *context=create(NULL);if(!context)return NO;void *source=string("(()=>({v:7})?.v)()"),*error=NULL;void *value=evaluate(context,source,NULL,NULL,1,&error);BOOL ok=!error&&value&&number(context,value,&error)==7&&!error;freeString(source);release(context);return ok;
}
static BOOL VerifyLoaded(BOOL system){
    NSString *web=nil,*jsc=nil;NSUInteger engine=0,tls=0;
    for(NSDictionary *image in Images()){
        NSString *p=image[@"resolved"],*name=image[@"name"];
        BOOL isEngine=[p rangeOfString:@"/WebKit/"].location!=NSNotFound||[p hasPrefix:@"/var/wkd/"]||[p hasPrefix:@"/private/var/wkd/"];
        BOOL isTLS=[@[@"libssl.3.dylib",@"libcrypto.3.dylib"]containsObject:name];
        if(!system&&![p hasPrefix:[Payload stringByAppendingString:@"/"]])return NO;
        if(isEngine||isTLS){
            BOOL expected=system?(isTLS?[p hasPrefix:@"/usr/lib/"]:([p hasPrefix:@"/var/wkd/"]||[p hasPrefix:@"/private/var/wkd/"])):[p hasPrefix:[Payload stringByAppendingString:@"/"]];
            if(!expected)return NO;if(isEngine)engine++;if(isTLS)tls++;
        }
        if([name isEqual:@"WebKitLegacy"])web=p;if([name isEqual:@"JavaScriptCore"])jsc=p;
    }
    Class cls=NSClassFromString(@"WebView");const char *raw=cls?class_getImageName(cls):NULL;NSString *origin=raw?Canonical([NSString stringWithUTF8String:raw]):nil;
    State[@"images"]=Images();State[@"webViewOrigin"]=origin?:@"missing";State[@"engineImages"]=@(engine);State[@"tlsImages"]=@(tls);
    if(engine<8||tls!=2||!web||!jsc||![origin isEqual:web])return NO;
    BOOL js=ProbeJSC(jsc);State[@"modernSyntax"]=@(js);return js;
}
BOOL OR6WebPortBootstrap(BOOL requireBundled){
    if(Decided)return [State[@"ready"]boolValue];Decided=YES;
    State=[@{@"schema":@1,@"ready":@NO,@"source":@"none",@"accountRequests":@0,@"requireBundled":@(requireBundled),@"initialImages":Images()}mutableCopy];
    Checkpoint(@"preflight");
    Payload=[Canonical([NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"WebPort"])copy];if(!Payload)return Fail(@"missing_payload");
    NSData *data=[NSData dataWithContentsOfFile:[Payload stringByAppendingPathComponent:@"Manifest.json"]];
    NSDictionary *manifest=data.length&&data.length<4*1024*1024?[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]:nil;
    if(![manifest isKindOfClass:NSDictionary.class]||![manifest[@"schema"]isEqual:@1])return Fail(@"invalid_manifest");
    NSArray *before=Images();BOOL hasEngine=NO;
    for(NSDictionary *image in before)if([@[@"JavaScriptCore",@"WebCore",@"WebKitLegacy"]containsObject:image[@"name"]])hasEngine=YES;
    if(hasEngine){
        if(requireBundled)return Fail(@"system_engine_preloaded");
        if(!VerifyNative(manifest,@"system",YES)||!VerifyLoaded(YES))return Fail(@"incompatible_preloaded_system_engine");
        State[@"source"]=@"system-active";State[@"ready"]=@YES;Checkpoint(@"ready");return YES;
    }
    if(before.count)return Fail(@"partial_or_inactive_runtime_preloaded");
    BOOL system=!requireBundled&&VerifyNative(manifest,@"system",YES);
    if(!system&&!VerifyNative(manifest,@"bundled",NO))return Fail(@"bundle_integrity");
    if(!PrepareContext())return Fail(@"private_paths");
    State[@"source"]=system?@"system":@"bundled";State[@"runtimeRoot"]=PrivateRoot;Checkpoint(@"loading_tls");
    // MobileSubstrate is the existing jailbreak's hooking API, not WebPort.
    void *substrate=dlopen("/usr/lib/libsubstrate.dylib",RTLD_NOW|RTLD_GLOBAL);
    if(!substrate||!dlsym(substrate,"MSHookFunction"))return Fail(@"missing_platform_hooking_api");
    NSString *prefix=[@"Loaders/"stringByAppendingString:system?@"system":@"bundled"];
    NSString *bridge=[[Payload stringByAppendingPathComponent:prefix]stringByAppendingPathComponent:@"STBridge.dylib"];
    if(!dlopen(bridge.fileSystemRepresentation,RTLD_NOW|RTLD_GLOBAL)){const char *why=dlerror();if(why)State[@"loaderError"]=[NSString stringWithUTF8String:why];return Fail(@"tls_loader");}
    Checkpoint(@"loading_engine");NSString *loader=[[Payload stringByAppendingPathComponent:prefix]stringByAppendingPathComponent:@"WK26.dylib"];
    if(!system&&!OR6WebPortInstallNamespaceAdapter(loader.fileSystemRepresentation,[[Payload stringByAppendingPathComponent:@"WebKit"]UTF8String]))return Fail(@"namespace_adapter_setup");
    if(!dlopen(loader.fileSystemRepresentation,RTLD_NOW|RTLD_GLOBAL)){const char *why=dlerror();if(why)State[@"loaderError"]=[NSString stringWithUTF8String:why];return Fail(@"engine_loader");}
    State[@"namespaceAdapterPatches"]=@(OR6WebPortNamespacePatchCount());
    if(!system&&!OR6WebPortNamespacePatchCount())return Fail(@"namespace_adapter_not_applied");
    Checkpoint(@"verifying_engine");if(!VerifyLoaded(system))return Fail(@"engine_origin_or_syntax");
    State[@"ready"]=@YES;Checkpoint(@"ready");return YES;
}
NSDictionary *OR6WebPortDiagnostics(void){return [[State copy]autorelease]?:@{@"ready":@NO,@"issue":@"not_initialized"};}

NSDictionary *OR6WebPortResourceAudit(void){
    if(![State[@"ready"]boolValue]||!Payload)return @{@"verified":@NO,@"issue":@"runtime_unavailable"};
    NSDictionary *manifest=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[Payload stringByAppendingPathComponent:@"Manifest.json"]]options:0 error:NULL];
    NSUInteger count=0;unsigned long long bytes=0;
    for(NSString *relative in manifest[@"files"]){
        NSString *path=[Payload stringByAppendingPathComponent:relative],*real=Canonical(path);NSDictionary *record=manifest[@"files"][relative];
        if(![real hasPrefix:[Payload stringByAppendingString:@"/"]]||![Digest(path)isEqual:record[@"sha256"]])return @{@"verified":@NO,@"issue":@"resource_integrity",@"file":relative};
        count++;NSDictionary *attrs=[NSFileManager.defaultManager attributesOfItemAtPath:path error:NULL];bytes+=[attrs[NSFileSize]unsignedLongLongValue];
    }
    return @{@"verified":@(count>3700),@"files":@(count),@"bytes":@(bytes)};
}

// Optional facade lets legacy standalone targets keep their existing engine detector.
@interface OR6WebPortRuntime : NSObject
+ (NSDictionary *)diagnostics;
@end
@implementation OR6WebPortRuntime
+ (NSDictionary *)diagnostics { return OR6WebPortDiagnostics(); }
@end
