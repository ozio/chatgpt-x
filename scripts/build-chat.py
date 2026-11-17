#!/usr/bin/env python3
"""Build ChatGPTX from a captured source tree; no network/install actions."""
import argparse, hashlib, importlib.util, json, os, plistlib, shutil, subprocess
from pathlib import Path
from archive_utils import deterministic_zip
R=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--acceptance',action='store_true');p.add_argument('--webport-probe-bundled',action='store_true',help='temporary physical bundled-engine acceptance; final build uses system priority');p.add_argument('--webport-runtime',type=Path,default=R/'.artifacts/webport-bundle-20261114/runtime-v2');p.add_argument('--build-number',type=int,default=11);a=p.parse_args();O=a.output.resolve();assert not O.exists();O.mkdir(parents=True)
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
resources=O/'sentinel-resources'
subprocess.run(['node',str(R/'support/sentinel-minimal/extract.mjs'),str(resources)],cwd=R,check=True)
provenance=json.loads((resources/'provenance.json').read_text())
assert sha(resources/'MinimalSentinelCore.js')==provenance['sourceSHA256']
project=R/'ios/standalone/chat-app';t=json.loads((R/'.artifacts/native-api-20261109/transport/build.json').read_text());mbed=R/'.artifacts/standalone-20261107/mbedtls/mbedtls-3.6.7';archive=Path(t['armv7Archive']['path']);roots=R/'.artifacts/standalone-20261107/system-public-roots.pem';assert sha(archive)==t['armv7Archive']['sha256'];assert sha(Path(t['config']))==t['configSHA256']
sources=[Path(__file__).resolve(),R/'scripts/archive_utils.py',R/'support/sentinel-minimal/extract.mjs',*sorted((R/'ios/chat').rglob('*')),*sorted((R/'ios/localization').rglob('*')),*sorted((R/'ios/api').glob('*.[hm]')),*sorted((R/'ios/api/priority9').glob('*.[hm]')),*sorted((R/'ios/api/priority8').glob('*.[hm]')),*sorted((R/'ios/ui/priority9').glob('*.[hm]')),*sorted((R/'ios/ui/priority8').glob('*.[hm]')),*sorted(f for d in ['priority7','priority7b','priority7c','priority7d','priority7e','priority7f','priority7g','priority7h','priority7all'] for f in (R/'ios/api'/d).glob('*.[hm]')),R/'ios/api/priority7all/admission.json',*[R/('support/priority%s/contracts.json'%k) for k in ['7','7b','7c','7d','7e','7f','7g']],*sorted((R/'ios/ui/priority7').glob('*.[hm]')),*sorted(f for d in ['priority6a','priority6b','priority6c','priority6d','priority6e','priority6f','priority6all'] for f in (R/'ios/api'/d).glob('*.[hm]')),*[R/('support/priority%s/contracts.json'%k) for k in ['6a','6b','6c','6d','6e','6f']],R/'ios/api/priority6all/admission.json',*sorted((R/'ios/ui/priority6').glob('*.[hm]')),*sorted((R/'ios/ui').glob('*.[hm]')),R/'ios/ui/RCGlyphData.inc',R/'ios/ui/RCKit.mk',*sorted((R/'ios/ui/Resources').glob('*.png')),R/'ios/OR6Audio.h',R/'ios/OR6Audio.m',R/'ios/OR6Files.h',R/'ios/OR6Files.m',R/'tests/chat-ui9/PhoneFixture.m',*sorted((R/'ios/auth').glob('OR6Web*')),R/'ios/auth/OR6AuthEngine.h',R/'ios/OR6Content.h',R/'ios/OR6Content.m',R/'prototype-login/ORLHTTP.m',R/'prototype-login/ORLHTTP.h',R/'support/native-api/contracts.json',Path(t['config']),R/'ios/standalone/web-session-app/Resources/web-session-probe.js',*[f for f in project.glob('*')if f.is_file() and f.name!='.stamp'],*sorted((project/'Resources').rglob('*'))];sources += [R/p for p in ['tests/chat-ui8-physical/PhoneFixture.m','tests/api/priority8/main.m','tests/api/priority9/main.m','tests/web-session/CoreFixture.m','tests/chat-ui7-live/Policy.h','tests/chat-ui7-live/Policy.m','tests/chat-ui7-live/PhoneProbe.m','tests/chat-ui7-physical/Backend.h','tests/chat-ui7-physical/Backend.m','tests/chat-ui7-physical/PhoneFixture.m']] if a.acceptance else []
sources += [R/'tests/stock-production/PhoneCycle.m',R/'tests/codex-ui/PhoneFixture.m',R/'tests/codex-pair/key-phone.m',R/'tests/codex-pair/phone-qr-fixtures.json'] if a.acceptance else []
sources += [*sorted((R/'ios/api/voice8').glob('*.[hm]'))]
sources += [*sorted((R/'ios/api/selected20').glob('*.[hm]')),*sorted((R/'ios/ui/selected20').glob('*.[hm]')),*[R/p for p in ['ios/api/priority5a/OR6API5APolicy.h','ios/api/priority5a/OR6API5APolicy.m','ios/api/priority4b/OR6API4BPolicy.h','ios/api/priority4b/OR6API4BPolicy.m','support/priority5a/contracts.json','support/priority4b/contracts.json']]]
sources += [R/'scripts/build-stock-preparation.mjs',*sorted((R/'support/stock-compat').glob('*'))]
sources += [*sorted((R/'ios/api/codex').glob('*.[hm]')),*sorted((R/'ios/api/codex/pair').glob('*.[hm]')),R/'ios/auth/OR6OAuthCrypto.h',R/'ios/auth/OR6OAuthCrypto.m',R/'support/codex/contracts.json']
sources += [*sorted((R/'ios/webport').glob('*.[chm]')),R/'scripts/webport-bundle.py',R/'support/webport-bundle/inputs.json',R/'support/webport-bundle/runtime.json']
sources += [p for k in ['all','local','content','account'] for p in (R/('ios/api/revisit67'+k)).glob('*') if p.suffix in ['.h','.m','.inc']]
sources += [R/'ios/api/codex/OR6CodexHost.inc',*sorted((R/'support/codex7').glob('*')),R/'support/codex/build-contracts.py']
sources += [p for k in ['priority5a','priority5b','priority5c','priority5d','priority5e','priority5all','revisit5all','revisit5local','revisit5content','revisit5system','revisit5asr'] for p in (R/'ios/api'/k).glob('*') if p.suffix in ['.h','.m','.inc']]
sources += [R/f'support/priority5{k}/contracts.json'for k in 'abcde']
# Pinned offline recognizer: package only verified local build inputs, never fetch during app build.
asr=json.loads((R/'.artifacts/api5-recheck-20261114/asr/build.json').read_text())
assert asr['tag']=='v5.0.4' and asr['commit']=='a9ec4b881de75771d8e6b8ded2823266589cbd5d'
asrArchive=Path(asr['archives']['armv7']);assert sha(asrArchive)==asr['archiveBinarySHA256']['armv7']
for path,h in asr['includeHeaderSHA256']['armv7'].items():assert sha(Path(path))==h,path
for path,h in asr['configurationHeaderSHA256']['armv7'].items():assert sha(Path(path))==h,path
for path,h in asr['effectiveSourceSHA256'].items():assert sha(Path(asr['sourceDirectory'])/path)==h,path
asrModel=Path(asr['modelDirectory']);asrResources={str(p.relative_to(asrModel)):sha(p)for p in asrModel.rglob('*')if p.is_file()}
assert json.loads((asrModel/'manifest.json').read_text())['files']==asr['modelSHA256']
for name,h in asr['modelSHA256'].items():assert asrResources[name]==h,name
sources += [R/'support/revisit5asr/build.py',R/'.artifacts/api5-recheck-20261114/asr/build.json',R/'.artifacts/api5-recheck-20261114/asr/portable.patch',asrArchive,*map(Path,asr['includeHeaderSHA256']['armv7']),*map(Path,asr['configurationHeaderSHA256']['armv7']),*[Path(asr['sourceDirectory'])/'src'/name for name in asr['librarySources']],*asrModel.rglob('*')]
rtc=json.loads((R/'.artifacts/voice-realtime-20261117/armv7/build.json').read_text());rtcArchive=Path(rtc['archive']);assert sha(rtcArchive)==rtc['archiveSHA256']
for path,h in {**rtc['sources'],**rtc.get('headers',{})}.items():assert sha(R/path.replace('research/','support/',1))==h,path
sources += [*sorted((R/'ios/api/voice-realtime').glob('*.[hm]')),*sorted((R/'ios/voice').glob('*.[hmc]')),R/'support/voice-realtime/build.py',R/'.artifacts/voice-realtime-20261117/armv7/build.json',rtcArchive,R/'.artifacts/voice-runtime-20261110/THIRD_PARTY_NOTICES.txt']
sources=sorted(set(x for x in sources if x.is_file()));before={str(x.relative_to(R)):sha(x)for x in sources}
for f in sources:
 dest=O/'source-snapshot'/f.relative_to(R);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(f,dest)
