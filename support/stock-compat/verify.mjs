// Host semantic checks, not old-JSC or service acceptance. Run under OS deny-network.
import fs from 'node:fs';import path from 'node:path';import vm from 'node:vm';import assert from 'node:assert/strict';import crypto from 'node:crypto';
import {TextEncoder} from 'node:util';import {performance} from 'node:perf_hooks';import {createRequire} from 'node:module';
import {assertStockGrammar} from './syntax-check.mjs';
const root=path.resolve(import.meta.dirname,'../..'),req=createRequire(path.join(root,'tools/package.json')),acorn=req('acorn');
const args=process.argv.slice(2);if(args.length!==2||args[0]!=='--output')throw Error('usage: --output DIR');
const out=path.resolve(args[1]);fs.mkdirSync(out,{recursive:true});
const resource=path.join(root,'.artifacts/stock-compat-20261111/resources'),compat=fs.readFileSync(path.join(resource,'StockCompatibility.js'),'utf8'),fixture=fs.readFileSync(path.join(resource,'compat-fixtures.js'),'utf8'),core=fs.readFileSync(path.join(root,'.artifacts/webport-native-stage1-20261111/core/MinimalSentinelCore.es5.js'),'utf8');
const digest=s=>crypto.createHash('sha256').update(s).digest('hex');let assertions=0;
function check(v){assert.ok(v);assertions++;}
assertStockGrammar(compat);assertStockGrammar(fixture);assertions+=2;
assert.throws(()=>assertStockGrammar('"use strict";if(true){function unsafe(){}}'),SyntaxError);assertions++;
assertStockGrammar('"use strict";function safe(){function nested(){}return nested;}');assertions++;
function realm(stripped=true){
 const c=vm.createContext({setTimeout,clearTimeout,crypto:crypto.webcrypto});
 vm.runInContext('var window=this;',c);
 if(stripped)vm.runInContext("Reflect=undefined;Map=undefined;Set=undefined;Promise=undefined;Symbol=undefined;TextEncoder=undefined;URLSearchParams=undefined;performance=undefined;Array.from=undefined;Object.entries=undefined;Math.imul=undefined;String.prototype.includes=undefined;String.prototype.startsWith=undefined;Array.prototype.includes=undefined;",c);
 else Object.assign(c,{TextEncoder,performance,URLSearchParams});
 return c;
}
const run=(c,s)=>vm.runInContext(s,c,{timeout:1500});
async function fixtures(c){
 assert.equal(run(c,fixture),'installed');assert.equal(run(c,'__OR6CompatFixtures.start()'),'started');
 const end=Date.now()+10500;let value;
 while(Date.now()<end){value=JSON.parse(run(c,'__OR6CompatFixtures.take()'));if(value.phase==='complete')return value;await new Promise(r=>setTimeout(r,5));}
 throw Error('fixture deadline: '+JSON.stringify(value));
}
const good=realm();const originalSource=run(good,'Function.prototype.toString');check(run(good,compat)==='installed');check(run(good,'Function.prototype.toString')===originalSource);check(!run(good,"Function.prototype.toString.call(Map).indexOf('[native code]')>=0"));run(good,core);
const positive=await fixtures(good);check(positive.failures===0&&positive.asyncSettled&&positive.coreReady);
const preserved=realm(false);const nativeEncoder=preserved.TextEncoder,nativeClock=preserved.performance.now;
check(run(preserved,compat)==='installed');check(preserved.TextEncoder===nativeEncoder&&preserved.performance.now===nativeClock);
run(preserved,core);const nativeControl=await fixtures(preserved);check(nativeControl.failures===0);
check(run(good,compat)==='installed');check(run(good,'__OR6Compatibility.installed.coarseClock')===true);
// Differential UTF8 oracle over deterministic UTF16 strings, including lone
// surrogates and small destination buffers. No account or browser stand-ins.
const encode=run(good,'(function(s){return Array.prototype.slice.call(new TextEncoder().encode(s));})');
const into=run(good,'(function(s,n){var a=new Uint8Array(n),r=new TextEncoder().encodeInto(s,a);return {read:r.read,written:r.written,bytes:Array.prototype.slice.call(a)};})');
const oracle=new TextEncoder(),corpus=['','ASCII','\u0000','\uD800','\uDFFF','\uD800\uD800\uDC00','\uD83D\uDE00','\u00E9\u4E2D','\uD800x\uDFFF',null,undefined,123,true];
let seed=0x12345678;
for(let n=0;n<2500;n++){let s='';for(let j=0;j<(n%9)+1;j++){seed=(Math.imul(seed,1664525)+1013904223)>>>0;s+=String.fromCharCode(seed&65535);}corpus.push(s);}
for(const s of corpus){
 assert.deepEqual(Array.from(encode(s)),Array.from(oracle.encode(s)));assertions++;
 const input=String(s);
 for(let n=0;n<9;n++){const bytes=new Uint8Array(n),r=oracle.encodeInto(input,bytes),actual=JSON.parse(JSON.stringify(into(input,n)));assert.deepEqual(actual,{read:r.read,written:r.written,bytes:Array.from(bytes)});assertions++;}
}
check(run(good,"(function(){try{TextEncoder.prototype.encode.call(Object.create(TextEncoder.prototype),'x');return false;}catch(e){return e.name==='TypeError';}})()"));
check(run(good,"(function(){try{new TextEncoder().encode(Symbol('x'));return false;}catch(e){return e.name==='TypeError';}})()"));
// Test the coarse clock clamp with controlled host-only Date.now values; never
// change phone clocks or synthesize browser identity data.
check(run(good,"(function(){var original=Date.now,a=performance.now();try{Date.now=function(){return 0;};var b=performance.now();Date.now=function(){return 9999999999999;};return b>=a&&performance.now()>=b;}finally{Date.now=original;}})()"));
const absent=realm();let missing=false;try{run(absent,core);}catch(e){missing=e.name==='TypeError'||e.name==='ReferenceError';}check(missing);
const broken=realm();run(broken,compat);run(broken,core);run(broken,'TextEncoder.prototype.encode=function(){return new Uint8Array(0);};');
const noReflect=realm();run(noReflect,compat);run(noReflect,core);run(noReflect,'Reflect=undefined;');const rejectedReflect=await fixtures(noReflect);check(rejectedReflect.failures>0&&rejectedReflect.firstFailure==='reflect');
const negative=await fixtures(broken);check(negative.failures>0&&negative.firstFailure==='utf8');
const report={result:'STOCK_COMPAT_HOST_VERIFIED',assertions,utf16Cases:corpus.length,positive,nativeControl,negative:{missingReflectRejected:rejectedReflect.failures>0,missingMapRejected:missing,brokenUTF8Rejected:negative.failures>0},nativeFacilitiesPreserved:true,idempotent:true,hostOnlyClockControl:true,resourceSHA256:digest(compat),fixtureSHA256:digest(fixture),coreSHA256:digest(core),sourceSHA256:Object.fromEntries(['runtime.js','build-resources.mjs','compat-fixtures.js','syntax-check.mjs','verify.mjs'].map(n=>['support/stock-compat/'+n,digest(fs.readFileSync(path.join(root,'support/stock-compat',n)))])),node:process.version,networkRequests:0,deviceOperations:0,limitations:['Stripped modern Node realm is not the iOS6 engine.','Old-iOS Promise scheduling uses core-js fallback; full native microtask equivalence is not asserted.','No real environment collector, PoW, challenge VM, service or account code runs.']};
fs.writeFileSync(path.join(out,'verification.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({result:report.result,assertions,utf16Cases:corpus.length,positive,negative:report.negative}));
