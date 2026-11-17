#!/usr/bin/env python3
"""One account-free stock probe over direct USB; retain actual production state."""
import argparse,json,pathlib,re,shlex,sys,time
R=pathlib.Path(__file__).resolve().parents[2];sys.path.insert(0,str(R/'scripts'))
import phone
from installation_proxy import Proxy
q=argparse.ArgumentParser();q.add_argument('--package',type=pathlib.Path,required=True);q.add_argument('--output',type=pathlib.Path,required=True);q.add_argument('--profile',type=pathlib.Path,default=R/'.private/phone.json');a=q.parse_args()
K=a.package.resolve();O=a.output.resolve();assert not O.exists()
B='io.ozio.chatgptx.chat.stockpreparation';M=json.loads((K/'build.json').read_text())
assert M['bundleID']==B and int(M['bundleVersion'])>=4
assert phone.sha(K/'StockPreparation.ipa')==M['ipa']['sha256'] and not M['treeDriftAfterCapture']
changed=[k for k,v in M['sourceInputs'].items()if phone.sha(R/k)!=v]
assert not changed,'Package source is stale; rebuild current inputs: '+', '.join(changed)
pending=R/'.private/stock-compat-device-pending.json';assert not pending.exists(),'Reconcile original checkpoint; do not replay'
p=phone.Phone(argparse.Namespace(profile=a.profile,udid=None),O)
paths=['/Library/MobileSubstrate/DynamicLibraries/WK26.plist','/Library/MobileSubstrate/DynamicLibraries/STBridge.plist',
 '/Library/WK26/Overrides/'+phone.BUNDLE,'/Library/CFBridge/Enabled/'+phone.BUNDLE,
 '/Library/WK26/Overrides/'+B,'/Library/CFBridge/Enabled/'+B]
def exists(path):return p.remote(['/bin/sh','-c','if test -e "$1"; then printf yes; else printf no; fi','stock-compat',path])=='yes'
def config():return {s:p.helper('hash',s)if exists(s)else None for s in paths}
def app():
 x=p.apps().get(B)
 if x:assert re.fullmatch(r'(?:/private)?/var/mobile/Applications/[A-Fa-f0-9-]{36}/StockPreparation.app',x['Path'])
 return x
def mark(stage):
 p.save(stage);phone.private_json(pending,{'stage':stage,'checkpoint':str(O/'deployment.json'),'package':str(K),'probeBundle':B})
def original_hashes(x):return {n:p.helper('hash',x['Path']+'/'+n)['sha256']for n in ['ChatGPTX','Info.plist','contracts.json','priority7-admission.json']}
with p.connection():
 before=p.apps();assert B not in before
 ordinary=p.own();s=p.app_state(ordinary);u=s['ui']['conversation']
 assert p.helper('state')['frontmostBundle']==phone.BUNDLE,'Production app must be foreground before probe'
 assert s['session']['authenticated'] and not s['core']['activeCount'] and not s['web']['active'] and not u['sending'] and not u['uncertain']
 before_cfg=config();before_hash=original_hashes(ordinary)
 p.receipt.update(productionBefore=s,productionHashesBefore=before_hash,productionBuildBefore=ordinary['CFBundleVersion'],configBefore=before_cfg,applicationPathsBefore={k:v['Path']for k,v in before.items()})
 remote=p.stage+'/StockPreparation.ipa';p.copy(K/'StockPreparation.ipa',p.profile['host']+':'+remote)
 assert p.helper('hash',remote)['sha256']==M['ipa']['sha256']
 p.receipt['probeBundle']=B;mark('probe-install-dispatched')
 (O/'install.log').write_text(p.remote(['/usr/bin/appinst',remote],timeout=150))
 installed=app();assert installed and installed['CFBundleVersion']==M['bundleVersion'];p.receipt['probePath']=installed['Path']
 important={'StockPreparation','Info.plist','harness.js','blank.html','MinimalSentinelCore.js','MinimalSentinelCore.es5.js','Manifest.plist'}
 proof={}
 for name,h in M['bundleFiles'].items():
  if name in important or name.startswith('StockCompat/'):
   actual=p.helper('hash',installed['Path']+'/'+name)['sha256'];assert actual==h,name;proof[name]=actual
 p.receipt['probeFileHashes']=proof;mark('probe-installed-verified')
 docs=installed['Path'].removesuffix('/StockPreparation.app')+'/Documents';result=docs+'/StockPreparationResult.json';assert not exists(result)
 mark('probe-launch-dispatched');p.remote(['su','mobile','-c',shlex.join(['/usr/bin/uiopen','chatgptx-stock-preparation://'])])
 deadline=time.monotonic()+95;receipt=None
 while time.monotonic()<deadline:
  if exists(result):
   candidate=json.loads(p.remote(['cat',result]))
   if candidate.get('result',{}).get('verdict') and candidate.get('bundleVersion')==int(M['bundleVersion']):receipt=candidate;break
  time.sleep(.5)
 assert receipt is not None,'Outcome unknown: inspect installed probe, do not launch it again'
 phone.private_json(O/'StockPreparationResult.json',receipt);p.receipt['probeResult']=receipt['result'];p.capture('stock-compat.png');mark('probe-result-observed')
 assert app()['Path']==installed['Path'];mark('probe-uninstall-dispatched')
 with Proxy(p.udid)as proxy:proxy.check(proxy.lib.instproxy_uninstall(proxy.client,B.encode(),None,None,None))
 assert app()is None
 after=p.apps();assert {k:v['Path']for k,v in after.items()}=={k:v['Path']for k,v in before.items()}
 assert config()==before_cfg and original_hashes(p.own())==before_hash
 p.receipt.update(probeRemoved=True,configurationPreserved=True,otherRegistrationsPreserved=True,productionBytesPreserved=True)
 mark('production-resume-dispatched');p.remote(['su','mobile','-c',shlex.join(['/usr/bin/uiopen','chatgptx-auth://open'])])
 deadline=time.monotonic()+40
 while True:
  final=p.app_state(p.own());v=final.get('ui',{}).get('conversation',{})
  stable=all(v.get(k)==u.get(k)for k in ['conversationId','draftLength','draftSHA256','model8','effort8'])
  if p.helper('state')['frontmostBundle']==phone.BUNDLE and final['session']['authenticated'] and stable and not final['core']['activeCount'] and not final['web']['active']:break
  assert time.monotonic()<deadline,'Production state needs inspection; do not reset session/draft'
  time.sleep(.5)
 p.receipt['productionAfter']=final;p.capture('production-restored.png');p.save('stock-probe-cleaned-production-preserved');pending.unlink()
 print(json.dumps({'verdict':receipt['result']['verdict'],'compat':receipt['result'].get('compatVerdict'),'checks':receipt['result'].get('fixtureChecks'),'failures':receipt['result'].get('fixtureFailures'),'modernEngine':receipt['images']['atEnd']['modernEngine'],'probeRemoved':True,'productionBuild':p.own()['CFBundleVersion'],'productionPreserved':True}))
