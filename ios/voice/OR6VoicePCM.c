#include "OR6VoicePCM.h"
#include <string.h>
_Static_assert(__atomic_always_lock_free(4,0),"32-bit atomics must be inline on this target");
void OR6VoicePCMInit(OR6VoicePCM *q) { memset(q,0,sizeof(*q)); }
void OR6VoicePCMFlush(OR6VoicePCM *q) { __atomic_store_n(&q->flush,1,__ATOMIC_RELEASE); }
uint32_t OR6VoicePCMOverruns(OR6VoicePCM *q) { return __atomic_load_n(&q->overruns,__ATOMIC_RELAXED); }
size_t OR6VoicePCMWrite(OR6VoicePCM *q,const int16_t *samples,size_t n) {
    if(!q||!samples||!n||n>OR6_VOICE_PCM_CAPACITY)return 0;
    uint32_t w=__atomic_load_n(&q->write,__ATOMIC_RELAXED),r=__atomic_load_n(&q->read,__ATOMIC_ACQUIRE);
    if(w-r>OR6_VOICE_PCM_CAPACITY||n>OR6_VOICE_PCM_CAPACITY-(w-r)) {
        __atomic_fetch_add(&q->overruns,1,__ATOMIC_RELAXED);return 0;
    }
    for(size_t i=0;i<n;i++)q->samples[(w+(uint32_t)i)&(OR6_VOICE_PCM_CAPACITY-1)]=samples[i];
    __atomic_store_n(&q->write,w+(uint32_t)n,__ATOMIC_RELEASE);return n;
}
size_t OR6VoicePCMRead(OR6VoicePCM *q,int16_t *samples,size_t n) {
    if(!q||!samples||!n||n>OR6_VOICE_PCM_CAPACITY)return 0;
    uint32_t r=__atomic_load_n(&q->read,__ATOMIC_RELAXED),w=__atomic_load_n(&q->write,__ATOMIC_ACQUIRE);
    if(__atomic_exchange_n(&q->flush,0,__ATOMIC_ACQ_REL)) {
        __atomic_store_n(&q->read,w,__ATOMIC_RELEASE);return 0;
    }
    size_t available=w-r;if(available>OR6_VOICE_PCM_CAPACITY)return 0;
    if(n>available)n=available;
    for(size_t i=0;i<n;i++)samples[i]=q->samples[(r+(uint32_t)i)&(OR6_VOICE_PCM_CAPACITY-1)];
    __atomic_store_n(&q->read,r+(uint32_t)n,__ATOMIC_RELEASE);return n;
}
