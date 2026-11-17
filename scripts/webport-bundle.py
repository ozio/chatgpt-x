#!/usr/bin/env python3
"""Reproducible private WebPort bundle from hash-pinned original packages.
No package scripts run, no global runtime is installed or changed.
"""
import argparse,hashlib,io,json,lzma,os,pathlib,shutil,struct,subprocess,tarfile,urllib.request
R=pathlib.Path(__file__).resolve().parents[1]
O=R/'.artifacts/webport-bundle-20261114'
INPUT=R/'support/webport-bundle/inputs.json'
sha=lambda p:hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
ROOT_RELOCATIONS=[(b'/var/mobile/',b'./UserFiles/'),(b'/var/wkd/',b'./WebKit/'),(b'/var/wkd',b'./WebKit'),(b'/Library/',b'./Config/'),(b'/var/tmp/',b'./Caches/'),(b'/usr/lib/libcrypto.3.dylib',b'./LibSSL/libcrypto.3.dylib'),(b'/usr/lib/libssl.3.dylib',b'./LibSSL/libssl.3.dylib'),(b'/usr/lib/libvlc.dylib',b'./LibVLC/libvlc.dylib')]
assert all(len(a)==len(b)for a,b in ROOT_RELOCATIONS)

def ar(data):
 assert data[:8]==b'!<arch>\n';offset=8
 while offset<len(data):
  header=data[offset:offset+60];assert len(header)==60 and header[58:]==b'`\n';size=int(header[48:58]);name=header[:16].decode().strip().rstrip('/');offset+=60;yield name,data[offset:offset+size];offset+=size+(size&1)

def extract(data,root):
 root.mkdir(parents=True,exist_ok=True)
 with tarfile.open(fileobj=io.BytesIO(data),mode='r:*')as archive:
  members=archive.getmembers();assert len(members)<10000
  for m in members:
   parts=pathlib.PurePosixPath(m.name).parts;assert not m.name.startswith('/')and '..'not in parts
   target=root.joinpath(*[p for p in parts if p!='.'])
   if m.isdir():target.mkdir(parents=True,exist_ok=True);continue
   assert m.isfile()or m.issym()or m.islnk(),m.name
   target.parent.mkdir(parents=True,exist_ok=True)
   if m.isfile():
    assert m.size<=100*1024*1024
    with archive.extractfile(m)as src,target.open('wb')as dest:shutil.copyfileobj(src,dest)
    target.chmod(m.mode&0o777)
   elif m.issym():
    assert not m.linkname.startswith('/')and '..'not in pathlib.PurePosixPath(m.linkname).parts,(m.name,m.linkname)
    target.symlink_to(m.linkname)
   else:raise AssertionError('Hardlink must be explicitly materialized: '+m.name)

def macho(data):
 assert data[:4]==b'\xce\xfa\xed\xfe','Expected thin little-endian ARMv7 Mach-O'
 magic,cpu,sub,filetype,ncmds,sizecmds,flags=struct.unpack_from('<7I',data);assert cpu==12 and(sub&0xffffff)==9,(cpu,sub)
 commands=[];sections=[];position=28
 for _ in range(ncmds):
  cmd,size=struct.unpack_from('<II',data,position);assert size>=8 and position+size<=28+sizecmds
  item={'cmd':cmd,'offset':position,'size':size}
  if cmd in [0xc,0xd,0x80000018,0x8000001f,0x80000023]:
   at=position+struct.unpack_from('<I',data,position+8)[0];end=data.find(b'\0',at,position+size);assert end>=at;item.update(name=data[at:end].decode(),nameOffset=at,nameLength=end-at)
  if cmd==1:
   nsections=struct.unpack_from('<I',data,position+48)[0]
   for i in range(nsections):
    at=position+56+i*68;name=data[at:at+16].split(b'\0')[0].decode();segment=data[at+16:at+32].split(b'\0')[0].decode();addr,length,offset,align,reloc,nreloc,sectionFlags=struct.unpack_from('<7I',data,at+32);sections.append(dict(name=name,segment=segment,address=addr,size=length,offset=offset,flags=sectionFlags))
  commands.append(item);position+=size
 assert position==28+sizecmds
 return {'commands':commands,'sections':sections,'filetype':filetype,'architecture':'armv7'}