# Compile exactly the captured inputs in a private build directory.
project=O/'source-snapshot/ios/standalone/chat-app'
ssh=json.loads((R/'.artifacts/codex8-api-20261113/ssh-build.json').read_text());ssh_archive=Path(ssh['archives']['armv7']['path']);assert sha(ssh_archive)==ssh['archives']['armv7']['sha256']
env=dict(os.environ,OR6_CODEX_SSH_SOURCE=str(R/'.artifacts/codex8-api-20261113/libssh2-1.11.1'),OR6_CODEX_SSH_ARCHIVE=str(ssh_archive),THEOS=os.environ.get('THEOS',str(Path.home()/'theos')),OR6_API_MBED_SOURCE=str(mbed),OR6_API_MBED_ARCHIVE=str(archive),OR6_CHAT_ACCEPTANCE='1'if a.acceptance else'0')
env.update(OR6_REALTIME_ARCHIVE=str(O/'source-snapshot'/rtcArchive.relative_to(R)))
env.update(OR6_ASR_ARCHIVE=str(O/'source-snapshot'/asrArchive.relative_to(R)),OR6_ASR_INCLUDE_FLAGS=' '.join('-I'+str(O/'source-snapshot'/Path(flag[2:]).relative_to(R))for flag in asr['includeFlags']['armv7']))
with(O/'build.log').open('w')as log:
 result=subprocess.run(['gmake','clean','package','messages=yes'],cwd=project,env=env,stdout=log,stderr=subprocess.STDOUT)
