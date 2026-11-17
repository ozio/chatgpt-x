"""Typed remote helper. Invoked by argv through command/exec, never via a shell.
Python 3 + Git are host prerequisites. No credentials, account or phone state.
"""
import base64,fcntl,hashlib,json,os,pathlib,re,selectors,signal,stat,subprocess,sys,tempfile,time
CAP=262144
class Refused(Exception):pass
def need(ok,code='invalid_request'):
 if not ok:raise Refused(code)
def digest(v):return hashlib.sha256(v if isinstance(v,bytes)else json.dumps(v,sort_keys=True,separators=(',',':')).encode()).hexdigest()
def git(root,*args,allowed=(0,)):
 env=dict(os.environ,GIT_OPTIONAL_LOCKS='0',GIT_EXTERNAL_DIFF='',GIT_DIFF_OPTS='',GIT_TERMINAL_PROMPT='0',GIT_CONFIG_NOSYSTEM='1');env.pop('GIT_DIR',None);env.pop('GIT_WORK_TREE',None)
 # Explicit git -c controls override configured hooks/diff drivers for these actions.
 p=subprocess.Popen(['git','-c','core.hooksPath=/dev/null','-c','core.fsmonitor=false','-c','diff.external=', '-C',str(root),*args],stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=env,start_new_session=True)
 output={p.stdout:bytearray(),p.stderr:bytearray()};selector=selectors.DefaultSelector();start=time.monotonic()
 for stream in output:selector.register(stream,selectors.EVENT_READ)
 try:
  while selector.get_map():
   need(time.monotonic()-start<12,'host_timeout')
   for key,_ in selector.select(.2):
    chunk=os.read(key.fileobj.fileno(),32768)
    if not chunk:selector.unregister(key.fileobj);continue
    output[key.fileobj].extend(chunk);need(len(output[key.fileobj])<=CAP,'size_limit')
  need(p.wait(timeout=1)in allowed,'git_conflict');return bytes(output[p.stdout])
 finally:
  if p.poll()is None:os.killpg(p.pid,signal.SIGKILL);p.wait()
  selector.close();p.stdout.close();p.stderr.close()

def absolute(s):
 need(isinstance(s,str)and s.startswith('/')and len(s)<=4096 and not any(ord(c)<32 for c in s)and not {'.','..'}.intersection(pathlib.PurePosixPath(s).parts));return pathlib.Path(s)
def inside(root,value):
 p=absolute(value);resolved=p.resolve();need(resolved==root or root in resolved.parents,'path_outside_root');return resolved
