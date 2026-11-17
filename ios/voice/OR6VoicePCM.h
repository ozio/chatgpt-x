#ifndef OR6_VOICE_PCM_H
#define OR6_VOICE_PCM_H
#include <stddef.h>
#include <stdint.h>
#define OR6_VOICE_PCM_CAPACITY 16384
/* One producer and one consumer. Flush is requested by any thread, performed
 * only by the consumer. No allocations, locks, logging or callbacks in I/O. */
typedef struct {
    uint32_t read, write, flush, overruns;
    int16_t samples[OR6_VOICE_PCM_CAPACITY];
} OR6VoicePCM;
void OR6VoicePCMInit(OR6VoicePCM *queue);
size_t OR6VoicePCMWrite(OR6VoicePCM *queue,const int16_t *samples,size_t frames);
size_t OR6VoicePCMRead(OR6VoicePCM *queue,int16_t *samples,size_t frames);
void OR6VoicePCMFlush(OR6VoicePCM *queue);
uint32_t OR6VoicePCMOverruns(OR6VoicePCM *queue);
#endif
