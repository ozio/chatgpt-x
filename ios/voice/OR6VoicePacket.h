#ifndef OR6_VOICE_PACKET_H
#define OR6_VOICE_PACKET_H
#include <stdint.h>
#include <stddef.h>
typedef struct {
    const uint8_t *payload;
    size_t bytes;
    uint16_t sequence;
    uint32_t timestamp, ssrc;
    uint8_t payloadType, marker;
} OR6VoiceRTP;
/* Authenticated plaintext only. Handles CSRCs, extensions and RTP padding. */
int OR6VoiceParseRTP(const uint8_t *packet, size_t bytes, OR6VoiceRTP *result);
/* Bound every attribute before handing a datagram to the vendor STUN parser. */
int OR6VoiceValidateSTUN(const uint8_t *packet, size_t bytes);
#endif
