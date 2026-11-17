#import "OR6CodexSSH.h"
#import "OR6CodexOperation.h"
#import <CFNetwork/CFNetwork.h>
#import <CommonCrypto/CommonDigest.h>
#import <dispatch/dispatch.h>
#import <mach/mach_time.h>
#include <libssh2.h>
#include <psa/crypto.h>
#include <sys/socket.h>
#include <sys/select.h>
#include <netinet/in.h>
#include <fcntl.h>
#include <unistd.h>
#include <pthread.h>
#include <errno.h>
static pthread_once_t Initialized=PTHREAD_ONCE_INIT;static int InitCode=-1;
static void Initialize(void){if(psa_crypto_init()==PSA_SUCCESS)InitCode=libssh2_init(0);}
static double Clock(void){mach_timebase_info_data_t t;mach_timebase_info(&t);return(double)mach_absolute_time()*t.numer/t.denom/1e9;}
static void Main(void(^b)(void)){if(NSThread.isMainThread)b();else dispatch_sync(dispatch_get_main_queue(),b);}
static void Resolved(CFHostRef h,CFHostInfoType t,const CFStreamError*e,void*context){(void)h;(void)t;(void)e;*(BOOL*)context=YES;}
@implementation OR6CodexSSH
+ (id<OR6APITask>)probeHost:(NSString*)host port:(NSUInteger)port completion:(OR6APIReply)completion{
 if(!completion)return nil;NSError*error=nil;OR6CodexSSH*t=[[[self alloc]initWithHost:host port:port username:@"probe"hostKeySHA256:[@""stringByPaddingToLength:64 withString:@"0"startingAtIndex:0]credentials:@{@"type":@"password",@"secret":@"unused"}error:&error]autorelease];if(!t){completion(nil,error);return nil;}
 OR6CodexOperation*c=[[[OR6CodexOperation alloc]init]autorelease];c->reply=[completion copy];t->_probeOnly=YES;c->cancelAction=[^{[t close];}copy];[t open:nil closed:nil ready:^(NSError*e){[c finish:t->_probeFingerprint?@{@"hostKeySHA256":t->_probeFingerprint}:nil error:t->_probeFingerprint?nil:e];}];return c;
}
- (id)initWithHost:(NSString*)h port:(NSUInteger)p username:(NSString*)u hostKeySHA256:(NSString*)key credentials:(NSDictionary*)credentials error:(NSError**)e{
 if(!(self=[super init]))return nil;credentials=OR6APIJSONSnapshot(credentials,49152);
 BOOL password=[credentials[@"type"]isEqual:@"password"]&&OR6CodexKeys(credentials,@[@"type",@"secret"],@[])&&OR6CodexText(credentials[@"secret"],4096,NO);
 BOOL publicKey=[credentials[@"type"]isEqual:@"publicKey"]&&OR6CodexKeys(credentials,@[@"type",@"privateKey",@"publicKey"],@[@"passphrase"])&&OR6CodexText(credentials[@"privateKey"],32768,NO)&&OR6CodexText(credentials[@"publicKey"],16384,NO)&&[credentials[@"publicKey"]hasPrefix:@"ssh-rsa "]&&(!credentials[@"passphrase"]||OR6CodexText(credentials[@"passphrase"],4096,YES));
 if(!OR6CodexText(h,253,NO)||[h rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-:"]invertedSet]].location!=NSNotFound||!p||p>65535||!OR6CodexID(u)||[u length]>64||!OR6CodexText(key,64,NO)||key.length!=64||[key rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"]invertedSet]].location!=NSNotFound||(!password&&!publicKey)){if(e)*e=OR6CodexError(@"invalid_request",NO);[self release];return nil;}
 _host=[h copy];_port=p;_username=[u copy];_hostKey=[key copy];_credentials=[credentials retain];_outgoing=[NSMutableArray new];return self;
}
- (BOOL)alive:(NSUInteger)r until:(double)end{@synchronized(self){return!_cancelled&&r==_revision&&Clock()<end;}}
- (void)close{@synchronized(self){_cancelled=YES;_opened=NO;[_outgoing removeAllObjects];}[_receiver release];_receiver=nil;[_ready release];_ready=nil;[_closed release];_closed=nil;}
- (BOOL)send:(NSDictionary*)m error:(NSError**)e{NSDictionary*s=OR6APIJSONSnapshot(m,[@[@"turn/start",@"turn/steer"]containsObject:m[@"method"]]?262144:24576);@synchronized(self){if(!NSThread.isMainThread||!s||!_opened||_cancelled||_outgoing.count>=32||!OR6APIJSONSnapshot([_outgoing arrayByAddingObject:s?:@{}],1048576)){if(e)*e=OR6CodexError(@"unavailable",NO);return NO;}[_outgoing addObject:s];}return YES;}
- (BOOL)wait:(int)fd session:(LIBSSH2_SESSION*)s revision:(NSUInteger)r until:(double)end{
 if(![self alive:r until:end])return NO;fd_set read,write;FD_ZERO(&read);FD_ZERO(&write);int flags=s?libssh2_session_block_directions(s):LIBSSH2_SESSION_BLOCK_OUTBOUND;if(flags&LIBSSH2_SESSION_BLOCK_INBOUND)FD_SET(fd,&read);if(flags&LIBSSH2_SESSION_BLOCK_OUTBOUND)FD_SET(fd,&write);if(!flags)FD_SET(fd,&read);struct timeval tv={0,50000};int n=select(fd+1,&read,&write,NULL,&tv);return(n>=0||errno==EINTR)&&[self alive:r until:end];
}
- (int)socket:(NSUInteger)revision until:(double)end{
 __block BOOL resolved=NO;CFHostClientContext context={0,&resolved,NULL,NULL,NULL};CFHostRef host=CFHostCreateWithName(NULL,(CFStringRef)_host);if(!host)return-1;BOOL okay=CFHostSetClient(host,Resolved,&context);if(okay){CFHostScheduleWithRunLoop(host,CFRunLoopGetCurrent(),kCFRunLoopDefaultMode);CFStreamError error;okay=CFHostStartInfoResolution(host,kCFHostAddresses,&error);}while(okay&&!resolved&&[self alive:revision until:end])CFRunLoopRunInMode(kCFRunLoopDefaultMode,.05,true);
 Boolean done=false;CFArrayRef values=resolved?CFHostGetAddressing(host,&done):NULL;NSArray*addresses=done?[[(NSArray*)values copy]autorelease]:nil;CFHostCancelInfoResolution(host,kCFHostAddresses);CFHostUnscheduleFromRunLoop(host,CFRunLoopGetCurrent(),kCFRunLoopDefaultMode);CFHostSetClient(host,NULL,NULL);CFRelease(host);
 NSUInteger attempts=0;for(NSData*raw in addresses){if(++attempts>8||![self alive:revision until:end])break;if(raw.length>sizeof(struct sockaddr_storage)||raw.length<sizeof(struct sockaddr))continue;struct sockaddr_storage address;memset(&address,0,sizeof(address));memcpy(&address,raw.bytes,raw.length);if(address.ss_family==AF_INET)((struct sockaddr_in*)&address)->sin_port=htons((unsigned short)_port);else if(address.ss_family==AF_INET6)((struct sockaddr_in6*)&address)->sin6_port=htons((unsigned short)_port);else continue;int fd=socket(address.ss_family,SOCK_STREAM,0);if(fd<0)continue;if(fd>=FD_SETSIZE){close(fd);continue;}int one=1;setsockopt(fd,SOL_SOCKET,SO_NOSIGPIPE,&one,sizeof(one));fcntl(fd,F_SETFL,fcntl(fd,F_GETFL,0)|O_NONBLOCK);int connected=connect(fd,(struct sockaddr*)&address,(socklen_t)raw.length);if(connected&&errno!=EINPROGRESS){close(fd);continue;}if(connected){while([self alive:revision until:end]){if(![self wait:fd session:NULL revision:revision until:end])break;int error=0;socklen_t size=sizeof(error);if(getsockopt(fd,SOL_SOCKET,SO_ERROR,&error,&size)||error){connected=-1;break;}struct sockaddr_storage peer;socklen_t count=sizeof(peer);if(!getpeername(fd,(struct sockaddr*)&peer,&count)){connected=0;break;}}}if(!connected)return fd;close(fd);}return-1;
}
- (NSError*)run:(NSUInteger)revision{
 pthread_once(&Initialized,Initialize);if(InitCode)return OR6CodexError(@"unavailable",NO);double end=Clock()+80,setup=Clock()+15;int fd=[self socket:revision until:setup];if(fd<0)return OR6CodexError(@"network_unavailable",NO);LIBSSH2_SESSION*s=libssh2_session_init();LIBSSH2_CHANNEL*channel=NULL;NSString*failure=@"network_unavailable";BOOL authenticated=NO;NSUInteger stderrBytes=0;
 if(!s){close(fd);return OR6CodexError(@"unavailable",NO);}libssh2_session_set_blocking(s,0);libssh2_session_flag(s,LIBSSH2_FLAG_SIGPIPE,0);
 // No downgrade to CBC, SHA-1 KEX, RSA-SHA1 host authentication or weak MACs.
 if(libssh2_session_method_pref(s,LIBSSH2_METHOD_KEX,"ecdh-sha2-nistp256,diffie-hellman-group14-sha256")||libssh2_session_method_pref(s,LIBSSH2_METHOD_HOSTKEY,"ecdsa-sha2-nistp256,rsa-sha2-512,rsa-sha2-256")||libssh2_session_method_pref(s,LIBSSH2_METHOD_CRYPT_CS,"aes256-ctr,aes128-ctr")||libssh2_session_method_pref(s,LIBSSH2_METHOD_CRYPT_SC,"aes256-ctr,aes128-ctr")||libssh2_session_method_pref(s,LIBSSH2_METHOD_MAC_CS,"hmac-sha2-256,hmac-sha2-512")||libssh2_session_method_pref(s,LIBSSH2_METHOD_MAC_SC,"hmac-sha2-256,hmac-sha2-512"))goto cleanup;
 {int code;do{code=libssh2_session_handshake(s,fd);if(code==LIBSSH2_ERROR_EAGAIN&&![self wait:fd session:s revision:revision until:setup])goto cleanup;}while(code==LIBSSH2_ERROR_EAGAIN);if(code)goto cleanup;}
 {size_t size=0;int type;const char*raw=libssh2_session_hostkey(s,&size,&type);(void)type;if(!raw||!size||size>16384)goto cleanup;unsigned char hash[CC_SHA256_DIGEST_LENGTH],expected[CC_SHA256_DIGEST_LENGTH];CC_SHA256(raw,(CC_LONG)size,hash);if(_probeOnly){NSMutableString*hex=[NSMutableString string];for(NSUInteger i=0;i<sizeof(hash);i++)[hex appendFormat:@"%02x",hash[i]];Main(^{if([self alive:revision until:end])_probeFingerprint=[hex copy];});goto cleanup;}for(NSUInteger i=0;i<sizeof(expected);i++){char part[3]={[_hostKey characterAtIndex:2*i],[_hostKey characterAtIndex:2*i+1],0};expected[i]=(unsigned char)strtoul(part,NULL,16);}unsigned char diff=0;for(NSUInteger i=0;i<sizeof(hash);i++)diff|=hash[i]^expected[i];if(diff){failure=@"access_denied";goto cleanup;}}
 {int code;do{if([_credentials[@"type"]isEqual:@"password"])code=libssh2_userauth_password_ex(s,_username.UTF8String,(unsigned)strlen(_username.UTF8String),[_credentials[@"secret"]UTF8String],(unsigned)[_credentials[@"secret"]lengthOfBytesUsingEncoding:NSUTF8StringEncoding],NULL);else{NSString*key=_credentials[@"privateKey"];code=libssh2_userauth_publickey_frommemory(s,_username.UTF8String,strlen(_username.UTF8String),[_credentials[@"publicKey"]UTF8String],[_credentials[@"publicKey"]lengthOfBytesUsingEncoding:NSUTF8StringEncoding],key.UTF8String,[key lengthOfBytesUsingEncoding:NSUTF8StringEncoding],[_credentials[@"passphrase"]UTF8String]);}if(code==LIBSSH2_ERROR_EAGAIN&&![self wait:fd session:s revision:revision until:setup])goto cleanup;}while(code==LIBSSH2_ERROR_EAGAIN);if(code){
#ifdef OR6_CODEX_SSH_FIXTURE
 char*message=NULL;int length=0;libssh2_session_last_error(s,&message,&length,0);const char*reason=message&&strcmp(message,"Callback returned error")==0?"sign_callback":message&&strstr(message,"Waiting")?"wait_response":"other";fprintf(stderr,"SSH_AUTH_ERROR %d %s\n",code,reason);
#endif
 failure=@"not_authenticated";goto cleanup;}authenticated=YES;}
 do{channel=libssh2_channel_open_session(s);if(!channel){if(libssh2_session_last_errno(s)!=LIBSSH2_ERROR_EAGAIN||![self wait:fd session:s revision:revision until:setup])goto cleanup;}}while(!channel);
 {int code;do{code=libssh2_channel_exec(channel,"codex app-server proxy");if(code==LIBSSH2_ERROR_EAGAIN&&![self wait:fd session:s revision:revision until:setup])goto cleanup;}while(code==LIBSSH2_ERROR_EAGAIN);if(code)goto cleanup;}
 libssh2_keepalive_config(s,1,10);Main(^{if([self alive:revision until:end]){_opened=YES;void(^ready)(NSError*)=[[_ready copy]autorelease];[_ready release];_ready=nil;if(ready)ready(nil);}});
 {NSMutableData*line=[NSMutableData data];NSUInteger total=0,messages=0;char buffer[4096];while([self alive:revision until:end]){
  NSAutoreleasePool*iteration=[NSAutoreleasePool new];BOOL okay=YES;NSArray*queue=nil;@synchronized(self){queue=[_outgoing copy];[_outgoing removeAllObjects];}
  for(NSDictionary*m in queue){NSMutableData*d=[NSMutableData dataWithData:[NSJSONSerialization dataWithJSONObject:m options:0 error:NULL]];[d appendBytes:"\n"length:1];NSUInteger offset=0;while(offset<d.length){if(![self alive:revision until:end]){okay=NO;break;}ssize_t n=libssh2_channel_write(channel,(const char*)d.bytes+offset,d.length-offset);if(n==LIBSSH2_ERROR_EAGAIN){if(![self wait:fd session:s revision:revision until:end]){okay=NO;break;}continue;}if(n<=0||![self alive:revision until:end]){okay=NO;break;}offset+=(NSUInteger)n;}if(!okay)break;}[queue release];
  if(okay){ssize_t n=libssh2_channel_read(channel,buffer,sizeof(buffer));if(n>0){total+=(NSUInteger)n;if(total>8*1024*1024){failure=@"size_limit";okay=NO;}else{[line appendBytes:buffer length:(NSUInteger)n];if(line.length>1024*1024+4096){failure=@"size_limit";okay=NO;}
   while(okay){const char*bytes=line.bytes;const char*newline=memchr(bytes,'\n',line.length);if(!newline)break;NSUInteger length=(NSUInteger)(newline-bytes);if(length>1024*1024||++messages>8192){failure=@"size_limit";okay=NO;break;}NSData*raw=[line subdataWithRange:NSMakeRange(0,length)];NSDictionary*m=[NSJSONSerialization JSONObjectWithData:raw options:0 error:NULL];if(![m isKindOfClass:NSDictionary.class]){failure=@"unknown_wire_shape";okay=NO;break;}Main(^{if([self alive:revision until:end]){void(^receive)(NSDictionary*)=[[_receiver copy]autorelease];if(receive)receive(m);}});[line replaceBytesInRange:NSMakeRange(0,length+1)withBytes:NULL length:0];}}}else if(n!=LIBSSH2_ERROR_EAGAIN&&n<0)okay=NO;else if(!n&&libssh2_channel_eof(channel))okay=NO;}
  if(okay){ssize_t n=libssh2_channel_read_stderr(channel,buffer,sizeof(buffer));if(n>0)stderrBytes+=(NSUInteger)n;if(stderrBytes>65536){failure=@"size_limit";okay=NO;}int seconds=0;int code=libssh2_keepalive_send(s,&seconds);if(code&&code!=LIBSSH2_ERROR_EAGAIN)okay=NO;}
  [iteration drain];if(!okay)break;if(![self wait:fd session:s revision:revision until:end])break;
 }}
 if(Clock()>=end)failure=@"timeout";else if(![self alive:revision until:end])failure=@"cancelled";
cleanup:
 // Closing only this proxy channel leaves the separately managed host daemon
 // alive. Cleanup is nonblocking; no retry can emit a second application write.
 shutdown(fd,SHUT_RDWR);libssh2_session_set_blocking(s,1);libssh2_session_set_timeout(s,100);if(channel)libssh2_channel_free(channel);libssh2_session_free(s);close(fd);return OR6CodexError(failure,authenticated);
}
- (void)open:(void(^)(NSDictionary*))receive closed:(void(^)(NSError*))closed ready:(void(^)(NSError*))ready{
 if(!NSThread.isMainThread){if(ready)ready(OR6CodexError(@"invalid_request",NO));return;}@synchronized(self){if(_running){if(ready)ready(OR6CodexError(@"conflict",NO));return;}_running=YES;_cancelled=NO;_opened=NO;_revision++;}_receiver=[receive copy];_closed=[closed copy];_ready=[ready copy];NSUInteger revision=_revision;
 dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{NSAutoreleasePool*pool=[NSAutoreleasePool new];NSError*error=[self run:revision];Main(^{if(revision==_revision){void(^first)(NSError*)=[[_ready copy]autorelease];void(^end)(NSError*)=[[_closed copy]autorelease];@synchronized(self){_running=NO;}[self close];if(first)first(error);else if(end)end(error);}});[pool drain];});
}
- (void)dealloc{[_probeFingerprint release];[_host release];[_username release];[_hostKey release];[_credentials release];[_outgoing release];[_receiver release];[_ready release];[_closed release];[super dealloc];}
@end