def relocate(original,flavor):
 data=bytearray(original);layout=macho(original);ranges=[]
 for c in layout['commands']:
  if 'name'in c:ranges.append((c['nameOffset'],c['nameLength'],'load_command'))
 for section in layout['sections']:
  if section['name']in ['__cstring','__objc_methname','__objc_classname']:
   start=section['offset'];end=start+section['size'];at=start
   while at<end:
    stop=original.find(b'\0',at,end)
    if stop<0:break
    if stop>at:ranges.append((at,stop-at,section['name']))
    at=stop+1
 changes=[]
 for at,length,kind in ranges:
  value=bytes(data[at:at+length]);replacement=value
  for prefix,new in ROOT_RELOCATIONS:
   if flavor=='system'and prefix not in [b'/Library/',b'/var/mobile/',b'/var/tmp/']:continue
   if value.startswith(prefix):replacement=new+value[len(prefix):];break
  if replacement!=value:
   assert len(replacement)==length;data[at:at+length]=replacement
   changes.append({'offset':at,'kind':kind,'before':value.decode(),'after':replacement.decode()})
 assert len(data)==len(original)
 return bytes(data),changes

def get_packages(cache):
 result={}
 for p in json.loads(INPUT.read_text())['packages']:
  path=cache/pathlib.PurePosixPath(p['url']).name
  if not path.exists():
   with urllib.request.urlopen(p['url'],timeout=45)as response,path.open('wb')as out:shutil.copyfileobj(response,out)
  assert path.stat().st_size==p['size']and sha(path)==p['sha256'],p['id']
  root=cache/'extracted'/p['id']
  if root.exists():
   assert root.is_relative_to(cache/'extracted')and not root.is_symlink();shutil.rmtree(root)
  for name,data in ar(path.read_bytes()):
   if name.startswith('data.tar'):extract(data,root/'data')
  result[p['id']]=root/'data'
 return result

def prepare(destination):
 O.mkdir(parents=True,exist_ok=True);cache=O/'inputs';cache.mkdir(exist_ok=True);roots=get_packages(cache)
 assert not destination.exists();destination.mkdir(parents=True)
 sources=[(roots['me.lululab.wk']/'var/wkd',destination/'WebKit'),(roots['libssl3']/'usr/lib',destination/'LibSSL'),(roots['me.lululab.libvlc']/'usr/lib',destination/'LibVLC')]
 records={}
 for source,target in sources:shutil.copytree(source,target,symlinks=True)
 loaders={'WK26.dylib':roots['me.lululab.wk']/'Library/MobileSubstrate/DynamicLibraries/WK26.dylib','STBridge.dylib':roots['me.lululab.stbridge']/'Library/MobileSubstrate/DynamicLibraries/STBridge.dylib'}
 for flavor in ['bundled','system']:
  target=destination/'Loaders'/flavor;target.mkdir(parents=True)
  for name,source in loaders.items():shutil.copyfile(source,target/name)
 for path in sorted(destination.rglob('*')):
  if not path.is_file()or path.is_symlink():continue
  relative=path.relative_to(destination).as_posix();original=path.read_bytes();entry={'originalSHA256':hashlib.sha256(original).hexdigest(),'bytes':len(original)}
  if relative.startswith('WebKit/'):entry['systemPath']='/var/wkd/'+relative[len('WebKit/'):]
  elif relative.startswith(('LibSSL/','LibVLC/')):entry['systemPath']='/usr/lib/'+path.name
  elif relative.startswith('Loaders/'):entry['systemPath']='/Library/MobileSubstrate/DynamicLibraries/'+path.name
  if original[:4]==b'\xce\xfa\xed\xfe':
   flavor='system'if '/system/'in '/'+relative else'bundled';patched,changes=relocate(original,flavor);path.write_bytes(patched);entry.update(macho=True,flavor=flavor,changes=changes)
   subprocess.run(['ldid','-Hsha1','-S',str(path)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
   entry['dependencies']=[c['name']for c in macho(path.read_bytes())['commands']if c['cmd']in [0xc,0x80000018,0x8000001f,0x80000023]]
  entry['sha256']=sha(path);records[relative]=entry
 manifest={'schema':1,'inputSHA256':sha(INPUT),'files':records,'unpackedBytes':sum(x['bytes']for x in records.values()),'strategy':'fixed-length path relocation; private process CWD aliases; original files unchanged','privateExperimentOnly':True}
 (destination/'Manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');return manifest

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args();d=prepare(a.output.resolve());print(json.dumps({'result':'WEBPORT_BUNDLE_PREPARED','files':len(d['files']),'MiB':round(d['unpackedBytes']/1048576,2)}))
