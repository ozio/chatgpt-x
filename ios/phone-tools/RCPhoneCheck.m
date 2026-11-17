// Direct USB development helper. Built by Theos; no Mac/bridge daemon.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonDigest.h>
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <signal.h>
static int output(id value){NSData*d=[NSJSONSerialization dataWithJSONObject:value options:0 error:NULL];if(!d)return 2;fwrite(d.bytes,1,d.length,stdout);puts("");return 0;}
static NSString *processPath(pid_t pid) {
    int mib[]={CTL_KERN,KERN_PROCARGS2,pid}; size_t size=262144;
    void *buffer=calloc(1,size); if (!buffer) return nil;
    NSString *path=nil;
    if (sysctl(mib,3,buffer,&size,NULL,0)==0 && size>sizeof(int)) {
        char *start=(char *)buffer+sizeof(int); size_t available=size-sizeof(int);
        if (memchr(start,0,available)) path=[[[NSString stringWithUTF8String:start] stringByResolvingSymlinksInPath] retain];
    }
    memset(buffer,0,262144);free(buffer);return [path autorelease];
}
static int processes(NSString *expected,BOOL stop) {
    expected=[expected stringByResolvingSymlinksInPath];
    if (![[expected lastPathComponent] isEqualToString:@"ChatGPTX"] || ![expected hasSuffix:@"/ChatGPTX.app/ChatGPTX"]) return 2;
    int mib[]={CTL_KERN,KERN_PROC,KERN_PROC_ALL,0};size_t size=0;
    if (sysctl(mib,4,NULL,&size,NULL,0)) return 2;
    size+=sizeof(struct kinfo_proc)*32;struct kinfo_proc *buffer=malloc(size);
    if (!buffer || sysctl(mib,4,buffer,&size,NULL,0)) { free(buffer);return 2; }
    NSMutableArray *found=[NSMutableArray array];
    for (NSUInteger i=0;i<size/sizeof(struct kinfo_proc);i++) {
        if (strcmp(buffer[i].kp_proc.p_comm,"ChatGPTX")) continue;
        pid_t pid=buffer[i].kp_proc.p_pid;NSString *path=processPath(pid);
        if ([path isEqualToString:expected]) [found addObject:@{@"pid":@(pid),@"path":path}];
    }
    free(buffer); if (found.count>1) return 2;
    if (stop) for (NSDictionary *entry in found) {
        pid_t pid=[[entry objectForKey:@"pid"] intValue];
        if (![processPath(pid) isEqualToString:expected] || kill(pid,SIGTERM)) return 2;
    }
    return output(@{@"matches":found,@"stopped":@(stop)});
}
static int deviceIdentity(void) {
    UIDevice *device=[UIDevice currentDevice];id identifier=nil;
    SEL selector=NSSelectorFromString(@"uniqueIdentifier");
    if([device respondsToSelector:selector])identifier=[device performSelector:selector];
    if(![identifier isKindOfClass:NSString.class]||[identifier length]!=40){
        void *library=dlopen("/usr/lib/libMobileGestalt.dylib",RTLD_LAZY);
        CFTypeRef (*copyAnswer)(CFStringRef)=library?dlsym(library,"MGCopyAnswer"):NULL;
        CFTypeRef answer=copyAnswer?copyAnswer(CFSTR("UniqueDeviceID")):NULL;
        if(answer&&CFGetTypeID(answer)==CFStringGetTypeID())identifier=[[(NSString *)answer copy] autorelease];
        if(answer)CFRelease(answer);if(library)dlclose(library);
    }
    char hardware[128]={0};size_t length=sizeof hardware;
    if(![identifier isKindOfClass:NSString.class]||[identifier length]!=40||sysctlbyname("hw.machine",hardware,&length,NULL,0))return 2;
    NSString *udid=[identifier lowercaseString];
    if([udid rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet]].location!=NSNotFound)return 2;
    NSDictionary *system=[NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
    if(![system[@"ProductBuildVersion"] isKindOfClass:NSString.class])return 2;
    return output(@{@"udid":udid,@"ProductType":[NSString stringWithUTF8String:hardware],@"ProductVersion":device.systemVersion,@"BuildVersion":system[@"ProductBuildVersion"]});
}
int main(int argc,char**argv){@autoreleasepool{
 if(argc==2&&!strcmp(argv[1],"identity"))return deviceIdentity();
 if(argc==3&&(!strcmp(argv[1],"process")||!strcmp(argv[1],"stop")))return processes([NSString stringWithUTF8String:argv[2]],!strcmp(argv[1],"stop"));
 if(argc==3&&!strcmp(argv[1],"hash")){NSData*d=[NSData dataWithContentsOfFile:[NSString stringWithUTF8String:argv[2]]];if(!d)return 2;unsigned char bytes[CC_SHA256_DIGEST_LENGTH];CC_SHA256(d.bytes,(CC_LONG)d.length,bytes);NSMutableString*h=[NSMutableString string];for(NSUInteger i=0;i<sizeof(bytes);i++)[h appendFormat:@"%02x",bytes[i]];return output(@{@"sha256":h,@"bytes":@(d.length)});}
 if(argc==2&&!strcmp(argv[1],"state")){void*lib=dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices",RTLD_LAZY);CFStringRef(*front)(void)=lib?dlsym(lib,"SBSCopyFrontmostApplicationDisplayIdentifier"):NULL;if(!front)return 2;CFStringRef b=front();int rc=output(@{@"frontmostBundle":(NSString*)(b?:CFSTR(""))});if(b)CFRelease(b);dlclose(lib);return rc;}
 if(argc==3&&!strcmp(argv[1],"screenshot")){CGImageRef(*capture)(void)=dlsym(RTLD_DEFAULT,"UIGetScreenImage");CGImageRef image=capture?capture():NULL;if(!image)return 2;NSData*d=UIImagePNGRepresentation([UIImage imageWithCGImage:image]);BOOL saved=[d writeToFile:[NSString stringWithUTF8String:argv[2]]atomically:YES];int rc=output(@{@"saved":@(saved),@"width":@(CGImageGetWidth(image)),@"height":@(CGImageGetHeight(image))});CGImageRelease(image);return saved?rc:2;}
 return 2;}}
