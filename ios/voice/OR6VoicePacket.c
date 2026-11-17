#include "OR6VoicePacket.h"
#include <string.h>
static uint16_t BE16(const uint8_t *p) { return (uint16_t)((p[0]<<8)|p[1]); }
static uint32_t BE32(const uint8_t *p) { return ((uint32_t)p[0]<<24)|((uint32_t)p[1]<<16)|((uint32_t)p[2]<<8)|p[3]; }
int OR6VoiceParseRTP(const uint8_t *p, size_t n, OR6VoiceRTP *out) {
    if (!out) return 0;
    memset(out, 0, sizeof(*out));
    if (!p || n < 12 || n > 65535 || (p[0] >> 6) != 2) return 0;
    size_t at = 12 + 4*(p[0]&15), end = n;
    if (at > n) return 0;
    if (p[0]&16) {
        if (n-at < 4) return 0;
        size_t extra = 4 + 4*(size_t)BE16(p+at+2);
        if (extra > n-at) return 0;
        at += extra;
    }
    if (p[0]&32) {
        size_t padding = p[n-1];
        if (!padding || padding > n-at) return 0;
        end -= padding;
    }
    if (at >= end) return 0;
    out->payload=p+at; out->bytes=end-at;
    out->sequence=BE16(p+2); out->timestamp=BE32(p+4); out->ssrc=BE32(p+8);
    out->payloadType=p[1]&127; out->marker=p[1]>>7;
    return 1;
}
int OR6VoiceValidateSTUN(const uint8_t *p,size_t n) {
    /* Selected ICE binding profile requires trailing MESSAGE-INTEGRITY then
       FINGERPRINT. The upstream verifier assumes their presence and order. */
    if(!p||n<52||n>256||(p[0]&192)||BE32(p+4)!=0x2112a442||BE16(p+2)!=n-20||(n&3))return 0;
    unsigned integrity=0,fingerprint=0;
    for(size_t at=20;at<n;) {
        if(n-at<4)return 0;
        unsigned kind=BE16(p+at);size_t size=BE16(p+at+2),padded=(size+3)&~(size_t)3;
        if(padded>n-at-4)return 0;
        /* The selected upstream parser copies these fields to fixed buffers. */
        if((kind==0x0006&&size>127)||(kind==0x0014&&size>63)||(kind==0x0015&&size>63)||
           (kind==0x0008&&size!=20)||(kind==0x8028&&size!=4))return 0;
        if(kind==0x0008){if(at!=n-32||++integrity!=1)return 0;}
        if(kind==0x8028){if(at!=n-8||++fingerprint!=1)return 0;}
        if(kind==0x0001||kind==0x0020||kind==0x0016) {
            if(size<2)return 0;
            if((p[at+5]==1&&size!=8)||(p[at+5]==2&&size!=20)||(p[at+5]!=1&&p[at+5]!=2))return 0;
        }
        at+=4+padded;
    }
    return integrity==1&&fingerprint==1;
}