def files(q):
 root=absolute(q['root']).resolve(strict=True);need(root.is_dir());action=q['action'];p=inside(root,q.get('path',str(root)))
 if action=='preview':
  # Open the checked canonical path, then verify the descriptor still names that file.
  fd=os.open(p,os.O_RDONLY|os.O_NOFOLLOW)
  try:
   st=os.fstat(fd);need(stat.S_ISREG(st.st_mode),'not_a_file');need(st.st_size<=65536,'size_limit');need(os.stat(p).st_ino==st.st_ino and os.stat(p).st_dev==st.st_dev,'stale_context');data=os.read(fd,65537);need(len(data)<=65536,'size_limit')
  finally:os.close(fd)
  try:text=data.decode('utf-8');binary='\0'in text
  except UnicodeDecodeError:text=None;binary=True
  return {'path':str(p),'bytes':len(data),'sha256':digest(data),'text':None if binary else text,'dataBase64':base64.b64encode(data).decode() if binary else None,'binary':binary}
 if action=='tree':
  need(p.is_dir());rows=[]
  with os.scandir(p)as it:
   for entry in it:
    need(len(rows)<2048,'directory_too_large');rows.append({'name':entry.name,'path':str(p/entry.name),'isDirectory':entry.is_dir(follow_symlinks=False),'isSymlink':entry.is_symlink()})
  rows.sort(key=lambda x:x['name']);revision=digest(rows);cursor=q.get('cursor');offset=0
  if cursor:
   need(isinstance(cursor,dict)and cursor.get('revision')==revision,'stale_context');offset=cursor['offset'];need(type(offset)is int and 0<=offset<=len(rows))
  limit=q.get('limit',50);need(type(limit)is int and 1<=limit<=100);end=offset+limit
  return {'data':rows[offset:end],'nextCursor':{'revision':revision,'offset':end}if end<len(rows)else None,'revision':revision}
 if action=='search':
  query=q['query'];need(isinstance(query,str)and 0<len(query)<=256);rows=[];visited=0;start=time.monotonic();truncated=False
  pending=[root]
  while pending and not truncated:
   parent=pending.pop();entries=[]
   with os.scandir(parent)as it:
    for entry in it:
     visited+=1
     if visited>10000 or len(entries)>=2048 or time.monotonic()-start>2:truncated=True;break
     entries.append(entry)
   for entry in sorted(entries,key=lambda e:e.name):
    if entry.name=='.git'or entry.is_symlink():continue
    path=pathlib.Path(entry.path)
    if entry.is_dir(follow_symlinks=False):pending.append(path);continue
    relative=str(path.relative_to(root))
    if query.casefold()in relative.casefold():rows.append({'path':str(path),'relativePath':relative,'root':str(root)})
    if len(rows)>=100:truncated=True;break
  return {'data':rows,'truncated':truncated,'visited':visited}
 raise Refused('invalid_request')
def atomic(path,value):
 fd,name=tempfile.mkstemp(dir=path.parent,prefix='.rc-')
 try:
  with os.fdopen(fd,'w')as f:json.dump(value,f,sort_keys=True);f.flush();os.fsync(f.fileno())
  os.replace(name,path)
 finally:
  if os.path.exists(name):os.unlink(name)
def status(path):
 head=git(path,'rev-parse','HEAD').decode().strip();branch=git(path,'symbolic-ref','--quiet','--short','HEAD',allowed=(0,1)).decode().strip();dirty=git(path,'status','--porcelain=v1','-z','--untracked-files=all');conflicts=git(path,'diff','--name-only','--diff-filter=U','-z').decode().split('\0')[:-1]
 return {'path':str(path),'head':head,'branch':branch,'dirty':bool(dirty),'conflicts':conflicts,'revision':digest(head.encode()+b'\0'+dirty+git(path,'diff','--binary','--no-ext-diff','--no-textconv','HEAD'))}
