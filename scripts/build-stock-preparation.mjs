// Reproducible ES5/standard compatibility resources. No network, account or VM.
import fs from'node:fs';import path from'node:path';import crypto from'node:crypto';import{createRequire}from'node:module';import{execFileSync}from'node:child_process';
import{assertStockGrammar}from'../support/stock-compat/syntax-check.mjs';
const root=path.resolve(import.meta.dirname,'..'),req=createRequire(path.join(root,'tools/package.json')),babel=req('@babel/core'),preset=req('@babel/preset-env').default;
if(req('@babel/core/package.json').version!=='8.1.0'||req('@babel/preset-env/package.json').version!=='8.0.7')throw Error('Babel pin drift');
const [input,out,roots]=process.argv.slice(2);if(!input||!out||!roots)throw Error('usage: ORIGINAL_CORE OUTPUT ROOTS');fs.mkdirSync(out,{recursive:true});
const sha=b=>crypto.createHash('sha256').update(b).digest('hex'),original=fs.readFileSync(input,'utf8');
const lower=s=>babel.transformSync(s,{presets:[[preset,{targets:{safari:'6'},modules:false,useBuiltIns:false}]],babelrc:false,configFile:false,sourceType:'script',comments:false,compact:false}).code+'\n';
let code=lower(original);assertStockGrammar(code);
// The global transparent WebCrypto return wrapper delegates once to native RNG.
// Keep the already verified caller adaptation too; no VM observer in production.
const tree=req('@babel/parser').parse(code,{sourceType:'script'});let factory,ret;
function walk(n,fn){if(!n?.type)return;fn(n);for(const[k,v]of Object.entries(n)){if(['loc','extra','comments'].includes(k))continue;for(const c of Array.isArray(v)?v:[v])if(c?.type)walk(c,fn);}}
walk(tree,n=>{if(n.type==='ObjectProperty'&&n.key.value==='sXNb'){if(factory)throw Error('ambiguous RNG module');factory=n.value;}});if(!factory)throw Error('RNG module absent');
walk(factory,n=>{if(n.type==='ReturnStatement'&&n.argument?.type==='CallExpression'&&n.argument.callee.name==='r'&&n.argument.arguments.length===1&&n.argument.arguments[0].name==='_a4'){if(ret)throw Error('ambiguous RNG call');ret=n;}});
if(!ret||code.slice(ret.start,ret.end)!=='return r(_a4);'||!code.slice(factory.start,factory.end).includes('r = crypto.getRandomValues.bind(crypto)'))throw Error('RNG caller drift');
code=code.slice(0,ret.start)+'var _or6NativeRNGResult = r(_a4);\n          return _or6NativeRNGResult === undefined ? _a4 : _or6NativeRNGResult;'+code.slice(ret.end);assertStockGrammar(code);
execFileSync(process.execPath,[path.join(root,'support/stock-compat/build-resources.mjs'),'--output',out],{cwd:root,stdio:'pipe'});
fs.writeFileSync(path.join(out,'SentinelCore.js'),code);
const bridge=fs.readFileSync(path.join(root,'ios/chat/Resources/sentinel-bridge.js'),'utf8');fs.writeFileSync(path.join(out,'SentinelBridge.js'),lower(bridge));
for(const name of ['DocumentCheck.js','DocumentMIME.js','LegacyCrypto.js'])fs.copyFileSync(path.join(root,'ios/chat/stock',name),path.join(out,name));
for(const name of fs.readdirSync(out).filter(n=>n.endsWith('.js')))assertStockGrammar(fs.readFileSync(path.join(out,name),'utf8'));
const files=Object.fromEntries(fs.readdirSync(out).filter(n=>n.endsWith('.js')).map(n=>[n,sha(fs.readFileSync(path.join(out,n)))]));
const report={schema:1,files,rootsSHA256:sha(fs.readFileSync(roots)),originalCoreSHA256:sha(original),loweredCoreSHA256:sha(code),originalBridgeSHA256:sha(bridge),vmObserver:false,vmValidationUnchanged:true,networkRequests:0,babelVersion:babel.version};fs.writeFileSync(path.join(out,'Manifest.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));
