// Bundle pinned local MIT core-js modules. Does not download or install anything.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
import {assertStockGrammar} from './syntax-check.mjs';
const root=path.resolve(import.meta.dirname,'../..'),req=createRequire(path.join(root,'tools/package.json'));
const {parse}=req('@babel/parser');
const args=process.argv.slice(2);if(args.length!==2||args[0]!=='--output')throw Error('usage: --output DIR');
const out=path.resolve(args[1]);fs.mkdirSync(out,{recursive:true});
const base=path.join(root,'tools/node_modules/core-js');
const pkg=JSON.parse(fs.readFileSync(path.join(base,'package.json')));
if(pkg.version!=='3.51.0'||pkg.license!=='MIT')throw Error('core-js pin drift');
const lock=JSON.parse(fs.readFileSync(path.join(root,'tools/package-lock.json')));
const pin=lock.packages['node_modules/core-js'];if(pin.version!==pkg.version||!pin.integrity)throw Error('lock pin drift');
const entries=['es.symbol','es.symbol.iterator','es.symbol.async-iterator','es.object.to-string','es.array.iterator','es.string.iterator','es.array.from','es.math.imul','es.object.entries','es.promise','es.promise.finally','es.map','es.set','es.string.includes','es.string.starts-with','es.string.pad-start','es.array.includes','es.reflect.apply','es.reflect.construct','es.reflect.define-property','es.reflect.delete-property','es.reflect.get','es.reflect.get-own-property-descriptor','es.reflect.get-prototype-of','es.reflect.has','es.reflect.is-extensible','es.reflect.own-keys','es.reflect.prevent-extensions','es.reflect.set','es.reflect.set-prototype-of','es.reflect.to-string-tag','web.url-search-params'].map(x=>'modules/'+x+'.js');
const modules=new Map(),digest=b=>crypto.createHash('sha256').update(b).digest('hex');
function walk(n,visit){if(!n||typeof n!=='object')return;visit(n);for(const[k,v]of Object.entries(n)){if(['loc','extra','comments','tokens'].includes(k))continue;for(const x of Array.isArray(v)?v:[v])if(x&&typeof x==='object'&&typeof x.type==='string')walk(x,visit);}}
function add(id){
 if(modules.has(id))return;
 const file=path.resolve(base,id);if(!file.startsWith(base+path.sep))throw Error('dependency escape');
 const bytes=fs.readFileSync(file),source=bytes.toString('utf8'),dependencies={};modules.set(id,{source,bytes:bytes.length,sha256:digest(bytes),dependencies});
 assertStockGrammar(source);
 walk(parse(source,{sourceType:'script'}),n=>{if(n.type!=='CallExpression'||n.callee?.type!=='Identifier'||n.callee.name!=='require')return;
  if(n.arguments.length!==1||n.arguments[0].type!=='StringLiteral')throw Error('dynamic dependency in '+id);
  const name=n.arguments[0].value;if(!name.startsWith('.'))throw Error('external dependency '+name);
  const target=path.posix.normalize(path.posix.join(path.posix.dirname(id),name))+(name.endsWith('.js')?'':'.js');dependencies[name]=target;add(target);
 });
}
entries.forEach(add);add('internals/internal-state.js');
const sorted=[...modules].sort(([a],[b])=>a.localeCompare(b));
const pinned=JSON.parse(fs.readFileSync(path.join(root,'support/stock-compat/vendor-lock.json')));
if(pinned.version!==pkg.version||pinned.lockIntegrity!==pin.integrity||pinned.licenseSHA256!==digest(fs.readFileSync(path.join(base,'LICENSE'))))throw Error('pinned metadata/license drift');
if(JSON.stringify(Object.keys(pinned.modules).sort())!==JSON.stringify([...modules.keys()].sort()))throw Error('pinned module closure drift');
for(const[id,m]of sorted)if(pinned.modules[id]!==m.sha256)throw Error('pinned module source drift: '+id);
const factories=sorted.map(([id,m])=>JSON.stringify(id)+':[function(module,exports,require){\n'+m.source+'\n},'+JSON.stringify(m.dependencies)+']').join(',\n');
const header='/* core-js 3.51.0, MIT; complete notice: licenses/CoreJS.txt. Generated from hash-recorded local sources. */\n';
const loader=header+'(function(){"use strict";var modules={'+factories+'},cache=Object.create(null);function load(id){if(cache[id])return cache[id].exports;if(!Object.prototype.hasOwnProperty.call(modules,id))throw Error("unsupported_module");var spec=modules[id],module={exports:{}};cache[id]=module;spec[0](module,module.exports,function(name){var next=spec[1][name];if(!next)throw Error("unsupported_dependency");return load(next);});return module.exports;}'+entries.map(id=>'load('+JSON.stringify(id)+');').join('')+'return load("internals/internal-state.js");})()';
const own=fs.readFileSync(path.join(root,'support/stock-compat/runtime.js'),'utf8');
const prefix='(function(window){if(window.__OR6Compatibility&&window.__OR6Compatibility.version==="stock-compat-1")return "installed";var before={screen:window.screen,navigator:window.navigator,document:window.document,location:window.location,agent:window.navigator&&window.navigator.userAgent,crypto:window.crypto,random:window.crypto&&window.crypto.getRandomValues,encoder:window.TextEncoder,clock:window.performance&&window.performance.now,defineProperty:Object.defineProperty,functionString:Object.getOwnPropertyDescriptor(Function.prototype,"toString")};\n';
const suffix='\nvar m=window.__OR6Compatibility;m.identityPreserved=window.screen===before.screen&&window.navigator===before.navigator&&window.document===before.document&&window.location===before.location&&(!window.navigator||window.navigator.userAgent===before.agent);m.nativeFacilitiesPreserved=window.crypto===before.crypto&&(!window.crypto||window.crypto.getRandomValues===before.random)&&(!before.encoder||window.TextEncoder===before.encoder)&&(!before.clock||window.performance.now===before.clock)&&Function.prototype.toString===before.functionString.value;return "installed";})(window);\n';
// Keep the browser's actual function source reporting. core-js's internal
// make-built-in source camouflage is not exposed as our browser environment.
const restore='before.defineProperty(Function.prototype,"toString",before.functionString);\n';
const bundle=prefix+'var __or6State='+loader+';\n'+restore+own+suffix;
assertStockGrammar(bundle);
fs.writeFileSync(path.join(out,'StockCompatibility.js'),bundle);
fs.copyFileSync(path.join(root,'support/stock-compat/compat-fixtures.js'),path.join(out,'compat-fixtures.js'));
assertStockGrammar(fs.readFileSync(path.join(out,'compat-fixtures.js'),'utf8'));
fs.mkdirSync(path.join(out,'licenses'),{recursive:true});
fs.copyFileSync(path.join(base,'LICENSE'),path.join(out,'licenses/CoreJS.txt'));
fs.copyFileSync(path.join(root,'LICENSE'),path.join(out,'licenses/Application.txt'));
const report={schema:1,result:'STOCK_COMPAT_RESOURCES_BUILT',coreJS:{version:pkg.version,license:pkg.license,lockIntegrity:pin.integrity,licenseSHA256:digest(fs.readFileSync(path.join(base,'LICENSE')))},entries,modules:sorted.map(([id,m])=>({id,sha256:m.sha256,bytes:m.bytes,dependencies:m.dependencies})),outputs:{'StockCompatibility.js':{sha256:digest(bundle),bytes:Buffer.byteLength(bundle)},'compat-fixtures.js':{sha256:digest(fs.readFileSync(path.join(out,'compat-fixtures.js'))),bytes:fs.statSync(path.join(out,'compat-fixtures.js')).size}},ownSources:Object.fromEntries(['runtime.js','compat-fixtures.js','build-resources.mjs','syntax-check.mjs','vendor-lock.json'].map(n=>['support/stock-compat/'+n,digest(fs.readFileSync(path.join(root,'support/stock-compat',n)))])),notes:['ES5 Symbol emulation provides usable well-known keys, not native typeof-symbol.','Missing native high-resolution performance.now uses a monotonic clamped Date-based coarse clock; timeOrigin is not fabricated.','Readiness requires semantic fixtures and core init; presence checks alone are insufficient.'],networkRequests:0,installPerformed:false};
fs.writeFileSync(path.join(out,'provenance.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({result:report.result,modules:modules.size,bytes:Buffer.byteLength(bundle),output:out}));
