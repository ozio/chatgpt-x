#!/usr/bin/env python3
"""Theos build → local USB/SSH IPA update → installed bytes and app receipt.
No remote Mac. Private configuration: .private/phone.json.
"""
import argparse,contextlib,fcntl,hashlib,json,os,plistlib,re,shlex,shutil,subprocess,sys,time,uuid
from pathlib import Path
from installation_proxy import Proxy
R=Path(__file__).resolve().parents[1]
BUNDLE='io.ozio.chatgptx'
EXPECTED={'ProductType':'iPhone5,2','ProductVersion':'6.1.4','BuildVersion':'10B350'}
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()

def private_json(path,value):
 path=Path(path);path.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
 tmp=path.with_name('.'+path.name+'.'+uuid.uuid4().hex)
 fd=os.open(tmp,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
 with os.fdopen(fd,'w') as f:json.dump(value,f,ensure_ascii=False,indent=2);f.write('\n');f.flush();os.fsync(f.fileno())
 os.replace(tmp,path)

def require_current(package,fresh=True,allow_acceptance=False):
 package=Path(package).resolve();d=json.loads((package/'build.json').read_text())
 if d['bundleID']!=BUNDLE or (d['acceptance'] and not allow_acceptance) or sha(package/'ChatGPTX.ipa')!=d['ipaSHA256']:raise RuntimeError('Not a verified ordinary ChatGPTX package (acceptance requires an explicit flag)')
 changed=[p for p,h in d['sourceFiles'].items() if not (R/p).is_file() or sha(R/p)!=h]
 if changed and fresh:raise RuntimeError('Package is stale; rebuild current source: '+', '.join(changed))
 return d

def local_profile(profile):
 d=json.loads(Path(profile).read_text())
 if not re.fullmatch(r'[A-Za-z0-9_.-]+',d['host']):raise RuntimeError('Invalid SSH alias')
 p=subprocess.run(['ssh','-G','-F',d['sshConfig'],d['host']],capture_output=True,text=True,check=True)
 settings=dict(line.split(' ',1) for line in p.stdout.splitlines() if ' ' in line)
 if settings.get('hostname') not in ['127.0.0.1','localhost','::1']:raise RuntimeError('Only local USB loopback SSH is allowed')
 if settings.get('proxyjump','none')!='none' or settings.get('proxycommand','none')!='none':raise RuntimeError('SSH must not proxy through another host')
 if settings.get('stricthostkeychecking') not in ['true','yes']:raise RuntimeError('SSH host verification must be strict')
 return d

def device_identity(requested=None):
 devices=subprocess.check_output(['idevice_id','-l'],text=True).splitlines();found=[]
 for u in devices:
  if requested and u!=requested:continue
  d={k:subprocess.check_output(['ideviceinfo','-u',u,'-k',k],text=True).strip() for k in EXPECTED}
  if d==EXPECTED:found.append((u,d))
 if len(found)!=1:raise RuntimeError('Connect exactly one selected iPhone5,2 / iOS6.1.4 over USB')
 return found[0]

def build_helper(output):
 o=Path(output);o.mkdir(parents=True,exist_ok=False)
 for p in (R/'ios/phone-tools').iterdir():
  if p.is_file():shutil.copyfile(p,o/p.name)
 with (o/'build.log').open('w') as f:p=subprocess.run(['gmake','clean','all','messages=yes'],cwd=o,env=dict(os.environ,THEOS=os.environ.get('THEOS',str(Path.home()/'theos'))),stdout=f,stderr=subprocess.STDOUT)
 (o/'build.exit').write_text(str(p.returncode)+'\n')
 if p.returncode:raise RuntimeError('Theos phone helper build failed: '+str(o/'build.log'))
 binary=o/'.theos/obj/RCPhoneCheck'
 if not binary.is_file():raise RuntimeError('Theos helper missing')
 return binary

def next_build():
 numbers=[]
 for p in (R/'.artifacts').glob('*/**/ChatGPTX.app/Info.plist'):
  try:numbers.append(int(plistlib.loads(p.read_bytes())['CFBundleVersion']))
  except (ValueError,KeyError,plistlib.InvalidFileException):pass
 return max(numbers,default=0)+1

def build(output=None):
 n=next_build();o=Path(output).resolve() if output else R/'.artifacts/phone-theos-20261110'/('ordinary'+str(n))
 subprocess.run([sys.executable,str(R/'scripts/build-chat.py'),'--output',str(o),'--build-number',str(n)],cwd=R,check=True)
 require_current(o);private_json(R/'.private/phone-latest-build.json',{'package':str(o)})
 return o

class Phone:
 def __init__(self,args,output):
  self.args=args;self.profile=local_profile(args.profile);self.udid,self.identity=device_identity(args.udid)
  self.output=Path(output).resolve();self.output.mkdir(parents=True,exist_ok=True,mode=0o700)
  self.env=dict(os.environ)
  if self.profile.get('askpass'):self.env.update(SSH_ASKPASS=self.profile['askpass'],SSH_ASKPASS_REQUIRE='force',DISPLAY='chatgptx-theos')
  self.ssh=['ssh','-F',self.profile['sshConfig'],'-o','StrictHostKeyChecking=yes',self.profile['host']]
  self.scp=['scp','-O','-F',self.profile['sshConfig'],'-o','StrictHostKeyChecking=yes']
  self.stage='/var/tmp/chatgptx-theos-'+uuid.uuid4().hex
  self.receipt={'schema':1,'bundleID':BUNDLE,'udid':self.udid,'identity':self.identity,'stage':self.stage,'state':'prepared','deviceRoute':'local-usb-ssh','accountGenerations':0}
 def save(self,state):self.receipt['state']=state;private_json(self.output/'deployment.json',self.receipt)
 def remote(self,argv,timeout=30):
  p=subprocess.run([*self.ssh,shlex.join(argv)],env=self.env,stdin=subprocess.DEVNULL,capture_output=True,text=True,timeout=timeout)
  if p.returncode:raise RuntimeError('Direct USB SSH failed (exit '+str(p.returncode)+')')
  return p.stdout
 def copy(self,source,target,recursive=False):
  subprocess.run([*self.scp,*(['-r']if recursive else[]),str(source),str(target)],env=self.env,stdin=subprocess.DEVNULL,capture_output=True,check=True,timeout=90)
 def helper(self,*argv):return json.loads(self.remote([self.stage+'/check',*argv]))
 def apps(self):
  with Proxy(self.udid) as p:return p.apps()
 def own(self):
  a=self.apps().get(BUNDLE)
  if not a or not re.fullmatch(r'(?:/private)?/var/mobile/Applications/[A-Fa-f0-9-]{36}/ChatGPTX.app',a['Path']):raise RuntimeError('Own app registration not unique/valid')
  return a
 @contextlib.contextmanager
 def connection(self):
  # Honor the per-device writer lock used by existing direct tooling; no daemon.
  lockdir=Path.home()/'.config/chatgpt-x/locks';lockdir.mkdir(parents=True,exist_ok=True,mode=0o700)
  fence=Path.home()/'.config/chatgpt-x/supervisor/fences'/(hashlib.sha256(self.udid.encode()).hexdigest()+'.json')
  if fence.exists():raise RuntimeError('An existing device operation is unresolved; inspect its checkpoint')
  with (lockdir/(hashlib.sha256(self.udid.encode()).hexdigest()+'.lock')).open('a') as lock:
   fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
   if self.remote(['uname','-m']).strip()!=EXPECTED['ProductType']:raise RuntimeError('SSH device differs from selected USB hardware')
   self.remote(['mkdir','-m','700',self.stage]);self.save('connected')
   try:
    h=build_helper(self.output/'helper-build');self.copy(h,self.profile['host']+':'+self.stage+'/check');self.remote(['chmod','700',self.stage+'/check'])
    actual=self.helper('identity')
    if actual.get('udid')!=self.udid.lower() or any(actual.get(k)!=v for k,v in EXPECTED.items()):raise RuntimeError('USB and SSH device identities differ')
    yield self
   finally:
    self.remote(['rm','-rf','--',self.stage]);self.receipt['stageRemoved']=True
    private_json(self.output/'deployment.json',self.receipt)
 def app_state(self,app):
  p=app['Path'].removesuffix('/ChatGPTX.app')+'/Documents/ChatUIState.json'
  return json.loads(self.remote(['cat',p]))
 def capture(self,name='screen.png'):
  target=self.stage+'/screen.png';v=self.helper('screenshot',target)
  if not v.get('saved'):raise RuntimeError('Native screenshot failed')
  self.copy(self.profile['host']+':'+target,self.output/name);self.receipt['lastScreenshot']={'at':time.time(),'file':str(self.output/name),'sha256':sha(self.output/name),'used':False,'frontmostBundle':self.helper('state')['frontmostBundle']};return self.output/name
 def tap(self,observation,x,y):
  if x is None or y is None:raise RuntimeError('Tap coordinates are required')
  frames=[{'t':round(i*.08/3,4),'contacts':[{'id':1,'phase':'down'if i==0 else'up'if i==3 else'move','x':x,'y':y}]}for i in range(4)]
  return self.touch(observation,frames,[x,y])
 def swipe(self,observation,x,y,to_x,to_y):
  if any(v is None for v in [x,y,to_x,to_y]) or not 80<=((to_x-x)**2+(to_y-y)**2)**.5<=850:raise RuntimeError('Swipe requires observed endpoints 80–850 pixels apart')
  frames=[{'t':round(i*.5/8,4),'contacts':[{'id':1,'phase':'down'if i==0 else'up'if i==8 else'move','x':round(x+(to_x-x)*i/8),'y':round(y+(to_y-y)*i/8)}]}for i in range(9)]
  return self.touch(observation,frames,[[x,y],[to_x,to_y]])
 def longpress(self,observation,x,y):
  if x is None or y is None:raise RuntimeError('Long-press coordinates are required')
  frames=[{'t':t,'contacts':[{'id':1,'phase':'down' if i==0 else 'up' if i==4 else 'move','x':x,'y':y}]}for i,t in enumerate([0,.1,.4,.7,.85])]
  return self.touch(observation,frames,[x,y])
 def touch(self,observation,frames,coordinates):
  oldpath=Path(observation);old=json.loads(oldpath.read_text());shot=old.get('lastScreenshot',{})
  if old.get('udid')!=self.udid or shot.get('used') or not 0<=time.time()-shot.get('at',0)<=30:raise RuntimeError('A fresh unused screenshot observation is required')
  if sha(shot['file'])!=shot['sha256'] or any(not(0<=c['x']<640 and 0<=c['y']<1136) for f in frames for c in f['contacts']):raise RuntimeError('Screenshot/coordinates invalid')
  target=getattr(getattr(self,'args',None),'foreground_bundle',None)or BUNDLE
  if target not in [BUNDLE,'com.apple.mobilesafari','com.apple.mobilemail','com.apple.mobileslideshow']:raise RuntimeError('Unsupported foreground bundle')
  if self.helper('state')['frontmostBundle']!=target or (target!=BUNDLE and shot.get('frontmostBundle')!=target):raise RuntimeError('Observed app must still be foreground')
  pending=R/'.private/phone-active-input.json'
  if pending.exists():raise RuntimeError('Prior input outcome is unresolved; inspect its original checkpoint')
  shot['used']=True;private_json(oldpath,old)
  self.receipt['inputDispatched']=True;self.receipt['inputCoordinates']=coordinates;self.receipt['inputBundle']=target;self.save('input-dispatched');private_json(pending,{'checkpoint':str(self.output/'deployment.json')})
  result=json.loads(self.remote([self.profile.get('touchHelper','/var/root/ChatGPTXTouch/rctouch'),json.dumps({'op':'play','bundleId':target,'frames':frames})]))
  if not result.get('ok'):raise RuntimeError('HID input refused; inspect original checkpoint')
  self.receipt['inputResult']=result;pending.unlink();time.sleep(.4);self.capture();self.save('input-returned')
  return {'inputResult':result,'screenshot':str(self.output/'screen.png')}
 def verify_files(self,app,package,meta):
  import zipfile
  with zipfile.ZipFile(Path(package)/'ChatGPTX.ipa') as z:
   names=['ChatGPTX','Info.plist','contracts.json','Default.png','Default@2x.png','Default-568h@2x.png','Icon.png','Icon@2x.png']
   # API7's executable and its exact extension/admission resources are one
   # composition. Keep older ordinary packages checkable, but refuse a partial
   # new composition and verify every installed registry against this IPA.
   extensions=['contracts-'+key+'.json' for key in ['7','7b','7c','7d','7e','7f','7g','6a','6b','6c','6d','6e','6f']]+['priority7-admission.json','priority6-admission.json']
   present={name for name in extensions if 'Payload/ChatGPTX.app/'+name in z.namelist()}
   if present and present!=set(extensions):raise RuntimeError('Incomplete API7 composition resources in package')
   names+=sorted(present)
   five=['contracts-'+key+'.json'for key in ['5a','5b','5c','5d','5e']]
   if meta.get('offlineASR'):
    for name in five:
     if 'Payload/ChatGPTX.app/'+name not in z.namelist():raise RuntimeError('Incomplete API5 composition resources')
    names+=five
    for name,h in meta['offlineASR']['resourceSHA256'].items():
     path='Rev5ASRModel/'+name
     if hashlib.sha256(z.read('Payload/ChatGPTX.app/'+path)).hexdigest()!=h:raise RuntimeError('Offline ASR package resource differs: '+name)
     names.append(path)
   if 'Payload/ChatGPTX.app/codex-contracts.json' in z.namelist():names.append('codex-contracts.json')
   stock=[n.removeprefix('Payload/ChatGPTX.app/') for n in z.namelist() if n.startswith('Payload/ChatGPTX.app/StockPreparation/') and not n.endswith('/')]
   if stock:
    manifest=json.loads(z.read('Payload/ChatGPTX.app/StockPreparation/Manifest.json'))
    required={'StockCompatibility.js','SentinelCore.js','SentinelBridge.js','DocumentCheck.js','DocumentMIME.js','LegacyCrypto.js','compat-fixtures.js'}
    if set(manifest['files'])!=required or manifest['rootsSHA256']!=hashlib.sha256(z.read('Payload/ChatGPTX.app/roots.pem')).hexdigest():raise RuntimeError('Incomplete stock preparation provenance')
    for name,h in manifest['files'].items():
     if hashlib.sha256(z.read('Payload/ChatGPTX.app/StockPreparation/'+name)).hexdigest()!=h:raise RuntimeError('Stock resource provenance differs')
    names+=sorted(stock)
   if meta.get('bundledThirdPartyEngine')=='WebPort':
    manifest_data=z.read('Payload/ChatGPTX.app/WebPort/Manifest.json')
    if hashlib.sha256(manifest_data).hexdigest()!=meta['webportRuntimeManifestSHA256']:raise RuntimeError('WebPort manifest differs')
    manifest=json.loads(manifest_data)
    for name,record in manifest['files'].items():
     if hashlib.sha256(z.read('Payload/ChatGPTX.app/WebPort/'+name)).hexdigest()!=record['sha256']:raise RuntimeError('WebPort package bytes differ: '+name)
    names+=['WebPort/Manifest.json']+['WebPort/'+n for n,r in manifest['files'].items() if r.get('macho')]
   proofs={}
   for name in names:
    expected=hashlib.sha256(z.read('Payload/ChatGPTX.app/'+name)).hexdigest();actual=self.helper('hash',app['Path']+'/'+name)['sha256']
    if actual!=expected:raise RuntimeError('Installed bytes differ: '+name)
    proofs[name]=actual
  if app['CFBundleVersion']!=meta['bundleVersion']:raise RuntimeError('Installed build number differs')
  return proofs
 def check(self,package,meta,launch=False,conversation=None,draft_hash=None):
  app=self.own();proof=self.verify_files(app,package,meta)
  if launch:
   url='chatgptx-auth://conversation/'+conversation if conversation else 'chatgptx-auth://open'
   self.receipt['launchDispatched']=True;self.save('launch-dispatched');self.remote(['su','mobile','-c',shlex.join(['/usr/bin/uiopen',url])])
  deadline=time.monotonic()+45
  while True:
   procs=self.helper('process',app['Path']+'/ChatGPTX')['matches'];front=self.helper('state')['frontmostBundle'];s=self.app_state(app)
   current=len(procs)==1 and s.get('pid')==procs[0]['pid'] and front==BUNDLE
   u=s.get('ui',{}).get('conversation',{})
   target_ready=not conversation or (u.get('conversationId')==conversation and u.get('loaded'))
   # A ready foreground must not conceal a stop from an automatic UI read.
   issues=[s.get('web',{}).get('issue'),s.get('sessionDiagnostics',{}).get('issue'),u.get('api6',{}).get('lastIssue')]
   issue=next((v for v in issues if v in ['rate_limited','service_challenge','access_denied','auth_failed','not_authenticated','login_required']),None)
   if issue:
    self.receipt['observedState']=s;self.save('service-stop')
    raise RuntimeError('App reported service stop: '+issue)
   if current and target_ready and s.get('session',{}).get('authenticated') and not s.get('web',{}).get('active') and not s.get('core',{}).get('activeCount') and (not draft_hash or u.get('draftSHA256')==draft_hash):break
   if time.monotonic()>deadline:
    self.receipt['observedState']=s;self.save('installed-app-check-incomplete')
    raise RuntimeError('Installed app check incomplete: '+str(s.get('sessionDiagnostics',{}).get('issue') or 'foreground/session not ready')+'; inspect original checkpoint, do not reinstall')
   time.sleep(.5)
  if draft_hash and s['ui']['conversation'].get('draftSHA256')!=draft_hash:raise RuntimeError('Draft restoration not confirmed')
  if draft_hash:self.remote(['test','!','-e',app['Path'].removesuffix('/ChatGPTX.app')+'/Documents/ChatGPTXDeploymentDraft.json'])
  pending=R/'.private/phone-active-install.json'
  if pending.exists():
   old=json.loads(pending.read_text())
   if old['udid']!=self.udid or Path(old['package']).resolve()!=Path(package).resolve():raise RuntimeError('Different pending installation must be inspected')
   oldpath=Path(old['checkpoint']);previous=json.loads(oldpath.read_text());previous.update(state='verified-after-uncertain-install',reconciledBy=str(self.output/'deployment.json'));private_json(oldpath,previous);pending.unlink()
  self.receipt.update(installed=app,fileHashes=proof,finalState=s,draftVerified=bool(draft_hash));self.capture();self.save('verified')
  return {'build':app['CFBundleVersion'],'authenticated':True,'foreground':True,'draftLength':s['ui']['conversation']['draftLength'],'screenshot':str(self.output/'screen.png')}
 def restart(self,package,meta,draft_file=None):
  app=self.own();self.verify_files(app,package,meta);s=self.app_state(app);u=s['ui']['conversation']
  if s['core']['activeCount'] or s['web']['active'] or u['sending'] or u['uncertain']:raise RuntimeError('Cannot restart an active app operation')
  conversation=(u.get('conversationId') or getattr(self.args,'conversation_id',None))if u.get('hasConversation')else None
  if u.get('hasConversation') and not conversation:raise RuntimeError('Original conversation UUID is required')
  h=None
  if u['draftLength']:
   if not draft_file:raise RuntimeError('Preserve the current unsent draft with --draft-file before restart')
   text=Path(draft_file).read_text();h=hashlib.sha256(text.encode()).hexdigest()
   if len(text.encode('utf-16-le'))//2!=u['draftLength'] or (u.get('draftSHA256') and u['draftSHA256']!=h):raise RuntimeError('Restart draft backup differs')
   d={'schema':1,'conversationId':conversation,'text':text,'textSHA256':h};local=self.output/'private-draft.json';private_json(local,d)
   target=app['Path'].removesuffix('/ChatGPTX.app')+'/Documents/ChatGPTXDeploymentDraft.json';self.remote(['test','!','-e',target]);self.copy(local,self.profile['host']+':'+target);self.remote(['chown','mobile:mobile',target]);self.remote(['chmod','600',target])
  self.receipt['restartDispatched']=True;self.save('restart-dispatched');self.helper('stop',app['Path']+'/ChatGPTX')
  deadline=time.monotonic()+10
  while self.helper('process',app['Path']+'/ChatGPTX')['matches']:
   if time.monotonic()>deadline:raise RuntimeError('Own process has not quiesced')
   time.sleep(.2)
  return self.check(package,meta,True,conversation,h)
 def rejected_draft(self,app,operation):
  if not re.fullmatch(r'[A-Fa-f0-9]{8}(?:-[A-Fa-f0-9]{4}){3}-[A-Fa-f0-9]{12}',operation):raise RuntimeError('Invalid rejected operation ID')
  library=app['Path'].removesuffix('/ChatGPTX.app')+'/Library';records=[]
  for directory in ['ChatGPTXOperations-v1','ChatGPTXWebOps-v1']:
   paths=self.remote(['find',library+'/'+directory,'-maxdepth','1','-type','f','-name','*.json']).splitlines()
   if len(paths)>256:raise RuntimeError('Journal inspection limit')
   found=[]
   for path in paths:
    if not path.startswith(library+'/'+directory+'/') or not re.fullmatch(r'[a-f0-9]{64}\.json',Path(path).name):raise RuntimeError('Invalid journal path')
    r=json.loads(self.remote(['cat',path]))
    if r.get('operationId')==operation:found.append(r)
   if len(found)!=1:raise RuntimeError('Rejected operation not uniquely recorded')
   records.append(found[0])
  core,native=records;q=core.get('request',{});text=q.get('text')
  if core.get('command')!='messages.send' or native.get('command')!='native.send.v1' or core.get('state')!='rejected' or native.get('state')!='rejected':raise RuntimeError('Outcome is not proven rejected; never resend it')
  if not isinstance(text,str) or not text or len(text.encode('utf-16-le'))//2>16000 or q.get('attachments') or q.get('temporary') or q.get('conversationId'):raise RuntimeError('Only a plain rejected new-chat text can be restored by this handoff')
  digest=hashlib.sha256(text.encode()).hexdigest()
  if native.get('request',{}).get('textSHA256')!=digest:raise RuntimeError('Rejected request fingerprints differ')
  return {'schema':1,'conversationId':None,'text':text,'textSHA256':digest}
 def first_install(self,package,meta):
  # First install of this bundle ID: there is no session, draft or private data to preserve.
  pending=R/'.private/phone-active-install.json'
  remote=self.stage+'/app.ipa';self.copy(Path(package)/'ChatGPTX.ipa',self.profile['host']+':'+remote)
  require_current(package,allow_acceptance=bool(getattr(getattr(self,'args',None),'acceptance',False)))
  self.receipt.update(firstInstall=True,package=str(package),packageSHA256=meta['ipaSHA256'],installDispatched=True);self.save('install-dispatched')
  private_json(pending,{'checkpoint':str(self.output/'deployment.json'),'package':str(package),'udid':self.udid})
  log=self.remote(['/usr/bin/appinst',remote],timeout=150);(self.output/'install.log').write_text(log)
  current=self.own();self.verify_files(current,package,meta);pending.unlink();self.save('first-install-verified')
  self.remote(['su','mobile','-c',shlex.join(['/usr/bin/uiopen','chatgptx-auth://open'])]);time.sleep(4);self.capture('screen.png')
  return {'build':current['CFBundleVersion'],'firstInstall':True,'signInRequired':True,'screenshot':str(self.output/'screen.png')}
 def deploy(self,package,meta,draft_file=None):
  pending=R/'.private/phone-active-install.json'
  if pending.exists():raise RuntimeError('Prior install has an unresolved outcome: '+str(pending))
  before=self.apps()
  if BUNDLE not in before:return self.first_install(package,meta)
  app=before[BUNDLE];s=self.app_state(app);u=s['ui']['conversation']
  if not s.get('session',{}).get('authenticated') and not u.get('draftLength') and not s['core']['activeCount']:return self.first_install(package,meta) # signed out: nothing to preserve
  docs=app['Path'].removesuffix('/ChatGPTX.app')+'/Documents'
  if s['core']['activeCount'] or s['web']['active'] or u['sending'] or u['uncertain']:raise RuntimeError('App operation active; preserve it before updating')
  if int(meta['bundleVersion'])<int(app['CFBundleVersion']):raise RuntimeError('Refusing to downgrade a newer installed build')
  self.receipt.update(before=app,package=str(package),packageSHA256=meta['ipaSHA256']);self.capture('before.png')
  conversation=(u.get('conversationId') or getattr(getattr(self,'args',None),'conversation_id',None))if u.get('hasConversation') else None;draft=None
  recover=getattr(getattr(self,'args',None),'recover_rejected',None)
  if recover:
   if u.get('draftLength') or u.get('hasConversation') or u.get('phase')!='rejected':raise RuntimeError('Rejected recovery must not replace another current draft/chat')
   draft=self.rejected_draft(app,recover);private_json(self.output/'private-draft.json',draft)
   self.receipt['rejectedTextRestoredFromOperation']=recover
   self.receipt['draftBackup']={'characters':len(draft['text'].encode('utf-16-le'))//2,'sha256':draft['textSHA256']}
  if conversation and not re.fullmatch(r'[A-Fa-f0-9]{8}(?:-[A-Fa-f0-9]{4}){3}-[A-Fa-f0-9]{12}',conversation):raise RuntimeError('Invalid conversation identifier')
  if u.get('hasConversation') and not conversation:raise RuntimeError('Existing conversation identifier is unavailable; do not move its draft')
  if u['draftLength']:
   self.remote(['test','!','-e',docs+'/ChatGPTXDeploymentDraft.json'])
   if not draft_file:raise RuntimeError('Unsent draft present; supply its private --draft-file before updating')
   text=Path(draft_file).read_text();n=len(text.encode('utf-16-le'))//2
   if n!=u['draftLength'] or n>16000:raise RuntimeError('Saved draft does not match current draft length')
   h=hashlib.sha256(text.encode()).hexdigest()
   if u.get('draftSHA256') and u['draftSHA256']!=h:raise RuntimeError('Saved draft hash differs')
   draft={'schema':1,'conversationId':conversation,'text':text,'textSHA256':h};private_json(self.output/'private-draft.json',draft)
   self.receipt['draftBackup']={'characters':n,'sha256':h}
  # Stop only this exact executable, then archive without dereferencing normal
  # iOS Library symlinks. Keep the archive opaque; never extract private links.
  self.helper('stop',app['Path']+'/ChatGPTX')
  deadline=time.monotonic()+10
  while self.helper('process',app['Path']+'/ChatGPTX')['matches']:
   if time.monotonic()>deadline:raise RuntimeError('Own app has not stopped')
   time.sleep(.2)
  container=app['Path'].removesuffix('/ChatGPTX.app');archive=self.stage+'/private-data.tar'
  self.remote(['tar','-cf',archive,'-C',container,'Documents','Library'],timeout=90)
  backup=self.output/'private-data.tar';self.copy(self.profile['host']+':'+archive,backup);backup.chmod(0o600)
  self.receipt['privateDataBackup']={'archive':str(backup),'sha256':sha(backup),'bytes':backup.stat().st_size}
  self.save('private-data-backed-up')
  remote=self.stage+'/app.ipa';self.copy(Path(package)/'ChatGPTX.ipa',self.profile['host']+':'+remote)
  require_current(package,allow_acceptance=bool(getattr(getattr(self,'args',None),'acceptance',False))) # Last check immediately before device mutation.
  self.receipt['installDispatched']=True;self.save('install-dispatched');private_json(pending,{'checkpoint':str(self.output/'deployment.json'),'package':str(package),'udid':self.udid})
  log=self.remote(['/usr/bin/appinst',remote],timeout=150);(self.output/'install.log').write_text(log)
  current=self.own();self.verify_files(current,package,meta);self.receipt['installerReturned']=True;self.save('installed-bytes-verified');pending.unlink()
  docs=current['Path'].removesuffix('/ChatGPTX.app')+'/Documents'
  if draft:
   local=self.output/'private-draft.json';target=docs+'/ChatGPTXDeploymentDraft.json';self.copy(local,self.profile['host']+':'+target);self.remote(['chown','mobile:mobile',target]);self.remote(['chmod','600',target])
  for name in ['ChatUIAcceptanceKey','ChatUIAcceptanceCommand.json','ChatUIAcceptanceResult.json','UI7ReadShapeCapture','UI7ReadShapes.json']:self.remote(['rm','-f','--',docs+'/'+name])
  if meta['acceptance']:
   if not getattr(self.args,'acceptance',False):raise RuntimeError('Acceptance package was not explicitly selected')
   keyfile=self.output/'private-acceptance-key';keyfile.write_text(os.urandom(32).hex());keyfile.chmod(0o600)
   self.copy(keyfile,self.profile['host']+':'+docs+'/ChatUIAcceptanceKey');self.remote(['chown','mobile:mobile',docs+'/ChatUIAcceptanceKey']);self.remote(['chmod','600',docs+'/ChatUIAcceptanceKey'])
   self.receipt['temporaryAcceptanceEnabled']=True
  result=self.check(package,meta,True,conversation,draft['textSHA256']if draft else None)
  after=self.apps();changes={k for k in set(before)|set(after) if k!=BUNDLE and before.get(k)!=after.get(k)}
  if changes:raise RuntimeError('Unrelated application registrations changed')
  self.receipt['unrelatedAppsUnchanged']=True;self.save('verified');return result

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('command',choices=['doctor','build','deploy','install','check','screen','tap','swipe','longpress','restart']);p.add_argument('--profile',type=Path,default=R/'.private/phone.json');p.add_argument('--udid');p.add_argument('--package',type=Path);p.add_argument('--output',type=Path);p.add_argument('--draft-file',type=Path);p.add_argument('--recover-rejected',help='restore a proven rejected plain new-chat send into the draft, never send it');p.add_argument('--conversation-id',help='original UUID when preserving a draft in an existing conversation');p.add_argument('--observation',type=Path);p.add_argument('--x',type=int);p.add_argument('--y',type=int);p.add_argument('--to-x',type=int);p.add_argument('--to-y',type=int);p.add_argument('--launch',action='store_true',help='check: launch once after verifying installed bytes');p.add_argument('--foreground-bundle',choices=[BUNDLE,'com.apple.mobilesafari','com.apple.mobilemail','com.apple.mobileslideshow'],help='observed system handoff app for bounded touch only');p.add_argument('--acceptance',action='store_true',help='explicit temporary development package, final ordinary install required');args=p.parse_args()
 if args.command=='build':print(build(args.output));return
 output=args.output or R/'.artifacts/phone-theos-20261110'/('device-'+uuid.uuid4().hex[:12])
 if (Path(output)/'deployment.json').exists():raise RuntimeError('Output already has an operation checkpoint; inspect it, do not replay')
 package=args.package
 if args.command=='deploy' and not package:package=build()
 if args.command in ['install','check','restart'] and not package:package=Path(json.loads((R/'.private/phone-latest-build.json').read_text())['package'])
 if args.acceptance and args.command not in ['install','check','restart']:raise RuntimeError('Acceptance flag requires an explicit install/check/restart package')
 if args.acceptance and not args.package:raise RuntimeError('Acceptance package must be explicit')
 meta=require_current(package,fresh=args.command in ['install','deploy'],allow_acceptance=args.acceptance)if package else None
 phone=Phone(args,output)
 with phone.connection():
  if args.command=='doctor':result={'identity':phone.identity,'udid':phone.udid,'ownApp':phone.own(),'route':'local-usb-ssh'};phone.save('doctor-verified')
  elif args.command=='screen':result={'screenshot':str(phone.capture())};phone.save('screen-verified')
  elif args.command=='tap':result=phone.tap(args.observation,args.x,args.y)
  elif args.command=='swipe':result=phone.swipe(args.observation,args.x,args.y,args.to_x,args.to_y)
  elif args.command=='longpress':result=phone.longpress(args.observation,args.x,args.y)
  elif args.command=='restart':result=phone.restart(package,meta,args.draft_file)
  elif args.command=='check':result=phone.check(package,meta,args.launch)
  else:result=phone.deploy(package,meta,args.draft_file)
 print(json.dumps(result,ensure_ascii=False))
if __name__=='__main__':
 try:main()
 except Exception as e:print('phone: '+str(e),file=sys.stderr);sys.exit(1)
