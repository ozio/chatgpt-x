#!/usr/bin/env python3
"""Offline extraction from CLI 0.163.0; does not contact or inspect an account."""
import hashlib,json,pathlib,re,sys
R=pathlib.Path(__file__).resolve().parents[2]
S=R/'support/codex/schema'
methods={
 'initialize':('InitializeParams','InitializeResponse'),
 'thread/start':('ThreadStartParams','ThreadStartResponse'),
 'thread/list':('ThreadListParams','ThreadListResponse'),
 'thread/read':('ThreadReadParams','ThreadReadResponse'),
 'thread/resume':('ThreadResumeParams','ThreadResumeResponse'),
 'thread/turns/list':('ThreadTurnsListParams','ThreadTurnsListResponse'),
 'thread/items/list':('ThreadItemsListParams','ThreadItemsListResponse'),
 'turn/start':('TurnStartParams','TurnStartResponse'),
 'turn/steer':('TurnSteerParams','TurnSteerResponse'),
 'turn/interrupt':('TurnInterruptParams','TurnInterruptResponse'),
 'thread/backgroundTerminals/list':('ThreadBackgroundTerminalsListParams','ThreadBackgroundTerminalsListResponse'),
 'thread/backgroundTerminals/terminate':('ThreadBackgroundTerminalsTerminateParams','ThreadBackgroundTerminalsTerminateResponse'),
 'fs/readDirectory':('FsReadDirectoryParams','FsReadDirectoryResponse'),
 'fs/getMetadata':('FsGetMetadataParams','FsGetMetadataResponse'),
 'fs/createDirectory':('FsCreateDirectoryParams','FsCreateDirectoryResponse'),
 'command/exec':('CommandExecParams','CommandExecResponse'),
 'account/read':('GetAccountParams','GetAccountResponse'),
}
requests={
 'item/commandExecution/requestApproval':('CommandExecutionRequestApprovalParams','CommandExecutionRequestApprovalResponse'),
 'item/fileChange/requestApproval':('FileChangeRequestApprovalParams','FileChangeRequestApprovalResponse'),
 'item/tool/requestUserInput':('ToolRequestUserInputParams','ToolRequestUserInputResponse'),
}
notifications=['thread/started','thread/status/changed','thread/name/updated','thread/closed','thread/archived','thread/deleted','turn/started','turn/completed','turn/diff/updated','item/started','item/completed','item/agentMessage/delta','item/reasoning/summaryTextDelta','item/reasoning/textDelta','item/commandExecution/outputDelta','item/commandExecution/terminalInteraction','item/fileChange/outputDelta','item/fileChange/patchUpdated','serverRequest/resolved','error','warning']
ann={'$schema','description','title','default','deprecated','format'}
allowed={'type','enum','required','properties','additionalProperties','items','minLength','maxLength','minimum','maximum','minItems','maxItems','$ref','anyOf','allOf','oneOf'}
sourceHashes={str((S/n).relative_to(R)):hashlib.sha256((S/n).read_bytes()).hexdigest()for n in ['ClientRequest.json','ServerRequest.json']};definitions={}
def clean(v):
 if isinstance(v,bool):return v
 assert isinstance(v,dict),v
 out={}
 for k,x in v.items():
  if k in ann or k=='definitions':continue
  assert k in allowed,(k,v)
  if k=='properties':out[k]={a:clean(b)for a,b in x.items()}
  elif k in ['items','additionalProperties']:out[k]=clean(x)
  elif k in ['anyOf','allOf','oneOf']:out[k]=list(map(clean,x))
  else:out[k]=x
 return out

def load(name):
 files=list(S.rglob(name+'.json'));assert len(files)==1,(name,files)
 f=files[0];raw=f.read_bytes();sourceHashes[str(f.relative_to(R))]=hashlib.sha256(raw).hexdigest();d=json.loads(raw)
 for n,v in d.get('definitions',{}).items():
  v=clean(v);assert n not in definitions or definitions[n]==v,n
  definitions[n]=v
 return clean(d)

extension=json.loads((R/'support/codex8/extension.json').read_text())
methods.update(extension['methods']);requests.update(extension['requests']);notifications+=extension['notifications']
seven=json.loads((R/'support/codex7/extension.json').read_text());methods.update(seven['methods']);notifications+=seven['notifications']
def group(rows):return {m:{'params':load(a) if a else {'type':'null'},'result':load(b)}for m,(a,b)in rows.items()}
client=group(methods);server=group(requests)
f=S/'ServerNotification.json';raw=f.read_bytes();sourceHashes[str(f.relative_to(R))]=hashlib.sha256(raw).hexdigest();d=json.loads(raw);byMethod={x['properties']['method']['enum'][0]:x['properties']['params']['$ref'].rsplit('/',1)[1]for x in d['oneOf']}
notify={m:load(byMethod[m])for m in notifications}
features={}
text=(R/'docs/support/function-implementation-groups/codex.md').read_text().split('## Исходные оценки')[0]
for line in text.splitlines():
 m=re.match(r'\| \[`(codex\.[^`]+)`.*?\| (9|10)/10 \|',line)
 if m:features[m[1]]=int(m[2])
assert len(features)==11,features
out=dict(protocolVersion='0.163.0',features=features,features8=extension['features'],features7=seven['features'],client=client,server=server,notifications=notify,definitions=definitions)
for name,value in [('contracts.json',out),('provenance.json',dict(cliVersion='0.163.0',sourceSHA256=sourceHashes,documentation='https://learn.chatgpt.com/docs/app-server',accountRequests=0))]:
 (R/'support/codex'/name).write_text(json.dumps(value,sort_keys=True,indent=2)+'\n')
print('CODEX_CONTRACTS_GENERATED',len(features),len(client),len(server),len(notify))
