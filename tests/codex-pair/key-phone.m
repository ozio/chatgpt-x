// Disposable, local Security API probe. No account, enrollment or network.
#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>
NSDictionary *OR6CodexLegacyECProbe(void){
 NSString *prefix=[@"io.ozio.chatgptx.codex.pair.probe."stringByAppendingString:NSProcessInfo.processInfo.globallyUniqueString];NSData *pubTag=[[prefix stringByAppendingString:@".public"]dataUsingEncoding:NSUTF8StringEncoding],*privTag=[[prefix stringByAppendingString:@".private"]dataUsingEncoding:NSUTF8StringEncoding];
 SecKeyRef pub=NULL,priv=NULL;NSDictionary *attributes=@{(id)kSecAttrKeyType:(id)kSecAttrKeyTypeEC,(id)kSecAttrKeySizeInBits:@256,(id)kSecPublicKeyAttrs:@{(id)kSecAttrApplicationTag:pubTag,(id)kSecAttrIsPermanent:@YES},(id)kSecPrivateKeyAttrs:@{(id)kSecAttrApplicationTag:privTag,(id)kSecAttrIsPermanent:@YES,(id)kSecAttrAccessible:(id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly}};
 OSStatus generated=SecKeyGeneratePair((CFDictionaryRef)attributes,&pub,&priv);unsigned char digest[32],signature[128];size_t signatureLength=sizeof(signature);NSData *message=[@"ChatGPT X disposable legacy EC probe"dataUsingEncoding:NSUTF8StringEncoding];CC_SHA256(message.bytes,(CC_LONG)message.length,digest);
 OSStatus signedCode=priv?SecKeyRawSign(priv,kSecPaddingNone,digest,sizeof(digest),signature,&signatureLength):errSecParam;
 OSStatus verified=pub&&signedCode==errSecSuccess?SecKeyRawVerify(pub,kSecPaddingNone,digest,sizeof(digest),signature,signatureLength):errSecParam;
 NSMutableArray *results=[NSMutableArray array];BOOL cleanup=YES;
 for(NSData *tag in @[pubTag,privTag]){CFTypeRef data=NULL;NSDictionary *query=@{(id)kSecClass:(id)kSecClassKey,(id)kSecAttrApplicationTag:tag,(id)kSecReturnData:@YES};OSStatus code=SecItemCopyMatching((CFDictionaryRef)query,&data);[results addObject:@{@"code":@(code),@"bytes":@(data&&CFGetTypeID(data)==CFDataGetTypeID()?CFDataGetLength(data):0)}];if(data)CFRelease(data);OSStatus removed=SecItemDelete((CFDictionaryRef)@{(id)kSecClass:(id)kSecClassKey,(id)kSecAttrKeyType:(id)kSecAttrKeyTypeEC,(id)kSecAttrApplicationTag:tag});if(removed!=errSecSuccess&&removed!=errSecItemNotFound)cleanup=NO;}
 if(pub)CFRelease(pub);if(priv)CFRelease(priv);NSDictionary *report=@{@"generated":@(generated),@"signed":@(signedCode),@"verified":@(verified),@"publicExport":results[0],@"privateExport":results[1],@"cleanup":@(cleanup),@"accountRequests":@0,@"privateValuesExported":@NO};return report;
}
#ifndef OR6_CHAT_ACCEPTANCE
int main(void){NSAutoreleasePool *pool=[NSAutoreleasePool new];NSDictionary *report=OR6CodexLegacyECProbe();NSData *json=[NSJSONSerialization dataWithJSONObject:report options:0 error:NULL];fwrite(json.bytes,1,json.length,stdout);puts("");BOOL ok=[report[@"cleanup"]boolValue];[pool drain];return ok?0:2;}
#endif
