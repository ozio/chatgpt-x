#!/usr/bin/env python3
"""Pinned C-only PocketSphinx5.0.4, SDK6.1 ARMv7 + native host. No tool installation."""
from pathlib import Path
import concurrent.futures,difflib,hashlib,json,os,re,shutil,subprocess,tarfile,urllib.request
R=Path(__file__).resolve().parents[2]; O=R/'.artifacts/api5-recheck-20261114/asr';O.mkdir(parents=True,exist_ok=True)
TAG='v5.0.4';COMMIT='a9ec4b881de75771d8e6b8ded2823266589cbd5d';ARCHIVE_SHA='9acd63cfdc76bbc85b7b6c6610b7a9cf30c79d5b36a31de7dc2f969e962653d7'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
a=O/'pocketsphinx-v5.0.4.tar.gz'
if not a.exists():
 with urllib.request.urlopen('https://codeload.github.com/cmusphinx/pocketsphinx/tar.gz/refs/tags/v5.0.4',timeout=180)as r,a.open('wb')as w:shutil.copyfileobj(r,w)
assert sha(a)==ARCHIVE_SHA,'upstream archive mismatch'
S=O/'pocketsphinx-5.0.4'
if not S.exists():
 with tarfile.open(a)as t:
  assert all(not p.name.startswith('/')and'..'not in Path(p.name).parts and not p.issym()and not p.islnk()for p in t.getmembers());t.extractall(O)
with tarfile.open(a)as t:
 for member in t.getmembers():
  if member.isfile():
   p=O/member.name
   assert p.is_file()and sha(p)==hashlib.sha256(t.extractfile(member).read()).hexdigest(),str(p)+' differs from pinned archive'
tool=json.loads((R/'.artifacts/native-api-20261109/transport/build.json').read_text())
# Use exactly upstream's library source set; no CLI, Python, socket library or optional plugin.
files=re.search(r'add_library\(pocketsphinx\s+(.*?)\s+\)',(S/'src/CMakeLists.txt').read_text(),re.S)[1].split()
source_hash={str(p.relative_to(S)):sha(p)for p in sorted(S.rglob('*'))if p.is_file()}
# Preserve pristine extracted tag; all portability changes are explicit and hashed.
pristine=S;P=O/'pocketsphinx-5.0.4-portable';shutil.copytree(S,P,dirs_exist_ok=True)
patches=[];diff=[]
for rel,pattern,count in [('src/ps_lattice.c',r'((?:l->link->ascr|x->link->ascr|link->ascr|dag->final_node_ascr)) << SENSCR_SHIFT',10),('src/util/logmath.c',r'(logb_p) << (lmath->t.shift)',3)]:
 p=P/rel;before=p.read_text()
 if 'lattice'in rel:after,n=re.subn(pattern,lambda m:'(int32)((uint32)('+m[1]+') << SENSCR_SHIFT)',before)
 else:after,n=re.subn(pattern,lambda m:'(int32)((uint32)('+m[1]+') << '+m[2]+')',before)
 assert n==count,(rel,n);p.write_text(after);patches.append({'path':rel,'beforeSHA256':hashlib.sha256(before.encode()).hexdigest(),'afterSHA256':sha(p),'replacements':n,'reason':'C undefined signed negative left shift; explicit uint32 shift then int32 conversion preserves target two-complement score representation'})
 diff.extend(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile='a/'+rel,tofile='b/'+rel))
(O/'portable.patch').write_text(''.join(diff));S=P
commands=[]
def run(args):
 p=subprocess.run([str(v)for v in args],cwd=R,capture_output=True,text=True);commands.append({'argv':[str(v)for v in args],'exit':p.returncode,'stderr':p.stderr});assert p.returncode==0,p.stderr[-6000:]
archives={};includes={}
for mode,extra in [('host',tool['hostFlags']),('armv7',tool['armFlags']),('sanitized',tool['hostFlags']+['-fsanitize=address,undefined','-fno-omit-frame-pointer','-g','-O1'])]:
 B=O/mode;B.mkdir(exist_ok=True);(B/'include/pocketsphinx').mkdir(parents=True,exist_ok=True)
 config='\n'.join(['#define DEFAULT_RADIX 12','#define HAVE_LONG_LONG 1','#define HAVE_SNPRINTF 1','#define HAVE_SYS_STAT_H 1','#define HAVE_SYS_TYPES_H 1','#define HAVE_UNISTD_H 1','#define HAVE_STDINT_H 1','#define HAVE_INTTYPES_H 1',f'#define SIZEOF_LONG {4 if mode=="armv7"else 8}','#define SIZEOF_LONG_LONG 8','#define PACKAGE_VERSION "5.0.4"'])+'\n'
 # HAVE_POPEN deliberately absent. Uncompressed pinned paths only; no shell decompression.
 (B/'config.h').write_text(config);(B/'include/pocketsphinx/sphinx_config.h').write_text(config)
 inc=['-I'+str(B),'-I'+str(S/'src'),'-I'+str(S/'include'),'-I'+str(B/'include')];includes[mode]=inc
 def compile_one(f):
  obj=B/(f.replace('/','_')+'.o');args=[tool['clang'],*extra,'-std=gnu99','-DHAVE_CONFIG_H','-DPOCKETSPHINX_EXPORTS','-DSPHINXBASE_EXPORTS','-DMODELDIR=""',*inc,'-c',S/'src'/f,'-o',obj]
  run(args)
  return obj
 with concurrent.futures.ThreadPoolExecutor(max_workers=4)as pool:objects=list(pool.map(compile_one,files))
 archive=B/'libpocketsphinx.a';run(['/usr/bin/libtool','-static','-o',archive,*objects]);archives[mode]=str(archive)