(O/'build.exit').write_text(str(result.returncode)+'\n');assert result.returncode==0,'see '+str(O/'build.log')
runtime=a.webport_runtime.resolve();pin=json.loads((O/'source-snapshot/support/webport-bundle/runtime.json').read_text());assert sha(runtime/'Manifest.json')==pin['manifestSHA256'];manifest=json.loads((runtime/'Manifest.json').read_text());assert manifest['schema']==1 and manifest['inputSHA256']==pin['inputSHA256']==sha(O/'source-snapshot/support/webport-bundle/inputs.json')
for name,record in manifest['files'].items():assert sha(runtime/name)==record['sha256'],name
app=project/'.theos/_/Applications/ChatGPTX.app';info=plistlib.loads((app/'Info.plist').read_bytes());info['CFBundleVersion']=str(a.build_number);
if a.webport_probe_bundled:info['OR6WebPortProbeRequireBundled']=True
(app/'Info.plist').write_bytes(plistlib.dumps(info));assert info['CFBundleIdentifier']=='io.ozio.chatgptx'
shutil.copytree(runtime,app/'WebPort',symlinks=True)
for source,name in [(roots,'roots.pem'),(R/'support/native-api/contracts.json','contracts.json'),(R/'ios/chat/Resources/chat-web.js','chat-web.js'),(R/'ios/standalone/web-session-app/Resources/web-session-probe.js','web-session-probe.js'),(R/'ios/chat/Resources/Default.png','Default.png'),(R/'ios/chat/Resources/Default@2x.png','Default@2x.png'),(R/'ios/chat/Resources/Default-568h@2x.png','Default-568h@2x.png')]:shutil.copyfile(source,app/name)
shutil.copyfile(resources/'MinimalSentinelCore.js',app/'MinimalSentinelCore.js')
subprocess.run(['node',str(R/'scripts/build-stock-preparation.mjs'),str(resources/'MinimalSentinelCore.js'),str(app/'StockPreparation'),str(roots)],cwd=R,check=True)
# API7 registry extensions and the admission tiers, from the captured snapshot (default-denied writes).
S=O/'source-snapshot'
shutil.copytree(S/asrModel.relative_to(R),app/'Rev5ASRModel')
shutil.copyfile(S/'support/codex/contracts.json',app/'codex-contracts.json')
if a.acceptance:shutil.copyfile(S/'tests/codex-pair/phone-qr-fixtures.json',app/'codex-pair-qr-fixtures.json')
for k in ['7','7b','7c','7d','7e','7f','7g','6a','6b','6c','6d','6e','6f','5a','5b','5c','5d','5e','4b']:shutil.copyfile(S/('support/priority%s/contracts.json'%k),app/('contracts-%s.json'%k))
shutil.copyfile(S/'ios/api/priority7all/admission.json',app/'priority7-admission.json')
shutil.copyfile(S/'ios/api/priority6all/admission.json',app/'priority6-admission.json')
shutil.copyfile(R/'ios/chat/Resources/sentinel-bridge.js',app/'sentinel-bridge.js')
for language in ['en','ru']:
 shutil.copytree(R/'ios/localization/Resources'/(language+'.lproj'),app/(language+'.lproj'),dirs_exist_ok=True)
