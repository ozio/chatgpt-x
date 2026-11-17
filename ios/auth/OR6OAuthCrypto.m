#import "OR6OAuthCrypto.h"
#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>
#include <math.h>
#include <stdint.h>
#include <string.h>
#include <mbedtls/base64.h>
#include <mbedtls/sha256.h>
#include <mbedtls/ecp.h>
#include <mbedtls/ecdsa.h>
#include <mbedtls/rsa.h>
#include <mbedtls/platform_util.h>

static int OR6Random(void *unused, unsigned char *bytes, size_t length) {
    (void)unused;
    return SecRandomCopyBytes(kSecRandomDefault, length, bytes)==errSecSuccess ? 0 : -1;
}
static BOOL OR6String(id value, NSUInteger maximum) {
    return [value isKindOfClass:NSString.class] && [value length] && [value length]<=maximum;
}
static BOOL OR6ASCII(NSString *value, NSUInteger maximum) {
    return OR6String(value,maximum) && [value dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:NO]!=nil;
}
static BOOL OR6Nonce(NSString *value) {
    if (!OR6ASCII(value,1024)) return NO;
    for (NSUInteger i=0;i<value.length;i++) {
        unichar c=[value characterAtIndex:i];
        if (!(c==0x21 || (c>=0x23 && c<=0x5b) || (c>=0x5d && c<=0x7e))) return NO;
    }
    return YES;
}
static BOOL OR6Number(id value, double *number) {
    if (![value isKindOfClass:NSNumber.class] || CFGetTypeID((CFTypeRef)value)==CFBooleanGetTypeID()) return NO;
    double result=[value doubleValue]; if (!isfinite(result)) return NO;
    if (number) *number=result; return YES;
}
static BOOL OR6Equal(NSString *left, NSString *right) {
    NSData *a=[left dataUsingEncoding:NSUTF8StringEncoding], *b=[right dataUsingEncoding:NSUTF8StringEncoding];
    if (!a || !b || a.length!=b.length) return NO;
    const unsigned char *x=a.bytes,*y=b.bytes; unsigned difference=0;
    for (NSUInteger i=0;i<a.length;i++) difference|=x[i]^y[i];
    return difference==0;
}
static NSData *OR6JSONData(NSDictionary *object) {
    if (![object isKindOfClass:NSDictionary.class] || ![NSJSONSerialization isValidJSONObject:object]) return nil;
    NSData *data=[NSJSONSerialization dataWithJSONObject:object options:0 error:NULL];
    return data.length<=32768 ? data : nil;
}
static NSDictionary *OR6JSONDictionary(NSData *data) {
    if (!data || !data.length || data.length>32768) return nil;
    id object=[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    return [object isKindOfClass:NSDictionary.class] ? object : nil;
}
static BOOL OR6LoadPrivate(NSData *raw, mbedtls_ecp_keypair *key) {
    if (![raw isKindOfClass:NSData.class] || raw.length!=32) return NO;
    if (mbedtls_ecp_read_key(MBEDTLS_ECP_DP_SECP256R1,key,raw.bytes,raw.length)!=0) return NO;
    if (mbedtls_ecp_check_privkey(&key->MBEDTLS_PRIVATE(grp),&key->MBEDTLS_PRIVATE(d))!=0) return NO;
    return mbedtls_ecp_mul(&key->MBEDTLS_PRIVATE(grp),&key->MBEDTLS_PRIVATE(Q),
        &key->MBEDTLS_PRIVATE(d),&key->MBEDTLS_PRIVATE(grp).G,OR6Random,NULL)==0;
}
static NSData *OR6CanonicalJWK(NSDictionary *JWK) {
    if (![JWK isKindOfClass:NSDictionary.class]) return nil;
    NSString *type=JWK[@"kty"],*canonical=nil;
    if ([type isEqual:@"EC"] && [JWK[@"crv"] isEqual:@"P-256"]) {
        NSData *x=[OR6OAuthCrypto dataForBase64urlString:JWK[@"x"]],*y=[OR6OAuthCrypto dataForBase64urlString:JWK[@"y"]];
        if (x.length!=32 || y.length!=32) return nil;
        // All variable content has already passed the base64url alphabet guard.
        canonical=[NSString stringWithFormat:@"{\"crv\":\"P-256\",\"kty\":\"EC\",\"x\":\"%@\",\"y\":\"%@\"}",JWK[@"x"],JWK[@"y"]];
    } else if ([type isEqual:@"RSA"]) {
        NSData *n=[OR6OAuthCrypto dataForBase64urlString:JWK[@"n"]],*e=[OR6OAuthCrypto dataForBase64urlString:JWK[@"e"]];
        if (!n.length || n.length>1024 || !e.length || e.length>8 || ((const unsigned char *)n.bytes)[0]==0 || ((const unsigned char *)e.bytes)[0]==0) return nil;
        canonical=[NSString stringWithFormat:@"{\"e\":\"%@\",\"kty\":\"RSA\",\"n\":\"%@\"}",JWK[@"e"],JWK[@"n"]];
    }
    return [canonical dataUsingEncoding:NSUTF8StringEncoding];
}
static BOOL OR6KeyMetadata(NSDictionary *JWK, NSString *algorithm) {
    if (![JWK isKindOfClass:NSDictionary.class] || JWK[@"d"] || JWK[@"p"] || JWK[@"q"] || JWK[@"dp"] || JWK[@"dq"] || JWK[@"qi"] || JWK[@"oth"] || JWK[@"k"]) return NO;
    id alg=JWK[@"alg"],use=JWK[@"use"],ops=JWK[@"key_ops"];
    if (alg && ![alg isEqual:algorithm]) return NO;
    if (use && ![use isEqual:@"sig"]) return NO;
    if (ops) {
        if (![ops isKindOfClass:NSArray.class] || [ops count]>16 || ![ops containsObject:@"verify"]) return NO;
        for (id op in ops) if (!OR6String(op,64)) return NO;
    }
    return YES;
}
static BOOL OR6Verify(NSData *message, NSData *signature, NSDictionary *JWK, NSString *algorithm) {
    if (!OR6KeyMetadata(JWK,algorithm)) return NO;
    NSData *digest=[OR6OAuthCrypto sha256:message]; if (!digest) return NO;
    if ([algorithm isEqual:@"ES256"] && [JWK[@"kty"] isEqual:@"EC"] && [JWK[@"crv"] isEqual:@"P-256"]) {
        NSData *x=[OR6OAuthCrypto dataForBase64urlString:JWK[@"x"]],*y=[OR6OAuthCrypto dataForBase64urlString:JWK[@"y"]];
        if (x.length!=32 || y.length!=32 || signature.length!=64) return NO;
        unsigned char publicPoint[65]={4};memcpy(publicPoint+1,x.bytes,32);memcpy(publicPoint+33,y.bytes,32);
        mbedtls_ecp_group group;mbedtls_ecp_point point;mbedtls_mpi r,s;
        mbedtls_ecp_group_init(&group);mbedtls_ecp_point_init(&point);mbedtls_mpi_init(&r);mbedtls_mpi_init(&s);
        BOOL valid=mbedtls_ecp_group_load(&group,MBEDTLS_ECP_DP_SECP256R1)==0 &&
            mbedtls_ecp_point_read_binary(&group,&point,publicPoint,sizeof(publicPoint))==0 &&
            mbedtls_ecp_check_pubkey(&group,&point)==0 &&
            mbedtls_mpi_read_binary(&r,signature.bytes,32)==0 &&
            mbedtls_mpi_read_binary(&s,(const unsigned char *)signature.bytes+32,32)==0 &&
            mbedtls_ecdsa_verify(&group,digest.bytes,digest.length,&point,&r,&s)==0;
        mbedtls_mpi_free(&r);mbedtls_mpi_free(&s);mbedtls_ecp_point_free(&point);mbedtls_ecp_group_free(&group);
        return valid;
    }
    if ([algorithm isEqual:@"RS256"] && [JWK[@"kty"] isEqual:@"RSA"]) {
        NSData *n=[OR6OAuthCrypto dataForBase64urlString:JWK[@"n"]],*e=[OR6OAuthCrypto dataForBase64urlString:JWK[@"e"]];
        if (n.length<256 || n.length>1024 || !e.length || e.length>8 ||
            ((const unsigned char *)n.bytes)[0]==0 || ((const unsigned char *)e.bytes)[0]==0) return NO;
        mbedtls_rsa_context key;mbedtls_rsa_init(&key);
        BOOL valid=mbedtls_rsa_import_raw(&key,n.bytes,n.length,NULL,0,NULL,0,NULL,0,e.bytes,e.length)==0 &&
            mbedtls_rsa_complete(&key)==0 && mbedtls_rsa_check_pubkey(&key)==0 &&
            mbedtls_rsa_get_bitlen(&key)>=2048 && mbedtls_rsa_get_bitlen(&key)<=8192 &&
            signature.length==mbedtls_rsa_get_len(&key) &&
            mbedtls_rsa_set_padding(&key,MBEDTLS_RSA_PKCS_V15,MBEDTLS_MD_SHA256)==0 &&
            mbedtls_rsa_pkcs1_verify(&key,MBEDTLS_MD_SHA256,(unsigned)digest.length,digest.bytes,signature.bytes)==0;
        mbedtls_rsa_free(&key);return valid;
    }
    return NO;
}
static BOOL OR6ParseJWT(NSString *JWT, NSDictionary **header, NSDictionary **claims, NSData **message, NSData **signature) {
    if (!OR6ASCII(JWT,65536)) return NO;
    NSArray *parts=[JWT componentsSeparatedByString:@"."];if (parts.count!=3) return NO;
    NSDictionary *h=OR6JSONDictionary([OR6OAuthCrypto dataForBase64urlString:parts[0]]);
    NSDictionary *c=OR6JSONDictionary([OR6OAuthCrypto dataForBase64urlString:parts[1]]);
    NSData *s=[OR6OAuthCrypto dataForBase64urlString:parts[2]];
    if (!h || !c || !s.length || h[@"crit"] || h[@"b64"]) return NO;
    if (h[@"kid"] && !OR6String(h[@"kid"],256)) return NO;
    NSData *m=[[NSString stringWithFormat:@"%@.%@",parts[0],parts[1]]dataUsingEncoding:NSASCIIStringEncoding];
    if (header) *header=h;if (claims) *claims=c;if (message) *message=m;if (signature) *signature=s;return YES;
}
static NSString *OR6HTU(NSURL *URL) {
    if (![URL isKindOfClass:NSURL.class] || ![URL.scheme.lowercaseString isEqual:@"https"] ||
        URL.user!=nil || URL.password!=nil || (URL.port && URL.port.integerValue!=443)) return nil;
    NSString *host=URL.host.lowercaseString,*absolute=URL.absoluteString;
    if (!OR6ASCII(host,253) || !OR6ASCII(absolute,8192)) return nil;
    NSCharacterSet *hostSet=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789-."];
    if ([host rangeOfCharacterFromSet:hostSet.invertedSet].location!=NSNotFound) return nil;
    for (NSString *label in [host componentsSeparatedByString:@"."])
        if (!label.length || label.length>63 || [label hasPrefix:@"-"] || [label hasSuffix:@"-"]) return nil;
    NSRange scheme=[absolute rangeOfString:@"://"];if (scheme.location==NSNotFound) return nil;
    NSUInteger authorityStart=NSMaxRange(scheme),end=absolute.length;
    NSRange suffix=[absolute rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/?#"] options:0 range:NSMakeRange(authorityStart,absolute.length-authorityStart)];
    if (suffix.location!=NSNotFound) end=suffix.location;
    NSString *authority=[[absolute substringWithRange:NSMakeRange(authorityStart,end-authorityStart)]lowercaseString];
    if (![authority isEqual:host] && ![authority isEqual:[host stringByAppendingString:@":443"]]) return nil;
    NSString *path=end<absolute.length && [absolute characterAtIndex:end]=='/' ? [absolute substringFromIndex:end] : @"/";
    NSRange cut=[path rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"?#"]];
    if (cut.location!=NSNotFound) path=[path substringToIndex:cut.location];
    if ([path rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound || [path rangeOfString:@"\\"].location!=NSNotFound) return nil;
    for (NSUInteger i=0;i<path.length;i++) if ([path characterAtIndex:i]=='%') {
        if (i+2>=path.length) return nil;
        for (NSUInteger j=i+1;j<=i+2;j++) {
            unichar ch=[path characterAtIndex:j];if (!((ch>='0'&&ch<='9')||(ch>='a'&&ch<='f')||(ch>='A'&&ch<='F'))) return nil;
        }
        i+=2;
    }
    return [NSString stringWithFormat:@"https://%@%@",host,path];
}
static NSString *OR6Proof(NSData *key,NSString *method,NSURL *URL,NSDate *date,NSString *nonce,NSString *identifier,NSString *accessToken) {
    if (!OR6ASCII(method,16) || [method rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ"]invertedSet]].location!=NSNotFound || !OR6ASCII(identifier,128)) return nil;
    if (![date isKindOfClass:NSDate.class]) return nil;double epoch=date.timeIntervalSince1970;
    if (!isfinite(epoch) || epoch<=0 || epoch>9007199254740991.0) return nil;
    if (nonce && !OR6Nonce(nonce)) return nil;
    NSString *HTU=OR6HTU(URL);NSDictionary *JWK=[OR6OAuthCrypto publicJWKForPrivateKey:key];if (!HTU || !JWK) return nil;
    NSDictionary *header=@{@"alg":@"ES256",@"typ":@"dpop+jwt",@"jwk":JWK};
    NSMutableDictionary *claims=[NSMutableDictionary dictionaryWithDictionary:@{@"htm":method,@"htu":HTU,@"iat":@((long long)floor(epoch)),@"jti":identifier}];
    if (nonce) claims[@"nonce"]=nonce;
    if (accessToken) {
        if (!OR6ASCII(accessToken,16384)) return nil;
        claims[@"ath"]=[OR6OAuthCrypto base64urlStringForData:[OR6OAuthCrypto sha256:[accessToken dataUsingEncoding:NSASCIIStringEncoding]]];
    }
    NSString *a=[OR6OAuthCrypto base64urlStringForData:OR6JSONData(header)],*b=[OR6OAuthCrypto base64urlStringForData:OR6JSONData(claims)];if (!a || !b) return nil;
    NSString *message=[NSString stringWithFormat:@"%@.%@",a,b];
    NSString *signature=[OR6OAuthCrypto base64urlStringForData:[OR6OAuthCrypto ES256SignatureForData:[message dataUsingEncoding:NSASCIIStringEncoding]privateKey:key]];
    return signature ? [message stringByAppendingFormat:@".%@",signature] : nil;
}

@implementation OR6OAuthCrypto
+ (NSData *)randomDataOfLength:(NSUInteger)length {
    if (!length || length>4096) return nil;
    NSMutableData *data=[NSMutableData dataWithLength:length];
    if (OR6Random(NULL,data.mutableBytes,length)!=0) {mbedtls_platform_zeroize(data.mutableBytes,length);return nil;}
    return data;
}
+ (NSString *)base64urlStringForData:(NSData *)data {
    if (![data isKindOfClass:NSData.class] || data.length>65536) return nil;
    if (!data.length) return @"";
    size_t length=0,capacity=4*((data.length+2)/3)+1;NSMutableData *encoded=[NSMutableData dataWithLength:capacity];
    if (mbedtls_base64_encode(encoded.mutableBytes,capacity,&length,data.bytes,data.length)!=0) return nil;
    NSString *value=[[[NSString alloc]initWithBytes:encoded.bytes length:length encoding:NSASCIIStringEncoding]autorelease];
    value=[[value stringByReplacingOccurrencesOfString:@"+"withString:@"-"]stringByReplacingOccurrencesOfString:@"/"withString:@"_"];
    return [value stringByReplacingOccurrencesOfString:@"="withString:@""];
}
+ (NSData *)dataForBase64urlString:(NSString *)string {
    if (![string isKindOfClass:NSString.class] || string.length>87384 || string.length%4==1) return nil;
    if (!string.length) return [NSData data];
    NSCharacterSet *allowed=[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"];
    if ([string rangeOfCharacterFromSet:allowed.invertedSet].location!=NSNotFound) return nil;
    NSString *padded=[[string stringByReplacingOccurrencesOfString:@"-"withString:@"+"]stringByReplacingOccurrencesOfString:@"_"withString:@"/"];
    while (padded.length%4) padded=[padded stringByAppendingString:@"="];
    NSData *ASCII=[padded dataUsingEncoding:NSASCIIStringEncoding];NSMutableData *output=[NSMutableData dataWithLength:3*(padded.length/4)];size_t length=0;
    if (mbedtls_base64_decode(output.mutableBytes,output.length,&length,ASCII.bytes,ASCII.length)!=0 || length>65536) return nil;
    [output setLength:length];
    // Reject nonzero unused bits / noncanonical alternate encodings.
    return [[self base64urlStringForData:output]isEqual:string] ? output : nil;
}
+ (NSData *)sha256:(NSData *)data {
    if (![data isKindOfClass:NSData.class] || data.length>1024*1024) return nil;
    unsigned char digest[32];if (mbedtls_sha256(data.bytes,data.length,digest,0)!=0) return nil;
    NSData *result=[NSData dataWithBytes:digest length:sizeof(digest)];mbedtls_platform_zeroize(digest,sizeof(digest));return result;
}
+ (NSString *)pkceChallengeForVerifier:(NSString *)verifier {
    if (!OR6ASCII(verifier,128) || verifier.length<43) return nil;
    NSCharacterSet *allowed=[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"];
    if ([verifier rangeOfCharacterFromSet:allowed.invertedSet].location!=NSNotFound) return nil;
    return [self base64urlStringForData:[self sha256:[verifier dataUsingEncoding:NSASCIIStringEncoding]]];
}
+ (NSData *)generateP256PrivateKey {
    mbedtls_ecp_keypair key;mbedtls_ecp_keypair_init(&key);unsigned char raw[32];size_t length=0;
    BOOL valid=mbedtls_ecp_gen_key(MBEDTLS_ECP_DP_SECP256R1,&key,OR6Random,NULL)==0 && mbedtls_ecp_write_key_ext(&key,&length,raw,sizeof(raw))==0 && length==32;
    NSData *result=valid ? [NSData dataWithBytes:raw length:sizeof(raw)] : nil;
    mbedtls_platform_zeroize(raw,sizeof(raw));mbedtls_ecp_keypair_free(&key);return result;
}
+ (NSDictionary *)publicJWKForPrivateKey:(NSData *)privateKey {
    mbedtls_ecp_keypair key;mbedtls_ecp_keypair_init(&key);unsigned char point[65];size_t length=0;
    BOOL valid=OR6LoadPrivate(privateKey,&key) && mbedtls_ecp_point_write_binary(&key.MBEDTLS_PRIVATE(grp),&key.MBEDTLS_PRIVATE(Q),MBEDTLS_ECP_PF_UNCOMPRESSED,&length,point,sizeof(point))==0 && length==65 && point[0]==4;
    NSDictionary *result=nil;
    if (valid) result=@{@"kty":@"EC",@"crv":@"P-256",@"x":[self base64urlStringForData:[NSData dataWithBytes:point+1 length:32]],@"y":[self base64urlStringForData:[NSData dataWithBytes:point+33 length:32]]};
    mbedtls_platform_zeroize(point,sizeof(point));mbedtls_ecp_keypair_free(&key);return result;
}
+ (NSString *)thumbprintForJWK:(NSDictionary *)JWK {return [self base64urlStringForData:[self sha256:OR6CanonicalJWK(JWK)]];}
+ (NSData *)ES256SignatureForData:(NSData *)data privateKey:(NSData *)privateKey {
    NSData *digest=[self sha256:data];if (!digest) return nil;
    mbedtls_ecp_keypair key;mbedtls_ecp_keypair_init(&key);mbedtls_mpi r,s;mbedtls_mpi_init(&r);mbedtls_mpi_init(&s);unsigned char raw[64];
    BOOL valid=OR6LoadPrivate(privateKey,&key) && mbedtls_ecdsa_sign_det_ext(&key.MBEDTLS_PRIVATE(grp),&r,&s,&key.MBEDTLS_PRIVATE(d),digest.bytes,digest.length,MBEDTLS_MD_SHA256,OR6Random,NULL)==0 && mbedtls_mpi_write_binary(&r,raw,32)==0 && mbedtls_mpi_write_binary(&s,raw+32,32)==0;
    NSData *result=valid ? [NSData dataWithBytes:raw length:sizeof(raw)] : nil;
    mbedtls_platform_zeroize(raw,sizeof(raw));mbedtls_mpi_free(&r);mbedtls_mpi_free(&s);mbedtls_ecp_keypair_free(&key);return result;
}
+ (NSString *)dpopProofWithPrivateKey:(NSData *)key method:(NSString *)method URL:(NSURL *)URL issuedAt:(NSDate *)date nonce:(NSString *)nonce {
    return [self dpopProofWithPrivateKey:key method:method URL:URL issuedAt:date nonce:nonce accessToken:nil];
}
+ (NSString *)dpopProofWithPrivateKey:(NSData *)key method:(NSString *)method URL:(NSURL *)URL issuedAt:(NSDate *)date nonce:(NSString *)nonce accessToken:(NSString *)token {
    NSString *identifier=[self base64urlStringForData:[self randomDataOfLength:32]];if (!identifier) return nil;
    return OR6Proof(key,method,URL,date,nonce,identifier,token);
}
+ (NSDictionary *)verifiedClaimsForJWT:(NSString *)JWT trustedJWK:(NSDictionary *)JWK algorithm:(NSString *)algorithm {
    if (![JWK isKindOfClass:NSDictionary.class] || ![@[@"RS256",@"ES256"]containsObject:algorithm]) return nil;
    NSDictionary *header=nil,*claims=nil;NSData *message=nil,*signature=nil;
    if (!OR6ParseJWT(JWT,&header,&claims,&message,&signature) || ![header[@"alg"]isEqual:algorithm]) return nil;
    if (JWK[@"kid"] && (!OR6String(JWK[@"kid"],256) || (header[@"kid"] && ![header[@"kid"]isEqual:JWK[@"kid"]]))) return nil;
    return OR6Verify(message,signature,JWK,algorithm) ? claims : nil;
}
+ (NSDictionary *)verifyToken:(NSString *)JWT trustedJWK:(NSDictionary *)JWK issuer:(NSString *)issuer audience:(NSString *)audience nonce:(NSString *)nonce subject:(NSString *)subject allowMissingNonce:(BOOL)allowMissingNonce now:(NSDate *)now leeway:(NSTimeInterval)leeway {
    if (!OR6String(issuer,2048) || !OR6String(audience,512) || !OR6String(nonce,1024) || ![now isKindOfClass:NSDate.class] || !isfinite(leeway) || leeway<0 || leeway>300) return nil;
    NSDictionary *header=nil;if (!OR6ParseJWT(JWT,&header,NULL,NULL,NULL)) return nil;
    NSDictionary *claims=[self verifiedClaimsForJWT:JWT trustedJWK:JWK algorithm:header[@"alg"]];if (!claims) return nil;
    if (![claims[@"iss"]isEqual:issuer] || !OR6String(claims[@"sub"],1024)) return nil;
    if (allowMissingNonce && (!OR6String(subject,1024) || !OR6Equal(claims[@"sub"],subject))) return nil;
    if ((!allowMissingNonce || claims[@"nonce"]) && (!OR6String(claims[@"nonce"],1024) || !OR6Equal(claims[@"nonce"],nonce))) return nil;
    id aud=claims[@"aud"];BOOL audienceMatches=NO,multiple=NO;
    if (OR6String(aud,512)) audienceMatches=[aud isEqual:audience];
    else if ([aud isKindOfClass:NSArray.class] && [aud count] && [aud count]<=16) {
        for (id item in aud) if (!OR6String(item,512)) return nil;
        audienceMatches=[aud containsObject:audience];multiple=[aud count]>1;
    }
    if (!audienceMatches || (multiple && !claims[@"azp"]) || (claims[@"azp"] && ![claims[@"azp"]isEqual:audience])) return nil;
    double expiration=0,issued=0,notBefore=0,epoch=now.timeIntervalSince1970;
    if (!isfinite(epoch) || epoch<=0 || !OR6Number(claims[@"exp"],&expiration) || !OR6Number(claims[@"iat"],&issued) || expiration<=0 || issued<=0 || issued>expiration || expiration<=epoch-leeway || issued>epoch+leeway) return nil;
    if (claims[@"nbf"] && (!OR6Number(claims[@"nbf"],&notBefore) || notBefore>epoch+leeway || notBefore>expiration)) return nil;
    return claims;
}
+ (NSDictionary *)verifiedIDToken:(NSString *)JWT trustedJWK:(NSDictionary *)JWK issuer:(NSString *)issuer audience:(NSString *)audience nonce:(NSString *)nonce now:(NSDate *)now leeway:(NSTimeInterval)leeway {
    return [self verifyToken:JWT trustedJWK:JWK issuer:issuer audience:audience nonce:nonce subject:nil allowMissingNonce:NO now:now leeway:leeway];
}
+ (NSDictionary *)verifiedRefreshIDToken:(NSString *)JWT trustedJWK:(NSDictionary *)JWK issuer:(NSString *)issuer audience:(NSString *)audience subject:(NSString *)subject originalNonce:(NSString *)nonce now:(NSDate *)now leeway:(NSTimeInterval)leeway {
    return [self verifyToken:JWT trustedJWK:JWK issuer:issuer audience:audience nonce:nonce subject:subject allowMissingNonce:YES now:now leeway:leeway];
}
#if defined(OR6_OAUTH_CRYPTO_TESTING)
+ (NSString *)testDPoPWithPrivateKey:(NSData *)key method:(NSString *)method URL:(NSURL *)URL issuedAt:(NSDate *)date nonce:(NSString *)nonce identifier:(NSString *)identifier {
    return OR6Proof(key,method,URL,date,nonce,identifier,nil);
}
#endif
@end
