#include "OR6VoicePeer.h"
#include <peer.h>
#include <peer_connection.h>
#include <opus/opus.h>
#include <usrsctp.h>
#include <pthread.h>
#include <mach/mach_time.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct OR6VoicePeer {
    PeerConnection *rtc;
    OpusEncoder *encoder;
    OpusDecoder *decoder;
    pthread_mutex_t lock;
    OR6VoicePeerStats stats;
    OR6VoiceAudioCallback audio;
    OR6VoiceEventCallback event;
    void *user;
    uint64_t timer,consentAt,consentSentAt;
    uint32_t consentRequests,consentResponses;
    int consentPending;
    int microphoneMuted, outputMuted, offered, answered, channelRequested, negotiated;
};
#if OR6_VOICE_REALTIME_CONSENT
extern int or6rtc_peer_consent_pending(PeerConnection *peer);
extern int or6rtc_peer_request_consent(PeerConnection *peer);
#endif
static pthread_mutex_t globalLock=PTHREAD_MUTEX_INITIALIZER;
static int activePeer;
static uint64_t Millis(void) {
    mach_timebase_info_data_t tb; mach_timebase_info(&tb);
    uint64_t n=mach_absolute_time();
    return n/1000000*tb.numer/tb.denom + (n%1000000)*tb.numer/tb.denom/1000000;
}
static int Cancelled(void *user) {
    OR6VoicePeer *p=user;pthread_mutex_lock(&p->lock);
    int value=p->stats.cancelled;pthread_mutex_unlock(&p->lock);return value;
}
static void State(PeerConnectionState state, void *user) {
    OR6VoicePeer *p=user;
    p->stats.transportConnected=state==PEER_CONNECTION_CONNECTED;
    if(state==PEER_CONNECTION_FAILED)p->stats.failed=1;
}
static void Open(void *user) {
    OR6VoicePeer *p=user;
    if(Cancelled(p))return;
    if(p->negotiated){p->stats.channelOpen=1;return;}
    if(!p->channelRequested) {
        p->channelRequested=1;
        if(peer_connection_create_datachannel(p->rtc,DATA_CHANNEL_RELIABLE,0,0,"chatgptx","")<0)p->stats.failed=1;
    }
}
static void Ready(void *user){OR6VoicePeer*p=user;if(!Cancelled(p))p->stats.channelOpen=1;}
static void Close(void *user) { ((OR6VoicePeer*)user)->stats.channelOpen=0; }
static void Event(char *bytes,size_t count,void *user,uint16_t sid) {
    OR6VoicePeer *p=user;
    if(Cancelled(p)||sid!=0||!bytes||!count||count>16384)return;
    p->stats.receivedEvents++;
    if(p->event)p->event(bytes,count,p->user);
}
static void Audio(uint8_t *bytes,size_t count,void *user) {
    OR6VoicePeer *p=user;
    if(Cancelled(p)||!bytes||!count||count>1275)return;
    int16_t pcm[5760];
    int frames=opus_decode(p->decoder,bytes,(opus_int32)count,pcm,5760,0);
    if(frames<=0)return;
    p->stats.receivedPackets++;p->stats.receivedFrames+=(uint64_t)frames;
    pthread_mutex_lock(&p->lock);int muted=p->outputMuted;pthread_mutex_unlock(&p->lock);
    if(!muted&&p->audio)p->audio(pcm,(size_t)frames,p->user);
}
static OR6VoicePeer *Create(OR6VoiceAudioCallback audio,OR6VoiceEventCallback event,void *user,int negotiated) {
    pthread_mutex_lock(&globalLock);
    if(activePeer){pthread_mutex_unlock(&globalLock);return NULL;}
    activePeer=1;pthread_mutex_unlock(&globalLock);
    OR6VoicePeer *p=calloc(1,sizeof(*p));
    if(!p)goto release_slot;
    pthread_mutex_init(&p->lock,NULL);p->audio=audio;p->event=event;p->user=user;p->negotiated=negotiated;
    int error=0;p->encoder=opus_encoder_create(48000,1,OPUS_APPLICATION_VOIP,&error);
    if(!p->encoder||error!=OPUS_OK)goto fail;
    p->decoder=opus_decoder_create(48000,1,&error);
    if(!p->decoder||error!=OPUS_OK)goto fail;
    opus_encoder_ctl(p->encoder,OPUS_SET_BITRATE(24000));
    opus_encoder_ctl(p->encoder,OPUS_SET_COMPLEXITY(3));
    if(peer_init())goto fail;
    PeerConfiguration config;memset(&config,0,sizeof(config));
    config.audio_codec=CODEC_OPUS;config.datachannel=DATA_CHANNEL_STRING;
    config.onaudiotrack=Audio;config.cancelled=Cancelled;config.channel_ready=Ready;config.user_data=p;
    p->rtc=peer_connection_create(&config);
    if(!p->rtc){peer_deinit();goto fail;}
    peer_connection_oniceconnectionstatechange(p->rtc,State);
    peer_connection_ondatachannel(p->rtc,Event,Open,Close);
    p->timer=Millis();return p;
fail:
    if(p->encoder)opus_encoder_destroy(p->encoder);
    if(p->decoder)opus_decoder_destroy(p->decoder);
    pthread_mutex_destroy(&p->lock);free(p);
release_slot:
    pthread_mutex_lock(&globalLock);activePeer=0;pthread_mutex_unlock(&globalLock);return NULL;
}
OR6VoicePeer *OR6VoicePeerCreate(OR6VoiceAudioCallback audio,OR6VoiceEventCallback event,void *user){return Create(audio,event,user,0);}
OR6VoicePeer *OR6VoicePeerCreateService(OR6VoiceAudioCallback audio,OR6VoiceEventCallback event,void *user){return Create(audio,event,user,1);}
int OR6VoicePeerOffer(OR6VoicePeer *p,char *out,size_t capacity) {
    if(!p||!out||p->offered||Cancelled(p)||capacity<8192)return 0;
    const char *sdp=peer_connection_create_offer(p->rtc);
    if(!sdp||peer_connection_get_state(p->rtc)==PEER_CONNECTION_FAILED)return 0;
    size_t n=strlen(sdp);if(!n||n>=capacity)return 0;
    memcpy(out,sdp,n+1);p->offered=1;return 1;
}
static int Prefix(const char *line,size_t n,const char *prefix) {
    size_t k=strlen(prefix);return n>=k&&!memcmp(line,prefix,k);
}
int OR6VoiceValidateAnswer(const char *sdp,size_t n) {
    if(!sdp||n<64||n>8191||memchr(sdp,0,n)||memcmp(sdp,"v=0\r\n",5))return 0;
    const char *at=sdp,*end=sdp+n;unsigned candidates=0;int audio=0,application=0,opus=0,fingerprint=0,pwd=0,ufrag=0;
    while(at<end) {
        const char *lf=memchr(at,'\n',(size_t)(end-at));
        if(!lf||lf==at||lf[-1]!='\r')return 0;
        const char *line=lf-1;
        if(line-at>=255)return 0;
        size_t length=(size_t)(line-at);
        for(size_t i=0;i<length;i++)if((unsigned char)at[i]<32||(unsigned char)at[i]>126)return 0;
        if(Prefix(at,length,"m=audio "))audio++;
        if(Prefix(at,length,"m=application "))application++;
        if(Prefix(at,length,"a=rtpmap:111 opus/48000/"))opus++;
        if(Prefix(at,length,"a=fingerprint:sha-256 ")) {
            if(length!=22+95)return 0;
            for(size_t i=22;i<length;i++) {
                int c=at[i];
                if((i-22)%3==2){if(c!=':')return 0;}
                else if(!((c>='0'&&c<='9')||(c>='A'&&c<='F')||(c>='a'&&c<='f')))return 0;
            }
            fingerprint++;
        }
        if(Prefix(at,length,"a=ice-ufrag:")){if(length<16||length>252)return 0;ufrag++;}
        if(Prefix(at,length,"a=ice-pwd:")){if(length<32||length>252)return 0;pwd++;}
        if(Prefix(at,length,"a=candidate:")&&++candidates>10)return 0;
        at=line+2;
    }
    return audio==1&&application==1&&opus==1&&fingerprint>=1&&pwd>=1&&ufrag>=1&&candidates>=1;
}
int OR6VoicePeerAnswer(OR6VoicePeer *p,const char *sdp,size_t n) {
    if(!p||!p->offered||p->answered||Cancelled(p)||!OR6VoiceValidateAnswer(sdp,n))return 0;
    char copy[8192];memcpy(copy,sdp,n);copy[n]=0;
    peer_connection_set_remote_description(p->rtc,copy,SDP_TYPE_ANSWER);p->answered=1;return 1;
}
int OR6VoicePeerTick(OR6VoicePeer *p) {
    if(!p)return 0;
    if(Cancelled(p)){peer_connection_close(p->rtc);p->stats.transportConnected=p->stats.channelOpen=0;return 0;}
    uint64_t now=Millis(),delta=now-p->timer;
    if(delta){usrsctp_handle_timers((uint32_t)(delta>1000?1000:delta));p->timer=now;}
    if(!p->answered)return 1;
    if(peer_connection_loop(p->rtc)<0||p->stats.failed)return 0;
    #if OR6_VOICE_REALTIME_CONSENT
    if(p->stats.transportConnected){
        if(!p->consentAt){p->consentAt=now;p->consentSentAt=now;}
        if(p->consentPending&&!or6rtc_peer_consent_pending(p->rtc)){p->consentPending=0;p->consentAt=now;p->consentResponses++;}
        if(now-p->consentAt>=30000){p->stats.failed=1;return 0;}
        if(now-p->consentSentAt>=5000){p->consentSentAt=now;if(or6rtc_peer_request_consent(p->rtc)>0){p->consentRequests++;p->consentPending=1;}}
    }
    #endif
    return 1;
}
int OR6VoicePeerSendPCM(OR6VoicePeer *p,const int16_t *mono,size_t frames) {
    if(!p||!mono||frames!=960||Cancelled(p)||!p->stats.transportConnected)return 0;
    pthread_mutex_lock(&p->lock);int muted=p->microphoneMuted;pthread_mutex_unlock(&p->lock);
    int16_t silence[960]={0};unsigned char packet[1275];
    int n=opus_encode(p->encoder,muted?silence:mono,960,packet,sizeof(packet));
    if(n<=0||peer_connection_send_audio(p->rtc,packet,(size_t)n)<0)return 0;
    p->stats.sentFrames+=frames;return 1;
}
int OR6VoicePeerSendEvent(OR6VoicePeer *p,const char *bytes,size_t n) {
    if(!p||!bytes||!n||n>16384||Cancelled(p)||!p->stats.channelOpen)return 0;
    if(peer_connection_datachannel_send(p->rtc,(char*)bytes,n)<0)return 0;
    p->stats.sentEvents++;return 1;
}
void OR6VoicePeerMute(OR6VoicePeer *p,int mic,int output) {
    if(!p)return;
    pthread_mutex_lock(&p->lock);p->microphoneMuted=!!mic;p->outputMuted=!!output;pthread_mutex_unlock(&p->lock);
}
void OR6VoicePeerCancel(OR6VoicePeer *p) {
    if(!p)return;pthread_mutex_lock(&p->lock);p->stats.cancelled=1;pthread_mutex_unlock(&p->lock);
}
OR6VoicePeerStats OR6VoicePeerGetStats(OR6VoicePeer *p) {
    OR6VoicePeerStats stats={0};if(!p)return stats;
    pthread_mutex_lock(&p->lock);stats=p->stats;pthread_mutex_unlock(&p->lock);return stats;
}
void OR6VoicePeerConsent(OR6VoicePeer *p,uint32_t *requests,uint32_t *responses,uint32_t *ageMS){if(requests)*requests=p?p->consentRequests:0;if(responses)*responses=p?p->consentResponses:0;if(ageMS)*ageMS=p&&p->consentAt?(uint32_t)(Millis()-p->consentAt):0;}
void OR6VoicePeerDestroy(OR6VoicePeer *p) {
    if(!p)return;OR6VoicePeerCancel(p);
    peer_connection_close(p->rtc);peer_connection_destroy(p->rtc);
    /* no SCTP timer thread or callback may retain the retired peer */
    for(unsigned i=0;i<10;i++)usrsctp_handle_timers(100);
    peer_deinit();opus_encoder_destroy(p->encoder);opus_decoder_destroy(p->decoder);
    pthread_mutex_destroy(&p->lock);free(p);
    pthread_mutex_lock(&globalLock);activePeer=0;pthread_mutex_unlock(&globalLock);
}
