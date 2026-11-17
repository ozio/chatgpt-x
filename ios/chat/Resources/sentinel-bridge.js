(function(global){'use strict';
 if(global!==global.top||location.href!=='https://chatgpt.com/robots.txt'||document.contentType!=='text/plain'||!document.body||!document.body.textContent.includes('User-agent'))return 'wrong_document';
 if(!global.__OR6SentinelCore||typeof Promise!=='function'||typeof Map!=='function'||typeof TextEncoder!=='function'||!crypto.getRandomValues)return 'engine_unavailable';
 let state=null,serial=0;const core=global.__OR6SentinelCore;
 function token(v){return typeof v==='string'&&v.length>0&&v.length<=32768&&!/[\r\n]/.test(v);}
 function fail(s,code){if(state!==s||s.closed)return;s.phase='failed';s.issue=code;s.key=null;s.headers=null;s.resolve=null;s.reject=null;}
 function resources(){let all=[];try{all=performance.getEntriesByType('resource');}catch{}return{resourceCount:all.length,chatBootstrapResources:all.filter(x=>typeof x.name==='string'&&x.name.includes('/cdn/assets/')).length};}
 const bridge={
 begin(nonce){if(typeof nonce!=='string'||nonce.length!==36||state&&!state.closed&&state.phase!=='ready'&&state.phase!=='failed')return 'conflict';const s={serial:++serial,nonce,phase:'starting',issue:'',key:null,headers:null,closed:false,proofRequired:false,vmRequired:false,started:performance.now()};state=s;
  core.f(p=>{if(state!==s||s.closed)throw Error('cancelled');if(!token(p)||!p.startsWith('gAAAAAC')||p.startsWith('gAAAAACwQ8Lk5FbGpA2NcR9dShT6gYjU7VxZ4D'))throw Error('unsupported_environment');s.key=p;s.keyReady=performance.now();s.prepareKeyMs=s.keyReady-s.started;s.phase='requirements';return new Promise((resolve,reject)=>{s.resolve=resolve;s.reject=reject;});}).then(result=>{
   if(state!==s||s.closed)return;if(!result||result.chatRequirements?.force_login)return fail(s,'force_login');
   if(s.proofRequired&&(!token(result.proofToken)||result.proofToken.startsWith('gAAAAABwQ8Lk5FbGpA2NcR9dShT6gYjU7VxZ4D')))return fail(s,'proof_failed');
   if(s.vmRequired){if(!token(result.turnstileToken)||/^\d+$/.test(result.turnstileToken))return fail(s,'vm_failed');try{if(/^\d+: /.test(atob(result.turnstileToken)))return fail(s,'vm_failed');}catch{return fail(s,'vm_failed');}}
   const allowed=new Set(['OpenAI-Sentinel-Chat-Requirements-Prepare-Token','OpenAI-Sentinel-Chat-Requirements-Token','OpenAI-Sentinel-Proof-Token','OpenAI-Sentinel-Turnstile-Token']);
   if(!result.headers||!Object.keys(result.headers).length||Object.entries(result.headers).some(([k,v])=>!allowed.has(k)||!token(v)))return fail(s,'invalid_headers');
   s.headers=result.headers;s.phase='ready';s.readyAt=performance.now();s.computeMs=s.readyAt-s.computeStarted;
  },()=>fail(s,'sentinel_failed'));return 'started';
 },
 supply(nonce,response){const s=state;if(!s||s.nonce!==nonce||s.closed||s.phase!=='awaiting_requirements'||!response||typeof response!=='object'||Array.isArray(response))return 'rejected';
  if(response.force_login===true){fail(s,'force_login');return 'stopped';}
  if(!token(response.token)&&!token(response.prepare_token)||typeof response.proofofwork?.required!=='boolean'||typeof response.turnstile?.required!=='boolean'){fail(s,'unknown_requirements');return 'stopped';}
  s.proofRequired=response.proofofwork.required;s.vmRequired=response.turnstile.required;
  s.phase='computing';s.computeStarted=performance.now();s.requirementsWaitMs=s.computeStarted-s.keyReady;const resolve=s.resolve;s.resolve=null;s.reject=null;resolve(response);return 'accepted';
 },
 take(nonce){const s=state;if(!s||s.nonce!==nonce||s.closed)return JSON.stringify({phase:'stale',issue:'stale_context'});const result={nonce:s.nonce,phase:s.phase,issue:s.issue,proofRequired:s.proofRequired,vmRequired:s.vmRequired,computeMs:s.computeMs??null,prepareKeyMs:s.prepareKeyMs??null,requirementsWaitMs:s.requirementsWaitMs??null,readyWaitMs:s.readyAt===undefined?null:performance.now()-s.readyAt,...resources()};
  if(s.phase==='requirements'){result.p=s.key;s.key=null;s.phase='awaiting_requirements';}
  if(s.phase==='ready'){result.headers=s.headers;s.headers=null;s.closed=true;}
  return JSON.stringify(result);
 },
 cancel(nonce){const s=state;if(!s||s.nonce!==nonce)return 'stale';s.closed=true;s.key=null;s.headers=null;const reject=s.reject;s.resolve=null;s.reject=null;if(reject)reject(Error('cancelled'));return 'cancelled';}
 };
 global.__OR6MinimalSentinel=bridge;return 'installed';
})(window);