# Fixed same-tag assets, plus all redistributed licenses. LM/dictionary have no separate
# license notices in the tag and are distributed under repository LICENSE; HMM has its own.
M=O/'Rev5ASRModel';M.mkdir(exist_ok=True)
for src,dest in [(S/'model/en-us/en-us',M/'en-us'),(S/'model/en-us/cmudict-en-us.dict',M/'cmudict-en-us.dict'),(S/'model/en-us/en-us.lm.bin',M/'en-us.lm.bin'),(S/'LICENSE',M/'PocketSphinx-LICENSE.txt')]:
 if src.is_dir():shutil.copytree(src,dest,dirs_exist_ok=True)
 else:shutil.copy2(src,dest)
# Root LICENSE omits some embedded notices (notably David Gay/Lucent dtoa).
# Preserve every distinct license/copyright C comment from the tagged C/header
# tree, including third-party support routines; never infer root notice coverage.
notices={}
for p in sorted(pristine.rglob('*')):
 if p.suffix not in{'.c','.h'}:continue
 text=p.read_text(errors='replace')
 for comment in re.findall(r'/\*.*?\*/',text,re.S):
  if re.search(r'copyright|permission.*(?:grant|use|copy)|redistribut',comment,re.I):notices.setdefault(comment,[]).append(str(p.relative_to(pristine)))
(M/'Embedded-Source-Notices.txt').write_text('PocketSphinx5.0.4 embedded source notices, verbatim comments.\n\n'+'\n\n'.join('Files: '+', '.join(paths)+'\n'+notice for notice,paths in notices.items())+'\n')
model={str(p.relative_to(M)):sha(p)for p in sorted(M.rglob('*'))if p.is_file()and p.name!='manifest.json'}
manifest={'version':'pocketsphinx-5.0.4-en-US','commit':COMMIT,'files':model};(M/'manifest.json').write_text(json.dumps(manifest,sort_keys=True,indent=2)+'\n')
# Compile-time trusted manifest prevents caller-controlled file lists/hash substitution.
header='/* Generated from pinned PocketSphinx5.0.4 archive; build.py regenerates identically. */\nstatic NSDictionary *OR6Rev5ASRExpectedFiles(void){return @{'+','.join('@"'+k+'":@"'+v+'"'for k,v in model.items())+'};}\n'
(R/'ios/api/revisit5asr/OR6Rev5ASRModelHashes.h').write_text(header)
report={'tag':TAG,'commit':COMMIT,'archiveSHA256':ARCHIVE_SHA,'sourceSHA256':source_hash,'archives':archives,'archiveBinarySHA256':{k:sha(Path(v))for k,v in archives.items()},'includeFlags':includes,'modelDirectory':str(M),'modelSHA256':model,'librarySources':files,'commands':commands,'patches':patches,'portablePatchSHA256':sha(O/'portable.patch'),'sourceDirectory':str(S),'pristineSourceDirectory':str(pristine),'effectiveSourceSHA256':{str(p.relative_to(S)):sha(p)for p in sorted(S.rglob('*'))if p.is_file()},'patchedSourceSHA256':{str(p.relative_to(S)):sha(p)for p in sorted(S.rglob('*'))if p.is_file()},'configurationHeaderSHA256':{mode:{str(p):sha(p)for p in [O/mode/'config.h',O/mode/'include/pocketsphinx/sphinx_config.h']}for mode in archives},'includeHeaderSHA256':{mode:{str(p):sha(p)for root in flags for p in sorted(Path(root[2:]).rglob('*.h'))}for mode,flags in includes.items()},'configuration':'floating point; no popen; explicit uint32 score-shift portability patch; SDK6.1 ARMv7/iOS6.0; host arm64'}
(O/'build.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:report[k]for k in ['archives','modelDirectory','includeFlags']}))
