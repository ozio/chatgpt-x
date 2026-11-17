#ifndef OR6_VOICE_PEER_H
#define OR6_VOICE_PEER_H
#include <stddef.h>
#include <stdint.h>

typedef struct OR6VoicePeer OR6VoicePeer;
typedef void (*OR6VoiceAudioCallback)(const int16_t *mono, size_t frames, void *user);
typedef void (*OR6VoiceEventCallback)(const char *utf8, size_t bytes, void *user);
typedef struct {
    uint64_t sentFrames, receivedFrames, receivedPackets, sentEvents, receivedEvents;
    int transportConnected, channelOpen, cancelled, failed;
} OR6VoicePeerStats;

/* Research transport: one peer/process, one serial worker; callbacks run there.
 * No microphone, playback, account, HTTP or credential access. PCM is mono48k.
 * Callbacks may request cancel/mute, but must not destroy/reenter the worker.
 * Only Cancel/Mute may be called from another thread. Cancel is a request;
 * worker quiescence precedes Destroy. There is no automatic reconnect. */
OR6VoicePeer *OR6VoicePeerCreate(OR6VoiceAudioCallback audio, OR6VoiceEventCallback event, void *user);
/* ChatGPT transceiver uses an externally negotiated channel, empty label, SID0. */
OR6VoicePeer *OR6VoicePeerCreateService(OR6VoiceAudioCallback audio, OR6VoiceEventCallback event, void *user);
int OR6VoicePeerOffer(OR6VoicePeer *peer, char *output, size_t capacity);
int OR6VoicePeerAnswer(OR6VoicePeer *peer, const char *sdp, size_t bytes);
int OR6VoicePeerTick(OR6VoicePeer *peer);
int OR6VoicePeerSendPCM(OR6VoicePeer *peer, const int16_t *mono, size_t frames);
int OR6VoicePeerSendEvent(OR6VoicePeer *peer, const char *utf8, size_t bytes);
void OR6VoicePeerMute(OR6VoicePeer *peer, int microphone, int output);
void OR6VoicePeerCancel(OR6VoicePeer *peer);
OR6VoicePeerStats OR6VoicePeerGetStats(OR6VoicePeer *peer);
void OR6VoicePeerDestroy(OR6VoicePeer *peer);
/* Serial worker only. Authenticated STUN responses renew consent; expiry is30s. */
void OR6VoicePeerConsent(OR6VoicePeer *peer,uint32_t *requests,uint32_t *responses,uint32_t *ageMS);
int OR6VoiceValidateAnswer(const char *sdp, size_t bytes);
#endif