(app/'Licenses').mkdir(exist_ok=True);shutil.copyfile(R/'LICENSE',app/'Licenses/Application.txt');shutil.copyfile(mbed/'LICENSE',app/'Licenses/MbedTLS.txt');shutil.copyfile(R/'.artifacts/voice-runtime-20261110/THIRD_PARTY_NOTICES.txt',app/'Licenses/Realtime-Third-Party.txt');shutil.copyfile(S/'ios/chat/codex/qr/LICENSE',app/'Licenses/Quirc.txt');shutil.copyfile(R/'.artifacts/codex8-api-20261113/libssh2-1.11.1/COPYING',app/'Licenses/LibSSH2.txt');ent=O/'Entitlements.plist';ent.write_bytes(plistlib.dumps({'application-identifier':'io.ozio.chatgptx'}));subprocess.run(['ldid','-Hsha1','-S'+str(ent),app/'ChatGPTX'],check=True)
# Prebuilt archives keep absolute build paths in assert messages. Replace each local checkout
# prefix with a neutral path of the same length, then re-sign exactly as Theos does.
import re
binary=app/'ChatGPTX';data=binary.read_bytes();home=re.escape(str(Path.home()).encode())
data=re.sub(home+rb'/[^\x00]*?/(?=\.artifacts/|ios/|support/|prototype-login/|tests/)',lambda m:b'/build'+b'/'*(len(m.group(0))-6),data)
data=data.replace(str(Path.home()).encode(),b'/build'+b'/'*(len(str(Path.home()))-6))
ents=subprocess.run(['ldid','-e',str(binary)],check=True,capture_output=True).stdout;assert b'application-identifier' in ents,'entitlements missing before re-sign';entfile=O/'entitlements.plist';entfile.write_bytes(ents)
binary.write_bytes(data);subprocess.run(['ldid','-S'+str(entfile),'-Hsha1',str(binary)],check=True,env=dict(os.environ,CODESIGN_ALLOCATE=os.environ.get('THEOS_LEGACY_PREFIX',str(Path.home()/'theos/toolchain/legacy'))+'/bin/arm-apple-darwin11-codesign_allocate'))
assert str(Path.home()).encode() not in binary.read_bytes(),'local path left in binary'
assert subprocess.run(['ldid','-e',str(binary)],check=True,capture_output=True).stdout==ents,'entitlements changed by re-sign'
spec=importlib.util.spec_from_file_location('macho',R/'scripts/macho_verify.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);data=(app/'ChatGPTX').read_bytes();mach=m.macho(data);assert mach['architecture']=='armv7'and mach['minimum_ios']=='6.0'and mach['sdk']=='6.1'
public={'/System/Library/Frameworks/'+x+'.framework/'+x for x in ['EventKit','AssetsLibrary','CoreLocation','MessageUI','UIKit','Foundation','CoreFoundation','CoreGraphics','CoreText','Security','CFNetwork','AVFoundation','AudioToolbox','ImageIO','MediaPlayer','CoreVideo','CoreMedia']}|{'/usr/lib/libobjc.A.dylib','/usr/lib/libz.1.dylib','/usr/lib/libSystem.B.dylib'};assert set(mach['libraries'])<=public
for marker in [b'/PrivateFrameworks/',b'127.0.0.1:28447']:assert marker not in data
assert a.acceptance or all(m not in data for m in [b'OR6CodexLegacyECProbe',b'codex-pair-qr-fixtures',b'OR6CodexFixture',b'CodexFixtureBackend',b'ChatUIAcceptanceKey',b'ChatGPTXUI7Fixture',b'UI7FBackend',b'ui7_fixture_open',b'UI7ReadShapeCapture',b'UI7ReadShapes.json',b'live7_begin',b'ChatServerAcceptance.json',b'StockProductionCycle.json',b'OR6StockCycle'])
epoch=int(subprocess.check_output(['git','show','-s','--format=%ct','HEAD'],cwd=R,text=True).strip());files=[('Payload/ChatGPTX.app/'+f.relative_to(app).as_posix(),f.read_bytes(),0o755 if f.name=='ChatGPTX' or f.suffix=='.dylib' else 0o644)for f in sorted(app.rglob('*'))if f.is_file()];ipa=O/'ChatGPTX.ipa';ipa.write_bytes(deterministic_zip(files,epoch));assert all(sha(R/k)==v for k,v in before.items())
report={'schema':1,'bundleID':info['CFBundleIdentifier'],'bundleVersion':info['CFBundleVersion'],'acceptance':a.acceptance,'ipaSHA256':sha(ipa),'ipaBytes':ipa.stat().st_size,'appMacho':mach,'sourceFiles':before,'realtimeArchiveSHA256':sha(rtcArchive),'offlineASR':{'engine':'pocketsphinx-5.0.4','language':'en-US','resourceSHA256':asrResources,'archiveSHA256':sha(asrArchive),'commit':asr['commit'],'patches':asr['patches']},'codexSSHArchiveSHA256':sha(ssh_archive),'archiveSHA256':sha(archive),'rootsSHA256':sha(roots),'requiresMacBridge':False,'networkDuringBuild':False,'sentinelCoreSHA256':provenance['sourceSHA256'],'sentinelProvenance':provenance,'nativeSendSSE':True,'noAppleSystemComponentsBundled':True,'bundledThirdPartyEngine':'WebPort','webportRuntimeManifestSHA256':sha(runtime/'Manifest.json'),'webportRequireBundled':a.webport_probe_bundled,'webportRuntime':str(runtime)};(O/'build.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:report[k]for k in ['bundleVersion','acceptance','ipaSHA256','ipaBytes']}))