def worktree(q):
 root=absolute(q['root']).resolve(strict=True);need(git(root,'rev-parse','--show-toplevel').decode().strip()==str(root),'not_repository_root');common=pathlib.Path(git(root,'rev-parse','--path-format=absolute','--git-common-dir').decode().strip()).resolve();state=common/'chatgptx-worktrees-v1';managed=state/'trees';action=q['action']
 if action in ['list','status','select']:
  ledger=state/'ledger.json';data=json.loads(ledger.read_text())if ledger.exists()else{};trees=git(root,'worktree','list','--porcelain','-z').decode().split('\0');paths=[x[9:]for x in trees if x.startswith('worktree ')]
  chosen=absolute(q.get('path',str(root))).resolve();need(str(chosen)in paths,'unknown_worktree');info=status(chosen);info['commonDir']=str(common);info['managedRoot']=str(managed);info['data']=[{'path':p,'owned':any(r.get('path')==p for r in data.values())}for p in paths];info['journal']=[{'id':k,'path':r['path'],'state':r['state']}for k,r in data.items()];return info
 state.mkdir(mode=0o700,exist_ok=True);need(not state.is_symlink(),'invalid_state')
 with (state/'lock').open('a')as lock:
  fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB);ledger=state/'ledger.json';data=json.loads(ledger.read_text())if ledger.exists()else{};action=q['action'];trees=git(root,'worktree','list','--porcelain','-z').decode().split('\0');paths=[x[9:]for x in trees if x.startswith('worktree ')]
  identifier=q.get('id');need(isinstance(identifier,str)and re.fullmatch('[a-zA-Z0-9_-]{1,64}',identifier));record=data.get(identifier);path=managed/identifier
  if action=='create':
   need(not record,'duplicate_operation');base=status(root);need(base['revision']==q.get('expectedRevision'),'stale_context');managed.mkdir(mode=0o700,exist_ok=True);need(not managed.is_symlink(),'invalid_state');need(not path.exists(),'path_exists')
   record={'path':str(path),'base':base['head'],'state':'creating','branch':'chatgptx/'+identifier};data[identifier]=record;atomic(ledger,data)
   try:git(root,'worktree','add','-b',record['branch'],str(path),base['head'])
   except Exception:record['state']='needs_reconciliation';atomic(ledger,data);raise
   record['state']='ready';atomic(ledger,data);return dict(status(path),id=identifier,state='ready',verified=True)
  need(record and record['path']==str(path)and not path.is_symlink(),'not_owned');present=str(path)in paths
  if action=='reconcile':
   if record['state']in ['handoff_possible','handed_off']:
    target=pathlib.Path(record['target']);known=str(target)in paths and target.is_dir()
    actual=status(target)if known else None
    applied=known and actual['head']==record['base']and digest(git(target,'diff','--binary','--no-ext-diff','--no-textconv',record['base'],'--'))==record['patchSHA256']
    unchanged=known and actual['head']==record['base']and not actual['dirty']
    record['state']='handed_off'if applied else'ready'if unchanged else'needs_reconciliation'
   else:record['state']='ready'if present and path.is_dir()else'removed'if not present and not path.exists()else'needs_reconciliation'
   atomic(ledger,data);return dict(record,id=identifier)
  need(present and (record['state']=='ready'or(action=='remove'and record['state']=='handed_off')),'needs_reconciliation');source=status(path);need(source['revision']==q.get('expectedRevision'),'stale_context')
  if action=='remove':
   need(not source['dirty']and not source['conflicts'],'worktree_dirty');record['state']='removing';atomic(ledger,data);git(root,'worktree','remove',str(path));record['state']='removed';atomic(ledger,data);return {'id':identifier,'state':'removed','verified':not path.exists()}
  if action=='handoff':
   target=pathlib.Path(q['target']).resolve();need(str(target)in paths and target!=path,'unknown_worktree');dest=status(target);need(dest['revision']==q.get('targetRevision')and not dest['dirty'],'stale_context');need(not source['conflicts'],'git_conflict');need(not git(path,'ls-files','--others','--exclude-standard','-z'),'untracked_files');patch=git(path,'diff','--binary','--no-ext-diff','--no-textconv',record['base'],'--');need(bool(patch),'no_changes');need(dest['head']==record['base'],'base_changed')
   fd,name=tempfile.mkstemp(dir=state,prefix='handoff-');os.write(fd,patch);os.close(fd)
   try:
    git(target,'apply','--check','--binary',name);record['state']='handoff_possible';record['target']=str(target);record['patchSHA256']=digest(patch);atomic(ledger,data);git(target,'apply','--binary',name);after=status(target);record['state']='handed_off';atomic(ledger,data);return {'state':'handed_off','verified':after['dirty'],'patchSHA256':digest(patch),'target':after}
   finally:os.unlink(name)
  raise Refused('invalid_request')
def main(q):
 need(isinstance(q,dict));family=q.get('family');return files(q)if family=='files'else worktree(q)if family=='worktree'else(_ for _ in ()).throw(Refused('invalid_request'))
if __name__=='__main__':
 try:result={'result':main(json.loads(sys.argv[1]))}
 except Refused as e:result={'error':str(e)}
 except (OSError,ValueError,KeyError,TypeError,subprocess.SubprocessError):result={'error':'host_operation_failed'}
 output=json.dumps(result,separators=(',',':'));print(output if len(output.encode())<=CAP else'{"error":"size_limit"}')
