#!/usr/bin/env python3
"""Isolated TLS symbols for RTC; reuse pinned codec/SCTP archives, no downloads."""
from pathlib import Path
import json,hashlib,re,subprocess,argparse,concurrent.futures,shutil
R=Path(__file__).resolve().parents[2];OLD=R/'.artifacts/voice-runtime-20261110';O=R/'.artifacts/voice-realtime-20261117'
a=argparse.ArgumentParser();a.add_argument('--target',choices=['host','armv7'],required=True);mode=a.parse_args().target;D=O/mode;D.mkdir(parents=True,exist_ok=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
base=json.loads((OLD/mode/'build.json').read_text());tool=json.loads((R/'.artifacts/native-api-20261109/transport/build.json').read_text());commands=[]
def run(name,args):
 p=subprocess.run([str(x)for x in args],cwd=R,capture_output=True,text=True);(D/(name+'.log')).write_text(p.stdout+p.stderr);commands.append({'name':name,'exit':p.returncode});assert p.returncode==0,(name,p.stderr[-5000:]);return p.stdout
# Derive the symbol map from the pinned archive, rather than guessing MbedTLS API names.
mbed=R/'.artifacts/standalone-20261107/mbedtls/mbedtls-3.6.7';oldArchive=OLD/mode/'libmbedvoice.a';expected=next(x['sha256']for x in base['archives']if x['path'].endswith('libmbedvoice.a'));assert sha(oldArchive)==expected
names=sorted(set(re.findall(r'\b_((?:mbedtls_|psa_)[A-Za-z0-9_]+)$',run('symbols-before',['nm','-gU',oldArchive]),re.M)));assert len(names)>500
prefix=D/'tls-prefix.h';prefix.write_text('/* Generated private RTC TLS namespace. Never include from HTTP callers. */\n'+''.join('#define '+n+' or6rtc_'+n+'\n'for n in names))
# Preserve the reviewed narrow compatibility copy. Track every extra patch here.
peer=D/'peer';shutil.copytree(OLD/'prepared/libpeer/src',peer,dirs_exist_ok=True)
# An audio-only native offer needs no SDP-provided SSRC if authenticated RTP later identifies PT111.
p=peer/'peer_connection.c';s=p.read_text();old='if (ssrc == pc->remote_assrc) {';assert s.count(old)==1;s=s.replace(old,'if (ssrc == pc->remote_assrc || (!pc->remote_assrc && (pc->agent_buf[1] & 127) == 111 && pc->config.audio_codec == CODEC_OPUS)) {\n            if (!pc->remote_assrc) pc->remote_assrc = ssrc;');p.write_text(s+'\n/* Narrow private hooks; PeerConnection remains opaque to the app. */\nint or6rtc_peer_consent_pending(PeerConnection *pc){return pc->agent.binding_request_pending;}\nint or6rtc_peer_request_consent(PeerConnection *pc){return agent_send_binding_request(&pc->agent); }\n')
flags=base['flags'];includes=['-I'+str(mbed/'include'),'-I'+str(mbed/'library'),'-I'+str(peer),'-I'+str(OLD/mode/'dist/include'),'-I'+str(R/'ios/voice')];extra=['-DOR6_VOICE_REALTIME_CONSENT=1','-include',prefix,'-DMBEDTLS_USER_CONFIG_FILE="'+str(R/'support/voice-runtime/mbed-voice.h')+'"',*base['defines'],'-Wno-deprecated-declarations']
sources=sorted((mbed/'library').glob('*.c'))+[R/'support/voice-runtime/clock.c']+[p for p in sorted(peer.glob('*.c'))if p.name not in ['peer_signaling.c','ssl_transport.c']]+[R/'ios/voice'/p for p in ['OR6VoicePeer.c','OR6VoicePacket.c','OR6VoicePCM.c']]
objects=D/'objects';objects.mkdir(exist_ok=True)
def compile(p):
 name=('mbed-'if p.parent.name=='library'else'peer-'if p.parent==peer else'own-')+p.stem;o=objects/(name+'.o');run(name,[tool['clang'],*flags,*includes,*extra,'-c',p,'-o',o]);return o
with concurrent.futures.ThreadPoolExecutor(max_workers=4)as pool:obs=list(pool.map(compile,sources))
codec=[]
for x in base['archives']:
 p=R/x['path']
 if p.name in ['libOR6VoiceNative.a','libor6voice.a','libpeer.a','libmbedvoice.a']:continue
 assert sha(p)==x['sha256'];codec.append(p)
archive=D/'libOR6Realtime.a';run('archive',['xcrun','libtool','-static','-o',archive,*obs,*codec]);defined=run('symbols-after',['nm','-gU',archive]);plain=set(re.findall(r'\b_((?:mbedtls_|psa_)[A-Za-z0-9_]+)$',defined,re.M));assert not plain,plain
http=Path(tool['hostArchive'if mode=='host'else'armv7Archive']['path']);assert sha(http)==tool['hostArchive'if mode=='host'else'armv7Archive']['sha256'];httpNames=set(re.findall(r'\b_(\w+)$',run('http-symbols',['nm','-gU',http]),re.M));rtcNames=set(re.findall(r'\b_(\w+)$',defined,re.M));assert not httpNames&rtcNames,httpNames&rtcNames
report={'target':mode,'archive':str(archive),'archiveSHA256':sha(archive),'prefix':str(prefix),'prefixSHA256':sha(prefix),'renamedSymbols':len(names),'HTTPArchive':str(http),'HTTPArchiveSHA256':sha(http),'symbolIntersection':[],'sources':{str(p.relative_to(R)):sha(p)for p in sources},'dependencyArchives':{str(p.relative_to(R)):sha(p)for p in codec},'headers':{str(p.relative_to(R)):sha(p)for p in [*sorted((R/'ios/voice').glob('*.h')),*sorted(peer.glob('*.h')),R/'support/voice-runtime/mbed-voice.h']},'includes':includes,'defines':[str(x) for x in extra],'flags':flags,'commands':commands,'accountRequests':0};(D/'build.json').write_text(json.dumps(report,indent=2)+'\n');print('RTC_TLS_ISOLATED',mode,len(names))
